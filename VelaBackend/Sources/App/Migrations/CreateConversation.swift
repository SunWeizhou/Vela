import Fluent

struct CreateConversation: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("conversations")
            .id()
            .field("user_id", .uuid, .required)
            .field("role", .string, .required)
            .field("content", .string, .required)
            .field("metadata", .string)
            .field("created_at", .datetime)
            .create()
    }
    func revert(on database: Database) async throws {
        try await database.schema("conversations").delete()
    }
}
