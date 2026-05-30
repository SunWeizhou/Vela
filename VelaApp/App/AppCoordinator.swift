import SwiftUI

struct AppCoordinator: View {
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @StateObject private var services: VelaServices
    @StateObject private var appState = VelaAppState.shared
    @StateObject private var dashboardVM: DashboardViewModel

    init() {
        let localServices = VelaServices()
        _services = StateObject(wrappedValue: localServices)
        _dashboardVM = StateObject(wrappedValue: DashboardViewModel(useCase: localServices.dailySummaryUseCase, services: localServices))
    }

    var body: some View {
        ZStack {
            if onboardingCompleted {
                VelaRootView()
                    .environmentObject(dashboardVM)
                    .environmentObject(services)
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
                    .id(language.rawValue)
            } else {
                VelaOnboardingView()
                    .environment(\.locale, Locale(identifier: language.localeIdentifier))
            }

            if appState.isFallbackStore || appState.isReadOnlySafetyMode {
                VStack {
                    storeWarningBanner
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isFallbackStore || appState.isReadOnlySafetyMode)
        .task {
            BackgroundTaskManager.schedule()
        }
    }

    private var language: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .simplifiedChinese
    }

    private var storeWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VelaTheme.energy)
            Text(appState.isReadOnlySafetyMode
                 ? (language.isChinese
                    ? "数据库严重损坏！已进入只读安全模式，数据无法保存。"
                    : "Database corrupted! Safe Read-Only Mode active. Changes won't save.")
                 : (language.isChinese
                    ? "存储不可用，数据不会跨启动保存。"
                    : "Storage unavailable. Data won't persist across launches."))
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.primaryText)
            Spacer()
            if !appState.isReadOnlySafetyMode {
                Button {
                    withAnimation {
                        appState.isFallbackStore = false
                        appState.isReadOnlySafetyMode = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VelaTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VelaTheme.elevatedSurface)
    }
}
