import SwiftUI
import UIKit

enum VelaNavigationVisibility {
    static func shouldShowBottomBar(keyboardVisible: Bool) -> Bool {
        !keyboardVisible
    }
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
        case today, training, vitals, coach, quickAdd

        static let contentTabs: [VelaTab] = [.today, .training, .vitals, .coach]
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
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
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
                .presentationBackground(VelaTheme.bg)
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
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $appState.triggerFoodSearch, onDismiss: appState.markLocalDataChanged) {
            FoodSearchSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $appState.triggerFoodScanner, onDismiss: appState.markLocalDataChanged) {
            FoodScannerView(type: appState.scannerType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $appState.triggerJournal, onDismiss: appState.markLocalDataChanged) {
            NavigationStack {
                VelaJournalView()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "#F5F3F0"))
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
                VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
            }
            Tab(label(for: .training), systemImage: iconName(for: .training), value: VelaTab.training) {
                VelaTrainingView()
            }
            Tab(label(for: .vitals), systemImage: iconName(for: .vitals), value: VelaTab.vitals) {
                VelaVitalsView()
            }
            Tab(label(for: .coach), systemImage: iconName(for: .coach), value: VelaTab.coach) {
                VelaCoachView(presentation: .embedded, vm: services.coachChat)
            }
            Tab(label(for: .quickAdd), systemImage: iconName(for: .quickAdd), value: VelaTab.quickAdd, role: .search) {
                Color.clear
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
                if result.shouldPresentQuickActions {
                    showPlusSheet = true
                } else {
                    appState.selectedTab = result.selectedTab.rawValue
                }
            }
        )
    }

    private var legacyFloatingNavigation: some View {
        ZStack(alignment: .bottom) {
            VelaTheme.bg.ignoresSafeArea()

            // Keep legacy primary surfaces mounted so cached SwiftData content
            // is already hydrated when the user switches tabs.
            ZStack {
                tabSurface(.today) {
                    VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
                }
                tabSurface(.training) {
                    VelaTrainingView()
                }
                tabSurface(.vitals) {
                    VelaVitalsView()
                }
                tabSurface(.coach) {
                    VelaCoachView(
                        presentation: .embedded,
                        usesOverlayNavigation: true,
                        vm: services.coachChat
                    )
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

    // MARK: - Side-by-Side Navigation Bar ("玻璃胶囊导航 + 右侧独立玻璃圆形 +")
    
    private var bottomGlassNavBar: some View {
        HStack(spacing: 12) {
            // 1. Frosted Glass Capsule for primary tabs
            HStack(spacing: 0) {
                ForEach(VelaTab.contentTabs, id: \.self) { tab in
                    customTabButton(tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .velaInteractiveGlass(in: Capsule())
            )
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)

            // 2. Independent Circular Glass Plus Button
            Button {
                showPlusSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                        .velaInteractiveGlass(in: Circle())
                    
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Individual Tab Button with Premium Sliding Highlight

    private func tabSurface<Content: View>(
        _ tab: VelaTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)) {
                selectedTab = tab
                appState.selectedTab = tab.rawValue
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName(for: tab))
                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                    .frame(height: 22)
                Text(label(for: tab))
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(isActive ? Color(hex: "#1A1917") : Color(hex: "#8E8A80"))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                ZStack {
                    if isActive {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(hex: "#E8E4DD").opacity(0.48))
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
        case .vitals:   "heart.text.square"
        case .coach:    "sparkles"
        case .quickAdd: "plus"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "首页"
        case .training: "健身"
        case .vitals:   "体征"
        case .coach:    "Coach"
        case .quickAdd: "添加"
        }
    }
}

enum VelaTabSelection {
    struct Result {
        var selectedTab: VelaShell.VelaTab
        var shouldPresentQuickActions: Bool
    }

    static func resolve(
        candidate: VelaShell.VelaTab,
        current: VelaShell.VelaTab
    ) -> Result {
        guard candidate == .quickAdd else {
            return Result(selectedTab: candidate, shouldPresentQuickActions: false)
        }
        return Result(selectedTab: current, shouldPresentQuickActions: true)
    }
}
