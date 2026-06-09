import Foundation

enum SampleData {
    static let goal = AppStore.defaultGoal
    static let preferences = UserPreferences.japaneseDefault

    static let bodyMetrics: [BodyMetric] = {
        (0..<42).map { offset -> BodyMetric in
            let daysBack = -41 + offset
            let date = Calendar.current.date(byAdding: .day, value: daysBack, to: .now) ?? .now
            let weightKg: Double = 79.6 - Double(offset) * 0.045 + Double(offset % 5) * 0.08
            let bodyFat: Double = 22.4 - Double(offset) * 0.025
            let waist: Double = 88.0 - Double(offset) * 0.04
            return BodyMetric(date: date, weightKg: weightKg, bodyFatPercent: bodyFat, waistCm: waist)
        }
    }()

    static let ledgers: [CalorieLedger] = {
        (0..<42).map { offset -> CalorieLedger in
            let daysBack = -41 + offset
            let date = Calendar.current.date(byAdding: .day, value: daysBack, to: .now) ?? .now
            let intake = 2050 + (offset % 6) * 80
            let active = 420 + (offset % 4) * 55
            return CalorieLedger(date: date, intakeKcal: intake, activeKcal: active, basalKcal: 1680)
        }
    }()

    static let meals: [MealLog] = [
        MealLog(date: .now, title: "鶏むね定食", note: "鶏むね、玄米、味噌汁",
                estimatedKcal: 620, proteinG: 48, fatG: 14, carbG: 74, confidence: 0.82),
        MealLog(date: .now.addingTimeInterval(-18_000), title: "プロテインとバナナ", note: "トレ後",
                estimatedKcal: 260, proteinG: 26, fatG: 3, carbG: 34, confidence: 0.9)
    ]

    static let strengthSets: [StrengthSet] = [
        StrengthSet(exercise: "ベンチプレス", date: .now.addingTimeInterval(-86_400 * 14),
                    weightKg: 70, reps: 6, sets: 4, rpe: 8, note: "少し余裕あり"),
        StrengthSet(exercise: "ベンチプレス", date: .now.addingTimeInterval(-86_400 * 7),
                    weightKg: 70, reps: 8, sets: 4, rpe: 8, note: "次回増量候補"),
        StrengthSet(exercise: "スクワット", date: .now.addingTimeInterval(-86_400 * 8),
                    weightKg: 100, reps: 5, sets: 5, rpe: 9, note: "フォーム優先"),
        StrengthSet(exercise: "デッドリフト", date: .now.addingTimeInterval(-86_400 * 5),
                    weightKg: 125, reps: 4, sets: 3, rpe: 8, note: "背中は問題なし")
    ]

    static let cardioSessions: [CardioSession] = [
        CardioSession(kind: .running, date: .now.addingTimeInterval(-86_400 * 2),
                      distanceKm: 8.2, durationMinutes: 46, calories: 620,
                      note: "Eペース", rpe: 5, sessionType: "easy"),
        CardioSession(kind: .hyrox, date: .now.addingTimeInterval(-86_400 * 5),
                      distanceKm: 8.0, durationMinutes: 74, calories: 920,
                      note: "壁球で失速", rpe: 8, sessionType: "simulation"),
        CardioSession(kind: .marathon, date: .now.addingTimeInterval(-86_400 * 13),
                      distanceKm: 21.1, durationMinutes: 118, calories: 1420,
                      note: "ハーフ試走", rpe: 7, sessionType: "long")
    ]

    static let checkIns: [QuickCheckIn] = [
        QuickCheckIn(date: .now, mealAmount: "普通", activity: "少しやった", condition: "普通", mood: "前向き")
    ]
}
