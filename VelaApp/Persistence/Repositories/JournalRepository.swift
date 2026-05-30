import Foundation
import SwiftData

protocol JournalRepository {
    func add(tags: [String], note: String, createdAt: Date) throws
    func recent(limit: Int) throws -> [JournalEntryRecord]
}

final class SwiftDataJournalRepository: JournalRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(tags: [String], note: String, createdAt: Date = Date()) throws {
        try PersistenceWriteGate.shared.assertWritable(operation: "JournalRepository: add", modelContext: modelContext)
        modelContext.insert(JournalEntryRecord(createdAt: createdAt, tags: tags, note: note))
        try modelContext.save()
    }

    func recent(limit: Int = 20) throws -> [JournalEntryRecord] {
        var descriptor = FetchDescriptor<JournalEntryRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }
}
