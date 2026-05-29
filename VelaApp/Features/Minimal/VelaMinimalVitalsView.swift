import SwiftUI

// MARK: - VelaAppleInsightsView — Insights Hub
// Segmented control switching between Data Coverage / Evidence Chain / Memory Inbox / Trust Center

struct VelaMinimalVitalsView: View {
    @State private var selectedSegment = 0
    private let segments = ["Coverage", "Evidence", "Memory", "Trust"]

    var body: some View {
        VelaMinimalScreen {
            // Segment Picker
            Picker("", selection: $selectedSegment) {
                ForEach(0..<segments.count, id: \.self) { i in
                    Text(segments[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, VelaTheme.spaceSM)

            switch selectedSegment {
            case 0: dataCoverageContent
            case 1: evidenceChainContent
            case 2: memoryInboxContent
            case 3: trustCenterContent
            default: EmptyView()
            }
        }
    }

    // MARK: - 1. Data Coverage

    private var dataCoverageContent: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
            coverageHero

            VelaMinimalSectionHeader(title: "Signal Quality")

            VelaAppleDataQualityRow(title: "Heart Rate Variability", subtitle: "Apple Watch · Last 7 days", isAvailable: true, qualityLabel: "98%", tint: VelaTheme.recovery)
            VelaAppleDataQualityRow(title: "Resting Heart Rate", subtitle: "Apple Watch · Last 7 days", isAvailable: true, qualityLabel: "100%", tint: VelaTheme.recovery)
            VelaAppleDataQualityRow(title: "Sleep Stages", subtitle: "Apple Watch · Last 7 days", isAvailable: true, qualityLabel: "92%", tint: VelaTheme.recovery)
            VelaAppleDataQualityRow(title: "Blood Oxygen", subtitle: "Apple Watch · Spotty", isAvailable: true, qualityLabel: "64%", tint: VelaTheme.energy)
            VelaAppleDataQualityRow(title: "Body Temperature", subtitle: "Apple Watch Series 9+", isAvailable: false, qualityLabel: "N/A", tint: VelaTheme.muted)
            VelaAppleDataQualityRow(title: "Blood Glucose", subtitle: "CGM not paired", isAvailable: false, qualityLabel: "Missing", tint: VelaTheme.muted)

            VelaAppleInlineAlert(
                title: "Coverage Summary",
                message: "85% of key signals available. Vela's recommendations are high-confidence for recovery and training, moderate for nutrition insights.",
                systemImage: "checkmark.shield.fill",
                tint: VelaTheme.recovery
            )
        }
    }

    private var coverageHero: some View {
        HStack(alignment: .center, spacing: 20) {
            VelaMinimalScoreRing(score: 85, color: VelaTheme.recovery, size: 100, lineWidth: 8, label: "Coverage")

            VStack(alignment: .leading, spacing: 6) {
                Text("DATA COVERAGE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .tracking(1.2)

                Text("High Confidence")
                    .font(VelaTheme.cardTitle)
                    .foregroundStyle(VelaTheme.onSurface)

                Text("Most key health signals are available and fresh. Vela's recommendations are well-supported.")
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.recovery)
    }

    // MARK: - 2. Evidence Chain

    private var evidenceChainContent: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
            VelaMinimalSectionHeader(
                title: "Why This Recommendation?",
                subtitle: "The reasoning path from health signals to today's plan"
            )

            VelaAppleEvidenceStep(
                index: 1,
                title: "Heart Rate Variability",
                value: "48ms (+3)",
                detail: "HRV is trending up over 7 days, indicating increasing parasympathetic activity and recovery capacity.",
                tint: VelaTheme.recovery,
                isLast: false
            )
            VelaAppleEvidenceStep(
                index: 2,
                title: "Resting Heart Rate",
                value: "52bpm (stable)",
                detail: "RHR has remained at baseline for 5 consecutive days. No sign of accumulated fatigue or illness onset.",
                tint: VelaTheme.accent,
                isLast: false
            )
            VelaAppleEvidenceStep(
                index: 3,
                title: "Sleep Quality",
                value: "78/100",
                detail: "Sleep duration 7h12m with 92% efficiency. Deep sleep proportion is adequate but REM could improve.",
                tint: VelaTheme.sleep,
                isLast: false
            )
            VelaAppleEvidenceStep(
                index: 4,
                title: "Training Load (7-day)",
                value: "Moderate",
                detail: "ATL:CTL ratio is 1.1 — within the safe window. Previous session's strain has been absorbed.",
                tint: VelaTheme.strain,
                isLast: true
            )

            VelaAppleInlineAlert(
                title: "Conclusion",
                message: "All four signals converge: today is a green-light day for Zone 2 endurance work. Hold off on high-intensity intervals until REM sleep improves.",
                systemImage: "lightbulb.fill",
                tint: VelaTheme.energy
            )
        }
    }

    // MARK: - 3. Memory Inbox

    private var memoryInboxContent: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
            VelaMinimalSectionHeader(
                title: "Memory Inbox",
                subtitle: "Patterns Vela has noticed. Confirm or reject to train the model."
            )

            memoryProposal(
                title: "Zone 2 Performance Pattern",
                evidence: "Your HR during Zone 2 runs has dropped 4bpm over the last 3 weeks at the same pace.",
                source: "Training History",
                target: "Fitness Profile",
                confidence: "92%"
            )
            memoryProposal(
                title: "Late-Night Eating Impact",
                evidence: "Sleep efficiency drops to 78% on nights you log food after 21:30, vs. 91% otherwise.",
                source: "Journal + Sleep",
                target: "Nutrition Preferences",
                confidence: "85%"
            )
            memoryProposal(
                title: "Monday Recovery Pattern",
                evidence: "HRV is consistently 8-12ms lower on Mondays after weekend long runs. Recovery takes ~36h.",
                source: "Training + Recovery",
                target: "Training Schedule",
                confidence: "78%"
            )
        }
    }

    private func memoryProposal(title: String, evidence: String, source: String, target: String, confidence: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VelaMinimalStatusBadge(label: "Pattern", systemImage: "brain.head.profile", tint: VelaTheme.accent)
                Spacer()
                Text("\(confidence) confidence")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.energy)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.onSurface)
            Text(evidence)
                .font(VelaTheme.captionFont)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                VelaAppleMetricPill(title: "Source", value: source, systemImage: "point.3.connected.trianglepath.dotted", tint: VelaTheme.sleep)
                VelaAppleMetricPill(title: "Target", value: target, systemImage: "doc.text", tint: VelaTheme.recovery)
            }

            HStack(spacing: 10) {
                VelaMinimalPillButton(title: "Confirm", systemImage: "checkmark", role: .primary) {}
                VelaMinimalPillButton(title: "Reject", systemImage: "xmark", role: .secondary) {}
            }
        }
        .cardSurface()
    }

    // MARK: - 4. Trust Center

    private var trustCenterContent: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
            VelaMinimalSectionHeader(
                title: "Agent Trust Log",
                subtitle: "Every recommendation Vela made, and why. Immutable audit trail."
            )

            ForEach(trustLogItems, id: \.0) { (title, subtitle, status) in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title3)
                        .foregroundStyle(VelaTheme.recovery)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(VelaTheme.recovery.opacity(0.10)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text(subtitle)
                            .font(VelaTheme.captionFont)
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                            .lineLimit(2)
                    }
                    Spacer()
                    VelaMinimalStatusBadge(label: status, tint: VelaTheme.recovery)
                }
                .padding(VelaTheme.spaceSM)
                .cardSurface(radius: VelaTheme.radiusSM)
            }

            VelaAppleInlineAlert(
                title: "Cryptographic Verification",
                message: "All 34 recommendations this week have verified evidence chains. Zero anomalies detected. SHA-256 audit trail is intact.",
                systemImage: "lock.shield.fill",
                tint: VelaTheme.recovery
            )
        }
    }

    private let trustLogItems: [(String, String, String)] = [
        ("Zone 2 recommendation", "Today 07:42 · HRV + RHR + Sleep → Endurance", "Verified"),
        ("Sleep optimization tip", "Yesterday 21:15 · Sleep debt + REM pattern → Wind-down", "Verified"),
        ("Training adjustment", "Yesterday 06:30 · Strain + Recovery → Reduce intervals", "Verified"),
        ("Nutrition suggestion", "Jan 3 12:10 · Journal + Training load → Protein timing", "Verified")
    ]
}
