import Foundation

enum LifeDayService {
    static func startOfLifeDay(containing date: Date, preferences: UserPreferences, calendar: Calendar = .current) -> Date {
        let naturalStart = calendar.startOfDay(for: date)
        let shiftedStart = calendar.date(
            byAdding: DateComponents(hour: preferences.dayStartHour, minute: preferences.dayStartMinute),
            to: naturalStart
        ) ?? naturalStart

        if date < shiftedStart {
            return calendar.date(byAdding: .day, value: -1, to: shiftedStart) ?? shiftedStart
        }

        return shiftedStart
    }

    static func endOfLifeDay(containing date: Date, preferences: UserPreferences, calendar: Calendar = .current) -> Date {
        let start = startOfLifeDay(containing: date, preferences: preferences, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? date
    }

    static func isSameLifeDay(_ lhs: Date, _ rhs: Date, preferences: UserPreferences, calendar: Calendar = .current) -> Bool {
        startOfLifeDay(containing: lhs, preferences: preferences, calendar: calendar) == startOfLifeDay(containing: rhs, preferences: preferences, calendar: calendar)
    }

    static func recentLifeDayInterval(days: Int, endingAt date: Date = .now, preferences: UserPreferences, calendar: Calendar = .current) -> DateInterval {
        let end = endOfLifeDay(containing: date, preferences: preferences, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -days, to: end) ?? date
        return DateInterval(start: start, end: end)
    }
}
