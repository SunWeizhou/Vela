import Foundation
import SwiftUI

struct ProactiveInsight: Identifiable, Hashable {
    let id = UUID()
    var severity: Severity
    var title: String
    var body: String
    var suggestedAction: String?
    var relatedMetrics: [String]
    var coachPresetQuestion: String // Tapping the card pre-fills this question
    
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
                severity: .alert,
                title: isChinese ? "⚠️ HRV 显著偏低" : "⚠️ HRV Significantly Low",
                body: isChinese
                    ? "你的 HRV Z-Score 为 \(String(format: "%.2f", hrvZScore))，处于个人基线以下 1.5 个标准差。交感神经过度兴奋，系统压力偏高。"
                    : "Your HRV Z-Score is \(String(format: "%.2f", hrvZScore)), falling below 1.5 SD of baseline. This indicates elevated autonomic strain.",
                suggestedAction: isChinese ? "轻度拉伸 + 深呼吸 15 分钟" : "15 mins of light stretching & deep breathing",
                relatedMetrics: ["hrv", "recovery"],
                coachPresetQuestion: isChinese
                    ? "我的 HRV 显著降低了，今天该怎么调整训练和生活方式？"
                    : "My HRV is significantly low today. How should I adjust my training and lifestyle?"
            ))
        }
        
        // Rule 2: Poor sleep efficiency (sleep efficiency < 85%)
        if let sleepEfficiency = dashboard.sleepScore.metrics["sleep_efficiency"], sleepEfficiency < 85 {
            insights.append(ProactiveInsight(
                severity: .warning,
                title: isChinese ? "🛌 睡眠效率欠佳" : "🛌 Poor Sleep Efficiency",
                body: isChinese
                    ? "昨晚睡眠效率仅为 \(String(format: "%.1f%%", sleepEfficiency))。微觉醒或醒来时间较多，这会压迫认知和体力恢复。"
                    : "Sleep efficiency last night was only \(String(format: "%.1f%%", sleepEfficiency)). Multiple micro-awakenings are limiting recovery.",
                suggestedAction: isChinese ? "晚上避免午后咖啡因 + 睡前热水浴" : "Limit late caffeine & try a warm bath before bed",
                relatedMetrics: ["sleep"],
                coachPresetQuestion: isChinese
                    ? "我昨晚睡眠效率很低，有什么具体建议改善睡眠连续性吗？"
                    : "My sleep efficiency was low last night. How can I improve my sleep continuity?"
            ))
        }
        
        // Rule 3: Gait asymmetry high (walkingAsymmetry > 4.0%)
        if let walkingAsymmetry = dashboard.extendedMetrics.walkingAsymmetry, walkingAsymmetry > 4.0 {
            insights.append(ProactiveInsight(
                severity: .warning,
                title: isChinese ? "⚖️ 步行不对称性高" : "⚖️ High Walking Asymmetry",
                body: isChinese
                    ? "步行不对称性达 \(String(format: "%.1f%%", walkingAsymmetry))，高于 2% 的正常水平。这可能意味着下肢关节或肌肉代偿风险。"
                    : "Walking asymmetry reached \(String(format: "%.1f%%", walkingAsymmetry)), exceeding the normal 2% limit. This may indicate biomechanical compensation.",
                suggestedAction: isChinese ? "进行单侧肌肉激活与拉伸" : "Focus on unilateral mobility and stretching",
                relatedMetrics: ["walking_asymmetry"],
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
                severity: .info,
                title: isChinese ? "🚀 极佳训练窗口期" : "🚀 Prime Training Window",
                body: isChinese
                    ? "副交感神经充能充分，静息心率偏低，且睡眠极佳！你的身体已做好高强度训练的充分准备。"
                    : "Autonomic system is fully recharged, resting HR is low, and sleep was excellent! Your body is ready for high intensity.",
                suggestedAction: isChinese ? "今日可尝试推进你的核心训练目标" : "Perfect day to push for your core training goals",
                relatedMetrics: ["recovery", "hrv", "sleep"],
                coachPresetQuestion: isChinese
                    ? "我今天的恢复状态非常棒！可以安排哪些挑战性的训练？"
                    : "My recovery is outstanding today! What kind of high-intensity training do you recommend?"
            ))
        }
        
        // Rule 5: Low Energy Bank Warning (Energy Bank < 30)
        let energyValue = dashboard.energy.currentEnergy
        if dashboard.energy.hasData && energyValue < 30 {
            insights.append(ProactiveInsight(
                severity: .alert,
                title: isChinese ? "🪫 能量储备不足" : "🪫 Low Energy Bank",
                body: isChinese
                    ? "你的能量银行估算值已降至 \(Int(energyValue))。近期高负荷或睡眠赤字正在快速消耗你的生理储备。"
                    : "Your energy bank has drained to \(Int(energyValue)). High load or sleep debt is depleting your somatic reserve.",
                suggestedAction: isChinese ? "今日建议减载，并进行冥想和早睡" : "Recommend scaling back load, meditating, and early sleep",
                relatedMetrics: ["energy"],
                coachPresetQuestion: isChinese
                    ? "我感觉身体特别累，能量银行只有 \(Int(energyValue))，今天应该做点什么来快速恢复？"
                    : "I feel exhausted, and my energy bank is at \(Int(energyValue)). What are the best ways to recharge quickly?"
            ))
        }
        
        return insights
    }
}
