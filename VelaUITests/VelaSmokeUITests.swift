import XCTest

@MainActor
final class VelaSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFourPrimarySurfacesAreReachable() {
        let app = launchApp(initialTab: 0)

        assertSurface(0, in: app)
        selectTab(index: 1, label: "趋势", in: app)
        assertSurface(1, in: app)
        selectTab(index: 2, label: "计划", in: app)
        assertSurface(2, in: app)
        selectTab(index: 3, label: "Vela", in: app)
        assertSurface(3, in: app)
        XCTAssertTrue(
            app.descendants(matching: .any)["coach-surface-header"].waitForExistence(timeout: 8),
            "Coach surface did not become visible"
        )
    }

    func testSettingsDeepLaunch() {
        let app = launchApp(extraArguments: ["-velaOpenSettings"])

        XCTAssertTrue(
            app.descendants(matching: .any)["settings-surface"].waitForExistence(timeout: 10),
            "Settings sheet did not open from its launch route"
        )
        XCTAssertTrue(app.navigationBars["设置"].exists)
    }

    func testRecoveryDetailDeepLaunch() {
        let app = launchApp(extraArguments: ["-velaOpenRecoveryDetail"])

        XCTAssertTrue(
            app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 10),
            "Recovery detail did not open from its launch route"
        )
        XCTAssertTrue(app.navigationBars["恢复"].exists)
    }

    func testLivedStateCheckInDeepLaunch() {
        let app = launchApp(extraArguments: ["-velaOpenLivedStateCheckIn"])

        XCTAssertTrue(
            app.descendants(matching: .any)["lived-state-check-in"].waitForExistence(timeout: 10),
            "Lived State check-in did not open from its launch route"
        )
        XCTAssertTrue(app.navigationBars["校准今日状态"].exists)
    }

    private func launchApp(
        initialTab: Int = 0,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-vela_onboarding_completed", "YES",
            "-vela_app_language", "simplifiedChinese",
            "-velaPreviewDashboard",
            "-velaLegacyInterface",
            "-velaInitialTab", String(initialTab),
        ] + extraArguments
        app.launch()
        return app
    }

    private func selectTab(
        index: Int,
        label: String,
        in app: XCUIApplication
    ) {
        let customButton = app.buttons["tab-\(index)"]
        if customButton.exists {
            customButton.tap()
            return
        }

        let nativeButton = app.tabBars.buttons[label]
        XCTAssertTrue(
            nativeButton.waitForExistence(timeout: 8),
            "Tab \(label) was not reachable"
        )
        nativeButton.tap()
    }

    private func assertSurface(_ index: Int, in app: XCUIApplication) {
        XCTAssertTrue(
            app.descendants(matching: .any)["surface-\(index)"].waitForExistence(timeout: 10),
            "Primary surface \(index) did not become visible"
        )
    }
}
