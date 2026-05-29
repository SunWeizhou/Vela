import SwiftUI

// MARK: - VelaAppleShell — Apple-style frosted glass tab bar shell
// Replaces VelaMinimalShell.swift. Uses 4 tabs + center Coach button.

struct VelaMinimalShell: View {
    @State private var selectedTab: VelaMinimalTab = .today
    @State private var showCoach = false

    var body: some View {
        ZStack {
            VelaTheme.background.ignoresSafeArea()

            // Active tab content
            activeTab
                .padding(.top, 60)
                .safeAreaPadding(.bottom, 100)

            // Top navigation bar
            VStack(spacing: 0) {
                VelaMinimalNavBar(title: navTitle,
                    leading: {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(VelaTheme.accent)
                    },
                    trailing: {
                        Image(systemName: "bell")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                    }
                )
                Spacer()
            }

            // Floating tab bar
            VStack {
                Spacer()
                VelaMinimalFloatingTabBar(selectedTab: $selectedTab) {
                    showCoach = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showCoach) {
            VelaMinimalCoachView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
        .tint(VelaTheme.accent)
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
            VelaMinimalTodayView()
        case .training:
            VelaMinimalFitnessView()
        case .insights:
            VelaMinimalVitalsView()
        case .settings:
            VelaMinimalJournalView()
        }
    }
}
