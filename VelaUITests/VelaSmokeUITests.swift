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

    func testTodayScoreContentAndMetricRouting() {
        let app = launchApp(initialTab: 0)

        XCTAssertTrue(
            app.descendants(matching: .any)["surface-0"].waitForExistence(timeout: 10),
            "Today surface did not become visible"
        )
        for metric in ["recovery", "sleep", "strain"] {
            XCTAssertTrue(
                app.descendants(matching: .any)["today-score-\(metric)"].waitForExistence(timeout: 3),
                "Today score \(metric) did not expose its stable identifier"
            )
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["today-secondary-stress"].waitForExistence(timeout: 3),
            "Today secondary stress card did not expose its stable identifier"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["today-secondary-energy"].waitForExistence(timeout: 3),
            "Today secondary energy card did not expose its stable identifier"
        )
        let guidanceCard = app.descendants(matching: .any)["today-guidance"]
        if guidanceCard.waitForExistence(timeout: 3) {
            guidanceCard.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["today-evidence-sheet"].waitForExistence(timeout: 8),
                "Tapping today guidance should open local evidence sheet"
            )
            let closeButton = app.buttons["关闭"]
            if closeButton.waitForExistence(timeout: 3) {
                closeButton.tap()
            }
        }
        let recoveryScore = app.descendants(matching: .any)["today-score-recovery"]
        if recoveryScore.waitForExistence(timeout: 3) {
            // Preview fixtures expose the score card as a stable, tappable
            // route. A real no-data launch may intentionally omit that card
            // while retaining the conservative state projection below.
            recoveryScore.tap()
            XCTAssertTrue(
                app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 8),
                "Today recovery score did not route to its metric detail"
            )
        } else {
            XCTAssertTrue(
                app.descendants(matching: .any)["today-data-state"].waitForExistence(timeout: 5),
                "No-data Today launch should expose its conservative data state"
            )
        }
    }

    func testTrendsScoreContentAndMetricRouting() {
        let app = launchApp(initialTab: 1)

        XCTAssertTrue(
            app.descendants(matching: .any)["trends-content"].waitForExistence(timeout: 10),
            "Trends surface did not become visible"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["trends-horizon-picker"].waitForExistence(timeout: 8),
            "Trends horizon picker did not expose its stable identifier"
        )
        for metric in ["recovery", "sleepScore", "strain", "stress", "energy"] {
            XCTAssertTrue(
                app.descendants(matching: .any)["trends-score-\(metric)"].waitForExistence(timeout: 8),
                "Trends score \(metric) did not expose its stable identifier"
            )
        }

        XCTAssertTrue(
            app.descendants(matching: .any)["trends-recovery-store-chart"].waitForExistence(timeout: 8),
            "Recovery trend should expose the Store-owned one-metric chart when preview history is available"
        )

        app.descendants(matching: .any)["trends-score-recovery"].tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 8),
            "Trends recovery score did not route to its metric detail"
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

        let closeButton = app.buttons["metric-detail-close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5), "Sheet should show close button")
        closeButton.tap()
        XCTAssertFalse(
            app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 3),
            "Recovery detail sheet should dismiss after tapping close"
        )
    }

    func testRecoveryDetailPushNavigationAndReturn() {
        let app = launchApp(initialTab: 0)

        XCTAssertTrue(
            app.descendants(matching: .any)["surface-0"].waitForExistence(timeout: 10),
            "Today surface did not become visible"
        )
        let recoveryScore = app.descendants(matching: .any)["today-score-recovery"]
        guard recoveryScore.waitForExistence(timeout: 5) else {
            return
        }
        recoveryScore.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 8),
            "Recovery detail did not open from Today push"
        )
        XCTAssertFalse(
            app.buttons["metric-detail-close"].exists,
            "Push navigation should not display custom sheet close button"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["metric-detail-hero"].waitForExistence(timeout: 5),
            "Recovery detail hero section should be present"
        )

        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5), "System back button should be present")
        backButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["surface-0"].waitForExistence(timeout: 8),
            "Should return to Today surface after tapping back button"
        )
    }

    func testRecoveryDetailHistoricalDateNavigation() {
        let app = launchApp(initialTab: 0)

        XCTAssertTrue(
            app.descendants(matching: .any)["surface-0"].waitForExistence(timeout: 10),
            "Today surface did not become visible"
        )
        let calendarButton = app.buttons["today-calendar-button"]
        guard calendarButton.waitForExistence(timeout: 5) else {
            return
        }
        calendarButton.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["calendar-overview-sheet"].waitForExistence(timeout: 8),
            "Calendar sheet should open"
        )
        let dayButton = app.buttons["calendar-day-1"]
        if dayButton.waitForExistence(timeout: 5) && dayButton.isHittable {
            dayButton.tap()
        } else {
            let todayButton = app.buttons["今天"]
            if todayButton.waitForExistence(timeout: 3) {
                todayButton.tap()
            }
        }

        let recoveryScore = app.descendants(matching: .any)["today-score-recovery"]
        guard recoveryScore.waitForExistence(timeout: 5) else {
            return
        }
        recoveryScore.tap()

        XCTAssertTrue(
            app.descendants(matching: .any)["metric-detail-recovery"].waitForExistence(timeout: 8),
            "Recovery detail should open for historical date"
        )
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: "/tmp/recovery-detail-historical.png"))
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.waitForExistence(timeout: 5) {
            backButton.tap()
        }
        XCTAssertTrue(
            app.descendants(matching: .any)["surface-0"].waitForExistence(timeout: 8),
            "Should return to Today surface"
        )
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
