import SwiftUI
import SwiftData
import UIKit

enum VelaNavigationVisibility {
    static func shouldShowBottomBar(keyboardVisible: Bool) -> Bool {
        !keyboardVisible
    }
}

enum VelaFloatingNavigationMetrics {
    static let barHeight: CGFloat = 58
    static let navBottomPadding: CGFloat = 14
    static let contentBottomPadding: CGFloat = 32
    static let coachComposerClearance: CGFloat = 116
}

enum VelaNavigationMotion {
    static let destinationFadeDuration = 0.16
}

// MARK: - VelaScrollTracking
// Kept for child view compatibility. Without binding injection these are no-ops.

enum VelaScrollDirection { case up, down, idle }

private struct VelaScrollDirectionKey: EnvironmentKey {
    static let defaultValue: Binding<VelaScrollDirection> = .constant(.idle)
}

private struct VelaSurfaceIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var velaScrollDirection: Binding<VelaScrollDirection> {
        get { self[VelaScrollDirectionKey.self] }
        set { self[VelaScrollDirectionKey.self] = newValue }
    }


    var velaSurfaceIsActive: Bool {
        get { self[VelaSurfaceIsActiveKey.self] }
        set { self[VelaSurfaceIsActiveKey.self] = newValue }
    }
}

extension View {
    @ViewBuilder
    func velaTrackScroll(direction: Binding<VelaScrollDirection>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldY, newY in
                let delta = newY - oldY
                if abs(delta) > 3 {
                    direction.wrappedValue = delta > 0 ? .down : .up
                }
            }
        } else {
            self
        }
    }
}

// MARK: - VelaShell — Native iOS 26 Navigation with Legacy Fallback
//
// iOS 26 uses the system Liquid Glass tab bar and its native scroll minimization.
// Earlier releases keep the custom floating glass navigation.

struct VelaShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var services: VelaServices

    @State private var showPlusSheet = false
    @State private var showCoach     = false
    @State private var keyboardVisible = false

    @ObservedObject private var appState = VelaAppState.shared
    @Namespace private var tabAnimation

    // MARK: - Tab Enum

    enum VelaTab: Int, CaseIterable, Hashable {
        case today = 0
        case training = 1
        case coach = 2
        case me = 3
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            navigationSurface
        }
        .onReceive(appState.$showCoachHub) { show in
            if show {
                showPlusSheet = false
                showCoach = true
                appState.showCoachHub = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(VelaTheme.snappy) {
                keyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(VelaTheme.snappy) {
                keyboardVisible = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            services.coachChat.handleAppActiveChange(isActive: phase == .active)
        }
        .sheet(isPresented: $showPlusSheet, onDismiss: appState.runDeferredQuickAction) {
            PlusActionSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .fullScreenCover(isPresented: $showCoach) {
            VelaCoachView(presentation: .quickCover, vm: services.coachChat)
        }
        .sheet(isPresented: $appState.showSettings) {
            NavigationStack { VelaSettingsView() }
        }
        .sheet(isPresented: $appState.triggerWeightLog, onDismiss: appState.markLocalDataChanged) {
            WeightLogSheetView()
        }
        .sheet(isPresented: $appState.triggerBloodLog, onDismiss: appState.markLocalDataChanged) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.triggerWorkoutLog, onDismiss: appState.markLocalDataChanged) {
            WorkoutLogSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerJournal, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                VelaJournalView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerRecoveryDetail) {
            NavigationStack {
                VelaMetricDetailView(metric: .recovery)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerPostWorkoutCheckIn, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                PostWorkoutCheckInSheet(workoutID: appState.postWorkoutCheckInWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerPostWorkoutImpact) {
            NavigationStack {
                PostWorkoutImpactSheet(workoutID: appState.postWorkoutImpactWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .tint(VelaTheme.accent)
        .sensoryFeedback(.selection, trigger: appState.selectedTab)
    }

    @ViewBuilder
    private var navigationSurface: some View {
        if #available(iOS 26.0, *) {
            nativeTabNavigation
        } else {
            legacyFloatingNavigation
        }
    }

    @available(iOS 26.0, *)
    private var nativeTabNavigation: some View {
        TabView(selection: $appState.selectedTab) {
            nativeTabSurface(.today) {
                VelaTodayView(showCoach: $showCoach, showSettings: $appState.showSettings)
            }
            .tabItem {
                Label(label(for: .today), systemImage: iconName(for: .today))
            }
            .tag(0)

            nativeTabSurface(.training) {
                VelaTrainingView()
            }
            .tabItem {
                Label(label(for: .training), systemImage: iconName(for: .training))
            }
            .tag(1)

            nativeTabSurface(.coach) {
                VelaCoachView(presentation: .embedded, vm: services.coachChat)
            }
            .tabItem {
                Label(label(for: .coach), systemImage: iconName(for: .coach))
            }
            .tag(2)

            nativeTabSurface(.me) {
                NavigationStack {
                    VelaMeView()
                }
            }
            .tabItem {
                Label(label(for: .me), systemImage: iconName(for: .me))
            }
            .tag(3)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbar(keyboardVisible ? .hidden : .visible, for: .tabBar)
    }

    private var legacyFloatingNavigation: some View {
        ZStack {
            VelaTheme.systemGroupedBackground.ignoresSafeArea()

            // Keep legacy primary surfaces mounted so cached SwiftData content
            // is already hydrated when the user switches tabs.
            ZStack {
                tabSurface(.today) {
                    VelaTodayView(showCoach: $showCoach, showSettings: $appState.showSettings)
                }
                tabSurface(.training) {
                    VelaTrainingView()
                }
                tabSurface(.coach) {
                    VelaCoachView(
                        presentation: .embedded,
                        usesOverlayNavigation: true,
                        vm: services.coachChat
                    )
                }
                tabSurface(.me) {
                    NavigationStack {
                        VelaMeView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if VelaNavigationVisibility.shouldShowBottomBar(keyboardVisible: keyboardVisible) {
                bottomGlassNavBar
                    .padding(.top, 6)
                    .padding(.bottom, VelaFloatingNavigationMetrics.navBottomPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Legacy Floating Glass Navigation
    
    private var bottomGlassNavBar: some View {
        HStack(spacing: 0) {
            ForEach(VelaTabSelection.contentTabs, id: \.self) { tab in
                customTabButton(tab)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(VelaTheme.cardBg.opacity(0.12))
                .velaInteractiveGlass(in: Capsule())
        )
        .overlay(
            Capsule()
                .stroke(VelaTheme.cardBg.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.018), radius: 10, y: 4)
        .padding(.horizontal, 16)
    }

    // MARK: - Individual Tab Button with Premium Sliding Highlight

    private func tabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isActive = VelaTabSelection.isActive(tab, selectedTab: appState.selectedTab)
        if isActive {
            return AnyView(
                content()
                    .zIndex(1)
            )
        } else {
            return AnyView(
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
            )
        }
    }

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = appState.selectedTab == tab.rawValue
        return Button {
            withAnimation(VelaTheme.snappy) {
                appState.selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .frame(height: 22)
                Text(label(for: tab))
                    .font(.system(size: 8.5, weight: .bold))
            }
            .foregroundStyle(isActive ? VelaTheme.fg : VelaTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: VelaFloatingNavigationMetrics.barHeight - 12)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VelaTheme.accent.opacity(0.08))
                            .matchedGeometryEffect(id: "activeTabHighlight", in: tabAnimation)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label(for: tab))
        .accessibilityValue(isActive ? "已选中" : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func iconName(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "sun.max"
        case .training: "figure.run"
        case .coach:    "sparkles"
        case .me:       "person.crop.circle"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    L10n.t("Today", "今日")
        case .training: L10n.t("Training", "训练")
        case .coach:    L10n.t("Coach", "教练")
        case .me:       L10n.t("Me", "个人")
        }
    }

    @ViewBuilder
    private func nativeTabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .environment(\.velaSurfaceIsActive, appState.selectedTab == tab.rawValue)
    }
}

enum VelaTabSelection {
    struct Result {
        var selectedTab: VelaShell.VelaTab
        var shouldPresentQuickActions: Bool
    }

    static let contentTabs: [VelaShell.VelaTab] = [.today, .training, .coach, .me]

    static func isActive(_ tab: VelaShell.VelaTab, selectedTab: Int) -> Bool {
        tab.rawValue == selectedTab
    }

    static func resolve(
        candidate: VelaShell.VelaTab,
        current: VelaShell.VelaTab
    ) -> Result {
        Result(selectedTab: candidate, shouldPresentQuickActions: false)
    }

}

