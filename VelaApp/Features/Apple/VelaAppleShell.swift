import SwiftUI

// MARK: - VelaAppleShell — Apple-style frosted glass tab bar shell
// Replaces VelaMinimalShell.swift. Uses 4 tabs + center Coach button.

struct VelaAppleShell: View {
    @ObservedObject private var appState = VelaAppState.shared
    @State private var showCoach = false

    var body: some View {
        ZStack {
            VelaTheme.background.ignoresSafeArea()

            activeTab
                .padding(.top, 60)
                .safeAreaPadding(.bottom, 100)

            VStack(spacing: 0) {
                VelaAppleNavBar(title: navTitle,
                    leading: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(VelaTheme.accent)
                    },
                    trailing: {
                        Button {
                            appState.showCoachHub = true
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(VelaTheme.onSurfaceVariant)
                        }
                    }
                )
                Spacer()
            }

            VStack {
                Spacer()
                VelaAppleTabBar(selectedTab: tabBinding) {
                    showCoach = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showCoach) {
            VelaAppleCoachView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $appState.showCoachHub) {
            CoachView()
        }
        .tint(VelaTheme.accent)
    }

    private var tabBinding: Binding<VelaAppleTab> {
        Binding(
            get: { VelaAppleTab(rawValue: appState.selectedTab) ?? .today },
            set: { appState.selectedTab = $0.rawValue }
        )
    }

    private var navTitle: String {
        switch selectedTab {
        case .today:    return "Vela"
        case .training: return "Training"
        case .insights: return "Insights"
        case .settings: return "You"
        }
    }

    @ViewBuilder
    private var activeTab: some View {
        switch selectedTab {
        case .today:
            VelaAppleTodayView()
        case .training:
            VelaAppleTrainingView()
        case .insights:
            VelaAppleInsightsView()
        case .settings:
            VelaAppleSettingsView()
        }
    }
}
