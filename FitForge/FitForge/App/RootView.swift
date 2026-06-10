import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if store.preferences.onboarding.isCompleted {
            TabView {
                DashboardView()
                    .tabItem { Label("今日", systemImage: "gauge.with.dots.needle.67percent") }

                MealsView()
                    .tabItem { Label("食事", systemImage: "fork.knife") }

                TrainingView()
                    .tabItem { Label("筋トレ", systemImage: "dumbbell") }

                CardioView()
                    .tabItem { Label("運動", systemImage: "figure.run") }

                GoalsView()
                    .tabItem { Label("目標", systemImage: "target") }
            }
            .tint(FF.accent)
            .task {
                SwiftDataBridge.hydrateStoreIfAvailable(store, context: modelContext)
                SwiftDataBridge.seedIfNeeded(from: store, context: modelContext)
            }
        } else {
            OnboardingView()
        }
    }
}
