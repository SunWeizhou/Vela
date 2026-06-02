import Fluent
import Vapor

final class DailyPlan: Model, Content, @unchecked Sendable {
    static let schema = "daily_plans"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "date") var date: String
    @Field(key: "kind") var kind: String
    @Field(key: "title") var title: String
    @Field(key: "description") var description: String
    @Field(key: "actions") var actions: String
    @Field(key: "scores") var scores: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, date: String, kind: String, title: String, description: String, actions: String, scores: String? = nil) {
        self.id = id
        self.userId = userId
        self.date = date
        self.kind = kind
        self.title = title
        self.description = description
        self.actions = actions
        self.scores = scores
    }
}
