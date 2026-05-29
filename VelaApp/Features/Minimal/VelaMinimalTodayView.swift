import SwiftUI

// MARK: - VelaAppleTodayView — Today's Body Cockpit
// Apple-style: one hero ring + 3 metric cards + coach insight + daily plan

struct VelaMinimalTodayView: View {
    // Mock data — replace with your DashboardViewModel bindings
    @State private var readinessScore: Double = 82
    @State private var sleepScore: Double = 78
    @State private var strainScore: Double = 65
    @State private var energyScore: Double = 71
    @State private var recoveryScore: Double = 84
    @State private var stressScore: Double = 32

    // Today's plan items
    private let planItems = [
        ("Zone 2 Run", "45 min · Keep HR 130–145 bpm", "figure.run", VelaTheme.strain),
        ("Foam Roll + Stretch", "15 min · Focus on hamstrings", "figure.strengthtraining.traditional", VelaTheme.recovery),
        ("Early Wind-down", "22:00 · No screens, read 20 min", "moon.stars.fill", VelaTheme.sleep)
    ]

    var body: some View {
        VelaMinimalScreen {
            // ── Readiness Hero
            readinessHero
                .sectionSpacing()

            // ── Metric Cards (horizontal row)
            VelaMinimalSectionHeader(title: "Key Metrics")
            metricRow
                .sectionSpacing()

            // ── Today's Plan
            VelaMinimalSectionHeader(
                title: "Today's Plan",
                subtitle: "Adapted from your recovery profile"
            )
            todayPlanList
                .sectionSpacing()

            // ── Coach Insight
            coachInsight
        }
    }

    // MARK: - Readiness Hero

    private var readinessHero: some View {
        HStack(alignment: .center, spacing: 24) {
            VelaMinimalScoreRing(
                score: readinessScore,
                color: ringColor,
                size: 130,
                lineWidth: 8,
                label: "Ready"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Good morning")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(readinessMessage)
                    .font(VelaTheme.sectionTitle)
                    .foregroundStyle(VelaTheme.onSurface)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    VelaMinimalStatusBadge(
                        label: "HRV 48ms",
                        systemImage: "waveform.path.ecg",
                        tint: VelaTheme.recovery
                    )
                    VelaMinimalStatusBadge(
                        label: "RHR 52",
                        systemImage: "heart.fill",
                        tint: VelaTheme.accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: ringColor)
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

            VelaMinimalPillButton(title: "Ask Coach More", systemImage: "bubble.left.fill", role: .secondary) {}
        }
        .cardSurface()
    }

    // MARK: - Computed

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
