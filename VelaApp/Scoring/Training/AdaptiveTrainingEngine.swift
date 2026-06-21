import Foundation

/// Manages adaptive adjustments to training plans based on daily readiness.
enum AdaptiveTrainingEngine {

    enum Adjustment: String, Codable, Hashable, Sendable {
        case keep
        case reduce
        case swap
        case rest
        case reschedule
        case deloadWeek
    }

    struct AdjustedDay: Codable, Hashable, Identifiable, Sendable {
        var id: UUID = UUID()
        var originalDay: TrainingDay
        var adjustment: Adjustment
        var reason: String
        var suggestedAlternative: String?

        init(id: UUID = UUID(), originalDay: TrainingDay, adjustment: Adjustment, reason: String, suggestedAlternative: String? = nil) {
            self.id = id
            self.originalDay = originalDay
            self.adjustment = adjustment
            self.reason = reason
            self.suggestedAlternative = suggestedAlternative
        }
    }

    /// Computes the appropriate adjustment for today's training step
    /// based on the user's physiological readiness.
    static func adjustToday(
        plan: TrainingPlanRecord,
        recoveryScore: Double,
        energyScore: Double,
        tsb: Double,
        sleepScore: Double,
        stressIndex: Double
    ) -> AdjustedDay? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayNumber = weekday == 1 ? 7 : weekday - 1

        guard let todayStep = plan.days.first(where: {
            !$0.isCompleted && $0.dayNumber == dayNumber
        }) else {
            return nil
        }

        let adjustment: Adjustment
        let reason: String
        let alternative: String?

        // Recovery-gated decision tree
        if recoveryScore > 75 && energyScore > 60 && tsb > 5 && sleepScore > 80 {
            adjustment = .keep
            reason = AppLanguage.stored.isChinese ? "当前恢复与睡眠信号支持按计划训练；训练中仍以动作质量和主观用力为准。" : "Current recovery and sleep signals support the planned session; keep technique and perceived effort in check."
            alternative = nil
        } else if recoveryScore > 50 && energyScore > 40 && tsb > -5 {
            adjustment = .reduce
            reason = AppLanguage.stored.isChinese ? "恢复状态中等。建议将训练容量减少 30-40%。" : "Recovery is moderate. Reduce intensity by 30-40%."
            alternative = buildReducedVersion(of: todayStep)
        } else if recoveryScore > 30 {
            adjustment = .swap
            reason = AppLanguage.stored.isChinese ? "恢复状态较低。建议今天进行低强度的恢复性训练。" : "Recovery is low. Swap to active recovery today."
            alternative = buildRecoveryAlternative(for: todayStep)
        } else {
            adjustment = .rest
            reason = AppLanguage.stored.isChinese ? "当前恢复信号较低。建议暂停计划训练，以休息或温和活动为主。" : "Current recovery signals are low. Pause planned training and prioritize rest or gentle movement."
            alternative = nil
        }

        // TSB override: if TSB < -15, always reduce regardless of recovery
        let finalAdjustment: Adjustment
        let finalReason: String
        if tsb < -15 && adjustment == .keep {
            finalAdjustment = .reduce
            finalReason = AppLanguage.stored.isChinese ? "体能负荷（TSB）处于深度负值（-\(Int(abs(tsb)))）。累积疲劳较高，建议降低训练容量。" : "TSB is deeply negative (-\(Int(abs(tsb)))). High accumulated fatigue requires reduced load."
        } else if tsb > 10 && adjustment == .reduce {
            finalAdjustment = .reduce
            finalReason = AppLanguage.stored.isChinese ? "长期负荷状态较好，但即时恢复仍未达到满量训练条件；今天继续按减量方案执行。" : "Long-term load is favorable, but current recovery still supports a reduced session today."
        } else {
            finalAdjustment = adjustment
            finalReason = reason
        }

        return AdjustedDay(
            originalDay: todayStep,
            adjustment: finalAdjustment,
            reason: finalReason,
            suggestedAlternative: finalAdjustment == .keep ? nil : alternative
        )
    }

    /// Per-day adjustment using BodyInterpretation. Used by generateWeekAdjustments
    /// to evaluate each future day independently against the body's current state.
    static func adjust(
        day: TrainingDay,
        interpretation: BodyInterpretation
    ) -> AdjustedDay? {
        let fatigueLevel = interpretation.fatigueLevel

        // Skip rest days — no adjustment needed
        guard day.focus != "rest" else { return nil }

        let adjustment: Adjustment
        let reason: String
        let alternative: String?

        switch (fatigueLevel, interpretation.trainingWindow.isOpen) {
        case (.none, true):
            adjustment = .keep
            reason = AppLanguage.stored.isChinese ? "当前可用信号未发现明显限制因素；按计划训练并保留余力。" : "Available signals show no major limiter; follow the plan while keeping some reserve."
            alternative = nil
        case (.mild, true):
            if day.intensity == "high" {
                adjustment = .reduce
                reason = AppLanguage.stored.isChinese ? "检测到轻度疲劳。建议降低计划中的高强度部分。" : "Mild fatigue detected. Reducing high-intensity session."
                alternative = buildReducedVersion(of: day)
            } else {
                adjustment = .keep
                reason = AppLanguage.stored.isChinese ? "检测到轻度疲劳，但当前训练强度适中。" : "Mild fatigue but session intensity is appropriate."
                alternative = nil
            }
        case (.moderate, _):
            if day.focus == "strength" || day.focus == "cardio" {
                adjustment = .swap
                reason = AppLanguage.stored.isChinese ? "中度疲劳。建议调整为主动恢复或拉伸。" : "Moderate fatigue. Swapping to active recovery."
                alternative = buildRecoveryAlternative(for: day)
            } else {
                adjustment = .reduce
                reason = AppLanguage.stored.isChinese ? "中度疲劳。建议降低训练容量。" : "Moderate fatigue. Reducing intensity."
                alternative = buildReducedVersion(of: day)
            }
        case (.significant, _):
            adjustment = .rest
            reason = AppLanguage.stored.isChinese ? "检测到明显疲劳。强烈建议安排休息。" : "Significant fatigue. Rest day recommended."
            alternative = nil
        case (.severe, _):
            adjustment = .deloadWeek
            reason = AppLanguage.stored.isChinese ? "检测到重度积累性疲劳。建议今天及本周安排减载（Deload）。" : "Severe fatigue detected. Deload week recommended."
            alternative = AppLanguage.stored.isChinese ? "轻度拉伸或 20 分钟散步" : "Light stretching or 20 min walk"
        case (_, false) where !interpretation.trainingWindow.isOpen:
            adjustment = .rest
            reason = AppLanguage.stored.isChinese ? "当前时段不属于建议的运动时间。" : "Training window is closed."
            alternative = nil
        default:
            adjustment = .keep
            reason = AppLanguage.stored.isChinese ? "当前可用信号未提示明显限制因素。" : "Available signals do not show a major limiter."
            alternative = nil
        }

        return AdjustedDay(
            originalDay: day,
            adjustment: adjustment,
            reason: reason,
            suggestedAlternative: adjustment == .keep ? nil : alternative
        )
    }

    // MARK: - Helpers

    private static func buildReducedVersion(of day: TrainingDay) -> String? {
        let reducedDuration = max(15, day.durationMinutes * 60 / 100) // 60% of original
        let reducedIntensity = day.intensity == "high" ? (AppLanguage.stored.isChinese ? "中等" : "moderate") : (AppLanguage.stored.isChinese ? "低" : "low")
        return AppLanguage.stored.isChinese 
            ? "\(day.title) (减载版): \(reducedDuration) 分钟以\(reducedIntensity)强度进行"
            : "\(day.title) (reduced): \(reducedDuration) min at \(reducedIntensity) intensity"
    }

    private static func buildRecoveryAlternative(for day: TrainingDay) -> String? {
        switch day.focus {
        case "strength":
            return AppLanguage.stored.isChinese 
                ? "自重关节活动度练习：20分钟泡沫轴滚压 + 动态拉伸"
                : "Bodyweight mobility routine: 20 min foam rolling + dynamic stretching"
        case "cardio":
            return AppLanguage.stored.isChinese 
                ? "超慢跑或轻度散步：20-30分钟 Zone 1 轻松活动"
                : "Light walk: 20-30 min at Zone 1, focusing on nasal breathing"
        case "flexibility":
            return AppLanguage.stored.isChinese 
                ? "保持静态拉伸，但将每次静止保持时间缩短至 30 秒"
                : "Keep flexibility session but reduce hold times to 30s"
        default:
            return AppLanguage.stored.isChinese 
                ? "温和流瑜伽或轻度拉伸：20分钟"
                : "Yoga or stretching: 20 min gentle flow"
        }
    }
}
