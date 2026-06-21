import Foundation

struct LLMRequest: Hashable, Sendable {
    var systemPrompt: String
    var userPrompt: String
    var contextJSON: String
    var tools: [[String: Value]]? = nil
}

struct LLMResponse: Hashable, Sendable {
    var content: String
    var toolCalls: [ToolCall]? = nil
    var reasoningContent: String? = nil
}

struct ToolCall: Hashable, Sendable, Codable {
    var id: String
    var name: String
    var arguments: String
}

struct ChatMessage: Hashable, Sendable {
    var role: Role
    var content: String
    var toolCalls: [ToolCall]? = nil
    var toolCallId: String? = nil
    var reasoningContent: String? = nil

    enum Role: String, Hashable, Sendable {
        case system
        case user
        case assistant
        case tool
    }
}

// JSON-compatible value type for tool parameter schemas
enum Value: Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([Value])
    case object([String: Value])
    case null
}

extension Value: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else if let v = try? container.decode([Value].self) { self = .array(v) }
        else if let v = try? container.decode([String: Value].self) { self = .object(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}

protocol LLMProvider: Sendable {
    func complete(request: LLMRequest) async throws -> LLMResponse
}

extension LLMProvider {
    func completeChat(messages: [ChatMessage], tools: [[String: Value]]? = nil) async throws -> LLMResponse {
        let systemPrompt = messages.first { $0.role == .system }?.content ?? ""
        let userMessages = messages.filter { $0.role != .system }
        let contextParts = Array(messages.filter { $0.role == .system }.dropFirst().map { $0.content })
        let contextJSON = contextParts.isEmpty ? "{}" : contextParts.joined(separator: "\n\n")
        return try await complete(
            request: LLMRequest(
                systemPrompt: systemPrompt,
                userPrompt: userMessages.map { msg in
                    if let tcs = msg.toolCalls, !tcs.isEmpty {
                        return "[\(msg.role.rawValue) tool_calls: \(tcs.map { "\($0.name)(\($0.arguments))" }.joined(separator: ", "))]"
                    }
                    if msg.role == .tool {
                        return "[tool_result id=\(msg.toolCallId ?? ""): \(msg.content)]"
                    }
                    return msg.content
                }.joined(separator: "\n\n"),
                contextJSON: contextJSON,
                tools: tools
            )
        )
    }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await completeChat(messages: messages)
                    continuation.yield(response.content)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

enum LLMProviderError: LocalizedError, Hashable, Sendable {
    case missingAPIKey
    case authenticationFailed
    case networkUnavailable
    case timedOut
    case invalidResponse
    case requestFailed(String)

    static func classify(_ error: Error) -> LLMProviderError {
        if let providerError = error as? LLMProviderError {
            return providerError
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return .networkUnavailable
            case .timedOut:
                return .timedOut
            default:
                return .requestFailed(urlError.localizedDescription)
            }
        }
        return .requestFailed(error.localizedDescription)
    }

    static func httpFailure(statusCode: Int, body: String) -> LLMProviderError {
        if statusCode == 401 || statusCode == 403 {
            return .authenticationFailed
        }
        return .requestFailed("DeepSeek request failed with status \(statusCode): \(body.prefix(200))")
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timedOut:
            return true
        case .requestFailed(let message):
            return message.contains("status 408")
                || message.contains("status 429")
                || message.contains("status 500")
                || message.contains("status 502")
                || message.contains("status 503")
                || message.contains("status 504")
        case .missingAPIKey, .authenticationFailed, .invalidResponse:
            return false
        }
    }

    func recoveryAction(isChinese: Bool) -> LLMErrorRecoveryAction {
        switch self {
        case .missingAPIKey, .authenticationFailed:
            return LLMErrorRecoveryAction(
                title: isChinese ? "打开设置" : "Open Settings",
                systemImage: "key.fill",
                destination: .settings
            )
        case .networkUnavailable, .timedOut, .requestFailed:
            return LLMErrorRecoveryAction(
                title: isChinese ? "重试 Coach" : "Retry Coach",
                systemImage: "arrow.clockwise",
                destination: .retry
            )
        case .invalidResponse:
            return LLMErrorRecoveryAction(
                title: isChinese ? "稍后重试" : "Retry Later",
                systemImage: "exclamationmark.triangle.fill",
                destination: .retry
            )
        }
    }

    func userFacingMessage(isChinese: Bool) -> String {
        switch self {
        case .missingAPIKey:
            return isChinese ? "请先在设置中添加 DeepSeek API Key。" : "Add your DeepSeek API key in Settings."
        case .authenticationFailed:
            return isChinese ? "DeepSeek API Key 无效，请前往设置更新后重试。" : "Your DeepSeek API key is invalid. Update it in Settings and retry."
        case .networkUnavailable:
            return isChinese ? "当前网络不可用。本地健康、训练和日志功能仍可使用，联网后可重试 Coach。" : "The network is unavailable. Local health, training, and journal features still work; retry Coach when online."
        case .timedOut:
            return isChinese ? "Coach 请求超时，未写入空回复。请检查网络后重试。" : "The Coach request timed out and no empty reply was saved. Check the network and retry."
        case .invalidResponse:
            return isChinese ? "AI 服务返回了无法解析的内容，请稍后重试。" : "The AI provider returned an unreadable response. Please retry."
        case .requestFailed:
            return isChinese ? "AI 服务暂时不可用，本地功能不受影响。请稍后重试。" : "The AI provider is temporarily unavailable. Local features are unaffected; please retry."
        }
    }

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "DeepSeek API key is missing."
        case .authenticationFailed:
            return "DeepSeek API authentication failed."
        case .networkUnavailable:
            return "The network is unavailable."
        case .timedOut:
            return "The provider request timed out."
        case .invalidResponse:
            return "The provider returned an invalid response."
        case .requestFailed(let message):
            return message
        }
    }
}

struct LLMErrorRecoveryAction: Hashable, Sendable, Codable {
    enum Destination: String, Hashable, Sendable, Codable {
        case settings
        case retry
    }

    var title: String
    var systemImage: String
    var destination: Destination
}
