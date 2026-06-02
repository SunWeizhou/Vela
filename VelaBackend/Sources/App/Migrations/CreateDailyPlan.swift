import Fluent

struct CreateDailyPlan: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("daily_plans")
            .id()
            .field("user_id", .uuid, .required)
            .field("date", .string, .required)
            .field("kind", .string, .required)
            .field("title", .string, .required)
            .field("description", .string, .required)
            .field("actions", .string, .required)
            .field("scores", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "date")
            .create()
    }
    func revert(on database: Database) async throws {
        try await database.schema("daily_plans").delete()
    }
}
