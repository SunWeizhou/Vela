import Foundation
import SwiftData

@MainActor
final class CoachPersistenceWriter {
    func persistThread(messages: [CoachChatVM.ChatMsg], currentSession: CoachSessionRecord?, modelContext: ModelContext) throws {
        guard let currentSession else { return }
        let persistable = messages.filter { !$0.isStreaming }
        let data = try JSONEncoder().encode(persistable)
        guard let json = String(data: data, encoding: .utf8) else { return }
        
        currentSession.serializedMessages = json
        currentSession.updatedAt = Date()
        try modelContext.save()
    }

    func persistInteraction(
        userText: String,
        assistantText: String,
        focus: CoachContextFocus,
        contextHash: String,
        currentSession: CoachSessionRecord?,
        modelContext: ModelContext
    ) throws {
        modelContext.insert(CoachInteractionRecord(
            userText: userText,
            assistantText: assistantText,
            focus: focus.title.lowercased().replacingOccurrences(of: " ", with: "_"),
            contextHash: contextHash,
            sessionId: currentSession?.id
        ))
        try modelContext.save()
    }

    func persistAgentTrace(_ trace: AgentRunTrace, modelContext: ModelContext) throws {
        let toolCallsJSON: String
        if let data = try? JSONEncoder().encode(trace.executedTools),
           let json = String(data: data, encoding: .utf8) {
            toolCallsJSON = json
        } else {
            toolCallsJSON = "[]"
        }
        modelContext.insert(AgentRunRecord(
            id: trace.id,
            agentName: "coach",
            startedAt: trace.startedAt,
            endedAt: trace.endedAt,
            status: .success,
            reason: [trace.schemaVersion, trace.contextHashSource]
                .compactMap { $0 }
                .joined(separator: ":"),
            inputContextHash: trace.contextHash,
            outputSummary: trace.finalResponse,
            toolCallsJSON: toolCallsJSON
        ))
        try modelContext.save()
    }
}
