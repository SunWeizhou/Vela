import Fluent

struct CreateMemoryCard: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("memory_cards")
            .id()
            .field("user_id", .uuid, .required)
            .field("pattern", .string, .required)
            .field("evidence", .string, .required)
            .field("confidence", .double, .required)
            .field("status", .string, .required)
            .field("created_at", .datetime)
            .create()
    }
    func revert(on database: Database) async throws {
        try await database.schema("memory_cards").delete()
    }
}
