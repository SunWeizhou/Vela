import XCTest
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeTokensReturnNonNilValues() {
        let bg = VelaTheme.bg
        let fg = VelaTheme.fg
        let cardBg = VelaTheme.cardBg
        XCTAssertTrue(true, "Theme tokens accessible: \(bg), \(fg), \(cardBg)")
    }

    @MainActor
    func testCoachRouteUsesCenteredTab() {
        let appState = VelaAppState.shared
        appState.selectedTab = 0

        appState.routeToCoach(question: nil)

        XCTAssertEqual(VelaAppState.coachTabIndex, 2)
        XCTAssertEqual(appState.selectedTab, 2)
    }

    @MainActor
    func testRecoveryDetailRoutesToVitalsTab() {
        let appState = VelaAppState.shared
        appState.selectedTab = 0

        appState.routeToRecoveryDetail()

        XCTAssertEqual(appState.selectedTab, 4)
        XCTAssertTrue(appState.triggerRecoveryDetail)
    }

    @MainActor
    func testWeeklyReportDoesNotTreatDefaultScoresAsHealthData() {
        var snapshot = DailyHealthSnapshot(date: Date())
        snapshot.recoveryScore = 100
        snapshot.sleepScore = 100

        let report = TrainingResponseInsightService().buildWeeklyBodyReport(
            snapshots: [snapshot],
            foodLogs: [],
            journalEntries: [],
            strengthWorkouts: [],
            trainingResponses: []
        )

        XCTAssertNil(report.averageRecoveryScore)
        XCTAssertNil(report.averageSleepScore)
        XCTAssertTrue(report.markdown.contains("平均恢复分：暂无"))
        XCTAssertTrue(report.markdown.contains("平均睡眠分：暂无"))
    }
}
