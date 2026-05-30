import Foundation

public protocol ScoreEngine {
    associatedtype Input
    associatedtype Output

    func calculate(from input: Input) -> Output
}

public enum MetricBand: String, Codable, Hashable {
    case veryLow = "veryLow"
    case low = "low"
    case normal = "normal"
    case high = "high"
    case veryHigh = "veryHigh"
}

public enum MetricConfidence: String, Codable, Hashable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

public enum MetricSource: String, Codable, Hashable {
    case healthKit = "healthKit"
    case userInput = "userInput"
    case derived = "derived"
    case mixed = "mixed"
}

public enum StrainTargetStatus: String, Codable, Hashable {
    case belowTarget = "Below target"
    case withinTarget = "Within target"
    case aboveTarget = "Above target"
}

public enum EnergyBankStatus: String, Codable, Hashable {
    case depleted = "Depleted"
    case low = "Low"
    case stable = "Stable"
    case strong = "Strong"
}

public struct MetricResult: Codable, Hashable {
    public var name: String
    public var value: Double?              // 0–100; nil if not computable
    public var band: MetricBand            // veryLow / low / normal / high / veryHigh
    public var confidence: MetricConfidence // low / medium / high
    public var components: [String: Double]
    public var componentWeights: [String: Double]
    public var reasons: [String]
    public var missingInputs: [String]
    public var dataWindow: DateInterval
    public var source: MetricSource         // healthKit / userInput / derived / mixed
    public var algorithmVersion: String
    public var lastUpdated: Date

    public init(
        name: String,
        value: Double?,
        band: MetricBand,
        confidence: MetricConfidence,
        components: [String: Double],
        componentWeights: [String: Double],
        reasons: [String],
        missingInputs: [String],
        dataWindow: DateInterval,
        source: MetricSource,
        algorithmVersion: String,
        lastUpdated: Date
    ) {
        self.name = name
        self.value = value
        self.band = band
        self.confidence = confidence
        self.components = components
        self.componentWeights = componentWeights
        self.reasons = reasons
        self.missingInputs = missingInputs
        self.dataWindow = dataWindow
        self.source = source
        self.algorithmVersion = algorithmVersion
        self.lastUpdated = lastUpdated
    }

    // Backward compatibility for SwiftUI views
    public var score: Double { value ?? 0 }
    public var weights: [String: Double] { componentWeights }
    public var metrics: [String: Double] { components }
    public var configVersion: String { algorithmVersion }
    public var hasData: Bool { value != nil && !components.isEmpty }

    // For EnergyBankResult
    public var morningEnergy: Double { components["morningEnergy"] ?? (value ?? 0) }
    public var currentEnergy: Double { value ?? 0 }
    public var status: EnergyBankStatus {
        switch value ?? 0 {
        case ..<25: return .depleted
        case ..<50: return .low
        case ..<75: return .stable
        default: return .strong
        }
    }

    // For StrainScoreResult
    public var recommendedRange: ClosedRange<Int> {
        let lower = components["recommended_lower"] ?? 40.0
        let upper = components["recommended_upper"] ?? 70.0
        return Int(lower)...Int(upper)
    }
    public var targetStatus: StrainTargetStatus {
        let v = value ?? 0
        let r = recommendedRange
        if v < Double(r.lowerBound) { return .belowTarget }
        if v > Double(r.upperBound) { return .aboveTarget }
        return .withinTarget
    }

    // For StressIndexResult
    public var stressIndex: Double { value ?? 0 }
}

public enum ScoreBand: String, Codable, Hashable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

public enum ScoreConfidence: String, Codable, Hashable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

// Keep StandardScoreResult as a thin wrapper or backward compatibility struct if needed elsewhere,
// but all engines will be refactored to output MetricResult directly.
public struct StandardScoreResult: Codable, Hashable {
    public var score: Double
    public var band: ScoreBand
    public var confidence: ScoreConfidence
    public var components: [String: Double]
    public var weights: [String: Double]
    public var reasons: [String]
    public var metrics: [String: Double]
    public var configVersion: String = "v0.1"

    public var hasData: Bool { !components.isEmpty }

    public init(
        score: Double,
        band: ScoreBand,
        confidence: ScoreConfidence,
        components: [String: Double],
        weights: [String: Double],
        reasons: [String],
        metrics: [String: Double],
        configVersion: String = "v0.1"
    ) {
        self.score = score
        self.band = band
        self.confidence = confidence
        self.components = components
        self.weights = weights
        self.reasons = reasons
        self.metrics = metrics
        self.configVersion = configVersion
    }
}

public enum ScoringMath {
    public static func clamp(_ value: Double, min minimum: Double = 0, max maximum: Double = 100) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    public static func band(for score: Double) -> MetricBand {
        switch score {
        case ..<25:
            return .veryLow
        case ..<45:
            return .low
        case ..<75:
            return .normal
        case ..<90:
            return .high
        default:
            return .veryHigh
        }
    }

    public static func confidence(available: Int, expected: Int) -> MetricConfidence {
        guard expected > 0 else { return .low }
        if available == expected { return .high }
        if available >= max(1, expected - 1) { return .medium }
        return .low
    }
}
