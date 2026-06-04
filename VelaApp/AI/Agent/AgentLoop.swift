import Foundation
import SwiftData

// MARK: - Agent Loop

/// Encapsulates the tool-call loop: sends messages to LLM, executes tool calls, collects results.
/// Extracted from CoachChatVM.send() so that CoachChatPanel.swift remains UI-only.
struct AgentLoop {

    let provider: DeepSeekProvider
    let toolRegistry: ToolRegistry
    let maxIterations: Int

    init(provider: DeepSeekProvider, toolRegistry: ToolRegistry, maxIterations: Int = 3) {
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

        for iteration in 0..<maxIterations {
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

                // Stream the final response after tool execution (not on last iteration fallback)
                if iteration < maxIterations - 1 {
                    let stream = provider.streamChat(messages: agentMessages)
                    var streamedText = ""
                    for try await delta in stream {
                        streamedText += delta
                        if let onStreamDelta {
                            await onStreamDelta(delta)
                        }
                    }
                    fullResponse = streamedText
                    return AgentLoopResult(
                        response: fullResponse,
                        executedTools: executedTools,
                        finalMessages: agentMessages,
                        wasStreamed: true
                    )
                }
                continue
            }

            // Final text response (no more tool calls)
            fullResponse = response.content
            break
        }

        if fullResponse.isEmpty {
            fullResponse = "I wasn't able to generate a response. Please try again."
        }

        return AgentLoopResult(
            response: fullResponse,
            executedTools: executedTools,
            finalMessages: agentMessages,
            wasStreamed: false
        )
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
