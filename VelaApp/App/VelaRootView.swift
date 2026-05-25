import SwiftUI
import UIKit

struct VelaRootView: View {
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundColor = VelaTheme.tabBarBackgroundUIColor
        appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
        appearance.shadowColor = VelaTheme.tabBarShadowUIColor
        appearance.stackedLayoutAppearance.normal.iconColor = VelaTheme.tabBarNormalUIColor
        appearance.stackedLayoutAppearance.selected.iconColor = VelaTheme.tabBarSelectedUIColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: VelaTheme.tabBarNormalUIColor]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: VelaTheme.tabBarSelectedUIColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
    }

    @ObservedObject private var appState = VelaAppState.shared
    @State private var showQuickActions = false
    @State private var showBloodLog = false
    @State private var showWeightLog = false

    var body: some View {
        ZStack {
            VelaTheme.background
                .ignoresSafeArea()

            TabView(selection: $appState.selectedTab) {
                HomeView()
                    .tag(0)

                JournalView()
                    .tag(1)

                StrainView()
                    .tag(2)

                RecoveryView()
                    .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VelaBottomTabBar(selectedTab: $appState.selectedTab, showQuickActions: $showQuickActions)
        }
        .fullScreenCover(isPresented: $appState.showCoachHub) {
            CoachView()
        }
        .sheet(isPresented: $showQuickActions) {
            VelaQuickActionsSheet()
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBloodLog) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeightLog) {
            WeightLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: appState.triggerBloodLog) { _, newValue in
            if newValue {
                appState.triggerBloodLog = false
                showBloodLog = true
            }
        }
        .onChange(of: appState.triggerWeightLog) { _, newValue in
            if newValue {
                appState.triggerWeightLog = false
                showWeightLog = true
            }
        }
        .tint(VelaTheme.primaryText)
    }
}

private struct VelaBottomTabBar: View {
    @Binding var selectedTab: Int
    @Binding var showQuickActions: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(index: 0, title: L10n.t("Home", "首页"), icon: "house.fill")
            tabButton(index: 1, title: L10n.t("Journal", "手记"), icon: "book.fill")
            
            plusButton
            
            tabButton(index: 2, title: L10n.t("Fitness", "健身"), icon: "figure.run")
            tabButton(index: 3, title: L10n.t("Vitals", "生命体征"), icon: "heart.fill")
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 6)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VelaTheme.stroke)
                .frame(height: 0.5)
        }
    }

    private func tabButton(index: Int, title: String, icon: String) -> some View {
        let isSelected = selectedTab == index

        return Button {
            if index == 0 {
                if selectedTab == 0 {
                    VelaAppState.shared.homeNavigationStackId = UUID()
                }
                VelaAppState.shared.showCoachHub = false
                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                    selectedTab = 0
                }
            } else {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                    selectedTab = index
                }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 28, height: 26)

                Text(title)
                    .font(.system(size: 9, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
            }
            .foregroundStyle(isSelected ? VelaTheme.primaryText : VelaTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var plusButton: some View {
        Button {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                showQuickActions = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(VelaTheme.accent)
                    .frame(width: 42, height: 42)
                    .shadow(color: VelaTheme.accent.opacity(0.35), radius: 8, y: 3)

                Image(systemName: "plus")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("Quick Actions", "快速操作"))
    }
}
