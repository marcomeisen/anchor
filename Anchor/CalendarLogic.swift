import Foundation

enum AnkerCalendar {
    static var iso: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }

    static func weekInterval(containing date: Date, calendar: Calendar = iso) -> (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let monday = calendar.date(from: components) ?? date
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday

        return (
            monday: calendar.startOfDay(for: monday),
            sunday: calendar.startOfDay(for: sunday),
            isoYear: components.yearForWeekOfYear ?? calendar.component(.year, from: date),
            isoWeek: components.weekOfYear ?? calendar.component(.weekOfYear, from: date)
        )
    }

    static func daysInWeek(starting monday: Date, calendar: Calendar = iso) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = iso
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = iso) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }
}
