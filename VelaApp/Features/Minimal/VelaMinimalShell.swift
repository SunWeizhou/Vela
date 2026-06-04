import SwiftUI
import UIKit

enum VelaNavigationVisibility {
    static func shouldShowBottomBar(keyboardVisible: Bool) -> Bool {
        !keyboardVisible
    }
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

extension EnvironmentValues {
    var velaScrollDirection: Binding<VelaScrollDirection> {
        get { self[VelaScrollDirectionKey.self] }
        set { self[VelaScrollDirectionKey.self] = newValue }
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

    @State private var selectedTab: VelaTab = .today
    @State private var showPlusSheet = false
    @State private var showCoach     = false
    @State private var showSettings  = false
    @State private var keyboardVisible = false

    @ObservedObject private var appState = VelaAppState.shared
    @Namespace private var tabAnimation

    // MARK: - Tab Enum

    enum VelaTab: Int, CaseIterable, Hashable {
        case today = 0
        case training = 1
        case insights = 2
        case coach = 3
        case me = 4
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
        .onReceive(appState.$selectedTab) { tab in
            guard let next = VelaTab(rawValue: tab), selectedTab != next else { return }
            selectedTab = next
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
        .sheet(isPresented: $showSettings) {
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
        .sheet(isPresented: $appState.triggerFoodSearch, onDismiss: appState.markLocalDataChanged) {
            FoodSearchSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $appState.triggerFoodScanner, onDismiss: appState.markLocalDataChanged) {
            FoodScannerView(type: appState.scannerType)
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
        .tint(VelaTheme.accent)
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
        TabView(selection: nativeTabSelection) {
            Tab(label(for: .today), systemImage: iconName(for: .today), value: VelaTab.today) {
                nativeTabSurface(.today) {
                    VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
                }
            }
            Tab(label(for: .training), systemImage: iconName(for: .training), value: VelaTab.training) {
                nativeTabSurface(.training) {
                    VelaTrainingView()
                }
            }
            Tab(label(for: .insights), systemImage: iconName(for: .insights), value: VelaTab.insights) {
                nativeTabSurface(.insights) {
                    VelaVitalsView()
                }
            }
            Tab(label(for: .coach), systemImage: iconName(for: .coach), value: VelaTab.coach) {
                nativeTabSurface(.coach) {
                    VelaCoachView(presentation: .embedded, vm: services.coachChat)
                }
            }
            Tab(label(for: .me), systemImage: iconName(for: .me), value: VelaTab.me) {
                nativeTabSurface(.me) {
                    NavigationStack {
                        VelaMeView()
                    }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .toolbar(keyboardVisible ? .hidden : .visible, for: .tabBar)
    }

    private var nativeTabSelection: Binding<VelaTab> {
        Binding(
            get: { selectedTab },
            set: { candidate in
                let result = VelaTabSelection.resolve(candidate: candidate, current: selectedTab)
                selectedTab = result.selectedTab
                appState.selectedTab = result.selectedTab.rawValue
            }
        )
    }

    private var legacyFloatingNavigation: some View {
        ZStack(alignment: .bottom) {
            VelaTheme.systemGroupedBackground.ignoresSafeArea()

            // Keep legacy primary surfaces mounted so cached SwiftData content
            // is already hydrated when the user switches tabs.
            ZStack {
                tabSurface(.today) {
                    VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
                }
                tabSurface(.training) {
                    VelaTrainingView()
                }
                tabSurface(.insights) {
                    VelaVitalsView()
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
            .ignoresSafeArea(.container, edges: .bottom)

            if VelaNavigationVisibility.shouldShowBottomBar(keyboardVisible: keyboardVisible) {
                bottomGlassNavBar
                    .padding(.bottom, 8)
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
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .animation(VelaTheme.snappy, value: selectedTab)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(VelaTheme.snappy) {
                selectedTab = tab
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
            .frame(height: 46)
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
    }

    private func iconName(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "sun.max"
        case .training: "figure.run"
        case .insights: "chart.xyaxis.line"
        case .coach:    "sparkles"
        case .me:       "person.crop.circle"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "Today"
        case .training: "Training"
        case .insights: "Insights"
        case .coach:    "Coach"
        case .me:       "Me"
        }
    }

    private func nativeTabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .animation(VelaTheme.snappy, value: selectedTab)
    }
}

enum VelaTabSelection {
    struct Result {
        var selectedTab: VelaShell.VelaTab
        var shouldPresentQuickActions: Bool
    }

    static let contentTabs: [VelaShell.VelaTab] = [.today, .training, .insights, .coach, .me]

    static func resolve(
        candidate: VelaShell.VelaTab,
        current: VelaShell.VelaTab
    ) -> Result {
        Result(selectedTab: candidate, shouldPresentQuickActions: false)
    }

}
