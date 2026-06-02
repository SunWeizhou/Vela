import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id) var id: UUID?
    @Field(key: "email") var email: String
    @Field(key: "password_hash") var passwordHash: String
    @Field(key: "timezone") var timezone: String
    @Field(key: "lang") var lang: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?
    @Timestamp(key: "updated_at", on: .update) var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, email: String, passwordHash: String, timezone: String = "Asia/Shanghai", lang: String = "zh") {
        self.id = id
        self.email = email
        self.passwordHash = passwordHash
        self.timezone = timezone
        self.lang = lang
    }
}

extension User {
    func toProfile() -> UserProfile {
        UserProfile(id: id!, email: email, timezone: timezone, lang: lang)
    }
}
