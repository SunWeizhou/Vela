import Foundation

public struct SleepScoreInput: Hashable, Sendable {
    public var asOf: Date
    public var totalSleepMinutes: Double?
    public var sleepTargetMinutes: Double
    public var todayBedtime: Date?
    public var recentBedtimes: [Date]
    public var awakeMinutes: Double?
    public var awakeEpisodeCount: Int?
    public var remMinutes: Double?
    public var deepMinutes: Double?
    public var inBedMinutes: Double?
    public var bedtimeOffsetMinutes: Double?
    public var wakeOffsetMinutes: Double?

    public init(
        asOf: Date,
        totalSleepMinutes: Double?,
        sleepTargetMinutes: Double = 450,
        todayBedtime: Date? = nil,
        recentBedtimes: [Date] = [],
        awakeMinutes: Double? = nil,
        awakeEpisodeCount: Int? = nil,
        remMinutes: Double? = nil,
        deepMinutes: Double? = nil,
        inBedMinutes: Double? = nil,
        bedtimeOffsetMinutes: Double? = nil,
        wakeOffsetMinutes: Double? = nil
    ) {
        self.asOf = asOf
        self.totalSleepMinutes = totalSleepMinutes
        self.sleepTargetMinutes = sleepTargetMinutes
        self.todayBedtime = todayBedtime
        self.recentBedtimes = recentBedtimes
        self.awakeMinutes = awakeMinutes
        self.awakeEpisodeCount = awakeEpisodeCount
        self.remMinutes = remMinutes
        self.deepMinutes = deepMinutes
        self.inBedMinutes = inBedMinutes
        self.bedtimeOffsetMinutes = bedtimeOffsetMinutes
        self.wakeOffsetMinutes = wakeOffsetMinutes
    }
}

public struct SleepDetailAnalysis: Codable, Hashable, Sendable {
    public var durationScore: Double
    public var efficiencyScore: Double
    public var regularityScore: Double
    public var architectureScore: Double
    public var continuityScore: Double

    public init(
        durationScore: Double,
        efficiencyScore: Double,
        regularityScore: Double,
        architectureScore: Double,
        continuityScore: Double
    ) {
        self.durationScore = durationScore
        self.efficiencyScore = efficiencyScore
        self.regularityScore = regularityScore
        self.architectureScore = architectureScore
        self.continuityScore = continuityScore
    }
}

/// The existing Vela sleep score, moved without changing its formula or
/// missing-data semantics. The calendar is explicit so replay tests do not
/// depend on the machine locale/time zone.
public struct SleepScoreEngine: ScoreEngine, Sendable {
    public typealias Input = SleepScoreInput
    public typealias Output = MetricResult

    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    private func minutesFromNoon(_ date: Date) -> Double {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        var minutes = Double(hour * 60 + minute)
        if minutes < 12 * 60 { minutes += 24 * 60 }
        return minutes
    }

    public func calculate(from input: SleepScoreInput) -> MetricResult {
        guard let totalSleep = input.totalSleepMinutes, totalSleep > 0 else {
            return MetricResult(
                domain: .sleep,
                name: "Sleep Score",
                value: nil,
                band: .low,
                confidence: .low,
                reasons: ["缺少睡眠时长数据"],
                missingInputs: ["totalSleepMinutes"],
                dataWindow: dataWindow(asOf: input.asOf, days: 13),
                source: .healthKit,
                algorithmVersion: ScoringAlgorithmVersions.sleep,
                lastUpdated: input.asOf
            )
        }

        var components: [String: Double] = [:]
        var componentWeights: [String: Double] = [:]
        var reasons: [String] = []
        var missingInputs: [String] = []
        let target = input.sleepTargetMinutes > 0 ? input.sleepTargetMinutes : 450

        let durationScore: Double
        if totalSleep >= target - 30 && totalSleep <= target + 60 {
            durationScore = 50
        } else if totalSleep < target - 30 {
            let range = (target - 30) - 240
            let progress = range > 0 ? (totalSleep - 240) / range : 0
            durationScore = 50 * ScoringMath.clamp(progress, min: 0, max: 1)
        } else {
            let progress = 1 - (totalSleep - (target + 60)) / 240
            durationScore = 50 * ScoringMath.clamp(progress, min: 0, max: 1)
        }
        components["duration"] = durationScore
        componentWeights["duration"] = 50
        reasons.append("睡眠时长 \(Int(totalSleep) / 60)小时\(Int(totalSleep) % 60)分钟（目标 \(Int(target) / 60)小时）")

        if input.recentBedtimes.count >= 5, let todayBedtime = input.todayBedtime,
           let baseline = ScoringMath.median(input.recentBedtimes.map(minutesFromNoon)) {
            let diff = abs(minutesFromNoon(todayBedtime) - baseline)
            let consistency: Double
            switch diff {
            case ...30: consistency = 30
            case ...60: consistency = 24
            case ...90: consistency = 18
            case ...120: consistency = 12
            case ...180: consistency = 6
            default: consistency = 0
            }
            components["consistency"] = consistency
            componentWeights["consistency"] = 30
            reasons.append("入睡一致性差异约为 \(Int(diff))分钟（基线参考过去 \(input.recentBedtimes.count)晚）")
        } else {
            if input.todayBedtime == nil { missingInputs.append("todayBedtime") }
            if input.recentBedtimes.count < 5 {
                missingInputs.append("recentBedtimesHistory")
                reasons.append("最近 13 晚有效睡眠记录不足 5 晚，一致性得分已降级")
            }
        }

        if let awakeMinutes = input.awakeMinutes {
            let awakeCount = input.awakeEpisodeCount ?? (awakeMinutes > 0 ? max(1, Int(awakeMinutes / 8)) : 0)
            let interruption = ScoringMath.clamp(
                20 - 0.45 * awakeMinutes - 2.5 * Double(awakeCount),
                min: 0,
                max: 20
            )
            components["interruption"] = interruption
            componentWeights["interruption"] = 20
            if input.awakeEpisodeCount != nil {
                reasons.append("睡眠中断 \(Int(awakeMinutes))分钟（醒来频率 \(awakeCount)次）")
            } else if awakeMinutes > 0 {
                reasons.append("睡眠中断 \(Int(awakeMinutes))分钟（醒来频率约 \(awakeCount)次 · 估算）")
            } else {
                reasons.append("睡眠中断 0分钟")
            }
        } else {
            missingInputs.append("awakeMinutes")
            reasons.append("缺少睡眠阶段中断数据")
        }

        let availableWeight = componentWeights.values.reduce(0, +)
        let sumScore = components.reduce(0) { $0 + $1.value }
        let confidence: MetricConfidence = components.count == 3 ? .high : (components.count >= 2 ? .medium : .low)
        let finalValue: Double?
        if availableWeight > 0 {
            let base = ScoringMath.clamp((sumScore / availableWeight) * 100)
            finalValue = confidence == .low ? min(base, 79) : base
            if confidence == .low {
                reasons.append("由于缺少质量与一致性指标，该评分已降为低置信度（最大限制为 79 分）")
            }
        } else {
            finalValue = nil
        }
        reasons.append("睡眠分析根据 Apple 公开结构建模，非官方指标。")

        let detail = calculateLegacyBuysse(from: input)
        components["buysse_duration"] = detail.durationScore
        components["buysse_efficiency"] = detail.efficiencyScore
        components["buysse_regularity"] = detail.regularityScore
        components["buysse_architecture"] = detail.architectureScore
        components["buysse_continuity"] = detail.continuityScore
        let inBed = input.inBedMinutes ?? (totalSleep + (input.awakeMinutes ?? 0))
        if inBed > 0 { components["sleep_efficiency"] = totalSleep / inBed * 100 }
        if let rem = input.remMinutes { components["rem_pct"] = rem / totalSleep * 100 }
        if let deep = input.deepMinutes { components["deep_pct"] = deep / totalSleep * 100 }
        if let awake = input.awakeMinutes {
            components["awake_minutes"] = awake
            components["awake_episode_count"] = Double(input.awakeEpisodeCount ?? (awake > 0 ? max(1, Int(awake / 8)) : 0))
        }

        return MetricResult(
            domain: .sleep,
            name: "Sleep Score",
            value: finalValue,
            band: finalValue.map(ScoringMath.band) ?? .low,
            confidence: confidence,
            components: components,
            componentWeights: componentWeights,
            reasons: reasons,
            missingInputs: missingInputs,
            dataWindow: dataWindow(asOf: input.asOf, days: 13),
            source: .healthKit,
            algorithmVersion: ScoringAlgorithmVersions.sleep,
            lastUpdated: input.asOf
        )
    }

    private func dataWindow(asOf: Date, days: Int) -> DateInterval {
        DateInterval(
            start: calendar.date(byAdding: .day, value: -days, to: asOf) ?? asOf,
            end: asOf
        )
    }

    private func calculateLegacyBuysse(from input: SleepScoreInput) -> SleepDetailAnalysis {
        let duration: Double
        if let total = input.totalSleepMinutes {
            let target = input.sleepTargetMinutes > 0 ? input.sleepTargetMinutes : 450
            let ratio = total / target
            if ratio >= 0.95 && ratio <= 1.05 { duration = 20 }
            else if ratio >= 0.90 && ratio <= 1.10 { duration = 18 }
            else if ratio < 0.60 { duration = 4 }
            else if ratio > 1.30 { duration = 12 }
            else { duration = 20 * pow(ratio, 3) }
        } else { duration = 15 }

        let efficiency: Double
        if let total = input.totalSleepMinutes {
            let inBed = input.inBedMinutes ?? (total + (input.awakeMinutes ?? 0))
            if inBed > 0 {
                let ratio = total / inBed
                efficiency = ratio >= 0.95 ? 20 : (ratio >= 0.90 ? 18 : (ratio >= 0.85 ? 15 : (ratio >= 0.80 ? 12 : 6)))
            } else { efficiency = 15 }
        } else { efficiency = 15 }

        let regularity: Double
        if let bedtime = input.bedtimeOffsetMinutes, let wake = input.wakeOffsetMinutes {
            let offset = (abs(bedtime) + abs(wake)) / 2
            regularity = offset <= 15 ? 20 : (offset <= 30 ? 18 : (offset <= 45 ? 15 : (offset <= 60 ? 12 : 8)))
        } else { regularity = 15 }

        let architecture: Double
        if let total = input.totalSleepMinutes, total > 0 {
            let rem = (input.remMinutes ?? 0) / total
            let deep = (input.deepMinutes ?? 0) / total
            let remScore: Double = (0.20...0.25).contains(rem) ? 10 : ((0.15..<0.20).contains(rem) || (0.25...0.30).contains(rem) ? 8 : 5)
            let deepScore: Double = (0.15...0.20).contains(deep) ? 10 : ((0.10..<0.15).contains(deep) || (0.20...0.25).contains(deep) ? 8 : 5)
            architecture = remScore + deepScore
        } else { architecture = 15 }

        let continuity: Double
        if let awake = input.awakeMinutes {
            let count = input.awakeEpisodeCount ?? (awake > 0 ? max(1, Int(awake / 8)) : 0)
            let timePenalty: Double = awake <= 10 ? 0 : (awake <= 20 ? 3 : (awake <= 40 ? 7 : 11))
            let countPenalty: Double = count <= 1 ? 0 : (count <= 3 ? 2 : 5)
            continuity = max(2.0, 20.0 - timePenalty - countPenalty)
        } else { continuity = 15 }
        return SleepDetailAnalysis(
            durationScore: duration,
            efficiencyScore: efficiency,
            regularityScore: regularity,
            architectureScore: architecture,
            continuityScore: continuity
        )
    }
}
