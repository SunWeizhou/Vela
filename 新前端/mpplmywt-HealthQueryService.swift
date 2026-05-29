import Foundation

@MainActor
protocol HealthQueryService {
    func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary?
    func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary]
    func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary
    func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary
    func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary
}
