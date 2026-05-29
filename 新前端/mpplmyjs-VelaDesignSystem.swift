import SwiftUI

// MARK: - Spacing Scale

enum VelaSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

// MARK: - Radius Scale

enum VelaRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let row: CGFloat = 16
    static let card: CGFloat = 20
    static let hero: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Motion Presets

enum VelaMotion {
    static let quick = Animation.spring(response: 0.26, dampingFraction: 0.82)
    static let expand = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let ringFill = Animation.spring(response: 1.2, dampingFraction: 0.72)
}

// MARK: - Semantic Color Resolver

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

// MARK: - VelaBackground

/// Fills the screen with the warm canvas background color.
struct VelaBackground: View {
    var body: some View {
        VelaTheme.background
            .ignoresSafeArea()
    }
}

// MARK: - GlassEffect

struct GlassEffect: ViewModifier {
    var isOverlay: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 0, style: .continuous)
            )
            .background(
                Color(UIColor { traits in
                    if traits.userInterfaceStyle == .dark {
                        let alpha: CGFloat = isOverlay ? 0.35 : 0.55
                        return UIColor(red: 0.110, green: 0.106, blue: 0.094, alpha: alpha)
                    } else {
                        let alpha: CGFloat = isOverlay ? 0.40 : 0.60
                        return UIColor(white: 1.0, alpha: alpha)
                    }
                })
            )
    }
}

// MARK: - Card Surface Modifiers

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(VelaSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLowest.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

struct HeroCardSurface: ViewModifier {
    var accent: Color?

    func body(content: Content) -> some View {
        content
            .padding(VelaSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill((accent ?? Color.clear).opacity(0.06))
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(
                            Color(UIColor { traits in
                                traits.userInterfaceStyle == .dark
                                    ? UIColor(red: 0.110, green: 0.106, blue: 0.094, alpha: 0.55)
                                    : UIColor(white: 1.0, alpha: 0.60)
                            })
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

struct CompactCardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(VelaSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous)
                    .fill(VelaTheme.surfaceContainerLowest.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

// MARK: - View Extensions for Modifiers

extension View {
    func glassEffect(isOverlay: Bool = false) -> some View {
        modifier(GlassEffect(isOverlay: isOverlay))
    }

    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    func heroCardSurface(accent: Color? = nil) -> some View {
        modifier(HeroCardSurface(accent: accent))
    }

    func compactCardSurface() -> some View {
        modifier(CompactCardSurface())
    }

    func leftAccentStrip(_ color: Color) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 3, height: 20),
            alignment: .leading
        )
    }
}

// MARK: - MetricRing

struct MetricRing: View {
    let score: Double
    let color: Color
    var size: CGFloat = 90

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(VelaTheme.outline.opacity(0.20), lineWidth: size <= 60 ? 3 : 4)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(color, style: StrokeStyle(lineWidth: size <= 60 ? 3 : 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(VelaMotion.ringFill, value: animatedProgress)

            VStack(spacing: 2) {
                Text("\(Int(score.rounded()))")
                    .font(size >= 120 ? VelaTheme.heroMetric : VelaTheme.metricValue)
                    .foregroundStyle(VelaTheme.onSurface)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
        }
        .frame(width: size, height: size)
        .onAppear { animatedProgress = score / 100.0 }
    }

    private var label: String {
        AppLanguage.stored.isChinese ? "分" : "Score"
    }
}

// MARK: - StressGauge

struct StressGauge: View {
    let value: Double

    @State private var animatedWidth: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(value.rounded()))/100")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(VelaTheme.onSurface)
                Spacer()
                Text(stressLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VelaTheme.quinary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(VelaTheme.outline.opacity(0.20))
                        .frame(height: 4)
                    Capsule(style: .continuous)
                        .fill(VelaTheme.quinary)
                        .frame(width: geometry.size.width * animatedWidth, height: 4)
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            withAnimation(VelaMotion.ringFill) { animatedWidth = value / 100.0 }
        }
    }

    private var stressLabel: String {
        if value < 30 { return AppLanguage.stored.isChinese ? "低" : "Low" }
        if value < 70 { return AppLanguage.stored.isChinese ? "中等" : "Moderate" }
        return AppLanguage.stored.isChinese ? "高" : "High"
    }
}

// MARK: - EnergyGauge

struct EnergyGauge: View {
    let value: Double

    @State private var animatedWidth: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 4) {
                    if value < 30 {
                        Image(systemName: "battery.25")
                            .font(.caption)
                            .foregroundStyle(VelaTheme.senary)
                    }
                    Text("\(Int(value.rounded()))%")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(VelaTheme.onSurface)
                }
                Spacer()
                Text(energyLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VelaTheme.senary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(VelaTheme.outline.opacity(0.20))
                        .frame(height: 4)
                    Capsule(style: .continuous)
                        .fill(VelaTheme.senary)
                        .frame(width: geometry.size.width * animatedWidth, height: 4)
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            withAnimation(VelaMotion.ringFill) { animatedWidth = value / 100.0 }
        }
    }

    private var energyLabel: String {
        if value >= 70 { return AppLanguage.stored.isChinese ? "充足" : "Charged" }
        if value >= 30 { return AppLanguage.stored.isChinese ? "中等" : "Stable" }
        return AppLanguage.stored.isChinese ? "不足" : "Draining"
    }
}

// MARK: - GlassChip

struct GlassChip: View {
    let text: String
    var icon: String?

    var body: some View {
        HStack(spacing: VelaSpacing.xxs) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, VelaSpacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }
}

// MARK: - VelaScreen

struct VelaScreen<Content: View>: View {
    var showsIndicators = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            VelaBackground()
            ScrollView(showsIndicators: showsIndicators) {
                VStack(alignment: .leading, spacing: VelaSpacing.lg) {
                    content()
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - VelaPageHeader

struct VelaPageHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = VelaTheme.primary

    var body: some View {
        HStack(alignment: .center, spacing: VelaSpacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(tint.opacity(0.12)))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: VelaSpacing.xs) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(VelaTheme.onSurface)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - VelaSectionHeader

struct VelaSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
    }
}

// MARK: - VelaHeroSurface

struct VelaHeroSurface<Content: View>: View {
    var tint: Color = VelaTheme.primary
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(VelaSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(VelaTheme.surfaceContainerLow)
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.085),
                                    VelaTheme.surfaceContainerLow.opacity(0.16),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: VelaTheme.cardShadowColor, radius: 14, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                    .stroke(VelaTheme.outline, lineWidth: 0.5)
            )
    }
}

// MARK: - VelaGlassCard

struct VelaGlassCard<Content: View>: View {
    var padding: CGFloat = VelaSpacing.md
    var cornerRadius: CGFloat = VelaRadius.card
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

// MARK: - VelaMetricPill

struct VelaMetricPill: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = VelaTheme.primary

    var body: some View {
        HStack(spacing: VelaSpacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.onSurface)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, VelaSpacing.sm)
        .padding(.vertical, VelaSpacing.xs)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.18), lineWidth: 0.7))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - VelaStatusBadge

struct VelaStatusBadge: View {
    let label: String
    var systemImage: String?
    var tint: Color = VelaTheme.primary

    var body: some View {
        HStack(spacing: VelaSpacing.xxs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.76)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, VelaSpacing.xs)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.18), lineWidth: 0.7))
    }
}

// MARK: - VelaConfidenceBadge

struct VelaConfidenceBadge: View {
    let confidence: DataConfidence

    var body: some View {
        VelaStatusBadge(
            label: label,
            systemImage: "checkmark.seal.fill",
            tint: VelaSemanticColors.color(for: confidence)
        )
    }

    private var label: String {
        switch confidence {
        case .high: return AppLanguage.stored.isChinese ? "高置信度" : "High confidence"
        case .medium: return AppLanguage.stored.isChinese ? "中等置信度" : "Medium confidence"
        case .low: return AppLanguage.stored.isChinese ? "低置信度" : "Low confidence"
        case .unavailable: return AppLanguage.stored.isChinese ? "置信度不足" : "Confidence unavailable"
        }
    }
}

// MARK: - VelaFreshnessBadge

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

// MARK: - VelaRiskBadge

struct VelaRiskBadge: View {
    let level: RiskLevel

    var body: some View {
        VelaStatusBadge(label: label, systemImage: icon, tint: tint)
    }

    private var label: String {
        switch level {
        case .info: return AppLanguage.stored.isChinese ? "提示" : "Info"
        case .warning: return AppLanguage.stored.isChinese ? "注意" : "Watch"
        case .critical: return AppLanguage.stored.isChinese ? "高风险" : "High risk"
        }
    }

    private var icon: String {
        switch level {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private var tint: Color {
        switch level {
        case .info: return VelaTheme.primary
        case .warning: return VelaTheme.energy
        case .critical: return VelaTheme.stress
        }
    }
}

// MARK: - VelaPrimaryActionButton

struct VelaPrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.onPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .background(Capsule(style: .continuous).fill(VelaTheme.primary))
        .shadow(color: VelaTheme.primary.opacity(0.18), radius: 8, y: 3)
        .buttonStyle(.plain)
    }
}

// MARK: - VelaSecondaryActionButton

struct VelaSecondaryActionButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.onSurface)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .background(Capsule(style: .continuous).fill(VelaTheme.surfaceContainerLow))
        .overlay(Capsule(style: .continuous).stroke(VelaTheme.outline, lineWidth: 0.5))
        .buttonStyle(.plain)
    }
}

// MARK: - VelaInlineAlert

struct VelaInlineAlert: View {
    let title: String
    let message: String
    var systemImage = "info.circle.fill"
    var tint: Color = VelaTheme.primary

    var body: some View {
        HStack(alignment: .top, spacing: VelaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VelaSpacing.sm)
        .background(RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous).stroke(tint.opacity(0.14), lineWidth: 0.7))
    }
}

// MARK: - VelaEmptyState

struct VelaEmptyState: View {
    let title: String
    let message: String
    var systemImage = "tray"
    var tint: Color = VelaTheme.primary

    var body: some View {
        VStack(spacing: VelaSpacing.md) {
            Image(systemName: systemImage)
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 72, height: 72)
                .background(Circle().fill(tint.opacity(0.12)))
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(VelaTheme.onSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(VelaSpacing.xl)
    }
}

// MARK: - VelaDataQualityRow

struct VelaDataQualityRow: View {
    let title: String
    let subtitle: String
    let freshness: DataFreshness
    let qualityLabel: String
    var tint: Color = VelaTheme.primary

    var body: some View {
        HStack(spacing: VelaSpacing.sm) {
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
            Spacer(minLength: VelaSpacing.xs)
            VStack(alignment: .trailing, spacing: VelaSpacing.xxs) {
                VelaFreshnessBadge(freshness: freshness)
                Text(qualityLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(.vertical, VelaSpacing.xs)
    }
}

// MARK: - VelaEvidenceStep

struct VelaEvidenceStep: View {
    let index: Int
    let title: String
    let value: String
    let detail: String
    var tint: Color = VelaTheme.primary
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: VelaSpacing.sm) {
            VStack(spacing: VelaSpacing.xs) {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(VelaTheme.background))
                    .overlay(Circle().stroke(VelaTheme.outline, lineWidth: 1.2))
                if !isLast {
                    Rectangle()
                        .fill(VelaTheme.outline)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: VelaSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
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
                    .font(.caption)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - VelaEvidenceChainView

struct VelaEvidenceChainView: View {
    let items: [EvidenceChainItem]

    var body: some View {
        VStack(alignment: .leading, spacing: VelaSpacing.md) {
            ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                VelaEvidenceStep(
                    index: offset + 1,
                    title: item.metricName,
                    value: item.currentValueFormatted + (item.unit.isEmpty ? "" : " \(item.unit)"),
                    detail: item.interpretation,
                    tint: VelaSemanticColors.color(for: item.metricCategory),
                    isLast: offset == items.count - 1
                )
            }
        }
    }
}

// MARK: - VelaAdaptiveTrainingBanner

struct VelaAdaptiveTrainingBanner: View {
    let title: String
    let reason: String
    var alternative: String?
    var onAccept: () -> Void
    var onKeep: () -> Void

    var body: some View {
        VelaHeroSurface(tint: VelaTheme.energy) {
            VStack(alignment: .leading, spacing: VelaSpacing.md) {
                Label(title, systemImage: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
                if let alternative, !alternative.isEmpty {
                    VelaInlineAlert(
                        title: AppLanguage.stored.isChinese ? "建议替代" : "Suggested alternative",
                        message: alternative,
                        systemImage: "arrow.triangle.swap",
                        tint: VelaTheme.energy
                    )
                }
                HStack(spacing: VelaSpacing.sm) {
                    VelaPrimaryActionButton(title: AppLanguage.stored.isChinese ? "接受调整" : "Accept", systemImage: "checkmark") {
                        onAccept()
                    }
                    VelaSecondaryActionButton(title: AppLanguage.stored.isChinese ? "保留原计划" : "Keep", systemImage: "xmark") {
                        onKeep()
                    }
                }
            }
        }
    }
}

// MARK: - VelaMemoryProposalCard

struct VelaMemoryProposalCard: View {
    let proposal: MemoryEventRecord
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        VelaGlassCard {
            VStack(alignment: .leading, spacing: VelaSpacing.sm) {
                HStack {
                    VelaStatusBadge(label: memoryTypeLabel, systemImage: "brain.head.profile", tint: VelaTheme.primary)
                    Spacer()
                    Text("\(Int((proposal.confidence * 100).rounded()))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.energy)
                }
                Text(proposal.content)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                    .fixedSize(horizontal: false, vertical: true)
                if !proposal.evidence.isEmpty {
                    Text(proposal.evidence)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: VelaSpacing.xs) {
                    VelaMetricPill(title: AppLanguage.stored.isChinese ? "来源" : "Source", value: proposal.source, systemImage: "point.3.connected.trianglepath.dotted", tint: VelaTheme.sleep)
                    VelaMetricPill(title: AppLanguage.stored.isChinese ? "目标" : "Target", value: proposal.targetFile, systemImage: "doc.text", tint: VelaTheme.recovery)
                }
                HStack(spacing: VelaSpacing.sm) {
                    VelaPrimaryActionButton(title: AppLanguage.stored.isChinese ? "确认保存" : "Confirm", systemImage: "checkmark") {
                        onAccept()
                    }
                    VelaSecondaryActionButton(title: AppLanguage.stored.isChinese ? "拒绝" : "Reject", systemImage: "xmark") {
                        onReject()
                    }
                }
            }
        }
    }

    private var memoryTypeLabel: String {
        switch proposal.memoryType {
        case .fact: return AppLanguage.stored.isChinese ? "事实" : "Fact"
        case .observation: return AppLanguage.stored.isChinese ? "观察" : "Observation"
        case .hypothesis: return AppLanguage.stored.isChinese ? "推测" : "Hypothesis"
        case .strategy: return AppLanguage.stored.isChinese ? "策略" : "Strategy"
        case .preference: return AppLanguage.stored.isChinese ? "偏好" : "Preference"
        case .constraint: return AppLanguage.stored.isChinese ? "约束" : "Constraint"
        case .goalChange: return AppLanguage.stored.isChinese ? "目标变更" : "Goal Change"
        case .baselineUpdate: return AppLanguage.stored.isChinese ? "基线更新" : "Baseline"
        }
    }
}

// MARK: - VelaTrustLogCard

struct VelaTrustLogCard: View {
    let title: String
    let subtitle: String
    let status: String
    var tint: Color = VelaTheme.primary

    var body: some View {
        VelaGlassCard(padding: VelaSpacing.sm, cornerRadius: VelaRadius.row) {
            HStack(spacing: VelaSpacing.sm) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(tint.opacity(0.12)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.onSurface)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .lineLimit(2)
                }
                Spacer()
                VelaStatusBadge(label: status, tint: tint)
            }
        }
    }
}

// MARK: - VelaCoachCommandCard

struct VelaCoachCommandCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = VelaTheme.primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: VelaSpacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(tint.opacity(0.12)))
                VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.onSurface)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(VelaSpacing.md)
            .background(RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous).fill(VelaTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous).stroke(VelaTheme.outline, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }
}
