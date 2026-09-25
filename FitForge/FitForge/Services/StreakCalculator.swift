import Foundation

/// 休んだ日があっても週に一定日数までは途切れない連続記録
enum StreakCalculator {
    static let allowedRestDaysPerWeek = 2

    /// - Parameters:
    ///   - recordedDays: 記録があった生活日の開始時刻
    ///   - today: 今日の生活日の開始時刻。今日がまだ未記録でも連続は途切れない
    /// - Returns: 連続中に記録した日数
    static func streak(recordedDays: Set<Date>, today: Date, calendar: Calendar = .current) -> Int {
        guard let earliest = recordedDays.min() else { return 0 }
        var restsByWeek: [String: Int] = [:]
        var count = 0
        var day = today

        if !recordedDays.contains(today) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }
            day = yesterday
        }

        while day >= earliest {
            if recordedDays.contains(day) {
                count += 1
            } else {
                let key = weekKey(for: day, calendar: calendar)
                let rests = restsByWeek[key, default: 0]
                guard rests < allowedRestDaysPerWeek else { break }
                restsByWeek[key] = rests + 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private static func weekKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
}
