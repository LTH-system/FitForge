import SwiftUI
import Charts

/// 直近7日間のふりかえり。画像として保存・共有もできる
struct WeeklyReviewView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    private var summary: AppStore.WeeklySummary { store.weeklySummary }

    var body: some View {
        NavigationStack {
            ScrollView {
                card
                    .padding()
            }
            .background(FF.background)
            .navigationTitle("今週のふりかえり")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let shareImage {
                        ShareLink(item: shareImage, preview: SharePreview("今週のふりかえり", image: shareImage)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { renderShareImage() }
        }
    }

    // MARK: カード（画面表示・シェア画像 共通）

    private var card: some View {
        VStack(spacing: 12) {
            periodHeader
            weightPanel
            metricsGrid
            nextWeekPanel
        }
    }

    private var periodHeader: some View {
        HStack {
            Text(Self.periodText(summary.interval))
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
            Spacer()
            if store.currentStreak > 0 {
                Label("\(store.currentStreak)日連続", systemImage: "flame.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(FF.accentText)
            }
        }
    }

    // MARK: 体重の変化

    private var weightPanel: some View {
        let deltaColor: Color = summary.actualWeightDeltaKg <= 0 ? FF.deficit : FF.over
        let onTrack = abs(summary.actualWeightDeltaKg) >= abs(summary.predictedWeightDeltaKg) * 0.8

        return VStack(alignment: .leading, spacing: 10) {
            Text("体重の変化")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(summary.actualWeightDeltaKg.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())))
                        .font(FF.fontHero)
                        .monospacedDigit()
                        .foregroundStyle(deltaColor)
                    Text("kg")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(deltaColor)
                }
                Text(onTrack ? "計画通り順調" : "計画 \(summary.predictedWeightDeltaKg.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())))kg より緩やか")
                    .font(FF.fontChip)
                    .foregroundStyle(FF.deficit)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(FF.deficit.opacity(0.12), in: Capsule())
            }

            if weightPoints.count >= 2 {
                Chart(weightPoints) { point in
                    AreaMark(x: .value("日付", point.dateLabel), y: .value("体重", point.weightKg))
                        .foregroundStyle(
                            LinearGradient(colors: [FF.deficit.opacity(0.2), FF.deficit.opacity(0)], startPoint: .top, endPoint: .bottom)
                        )
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("日付", point.dateLabel), y: .value("体重", point.weightKg))
                        .foregroundStyle(FF.deficit)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 90)
            }
        }
        .panelStyle()
    }

    private struct WeightPoint: Identifiable {
        var id = UUID()
        var dateLabel: String
        var weightKg: Double
    }

    private var weightPoints: [WeightPoint] {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "E"
            return f
        }()
        return store.bodyMetrics
            .filter { summary.interval.contains($0.date) }
            .sorted { $0.date < $1.date }
            .map { WeightPoint(dateLabel: formatter.string(from: $0.date), weightKg: $0.weightKg) }
    }

    // MARK: 指標グリッド

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            metricTile(title: "平均の摂取", value: "\(summary.averageIntakeKcal)", unit: "kcal", detail: "目標摂取 \(summary.budgetKcal) 以内")
            metricTile(title: "記録した日", value: "\(summary.recordedDayCount)", unit: "/ 7日", detail: "\(store.currentStreak)日連続中")
            metricTile(title: "リングを全部閉じた日", value: "\(summary.ringsClosedDayCount)", unit: "日", detail: nil)
            metricTile(title: "自己ベスト", value: "\(summary.bestCount)", unit: "件", detail: summary.bestHighlights.isEmpty ? nil : summary.bestHighlights.joined(separator: " · "))
        }
    }

    private func metricTile(title: String, value: String, unit: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(FF.fontNumber)
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
                Text(unit)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(FF.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(FF.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: 来週の計画

    private var nextWeekPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("来週の計画")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(FF.accentText)
            Text(nextWeekText)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(FF.textPrimary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FF.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var nextWeekText: String {
        var text = "目標摂取カロリーは \(summary.budgetKcal)kcal です。"
        if let arrival = summary.arrivalDate {
            text += "このペースなら \(Self.shortDate(arrival)) に目標体重へ到着予定です。"
        }
        return text
    }

    // MARK: 画像共有

    @MainActor
    private func renderShareImage() {
        let renderer = ImageRenderer(content: card.frame(width: 360).padding().background(FF.background))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    private static func periodText(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        let end = Calendar.current.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
        return "\(formatter.string(from: interval.start)) 〜 \(formatter.string(from: end))"
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "ja_JP")))
    }
}
