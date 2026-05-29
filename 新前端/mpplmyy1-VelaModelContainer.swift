import SwiftData

enum VelaModelContainer {
    static let schema = Schema([
        DailyHealthSummaryRecord.self,
        JournalEntryRecord.self,
        AIReportRecord.self,
        UserWikiDocumentRecord.self,
        CoachSessionRecord.self
    ])

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
