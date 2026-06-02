import Fluent
import Vapor

final class MemoryCard: Model, Content, @unchecked Sendable {
    static let schema = "memory_cards"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "pattern") var pattern: String
    @Field(key: "evidence") var evidence: String
    @Field(key: "confidence") var confidence: Double
    @Field(key: "status") var status: String
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, pattern: String, evidence: String, confidence: Double = 0.5, status: String = "pending") {
        self.id = id
        self.userId = userId
        self.pattern = pattern
        self.evidence = evidence
        self.confidence = confidence
        self.status = status
    }
}
