import XCTest
import SwiftData
@testable import Vela

/// SwiftData 版本化 schema 演进回归测试。
///
/// 审计 (docs/validation/engineering-audit-2026-08-23.md C1) 发现：VelaSchemaV3 直接
/// 指向 live 模型类型且无任何守卫，一旦 @Model 字段变更而未升版本，存量 store 会
/// 报告 unknown model version 并落入只读安全模式。
///
/// 修复后的机制（经验证）：
///   - SwiftData 拒绝同一迁移计划中 checksum 相同的两个 schema
///     （Duplicate version checksums），且当前模型图自 V3 起未变（三个新字段都在
///     DTO/struct 上），因此不引入重复图形的新版本；
///   - 冻结快照（VelaSchemaV3Frozen）作为「下次模型变更时的迁移源」预案，
///     由 scripts/schema_fingerprint.py --check 强制：模型一变，守卫先失败，
///     直到按 VelaModelContainer 中的注释完成版本提升流程——即变更与版本提升
///     在同一提交内原子完成，不存在「改了字段断了存库」的窗口。
///
/// 本文件验证：
///   1. 当前构建写出的 store 重开无损（无回归）；
///   2. 版本标识单调递增；
///   3. 冻结快照实体名集合与 live 图形一致（它是合法的迁移源 schema 的前提）。
final class SchemaMigrationTests: XCTestCase {

    @MainActor
    func testCurrentEraStoreReopensIntact() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("current.store")

        let container = try VelaModelContainer.make(at: storeURL)
        let context = ModelContext(container)
        let dayID = "migration-current-\(UUID().uuidString)"
        let record = DailyHealthSummaryRecord(
            dayIdentifier: dayID,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
        record.sleepScore = 55.0
        context.insert(record)
        try context.save()

        let reopened = try VelaModelContainer.make(at: storeURL)
        let reopenedContext = ModelContext(reopened)
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate { $0.dayIdentifier == dayID }
        )
        let fetched = try reopenedContext.fetch(descriptor)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sleepScore, 55.0)
    }

    func testVersionIdentifiersIncreaseMonotonically() {
        let versions: [Schema.Version] = [
            VelaSchemaV1.versionIdentifier,
            VelaSchemaV2.versionIdentifier,
            VelaSchemaV3.versionIdentifier
        ]
        for i in 1..<versions.count {
            XCTAssertLessThanOrEqual(
                versions[i - 1], versions[i],
                "版本标识必须单调递增（当前 schema 变更时请按 VelaModelContainer 注释做版本提升）"
            )
        }
    }

    func testFrozenSnapshotEntityNamesMatchLiveGraph() {
        // 冻结快照与 live 图形共享同一批实体名（生成时逐属性一致），
        // 这使它在模型变更时能作为迁移源 schema 精确匹配存量 store。
        let liveNames = Set(
            Schema(VelaSchemaV3.models).entities.map(\.name)
        )
        let frozenNames = Set(
            Schema(VelaSchemaV3Frozen.models).entities.map(\.name)
        )
        XCTAssertEqual(
            liveNames, frozenNames,
            "冻结快照的实体集合必须与 live 图形一致；生成器或模型变更后请重新 --emit-frozen"
        )
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VelaSchemaMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
