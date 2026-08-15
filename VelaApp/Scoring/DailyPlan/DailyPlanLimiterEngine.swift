import Foundation

// 算法打通（批次 D）：DailyPlanLimiterEngine / DailyPlanLimiterInput /
// DailyPlanLimiterResult / PlanAction 已随 TrainingDecisionEngine 一并删除
// （唯一调用方是死代码；决策收敛到 TrainingDecisionKernel）。
// PlanLimiter 保留：TrainingDecision.compatibilityView 仍用它表达计划限制项。

public struct PlanLimiter: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var severity: Int // 1–3
    public var reason: String
    public var recommendation: String
}
