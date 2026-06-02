import Fluent

struct CreateUserSettings: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_settings")
            .id()
            .field("user_id", .uuid, .required)
            .field("language", .string, .required)
            .field("notifications_json", .string, .required)
            .field("data_sources", .string, .required)
            .field("coach_personality", .string, .required)
            .field("theme", .string, .required)
            .field("updated_at", .datetime)
            .unique(on: "user_id")
            .create()
    }
    func revert(on database: Database) async throws {
        try await database.schema("user_settings").delete()
    }
}
