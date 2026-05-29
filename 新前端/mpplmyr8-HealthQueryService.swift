import Foundation

@MainActor
protocol HealthQueryService {
    func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary?
    func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary]
    func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary
    func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary
    func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary
    
    // Workout details queries
    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary]
    func heartRateSamples(start: Date, end: Date) async throws -> [HeartRateSample]
    func workoutRoute(workoutId: UUID) async throws -> [RouteCoordinate]
}
