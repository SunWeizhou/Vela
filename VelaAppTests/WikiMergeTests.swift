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

    // MARK: - 健康档案空白修复（模板污染 / 中文解析 / 生理档案互通）

    @MainActor
    func testSyncDoesNotWriteEmptyTemplatesToDisk() throws {
        try withRestoredWikiFiles(["constraints.md", "diet.md"]) {
            let url = WikiFileService.localURL(for: "constraints.md")
            try? FileManager.default.removeItem(at: url)

            let container = try VelaModelContainer.make(inMemory: true)
            WikiSyncManager.sync(modelContext: container.mainContext)

            XCTAssertFalse(
                FileManager.default.fileExists(atPath: url.path),
                "sync 不得把空模板落盘，否则 materializer 会把模板误判为已写入、档案永远无法初始化"
            )
            let records = try container.mainContext.fetch(FetchDescriptor<UserWikiDocumentRecord>())
            let constraints = try XCTUnwrap(records.first { $0.filename == "constraints.md" })
            XCTAssertEqual(constraints.markdownContent, WikiFileService.defaultContent(for: "constraints.md"))
        }
    }

    @MainActor
    func testIsUninitializedTreatsTemplateAsEmpty() throws {
        try withRestoredWikiFiles(["profile.md"]) {
            let url = WikiFileService.localURL(for: "profile.md")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try WikiFileService.defaultContent(for: "profile.md").write(to: url, atomically: true, encoding: .utf8)
            XCTAssertTrue(WikiFileService.isUninitialized("profile.md"))

            try "# Profile\n\n- Age: 29\n".write(to: url, atomically: true, encoding: .utf8)
            XCTAssertFalse(WikiFileService.isUninitialized("profile.md"))
        }
    }

    @MainActor
    func testMaterializerReplacesPoisonedTemplate() throws {
        try withRestoredWikiFiles(["profile.md", "preferences.md", "habits.md", "training_history.md"]) {
            try withCleanProfileDefaults {
                let url = WikiFileService.localURL(for: "profile.md")
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                // 历史版本 sync 曾把空模板落盘（污染），materializer 必须覆盖它。
                try WikiFileService.defaultContent(for: "profile.md").write(to: url, atomically: true, encoding: .utf8)

                let container = try VelaModelContainer.make(inMemory: true)
                container.mainContext.insert(OnboardingState(
                    goalProfile: UserGoalProfile(
                        primaryGoal: "fat_loss",
                        secondaryGoals: ["health"],
                        experienceLevel: "intermediate"
                    ),
                    trainingPreference: TrainingPreferenceProfile(
                        trainingStyle: "strength",
                        weeklyTrainingDays: 4,
                        sessionDurationMinutes: 60
                    ),
                    equipmentProfile: EquipmentProfile(equipment: ["gym"]),
                    coachingPreference: CoachingPreference(style: "direct")
                ))
                try container.mainContext.save()

                WikiProfileMaterializer.materializeIfNeeded(modelContext: container.mainContext)

                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(content.contains("主要目标: 减脂"), content)
                XCTAssertTrue(content.contains("经验水平: 中级"), content)
                XCTAssertFalse(content.contains("- Age:"), "空英文模板应被真实内容替换: \(content)")
            }
        }
    }

    @MainActor
    func testMaterializerPreservesUserEditedProfile() throws {
        try withRestoredWikiFiles(["profile.md", "preferences.md", "habits.md", "training_history.md"]) {
            try withCleanProfileDefaults {
                let url = WikiFileService.localURL(for: "profile.md")
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try "# Profile\n\n- Age: 29\n- 自己写的备注: 旧伤\n".write(to: url, atomically: true, encoding: .utf8)

                let container = try VelaModelContainer.make(inMemory: true)
                container.mainContext.insert(OnboardingState(
                    goalProfile: UserGoalProfile(primaryGoal: "muscle_gain", experienceLevel: "advanced")
                ))
                try container.mainContext.save()

                WikiProfileMaterializer.materializeIfNeeded(modelContext: container.mainContext)

                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(content.contains("- Age: 29"))
                XCTAssertTrue(content.contains("旧伤"))
                XCTAssertFalse(content.contains("主要目标"), "用户手改内容不得被覆盖: \(content)")
            }
        }
    }

    @MainActor
    func testPhysiologicalProfileRefreshMergesIntoWiki() throws {
        try withRestoredWikiFiles(["profile.md"]) {
            try withCleanProfileDefaults {
                let url = WikiFileService.localURL(for: "profile.md")
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try "# 个人档案\n\n- 年龄: 30\n- 自定义备注: 保持\n".write(to: url, atomically: true, encoding: .utf8)

                let defaults = UserDefaults.standard
                defaults.set(32, forKey: UserProfileSettings.ageKey)
                defaults.set(175.0, forKey: UserProfileSettings.heightKey)
                defaults.set(72.5, forKey: UserProfileSettings.weightKey)
                defaults.set(188, forKey: UserProfileSettings.maxHeartRateKey)
                defaults.set("male", forKey: UserProfileSettings.biologicalSexKey)

                WikiProfileMaterializer.refreshPhysiologicalProfile(defaults: defaults)

                let content = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(content.contains("- 年龄: 32"), content)
                XCTAssertTrue(content.contains("- 身高: 175 cm"), content)
                XCTAssertTrue(content.contains("- 体重: 72.5 kg"), content)
                XCTAssertTrue(content.contains("- 最大心率: 188 bpm"), content)
                XCTAssertTrue(content.contains("- 性别: 男"), content)
                XCTAssertTrue(content.contains("- 自定义备注: 保持"), content)
                XCTAssertFalse(content.contains("- 年龄: 30"), content)

                // UserDefaults 无手动值时，保留既有行不动。
                defaults.removeObject(forKey: UserProfileSettings.ageKey)
                WikiProfileMaterializer.refreshPhysiologicalProfile(defaults: defaults)
                let after = try String(contentsOf: url, encoding: .utf8)
                XCTAssertTrue(after.contains("- 年龄: 32"), after)
            }
        }
    }

    func testBulletParserHandlesChineseAndEnglishLabels() {
        let content = """
        # 个人档案

        - 主要目标: 减脂
        - 年龄：32
        - Age: 32
        - 训练风格: 力量训练
        """
        let fields = WikiBulletParser.parseFields(in: content, templateLabels: ["Age", "Activity level"])
        XCTAssertEqual(fields.map(\.label), ["主要目标", "年龄", "Age", "训练风格"])
        XCTAssertEqual(fields.map(\.value), ["减脂", "32", "32", "力量训练"])
    }

    func testBulletParserFallsBackToTemplateWhenEmpty() {
        let fields = WikiBulletParser.parseFields(in: "# Profile\n\nnothing here\n", templateLabels: ["Age", "Health goals"])
        XCTAssertEqual(fields.map(\.label), ["Age", "Health goals"])
        XCTAssertTrue(fields.allSatisfy { $0.value.isEmpty })
    }

    // MARK: - 测试隔离辅助

    @MainActor
    private func withRestoredWikiFiles(
        _ filenames: [String],
        _ body: @MainActor () throws -> Void
    ) rethrows {
        var originals: [(url: URL, data: Data?)] = []
        for name in filenames {
            let url = WikiFileService.localURL(for: name)
            originals.append((url, try? Data(contentsOf: url)))
        }
        defer {
            for (url, data) in originals {
                if let data {
                    try? FileManager.default.createDirectory(
                        at: url.deletingLastPathComponent(),
                        withIntermediateDirectories: true
                    )
                    try? data.write(to: url)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
        try body()
    }

    @MainActor
    private func withCleanProfileDefaults(_ body: @MainActor () throws -> Void) rethrows {
        let keys = [
            UserProfileSettings.ageKey,
            UserProfileSettings.weightKey,
            UserProfileSettings.heightKey,
            UserProfileSettings.maxHeartRateKey,
            UserProfileSettings.biologicalSexKey
        ]
        let defaults = UserDefaults.standard
        var originals: [String: Any?] = [:]
        for key in keys {
            originals[key] = defaults.object(forKey: key)
            defaults.removeObject(forKey: key)
        }
        defer {
            for (key, value) in originals {
                if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        try body()
    }
}
