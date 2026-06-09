import Foundation

struct AgentContextEnvelope: Codable, Hashable {
    var metadata: AgentContextMetadata
    var todaySummary: [String: String]
    var bodyState: [String: String]? = nil
    var sleep: [String: String]
    var recovery: [String: String]
    var strain: [String: String]
    var workouts: [String: String]
    var unifiedWorkouts: [String: String]?
    var stress: [String: String]
    var energyBank: [String: String]
    var healthAgeTrend: [String: String]
    var recentTrends: [String: String]
    var weeklyTrends: [String: String]
    var nutrition: [String: String]
    var journal: [String: String]
    var historicalAIReports: [String: String]
    var userWiki: [String: String]
    var agentInstruction: [String: String]
    var extendedMetrics: [String: String]
    var strengthTraining: [String: String]?

    enum CodingKeys: String, CodingKey {
        case metadata
        case todaySummary = "today_summary"
        case bodyState = "body_state"
        case sleep
        case recovery
        case strain
        case workouts
        case unifiedWorkouts = "unified_workouts"
        case stress
        case energyBank = "energy_bank"
        case healthAgeTrend = "health_age_trend"
        case recentTrends = "recent_trends"
        case weeklyTrends = "weekly_trends"
        case nutrition
        case journal
        case historicalAIReports = "historical_ai_reports"
        case userWiki = "user_wiki"
        case agentInstruction = "agent_instruction"
        case extendedMetrics = "extended_metrics"
        case strengthTraining = "strength_training"
    }
}

struct AgentContextMetadata: Codable, Hashable {
    var generatedAt: Date
    var contextWindow: String

    enum CodingKeys: String, CodingKey {
        case generatedAt = "generated_at"
        case contextWindow = "context_window"
    }
}

struct JournalContextEntry: Codable, Hashable {
    var tags: [String]
    var text: String
}

enum AIReportType: String, Codable, Hashable, CaseIterable, Identifiable {
    case morningBrief = "morning_brief"
    case sleepReview = "sleep_review"
    case workoutReadiness = "workout_readiness"
    case weeklyReview = "weekly_review"
    case coachPrompt = "coach_prompt"

    var id: String { rawValue }

    static var reportTypes: [AIReportType] {
        [.morningBrief, .sleepReview, .workoutReadiness, .weeklyReview]
    }

    var title: String {
        switch self {
        case .morningBrief:
            return "Morning Brief"
        case .sleepReview:
            return "Sleep Review"
        case .workoutReadiness:
            return "Workout Readiness"
        case .weeklyReview:
            return "Weekly Review"
        case .coachPrompt:
            return "Coach Response"
        }
    }
}

struct GeneratedAIReport: Codable, Hashable {
    var type: AIReportType
    var title: String
    var markdownContent: String
    var contextSnapshot: String
    var createdAt: Date
}

// MARK: - Strength Training Context

struct StrengthTrainingContext: Codable, Hashable {
    var sessions7d: Int
    var sessions14d: Int
    var hardSets7d: Int
    var hardSets14d: Int
    var volume7dKg: Double
    var volume14dKg: Double
    var muscleGroupSets7d: [String: Int]
    var muscleGroupSets14d: [String: Int]
    var recentPRs: [String]
    var localFatigue: [String: LocalMuscleFatigue]
    var recentExerciseProgress: [ExerciseProgressSummary]
    var lastSessionSummary: String
    var trainingAdaptation: String
    var recoveryResponseSummary: String = "No post-training response data yet."
    var averageNextDayRecoveryDelta: Double? = nil
    var flaggedResponseCount: Int = 0
    var recentWorkoutDetails: String? = nil
}

struct ExerciseProgressSummary: Codable, Hashable {
    var exerciseName: String
    var setsCount: Int
    var maxWeightKg: Double
    var estimated1RMPeakKg: Double
}

struct UnifiedWorkoutContextEntry: Codable, Hashable {
    var id: UUID
    var source: String
    var title: String
    var activityType: String
    var startedAt: Date
    var endedAt: Date
    var durationMinutes: Double
    var energyKilocalories: Double?
    var averageHeartRate: Double?
    var rpe: Double?
    var linkedStrengthWorkoutId: UUID?
    var linkedHealthKitWorkoutId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case title
        case activityType = "activity_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case energyKilocalories = "energy_kilocalories"
        case averageHeartRate = "average_heart_rate"
        case rpe
        case linkedStrengthWorkoutId = "linked_strength_workout_id"
        case linkedHealthKitWorkoutId = "linked_healthkit_workout_id"
    }

    init(event: WorkoutEventRecord) {
        id = event.id
        source = event.source
        title = event.title
        activityType = event.activityType
        startedAt = event.startedAt
        endedAt = event.endedAt
        durationMinutes = event.durationMinutes
        energyKilocalories = event.energyKilocalories
        averageHeartRate = event.averageHeartRate
        rpe = event.rpe
        linkedStrengthWorkoutId = event.linkedStrengthWorkoutId
        linkedHealthKitWorkoutId = event.linkedHealthKitWorkoutId
    }
}
