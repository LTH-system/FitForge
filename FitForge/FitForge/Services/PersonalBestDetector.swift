import Foundation

/// 自己ベスト（重量・距離）の判定と、1RM推移などの表示用データを作る純粋なロジック
enum PersonalBestDetector {
    /// この筋トレ記録が、それより前の同じ種目の記録より重い自己ベストかどうか。
    /// その種目の記録が他に1件もない場合は「初回」であってベスト更新ではないためfalse
    static func isBestWeight(_ set: StrengthSet, among all: [StrengthSet]) -> Bool {
        let earlier = all.filter { $0.exercise == set.exercise && $0.id != set.id && $0.date < set.date }
        guard !earlier.isEmpty else { return false }
        return earlier.allSatisfy { $0.weightKg < set.weightKg }
    }

    /// この有酸素記録が、それより前の同じ種目(ランニング/HYROX/マラソン)より長い距離の自己ベストかどうか
    static func isBestDistance(_ session: CardioSession, among all: [CardioSession]) -> Bool {
        let earlier = all.filter { $0.kind == session.kind && $0.id != session.id && $0.date < session.date }
        guard !earlier.isEmpty else { return false }
        return earlier.allSatisfy { $0.distanceKm < session.distanceKm }
    }

    /// 指定した種目の推定1RMの推移（古い順）。グラフ表示用
    static func oneRepMaxTrend(exercise: String, among all: [StrengthSet], limit: Int = 6) -> [(date: Date, value: Double)] {
        all.filter { $0.exercise == exercise }
            .sorted { $0.date < $1.date }
            .suffix(limit)
            .map { ($0.date, $0.estimatedOneRepMax) }
    }

    /// 指定した種目の距離の推移（古い順）。グラフ表示用
    static func distanceTrend(kind: WorkoutKind, among all: [CardioSession], limit: Int = 6) -> [(date: Date, value: Double)] {
        all.filter { $0.kind == kind }
            .sorted { $0.date < $1.date }
            .suffix(limit)
            .map { ($0.date, $0.distanceKm) }
    }

    /// 今月、自己ベストを更新した回数（筋トレ・有酸素の合計）
    static func monthlyBestCount(strengthSets: [StrengthSet], cardioSessions: [CardioSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        let strengthCount = strengthSets
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .filter { isBestWeight($0, among: strengthSets) }
            .count
        let cardioCount = cardioSessions
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .filter { isBestDistance($0, among: cardioSessions) }
            .count
        return strengthCount + cardioCount
    }
}
