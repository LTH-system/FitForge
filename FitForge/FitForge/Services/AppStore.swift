import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var bodyMetrics: [BodyMetric]
    @Published var ledgers: [CalorieLedger]
    @Published var meals: [MealLog]
    @Published var strengthSets: [StrengthSet]
    @Published var cardioSessions: [CardioSession]
    @Published var checkIns: [QuickCheckIn]
    @Published var goal: GoalPlan
    @Published var preferences: UserPreferences

    init() {
        if let snapshot = PersistenceService.load() {
            bodyMetrics = snapshot.bodyMetrics
            ledgers = snapshot.ledgers
            meals = snapshot.meals
            strengthSets = snapshot.strengthSets
            cardioSessions = snapshot.cardioSessions
            checkIns = snapshot.checkIns
            goal = snapshot.goal
            preferences = snapshot.preferences
        } else {
            // 新規ユーザーはゼロから開始する。デモデータは設定画面から明示的に投入する。
            bodyMetrics = []
            ledgers = []
            meals = []
            strengthSets = []
            cardioSessions = []
            checkIns = []
            goal = AppStore.defaultGoal
            preferences = .japaneseDefault
        }
    }

    private var snapshot: AppSnapshot {
        AppSnapshot(
            bodyMetrics: bodyMetrics,
            ledgers: ledgers,
            meals: meals,
            strengthSets: strengthSets,
            cardioSessions: cardioSessions,
            checkIns: checkIns,
            goal: goal,
            preferences: preferences
        )
    }

    func save() {
        PersistenceService.save(snapshot)
    }

    func replaceAll(
        bodyMetrics: [BodyMetric],
        ledgers: [CalorieLedger],
        meals: [MealLog],
        strengthSets: [StrengthSet],
        cardioSessions: [CardioSession],
        goal: GoalPlan,
        onboarding: OnboardingProfile
    ) {
        self.bodyMetrics = bodyMetrics
        self.ledgers = ledgers
        self.meals = meals
        self.strengthSets = strengthSets
        self.cardioSessions = cardioSessions
        self.goal = goal
        preferences.onboarding = onboarding
        save()
    }

    static let defaultGoal = GoalPlan(
        currentWeightKg: 78.4,
        targetWeightKg: 72.0,
        deadline: Calendar.current.date(byAdding: .month, value: 4, to: .now) ?? .now,
        dailyCalorieTarget: 2150
    )

    var todayLedger: CalorieLedger? {
        ledgers
            .filter { LifeDayService.isSameLifeDay($0.date, .now, preferences: preferences) }
            .sorted { $0.date > $1.date }
            .first
    }

    // MARK: 今日のサマリー（食事記録を正とする）

    var todayMeals: [MealLog] {
        meals.filter { LifeDayService.isSameLifeDay($0.date, .now, preferences: preferences) }
    }

    var todayIntakeKcal: Int {
        todayMeals.map(\.estimatedKcal).reduce(0, +)
    }

    var todayPFC: (protein: Int, fat: Int, carb: Int) {
        (
            todayMeals.map(\.proteinG).reduce(0, +),
            todayMeals.map(\.fatG).reduce(0, +),
            todayMeals.map(\.carbG).reduce(0, +)
        )
    }

    /// タンパク質の1日目標(g)。体重×1.6gの目安
    var proteinTargetG: Int {
        max(60, Int(latestWeight * 1.6))
    }

    /// 体重から推定した1日の総消費カロリー目安。HealthKitデータがない日のフォールバック
    var estimatedMaintenanceKcal: Int {
        Int(latestWeight * 33)
    }

    /// 消費実測がない日は推定維持カロリーで収支を出す
    func dailyBalanceKcal(for ledger: CalorieLedger) -> Int {
        let expenditure = ledger.expenditureKcal > 0 ? ledger.expenditureKcal : estimatedMaintenanceKcal
        return ledger.intakeKcal - expenditure
    }

    var latestWeight: Double {
        bodyMetrics.sorted { $0.date > $1.date }.first?.weightKg ?? goal.currentWeightKg
    }

    var sevenDayBalance: Int {
        let interval = LifeDayService.recentLifeDayInterval(days: 7, preferences: preferences)
        return ledgers.filter { interval.contains($0.date) }.map { dailyBalanceKcal(for: $0) }.reduce(0, +)
    }

    var thirtyDayBalance: Int {
        let interval = LifeDayService.recentLifeDayInterval(days: 30, preferences: preferences)
        return ledgers.filter { interval.contains($0.date) }.map { dailyBalanceKcal(for: $0) }.reduce(0, +)
    }

    func predictedWeightDeltaKg(from calorieBalance: Int) -> Double {
        Double(calorieBalance) / 7_200
    }

    func actualWeightDeltaKg(days: Int) -> Double {
        let sorted = bodyMetrics.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return 0 }
        let interval = LifeDayService.recentLifeDayInterval(days: days, endingAt: latest.date, preferences: preferences)
        let startDate = interval.start
        let start = sorted.first { $0.date >= startDate } ?? sorted.first ?? latest
        return latest.weightKg - start.weightKg
    }

    @discardableResult
    func addMeal(from analysis: MealLog) -> MealLog {
        meals.insert(analysis, at: 0)
        upsertTodayIntake(byAdding: analysis.estimatedKcal)
        save()
        return analysis
    }

    @discardableResult
    func addStrengthSet(exercise: String, weightKg: Double, reps: Int, sets: Int, rpe: Int?, note: String) -> StrengthSet {
        let entry = StrengthSet(
            exercise: exercise,
            date: .now,
            weightKg: weightKg,
            reps: reps,
            sets: sets,
            rpe: rpe,
            note: note
        )
        strengthSets.append(entry)
        save()
        return entry
    }

    @discardableResult
    func addCardioSession(kind: WorkoutKind, distanceKm: Double, durationMinutes: Int, calories: Int, note: String, rpe: Int?, sessionType: String) -> CardioSession {
        let session = CardioSession(
            kind: kind,
            date: .now,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            calories: calories,
            note: note,
            rpe: rpe,
            sessionType: sessionType
        )
        cardioSessions.insert(session, at: 0)
        save()
        return session
    }

    // MARK: 削除

    func deleteMeal(_ meal: MealLog) {
        meals.removeAll { $0.id == meal.id }
        if let index = ledgers.firstIndex(where: { LifeDayService.isSameLifeDay($0.date, meal.date, preferences: preferences) }) {
            ledgers[index].intakeKcal = max(0, ledgers[index].intakeKcal - meal.estimatedKcal)
        }
        save()
    }

    func deleteStrengthSet(_ set: StrengthSet) {
        strengthSets.removeAll { $0.id == set.id }
        save()
    }

    func deleteCardioSession(_ session: CardioSession) {
        cardioSessions.removeAll { $0.id == session.id }
        save()
    }

    // MARK: 体重クイック記録

    func logWeight(_ kg: Double) {
        bodyMetrics.append(BodyMetric(date: .now, weightKg: kg, bodyFatPercent: nil))
        save()
    }

    // MARK: 筋トレ支援

    /// 指定種目の最新記録。「前回何kgだったか」をジムで見るための核
    func latestSet(for exercise: String) -> StrengthSet? {
        strengthSets.filter { $0.exercise == exercise }.max { $0.date < $1.date }
    }

    /// 指定種目の自己ベスト重量
    func personalBestWeight(for exercise: String) -> Double? {
        strengthSets.filter { $0.exercise == exercise }.map(\.weightKg).max()
    }

    // MARK: デモデータ / 全削除

    func loadDemoData() {
        bodyMetrics = SampleData.bodyMetrics
        ledgers = SampleData.ledgers
        meals = SampleData.meals
        strengthSets = SampleData.strengthSets
        cardioSessions = SampleData.cardioSessions
        checkIns = SampleData.checkIns
        save()
    }

    func eraseAllRecords() {
        bodyMetrics = []
        ledgers = []
        meals = []
        strengthSets = []
        cardioSessions = []
        checkIns = []
        save()
    }

    func updateGoal(currentWeightKg: Double, targetWeightKg: Double, dailyCalorieTarget: Int) {
        goal.currentWeightKg = currentWeightKg
        goal.targetWeightKg = targetWeightKg
        goal.dailyCalorieTarget = dailyCalorieTarget

        bodyMetrics.append(BodyMetric(date: .now, weightKg: currentWeightKg, bodyFatPercent: nil))
        save()
    }

    func addCheckIn(mealAmount: String, activity: String, condition: String, mood: String) {
        checkIns.insert(QuickCheckIn(
            date: .now,
            mealAmount: mealAmount,
            activity: activity,
            condition: condition,
            mood: mood
        ), at: 0)
        save()
    }

    private func upsertTodayIntake(byAdding kcal: Int) {
        if let index = ledgers.firstIndex(where: { LifeDayService.isSameLifeDay($0.date, .now, preferences: preferences) }) {
            ledgers[index].intakeKcal = max(0, ledgers[index].intakeKcal + kcal)
        } else if kcal > 0 {
            // 今日の台帳がなければ作る。他の日の台帳に加算してはいけない
            ledgers.append(CalorieLedger(
                date: LifeDayService.startOfLifeDay(containing: .now, preferences: preferences),
                intakeKcal: kcal,
                activeKcal: 0,
                basalKcal: 0
            ))
            ledgers.sort { $0.date < $1.date }
        }
    }

    func updatePreferences(languageCode: String, dayStartHour: Int, dayStartMinute: Int) {
        preferences.languageCode = languageCode
        preferences.dayStartHour = dayStartHour
        preferences.dayStartMinute = dayStartMinute
        save()
    }

    func updateMealAIEndpoint(_ endpointURLString: String) {
        preferences.mealAIEndpointURLString = endpointURLString
        save()
    }

    func applyHealthKitSummary(stepCount: Int, activeKcal: Int, basalKcal: Int, bodyMassKg: Double?) {
        let today = LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)
        let ledger = CalorieLedger(
            date: today,
            intakeKcal: todayLedger?.intakeKcal ?? 0,
            activeKcal: activeKcal,
            basalKcal: basalKcal,
            source: .healthKit
        )

        if let index = ledgers.firstIndex(where: { LifeDayService.isSameLifeDay($0.date, today, preferences: preferences) }) {
            ledgers[index] = ledger
        } else {
            ledgers.append(ledger)
        }

        if let bodyMassKg {
            bodyMetrics.append(BodyMetric(
                date: .now,
                weightKg: bodyMassKg,
                bodyFatPercent: nil,
                waistCm: nil,
                source: .healthKit
            ))
            goal.currentWeightKg = bodyMassKg
        }

        if checkIns.first(where: { LifeDayService.isSameLifeDay($0.date, today, preferences: preferences) }) == nil {
            checkIns.insert(QuickCheckIn(
                date: .now,
                mealAmount: "未入力",
                activity: stepCount >= 8_000 ? "やった" : "少しやった",
                condition: "普通",
                mood: "普通"
            ), at: 0)
        }

        save()
    }

    func applyHealthKitDailySummaries(_ summaries: [HealthKitDailySummary]) {
        for summary in summaries {
            let existingIntake = ledgers.first(where: {
                LifeDayService.isSameLifeDay($0.date, summary.lifeDayStart, preferences: preferences)
            })?.intakeKcal ?? 0

            let ledger = CalorieLedger(
                date: summary.lifeDayStart,
                intakeKcal: existingIntake,
                activeKcal: summary.activeKcal,
                basalKcal: summary.basalKcal,
                source: .healthKit
            )

            if let index = ledgers.firstIndex(where: {
                LifeDayService.isSameLifeDay($0.date, summary.lifeDayStart, preferences: preferences)
            }) {
                ledgers[index] = ledger
            } else {
                ledgers.append(ledger)
            }
        }

        ledgers.sort { $0.date < $1.date }
        save()
    }

    func completeOnboarding(
        primaryGoal: PrimaryGoal,
        currentWeightKg: Double,
        targetWeightKg: Double,
        dayStartHour: Int,
        dayStartMinute: Int,
        weeklyWorkoutDays: Int,
        mealTrackingStyle: MealTrackingStyle
    ) {
        goal.currentWeightKg = currentWeightKg
        goal.targetWeightKg = targetWeightKg
        preferences.dayStartHour = dayStartHour
        preferences.dayStartMinute = dayStartMinute
        preferences.onboarding = OnboardingProfile(
            isCompleted: true,
            primaryGoal: primaryGoal,
            weeklyWorkoutDays: weeklyWorkoutDays,
            mealTrackingStyle: mealTrackingStyle,
            createdAt: .now
        )
        bodyMetrics.append(BodyMetric(date: .now, weightKg: currentWeightKg, bodyFatPercent: nil))
        save()
    }

    func suggestions() -> [ActionSuggestion] {
        var items: [ActionSuggestion] = []

        items.append(primaryGoalSuggestion())

        // 収支コメントは記録がある場合のみ（初日に「収支ゼロで良好」と出すのは不自然）
        if !ledgers.isEmpty {
            if sevenDayBalance > 0 {
                items.append(ActionSuggestion(
                    title: "今週は収支がプラス気味",
                    detail: "週次で約 \(sevenDayBalance) kcal（推定込み）。夕食の脂質を少し抑えるか、有酸素を2回足すと目標ペースに戻しやすいです。",
                    priority: "高"
                ))
            } else {
                items.append(ActionSuggestion(
                    title: "減量ペースは良好",
                    detail: "週次で約 \(abs(sevenDayBalance)) kcal の赤字（推定込み）。筋トレ重量が落ちない範囲でこのペースを維持しましょう。",
                    priority: "中"
                ))
            }
        }

        if let candidate = strengthSets.filter({ $0.reps >= 8 }).max(by: { $0.date < $1.date }) {
            items.append(ActionSuggestion(
                title: "\(candidate.exercise) 増量候補",
                detail: "\(candidate.weightKg.formatted())kg x \(candidate.reps)回を達成。次回は +2.5kg で6回以上を狙うタイミングです。",
                priority: "中"
            ))
        }

        items.append(ActionSuggestion(
            title: "HealthKit連携",
            detail: "体重、歩数、アクティブカロリー、ワークアウトをiOSヘルスケアから同期できる設計にしています。",
            priority: "設定"
        ))

        return items
    }

    private func primaryGoalSuggestion() -> ActionSuggestion {
        switch preferences.onboarding.primaryGoal {
        case .fatLoss:
            return ActionSuggestion(
                title: "今日は収支を軽く整える日",
                detail: "食事は\(preferences.onboarding.mealTrackingStyle.rawValue)記録でOK。歩数か軽い有酸素を少し足すと、減量ペースを作りやすいです。",
                priority: "今日"
            )
        case .muscleGain:
            return ActionSuggestion(
                title: "主要種目を1つ伸ばす",
                detail: "前回の重量か回数を少しだけ上回ることを狙いましょう。無理な日は同重量でフォーム優先です。",
                priority: "今日"
            )
        case .running:
            return ActionSuggestion(
                title: "ランは目的を決めて記録",
                detail: "easy、tempo、longなどタイプを残すと、週次の走行量と疲労を見やすくなります。",
                priority: "今日"
            )
        case .hyrox:
            return ActionSuggestion(
                title: "ランとステーションの弱点を残す",
                detail: "HYROXはタイムだけでなく、失速した種目やRPEをメモすると次の伸びしろが見つかります。",
                priority: "今日"
            )
        case .health:
            return ActionSuggestion(
                title: "今日はここまででOK",
                detail: "30秒チェックインだけでも十分です。休む日も記録に入れて、週単位で見ていきましょう。",
                priority: "今日"
            )
        }
    }
}
