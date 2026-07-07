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

struct TrainingDecisionInput {
    var bodyState: BodyState
    var activePlan: TrainingPlanRecord?
    var recentStrengthSummary: RecentTrainingSummary?
    var trainingResponses: [TrainingResponseRecord]
    var userConstraints: [String]

    init(
        bodyState: BodyState,
        activePlan: TrainingPlanRecord? = nil,
        recentStrengthSummary: RecentTrainingSummary? = nil,
        trainingResponses: [TrainingResponseRecord] = [],
        userConstraints: [String] = []
    ) {
        self.bodyState = bodyState
        self.activePlan = activePlan
        self.recentStrengthSummary = recentStrengthSummary
        self.trainingResponses = trainingResponses
        self.userConstraints = userConstraints
    }
}

struct TrainingDecisionKernel {
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
                let library = ExerciseLibraryService.defaultDefinitions()
                for item in planned {
                    let definition = library.first { def in
                        if let key = item.exerciseCanonicalKey {
                            return def.canonicalKey == key
                        }
                        return def.name.caseInsensitiveCompare(item.name) == .orderedSame
                    }
                    if let definition {
                        targetMuscles.insert(definition.primaryMuscleGroup.lowercased())
                        if let secondaryData = definition.secondaryMuscleGroupsJSON.data(using: .utf8),
                           let secondary = try? JSONDecoder().decode([String].self, from: secondaryData) {
                            for m in secondary {
                                targetMuscles.insert(m.lowercased())
                            }
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
        var type: DailyTrainingDecisionType = .keep
        var multiplier = 1.0
        var cap = 9
        var summary = ""
        var reasons: [String] = []
        
        if ["sick", "injured", "resting"].contains(state.activeStatus)
            || state.readiness == .recovering {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "状态受限，今天优先恢复与休息。"
            reasons.append("活动状态: 标记为\(Self.localizedActiveStatus(state.activeStatus))或生理处于恢复期。")
        } else if todayScheduledDay?.focus.lowercased() == "rest" {
            type = .rest
            multiplier = 0.0
            cap = 2
            summary = "今天是计划内的休息日，建议做好恢复工作。"
            reasons.append("日程安排: 计划内休息。")
        } else if !highFatigueTargetMuscles.isEmpty {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "避开高疲劳肌群 \(Self.localizedMuscleGroups(highFatigueTargetMuscles))，改做低风险替代训练。"
            reasons.append("局部疲劳: 目标肌群处于高疲劳状态。")
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
        } else if state.readiness == .caution {
            type = .reduce
            multiplier = 0.75
            cap = 7
            summary = "身体评分偏低，建议将今天训练容量减少至 75%，限制负荷上限。"
            reasons.append("生理评级: 恢复或睡眠分数偏低。")
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
