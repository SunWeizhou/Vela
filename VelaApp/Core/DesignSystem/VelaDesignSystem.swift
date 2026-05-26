import SwiftData
import SwiftUI

enum VelaSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum VelaRadius {
    static let row: CGFloat = 14
    static let card: CGFloat = 20
    static let hero: CGFloat = 26
}

enum VelaMotion {
    static let quick = Animation.spring(response: 0.26, dampingFraction: 0.82)
    static let expand = Animation.spring(response: 0.34, dampingFraction: 0.86)
}

enum VelaSemanticColors {
    static func color(for category: String) -> Color {
        switch category {
        case "recovery": return VelaTheme.recovery
        case "sleep": return VelaTheme.sleep
        case "strain", "training": return VelaTheme.strain
        case "stress": return VelaTheme.stress
        case "energy": return VelaTheme.energy
        case "gait", "cardio": return VelaTheme.accent
        default: return VelaTheme.accent
        }
    }

    static func color(for confidence: DataConfidence) -> Color {
        switch confidence {
        case .high: return VelaTheme.recovery
        case .medium: return VelaTheme.energy
        case .low: return VelaTheme.strain
        case .unavailable: return VelaTheme.mutedText
        }
    }

    static func color(for freshness: DataFreshness) -> Color {
        switch freshness {
        case .live, .today: return VelaTheme.recovery
        case .recent: return VelaTheme.accent
        case .stale: return VelaTheme.strain
        case .missing: return VelaTheme.mutedText
        }
    }
}

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

struct VelaPageHeader: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    var tint: Color = VelaTheme.accent

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
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

struct VelaSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
    }
}

struct VelaHeroSurface<Content: View>: View {
    var tint: Color = VelaTheme.accent
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(VelaSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(VelaTheme.elevatedSurface)
                    RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity(0.085),
                                    VelaTheme.elevatedSurface.opacity(0.16),
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
                    .stroke(VelaTheme.stroke, lineWidth: 0.9)
            )
    }
}

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
                    .stroke(VelaTheme.stroke, lineWidth: 0.85)
            )
    }
}

struct VelaMetricPill: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

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
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
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

struct VelaStatusBadge: View {
    let label: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

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
        case .info: return VelaTheme.accent
        case .warning: return VelaTheme.energy
        case .critical: return VelaTheme.stress
        }
    }
}

struct VelaPrimaryActionButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "checkmark")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.inverseText)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .background(Capsule(style: .continuous).fill(VelaTheme.accent))
        .shadow(color: VelaTheme.accent.opacity(0.18), radius: 8, y: 3)
        .buttonStyle(.plain)
    }
}

struct VelaSecondaryActionButton: View {
    let title: String
    var systemImage: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .background(Capsule(style: .continuous).fill(VelaTheme.elevatedSurface))
        .overlay(Capsule(style: .continuous).stroke(VelaTheme.stroke, lineWidth: 0.85))
        .buttonStyle(.plain)
    }
}

struct VelaInlineAlert: View {
    let title: String
    let message: String
    var systemImage = "info.circle.fill"
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: VelaSpacing.sm) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: VelaSpacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(VelaSpacing.sm)
        .background(RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous).fill(tint.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous).stroke(tint.opacity(0.14), lineWidth: 0.7))
    }
}

struct VelaEmptyState: View {
    let title: String
    let message: String
    var systemImage = "tray"
    var tint: Color = VelaTheme.accent

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
                .foregroundStyle(VelaTheme.primaryText)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(VelaSpacing.xl)
    }
}

struct VelaDataQualityRow: View {
    let title: String
    let subtitle: String
    let freshness: DataFreshness
    let qualityLabel: String
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: VelaSpacing.sm) {
            Image(systemName: freshness == .missing ? "xmark.circle.fill" : "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaSemanticColors.color(for: freshness))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
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

struct VelaEvidenceStep: View {
    let index: Int
    let title: String
    let value: String
    let detail: String
    var tint: Color = VelaTheme.accent
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: VelaSpacing.sm) {
            VStack(spacing: VelaSpacing.xs) {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(VelaTheme.background))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 1.2))
                if !isLast {
                    Rectangle()
                        .fill(VelaTheme.stroke)
                        .frame(width: 1.5)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: VelaSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Spacer()
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

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
                    .foregroundStyle(VelaTheme.primaryText)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
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

struct VelaMemoryProposalCard: View {
    let proposal: MemoryEventRecord
    var onAccept: () -> Void
    var onReject: () -> Void

    var body: some View {
        VelaGlassCard {
            VStack(alignment: .leading, spacing: VelaSpacing.sm) {
                HStack {
                    VelaStatusBadge(label: memoryTypeLabel, systemImage: "brain.head.profile", tint: VelaTheme.accent)
                    Spacer()
                    Text("\(Int((proposal.confidence * 100).rounded()))%")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.energy)
                }
                Text(proposal.content)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !proposal.evidence.isEmpty {
                    Text(proposal.evidence)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
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

struct VelaTrustLogCard: View {
    let title: String
    let subtitle: String
    let status: String
    var tint: Color = VelaTheme.accent

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
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer()
                VelaStatusBadge(label: status, tint: tint)
            }
        }
    }
}

struct VelaCoachCommandCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = VelaTheme.accent
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
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
            }
            .padding(VelaSpacing.md)
            .background(RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous).fill(VelaTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous).stroke(VelaTheme.stroke, lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }
}
