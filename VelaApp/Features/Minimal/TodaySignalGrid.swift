import SwiftUI

// MARK: - TodaySignalGrid
// Stress and Energy displayed as horizontal bar gauges for intuitive at-a-glance reading.
// Design: horizontal progress bar (0–100) + numeric value + 7-day sparkline trend below.

struct TodaySignalGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let model: TodayExperienceModel
    let freshness: DataFreshness
    let accentColor: (DailyPlanAccent) -> Color

    private var liveStateCards: [TodayExperienceSignalCard] {
        let ids = ["stress", "energy"]
        return ids.compactMap { id in model.signalCards.first(where: { $0.id == id }) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            HStack {
                Text("压力和能量")
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                DataFreshnessIndicator(freshness: freshness)
            }

            // Two gauge cards side by side (or stacked under accessibility sizes)
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ForEach(liveStateCards) { card in
                            gaugeSignalLink(card)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ForEach(liveStateCards) { card in
                            gaugeSignalLink(card)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Navigation wrapper
    private func gaugeSignalLink(_ card: TodayExperienceSignalCard) -> some View {
        Group {
            if let metric = detailMetric(for: card.id) {
                NavigationLink {
                    VelaMetricDetailView(metric: metric)
                } label: {
                    gaugeSignalCard(card)
                }
            } else {
                gaugeSignalCard(card)
            }
        }
        .buttonStyle(.cardPress)
        .accessibilityHint("查看\(card.title)评分依据、个人趋势和建议")
    }

    // MARK: - Horizontal bar gauge card
    private func gaugeSignalCard(_ card: TodayExperienceSignalCard) -> some View {
        let accent = accentColor(card.accent)
        let scoreValue: Double? = card.value == "--" ? nil : Double(card.value)
        let progress = scoreValue.map { min(1.0, max(0.0, $0 / 100.0)) } ?? 0.0
        let iconName = card.id == "stress" ? "waveform.path.ecg" : "bolt.batteryblock.fill"

        return VStack(alignment: .leading, spacing: 10) {
            // Row 1: Icon squircle + Title + score value
            HStack(alignment: .center) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent.opacity(0.12))
                    Image(systemName: iconName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                }
                .frame(width: 20, height: 20)

                Text(card.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                Spacer(minLength: 4)

                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(card.value == "--" ? "--" : card.value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .monospacedDigit()
                    if card.value != "--" {
                        Text("/100")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.4))
                        .padding(.leading, 2)
                }
            }

            // Row 2: Horizontal bar gauge with gradient fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(VelaTheme.rhythmMist)
                        .frame(height: 6)

                    // Fill
                    if scoreValue != nil {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.7), accent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, geo.size.width * CGFloat(progress)), height: 6)
                            .animation(
                                reduceMotion ? .none : .spring(response: 1.0, dampingFraction: 0.85),
                                value: progress
                            )
                    }
                }
            }
            .frame(height: 6)

            // Row 3: Status label + direction
            HStack(spacing: 4) {
                Text(card.directionLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(accent)

                if !card.subtitle.isEmpty {
                    Text("·")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.5))
                    Text(localizedReason(card.subtitle))
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(1)
                }
            }

            // Row 4: 7-day sparkline trend
            if card.trend.count > 1 {
                TodayMiniSparkline(values: card.trend, color: accent)
                    .frame(height: 20)
            } else {
                Capsule()
                    .fill(VelaTheme.rhythmMist)
                    .frame(height: 2)
                    .padding(.vertical, 9)
                    .accessibilityHidden(true)
            }

            // Row 5: Evidence chips
            HStack(spacing: 6) {
                scoreEvidenceChip(card.confidenceLabel, accent: accent)
                scoreEvidenceChip(card.coverageLabel, accent: accent)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title)，\(card.value)，\(card.directionLabel)，\(card.confidenceLabel)，\(card.coverageLabel)")
    }

    // MARK: - Evidence chip
    private func scoreEvidenceChip(_ label: String, accent: Color) -> some View {
        Text(label)
            .font(VelaTheme.caption2().weight(.semibold))
            .foregroundStyle(VelaTheme.rhythmInkSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.08))
            )
    }

    // MARK: - Helpers
    private func detailMetric(for cardID: String) -> VelaMetricDetailView.MetricType? {
        switch cardID {
        case "recovery": return .recovery
        case "sleep":    return .sleep
        case "strain":   return .strain
        case "stress":   return .stress
        case "energy":   return .energy
        default:         return nil
        }
    }

    private func metricDomain(for cardID: String) -> VelaMetricDomain {
        switch cardID {
        case "recovery": .recovery
        case "sleep":    .sleep
        case "strain":   .strain
        case "stress":   .stress
        case "energy":   .energy
        default:         .neutral
        }
    }
}

// MARK: - TodayMiniSparkline
private struct TodayMiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                var placeholder = Path()
                placeholder.move(to: CGPoint(x: 0, y: size.height * 0.5))
                placeholder.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(
                    placeholder,
                    with: .color(color.opacity(0.3)),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [4, 5])
                )
                return
            }

            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 100
            let span = max(maxValue - minValue, 1)
            let stepX = size.width / CGFloat(values.count - 1)

            var points: [CGPoint] = []
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let normalized = (value - minValue) / span
                let y = (size.height * 0.15) + (size.height * 0.70) * (1 - CGFloat(normalized))
                points.append(CGPoint(x: x, y: y))
            }

            var path = Path()
            if points.count == 2 {
                path.move(to: points[0])
                path.addLine(to: points[1])
            } else {
                path.move(to: points[0])
                for i in 0..<(points.count - 1) {
                    let current = points[i]
                    let next = points[i + 1]
                    let control1 = CGPoint(x: current.x + (next.x - current.x) * 0.5, y: current.y)
                    let control2 = CGPoint(x: current.x + (next.x - current.x) * 0.5, y: next.y)
                    path.addCurve(to: next, control1: control1, control2: control2)
                }
            }

            // Area fill
            var closedPath = path
            closedPath.addLine(to: CGPoint(x: size.width, y: size.height))
            closedPath.addLine(to: CGPoint(x: 0, y: size.height))
            closedPath.closeSubpath()
            context.fill(
                closedPath,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.22), color.opacity(0.01)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            // Line
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )

            // End dot
            if let lastPoint = points.last {
                context.fill(
                    Path(ellipseIn: CGRect(x: lastPoint.x - 2.5, y: lastPoint.y - 2.5, width: 5, height: 5)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}
