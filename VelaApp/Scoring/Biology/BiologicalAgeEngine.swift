import Foundation

public struct BiologicalAgeInput {
    public var chronologicalAge: Double
    public var restingHR: Double?
    public var vo2Max: Double?
    public var sleepHours: Double?
    public var sleepEfficiency: Double?
    public var steps: Double?
    public var biomarkers: [BiomarkerRecord]

    public init(
        chronologicalAge: Double = 30.0,
        restingHR: Double? = nil,
        vo2Max: Double? = nil,
        sleepHours: Double? = nil,
        sleepEfficiency: Double? = nil,
        steps: Double? = nil,
        biomarkers: [BiomarkerRecord] = []
    ) {
        self.chronologicalAge = chronologicalAge
        self.restingHR = restingHR
        self.vo2Max = vo2Max
        self.sleepHours = sleepHours
        self.sleepEfficiency = sleepEfficiency
        self.steps = steps
        self.biomarkers = biomarkers
    }
}

public struct BiologicalAgeResult {
    public var biologicalAge: Double
    public var overallScore: Double // 0-100
    public var wearableScore: Double // 0-100
    public var biomarkerScore: Double // 0-100
    public var suboptimalCount: Int
    public var optimalCount: Int
    public var factors: [BiologicalAgeFactor]
}

public struct BiologicalAgeFactor: Identifiable {
    public var id = UUID()
    public var name: String
    public var score: Double
    public var isOptimal: Bool
    public var description: String
    public var type: FactorType

    public enum FactorType {
        case wearable
        case biomarker
    }
}

public final class BiologicalAgeEngine {
    public init() {}

    public func calculate(input: BiologicalAgeInput) -> BiologicalAgeResult {
        var wearableFactors: [BiologicalAgeFactor] = []
        var biomarkerFactors: [BiologicalAgeFactor] = []

        // 1. Wearable Calculations (65% weight)
        // Cardiovascular (Resting HR & VO2 Max)
        if let rhr = input.restingHR {
            // Lower resting HR is generally better. Optimal RHR: 50-60 bpm.
            let score: Double
            if rhr <= 60 {
                score = 100.0
            } else if rhr >= 90 {
                score = 30.0
            } else {
                score = 100.0 - (rhr - 60.0) * 2.33 // scaled linearly between 60 (100) and 90 (30)
            }
            wearableFactors.append(BiologicalAgeFactor(
                name: L10n.t("Resting Heart Rate", "静息心率"),
                score: score,
                isOptimal: rhr <= 65,
                description: rhr <= 65 
                    ? L10n.t("Excellent cardiac efficiency.", "心肺效率极佳。")
                    : L10n.t("Elevated. Suggests physiological stress or cardiovascular load.", "略高。表明身体面临生理压力或心血管负荷。"),
                type: .wearable
            ))
        }

        if let vo2 = input.vo2Max {
            // VO2 Max: higher is better. Excellent: > 45, Poor: < 30.
            let score: Double
            if vo2 >= 48 {
                score = 100.0
            } else if vo2 <= 28 {
                score = 30.0
            } else {
                score = 30.0 + (vo2 - 28.0) * 3.5 // scaled linearly between 28 (30) and 48 (100)
            }
            wearableFactors.append(BiologicalAgeFactor(
                name: L10n.t("VO2 Max", "最大摄氧量"),
                score: score,
                isOptimal: vo2 >= 42,
                description: vo2 >= 42
                    ? L10n.t("Superb aerobic fitness level.", "心肺耐力水平极其优秀。")
                    : L10n.t("Aerobic capacity has room for aerobic baseline training.", "心肺容量还有提升空间，建议增加低强度有氧训练。"),
                type: .wearable
            ))
        }

        // Sleep Resilience (Hours & Efficiency)
        if let hours = input.sleepHours {
            // Optimal sleep: 7-9 hours.
            let score: Double
            if hours >= 7.0 && hours <= 9.0 {
                score = 100.0
            } else if hours < 5.0 {
                score = 30.0
            } else if hours > 10.0 {
                score = 70.0
            } else if hours < 7.0 {
                score = 30.0 + (hours - 5.0) * 35.0 // scaled 5 (30) to 7 (100)
            } else {
                score = 100.0 - (hours - 9.0) * 30.0 // scaled 9 (100) to 10 (70)
            }
            wearableFactors.append(BiologicalAgeFactor(
                name: L10n.t("Sleep Duration", "睡眠时长"),
                score: score,
                isOptimal: hours >= 7.0 && hours <= 9.0,
                description: hours >= 7.0 && hours <= 9.0
                    ? L10n.t("Optimal sleep duration for cellular regeneration.", "达到细胞修复的黄金睡眠时长。")
                    : L10n.t("Insufficient sleep inhibits neural restoration and muscle recovery.", "睡眠不足，抑制中枢神经恢复和肌肉生长。"),
                type: .wearable
            ))
        }

        if let eff = input.sleepEfficiency {
            // Sleep Efficiency (percent): Optimal: >= 90%.
            let effPercent = eff * 100.0
            let score: Double
            if effPercent >= 90.0 {
                score = 100.0
            } else if effPercent <= 70.0 {
                score = 30.0
            } else {
                score = 30.0 + (effPercent - 70.0) * 3.5 // scaled 70% (30) to 90% (100)
            }
            wearableFactors.append(BiologicalAgeFactor(
                name: L10n.t("Sleep Efficiency", "睡眠效率"),
                score: score,
                isOptimal: effPercent >= 88.0,
                description: effPercent >= 88.0
                    ? L10n.t("Excellent sleep continuity with low fragmentation.", "睡眠连续性极佳，睡眠碎片化极低。")
                    : L10n.t("High bedtime fragmentation. Reduce ambient sound or blue light.", "睡眠碎片化较高。建议优化夜间光线和环境噪音。"),
                type: .wearable
            ))
        }

        // Lifestyle (Steps)
        if let st = input.steps {
            // Optimal steps: >= 10,000. Sedentary: < 4,000.
            let score: Double
            if st >= 10000 {
                score = 100.0
            } else if st <= 3000 {
                score = 30.0
            } else {
                score = 30.0 + (st - 3000.0) * 0.01 // scaled 3000 (30) to 10000 (100)
            }
            wearableFactors.append(BiologicalAgeFactor(
                name: L10n.t("Daily Steps", "每日步数"),
                score: score,
                isOptimal: st >= 8000,
                description: st >= 8000
                    ? L10n.t("Active metabolic lifestyle.", "日常代谢活跃，久坐风险极低。")
                    : L10n.t("Low physical activity. Move more to optimize metabolic age.", "活动量较低。建议增加步行来改善代谢年龄。"),
                type: .wearable
            ))
        }

        // Calculate Wearable Score
        let wearableScore: Double
        if !wearableFactors.isEmpty {
            wearableScore = wearableFactors.map(\.score).reduce(0, +) / Double(wearableFactors.count)
        } else {
            wearableScore = 75.0 // default neutral baseline
        }

        // 2. Biomarkers Calculations (35% weight)
        if !input.biomarkers.isEmpty {
            for bm in input.biomarkers {
                let score: Double
                let isOptimal: Bool
                
                if bm.referenceMax > bm.referenceMin {
                    if bm.value >= bm.referenceMin && bm.value <= bm.referenceMax {
                        score = 100.0
                        isOptimal = true
                    } else {
                        // Calculate deviation percentage
                        let mid = (bm.referenceMin + bm.referenceMax) / 2.0
                        let totalRange = bm.referenceMax - bm.referenceMin
                        let deviation = abs(bm.value - mid) - (totalRange / 2.0)
                        let percentDeviation = deviation / totalRange
                        score = max(20.0, 100.0 - percentDeviation * 100.0)
                        isOptimal = false
                    }
                } else {
                    score = 80.0
                    isOptimal = true
                }

                biomarkerFactors.append(BiologicalAgeFactor(
                    name: bm.name,
                    score: score,
                    isOptimal: isOptimal,
                    description: isOptimal
                        ? L10n.t("Within clinical reference range.", "处于临床标准正常区间内。")
                        : L10n.t("Outside optimal bounds. Consult your private report.", "偏离最佳范围。请参考健康报告优化生活偏好。"),
                    type: .biomarker
                ))
            }
        }

        let biomarkerScore: Double
        if !biomarkerFactors.isEmpty {
            biomarkerScore = biomarkerFactors.map(\.score).reduce(0, +) / Double(biomarkerFactors.count)
        } else {
            biomarkerScore = 80.0 // default neutral baseline
        }

        // 3. Combined Score (65% wearables + 35% biomarkers)
        let overallScore: Double
        if !biomarkerFactors.isEmpty && !wearableFactors.isEmpty {
            overallScore = wearableScore * 0.65 + biomarkerScore * 0.35
        } else if !wearableFactors.isEmpty {
            overallScore = wearableScore
        } else {
            overallScore = biomarkerScore
        }

        // 4. Biological Age Mapping
        // Formula: Biological Age = Chronological Age * (1.25 - (OverallScore / 200.0))
        // So a score of 100 gives Chronological Age * 0.75 (saving 25% of age)
        // A score of 50 gives Chronological Age * 1.0 (perfect match)
        // A score of 0 gives Chronological Age * 1.25 (aging 25% faster)
        let modifier = 1.25 - (overallScore / 200.0)
        let biologicalAge = max(18.0, input.chronologicalAge * modifier)

        let allFactors = wearableFactors + biomarkerFactors
        let suboptimalCount = allFactors.filter { !$0.isOptimal }.count
        let optimalCount = allFactors.filter { $0.isOptimal }.count

        return BiologicalAgeResult(
            biologicalAge: biologicalAge,
            overallScore: overallScore,
            wearableScore: wearableScore,
            biomarkerScore: biomarkerScore,
            suboptimalCount: suboptimalCount,
            optimalCount: optimalCount,
            factors: allFactors
        )
    }
}
