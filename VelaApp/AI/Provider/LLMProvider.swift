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
    case invalidResponse
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "DeepSeek API key is missing."
        case .invalidResponse:
            return "The provider returned an invalid response."
        case .requestFailed(let message):
            return message
        }
    }
}
