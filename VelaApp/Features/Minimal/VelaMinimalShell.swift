import SwiftUI

struct VelaMinimalShell: View {
    @ObservedObject private var appState = VelaAppState.shared
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @State private var showBloodLog = false
    @State private var showWeightLog = false

    var body: some View {
        ZStack {
            VelaBackground()

            activeTab
                .padding(.top, 88)
                .safeAreaPadding(.bottom, 108)

            VStack(spacing: 0) {
                VelaMinimalAppBar(
                    title: "Vela",
                    leadingSystemImage: "person.crop.circle.fill",
                    trailingSystemImage: "bell"
                ) {
                    appState.showCoachHub = true
                }
                Spacer(minLength: 0)
            }

            VStack {
                Spacer(minLength: 0)
                VelaMinimalFloatingTabBar(selectedTab: boundTab) {
                    appState.showCoachHub = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
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
        .fullScreenCover(isPresented: $appState.showCoachHub) {
            CoachView()
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
        .tint(VelaTheme.primary)
        .velaErrorAlert(error: $dashboardVM.currentError)
    }

    private var boundTab: Binding<VelaMinimalTab> {
        Binding(
            get: {
                VelaMinimalTab(rawValue: appState.selectedTab) ?? .today
            },
            set: { tab in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    appState.selectedTab = tab.rawValue
                }
            }
        )
    }

    @ViewBuilder
    private var activeTab: some View {
        switch boundTab.wrappedValue {
        case .today:
            VelaMinimalTodayView()
        case .vitals:
            VelaMinimalVitalsView()
        case .fitness:
            VelaMinimalFitnessView()
        case .journal:
            VelaMinimalJournalView()
        case .coach:
            VelaMinimalCoachView()
        }
    }
}

