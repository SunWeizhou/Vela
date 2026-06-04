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
    /// - Returns: AgentLoopResult with the final text response, executed tools, and updated messages.
    func run(
        messages: [ChatMessage],
        onStreamDelta: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> AgentLoopResult {
        var agentMessages = messages
        var fullResponse = ""
        var executedTools: [ExecutedTool] = []

        for _ in 0..<maxIterations {
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
                    wasStreamed: true
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
                    wasStreamed: true
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
            wasStreamed: false
        )
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
