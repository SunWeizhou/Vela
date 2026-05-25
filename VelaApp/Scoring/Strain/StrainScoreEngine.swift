import Foundation

struct StrainScoreInput: Hashable {
    var activeEnergyToday: Double?
    var activeEnergyBaseline: Double?
    var exerciseMinutesToday: Double?
    var exerciseMinutesBaseline: Double?
    var workoutIntensityLoad: Double?
    var recoveryScore: Double?
    var stepCount: Double?
}

enum StrainTargetStatus: String, Codable, Hashable {
    case belowTarget = "Below target"
    case withinTarget = "Within target"
    case aboveTarget = "Above target"
}

struct StrainScoreResult: Codable, Hashable {
    var score: Double
    var band: ScoreBand
    var confidence: ScoreConfidence
    var components: [String: Double]
    var weights: [String: Double]
    var recommendedRange: ClosedRange<Int>
    var targetStatus: StrainTargetStatus
    var reasons: [String]
    var metrics: [String: Double]
    var configVersion: String = VelaAppMetadata.configVersion

    var hasData: Bool { !components.isEmpty }
}

// Based on: Banister (1991) — TRIMP (Training Impulse) model
// Method: Logarithmic mapping so high strain values are progressively harder to achieve
// Recommended range dynamically adjusts based on Recovery (periodization principle)
struct StrainScoreEngine: ScoreEngine {
    private let weights = [
        "energy_load_score": 0.40,
        "exercise_duration_score": 0.25,
        "workout_intensity_score": 0.35
    ]

    func calculate(from input: StrainScoreInput) -> StrainScoreResult {
        var components: [String: Double] = [:]
        var reasons: [String] = []
        var metrics: [String: Double] = [:]

        // Energy expenditure vs baseline (Banister-style relative load)
        if let today = input.activeEnergyToday, let baseline = input.activeEnergyBaseline, baseline > 0 {
            let ratio = today / baseline
            // Logarithmic mapping: diminishing returns at high loads
            let linearScore = ratio * 50
            let logScore = 100 * log(1 + linearScore * 0.01718) // ln(1+x) mapping
            components["energy_load_score"] = ScoringMath.clamp(logScore)
            metrics["active_energy_ratio"] = ratio
            metrics["active_energy_raw"] = today
            reasons.append("Active energy \(Int(today)) kcal (\(Int(ratio * 100))% of baseline)")
        } else if let today = input.activeEnergyToday {
            metrics["active_energy_raw"] = today
            reasons.append("Active energy baseline unavailable.")
        } else {
            reasons.append("Active energy data unavailable.")
        }

        // Exercise duration relative to baseline
        if let today = input.exerciseMinutesToday, let baseline = input.exerciseMinutesBaseline, baseline > 0 {
            let ratio = today / baseline
            let linearScore = ratio * 50
            let logScore = 100 * log(1 + linearScore * 0.01718)
            components["exercise_duration_score"] = ScoringMath.clamp(logScore)
            metrics["exercise_ratio"] = ratio
            metrics["exercise_minutes_raw"] = today
            reasons.append("Exercise \(Int(today)) min (\(Int(ratio * 100))% of baseline)")
        } else if let today = input.exerciseMinutesToday {
            metrics["exercise_minutes_raw"] = today
            reasons.append("Exercise baseline unavailable.")
        } else {
            reasons.append("Exercise data unavailable.")
        }

        // Workout intensity (HR-based TRIMP-like scoring)
        // Exponential weighting: higher HR zones contribute disproportionately
        if let workoutLoad = input.workoutIntensityLoad {
            // Apply exponential emphasis on high-intensity work
            let expScore = 100 * (1 - exp(-workoutLoad * 0.03))
            components["workout_intensity_score"] = ScoringMath.clamp(expScore)
            metrics["workout_intensity_load"] = workoutLoad
            if workoutLoad > 70 {
                reasons.append("High-intensity workout contributed significantly to strain")
            } else if workoutLoad > 30 {
                reasons.append("Moderate workout intensity")
            } else {
                reasons.append("Light workout intensity")
            }
        } else {
            reasons.append("No workout intensity data available.")
        }

        if let steps = input.stepCount {
            metrics["steps_raw"] = steps
        }

        let weighted = ScoringMath.weightedAverage(components: components, weights: weights)
        let score = weighted?.score ?? 0
        let range = recommendedRange(for: input.recoveryScore)

        return StrainScoreResult(
            score: score,
            band: ScoringMath.band(for: score),
            confidence: ScoringMath.confidence(available: components.count, expected: weights.count),
            components: components,
            weights: weighted?.normalizedWeights ?? [:],
            recommendedRange: range,
            targetStatus: targetStatus(score: score, range: range),
            reasons: reasons,
            metrics: metrics
        )
    }

    // Periodization: adjust recommended strain based on recovery state
    private func recommendedRange(for recoveryScore: Double?) -> ClosedRange<Int> {
        guard let recoveryScore else { return 40...70 }
        switch ScoringMath.band(for: recoveryScore) {
        case .low:
            return 15...40   // Low recovery → rest or very light
        case .moderate:
            return 35...65   // Moderate → controlled training
        case .high:
            return 55...85   // High recovery → can push harder
        }
    }

    private func targetStatus(score: Double, range: ClosedRange<Int>) -> StrainTargetStatus {
        if score < Double(range.lowerBound) { return .belowTarget }
        if score > Double(range.upperBound) { return .aboveTarget }
        return .withinTarget
    }
}
