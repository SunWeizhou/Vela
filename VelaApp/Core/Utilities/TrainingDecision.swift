import Foundation
import SwiftData

enum DailyTrainingDecisionType: String, Codable, Hashable, Sendable {
    case keep
    case reduce
    case swap
    case rest
}

struct DailyTrainingDecision: Codable, Hashable, Sendable {
    var decision: DailyTrainingDecisionType
    var targetSessionTitle: String?
    var volumeMultiplier: Double
    var intensityCap: Int
    var reasons: [String]
    var userFacingSummary: String
    var confidence: Double
    var source: String
    var safetyNotice: String
}

enum TrainingDecisionFallback {
    static func conservative(targetSessionTitle: String?) -> DailyTrainingDecision {
        DailyTrainingDecision(
            decision: .reduce,
            targetSessionTitle: targetSessionTitle,
            volumeMultiplier: 0.60,
            intensityCap: 7,
            reasons: ["数据状态：今日身体信号尚未完成同步，使用保守训练窗口。"],
            userFacingSummary: "今日数据尚未完成同步；先按约 60% 容量训练，RPE 不超过 7，并在动作质量下降时停止加量。",
            confidence: 0.25,
            source: "TrainingDecisionFallback",
            safetyNotice: "一般健康与训练建议，不构成医疗诊断。"
        )
    }
}

struct TrainingDecisionInput {
    var bodyState: BodyState
    var activePlan: TrainingPlanDTO?
    var trainingResponses: [TrainingResponseDTO]
    var userConstraints: [String]
    /// 三年训练量长线统计（Layer 2：本月训练量三年百分位信号；nil = 不启用）。
    var longTermTrainingVolume: TrainingVolumeLongTerm?

    init(
        bodyState: BodyState,
        activePlan: TrainingPlanDTO? = nil,
        trainingResponses: [TrainingResponseDTO] = [],
        userConstraints: [String] = [],
        longTermTrainingVolume: TrainingVolumeLongTerm? = nil
    ) {
        self.bodyState = bodyState
        self.activePlan = activePlan
        self.trainingResponses = trainingResponses
        self.userConstraints = userConstraints
        self.longTermTrainingVolume = longTermTrainingVolume
    }
}

struct TrainingDecisionKernel: Sendable {
    func decide(input: TrainingDecisionInput) -> DailyTrainingDecision {
        let state = input.bodyState
        let activePlan = input.activePlan
        
        // 1. Resolve today's scheduled TrainingDay using bodyState date
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: state.date)
        let dayNumber = weekday == 1 ? 7 : weekday - 1
        
        let todayScheduledDay = activePlan?.days.first(where: {
            !$0.isCompleted && $0.dayNumber == dayNumber
        })
        
        // 2. Identify target muscle groups from planned exercises
        var targetMuscles = Set<String>()
        if let todayScheduledDay {
            if let data = todayScheduledDay.plannedExercisesJSON.data(using: .utf8),
               let planned = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) {
                let library = ExerciseLibraryService.defaultDefinitionsDTO()
                for item in planned {
                    let definition = library.first { def in
                        if let key = item.exerciseCanonicalKey {
                            return def.canonicalKey == key
                        }
                        return def.name.caseInsensitiveCompare(item.name) == .orderedSame
                    }
                    if let definition {
                        targetMuscles.insert(definition.primaryMuscleGroup.lowercased())
                        for m in definition.secondaryMuscleGroups {
                            targetMuscles.insert(m.lowercased())
                        }
                    }
                }
            }
        }
        
        // 3. Compare target muscles with local fatigue
        var highFatigueTargetMuscles: [String] = []
        for muscle in targetMuscles {
            if let fatigue = state.localFatigue[muscle], fatigue.fatigueLevel == "high" {
                highFatigueTargetMuscles.append(muscle)
            }
        }
        
        // 4. Use TrainingResponseRecord history by muscle group (last 28 days)
        var poorResponseTargetMuscles: [String] = []
        var severeResponseCrash = false
        let cutoffDate = state.date.addingTimeInterval(-28 * 86_400)
        let recentResponses = input.trainingResponses.filter {
            $0.date >= cutoffDate && $0.date <= state.date
        }
        for response in recentResponses {
            let responseMuscles = response.primaryMuscleGroups.map { $0.lowercased() }
            let intersects = responseMuscles.contains { targetMuscles.contains($0) }
            if intersects {
                let isPoor = (response.nextDayRecoveryDelta ?? 0) <= -8
                    || (response.nextDayHRVDelta ?? 0) <= -10
                    || (response.nextDayRHRDelta ?? 0) >= 5
                if isPoor {
                    for m in responseMuscles {
                        if targetMuscles.contains(m) {
                            poorResponseTargetMuscles.append(m)
                        }
                    }
                    if (response.nextDayRecoveryDelta ?? 0) <= -15 {
                        severeResponseCrash = true
                    }
                }
            }
        }
        
        // 5. Decision logic tree
        // 算法打通（批次 A）：本决策树是「今日/训练/计划」三处的唯一结论源。
        // 睡眠/压力/能量/TSB/当日负荷门控此前只存在于 TodayCommandBuilder 或死代码
        // （TrainingDecisionEngine / AdaptiveTrainingEngine.adjustToday），现统一在此，
        // 且只向保守方向收紧（keep → reduce/rest；不新增激进分支）。
        let thresholds = PersonalBaselineEngine.resolveThresholds()
        let stressIndex = state.stress.stressIndex
        let energyLevel = state.energy.currentEnergy
        let tsb = state.energy.metrics["tsb"]
        let strainUpper = state.strain.recommendedRange.upperBound
        var type: DailyTrainingDecisionType = .keep
        var multiplier = 1.0
        var cap = 9
        var summary = ""
        var reasons: [String] = []
        
        if ["sick", "injured", "resting"].contains(state.activeStatus) {
            // 用户显式标记的身体状态是硬约束，先于一切数据判定。
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "状态受限，今天优先恢复与休息。"
            reasons.append("活动状态: 标记为\(Self.localizedActiveStatus(state.activeStatus))，今天自动降低训练冒险度。")
        } else if !state.recovery.hasData {
            type = .reduce
            multiplier = 0.60
            cap = 7
            summary = "恢复基线数据不足，先按保守方案执行。"
            reasons.append("数据状态: 恢复基线数据不足，按保守方案执行。")
        } else if state.readiness == .recovering {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "状态受限，今天优先恢复与休息。"
            reasons.append("生理状态: 恢复分数低于休息阈值，处于恢复期。")
        } else if todayScheduledDay?.focus.lowercased() == "rest" {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "今天是计划内的休息日，建议做好恢复工作。"
            reasons.append("日程安排: 计划内休息。")
        } else if state.sleep.hasData, state.sleep.score < thresholds.sleepRest {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "睡眠明显不足，今天优先恢复与补觉，避免高强度训练。"
            reasons.append("睡眠不足: 睡眠分数 \(Int(state.sleep.score.rounded())) 低于休息阈值 \(Int(thresholds.sleepRest.rounded()))。")
        } else if state.stress.hasData, stressIndex > 75 {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "生理压力偏高，今天优先减压与恢复，避免叠加训练负荷。"
            reasons.append("压力偏高: 压力指数 \(Int(stressIndex.rounded()))（>75），先降压力再考虑负荷。")
        } else if !highFatigueTargetMuscles.isEmpty {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "避开高疲劳肌群 \(Self.localizedMuscleGroups(highFatigueTargetMuscles))，改做低风险替代训练。"
            reasons.append("局部疲劳: 目标肌群处于高疲劳状态。")
        } else if targetMuscles.isEmpty,
                  let worstFatigue = state.localFatigue.values
                      .filter({ $0.fatigueLevel == "high" })
                      .sorted(by: { $0.setsLast48h > $1.setsLast48h })
                      .first {
            // 无计划日：任一肌群高疲劳即建议换部位（与今日页此前的「任一高疲劳 → 换练」语义对齐）。
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "\(Self.localizedMuscleGroup(worstFatigue.muscleGroup))局部疲劳偏高，建议换练其他部位。"
            reasons.append("局部疲劳: \(Self.localizedMuscleGroup(worstFatigue.muscleGroup))处于高疲劳状态（48 小时 \(worstFatigue.setsLast48h) 组）。")
        } else if severeResponseCrash {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "近期同部位训练出现严重生理响应崩溃，建议今天替换训练肌群。"
            reasons.append("训练响应: 该肌群近期训练后次日恢复严重暴跌。")
        } else if !poorResponseTargetMuscles.isEmpty {
            type = .reduce
            multiplier = 0.70
            cap = 7
            summary = "近期对 \(Self.localizedMuscleGroups(poorResponseTargetMuscles)) 训练的恢复响应欠佳，建议减量训练。"
            reasons.append("训练响应: 该肌群近期训练后次日恢复有下降趋势。")
        } else if state.energy.hasData, energyLevel < 30 {
            type = .reduce
            multiplier = 0.70
            cap = 7
            summary = "身体储备偏低，建议减量训练，并保证正常进食与睡眠。"
            reasons.append("能量储备: 当前能量 \(Int(energyLevel.rounded()))/100 偏低，不宜硬扛。")
        } else if let tsb, tsb <= -15 {
            type = .reduce
            multiplier = 0.70
            cap = 7
            summary = "累积训练负荷偏高，建议今天降低容量。"
            reasons.append("训练压力平衡: TSB \(String(format: "%+.0f", tsb)) 深度为负（≤-15），累积负荷偏高。")
        } else if state.readiness == .caution {
            type = .reduce
            multiplier = 0.75
            cap = 7
            summary = "身体评分偏低，建议将今天训练容量减少至 75%，限制负荷上限。"
            reasons.append("生理评级: 恢复或睡眠分数偏低。")
        } else if state.strain.hasData, state.strain.score > Double(strainUpper) {
            type = .reduce
            multiplier = 0.75
            cap = 7
            summary = "当日负荷已高于目标区间，建议减量。"
            reasons.append("当日负荷: 负荷 \(Int(state.strain.score.rounded())) 已超过今日目标上限 \(strainUpper)。")
        } else if state.readiness == .unknown {
            type = .reduce
            multiplier = 0.60
            cap = 7
            summary = "当前生理数据覆盖度不足，进行保守减量推荐以规避风险。"
            reasons.append("数据状态: 生理可信度过低。")
        } else {
            type = .keep
            multiplier = 1.0
            cap = 9
            summary = "可以按计划训练，但建议保留 1-2 次余力，并根据动作质量自我调节。"
            reasons.append("生理评级: 身体信号优良，支持正常训练。")
        }
        
        // Layer 2：本月训练量处于三年月分布 P85 以上时，长期视角建议减量。
        if type == .keep,
           let volume = input.longTermTrainingVolume,
           let percentile = volume.currentMonthPercentile,
           percentile >= 85 {
            type = .reduce
            multiplier = 0.85
            cap = 8
            summary = "本月训练量处于三年月分布 P\(Int(percentile.rounded()))，长期视角偏高，建议适当减量。"
            reasons.append("长线训练量: 本月 \(Int(volume.currentMonthMinutes.rounded())) 分钟处于三年月分布 P\(Int(percentile.rounded()))。")
        }

        // C3：按个人训练响应的平均恢复变化全局校准容量系数
        //（rest/swap 的决策语义已固定，不参与校准）。
        if type == .keep || type == .reduce {
            let recoveryDeltas = recentResponses.compactMap(\.nextDayRecoveryDelta)
            let calibrated = TrainingResponseCalibrator.calibratedVolumeMultiplier(
                base: multiplier,
                recoveryDeltas: recoveryDeltas
            )
            if abs(calibrated - multiplier) > 0.005 {
                reasons.append("已按你近期的训练后恢复变化校准容量。")
                multiplier = calibrated
            }
        }

        // Inject user constraints
        for constraint in input.userConstraints {
            if constraint.localizedCaseInsensitiveContains("injury") || constraint.localizedCaseInsensitiveContains("hurt") || constraint.localizedCaseInsensitiveContains("pain") {
                type = .rest
                multiplier = 0.0
                cap = 2
                summary = "受用户限制条件约束，今天建议完全休息。"
                reasons.append("用户约束: 限制条件包含伤病或疼痛。")
            }
        }
        
        let confidence: Double = switch state.confidence {
        case .high: 0.9
        case .medium: 0.75
        case .low: 0.5
        case .unavailable: 0.3
        }
        
        let finalTitle = todayScheduledDay?.title ?? activePlan?.title ?? "自由训练"
        
        return DailyTrainingDecision(
            decision: type,
            targetSessionTitle: finalTitle,
            volumeMultiplier: multiplier,
            intensityCap: cap,
            reasons: reasons,
            userFacingSummary: summary,
            confidence: confidence,
            source: "BodyStateKernel + TrainingDecisionKernel v2",
            safetyNotice: "仅提供一般健康与训练建议，不构成医疗诊断；如出现异常症状，请停止训练并寻求专业帮助。"
        )
    }
    
    private static func localizedActiveStatus(_ status: String) -> String {
        switch status.lowercased() {
        case "sick": return "生病"
        case "injured": return "受伤"
        case "resting": return "休息中"
        default: return "活跃"
        }
    }

    private static func localizedMuscleGroups(_ groups: [String]) -> String {
        let localized = groups.map(localizedMuscleGroup).filter { !$0.isEmpty }
        guard !localized.isEmpty else { return "相关肌群" }
        return localized.joined(separator: "、")
    }

    private static func localizedMuscleGroup(_ group: String) -> String {
        switch group.lowercased() {
        case "chest": return "胸部"
        case "back": return "背部"
        case "shoulders": return "肩部"
        case "biceps": return "肱二头肌"
        case "triceps": return "肱三头肌"
        case "quads", "quadriceps": return "股四头肌"
        case "hamstrings": return "腘绳肌"
        case "glutes": return "臀部"
        case "core", "abs": return "核心"
        case "legs": return "腿部"
        default: return group
        }
    }
}
