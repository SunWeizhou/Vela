import XCTest
@testable import Vela

final class VelaThemeTests: XCTestCase {
    func testThemeTokensReturnNonNilValues() {
        let bg = VelaTheme.bg
        let fg = VelaTheme.fg
        let cardBg = VelaTheme.cardBg
        XCTAssertNotEqual(String(describing: bg), "")
        XCTAssertNotEqual(String(describing: fg), "")
        XCTAssertNotEqual(String(describing: cardBg), "")
    }

    func testDebugInitialTabLaunchArgumentDefaultsToTodayAndClampsInvalidValues() {
        XCTAssertEqual(VelaAppState.initialTab(from: ["Vela"]), 0)
        XCTAssertEqual(VelaAppState.initialTab(from: ["Vela", "-velaInitialTab", "3"]), 3)
        XCTAssertEqual(VelaAppState.initialTab(from: ["Vela", "-velaInitialTab", "9"]), 0)
        XCTAssertEqual(VelaAppState.initialTab(from: ["Vela", "-velaInitialTab"]), 0)
    }

    func testDebugForceOnboardingLaunchArgument() {
        XCTAssertFalse(AppCoordinator.shouldForceOnboarding(arguments: ["Vela"]))
        XCTAssertTrue(AppCoordinator.shouldForceOnboarding(arguments: ["Vela", "-velaForceOnboarding"]))
    }

    func testFloatingNavigationReservesEnoughBottomContentClearance() {
        XCTAssertGreaterThanOrEqual(VelaFloatingNavigationMetrics.contentBottomPadding, 24)
        XCTAssertGreaterThanOrEqual(
            CoachChatLayout.bottomClearance(
                presentation: .embedded,
                keyboardVisible: false,
                usesOverlayNavigation: true
            ),
            112
        )
        XCTAssertEqual(
            CoachChatLayout.bottomClearance(
                presentation: .embedded,
                keyboardVisible: true,
                usesOverlayNavigation: true
            ),
            0
        )
    }

    func testLocalizedReasonTranslatesDataCoverageFallback() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        let reason = "Limited data coverage: Vela is using a conservative fallback until health or local records are available."
        let localized = localizedReason(reason)

        XCTAssertTrue(localized.contains("数据覆盖不足"))
        XCTAssertFalse(localized.contains("Limited data coverage"))
    }

    func testLocalizedWorkoutTemplateTitleMapsDefaultTemplates() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        XCTAssertEqual(localizedWorkoutTemplateTitle("Full Body"), "全身训练")
        XCTAssertEqual(localizedWorkoutTemplateTitle("Leg Day"), "腿部训练")
        XCTAssertEqual(localizedWorkoutTemplateTitle("我的自定义模板"), "我的自定义模板")
    }

    func testLocalizedMuscleGroupDoesNotExposeInternalKeysInChinese() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        XCTAssertEqual(localizedMuscleGroup("back"), "背部")
        XCTAssertEqual(localizedMuscleGroup("quads"), "股四头肌")
    }

    func testCoachArtifactTypesUseChineseTitlesInChineseMode() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        XCTAssertEqual(CoachArtifactType.morningBrief.displayTitle, "今日简报")
        XCTAssertEqual(CoachArtifactType.workoutReadiness.displayTitle, "训练准备度")
        XCTAssertEqual(CoachArtifactType.postWorkoutReview.displayTitle, "训练后复盘")
    }

    func testOnboardingStoredValuesRenderAsLocalizedLabelsAndBrief() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        XCTAssertEqual(localizedOnboardingGoal("performance"), "运动表现")
        XCTAssertEqual(localizedOnboardingGoal("muscle_gain"), "增肌塑形")
        XCTAssertEqual(localizedOnboardingTrainingStyle("hybrid"), "力量+耐力")
        XCTAssertEqual(localizedOnboardingTrainingStyle("cardio"), "有氧训练")
        XCTAssertEqual(localizedOnboardingTrainingStyle("yoga"), "瑜伽伸展")
        XCTAssertEqual(localizedOnboardingExperience("intermediate"), "有训练基础")
        XCTAssertEqual(localizedOnboardingEquipment("home_equipment"), "居家器械")
        XCTAssertEqual(localizedOnboardingCoachStyle("explanatory"), "详细解释")
        XCTAssertEqual(localizedOnboardingCoachStyle("encouraging"), "积极鼓励")

        let brief = localizedOnboardingFirstBrief(
            primaryGoal: "muscle_gain",
            trainingStyle: "strength",
            weeklyTrainingDays: 4
        )

        XCTAssertTrue(brief.contains("增肌塑形"))
        XCTAssertTrue(brief.contains("力量训练"))
        XCTAssertFalse(brief.contains("muscle_gain"))
        XCTAssertFalse(brief.contains("strength"))
    }
}
