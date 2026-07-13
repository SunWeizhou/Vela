import Foundation

// MARK: - Body Interpretation Output

struct BodyInterpretation: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var generatedAt: Date
    var contextHash: String

    // Core state
    var dailyState: DailyState
    var fatigueLevel: FatigueLevel
    var readinessScore: Double  // 0-100

    // Source analysis
    var fatigueSources: [FatigueSource]
    var primaryLimiter: PrimaryLimiter
    var secondaryLimiters: [PrimaryLimiter]

    // Narratives
    var readinessNarrative: String
    var trainingWindow: TrainingWindow
    var recoveryTasks: [RecoveryTask]
    var riskFlags: [RiskFlag]

    // Actions
    var recommendedAction: RecommendedAction
    var alternativeActions: [RecommendedAction]

    // Confidence
    var overallConfidence: DataConfidence
    var confidenceBreakdown: [String: DataConfidence]
}

// MARK: - Fatigue Analysis

enum FatigueLevel: String, Codable, Hashable, CaseIterable {
    case none
    case mild
    case moderate
    case significant
    case severe

    var label: String {
        switch self {
        case .none: return AppLanguage.stored.isChinese ? "无疲劳" : "No Fatigue"
        case .mild: return AppLanguage.stored.isChinese ? "轻度疲劳" : "Mild Fatigue"
        case .moderate: return AppLanguage.stored.isChinese ? "中度疲劳" : "Moderate Fatigue"
        case .significant: return AppLanguage.stored.isChinese ? "明显疲劳" : "Significant Fatigue"
        case .severe: return AppLanguage.stored.isChinese ? "严重疲劳" : "Severe Fatigue"
        }
    }
}

struct FatigueSource: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var category: FatigueCategory
    var contribution: Double  // 0-1, relative contribution to total fatigue
    var evidence: [String]
    var metrics: [String: Double]
}

enum FatigueCategory: String, Codable, Hashable, CaseIterable {
    case autonomic
    case muscular
    case sleepRelated
    case mentalStress
    case nutritional
    case environmental

    var label: String {
        switch self {
        case .autonomic: return AppLanguage.stored.isChinese ? "HRV 恢复信号" : "HRV Recovery Signal"
        case .muscular: return AppLanguage.stored.isChinese ? "肌肉疲劳" : "Muscular Fatigue"
        case .sleepRelated: return AppLanguage.stored.isChinese ? "睡眠不足" : "Sleep Deficit"
        case .mentalStress: return AppLanguage.stored.isChinese ? "精神压力" : "Mental Stress"
        case .nutritional: return AppLanguage.stored.isChinese ? "营养不足" : "Nutritional Deficit"
        case .environmental: return AppLanguage.stored.isChinese ? "环境因素" : "Environmental"
        }
    }
}

// MARK: - Primary Limiter

struct PrimaryLimiter: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var system: String
    var metricName: String
    var currentValue: Double
    var optimalRange: ClosedRange<Double>
    var severity: Double  // 0-1, how far from optimal
    var interpretation: String
}

// MARK: - Training Window

struct TrainingWindow: Codable, Hashable {
    var isOpen: Bool
    var recommendedIntensity: String  // "high", "moderate", "low", "rest"
    var maxDurationMinutes: Int
    var targetHRZone: String?  // e.g. "Zone 2-3"
    var bestTimeOfDay: String?
    var constraints: [String]
    var narrative: String
}

// MARK: - Recovery Tasks

struct RecoveryTask: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var category: String  // "sleep", "nutrition", "mobility", "breathwork", "hydration"
    var title: String
    var description: String
    var durationMinutes: Int?
    var priority: Int
}

// MARK: - Risk Flags

struct RiskFlag: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var level: RiskLevel
    var system: String
    var message: String
    var detail: String
    var triggeringMetrics: [String]
}

enum RiskLevel: String, Codable, Hashable {
    case info
    case warning
    case critical
}

// MARK: - Recommended Action

struct RecommendedAction: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var type: DailyActionType
    var title: String
    var subtitle: String
    var detailMarkdown: String
    var evidenceChain: [EvidenceChainItem]
    var priority: Int
}

// MARK: - Evidence Chain Item (Why This 2.0)

struct EvidenceChainItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var metricName: String
    var metricCategory: String  // "recovery", "sleep", "strain", "stress", "energy", "gait", "cardio", "environment", "nutrition"
    var currentValue: Double
    var currentValueFormatted: String
    var unit: String
    var baselineValue: Double?
    var baselineFormatted: String?
    var trend: MetricTrend
    var trendDescription: String
    var interpretation: String
    var confidence: DataConfidence
    var dataFreshness: DataFreshness
    var source: HealthDataSource
    var actionImpact: String  // How this metric drives the recommendation
}

enum MetricTrend: String, Codable, Hashable {
    case improving
    case stable
    case declining
    case insufficientData
}
