import SwiftUI

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

// MARK: - VelaShell — Unified Floating Glass Navigation
//
// iOS 26 & iOS 18+: Uses ZStack content switcher + "玻璃胶囊导航 + 右侧独立玻璃圆形 +" side-by-side layout.
// Automatically leverages native iOS 26 Liquid Glass material effect with smooth spring slide animations.
// Completely bypasses native system tab bar to prevent overlap, duplication, and tap lag.

struct VelaShell: View {
    @State private var selectedTab: VelaTab = .today
    @State private var showPlusSheet = false
    @State private var showCoach     = false
    @State private var showSettings  = false

    @ObservedObject private var appState = VelaAppState.shared
    @Namespace private var tabAnimation

    // MARK: - Tab Enum

    enum VelaTab: Int, CaseIterable, Hashable {
        case today, journal, training, vitals
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Background Warm Canvas
                VelaTheme.bg.ignoresSafeArea()

                // Tab Content View Controller
                Group {
                    switch selectedTab {
                    case .today:
                        VelaTodayView(showCoach: $showCoach, showSettings: $showSettings)
                    case .journal:
                        VelaJournalView()
                    case .training:
                        VelaTrainingView()
                    case .vitals:
                        VelaVitalsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.all, edges: .bottom)

                // "玻璃胶囊导航 + 右侧独立玻璃圆形 +" Side-by-Side Glass Tab Bar
                bottomGlassNavBar
                    .padding(.bottom, 8)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onReceive(appState.$showCoachHub) { show in
            if show {
                showPlusSheet = false
                showCoach = true
                appState.showCoachHub = false
            }
        }
        .sheet(isPresented: $showPlusSheet) {
            PlusActionSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.bg)
        }
        .sheet(isPresented: $showCoach) {
            VelaCoachView()
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { VelaSettingsView() }
        }
        .sheet(isPresented: $appState.triggerWeightLog) {
            WeightLogSheetView()
        }
        .sheet(isPresented: $appState.triggerBloodLog) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $appState.triggerWorkoutLog) {
            WorkoutLogSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $appState.triggerFoodSearch) {
            FoodSearchSheetView()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $appState.triggerFoodScanner) {
            FoodScannerSimulatorView(type: appState.scannerType)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .tint(VelaTheme.accent)
    }

    // MARK: - Side-by-Side Navigation Bar ("玻璃胶囊导航 + 右侧独立玻璃圆形 +")
    
    private var bottomGlassNavBar: some View {
        HStack(spacing: 12) {
            // 1. Frosted Glass Capsule for 4 Tabs
            HStack(spacing: 0) {
                ForEach(VelaTab.allCases, id: \.self) { tab in
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

    private func customTabButton(_ tab: VelaTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78, blendDuration: 0)) {
                selectedTab = tab
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
        case .journal:  "book.pages"
        case .training: "figure.run"
        case .vitals:   "heart.text.square"
        }
    }

    private func label(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "首页"
        case .journal:  "手记"
        case .training: "健身"
        case .vitals:   "体征"
        }
    }
}
