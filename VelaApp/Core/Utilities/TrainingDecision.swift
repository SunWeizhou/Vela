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
        let highFatigue = state.localFatigue.values
            .filter { $0.fatigueLevel == "high" }
            .map(\.muscleGroup)
            .sorted()
        let type: DailyTrainingDecisionType
        let multiplier: Double
        let cap: Int
        let summary: String

        if ["sick", "injured", "resting"].contains(state.activeStatus)
            || state.readiness == .recovering {
            type = .rest
            multiplier = 0
            cap = 2
            summary = "今天优先休息或轻恢复，避免高强度训练。"
        } else if !highFatigue.isEmpty {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "避开\(Self.localizedMuscleGroups(highFatigue))，改做低风险替代训练。"
        } else if state.readiness == .caution || state.readiness == .unknown {
            type = .reduce
            multiplier = state.readiness == .unknown ? 0.6 : 0.75
            cap = 7
            summary = "建议减量训练：降低计划容量，RPE 控制在 7 以内；动作质量或主观用力变差时停止加量。"
        } else {
            type = .keep
            multiplier = 1
            cap = 9
            summary = "可以按计划训练，但保留 1-2 次余力并根据动作质量自我调节。"
        }

        let reasons = state.drivers.prefix(3).map { "\($0.title): \($0.detail)" }
        let confidence: Double = switch state.confidence {
        case .high: 0.9
        case .medium: 0.75
        case .low: 0.5
        case .unavailable: 0.3
        }
        return DailyTrainingDecision(
            decision: type,
            targetSessionTitle: input.activePlan?.title,
            volumeMultiplier: multiplier,
            intensityCap: cap,
            reasons: reasons.isEmpty ? ["未发现明显限制因素。"] : reasons,
            userFacingSummary: summary,
            confidence: confidence,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "仅提供一般健康与训练建议，不构成医疗诊断；如出现异常症状，请停止训练并寻求专业帮助。"
        )
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
