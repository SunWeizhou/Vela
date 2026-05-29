import SwiftUI

// MARK: - VelaAppleTodayView — Today's Body Cockpit
// Apple-style: one hero ring + 3 metric cards + coach insight + daily plan

struct VelaAppleTodayView: View {
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    private var readinessScore: Double { dashboard.recovery.score }
    private var sleepScore: Double { dashboard.sleepScore.score }
    private var strainScore: Double { dashboard.strain.score }
    private var energyScore: Double { dashboard.energy.currentEnergy }
    private var recoveryScore: Double { dashboard.recovery.score }
    private var stressScore: Double { dashboard.stress.stressIndex }

    private var hrvValue: String { dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--" }
    private var rhrValue: String { dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))" } ?? "--" }

    private var planItems: [(String, String, String, Color)] {
        let plan = DailyPlanEngine.recommendation(for: dashboard)
        return [
            (plan.primaryActionTitle, plan.body, "figure.run", VelaTheme.strain),
            (plan.secondaryActionTitle ?? "Check Signals", plan.limiter?.title ?? "", "heart.text.square", VelaTheme.recovery),
        ]
    }

    var body: some View {
        VelaAppleScreen {
            // ── Readiness Hero
            readinessHero
                .appleSectionSpacing()

            // ── Metric Cards (horizontal row)
            VelaAppleSectionHeader(title: "Key Metrics")
            metricRow
                .appleSectionSpacing()

            // ── Today's Plan
            VelaAppleSectionHeader(
                title: "Today's Plan",
                subtitle: "Adapted from your recovery profile"
            )
            todayPlanList
                .appleSectionSpacing()

            // ── Coach Insight
            coachInsight
        }
    }

    // MARK: - Readiness Hero

    private var readinessHero: some View {
        HStack(alignment: .center, spacing: 24) {
            VelaAppleScoreRing(
                score: readinessScore,
                color: ringColor,
                size: 130,
                lineWidth: 8,
                label: "Ready"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(greeting)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(readinessMessage)
                    .font(VelaTheme.sectionTitle)
                    .foregroundStyle(VelaTheme.onSurface)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    VelaAppleStatusBadge(
                        label: "HRV \(hrvValue)",
                        systemImage: "waveform.path.ecg",
                        tint: VelaTheme.recovery
                    )
                    VelaAppleStatusBadge(
                        label: "RHR \(rhrValue)",
                        systemImage: "heart.fill",
                        tint: VelaTheme.accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .appleHeroCard(accent: ringColor)
    }

    // MARK: - Metric Row

    private var metricRow: some View {
        HStack(spacing: 10) {
            miniMetric("Sleep", "\(Int(sleepScore))%", "moon.zzz.fill", VelaTheme.sleep)
            miniMetric("Strain", "\(Int(strainScore))", "figure.run", VelaTheme.strain)
            miniMetric("Energy", "\(Int(energyScore))%", "bolt.fill", VelaTheme.energy)
            miniMetric("Recovery", "\(Int(recoveryScore))", "heart.fill", VelaTheme.recovery)
        }
    }

    private func miniMetric(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.10)))
            Text(value)
                .font(.system(.headline, design: .default).bold())
                .foregroundStyle(VelaTheme.onSurface)
                .monospacedDigit()
            Text(title)
                .font(VelaTheme.microFont)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VelaTheme.spaceSM)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    // MARK: - Today's Plan

    private var todayPlanList: some View {
        VStack(spacing: 10) {
            ForEach(Array(planItems.enumerated()), id: \.offset) { _, item in
                planRow(item.0, item.1, item.2, item.3)
            }
        }
    }

    private func planRow(_ title: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.10)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(subtitle)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(VelaTheme.spaceLG)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    // MARK: - Coach Insight

    private var coachInsight: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(VelaTheme.accent)
                Text("Coach Insight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.accent)
                    .textCase(.uppercase)
                    .tracking(1.0)
            }

            Text("Your HRV is trending up and resting heart rate is stable. Today is an ideal day for a Zone 2 endurance session — your recovery capacity has headroom. Avoid high-intensity intervals until sleep debt is cleared.")
                .font(VelaTheme.bodyFont)
                .foregroundStyle(VelaTheme.onSurface)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            VelaApplePillButton(title: "Ask Coach More", systemImage: "bubble.left.fill", role: .secondary) {
                VelaAppState.shared.routeToCoach(question: coachQuestion)
            }
        }
        .appleCard()
    }

    // MARK: - Computed

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return L10n.t("Good morning", "早上好")
        case 12..<17: return L10n.t("Good afternoon", "下午好")
        default: return L10n.t("Good evening", "晚上好")
        }
    }

    private var coachQuestion: String {
        let plan = DailyPlanEngine.recommendation(for: dashboard)
        return plan.coachQuestion
    }

    private var ringColor: Color {
        if readinessScore >= 75 { return VelaTheme.recovery }
        if readinessScore >= 50 { return VelaTheme.energy }
        return VelaTheme.stress
    }

    private var readinessMessage: String {
        if readinessScore >= 80 { return "Your body is ready.\nRecovery capacity is high." }
        if readinessScore >= 60 { return "Steady state.\nGood day for controlled effort." }
        return "Take it easy.\nFocus on recovery today."
    }
}
