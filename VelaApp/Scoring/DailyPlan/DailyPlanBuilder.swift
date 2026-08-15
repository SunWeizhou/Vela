import Foundation

// MARK: - Daily State

enum DailyState: String, Codable, Hashable, CaseIterable {
    case great
    case good
    case fair
    case poor
    case unknown

    var label: String {
        switch self {
        case .great: return AppLanguage.stored.isChinese ? "状态极佳" : "Great"
        case .good: return AppLanguage.stored.isChinese ? "状态良好" : "Good"
        case .fair: return AppLanguage.stored.isChinese ? "一般" : "Fair"
        case .poor: return AppLanguage.stored.isChinese ? "需要休息" : "Need Rest"
        case .unknown: return AppLanguage.stored.isChinese ? "数据不足" : "Not Enough Data"
        }
    }

    var emoji: String {
        switch self {
        case .great: return "⚡️"
        case .good: return "👍"
        case .fair: return "🤔"
        case .poor: return "🛟"
        case .unknown: return "📡"
        }
    }

    var color: String {
        switch self {
        case .great: return "energy"
        case .good: return "accent"
        case .fair: return "strain"
        case .poor: return "recovery"
        case .unknown: return "muted"
        }
    }
}

// MARK: - Action Type

enum DailyActionType: String, Codable, Hashable, CaseIterable {
    case train
    case rest
    case activeRecovery
    case nutritionTip
    case sleepTip
    case hydrationTip
    case mobilityTip
    case stressTip
    case dailySummary
    case trainingPlanStep
}

