import Foundation

enum WorkoutKind: String, CaseIterable, Identifiable, Codable {
    case strength = "筋トレ"
    case running = "ランニング"
    case hyrox = "HYROX"
    case marathon = "マラソン"

    var id: String { rawValue }
}

enum DataSource: String, Codable, CaseIterable, Identifiable {
    case manual = "手入力"
    case healthKit = "HealthKit"
    case ai = "AI推定"
    case imported = "外部連携"

    var id: String { rawValue }
}

enum PrimaryGoal: String, Codable, CaseIterable, Identifiable {
    case fatLoss = "減量"
    case muscleGain = "筋力アップ"
    case running = "ランニング"
    case hyrox = "HYROX"
    case health = "健康維持"

    var id: String { rawValue }
}

enum MealTrackingStyle: String, Codable, CaseIterable, Identifiable {
    case loose = "ざっくり"
    case standard = "普通"
    case detailed = "詳細"

    var id: String { rawValue }
}

struct OnboardingProfile: Hashable, Codable {
    var isCompleted: Bool
    var primaryGoal: PrimaryGoal
    var weeklyWorkoutDays: Int
    var mealTrackingStyle: MealTrackingStyle
    var createdAt: Date

    static let initial = OnboardingProfile(
        isCompleted: false,
        primaryGoal: .fatLoss,
        weeklyWorkoutDays: 3,
        mealTrackingStyle: .standard,
        createdAt: .now
    )
}

struct BodyMetric: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double?
    var waistCm: Double?
    var source: DataSource = .manual
}

struct CalorieLedger: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var intakeKcal: Int
    var activeKcal: Int
    var basalKcal: Int
    var source: DataSource = .manual

    var expenditureKcal: Int { activeKcal + basalKcal }
    var balanceKcal: Int { intakeKcal - expenditureKcal }
}

struct MealLog: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var title: String
    var note: String
    var estimatedKcal: Int
    var proteinG: Int
    var fatG: Int
    var carbG: Int
    var confidence: Double
    var source: DataSource = .ai
}

struct StrengthSet: Identifiable, Hashable, Codable {
    var id = UUID()
    var exercise: String
    var date: Date
    var weightKg: Double
    var reps: Int
    var sets: Int
    var rpe: Int?
    var note: String = ""
    var source: DataSource = .manual

    var estimatedOneRepMax: Double {
        weightKg * (1 + Double(reps) / 30)
    }
}

struct CardioSession: Identifiable, Hashable, Codable {
    var id = UUID()
    var kind: WorkoutKind
    var date: Date
    var distanceKm: Double
    var durationMinutes: Int
    var calories: Int
    var note: String
    var rpe: Int?
    var sessionType: String = "easy"
    var source: DataSource = .manual

    var paceText: String {
        guard distanceKm > 0 else { return "--" }
        let pace = Double(durationMinutes) / distanceKm
        let min = Int(pace)
        let sec = Int((pace - Double(min)) * 60)
        return "\(min):\(String(format: "%02d", sec))/km"
    }
}

struct GoalPlan: Hashable, Codable {
    var currentWeightKg: Double
    var targetWeightKg: Double
    var deadline: Date
    var dailyCalorieTarget: Int

    var remainingKg: Double { currentWeightKg - targetWeightKg }
}

struct UserPreferences: Hashable, Codable {
    var languageCode: String
    var dayStartHour: Int
    var dayStartMinute: Int
    var onboarding: OnboardingProfile
    var mealAIEndpointURLString: String

    static let japaneseDefault = UserPreferences(
        languageCode: "ja",
        dayStartHour: 5,
        dayStartMinute: 0,
        onboarding: .initial,
        mealAIEndpointURLString: ""
    )

    init(languageCode: String, dayStartHour: Int, dayStartMinute: Int, onboarding: OnboardingProfile, mealAIEndpointURLString: String = "") {
        self.languageCode = languageCode
        self.dayStartHour = dayStartHour
        self.dayStartMinute = dayStartMinute
        self.onboarding = onboarding
        self.mealAIEndpointURLString = mealAIEndpointURLString
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? "ja"
        dayStartHour = try container.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? 5
        dayStartMinute = try container.decodeIfPresent(Int.self, forKey: .dayStartMinute) ?? 0
        onboarding = try container.decodeIfPresent(OnboardingProfile.self, forKey: .onboarding) ?? .initial
        mealAIEndpointURLString = try container.decodeIfPresent(String.self, forKey: .mealAIEndpointURLString) ?? ""
    }
}

struct ActionSuggestion: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var detail: String
    var priority: String
}

struct QuickCheckIn: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var mealAmount: String
    var activity: String
    var condition: String
    var mood: String
}
