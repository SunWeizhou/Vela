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
    @MainActor
    static func makeRegistry(
        modelContext: ModelContext,
        dashboard: DashboardSummary,
        readOnly: Bool = false,
        outboundPolicy: CoachOutboundDataPolicy = .all
    ) -> ToolRegistry {
        let tools = allTools(modelContext: modelContext, dashboard: dashboard)
            .filter { toolIsAllowed($0.name, policy: outboundPolicy) }
        return ToolRegistry(tools: readOnly ? tools.filter { $0.riskLevel == .read } : tools)
    }

    private static func toolIsAllowed(_ name: String, policy: CoachOutboundDataPolicy) -> Bool {
        switch name {
        case "web_search":
            return policy.webSearch
        case "get_today_health", "get_health_history", "get_health_trends":
            return policy.health
        case "get_unified_workout_history", "get_strength_workout_history",
             "get_training_response_history", "generate_training_plan",
             "create_training_plan", "delete_plan":
            return policy.training
        case "journal_correlation", "render_correlation_chart":
            return policy.journal && policy.health
        case "log_food":
            return policy.nutrition
        default:
            return true
        }
    }

    /// Returns all available agent tools.
    /// Add new tools here — they'll be automatically available to the Coach.
    @MainActor
    static func allTools(
        modelContext: ModelContext,
        dashboard: DashboardSummary
    ) -> [AgentTool] {
        let executionContext = ToolExecutionContext(modelContext: modelContext, dashboard: dashboard)
        return [
            WebSearchTool(),
            UpdateWikiTool(executionContext: executionContext),
            TodayHealthTool(executionContext: executionContext),
            HealthHistoryTool(executionContext: executionContext),
            HealthTrendTool(executionContext: executionContext),
            UnifiedWorkoutHistoryTool(executionContext: executionContext),
            StrengthWorkoutHistoryTool(executionContext: executionContext),
            TrainingResponseHistoryTool(executionContext: executionContext),
            JournalCorrelationTool(executionContext: executionContext),
            FoodLogTool(executionContext: executionContext),
            TrainingPlanTool(decision: dashboard.trainingDecision),
            CreateTrainingPlanTool(executionContext: executionContext),
            DeleteTrainingPlanTool(executionContext: executionContext),
            RenderCorrelationChartTool(),
        ]
    }
}
