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
    func run(messages: [ChatMessage]) async throws -> AgentLoopResult {
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

            fullResponse = response.content
            break
        }

        return AgentLoopResult(
            response: fullResponse,
            executedTools: executedTools,
            finalMessages: agentMessages
        )
    }
}

struct AgentLoopResult {
    var response: String
    var executedTools: [ExecutedTool]
    var finalMessages: [ChatMessage]
}

struct ExecutedTool: Identifiable {
    var id: UUID = UUID()
    var name: String
    var arguments: String
    var result: String

    var wikiFiles: [String] {
        guard name == "update_user_wiki",
              let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let file = json["file"] as? String else {
            return []
        }
        return [file]
    }
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

    init(contextHash: String, schemaVersion: String) {
        self.id = UUID()
        self.startedAt = Date()
        self.inputMessages = []
        self.executedTools = []
        self.finalResponse = ""
        self.contextHash = contextHash
        self.schemaVersion = schemaVersion
    }
}
