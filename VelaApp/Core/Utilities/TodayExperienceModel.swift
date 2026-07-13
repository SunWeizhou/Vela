import Foundation
import SwiftUI

enum DailyPlanKind: String, Codable, Hashable {
    case rest
    case recovery
    case train
    case maintain
    case protectSleep
    case downshift
}

enum DailyPlanAccent: String, Codable, Hashable {
    case recovery
    case sleep
    case strain
    case energy
    case stress
}

struct TodayExperienceNutrition: Codable, Hashable {
    var calories: Int
    var calorieTarget: Int
    var protein: Int
    var carbs: Int
    var fat: Int

    static let empty = TodayExperienceNutrition(
        calories: 0,
        calorieTarget: 0,
        protein: 0,
        carbs: 0,
        fat: 0
    )

    var calorieProgress: Double {
        guard calorieTarget > 0 else { return 0 }
        return min(1, max(0, Double(calories) / Double(calorieTarget)))
    }

    var calorieText: String {
        if calories == 0, protein == 0, carbs == 0, fat == 0 {
            return "今日未记录"
        }
        if calorieTarget > 0 {
            return "\(calories)/\(calorieTarget) kcal"
        }
        return calories > 0 ? "\(calories) kcal · 目标未设置" : "--"
    }

    var macroText: String {
        guard calories > 0 || protein > 0 || carbs > 0 || fat > 0 else { return "今日营养尚未记录" }
        return "蛋白 \(protein)g · 碳水 \(carbs)g · 脂肪 \(fat)g"
    }
}

struct TodayExperienceHero: Codable, Hashable {
    var scoreTitle: String
    var decisionTitle: String
    var summary: String
    var confidenceLabel: String
    var primaryActionTitle: String
}

struct TodayExperienceSignalCard: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var value: String
    var subtitle: String
    var trend: [Double]
    var accent: DailyPlanAccent
}

struct TodayExperienceAction: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var detail: String
    var destination: String
    var isPrimary: Bool
}

struct TodayExperienceModel: Codable, Hashable {
    var generatedAt: Date
    var hero: TodayExperienceHero
    var signalCards: [TodayExperienceSignalCard]
    var evidenceChips: [String]
    var actions: [TodayExperienceAction]
    var nutrition: TodayExperienceNutrition
    var coachPreview: String

    static func build(
        dashboard: DashboardSummary,
        bodyState: BodyState,
        trainingDecision: DailyTrainingDecision,
        generatedAt: Date = Date(),
        nutrition: TodayExperienceNutrition = .empty
    ) -> TodayExperienceModel {
        let hasReadinessData = dashboard.recovery.hasData
        let displayConfidence = hasReadinessData ? trainingDecision.confidence : 0.0
        let confidenceDetail = hasReadinessData ? label(for: bodyState.confidence) : "数据不足"
        let hero = TodayExperienceHero(
            scoreTitle: scoreTitle(dashboard),
            decisionTitle: decisionTitle(
                trainingDecision,
                hasReadinessData: hasReadinessData
            ),
            summary: summary(
                dashboard: dashboard,
                bodyState: bodyState,
                decision: trainingDecision,
                hasReadinessData: hasReadinessData
            ),
            confidenceLabel: hasReadinessData
                ? "置信度 \(Int((displayConfidence * 100).rounded()))% · \(confidenceDetail)"
                : confidenceDetail,
            primaryActionTitle: primaryActionTitle(
                trainingDecision,
                hasReadinessData: hasReadinessData
            )
        )

        let signals = [
            signal(
                id: "recovery",
                title: "恢复",
                metric: dashboard.recovery,
                fallbackSubtitle: "等待 HealthKit 恢复基线",
                accent: .recovery
            ),
            signal(
                id: "sleep",
                title: "睡眠",
                metric: dashboard.sleepScore,
                fallbackSubtitle: "等待睡眠时长与连续性",
                accent: .sleep
            ),
            signal(
                id: "strain",
                title: "负荷",
                metric: dashboard.strain,
                fallbackSubtitle: "等待训练负荷",
                accent: .strain
            ),
            signal(
                id: "stress",
                title: "压力",
                metric: dashboard.stress,
                fallbackSubtitle: "等待压力指标",
                accent: .stress
            ),
            signal(
                id: "energy",
                title: "能量",
                metric: dashboard.energy,
                fallbackSubtitle: "等待能量模型",
                accent: .energy
            )
        ]

        return TodayExperienceModel(
            generatedAt: generatedAt,
            hero: hero,
            signalCards: signals,
            evidenceChips: evidenceChips(
                dashboard: dashboard,
                bodyState: bodyState,
                decision: trainingDecision,
                hasReadinessData: hasReadinessData
            ),
            actions: actionPlan(
                decision: trainingDecision,
                hasReadinessData: hasReadinessData
            ),
            nutrition: nutrition,
            coachPreview: coachPreview(
                dashboard: dashboard,
                bodyState: bodyState,
                decision: trainingDecision,
                confidence: displayConfidence,
                hasReadinessData: hasReadinessData
            )
        )
    }

    private static func scoreTitle(_ dashboard: DashboardSummary) -> String {
        dashboard.recovery.hasData ? "恢复 \(Int(dashboard.recovery.score.rounded()))" : "恢复 --"
    }

    private static func decisionTitle(
        _ decision: DailyTrainingDecision,
        hasReadinessData: Bool
    ) -> String {
        guard hasReadinessData else { return "先保守减量" }
        switch decision.decision {
        case .keep: return "按计划训练"
        case .reduce: return "控制训练量"
        case .swap: return "换练其他部位"
        case .rest: return "恢复优先"
        }
    }

    private static func primaryActionTitle(
        _ decision: DailyTrainingDecision,
        hasReadinessData: Bool
    ) -> String {
        guard hasReadinessData else { return "同步健康数据" }
        switch decision.decision {
        case .keep, .reduce, .swap: return "开始今日训练"
        case .rest: return "执行恢复计划"
        }
    }

    private static func summary(
        dashboard: DashboardSummary,
        bodyState: BodyState,
        decision: DailyTrainingDecision,
        hasReadinessData: Bool
    ) -> String {
        guard hasReadinessData else {
            return "当前缺少恢复基线，Vela 会先按保守训练窗口处理，并优先引导同步数据。"
        }
        let sleep = dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--"
        let strain = dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--"
        let limiter = bodyState.drivers.first.map(displayDriverTitle) ?? "未发现主要限制"
        return "\(displayDecisionSummary(decision)) 睡眠 \(sleep)，负荷 \(strain)，主要证据：\(limiter)。"
    }

    private static func signal(
        id: String,
        title: String,
        metric: MetricResult,
        fallbackSubtitle: String,
        accent: DailyPlanAccent
    ) -> TodayExperienceSignalCard {
        let value = metric.hasData ? "\(Int(metric.score.rounded()))" : "--"
        let subtitle = metric.hasData ? "已纳入今日评估" : fallbackSubtitle
        return TodayExperienceSignalCard(
            id: id,
            title: title,
            value: value,
            subtitle: subtitle,
            trend: [],
            accent: accent
        )
    }

    private static func evidenceChips(
        dashboard: DashboardSummary,
        bodyState: BodyState,
        decision: DailyTrainingDecision,
        hasReadinessData: Bool
    ) -> [String] {
        guard hasReadinessData else {
            return ["等待 HealthKit", "保守训练窗口", "先建立个人基线"]
        }

        var chips = [decisionEvidenceChip(decision)]
        if let driver = bodyState.drivers.first {
            chips.append(displayDriverTitle(driver))
        }
        if let hrv = dashboard.recoveryMetrics.hrvMilliseconds {
            chips.append("HRV \(Int(hrv.rounded()))ms")
        }
        if dashboard.sleepScore.hasData {
            chips.append("睡眠 \(Int(dashboard.sleepScore.score.rounded()))")
        }
        return Array(chips.prefix(4))
    }

    private static func actionPlan(
        decision: DailyTrainingDecision,
        hasReadinessData: Bool
    ) -> [TodayExperienceAction] {
        guard hasReadinessData else {
            return [
                .init(id: "sync_health", title: "同步健康数据", detail: "更新 HRV、静息心率、睡眠和训练负荷。", destination: "sync", isPrimary: true),
                .init(id: "log_status", title: "记录身体状态", detail: "补充疲劳、酸痛、压力或生病状态。", destination: "journal", isPrimary: false),
                .init(id: "ask_coach", title: "询问 Vela", detail: "用当前有限数据生成保守建议。", destination: "coach", isPrimary: false)
            ]
        }
        switch decision.decision {
        case .keep:
            return [
                .init(id: "start_training", title: "开始今日训练", detail: "正常执行计划，保留 1-2 次余力。", destination: "training", isPrimary: true),
                .init(id: "protect_sleep", title: "保护今晚睡眠", detail: "固定入睡时间，避免训练后过晚进食。", destination: "journal", isPrimary: false),
                .init(id: "ask_coach", title: "问 Vela 调整细节", detail: "根据动作、RPE 和肌群疲劳微调。", destination: "coach", isPrimary: false)
            ]
        case .reduce:
            return [
                .init(id: "reduce_training", title: "减量训练", detail: "容量 \(Int((decision.volumeMultiplier * 100).rounded()))%，RPE 上限 \(decision.intensityCap)。", destination: "training", isPrimary: true),
                .init(id: "check_in", title: "记录疲劳", detail: "把酸痛、精神状态 and 压力写入上下文。", destination: "journal", isPrimary: false),
                .init(id: "recovery_block", title: "安排恢复块", detail: "补水、低强度步行和提前睡眠。", destination: "recovery", isPrimary: false)
            ]
        case .swap:
            return [
                .init(id: "swap_session", title: "替换训练内容", detail: "避开高疲劳肌群，保留训练节奏。", destination: "training", isPrimary: true),
                .init(id: "mobility", title: "增加活动度", detail: "优先低冲击和技术练习。", destination: "recovery", isPrimary: false),
                .init(id: "ask_coach", title: "让 Vela 改计划", detail: "生成替代动作与组数。", destination: "coach", isPrimary: false)
            ]
        case .rest:
            return [
                .init(id: "recovery_day", title: "执行恢复日", detail: "停止高强度训练，只做轻 activity。", destination: "recovery", isPrimary: true),
                .init(id: "symptom_check", title: "记录异常信号", detail: "如果有不适，记录并考虑专业意见。", destination: "journal", isPrimary: false),
                .init(id: "sleep_plan", title: "今晚提前睡眠", detail: "把恢复放在训练之前。", destination: "journal", isPrimary: false)
            ]
        }
    }

    private static func coachPreview(
        dashboard: DashboardSummary,
        bodyState: BodyState,
        decision: DailyTrainingDecision,
        confidence: Double,
        hasReadinessData: Bool
    ) -> String {
        guard hasReadinessData else {
            return "AI 教练：当前置信度 \(Int((confidence * 100).rounded()))%，先同步 HealthKit 并采用保守建议。"
        }
        let freshness = label(for: bodyState.freshness)
        let recovery = Int(dashboard.recovery.score.rounded())
        return "AI 教练：恢复 \(recovery)，\(displayDecisionSummary(decision)) 置信度 \(Int((confidence * 100).rounded()))%，数据新鲜度：\(freshness)。"
    }

    private static func displayDecisionSummary(_ decision: DailyTrainingDecision) -> String {
        switch decision.decision {
        case .keep:
            return "按计划训练，保留 1-2 次余力，并根据动作质量自我调节。"
        case .reduce:
            return "建议将训练容量调整到 \(Int((decision.volumeMultiplier * 100).rounded()))%，RPE 控制在 \(decision.intensityCap) 以内。"
        case .swap:
            return "建议替换高疲劳肌群的训练内容，保留训练节奏，RPE 控制在 \(decision.intensityCap) 以内。"
        case .rest:
            return "今天优先恢复或轻活动，避免追求训练量。"
        }
    }

    private static func decisionEvidenceChip(_ decision: DailyTrainingDecision) -> String {
        switch decision.decision {
        case .keep:
            return "按计划训练"
        case .reduce:
            return "训练容量 \(Int((decision.volumeMultiplier * 100).rounded()))%"
        case .swap:
            return "替换高疲劳肌群"
        case .rest:
            return "恢复优先"
        }
    }

    private static func displayDriverTitle(_ driver: BodyStateDriver) -> String {
        switch driver.kind {
        case .localFatigue:
            return "\(localizedMuscle(from: driver.title))局部疲劳"
        case .trainingResponse:
            return "近期训练后的恢复反应"
        case .dataCoverage:
            return "数据覆盖不足"
        case .recovery:
            return "恢复信号"
        case .sleep:
            return "睡眠信号"
        case .strain:
            return "近期训练负荷"
        case .stress:
            return "压力信号"
        case .energy:
            return "能量状态"
        case .activeStatus:
            return "当前生活状态"
        case .nutrition:
            return "今日营养记录"
        case .journal:
            return "近期主观记录"
        case .activePlan:
            return "当前训练计划"
        case .recentActivity:
            return "近期活动"
        }
    }

    private static func localizedMuscle(from title: String) -> String {
        let normalized = title.lowercased()
        if normalized.contains("chest") { return "胸部" }
        if normalized.contains("back") { return "背部" }
        if normalized.contains("quads") || normalized.contains("quadriceps") { return "股四头肌" }
        if normalized.contains("hamstrings") { return "腘绳肌" }
        if normalized.contains("glutes") { return "臀部" }
        if normalized.contains("shoulders") || normalized.contains("shoulder") { return "肩部" }
        if normalized.contains("biceps") { return "肱二头肌" }
        if normalized.contains("triceps") { return "肱三头肌" }
        if normalized.contains("core") { return "核心" }
        if normalized.contains("leg") { return "腿部" }
        return "相关肌群"
    }

    private static func label(for confidence: DataConfidence) -> String {
        switch confidence {
        case .high: return "高可信"
        case .medium: return "中等可信"
        case .low: return "低可信"
        case .unavailable: return "数据不足"
        }
    }

    private static func label(for freshness: DataFreshness) -> String {
        switch freshness {
        case .live: return "实时"
        case .today: return "今日"
        case .recent: return "近期"
        case .stale: return "过期"
        case .missing: return "缺失"
        }
    }
}

struct TrainingSurfaceSummaryModel: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var headline: String
    var guidance: String
    var targetRangeText: String
    var recoveryValue: String
    var sleepValue: String
    var strainValue: String
    var confidenceLabel: String
    var primaryActionTitle: String
    var sessionTitle: String?
    var intensityCapText: String
    var coachQuestion: String

    static func build(
        dashboard: DashboardSummary,
        todayExperience: TodayExperienceModel,
        trainingDecision: DailyTrainingDecision,
        operatingPlan: DailyOperatingPlanPayload?
    ) -> TrainingSurfaceSummaryModel {
        let decision = operatingPlan?.decision ?? trainingDecision.decision
        let range = dashboard.strain.recommendedRange
        let sessionTitle = operatingPlan?.targetSessionTitle ?? trainingDecision.targetSessionTitle
        let guidance = operatingPlan?.summary ?? todayExperience.hero.summary
        let intensityCap = operatingPlan?.intensityCap ?? trainingDecision.intensityCap

        return TrainingSurfaceSummaryModel(
            decision: decision,
            headline: headline(for: decision),
            guidance: guidance,
            targetRangeText: dashboard.strain.hasData ? "\(range.lowerBound)-\(range.upperBound)" : "--",
            recoveryValue: dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--",
            sleepValue: dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--",
            strainValue: dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--",
            confidenceLabel: dashboard.source == .empty ? "数据不足" : todayExperience.hero.confidenceLabel,
            primaryActionTitle: primaryActionTitle(for: decision),
            sessionTitle: sessionTitle,
            intensityCapText: "RPE <= \(intensityCap)",
            coachQuestion: coachQuestion(for: decision, sessionTitle: sessionTitle, guidance: guidance)
        )
    }

    private static func headline(for decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: return "今日按计划训练"
        case .reduce: return "今日减量训练"
        case .swap: return "替换训练内容"
        case .rest: return "恢复优先"
        }
    }

    private static func primaryActionTitle(for decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: return "开始今日训练"
        case .reduce: return "执行减量训练"
        case .swap: return "换成更合适训练"
        case .rest: return "安排恢复日"
        }
    }

    private static func coachQuestion(
        for decision: DailyTrainingDecisionType,
        sessionTitle: String?,
        guidance: String
    ) -> String {
        let session = sessionTitle.map { "目标训练：\($0)。" } ?? ""
        switch decision {
        case .keep:
            return "\(session)请基于当前数据确认今天训练的热身、主项和强度上限。"
        case .reduce:
            return "\(session)请把今天训练改成减量版本，并保留最重要的训练刺激。依据：\(guidance)"
        case .swap:
            return "\(session)请替换今天训练内容，避开高疲劳部位，同时保持训练连续性。依据：\(guidance)"
        case .rest:
            return "请为今天安排恢复日，包括低强度活动、拉伸和睡眠优先级。依据：\(guidance)"
        }
    }
}
