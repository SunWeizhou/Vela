import XCTest
@testable import Vela

final class WikiMergeTests: XCTestCase {

    // Use a less critical filename for merge tests — notes.md is a real user doc
    // but in test environment (simulator) it's a fresh sandbox, so this is safe.
    // We still use setUp/tearDown to keep the file clean between tests.
    private let testFile = "notes.md"

    override func setUp() {
        super.setUp()
        try? WikiFileService.updateSection(filename: testFile, content: "# Test\n\n", mode: .replace)
    }

    override func tearDown() {
        try? WikiFileService.updateSection(filename: testFile, content: "", mode: .replace)
        super.tearDown()
    }

    // MARK: - Levenshtein Dedup

    func testLevenshteinExactDuplicateIsRejected() {
        let content = "Caffeine after 2 PM consistently reduces REM sleep duration."
        try? WikiFileService.updateSection(filename: testFile, content: content, mode: .replace)
        try? WikiFileService.updateSection(filename: testFile, content: content, mode: .merge)

        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        let occurrences = fileContent.components(separatedBy: "reduces REM sleep").count - 1
        XCTAssertEqual(occurrences, 1, "Exact duplicate paragraph should not be merged")
    }

    func testLevenshteinSimilarContentIsDeduped() {
        let original = "Caffeine after 2 PM reduces REM sleep duration."
        try? WikiFileService.updateSection(filename: testFile, content: original, mode: .replace)

        let similar = "Caffeine after 2 PM reduces REM sleep duration"
        try? WikiFileService.updateSection(filename: testFile, content: similar, mode: .merge)

        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        let occurrences = fileContent.components(separatedBy: "reduces REM").count - 1
        XCTAssertEqual(occurrences, 1, "Similar paragraph should be deduplicated")
    }

    func testDifferentContentIsMerged() {
        let original = "User runs 3 times per week."
        try? WikiFileService.updateSection(filename: testFile, content: original, mode: .replace)

        let different = "User started swimming twice weekly for cross-training."
        try? WikiFileService.updateSection(filename: testFile, content: different, mode: .merge)

        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        XCTAssertTrue(fileContent.contains("runs 3 times"), "Original content should remain")
        XCTAssertTrue(fileContent.contains("swimming twice"), "New different content should be added")
    }

    func testSubstringContainedInExistingIsDeduped() {
        let existing = "User prefers morning workouts between 6-8 AM for optimal energy."
        try? WikiFileService.updateSection(filename: testFile, content: existing, mode: .replace)

        let subset = "morning workouts between 6-8 AM"
        try? WikiFileService.updateSection(filename: testFile, content: subset, mode: .merge)

        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        let occurrences = fileContent.components(separatedBy: "morning workouts").count - 1
        XCTAssertEqual(occurrences, 1, "Substring should not create a duplicate")
    }

    func testUnknownFileIsRejected() {
        let unknownFile = "does_not_exist.md"
        try? WikiFileService.updateSection(filename: unknownFile, content: "test", mode: .merge)
        let dict = WikiFileService.loadDictionary()
        XCTAssertNil(dict[unknownFile], "Unknown file should not appear in dictionary")
    }
}

final class DailyLogServiceTests: XCTestCase {

    func testRefreshPreservesConversationAndWritesFullBodySnapshot() throws {
        let date = Date(timeIntervalSince1970: 0)
        let fileURL = DailyLogService.url(for: date)
        try? FileManager.default.removeItem(at: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let dashboard = DashboardSummary.preview(date: date)
        try DailyLogService.recordInteraction(
            dashboard: dashboard,
            userText: "I slept poorly last night.",
            assistantText: "Keep today's training light.",
            date: date,
            wikiUpdates: ["habits.md"],
            coachArchiveSummary: "Coach proposed a durable caffeine cutoff preference."
        )
        try DailyLogService.refresh(dashboard: dashboard, date: date)

        let text = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(text.contains("I slept poorly last night."))
        XCTAssertTrue(text.contains("Keep today's training light."))
        XCTAssertTrue(text.contains("\"extendedMetrics\""))
        XCTAssertTrue(text.contains("\"recoveryMetrics\""))
        XCTAssertTrue(text.contains("\"workouts\""))
        XCTAssertTrue(text.contains("habits.md"))
        XCTAssertTrue(text.contains("durable caffeine cutoff preference"))
    }
}
