import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "ModelContainer")

enum VelaModelContainer {
    static let schema = Schema([
        DailyHealthSummaryRecord.self,
        SleepSummaryRecord.self,
        JournalEntryRecord.self,
        AIReportRecord.self,
        UserWikiDocumentRecord.self,
        CoachSessionRecord.self,
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
        TrainingPlanAdaptationRecord.self,
        WorkoutEventRecord.self
    ])

    private static let storeURL: URL = {
        let base = URL.applicationSupportDirectory
        return base.appending(path: "Vela.store")
    }()

    private static let legacyStoreURLs: [URL] = {
        let base = URL.applicationSupportDirectory
        let defaultStore = base.appending(path: "default.store")
        return [defaultStore]
    }()

    private static func deleteStoreFiles(at url: URL) {
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
    }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        if inMemory {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [config])
        }

        do {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            // Enforce standard SwiftData container which automatically performs lightweight migration
            return try ModelContainer(
                for: schema,
                configurations: [config]
            )
        } catch {
            logger.warning("Failed to open store, attempting migration recovery: \(error.localizedDescription)")

            #if DEBUG
            deleteStoreFiles(at: storeURL)
            for legacyURL in legacyStoreURLs {
                deleteStoreFiles(at: legacyURL)
            }

            let config = ModelConfiguration(schema: schema, url: storeURL)
            return try ModelContainer(
                for: schema,
                configurations: [config]
            )
            #else
            throw error
            #endif
        }
    }
}
