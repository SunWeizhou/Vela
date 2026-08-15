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

    /// Per-day adjustment using BodyInterpretation（refreshDailyProposal 使用）。
    
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
