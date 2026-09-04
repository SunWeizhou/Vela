import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "ModelContainer")

enum VelaModelContainer {
    static let modelTypes: [any PersistentModel.Type] = [
        DailyHealthSummaryRecord.self,
        IntradaySignalBucketRecord.self,
        SleepSummaryRecord.self,
        JournalEntryRecord.self,
        CoachInteractionRecord.self,
        AIReportRecord.self,
        UserWikiDocumentRecord.self,
        CoachSessionRecord.self,
        OnboardingState.self,
        CoachArtifactRecord.self,
        FoodLogRecord.self,
        StrengthWorkoutRecord.self,
        ActiveWorkoutDraftRecord.self,
        ExerciseDefinitionRecord.self,
        WorkoutTemplateRecord.self,
        TrainingResponseRecord.self,
        TrainingPlanRecord.self,
        BiomarkerRecord.self,
        MemoryEventRecord.self,
        AgentRunRecord.self,
        DailyOperatingPlanRecord.self,
        DailyDecisionFeedbackRecord.self,
        PersonalExperimentRecord.self,
        ExperimentCheckInRecord.self,
        AgentArtifactRecord.self,
        TrainingPlanAdaptationRecord.self,
        WorkoutEventRecord.self,
        XunjiDailyCacheRecord.self,
        XunjiWorkoutMirrorRecord.self,
        DeletedWorkoutRecord.self,
        VelaEventRecord.self,
        ProactiveInsightRecord.self
    ]
    static let schema = Schema(VelaSchemaV3.models)

    /// App 生命周期内已创建的容器（VelaApp.init 注入）。
    /// 后台任务（BGAppRefreshTask）优先复用，避免每次后台刷新都重建容器——
    /// 打开 store + 迁移检查既有主线程成本，又挤占 BG ~30s 预算（审计 H3）。
    @MainActor
    static var activeContainer: ModelContainer?

    private static let storeURL: URL = {
        let base = URL.applicationSupportDirectory
        return base.appending(path: "Vela.store")
    }()

    private static let legacyStoreURLs: [URL] = {
        let base = URL.applicationSupportDirectory
        let defaultStore = base.appending(path: "default.store")
        return [defaultStore]
    }()

    @discardableResult
    static func backupStoreFiles(
        at storeURL: URL,
        recoveryRoot: URL,
        timestamp: Date = Date(),
        fileManager: FileManager = .default
    ) throws -> URL? {
        let sourceURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        let existingSources = sourceURLs.filter {
            fileManager.fileExists(atPath: $0.path)
        }
        guard !existingSources.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let backupDirectory = recoveryRoot.appending(
            path: formatter.string(from: timestamp),
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )
        for source in existingSources {
            let destination = backupDirectory.appending(path: source.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
        }
        return backupDirectory
    }

    /// 删除 VelaRecovery 恢复备份目录（含被备份的 store 文件副本）。
    /// 「清空 Vela 本地数据」必须覆盖此目录，否则数据副本随 iCloud 备份离机（审计 H7）。
    /// - Returns: 删除的备份条目数量；目录不存在时返回 0。
    static func deleteRecoveryBackups(
        at root: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> Int {
        let resolvedRoot = root ?? URL.applicationSupportDirectory
            .appending(path: "VelaRecovery", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: resolvedRoot.path) else { return 0 }
        let contents = try fileManager.contentsOfDirectory(
            at: resolvedRoot,
            includingPropertiesForKeys: nil
        )
        try fileManager.removeItem(at: resolvedRoot)
        return contents.count
    }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(
                for: schema,
                migrationPlan: VelaMigrationPlan.self,
                configurations: [config]
            )
        }

        do {
            return try make(at: storeURL)
        } catch {
            let recoveryRoot = URL.applicationSupportDirectory
                .appending(path: "VelaRecovery", directoryHint: .isDirectory)
            do {
                if let backup = try backupStoreFiles(
                    at: storeURL,
                    recoveryRoot: recoveryRoot
                ) {
                    logger.error("Store open failed. Recovery backup created at \(backup.path, privacy: .public)")
                }
                for legacyURL in legacyStoreURLs {
                    if let backup = try backupStoreFiles(
                        at: legacyURL,
                        recoveryRoot: recoveryRoot
                    ) {
                        logger.error("Legacy store backup created at \(backup.path, privacy: .public)")
                    }
                }
            } catch {
                logger.error("Failed to create store recovery backup: \(error.localizedDescription)")
            }
            throw error
        }
    }

    static func make(at storeURL: URL) throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, url: storeURL)
        return try ModelContainer(
            for: schema,
            migrationPlan: VelaMigrationPlan.self,
            configurations: [config]
        )
    }
}

enum VelaSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    // Source compatibility for existing migration fixtures. This is an alias
    // to the immutable historical type, never to a production @Model class.
    typealias DailyHealthSummaryRecord = VelaSchemaV1Frozen.DailyHealthSummaryRecord

    /// The historical graph is defined in VelaSchemaV1Frozen.swift. Keeping
    /// this wrapper free of production model references is what makes the
    /// migration checksum independent from future @Model edits.
    static var models: [any PersistentModel.Type] {
        VelaSchemaV1Frozen.models
    }
}

enum VelaSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    // Source compatibility for existing migration fixtures. This is an alias
    // to the immutable historical type, never to a production @Model class.
    typealias DailyHealthSummaryRecord = VelaSchemaV2Frozen.DailyHealthSummaryRecord

    /// The historical graph is defined in VelaSchemaV2Frozen.swift. The
    /// daily summary differs from V1 only by scoreEvidenceData; all other
    /// classes come from the fingerprint-guarded immutable V3 snapshot.
    static var models: [any PersistentModel.Type] {
        VelaSchemaV2Frozen.models
    }
}

/// 当前（live）模型图所属的版本化 schema。
///
/// SwiftData 版本演进规则（必须遵守，`scripts/schema_fingerprint.py --check` 会强制）：
///   1. 当前 VersionedSchema 必须引用 live 模型类型（本枚举）；历史版本应引用
///      VelaSchemaV1Frozen/VelaSchemaV2Frozen 的冻结副本。注意：SwiftData 拒绝在同一迁移计划中
///      出现两个 checksum 相同的 schema（Duplicate version checksums）——所以
///      不要为「图形未变」的版本号单独建版本。
///   2. 任何 @Model 字段/注解变更 → 先把变更前的图形冻结为 VelaSchemaV3Frozen
///      （`python3 scripts/schema_fingerprint.py --emit-frozen`），再把冻结类升级为
///      VersionedSchema、新建 live 的 VelaSchemaV4、补 `.lightweight` stage、
///      最后 `--update` 更新黄金快照——全部在同一个提交内完成。
///   3. 冻结副本禁止手工修改。
enum VelaSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)
    static var models: [any PersistentModel.Type] {
        VelaModelContainer.modelTypes
    }
}

enum VelaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VelaSchemaV1.self, VelaSchemaV2.self, VelaSchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: VelaSchemaV1.self, toVersion: VelaSchemaV2.self),
            .lightweight(fromVersion: VelaSchemaV2.self, toVersion: VelaSchemaV3.self)
        ]
    }
}

struct RetentionPolicyService {
    struct Result: Equatable {
        var agentRuns = 0
        var agentArtifacts = 0
        var coachArtifacts = 0
        var xunjiCaches = 0
        var aiReports = 0
        var coachInteractions = 0
        var productEvents = 0
        var memoryEvents = 0
        var proactiveInsights = 0
    }

    var agentRunDays = 30
    var agentArtifactDays = 90
    var coachArtifactDays = 180
    var coachInteractionDays = 90
    var productEventDays = 180
    var memoryEventDays = 90
    var xunjiCacheDays = 7

    @MainActor
    func prune(modelContext: ModelContext, now: Date = Date()) throws -> Result {
        var result = Result()
        let agentRunCutoff = now.addingTimeInterval(-Double(agentRunDays) * 86_400)
        let agentArtifactCutoff = now.addingTimeInterval(-Double(agentArtifactDays) * 86_400)
        let coachArtifactCutoff = now.addingTimeInterval(-Double(coachArtifactDays) * 86_400)
        let xunjiCacheCutoff = now.addingTimeInterval(-Double(xunjiCacheDays) * 86_400)

        let oldRuns = try modelContext.fetch(FetchDescriptor<AgentRunRecord>(
            predicate: #Predicate { $0.startedAt < agentRunCutoff }
        ))
        oldRuns.forEach(modelContext.delete)
        result.agentRuns = oldRuns.count

        let oldAgentArtifacts = try modelContext.fetch(FetchDescriptor<AgentArtifactRecord>(
            predicate: #Predicate { $0.createdAt < agentArtifactCutoff }
        ))
        oldAgentArtifacts.forEach(modelContext.delete)
        result.agentArtifacts = oldAgentArtifacts.count

        let protectedStatus = CoachArtifactStatus.acted.rawValue
        let oldCoachArtifacts = try modelContext.fetch(FetchDescriptor<CoachArtifactRecord>(
            predicate: #Predicate {
                $0.createdAt < coachArtifactCutoff && $0.status != protectedStatus
            }
        ))
        oldCoachArtifacts.forEach(modelContext.delete)
        result.coachArtifacts = oldCoachArtifacts.count

        let oldCaches = try modelContext.fetch(FetchDescriptor<XunjiDailyCacheRecord>(
            predicate: #Predicate { $0.fetchedAt < xunjiCacheCutoff }
        ))
        oldCaches.forEach(modelContext.delete)
        result.xunjiCaches = oldCaches.count

        // AIReportRecord 此前无保留策略、只增不减：每 type 保留最近 N 条。
        let allReports = try modelContext.fetch(FetchDescriptor<AIReportRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        var keptByType: [String: Int] = [:]
        for report in allReports {
            let type = report.type
            let kept = keptByType[type, default: 0]
            if kept >= Self.reportKeepCountPerType {
                modelContext.delete(report)
                result.aiReports += 1
            } else {
                keptByType[type] = kept + 1
            }
        }

        // PR5：保留策略从 5 类扩展到覆盖对话交互/产品事件/记忆事件/主动洞察。
        // 用户内容类（日志/对话会话/训练/计划）仍永久保留——这是用户的历史，
        // 只修剪诊断/遥测类记录。
        let coachInteractionCutoff = now.addingTimeInterval(-Double(coachInteractionDays) * 86_400)
        let oldInteractions = try modelContext.fetch(FetchDescriptor<CoachInteractionRecord>(
            predicate: #Predicate { $0.createdAt < coachInteractionCutoff }
        ))
        oldInteractions.forEach(modelContext.delete)
        result.coachInteractions = oldInteractions.count

        let productEventCutoff = now.addingTimeInterval(-Double(productEventDays) * 86_400)
        let oldEvents = try modelContext.fetch(FetchDescriptor<VelaEventRecord>(
            predicate: #Predicate { $0.timestamp < productEventCutoff }
        ))
        oldEvents.forEach(modelContext.delete)
        result.productEvents = oldEvents.count

        let memoryCutoff = now.addingTimeInterval(-Double(memoryEventDays) * 86_400)
        let memoryStatuses = [
            MemoryProposalStatus.rejected.rawValue,
            MemoryProposalStatus.superseded.rawValue,
            MemoryProposalStatus.expired.rawValue
        ]
        let oldMemories = try modelContext.fetch(FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.createdAt < memoryCutoff && memoryStatuses.contains($0.status) }
        ))
        oldMemories.forEach(modelContext.delete)
        result.memoryEvents = oldMemories.count

        // ProactiveInsightRecord 已不再写入（D3），历史行全部清理。
        let staleInsights = try modelContext.fetch(FetchDescriptor<ProactiveInsightRecord>())
        staleInsights.forEach(modelContext.delete)
        result.proactiveInsights = staleInsights.count

        if result != Result() {
            try modelContext.save()
        }
        return result
    }

    /// 每种报告类型保留的最新条数（morning_brief/weekly_review 等）。
    static let reportKeepCountPerType = 30
}
