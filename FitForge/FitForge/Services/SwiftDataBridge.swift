import Foundation
import SwiftData

@MainActor
enum SwiftDataBridge {
    /// SwiftData から記録データを復元する。
    /// ゴールとオンボーディングは JSON (AppStore) を正とする。
    /// SwiftData の GoalProfileEntry が初回シード時のサンプルデータのまま残っていても
    /// ユーザーが完了したオンボーディング状態やゴールを上書きしない。
    static func hydrateStoreIfAvailable(_ store: AppStore, context: ModelContext) {
        let goals = (try? context.fetch(FetchDescriptor<GoalProfileEntry>())) ?? []
        guard goals.first != nil else { return }

        let meals = ((try? context.fetch(FetchDescriptor<MealEntry>())) ?? [])
            .map(\.mealLog)
            .sorted { $0.date > $1.date }
        let strengthSets = ((try? context.fetch(FetchDescriptor<StrengthSetEntry>())) ?? [])
            .map(\.strengthSet)
            .sorted { $0.date < $1.date }
        let cardioSessions = ((try? context.fetch(FetchDescriptor<CardioEntry>())) ?? [])
            .map(\.cardioSession)
            .sorted { $0.date > $1.date }
        let bodyMetrics = ((try? context.fetch(FetchDescriptor<BodyMetricEntry>())) ?? [])
            .map(\.bodyMetric)
            .sorted { $0.date < $1.date }
        let ledgers = ((try? context.fetch(FetchDescriptor<DailyHealthSummaryEntry>())) ?? [])
            .map(\.calorieLedger)
            .sorted { $0.date < $1.date }

        // ゴールとオンボーディングは JSON からロードした現在の値を維持する。
        // SwiftData の GoalProfileEntry はサンプルシード時点の値が残っている可能性があるため
        // ここでは使わない。
        store.replaceAll(
            bodyMetrics: bodyMetrics.isEmpty ? store.bodyMetrics : bodyMetrics,
            ledgers: ledgers.isEmpty ? store.ledgers : ledgers,
            meals: meals.isEmpty ? store.meals : meals,
            strengthSets: strengthSets.isEmpty ? store.strengthSets : strengthSets,
            cardioSessions: cardioSessions.isEmpty ? store.cardioSessions : cardioSessions,
            goal: store.goal,
            onboarding: store.preferences.onboarding
        )
    }

    static func seedIfNeeded(from store: AppStore, context: ModelContext) {
        let descriptor = FetchDescriptor<GoalProfileEntry>()
        let existingGoals = (try? context.fetch(descriptor)) ?? []
        guard existingGoals.isEmpty else { return }

        for meal in store.meals {
            context.insert(MealEntry(from: meal))
        }

        for set in store.strengthSets {
            context.insert(StrengthSetEntry(from: set))
        }

        for session in store.cardioSessions {
            context.insert(CardioEntry(from: session))
        }

        for metric in store.bodyMetrics {
            context.insert(BodyMetricEntry(from: metric))
        }

        context.insert(GoalProfileEntry(goal: store.goal, onboarding: store.preferences.onboarding))
        try? context.save()
    }
}
