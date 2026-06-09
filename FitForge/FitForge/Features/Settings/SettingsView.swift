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
        List {
            Section(L10n.text("language", languageCode: store.preferences.languageCode)) {
                Picker(L10n.text("language", languageCode: store.preferences.languageCode), selection: $selectedLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }

                Text(L10n.text("japanese_first", languageCode: store.preferences.languageCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.text("life_day", languageCode: store.preferences.languageCode)) {
                Stepper(value: $dayStartHour, in: 0...23) {
                    Text("\(L10n.text("wake_time", languageCode: store.preferences.languageCode)) \(dayStartHour):\(String(format: "%02d", dayStartMinute))")
                        .monospacedDigit()
                }

                Picker("分", selection: $dayStartMinute) {
                    Text("00").tag(0)
                    Text("15").tag(15)
                    Text("30").tag(30)
                    Text("45").tag(45)
                }
                .pickerStyle(.segmented)

                Text(L10n.text("life_day_detail", languageCode: store.preferences.languageCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("設定を保存") {
                    store.updatePreferences(
                        languageCode: selectedLanguage,
                        dayStartHour: dayStartHour,
                        dayStartMinute: dayStartMinute
                    )
                }
            }

            Section("連携") {
                HStack {
                    Label("iOSヘルスケア", systemImage: "heart.text.square")
                    Spacer()
                    Text(healthKit.authorizationStatusText)
                        .foregroundStyle(.secondary)
                }

                Button("HealthKitの読み取りを許可") {
                    Task { await healthKit.requestAuthorization(preferences: store.preferences) }
                }

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

                Button("過去7日を同期") {
                    Task {
                        await syncHealthKitHistory(days: 7)
                    }
                }

                Button("過去30日を同期") {
                    Task {
                        await syncHealthKitHistory(days: 30)
                    }
                }
            }

            Section("今後の接続先") {
                TextField("食事AI API URL", text: $mealAIEndpointURLString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                Button("食事AI API URLを保存") {
                    store.updateMealAIEndpoint(mealAIEndpointURLString)
                }

                Label("写真解析AI", systemImage: "camera.metering.matrix")
                Label("食事テキスト解析AI", systemImage: "sparkles")
                Label("Apple Watchワークアウト", systemImage: "applewatch")
                Label("Garmin / Strava", systemImage: "figure.outdoor.cycle")
            }

            Section("安心して使うために") {
                Label("食事AIは推定値として扱います", systemImage: "exclamationmark.magnifyingglass")
                Label("身体データは許可された範囲だけ読み取ります", systemImage: "lock.shield")
                Label("急激な減量ではなく、続けられる範囲を重視します", systemImage: "heart")
            }
        }
        .navigationTitle(L10n.text("settings", languageCode: store.preferences.languageCode))
        .onAppear {
            selectedLanguage = store.preferences.languageCode
            dayStartHour = store.preferences.dayStartHour
            dayStartMinute = store.preferences.dayStartMinute
            mealAIEndpointURLString = store.preferences.mealAIEndpointURLString
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
