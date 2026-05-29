import SwiftUI

// MARK: - VelaAppleTrainingView — Apple-style Training Calendar
// Weekly view + adaptive vs original comparison + upcoming sessions

struct VelaMinimalFitnessView: View {
    @State private var strainScore: Double = 65
    @State private var strainRange: ClosedRange<Int> = 55...85

    private let weekDays = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
    private let weekData: [(String, Bool, String)] = [
        ("Mon", true,  "Zone 2 · 45m"), ("Tue", true,  "Strength · 30m"),
        ("Wed", false, "Rest"),          ("Thu", true,  "Intervals · 25m"),
        ("Fri", true,  "Tempo · 40m"),   ("Sat", false, "Easy Walk"),
        ("Sun", true,  "Long Run · 60m")
    ]

    private let upcomingSessions: [(String, String, String, Color)] = [
        ("Tomorrow", "Zone 2 Run", "45 min · HR 130–145 · Low impact", VelaTheme.recovery),
        ("Fri 30", "Tempo Run", "40 min · HR 155–168 · Moderate effort", VelaTheme.strain),
        ("Sun 1", "Long Run", "60 min · HR 140–155 · Endurance", VelaTheme.accent)
    ]

    private let adjustments: [(String, String)] = [
        ("Today's Intervals", "Reduced from 6×400m → 4×400m based on HRV decline"),
        ("Thu Tempo", "Pace target eased 5s/km after sleep score < 70"),
        ("Sun Long Run", "Extended +15 min — recovery trending up")
    ]

    var body: some View {
        VelaMinimalScreen {
            // ── Strain Hero
            strainHero
                .sectionSpacing()

            // ── Week Calendar
            VelaMinimalSectionHeader(title: "This Week")
            weekCalendar
                .sectionSpacing()

            // ── Adaptive Adjustments
            VelaMinimalSectionHeader(
                title: "Adaptive Adjustments",
                subtitle: "Vela's suggested changes based on your recovery signals"
            )
            adjustmentsList
                .sectionSpacing()

            // ── Upcoming Sessions
            VelaMinimalSectionHeader(title: "Upcoming")
            upcomingList
        }
    }

    // MARK: - Strain Hero

    private var strainHero: some View {
        HStack(alignment: .center, spacing: 20) {
            VelaMinimalScoreRing(
                score: strainScore,
                color: VelaTheme.strain,
                size: 110,
                lineWidth: 8,
                label: "Strain"
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("TRAINING WINDOW")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .tracking(1.2)

                Text("\(strainRange.lowerBound)–\(strainRange.upperBound)")
                    .font(VelaTheme.heroMetric)
                    .foregroundStyle(VelaTheme.onSurface)
                    .monospacedDigit()

                VelaMinimalStatusBadge(
                    label: "Optimal",
                    systemImage: "checkmark.circle.fill",
                    tint: VelaTheme.recovery
                )

                Text("Current strain is inside the recommended window. Keep the next session controlled and purposeful.")
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.strain)
    }

    // MARK: - Week Calendar

    private var weekCalendar: some View {
        HStack(spacing: 6) {
            ForEach(Array(weekData.enumerated()), id: \.offset) { idx, entry in
                let (day, active, detail) = entry
                VStack(spacing: 6) {
                    Text(day)
                        .font(VelaTheme.microFont.weight(.semibold))
                        .foregroundStyle(VelaTheme.onSurfaceVariant)

                    ZStack {
                        Circle()
                            .fill(active ? VelaTheme.accent : VelaTheme.surface)
                            .frame(width: 36, height: 36)
                        if active {
                            Circle()
                                .stroke(VelaTheme.accent.opacity(0.2), lineWidth: 2)
                                .frame(width: 44, height: 44)
                        }
                        Text(detail.prefix(3))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(active ? .white : VelaTheme.muted)
                    }

                    Text(detail)
                        .font(.system(size: 8))
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
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

    // MARK: - Adjustments List

    private var adjustmentsList: some View {
        VStack(spacing: 10) {
            ForEach(Array(adjustments.enumerated()), id: \.offset) { _, adj in
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.energy)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(VelaTheme.energy.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(adj.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text(adj.1)
                            .font(VelaTheme.captionFont)
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(VelaTheme.spaceSM)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusSM, style: .continuous)
                        .fill(VelaTheme.energyContainer.opacity(0.3))
                )
            }
        }
    }

    // MARK: - Upcoming Sessions

    private var upcomingList: some View {
        VStack(spacing: 10) {
            ForEach(Array(upcomingSessions.enumerated()), id: \.offset) { _, s in
                HStack(spacing: 14) {
                    VStack(spacing: 2) {
                        Text(s.0.components(separatedBy: " ").first ?? "")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(s.3)
                        Text(s.0.components(separatedBy: " ").last ?? "")
                            .font(VelaTheme.microFont)
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                    }
                    .frame(width: 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.1)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text(s.2)
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
        }
    }
}
