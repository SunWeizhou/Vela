import Charts
import SwiftUI

struct DetailScreenScaffold<Hero: View, Content: View>: View {
    let title: String
    let subtitle: String
    var showDateNavigation: Bool = false
    @ViewBuilder let hero: Hero
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        SectionHeader(title: title, subtitle: subtitle)

                        if showDateNavigation {
                            DateNavigationBar()
                        }

                        hero
                        content
                    }
                    .padding(VelaTheme.screenPadding)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }
            }
        }
    }
}

struct MetricRowItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    var tint: Color = VelaTheme.accent
}

struct MetricRow: View {
    let items: [MetricRowItem]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)

                    Text(item.value)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                        .fill(VelaTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                        )
                )
            }
        }
    }
}

struct PlaceholderInsightCard: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(VelaTheme.accent.opacity(0.7))
                    .frame(width: 3, height: 16)
                    .cornerRadius(1.5)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
            }

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

struct VelaIntelligenceMarquee: View {
    let tint: Color
    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(VelaTheme.subtleFill)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.08),
                                    tint.opacity(0.65),
                                    VelaTheme.sleep.opacity(0.50),
                                    tint.opacity(0.08)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(80, geo.size.width * 0.42))
                        .offset(x: animate ? geo.size.width : -geo.size.width * 0.45)
                }
                .clipShape(Capsule(style: .continuous))
            }
            .frame(height: 7)

            Text(L10n.t("Live analysis", "实时分析"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.45).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct MetricActionCard: View {
    let title: String
    let bodyText: String
    let actionTitle: String
    let systemImage: String
    let tint: Color
    let coachQuestion: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                }
            }

            VelaIntelligenceMarquee(tint: tint)

            Button {
                VelaAppState.shared.routeToCoach(question: coachQuestion)
            } label: {
                Label(actionTitle, systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - Bevel Health-inspired Baseline Range Gauge
struct VelaRangeBar: View {
    let label: String
    let todayValue: Double?
    let baselineValue: Double?
    let isLowerBetter: Bool
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                Spacer()
                if let today = todayValue {
                    Text("\(Int(today))\(unit)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                } else {
                    Text("--")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }

            if let today = todayValue, let baseline = baselineValue, baseline > 0 {
                let minScale = 0.5
                let maxScale = 1.5
                let scaleRange = maxScale - minScale
                let todayRatio = (today / baseline - minScale) / scaleRange
                let clampedTodayRatio = min(max(todayRatio, 0.05), 0.95)

                let normalMinRatio = (0.85 - minScale) / scaleRange
                let normalMaxRatio = (1.15 - minScale) / scaleRange

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: max(4, (normalMaxRatio - normalMinRatio) * geo.size.width), height: 4)
                            .offset(x: normalMinRatio * geo.size.width)

                        Rectangle()
                            .fill(VelaTheme.mutedText.opacity(0.3))
                            .frame(width: 1, height: 6)
                            .offset(x: 0.5 * geo.size.width)

                        let deviationPercent = ((today - baseline) / baseline) * 100
                        let isPositiveDeviation = isLowerBetter ? (today <= baseline) : (today >= baseline)
                        let dotColor = isPositiveDeviation ? VelaTheme.recovery : (abs(deviationPercent) > 15 ? VelaTheme.stress : VelaTheme.energy)

                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: dotColor.opacity(0.4), radius: 2)
                            .offset(x: clampedTodayRatio * geo.size.width - 3, y: -1)
                    }
                }
                .frame(height: 4)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 4)
            }
        }
    }
}
