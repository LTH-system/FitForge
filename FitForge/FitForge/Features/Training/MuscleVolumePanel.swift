import SwiftUI

/// 部位別のトレーニング量（プレミアム）。直近7日のセット数を部位・種類ごとに並べ、前の7日と比べる
struct MuscleVolumePanel: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var premium: PremiumStore

    var body: some View {
        if premium.isPremium {
            content
        } else {
            PremiumLockedCard(feature: .muscleVolume)
        }
    }

    private var content: some View {
        let rows = store.muscleVolumeRows()
        let maxSets = max(1, rows.map { max($0.sets, $0.previousSets) }.max() ?? 1)
        let totalVolume = rows.map(\.volumeKg).reduce(0, +)

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "部位別のトレーニング量", subtitle: "直近7日のセット数（薄い線は前の7日）")

            if rows.isEmpty {
                Text("この2週間の筋トレ記録がまだありません")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                ForEach(rows) { row in
                    VStack(spacing: 4) {
                        HStack {
                            Text(row.title)
                                .font(FF.fontCaption.weight(.medium))
                                .foregroundStyle(FF.textPrimary)
                            Spacer()
                            Text("\(row.sets)セット")
                                .font(FF.fontChip)
                                .monospacedDigit()
                                .foregroundStyle(FF.strength)
                            Text(changeText(row))
                                .font(FF.fontCaption)
                                .monospacedDigit()
                                .foregroundStyle(FF.textTertiary)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(FF.strength.opacity(0.12))
                                Capsule()
                                    .fill(FF.strength)
                                    .frame(width: geo.size.width * Double(row.sets) / Double(maxSets))
                                Rectangle()
                                    .fill(FF.textTertiary)
                                    .frame(width: 2, height: 12)
                                    .offset(x: max(0, geo.size.width * Double(row.previousSets) / Double(maxSets) - 1))
                                    .opacity(row.previousSets > 0 ? 1 : 0)
                            }
                        }
                        .frame(height: 8)
                    }
                }

                Text("この7日の総ボリューム（重量×回数×セット）：\(Int(totalVolume).formatted())kg")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textSecondary)
                if rows.contains(where: { $0.category == nil }) {
                    Text("種目カタログにない名前の種目は「その他」にまとめています")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textTertiary)
                }
            }
        }
        .panelStyle()
    }

    private func changeText(_ row: MuscleVolumeRow) -> String {
        let diff = row.sets - row.previousSets
        if row.previousSets == 0 { return "前週 0" }
        if diff == 0 { return "前週と同じ" }
        return "前週 \(diff > 0 ? "+" : "")\(diff)"
    }
}

/// 次回の重量の提案（プレミアム）。前回の記録から、次に挑戦する重量と回数を出す
struct ProgressionSuggestionCard: View {
    @EnvironmentObject private var store: AppStore
    var exercise: String
    /// この日時より前の記録から提案する（ワークアウト中は開始時刻を渡す）
    var before: Date = .now
    /// 指定すると「この内容を入力」ボタンを出す
    var onApply: ((ProgressionSuggestion) -> Void)?

    var body: some View {
        if let suggestion = ProgressionAdvisor.suggest(exercise: exercise, history: store.strengthSets, before: before, preferences: store.preferences) {
            HStack(alignment: .top, spacing: 12) {
                IconSeat(systemName: "arrow.up.forward.circle.fill", color: FF.strength, size: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("次回の提案")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                    Text(suggestion.headline)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(FF.textPrimary)
                    Text(suggestion.reason)
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let onApply {
                        Button("この内容を入力") { onApply(suggestion) }
                            .buttonStyle(FFCompactButtonStyle(tint: FF.strength, isSelected: true))
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(FF.strength.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
