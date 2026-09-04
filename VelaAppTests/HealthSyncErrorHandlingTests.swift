import XCTest
import HealthKit
@testable import Vela

/// HealthKit 查询失败分类回归测试（审计 C2）。
/// 不变量：
///   1. 真实查询错误（授权被拒/参数错误/数据库异常）→ 记录为组件失败，绝不当作「无数据」；
///   2. 只有 errorNoData（该范围确实没有样本）→ 空数据分支，不记为失败；
///   3. 核心组件全部失败 → hasCoreData == false（调用方不得持久化全空快照）；
///   4. 至少一个核心组件成功 → 部分数据合法，hasCoreData == true。
final class HealthSyncErrorHandlingTests: XCTestCase {

    private final class FakeHealthQueryService: HealthQueryService {
        var onSleep: () throws -> SleepSummary? = { nil }
        var onRecovery: () throws -> RecoveryMetricSummary = {
            RecoveryMetricSummary()
        }
        var onStrain: () throws -> StrainActivitySummary = {
            StrainActivitySummary(workouts: [])
        }
        var onBody: () throws -> BodyMetricsSummary = {
            BodyMetricsSummary()
        }
        var onExtended: () throws -> ExtendedHealthMetrics = {
            ExtendedHealthMetrics()
        }

        func sleepSummary(in range: DateRangeQuery) async throws -> SleepSummary? {
            try onSleep()
        }

        func sleepEpisodes(in range: DateRangeQuery) async throws -> [SleepSummary] { [] }

        func recoveryMetrics(in range: DateRangeQuery) async throws -> RecoveryMetricSummary {
            try onRecovery()
        }

        func strainSummary(in range: DateRangeQuery) async throws -> StrainActivitySummary {
            try onStrain()
        }

        func bodyMetrics(in range: DateRangeQuery) async throws -> BodyMetricsSummary {
            try onBody()
        }

        func recentWorkouts(limit: Int) async throws -> [WorkoutSummary] { [] }
        func heartRateSamples(start: Date, end: Date) async throws -> [HeartRateSample] { [] }
        func workoutRoute(workoutId: UUID) async throws -> [RouteCoordinate] { [] }
    }

    private var calendar: Calendar { Calendar.current }

    private static func nonBenignError() -> NSError {
        NSError(domain: HKErrorDomain, code: 100, userInfo: nil)
    }

    private static func benignNoDataError() -> NSError {
        NSError(domain: HKErrorDomain, code: HKError.Code.errorNoData.rawValue, userInfo: nil)
    }

    @MainActor
    func testRealQueryErrorsAreRecordedNotSwallowed() async {
        let fake = FakeHealthQueryService()
        fake.onSleep = { throw Self.nonBenignError() }
        fake.onRecovery = { throw Self.nonBenignError() }
        fake.onStrain = { throw Self.nonBenignError() }
        fake.onBody = { throw Self.nonBenignError() }

        let result = await DailySnapshotBuilder.buildSnapshot(
            for: Date(),
            queryService: fake,
            calendar: calendar
        )

        XCTAssertEqual(
            Set(result.queryFailures),
            [.sleep, .recovery, .strain, .body],
            "真实查询错误必须记录为组件失败，绝不能当作无数据吞掉"
        )
        XCTAssertEqual(
            result.diagnostics.filter { $0.outcome == .failed }.map(\.component),
            ["sleep", "recovery", "strain", "body"]
        )
        XCTAssertFalse(
            result.hasCoreData,
            "核心组件全部失败时不得持久化全空快照"
        )
        XCTAssertNil(result.snapshot.sleepHours)
        XCTAssertNil(result.snapshot.hrvAverage)
    }

    @MainActor
    func testNoDataIsBenignAndNotAFailure() async {
        let fake = FakeHealthQueryService()
        fake.onSleep = { throw Self.benignNoDataError() }
        fake.onRecovery = { throw Self.benignNoDataError() }
        fake.onStrain = { throw Self.benignNoDataError() }
        fake.onBody = { throw Self.benignNoDataError() }

        let result = await DailySnapshotBuilder.buildSnapshot(
            for: Date(),
            queryService: fake,
            calendar: calendar
        )

        XCTAssertTrue(
            result.queryFailures.isEmpty,
            "errorNoData 是无样本而不是查询失败，不应记入失败清单"
        )
        XCTAssertEqual(result.diagnostics.map(\.outcome), [.noData, .noData, .noData, .noData])
        // 注意：无数据 ≠ 没有核心数据依赖——组件全部「无样本」时快照为空，
        // 但这是合法的缺失数据表达（由 Data Coverage 规则承接）。
    }

    @MainActor
    func testPartialFailureKeepsCoreDataAndReportsComponent() async {
        let fake = FakeHealthQueryService()
        fake.onSleep = { throw Self.nonBenignError() }
        fake.onRecovery = {
            var summary = RecoveryMetricSummary()
            summary.hrvMilliseconds = 41.0
            summary.restingHeartRate = 62.0
            return summary
        }

        let result = await DailySnapshotBuilder.buildSnapshot(
            for: Date(),
            queryService: fake,
            calendar: calendar
        )

        XCTAssertEqual(result.queryFailures, [.sleep])
        XCTAssertEqual(result.diagnostics.first?.outcome, .failed)
        XCTAssertTrue(result.hasCoreData, "部分组件失败时应保留其余核心数据")
        XCTAssertEqual(result.snapshot.hrvAverage, 41.0)
        XCTAssertNil(result.snapshot.sleepHours, "失败组件不得产出伪造数据")
    }

    func testHealthKitErrorClassifierKeepsPermissionAndAvailabilityDistinct() {
        XCTAssertEqual(
            HealthKitQueryOutcomeClassifier.classify(
                NSError(domain: HKErrorDomain, code: HKError.Code.errorAuthorizationDenied.rawValue)
            ),
            .denied
        )
        XCTAssertEqual(
            HealthKitQueryOutcomeClassifier.classify(
                NSError(domain: HKErrorDomain, code: HKError.Code.errorHealthDataUnavailable.rawValue)
            ),
            .unavailable
        )
        XCTAssertEqual(
            HealthKitQueryOutcomeClassifier.classify(
                NSError(domain: HKErrorDomain, code: HKError.Code.errorNoData.rawValue)
            ),
            .noData
        )
    }
}
