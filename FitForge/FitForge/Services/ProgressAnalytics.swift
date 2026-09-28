import Foundation

// MARK: - 長期の推移（プレミアム）

enum TrendRange: String, CaseIterable, Identifiable {
    case fourWeeks = "4週"
    case threeMonths = "3ヶ月"
    case sixMonths = "6ヶ月"
    case oneYear = "1年"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .fourWeeks: 28
        case .threeMonths: 91
        case .sixMonths: 182
        case .oneYear: 365
        }
    }

    /// 1年表示は月ごと、それ以外は週ごとにまとめる
    var groupsByMonth: Bool { self == .oneYear }
}

struct WeightPoint: Identifiable, Hashable {
    var date: Date
    var weightKg: Double
    var id: Date { date }
}

/// 週または月ごとの平均。記録のある日だけで平均する
struct TrendPeriodSummary: Identifiable, Hashable {
    var start: Date
    var loggedDays: Int
    var averageIntakeKcal: Int
    var averageExpenditureKcal: Int
    var averageWeightKg: Double?

    var id: Date { start }
    var averageBalanceKcal: Int { averageIntakeKcal - averageExpenditureKcal }
}

struct TrendReport {
    var range: TrendRange
    var periods: [TrendPeriodSummary]
    var weightPoints: [WeightPoint]
    /// 食事を記録した日数
    var loggedDays: Int
    var totalDays: Int
    /// 記録した日の1日あたりの平均収支
    var averageBalanceKcal: Int?
    /// 平均収支が期間中ずっと続いたとした場合の体重の変化（理論値）
    var predictedDeltaKg: Double?
    /// 期間の最初と最後の体重の差（実測）
    var actualDeltaKg: Double?

    /// 平均から推計するのに最低限必要な記録日数
    static let minimumLoggedDays = 3
}

extension AppStore {
    func trendReport(for range: TrendRange, now: Date = .now, calendar: Calendar = .current) -> TrendReport {
        let interval = LifeDayService.recentLifeDayInterval(days: range.days, endingAt: now, preferences: preferences, calendar: calendar)

        // 食事記録を正として、生活日ごとの摂取を集計する
        let mealsByDay = Dictionary(grouping: meals.filter { interval.contains($0.date) }) {
            LifeDayService.startOfLifeDay(containing: $0.date, preferences: preferences, calendar: calendar)
        }
        let dailyIntake = mealsByDay.mapValues { $0.map(\.estimatedKcal).reduce(0, +) }.filter { $0.value > 0 }
        let dailyExpenditure = Dictionary(uniqueKeysWithValues: dailyIntake.keys.map { ($0, expenditureKcal(for: $0)) })

        // 体重は生活日ごとの平均にする（同じ日に何度か量っても1点）
        let weightsByDay = Dictionary(grouping: bodyMetrics.filter { interval.contains($0.date) }) {
            LifeDayService.startOfLifeDay(containing: $0.date, preferences: preferences, calendar: calendar)
        }
        let weightPoints = weightsByDay
            .map { WeightPoint(date: $0.key, weightKg: $0.value.map(\.weightKg).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }

        func periodStart(_ day: Date) -> Date {
            let component: Calendar.Component = range.groupsByMonth ? .month : .weekOfYear
            return calendar.dateInterval(of: component, for: day)?.start ?? day
        }

        let periodKeys = Set(dailyIntake.keys.map(periodStart)).union(weightPoints.map { periodStart($0.date) })
        let periods = periodKeys.sorted().map { start -> TrendPeriodSummary in
            let days = dailyIntake.keys.filter { periodStart($0) == start }
            let intake = days.compactMap { dailyIntake[$0] }
            let expenditure = days.compactMap { dailyExpenditure[$0] }
            let weights = weightPoints.filter { periodStart($0.date) == start }.map(\.weightKg)
            return TrendPeriodSummary(
                start: start,
                loggedDays: days.count,
                averageIntakeKcal: intake.isEmpty ? 0 : intake.reduce(0, +) / intake.count,
                averageExpenditureKcal: expenditure.isEmpty ? 0 : expenditure.reduce(0, +) / expenditure.count,
                averageWeightKg: weights.isEmpty ? nil : weights.reduce(0, +) / Double(weights.count)
            )
        }

        let balances = dailyIntake.map { day, intake in intake - (dailyExpenditure[day] ?? 0) }
        let averageBalance = balances.count >= TrendReport.minimumLoggedDays ? balances.reduce(0, +) / balances.count : nil
        let predicted = averageBalance.map { Double($0 * range.days) / BudgetCalculator.kcalPerKgBodyFat }
        let actual: Double? = {
            guard let first = weightPoints.first, let last = weightPoints.last, weightPoints.count >= 2 else { return nil }
            return last.weightKg - first.weightKg
        }()

        return TrendReport(
            range: range,
            periods: periods,
            weightPoints: weightPoints,
            loggedDays: dailyIntake.count,
            totalDays: range.days,
            averageBalanceKcal: averageBalance,
            predictedDeltaKg: predicted,
            actualDeltaKg: actual
        )
    }
}

// MARK: - 部位別のトレーニング量（プレミアム）

struct MuscleVolumeRow: Identifiable, Hashable {
    /// カタログにない自由入力の種目は nil（「その他」）
    var category: ExerciseCategory?
    var sets: Int
    var previousSets: Int
    var volumeKg: Double

    var id: String { title }
    var title: String { category?.rawValue ?? "その他" }
}

extension ExerciseCatalog {
    /// 記録された種目名からカタログの分類を引く。カタログにない名前は nil
    static func category(forExercise name: String) -> ExerciseCategory? {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        return items.first { item in
            item.nameJa.lowercased() == normalized
                || item.nameEn.lowercased() == normalized
                || item.aliasesJa.contains { $0.lowercased() == normalized }
        }?.category
    }
}

extension AppStore {
    /// 直近7日と、その前の7日の部位別セット数・ボリューム（重量×回数×セット）
    func muscleVolumeRows(now: Date = .now) -> [MuscleVolumeRow] {
        let thisWeek = LifeDayService.recentLifeDayInterval(days: 7, endingAt: now, preferences: preferences)
        let twoWeeks = LifeDayService.recentLifeDayInterval(days: 14, endingAt: now, preferences: preferences)
        let lastWeek = DateInterval(start: twoWeeks.start, end: thisWeek.start)

        var rows: [String: MuscleVolumeRow] = [:]
        for set in strengthSets {
            let inThisWeek = thisWeek.contains(set.date)
            let inLastWeek = !inThisWeek && lastWeek.contains(set.date)
            guard inThisWeek || inLastWeek else { continue }

            let category = ExerciseCatalog.category(forExercise: set.exercise)
            var row = rows[category?.rawValue ?? "その他"] ?? MuscleVolumeRow(category: category, sets: 0, previousSets: 0, volumeKg: 0)
            let setCount = max(1, set.sets)
            if inThisWeek {
                row.sets += setCount
                row.volumeKg += set.weightKg * Double(set.reps * setCount)
            } else {
                row.previousSets += setCount
            }
            rows[row.title] = row
        }

        let order = ExerciseCategory.allCases
        return rows.values.sorted { lhs, rhs in
            let l = lhs.category.flatMap { order.firstIndex(of: $0) } ?? order.count
            let r = rhs.category.flatMap { order.firstIndex(of: $0) } ?? order.count
            return l < r
        }
    }
}

// MARK: - 栄養の過不足（プレミアム）

enum NutrientStatus {
    case low
    case ok
    case high

    var label: String {
        switch self {
        case .low: "不足"
        case .ok: "目標どおり"
        case .high: "多め"
        }
    }

    init(ratio: Double) {
        if ratio < 0.8 {
            self = .low
        } else if ratio > 1.2 {
            self = .high
        } else {
            self = .ok
        }
    }
}

struct NutrientBalanceRow: Identifiable {
    var name: String
    var actual: Int
    var target: Int
    var unit: String

    var id: String { name }
    var ratio: Double { target > 0 ? Double(actual) / Double(target) : 0 }
    var status: NutrientStatus { NutrientStatus(ratio: ratio) }
}

/// 1日の目標量。たんぱく質は体重×1.6g、脂質は目標摂取カロリーの25%、炭水化物は残り
struct NutrientTargets {
    var kcal: Int
    var proteinG: Int
    var fatG: Int
    var carbG: Int

    init(kcal: Int, proteinG: Int) {
        self.kcal = kcal
        self.proteinG = proteinG
        fatG = Int((Double(kcal) * 0.25 / 9).rounded())
        carbG = max(0, (kcal - proteinG * 4 - fatG * 9) / 4)
    }
}

extension AppStore {
    var nutrientTargets: NutrientTargets {
        NutrientTargets(kcal: dailyCalorieBudget, proteinG: proteinTargetG)
    }

    func nutrientBalance(for nutrition: DailyNutrition) -> [NutrientBalanceRow] {
        nutrientBalanceRows(kcal: nutrition.kcal, protein: nutrition.proteinG, fat: nutrition.fatG, carb: nutrition.carbG)
    }

    /// 直近の食事を記録した日の平均。記録のない日は平均に含めない
    func averageNutrientBalance(days: Int, now: Date = .now) -> (rows: [NutrientBalanceRow], loggedDays: Int) {
        let interval = LifeDayService.recentLifeDayInterval(days: days, endingAt: now, preferences: preferences)
        let logged = Dictionary(grouping: meals.filter { interval.contains($0.date) }) {
            LifeDayService.startOfLifeDay(containing: $0.date, preferences: preferences)
        }
        .map { DailyNutrition(lifeDayStart: $0.key, meals: $0.value) }
        .filter { $0.kcal > 0 }

        guard !logged.isEmpty else { return ([], 0) }
        let count = logged.count
        let rows = nutrientBalanceRows(
            kcal: logged.map(\.kcal).reduce(0, +) / count,
            protein: logged.map(\.proteinG).reduce(0, +) / count,
            fat: logged.map(\.fatG).reduce(0, +) / count,
            carb: logged.map(\.carbG).reduce(0, +) / count
        )
        return (rows, count)
    }

    private func nutrientBalanceRows(kcal: Int, protein: Int, fat: Int, carb: Int) -> [NutrientBalanceRow] {
        let targets = nutrientTargets
        return [
            NutrientBalanceRow(name: "カロリー", actual: kcal, target: targets.kcal, unit: "kcal"),
            NutrientBalanceRow(name: "たんぱく質", actual: protein, target: targets.proteinG, unit: "g"),
            NutrientBalanceRow(name: "脂質", actual: fat, target: targets.fatG, unit: "g"),
            NutrientBalanceRow(name: "炭水化物", actual: carb, target: targets.carbG, unit: "g")
        ]
    }
}

// MARK: - 次回の重量の提案（プレミアム）

struct ProgressionSuggestion: Hashable {
    var weightKg: Double
    var reps: Int
    var headline: String
    var reason: String
}

/// 回数が目安の上限に届いたら重量を上げる「ダブルプログレッション」で、次回の重量と回数を提案する
enum ProgressionAdvisor {
    static let repRangeLower = 8
    static let repRangeUpper = 12

    /// 指定日時より前の、直近の1日分の記録から提案する
    static func suggest(exercise: String, history: [StrengthSet], before date: Date = .now, preferences: UserPreferences) -> ProgressionSuggestion? {
        let past = history.filter { $0.exercise == exercise && $0.date < date }
        guard let latest = past.max(by: { $0.date < $1.date }) else { return nil }
        let lastSession = past.filter { LifeDayService.isSameLifeDay($0.date, latest.date, preferences: preferences) }

        guard let topWeight = lastSession.map(\.weightKg).max() else { return nil }
        let topSets = lastSession.filter { $0.weightKg == topWeight }
        let minReps = topSets.map(\.reps).min() ?? latest.reps
        let hardestRPE = topSets.compactMap(\.rpe).max()
        let weightText = "\(topWeight.formatted())kg"

        // 自重種目は回数で伸ばす
        if topWeight <= 0 {
            let add = (hardestRPE ?? 8) <= 7 ? 2 : 1
            return ProgressionSuggestion(
                weightKg: 0,
                reps: minReps + add,
                headline: "自重で \(minReps + add)回",
                reason: "前回は\(minReps)回でした。まずは各セット\(add)回ずつ増やしましょう。"
            )
        }

        if let hardestRPE, hardestRPE >= 10 {
            return ProgressionSuggestion(
                weightKg: topWeight,
                reps: minReps,
                headline: "\(weightText) × \(minReps)回",
                reason: "前回は限界に近いきつさでした。同じ重量・回数で、フォームを安定させましょう。"
            )
        }

        let increment = weightIncrement(for: exercise, currentWeight: topWeight)
        let nextWeight = topWeight + increment

        if minReps >= repRangeUpper || ((hardestRPE ?? 8) <= 7 && minReps >= repRangeLower) {
            let nextReps = repRangeLower
            return ProgressionSuggestion(
                weightKg: nextWeight,
                reps: nextReps,
                headline: "\(nextWeight.formatted())kg × \(nextReps)回",
                reason: "前回は\(weightText)で全セット\(minReps)回できました。+\(increment.formatted())kgに上げて、\(nextReps)回から積み上げ直しましょう。"
            )
        }

        let nextReps = min(repRangeUpper, minReps + 1)
        return ProgressionSuggestion(
            weightKg: topWeight,
            reps: nextReps,
            headline: "\(weightText) × \(nextReps)回",
            reason: "同じ重量で1回ずつ増やす段階です。全セット\(repRangeUpper)回できたら重量を上げます。"
        )
    }

    /// 脚・尻・背中の重い種目は5kg、軽い重量（ダンベルなど）は1kg、それ以外は2.5kg刻み
    private static func weightIncrement(for exercise: String, currentWeight: Double) -> Double {
        if currentWeight < 20 { return 1 }
        switch ExerciseCatalog.category(forExercise: exercise) {
        case .legs?, .glutes?, .back?:
            return currentWeight >= 60 ? 5 : 2.5
        default:
            return 2.5
        }
    }
}
