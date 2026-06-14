import Foundation

enum DeepSeekTextModel: String, CaseIterable, Sendable {
    static let storageKey = "vela_coach_text_model"

    case flash = "DeepSeek V4 Flash"
    case pro = "DeepSeek V4 Pro"

    init(displayName: String) {
        self = Self(rawValue: displayName) ?? .pro
    }

    static var stored: DeepSeekTextModel {
        DeepSeekTextModel(
            displayName: UserDefaults.standard.string(forKey: storageKey) ?? DeepSeekTextModel.pro.rawValue
        )
    }

    var apiIdentifier: String {
        switch self {
        case .flash: return "deepseek-v4-flash"
        case .pro: return "deepseek-v4-pro"
        }
    }
}

enum DeepSeekStreamCompletion {
    static func isComplete(didReceiveDone: Bool) -> Bool {
        didReceiveDone
    }
}

struct DeepSeekProvider: LLMProvider {
    var apiKey: String
    var model: String
    var endpoint: URL

    init(
        apiKey: String,
        model: String = DeepSeekTextModel.stored.apiIdentifier,
        endpoint: URL = URL(string: "https://api.deepseek.com/chat/completions")!
    ) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
    }

    func complete(request: LLMRequest) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey
        }

        let messages: [ChatMessage] = [
            ChatMessage(role: .system, content: request.systemPrompt),
            ChatMessage(role: .user, content: "\(request.userPrompt)\n\nContext:\n\(request.contextJSON)")
        ]
        return try await chat(messages: messages, tools: request.tools)
    }

    /// Non-streaming chat with optional tools. Returns content and/or tool_calls.
    func chat(messages: [ChatMessage], tools: [[String: Value]]? = nil) async throws -> LLMResponse {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMProviderError.missingAPIKey
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = 120

        let body = DeepSeekChatRequest(
            model: model,
            messages: messages.map { msg in
                DeepSeekChatRequest.Message(
                    role: msg.role.apiValue,
                    content: msg.content.isEmpty ? nil : msg.content,
                    toolCalls: msg.toolCalls?.map { tc in
                        DeepSeekChatRequest.ToolCall(id: tc.id, type: "function", function: .init(name: tc.name, arguments: tc.arguments))
                    },
                    toolCallId: msg.toolCallId,
                    reasoningContent: msg.reasoningContent
                )
            },
            temperature: 0.4,
            stream: false,
            tools: tools?.map { ToolDef(from: $0) },
            toolChoice: tools != nil ? "auto" : nil
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch {
            throw LLMProviderError.classify(error)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMProviderError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMProviderError.httpFailure(statusCode: httpResponse.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        let choice = decoded.choices.first
        let content = choice?.message.content ?? ""
        let reasoningContent = choice?.message.reasoningContent

        var toolCalls: [ToolCall]? = nil
        if let rawCalls = choice?.message.toolCalls, !rawCalls.isEmpty {
            toolCalls = rawCalls.map { tc in
                ToolCall(id: tc.id, name: tc.function.name, arguments: tc.function.arguments)
            }
        }

        return LLMResponse(content: content, toolCalls: toolCalls, reasoningContent: reasoningContent)
    }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw LLMProviderError.missingAPIKey
                    }

                    var urlRequest = URLRequest(url: endpoint)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    urlRequest.timeoutInterval = 180
                    urlRequest.httpBody = try JSONEncoder().encode(
                        DeepSeekChatRequest(
                            model: model,
                            messages: messages.map { msg in
                                DeepSeekChatRequest.Message(
                                    role: msg.role.apiValue,
                                    content: msg.content.isEmpty ? nil : msg.content,
                                    toolCalls: msg.toolCalls?.map { tc in
                                        DeepSeekChatRequest.ToolCall(id: tc.id, type: "function", function: .init(name: tc.name, arguments: tc.arguments))
                                    },
                                    toolCallId: msg.toolCallId,
                                    reasoningContent: msg.reasoningContent
                                )
                            },
                            temperature: 0.4,
                            stream: true,
                            tools: nil,
                            toolChoice: nil
                        )
                    )

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw LLMProviderError.invalidResponse
                    }
                    guard (200..<300).contains(httpResponse.statusCode) else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line + "\n"
                        }
                        throw LLMProviderError.httpFailure(statusCode: httpResponse.statusCode, body: errorBody)
                    }

                    var didReceiveDone = false
                    for try await line in bytes.lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedLine == "data: [DONE]" || trimmedLine == "data:[DONE]" {
                            didReceiveDone = true
                            break
                        }
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let data = json.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(DeepSeekStreamChunk.self, from: data),
                              let delta = chunk.choices.first?.delta.content,
                              !delta.isEmpty else { continue }
                        continuation.yield(delta)
                    }
                    guard DeepSeekStreamCompletion.isComplete(didReceiveDone: didReceiveDone) else {
                        throw LLMProviderError.invalidResponse
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: CancellationError())
                } catch {
                    continuation.finish(throwing: LLMProviderError.classify(error))
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }
}

// MARK: - Request/Response Codable Types

private struct DeepSeekChatRequest: Encodable {
    var model: String
    var messages: [Message]
    var temperature: Double
    var stream: Bool
    var tools: [ToolDef]?
    var toolChoice: String?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream, tools
        case toolChoice = "tool_choice"
    }

    struct Message: Encodable {
        var role: String
        var content: String?
        var toolCalls: [ToolCall]?
        var toolCallId: String?
        var reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case role, content
            case toolCalls = "tool_calls"
            case toolCallId = "tool_call_id"
            case reasoningContent = "reasoning_content"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role, forKey: .role)
            try container.encodeIfPresent(content, forKey: .content)
            try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
            try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
            try container.encodeIfPresent(reasoningContent, forKey: .reasoningContent)
        }
    }

    struct ToolCall: Encodable {
        var id: String
        var type: String
        var function: FunctionDef

        struct FunctionDef: Encodable {
            var name: String
            var arguments: String
        }
    }
}

private struct ToolDef: Encodable {
    var type: String = "function"
    var function: FunctionSchema

    struct FunctionSchema: Encodable {
        var name: String
        var description: String
        var parameters: [String: Value]
    }

    init(from dict: [String: Value]) {
        let fnDict: [String: Value] = {
            if case .object(let v) = dict["function"] { return v }
            return [:]
        }()
        let nameStr: String = {
            if case .string(let v) = fnDict["name"] { return v }
            return ""
        }()
        let descStr: String = {
            if case .string(let v) = fnDict["description"] { return v }
            return ""
        }()
        let params: [String: Value] = {
            if case .object(let v) = fnDict["parameters"] { return v }
            return [:]
        }()
        self.function = FunctionSchema(
            name: nameStr,
            description: descStr,
            parameters: params
        )
    }
}

private struct DeepSeekChatResponse: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var message: ResponseMessage
        var finishReason: String?

        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }

    struct ResponseMessage: Decodable {
        var content: String?
        var toolCalls: [ResponseToolCall]?
        var reasoningContent: String?

        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
            case reasoningContent = "reasoning_content"
        }
    }

    struct ResponseToolCall: Decodable {
        var id: String
        var type: String
        var function: FunctionCall
    }

    struct FunctionCall: Decodable {
        var name: String
        var arguments: String
    }
}

private struct DeepSeekStreamChunk: Decodable {
    var choices: [Choice]

    struct Choice: Decodable {
        var delta: Delta
    }

    struct Delta: Decodable {
        var content: String?
    }
}

private extension ChatMessage.Role {
    var apiValue: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        case .tool: return "tool"
        }
    }
}
