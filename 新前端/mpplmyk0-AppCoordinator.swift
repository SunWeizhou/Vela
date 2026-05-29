import SwiftUI

struct AppCoordinator: View {
    @AppStorage("vela_app_language") private var languageRaw = AppLanguage.simplifiedChinese.rawValue
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var appState = VelaAppState.shared
    @StateObject private var services = VelaServices()

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

            if appState.isFallbackStore {
                VStack {
                    storeWarningBanner
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.3), value: appState.isFallbackStore)
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
            Text(language.isChinese
                 ? "存储不可用，数据不会跨启动保存。"
                 : "Storage unavailable. Data won't persist across launches.")
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.primaryText)
            Spacer()
            Button {
                withAnimation { appState.isFallbackStore = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(VelaTheme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VelaTheme.elevatedSurface)
    }
}
