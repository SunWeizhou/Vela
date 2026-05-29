import Foundation

struct HealthCachePolicy: Hashable {
    var maxAge: TimeInterval

    static let dashboard = HealthCachePolicy(maxAge: 15 * 60)
    static let dailySummary = HealthCachePolicy(maxAge: 60 * 60)

    func isStale(lastUpdatedAt: Date?, now: Date = Date()) -> Bool {
        guard let lastUpdatedAt else { return true }
        return now.timeIntervalSince(lastUpdatedAt) > maxAge
    }
}
