import Foundation

public struct RecoveryScoreInput: Hashable {
    public var hrvToday: Double?
    public var hrvBaseline: Double?
    public var hrvHistory: [Double] = []
    
    public var restingHeartRateToday: Double?
    public var restingHeartRateBaseline: Double?
    public var rhrHistory: [Double] = []
    
    public var sleepScoreLastNight: Double?
    public var strainScoreYesterday: Double?
    
    public var respiratoryRateToday: Double?
    public var respiratoryRateBaseline: Double?
    public var respiratoryRateHistory: [Double] = []
    
    public var bodyTempDelta: Double?
    public var SpO2: Double?

    public init(
        hrvToday: Double?,
        hrvBaseline: Double?,
        hrvHistory: [Double] = [],
        restingHeartRateToday: Double?,
        restingHeartRateBaseline: Double?,
        rhrHistory: [Double] = [],
        sleepScoreLastNight: Double?,
        strainScoreYesterday: Double?,
        respiratoryRateToday: Double? = nil,
        respiratoryRateBaseline: Double? = nil,
        respiratoryRateHistory: [Double] = [],
        bodyTempDelta: Double? = nil,
        SpO2: Double? = nil
    ) {
        self.hrvToday = hrvToday
        self.hrvBaseline = hrvBaseline
        self.hrvHistory = hrvHistory
        self.restingHeartRateToday = restingHeartRateToday
        self.restingHeartRateBaseline = restingHeartRateBaseline
        self.rhrHistory = rhrHistory
        self.sleepScoreLastNight = sleepScoreLastNight
        self.strainScoreYesterday = strainScoreYesterday
        self.respiratoryRateToday = respiratoryRateToday
        self.respiratoryRateBaseline = respiratoryRateBaseline
        self.respiratoryRateHistory = respiratoryRateHistory
        self.bodyTempDelta = bodyTempDelta
        self.SpO2 = SpO2
    }
}

public struct RecoveryScoreEngine: ScoreEngine {
    public typealias Input = RecoveryScoreInput
    public typealias Output = MetricResult

    public init() {}

    private func calculateMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        } else {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        }
    }

    private func robustSD(for values: [Double], medianVal: Double) -> Double {
        let absDevs = values.map { abs($0 - medianVal) }
        guard let mad = calculateMedian(absDevs) else { return 0.0 }
        return 1.4826 * mad
    }

    public func calculate(from input: RecoveryScoreInput) -> MetricResult {
        var components: [String: Double] = [:]
        var componentWeights: [String: Double] = [:]
        var reasons: [String] = []
        var missingInputs: [String] = []

        let weights = [
            "hrv": 0.35,
            "rhr": 0.25,
            "sleep": 0.25,
            "prior_strain": 0.15
        ]

        var hrvZ = 0.0
        var rhrZ = 0.0

        // 1. HRV Component (35%) - Log-transformed SDNN
        if let hrvToday = input.hrvToday {
            let lnToday = log(max(hrvToday, 1.0))
            
            // Build baseline using history (21 to 42 days), fallback to baseline if history too short
            let hrvHistoryToUse = input.hrvHistory.count >= 5 ? input.hrvHistory : [input.hrvBaseline ?? hrvToday]
            let lnHistory = hrvHistoryToUse.map { log(max($0, 1.0)) }
            
            if let lnBaseline = calculateMedian(lnHistory) {
                var lnSD = robustSD(for: lnHistory, medianVal: lnBaseline)
                let fallbackSD = lnBaseline * 0.12
                if lnSD < 0.01 {
                    lnSD = fallbackSD > 0.01 ? fallbackSD : 0.05
                }
                
                hrvZ = (lnToday - lnBaseline) / lnSD
                var hrvComponent = ScoringMath.clamp(50.0 + 18.0 * hrvZ, min: 0, max: 100)
                
                if hrvZ > 2.2 && (input.strainScoreYesterday ?? 0) > 75 {
                    hrvComponent = min(hrvComponent, 65.0)
                    reasons.append("高负荷后 HRV 异常升高（可能存在副交感神经反弹/过度训练）")
                } else if hrvZ < -1.5 {
                    reasons.append("HRV 显著低于自主神经基线")
                } else if hrvZ > 1.0 {
                    reasons.append("HRV 表现良好，自主神经恢复充沛")
                }
                
                components["hrv"] = hrvComponent
                componentWeights["hrv"] = weights["hrv"]
            }
        } else {
            missingInputs.append("hrvToday")
            reasons.append("缺少今日 HRV 数据")
        }

        // 2. RHR Component (25%) - Robust Z-Score
        if let rhrToday = input.restingHeartRateToday {
            let rhrHistoryToUse = input.rhrHistory.count >= 5 ? input.rhrHistory : [input.restingHeartRateBaseline ?? rhrToday]
            if let rhrBaseline = calculateMedian(rhrHistoryToUse) {
                var rhrSD = robustSD(for: rhrHistoryToUse, medianVal: rhrBaseline)
                let fallbackSD = max(2.5, rhrBaseline * 0.04)
                if rhrSD < 0.5 {
                    rhrSD = fallbackSD
                }
                
                rhrZ = (rhrToday - rhrBaseline) / rhrSD
                let rhrComponent = ScoringMath.clamp(50.0 - 18.0 * rhrZ, min: 0, max: 100)
                
                if rhrZ > 1.5 {
                    reasons.append("静息心率异常偏高 (\(Int(rhrToday)) bpm)，表明身体承受心血管负荷")
                } else if rhrZ < -1.0 {
                    reasons.append("静息心率低于日常基线，心肺系统恢复良好")
                }
                
                components["rhr"] = rhrComponent
                componentWeights["rhr"] = weights["rhr"]
            }
        } else {
            missingInputs.append("restingHeartRateToday")
            reasons.append("缺少今日静息心率数据")
        }

        // 3. Sleep Component (25%)
        if let sleepScore = input.sleepScoreLastNight {
            components["sleep"] = sleepScore
            componentWeights["sleep"] = weights["sleep"]
            if sleepScore < 60 {
                reasons.append("昨晚睡眠质量不佳，限制了系统性修复")
            } else if sleepScore >= 80 {
                reasons.append("高质量睡眠为今日恢复提供了强力保障")
            }
        } else {
            missingInputs.append("sleepScore")
            reasons.append("缺少昨晚睡眠评分")
        }

        // 4. Prior Strain Component (15%)
        if let priorStrain = input.strainScoreYesterday {
            let priorStrainComponent = ScoringMath.clamp(100.0 - priorStrain, min: 0, max: 100)
            components["prior_strain"] = priorStrainComponent
            componentWeights["prior_strain"] = weights["prior_strain"]
            
            if priorStrain > 75 {
                reasons.append("昨日高强度耗力需要更多的恢复代偿")
            }
        } else {
            missingInputs.append("priorStrainYesterday")
            reasons.append("缺少昨日耗力负荷记录")
        }

        // Weighted Average
        let totalWeight = componentWeights.values.reduce(0, +)
        let weightedSum = components.reduce(0.0) { partial, item in
            partial + (item.value * (componentWeights[item.key] ?? 0.0))
        }

        var recoveryValue: Double? = nil
        if totalWeight > 0 {
            recoveryValue = weightedSum / totalWeight
        }

        // 5. Red Flag Modifiers
        var penalty = 0.0
        if let bodyTempDelta = input.bodyTempDelta, bodyTempDelta >= 0.5 {
            penalty += 8.0
            reasons.append("体温偏高 (\(String(format: "+%.1f", bodyTempDelta))°C)，检测到轻度全身性生理负荷")
        }

        var respiratoryRateZ = 0.0
        if let respToday = input.respiratoryRateToday, let respBaseline = input.respiratoryRateBaseline {
            let respHistoryToUse = input.respiratoryRateHistory.count >= 5 ? input.respiratoryRateHistory : [respBaseline]
            let mean = respHistoryToUse.reduce(0, +) / Double(max(1, respHistoryToUse.count))
            let variance = respHistoryToUse.map { pow($0 - mean, 2) }.reduce(0, +) / Double(max(1, respHistoryToUse.count))
            let sd = max(0.5, sqrt(variance))
            respiratoryRateZ = (respToday - respBaseline) / sd
            
            if respiratoryRateZ >= 1.5 {
                penalty += 5.0
                reasons.append("呼吸频率异常偏快 (\(Int(respToday)) 次/分)，自主神经系统表现紧张")
            }
        }

        if let SpO2 = input.SpO2, SpO2 < 94 {
            penalty += 8.0
            reasons.append("血氧饱和度偏低 (\(Int(SpO2))%)，系统性氧合能力下降")
        }

        if rhrZ > 2.0 && hrvZ < -1.0 {
            penalty += 8.0
            reasons.append("静息心率显著上升且 HRV 受到抑制，发出红色生理疲劳警报")
        }

        if let val = recoveryValue {
            recoveryValue = ScoringMath.clamp(val - penalty, min: 0, max: 100)
        }

        // Mapped Band
        let band: MetricBand
        if let val = recoveryValue {
            band = ScoringMath.band(for: val)
        } else {
            band = .low
        }

        // Mapped Confidence
        let confidence: MetricConfidence
        let totalHistoryDays = max(input.hrvHistory.count, input.rhrHistory.count)
        
        let hasCoreInputs = input.hrvToday != nil && input.restingHeartRateToday != nil && input.sleepScoreLastNight != nil
        if hasCoreInputs && totalHistoryDays >= 14 {
            confidence = .high
        } else {
            let activeCoreCount = (input.hrvToday != nil ? 1 : 0) + (input.restingHeartRateToday != nil ? 1 : 0) + (input.sleepScoreLastNight != nil ? 1 : 0)
            if activeCoreCount >= 2 && totalHistoryDays >= 7 {
                confidence = .medium
            } else {
                confidence = .low
            }
        }

        let dataWindow = DateInterval(start: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(), end: Date())

        return MetricResult(
            name: "Recovery Score",
            value: recoveryValue,
            band: band,
            confidence: confidence,
            components: components,
            componentWeights: componentWeights,
            reasons: reasons,
            missingInputs: missingInputs,
            dataWindow: dataWindow,
            source: .healthKit,
            algorithmVersion: "1.0.0",
            lastUpdated: Date()
        )
    }
}
