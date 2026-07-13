import XCTest
import SwiftData
@testable import Vela

final class WikiMergeTests: XCTestCase {
    func testDeletingLocalWikiRemovesTheEntireFileBackedMemoryDirectory() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VelaWikiDeletion-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("profile".utf8).write(to: root.appending(path: "profile.md"))
        try Data("future".utf8).write(to: root.appending(path: "future-memory.md"))

        let deleted = try WikiFileService.deleteLocalDocuments(at: root)

        XCTAssertEqual(deleted, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testStructuredFieldReplacementPreservesExistingMemorySections() {
        let original = """
        # 个人档案

        - Age: 29
        - Activity level: moderate

        ## Updated 2026-06-05T08:00:00Z

        - 长期规律：大重量腿部训练后的第二天 HRV 容易下降。
        """

        let updated = WikiFileService.replacingStructuredFields(
            in: original,
            title: "个人档案",
            fieldValues: [
                "Age": "31",
                "Activity level": "high"
            ],
            preferredOrder: ["Age", "Activity level", "Primary sports"]
        )

        XCTAssertTrue(updated.contains("- Age: 31"))
        XCTAssertTrue(updated.contains("- Activity level: high"))
        XCTAssertTrue(updated.contains("- Primary sports:"))
        XCTAssertTrue(updated.contains("## Updated 2026-06-05T08:00:00Z"))
        XCTAssertTrue(updated.contains("大重量腿部训练后的第二天 HRV 容易下降"))
        XCTAssertFalse(updated.contains("- Age: 29"))
    }

    @MainActor
    func testWikiSyncTreatsMarkdownFileAsCanonicalSource() throws {
        let url = WikiFileService.localURL(for: "profile.md")
        let original = try? String(contentsOf: url, encoding: .utf8)
        defer {
            if let original {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? original.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let canonical = """
        # Profile

        - Age: 31

        ## Updated 2026-06-05T08:00:00Z

        - Confirmed long-term preference.
        """

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try canonical.write(to: url, atomically: true, encoding: .utf8)

        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let stale = UserWikiDocumentRecord(
            filename: "profile.md",
            title: "旧缓存",
            markdownContent: "# Stale\n\n- Age: 20\n",
            updatedAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(stale)
        try context.save()

        WikiSyncManager.sync(modelContext: context)

        let records = try context.fetch(FetchDescriptor<UserWikiDocumentRecord>())
        let profile = try XCTUnwrap(records.first { $0.filename == "profile.md" })
        XCTAssertEqual(profile.markdownContent, canonical)
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), canonical)
    }
}
