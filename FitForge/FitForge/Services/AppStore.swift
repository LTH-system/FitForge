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
            bodyMetrics = SampleData.bodyMetrics
            ledgers = SampleData.ledgers
            meals = SampleData.meals
            strengthSets = SampleData.strengthSets
            cardioSessions = SampleData.cardioSessions
            checkIns = SampleData.checkIns
            goal = SampleData.goal
            preferences = SampleData.preferences
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
            ?? ledgers.sorted { $0.date > $1.date }.first
    }

    var latestWeight: Double {
        bodyMetrics.sorted { $0.date > $1.date }.first?.weightKg ?? goal.currentWeightKg
    }

    var sevenDayBalance: Int {
        let interval = LifeDayService.recentLifeDayInterval(days: 7, preferences: preferences)
        return ledgers.filter { interval.contains($0.date) }.map(\.balanceKcal).reduce(0, +)
    }

    var thirtyDayBalance: Int {
        let interval = LifeDayService.recentLifeDayInterval(days: 30, preferences: preferences)
        return ledgers.filter { interval.contains($0.date) }.map(\.balanceKcal).reduce(0, +)
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
        guard let index = ledgers.indices.last(where: { LifeDayService.isSameLifeDay(ledgers[$0].date, .now, preferences: preferences) }) ?? ledgers.indices.last else { return }
        ledgers[index].intakeKcal += kcal
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

        if sevenDayBalance > 0 {
            items.append(ActionSuggestion(
                title: "今週は収支がプラス",
                detail: "週次で \(sevenDayBalance) kcal。夕食の脂質を少し抑えるか、有酸素を2回足すと目標ペースに戻しやすいです。",
                priority: "高"
            ))
        } else {
            items.append(ActionSuggestion(
                title: "減量ペースは良好",
                detail: "週次で \(abs(sevenDayBalance)) kcal の赤字。筋トレ重量が落ちない範囲でこのペースを維持しましょう。",
                priority: "中"
            ))
        }

        if let bench = strengthSets.filter({ $0.exercise == "ベンチプレス" }).max(by: { $0.date < $1.date }), bench.reps >= 8 {
            items.append(ActionSuggestion(
                title: "ベンチプレス増量候補",
                detail: "\(Int(bench.weightKg))kg x \(bench.reps)回を達成。次回は +2.5kg で6回以上を狙うタイミングです。",
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
