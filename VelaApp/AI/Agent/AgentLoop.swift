import Foundation
import SwiftData

/// Risk level for tool operations — AgentLoop uses this for guardrails.
enum ToolRiskLevel: String, Sendable {
    case read        // Query data, no side effects — execute freely
    case propose     // Generate suggestion that needs user confirmation
    case write       // Mutate data with idempotency — allow with key check
    case destructive // Delete or deactivate — require explicit confirmation
}

struct ToolCallDescription: Sendable {
    let name: String
    let arguments: String
    let riskLevel: ToolRiskLevel
}

// MARK: - Agent Loop

protocol AgentChatProvider: Sendable {
    func chat(messages: [ChatMessage], tools: [[String: Value]]?) async throws -> LLMResponse
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

extension DeepSeekProvider: AgentChatProvider {}

/// Retries provider transport failures without replaying AgentLoop tool execution.
struct RetryingAgentChatProvider: AgentChatProvider {
    let base: any AgentChatProvider
    let maxAttempts: Int
    let initialDelayNanoseconds: UInt64
    let sleeper: @Sendable (UInt64) async throws -> Void

    init(
        base: any AgentChatProvider,
        maxAttempts: Int = 3,
        initialDelayNanoseconds: UInt64 = 350_000_000,
        sleeper: @escaping @Sendable (UInt64) async throws -> Void = { delay in
            try await Task.sleep(nanoseconds: delay)
        }
    ) {
        self.base = base
        self.maxAttempts = max(1, maxAttempts)
        self.initialDelayNanoseconds = initialDelayNanoseconds
        self.sleeper = sleeper
    }

    func chat(messages: [ChatMessage], tools: [[String: Value]]?) async throws -> LLMResponse {
        try await retrying {
            try await base.chat(messages: messages, tools: tools)
        }
    }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var attempt = 1

                while true {
                    var didYield = false
                    do {
                        let stream = base.streamChat(messages: messages)
                        for try await delta in stream {
                            didYield = true
                            continuation.yield(delta)
                        }
                        continuation.finish()
                        return
                    } catch is CancellationError {
                        continuation.finish(throwing: CancellationError())
                        return
                    } catch {
                        let providerError = LLMProviderError.classify(error)
                        guard !didYield, shouldRetry(error: providerError, attempt: attempt) else {
                            continuation.finish(throwing: providerError)
                            return
                        }
                        do {
                            try await sleepBeforeRetry(attempt: attempt)
                        } catch {
                            continuation.finish(throwing: error)
                            return
                        }
                        attempt += 1
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func retrying<T>(_ operation: () async throws -> T) async throws -> T {
        var attempt = 1

        while true {
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let providerError = LLMProviderError.classify(error)
                guard shouldRetry(error: providerError, attempt: attempt) else {
                    throw providerError
                }
                try await sleepBeforeRetry(attempt: attempt)
                attempt += 1
            }
        }
    }

    private func shouldRetry(error: LLMProviderError, attempt: Int) -> Bool {
        attempt < maxAttempts && error.isRetryable
    }

    private func sleepBeforeRetry(attempt: Int) async throws {
        let delay = delayNanoseconds(for: attempt)
        guard delay > 0 else { return }
        try await sleeper(delay)
    }

    private func delayNanoseconds(for attempt: Int) -> UInt64 {
        guard initialDelayNanoseconds > 0 else { return 0 }
        let multiplier = UInt64(1 << min(max(attempt - 1, 0), 4))
        return initialDelayNanoseconds.saturatingMultiply(multiplier)
    }
}

private extension UInt64 {
    func saturatingMultiply(_ multiplier: UInt64) -> UInt64 {
        let (result, overflow) = multipliedReportingOverflow(by: multiplier)
        return overflow ? UInt64.max : result
    }
}

/// Encapsulates the tool-call loop: sends messages to LLM, executes tool calls, collects results.
/// Extracted from CoachChatVM.send() so that CoachChatPanel.swift remains UI-only.
struct AgentLoop {

    let provider: any AgentChatProvider
    let toolRegistry: ToolRegistry
    let maxIterations: Int
    /// Maximum total tool calls allowed per loop run (across all iterations).
    let maxToolCalls: Int
    /// Timeout per individual tool execution in seconds.
    let toolTimeoutSeconds: Int
    /// Optional callback to confirm high-risk tool calls.
    var onConfirmToolCall: (@Sendable (ToolCallDescription) async -> Bool)? = nil

    init(
        provider: any AgentChatProvider,
        toolRegistry: ToolRegistry,
        maxIterations: Int = 3,
        maxToolCalls: Int = 15,
        toolTimeoutSeconds: Int = 20,
        onConfirmToolCall: (@Sendable (ToolCallDescription) async -> Bool)? = nil
    ) {
        self.provider = provider
        self.toolRegistry = toolRegistry
        self.maxIterations = maxIterations
        self.maxToolCalls = maxToolCalls
        self.toolTimeoutSeconds = toolTimeoutSeconds
        self.onConfirmToolCall = onConfirmToolCall
    }

    /// Runs the agentic loop and returns the final response plus tool execution details.
    /// - Parameters:
    ///   - messages: The chat message history including system prompt.
    ///   - onStreamDelta: Optional callback invoked with each streamed text token delta.
    ///   - initialDataVersion: Optional data version hash from the compact snapshot, for change detection.
    /// - Returns: AgentLoopResult with the final text response, executed tools, and updated messages.
    func run(
        messages: [ChatMessage],
        onStreamDelta: (@MainActor @Sendable (String) -> Void)? = nil,
        initialDataVersion: String? = nil
    ) async throws -> AgentLoopResult {
        let startedAt = Date()
        var agentMessages = messages
        var fullResponse = ""
        var executedTools: [ExecutedTool] = []
        var activeDataVersion = initialDataVersion
        var dataVersionWarnings: [String] = []
        var providerCallCount = 0
        var duplicateToolTracker: Set<String> = []
        var toolCallBudget = maxToolCalls
        var executedToolCallIds: Set<String> = []

        for _ in 0..<maxIterations {
            // ── Inject data-version notice if tools returned fresher data than the snapshot ──
            if let currentVersion = activeDataVersion, let initial = initialDataVersion, currentVersion != initial {
                let notice = "[DATA VERSION CHANGE: tool-returned data (v:\(currentVersion)) is newer than the initial snapshot (v:\(initial)). Prefer the tool-fetched values over any inline snapshot for the rest of this response.]"
                if !dataVersionWarnings.contains(notice) {
                    dataVersionWarnings.append(notice)
                    agentMessages.append(ChatMessage(role: .system, content: notice))
                }
            }

            guard toolCallBudget > 0 else {
                agentMessages.append(ChatMessage(
                    role: .system,
                    content: "[BUDGET EXCEEDED: Maximum tool calls (\(maxToolCalls)) reached. Please summarize what was done so far and suggest next steps to the user.]"
                ))
                break
            }

            providerCallCount += 1
            let response = try await provider.chat(
                messages: agentMessages,
                tools: toolRegistry.definitions
            )

            if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                agentMessages.append(ChatMessage(
                    role: .assistant,
                    content: response.content,
                    toolCalls: toolCalls,
                    reasoningContent: response.reasoningContent
                ))

                for tc in toolCalls {
                    toolCallBudget -= 1

                    guard toolRegistry.contains(name: tc.name) else {
                        let blocked = "[BLOCKED: Tool '\(tc.name)' is not in this session's allowlist.]"
                        agentMessages.append(ChatMessage(
                            role: .tool,
                            content: blocked,
                            toolCallId: tc.id
                        ))
                        executedTools.append(ExecutedTool(
                            name: tc.name,
                            arguments: tc.arguments,
                            result: blocked
                        ))
                        continue
                    }

                    let toolRisk = toolRegistry.risk(for: tc.name)
                    if (toolRisk == .write || toolRisk == .destructive) && executedToolCallIds.contains(tc.id) {
                        agentMessages.append(ChatMessage(
                            role: .tool,
                            content: "[ALREADY EXECUTED: Tool \(tc.name) with call ID \(tc.id) was successfully executed. Skipping replay.]",
                            toolCallId: tc.id
                        ))
                        continue
                    }

                    // Duplicate tool call detection (same name + same args within this loop)
                    let callSignature = Self.canonicalCallSignature(name: tc.name, arguments: tc.arguments)
                    if !duplicateToolTracker.insert(callSignature).inserted {
                        agentMessages.append(ChatMessage(
                            role: .tool,
                            content: "[DUPLICATE DETECTED: Tool \(tc.name) called with identical arguments already executed this session. The result was not re-executed. Use the previous result instead.]",
                            toolCallId: tc.id
                        ))
                        continue
                    }

                    // User confirmation check for write / destructive tools
                    let userConfirmed: Bool
                    let refusalResult: String?
                    
                    if toolRisk == .write || toolRisk == .destructive {
                        if let onConfirm = onConfirmToolCall {
                            let description = ToolCallDescription(name: tc.name, arguments: tc.arguments, riskLevel: toolRisk)
                            userConfirmed = await onConfirm(description)
                            refusalResult = userConfirmed ? nil : "Error: User rejected execution of this tool."
                        } else {
                            userConfirmed = false
                            refusalResult = "Error: Write or destructive action refused because no user confirmation callback was supplied."
                        }
                    } else {
                        userConfirmed = true
                        refusalResult = nil
                    }

                    let result: String
                    if !userConfirmed {
                        result = refusalResult ?? "Error: User rejected execution of this tool."
                    } else {
                        // Execute with timeout
                        if toolTimeoutSeconds > 0 {
                            result = await executeWithTimeout(name: tc.name, arguments: tc.arguments)
                        } else {
                            result = await toolRegistry.execute(name: tc.name, arguments: tc.arguments)
                        }
                    }

                    if userConfirmed && !result.hasPrefix("Error executing") {
                        executedToolCallIds.insert(tc.id)
                    }

                    agentMessages.append(ChatMessage(
                        role: .tool,
                        content: result,
                        toolCallId: tc.id
                    ))
                    executedTools.append(ExecutedTool(
                        name: tc.name,
                        arguments: tc.arguments,
                        result: result
                    ))
                    // Track data version from tools that return it
                    if let newVersion = Self.extractDataVersion(from: result), newVersion != activeDataVersion {
                        activeDataVersion = newVersion
                    }
                }

                continue
            }

            // Final text response (no more tool calls)
            if let onStreamDelta {
                fullResponse = response.content
                if !fullResponse.isEmpty {
                    await onStreamDelta(fullResponse)
                }
                return AgentLoopResult(
                    response: fullResponse,
                    executedTools: executedTools,
                    finalMessages: agentMessages,
                    wasStreamed: false,
                    trace: makeTrace(
                        startedAt: startedAt,
                        inputMessages: messages,
                        executedTools: executedTools,
                        finalResponse: fullResponse,
                        contextHash: initialDataVersion,
                        providerCallCount: providerCallCount
                    )
                )
            } else {
                fullResponse = response.content
            }
            break
        }

        if fullResponse.isEmpty {
            if let onStreamDelta {
                providerCallCount += 1
                let finalResponse = try await provider.chat(messages: agentMessages, tools: nil)
                fullResponse = finalResponse.content
                if !fullResponse.isEmpty {
                    await onStreamDelta(fullResponse)
                }
                return AgentLoopResult(
                    response: fullResponse,
                    executedTools: executedTools,
                    finalMessages: agentMessages,
                    wasStreamed: false,
                    trace: makeTrace(
                        startedAt: startedAt,
                        inputMessages: messages,
                        executedTools: executedTools,
                        finalResponse: fullResponse,
                        contextHash: initialDataVersion,
                        providerCallCount: providerCallCount
                    )
                )
            } else {
                providerCallCount += 1
                let finalResponse = try await provider.chat(messages: agentMessages, tools: nil)
                fullResponse = finalResponse.content.isEmpty
                    ? "I wasn't able to generate a response. Please try again."
                    : finalResponse.content
            }
        }

        return AgentLoopResult(
            response: fullResponse,
            executedTools: executedTools,
            finalMessages: agentMessages,
            wasStreamed: false,
            trace: makeTrace(
                startedAt: startedAt,
                inputMessages: messages,
                executedTools: executedTools,
                finalResponse: fullResponse,
                contextHash: initialDataVersion,
                providerCallCount: providerCallCount
            )
        )
    }

    private func makeTrace(
        startedAt: Date,
        inputMessages: [ChatMessage],
        executedTools: [ExecutedTool],
        finalResponse: String,
        contextHash: String?,
        providerCallCount: Int
    ) -> AgentRunTrace {
        let resolvedHash = contextHash ?? ContentHash.hash(
            inputMessages.map { "\($0.role.rawValue):\($0.content)" }.joined(separator: "\n")
        )
        return AgentRunTrace(
            id: UUID(),
            startedAt: startedAt,
            endedAt: Date(),
            inputMessages: inputMessages.map {
                AgentRunTrace.ChatMessageSnapshot(
                    role: $0.role.rawValue,
                    content: sanitizeForTrace($0.content),
                    toolCalls: $0.toolCalls?.map(\.name)
                )
            },
            executedTools: executedTools.map {
                AgentRunTrace.ExecutedToolSnapshot(
                    name: $0.name,
                    arguments: redactToolArguments($0.name, arguments: $0.arguments),
                    result: redactToolResult($0.name, result: $0.result)
                )
            },
            finalResponse: sanitizeForTrace(finalResponse),
            contextHash: resolvedHash,
            schemaVersion: "agentTrace.v1",
            providerCallCount: providerCallCount
        )
    }

    /// Truncates and hashes sensitive health/diet/journal content for trace storage,
    /// while preserving enough context for debugging.
    private func sanitizeForTrace(_ text: String) -> String {
        let sensitivePatterns = [
            "food_analysis", "calories", "protein", "carbohydrates",
            "fat", "journal", "日记", "饮食", "food_log", "meal_photo",
            "blood", "血糖", "glucose", "heart_rate", "心率",
            "HRV", "睡眠", "sleep", "recovery", "恢复"
        ]
        let lowercased = text.lowercased()
        let needsTruncation = sensitivePatterns.contains(where: { lowercased.contains($0.lowercased()) })
        guard needsTruncation else { return text }

        let hash = ContentHash.hash(text)
        return "[REDACTED: sensitive content] hash=\(hash.prefix(12)) length=\(text.count)"
    }

    /// Redacts sensitive tool arguments while preserving non-sensitive ones.
    private func redactToolArguments(_ toolName: String, arguments: String) -> String {
        let fullyRedacted = [
            "log_food", "journal_correlation", "get_today_health", "get_health_history",
            "get_health_trends", "get_training_response_history", "get_strength_workout_history",
            "get_unified_workout_history", "food_photo", "food_search", "update_food_log",
            "journal_entry", "journal_search"
        ]
        guard !fullyRedacted.contains(toolName) else {
            return "[REDACTED: tool=\(toolName) hash=\(ContentHash.hash(arguments).prefix(12))]"
        }
        // For wiki tools, preserve the file name but redact content
        if toolName == "update_user_wiki",
           let data = arguments.data(using: .utf8),
           var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            obj["content"] = "[REDACTED: content omitted from trace]"
            if let redacted = try? JSONSerialization.data(withJSONObject: obj, options: .sortedKeys) {
                return String(data: redacted, encoding: .utf8) ?? arguments
            }
        }
        return arguments
    }

    private func redactToolResult(_ toolName: String, result: String) -> String {
        let sensitiveTools = [
            "log_food", "journal_correlation", "get_today_health", "get_health_history",
            "get_health_trends", "get_training_response_history", "get_strength_workout_history",
            "get_unified_workout_history", "update_user_wiki"
        ]
        guard sensitiveTools.contains(toolName) else { return sanitizeForTrace(result) }
        return "[REDACTED: tool result] hash=\(ContentHash.hash(result).prefix(12)) length=\(result.count)"
    }

    private static func canonicalCallSignature(name: String, arguments: String) -> String {
        guard let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              JSONSerialization.isValidJSONObject(object),
              let canonical = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let canonicalString = String(data: canonical, encoding: .utf8) else {
            return "\(name):\(arguments.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        return "\(name):\(canonicalString)"
    }

    /// Extracts the data_version field from a JSON tool result.
    private static func extractDataVersion(from jsonResult: String) -> String? {
        guard let data = jsonResult.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["data_version"] as? String
            ?? obj["context_hash"] as? String
    }

    /// Executes a tool with a timeout. If the tool exceeds the timeout, returns an error message.
    private func executeWithTimeout(name: String, arguments: String) async -> String {
        return await withTaskGroup(of: String.self) { group in
            group.addTask {
                return await self.toolRegistry.execute(name: name, arguments: arguments)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(self.toolTimeoutSeconds) * 1_000_000_000)
                return "[TIMEOUT: Tool \(name) exceeded \(self.toolTimeoutSeconds)s limit. Result may be incomplete.]"
            }
            let first = await group.next() ?? "[ERROR: Tool execution failed to return a result.]"
            group.cancelAll()
            return first
        }
    }

    /// Maps a tool name to its risk level for guardrail enforcement.
    static func riskLevel(for toolName: String) -> ToolRiskLevel {
        switch toolName {
        case "web_search", "today_health", "health_history", "health_trend",
             "workout_history", "strength_workout_history", "training_response_history",
             "journal_correlation", "render_correlation_chart":
            return .read
        case "update_user_wiki":
            return .propose
        case "update_food_log", "food_photo", "food_search", "create_training_plan":
            return .write
        case "delete_plan", "deactivate_all_plans":
            return .destructive
        default:
            // Default conservative: unknown tools are write-risk
            return .write
        }
    }

}

struct AgentLoopResult {
    var response: String
    var executedTools: [ExecutedTool]
    var finalMessages: [ChatMessage]
    /// Whether the final response was delivered via streaming.
    var wasStreamed: Bool
    var trace: AgentRunTrace

    /// Extracts wiki file names updated during tool execution.
    var wikiFiles: [String] {
        executedTools.compactMap { tool in
            guard tool.name == "update_user_wiki",
                  let data = tool.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let file = json["file"] as? String,
                  !tool.result.hasPrefix("Error") else {
                return nil
            }
            return file
        }
    }

    /// Summaries of wiki updates made during tool execution.
    var wikiUpdateSummaries: [String] {
        executedTools.compactMap { tool in
            guard tool.name == "update_user_wiki",
                  let data = tool.arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let file = json["file"] as? String,
                  let content = json["content"] as? String,
                  !tool.result.hasPrefix("Error") else {
                return nil
            }
            return "\(file): \(content)"
        }
    }
}

struct ExecutedTool: Identifiable {
    var id: UUID = UUID()
    var name: String
    var arguments: String
    var result: String
}

// MARK: - Agent Run Trace (for debugging / reproducibility)

struct AgentRunTrace: Codable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var inputMessages: [ChatMessageSnapshot]
    var executedTools: [ExecutedToolSnapshot]
    var finalResponse: String
    var contextHash: String
    var schemaVersion: String
    var providerCallCount: Int?

    struct ChatMessageSnapshot: Codable {
        var role: String
        var content: String
        var toolCalls: [String]?
    }

    struct ExecutedToolSnapshot: Codable {
        var name: String
        var arguments: String
        var result: String
    }
}
