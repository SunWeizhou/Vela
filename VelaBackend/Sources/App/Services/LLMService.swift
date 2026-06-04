import Vapor

/// Claude API integration. Supports anthropic.com and any OpenAI-compatible endpoint.
/// Uses Claude's native tool-use / function-calling capabilities.
actor LLMService {

    private let apiKey: String
    private let baseURL: String
    private let model: String
    private let client: Client
    private let logger: Logger

    init(app: Application) {
        self.apiKey = Environment.get("ANTHROPIC_API_KEY") ?? ""
        let configuredBaseURL = (Environment.get("ANTHROPIC_BASE_URL") ?? "https://api.anthropic.com")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.baseURL = configuredBaseURL.hasSuffix("/v1")
            ? configuredBaseURL
            : configuredBaseURL + "/v1"
        self.model = Environment.get("LLM_MODEL") ?? "claude-sonnet-4-6"
        self.client = app.client
        self.logger = app.logger
    }

    // MARK: - Chat Completion

    private static let requestTimeoutSeconds: Int64 = 45
    private static let maxRetries = 2

    func chat(
        messages: [ChatMessage],
        systemPrompt: String,
        tools: [ToolDefinition]? = nil,
        temperature: Double = 0.7,
        lang: String = "zh"
    ) async throws -> ChatResponse {
        var lastError: Error?

        for attempt in 0...Self.maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
                logger.info("LLM retry attempt \(attempt)/\(Self.maxRetries)")
            }

            do {
                return try await performChatRequest(
                    messages: messages,
                    systemPrompt: systemPrompt,
                    tools: tools,
                    temperature: temperature,
                    lang: lang
                )
            } catch {
                lastError = error
                // Only retry on server errors (502/503) or timeouts (504)
                if let abort = error as? Abort {
                    let code = abort.status.code
                    guard code == 502 || code == 503 || code == 504 else { throw abort }
                } else {
                    // Non-Abort errors (network timeouts, etc.) are retryable
                    guard attempt < Self.maxRetries else { throw error }
                }
            }
        }

        throw lastError ?? Abort(.badGateway, reason: "LLM request failed after \(Self.maxRetries + 1) attempts.")
    }

    private func performChatRequest(
        messages: [ChatMessage],
        systemPrompt: String,
        tools: [ToolDefinition]?,
        temperature: Double,
        lang: String
    ) async throws -> ChatResponse {
        guard !apiKey.isEmpty else {
            throw Abort(.serviceUnavailable, reason: "ANTHROPIC_API_KEY is not configured.")
        }

        let url = "\(baseURL)/messages"
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "temperature": temperature,
            "system": systemPrompt,
            "messages": messages.map { $0.toDict() },
        ]
        if let tools = tools, !tools.isEmpty {
            body["tools"] = tools.map { $0.toDict() }
        }
        let jsonData = try JSONSerialization.data(withJSONObject: body)

        let response = try await client.post(URI(string: url), beforeSend: { req in
            req.timeout = .seconds(Self.requestTimeoutSeconds)
            req.headers.add(name: "x-api-key", value: apiKey)
            req.headers.add(name: "anthropic-version", value: "2023-06-01")
            req.headers.contentType = .json
            var buffer = ByteBufferAllocator().buffer(capacity: jsonData.count)
            buffer.writeBytes(jsonData)
            req.body = buffer
        })
        guard response.status == HTTPStatus.ok else {
            throw Abort(.badGateway, reason: "Anthropic request failed with status \(response.status.code).")
        }

        let decoded = try response.content.decode(ClaudeResponse.self)
        let tokenCount = decoded.usage.map { $0.input_tokens + $0.output_tokens } ?? 0
        logger.info("LLM call — model: \(model), tokens: \(tokenCount)")

        return ChatResponse(
            content: decoded.content.first?.text ?? "",
            toolCalls: decoded.content.compactMap { block in
                guard block.type == "tool_use",
                      let id = block.id,
                      let name = block.name,
                      let input = block.input else { return nil }
                return ToolCall(id: id, name: name, input: input)
            },
            stopReason: decoded.stop_reason,
            usage: decoded.usage.map { Usage(input: $0.input_tokens, output: $0.output_tokens) }
        )
    }

    // MARK: - JSON Completion (structured output)

    func jsonCompletion(
        prompt: String,
        temperature: Double = 0.2,
        lang: String = "zh"
    ) async throws -> String {
        let systemPrompt = lang == "zh"
            ? "你是一个健康数据分析助手。你必须只返回有效的 JSON，不要有任何额外文字或解释。"
            : "You are a health data analysis assistant. You must return only valid JSON with no additional text."

        let response = try await chat(
            messages: [ChatMessage(role: "user", content: prompt)],
            systemPrompt: systemPrompt,
            temperature: temperature,
            lang: lang
        )

        // Extract JSON from response (strip any markdown code blocks)
        var content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if content.hasPrefix("```json") {
            content = String(content.dropFirst(7))
        }
        if content.hasPrefix("```") {
            content = String(content.dropFirst(3))
        }
        if content.hasSuffix("```") {
            content = String(content.dropLast(3))
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Tool definitions for Claude

    static let coachTools: [ToolDefinition] = [
        ToolDefinition(
            name: "propose_memory",
            description: "向用户的记忆收件箱建议一条长期模式。用户审核后确认或驳回。",
            parameters: [
                "type": "object",
                "properties": [
                    "pattern": ["type": "string", "description": "模式名称，5-10字"],
                    "description": ["type": "string", "description": "发现的具体模式描述"],
                    "evidence": ["type": "string", "description": "支撑数据"],
                    "confidence": ["type": "number", "description": "0.0-1.0"]
                ],
                "required": ["pattern", "description", "evidence"]
            ]
        ),
        ToolDefinition(
            name: "suggest_training",
            description: "根据当前恢复状态和能量水平生成训练建议。",
            parameters: [
                "type": "object",
                "properties": [
                    "focus": ["type": "string", "description": "cardio|strength|flexibility|rest"],
                    "duration_minutes": ["type": "integer", "description": "建议时长"],
                    "intensity": ["type": "string", "description": "low|moderate|high"],
                    "reason": ["type": "string", "description": "基于数据的理由"]
                ],
                "required": ["focus", "duration_minutes", "intensity"]
            ]
        ),
        ToolDefinition(
            name: "web_search",
            description: "查询最新公开健康研究、运动科学资料或指南摘要。只用于需要外部最新信息的问题，不用于读取用户私人健康数据。",
            parameters: [
                "type": "object",
                "properties": [
                    "query": ["type": "string", "description": "搜索问题。健康研究和运动科学问题优先使用英文。"],
                    "source_policy": [
                        "type": "string",
                        "description": "来源优先级：medical_primary|sports_science|general",
                        "enum": ["medical_primary", "sports_science", "general"]
                    ]
                ],
                "required": ["query"]
            ]
        ),
    ]
}

// MARK: - Supporting Types

struct ChatMessage: Codable {
    var role: String
    var content: String

    func toDict() -> [String: String] {
        ["role": role, "content": content]
    }
}

struct ToolDefinition {
    var name: String
    var description: String
    var parameters: [String: Any]

    func toDict() -> [String: Any] {
        [
            "name": name,
            "description": description,
            "input_schema": parameters,
        ]
    }
}

struct ChatResponse: Codable {
    var content: String
    var toolCalls: [ToolCall]?
    var stopReason: String?
    var usage: Usage?
}

struct ToolCall: Codable {
    var id: String
    var name: String
    var input: [String: AnyCodable]
}

struct Usage: Codable {
    var input: Int
    var output: Int
}

// MARK: - Claude API Response Types

struct ClaudeResponse: Codable {
    var id: String?
    var content: [ContentBlock]
    var stop_reason: String?
    var usage: UsageInfo?

    struct ContentBlock: Codable {
        var type: String
        var text: String?
        var id: String?
        var name: String?
        var input: [String: AnyCodable]?
    }

    struct UsageInfo: Codable {
        var input_tokens: Int
        var output_tokens: Int
    }
}

struct AnyCodable: Codable, CustomStringConvertible {
    var value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(value, .init(codingPath: container.codingPath, debugDescription: "Unsupported JSON value"))
        }
    }

    var description: String {
        String(describing: value)
    }
}
