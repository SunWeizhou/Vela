import Foundation
import SwiftData

@MainActor
public final class PipelineDiagnosticsLogger {
    /// Logs a health pipeline operation outcome as an auditable log entry.
    /// This integrates directly with the existing Trust Center UI.
    public static func log(
        modelContext: ModelContext,
        stage: String,
        isSuccess: Bool,
        summary: String,
        error: Error? = nil
    ) {
        let record = AgentRunRecord(
            id: UUID(),
            agentName: "health_pipeline",
            startedAt: Date(),
            endedAt: Date(),
            status: isSuccess ? "success" : "failed",
            reason: stage,
            inputContextHash: "",
            outputSummary: summary,
            toolCallsJSON: "[]",
            errorMessage: error?.localizedDescription
        )
        modelContext.insert(record)
        try? modelContext.save()
    }
}
