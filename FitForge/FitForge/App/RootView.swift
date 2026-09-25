import SwiftUI
import SwiftData

/// fullScreenCover(item:)にString?を直接渡せないためのラッパー
private struct IdentifiedExercise: Identifiable {
    var name: String
    var id: String { name }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var router = AppRouter()

    var body: some View {
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
            }
            .environmentObject(router)
        } else {
            OnboardingView()
        }
    }
}
