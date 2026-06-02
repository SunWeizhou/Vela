import Fluent
import Vapor

final class Conversation: Model, Content, @unchecked Sendable {
    static let schema = "conversations"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "role") var role: String
    @Field(key: "content") var content: String
    @Field(key: "metadata") var metadata: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, role: String, content: String, metadata: String? = nil) {
        self.id = id
        self.userId = userId
        self.role = role
        self.content = content
        self.metadata = metadata
    }
}
