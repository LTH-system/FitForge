import SwiftUI
import Charts

/// 自己ベスト更新の演出画面。筋トレの重量PBと有酸素の距離PBの両方に使う
struct PersonalBestCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: Image?

    /// 画面上部の見出し（自己ベスト更新・完走など）
    var headline = "自己ベスト更新！"
    var exerciseTitle: String
    var valueText: String
    var unitText: String
    var badge: Badge?
    var trend: [TrendPoint]
    var trendTitle: String
    var footerText: String

    struct Badge {
        var label: String
        var value: String
        var delta: String
    }

    struct TrendPoint: Identifiable {
        var id = UUID()
        var dateLabel: String
        var value: Double
        var isLatest: Bool
    }

    init(exerciseTitle: String, valueText: String, unitText: String, badge: Badge?, trend: [TrendPoint], trendTitle: String, footerText: String) {
        self.exerciseTitle = exerciseTitle
        self.valueText = valueText
        self.unitText = unitText
        self.badge = badge
        self.trend = trend
        self.trendTitle = trendTitle
        self.footerText = footerText
    }

    /// 筋トレの重量PB用
    init(celebrating set: StrengthSet, store: AppStore) {
        let allTrend = PersonalBestDetector.oneRepMaxTrend(exercise: set.exercise, among: store.strengthSets)
        let previousBest1RM = allTrend.dropLast().map(\.value).max()

        exerciseTitle = set.exercise
        valueText = set.weightKg.formatted()
        unitText = "kg × \(set.reps)回"
        if let previousBest1RM {
            let delta = set.estimatedOneRepMax - previousBest1RM
            badge = Badge(
                label: "推定1RM",
                value: "\(set.estimatedOneRepMax.formatted(.number.precision(.fractionLength(1))))kg",
                delta: "+\(delta.formatted(.number.precision(.fractionLength(1))))kg"
            )
        } else {
            badge = nil
        }
        trend = Self.points(from: allTrend)
        trendTitle = "推定1RMの推移"
        footerText = Self.footer(store: store)
    }

    /// 大会（sessionType が race）の結果用。自己ベストでなくても完走を祝ってシェアできるようにする
    init(raceResult session: CardioSession, store: AppStore) {
        let allTrend = PersonalBestDetector.distanceTrend(kind: session.kind, among: store.cardioSessions)
        let isBest = PersonalBestDetector.isBestDistance(session, among: store.cardioSessions)

        headline = isBest ? "自己ベスト更新！" : "完走おめでとう！"
        exerciseTitle = session.kind == .hyrox ? "HYROX" : "\(session.kind.rawValue)の大会"
        valueText = Self.durationText(minutes: session.durationMinutes)
        unitText = ""
        badge = session.distanceKm > 0
            ? Badge(label: "\(session.distanceKm.formatted(.number.precision(.fractionLength(1))))km", value: session.paceText, delta: isBest ? "距離の自己ベスト" : "")
            : nil
        trend = Self.points(from: allTrend)
        trendTitle = "距離の推移"
        footerText = Self.footer(store: store)
    }

    /// 90分 → 1:30:00、45分 → 45:00
    private static func durationText(minutes: Int) -> String {
        minutes >= 60 ? String(format: "%d:%02d:00", minutes / 60, minutes % 60) : String(format: "%d:00", minutes)
    }

    /// 有酸素（ラン・HYROX・マラソン）の距離PB用
    init(celebrating session: CardioSession, store: AppStore) {
        let allTrend = PersonalBestDetector.distanceTrend(kind: session.kind, among: store.cardioSessions)

        exerciseTitle = session.kind.rawValue
        valueText = session.distanceKm.formatted(.number.precision(.fractionLength(1)))
        unitText = "km"
        badge = Badge(label: "ペース", value: session.paceText, delta: "自己ベスト")
        trend = Self.points(from: allTrend)
        trendTitle = "距離の推移"
        footerText = Self.footer(store: store)
    }

    private static func points(from trend: [(date: Date, value: Double)]) -> [TrendPoint] {
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ja_JP")
            f.dateFormat = "M/d"
            return f
        }()
        return trend.enumerated().map { index, item in
            TrendPoint(dateLabel: formatter.string(from: item.date), value: item.value, isLatest: index == trend.count - 1)
        }
    }

    private static func footer(store: AppStore) -> String {
        let monthlyCount = PersonalBestDetector.monthlyBestCount(strengthSets: store.strengthSets, cardioSessions: store.cardioSessions)
        return "\(store.currentStreak)日連続記録中 · 今月のベスト更新 \(monthlyCount)回目"
    }

    var body: some View {
        ZStack {
            Color(hex: 0x15171B).ignoresSafeArea()
            confetti

            VStack(spacing: 14) {
                Spacer(minLength: 40)

                resultContent

                Spacer(minLength: 40)

                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview(headline, image: shareImage)) {
                        Label("画像でシェア", systemImage: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(hex: 0x1F2228), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color(hex: 0x2E323A), lineWidth: 1))
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("続ける")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x1F7A2B), Color(hex: 0x1C5F42)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
        .task { renderShareImage() }
    }

    /// 画面表示とシェア画像で共通の中身
    private var resultContent: some View {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: 0x2DBF5D).opacity(0.16))
                        .frame(width: 108, height: 108)
                    Circle()
                        .fill(Color(hex: 0x2DBF5D))
                        .frame(width: 78, height: 78)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color(hex: 0x15171B))
                }

                Text(headline)
                    .font(.system(size: 15, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: 0x8BEE90))

                Text(exerciseTitle)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(valueText)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(unitText)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xA6ADB8))
                }

                if let badge {
                    HStack(spacing: 8) {
                        Text(badge.label)
                            .foregroundStyle(Color(hex: 0xA6ADB8))
                        Text(badge.value)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                        Text(badge.delta)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(Color(hex: 0x54D6A4))
                    }
                    .font(.system(size: 13))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: 0x1F2228), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color(hex: 0x2E323A), lineWidth: 1))
                }

                if trend.count >= 2 {
                    trendChart
                        .padding(14)
                        .background(Color(hex: 0x1F2228), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 6)
                }

                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color(hex: 0x2DBF5D))
                    Text(footerText)
                        .foregroundStyle(Color(hex: 0xA6ADB8))
                }
                .font(.system(size: 13))
            }
    }

    // MARK: シェア画像

    @MainActor
    private func renderShareImage() {
        let card = VStack(spacing: 18) {
            resultContent
            Text("FitForge")
                .font(.system(size: 13, weight: .bold))
                .tracking(2)
                .foregroundStyle(Color(hex: 0x6A7079))
        }
        .padding(28)
        .frame(width: 360)
        .background(Color(hex: 0x15171B))
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            shareImage = Image(uiImage: uiImage)
        }
    }

    private var trendChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trendTitle)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("直近\(trend.count)件")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: 0xA6ADB8))
            }
            Chart(trend) { point in
                LineMark(x: .value("日付", point.dateLabel), y: .value("値", point.value))
                    .foregroundStyle(Color(hex: 0x2DBF5D))
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("日付", point.dateLabel), y: .value("値", point.value))
                    .foregroundStyle(point.isLatest ? Color(hex: 0x15171B) : Color(hex: 0x2DBF5D))
                    .symbolSize(point.isLatest ? 90 : 40)
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: 0xA6ADB8))
                        }
                    }
                }
            }
            .frame(height: 100)
        }
    }

    private var confetti: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<10, id: \.self) { index in
                    let colors: [Color] = [
                        Color(hex: 0x2DBF5D), Color(hex: 0xF7C766), Color(hex: 0x48DCCE),
                        Color(hex: 0xF27BA3), Color(hex: 0x7BA5F5), Color(hex: 0xB07FF0), Color(hex: 0x54D6A4)
                    ]
                    let x = CGFloat((index * 37) % 100) / 100 * geo.size.width
                    let y = CGFloat((index * 53) % 60 + 10) / 100 * geo.size.height
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colors[index % colors.count])
                        .frame(width: index.isMultiple(of: 3) ? 8 : 6, height: index.isMultiple(of: 3) ? 8 : 12)
                        .rotationEffect(.degrees(Double(index * 41 % 360)))
                        .position(x: x, y: y)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
