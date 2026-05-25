import Foundation

struct StressIndexInput: Hashable {
    var heartRateElevationScore: Double?
    var hrvSuppressionScore: Double?
    var sleepDebtStressScore: Double?
    var recentStrainStressScore: Double?
}

enum StressBand: String, Codable, Hashable {
    case calm = "Calm"
    case normal = "Normal"
    case elevated = "Elevated"
    case high = "High"
}

struct StressIndexResult: Codable, Hashable {
    var stressIndex: Double
    var band: StressBand
    var confidence: ScoreConfidence
    var components: [String: Double]
    var weights: [String: Double]
    var reasons: [String]
    var metrics: [String: Double]
    var configVersion: String = VelaAppMetadata.configVersion

    var hasData: Bool { !components.isEmpty }
}

struct StressIndexEngine: ScoreEngine {
    private let weights = [
        "heart_rate": 0.40,
        "hrv": 0.35,
        "sleep_debt": 0.15,
        "recent_strain": 0.10
    ]

    func calculate(from input: StressIndexInput) -> StressIndexResult {
        var components: [String: Double] = [:]
        var reasons: [String] = []

        if let value = input.heartRateElevationScore {
            components["heart_rate"] = ScoringMath.clamp(value)
            reasons.append("Heart rate elevation proxy was included")
        }
        if let value = input.hrvSuppressionScore {
            components["hrv"] = ScoringMath.clamp(value)
            reasons.append("HRV suppression proxy was included")
        }
        if let value = input.sleepDebtStressScore {
            components["sleep_debt"] = ScoringMath.clamp(value)
            reasons.append("Sleep debt context was included")
        }
        if let value = input.recentStrainStressScore {
            components["recent_strain"] = ScoringMath.clamp(value)
            reasons.append("Recent strain context was included")
        }
        if components.isEmpty {
            reasons.append("Stress proxy data unavailable.")
        }

        let weighted = ScoringMath.weightedAverage(components: components, weights: weights)
        let stressIndex = weighted?.score ?? 0

        return StressIndexResult(
            stressIndex: stressIndex,
            band: stressBand(for: stressIndex),
            confidence: ScoringMath.confidence(available: components.count, expected: weights.count),
            components: components,
            weights: weighted?.normalizedWeights ?? [:],
            reasons: reasons,
            metrics: components
        )
    }

    private func stressBand(for index: Double) -> StressBand {
        switch index {
        case ..<25:
            return .calm
        case ..<50:
            return .normal
        case ..<75:
            return .elevated
        default:
            return .high
        }
    }
}
