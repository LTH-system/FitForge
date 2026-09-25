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
        meals(onLifeDay: .now)
    }

    func meals(onLifeDay date: Date) -> [MealLog] {
        meals
            .filter { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }
            .sorted { $0.date < $1.date }
    }

    func nutrition(onLifeDay date: Date) -> DailyNutrition {
        DailyNutrition(
            lifeDayStart: LifeDayService.startOfLifeDay(containing: date, preferences: preferences),
            meals: meals(onLifeDay: date)
        )
    }

    /// よく記録する食事。同じ食事名の記録回数が多い順、同数なら新しい順
    func frequentMeals(limit: Int) -> [MealLog] {
        Dictionary(grouping: meals, by: \.title)
            .compactMap { _, logs -> (latest: MealLog, count: Int)? in
                guard let latest = logs.max(by: { $0.date < $1.date }) else { return nil }
                return (latest, logs.count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.latest.date > $1.latest.date }
            .prefix(limit)
            .map(\.latest)
    }

    /// 過去の食事を今の時刻でもう一度記録する
    @discardableResult
    func repeatMeal(_ meal: MealLog) -> MealLog {
        addMeal(from: MealLog(
            date: .now,
            title: meal.title,
            note: meal.note,
            estimatedKcal: meal.estimatedKcal,
            proteinG: meal.proteinG,
            fatG: meal.fatG,
            carbG: meal.carbG,
            confidence: meal.confidence,
            source: .manual
        ))
    }

    /// 食事記録のある生活日を新しい順に返す
    func recordedNutritionDays(limit: Int) -> [DailyNutrition] {
        let grouped = Dictionary(grouping: meals) {
            LifeDayService.startOfLifeDay(containing: $0.date, preferences: preferences)
        }
        return grouped
            .map { DailyNutrition(lifeDayStart: $0.key, meals: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.lifeDayStart > $1.lifeDayStart }
            .prefix(limit)
            .map { $0 }
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

    // MARK: 目標から逆算した予算

    /// 当日を除く直近14日の、HealthKitで丸1日分取れた基礎代謝
    private var recentHealthKitBasalKcal: [Int] {
        let todayStart = LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)
        guard let windowStart = Calendar.current.date(byAdding: .day, value: -14, to: todayStart) else { return [] }
        return ledgers
            .filter { $0.source == .healthKit && $0.date >= windowStart && $0.date < todayStart }
            .map(\.basalKcal)
    }

    var budgetPlan: BudgetPlan {
        budgetPlan(for: goal.pace)
    }

    func budgetPlan(for pace: WeightPace) -> BudgetPlan {
        BudgetCalculator.plan(
            currentWeightKg: latestWeight,
            targetWeightKg: goal.targetWeightKg,
            pace: pace,
            weeklyWorkoutDays: preferences.onboarding.weeklyWorkoutDays,
            profile: preferences.bodyProfile,
            recentBasalKcal: recentHealthKitBasalKcal
        )
    }

    var dailyCalorieBudget: Int {
        budgetPlan.budgetKcal
    }

    /// 保存済みの目標にも最新の予算と到着予定日を反映する（週次ふりかえり等で過去の値を参照するため）
    private func syncGoalWithBudget() {
        let plan = budgetPlan
        goal.dailyCalorieTarget = plan.budgetKcal
        if let arrival = plan.arrivalDate {
            goal.deadline = arrival
        }
    }

    /// HealthKitデータがない日の1日の総消費カロリー目安（基礎代謝×活動係数）
    var estimatedMaintenanceKcal: Int {
        budgetPlan.maintenanceKcal
    }

    /// 基礎代謝のみの推定。歩数・運動由来のカロリーは別途加算するため活動分は含めない
    private var estimatedBasalKcal: Int {
        BudgetCalculator.basal(weightKg: latestWeight, profile: preferences.bodyProfile, recentBasalKcal: []).kcal
    }

    /// 1歩あたりの推定消費カロリー係数(体重1kgあたり)。10,000歩・体重70kgでおよそ300kcal程度になる目安
    private let stepKcalPerKgPerStep = 0.0005

    /// ランニング等の手入力記録1kmあたりの推定歩数。歩数由来カロリーとの二重計上を避けるために差し引く
    private let cardioStepsPerKm = 1000.0

    private func cardioTotals(on date: Date) -> (kcal: Int, distanceKm: Double) {
        let sessions = cardioSessions.filter { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }
        return (sessions.map(\.calories).reduce(0, +), sessions.map(\.distanceKm).reduce(0, +))
    }

    /// 歩数から推定した消費カロリー。ランニング等ですでに手入力済みの距離分の歩数は除外し、二重計上を防ぐ
    private func stepsKcal(stepCount: Int, excludingRunKm: Double) -> Int {
        let runSteps = excludingRunKm * cardioStepsPerKm
        let neatSteps = max(0, Double(stepCount) - runSteps)
        return Int(neatSteps * latestWeight * stepKcalPerKgPerStep)
    }

    private func ledger(on date: Date) -> CalorieLedger? {
        ledgers.first { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }
    }

    /// その日の消費カロリー。基礎代謝(HealthKit実測 or 推定) + 歩数由来の活動カロリー + 手入力の筋トレ/有酸素記録を合算する
    func expenditureKcal(for date: Date) -> Int {
        let cardio = cardioTotals(on: date)

        guard let ledger = ledger(on: date), ledger.basalKcal > 0 || ledger.stepCount > 0 else {
            return estimatedMaintenanceKcal + cardio.kcal
        }

        let basal = ledger.basalKcal > 0 ? ledger.basalKcal : estimatedBasalKcal
        let steps = stepsKcal(stepCount: ledger.stepCount, excludingRunKm: cardio.distanceKm)
        return basal + steps + cardio.kcal
    }

    /// HealthKitの実測データがなく、体重ベースの推定値にフォールバックしているかどうか
    func isExpenditureEstimated(for date: Date) -> Bool {
        guard let ledger = ledger(on: date) else { return true }
        return ledger.basalKcal <= 0 && ledger.stepCount <= 0
    }

    func dailyBalanceKcal(for ledger: CalorieLedger) -> Int {
        ledger.intakeKcal - expenditureKcal(for: ledger.date)
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
        syncGoalWithBudget()
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

    func updateGoal(currentWeightKg: Double, targetWeightKg: Double, pace: WeightPace) {
        goal.currentWeightKg = currentWeightKg
        goal.targetWeightKg = targetWeightKg
        goal.pace = pace

        bodyMetrics.append(BodyMetric(date: .now, weightKg: currentWeightKg, bodyFatPercent: nil))
        syncGoalWithBudget()
        save()
    }

    func updatePace(_ pace: WeightPace) {
        goal.pace = pace
        syncGoalWithBudget()
        save()
    }

    func updateBodyProfile(_ profile: BodyProfile, weeklyWorkoutDays: Int) {
        preferences.bodyProfile = profile
        preferences.onboarding.weeklyWorkoutDays = weeklyWorkoutDays
        syncGoalWithBudget()
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
            stepCount: stepCount,
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

        syncGoalWithBudget()
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
                stepCount: summary.stepCount,
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
        syncGoalWithBudget()
        save()
    }

    func completeOnboarding(
        primaryGoal: PrimaryGoal,
        currentWeightKg: Double,
        targetWeightKg: Double,
        dayStartHour: Int,
        dayStartMinute: Int,
        weeklyWorkoutDays: Int,
        mealTrackingStyle: MealTrackingStyle,
        bodyProfile: BodyProfile,
        pace: WeightPace
    ) {
        goal.currentWeightKg = currentWeightKg
        goal.targetWeightKg = targetWeightKg
        goal.pace = pace
        preferences.bodyProfile = bodyProfile
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
        syncGoalWithBudget()
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
