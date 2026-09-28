import SwiftUI

/// 栄養の過不足（プレミアム）。選んだ日と直近7日平均を、目標量と比べる
struct NutrientBalancePanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var premium: PremiumStore
    var nutrition: DailyNutrition
    var isToday: Bool

    private enum Scope: String, CaseIterable {
        case day
        case week
    }

    @State private var scope: Scope = .day

    var body: some View {
        if premium.isPremium {
            content
        } else {
            PremiumLockedCard(feature: .nutritionBalance)
        }
    }

    private var content: some View {
        let weekly = store.averageNutrientBalance(days: 7)
        let rows = scope == .day ? store.nutrientBalance(for: nutrition) : weekly.rows
        let targets = store.nutrientTargets

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "栄養の過不足", subtitle: "目標の80〜120%を「目標どおり」としています")

            FFSegmentedPicker(
                options: Scope.allCases,
                label: { $0 == .day ? (isToday ? "今日" : "この日") : "直近7日平均" },
                selection: $scope
            )

            if rows.isEmpty || (scope == .day && nutrition.kcal == 0) {
                Text(scope == .day ? "この日の食事を記録すると表示されます" : "直近7日の食事記録がまだありません")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ForEach(rows) { row in
                    rowView(row)
                }
                if scope == .week {
                    Text("食事を記録した\(weekly.loggedDays)日の平均です")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textTertiary)
                }
                if let advice = advice(for: rows) {
                    Text(advice)
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text("目標：たんぱく質 体重×1.6g（\(targets.proteinG)g）、脂質 目標摂取カロリーの25%（\(targets.fatG)g）、炭水化物 残り（\(targets.carbG)g）")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelStyle()
    }

    private func color(for name: String) -> Color {
        switch name {
        case "たんぱく質": FF.protein
        case "脂質": FF.fat
        case "炭水化物": FF.carb
        default: FF.intake
        }
    }

    private func statusColor(_ status: NutrientStatus) -> Color {
        switch status {
        case .low: FF.over
        case .ok: FF.deficit
        case .high: FF.over
        }
    }

    private func rowView(_ row: NutrientBalanceRow) -> some View {
        let tint = color(for: row.name)
        return VStack(spacing: 4) {
            HStack {
                Text(row.name)
                    .font(FF.fontCaption.weight(.medium))
                    .foregroundStyle(FF.textSecondary)
                Spacer()
                Text("\(row.actual) / \(row.target)\(row.unit)")
                    .font(FF.fontChip)
                    .monospacedDigit()
                    .foregroundStyle(FF.textPrimary)
                Text(row.status.label)
                    .font(FF.fontCaption.weight(.semibold))
                    .foregroundStyle(statusColor(row.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusColor(row.status).opacity(0.12), in: Capsule())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * min(1, row.ratio / 1.5))
                    // 目標（100%）の位置
                    Rectangle()
                        .fill(FF.textTertiary)
                        .frame(width: 2, height: 12)
                        .offset(x: geo.size.width / 1.5 - 1)
                }
            }
            .frame(height: 8)
        }
    }

    /// いちばん気になる項目についてのひとこと
    private func advice(for rows: [NutrientBalanceRow]) -> String? {
        if let protein = rows.first(where: { $0.name == "たんぱく質" }), protein.status == .low {
            return "たんぱく質があと\(protein.target - protein.actual)gほど足りません。卵・鶏むね肉・豆腐・プロテインなどで補えます。"
        }
        if let fat = rows.first(where: { $0.name == "脂質" }), fat.status == .high {
            return "脂質が多めです。揚げ物や脂身の多い肉を、焼き・蒸し料理や赤身に置き換えると抑えられます。"
        }
        if let carb = rows.first(where: { $0.name == "炭水化物" }), carb.status == .high {
            return "炭水化物が多めです。主食の量を少し減らすか、間食の甘いものを見直してみましょう。"
        }
        if rows.allSatisfy({ $0.status == .ok }) {
            return "すべて目標どおりです。この調子で続けましょう。"
        }
        return nil
    }
}
