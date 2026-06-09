import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var currentWeightKg = 78.4
    @State private var targetWeightKg = 72.0
    @State private var dailyCalorieTarget = 2150

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    goalPanel
                    editPanel
                    balancePanel
                    actionPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("目標")
            .onAppear {
                currentWeightKg = store.latestWeight
                targetWeightKg = store.goal.targetWeightKg
                dailyCalorieTarget = store.goal.dailyCalorieTarget
            }
        }
    }

    private var goalPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("体重目標")
                .font(.headline)

            HStack(spacing: 12) {
                MetricCard(title: "現在", value: String(format: "%.1f", store.latestWeight), unit: "kg", color: .blue)
                MetricCard(title: "目標", value: String(format: "%.1f", store.goal.targetWeightKg), unit: "kg", color: .teal)
                MetricCard(title: "残り", value: String(format: "%.1f", max(0, store.latestWeight - store.goal.targetWeightKg)), unit: "kg", color: .orange)
            }

            ProgressView(value: max(0, min(1, (store.goal.currentWeightKg - store.latestWeight) / max(0.1, store.goal.currentWeightKg - store.goal.targetWeightKg))))
        }
        .panelStyle()
    }

    private var editPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目標を編集")
                .font(.headline)

            Stepper(value: $currentWeightKg, in: 30...200, step: 0.1) {
                Text("現在 \(currentWeightKg, specifier: "%.1f")kg")
                    .monospacedDigit()
            }

            Stepper(value: $targetWeightKg, in: 30...200, step: 0.1) {
                Text("目標 \(targetWeightKg, specifier: "%.1f")kg")
                    .monospacedDigit()
            }

            Stepper(value: $dailyCalorieTarget, in: 1200...5000, step: 50) {
                Text("目標摂取 \(dailyCalorieTarget)kcal")
                    .monospacedDigit()
            }

            Button {
                store.updateGoal(
                    currentWeightKg: currentWeightKg,
                    targetWeightKg: targetWeightKg,
                    dailyCalorieTarget: dailyCalorieTarget
                )
            } label: {
                Label("保存", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .panelStyle()
    }

    private var balancePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("理論値と実績")
                .font(.headline)

            ComparisonRow(label: "週次", predicted: store.predictedWeightDeltaKg(from: store.sevenDayBalance), actual: store.actualWeightDeltaKg(days: 7))
            ComparisonRow(label: "月次", predicted: store.predictedWeightDeltaKg(from: store.thirtyDayBalance), actual: store.actualWeightDeltaKg(days: 30))
            ComparisonRow(label: "年次換算", predicted: store.predictedWeightDeltaKg(from: store.thirtyDayBalance * 12), actual: store.actualWeightDeltaKg(days: 30) * 12)
        }
        .panelStyle()
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今やること")
                .font(.headline)

            ForEach(store.suggestions()) { suggestion in
                Label(suggestion.title, systemImage: "checkmark.circle")
                    .font(.subheadline)
            }
        }
        .panelStyle()
    }
}
