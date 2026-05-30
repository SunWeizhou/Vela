import Foundation

struct RecoveryScoreInput: Hashable {
    var hrvToday: Double?
    var hrvBaseline: Double?
    var hrvHistory: [Double] = []
    var restingHeartRateToday: Double?
    var restingHeartRateBaseline: Double?
    var rhrHistory: [Double] = []
    var sleepScoreLastNight: Double?
    var strainScoreYesterday: Double?
}

// Based on: Plews et al. (2013) - Training Adaptation and Heart Rate Variability
// Method: Individual HRV/RHR z-scores relative to rolling baseline
// Also: Buchheit (2014) - Monitoring Training Status with HR Measures
struct RecoveryScoreEngine: ScoreEngine {
    private let weights = [
        "hrv": 0.40,        // Plews et al.: HRV is the primary autonomic recovery marker
        "rhr": 0.20,        // Buchheit: RHR elevation indicates incomplete recovery
        "sleep": 0.30,      // Buysse et al.: Sleep quality is a major recovery determinant
        "prior_strain": 0.10 // Banister TRIMP: Prior load creates recovery demand
    ]

    func calculate(from input: RecoveryScoreInput) -> StandardScoreResult {
        var components: [String: Double] = [:]
        var reasons: [String] = []
        var metrics: [String: Double] = [:]

        // HRV component — z-score approach (Plews et al. 2013)
        // Uses tanh mapping for smooth, bounded transformation
        if let hrvToday = input.hrvToday, let baseline = input.hrvBaseline, baseline > 0 {
            let lnToday = log(max(hrvToday, 1))
            let lnBaseline = log(max(baseline, 1))
            
            // Calculate actual individual SD of lnHRV if history is available, otherwise fallback
            let estimatedSD: Double = {
                if !input.hrvHistory.isEmpty {
                    let lnHistory = input.hrvHistory.map { log(max($0, 1)) }
                    let mean = lnHistory.reduce(0, +) / Double(lnHistory.count)
                    let variance = lnHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Double(lnHistory.count)
                    let actualSD = sqrt(variance)
                    return actualSD > 0.01 ? actualSD : (lnBaseline * 0.15)
                }
                return lnBaseline * 0.15
            }()
            
            let zScore = estimatedSD > 0 ? (lnToday - lnBaseline) / estimatedSD : 0
            
            // Plews et al. (2013): Abnormally elevated HRV (Z-score > 2.5) combined with high prior strain
            // indicates autonomic hyper-parasympathetic activation (overtraining saturation/overreaching).
            let score: Double
            if zScore > 2.5 && (input.strainScoreYesterday ?? 0) > 70 {
                score = 50 - 25 * tanh((zScore - 2.5) * 1.0)
                reasons.append("HRV abnormally elevated (z=\(String(format: "%.1f", zScore))) — potential parasympathetic saturation / overreaching")
            } else {
                score = 50 + 48 * tanh(zScore * 0.6)
                if zScore < -1.0 {
                    reasons.append("HRV significantly below personal baseline (z=\(String(format: "%.1f", zScore)))")
                } else if zScore < -0.3 {
                    reasons.append("HRV slightly below baseline")
                } else if zScore > 0.5 {
                    reasons.append("HRV above baseline — good autonomic recovery")
                } else {
                    reasons.append("HRV within normal range")
                }
            }
            components["hrv"] = ScoringMath.clamp(score)
            metrics["hrv_z_score"] = zScore
            metrics["hrv_today"] = hrvToday
            metrics["hrv_baseline"] = baseline
        } else {
            reasons.append("HRV data unavailable; recovery score is based on remaining metrics.")
        }

        // RHR component — z-score approach (Buchheit 2014)
        // Note: Direction is inverted — higher RHR = worse recovery
        if let rhrToday = input.restingHeartRateToday, let baseline = input.restingHeartRateBaseline, baseline > 0 {
            
            // Calculate actual individual SD of RHR if history is available, otherwise fallback
            let estimatedSD: Double = {
                if !input.rhrHistory.isEmpty {
                    let mean = input.rhrHistory.reduce(0, +) / Double(input.rhrHistory.count)
                    let variance = input.rhrHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Double(input.rhrHistory.count)
                    let actualSD = sqrt(variance)
                    return actualSD > 0.5 ? actualSD : (baseline * 0.05)
                }
                return baseline * 0.05
            }()
            
            let zScore = estimatedSD > 0 ? (rhrToday - baseline) / estimatedSD : 0
            // Inverted: positive z (RHR up) → lower score
            let score = 50 - 48 * tanh(zScore * 0.5)
            components["rhr"] = ScoringMath.clamp(score)
            metrics["rhr_z_score"] = zScore
            metrics["rhr_today"] = rhrToday
            metrics["rhr_baseline"] = baseline

            if zScore > 1.5 {
                reasons.append("Resting heart rate elevated \(Int(rhrToday - baseline)) bpm above baseline")
            } else if zScore > 0.5 {
                reasons.append("Resting heart rate slightly above baseline")
            } else if zScore < -0.5 {
                reasons.append("Resting heart rate below baseline — good sign")
            } else {
                reasons.append("Resting heart rate close to baseline")
            }
        } else {
            reasons.append("Resting heart rate data unavailable.")
        }

        // Sleep quality component — direct pass-through of multi-dimensional sleep score
        // Based on: Buysse (2014) Sleep Health framework
        if let sleepScore = input.sleepScoreLastNight {
            components["sleep"] = ScoringMath.clamp(sleepScore)
            metrics["sleep_score"] = sleepScore
            if sleepScore >= 80 {
                reasons.append("Strong sleep quality supported recovery")
            } else if sleepScore >= 60 {
                reasons.append("Moderate sleep quality")
            } else {
                reasons.append("Poor sleep quality is limiting recovery")
            }
        } else {
            reasons.append("Sleep score unavailable.")
        }

        // Prior strain load factor
        // Based on: Banister (1991) — high training impulse creates recovery demand
        if let priorStrain = input.strainScoreYesterday {
            // High strain → lower recovery score contribution
            let penalty = max(0, (priorStrain - 50) / 50) * 40
            let score = max(10, 90 - penalty)
            components["prior_strain"] = score
            metrics["strain_score_yesterday"] = priorStrain
            if priorStrain > 75 {
                reasons.append("High strain yesterday may require extended recovery")
            } else {
                reasons.append("Yesterday's strain was manageable")
            }
        } else {
            reasons.append("Prior strain unavailable.")
        }

        let weighted = ScoringMath.weightedAverage(components: components, weights: weights)
        let score = weighted?.score ?? 0

        return StandardScoreResult(
            score: score,
            band: ScoringMath.band(for: score),
            confidence: ScoringMath.confidence(available: components.count, expected: weights.count),
            components: components,
            weights: weighted?.normalizedWeights ?? [:],
            reasons: reasons,
            metrics: metrics
        )
    }
}
