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
    let parityInterfaceEnabled: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var services: VelaServices

    @State private var showPlusSheet = false
    @State private var showCoach     = false
    @State private var keyboardVisible = false
    @State private var paritySelectedTab = ParityTab.home.rawValue
    @State private var previousParityTab = ParityTab.home.rawValue
    @State private var mountedLegacyTabs: Set<VelaTab> = [.today]

    @ObservedObject private var appState = VelaAppState.shared
    @Namespace private var tabAnimation

    // MARK: - Tab Enum

    enum VelaTab: Int, CaseIterable, Hashable {
        case today = 0
        case trends = 1
        case coach = 2
        case training = 3
    }

    enum ParityTab: Int, CaseIterable, Hashable {
        case home = 0
        case journal = 1
        case fitness = 2
        case biology = 3
        case intelligence = 4
    }

    /// Rhythm's four canonical surfaces are the safe default. The parity Adapter
    /// is opt-in for regression capture only.
    init(parityInterfaceEnabled: Bool = false) {
        self.parityInterfaceEnabled = parityInterfaceEnabled
    }

    // MARK: - Body

    var body: some View {
        navigationSurface
        .onReceive(appState.$showCoachHub) { show in
            if show {
                showPlusSheet = false
                showCoach = true
                appState.showCoachHub = false
            }
        }
        .onReceive(appState.$selectedTab) { selectedTab in
            guard parityInterfaceEnabled else { return }
            switch selectedTab {
            case VelaAppState.trendsTabIndex:
                paritySelectedTab = ParityTab.biology.rawValue
            case VelaAppState.trainingTabIndex:
                paritySelectedTab = ParityTab.fitness.rawValue
            case VelaAppState.coachTabIndex:
                showCoach = true
            default:
                paritySelectedTab = ParityTab.home.rawValue
            }
        }
        .onChange(of: paritySelectedTab) { oldValue, newValue in
            guard newValue == ParityTab.intelligence.rawValue else {
                previousParityTab = newValue
                return
            }
            paritySelectedTab = oldValue == ParityTab.intelligence.rawValue
                ? previousParityTab
                : oldValue
            showPlusSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                keyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                keyboardVisible = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            services.coachChat.handleAppActiveChange(isActive: phase == .active)
            if phase == .active {
                let ctx = modelContext
                Task { @MainActor in
                    await ProactiveIntelligenceOrchestrator().runAsyncCheck(modelContext: ctx)
                }
            }
        }
        .sheet(isPresented: $showPlusSheet, onDismiss: appState.runDeferredQuickAction) {
            PlusActionSheet()
                .presentationDetents([.medium])
                .velaSheetSurface()
        }
        .fullScreenCover(isPresented: $showCoach) {
            VelaCoachView(presentation: .quickCover, vm: services.coachChat)
        }
        .sheet(isPresented: $appState.showSettings) {
            NavigationStack { VelaSettingsView() }
                .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerWeightLog, onDismiss: appState.markLocalDataChanged) {
            WeightLogSheetView()
                .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerBloodLog, onDismiss: appState.markLocalDataChanged) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerWorkoutLog, onDismiss: appState.markLocalDataChanged) {
            WorkoutLogSheetView()
                .presentationDetents([.medium])
                .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerJournal, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                VelaJournalView()
            }
            .presentationDetents([.large])
            .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerRecoveryDetail) {
            NavigationStack {
                VelaMetricDetailView(metric: .recovery)
            }
            .presentationDetents([.large])
            .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerPostWorkoutCheckIn, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                PostWorkoutCheckInSheet(workoutID: appState.postWorkoutCheckInWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .velaSheetSurface()
        }
        .sheet(isPresented: $appState.triggerPostWorkoutImpact) {
            NavigationStack {
                PostWorkoutImpactSheet(workoutID: appState.postWorkoutImpactWorkoutID)
            }
            .presentationDetents([.medium, .large])
            .velaSheetSurface()
        }
        .tint(VelaTheme.accent)
    }

    @ViewBuilder
    private var navigationSurface: some View {
        if parityInterfaceEnabled {
            parityTabNavigation
        } else if #available(iOS 26.0, *) {
            nativeTabNavigation
        } else {
            legacyFloatingNavigation
        }
    }

    private var parityTabNavigation: some View {
        TabView(selection: $paritySelectedTab) {
            // Each tab root needs its own NavigationStack so the NavigationLinks
            // inside (signal grid, metric detail, journal detail, vitals metrics)
            // get a back button. Without it, pushing a detail leaves no way to
            // return — reported as "进入了之后就没办法返回了".
            NavigationStack {
                VelaTodayView(showCoach: $showCoach, showSettings: $appState.showSettings)
            }
            .environment(\.velaSurfaceIsActive, paritySelectedTab == ParityTab.home.rawValue)
            .tabItem { Label(L10n.t("Home", "首页"), systemImage: "house.fill") }
            .tag(ParityTab.home.rawValue)

            NavigationStack {
                VelaJournalView()
            }
            .environment(\.velaSurfaceIsActive, paritySelectedTab == ParityTab.journal.rawValue)
            .tabItem { Label(L10n.t("Journal", "日志"), systemImage: "checklist") }
            .tag(ParityTab.journal.rawValue)

            NavigationStack {
                VelaTrainingView()
            }
            .environment(\.velaSurfaceIsActive, paritySelectedTab == ParityTab.fitness.rawValue)
            .tabItem { Label(L10n.t("Fitness", "健身"), systemImage: "figure.run") }
            .tag(ParityTab.fitness.rawValue)

            NavigationStack {
                VelaVitalsView()
            }
            .environment(\.velaSurfaceIsActive, paritySelectedTab == ParityTab.biology.rawValue)
            .tabItem { Label(L10n.t("Biology", "生理"), systemImage: "waveform.path.ecg") }
            .tag(ParityTab.biology.rawValue)

            Color.clear
                .tabItem { Label(L10n.t("Add", "添加"), systemImage: "plus.circle.fill") }
                .tag(ParityTab.intelligence.rawValue)
        }
        .tint(VelaTheme.accent)
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

            nativeTabSurface(.trends) {
                VelaTrendsView()
            }
            .tabItem {
                Label(label(for: .trends), systemImage: iconName(for: .trends))
            }
            .tag(1)

            nativeTabSurface(.coach) {
                VelaCoachView(presentation: .embedded, vm: services.coachChat)
            }
            .tabItem {
                Label(label(for: .coach), systemImage: iconName(for: .coach))
            }
            .tag(2)

            nativeTabSurface(.training) {
                VelaTrainingView()
            }
            .tabItem {
                Label(label(for: .training), systemImage: iconName(for: .training))
            }
            .tag(3)
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbar(keyboardVisible ? .hidden : .visible, for: .tabBar)
    }

    private var legacyFloatingNavigation: some View {
        ZStack {
            VelaTheme.rhythmCanvas.ignoresSafeArea()

            // Mount each legacy surface on first visit, then preserve its navigation
            // and scroll state. This avoids eagerly initializing four SwiftData trees
            // at launch while keeping normal tab-return behavior after the first visit.
            ZStack {
                if mountedLegacyTabs.contains(.today) {
                    tabSurface(.today) {
                        VelaTodayView(showCoach: $showCoach, showSettings: $appState.showSettings)
                    }
                }
                if mountedLegacyTabs.contains(.trends) {
                    tabSurface(.trends) {
                        VelaTrendsView()
                    }
                }
                if mountedLegacyTabs.contains(.coach) {
                    tabSurface(.coach) {
                        VelaCoachView(
                            presentation: .embedded,
                            usesOverlayNavigation: true,
                            vm: services.coachChat
                        )
                    }
                }
                if mountedLegacyTabs.contains(.training) {
                    tabSurface(.training) {
                        VelaTrainingView()
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
                    .transition(bottomBarTransition)
            }
        }
        .onAppear {
            mountedLegacyTabs = VelaLegacySurfaceMountPolicy.including(
                selectedTab: appState.selectedTab,
                in: mountedLegacyTabs
            )
        }
        .onChange(of: appState.selectedTab) { _, selectedTab in
            mountedLegacyTabs = VelaLegacySurfaceMountPolicy.including(
                selectedTab: selectedTab,
                in: mountedLegacyTabs
            )
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
        return NavigationStack {
            content()
        }
        .environment(\.velaSurfaceIsActive, isActive)
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
        .accessibilityHidden(!isActive)
        .zIndex(isActive ? 1 : 0)
        .animation(
            .easeOut(duration: reduceMotion ? 0.12 : VelaNavigationMotion.destinationFadeDuration),
            value: isActive
        )
    }

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = appState.selectedTab == tab.rawValue
        return Button {
            guard !isActive else { return }
            withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                appState.selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 17, weight: isActive ? .semibold : .regular))
                    .frame(height: 22)
                Text(label(for: tab))
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(isActive ? VelaTheme.fg : VelaTheme.muted)
            .frame(maxWidth: .infinity)
            .frame(height: VelaFloatingNavigationMetrics.barHeight - 12)
            .background(
                ZStack {
                    if isActive {
                        if reduceMotion {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VelaTheme.accent.opacity(0.08))
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VelaTheme.accent.opacity(0.08))
                                .matchedGeometryEffect(id: "activeTabHighlight", in: tabAnimation)
                        }
                    }
                }
            )
        }
        .buttonStyle(.tabItem)
        .accessibilityLabel(label(for: tab))
        .accessibilityValue(isActive ? L10n.t("Selected", "已选中") : "")
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .accessibilityIdentifier("tab-\(tab.rawValue)")
    }

    private func iconName(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "sun.max"
        case .trends:   "waveform.path.ecg"
        case .coach:    "sparkles"
        case .training: "figure.run"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    L10n.t("Today", "今日")
        case .trends:   L10n.t("Trends", "趋势")
        case .coach:    "Vela"
        case .training: L10n.t("Training", "训练")
        }
    }

    private var bottomBarTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    @ViewBuilder
    private func nativeTabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
        }
        .environment(\.velaSurfaceIsActive, appState.selectedTab == tab.rawValue)
    }
}

enum VelaTabSelection {
    struct Result {
        var selectedTab: VelaShell.VelaTab
        var shouldPresentQuickActions: Bool
    }

    static let contentTabs: [VelaShell.VelaTab] = [.today, .trends, .coach, .training]

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

enum VelaLegacySurfaceMountPolicy {
    static func including(
        selectedTab: Int,
        in mountedTabs: Set<VelaShell.VelaTab>
    ) -> Set<VelaShell.VelaTab> {
        guard let selected = VelaShell.VelaTab(rawValue: selectedTab) else {
            return mountedTabs
        }
        return mountedTabs.union([selected])
    }
}
