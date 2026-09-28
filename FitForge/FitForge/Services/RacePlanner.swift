import Foundation

// MARK: - 大会プランの設定

enum RaceType: String, Codable, CaseIterable, Identifiable {
    case fiveK = "5km"
    case tenK = "10km"
    case half = "ハーフマラソン"
    case full = "フルマラソン"
    case hyrox = "HYROX"

    var id: String { rawValue }

    /// 大会の距離（HYROXはラン8km）
    var distanceKm: Double {
        switch self {
        case .fiveK: 5
        case .tenK: 10
        case .half: 21.1
        case .full: 42.195
        case .hyrox: 8
        }
    }

    var workoutKind: WorkoutKind {
        switch self {
        case .full: .marathon
        case .hyrox: .hyrox
        default: .running
        }
    }

    /// 調整期（大会前に量を落とす週数）
    var taperWeeks: Int {
        switch self {
        case .full: 3
        case .half, .hyrox: 2
        case .fiveK, .tenK: 1
        }
    }

    /// ロング走の開始時と最長の距離(km)
    var longRunRange: (start: Double, peak: Double) {
        switch self {
        case .fiveK: (4, 8)
        case .tenK: (6, 14)
        case .half: (8, 18)
        case .full: (12, 30)
        case .hyrox: (5, 10)
        }
    }
}

struct RacePlan: Codable, Hashable {
    var id = UUID()
    var raceType: RaceType
    var raceDate: Date
    /// 週に走る（トレーニングする）日数。3〜5日
    var trainingDaysPerWeek: Int
    var createdAt = Date.now
}

// MARK: - 週ごとのメニュー

enum RacePhase: String {
    case base = "基礎期"
    case build = "強化期"
    case taper = "調整期"
    case race = "大会の週"

    var detail: String {
        switch self {
        case .base: "ゆっくり長く走れる土台を作る時期です。速さより、続けることを優先しましょう。"
        case .build: "距離とスピードを少しずつ上げる時期です。きつい日の翌日はしっかり休みましょう。"
        case .taper: "量を減らして疲れを抜く時期です。走り足りないくらいでちょうどよいです。"
        case .race: "本番の週です。短いジョグで体を動かし、睡眠と食事を整えましょう。"
        }
    }
}

struct PlannedWorkout: Identifiable, Hashable {
    var id: String
    var title: String
    var detail: String
    var kind: WorkoutKind
    /// 運動記録の sessionType（easy / tempo / interval / long / race / hyrox）と対応させる
    var sessionType: String
    var targetKm: Double?
}

struct RacePlanWeek {
    /// プラン開始の週を0とした週番号
    var index: Int
    var start: Date
    var end: Date
    /// 大会の週まであと何週か（0が大会の週）
    var weeksToRace: Int
    var phase: RacePhase
    var isRecoveryWeek: Bool
    var workouts: [PlannedWorkout]

    var totalKm: Double {
        workouts.compactMap(\.targetKm).reduce(0, +)
    }
}

/// 大会日から逆算して、週ごとのトレーニングを決まったルールで組み立てる（サーバー・AIは使わない）
enum RacePlanner {
    /// トレーニングの週は月曜始まり
    static var trainingCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    static func weekStart(_ date: Date) -> Date {
        trainingCalendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
    }

    static func weeksBetween(_ from: Date, _ to: Date) -> Int {
        trainingCalendar.dateComponents([.weekOfYear], from: weekStart(from), to: weekStart(to)).weekOfYear ?? 0
    }

    static func daysUntilRace(_ plan: RacePlan, now: Date = .now) -> Int {
        let calendar = trainingCalendar
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: plan.raceDate)).day ?? 0
    }

    /// 指定日を含む週のメニュー。大会が終わっていれば nil
    static func week(for plan: RacePlan, containing date: Date = .now) -> RacePlanWeek? {
        let calendar = trainingCalendar
        let raceWeekIndex = max(0, weeksBetween(plan.createdAt, plan.raceDate))
        let index = max(0, weeksBetween(plan.createdAt, date))
        let weeksToRace = raceWeekIndex - index
        guard weeksToRace >= 0 else { return nil }

        let taperWeeks = min(plan.raceType.taperWeeks, max(0, raceWeekIndex - 1))
        let peakIndex = max(0, raceWeekIndex - taperWeeks - 1)
        let buildWeeks = min(8, Int((Double(peakIndex + 1) * 0.6).rounded()))

        let phase: RacePhase
        if weeksToRace == 0 {
            phase = .race
        } else if weeksToRace <= taperWeeks {
            phase = .taper
        } else if weeksToRace <= taperWeeks + buildWeeks {
            phase = .build
        } else {
            phase = .base
        }

        // ロング走の距離：開始時から最長まで直線的に伸ばすが、1週あたり10%を超えて増やさない
        let range = plan.raceType.longRunRange
        let progress = Double(min(index, peakIndex)) / Double(max(1, peakIndex))
        let linear = range.start + (range.peak - range.start) * progress
        let capped = range.start * pow(1.1, Double(min(index, peakIndex)))
        var longKm = min(linear, capped)
        let peakLongKm = min(range.peak, range.start * pow(1.1, Double(peakIndex)))

        let isRecovery = (phase == .base || phase == .build) && index > 0 && (index + 1) % 4 == 0 && index != peakIndex
        if isRecovery { longKm *= 0.8 }
        if phase == .taper {
            let factor = max(0.5, 0.8 - 0.1 * Double(taperWeeks - weeksToRace + 1))
            longKm = peakLongKm * factor
        }

        let start = weekStart(date)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let workouts = plan.raceType == .hyrox
            ? hyroxWorkouts(plan: plan, phase: phase, progress: progress, longKm: longKm, weekIndex: index)
            : runWorkouts(plan: plan, phase: phase, progress: progress, longKm: longKm, weekIndex: index)

        return RacePlanWeek(
            index: index,
            start: start,
            end: end,
            weeksToRace: weeksToRace,
            phase: phase,
            isRecoveryWeek: isRecovery,
            workouts: workouts
        )
    }

    // MARK: ラン（5km〜フルマラソン）

    private static func runWorkouts(plan: RacePlan, phase: RacePhase, progress: Double, longKm: Double, weekIndex: Int) -> [PlannedWorkout] {
        let kind = plan.raceType.workoutKind
        let easyKm = max(3, roundHalf(longKm * 0.45))
        var list: [PlannedWorkout] = []

        func add(_ title: String, _ detail: String, _ type: String, _ km: Double?, kind: WorkoutKind = .running) {
            list.append(PlannedWorkout(id: "\(weekIndex)-\(list.count)", title: title, detail: detail, kind: kind, sessionType: type, targetKm: km))
        }

        if phase == .race {
            add("大会本番", "\(plan.raceType.rawValue)。前半は抑えめに入りましょう", "race", plan.raceType.distanceKm, kind: kind)
            for _ in 0..<min(2, plan.trainingDaysPerWeek - 1) {
                add("ジョグ＋流し", "20〜30分ゆっくり走り、最後に100m×3本だけ少し速く", "easy", 4)
            }
            return list
        }

        let long = roundHalf(longKm)
        add("ロング走", "\(long.formatted())km を会話できる速さで", "long", long)

        switch phase {
        case .base:
            let km = roundHalf(easyKm + 1)
            add("ビルドアップ走", "\(km.formatted())km。後半の2kmだけ少しペースを上げる", "tempo", km)
        case .build:
            if weekIndex.isMultiple(of: 2) {
                let km = roundHalf(max(4, longKm * 0.4))
                add("テンポ走", "\(km.formatted())km。会話がぎりぎりできるくらいの速さ", "tempo", km)
            } else {
                let reps = 4 + Int((progress * 4).rounded())
                add("インターバル", "1km×\(reps)本（間に2〜3分ジョグ）。前後にジョグ1〜2km", "interval", Double(reps) + 3)
            }
        case .taper:
            let km = roundHalf(max(3, longKm * 0.4))
            add("レースペース走", "\(km.formatted())km を大会の目標ペースで", "tempo", km)
        case .race:
            break
        }

        for _ in 0..<max(1, plan.trainingDaysPerWeek - 2) {
            add("ジョグ", "\(easyKm.formatted())km をゆっくり", "easy", easyKm)
        }
        return list
    }

    // MARK: HYROX

    private static func hyroxWorkouts(plan: RacePlan, phase: RacePhase, progress: Double, longKm: Double, weekIndex: Int) -> [PlannedWorkout] {
        var list: [PlannedWorkout] = []

        func add(_ title: String, _ detail: String, _ kind: WorkoutKind, _ type: String, _ km: Double?) {
            list.append(PlannedWorkout(id: "\(weekIndex)-\(list.count)", title: title, detail: detail, kind: kind, sessionType: type, targetKm: km))
        }

        if phase == .race {
            add("HYROX本番", "ラン1km×8とステーション8種目。最初の2本は抑えめに", .hyrox, "race", 8)
            if plan.trainingDaysPerWeek > 1 {
                add("ジョグ＋軽いウォールボール", "20分ジョグと、ウォールボール10回×2で体を動かす", .running, "easy", 3)
            }
            return list
        }

        let rounds = phase == .taper ? 3 : 3 + Int((progress * 3).rounded())
        add("ラン＋ステーション", "1km走 → ステーション1種目 を\(rounds)セット（スキー・ロー・ウォールボールなど）", .hyrox, "hyrox", Double(rounds))

        let reps = phase == .taper ? 3 : 3 + Int((progress * 3).rounded())
        add("インターバル走", "1km×\(reps)本をレースのペースで（間に90秒休む）", .running, "interval", Double(reps) + 2)

        add("HYROX筋力", "スレッドプッシュ・ランジ・ウォールボールを各3セット（ジムでは近い種目で代用）", .strength, "strength", nil)

        if plan.trainingDaysPerWeek >= 4 {
            let km = max(4, roundHalf(longKm))
            add("ロングジョグ", "\(km.formatted())km をゆっくり", .running, "long", km)
        }
        if plan.trainingDaysPerWeek >= 5 {
            add("ジョグ", "5km をゆっくり", .running, "easy", 5)
        }
        return list
    }

    // MARK: 記録との照合

    /// その週の記録から、終わったメニューのIDを返す。同じ記録を2つのメニューに使わない
    static func completedWorkoutIDs(in week: RacePlanWeek, cardio: [CardioSession], strength: [StrengthSet]) -> Set<String> {
        let interval = DateInterval(start: week.start, end: week.end)
        var unusedCardio = cardio.filter { interval.contains($0.date) }.sorted { $0.date < $1.date }
        let strengthDays = Set(strength.filter { interval.contains($0.date) }.map { trainingCalendar.startOfDay(for: $0.date) })
        var usedStrengthDays = 0
        var done = Set<String>()

        // 種類がはっきりしたメニュー（大会・ロング・テンポ・インターバル・HYROX）から先に割り当てる
        let ordered = week.workouts.sorted { priority($0) < priority($1) }
        for workout in ordered {
            if workout.kind == .strength {
                if usedStrengthDays < strengthDays.count {
                    usedStrengthDays += 1
                    done.insert(workout.id)
                }
                continue
            }
            let match = unusedCardio.firstIndex { matches($0, workout) }
            if let match {
                unusedCardio.remove(at: match)
                done.insert(workout.id)
            }
        }
        return done
    }

    private static func matches(_ session: CardioSession, _ workout: PlannedWorkout) -> Bool {
        switch workout.sessionType {
        case "race":
            return session.sessionType == "race"
        case "hyrox":
            return session.kind == .hyrox || session.sessionType == "hyrox"
        case "long", "tempo", "interval":
            return session.sessionType == workout.sessionType
        default:
            return session.kind != .hyrox
        }
    }

    private static func priority(_ workout: PlannedWorkout) -> Int {
        switch workout.sessionType {
        case "race", "hyrox": 0
        case "long", "tempo", "interval": 1
        case "strength": 2
        default: 3
        }
    }

    private static func roundHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }
}
