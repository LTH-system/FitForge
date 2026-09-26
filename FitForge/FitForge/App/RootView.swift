import SwiftUI
import SwiftData

/// fullScreenCover(item:)にString?を直接渡せないためのラッパー
private struct IdentifiedExercise: Identifiable {
    var name: String
    var id: String { name }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var cloudBackup: CloudBackupService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var router = AppRouter()
    @State private var restoreFailed = false

    var body: some View {
        content
            .task {
                await cloudBackup.refreshStatus()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    cloudBackup.backupInBackground(store.backupSnapshot)
                }
            }
            .alert(
                "iCloudにバックアップがあります",
                isPresented: Binding(
                    get: { cloudBackup.pendingRestore != nil },
                    set: { if !$0 { cloudBackup.pendingRestore = nil } }
                ),
                presenting: cloudBackup.pendingRestore
            ) { _ in
                Button("復元する") {
                    Task { await restoreFromCloud() }
                }
                Button("復元しない", role: .cancel) {
                    cloudBackup.declinePendingRestore()
                }
            } message: { info in
                Text(restoreMessage(for: info))
            }
            .alert("復元できませんでした", isPresented: $restoreFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(cloudBackup.lastErrorMessage ?? "もう一度お試しください。次に起動したときにも確認します。")
            }
    }

    private func restoreMessage(for info: CloudBackupService.BackupInfo) -> String {
        let date = info.savedAt.formatted(.dateTime.year().month().day().hour().minute())
        var text = "\(date) に保存した記録（\(info.recordCount)件）を、この端末に戻しますか？"
        if store.recordCount > 0 {
            text += "\n復元すると、この端末にある今の記録はバックアップの内容に置き換わります。"
        }
        return text
    }

    private func restoreFromCloud() async {
        do {
            try await cloudBackup.restoreLatest(into: store, context: modelContext)
        } catch {
            cloudBackup.reportRestoreFailure(error)
            restoreFailed = true
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.preferences.onboarding.isCompleted {
            TabView(selection: $router.selectedTab) {
                DashboardView()
                    .tabItem { Label("今日", systemImage: "house") }
                    .tag(AppTab.today)

                MealsView()
                    .tabItem { Label("食事", systemImage: "fork.knife") }
                    .tag(AppTab.meals)

                // 中央の＋はタブではなく記録シートを開くボタンとして扱う
                Color.clear
                    .tabItem { Label("記録", systemImage: "plus.circle.fill") }
                    .tag(AppTab.add)

                TrainingHubView()
                    .tabItem { Label("トレーニング", systemImage: "dumbbell") }
                    .tag(AppTab.training)

                NavigationStack { GoalsView() }
                    .tabItem { Label("進捗", systemImage: "chart.bar.xaxis") }
                    .tag(AppTab.progress)
            }
            .tint(FF.accent)
            .onChange(of: router.selectedTab) { oldValue, newValue in
                if newValue == .add {
                    router.selectedTab = oldValue
                    router.isQuickAddPresented = true
                }
            }
            .sheet(isPresented: $router.isQuickAddPresented) {
                QuickAddSheet()
                    .presentationDetents([.large])
            }
            .fullScreenCover(item: Binding(
                get: { router.workoutSessionExercise.map(IdentifiedExercise.init) },
                set: { router.workoutSessionExercise = $0?.name }
            )) { item in
                WorkoutSessionView(initialExercise: item.name)
            }
            .task {
                SwiftDataBridge.hydrateStoreIfAvailable(store, context: modelContext)
                SwiftDataBridge.seedIfNeeded(from: store, context: modelContext)
                store.removeDuplicateSyncedRecords()
                SwiftDataBridge.removeDuplicateSyncedEntries(preferences: store.preferences, context: modelContext)
                store.recalibrateMaintenanceIfNeeded()
                NotificationService.apply(store.preferences.notificationSettings)
            }
            .environmentObject(router)
        } else {
            OnboardingView()
        }
    }
}
