import Foundation
import SwiftUI

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
            case .recovery: return VelaTheme.recovery
            case .sleep: return Color(hex: "#5C6BC0")
            case .training: return Color(hex: "#FF8A3D")
            case .energy: return VelaTheme.energy
            case .movement: return Color(hex: "#34C759")
            case .stress: return VelaTheme.stress
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
            case .info: return VelaTheme.recovery
            case .warning: return VelaTheme.energy
            case .alert: return VelaTheme.stress
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
                    ? "HRV 明显低于你的个人基线，身体更像处在高压力输出状态。今天硬顶强度，收益会比风险低。"
                    : "HRV is well below your personal baseline, suggesting elevated physiological strain. Pushing hard today has a poor risk-to-reward ratio.",
                suggestedAction: isChinese ? "把训练改为低强度有氧、技术练习或拉伸；睡前做 10 分钟慢呼吸。" : "Switch to low-intensity cardio, technique work, or mobility; add 10 minutes of slow breathing before bed.",
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
                    ? "昨晚睡眠效率偏低，说明在床时间没有充分转化为有效恢复。今天更适合稳定节奏，而不是临时加量。"
                    : "Sleep efficiency was low, so time in bed did not fully convert into recovery. Keep the day steady instead of adding load.",
                suggestedAction: isChinese ? "下午后不碰咖啡因；晚间提前 30 分钟降光、热水浴或拉伸。" : "Avoid caffeine after midday; dim lights 30 minutes earlier and use a warm bath or light stretching.",
                relatedMetrics: ["sleep"],
                evidence: [
                    isChinese ? "睡眠效率 \(String(format: "%.1f%%", sleepEfficiency))" : "Sleep efficiency \(String(format: "%.1f%%", sleepEfficiency))",
                    isChinese ? "连续性不足会影响恢复质量" : "Fragmented sleep can reduce recovery quality"
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
                    ? "步行不对称性升高时，深蹲、跑步和跳跃类训练更容易放大代偿。先把动作质量放在强度前面。"
                    : "Elevated walking asymmetry can amplify compensation during squats, running, and jumping. Prioritize movement quality before intensity.",
                suggestedAction: isChinese ? "热身加入单腿臀桥、髋踝活动和轻量单侧训练；今天避免冲刺。" : "Add single-leg bridges, hip/ankle mobility, and light unilateral work; avoid sprinting today.",
                relatedMetrics: ["walking_asymmetry"],
                evidence: [
                    isChinese ? "步行不对称性 \(String(format: "%.1f%%", walkingAsymmetry))" : "Walking asymmetry \(String(format: "%.1f%%", walkingAsymmetry))",
                    isChinese ? "高于常见健康范围" : "Above the common healthy range"
                ],
                priority: 30,
                coachPresetQuestion: isChinese
                    ? "我的步行不对称性偏高，这跟运动损伤有关系吗？该怎么做拉伸？"
                    : "My walking asymmetry is high. Is it related to potential injuries, and how should I stretch?"
            ))
        }
        
        // Rule 4: High Recovery Window (HRV Z-Score > 0.5 & RHR Z-Score < -0.5 & Sleep Score > 80)
        let hrvZScore = dashboard.recovery.metrics["hrv_z_score"] ?? 0.0
        let rhrZScore = dashboard.recovery.metrics["rhr_z_score"] ?? 0.0
        let sleepScore = dashboard.sleepScore.score
        
        if hrvZScore > 0.5 && rhrZScore < -0.5 && sleepScore > 80 {
            insights.append(ProactiveInsight(
                focus: .training,
                severity: .info,
                title: isChinese ? "今天可以推进核心训练目标" : "Today is a good window to push",
                body: isChinese
                    ? "恢复、静息心率和睡眠共同指向较好的准备度。今天适合把最重要的训练放在前半程完成。"
                    : "Recovery, resting heart rate, and sleep point to strong readiness. Put your most important training work early in the session.",
                suggestedAction: isChinese ? "优先安排主项或渐进超负荷；结束后保留 10 分钟冷身恢复。" : "Prioritize your main lift or progressive overload; keep 10 minutes for cooldown recovery.",
                relatedMetrics: ["recovery", "hrv", "sleep"],
                evidence: [
                    isChinese ? "睡眠分数 \(Int(sleepScore.rounded()))" : "Sleep score \(Int(sleepScore.rounded()))",
                    isChinese ? "HRV 与静息心率趋势良好" : "HRV and resting HR trend favorably"
                ],
                priority: 40,
                coachPresetQuestion: isChinese
                    ? "我今天的恢复状态非常棒！可以安排哪些挑战性的训练？"
                    : "My recovery is outstanding today! What kind of high-intensity training do you recommend?"
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
                    ? "当前能量储备已经偏低，说明近期负荷、睡眠或压力可能正在透支恢复能力。今天的目标应该是回补。"
                    : "Your current energy reserve is low, suggesting recent load, sleep, or stress is drawing down recovery capacity. Today should focus on replenishment.",
                suggestedAction: isChinese ? "训练量减少 30-40%；补足碳水和水分，晚上优先早睡。" : "Reduce training volume by 30-40%; refill carbs and fluids, then prioritize an earlier bedtime.",
                relatedMetrics: ["energy"],
                evidence: [
                    isChinese ? "能量 \(Int(energyValue.rounded()))/100" : "Energy \(Int(energyValue.rounded()))/100",
                    isChinese ? "恢复储备不足" : "Low recovery reserve"
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
                    ? "训练负荷偏高，但恢复分数没有跟上。继续加量可能让后续几天的训练质量下降。"
                    : "Training load is high while recovery has not caught up. Adding more volume may reduce training quality over the next few days.",
                suggestedAction: isChinese ? "今天保留动作模式，减少组数和接近力竭的训练。" : "Keep movement patterns, but reduce sets and avoid near-failure work today.",
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
                    ? "压力指数偏高时，身体更难进入恢复模式。训练前先做短时间降压，会让后面的输出更稳定。"
                    : "When stress is elevated, the body has a harder time shifting into recovery. Downshifting before training can stabilize output.",
                suggestedAction: isChinese ? "训练前 5 分钟鼻吸慢呼；今天少做高刺激收尾。" : "Do 5 minutes of slow nasal breathing before training; skip high-stimulation finishers today.",
                relatedMetrics: ["stress"],
                evidence: [
                    isChinese ? "压力 \(Int(dashboard.stress.stressIndex.rounded()))/100" : "Stress \(Int(dashboard.stress.stressIndex.rounded()))/100",
                    isChinese ? "恢复切换可能受影响" : "Recovery switching may be impaired"
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
