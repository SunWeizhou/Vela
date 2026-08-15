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

    @Model
    final class DailyHealthSummaryRecord {
        @Attribute(.unique) var dayIdentifier: String
        var date: Date
        var sleepScore: Double?
        var recoveryScore: Double?
        var strainScore: Double?
        var stressIndex: Double?
        var morningEnergy: Double?
        var currentEnergy: Double?
        var energyBank: Double?
        var configVersion: String
        var schemaVersion: Int
        var updatedAt: Date
        var createdAt: Date
        var healthAge: Double?
        var hrvAverage: Double?
        var restingHeartRate: Double?
        var sleepHours: Double?
        var deepSleepPercent: Double?
        var remSleepPercent: Double?
        var sleepEfficiency: Double?
        var steps: Double?
        var activeCalories: Double?
        var activeMinutes: Double?
        var workoutCount: Int?
        var workoutTypes: String?
        var workoutDuration: Double?
        var bodyWeight: Double?
        var bodyFatPercent: Double?
        var bmi: Double?
        var oxygenSaturation: Double?
        var respiratoryRate: Double?
        var wristTemperature: Double?
        var dailyLoad: Double?
        var workoutLoad: Double?
        var activityLoad: Double?
        var trainingLoadRatio: Double?
        var atl: Double?
        var ctl: Double?
        var tsb: Double?
        var acwr: Double?
        var bedtime: Date?
        var wakeTime: Date?
        var awakeMinutes: Double?
        var awakeEpisodeCount: Int?
        var deepSleepMinutes: Double?
        var remSleepMinutes: Double?
        @Attribute(.externalStorage) var workoutsData: Data?

        init(
            dayIdentifier: String,
            date: Date,
            sleepScore: Double? = nil,
            recoveryScore: Double? = nil,
            configVersion: String = VelaAppMetadata.configVersion,
            schemaVersion: Int = 1,
            updatedAt: Date = Date(),
            createdAt: Date = Date()
        ) {
            self.dayIdentifier = dayIdentifier
            self.date = date
            self.sleepScore = sleepScore
            self.recoveryScore = recoveryScore
            self.configVersion = configVersion
            self.schemaVersion = schemaVersion
            self.updatedAt = updatedAt
            self.createdAt = createdAt
        }
    }

    static var models: [any PersistentModel.Type] {
        [
            DailyHealthSummaryRecord.self,
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
    }
}

enum VelaSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    /// Frozen representation of the production V2 daily summary. Versioned
    /// schemas must never point at the mutable current model type: doing so
    /// changes the historical checksum whenever a field is added and makes an
    /// existing on-device store appear to have an unknown model version.
    @Model
    final class DailyHealthSummaryRecord {
        @Attribute(.unique) var dayIdentifier: String
        var date: Date
        var sleepScore: Double?
        var recoveryScore: Double?
        var strainScore: Double?
        var stressIndex: Double?
        var morningEnergy: Double?
        var currentEnergy: Double?
        var energyBank: Double?
        var configVersion: String
        var schemaVersion: Int
        var updatedAt: Date
        var createdAt: Date
        var healthAge: Double?
        var hrvAverage: Double?
        var restingHeartRate: Double?
        var sleepHours: Double?
        var deepSleepPercent: Double?
        var remSleepPercent: Double?
        var sleepEfficiency: Double?
        var steps: Double?
        var activeCalories: Double?
        var activeMinutes: Double?
        var workoutCount: Int?
        var workoutTypes: String?
        var workoutDuration: Double?
        var bodyWeight: Double?
        var bodyFatPercent: Double?
        var bmi: Double?
        var oxygenSaturation: Double?
        var respiratoryRate: Double?
        var wristTemperature: Double?
        var dailyLoad: Double?
        var workoutLoad: Double?
        var activityLoad: Double?
        var trainingLoadRatio: Double?
        var atl: Double?
        var ctl: Double?
        var tsb: Double?
        var acwr: Double?
        var bedtime: Date?
        var wakeTime: Date?
        var awakeMinutes: Double?
        var awakeEpisodeCount: Int?
        var deepSleepMinutes: Double?
        var remSleepMinutes: Double?
        @Attribute(.externalStorage) var workoutsData: Data?
        @Attribute(.externalStorage) var scoreEvidenceData: Data?

        init(
            dayIdentifier: String,
            date: Date,
            sleepScore: Double? = nil,
            recoveryScore: Double? = nil,
            configVersion: String = VelaAppMetadata.configVersion,
            schemaVersion: Int = 2,
            updatedAt: Date = Date(),
            createdAt: Date = Date()
        ) {
            self.dayIdentifier = dayIdentifier
            self.date = date
            self.sleepScore = sleepScore
            self.recoveryScore = recoveryScore
            self.configVersion = configVersion
            self.schemaVersion = schemaVersion
            self.updatedAt = updatedAt
            self.createdAt = createdAt
        }
    }

    static var models: [any PersistentModel.Type] {
        var models = VelaModelContainer.modelTypes
        models[0] = DailyHealthSummaryRecord.self
        return models
    }
}

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
