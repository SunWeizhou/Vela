import Foundation

struct SleepScoreInput: Hashable {
    var totalSleepMinutes: Double?
    var sleepTargetMinutes: Double
    var bedtimeOffsetMinutes: Double?
    var wakeOffsetMinutes: Double?
    // New fields for the 5-dimension framework
    var remMinutes: Double?
    var deepMinutes: Double?
    var awakeMinutes: Double?
    var awakeCount: Int?
    var inBedMinutes: Double?

    init(
        totalSleepMinutes: Double?,
        sleepTargetMinutes: Double = 450,
        bedtimeOffsetMinutes: Double?,
        wakeOffsetMinutes: Double?,
        remMinutes: Double? = nil,
        deepMinutes: Double? = nil,
        awakeMinutes: Double? = nil,
        awakeCount: Int? = nil,
        inBedMinutes: Double? = nil
    ) {
        self.totalSleepMinutes = totalSleepMinutes
        self.sleepTargetMinutes = sleepTargetMinutes
        self.bedtimeOffsetMinutes = bedtimeOffsetMinutes
        self.wakeOffsetMinutes = wakeOffsetMinutes
        self.remMinutes = remMinutes
        self.deepMinutes = deepMinutes
        self.awakeMinutes = awakeMinutes
        self.awakeCount = awakeCount
        self.inBedMinutes = inBedMinutes
    }
}

// Based on: Buysse (2014) "Sleep Health: Can We Define It? Does It Matter?"
// Framework: 5 dimensions of sleep health — Duration, Efficiency, Timing, Architecture, Continuity
// Each dimension scored 0-20, total 0-100
struct SleepScoreEngine: ScoreEngine {
    private let weights = [
        "duration_score": 0.25,
        "efficiency_score": 0.20,
        "regularity_score": 0.20,
        "architecture_score": 0.20,
        "continuity_score": 0.15
    ]

    func calculate(from input: SleepScoreInput) -> StandardScoreResult {
        var components: [String: Double] = [:]
        var reasons: [String] = []
        var metrics: [String: Double] = [:]

        // 1. Duration (Buysse Dimension 1)
        // NSF recommendation: adults 7-9h (420-540 min)
        if let totalSleepMinutes = input.totalSleepMinutes, input.sleepTargetMinutes > 0 {
            let ratio = totalSleepMinutes / input.sleepTargetMinutes
            let score = durationScore(ratio: ratio)
            components["duration_score"] = score
            metrics["total_sleep_minutes"] = totalSleepMinutes
            metrics["sleep_target_minutes"] = input.sleepTargetMinutes
            metrics["duration_ratio"] = ratio

            let hours = Int(totalSleepMinutes) / 60
            let mins = Int(totalSleepMinutes) % 60
            if ratio >= 0.9 && ratio <= 1.1 {
                reasons.append("Sleep duration \(hours)h \(mins)m — within target range")
            } else if ratio < 0.9 {
                reasons.append("Sleep duration \(hours)h \(mins)m — below target by \(Int((1.0 - ratio) * 100))%")
            } else {
                reasons.append("Sleep duration \(hours)h \(mins)m — above target")
            }
        } else {
            reasons.append("Sleep duration unavailable; score is based on remaining metrics.")
        }

        // 2. Efficiency (Buysse Dimension 2)
        // Efficiency = total sleep / total in-bed time
        if let totalSleep = input.totalSleepMinutes {
            let inBed = input.inBedMinutes ?? (totalSleep + (input.awakeMinutes ?? 0))
            if inBed > 0 {
                let efficiency = totalSleep / inBed
                let score = efficiencyScore(efficiency: efficiency)
                components["efficiency_score"] = score
                metrics["sleep_efficiency"] = efficiency * 100

                if efficiency >= 0.90 {
                    reasons.append("Sleep efficiency \(Int(efficiency * 100))% — excellent")
                } else if efficiency >= 0.80 {
                    reasons.append("Sleep efficiency \(Int(efficiency * 100))% — acceptable")
                } else {
                    reasons.append("Sleep efficiency \(Int(efficiency * 100))% — too much time awake in bed")
                }
            }
        }

        // 3. Timing/Regularity (Buysse Dimension 3)
        if let bedtimeOffset = input.bedtimeOffsetMinutes, let wakeOffset = input.wakeOffsetMinutes {
            let avgOffset = (abs(bedtimeOffset) + abs(wakeOffset)) / 2
            let score = regularityScore(offsetMinutes: avgOffset)
            components["regularity_score"] = score
            metrics["bedtime_offset_minutes"] = abs(bedtimeOffset)
            metrics["wake_offset_minutes"] = abs(wakeOffset)
            metrics["avg_timing_offset"] = avgOffset

            if avgOffset <= 30 {
                reasons.append("Sleep timing very consistent (±\(Int(avgOffset)) min)")
            } else if avgOffset <= 60 {
                reasons.append("Sleep timing fairly regular")
            } else {
                reasons.append("Irregular sleep timing — \(Int(avgOffset)) min off baseline")
            }
        } else {
            reasons.append("Sleep timing baseline unavailable; regularity was not scored.")
        }

        // 4. Architecture (Buysse Dimension 4)
        // Ideal: REM ~20-25% of total sleep, Deep ~15-20%
        if let totalSleep = input.totalSleepMinutes, totalSleep > 0 {
            let rem = input.remMinutes ?? 0
            let deep = input.deepMinutes ?? 0

            if rem > 0 || deep > 0 {
                let remPct = rem / totalSleep
                let deepPct = deep / totalSleep
                let score = architectureScore(remPct: remPct, deepPct: deepPct)
                components["architecture_score"] = score
                metrics["rem_pct"] = remPct * 100
                metrics["deep_pct"] = deepPct * 100

                var archReasons: [String] = []
                if remPct < 0.15 { archReasons.append("low REM") }
                if deepPct < 0.10 { archReasons.append("low deep sleep") }
                if archReasons.isEmpty {
                    reasons.append("Sleep architecture balanced (REM \(Int(remPct * 100))%, Deep \(Int(deepPct * 100))%)")
                } else {
                    reasons.append("Sleep architecture: \(archReasons.joined(separator: ", "))")
                }
            }
        }

        // 5. Continuity (Buysse Dimension 5)
        if let awakeMinutes = input.awakeMinutes {
            let awakeCount = input.awakeCount ?? (awakeMinutes > 0 ? max(1, Int(awakeMinutes / 8)) : 0)
            let score = continuityScore(awakeMinutes: awakeMinutes, awakeCount: awakeCount)
            components["continuity_score"] = score
            metrics["awake_minutes"] = awakeMinutes
            metrics["awake_count"] = Double(awakeCount)

            if awakeMinutes <= 15 {
                reasons.append("Excellent sleep continuity — minimal wake time")
            } else if awakeMinutes <= 30 {
                reasons.append("Good sleep continuity")
            } else {
                reasons.append("Fragmented sleep — \(Int(awakeMinutes)) min awake during night")
            }
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

    // MARK: - Dimension Scorers

    /// Duration: smooth logistic curve centered on target
    private func durationScore(ratio: Double) -> Double {
        if ratio >= 0.95 && ratio <= 1.05 { return 95 }
        if ratio >= 0.90 && ratio <= 1.10 { return 85 }
        if ratio < 0.60 { return 10 }
        if ratio > 1.30 { return 60 } // Oversleeping penalty (less severe)

        // Sigmoid-like for deficit
        if ratio < 1.0 {
            return 10 + 85 * pow(ratio, 3)
        }
        // Mild penalty for oversleeping
        return max(60, 95 - (ratio - 1.0) * 100)
    }

    /// Efficiency: WHO guideline ≥85% is normal, clinical ≥90% is good
    private func efficiencyScore(efficiency: Double) -> Double {
        if efficiency >= 0.95 { return 95 }
        if efficiency >= 0.90 { return 85 }
        if efficiency >= 0.85 { return 70 }
        if efficiency >= 0.80 { return 55 }
        if efficiency >= 0.70 { return 35 }
        return 15
    }

    /// Regularity: offset from personal median bedtime/waketime
    private func regularityScore(offsetMinutes: Double) -> Double {
        if offsetMinutes <= 15 { return 95 }
        if offsetMinutes <= 30 { return 85 }
        if offsetMinutes <= 45 { return 72 }
        if offsetMinutes <= 60 { return 60 }
        if offsetMinutes <= 90 { return 40 }
        return 20
    }

    /// Architecture: REM + Deep stage proportions
    private func architectureScore(remPct: Double, deepPct: Double) -> Double {
        // REM ideal: 20-25%, Deep ideal: 15-20%
        let remScore: Double
        switch remPct {
        case 0.20...0.25: remScore = 50
        case 0.15..<0.20, 0.25...0.30: remScore = 40
        case 0.10..<0.15: remScore = 25
        default: remScore = 10
        }

        let deepScore: Double
        switch deepPct {
        case 0.15...0.20: deepScore = 50
        case 0.10..<0.15, 0.20...0.25: deepScore = 40
        case 0.05..<0.10: deepScore = 25
        default: deepScore = 10
        }

        return remScore + deepScore
    }

    /// Continuity: awake time and awake count during sleep period
    private func continuityScore(awakeMinutes: Double, awakeCount: Int) -> Double {
        let timePenalty: Double
        if awakeMinutes <= 10 { timePenalty = 0 }
        else if awakeMinutes <= 20 { timePenalty = 15 }
        else if awakeMinutes <= 40 { timePenalty = 35 }
        else { timePenalty = 55 }

        let countPenalty: Double
        if awakeCount <= 1 { countPenalty = 0 }
        else if awakeCount <= 3 { countPenalty = 10 }
        else { countPenalty = 25 }

        return max(10, 95 - timePenalty - countPenalty)
    }
}
