import XCTest
@testable import Vela

final class PromptComposerTests: XCTestCase {

    private let lang = AppLanguage.stored
    private let personality = CoachPersonality.dataNerd

    func testCasualPromptIsShortAndHasNoContextJSON() {
        let composer = CoachPromptComposer(
            lang: lang,
            personality: personality,
            wikiText: "### goals.md\nRun a marathon",
            baselinePrompt: "HRV baseline: 55ms",
            activePlan: nil,
            contextJSON: "",
            correlationText: "",
            wikiFiles: "goals.md, habits.md"
        )

        let prompt = composer.compose(for: .casual)

        XCTAssertTrue(prompt.contains("2-3"), "Casual prompt should mention 2-3 sentence limit")
        XCTAssertFalse(prompt.contains("today_summary"), "Casual prompt should not contain context JSON")
        XCTAssertTrue(prompt.contains("Wiki"), "Casual prompt should mention Wiki")
    }

    func testCasualPromptIncludesDualTrackArchiveDirective() {
        let composer = CoachPromptComposer(
            lang: .english,
            personality: personality,
            wikiText: "",
            baselinePrompt: "",
            activePlan: nil,
            contextJSON: "",
            correlationText: "",
            wikiFiles: "profile.md, habits.md"
        )

        let prompt = composer.compose(for: .casual)

        XCTAssertTrue(prompt.contains("Dual-Track Archive Maintenance"))
        XCTAssertTrue(prompt.contains("single-day"))
        XCTAssertTrue(prompt.contains("update_user_wiki"))
    }

    func testFullPromptContainsAllSections() {
        let composer = CoachPromptComposer(
            lang: lang,
            personality: personality,
            wikiText: "### goals.md\nImprove sleep\n### habits.md\nNo caffeine after 2pm",
            baselinePrompt: "HRV: 55ms | RHR: 58bpm",
            activePlan: nil,
            contextJSON: "{\"today_summary\":{\"date\":\"2024-01-15\"}}",
            correlationText: "caffeine → sleep score: -8 pts",
            wikiFiles: "goals.md, habits.md, training_history.md"
        )

        let prompt = composer.compose(for: .full)

        XCTAssertTrue(prompt.contains("goals.md"), "Full prompt should include wiki content")
        XCTAssertTrue(prompt.contains("habits.md"), "Full prompt should include all wiki files")
        XCTAssertTrue(prompt.contains("today_summary"), "Full prompt should include context JSON")
        XCTAssertTrue(prompt.contains("HRV"), "Full prompt should include baselines")
        XCTAssertTrue(prompt.contains("caffeine"), "Full prompt should include correlation insights")
    }

    func testFocusedPromptStartsWithConciseDirective() {
        let composer = CoachPromptComposer(
            lang: lang,
            personality: personality,
            wikiText: "",
            baselinePrompt: "",
            activePlan: nil,
            contextJSON: "{}",
            correlationText: "",
            wikiFiles: ""
        )

        let prompt = composer.compose(for: .focused)

        XCTAssertTrue(
            prompt.contains("CONCISE") || prompt.contains("极简"),
            "Focused prompt should start with concise directive"
        )
        XCTAssertTrue(prompt.contains("150"), "Focused prompt should mention 150-word limit")
    }

    func testResponseLengthPolicyClassifiesCorrectly() {
        XCTAssertEqual(ResponseLengthPolicy.forQuery("Hi", lang: .english), .casual)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("你好", lang: .chinese), .casual)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("谢谢", lang: .chinese), .casual)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("分析今天的数据", lang: .chinese), .full)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("daily report please", lang: .english), .full)
        XCTAssertEqual(ResponseLengthPolicy.forQuery("Should I train today?", lang: .english), .focused)
    }

    func testNeedsWebSearchDetectsResearchQueries() {
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("最新研究表明"))
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("latest research on sleep"))
        XCTAssertTrue(ResponseLengthPolicy.needsWebSearch("what is the benefit of magnesium"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("Hi"))
        XCTAssertFalse(ResponseLengthPolicy.needsWebSearch("今天适合训练吗"))
    }

    func testPromptWithActiveTrainingPlan() {
        let plan = TrainingPlanRecord(
            title: "4-Week Strength Builder",
            goalDescription: "Build upper body strength",
            weeksCount: 4,
            days: [
                TrainingDay(weekNumber: 1, dayNumber: 1, title: "Push Day", description: "Bench press 5x5", focus: "strength", durationMinutes: 60, intensity: "high"),
                TrainingDay(weekNumber: 1, dayNumber: 2, title: "Rest", description: "Active recovery", focus: "rest", durationMinutes: 0, intensity: "low")
            ]
        )

        let composer = CoachPromptComposer(
            lang: lang,
            personality: personality,
            wikiText: "",
            baselinePrompt: "",
            activePlan: plan,
            contextJSON: "{}",
            correlationText: "",
            wikiFiles: ""
        )

        let prompt = composer.compose(for: .full)

        XCTAssertTrue(prompt.contains("4-Week Strength Builder"), "Prompt should include active plan title")
        XCTAssertTrue(prompt.contains("Push Day"), "Prompt should include training day details")
    }
}
