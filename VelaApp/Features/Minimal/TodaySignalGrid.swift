import SwiftUI

struct TodaySignalGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: TodayExperienceModel
    let freshness: DataFreshness
    let accentColor: (DailyPlanAccent) -> Color

    private var liveStateCards: [TodayExperienceSignalCard] {
        let ids = ["stress", "energy"]
        return ids.compactMap { id in model.signalCards.first(where: { $0.id == id }) }
    }

    var body: some View {
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("压力和能量")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                DataFreshnessIndicator(freshness: freshness)
            }

            Text("查看你的身体如何响应今天的活动与恢复。")
                .font(VelaTheme.footnote())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(2)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        ForEach(liveStateCards) { card in
                            liveStateSignalLink(card)
                        }
                    }
                } else {
                    HStack(spacing: 10) {
                        ForEach(liveStateCards) { card in
                            liveStateSignalLink(card)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func liveStateSignalLink(_ card: TodayExperienceSignalCard) -> some View {
        Group {
            if let metric = detailMetric(for: card.id) {
                NavigationLink {
                    VelaMetricDetailView(metric: metric)
                } label: {
                    liveStateSignalCard(card)
                }
            } else {
                liveStateSignalCard(card)
            }
        }
        .buttonStyle(.cardPress)
        .accessibilityHint("查看\(card.title)评分依据、个人趋势和建议")
    }

    private func liveStateSignalCard(_ card: TodayExperienceSignalCard) -> some View {
        let accent = accentColor(card.accent)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(VelaTheme.caption1().weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(card.directionLabel)
                        .font(VelaTheme.caption2().weight(.medium))
                        .foregroundStyle(accent)
                }
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(card.value)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                        .monospacedDigit()
                    if card.value != "--" {
                        Text("/100")
                            .font(VelaTheme.caption2().weight(.semibold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    Image(systemName: "chevron.right")
                        .font(VelaTheme.caption2().weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                }
            }

            if card.trend.count > 1 {
                TodayMiniSparkline(values: card.trend, color: accent)
                    .frame(height: 24)
            } else {
                Capsule()
                    .fill(VelaTheme.borderSoft)
                    .frame(height: 2)
                    .padding(.vertical, 11)
                    .accessibilityHidden(true)
            }

            Text(localizedReason(card.subtitle))
                .font(VelaTheme.caption2())
                .lineLimit(2)
                .foregroundStyle(VelaTheme.fg2)

            HStack(spacing: 6) {
                scoreEvidenceChip(card.confidenceLabel, accent: accent)
                scoreEvidenceChip(card.coverageLabel, accent: accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.14), lineWidth: 0.75)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title)，\(card.value)，\(card.directionLabel)，\(card.confidenceLabel)，\(card.coverageLabel)")
    }

    private func scoreEvidenceChip(_ label: String, accent: Color) -> some View {
        Text(label)
            .font(VelaTheme.caption2().weight(.semibold))
            .foregroundStyle(VelaTheme.fg2)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.08))
            )
    }

    private func detailMetric(for cardID: String) -> VelaMetricDetailView.MetricType? {
        switch cardID {
        case "recovery": return .recovery
        case "sleep": return .sleep
        case "strain": return .strain
        case "stress": return .stress
        case "energy": return .energy
        default: return nil
        }
    }

    private func metricDomain(for cardID: String) -> VelaMetricDomain {
        switch cardID {
        case "recovery": .recovery
        case "sleep": .sleep
        case "strain": .strain
        case "stress": .stress
        case "energy": .energy
        default: .neutral
        }
    }
}

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
                    with: .color(VelaTheme.border),
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

            var closedPath = path
            closedPath.addLine(to: CGPoint(x: size.width, y: size.height))
            closedPath.addLine(to: CGPoint(x: 0, y: size.height))
            closedPath.closeSubpath()

            let fillGradient = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [color.opacity(0.24), color.opacity(0.01)]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
            context.fill(closedPath, with: fillGradient)

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )

            if let lastPoint = points.last {
                context.fill(
                    Path(ellipseIn: CGRect(x: lastPoint.x - 3, y: lastPoint.y - 3, width: 6, height: 6)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}
