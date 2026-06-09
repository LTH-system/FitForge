import SwiftUI
import Charts
import SwiftData

struct DashboardView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.modelContext) private var modelContext
    @State private var mealAmount = "普通"
    @State private var activity = "少しやった"
    @State private var condition = "普通"
    @State private var mood = "前向き"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profilePanel
                    checkInPanel
                    dailySummary
                    calorieTrend
                    suggestions
                    healthKitPanel
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("FitForge")
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
    }

    private var profilePanel: some View {
        let onboarding = store.preferences.onboarding
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(onboarding.primaryGoal.rawValue)
                        .font(.headline)
                    Text("週 \(onboarding.weeklyWorkoutDays) 回 / 食事は\(onboarding.mealTrackingStyle.rawValue)記録 / 1日は \(store.preferences.dayStartHour):\(String(format: "%02d", store.preferences.dayStartMinute)) から")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: icon(for: onboarding.primaryGoal))
                    .foregroundStyle(.teal)
                    .font(.title2)
            }
        }
        .panelStyle()
    }

    private var checkInPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("30秒チェックイン")
                        .font(.headline)
                    Text("完璧じゃなくて大丈夫。休む日も記録に入ります。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Picker("食事", selection: $mealAmount) {
                ForEach(["少なめ", "普通", "多め"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            Picker("運動", selection: $activity) {
                ForEach(["休んだ", "少しやった", "やった"], id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                Picker("体調", selection: $condition) {
                    ForEach(["だるい", "普通", "よい"], id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)

                Picker("気分", selection: $mood) {
                    ForEach(["しんどい", "普通", "前向き"], id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }

            Button {
                store.addCheckIn(mealAmount: mealAmount, activity: activity, condition: condition, mood: mood)
            } label: {
                Label("今日はここまででOK", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if let latest = store.checkIns.first {
                Text("最新: 食事 \(latest.mealAmount) / 運動 \(latest.activity) / 体調 \(latest.condition)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var dailySummary: some View {
        let ledger = store.todayLedger
        return VStack(alignment: .leading, spacing: 14) {
            Text("今日の収支")
                .font(.headline)

            HStack(spacing: 12) {
                MetricCard(title: "摂取", value: "\(ledger?.intakeKcal ?? 0)", unit: "kcal", color: .orange)
                MetricCard(title: "消費", value: "\(ledger?.expenditureKcal ?? 0)", unit: "kcal", color: .teal)
                MetricCard(title: "差分", value: "\(ledger?.balanceKcal ?? 0)", unit: "kcal", color: (ledger?.balanceKcal ?? 0) <= 0 ? .green : .red)
            }
        }
        .panelStyle()
    }

    private var calorieTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("カロリー収支と体重")
                    .font(.headline)
                Spacer()
                Text("直近42日")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(store.ledgers) { ledger in
                    BarMark(
                        x: .value("日付", ledger.date, unit: .day),
                        y: .value("収支", ledger.balanceKcal)
                    )
                    .foregroundStyle(ledger.balanceKcal <= 0 ? .green.opacity(0.7) : .red.opacity(0.65))
                }

                ForEach(store.bodyMetrics) { metric in
                    LineMark(
                        x: .value("日付", metric.date, unit: .day),
                        y: .value("体重", metric.weightKg * 100)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 220)

            HStack(spacing: 12) {
                DeltaCard(title: "週次理論", kg: store.predictedWeightDeltaKg(from: store.sevenDayBalance))
                DeltaCard(title: "週次実績", kg: store.actualWeightDeltaKg(days: 7))
                DeltaCard(title: "月次理論", kg: store.predictedWeightDeltaKg(from: store.thirtyDayBalance))
            }
        }
        .panelStyle()
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行動パターン")
                .font(.headline)

            ForEach(store.suggestions()) { item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.priority)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.teal))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.bold())
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .panelStyle()
    }

    private var healthKitPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("iOSヘルスケア")
                        .font(.headline)
                    Text(healthKit.authorizationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("連携") {
                    Task { await healthKit.requestAuthorization(preferences: store.preferences) }
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                MetricCard(title: "歩数", value: "\(Int(healthKit.latestStepCount))", unit: "歩", color: .blue)
                MetricCard(title: "活動", value: "\(Int(healthKit.latestActiveEnergyKcal))", unit: "kcal", color: .pink)
            }

            Button {
                Task {
                    await healthKit.refreshTodaySummary(preferences: store.preferences)
                    store.applyHealthKitSummary(
                        stepCount: Int(healthKit.latestStepCount),
                        activeKcal: Int(healthKit.latestActiveEnergyKcal),
                        basalKcal: Int(healthKit.latestBasalEnergyKcal),
                        bodyMassKg: healthKit.latestBodyMassKg
                    )
                    modelContext.insert(DailyHealthSummaryEntry(
                        lifeDayStart: LifeDayService.startOfLifeDay(containing: .now, preferences: store.preferences),
                        intakeKcal: store.todayLedger?.intakeKcal ?? 0,
                        activeKcal: Int(healthKit.latestActiveEnergyKcal),
                        basalKcal: Int(healthKit.latestBasalEnergyKcal),
                        stepCount: Int(healthKit.latestStepCount),
                        sourceRaw: DataSource.healthKit.rawValue
                    ))
                    if let bodyMassKg = healthKit.latestBodyMassKg {
                        modelContext.insert(BodyMetricEntry(from: BodyMetric(
                            date: .now,
                            weightKg: bodyMassKg,
                            bodyFatPercent: nil,
                            waistCm: nil,
                            source: .healthKit
                        )))
                    }
                    try? modelContext.save()
                }
            } label: {
                Label("今日のデータを同期", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .panelStyle()
    }

    private func icon(for goal: PrimaryGoal) -> String {
        switch goal {
        case .fatLoss: "scalemass"
        case .muscleGain: "dumbbell"
        case .running: "figure.run"
        case .hyrox: "figure.cross.training"
        case .health: "heart"
        }
    }
}
