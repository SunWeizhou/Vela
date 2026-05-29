import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english
    case simplifiedChinese

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "简体中文"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .english:
            return "en"
        case .simplifiedChinese:
            return "zh-Hans"
        }
    }

    var isChinese: Bool {
        self == .simplifiedChinese
    }

    static var stored: AppLanguage {
        get {
            AppLanguage(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .simplifiedChinese
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    private static let storageKey = "vela_app_language"
}

enum L10n {
    static func t(_ english: String, _ chinese: String) -> String {
        AppLanguage.stored.isChinese ? chinese : english
    }
}

func localizedBand(_ band: ScoreBand) -> String {
    guard AppLanguage.stored.isChinese else { return band.rawValue }
    switch band {
    case .low: return "偏低"
    case .moderate: return "中等"
    case .high: return "较高"
    }
}

func localizedConfidence(_ confidence: ScoreConfidence) -> String {
    guard AppLanguage.stored.isChinese else { return confidence.rawValue }
    switch confidence {
    case .high: return "高"
    case .medium: return "中"
    case .low: return "低"
    }
}

func localizedTarget(_ status: StrainTargetStatus) -> String {
    guard AppLanguage.stored.isChinese else { return status.rawValue }
    switch status {
    case .belowTarget: return "低于目标"
    case .withinTarget: return "目标范围内"
    case .aboveTarget: return "高于目标"
    }
}

func localizedStressBand(_ band: StressBand) -> String {
    guard AppLanguage.stored.isChinese else { return band.rawValue }
    switch band {
    case .calm: return "平稳"
    case .normal: return "正常"
    case .elevated: return "升高"
    case .high: return "偏高"
    }
}

func localizedEnergy(_ status: EnergyBankStatus) -> String {
    guard AppLanguage.stored.isChinese else { return status.rawValue }
    switch status {
    case .depleted: return "耗尽"
    case .low: return "偏低"
    case .stable: return "稳定"
    case .strong: return "充足"
    }
}

func localizedHealthAge(_ label: HealthAgeTrendLabel) -> String {
    guard AppLanguage.stored.isChinese else { return label.rawValue }
    switch label {
    case .improving: return "改善"
    case .stable: return "稳定"
    case .worsening: return "变差"
    }
}

func localizedReportTitle(_ type: AIReportType) -> String {
    guard AppLanguage.stored.isChinese else { return type.title }
    switch type {
    case .morningBrief: return "晨间简报"
    case .sleepReview: return "睡眠复盘"
    case .workoutReadiness: return "训练准备度"
    case .weeklyReview: return "周复盘"
    case .coachPrompt: return "教练回应"
    }
}

func localizedReason(_ reason: String) -> String {
    guard AppLanguage.stored.isChinese else { return reason }
    if reason.contains("HRV significantly below personal baseline") {
        if let range = reason.range(of: #"z=-?\d+(\.\d+)?"#, options: .regularExpression) {
            return "HRV 显著低于个人基线（\(reason[range])）"
        }
        return "HRV 显著低于个人基线"
    }
    if reason.contains("HRV slightly below baseline") { return "HRV 略低于基线" }
    if reason.contains("HRV above baseline") { return "HRV 高于基线，自主神经恢复良好" }
    if reason.contains("HRV within normal range") { return "HRV 处于正常范围" }
    if reason.contains("Resting heart rate elevated") {
        let bpm = reason.components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty }
        return bpm.map { "静息心率比基线高 \($0)bpm" } ?? "静息心率高于基线"
    }
    if reason.contains("Resting heart rate slightly above baseline") { return "静息心率略高于基线" }
    if reason.contains("Resting heart rate below baseline") { return "静息心率低于基线，是积极信号" }
    if reason.contains("HRV was below") { return "HRV 低于 28 天基线" }
    if reason.contains("HRV was at or above") { return "HRV 达到或高于 28 天基线" }
    if reason.contains("HRV data unavailable") { return "HRV 数据不可用，恢复评分会使用其余指标。" }
    if reason.contains("Resting heart rate was above") { return "静息心率高于基线" }
    if reason.contains("Resting heart rate was close") { return "静息心率接近基线" }
    if reason.contains("Resting heart rate data unavailable") { return "静息心率数据不可用。" }
    if reason.contains("Sleep score contributed") { return "睡眠评分已纳入恢复计算" }
    if reason.contains("Sleep score unavailable") { return "睡眠评分不可用。" }
    if reason.contains("Prior strain unavailable") { return "前一日负荷不可用。" }
    if reason.contains("Sleep duration") && reason.contains("below target by") {
        return reason
            .replacingOccurrences(of: "Sleep duration", with: "睡眠时长")
            .replacingOccurrences(of: " — below target by ", with: "，低于目标 ")
    }
    if reason.contains("Sleep duration") && reason.contains("within target range") {
        return reason
            .replacingOccurrences(of: "Sleep duration", with: "睡眠时长")
            .replacingOccurrences(of: " — within target range", with: "，位于目标范围内")
    }
    if reason.contains("Sleep duration") && reason.contains("above target") {
        return reason
            .replacingOccurrences(of: "Sleep duration", with: "睡眠时长")
            .replacingOccurrences(of: " — above target", with: "，高于目标")
    }
    if reason.contains("Sleep duration reached") { return reason.replacingOccurrences(of: "Sleep duration reached", with: "睡眠时长达到").replacingOccurrences(of: "of target", with: "目标") }
    if reason.contains("Sleep timing baseline unavailable") { return "睡眠时间基线不可用，暂未评分规律性。" }
    if reason.contains("Today's active energy") { return reason.replacingOccurrences(of: "Today's active energy was", with: "今日活动能量为").replacingOccurrences(of: "of baseline", with: "基线") }
    if reason.contains("Exercise duration was included") { return "锻炼时长已纳入负荷计算" }
    if reason.contains("Workout intensity contributed") { return "训练强度已纳入今日负荷" }
    if reason.contains("Active energy baseline unavailable") { return "活动能量基线不可用。" }
    if reason.contains("Exercise baseline unavailable") { return "锻炼基线不可用。" }
    if reason.contains("No workout intensity data available") { return "暂无训练强度数据。" }
    if reason.contains("Stress proxy data unavailable") { return "压力代理数据不可用。" }
    if reason.contains("Heart rate elevation proxy") { return "已纳入心率升高代理指标" }
    if reason.contains("HRV suppression proxy") { return "已纳入 HRV 抑制代理指标" }
    if reason.contains("Sleep debt context") { return "已纳入睡眠债背景" }
    if reason.contains("Recent strain context") { return "已纳入近期负荷背景" }
    if reason.contains("Morning energy") { return "早晨能量基于恢复和睡眠估算。" }
    if reason.contains("Current energy subtracts") { return "当前能量会扣除负荷和压力代理消耗。" }
    if reason.contains("Health Age Trend") { return "健康年龄趋势是 beta 代理趋势，不代表真实生物年龄。" }
    return reason
}

func localizedMetricName(_ name: String) -> String {
    guard AppLanguage.stored.isChinese else { return name }
    let normalized = name
        .replacingOccurrences(of: "_", with: " ")
        .lowercased()
    switch normalized {
    case "vo2 max": return "最大摄氧量"
    case "resting heart rate", "rhr": return "静息心率"
    case "sleep regularity": return "睡眠规律性"
    case "sleep duration": return "睡眠时长"
    case "activity consistency": return "活动一致性"
    case "recovery trend": return "恢复趋势"
    case "heart rate elevation": return "心率升高"
    case "hrv suppression": return "HRV 抑制"
    case "sleep debt": return "睡眠债"
    case "recent strain": return "近期负荷"
    default:
        return name.replacingOccurrences(of: "_", with: " ")
    }
}
