import Foundation

enum BasalSource: Equatable {
    /// HealthKitの過去数日の基礎代謝の平均
    case healthKit
    /// 性別・年齢・身長・体重からMifflin-St Jeor式で計算
    case formula
    /// 身体情報が未入力のため体重だけで推定
    case weightOnly
}

struct BudgetPlan: Equatable {
    var basalKcal: Int
    var basalSource: BasalSource
    var activityFactor: Double
    /// 基礎代謝×活動係数の推定消費
    var maintenanceKcal: Int
    /// 1日の予算 − 推定消費。減量ならマイナス
    var dailyDeltaKcal: Int
    var budgetKcal: Int
    /// 目標ペースだと基礎代謝を下回るため、予算を基礎代謝に合わせた
    var isFlooredAtBasal: Bool
    /// 下限調整後に実際に見込める週あたりの体重変化(kg、絶対値)
    var effectiveKgPerWeek: Double
    /// 目標体重に届く見込みの日。維持目標や変化が見込めない場合はnil
    var arrivalDate: Date?
}

enum BudgetCalculator {
    static let kcalPerKgBodyFat = 7_200.0
    /// これ以内の差なら維持目標とみなす
    static let maintenanceToleranceKg = 0.1
    /// HealthKitの基礎代謝を採用するのに必要な、丸1日分のデータ日数
    static let minimumHealthKitDays = 3
    /// 毎週の自動補正が一度に動かせるkcalの上限(絶対値)。1週間分の実績で大きく振れすぎないための歯止め
    static let maxCalibrationKcal = 400

    static func mifflinStJeor(sex: BiologicalSex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        let base = 10 * weightKg + 6.25 * heightCm - 5 * Double(age)
        return base + (sex == .male ? 5 : -161)
    }

    static func activityFactor(weeklyWorkoutDays: Int) -> Double {
        switch weeklyWorkoutDays {
        case ...1: 1.2
        case 2...3: 1.375
        default: 1.55
        }
    }

    /// - Parameter recentBasalKcal: 当日を除く、丸1日分のHealthKit基礎代謝の値
    static func basal(
        weightKg: Double,
        profile: BodyProfile?,
        recentBasalKcal: [Int],
        on date: Date = .now
    ) -> (kcal: Int, source: BasalSource) {
        let measured = recentBasalKcal.filter { $0 > 0 }
        if measured.count >= minimumHealthKitDays {
            return (measured.reduce(0, +) / measured.count, .healthKit)
        }
        if let profile {
            let kcal = mifflinStJeor(sex: profile.sex, weightKg: weightKg, heightCm: profile.heightCm, age: profile.age(on: date))
            return (Int(kcal.rounded()), .formula)
        }
        return (Int(weightKg * 22), .weightOnly)
    }

    /// - Parameter calibrationKcal: 毎週の自動補正で調整された、基礎代謝×活動係数の推定消費への上乗せ分(kcal)
    static func plan(
        currentWeightKg: Double,
        targetWeightKg: Double,
        pace: WeightPace,
        weeklyWorkoutDays: Int,
        profile: BodyProfile?,
        recentBasalKcal: [Int],
        calibrationKcal: Int = 0,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> BudgetPlan {
        let basal = basal(weightKg: currentWeightKg, profile: profile, recentBasalKcal: recentBasalKcal, on: today)
        let factor = activityFactor(weeklyWorkoutDays: weeklyWorkoutDays)
        let maintenance = Double(basal.kcal) * factor + Double(calibrationKcal)
        let remainingKg = targetWeightKg - currentWeightKg

        guard abs(remainingKg) > maintenanceToleranceKg else {
            let rounded = roundToTen(maintenance)
            return BudgetPlan(
                basalKcal: basal.kcal, basalSource: basal.source, activityFactor: factor,
                maintenanceKcal: rounded, dailyDeltaKcal: 0, budgetKcal: rounded,
                isFlooredAtBasal: false, effectiveKgPerWeek: 0, arrivalDate: nil
            )
        }

        let direction: Double = remainingKg < 0 ? -1 : 1
        var delta = direction * pace.kgPerWeek * kcalPerKgBodyFat / 7
        var budget = maintenance + delta
        var floored = false

        if budget < Double(basal.kcal) {
            budget = Double(basal.kcal)
            delta = budget - maintenance
            floored = true
        }

        let effectiveKgPerWeek = abs(delta) * 7 / kcalPerKgBodyFat
        var arrival: Date?
        if effectiveKgPerWeek > 0 {
            let days = Int((abs(remainingKg) / effectiveKgPerWeek * 7).rounded(.up))
            arrival = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: today))
        }

        let roundedMaintenance = roundToTen(maintenance)
        let roundedBudget = floored ? basal.kcal : roundToTen(budget)
        return BudgetPlan(
            basalKcal: basal.kcal,
            basalSource: basal.source,
            activityFactor: factor,
            maintenanceKcal: roundedMaintenance,
            dailyDeltaKcal: roundedBudget - roundedMaintenance,
            budgetKcal: roundedBudget,
            isFlooredAtBasal: floored,
            effectiveKgPerWeek: effectiveKgPerWeek,
            arrivalDate: arrival
        )
    }

    private static func roundToTen(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}
