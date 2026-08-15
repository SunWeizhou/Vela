import SwiftUI
import SwiftData

struct AppCoordinator: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_dark_mode") private var darkModeRaw = "system"
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @StateObject private var services: VelaServices
    @StateObject private var appState = VelaAppState.shared
    @StateObject private var dashboardVM: DashboardViewModel
    private let forceOnboarding: Bool

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let localServices = VelaServices()
        _services = StateObject(wrappedValue: localServices)
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(useCase: localServices.dailySummaryUseCase, services: localServices))
        forceOnboarding = Self.shouldForceOnboarding(arguments: arguments)
    }

    var body: some View {
        ZStack {
            if onboardingCompleted && !forceOnboarding {
                VelaRootView()
                    .environmentObject(dashboardVM)
                    .environmentObject(services)
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
                    .id(language.rawValue)
            } else {
                VelaOnboardingView()
                    .environmentObject(dashboardVM)
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
            }

            if appState.isFallbackStore || appState.isReadOnlySafetyMode {
                VStack {
                    storeWarningBanner
                    Spacer()
                }
                .transition(warningTransition)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .animation(
            VelaTheme.interfaceAnimation(reduceMotion: reduceMotion),
            value: appState.isFallbackStore || appState.isReadOnlySafetyMode
        )
        .task {
            UserProfileSettings.migrateLegacyHydratedValuesIfNeeded()
            // 已有用户一次性迁移：把建档资料写进 wiki（此前只存 SwiftData）。
            WikiProfileMaterializer.materializeIfNeeded(modelContext: modelContext)
            BackgroundTaskManager.schedule()
            // 健康数据后台更新时重排刷新（晨间睡眠段到达即可生成晨报）。
            HealthKitBackgroundDelivery.registerObservers()
            guard !appState.isReadOnlySafetyMode else { return }
            try? await Task.sleep(for: .seconds(2))
            _ = try? RetentionPolicyService().prune(modelContext: modelContext)
        }
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .simplifiedChinese
    }

    private var preferredColorScheme: ColorScheme? {
        switch darkModeRaw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private var storeWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VelaTheme.energyColor)
            Text(appState.isReadOnlySafetyMode
                 ? (language.isChinese
                    ? "数据库无法打开，原文件已备份并进入只读安全模式。"
                    : "The database could not be opened. Original files were backed up and read-only safety mode is active.")
                 : (language.isChinese
                    ? "存储不可用，数据不会跨启动保存。"
                    : "Storage unavailable. Data won't persist across launches."))
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.fg)
            Spacer()
            if appState.isReadOnlySafetyMode {
                Button(language.isChinese ? "恢复/导出" : "Recover/Export") {
                    appState.routeToMe()
                }
                .font(.caption.weight(.bold))
            } else {
                Button {
                    withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                        appState.isFallbackStore = false
                        appState.isReadOnlySafetyMode = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VelaTheme.fg2)
                }
                .buttonStyle(.cardPress)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VelaTheme.elevatedBg)
    }

    private var warningTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    nonisolated static func shouldForceOnboarding(arguments: [String]) -> Bool {
        #if DEBUG
        arguments.contains("-velaForceOnboarding")
        #else
        false
        #endif
    }
}
