import Foundation
import SwiftData

@MainActor
enum SwiftDataBridge {
    /// SwiftData から記録データを復元する（JSONが読めなかったときの予備）。
    /// 記録の正は JSON (AppStore)。SwiftData は一部の操作しか反映していないため、
    /// JSON に記録が残っているときに上書きすると、食事の時間帯の変更や目標更新時の体重などが元に戻ってしまう。
    /// そのため JSON 側に記録が1件もないときだけ SwiftData から戻す。
    static func hydrateStoreIfAvailable(_ store: AppStore, context: ModelContext) {
        let goals = (try? context.fetch(FetchDescriptor<GoalProfileEntry>())) ?? []
        guard goals.first != nil else { return }

        let storeHasRecords = !store.meals.isEmpty
            || !store.bodyMetrics.isEmpty
            || !store.strengthSets.isEmpty
            || !store.cardioSessions.isEmpty
            || !store.ledgers.isEmpty
        guard !storeHasRecords else { return }

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

        guard !(meals.isEmpty && strengthSets.isEmpty && cardioSessions.isEmpty && bodyMetrics.isEmpty && ledgers.isEmpty) else { return }

        // ゴールとオンボーディングは JSON からロードした現在の値を維持する。
        // SwiftData の GoalProfileEntry はサンプルシード時点の値が残っている可能性があるため
        // ここでは使わない。
        store.replaceAll(
            bodyMetrics: bodyMetrics,
            ledgers: ledgers,
            meals: meals,
            strengthSets: strengthSets,
            cardioSessions: cardioSessions,
            goal: store.goal,
            onboarding: store.preferences.onboarding
        )
        // 以前の同期で重なった日の台帳・体重をまとめる
        store.removeDuplicateSyncedRecords()
    }

    // MARK: ヘルスケア同期（生活日ごとに1件にそろえる）

    /// その生活日の集計を1件だけ残して更新する。なければ追加する
    static func upsertDailySummary(
        lifeDayStart: Date,
        intakeKcal: Int,
        activeKcal: Int,
        basalKcal: Int,
        stepCount: Int,
        preferences: UserPreferences,
        context: ModelContext
    ) {
        let sameDay = ((try? context.fetch(FetchDescriptor<DailyHealthSummaryEntry>())) ?? [])
            .filter { LifeDayService.isSameLifeDay($0.lifeDayStart, lifeDayStart, preferences: preferences) }

        if let entry = sameDay.first {
            entry.lifeDayStart = lifeDayStart
            entry.intakeKcal = intakeKcal
            entry.activeKcal = activeKcal
            entry.basalKcal = basalKcal
            entry.stepCount = stepCount
            entry.sourceRaw = DataSource.healthKit.rawValue
            for duplicate in sameDay.dropFirst() {
                context.delete(duplicate)
            }
        } else {
            context.insert(DailyHealthSummaryEntry(
                lifeDayStart: lifeDayStart,
                intakeKcal: intakeKcal,
                activeKcal: activeKcal,
                basalKcal: basalKcal,
                stepCount: stepCount,
                sourceRaw: DataSource.healthKit.rawValue
            ))
        }
    }

    /// ヘルスケア由来の体重を、その生活日で1件にそろえる（AppStore.applyHealthKitSummary と同じ扱い）
    static func replaceHealthKitBodyMetric(weightKg: Double, date: Date, preferences: UserPreferences, context: ModelContext) {
        let healthKitRaw = DataSource.healthKit.rawValue
        let sameDay = ((try? context.fetch(FetchDescriptor<BodyMetricEntry>(predicate: #Predicate { $0.sourceRaw == healthKitRaw }))) ?? [])
            .filter { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }
        for entry in sameDay {
            context.delete(entry)
        }
        context.insert(BodyMetricEntry(from: BodyMetric(
            date: date,
            weightKg: weightKg,
            bodyFatPercent: nil,
            waistCm: nil,
            source: .healthKit
        )))
    }

    /// 以前のバージョンで同期のたびに追加されていた、同じ生活日の集計とヘルスケア体重の重複を消す
    static func removeDuplicateSyncedEntries(preferences: UserPreferences, context: ModelContext) {
        var changed = false

        let summaries = ((try? context.fetch(FetchDescriptor<DailyHealthSummaryEntry>())) ?? [])
        let summariesByDay = Dictionary(grouping: summaries) {
            LifeDayService.startOfLifeDay(containing: $0.lifeDayStart, preferences: preferences)
        }
        for (_, entries) in summariesByDay where entries.count > 1 {
            // あとから同期した方が歩数・消費が大きいので、それを残す
            let sorted = entries.sorted { ($0.stepCount, $0.activeKcal) > ($1.stepCount, $1.activeKcal) }
            let maxIntake = entries.map(\.intakeKcal).max() ?? 0
            sorted[0].intakeKcal = maxIntake
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
            changed = true
        }

        let healthKitRaw = DataSource.healthKit.rawValue
        let healthKitMetrics = ((try? context.fetch(FetchDescriptor<BodyMetricEntry>(predicate: #Predicate { $0.sourceRaw == healthKitRaw }))) ?? [])
        let metricsByDay = Dictionary(grouping: healthKitMetrics) {
            LifeDayService.startOfLifeDay(containing: $0.date, preferences: preferences)
        }
        for (_, entries) in metricsByDay where entries.count > 1 {
            let sorted = entries.sorted { $0.date > $1.date }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
            }
            changed = true
        }

        if changed {
            try? context.save()
        }
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

    // MARK: 削除（JSON側と同期して呼ぶ）

    static func deleteMealEntry(id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<MealEntry>(predicate: #Predicate { $0.id == id })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            try? context.save()
        }
    }

    static func deleteStrengthSetEntry(id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<StrengthSetEntry>(predicate: #Predicate { $0.id == id })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            try? context.save()
        }
    }

    static func deleteCardioEntry(id: UUID, context: ModelContext) {
        let descriptor = FetchDescriptor<CardioEntry>(predicate: #Predicate { $0.id == id })
        if let entry = try? context.fetch(descriptor).first {
            context.delete(entry)
            try? context.save()
        }
    }

    /// SwiftDataを全消去してstoreの現在内容で再シードする（デモデータ投入・全削除用）
    static func resetAndSeed(from store: AppStore, context: ModelContext) {
        try? context.delete(model: MealEntry.self)
        try? context.delete(model: StrengthSetEntry.self)
        try? context.delete(model: CardioEntry.self)
        try? context.delete(model: BodyMetricEntry.self)
        try? context.delete(model: DailyHealthSummaryEntry.self)
        try? context.delete(model: GoalProfileEntry.self)
        try? context.save()
        seedIfNeeded(from: store, context: context)
    }
}
