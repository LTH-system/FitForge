import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService
    @Environment(\.modelContext) private var modelContext
    @State private var selectedLanguage = "ja"
    @State private var dayStartHour = 5
    @State private var dayStartMinute = 0
    @State private var mealAIEndpointURLString = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                languagePanel
                lifeDayPanel
                healthKitPanel
                connectionPanel
                trustPanel
            }
            .padding()
        }
        .background(FF.background)
        .navigationTitle(L10n.text("settings", languageCode: store.preferences.languageCode))
        .onAppear {
            selectedLanguage = store.preferences.languageCode
            dayStartHour = store.preferences.dayStartHour
            dayStartMinute = store.preferences.dayStartMinute
            mealAIEndpointURLString = store.preferences.mealAIEndpointURLString
        }
    }

    // MARK: 言語

    private var languagePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: L10n.text("language", languageCode: store.preferences.languageCode))

            FFSegmentedPicker(
                options: AppLanguage.allCases.map(\.rawValue),
                label: { code in AppLanguage(rawValue: code)?.displayName ?? code },
                selection: $selectedLanguage
            )

            Text(L10n.text("japanese_first", languageCode: store.preferences.languageCode))
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)
        }
        .panelStyle()
    }

    // MARK: 生活日

    private var lifeDayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: L10n.text("life_day", languageCode: store.preferences.languageCode))

            FFStepperRow(
                label: L10n.text("wake_time", languageCode: store.preferences.languageCode),
                valueText: "\(dayStartHour):\(String(format: "%02d", dayStartMinute))",
                onMinus: { dayStartHour = max(0, dayStartHour - 1) },
                onPlus: { dayStartHour = min(23, dayStartHour + 1) }
            )

            FFSegmentedPicker(
                options: [0, 15, 30, 45],
                label: { String(format: "%02d", $0) },
                selection: $dayStartMinute
            )

            Text(L10n.text("life_day_detail", languageCode: store.preferences.languageCode))
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)

            Button("設定を保存") {
                store.updatePreferences(
                    languageCode: selectedLanguage,
                    dayStartHour: dayStartHour,
                    dayStartMinute: dayStartMinute
                )
            }
            .buttonStyle(FFSecondaryButtonStyle())
        }
        .panelStyle()
    }

    // MARK: 連携

    private var healthKitPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "連携")

            HStack(spacing: 10) {
                IconSeat(systemName: "heart.text.square", color: FF.accent)
                Text("iOSヘルスケア")
                    .font(FF.fontBody)
                    .foregroundStyle(FF.textPrimary)
                Spacer()
                FFBadge(text: healthKit.authorizationStatusText, color: FF.textSecondary)
            }

            Button("HealthKitの読み取りを許可") {
                Task { await healthKit.requestAuthorization(preferences: store.preferences) }
            }
            .buttonStyle(FFSecondaryButtonStyle())

            Button("今日のHealthKitデータを同期") {
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
            }
            .buttonStyle(FFSecondaryButtonStyle())

            HStack(spacing: 12) {
                Button("過去7日を同期") {
                    Task {
                        await syncHealthKitHistory(days: 7)
                    }
                }
                .buttonStyle(FFSecondaryButtonStyle())

                Button("過去30日を同期") {
                    Task {
                        await syncHealthKitHistory(days: 30)
                    }
                }
                .buttonStyle(FFSecondaryButtonStyle())
            }
        }
        .panelStyle()
    }

    // MARK: 今後の接続先

    private var connectionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "今後の接続先")

            TextField("食事AI API URL", text: $mealAIEndpointURLString)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .ffFieldStyle()

            Button("食事AI API URLを保存") {
                store.updateMealAIEndpoint(mealAIEndpointURLString)
            }
            .buttonStyle(FFSecondaryButtonStyle())

            infoRow("camera.metering.matrix", "写真解析AI")
            infoRow("sparkles", "食事テキスト解析AI")
            infoRow("applewatch", "Apple Watchワークアウト")
            infoRow("figure.outdoor.cycle", "Garmin / Strava")
        }
        .panelStyle()
    }

    // MARK: 安心して使うために

    private var trustPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "安心して使うために")

            infoRow("exclamationmark.magnifyingglass", "食事AIは推定値として扱います")
            infoRow("lock.shield", "身体データは許可された範囲だけ読み取ります")
            infoRow("heart", "急激な減量ではなく、続けられる範囲を重視します")
        }
        .panelStyle()
    }

    private func infoRow(_ systemName: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            IconSeat(systemName: systemName, color: FF.accent)
            Text(text)
                .font(FF.fontBody)
                .foregroundStyle(FF.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private func syncHealthKitHistory(days: Int) async {
        await healthKit.refreshDailySummaries(days: days, preferences: store.preferences)
        store.applyHealthKitDailySummaries(healthKit.recentDailySummaries)

        for summary in healthKit.recentDailySummaries {
            modelContext.insert(DailyHealthSummaryEntry(
                lifeDayStart: summary.lifeDayStart,
                intakeKcal: store.ledgers.first(where: {
                    LifeDayService.isSameLifeDay($0.date, summary.lifeDayStart, preferences: store.preferences)
                })?.intakeKcal ?? 0,
                activeKcal: summary.activeKcal,
                basalKcal: summary.basalKcal,
                stepCount: summary.stepCount,
                sourceRaw: DataSource.healthKit.rawValue
            ))
        }

        try? modelContext.save()
    }
}
