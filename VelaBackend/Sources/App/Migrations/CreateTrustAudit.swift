import Fluent

struct CreateTrustAudit: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("trust_audits")
            .id()
            .field("user_id", .uuid, .required)
            .field("tool_name", .string, .required)
            .field("parameters", .string, .required)
            .field("result_status", .string, .required)
            .field("model_version", .string, .required)
            .field("timestamp", .datetime)
            .create()
    }
    func revert(on database: Database) async throws {
        try await database.schema("trust_audits").delete()
    }
}
