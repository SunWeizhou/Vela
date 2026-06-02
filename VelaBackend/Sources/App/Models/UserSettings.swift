import Fluent
import Vapor

final class UserSettings: Model, Content, @unchecked Sendable {
    static let schema = "user_settings"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "language") var language: String
    @Field(key: "notifications_json") var notificationsJson: String
    @Field(key: "data_sources") var dataSources: String
    @Field(key: "coach_personality") var coachPersonality: String
    @Field(key: "theme") var theme: String
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, language: String = "zh", notificationsJson: String = "{}", dataSources: String = "[\"apple_watch\"]", coachPersonality: String = "friend", theme: String = "system") {
        self.id = id
        self.userId = userId
        self.language = language
        self.notificationsJson = notificationsJson
        self.dataSources = dataSources
        self.coachPersonality = coachPersonality
        self.theme = theme
    }
}
