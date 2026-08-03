import Foundation

enum HealthDaySettings {
    static let boundaryMinutesKey = "vela.healthDay.boundaryMinutes"
    static let defaultBoundaryMinutes = 4 * 60

    static func boundaryMinutes(defaults: UserDefaults = .standard) -> Int {
        guard defaults.object(forKey: boundaryMinutesKey) != nil else {
            return defaultBoundaryMinutes
        }
        return min(max(defaults.integer(forKey: boundaryMinutesKey), 0), 12 * 60)
    }
}

struct HealthDayBoundary: Hashable {
    var calendar: Calendar
    var boundaryMinutes: Int

    init(
        calendar: Calendar = .current,
        boundaryMinutes: Int = HealthDaySettings.boundaryMinutes()
    ) {
        self.calendar = calendar
        self.boundaryMinutes = min(max(boundaryMinutes, 0), 12 * 60)
    }

    func start(containing instant: Date) -> Date {
        let midnight = calendar.startOfDay(for: instant)
        let candidate = calendar.date(
            byAdding: .minute,
            value: boundaryMinutes,
            to: midnight
        ) ?? midnight
        if instant >= candidate {
            return candidate
        }
        let previousMidnight = calendar.date(byAdding: .day, value: -1, to: midnight) ?? midnight
        return calendar.date(
            byAdding: .minute,
            value: boundaryMinutes,
            to: previousMidnight
        ) ?? previousMidnight
    }

    func labelDate(containing instant: Date) -> Date {
        calendar.startOfDay(for: start(containing: instant))
    }

    func range(forLabelDate date: Date) -> DateRangeQuery {
        let midnight = calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .minute, value: boundaryMinutes, to: midnight) ?? midnight
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateRangeQuery(start: start, end: end)
    }

    func range(containing instant: Date) -> DateRangeQuery {
        range(forLabelDate: labelDate(containing: instant))
    }
}

struct DateRangeQuery: Hashable {
    let start: Date
    let end: Date

    static func recentDays(
        _ count: Int,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> DateRangeQuery {
        let boundary = HealthDayBoundary(calendar: calendar)
        let labelDate = boundary.labelDate(containing: date)
        let currentRange = boundary.range(forLabelDate: labelDate)
        let end = currentRange.end
        let safeCount = max(count, 1)
        let start = calendar.date(byAdding: .day, value: -safeCount, to: end) ?? end
        return DateRangeQuery(start: start, end: end)
    }

    static func today(containing date: Date = Date(), calendar: Calendar = .current) -> DateRangeQuery {
        HealthDayBoundary(calendar: calendar).range(containing: date)
    }

    static func singleDay(_ date: Date, calendar: Calendar = .current) -> DateRangeQuery {
        HealthDayBoundary(calendar: calendar).range(forLabelDate: date)
    }

    func dayCount(calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}
