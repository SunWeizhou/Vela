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
            reason = AppLanguage.stored.isChinese ? "所有生理指标极佳。按原计划进行。" : "All readiness indicators are optimal. Stick to the plan."
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
            reason = AppLanguage.stored.isChinese ? "恢复状态极低。建议今天完全休息。" : "Recovery is critically low. Full rest day recommended."
            alternative = nil
        }

        // TSB override: if TSB < -15, always reduce regardless of recovery
        let finalAdjustment: Adjustment
        let finalReason: String
        if tsb < -15 && adjustment == .keep {
            finalAdjustment = .reduce
            finalReason = AppLanguage.stored.isChinese ? "体能负荷（TSB）处于深度负值（-\(Int(abs(tsb)))）。累积疲劳较高，建议降低训练容量。" : "TSB is deeply negative (-\(Int(abs(tsb)))). High accumulated fatigue requires reduced load."
        } else if tsb > 10 && adjustment == .reduce {
            finalAdjustment = .keep
            finalReason = AppLanguage.stored.isChinese ? "体能负荷（TSB）良好（+\(Int(tsb))）。虽然即时恢复度一般，但长期体能支持正常训练。" : "TSB is positive (+\(Int(tsb))). Despite moderate recovery, your chronic fitness allows normal training."
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
            reason = AppLanguage.stored.isChinese ? "所有生理准备指标良好。" : "All readiness indicators are optimal."
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
            reason = AppLanguage.stored.isChinese ? "未检测到异常生理信号。" : "No significant issues detected."
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
