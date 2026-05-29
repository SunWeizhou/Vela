import SwiftUI

// MARK: - Apple-Style Reusable Components
// Uses VelaTheme tokens. Drop-in replacement for VelaDesignSystem / VelaMinimalComponents.

// MARK: - Apple Background

struct VelaBackground: View {
    var body: some View {
        VelaTheme.background.ignoresSafeArea()
    }
}

// MARK: - View Modifiers (Apple style)

extension View {
    /// Apple-style card: white surface, hairline border, minimal shadow
    func cardSurface(padding: CGFloat = VelaTheme.spaceLG, radius: CGFloat = VelaTheme.radiusLG) -> some View {
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
    func heroCardSurface(accent: Color = VelaTheme.accent, padding: CGFloat = VelaTheme.spaceLG) -> some View {
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
    func glassEffect(radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Section spacing
    func sectionSpacing() -> some View {
        self.padding(.bottom, VelaTheme.sectionGap)
    }
}

// MARK: - Apple Screen Scaffold

struct VelaMinimalScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VelaBackground()
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

struct VelaMinimalSectionHeader: View {
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

struct VelaMinimalPillButton: View {
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

struct VelaMinimalStatusBadge: View {
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

struct VelaMinimalScoreRing: View {
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

enum VelaMinimalTab: Int, CaseIterable, Identifiable {
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

struct VelaMinimalFloatingTabBar: View {
    @Binding var selectedTab: VelaMinimalTab
    var coachAction: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VelaMinimalTab.allCases) { tab in
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

    private func tabButton(_ tab: VelaMinimalTab) -> some View {
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

struct VelaMinimalNavBar: View {
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



// MARK: - Backward Compat (from old VelaDesignSystem)

struct VelaHeroSurface<Content: View>: View {
    var tint: Color = VelaTheme.accent
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(VelaTheme.spaceLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLow)
                    .shadow(color: VelaTheme.cardShadowColor, radius: 14, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

struct VelaInlineAlert: View {
    let title: String
    let message: String
    var systemImage = "info.circle.fill"
    var tint: Color = VelaTheme.accent
    var body: some View {
        HStack(alignment: .top, spacing: VelaTheme.spaceSM) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: VelaTheme.spaceXS) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VelaTheme.spaceSM)
        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSM, style: .continuous).fill(tint.opacity(0.10)))
    }
}

struct VelaMemoryProposalCard: View {
    let proposal: MemoryEventRecord
    var onAccept: () -> Void
    var onReject: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceSM) {
            HStack {
                Text(proposal.memoryType.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.accent)
                Spacer()
                Text("\(Int((proposal.confidence * 100).rounded()))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.energy)
            }
            Text(proposal.content)
                .font(VelaTheme.bodyFont)
                .foregroundStyle(VelaTheme.onSurface)
                .lineLimit(4)
            HStack(spacing: 12) {
                Button(action: onAccept) {
                    Label("Accept", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(VelaTheme.recovery)
                }
                Button(action: onReject) {
                    Label("Dismiss", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(VelaTheme.spaceLG)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }
}


struct VelaGlassCard<Content: View>: View {
    var padding: CGFloat = VelaTheme.spaceMD
    var cornerRadius: CGFloat = VelaTheme.radiusCard
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VelaTheme.surface)
                    .shadow(color: VelaTheme.cardShadowColor, radius: 8, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

struct VelaMetricPill: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent
    var body: some View {
        HStack(spacing: VelaTheme.spaceXS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.onSurface)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, VelaTheme.spaceXS)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
    }
}

struct VelaStatusBadge: View {
    let label: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent
    var body: some View {
        HStack(spacing: VelaTheme.spaceXXS) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, VelaTheme.spaceXS)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
    }
}

struct VelaEmptyState: View {
    let title: String
    let message: String
    var systemImage = "tray"
    var tint: Color = VelaTheme.accent
    var body: some View {
        VStack(spacing: VelaTheme.spaceMD) {
            Image(systemName: systemImage)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(Circle().fill(tint.opacity(0.12)))
            Text(title)
                .font(.headline)
                .foregroundStyle(VelaTheme.onSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
        }
        .padding(VelaTheme.spaceXL)
        .frame(maxWidth: .infinity)
    }
}


struct VelaFreshnessBadge: View {
        let freshness: DataFreshness

        var body: some View {
                VelaStatusBadge(label: label, systemImage: "clock.fill", tint: VelaSemanticColors.color(for: freshness))
        }

        private var label: String {
                switch freshness {
                case .live: return AppLanguage.stored.isChinese ? "实时" : "Live"
                case .today: return AppLanguage.stored.isChinese ? "今日" : "Today"
                case .recent: return AppLanguage.stored.isChinese ? "近期" : "Recent"
                case .stale: return AppLanguage.stored.isChinese ? "陈旧" : "Stale"
                case .missing: return AppLanguage.stored.isChinese ? "缺失" : "Missing"
                }
        }
}

struct VelaDataQualityRow: View {
        let title: String
        let subtitle: String
        let freshness: DataFreshness
        let qualityLabel: String
        var tint: Color = VelaTheme.primary

        var body: some View {
                HStack(spacing: VelaTheme.spaceSM) {
                        Image(systemName: freshness == .missing ? "xmark.circle.fill" : "checkmark.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VelaSemanticColors.color(for: freshness))
                                .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(VelaTheme.onSurface)
                                Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                                        .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: VelaTheme.spaceXS)
                        VStack(alignment: .trailing, spacing: VelaTheme.spaceXXS) {
                                VelaFreshnessBadge(freshness: freshness)
                                Text(qualityLabel)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(tint)
                        }
                }
                .padding(.vertical, VelaTheme.spaceXS)
        }
}

enum VelaSemanticColors {
    static func color(for category: String) -> Color {
        switch category {
        case "recovery": return VelaTheme.recovery
        case "sleep": return VelaTheme.sleep
        case "strain", "training": return VelaTheme.strain
        case "stress": return VelaTheme.stress
        case "energy": return VelaTheme.energy
        case "gait", "cardio": return VelaTheme.primary
        default: return VelaTheme.primary
        }
    }

    static func color(for confidence: DataConfidence) -> Color {
        switch confidence {
        case .high: return VelaTheme.recovery
        case .medium: return VelaTheme.energy
        case .low: return VelaTheme.strain
        case .unavailable: return VelaTheme.muted
        }
    }

    static func color(for freshness: DataFreshness) -> Color {
        switch freshness {
        case .live, .today: return VelaTheme.recovery
        case .recent: return VelaTheme.primary
        case .stale: return VelaTheme.strain
        case .missing: return VelaTheme.muted
        }
    }
}

// CoachView compat types
struct VelaSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: VelaTheme.spaceXS) {
            Text(title)
                .font(VelaTheme.sectionTitle)
                .foregroundStyle(VelaTheme.onSurface)
            if let subtitle {
                Text(subtitle)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
        }
        .padding(.bottom, VelaTheme.spaceSM)
    }
}

struct VelaCoachCommandCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = VelaTheme.accent
    var action: (() -> Void)? = nil
    @State private var isPressed = false
    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: VelaTheme.spaceSM) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
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
                        .lineLimit(2)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(VelaTheme.spaceLG)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }
}
