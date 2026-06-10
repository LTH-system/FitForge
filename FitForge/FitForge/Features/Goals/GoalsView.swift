import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var currentWeightKg = 78.4
    @State private var targetWeightKg = 72.0
    @State private var dailyCalorieTarget = 2150

    private var remainingKg: Double {
        max(0, store.latestWeight - store.goal.targetWeightKg)
    }

    private var progress: Double {
        max(0, min(1, (store.goal.currentWeightKg - store.latestWeight) / max(0.1, store.goal.currentWeightKg - store.goal.targetWeightKg)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    goalPanel
                    editPanel
                    balancePanel
                    actionPanel
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("目標")
            .onAppear {
                currentWeightKg = store.latestWeight
                targetWeightKg = store.goal.targetWeightKg
                dailyCalorieTarget = store.goal.dailyCalorieTarget
            }
        }
    }

    // MARK: 体重目標（ヒーロー）

    private var goalPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "体重目標")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("あと")
                        .font(FF.fontBody)
                        .foregroundStyle(FF.textSecondary)
                    Text(String(format: "%.1f", remainingKg))
                        .font(FF.fontHero)
                        .monospacedDigit()
                        .foregroundStyle(FF.textPrimary)
                    Text("kg")
                        .font(FF.fontNumber)
                        .foregroundStyle(FF.textSecondary)
                }

                gradientProgressBar
            }

            HStack(spacing: 12) {
                MetricCard(
                    title: "現在",
                    value: String(format: "%.1f", store.latestWeight),
                    unit: "kg",
                    color: FF.burn,
                    icon: "figure.stand"
                )
                MetricCard(
                    title: "目標",
                    value: String(format: "%.1f", store.goal.targetWeightKg),
                    unit: "kg",
                    color: FF.deficit,
                    icon: "target"
                )
                MetricCard(
                    title: "残り",
                    value: String(format: "%.1f", remainingKg),
                    unit: "kg",
                    color: FF.accent,
                    icon: "flag.checkered"
                )
            }
        }
        .panelStyle()
    }

    private var gradientProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FF.surfaceSecondary)
                Capsule()
                    .fill(FF.accentGradient)
                    .frame(width: max(10, geo.size.width * progress))
            }
        }
        .frame(height: 10)
    }

    // MARK: 目標を編集

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "目標を編集")

            FFStepperRow(
                label: "現在",
                valueText: String(format: "%.1fkg", currentWeightKg),
                onMinus: { currentWeightKg = max(30, currentWeightKg - 0.1) },
                onPlus: { currentWeightKg = min(200, currentWeightKg + 0.1) }
            )

            FFStepperRow(
                label: "目標",
                valueText: String(format: "%.1fkg", targetWeightKg),
                onMinus: { targetWeightKg = max(30, targetWeightKg - 0.1) },
                onPlus: { targetWeightKg = min(200, targetWeightKg + 0.1) }
            )

            FFStepperRow(
                label: "目標摂取",
                valueText: "\(dailyCalorieTarget)kcal",
                onMinus: { dailyCalorieTarget = max(1200, dailyCalorieTarget - 50) },
                onPlus: { dailyCalorieTarget = min(5000, dailyCalorieTarget + 50) }
            )

            Button {
                store.updateGoal(
                    currentWeightKg: currentWeightKg,
                    targetWeightKg: targetWeightKg,
                    dailyCalorieTarget: dailyCalorieTarget
                )
            } label: {
                Label("保存", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FFPrimaryButtonStyle())
        }
        .panelStyle()
    }

    // MARK: 理論値と実績

    private var balancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "理論値と実績")

            ComparisonRow(label: "週次", predicted: store.predictedWeightDeltaKg(from: store.sevenDayBalance), actual: store.actualWeightDeltaKg(days: 7))
            ComparisonRow(label: "月次", predicted: store.predictedWeightDeltaKg(from: store.thirtyDayBalance), actual: store.actualWeightDeltaKg(days: 30))
            ComparisonRow(label: "年次換算", predicted: store.predictedWeightDeltaKg(from: store.thirtyDayBalance * 12), actual: store.actualWeightDeltaKg(days: 30) * 12)
        }
        .panelStyle()
    }

    // MARK: 今やること

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "今やること")

            ForEach(store.suggestions()) { suggestion in
                HStack(spacing: 10) {
                    IconSeat(systemName: "checkmark.circle", color: FF.deficit, size: 24)
                    Text(suggestion.title)
                        .font(FF.fontBody)
                        .foregroundStyle(FF.textPrimary)
                    Spacer(minLength: 0)
                }
            }
        }
        .panelStyle()
    }
}
