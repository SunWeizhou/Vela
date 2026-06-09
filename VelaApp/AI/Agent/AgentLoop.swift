import Foundation
import SwiftData

// MARK: - Agent Loop

protocol AgentChatProvider: Sendable {
    func chat(messages: [ChatMessage], tools: [[String: Value]]?) async throws -> LLMResponse
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}

extension DeepSeekProvider: AgentChatProvider {}

/// Encapsulates the tool-call loop: sends messages to LLM, executes tool calls, collects results.
/// Extracted from CoachChatVM.send() so that CoachChatPanel.swift remains UI-only.
struct AgentLoop {

    let provider: any AgentChatProvider
    let toolRegistry: ToolRegistry
    let maxIterations: Int

    init(provider: any AgentChatProvider, toolRegistry: ToolRegistry, maxIterations: Int = 3) {
        self.provider = provider
        self.toolRegistry = toolRegistry
        self.maxIterations = maxIterations
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

        for _ in 0..<maxIterations {
            // ── Inject data-version notice if tools returned fresher data than the snapshot ──
            if let currentVersion = activeDataVersion, let initial = initialDataVersion, currentVersion != initial {
                let notice = "[DATA VERSION CHANGE: tool-returned data (v:\(currentVersion)) is newer than the initial snapshot (v:\(initial)). Prefer the tool-fetched values over any inline snapshot for the rest of this response.]"
                if !dataVersionWarnings.contains(notice) {
                    dataVersionWarnings.append(notice)
                    agentMessages.append(ChatMessage(role: .system, content: notice))
                }
            }

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
                    let result = await toolRegistry.execute(name: tc.name, arguments: tc.arguments)
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
                fullResponse = try await streamFinalResponse(messages: agentMessages, onStreamDelta: onStreamDelta)
                return AgentLoopResult(
                    response: fullResponse,
                    executedTools: executedTools,
                    finalMessages: agentMessages,
                    wasStreamed: true,
                    trace: makeTrace(
                        startedAt: startedAt,
                        inputMessages: messages,
                        executedTools: executedTools,
                        finalResponse: fullResponse,
                        contextHash: initialDataVersion
                    )
                )
            } else {
                fullResponse = response.content
            }
            break
        }

        if fullResponse.isEmpty {
            if let onStreamDelta {
                fullResponse = try await streamFinalResponse(messages: agentMessages, onStreamDelta: onStreamDelta)
                return AgentLoopResult(
                    response: fullResponse,
                    executedTools: executedTools,
                    finalMessages: agentMessages,
                    wasStreamed: true,
                    trace: makeTrace(
                        startedAt: startedAt,
                        inputMessages: messages,
                        executedTools: executedTools,
                        finalResponse: fullResponse,
                        contextHash: initialDataVersion
                    )
                )
            } else {
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
                contextHash: initialDataVersion
            )
        )
    }

    private func makeTrace(
        startedAt: Date,
        inputMessages: [ChatMessage],
        executedTools: [ExecutedTool],
        finalResponse: String,
        contextHash: String?
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
                    content: $0.content,
                    toolCalls: $0.toolCalls?.map(\.name)
                )
            },
            executedTools: executedTools.map {
                AgentRunTrace.ExecutedToolSnapshot(
                    name: $0.name,
                    arguments: $0.arguments,
                    result: $0.result
                )
            },
            finalResponse: finalResponse,
            contextHash: resolvedHash,
            schemaVersion: "agentTrace.v1"
        )
    }

    /// Extracts the data_version field from a JSON tool result.
    private static func extractDataVersion(from jsonResult: String) -> String? {
        guard let data = jsonResult.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return obj["data_version"] as? String
            ?? obj["context_hash"] as? String
    }

    private func streamFinalResponse(
        messages: [ChatMessage],
        onStreamDelta: @MainActor @Sendable (String) -> Void
    ) async throws -> String {
        let stream = provider.streamChat(messages: messages)
        var streamedText = ""
        for try await delta in stream {
            streamedText += delta
            await onStreamDelta(delta)
        }
        return streamedText
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
