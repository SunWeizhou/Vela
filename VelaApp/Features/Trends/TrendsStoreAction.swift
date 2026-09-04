import Foundation

enum TrendsStoreAction: Sendable {
    case appear
    case selectDay(Date)
    case selectHorizon(HealthTrendHorizon)
    case selectMetric(CoreHealthMetric)
    case retry
    case selectPoint(Date?)
}

protocol TrendsHistoryProviding: Sendable {
    func history(
        metric: CoreHealthMetric,
        horizon: HealthTrendHorizon,
        endingAt selectedDay: Date,
        calendar: Calendar
    ) async throws -> TrendsHistoryPayload
}

struct StaticTrendsHistoryProvider: TrendsHistoryProviding {
    let payload: TrendsHistoryPayload

    func history(
        metric: CoreHealthMetric,
        horizon: HealthTrendHorizon,
        endingAt selectedDay: Date,
        calendar: Calendar
    ) async throws -> TrendsHistoryPayload {
        payload
    }
}
