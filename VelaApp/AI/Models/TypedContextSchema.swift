import Foundation

// MARK: - Typed Metric Value

public enum DataFreshness: String, Codable, Hashable, CaseIterable, Sendable {
    case live
    case today
    case recent
    case stale
    case missing
}

public enum DataConfidence: String, Codable, Hashable, CaseIterable, Sendable {
    case high
    case medium
    case low
    case unavailable
}

public enum HealthDataSource: String, Codable, Hashable, CaseIterable, Sendable {
    case healthKit
    case userProvided
    case aiEstimated
    case wikiProfile
    case biomarkerLab
    case computed
}

struct BaselineComparison: Codable, Hashable, Sendable {
    var baselineValue: Double?
    var delta: Double?
    var deltaPercent: Double?
    var zScore: Double?
    var windowDays: Int?
}

struct MetricValue<T: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    var value: T?
    var unit: String?
    var source: HealthDataSource
    var measuredAt: Date?
    var freshness: DataFreshness
    var confidence: DataConfidence
    var baseline: BaselineComparison?
    var note: String?

    static func missing(unit: String? = nil, note: String? = nil) -> MetricValue<T> {
        MetricValue(value: nil, unit: unit, source: .healthKit, freshness: .missing, confidence: .unavailable, note: note)
    }

    static func live(
        _ value: T,
        unit: String? = nil,
        source: HealthDataSource = .healthKit,
        measuredAt: Date? = nil,
        freshness: DataFreshness = .live,
        confidence: DataConfidence = .high,
        baseline: BaselineComparison? = nil
    ) -> MetricValue<T> {
        MetricValue(
            value: value,
            unit: unit,
            source: source,
            measuredAt: measuredAt,
            freshness: freshness,
            confidence: confidence,
            baseline: baseline
        )
    }
}

// MARK: - Typed Domain Contexts

struct RecoveryContext: Codable, Hashable, Sendable {
    var score: MetricValue<Double>
    var band: String
    var hrv: MetricValue<Double>
    /// A2：RMSSD 派生指标（缺失时引擎回退 SDNN，但此处如实标注 missing）。
    var hrvRmssd: MetricValue<Double>?
    var restingHeartRate: MetricValue<Double>
    var respiratoryRate: MetricValue<Double>
    var topReason: String?
    /// 联通专项批次 3：v2 上下文补齐 z-score（此前 v1 有、v2 反而丢）。
    var hrvZScore: MetricValue<Double>
    var rhrZScore: MetricValue<Double>
}

struct SleepContext: Codable, Hashable, Sendable {
    var score: MetricValue<Double>
    var band: String
    var totalMinutes: MetricValue<Int>
    var efficiency: MetricValue<Double>
    var remPercent: MetricValue<Double>
    var deepPercent: MetricValue<Double>
    var coreMinutes: MetricValue<Int>
    var remMinutes: MetricValue<Int>
    var deepMinutes: MetricValue<Int>
    var awakeMinutes: MetricValue<Int>
    var bedtime: Date?
    var wakeTime: Date?
    var topReason: String?
}

struct StrainContext: Codable, Hashable, Sendable {
    var score: MetricValue<Double>
    var band: String
    var targetStatus: String
    var recommendedRangeLower: Int
    var recommendedRangeUpper: Int
    var steps: MetricValue<Int>
    var activeEnergyKcal: MetricValue<Int>
    var exerciseMinutes: MetricValue<Int>
}

struct StressContext: Codable, Hashable, Sendable {
    var stressIndex: MetricValue<Double>
    var band: String
    var confidence: DataConfidence
    var proxyNote: String
    /// 联通专项批次 3：压力六因子（此前 v2 只有聚合值，agent 无法解释压力来源）。
    var rhrStress: MetricValue<Double>
    var hrvStress: MetricValue<Double>
    var respStress: MetricValue<Double>
    var tempStress: MetricValue<Double>
    var sleepDebtStress: MetricValue<Double>
    var loadStress: MetricValue<Double>
}

struct EnergyBankContext: Codable, Hashable, Sendable {
    var morningEnergy: MetricValue<Double>
    var currentEnergy: MetricValue<Double>
    var status: String
    var chargeEfficiency: MetricValue<Double>
    var atl7Day: MetricValue<Double>
    var ctl42Day: MetricValue<Double>
    var tsbFreshness: MetricValue<Double>
    /// 联通专项批次 3：v2 补齐 ACWR（此前 v1 有、v2 丢）。
    var acwrRatio: MetricValue<Double>
}

struct TrainingContext: Codable, Hashable, Sendable {
    var activePlan: ActivePlanSummary?
    var workoutCount: Int
    var workoutTypes: [String]
    var totalEnergyKcal: Double
    var totalDurationMin: Int
    var workoutListJSON: String
}

struct ActivePlanSummary: Codable, Hashable, Sendable {
    var title: String
    var goalDescription: String
    var weeksCount: Int
    var completedDays: Int
    var totalDays: Int
}

struct NutritionContext: Codable, Hashable, Sendable {
    var recentEntries: [String]
    var recentCount: Int
    var totalCalories: Int
    var totalProtein: Int
    var totalCarbs: Int
    var totalFat: Int
    var totalFiber: Int
}

struct ExtendedMetricsContext: Codable, Hashable, Sendable {
    var age: Int?
    var biologicalSex: String?
    var heightCm: MetricValue<Double>
    var weightKg: MetricValue<Double>
    var bmi: MetricValue<Double>
    var bodyFatPct: MetricValue<Double>
    var vo2Max: MetricValue<Double>
    var walkingSpeed: MetricValue<Double>
    var walkingAsymmetry: MetricValue<Double>
    var doubleSupportPct: MetricValue<Double>
    var spo2: MetricValue<Double>
    var bloodPressureSystolic: MetricValue<Int>?
    var bloodPressureDiastolic: MetricValue<Int>?
    var bloodGlucose: MetricValue<Double>?
    var waterMl: MetricValue<Int>?
    var caffeineMg: MetricValue<Int>?
    var envNoiseDb: MetricValue<Double>?
    var daylightMinutes: MetricValue<Int>?
    var wristTempC: MetricValue<Double>?
}

struct AgentBodyStateContext: Codable, Hashable, Sendable {
    var readiness: BodyReadiness
    var confidence: DataConfidence
    var freshness: DataFreshness
    var source: String
    var activeStatus: String
    var contextHash: String
    var drivers: [BodyStateDriver]
}

struct AgentTrainingDecisionContext: Codable, Hashable, Sendable {
    var readinessLevel: String
    var readinessGuidance: String
    var volumeMultiplier: Double
    var maxIntensity: String
    var recommendedTrainingType: String
    var reasons: String
    var confidence: DataConfidence
}

struct AgentDataCoverageContext: Codable, Hashable, Sendable {
    var availableSections: Int
    var totalSections: Int
    var missingSections: [String]
    var confidence: DataConfidence
}

// MARK: - Canonical Agent Fact Snapshot (v2)

struct AgentFactSnapshot: Codable, Hashable, Sendable {
    var schemaVersion: String
    var contextHash: String
    var generatedAt: Date
    var contextWindow: String

    var bodyState: AgentBodyStateContext
    var trainingDecision: AgentTrainingDecisionContext
    var dataCoverage: AgentDataCoverageContext

    var recovery: RecoveryContext
    var sleep: SleepContext
    var strain: StrainContext
    var stress: StressContext
    var energyBank: EnergyBankContext
    var training: TrainingContext
    var nutrition: NutritionContext
    var extendedMetrics: ExtendedMetricsContext
    var strengthTraining: StrengthTrainingContext?

    var recentTrends: [String: String]
    var weeklyTrends: [String: String]
    var journalEntries: [String]
    var historicalReports: [String]
    var userWiki: [String: String]
    /// A1：完整 Daily Operating Plan（主行动/支持行动/理由/置信度）。
    /// 此前 LLM 只拿到 trainingDecision 切片，无法讨论跨域计划的完整内容。
    var dailyOperatingPlan: [String: String]?
}
