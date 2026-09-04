import XCTest
import SwiftData
@testable import Vela

/// SwiftData 版本化 schema 演进回归测试。
///
/// 审计 (docs/validation/engineering-audit-2026-08-23.md C1) 发现：一旦 @Model
/// 字段变更而未升版本，存量 store 会报告 unknown model version 并落入只读安全模式。
/// 当前 migration plan 的 V1/V2 均指向独立 frozen graph，V3 指向 live graph；
/// scripts/schema_fingerprint.py --check 会在任何图形漂移时 fail-closed。
///
/// 本文件验证：
///   1. 当前构建写出的 store 重开无损（无回归）；
///   2. V1/V2 pinned disk fixtures 可走完整迁移链且保留行值；
///   3. 版本标识单调递增，历史 entity inventory 与 live/frozen 图满足 release contract。
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

    /// Creates a deterministic V1 store from the pinned historical graph, then
    /// opens it with the production migration plan.  This is a real SwiftData
    /// disk store (not an in-memory schema comparison); the source schema and
    /// row values are recorded in Fixtures/SchemaMigration/v1-v2-fixture-manifest.json.
    /// It proves the migration wiring, but does not claim compatibility with
    /// an arbitrary pre-release store whose binary is not available here.
    @MainActor
    func testPinnedV1DiskFixtureMigratesToCurrentSchema() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("pinned-v1.store")
        let historicalSchema = Schema(VelaSchemaV1Frozen.models)
        let historicalConfig = ModelConfiguration(schema: historicalSchema, url: storeURL)
        let historical = try ModelContainer(
            for: historicalSchema,
            configurations: [historicalConfig]
        )
        let historicalContext = ModelContext(historical)
        let dayID = "fixture-v1-20260904"
        let oldRecord = VelaSchemaV1Frozen.DailyHealthSummaryRecord(
            dayIdentifier: dayID,
            date: Date(timeIntervalSince1970: 1_788_480_000),
            sleepScore: 72.5,
            recoveryScore: 61.25,
            configVersion: "fixture-v1",
            schemaVersion: 1,
            updatedAt: Date(timeIntervalSince1970: 1_788_480_000),
            createdAt: Date(timeIntervalSince1970: 1_788_480_000)
        )
        historicalContext.insert(oldRecord)
        try historicalContext.save()

        let migrated = try VelaModelContainer.make(at: storeURL)
        let migratedContext = ModelContext(migrated)
        let fetched = try migratedContext.fetch(
            FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate { $0.dayIdentifier == dayID }
            )
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sleepScore, 72.5)
        XCTAssertEqual(fetched.first?.recoveryScore, 61.25)
        XCTAssertNil(fetched.first?.hrvRmssdMilliseconds)
    }

    /// Same disk-fixture check starting at V2.  Keeping this separate makes a
    /// failure in either migration stage immediately attributable.
    @MainActor
    func testPinnedV2DiskFixtureMigratesToCurrentSchema() throws {
        let dir = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let storeURL = dir.appendingPathComponent("pinned-v2.store")
        let historicalSchema = Schema(VelaSchemaV2Frozen.models)
        let historicalConfig = ModelConfiguration(schema: historicalSchema, url: storeURL)
        let historical = try ModelContainer(
            for: historicalSchema,
            configurations: [historicalConfig]
        )
        let historicalContext = ModelContext(historical)
        let dayID = "fixture-v2-20260904"
        let oldRecord = VelaSchemaV2Frozen.DailyHealthSummaryRecord(
            dayIdentifier: dayID,
            date: Date(timeIntervalSince1970: 1_788_480_000),
            sleepScore: 83.25,
            recoveryScore: 77.75,
            configVersion: "fixture-v2",
            schemaVersion: 2,
            updatedAt: Date(timeIntervalSince1970: 1_788_480_000),
            createdAt: Date(timeIntervalSince1970: 1_788_480_000)
        )
        oldRecord.scoreEvidenceData = Data("fixture-v2-evidence".utf8)
        historicalContext.insert(oldRecord)
        try historicalContext.save()

        let migrated = try VelaModelContainer.make(at: storeURL)
        let migratedContext = ModelContext(migrated)
        let fetched = try migratedContext.fetch(
            FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate { $0.dayIdentifier == dayID }
            )
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.sleepScore, 83.25)
        XCTAssertEqual(fetched.first?.recoveryScore, 77.75)
        XCTAssertEqual(fetched.first?.scoreEvidenceData, Data("fixture-v2-evidence".utf8))
        XCTAssertNil(fetched.first?.hrvRmssdMilliseconds)
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

    func testHistoricalFrozenInventoriesMatchReleaseContract() {
        XCTAssertEqual(Schema(VelaSchemaV1Frozen.models).entities.count, 31)
        XCTAssertEqual(Schema(VelaSchemaV2Frozen.models).entities.count, 32)
        XCTAssertFalse(
            Schema(VelaSchemaV1Frozen.models).entities.contains {
                $0.name == "IntradaySignalBucketRecord"
            }
        )
        XCTAssertTrue(
            Schema(VelaSchemaV2Frozen.models).entities.contains {
                $0.name == "IntradaySignalBucketRecord"
            }
        )
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("VelaSchemaMigration-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
