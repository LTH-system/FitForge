import Foundation

struct AppSnapshot: Codable {
    var bodyMetrics: [BodyMetric]
    var ledgers: [CalorieLedger]
    var meals: [MealLog]
    var strengthSets: [StrengthSet]
    var cardioSessions: [CardioSession]
    var checkIns: [QuickCheckIn]
    var goal: GoalPlan
    var preferences: UserPreferences

    init(
        bodyMetrics: [BodyMetric],
        ledgers: [CalorieLedger],
        meals: [MealLog],
        strengthSets: [StrengthSet],
        cardioSessions: [CardioSession],
        checkIns: [QuickCheckIn],
        goal: GoalPlan,
        preferences: UserPreferences
    ) {
        self.bodyMetrics = bodyMetrics
        self.ledgers = ledgers
        self.meals = meals
        self.strengthSets = strengthSets
        self.cardioSessions = cardioSessions
        self.checkIns = checkIns
        self.goal = goal
        self.preferences = preferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bodyMetrics = try container.decode([BodyMetric].self, forKey: .bodyMetrics)
        ledgers = try container.decode([CalorieLedger].self, forKey: .ledgers)
        meals = try container.decode([MealLog].self, forKey: .meals)
        strengthSets = try container.decode([StrengthSet].self, forKey: .strengthSets)
        cardioSessions = try container.decode([CardioSession].self, forKey: .cardioSessions)
        checkIns = try container.decodeIfPresent([QuickCheckIn].self, forKey: .checkIns) ?? []
        goal = try container.decode(GoalPlan.self, forKey: .goal)
        preferences = try container.decodeIfPresent(UserPreferences.self, forKey: .preferences) ?? .japaneseDefault
    }
}

enum PersistenceService {
    private static var fileURL: URL {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("fitforge_snapshot.json")
    }

    static func load() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppSnapshot.self, from: data)
    }

    static func save(_ snapshot: AppSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
