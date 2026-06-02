import Fluent
import Vapor

final class TrustAuditEntry: Model, Content, @unchecked Sendable {
    static let schema = "trust_audits"

    @ID(key: .id) var id: UUID?
    @Field(key: "user_id") var userId: UUID
    @Field(key: "tool_name") var toolName: String
    @Field(key: "parameters") var parameters: String
    @Field(key: "result_status") var resultStatus: String
    @Field(key: "model_version") var modelVersion: String
    @Timestamp(key: "timestamp", on: .create) var timestamp: Date?

    init() {}

    init(id: UUID? = nil, userId: UUID, toolName: String, parameters: String, resultStatus: String, modelVersion: String) {
        self.id = id
        self.userId = userId
        self.toolName = toolName
        self.parameters = parameters
        self.resultStatus = resultStatus
        self.modelVersion = modelVersion
    }
}
