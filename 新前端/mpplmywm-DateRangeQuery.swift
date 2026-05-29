import Foundation

struct DateRangeQuery: Hashable {
    let start: Date
    let end: Date

    static func recentDays(
        _ count: Int,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> DateRangeQuery {
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: date) ?? date)
        let safeCount = max(count, 1)
        let start = calendar.date(byAdding: .day, value: -safeCount, to: end) ?? end
        return DateRangeQuery(start: start, end: end)
    }

    static func today(containing date: Date = Date(), calendar: Calendar = .current) -> DateRangeQuery {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DateRangeQuery(start: start, end: end)
    }

    static func singleDay(_ date: Date, calendar: Calendar = .current) -> DateRangeQuery {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? date
        return DateRangeQuery(start: start, end: end)
    }

    func dayCount(calendar: Calendar = .current) -> Int {
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        return calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0
    }
}
