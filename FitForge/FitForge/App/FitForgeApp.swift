import SwiftUI
import SwiftData

@main
struct FitForgeApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var healthKit = HealthKitService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(healthKit)
                .modelContainer(for: [
                    MealEntry.self,
                    StrengthSetEntry.self,
                    CardioEntry.self,
                    BodyMetricEntry.self,
                    DailyHealthSummaryEntry.self,
                    GoalProfileEntry.self
                ])
        }
    }
}
