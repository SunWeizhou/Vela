import Foundation

struct HealthAgeTrendInput: Hashable {
    var factors: [HealthAgeTrendFactor]
}

struct HealthAgeTrendFactor: Hashable, Codable {
    var name: String
    var direction: HealthAgeTrendDirection
}

enum HealthAgeTrendDirection: String, Codable, Hashable {
    case positive = "Positive"
    case neutral = "Neutral"
    case negative = "Negative"

    var score: Double {
        switch self {
        case .positive:
            return 1
        case .neutral:
            return 0
        case .negative:
            return -1
        }
    }
}

enum HealthAgeTrendLabel: String, Codable, Hashable {
    case improving = "Improving"
    case stable = "Stable"
    case worsening = "Worsening"
}

struct HealthAgeTrendResult: Codable, Hashable, Sendable {
    var trendScore: Double
    var label: HealthAgeTrendLabel
    var confidence: MetricConfidence
    var positiveFactors: [String]
    var negativeFactors: [String]
    var reasons: [String]
    var metrics: [String: Double]
    var configVersion: String = VelaAppMetadata.configVersion

    var hasData: Bool { confidence != .low || metrics["factor_count"] ?? 0 > 0 }
}

struct HealthAgeTrendEngine: ScoreEngine {
    func calculate(from input: HealthAgeTrendInput) -> HealthAgeTrendResult {
        guard !input.factors.isEmpty else {
            return HealthAgeTrendResult(
                trendScore: 0,
                label: .stable,
                confidence: .low,
                positiveFactors: [],
                negativeFactors: [],
                reasons: ["Health age trend inputs unavailable."],
                metrics: [:]
            )
        }

        let trendScore = input.factors.map(\.direction.score).reduce(0, +) / Double(input.factors.count)
        let positive = input.factors.filter { $0.direction == .positive }.map(\.name)
        let negative = input.factors.filter { $0.direction == .negative }.map(\.name)

        return HealthAgeTrendResult(
            trendScore: trendScore,
            label: label(for: trendScore),
            confidence: confidence(for: input.factors.count),
            positiveFactors: positive,
            negativeFactors: negative,
            reasons: ["Health Age Trend is a beta trend proxy, not a biological age claim."],
            metrics: [
                "trend_score": trendScore,
                "factor_count": Double(input.factors.count)
            ]
        )
    }

    private func label(for trendScore: Double) -> HealthAgeTrendLabel {
        if trendScore >= 0.35 { return .improving }
        if trendScore <= -0.35 { return .worsening }
        return .stable
    }

    private func confidence(for factorCount: Int) -> MetricConfidence {
        if factorCount >= 5 { return .high }
        if factorCount >= 3 { return .medium }
        return .low
    }
}
