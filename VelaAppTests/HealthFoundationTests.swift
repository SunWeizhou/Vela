import XCTest
@testable import Vela

final class HealthFoundationTests: XCTestCase {
    func testSleepNormalizerAggregatesAsleepStagesAndAwakeSeparately() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 23)))
        let coreEnd = start.addingTimeInterval(120 * 60)
        let remEnd = coreEnd.addingTimeInterval(60 * 60)
        let awakeEnd = remEnd.addingTimeInterval(20 * 60)

        let summary = SleepSampleNormalizer.summary(
            for: start,
            segments: [
                .init(stage: .core, start: start, end: coreEnd),
                .init(stage: .rem, start: coreEnd, end: remEnd),
                .init(stage: .awake, start: remEnd, end: awakeEnd)
            ]
        )

        XCTAssertEqual(summary.totalSleepMinutes, 180)
        XCTAssertEqual(summary.stageMinutes[.core], 120)
        XCTAssertEqual(summary.stageMinutes[.rem], 60)
        XCTAssertEqual(summary.stageMinutes[.awake], 20)
        XCTAssertEqual(summary.bedtime, start)
        XCTAssertEqual(summary.wakeTime, awakeEnd)
    }

    func testSleepNormalizerUsesMostRecentEpisodeInsteadOfTwoDayTotal() throws {
        let calendar = Calendar(identifier: .gregorian)
        let priorNightStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 1)))
        let lastNightStart = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 16, hour: 23)))

        let summary = try XCTUnwrap(
            SleepSampleNormalizer.mostRecentEpisodeSummary(
                for: lastNightStart,
                segments: [
                    .init(stage: .core, start: priorNightStart, end: priorNightStart.addingTimeInterval(180 * 60)),
                    .init(stage: .core, start: lastNightStart, end: lastNightStart.addingTimeInterval(240 * 60)),
                    .init(stage: .rem, start: lastNightStart.addingTimeInterval(240 * 60), end: lastNightStart.addingTimeInterval(300 * 60))
                ]
            )
        )

        XCTAssertEqual(summary.totalSleepMinutes, 300)
        XCTAssertEqual(summary.bedtime, lastNightStart)
        XCTAssertEqual(summary.wakeTime, lastNightStart.addingTimeInterval(300 * 60))
    }

    func testPreviewProviderReturnsThirtyDailySnapshots() {
        let snapshots = PreviewHealthDataProvider.dailySnapshots(days: 30)

        XCTAssertEqual(snapshots.count, 30)
        XCTAssertTrue(snapshots.allSatisfy { $0.sleepScore != nil })
        XCTAssertTrue(snapshots.allSatisfy { $0.recoveryScore != nil })
        XCTAssertTrue(snapshots.allSatisfy { $0.strainScore != nil })
    }

    @MainActor
    func testRefreshServiceReturnsSnapshotWhenHealthDataIsMissing() async throws {
        let service = HealthDataRefreshService(queryService: EmptyHealthQueryService())

        let snapshot = try await service.refreshToday(now: Date(timeIntervalSince1970: 1_779_000_000))

        XCTAssertNil(snapshot.sleepScore)
        XCTAssertNil(snapshot.recoveryScore)
        XCTAssertNil(snapshot.strainScore)
        XCTAssertNil(snapshot.stressIndex)
    }
}

private struct EmptyHealthQueryService: HealthQueryService {
    func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary? {
        nil
    }

    func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary] {
        []
    }

    func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary {
        RecoveryMetricSummary()
    }

    func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary {
        StrainActivitySummary(workouts: [])
    }

    func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary {
        BodyMetricsSummary()
    }
}
