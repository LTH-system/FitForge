import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var healthKit: HealthKitService
    @EnvironmentObject private var cloudBackup: CloudBackupService
    @EnvironmentObject private var premium: PremiumStore
    @Environment(\.modelContext) private var modelContext
    @State private var dayStartHour = 5
    @State private var dayStartMinute = 0
    @State private var mealAIEndpointURLString = ""
    @State private var showEraseConfirm = false
    @State private var isEditingBody = false
    @State private var isEditingGoal = false
    @State private var notificationSettings = NotificationSettings()
    @State private var isNotificationAuthorized = true
    @State private var showRestoreConfirm = false
    @State private var isPaywallPresented = false
    @State private var isManagingSubscription = false
    @State private var restoreResultMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                premiumPanel
                profilePanel
                lifeDayPanel
                notificationPanel
                healthKitPanel
                connectionPanel
                backupPanel
                dataPanel
                trustPanel
            }
            .padding()
        }
        .background(FF.background)
        .navigationTitle("マイページ")
        .sheet(isPresented: $isEditingBody) {
            BodyProfileEditorView()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isPaywallPresented) {
            PremiumPaywallView()
        }
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .sheet(isPresented: $isEditingGoal) {
            GoalEditorView()
                .presentationDetents([.medium])
        }
        .onAppear {
            dayStartHour = store.preferences.dayStartHour
            dayStartMinute = store.preferences.dayStartMinute
            mealAIEndpointURLString = store.preferences.mealAIEndpointURLString
            notificationSettings = store.preferences.notificationSettings
        }
        .task {
            isNotificationAuthorized = await NotificationService.isAuthorized()
        }
    }

    // MARK: プレミアム

    private var premiumPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                IconSeat(systemName: premium.isPremium ? "checkmark.seal.fill" : "sparkles", color: FF.accent, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FitForge プレミアム")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FF.textPrimary)
                    Text(premiumStatusText)
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if premium.isPremium {
                Button("サブスクリプションを管理") {
                    isManagingSubscription = true
                }
                .buttonStyle(FFSecondaryButtonStyle())
            } else {
                Button(trialButtonTitle) {
                    isPaywallPresented = true
                }
                .buttonStyle(FFPrimaryButtonStyle())
            }
        }
        .panelStyle()
    }

    private var trialButtonTitle: String {
        if let product = premium.product(for: .yearly) ?? premium.products.first,
           let trial = premium.freeTrialText(for: product) {
            return "\(trial)無料で試す"
        }
        return "プレミアムについて見る"
    }

    private var premiumStatusText: String {
        guard premium.isPremium else { return "長期の分析や次回の重量の提案が使えます" }
        let plan = premium.activePlan == .yearly ? "年額プラン" : "月額プラン"
        if premium.isInTrial { return "\(plan)・無料お試し中" }
        return "\(plan)をご利用中"
    }

    // MARK: 通知

    private var notificationPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "通知", subtitle: "内容は固定文です。記録の数値は通知には含まれません")

            if !isNotificationAuthorized {
                Label("通知が許可されていません。iPhoneの設定 > 通知 から許可してください", systemImage: "exclamationmark.triangle")
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.over)
            }

            Toggle("夕食前のリマインド", isOn: $notificationSettings.dinnerReminderEnabled)
                .tint(FF.accent)
            if notificationSettings.dinnerReminderEnabled {
                timeRow(hour: $notificationSettings.dinnerReminderHour, minute: $notificationSettings.dinnerReminderMinute)
            }

            Divider()

            Toggle("週次ふりかえりの通知", isOn: $notificationSettings.weeklyReviewReminderEnabled)
                .tint(FF.accent)
            if notificationSettings.weeklyReviewReminderEnabled {
                FFSegmentedPicker(
                    options: Array(1...7),
                    label: { ["日", "月", "火", "水", "木", "金", "土"][$0 - 1] },
                    selection: $notificationSettings.weeklyReviewWeekday,
                    tint: FF.accent
                )
                timeRow(hour: $notificationSettings.weeklyReviewHour, minute: $notificationSettings.weeklyReviewMinute)
            }

            Button("通知の設定を保存") {
                Task {
                    if notificationSettings.dinnerReminderEnabled || notificationSettings.weeklyReviewReminderEnabled {
                        isNotificationAuthorized = await NotificationService.requestAuthorization()
                    }
                    store.updateNotificationSettings(notificationSettings)
                }
            }
            .buttonStyle(FFSecondaryButtonStyle())
        }
        .panelStyle()
    }

    private func timeRow(hour: Binding<Int>, minute: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            FFStepperRow(
                label: "時刻",
                valueText: String(format: "%d:%02d", hour.wrappedValue, minute.wrappedValue),
                onMinus: { hour.wrappedValue = (hour.wrappedValue + 23) % 24 },
                onPlus: { hour.wrappedValue = (hour.wrappedValue + 1) % 24 }
            )
            FFSegmentedPicker(options: [0, 15, 30, 45], label: { String(format: "%02d分", $0) }, selection: minute, tint: FF.accent)
        }
    }

    // MARK: プロフィール

    private var profilePanel: some View {
        let profile = store.preferences.bodyProfile
        let plan = store.budgetPlan

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "プロフィール", subtitle: "1日の目標摂取カロリーの計算に使います")

            profileRow("からだ", profile.map { "\($0.sex.rawValue)・\($0.age())歳・\(Int($0.heightCm))cm" } ?? "未入力")
            profileRow("運動する回数", "週 \(store.preferences.onboarding.weeklyWorkoutDays) 回")
            profileRow("目標体重", String(format: "%.1fkg（%@）", store.goal.targetWeightKg, store.goal.pace.label))
            profileRow("基礎代謝 / 目標摂取カロリー", "\(plan.basalKcal) / \(plan.budgetKcal) kcal")

            HStack(spacing: 10) {
                Button("からだの情報を変更") { isEditingBody = true }
                    .buttonStyle(FFSecondaryButtonStyle())
                Button("目標体重を変更") { isEditingGoal = true }
                    .buttonStyle(FFSecondaryButtonStyle())
            }
        }
        .panelStyle()
    }

    private func profileRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(FF.fontBody)
                .foregroundStyle(FF.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(FF.textPrimary)
        }
    }

    // MARK: 生活日

    private var lifeDayPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "1日の区切り")

            FFStepperRow(
                label: "起床時刻",
                valueText: "\(dayStartHour):\(String(format: "%02d", dayStartMinute))",
                onMinus: { dayStartHour = max(0, dayStartHour - 1) },
                onPlus: { dayStartHour = min(23, dayStartHour + 1) }
            )

            FFSegmentedPicker(
                options: [0, 15, 30, 45],
                label: { String(format: "%02d", $0) },
                selection: $dayStartMinute
            )

            Text("起床時刻に合わせて、深夜の記録を前日扱いにできます。")
                .font(FF.fontCaption)
                .foregroundStyle(FF.textSecondary)

            Button("設定を保存") {
                store.updatePreferences(
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
                    SwiftDataBridge.upsertDailySummary(
                        lifeDayStart: LifeDayService.startOfLifeDay(containing: .now, preferences: store.preferences),
                        intakeKcal: store.todayLedger?.intakeKcal ?? 0,
                        activeKcal: Int(healthKit.latestActiveEnergyKcal),
                        basalKcal: Int(healthKit.latestBasalEnergyKcal),
                        stepCount: Int(healthKit.latestStepCount),
                        preferences: store.preferences,
                        context: modelContext
                    )
                    if let bodyMassKg = healthKit.latestBodyMassKg {
                        SwiftDataBridge.replaceHealthKitBodyMetric(weightKg: bodyMassKg, date: .now, preferences: store.preferences, context: modelContext)
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

    // MARK: iCloudバックアップ

    private var backupPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "iCloudバックアップ", subtitle: "機種変更やアプリの入れ直しのあとに、同じApple IDで記録を戻せます")

            switch cloudBackup.accountState {
            case .checking:
                infoRow("icloud", "iCloudの状態を確認しています")
            case .available:
                infoRow("checkmark.icloud", lastBackupText)
            case .unavailable(let reason):
                infoRow("icloud.slash", reason)
            }

            Toggle(isOn: $cloudBackup.isAutoBackupEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("自動でバックアップ")
                        .font(FF.fontBody)
                        .foregroundStyle(FF.textPrimary)
                    Text("アプリを閉じたときに、記録が変わっていれば保存します")
                        .font(FF.fontCaption)
                        .foregroundStyle(FF.textSecondary)
                }
            }
            .tint(FF.accent)

            Button {
                Task { await cloudBackup.backupNow(store.backupSnapshot) }
            } label: {
                Label("今すぐバックアップ", systemImage: "icloud.and.arrow.up")
            }
            .buttonStyle(FFSecondaryButtonStyle())
            .disabled(cloudBackup.isWorking || cloudBackup.accountState != .available)

            Button {
                showRestoreConfirm = true
            } label: {
                Label("iCloudから復元", systemImage: "icloud.and.arrow.down")
            }
            .buttonStyle(FFSecondaryButtonStyle())
            .disabled(cloudBackup.isWorking || cloudBackup.latestBackup == nil)
            .confirmationDialog(
                "iCloudのバックアップから復元しますか？",
                isPresented: $showRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button("復元する", role: .destructive) {
                    Task { await restoreFromCloud() }
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("この端末にある今の記録は、バックアップの内容に置き換わります。")
            }

            if cloudBackup.isWorking {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }

            if let restoreResultMessage {
                Text(restoreResultMessage)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.deficit)
            } else if let error = cloudBackup.lastErrorMessage, cloudBackup.accountState == .available {
                Text(error)
                    .font(FF.fontCaption)
                    .foregroundStyle(FF.destructive)
            }
        }
        .panelStyle()
        .task {
            await cloudBackup.refreshStatus()
        }
    }

    private var lastBackupText: String {
        guard let backup = cloudBackup.latestBackup else { return "まだバックアップはありません" }
        let date = backup.savedAt.formatted(.dateTime.month().day().hour().minute())
        return "最終バックアップ：\(date)（記録\(backup.recordCount)件）"
    }

    private func restoreFromCloud() async {
        restoreResultMessage = nil
        do {
            try await cloudBackup.restoreLatest(into: store, context: modelContext)
            dayStartHour = store.preferences.dayStartHour
            dayStartMinute = store.preferences.dayStartMinute
            notificationSettings = store.preferences.notificationSettings
            restoreResultMessage = "バックアップから復元しました"
        } catch {
            cloudBackup.reportRestoreFailure(error)
        }
    }

    // MARK: データ管理

    private var dataPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "データ管理", subtitle: "記録はこの端末に保存されています。iCloudバックアップをオンにすると、iCloudにも保存されます")

            Button {
                store.loadDemoData()
                SwiftDataBridge.resetAndSeed(from: store, context: modelContext)
            } label: {
                Label("デモデータを読み込む", systemImage: "wand.and.stars")
            }
            .buttonStyle(FFSecondaryButtonStyle())

            Button {
                showEraseConfirm = true
            } label: {
                Label("記録をすべて削除", systemImage: "trash")
            }
            .buttonStyle(FFSecondaryButtonStyle(tint: FF.destructive))
            .confirmationDialog(
                "すべての記録を削除しますか？",
                isPresented: $showEraseConfirm,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    store.eraseAllRecords()
                    SwiftDataBridge.resetAndSeed(from: store, context: modelContext)
                }
                Button("やめる", role: .cancel) {}
            } message: {
                Text("食事・筋トレ・運動・体重・チェックインの記録がこの端末から消えます。iCloudにバックアップがあれば、「iCloudから復元」で戻せます。")
            }
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
            SwiftDataBridge.upsertDailySummary(
                lifeDayStart: summary.lifeDayStart,
                intakeKcal: store.ledgers.first(where: {
                    LifeDayService.isSameLifeDay($0.date, summary.lifeDayStart, preferences: store.preferences)
                })?.intakeKcal ?? 0,
                activeKcal: summary.activeKcal,
                basalKcal: summary.basalKcal,
                stepCount: summary.stepCount,
                preferences: store.preferences,
                context: modelContext
            )
        }

        try? modelContext.save()
    }
}
