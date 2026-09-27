import SwiftUI
import SwiftData

@main
struct FitForgeApp: App {
    @StateObject private var store = AppStore()
    @StateObject private var healthKit = HealthKitService()
    @StateObject private var cloudBackup = CloudBackupService()
    @StateObject private var premium = PremiumStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(healthKit)
                .environmentObject(cloudBackup)
                .environmentObject(premium)
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
