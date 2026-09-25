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

    /// 前日の食事をまとめて今日に複製する。時間帯は保つが、時刻は各時間帯の目安時刻にする
    @discardableResult
    func repeatYesterdayMeals() -> [MealLog] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let source = meals(onLifeDay: yesterday)
        guard !source.isEmpty else { return [] }

        let today = LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)
        return source.map { meal in
            let date = Calendar.current.date(bySettingHour: meal.period.representativeHour, minute: 0, second: 0, of: today) ?? .now
            return addMeal(from: MealLog(
                date: date,
                title: meal.title,
                note: meal.note,
                estimatedKcal: meal.estimatedKcal,
                proteinG: meal.proteinG,
                fatG: meal.fatG,
                carbG: meal.carbG,
                confidence: meal.confidence,
                source: .manual,
                period: meal.period
            ))
        }
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

    /// 1セットあたりの目安時間（セット+休憩を含む）。METs 5.0の筋トレとして消費カロリーを見積もる
    private let strengthMinutesPerSet = 3.0
    private let strengthMETs = 5.0

    private func strengthKcal(on date: Date) -> Int {
        let totalSets = strengthSets
            .filter { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }
            .map(\.sets)
            .reduce(0, +)
        let hours = Double(totalSets) * strengthMinutesPerSet / 60
        return Int(strengthMETs * latestWeight * hours)
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
        let strength = strengthKcal(on: date)

        guard let ledger = ledger(on: date), ledger.basalKcal > 0 || ledger.stepCount > 0 else {
            return estimatedMaintenanceKcal + cardio.kcal + strength
        }

        let basal = ledger.basalKcal > 0 ? ledger.basalKcal : estimatedBasalKcal
        let steps = stepsKcal(stepCount: ledger.stepCount, excludingRunKm: cardio.distanceKm)
        return basal + steps + cardio.kcal + strength
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
        upsertIntake(onLifeDay: analysis.date, byAdding: analysis.estimatedKcal)
        save()
        return analysis
    }

    /// 保存済みの食事の時間帯をあとから変更する
    func updateMealPeriod(_ meal: MealLog, to period: MealPeriod) {
        guard let index = meals.firstIndex(where: { $0.id == meal.id }) else { return }
        meals[index].period = period
        save()
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
        upsertIntake(onLifeDay: meal.date, byAdding: -meal.estimatedKcal)
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

    /// 食事の追加・削除に合わせて、その食事があった生活日の台帳の摂取カロリーを増減する
    private func upsertIntake(onLifeDay date: Date, byAdding kcal: Int) {
        if let index = ledgers.firstIndex(where: { LifeDayService.isSameLifeDay($0.date, date, preferences: preferences) }) {
            ledgers[index].intakeKcal = max(0, ledgers[index].intakeKcal + kcal)
        } else if kcal > 0 {
            // その日の台帳がなければ作る。他の日の台帳に加算してはいけない
            ledgers.append(CalorieLedger(
                date: LifeDayService.startOfLifeDay(containing: date, preferences: preferences),
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

    // MARK: 連続記録

    /// 自分で何かを記録した生活日（HealthKitから自動で入った体重は含めない）
    var recordedLifeDays: Set<Date> {
        let dates = meals.map(\.date)
            + strengthSets.map(\.date)
            + cardioSessions.map(\.date)
            + checkIns.map(\.date)
            + bodyMetrics.filter { $0.source != .healthKit }.map(\.date)
        return Set(dates.map { LifeDayService.startOfLifeDay(containing: $0, preferences: preferences) })
    }

    var currentStreak: Int {
        StreakCalculator.streak(
            recordedDays: recordedLifeDays,
            today: LifeDayService.startOfLifeDay(containing: .now, preferences: preferences)
        )
    }

    var hasLoggedWeightToday: Bool {
        bodyMetrics.contains { LifeDayService.isSameLifeDay($0.date, .now, preferences: preferences) }
    }

    // MARK: 次の一手

    func nextAction(now: Date = .now) -> NextAction {
        let remaining = dailyCalorieBudget - todayIntakeKcal
        let proteinLeft = max(0, proteinTargetG - todayPFC.protein)
        let hour = Calendar.current.component(.hour, from: now)

        if !hasLoggedWeightToday && hour < 12 {
            return NextAction(
                title: "まず体重を記録",
                detail: "朝の同じタイミングで測ると、日々の変化が見やすくなります。",
                kind: .weight
            )
        }

        if remaining < 0 {
            return NextAction(
                title: "今日は目標摂取カロリーを \(abs(remaining))kcal 超えています",
                detail: "ここからは軽めで大丈夫。1日で取り返そうとせず、週の平均で整えていきましょう。",
                kind: .rest
            )
        }

        let mealName: String
        switch hour {
        case ..<11: mealName = "朝食"
        case ..<15: mealName = "昼食"
        case ..<17: mealName = "間食"
        default: mealName = "夕食"
        }

        if hour >= 21 && proteinLeft == 0 {
            return NextAction(
                title: "今日の食事はばっちりです",
                detail: "目標摂取カロリー内でたんぱく質も目標に届きました。このまま休みましょう。",
                kind: .rest
            )
        }

        var detail = "\(mealName)は \(remaining)kcal 以内"
        if proteinLeft > 0 {
            detail += "・たんぱく質 \(min(proteinLeft, 40))g が目安です。"
            if proteinLeft >= 20 {
                detail += "サラダチキンや卵、納豆を足すと届きやすいです。"
            }
        } else {
            detail += "が目安です。たんぱく質は今日の目標に届いています。"
        }
        return NextAction(title: "\(mealName)の目安", detail: detail, kind: .meal)
    }
}
