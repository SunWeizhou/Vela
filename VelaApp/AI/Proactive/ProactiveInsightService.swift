import Foundation
import SwiftUI
import SwiftData
import UserNotifications
import os.log

struct ProactiveInsight: Identifiable, Hashable {
    let id = UUID()
    var focus: Focus = .readiness
    var severity: Severity
    var title: String
    var body: String
    var suggestedAction: String?
    var relatedMetrics: [String]
    var evidence: [String] = []
    var priority: Int = 50
    var coachPresetQuestion: String // Tapping the card pre-fills this question

    enum Focus: Hashable {
        case readiness
        case recovery
        case sleep
        case training
        case energy
        case movement
        case stress

        var title: String {
            switch self {
            case .readiness: return "今日策略"
            case .recovery: return "恢复"
            case .sleep: return "睡眠"
            case .training: return "训练"
            case .energy: return "能量"
            case .movement: return "动作质量"
            case .stress: return "压力"
            }
        }

        var icon: String {
            switch self {
            case .readiness: return "scope"
            case .recovery: return "arrow.clockwise.heart"
            case .sleep: return "moon.zzz.fill"
            case .training: return "figure.strengthtraining.traditional"
            case .energy: return "bolt.fill"
            case .movement: return "figure.walk"
            case .stress: return "waveform.path.ecg"
            }
        }

        var color: Color {
            switch self {
            case .readiness: return VelaTheme.accent
            case .recovery: return VelaTheme.recoveryColor
            case .sleep: return Color(hex: "#5C6BC0")
            case .training: return Color(hex: "#FF8A3D")
            case .energy: return VelaTheme.energyColor
            case .movement: return Color(hex: "#34C759")
            case .stress: return VelaTheme.stressColor
            }
        }
    }
    
    enum Severity: Hashable {
        case info
        case warning
        case alert
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .alert: return "exclamationmark.octagon.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return VelaTheme.recoveryColor
            case .warning: return VelaTheme.energyColor
            case .alert: return VelaTheme.stressColor
            }
        }
    }
}

enum ProactiveInsightService {
    static func evaluate(dashboard: DashboardSummary) -> [ProactiveInsight] {
        var insights: [ProactiveInsight] = []
        let isChinese = AppLanguage.stored.isChinese
        
        // Rule 1: HRV significantly low (HRV Z-score < -1.5)
        if let hrvZScore = dashboard.recovery.metrics["hrv_z_score"], hrvZScore < -1.5 {
            insights.append(ProactiveInsight(
                focus: .recovery,
                severity: .alert,
                title: isChinese ? "今天先把强度降下来" : "Reduce intensity today",
                body: isChinese
                    ? "HRV 明显低于你的个人基线。这是一项需要结合睡眠、近期训练和主观感受观察的恢复信号。"
                    : "HRV is well below your personal baseline. Treat it as a recovery signal to consider alongside sleep, recent training, and how you feel.",
                suggestedAction: isChinese ? "可考虑把计划换成轻松活动、技术练习或活动度训练；若有不适，暂停训练并寻求专业建议。" : "Consider light activity, technique work, or mobility; pause training and seek professional advice if you feel unwell.",
                relatedMetrics: ["hrv", "recovery"],
                evidence: [
                    isChinese ? "HRV Z-Score \(String(format: "%.2f", hrvZScore))" : "HRV Z-score \(String(format: "%.2f", hrvZScore))",
                    isChinese ? "低于个人基线 1.5 个标准差" : "More than 1.5 SD below baseline"
                ],
                priority: 10,
                coachPresetQuestion: isChinese
                    ? "我的 HRV 显著降低了，今天该怎么调整训练和生活方式？"
                    : "My HRV is significantly low today. How should I adjust my training and lifestyle?"
            ))
        }
        
        // Rule 2: Poor sleep efficiency (sleep efficiency < 85%)
        if let sleepEfficiency = dashboard.sleepScore.metrics["sleep_efficiency"], sleepEfficiency < 85 {
            insights.append(ProactiveInsight(
                focus: .sleep,
                severity: .warning,
                title: isChinese ? "睡眠没有完全接住恢复" : "Sleep did not fully support recovery",
                body: isChinese
                    ? "昨晚睡眠效率偏低。今天可优先保持稳定节奏，避免基于这一项信号临时增加训练量。"
                    : "Sleep efficiency was low last night. Keep the day steady and avoid adding training volume based on this signal alone.",
                suggestedAction: isChinese ? "如符合你的习惯，可减少下午后的咖啡因，并在睡前预留一段低刺激放松时间。" : "If it fits your routine, reduce caffeine later in the day and leave some low-stimulation wind-down time before bed.",
                relatedMetrics: ["sleep"],
                evidence: [
                    isChinese ? "睡眠效率 \(String(format: "%.1f%%", sleepEfficiency))" : "Sleep efficiency \(String(format: "%.1f%%", sleepEfficiency))",
                    isChinese ? "睡眠连续性偏低" : "Sleep continuity was lower than usual"
                ],
                priority: 20,
                coachPresetQuestion: isChinese
                    ? "我昨晚睡眠效率很低，有什么具体建议改善睡眠连续性吗？"
                    : "My sleep efficiency was low last night. How can I improve my sleep continuity?"
            ))
        }
        
        // Rule 3: Gait asymmetry high (walkingAsymmetry > 4.0%)
        if let walkingAsymmetry = dashboard.extendedMetrics.walkingAsymmetry, walkingAsymmetry > 4.0 {
            insights.append(ProactiveInsight(
                focus: .movement,
                severity: .warning,
                title: isChinese ? "下肢动作先做保守处理" : "Treat lower-body movement conservatively",
                body: isChinese
                    ? "步行不对称性高于近期参考时，今天可把动作质量放在强度前面，并结合身体感受观察。"
                    : "When walking asymmetry is above its recent reference, prioritize movement quality over intensity today and consider how you feel.",
                suggestedAction: isChinese ? "热身加入单腿臀桥、髋踝活动和轻量单侧训练；今天避免冲刺。" : "Add single-leg bridges, hip/ankle mobility, and light unilateral work; avoid sprinting today.",
                relatedMetrics: ["walking_asymmetry"],
                evidence: [
                    isChinese ? "步行不对称性 \(String(format: "%.1f%%", walkingAsymmetry))" : "Walking asymmetry \(String(format: "%.1f%%", walkingAsymmetry))",
                    isChinese ? "高于当前参考阈值" : "Above the current reference threshold"
                ],
                priority: 30,
                coachPresetQuestion: isChinese
                    ? "我的步行不对称性偏高，今天训练应如何调整？"
                    : "My walking asymmetry is elevated. How should I adjust today's training?"
            ))
        }
        
        // Rule 4: Signals that can support following the existing plan. This is
        // never a standalone prescription to increase training intensity.
        let hrvZScore = dashboard.recovery.metrics["hrv_z_score"]
        let rhrZScore = dashboard.recovery.metrics["rhr_z_score"]
        let sleepScore = dashboard.sleepScore.score
        
        if let hrvZScore, let rhrZScore,
           hrvZScore > 0.5 && rhrZScore < -0.5 && sleepScore > 80 {
            insights.append(ProactiveInsight(
                focus: .training,
                severity: .info,
                title: isChinese ? "当前信号支持按计划训练" : "Current signals support the planned session",
                body: isChinese
                    ? "恢复、静息心率和睡眠信号支持既定计划。训练中仍以动作质量和主观用力调节。"
                    : "Recovery, resting heart rate, and sleep signals support the existing plan. Keep regulating with technique and perceived effort.",
                suggestedAction: isChinese ? "按既定训练计划执行；动作质量或主观用力变差时，不再加量。" : "Follow the existing plan; stop adding load if technique or perceived effort worsens.",
                relatedMetrics: ["recovery", "hrv", "sleep"],
                evidence: [
                    isChinese ? "睡眠分数 \(Int(sleepScore.rounded()))" : "Sleep score \(Int(sleepScore.rounded()))",
                    isChinese ? "HRV 与静息心率趋势良好" : "HRV and resting HR trend favorably"
                ],
                priority: 40,
                coachPresetQuestion: isChinese
                    ? "当前恢复信号支持按计划训练。怎样把今天的训练保持在可控范围内？"
                    : "Current recovery signals support my planned session. How can I keep today's training controlled?"
            ))
        }
        
        // Rule 5: Low Energy Bank Warning (Energy Bank < 30)
        let energyValue = dashboard.energy.currentEnergy
        if dashboard.energy.hasData && energyValue < 30 {
            insights.append(ProactiveInsight(
                focus: .energy,
                severity: .alert,
                title: isChinese ? "身体储备偏低，别硬扛" : "Energy reserve is low",
                body: isChinese
                    ? "当前能量储备偏低。这是一个综合估算值，适合结合饮食、睡眠、训练安排和主观疲劳再决定当天节奏。"
                    : "Your energy reserve is low. It is a composite estimate, so combine it with meals, sleep, training plans, and perceived fatigue before deciding today's pace.",
                suggestedAction: isChinese ? "可考虑降低计划负荷，保证正常进食、饮水和休息；不要依赖单一分数做激进调整。" : "Consider a lighter planned load, regular meals, fluids, and rest; avoid aggressive changes based on one score.",
                relatedMetrics: ["energy"],
                evidence: [
                    isChinese ? "能量 \(Int(energyValue.rounded()))/100" : "Energy \(Int(energyValue.rounded()))/100",
                    isChinese ? "综合储备估算偏低" : "Composite reserve estimate is low"
                ],
                priority: 12,
                coachPresetQuestion: isChinese
                    ? "我感觉身体特别累，能量银行只有 \(Int(energyValue))，今天应该做点什么来快速恢复？"
                    : "I feel exhausted, and my energy bank is at \(Int(energyValue)). What are the best ways to recharge quickly?"
            ))
        }

        if dashboard.strain.hasData,
           dashboard.recovery.hasData,
           dashboard.strain.score > 70,
           dashboard.recovery.score < 55 {
            insights.append(ProactiveInsight(
                focus: .training,
                severity: .alert,
                title: isChinese ? "负荷和恢复出现错配" : "Load and recovery are mismatched",
                body: isChinese
                    ? "训练负荷偏高，而恢复评分偏低。两个信号同时出现时，今天更适合重新核对既定计划和主观感受。"
                    : "Training load is high while the recovery score is low. When both signals appear, review the plan alongside your perceived readiness.",
                suggestedAction: isChinese ? "可保留熟悉的动作模式，并优先减少额外组数或接近力竭的安排。" : "Consider keeping familiar movement patterns while avoiding extra sets or near-failure work.",
                relatedMetrics: ["strain", "recovery"],
                evidence: [
                    isChinese ? "负荷 \(Int(dashboard.strain.score.rounded()))/100" : "Strain \(Int(dashboard.strain.score.rounded()))/100",
                    isChinese ? "恢复 \(Int(dashboard.recovery.score.rounded()))/100" : "Recovery \(Int(dashboard.recovery.score.rounded()))/100"
                ],
                priority: 8,
                coachPresetQuestion: isChinese
                    ? "我的训练负荷高但恢复不够，今天应该怎么安排训练？"
                    : "My strain is high but recovery is low. How should I plan today's training?"
            ))
        }

        if dashboard.stress.hasData, dashboard.stress.stressIndex > 70 {
            insights.append(ProactiveInsight(
                focus: .stress,
                severity: .warning,
                title: isChinese ? "先把压力降下来" : "Lower stress before adding load",
                body: isChinese
                    ? "压力指数偏高是基于可用信号的估算。可先确认自己是否适合训练，再决定当天是否保持原计划。"
                    : "The stress index is an estimate from available signals. Check whether you feel ready to train before deciding whether to keep the original plan.",
                suggestedAction: isChinese ? "训练前可安排几分钟安静呼吸或轻松热身；若感觉不适，选择休息或轻量活动。" : "Consider a few minutes of quiet breathing or an easy warm-up; choose rest or light activity if you feel unwell.",
                relatedMetrics: ["stress"],
                evidence: [
                    isChinese ? "压力 \(Int(dashboard.stress.stressIndex.rounded()))/100" : "Stress \(Int(dashboard.stress.stressIndex.rounded()))/100",
                    isChinese ? "需要结合主观压力感受确认" : "Confirm alongside perceived stress"
                ],
                priority: 24,
                coachPresetQuestion: isChinese
                    ? "我今天压力指数偏高，怎么安排训练和恢复更合适？"
                    : "My stress is elevated today. How should I adjust training and recovery?"
            ))
        }
        
        if insights.isEmpty {
            let hasReadinessData = dashboard.recovery.hasData || dashboard.sleepScore.hasData || dashboard.strain.hasData
            insights.append(ProactiveInsight(
                focus: hasReadinessData ? .readiness : .recovery,
                severity: .info,
                title: isChinese
                    ? (hasReadinessData ? "今天适合保持稳定节奏" : "等待更多健康数据")
                    : (hasReadinessData ? "Keep a steady rhythm today" : "Waiting for more health data"),
                body: isChinese
                    ? (hasReadinessData
                       ? "目前没有明显的恢复或训练风险信号。与其临时加码，更适合按计划执行，并观察训练后的身体反馈。"
                       : "Vela 还需要更多 Apple 健康数据来判断恢复、睡眠和训练负荷。同步完成后会生成更具体的建议。")
                    : (hasReadinessData
                       ? "No major recovery or training risk signal stands out. Execute the plan steadily and watch how your body responds after training."
                       : "Vela needs more Apple Health data to judge recovery, sleep, and training load. More specific guidance will appear after sync."),
                suggestedAction: isChinese
                    ? (hasReadinessData ? "按原计划训练；保留 1-2 组余力，不做临时加量。" : "完成健康数据授权和同步，先记录今天的睡眠、训练和主观感受。")
                    : (hasReadinessData ? "Follow the plan; keep 1-2 reps in reserve and avoid unplanned extra volume." : "Authorize and sync health data, then log sleep, training, and subjective feel."),
                relatedMetrics: hasReadinessData ? ["recovery", "sleep", "strain"] : ["recovery", "sleep"],
                evidence: hasReadinessData
                    ? [
                        isChinese ? "未发现高优先级风险" : "No high-priority risk detected",
                        isChinese ? "适合按计划执行" : "Plan execution is appropriate"
                    ]
                    : [
                        isChinese ? "健康数据不足" : "Insufficient health data",
                        isChinese ? "需要更多连续样本" : "More continuous samples needed"
                    ],
                priority: 60,
                coachPresetQuestion: isChinese
                    ? "我今天整体状态看起来比较稳定，训练上应该怎么安排更合理？"
                    : "My overall status looks stable today. How should I structure training?"
            ))
        }

        return Array(insights.sorted { $0.priority < $1.priority }.prefix(4))
    }
}

// MARK: - Proactive Intelligence Orchestrator

@MainActor
final class ProactiveIntelligenceOrchestrator: Sendable {
    private static let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "ProactiveIntelligence")

    init() {}

    /// Main entry point for asynchronous proactive check.
    /// Executed on app launch, scene active change, or background refresh task.
    @discardableResult
    func runAsyncCheck(modelContext: ModelContext, date: Date = Date()) async -> [ProactiveInsight] {
        Self.logger.info("Running proactive intelligence evaluation for \(date)...")
        
        do {
            // 1. Build current DashboardSummary
            let dashboard = (try? await DailySummaryUseCase().loadDashboard(for: date, modelContext: modelContext)) ?? DashboardSummary.empty(date: date)
            
            // 2. Evaluate Proactive Insights via ProactiveInsightService
            let evaluatedInsights = ProactiveInsightService.evaluate(dashboard: dashboard)
            
            // 3. Persist Insights into SwiftData
            let dayStart = Calendar.current.startOfDay(for: date)
            let existingRecords = (try? modelContext.fetch(FetchDescriptor<ProactiveInsightRecord>(
                predicate: #Predicate { $0.date >= dayStart }
            ))) ?? []
            
            for oldRecord in existingRecords {
                modelContext.delete(oldRecord)
            }
            
            for insight in evaluatedInsights {
                let record = ProactiveInsightRecord(
                    date: dayStart,
                    focusRaw: "\(insight.focus)",
                    severityRaw: "\(insight.severity)",
                    title: insight.title,
                    bodyText: insight.body,
                    suggestedAction: insight.suggestedAction,
                    priority: insight.priority,
                    coachPresetQuestion: insight.coachPresetQuestion,
                    createdAt: Date()
                )
                modelContext.insert(record)
            }
            
            try? modelContext.save()
            
            // 4. Log event in Event Service
            VelaEventService.shared.log(
                modelContext: modelContext,
                type: VelaProductEventType.proactiveInsightGenerated,
                title: "主动健康分析完成",
                detail: "生成 \(evaluatedInsights.count) 条今日策略洞察。"
            )
            
            // 5. Trigger Local Push Notification for High Severity Alert
            if let alertInsight = evaluatedInsights.first(where: { $0.severity == .alert }) {
                await scheduleLocalAlertNotification(insight: alertInsight)
            }
            
            Self.logger.info("Proactive intelligence check completed with \(evaluatedInsights.count) insights.")
            return evaluatedInsights
        } catch {
            Self.logger.error("Proactive intelligence check failed: \(error.localizedDescription)")
            return []
        }
    }

    private func scheduleLocalAlertNotification(insight: ProactiveInsight) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Vela Proactive: \(insight.title)"
        content.body = insight.body
        content.sound = .default
        
        let request = UNNotificationRequest(
            // Unique per alert: focus alone (~7 values) reused the same identifier,
            // so a new alert for the same focus silently replaced the previous one.
            identifier: "vela_alert_\(insight.focus)_\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        do {
            try await center.add(request)
        } catch {
            Self.logger.error("Failed to post local alert notification: \(error.localizedDescription)")
        }
    }
}

// MARK: - Autonomous Health Digital Twin (Epic-Grade Simulation Engine)

public struct SimulationScenarioInput: Sendable {
    public var plannedWorkoutStrain: Double  // e.g. 14.5
    public var plannedWorkoutHour: Double    // e.g. 20.0 (20:00)
    public var targetSleepDurationHours: Double // e.g. 7.5
    public var caffeineCutoffHour: Double    // e.g. 14.0

    public init(
        plannedWorkoutStrain: Double = 12.0,
        plannedWorkoutHour: Double = 18.0,
        targetSleepDurationHours: Double = 8.0,
        caffeineCutoffHour: Double = 14.0
    ) {
        self.plannedWorkoutStrain = plannedWorkoutStrain
        self.plannedWorkoutHour = plannedWorkoutHour
        self.targetSleepDurationHours = targetSleepDurationHours
        self.caffeineCutoffHour = caffeineCutoffHour
    }
}

public struct DigitalTwinSimulationResult: Sendable, Equatable {
    public var predictedNextDayRecovery: Double  // 0..100
    public var predictedEnergyScore: Double     // 0..100
    public var sleepQualityMultiplier: Double   // e.g. 0.92
    public var recommendation: String
    public var scenarioTag: String             // "optimal", "strained", "suboptimal_timing"

    public init(
        predictedNextDayRecovery: Double,
        predictedEnergyScore: Double,
        sleepQualityMultiplier: Double,
        recommendation: String,
        scenarioTag: String
    ) {
        self.predictedNextDayRecovery = predictedNextDayRecovery
        self.predictedEnergyScore = predictedEnergyScore
        self.sleepQualityMultiplier = sleepQualityMultiplier
        self.recommendation = recommendation
        self.scenarioTag = scenarioTag
    }
}

@MainActor
public struct AutonomousHealthDigitalTwin: Sendable {
    public init() {}

    /// Simulates the user's biological recovery & energy response 24 hours ahead
    /// given current body state and a hypothetical workout/sleep scenario.
    func simulateNextDay(
        dashboard: DashboardSummary,
        scenario: SimulationScenarioInput
    ) -> DigitalTwinSimulationResult {
        let baseRecovery = dashboard.recovery.hasData ? dashboard.recovery.score : 70.0

        var sleepMultiplier = 1.0
        if scenario.plannedWorkoutHour >= 20.5 && scenario.plannedWorkoutStrain > 10.0 {
            sleepMultiplier *= 0.85
        }

        if scenario.targetSleepDurationHours < 7.0 {
            sleepMultiplier *= 0.88
        } else if scenario.targetSleepDurationHours >= 8.0 {
            sleepMultiplier *= 1.05
        }

        let strainCost = scenario.plannedWorkoutStrain * 1.8
        let recoveryGain = 45.0 * sleepMultiplier
        let predictedRecovery = ScoringMath.clamp(baseRecovery * 0.4 + recoveryGain - strainCost + 30.0, min: 10.0, max: 99.0)

        let predictedEnergy = ScoringMath.clamp(predictedRecovery * 0.85 + (scenario.targetSleepDurationHours / 8.0) * 15.0, min: 15.0, max: 100.0)

        let tag: String
        let rec: String

        if sleepMultiplier < 0.9 {
            tag = "suboptimal_timing"
            rec = "晚间高强度训练可能干扰自主神经平息，建议将训练提早至 19:00 前完成或降低容量。"
        } else if predictedRecovery >= 75.0 {
            tag = "optimal"
            rec = "该模拟组合支持次日恢复维持在绿区，建议按此计划执行。"
        } else {
            tag = "strained"
            rec = "预测次日恢复呈中度偏低，建议增加 30 分钟睡眠或降低 15% 训练容量。"
        }

        return DigitalTwinSimulationResult(
            predictedNextDayRecovery: predictedRecovery,
            predictedEnergyScore: predictedEnergy,
            sleepQualityMultiplier: sleepMultiplier,
            recommendation: rec,
            scenarioTag: tag
        )
    }
}

