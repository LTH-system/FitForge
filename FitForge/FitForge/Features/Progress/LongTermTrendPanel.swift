import SwiftUI
import Charts

/// 長期の推移と分析（プレミアム）。体重の推移と、週・月ごとの平均収支、理論値と実測の比較
struct LongTermTrendPanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var premium: PremiumStore
    @State private var range: TrendRange = .threeMonths

    var body: some View {
        if premium.isPremium {
            content
        } else {
            PremiumLockedCard(feature: .trends)
        }
    }

    private var content: some View {
        let report = store.trendReport(for: range)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "長期の推移", subtitle: "食事を記録した日だけで平均しています")

            FFSegmentedPicker(options: TrendRange.allCases, label: \.rawValue, selection: $range)

            summaryTiles(report)

            if report.weightPoints.count >= 2 {
                weightChart(report)
            }

            if report.periods.contains(where: { $0.loggedDays > 0 }) {
                balanceChart(report)
            }

            if report.weightPoints.count < 2 && report.loggedDays == 0 {
                Text("この期間の食事・体重の記録がまだありません")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }

            insightText(report)
        }
        .panelStyle()
    }

    // MARK: 数字のまとめ

    private func summaryTiles(_ report: TrendReport) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                tile(title: "記録した日", value: "\(report.loggedDays)", unit: "/ \(report.totalDays)日", color: FF.textPrimary)
                tile(
                    title: "平均収支",
                    value: report.averageBalanceKcal.map { $0.formatted(.number.sign(strategy: .always())) } ?? "--",
                    unit: "kcal/日",
                    color: (report.averageBalanceKcal ?? 0) <= 0 ? FF.deficit : FF.over
                )
            }
            HStack(spacing: 8) {
                deltaTile(title: "理論値", kg: report.predictedDeltaKg)
                deltaTile(title: "実測", kg: report.actualDeltaKg)
            }
        }
    }

    @ViewBuilder
    private func deltaTile(title: String, kg: Double?) -> some View {
        if let kg {
            DeltaCard(title: title, kg: kg)
        } else {
            tile(title: title, value: "--", unit: "", color: FF.textTertiary)
        }
    }

    private func tile(title: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(unit)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: グラフ

    private func weightChart(_ report: TrendReport) -> some View {
        let weights = report.weightPoints.map(\.weightKg)
        let lower = (weights.min() ?? 0) - 1
        let upper = (weights.max() ?? 0) + 1

        return VStack(alignment: .leading, spacing: 6) {
            Text("体重")
                .font(FF.fontCaption.weight(.medium))
                .foregroundStyle(FF.textSecondary)
            Chart {
                ForEach(report.weightPoints) { point in
                    LineMark(
                        x: .value("日付", point.date, unit: .day),
                        y: .value("体重", point.weightKg)
                    )
                    .foregroundStyle(FF.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                RuleMark(y: .value("目標", store.goal.targetWeightKg))
                    .foregroundStyle(FF.textTertiary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: min(lower, store.goal.targetWeightKg - 0.5)...max(upper, store.goal.targetWeightKg + 0.5))
            .frame(height: 170)
        }
    }

    private func balanceChart(_ report: TrendReport) -> some View {
        let periods = report.periods.filter { $0.loggedDays > 0 }
        let unit: Calendar.Component = report.range.groupsByMonth ? .month : .weekOfYear

        return VStack(alignment: .leading, spacing: 6) {
            Text(report.range.groupsByMonth ? "月ごとの平均収支（kcal/日）" : "週ごとの平均収支（kcal/日）")
                .font(FF.fontCaption.weight(.medium))
                .foregroundStyle(FF.textSecondary)
            Chart {
                ForEach(periods) { period in
                    BarMark(
                        x: .value("期間", period.start, unit: unit),
                        y: .value("収支", period.averageBalanceKcal)
                    )
                    .foregroundStyle(period.averageBalanceKcal <= 0 ? FF.deficit : FF.over)
                    .cornerRadius(4)
                }
                RuleMark(y: .value("ゼロ", 0))
                    .foregroundStyle(FF.separator)
            }
            .frame(height: 150)
        }
    }

    // MARK: ひとこと

    private func insightText(_ report: TrendReport) -> some View {
        Text(insight(report))
            .font(FF.fontCaption)
            .foregroundStyle(FF.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func insight(_ report: TrendReport) -> String {
        guard let predicted = report.predictedDeltaKg else {
            return "食事の記録が\(TrendReport.minimumLoggedDays)日以上あると、この期間の理論値を計算できます。"
        }
        guard let actual = report.actualDeltaKg else {
            return "体重を2回以上記録すると、理論値と実測を比べられます。"
        }
        let gap = actual - predicted
        if abs(gap) < 0.5 {
            return "理論値と実測がほぼ一致しています。記録と計算が実態に合っています。"
        }
        if gap > 0 {
            return "実測の体重が理論値より\(gap.formatted(.number.precision(.fractionLength(1))))kg重くなっています。記録していない間食や飲み物がないか、見直してみましょう。"
        }
        return "実測の体重が理論値より\((-gap).formatted(.number.precision(.fractionLength(1))))kg軽くなっています。消費が見積もりより多い可能性があります。毎週の自動補正で目標摂取カロリーに反映されます。"
    }
}
