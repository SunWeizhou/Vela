import Foundation

enum VelaError: Error, LocalizedError, Identifiable {
    var id: String { "\(code)-\(localizedDescription)" }

    // MARK: - HealthKit
    case healthKitUnauthorized
    case healthKitQueryFailed(sampleType: String, underlying: Error? = nil)
    case healthKitDataUnavailable(sampleType: String)

    // MARK: - Network / AI
    case aiServiceError(statusCode: Int, message: String)
    case networkUnavailable(underlying: Error? = nil)
    case aiResponseEmpty

    // MARK: - Persistence
    case persistenceFailed(operation: String, underlying: Error? = nil)
    case wikiFileError(path: String, underlying: Error? = nil)

    // MARK: - General
    case unknown(underlying: Error? = nil)

    var code: Int {
        switch self {
        case .healthKitUnauthorized: return 1001
        case .healthKitQueryFailed: return 1002
        case .healthKitDataUnavailable: return 1003
        case .aiServiceError: return 2001
        case .networkUnavailable: return 2002
        case .aiResponseEmpty: return 2003
        case .persistenceFailed: return 3001
        case .wikiFileError: return 3002
        case .unknown: return 9999
        }
    }

    var errorDescription: String? {
        let isChinese = AppLanguage.stored.isChinese
        switch self {
        case .healthKitUnauthorized:
            return isChinese ? "健康数据未授权" : "Health Data Not Authorized"
        case .healthKitQueryFailed(let type, _):
            return isChinese ? "无法读取\(type)数据" : "Failed to read \(type) data"
        case .healthKitDataUnavailable(let type):
            return isChinese ? "\(type)数据不可用" : "\(type) data unavailable"
        case .aiServiceError(let code, _):
            return isChinese ? "AI 服务错误 (\(code))" : "AI Service Error (\(code))"
        case .networkUnavailable:
            return isChinese ? "网络连接失败" : "Network Unavailable"
        case .aiResponseEmpty:
            return isChinese ? "AI 未返回内容" : "AI returned empty response"
        case .persistenceFailed(let op, _):
            return isChinese ? "数据\(op)失败" : "Data \(op) failed"
        case .wikiFileError:
            return isChinese ? "Wiki 文件错误" : "Wiki file error"
        case .unknown:
            return isChinese ? "未知错误" : "Unknown error"
        }
    }

    var recoverySuggestion: String? {
        let isChinese = AppLanguage.stored.isChinese
        switch self {
        case .healthKitUnauthorized:
            return isChinese
                ? "请在系统设置中授权 Apple 健康数据访问"
                : "Please authorize Apple Health access in System Settings"
        case .healthKitQueryFailed:
            return isChinese
                ? "请确保 Apple Watch 已配对并正在同步数据"
                : "Make sure your Apple Watch is paired and syncing data"
        case .healthKitDataUnavailable:
            return isChinese
                ? "佩戴 Apple Watch 睡觉或运动后数据将自动出现"
                : "Data will appear after wearing your Apple Watch to sleep or exercise"
        case .aiServiceError:
            return isChinese
                ? "请稍后重试或在设置中检查 API Key"
                : "Please try again later or check your API key in Settings"
        case .networkUnavailable:
            return isChinese
                ? "请检查网络连接后重试"
                : "Please check your internet connection and try again"
        case .aiResponseEmpty:
            return isChinese
                ? "请重试或简化你的问题"
                : "Please try again or simplify your question"
        case .persistenceFailed:
            return isChinese
                ? "请重启 App 后重试"
                : "Please restart the app and try again"
        case .wikiFileError:
            return nil
        case .unknown:
            return isChinese
                ? "请重启 App 后重试"
                : "Please restart the app and try again"
        }
    }
}
