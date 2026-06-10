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
                    heroPanel
                    pfcPanel
                    checkInPanel
                    calorieTrend
                    suggestions
                    healthKitPanel
                }
                .padding()
            }
            .background(FF.background)
            .navigationTitle("FitForge")
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(FF.textSecondary)
                }
            }
        }
    }

    // MARK: - 今日のPFC合計

    private var todayPFC: (protein: Int, fat: Int, carb: Int) {
        let todayMeals = store.meals.filter {
            LifeDayService.isSameLifeDay($0.date, .now, preferences: store.preferences)
        }
        return (
            todayMeals.map(\.proteinG).reduce(0, +),
            todayMeals.map(\.fatG).reduce(0, +),
            todayMeals.map(\.carbG).reduce(0, +)
        )
    }

    // MARK: - ヒーロー（残りカロリー）

    private var heroPanel: some View {
        let target = store.goal.dailyCalorieTarget
        let intake = store.todayLedger?.intakeKcal ?? 0
        let burn = store.todayLedger?.expenditureKcal ?? 0
        let balance = store.todayLedger?.balanceKcal ?? 0
        let remaining = target - intake
        let progress = target > 0 ? Double(intake) / Double(target) : 0
        let onboarding = store.preferences.onboarding

        return VStack(spacing: 16) {
            HStack {
                FFBadge(text: onboarding.primaryGoal.rawValue, color: FF.accent)
                FFBadge(text: "週 \(onboarding.weeklyWorkoutDays) 回ペース", color: FF.run)
                Spacer()
                Text("目標 \(target) kcal")
                    .font(FF.fontCaption)
                    .monospacedDigit()
                    .foregroundStyle(FF.textTertiary)
            }

            ZStack {
                RingGauge(progress: progress, lineWidth: 14)
                    .frame(width: 240, height: 240)

                VStack(spacing: 4) {
                    Text(remaining >= 0 ? "今日あと" : "目標から")
                        .font(FF.fontCaption.weight(.medium))
                        .foregroundStyle(FF.textSecondary)
                    Text(remaining >= 0 ? "\(remaining)" : "+\(abs(remaining))")
                        .font(FF.fontHero)
                        .monospacedDigit()
                        .foregroundStyle(remaining >= 0 ? FF.textPrimary : FF.over)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textTertiary)
                }
            }

            Text(coachLine)
                .font(FF.fontBody)
                .lineSpacing(5)
                .foregroundStyle(FF.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                MetricCard(title: "摂取", value: "\(intake)", unit: "kcal", color: FF.intake, icon: "fork.knife")
                MetricCard(title: "消費", value: "\(burn)", unit: "kcal", color: FF.burn, icon: "flame.fill")
                MetricCard(
                    title: "差分",
                    value: "\(balance)",
                    unit: "kcal",
                    color: balance <= 0 ? FF.deficit : FF.over,
                    icon: "scalemass.fill"
                )
            }
        }
        .panelStyle()
    }

    private var coachLine: String {
        store.suggestions().first?.detail ?? "今日できることを、できる分だけで大丈夫です。"
    }

    // MARK: - PFC

    private var pfcPanel: some View {
        let pfc = todayPFC
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "今日のPFC", subtitle: "記録した食事からの合計です")
            PFCBars(protein: pfc.protein, fat: pfc.fat, carb: pfc.carb)
        }
        .panelStyle()
    }

    // MARK: - 30秒チェックイン

    private var checkInPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "30秒チェックイン", subtitle: "完璧じゃなくて大丈夫。休む日も記録に入ります。")

            checkInRow("食事") {
                FFSegmentedPicker(
                    options: ["少なめ", "普通", "多め"],
                    label: { $0 },
                    selection: $mealAmount,
                    tint: FF.intake
                )
            }

            checkInRow("運動") {
                FFSegmentedPicker(
                    options: ["休んだ", "少しやった", "やった"],
                    label: { $0 },
                    selection: $activity,
                    tint: FF.burn
                )
            }

            checkInRow("体調") {
                FFSegmentedPicker(
                    options: ["だるい", "普通", "よい"],
                    label: { $0 },
                    selection: $condition,
                    tint: FF.accent
                )
            }

            checkInRow("気分") {
                FFSegmentedPicker(
                    options: ["しんどい", "普通", "前向き"],
                    label: { $0 },
                    selection: $mood,
                    tint: FF.protein
                )
            }

            Button {
                store.addCheckIn(mealAmount: mealAmount, activity: activity, condition: condition, mood: mood)
            } label: {
                Label("今日はここまででOK", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(FFSecondaryButtonStyle())

            if let latest = store.checkIns.first {
                Text("最新: 食事 \(latest.mealAmount) / 運動 \(latest.activity) / 体調 \(latest.condition)")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textTertiary)
            }
        }
        .panelStyle()
    }

    private func checkInRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(FF.fontCaption.weight(.medium))
                .foregroundStyle(FF.textSecondary)
            content()
        }
    }

    // MARK: - カロリー収支チャート

    private var calorieTrend: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "カロリー収支と体重")
                Spacer()
                Text("直近42日")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.textTertiary)
            }

            Chart {
                ForEach(store.ledgers) { ledger in
                    BarMark(
                        x: .value("日付", ledger.date, unit: .day),
                        y: .value("収支", ledger.balanceKcal)
                    )
                    .foregroundStyle(ledger.balanceKcal <= 0 ? FF.deficit : FF.over)
                    .cornerRadius(4)
                }

                ForEach(store.bodyMetrics) { metric in
                    AreaMark(
                        x: .value("日付", metric.date, unit: .day),
                        y: .value("体重", metric.weightKg * 100)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FF.accent.opacity(0.2), FF.accent.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("日付", metric.date, unit: .day),
                        y: .value("体重", metric.weightKg * 100)
                    )
                    .foregroundStyle(FF.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
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

    // MARK: - 行動パターン

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "行動パターン")

            ForEach(store.suggestions()) { item in
                HStack(alignment: .top, spacing: 12) {
                    FFBadge(text: item.priority, color: FF.accent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(FF.textPrimary)
                        Text(item.detail)
                            .font(FF.fontCaption)
                            .lineSpacing(3)
                            .foregroundStyle(FF.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(FF.surfaceSecondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .panelStyle()
    }

    // MARK: - HealthKit

    private var healthKitPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                IconSeat(systemName: "heart.fill", color: FF.protein, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iOSヘルスケア")
                        .font(FF.fontSection)
                        .foregroundStyle(FF.textPrimary)
                    Text(healthKit.authorizationStatusText)
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                Spacer()
                Button("連携") {
                    Task { await healthKit.requestAuthorization(preferences: store.preferences) }
                }
                .buttonStyle(FFCompactButtonStyle(tint: FF.accent, isSelected: true))
            }

            HStack(spacing: 12) {
                MetricCard(title: "歩数", value: "\(Int(healthKit.latestStepCount))", unit: "歩", color: FF.carb, icon: "figure.walk")
                MetricCard(title: "活動", value: "\(Int(healthKit.latestActiveEnergyKcal))", unit: "kcal", color: FF.burn, icon: "flame.fill")
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
            }
            .buttonStyle(FFSecondaryButtonStyle(tint: FF.burn))
        }
        .panelStyle()
    }
}
