import Foundation
import SwiftData

@Model
final class MealEntry {
    var id: UUID
    var date: Date
    var title: String
    var note: String
    var kcal: Int
    var proteinG: Int
    var fatG: Int
    var carbG: Int
    var confidence: Double
    var sourceRaw: String

    init(from log: MealLog) {
        id = log.id
        date = log.date
        title = log.title
        note = log.note
        kcal = log.estimatedKcal
        proteinG = log.proteinG
        fatG = log.fatG
        carbG = log.carbG
        confidence = log.confidence
        sourceRaw = log.source.rawValue
    }

    var mealLog: MealLog {
        MealLog(
            id: id,
            date: date,
            title: title,
            note: note,
            estimatedKcal: kcal,
            proteinG: proteinG,
            fatG: fatG,
            carbG: carbG,
            confidence: confidence,
            source: DataSource(rawValue: sourceRaw) ?? .manual
        )
    }
}

@Model
final class StrengthSetEntry {
    var id: UUID
    var exercise: String
    var date: Date
    var weightKg: Double
    var reps: Int
    var sets: Int
    var rpe: Int?
    var note: String
    var sourceRaw: String

    init(from set: StrengthSet) {
        id = set.id
        exercise = set.exercise
        date = set.date
        weightKg = set.weightKg
        reps = set.reps
        sets = set.sets
        rpe = set.rpe
        note = set.note
        sourceRaw = set.source.rawValue
    }

    var strengthSet: StrengthSet {
        StrengthSet(
            id: id,
            exercise: exercise,
            date: date,
            weightKg: weightKg,
            reps: reps,
            sets: sets,
            rpe: rpe,
            note: note,
            source: DataSource(rawValue: sourceRaw) ?? .manual
        )
    }
}

@Model
final class CardioEntry {
    var id: UUID
    var kindRaw: String
    var date: Date
    var distanceKm: Double
    var durationMinutes: Int
    var calories: Int
    var note: String
    var rpe: Int?
    var sessionType: String
    var sourceRaw: String

    init(from session: CardioSession) {
        id = session.id
        kindRaw = session.kind.rawValue
        date = session.date
        distanceKm = session.distanceKm
        durationMinutes = session.durationMinutes
        calories = session.calories
        note = session.note
        rpe = session.rpe
        sessionType = session.sessionType
        sourceRaw = session.source.rawValue
    }

    var cardioSession: CardioSession {
        CardioSession(
            id: id,
            kind: WorkoutKind(rawValue: kindRaw) ?? .running,
            date: date,
            distanceKm: distanceKm,
            durationMinutes: durationMinutes,
            calories: calories,
            note: note,
            rpe: rpe,
            sessionType: sessionType,
            source: DataSource(rawValue: sourceRaw) ?? .manual
        )
    }
}

@Model
final class BodyMetricEntry {
    var id: UUID
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var waistCm: Double?
    var sourceRaw: String

    init(from metric: BodyMetric) {
        id = metric.id
        date = metric.date
        weightKg = metric.weightKg
        bodyFatPercent = metric.bodyFatPercent
        waistCm = metric.waistCm
        sourceRaw = metric.source.rawValue
    }

    var bodyMetric: BodyMetric {
        BodyMetric(
            id: id,
            date: date,
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent,
            waistCm: waistCm,
            source: DataSource(rawValue: sourceRaw) ?? .manual
        )
    }
}

@Model
final class DailyHealthSummaryEntry {
    var id: UUID
    var lifeDayStart: Date
    var intakeKcal: Int
    var activeKcal: Int
    var basalKcal: Int
    var stepCount: Int
    var sourceRaw: String

    init(id: UUID = UUID(), lifeDayStart: Date, intakeKcal: Int, activeKcal: Int, basalKcal: Int, stepCount: Int, sourceRaw: String) {
        self.id = id
        self.lifeDayStart = lifeDayStart
        self.intakeKcal = intakeKcal
        self.activeKcal = activeKcal
        self.basalKcal = basalKcal
        self.stepCount = stepCount
        self.sourceRaw = sourceRaw
    }

    var calorieLedger: CalorieLedger {
        CalorieLedger(
            id: id,
            date: lifeDayStart,
            intakeKcal: intakeKcal,
            activeKcal: activeKcal,
            basalKcal: basalKcal,
            source: DataSource(rawValue: sourceRaw) ?? .manual
        )
    }
}

@Model
final class GoalProfileEntry {
    var id: UUID
    var currentWeightKg: Double
    var targetWeightKg: Double
    var deadline: Date
    var dailyCalorieTarget: Int
    var primaryGoalRaw: String
    var weeklyWorkoutDays: Int
    var mealTrackingStyleRaw: String

    init(id: UUID = UUID(), goal: GoalPlan, onboarding: OnboardingProfile) {
        self.id = id
        currentWeightKg = goal.currentWeightKg
        targetWeightKg = goal.targetWeightKg
        deadline = goal.deadline
        dailyCalorieTarget = goal.dailyCalorieTarget
        primaryGoalRaw = onboarding.primaryGoal.rawValue
        weeklyWorkoutDays = onboarding.weeklyWorkoutDays
        mealTrackingStyleRaw = onboarding.mealTrackingStyle.rawValue
    }

    var goalPlan: GoalPlan {
        GoalPlan(
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            deadline: deadline,
            dailyCalorieTarget: dailyCalorieTarget
        )
    }

    var onboardingProfile: OnboardingProfile {
        OnboardingProfile(
            isCompleted: true,
            primaryGoal: PrimaryGoal(rawValue: primaryGoalRaw) ?? .fatLoss,
            weeklyWorkoutDays: weeklyWorkoutDays,
            mealTrackingStyle: MealTrackingStyle(rawValue: mealTrackingStyleRaw) ?? .standard,
            createdAt: .now
        )
    }
}
