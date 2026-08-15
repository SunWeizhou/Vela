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
        isGhostMode: Bool = false,
        onStreamDelta: @MainActor @escaping (String) -> Void,
        onConfirmToolCall: (@Sendable (ToolCallDescription) async -> Bool)? = nil
    ) async throws -> AgentLoopResult {
        let lang = AppLanguage.stored
        let policy = ResponseLengthPolicy.forQuery(userText, lang: lang)
        // Respect the user's explicit text-model picker (vela_coach_text_model,
        // Flash/Pro). Previously the runner decided purely from CoachReasoningMode
        // and never read the stored text model, making the Settings picker a no-op.
        let selectedModel = DeepSeekTextModel.stored.apiIdentifier
        let baseProvider = services?.deepSeekProvider(apiKey: apiKey, model: selectedModel)
            ?? DeepSeekProvider(apiKey: apiKey, model: selectedModel)
        let provider = RetryingAgentChatProvider(base: baseProvider)
        let toolRegistry = ToolFactory.makeRegistry(
            modelContext: modelContext,
            dashboard: dashboard,
            readOnly: isGhostMode,
            outboundPolicy: CoachOutboundDataPolicy.stored
        )
        
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
            // ADR 0008：AI 只能提议、用户确认——写/破坏类工具必须经过确认回调。
            // 此前未传 onConfirmToolCall，create_training_plan/log_food/delete_plan
            // 等工具被提示词诱导调用后必然被拒（死功能）。
            let agentLoop = AgentLoop(
                provider: provider,
                toolRegistry: toolRegistry,
                onConfirmToolCall: onConfirmToolCall
            )
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
