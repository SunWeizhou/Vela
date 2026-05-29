import SwiftUI

struct VelaRootView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor(VelaTheme.surface).withAlphaComponent(0.92)
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(VelaTheme.mutedText)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(VelaTheme.accent)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(VelaTheme.mutedText)]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(VelaTheme.accent)]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @ObservedObject private var appState = VelaAppState.shared

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .tabItem {
                    Label(L10n.t("Home", "首页"), systemImage: "house.fill")
                }
                .tag(0)

            SleepView()
                .tabItem {
                    Label(L10n.t("Sleep", "睡眠"), systemImage: "moon.fill")
                }
                .tag(1)

            StrainView()
                .tabItem {
                    Label(L10n.t("Strain", "负荷"), systemImage: "flame.fill")
                }
                .tag(2)

            RecoveryView()
                .tabItem {
                    Label(L10n.t("Recovery", "恢复"), systemImage: "heart.fill")
                }
                .tag(3)

            CoachView()
                .tabItem {
                    Label(L10n.t("Coach", "教练"), systemImage: "sparkles")
                }
                .tag(4)

            SettingsView()
                .tabItem {
                    Label(L10n.t("Settings", "设置"), systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .tint(VelaTheme.accent)
    }
}
