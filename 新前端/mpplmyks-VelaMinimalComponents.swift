import SwiftUI

enum VelaMinimalTab: Int, CaseIterable, Identifiable {
    case today
    case vitals
    case fitness
    case journal
    case coach

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: return L10n.t("Today", "今日")
        case .vitals: return L10n.t("Vitals", "生命体征")
        case .fitness: return L10n.t("Fitness", "健身")
        case .journal: return L10n.t("Journal", "手记")
        case .coach: return L10n.t("Coach", "教练")
        }
    }

    var icon: String {
        switch self {
        case .today: return "house"
        case .vitals: return "heart"
        case .fitness: return "figure.run"
        case .journal: return "book"
        case .coach: return "sparkles"
        }
    }

    var filledIcon: String {
        switch self {
        case .today: return "house.fill"
        case .vitals: return "heart.fill"
        case .fitness: return "figure.run"
        case .journal: return "book.fill"
        case .coach: return "sparkles"
        }
    }
}

enum VelaMinimalFormat {
    static func whole(_ value: Double?) -> String {
        value.map { "\(Int($0.rounded()))" } ?? "--"
    }

    static func oneDecimal(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? "--"
    }

    static func minutesAsHours(_ minutes: Int) -> String {
        guard minutes > 0 else { return "--" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    static func score(_ result: StandardScoreResult) -> String {
        result.hasData ? "\(Int(result.score.rounded()))" : "--"
    }

    static func band(_ result: StandardScoreResult) -> String {
        guard result.hasData else { return L10n.t("Building baseline", "正在建立基线") }
        switch result.band {
        case .low: return L10n.t("Low", "偏低")
        case .moderate: return L10n.t("Controlled", "可控")
        case .high: return L10n.t("Ready", "就绪")
        }
    }
}

struct VelaMinimalGlassPanel<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 24
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.thinMaterial)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(VelaTheme.surface.opacity(0.24))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(VelaTheme.stroke, lineWidth: 0.85)
            }
            .shadow(color: VelaTheme.cardShadowColor, radius: 18, y: 8)
    }
}

struct VelaMinimalAppBar: View {
    let title: String
    var leadingSystemImage = "person.crop.circle.fill"
    var trailingSystemImage = "bell"
    var trailingAction: () -> Void

    var body: some View {
        HStack {
            Image(systemName: leadingSystemImage)
                .font(.system(size: 29, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(VelaTheme.surface.opacity(0.48)))
                .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.8))

            Spacer()

            Text(title)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(VelaTheme.accent)
                .lineLimit(1)

            Spacer()

            Button(action: trailingAction) {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(VelaTheme.surface.opacity(0.48)))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.8))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .frame(height: 72)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VelaTheme.stroke)
                .frame(height: 0.6)
        }
    }
}

struct VelaMinimalFloatingTabBar: View {
    @Binding var selectedTab: VelaMinimalTab
    var coachAction: () -> Void

    private let standardTabs: [VelaMinimalTab] = [.today, .journal, .fitness, .vitals]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(standardTabs.enumerated()), id: \.element) { index, tab in
                if index == 2 {
                    coachButtonView
                }
                tabItemView(tab)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            Capsule(style: .continuous)
                .fill(glassTint)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    private var glassTint: Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.106, blue: 0.094, alpha: 0.55)
                : UIColor(white: 1.0, alpha: 0.60)
        })
    }

    private func tabItemView(_ tab: VelaMinimalTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: isSelected ? tab.filledIcon : tab.icon)
                    .font(.system(size: 24, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? VelaTheme.primary : VelaTheme.onSurfaceVariant)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.title)
    }

    private var coachButtonView: some View {
        Button(action: coachAction) {
            Image(systemName: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .fill(VelaTheme.primary)
                )
                .shadow(color: VelaTheme.primary.opacity(0.30), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .offset(y: -4)
        .accessibilityLabel(L10n.t("Coach", "教练"))
    }
}

struct VelaMinimalSectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(VelaTheme.secondaryText)
                .tracking(1.2)
                .textCase(.uppercase)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding(.horizontal, 2)
    }
}

struct VelaMinimalValueText: View {
    let value: String
    var unit: String?
    var size: CGFloat = 34
    var tint: Color = VelaTheme.primaryText

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: size, weight: .black, design: .rounded))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            if let unit {
                Text(unit)
                    .font(.system(size: max(12, size * 0.38), weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct VelaMinimalChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.18), lineWidth: 0.7))
    }
}

struct VelaMinimalBentoMetricCard: View {
    let title: String
    let value: String
    var unit: String?
    let subtitle: String
    let systemImage: String
    var tint: Color = VelaTheme.accent

    var body: some View {
        VelaMinimalGlassPanel(padding: 16, radius: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tint)
                    Spacer()
                    Text(title)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                VStack(alignment: .leading, spacing: 4) {
                    VelaMinimalValueText(value: value, unit: unit, size: 28)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }
            .frame(minHeight: 104, alignment: .topLeading)
        }
    }
}

struct VelaMinimalRecordRow: View {
    let title: String
    var detail: String?
    let systemImage: String
    var tint: Color = VelaTheme.accent
    var action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.11)))

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()

            if let detail {
                Text(detail)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 13)
    }
}

struct VelaMinimalSleepArchitectureBar: View {
    let stageMinutes: [SleepStage: Int]

    private var total: Int {
        max(stageMinutes.values.reduce(0, +), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 2) {
                segment(.deep, color: VelaTheme.accent)
                segment(.core, color: VelaTheme.sleep)
                segment(.rem, color: VelaTheme.strain)
                segment(.awake, color: VelaTheme.recovery)
            }
            .frame(height: 32)
            .clipShape(Capsule(style: .continuous))

            HStack(spacing: 10) {
                legend(L10n.t("Deep", "深睡"), color: VelaTheme.accent, minutes: stageMinutes[.deep])
                legend(L10n.t("Core", "核心"), color: VelaTheme.sleep, minutes: stageMinutes[.core])
                legend("REM", color: VelaTheme.strain, minutes: stageMinutes[.rem])
            }
        }
    }

    private func segment(_ stage: SleepStage, color: Color) -> some View {
        let width = CGFloat(max(stageMinutes[stage] ?? 0, stage == .core ? total : 0)) / CGFloat(total)
        return Rectangle()
            .fill(color)
            .frame(maxWidth: .infinity)
            .layoutPriority(Double(width))
    }

    private func legend(_ title: String, color: Color, minutes: Int?) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text("\(title) \(minutes.map { "\($0)m" } ?? "--")")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
