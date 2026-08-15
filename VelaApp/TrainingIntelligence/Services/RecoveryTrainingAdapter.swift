import Foundation

/// C3：用真实训练后的次日恢复变化校准容量系数——
/// 平均恢复变化正向（练后恢复良好）→ 略放宽；负向（练后吃力）→ 收紧。
enum TrainingResponseCalibrator {
    static func calibratedVolumeMultiplier(
        base: Double,
        recoveryDeltas: [Double],
        minimumSamples: Int = 6,
        floor: Double = 0.85,
        ceiling: Double = 1.1
    ) -> Double {
        guard recoveryDeltas.count >= minimumSamples else { return base }
        let meanDelta = recoveryDeltas.reduce(0, +) / Double(recoveryDeltas.count)
        let adjustment = ScoringMath.clamp(1.0 + meanDelta / 100.0, min: floor, max: ceiling)
        return base * adjustment
    }
}

struct RecoveryTrainingAdapter: Sendable {
    
    init() {}

    func adapt(input: RecoveryTrainingInput) -> TrainingAdaptationRecommendation {
        var reasons: [String] = []
        var baseMultiplier: Double
        let readiness: String
        var intensity: String
        var shouldTrain = true

        switch input.recoveryScore {
        case 80...:
            baseMultiplier = 1.05
            readiness = "high"
            intensity = "high"
        case 60..<80:
            baseMultiplier = 0.9
            readiness = "moderate"
            intensity = "moderate"
        case 40..<60:
            baseMultiplier = 0.65
            readiness = "low"
            intensity = "low"
            reasons.append(AppLanguage.stored.isChinese ? "恢复度低于正常训练区间。" : "Recovery is below the normal training range.")
        default:
            baseMultiplier = 0.35
            readiness = "very_low"
            intensity = "recovery"
            shouldTrain = false
            reasons.append(AppLanguage.stored.isChinese ? "恢复度极低。建议休息或进行主动恢复。" : "Recovery is very low. Rest or active recovery is preferred.")
        }

        if input.sleepScore < 75 {
            intensity = intensity == "recovery" ? intensity : "low"
            baseMultiplier = min(baseMultiplier, 0.75)
            reasons.append(AppLanguage.stored.isChinese ? "睡眠质量低于高强度训练阈值。" : "Sleep is below the threshold for high-intensity training.")
        }
        if let hrv = input.hrvZScore, hrv <= -1 {
            intensity = intensity == "recovery" ? intensity : "low"
            baseMultiplier = min(baseMultiplier, 0.8)
            reasons.append(AppLanguage.stored.isChinese ? "HRV 明显低于基线水平。" : "HRV is meaningfully below baseline.")
        }
        if let rhr = input.restingHRZScore, rhr >= 1 {
            intensity = intensity == "recovery" ? intensity : "low"
            baseMultiplier = min(baseMultiplier, 0.8)
            reasons.append(AppLanguage.stored.isChinese ? "静息心率明显高于基线水平。" : "Resting heart rate is elevated above baseline.")
        }
        if let tsb = input.tsb, tsb <= -15 {
            intensity = intensity == "recovery" ? intensity : "low"
            baseMultiplier = min(baseMultiplier, 0.7)
            reasons.append(AppLanguage.stored.isChinese ? "训练压力平衡（TSB）处于深度负值。" : "Training stress balance is deeply negative.")
        }

        let avoid = input.localFatigue.values.filter { $0.fatigueLevel == "high" }.map(\.muscleGroup).sorted()
        let preferred = input.localFatigue.values.filter { $0.setsLast7d < 6 }.map(\.muscleGroup).sorted()
        if let focus = input.plannedFocus, avoid.contains(focus) {
            reasons.append(AppLanguage.stored.isChinese ? "\(focus) 肌群在过去 48 小时内累积了过多局部疲劳。" : "\(focus) has accumulated too much local fatigue in the last 48 hours.")
        }
        let focus = preferred.first ?? (shouldTrain ? "balanced" : "active_recovery")
        let multiplier = avoid.contains(input.plannedFocus ?? "") ? min(baseMultiplier, 0.6) : baseMultiplier
        // C3：按个人训练响应校准容量系数。
        let calibratedMultiplier = TrainingResponseCalibrator.calibratedVolumeMultiplier(
            base: multiplier,
            recoveryDeltas: input.trainingResponseRecoveryDeltas
        )
        if abs(calibratedMultiplier - multiplier) > 0.005 {
            reasons.append(
                AppLanguage.stored.isChinese
                    ? "已按你近期的训练后恢复变化校准容量。"
                    : "Volume calibrated from your recent post-training recovery responses."
            )
        }
        
        let modifiedDesc: String
        if shouldTrain {
            modifiedDesc = AppLanguage.stored.isChinese
                ? "建议使用计划容量的 \(Int((calibratedMultiplier * 100).rounded()))%，强度控制在 \(intensity)。"
                : "Use \(Int((calibratedMultiplier * 100).rounded()))% of planned volume at \(intensity) intensity."
        } else {
            modifiedDesc = AppLanguage.stored.isChinese
                ? "建议选择休息、散步、拉伸或极轻度的恢复性训练。"
                : "Choose rest, walking, mobility, or light recovery work."
        }

        return TrainingAdaptationRecommendation(
            readinessLevel: readiness,
            shouldTrain: shouldTrain,
            recommendedIntensity: intensity,
            volumeMultiplier: calibratedMultiplier,
            suggestedFocus: focus,
            avoidMuscleGroups: avoid,
            preferredMuscleGroups: preferred,
            reasons: reasons.isEmpty ? [AppLanguage.stored.isChinese ? "当前恢复指标支持完成计划训练。" : "Current recovery signals support the planned session."] : reasons,
            modifiedWorkoutDescription: modifiedDesc
        )
    }
}
