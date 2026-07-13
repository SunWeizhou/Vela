import Foundation
import SwiftData

@MainActor
final class CoachRequestRunner {
    func runRequest(
        userText: String,
        apiKey: String,
        chatMessages: [ChatMessage],
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        services: VelaServices?,
        onStreamDelta: @MainActor @escaping (String) -> Void
    ) async throws -> AgentLoopResult {
        let baseProvider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
        let provider = RetryingAgentChatProvider(base: baseProvider)
        let toolRegistry = ToolFactory.makeRegistry(
            modelContext: modelContext,
            dashboard: dashboard
        )
        
        let lang = AppLanguage.stored
        let policy = ResponseLengthPolicy.forQuery(userText, lang: lang)
        
        if policy == .casual {
            var fullResponse = ""
            let stream = provider.streamChat(messages: chatMessages)
            for try await delta in stream {
                fullResponse += delta
                onStreamDelta(delta)
            }
            
            let trace = AgentRunTrace(
                id: UUID(),
                startedAt: Date(),
                endedAt: Date(),
                inputMessages: chatMessages.map {
                    AgentRunTrace.ChatMessageSnapshot(
                        role: $0.role.rawValue,
                        content: $0.content,
                        toolCalls: $0.toolCalls?.map(\.name)
                    )
                },
                executedTools: [],
                finalResponse: fullResponse,
                contextHash: ContentHash.hash(chatMessages.map(\.content).joined(separator: "\n")),
                schemaVersion: "agentTrace.v1",
                providerCallCount: 1
            )
            return AgentLoopResult(
                response: fullResponse,
                executedTools: [],
                finalMessages: chatMessages,
                wasStreamed: true,
                trace: trace
            )
        } else {
            let agentLoop = AgentLoop(provider: provider, toolRegistry: toolRegistry)
            let snapshotVersion = ContentHash.hash("\(dashboard.date.timeIntervalSince1970)-\(dashboard.source.rawValue)")
            return try await agentLoop.run(
                messages: chatMessages,
                onStreamDelta: { delta in
                    onStreamDelta(delta)
                },
                initialDataVersion: snapshotVersion
            )
        }
    }
}
