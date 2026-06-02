import Foundation

public struct DailyPlanLimiterInput {
    public var sleepScore: Double
    public var totalSleepMinutes: Double
    public var recoveryScore: Double
    public var strainScore: Double
    public var stressIndex: Double
    public var energyScore: Double
    public var trainingLoadStatus: TrainingLoadStatus
    public var journalFlags: Set<String> // e.g., "sick", "injured", "sore", "poor_mood"
    public var bodyTempDelta: Double
    public var hrvZ: Double
    public var rhrZ: Double

    public init(
        sleepScore: Double,
        totalSleepMinutes: Double,
        recoveryScore: Double,
        strainScore: Double,
        stressIndex: Double,
        energyScore: Double,
        trainingLoadStatus: TrainingLoadStatus,
        journalFlags: Set<String> = [],
        bodyTempDelta: Double = 0.0,
        hrvZ: Double = 0.0,
        rhrZ: Double = 0.0
    ) {
        self.sleepScore = sleepScore
        self.totalSleepMinutes = totalSleepMinutes
        self.recoveryScore = recoveryScore
        self.strainScore = strainScore
        self.stressIndex = stressIndex
        self.energyScore = energyScore
        self.trainingLoadStatus = trainingLoadStatus
        self.journalFlags = journalFlags
        self.bodyTempDelta = bodyTempDelta
        self.hrvZ = hrvZ
        self.rhrZ = rhrZ
    }
}

public struct PlanLimiter: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var severity: Int // 1–3
    public var reason: String
    public var recommendation: String
}

public enum PlanAction: String, Codable, Hashable {
    case keep = "keep"
    case reduce = "reduce"
    case swap = "swap"
    case rest = "rest"
}

public struct DailyPlanLimiterResult: Codable, Hashable {
    public var action: PlanAction
    public var recommendedTrainingType: String
    public var maxIntensity: String
    public var volumeMultiplier: Double
    public var limiters: [PlanLimiter]
    public var whyThis: String
}

public final class DailyPlanLimiterEngine {
    public init() {}

    public func calculate(input: DailyPlanLimiterInput) -> DailyPlanLimiterResult {
        var limiters: [PlanLimiter] = []

        // 1. Check Sleep
        if input.sleepScore < 60 || input.totalSleepMinutes < 360.0 {
            limiters.append(PlanLimiter(
                id: "low_sleep",
                severity: 2,
                reason: L10n.t("Sleep is short or poor quality", "睡眠时长较短或质量欠佳"),
                recommendation: L10n.t("Prioritize sleep extension and avoid heavy workouts", "优先安排补觉，避免重负荷运动")
            ))
        }

        // 2. Check Recovery
        if input.recoveryScore < 45 {
            limiters.append(PlanLimiter(
                id: "low_recovery",
                severity: 3,
                reason: L10n.t("Autonomic recovery is significantly suppressed", "自主神经系统恢复偏低"),
                recommendation: L10n.t("Focus strictly on passive recovery and hydration", "全力进行静养和水分补充，不建议运动")
            ))
        } else if input.recoveryScore < 60 {
            limiters.append(PlanLimiter(
                id: "low_recovery",
                severity: 2,
                reason: L10n.t("Recovery is moderate", "自主神经系统恢复一般"),
                recommendation: L10n.t("Moderate volume and focus on cardiovascular baseline", "控制运动强度，建议以有氧基线训练为主")
            ))
        }

        // 3. Check Stress
        if input.stressIndex > 75 {
            limiters.append(PlanLimiter(
                id: "high_stress",
                severity: 3,
                reason: L10n.t("Physiological stress index is high", "生理压力水平偏高"),
                recommendation: L10n.t("Avoid sympathetic-heavy training, perform breathing exercises", "避免交感神经兴奋性训练，做深呼吸或舒缓拉伸")
            ))
        } else if input.stressIndex > 60 {
            limiters.append(PlanLimiter(
                id: "high_stress",
                severity: 2,
                reason: L10n.t("Physiological stress is elevated", "生理压力轻微偏高"),
                recommendation: L10n.t("Reduce daily workload", "适当降低今日耗力")
            ))
        }

        // 4. Check Training Load
        if input.trainingLoadStatus == .highRisk {
            limiters.append(PlanLimiter(
                id: "high_load",
                severity: 3,
                reason: L10n.t("Acute training load significantly exceeds baseline (High Risk)", "近期累计负荷增加过快"),
                recommendation: L10n.t("Mandatory deload to prevent cardiovascular and soft tissue injuries", "强制主动减载，防范运动伤病风险")
            ))
        } else if input.trainingLoadStatus == .elevated {
            limiters.append(PlanLimiter(
                id: "high_load",
                severity: 2,
                reason: L10n.t("Acute training load is elevated", "近期负荷略有堆积"),
                recommendation: L10n.t("Maintain current intensity, monitor joints and recovery closely", "保持现有节奏，密切关注关节与心肺恢复")
            ))
        }

        // 5. Check Body Temperature
        if input.bodyTempDelta > 0.6 {
            limiters.append(PlanLimiter(
                id: "high_temp",
                severity: 3,
                reason: L10n.t("Nightly skin temperature has elevated abnormally", "夜间体温出现异常上升"),
                recommendation: L10n.t("Signs of metabolic or systemic immune fight. Sleep and rest only", "提示机体面临全身性免疫或代谢对抗，强烈建议静养休息")
            ))
        }

        // 6. Check Subjective Journal Flags and explicit rest status
        if input.journalFlags.contains("sick") || input.journalFlags.contains("injured") {
            limiters.append(PlanLimiter(
                id: "journal_sick_injured",
                severity: 3,
                reason: L10n.t("Self-reported sickness or orthopedic pain", "手记记录了生病或关节伤病"),
                recommendation: L10n.t("Suspend all training immediately to focus on recovery", "立即停止任何负荷训练，遵医嘱并静养恢复")
            ))
        } else if input.journalFlags.contains("resting") {
            limiters.append(PlanLimiter(
                id: "status_resting",
                severity: 3,
                reason: L10n.t("User selected a rest period", "用户主动选择了休息期"),
                recommendation: L10n.t("Keep today training-free and focus on recovery habits", "今天暂停训练，优先安排恢复习惯")
            ))
        }

        // Calculate decision output
        let action: PlanAction
        let recommendedTrainingType: String
        let maxIntensity: String
        let volumeMultiplier: Double
        let whyThis: String

        let hasSeverity3 = limiters.contains { $0.severity == 3 }
        let totalSeverity = limiters.reduce(0) { $0 + $1.severity }

        if hasSeverity3 {
            action = .rest
            recommendedTrainingType = L10n.t("Passive Recovery / Mobility", "完全静养 / 关节伸展")
            maxIntensity = "Zone 1 / Mobility"
            volumeMultiplier = 0.0
            
            let primaryReason = limiters.first { $0.severity == 3 }?.reason ?? ""
            whyThis = L10n.t("Action based on critical warnings: \(primaryReason).", "由于关键指标发出红色生理警报（\(primaryReason)），今日建议完全休息。")
        } else if totalSeverity >= 4 {
            action = .reduce
            recommendedTrainingType = L10n.t("Active Recovery / Base Cardio", "主动恢复 / 基础低强度有氧")
            maxIntensity = "Zone 2"
            volumeMultiplier = 0.6
            whyThis = L10n.t("Multiple mild constraints exist. Recommending a moderate deload.", "存在多项轻微生理限制因素，今日建议控制训练量，降低负荷。")
        } else if input.recoveryScore >= 75 && input.sleepScore >= 75 && input.stressIndex < 50 {
            action = .keep
            recommendedTrainingType = L10n.t("Strength / High-Intensity Cardio", "力量重训 / 高强度心肺刺激")
            maxIntensity = "Zone 4-5"
            volumeMultiplier = 1.1
            whyThis = L10n.t("Excellent physiological resilience today. Good window to push performance.", "今日多项生理指标极佳，身体展现出强健的代偿与超量恢复潜力，适合冲击运动表现。")
        } else {
            action = .keep
            recommendedTrainingType = L10n.t("Base Aerobic Cardio / Core Workouts", "常规有氧 / 核心力量维持")
            maxIntensity = "Zone 3"
            volumeMultiplier = 0.9
            whyThis = L10n.t("Physiological metrics are stable. Proceed with regular scheduled training.", "今日各项生理指标表现平稳，可按原定计划开展中低强度常规训练。")
        }

        return DailyPlanLimiterResult(
            action: action,
            recommendedTrainingType: recommendedTrainingType,
            maxIntensity: maxIntensity,
            volumeMultiplier: volumeMultiplier,
            limiters: limiters,
            whyThis: whyThis
        )
    }
}
