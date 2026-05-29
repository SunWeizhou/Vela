import XCTest
@testable import Vela

final class AgentActionParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseSingleUpdateWikiAction() {
        let raw = """
        Here's my analysis of your sleep patterns.

        [ACTION:update_wiki]
        file: habits.md
        Your caffeine intake after 2 PM consistently correlates with reduced REM sleep.
        [/ACTION]

        Let me know if you'd like to discuss this further.
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].type, .updateWiki)
        XCTAssertEqual(result.actions[0].target, "habits.md")
        XCTAssertTrue(result.actions[0].content.contains("caffeine"))
        XCTAssertTrue(result.actions[0].content.contains("REM sleep"))

        // Display text should NOT contain the action block
        XCTAssertFalse(result.displayText.contains("[ACTION:update_wiki]"))
        XCTAssertFalse(result.displayText.contains("[/ACTION]"))
        XCTAssertTrue(result.displayText.contains("Here's my analysis"))
        XCTAssertTrue(result.displayText.contains("Let me know"))
    }

    func testParseMultipleActions() {
        let raw = """
        Great progress this week!

        [ACTION:update_wiki]
        file: goals.md
        New goal: increase VO2 max by 5% in 8 weeks.
        [/ACTION]

        Also noting:

        [ACTION:update_wiki]
        file: habits.md
        Consistently meditating 10 min before bed improves sleep onset.
        [/ACTION]
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 2)

        let goals = result.actions.first { $0.target == "goals.md" }
        XCTAssertNotNil(goals, "Should have goals.md action")
        XCTAssertTrue(goals?.content.contains("VO2 max") ?? false)

        let habits = result.actions.first { $0.target == "habits.md" }
        XCTAssertNotNil(habits, "Should have habits.md action")
        XCTAssertTrue(habits?.content.contains("meditating") ?? false)
    }

    func testParseNoActionReturnsOriginalText() {
        let raw = "Just a normal chat message without any wiki updates."

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 0)
        XCTAssertEqual(result.displayText.trimmingCharacters(in: .whitespacesAndNewlines), raw)
    }

    // MARK: - File: Prefix Parsing

    func testParseChineseFilePrefix() {
        let raw = """
        [ACTION:update_wiki]
        文件: habits.md
        每天喝咖啡超过3杯可能影响深度睡眠。
        [/ACTION]
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 1)
        // The parser looks for "file:" prefix, "文件:" won't match
        // This tests legacy behavior: content will target default notes.md
        XCTAssertTrue(result.actions[0].target == "notes.md" || result.actions[0].target == "habits.md")
    }

    func testParseFilePrefixCaseInsensitive() {
        let raw = """
        [ACTION:update_wiki]
        File: training_history.md
        Running frequency increased from 3x to 5x per week.
        [/ACTION]
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertEqual(result.actions[0].target, "training_history.md")
        XCTAssertTrue(result.actions[0].content.contains("Running frequency"))
    }

    // MARK: - Content Preservation

    func testContentPreservesMarkdownFormatting() {
        let raw = """
        [ACTION:update_wiki]
        file: notes.md
        ## Key Observations
        - Sleep score drops ~15 points after alcohol
        - HRV recovers within 48 hours
        - Recommend: limit to 1 drink, before 7 PM
        [/ACTION]
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 1)
        XCTAssertTrue(result.actions[0].content.contains("## Key Observations"))
        XCTAssertTrue(result.actions[0].content.contains("- Sleep score drops"))
        XCTAssertTrue(result.actions[0].content.contains("- HRV recovers"))
    }

    // MARK: - Empty or Malformed Actions

    func testMalformedNoClosingTagReturnsNoAction() {
        let raw = """
        [ACTION:update_wiki]
        file: habits.md
        This action block is missing the closing tag.
        """

        let result = AgentActionParser.parse(raw)

        // Missing closing tag means regex won't match
        XCTAssertEqual(result.actions.count, 0)
    }

    func testUnknownActionTypeIsIgnored() {
        let raw = """
        [ACTION:non_existent_action]
        Some content
        [/ACTION]
        """

        let result = AgentActionParser.parse(raw)

        XCTAssertEqual(result.actions.count, 0)
        XCTAssertTrue(result.displayText.contains("[ACTION:non_existent_action]"))
    }
}
