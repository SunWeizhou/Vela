import Foundation

public struct RecoveryScoreInput: Hashable {
    public var asOf: Date
    public var hrvToday: Double?
    public var hrvBaseline: Double?
    public var hrvHistory: [Double] = []

    public var hrvRmssdToday: Double?
    public var hrvRmssdBaseline: Double?
    public var hrvRmssdHistory: [Double] = []

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
        asOf: Date,
        hrvToday: Double?,
        hrvBaseline: Double?,
        hrvHistory: [Double] = [],
        hrvRmssdToday: Double? = nil,
        hrvRmssdBaseline: Double? = nil,
        hrvRmssdHistory: [Double] = [],
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
        self.asOf = asOf
        self.hrvToday = hrvToday
        self.hrvBaseline = hrvBaseline
        self.hrvHistory = hrvHistory
        self.hrvRmssdToday = hrvRmssdToday
        self.hrvRmssdBaseline = hrvRmssdBaseline
        self.hrvRmssdHistory = hrvRmssdHistory
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

            if let lnBaseline = PersonalBaselineEngine.median(lnHistory) {
                var lnSD = PersonalBaselineEngine.robustStandardDeviation(
                    lnHistory,
                    around: lnBaseline
                ) ?? 0
                let fallbackSD = lnBaseline * 0.12
                if lnSD < 0.01 {
                    lnSD = fallbackSD > 0.01 ? fallbackSD : 0.05
                }

                hrvZ = (lnToday - lnBaseline) / lnSD
                let sigmoidHRV = (2.0 / (1.0 + exp(-0.45 * hrvZ))) - 1.0
                var hrvComponent = ScoringMath.clamp(50.0 + 48.0 * sigmoidHRV, min: 0, max: 100)

                if hrvZ > 2.2 && (input.strainScoreYesterday ?? 0) > 75 {
                    hrvComponent = min(hrvComponent, 65.0)
                    reasons.append("高负荷后 HRV 明显高于个人基线，恢复评分已按保守规则下调")
                } else if hrvZ < -1.5 {
                    reasons.append("HRV 明显低于个人基线")
                } else if hrvZ > 1.0 {
                    reasons.append("HRV 高于近期个人基线")
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
            if let rhrBaseline = PersonalBaselineEngine.median(rhrHistoryToUse) {
                var rhrSD = PersonalBaselineEngine.robustStandardDeviation(
                    rhrHistoryToUse,
                    around: rhrBaseline
                ) ?? 0
                let fallbackSD = max(2.5, rhrBaseline * 0.04)
                if rhrSD < 0.5 {
                    rhrSD = fallbackSD
                }

                rhrZ = (rhrToday - rhrBaseline) / rhrSD
                let sigmoidRHR = (2.0 / (1.0 + exp(0.45 * rhrZ))) - 1.0
                let rhrComponent = ScoringMath.clamp(50.0 + 48.0 * sigmoidRHR, min: 0, max: 100)

                if rhrZ > 1.5 {
                    reasons.append("静息心率高于近期个人基线（\(Int(rhrToday)) bpm）")
                } else if rhrZ < -1.0 {
                    reasons.append("静息心率低于近期个人基线")
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
                reasons.append("昨晚睡眠评分偏低")
            } else if sleepScore >= 80 {
                reasons.append("昨晚睡眠评分较高")
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
                reasons.append("昨日训练负荷评分偏高")
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

        let hasSleepSignal = input.sleepScoreLastNight != nil
        let hasCardiovascularSignal = input.hrvToday != nil || input.restingHeartRateToday != nil
        let canPublishRecoveryScore = hasSleepSignal && hasCardiovascularSignal

        var recoveryValue: Double? = nil
        if totalWeight > 0 && canPublishRecoveryScore {
            recoveryValue = weightedSum / totalWeight
        } else if !canPublishRecoveryScore {
            reasons.append("需要睡眠评分和至少一项心血管恢复信号后，才会给出恢复评分")
        }

        // 5. Red Flag Modifiers
        var penalty = 0.0
        if let bodyTempDelta = input.bodyTempDelta, bodyTempDelta >= 1.0 {
            penalty += 8.0
            reasons.append("体温相对基线偏高 (\(String(format: "+%.1f", bodyTempDelta))°C)，恢复评分已保守下调")
        }

        var respiratoryRateZ = 0.0
        if let respToday = input.respiratoryRateToday, let respBaseline = input.respiratoryRateBaseline {
            let respHistoryToUse = input.respiratoryRateHistory.count >= 5 ? input.respiratoryRateHistory : [respBaseline]
            // Reuse the shared sample SD (n-1, Bessel's correction) so respiratory
            // baselines stay consistent with every other scoring module. The previous
            // inline population SD (÷n) diverged from PersonalBaselineEngine.
            let sd = max(0.5, PersonalBaselineEngine.sampleStandardDeviation(respHistoryToUse) ?? 0.5)
            respiratoryRateZ = (respToday - respBaseline) / sd

            if respiratoryRateZ >= 1.5 {
                penalty += 5.0
                reasons.append("呼吸频率高于近期个人基线 (\(Int(respToday)) 次/分)，恢复评分已保守下调")
            }
        }

        if let SpO2 = input.SpO2, SpO2 < 94 {
            penalty += 8.0
            reasons.append("血氧饱和度读数偏低 (\(Int(SpO2))%)，恢复评分已保守下调；如有不适请寻求专业建议")
        }

        if input.hrvToday != nil {
            components["hrv_z_score"] = hrvZ
        }

        // Parasympathetic Tone Index (PSTI) based on normalized log-transformed RMSSD values
        let rmssdToday = input.hrvRmssdToday ?? input.hrvToday
        if let rmssdToday {
            let lnToday = log(max(rmssdToday, 1.0))
            let rmssdHistoryToUse = !input.hrvRmssdHistory.isEmpty
                ? input.hrvRmssdHistory
                : (input.hrvRmssdBaseline != nil ? [input.hrvRmssdBaseline!] : (input.hrvHistory.count >= 5 ? input.hrvHistory : [input.hrvBaseline ?? rmssdToday]))
            let lnHistory = rmssdHistoryToUse.map { log(max($0, 1.0)) }

            if let lnBaseline = PersonalBaselineEngine.median(lnHistory) {
                var lnSD = PersonalBaselineEngine.robustStandardDeviation(
                    lnHistory,
                    around: lnBaseline
                ) ?? 0
                let fallbackSD = lnBaseline * 0.12
                if lnSD < 0.01 {
                    lnSD = fallbackSD > 0.01 ? fallbackSD : 0.05
                }

                let pstiZ = (lnToday - lnBaseline) / lnSD
                let pstiScore = ScoringMath.clamp(50.0 + 25.0 * pstiZ, min: 0, max: 100)

                components["parasympathetic_tone_index"] = pstiScore
                components["psti_z_score"] = pstiZ
            }
        }

        if input.restingHeartRateToday != nil {
            components["rhr_z_score"] = rhrZ
        }
        if input.respiratoryRateToday != nil, input.respiratoryRateBaseline != nil {
            components["respiratory_rate_z"] = respiratoryRateZ
        }
        if let bodyTempDelta = input.bodyTempDelta {
            components["body_temp_delta"] = bodyTempDelta
        }
        if let SpO2 = input.SpO2 {
            components["spo2"] = SpO2
        }

        if rhrZ > 2.0 && hrvZ < -1.0 {
            penalty += 8.0
            reasons.append("静息心率高于个人基线且 HRV 低于基线，恢复评分已相应下调")
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

        let dataWindow = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -28, to: input.asOf) ?? input.asOf,
            end: input.asOf
        )

        return MetricResult(
            domain: .recovery,
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
            algorithmVersion: ScoringAlgorithmVersions.recovery,
            lastUpdated: input.asOf
        )
    }
}
