import XCTest
@testable import Vela

final class WikiMergeTests: XCTestCase {

    // Use a valid wiki filename that the WikiFileService allows
    private let testFile = "notes.md"

    override func setUp() {
        super.setUp()
        // Clear the test file before each test
        try? WikiFileService.updateSection(filename: testFile, content: "", mode: .replace)
    }

    override func tearDown() {
        // Clean up after each test
        try? WikiFileService.updateSection(filename: testFile, content: "", mode: .replace)
        super.tearDown()
    }

    // MARK: - Levenshtein Dedup

    func testLevenshteinExactDuplicateIsRejected() {
        let content = "Caffeine after 2 PM consistently reduces REM sleep duration."
        try? WikiFileService.updateSection(filename: testFile, content: content, mode: .replace)

        // Try to merge the exact same content
        try? WikiFileService.updateSection(filename: testFile, content: content, mode: .merge)

        // The file should only contain the original content once
        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        let occurrences = fileContent.components(separatedBy: "reduces REM sleep").count - 1
        XCTAssertEqual(occurrences, 1, "Exact duplicate paragraph should not be merged")
    }

    func testLevenshteinSimilarContentIsDeduped() {
        let original = "Caffeine after 2 PM reduces REM sleep duration."
        try? WikiFileService.updateSection(filename: testFile, content: original, mode: .replace)

        // Very similar content (missing period, 93% similar)
        let similar = "Caffeine after 2 PM reduces REM sleep duration"
        try? WikiFileService.updateSection(filename: testFile, content: similar, mode: .merge)

        let dict = WikiFileService.loadDictionary()
        let fileContent = dict[testFile] ?? ""
        // Should be deduped because similarity > 0.85
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

    // MARK: - Substring Dedup

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

    // MARK: - Unknown File Rejection

    func testUnknownFileIsRejected() {
        let unknownFile = "does_not_exist.md"
        try? WikiFileService.updateSection(filename: unknownFile, content: "test", mode: .merge)
        let dict = WikiFileService.loadDictionary()
        XCTAssertNil(dict[unknownFile], "Unknown file should not be created")
    }
}
