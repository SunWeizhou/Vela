import XCTest
import HealthKit
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeDefinesStableProductIdentity() {
        XCTAssertEqual(VelaAppMetadata.name, "Vela")
        XCTAssertEqual(VelaAppMetadata.minimumOSVersion, "17.0")
        XCTAssertEqual(VelaTheme.cornerRadiusCard, 18)
    }

    func testDateRangeBuildsRecentCalendarWindows() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 9)))

        let range = DateRangeQuery.recentDays(7, endingAt: now, calendar: calendar)

        XCTAssertEqual(range.dayCount(calendar: calendar), 7)
        XCTAssertTrue(range.start < range.end)
        XCTAssertEqual(calendar.component(.hour, from: range.end), 0)
    }

    func testEmptyDashboardDoesNotExposePreviewScores() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 29)))
        let dashboard = DashboardSummary.empty(date: date)

        XCTAssertEqual(dashboard.source, .empty)
        XCTAssertFalse(dashboard.sleepScore.hasData)
        XCTAssertFalse(dashboard.recovery.hasData)
        XCTAssertFalse(dashboard.strain.hasData)
        XCTAssertFalse(dashboard.stress.hasData)
        XCTAssertFalse(dashboard.energy.hasData)
        XCTAssertTrue(dashboard.workouts.isEmpty)
        XCTAssertTrue(dashboard.dailyInsight.isEmpty)
    }

    func testHealthDataCatalogCoversPhaseOneReadTypes() {
        XCTAssertTrue(HealthDataTypeCatalog.sleepReadTypes.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        XCTAssertTrue(HealthDataTypeCatalog.recoveryReadTypes.contains(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        XCTAssertTrue(HealthDataTypeCatalog.strainReadTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(HealthDataTypeCatalog.biologyReadTypes.contains(HKObjectType.quantityType(forIdentifier: .vo2Max)!))
        XCTAssertEqual(Set(HealthDataTypeCatalog.readTypes).count, HealthDataTypeCatalog.readTypes.count)
    }

    func testDailyPlanRecommendsRecoveryWhenScoreLow() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = StandardScoreResult(
            score: 35,
            band: .low,
            confidence: .high,
            components: ["hrv": 35],
            weights: ["hrv": 1],
            reasons: ["HRV significantly below personal baseline"],
            metrics: ["hrv_z_score": -2.0]
        )
        let plan = DailyPlanEngine.recommendation(for: dashboard)
        XCTAssertEqual(plan.kind, .recovery)
        XCTAssertEqual(plan.accent, .recovery)
    }

    func testAppleThemeHasSemanticColors() {
        XCTAssertNotNil(VelaTheme.recovery)
        XCTAssertNotNil(VelaTheme.sleep)
        XCTAssertNotNil(VelaTheme.strain)
        XCTAssertNotNil(VelaTheme.stress)
        XCTAssertNotNil(VelaTheme.energy)
    }

    @MainActor
    func testCoachRouteWritesPrefilledQuestionAndOpensCoachHub() {
        let state = VelaAppState.shared
        state.selectedTab = 0
        state.showCoachHub = false
        state.prefilledCoachQuestion = nil

        state.routeToCoach(question: "Review my sleep and give me one action.")

        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertTrue(state.showCoachHub)
        XCTAssertEqual(state.prefilledCoachQuestion, "Review my sleep and give me one action.")
    }

    @MainActor
    func testCoachRouteWithoutQuestionStartsBlankSession() {
        let state = VelaAppState.shared
        state.showCoachHub = false
        state.prefilledCoachQuestion = "Stale question"
        state.forceNewCoachSession = false

        state.routeToCoach(question: nil)

        XCTAssertTrue(state.showCoachHub)
        XCTAssertTrue(state.forceNewCoachSession)
        XCTAssertNil(state.prefilledCoachQuestion)
    }
}
