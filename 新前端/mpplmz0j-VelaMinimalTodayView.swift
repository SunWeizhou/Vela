import SwiftData
import SwiftUI

struct VelaMinimalTodayView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    private var plan: DailyPlanRecommendation {
        DailyPlanEngine.recommendation(for: viewModel.dashboard)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                capacityHero
                actionCard
                metricsGrid
                trustCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
        }
    }

    private var capacityHero: some View {
        VelaMinimalGlassPanel(padding: 24, radius: 28) {
            VStack(alignment: .center, spacing: 18) {
                VelaMinimalSectionTitle(title: L10n.t("Today's Capacity", "今日容量"))
                    .frame(maxWidth: .infinity, alignment: .center)

                ZStack {
                    Circle()
                        .stroke(VelaTheme.accent.opacity(0.10), lineWidth: 16)

                    Circle()
                        .trim(from: 0, to: recoveryProgress)
                        .stroke(
                            VelaTheme.accent,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: VelaTheme.accent.opacity(0.18), radius: 14, y: 4)

                    VStack(spacing: 0) {
                        VelaMinimalValueText(
                            value: VelaMinimalFormat.score(viewModel.dashboard.recovery),
                            unit: "%",
                            size: 68,
                            tint: VelaTheme.accent
                        )
                        Text(VelaMinimalFormat.band(viewModel.dashboard.recovery))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                    }
                }
                .frame(width: 230, height: 230)

                Text(viewModel.dashboard.dailyInsight)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(title: L10n.t("Recommended Action", "建议行动"))
            VelaMinimalGlassPanel(padding: 18, radius: 24) {
                HStack(spacing: 14) {
                    Image(systemName: planIcon)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(planTint))
                        .shadow(color: planTint.opacity(0.20), radius: 14, y: 6)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                            .lineLimit(2)
                        Text(plan.body)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(VelaTheme.secondaryText)
                            .lineLimit(3)
                    }

                    Spacer()

                    Button {
                        VelaAppState.shared.routeToCoach(question: plan.coachQuestion)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            VelaMinimalBentoMetricCard(
                title: L10n.t("Sleep", "睡眠"),
                value: VelaMinimalFormat.score(viewModel.dashboard.sleepScore),
                unit: "%",
                subtitle: VelaMinimalFormat.minutesAsHours(viewModel.dashboard.sleepSummary.totalSleepMinutes),
                systemImage: "bed.double.fill",
                tint: VelaTheme.sleep
            )
            VelaMinimalBentoMetricCard(
                title: L10n.t("Strain", "负荷"),
                value: VelaMinimalFormat.whole(viewModel.dashboard.strain.hasData ? viewModel.dashboard.strain.score : nil),
                subtitle: "\(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)",
                systemImage: "figure.run",
                tint: VelaTheme.strain
            )
            VelaMinimalBentoMetricCard(
                title: L10n.t("Energy", "能量"),
                value: VelaMinimalFormat.whole(viewModel.dashboard.energy.hasData ? viewModel.dashboard.energy.currentEnergy : nil),
                unit: "%",
                subtitle: L10n.t("Current bank", "当前能量库"),
                systemImage: "battery.75percent",
                tint: VelaTheme.energy
            )
            VelaMinimalBentoMetricCard(
                title: L10n.t("Stress", "压力"),
                value: VelaMinimalFormat.whole(viewModel.dashboard.stress.hasData ? viewModel.dashboard.stress.stressIndex : nil),
                subtitle: L10n.t("Physiology load", "生理压力"),
                systemImage: "waveform.path.ecg",
                tint: VelaTheme.stress
            )
        }
    }

    private var trustCard: some View {
        VelaMinimalGlassPanel(padding: 18, radius: 22) {
            HStack(spacing: 13) {
                Image(systemName: viewModel.errorMessage == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(viewModel.errorMessage == nil ? VelaTheme.recovery : VelaTheme.stress)
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.errorMessage == nil ? L10n.t("Apple Health connected", "Apple Health 已连接") : L10n.t("Needs attention", "需要处理"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(lastUpdatedText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                Spacer()
            }
        }
    }

    private var recoveryProgress: CGFloat {
        guard viewModel.dashboard.recovery.hasData else { return 0.06 }
        return min(max(CGFloat(viewModel.dashboard.recovery.score / 100), 0.06), 1)
    }

    private var planTint: Color {
        switch plan.accent {
        case .recovery: return VelaTheme.recovery
        case .sleep: return VelaTheme.sleep
        case .strain: return VelaTheme.strain
        case .energy: return VelaTheme.energy
        case .stress: return VelaTheme.stress
        }
    }

    private var planIcon: String {
        switch plan.kind {
        case .recovery: return "heart.fill"
        case .train: return "figure.run"
        case .maintain: return "slider.horizontal.3"
        case .protectSleep: return "moon.fill"
        case .downshift: return "arrow.down.forward.circle.fill"
        }
    }

    private var lastUpdatedText: String {
        guard let lastUpdated = viewModel.lastUpdated else {
            return L10n.t("Sync pending", "等待同步")
        }
        return lastUpdated.formatted(date: .omitted, time: .shortened)
    }
}

