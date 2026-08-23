import Foundation
import Sentry

/// 崩溃上报（审计 H4）——可选启用：DSN 存 Keychain（account: "sentry_dsn"），
/// 未配置时完全 no-op（不上传任何数据）；用户显式配置后才发送崩溃与诊断。
/// 隐私边界：原始健康采样永不出设备；Sentry 仅接收技术诊断（崩溃栈/系统信息）；
/// breadcrumb 关闭、PII 关闭、tracing 采样率 0。
enum SentryService {
    static let dsnAccount = "sentry_dsn"

    @MainActor
    static func configureOnLaunch(keychain: KeychainService = .shared) {
        guard let dsn = try? keychain.read(account: dsnAccount), !dsn.isEmpty else {
            return
        }
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAutoBreadcrumbTracking = false
            options.sendDefaultPii = false
            options.tracesSampleRate = 0
        }
    }

    @MainActor
    static var isConfigured: Bool {
        guard let dsn = try? KeychainService.shared.read(account: dsnAccount) else { return false }
        return !dsn.isEmpty
    }
}
