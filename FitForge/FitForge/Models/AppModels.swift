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
    var stepCount: Int
    var source: DataSource = .manual

    var expenditureKcal: Int { activeKcal + basalKcal }
    var balanceKcal: Int { intakeKcal - expenditureKcal }

    init(id: UUID = UUID(), date: Date, intakeKcal: Int, activeKcal: Int, basalKcal: Int, stepCount: Int = 0, source: DataSource = .manual) {
        self.id = id
        self.date = date
        self.intakeKcal = intakeKcal
        self.activeKcal = activeKcal
        self.basalKcal = basalKcal
        self.stepCount = stepCount
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        intakeKcal = try container.decode(Int.self, forKey: .intakeKcal)
        activeKcal = try container.decode(Int.self, forKey: .activeKcal)
        basalKcal = try container.decode(Int.self, forKey: .basalKcal)
        stepCount = try container.decodeIfPresent(Int.self, forKey: .stepCount) ?? 0
        source = try container.decodeIfPresent(DataSource.self, forKey: .source) ?? .manual
    }
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

struct DailyNutrition: Identifiable, Hashable {
    var lifeDayStart: Date
    var meals: [MealLog]

    var id: Date { lifeDayStart }
    var kcal: Int { meals.map(\.estimatedKcal).reduce(0, +) }
    var proteinG: Int { meals.map(\.proteinG).reduce(0, +) }
    var fatG: Int { meals.map(\.fatG).reduce(0, +) }
    var carbG: Int { meals.map(\.carbG).reduce(0, +) }

    /// PFCそれぞれがエネルギーに占める割合(%)。P・Cは4kcal/g、Fは9kcal/gで換算
    var energyRatio: (protein: Int, fat: Int, carb: Int)? {
        let p = Double(proteinG * 4), f = Double(fatG * 9), c = Double(carbG * 4)
        let total = p + f + c
        guard total > 0 else { return nil }
        let protein = Int((p / total * 100).rounded())
        let fat = Int((f / total * 100).rounded())
        return (protein, fat, 100 - protein - fat)
    }
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

enum WeightPace: String, Codable, CaseIterable, Identifiable {
    case slow
    case standard
    case fast

    var id: String { rawValue }

    var kgPerWeek: Double {
        switch self {
        case .slow: 0.25
        case .standard: 0.4
        case .fast: 0.5
        }
    }

    var label: String {
        switch self {
        case .slow: "ゆっくり"
        case .standard: "標準"
        case .fast: "しっかり"
        }
    }
}

struct GoalPlan: Hashable, Codable {
    /// 目標を設定した時点の体重（道のりのスタート地点）。最新体重は AppStore.latestWeight を使う
    var currentWeightKg: Double
    var targetWeightKg: Double
    var deadline: Date
    var dailyCalorieTarget: Int
    var pace: WeightPace

    var remainingKg: Double { currentWeightKg - targetWeightKg }

    init(currentWeightKg: Double, targetWeightKg: Double, deadline: Date, dailyCalorieTarget: Int, pace: WeightPace = .standard) {
        self.currentWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.deadline = deadline
        self.dailyCalorieTarget = dailyCalorieTarget
        self.pace = pace
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentWeightKg = try container.decode(Double.self, forKey: .currentWeightKg)
        targetWeightKg = try container.decode(Double.self, forKey: .targetWeightKg)
        deadline = try container.decode(Date.self, forKey: .deadline)
        dailyCalorieTarget = try container.decode(Int.self, forKey: .dailyCalorieTarget)
        pace = try container.decodeIfPresent(WeightPace.self, forKey: .pace) ?? .standard
    }
}

enum BiologicalSex: String, Codable, CaseIterable, Identifiable {
    case male = "男性"
    case female = "女性"

    var id: String { rawValue }
}

/// 基礎代謝の計算に使う身体情報
struct BodyProfile: Hashable, Codable {
    var sex: BiologicalSex
    var birthYear: Int
    var heightCm: Double

    func age(on date: Date = .now, calendar: Calendar = .current) -> Int {
        max(0, calendar.component(.year, from: date) - birthYear)
    }
}

struct UserPreferences: Hashable, Codable {
    var languageCode: String
    var dayStartHour: Int
    var dayStartMinute: Int
    var onboarding: OnboardingProfile
    var mealAIEndpointURLString: String
    /// 未入力の既存ユーザーはnil。入力を促し、それまでは体重ベースで推定する
    var bodyProfile: BodyProfile?

    static let japaneseDefault = UserPreferences(
        languageCode: "ja",
        dayStartHour: 5,
        dayStartMinute: 0,
        onboarding: .initial,
        mealAIEndpointURLString: ""
    )

    init(languageCode: String, dayStartHour: Int, dayStartMinute: Int, onboarding: OnboardingProfile, mealAIEndpointURLString: String = "", bodyProfile: BodyProfile? = nil) {
        self.languageCode = languageCode
        self.dayStartHour = dayStartHour
        self.dayStartMinute = dayStartMinute
        self.onboarding = onboarding
        self.mealAIEndpointURLString = mealAIEndpointURLString
        self.bodyProfile = bodyProfile
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        languageCode = try container.decodeIfPresent(String.self, forKey: .languageCode) ?? "ja"
        dayStartHour = try container.decodeIfPresent(Int.self, forKey: .dayStartHour) ?? 5
        dayStartMinute = try container.decodeIfPresent(Int.self, forKey: .dayStartMinute) ?? 0
        onboarding = try container.decodeIfPresent(OnboardingProfile.self, forKey: .onboarding) ?? .initial
        mealAIEndpointURLString = try container.decodeIfPresent(String.self, forKey: .mealAIEndpointURLString) ?? ""
        bodyProfile = try container.decodeIfPresent(BodyProfile.self, forKey: .bodyProfile)
    }
}

struct NextAction: Hashable {
    enum Kind {
        case meal
        case weight
        case rest
    }

    var title: String
    var detail: String
    var kind: Kind
}

struct QuickCheckIn: Identifiable, Hashable, Codable {
    var id = UUID()
    var date: Date
    var mealAmount: String
    var activity: String
    var condition: String
    var mood: String
}
