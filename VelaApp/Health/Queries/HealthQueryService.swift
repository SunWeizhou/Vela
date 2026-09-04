import Foundation

@MainActor
protocol HealthQueryService {
    func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary?
    func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary]
    func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary
    func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary
    func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary
    /// Extended daily evidence used by the Today summary adapter. Keeping this
    /// on the protocol (rather than the HealthKit concrete type) lets preview
    /// and test providers preserve missing-data semantics without constructing
    /// an `HKHealthStore`.
    func extendedMetrics(in range: DateRangeQuery) async throws -> ExtendedHealthMetrics
    /// Intraday points are an explicit adapter seam for Today's persistence
    /// buckets. They remain HealthKit value types and never cross into Domain.
    func intradaySamples(
        for signal: HealthSignal,
        in range: DateRangeQuery
    ) async throws -> [IntradaySignalPoint]
    
    // Workout details queries
    func recentWorkouts(limit: Int) async throws -> [WorkoutSummary]
    func heartRateSamples(start: Date, end: Date) async throws -> [HeartRateSample]
    func workoutRoute(workoutId: UUID) async throws -> [RouteCoordinate]
}

extension HealthQueryService {
    /// Source-compatible defaults keep existing lightweight test providers
    /// valid while they opt into the newly explicit daily-evidence seam.
    func extendedMetrics(in range: DateRangeQuery) async throws -> ExtendedHealthMetrics {
        ExtendedHealthMetrics()
    }

    func intradaySamples(
        for signal: HealthSignal,
        in range: DateRangeQuery
    ) async throws -> [IntradaySignalPoint] {
        []
    }

    /// Implementations may expose diagnostics collected by nested/ancillary
    /// queries. The default keeps preview and test providers source-compatible.
    func consumeDiagnostics() -> [HealthQueryDiagnostic] { [] }
}
