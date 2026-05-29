import SwiftUI

// MARK: - Apple-Style Reusable Components
// Uses VelaTheme tokens. Drop-in replacement for VelaDesignSystem / VelaMinimalComponents.

// MARK: - Apple Background

struct VelaAppleBackground: View {
    var body: some View {
        VelaTheme.background.ignoresSafeArea()
    }
}

// MARK: - View Modifiers (Apple style)

extension View {
    /// Apple-style card: white surface, hairline border, minimal shadow
    func appleCard(padding: CGFloat = VelaTheme.spaceLG, radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
            .shadow(color: VelaTheme.cardShadowColor, radius: 2, y: 1)
    }

    /// Hero card with subtle accent tint
    func appleHeroCard(accent: Color = VelaTheme.accent, padding: CGFloat = VelaTheme.spaceLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }

    /// Frosted glass surface — Apple's signature
    func appleFrosted(radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Section spacing
    func appleSectionSpacing() -> some View {
        self.padding(.bottom, VelaTheme.sectionGap)
    }
}

// MARK: - Apple Screen Scaffold

struct VelaAppleScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VelaAppleBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: VelaTheme.spaceLG) {
                    content()
                }
                .padding(.horizontal, VelaTheme.screenPadding)
                .padding(.top, VelaTheme.spaceLG)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Section Header

struct VelaAppleSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: VelaTheme.spaceXS) {
                Text(title)
                    .font(VelaTheme.sectionTitle)
                    .foregroundStyle(VelaTheme.onSurface)
                if let subtitle {
                    Text(subtitle)
                        .font(VelaTheme.captionFont)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.accent)
            }
        }
        .padding(.top, VelaTheme.spaceSM)
    }
}

// MARK: - Apple Pill Button

struct VelaApplePillButton: View {
    let title: String
    var systemImage: String? = nil
    var role: PillRole = .primary
    var action: () -> Void

    enum PillRole {
        case primary, secondary, ghost
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(backgroundShape)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch role {
        case .primary:
            Capsule(style: .continuous)
                .fill(VelaTheme.accent)
        case .secondary:
            Capsule(style: .continuous)
                .fill(VelaTheme.surface)
                .overlay(Capsule(style: .continuous).stroke(VelaTheme.outline, lineWidth: 0.5))
        case .ghost:
            Capsule(style: .continuous)
                .fill(Color.clear)
        }
    }
}

// MARK: - Apple Metric Pill

struct VelaAppleMetricPill: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: VelaTheme.spaceSM) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VelaTheme.microFont.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelaTheme.onSurface)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, VelaTheme.spaceSM)
        .padding(.vertical, VelaTheme.spaceXS)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.15), lineWidth: 0.5))
    }
}

// MARK: - Status Badge

struct VelaAppleStatusBadge: View {
    let label: String
    var systemImage: String? = nil
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
    }
}

// MARK: - Inline Alert

struct VelaAppleInlineAlert: View {
    let title: String
    let message: String
    var systemImage: String = "info.circle.fill"
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: VelaTheme.spaceSM) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(message)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VelaTheme.spaceSM)
        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSM, style: .continuous).fill(tint.opacity(0.08)))
    }
}

// MARK: - Score Ring (Apple style)

struct VelaAppleScoreRing: View {
    let score: Double
    let color: Color
    var size: CGFloat = 90
    var lineWidth: CGFloat = 6
    var label: String? = nil

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(VelaTheme.outline, lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 1.2, dampingFraction: 0.72), value: animatedProgress)

            VStack(spacing: 2) {
                Text("\(Int(score.rounded()))")
                    .font(size >= 100 ? VelaTheme.heroMetric : VelaTheme.metricValue)
                    .foregroundStyle(VelaTheme.onSurface)
                    .monospacedDigit()
                if let label {
                    Text(label)
                        .font(VelaTheme.microFont)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear { animatedProgress = score / 100.0 }
    }
}

// MARK: - Apple Tab

enum VelaAppleTab: Int, CaseIterable, Identifiable {
    case today, training, insights, settings

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today:     return "Today"
        case .training:  return "Training"
        case .insights:  return "Insights"
        case .settings:  return "You"
        }
    }

    var icon: String {
        switch self {
        case .today:     return "square.grid.2x2"
        case .training:  return "figure.run"
        case .insights:  return "chart.bar.fill"
        case .settings:  return "person.crop.circle"
        }
    }
}

// MARK: - Apple Tab Bar

struct VelaAppleTabBar: View {
    @Binding var selectedTab: VelaAppleTab
    var coachAction: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VelaAppleTab.allCases) { tab in
                tabButton(tab)
            }

            // Center + button — Coach quick access
            Button(action: coachAction) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VelaTheme.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        .overlay(Capsule(style: .continuous).stroke(VelaTheme.outline, lineWidth: 0.3))
        .shadow(color: .black.opacity(0.06), radius: 16, y: 6)
    }

    private func tabButton(_ tab: VelaAppleTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? "\(tab.icon).fill" : tab.icon)
                    .font(.system(size: 22, weight: .regular))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? VelaTheme.accent : VelaTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Apple Navigation Bar

struct VelaAppleNavBar: View {
    let title: String
    var leading: (() -> AnyView)? = nil
    var trailing: (() -> AnyView)? = nil

    init<L: View, T: View>(
        title: String,
        @ViewBuilder leading: @escaping () -> L = { EmptyView() },
        @ViewBuilder trailing: @escaping () -> T = { EmptyView() }
    ) {
        self.title = title
        self.leading = { AnyView(leading()) }
        self.trailing = { AnyView(trailing()) }
    }

    var body: some View {
        HStack {
            leading?()
                .frame(width: 44, height: 44)
            Spacer()
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.onSurface)
            Spacer()
            trailing?()
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, VelaTheme.screenPadding)
        .frame(height: 44)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VelaTheme.outline)
                .frame(height: 0.5)
        }
    }
}

// MARK: - Apple Empty State

struct VelaAppleEmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "tray"
    var tint: Color = VelaTheme.accent

    var body: some View {
        VStack(spacing: VelaTheme.spaceLG) {
            Image(systemName: systemImage)
                .font(.largeTitle.weight(.medium))
                .foregroundStyle(tint)
                .frame(width: 64, height: 64)
                .background(Circle().fill(tint.opacity(0.10)))
            Text(title)
                .font(VelaTheme.cardTitle)
                .foregroundStyle(VelaTheme.onSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(VelaTheme.captionFont)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VelaTheme.space4XL)
    }
}

// MARK: - Evidence Step (Apple style)

struct VelaAppleEvidenceStep: View {
    let index: Int
    let title: String
    let value: String
    let detail: String
    var tint: Color = VelaTheme.accent
    var isLast: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: VelaTheme.spaceSM) {
            VStack(spacing: 6) {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.10)))
                    .overlay(Circle().stroke(tint.opacity(0.20), lineWidth: 1))
                if !isLast {
                    Rectangle()
                        .fill(VelaTheme.outline)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.onSurface)
                    Spacer()
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
                Text(detail)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Data Quality Row

struct VelaAppleDataQualityRow: View {
    let title: String
    let subtitle: String
    let isAvailable: Bool
    let qualityLabel: String
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: VelaTheme.spaceSM) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isAvailable ? VelaTheme.recovery : VelaTheme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(subtitle)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
            Spacer()
            Text(qualityLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(tint)
        }
        .padding(.vertical, VelaTheme.spaceXS)
    }
}

// MARK: - Coach Command Card

struct VelaAppleCommandCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = VelaTheme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VelaTheme.spaceMD) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.10)))
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
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(VelaTheme.spaceMD)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLowest)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLG, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
