import XCTest
@testable import App

final class PromptServiceTests: XCTestCase {
    func testCoachPromptIncludesGlobalHealthAndMemoryConstraints() {
        let prompt = PromptService.coachSystemPrompt(lang: "zh")

        XCTAssertTrue(prompt.contains("HRV"))
        XCTAssertTrue(prompt.contains("ATL"))
        XCTAssertTrue(prompt.contains("CTL"))
        XCTAssertTrue(prompt.contains("TSB"))
        XCTAssertTrue(prompt.contains("今日运动列表"))
        XCTAssertTrue(prompt.contains("propose_memory"))
    }

    func testCoachToolsExposeMemoryAndTrainingActions() {
        XCTAssertEqual(
            Set(LLMService.coachTools.map(\.name)),
            Set(["propose_memory", "suggest_training", "web_search"])
        )
    }

    func testCoachPromptToolReferencesAreRegistered() {
        let prompt = PromptService.coachSystemPrompt(lang: "zh")
        let registeredToolNames = Set(LLMService.coachTools.map(\.name))

        for toolName in ["propose_memory", "suggest_training", "web_search"] {
            XCTAssertTrue(prompt.contains(toolName), "Prompt should mention \(toolName).")
            XCTAssertTrue(registeredToolNames.contains(toolName), "\(toolName) should be registered in LLMService.coachTools.")
        }
    }
}
