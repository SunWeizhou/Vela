import XCTest
import HealthKit
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeDefinesStableProductIdentity() {
        XCTAssertEqual(VelaAppMetadata.name, "Vela")
        XCTAssertEqual(VelaAppMetadata.minimumOSVersion, "17.0")
        XCTAssertEqual(VelaTheme.cornerRadiusCard, 20)
    }

    func testDateRangeBuildsRecentCalendarWindows() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 9)))

        let range = DateRangeQuery.recentDays(7, endingAt: now, calendar: calendar)

        XCTAssertEqual(range.dayCount(calendar: calendar), 7)
        XCTAssertTrue(range.start < range.end)
        XCTAssertEqual(calendar.component(.hour, from: range.end), 0)
    }

    func testHealthDataCatalogCoversPhaseOneReadTypes() {
        XCTAssertTrue(HealthDataTypeCatalog.sleepReadTypes.contains(HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!))
        XCTAssertTrue(HealthDataTypeCatalog.recoveryReadTypes.contains(HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!))
        XCTAssertTrue(HealthDataTypeCatalog.strainReadTypes.contains(HKObjectType.workoutType()))
        XCTAssertTrue(HealthDataTypeCatalog.biologyReadTypes.contains(HKObjectType.quantityType(forIdentifier: .vo2Max)!))
        XCTAssertEqual(Set(HealthDataTypeCatalog.readTypes).count, HealthDataTypeCatalog.readTypes.count)
    }

    func testHomeReadinessBriefSurfacesWhyAndNextAction() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = StandardScoreResult(
            score: 35,
            band: .low,
            confidence: .high,
            components: ["hrv": 35],
            weights: ["hrv": 1],
            reasons: ["HRV significantly below personal baseline (z=-2.0)"],
            metrics: ["hrv_z_score": -2.0]
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard)
        let brief = HomeReadinessBrief.make(dashboard: dashboard, plan: plan)

        XCTAssertEqual(brief.statusLabel, "Low readiness")
        XCTAssertTrue(brief.why.contains("HRV"))
        XCTAssertEqual(brief.nextAction, plan.primaryActionTitle)
        XCTAssertEqual(brief.accent, .recovery)
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
}
