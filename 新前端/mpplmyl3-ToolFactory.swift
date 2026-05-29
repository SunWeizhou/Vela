import Foundation
import SwiftData

/// Centralized factory for creating AgentTool instances.
/// CoachChatPanel uses this instead of manually constructing each tool.
enum ToolFactory {

    /// Builds the complete tool registry for a coaching session.
    /// - Parameters:
    ///   - modelContext: SwiftData context for tools that persist data
    ///   - dashboard: Current health dashboard for tools that need score context
    /// - Returns: ToolRegistry with all available tools
    static func makeRegistry(
        modelContext: ModelContext,
        dashboard: DashboardSummary
    ) -> ToolRegistry {
        ToolRegistry(tools: allTools(modelContext: modelContext, dashboard: dashboard))
    }

    /// Returns all available agent tools.
    /// Add new tools here — they'll be automatically available to the Coach.
    static func allTools(
        modelContext: ModelContext,
        dashboard: DashboardSummary
    ) -> [AgentTool] {
        [
            WebSearchTool(),
            UpdateWikiTool(modelContext: modelContext),
            HealthDataTool(),
            JournalCorrelationTool(),
            FoodLogTool(modelContext: modelContext),
            TrainingPlanTool(
                recoveryScore: dashboard.recovery.score,
                strainScore: dashboard.strain.score,
                energyBankScore: dashboard.energy.currentEnergy,
                atl: dashboard.energy.metrics["atl"] ?? dashboard.strain.score,
                ctl: dashboard.energy.metrics["ctl"] ?? dashboard.strain.score,
                tsb: dashboard.energy.metrics["tsb"] ?? 0,
                sleepScore: dashboard.sleepScore.score,
                stressIndex: dashboard.stress.stressIndex
            ),
            CreateTrainingPlanTool(modelContext: modelContext),
            RenderCorrelationChartTool(),
        ]
    }
}
