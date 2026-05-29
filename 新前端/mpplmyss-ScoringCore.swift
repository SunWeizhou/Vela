import Foundation

protocol ScoreEngine {
    associatedtype Input
    associatedtype Output

    func calculate(from input: Input) -> Output
}

enum ScoreBand: String, Codable, Hashable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
}

enum ScoreConfidence: String, Codable, Hashable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct StandardScoreResult: Codable, Hashable {
    var score: Double
    var band: ScoreBand
    var confidence: ScoreConfidence
    var components: [String: Double]
    var weights: [String: Double]
    var reasons: [String]
    var metrics: [String: Double]
    var configVersion: String = VelaAppMetadata.configVersion

    var hasData: Bool { !components.isEmpty }
}

enum ScoringMath {
    static func clamp(_ value: Double, min minimum: Double = 0, max maximum: Double = 100) -> Double {
        Swift.max(minimum, Swift.min(maximum, value))
    }

    static func band(for score: Double) -> ScoreBand {
        switch score {
        case ..<40:
            return .low
        case ..<70:
            return .moderate
        default:
            return .high
        }
    }

    static func weightedAverage(
        components: [String: Double],
        weights: [String: Double]
    ) -> (score: Double, normalizedWeights: [String: Double])? {
        let availableWeights = weights.filter { components[$0.key] != nil }
        let totalWeight = availableWeights.values.reduce(0, +)
        guard totalWeight > 0 else { return nil }

        let normalizedWeights = availableWeights.mapValues { $0 / totalWeight }
        let score = normalizedWeights.reduce(0) { partial, entry in
            partial + ((components[entry.key] ?? 0) * entry.value)
        }

        return (clamp(score), normalizedWeights)
    }

    static func confidence(available: Int, expected: Int) -> ScoreConfidence {
        guard expected > 0 else { return .low }
        if available == expected { return .high }
        if available >= max(1, expected - 1) { return .medium }
        return .low
    }
}
