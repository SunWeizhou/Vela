import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "ModelContainer")

enum VelaModelContainer {
    static let modelTypes: [any PersistentModel.Type] = [
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
        AgentArtifactRecord.self,
        TrainingPlanAdaptationRecord.self,
        WorkoutEventRecord.self,
        XunjiDailyCacheRecord.self,
        XunjiWorkoutMirrorRecord.self,
        DeletedWorkoutRecord.self
    ]
    static let schema = Schema(modelTypes)

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
            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(
                for: schema,
                migrationPlan: VelaMigrationPlan.self,
                configurations: [config]
            )
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
}

enum VelaSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        VelaModelContainer.modelTypes
    }
}

enum VelaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [VelaSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

struct RetentionPolicyService {
    struct Result: Equatable {
        var agentRuns = 0
        var agentArtifacts = 0
        var coachArtifacts = 0
        var xunjiCaches = 0
    }

    var agentRunDays = 30
    var agentArtifactDays = 90
    var coachArtifactDays = 180
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

        if result != Result() {
            try modelContext.save()
        }
        return result
    }
}
