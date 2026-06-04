import SwiftUI

// MARK: - VelaComponents — Apple-Style Reusable Components
// 组件清单: ScoreRing, VitalCard, InfoCard, InsightCard, EmptyStateCard,
//           GlassTabBar, StatusCapsule, DayPill, MessageBubble, TypingIndicator,
//           SettingsRow, ToggleRow, EvidenceStep, DataFreshnessBar

// MARK: - ScoreRing (Ring progress view)

struct ScoreRing: View {
    let score: Double      // 0…1
    let color: Color
    let size: CGFloat
    let strokeWidth: CGFloat?
    let value: String
    let unit: String?
    let label: String

    init(
        score: Double,
        color: Color,
        size: CGFloat = VelaTheme.ringMd,
        strokeWidth: CGFloat? = nil,
        value: String,
        unit: String? = nil,
        label: String
    ) {
        self.score = max(0, min(1, score))
        self.color = color
        self.size = size
        self.strokeWidth = strokeWidth ?? (size * 0.085)
        self.value = value
        self.unit = unit
        self.label = label
    }

    var body: some View {
        let sw = strokeWidth ?? (size * 0.085)
        ZStack {
            Circle()
                .stroke(VelaTheme.borderSoft, lineWidth: sw)

            Circle()
                .trim(from: 0, to: score)
                .stroke(color, style: StrokeStyle(lineWidth: sw, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.8), value: score)

            VStack(spacing: 0) {
                if let unit = unit {
                    Text(value)
                        .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                    Text(unit)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.meta)
                } else {
                    Text(value)
                        .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottom) {
            Text(label)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .offset(y: size * 0.2)
        }
        .padding(.bottom, size * 0.16)
    }
}

// MARK: - VitalCard (vitals metric card)

struct VitalCard: View {
    let title: String
    let value: String
    let unit: String
    let range: String
    let freshness: VitalFreshness
    let bars: [Double]
    let color: Color
    var onTap: () -> Void

    enum VitalFreshness {
        case fresh, stale, missing
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    freshnessBadge
                }

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 36, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(VelaTheme.fg)
                    Text(unit)
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.meta)
                }

                Text(range)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { i, h in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i == bars.count - 1 ? color : color.opacity(0.3))
                            .frame(height: max(2, h * 48))
                    }
                }
                .frame(height: 48)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
        }
        .buttonStyle(.cardPress)
    }

    @ViewBuilder
    private var freshnessBadge: some View {
        switch freshness {
        case .fresh:
            Text("最新")
                .font(VelaTheme.caption2())
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: "#137333"))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: "#E6F4EA"))
                .clipShape(.capsule)
        case .stale:
            Text("8小时前")
                .font(VelaTheme.caption2())
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: "#B06000"))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: "#FEF7E0"))
                .clipShape(.capsule)
        case .missing:
            Text("无数据")
                .font(VelaTheme.caption2())
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: "#C5221F"))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(hex: "#FCE8E6"))
                .clipShape(.capsule)
        }
    }
}

// MARK: - InfoCard (dual metric card)

struct InfoCard: View {
    let eyebrow: String
    let value: String
    let unit: String?
    let subtitle: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(VelaTheme.caption2())
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(VelaTheme.meta)
                    .kerning(0.04)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 32, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(VelaTheme.fg)
                    if let unit = unit {
                        Text(unit)
                            .font(.system(size: 14))
                            .foregroundStyle(VelaTheme.meta)
                    }
                }

                Text(subtitle)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(16)
        }
        .buttonStyle(.cardPress)
    }
}

// MARK: - InsightCard (coach insight with left accent bar)

struct InsightCard: View {
    let title: String
    let bodyText: String
    let cta: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(VelaTheme.caption2())
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .kerning(0.04)
                    .foregroundStyle(VelaTheme.accent)

                Text(bodyText)
                    .font(VelaTheme.subheadline())
                    .lineSpacing(4)
                    .foregroundStyle(VelaTheme.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 4) {
                    Text(cta)
                        .font(VelaTheme.subheadline())
                        .fontWeight(.medium)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(VelaTheme.accent)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(VelaTheme.accent)
                    .frame(width: 3)
                    .padding(.leading, 1)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            }
        }
        .buttonStyle(.cardPress)
    }
}

// MARK: - EmptyStateCard

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String
    var actionLabel: String?
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(VelaTheme.meta)

            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)

            Text(subtitle)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if let label = actionLabel, let action = onAction {
                Button(action: action) {
                    Text(label)
                        .font(VelaTheme.subheadline())
                        .fontWeight(.medium)
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .stroke(VelaTheme.accent, lineWidth: 1)
                        )
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .stroke(VelaTheme.border, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
        )
    }
}

// MARK: - GlassTabBar (4 tabs centered, floating capsule style with sliding active indicator)

struct GlassTabBar: View {
    @Binding var selectedTab: VelaTab
    @Namespace private var animation

    enum VelaTab: CaseIterable {
        case today, journal, training, vitals

        var index: Int {
            switch self {
            case .today: 0; case .journal: 1; case .training: 2; case .vitals: 3
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(VelaTab.allCases, id: \.self) { tab in
                Button {
                    VelaHaptic.selection()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.78, blendDuration: 0)) {
                        selectedTab = tab
                    }
                } label: {
                    let isActive = selectedTab == tab
                    VStack(spacing: 4) {
                        Image(systemName: iconName(for: tab))
                            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                            .frame(width: 22, height: 22)
                        Text(label(for: tab))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(isActive ? Color(hex: "#1A1917") : Color(hex: "#8E8A80"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        ZStack {
                            if isActive {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(hex: "#E5E5EA").opacity(0.45))
                                    .matchedGeometryEffect(id: "activeTabBackground", in: animation)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .velaInteractiveGlass(in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
    }

    private func iconName(for tab: VelaTab) -> String {
        switch tab {
        case .today:    "sun.max"
        case .journal:  "book.pages"
        case .training: "figure.run"
        case .vitals:   "heart.text.square"
        }
    }

    private func label(for tab: VelaTab) -> LocalizedStringKey {
        switch tab {
        case .today:    VelaLoc.tabToday
        case .journal:  VelaLoc.tabJournal
        case .training: VelaLoc.tabTraining
        case .vitals:   VelaLoc.tabVitals
        }
    }
}

extension View {
    @ViewBuilder
    func velaInteractiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - StatusCapsule

struct StatusCapsule: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)

                Text(label)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.fg2)

                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.fg)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(VelaTheme.cardBg)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DayPill (week strip day)

struct DayPill: View {
    let dow: String
    let dom: String
    let isToday: Bool
    let isActive: Bool
    let hasEvent: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text(dow)
                    .font(VelaTheme.caption2())
                    .fontWeight(isToday ? .semibold : .medium)
                    .foregroundStyle(isToday ? VelaTheme.accent : VelaTheme.meta)
                    .kerning(0.02)

                Text(dom)
                    .font(.system(size: 18, weight: isActive ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(isActive ? .white : VelaTheme.fg)
                    .frame(width: 36, height: 36)
                    .background(
                        Group {
                            if isActive {
                                Circle().fill(VelaTheme.accent)
                            }
                        }
                    )

                Circle()
                    .fill(VelaTheme.accent)
                    .frame(width: 4, height: 4)
                    .opacity(hasEvent ? 1 : 0)
            }
            .frame(width: 48)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - MessageBubble

struct MessageBubble: View {
    let text: String
    let isUser: Bool
    let time: String
    var isStreaming = false

    var body: some View {
        HStack(spacing: 0) {
            if isUser { Spacer() }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                MarkdownText(
                    markdown: text,
                    font: VelaTheme.subheadline(),
                    color: isUser ? .white : VelaTheme.fg,
                    isStreaming: isStreaming
                )
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        Group {
                            if isUser {
                                VelaTheme.accent
                            } else {
                                VelaTheme.surface
                            }
                        }
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: VelaTheme.radiusLg,
                            style: .continuous
                        )
                    )
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isUser ? VelaTheme.radiusLg : 4,
                            bottomLeadingRadius: VelaTheme.radiusLg,
                            bottomTrailingRadius: VelaTheme.radiusLg,
                            topTrailingRadius: isUser ? 4 : VelaTheme.radiusLg,
                            style: .continuous
                        )
                    )
                    .frame(maxWidth: 280, alignment: isUser ? .trailing : .leading)

                if !time.isEmpty {
                    Text(time)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.meta)
                        .padding(.horizontal, 4)
                }
            }

            if !isUser { Spacer() }
        }
    }
}

// MARK: - TypingIndicator

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(VelaTheme.meta)
                    .frame(width: 7, height: 7)
                    .scaleEffect(phase == i ? 1 : 0.6)
                    .opacity(phase == i ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true), value: phase)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: VelaTheme.radiusLg,
                bottomTrailingRadius: VelaTheme.radiusLg,
                topTrailingRadius: VelaTheme.radiusLg,
                style: .continuous
            )
            .fill(VelaTheme.surface)
        )
        .onAppear {
            phase = 0
            withAnimation(.easeInOut(duration: 0.32).delay(0.32)) { phase = 1 }
            withAnimation(.easeInOut(duration: 0.32).delay(0.64)) { phase = 2 }
            withAnimation(.easeInOut(duration: 0.32).delay(0.96)) { phase = 0 }
        }
    }
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let iconBg: Color
    let title: String
    var value: String?
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(title)
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.fg)

                Spacer()

                if let value = value {
                    Text(value)
                        .font(VelaTheme.body())
                        .foregroundStyle(VelaTheme.meta)
                }

                Image(systemName: "chevron.forward")
                    .font(.system(size: 14))
                    .foregroundStyle(VelaTheme.meta.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ToggleRow

struct ToggleRow: View {
    let icon: String
    let iconBg: Color
    let title: String
    @Binding var isOn: Bool
    var onToggle: ((Bool) -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(title)
                .font(VelaTheme.body())
                .foregroundStyle(VelaTheme.fg)

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(VelaTheme.accent)
                .labelsHidden()
                .onChange(of: isOn) { _, val in
                    onToggle?(val)
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - EvidenceStep

struct EvidenceStep: View {
    let step: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(step)")
                .font(VelaTheme.monoCaption())
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(VelaTheme.accent)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VelaTheme.subheadline())
                    .fontWeight(.semibold)
                    .foregroundStyle(VelaTheme.fg)
                Text(detail)
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(2)
            }
        }
    }
}

// MARK: - DataFreshnessBar

struct DataFreshnessBar: View {
    let lastSync: String
    let device: String?

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(VelaTheme.success)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading) {
                Text("数据已同步")
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.fg)
                +
                Text(" · \(lastSync)")
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.muted)

                if let device = device {
                    Text(" · \(device)")
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.meta)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                .fill(VelaTheme.surface)
        )
    }
}

// MARK: - QuickEntryButton

struct QuickEntryButton: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let label: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconFg)
                    .frame(width: 36, height: 36)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(label)
                    .font(VelaTheme.subheadline())
                    .fontWeight(.medium)
                    .foregroundStyle(VelaTheme.fg)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
        }
        .buttonStyle(.cardPress)
    }
}

// MARK: - WorkoutCard

struct WorkoutCard: View {
    let badge: String
    let badgeColor: Color
    let badgeBg: Color
    let title: String
    let duration: String
    let originalPlan: String?
    let adaptedPlan: String
    let reason: String
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(badge)
                        .font(VelaTheme.caption2())
                        .fontWeight(.semibold)
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule(style: .continuous).fill(badgeBg)
                        )

                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)

                    Spacer()

                    Text(duration)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.muted)
                }

                if let original = originalPlan {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.warn)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(original)
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.meta)
                                .strikethrough()

                            Text(adaptedPlan)
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.fg)
                                .fontWeight(.medium)
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusSm, style: .continuous)
                            .fill(VelaTheme.elevatedBg)
                    )
                } else {
                    Text(adaptedPlan)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.fg)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: VelaTheme.radiusSm, style: .continuous)
                                .fill(VelaTheme.elevatedBg)
                        )
                }

                Text(reason)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.meta)
                    .lineLimit(2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
        }
        .buttonStyle(.cardPress)
    }
}

// MARK: - TagChip

struct TagChip: View {
    let label: String
    let color: Color

    init(_ label: String, color: Color) {
        self.label = label
        self.color = color
    }

    var body: some View {
        Text(label)
            .font(VelaTheme.caption1())
            .fontWeight(.medium)
            .foregroundStyle(VelaTheme.fg)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(VelaTheme.cardBg)
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - SettingsGroup

struct SettingsGroup<Content: View>: View {
    var header: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header = header {
                Text(header)
                    .font(VelaTheme.caption1())
                    .fontWeight(.medium)
                    .foregroundStyle(VelaTheme.muted)
                    .textCase(.uppercase)
                    .kerning(0.02)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
        }
    }
}

// MARK: - PlusAction

struct PlusAction: View {
    let icon: String
    let iconBg: Color
    let iconFg: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconFg)
                .frame(width: 44, height: 44)
                .background(iconBg)
                .clipShape(Circle())

            Text(title)
                .font(VelaTheme.subheadline())
                .fontWeight(.semibold)
                .foregroundStyle(VelaTheme.fg)

            Text(subtitle)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .fill(VelaTheme.surface)
        )
    }
}

// MARK: - Button Styles

extension ButtonStyle where Self == CardPressStyle {
    static var cardPress: CardPressStyle { CardPressStyle() }
}

struct CardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.light()
                }
            }
    }
}

extension ButtonStyle where Self == TabItemStyle {
    static var tabItem: TabItemStyle { TabItemStyle() }
}

struct TabItemStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.selection()
                }
            }
    }
}

extension ButtonStyle where Self == PlusButtonStyle {
    static var plusButton: PlusButtonStyle { PlusButtonStyle() }
}

struct PlusButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    VelaHaptic.medium()
                }
            }
    }
}

// MARK: - View Modifiers

// MARK: - View Modifiers

struct AmbientGlowModifier: ViewModifier {
    let color: Color
    let intensity: CGFloat
    @State private var breathe = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(color)
                    .blur(radius: breathe ? 24 : 16)
                    .opacity(breathe ? intensity * 1.15 : intensity)
                    .scaleEffect(breathe ? 1.015 : 0.985)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                            breathe = true
                        }
                    }
            )
    }
}

struct VelaNativeCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(VelaTheme.cardBg)
                    .shadow(color: VelaTheme.nativeShadow(colorScheme), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
    }
}

extension View {
    func ambientGlow(color: Color, intensity: CGFloat = 0.05) -> some View {
        self.modifier(AmbientGlowModifier(color: color, intensity: intensity))
    }

    func velaNativeCard(radius: CGFloat = 16) -> some View {
        self.modifier(VelaNativeCardModifier(radius: radius))
    }

    func cardSurface(padding: CGFloat = VelaTheme.spaceLG, radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                // Inner concentric highlight border for refraction look
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.0)
                    .padding(0.5)
            )
            .shadow(color: VelaTheme.cardShadowColor, radius: 4, y: 2)
    }

    func heroCardSurface(accent: Color = VelaTheme.accent, padding: CGFloat = VelaTheme.spaceLG) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .fill(VelaTheme.elevatedBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1.0)
                    .padding(0.5)
            )
    }

    func glassEffect(radius: CGFloat = VelaTheme.radiusLG) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
    }

    func sectionSpacing() -> some View {
        self.padding(.bottom, VelaTheme.sectionGap)
    }
}

// MARK: - Screen Wrapper

struct VelaMinimalScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.bottom, VelaTheme.tabBarHeight + 20)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.bg)
    }
}

// MARK: - Section Header

struct VelaMinimalSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.meta)
                .textCase(.uppercase)
                .tracking(1.0)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .padding(.top, VelaTheme.spaceSM)
        .padding(.bottom, VelaTheme.spaceSM)
    }
}

// MARK: - Backward Compat Types

// VelaBackground — simple full-screen background
struct VelaBackground: View {
    var body: some View {
        VelaTheme.bg.ignoresSafeArea()
    }
}

// Old VelaEmptyState with legacy init signature (all optional for compat)
struct VelaEmptyStateCompat: View {
    var title: String = ""
    var subtitle: String = ""
    var message: String = ""
    var systemImage: String = "questionmark.circle"
    var tint: Color = VelaTheme.accent
    var action: (() -> Void)?
    var actionLabel: String?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(tint)
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            if !message.isEmpty {
                Text(message)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.muted)
                    .multilineTextAlignment(.center)
            }
            if let label = actionLabel, let action = action {
                Button(action: action) {
                    Text(label)
                        .font(VelaTheme.subheadline())
                        .fontWeight(.medium)
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Capsule().stroke(VelaTheme.accent, lineWidth: 1))
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg)
                .fill(VelaTheme.cardBg)
        )
    }
}
typealias VelaEmptyState = VelaEmptyStateCompat

// Old VelaStatusBadge with legacy init signature
struct VelaStatusBadgeCompat: View {
    let label: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: 10))
            }
            Text(label)
                .font(VelaTheme.caption2())
                .fontWeight(.medium)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}
typealias VelaStatusBadge = VelaStatusBadgeCompat

// Old VelaInlineAlert with legacy init signature
struct VelaInlineAlertCompat: View {
    let title: String
    let message: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 10) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.title3)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text(message)
                    .font(VelaTheme.captionFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd)
                .fill(tint.opacity(0.06))
        )
    }
}
typealias VelaInlineAlert = VelaInlineAlertCompat
typealias VelaAppleInlineAlert = VelaInlineAlertCompat

// Old VelaDataQualityRow with legacy init signature
struct VelaDataQualityRowCompat: View {
    let title: String
    let subtitle: String
    var isAvailable: Bool = true
    var freshness: DataFreshness? = nil
    let qualityLabel: String
    let tint: Color

    var body: some View {
        let available = freshness.map { $0 != .missing } ?? isAvailable
        HStack(spacing: 12) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(available ? tint : VelaTheme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(VelaTheme.fg)
                Text(subtitle)
                    .font(VelaTheme.microFont)
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }
            Spacer()
            Text(qualityLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(available ? tint : VelaTheme.muted)
        }
        .padding(.vertical, 6)
    }
}
typealias VelaDataQualityRow = VelaDataQualityRowCompat
typealias VelaAppleDataQualityRow = VelaDataQualityRowCompat

// VelaHeroSurface — tinted hero card container
struct VelaHeroSurface<Content: View>: View {
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(VelaTheme.spaceLG)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .fill(tint.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusHero, style: .continuous)
                    .stroke(tint.opacity(0.2), lineWidth: 0.5)
            )
    }
}

// VelaMetricPill — small metric chip
struct VelaMetricPill: View {
    let title: String
    let value: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 4) {
            if let img = systemImage {
                Image(systemName: img)
                    .font(.system(size: 10))
            }
            Text("\(title) ")
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
            + Text(value)
                .font(VelaTheme.caption2().weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// VelaGlassCard — glass-style card wrapper
struct VelaGlassCard<Content: View>: View {
    var padding: CGFloat = VelaTheme.spaceLG
    var cornerRadius: CGFloat = VelaTheme.radiusLg
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// VelaMemoryProposalCard — proposal-based card for WikiProfileView compat
struct VelaMemoryProposalCardCompat: View {
    var title: String = ""
    var evidence: String = ""
    var confidence: String = ""
    var source: String = ""
    var target: String = ""
    var proposal: Any?
    var onAccept: (() -> Void)?
    var onReject: (() -> Void)?

    var body: some View {
        let displayTitle: String = {
            if let p = proposal as? MemoryProposal { return p.displayTitle }
            if let r = proposal as? MemoryEventRecord { return r.content }
            return title
        }()
        let displayEvidence: String = {
            if let p = proposal as? MemoryProposal { return p.content }
            if let r = proposal as? MemoryEventRecord { return r.evidence }
            return evidence
        }()
        let displayConfidence: String = {
            if let p = proposal as? MemoryProposal { return String(format: "%.0f%%", p.confidence * 100) }
            if let r = proposal as? MemoryEventRecord { return String(format: "%.0f%%", r.confidence * 100) }
            return confidence
        }()

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VelaStatusBadge(label: "Pattern", systemImage: "brain.head.profile", tint: VelaTheme.accent)
                Spacer()
                Text("\(displayConfidence) confidence")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.energyColor)
            }
            Text(displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
            Text(displayEvidence)
                .font(VelaTheme.captionFont)
                .foregroundStyle(VelaTheme.onSurfaceVariant)
            if !source.isEmpty || !target.isEmpty {
                HStack(spacing: 8) {
                    VelaMetricPill(title: "Source", value: source, systemImage: "point.3.connected.trianglepath.dotted", tint: VelaTheme.sleepColor)
                    VelaMetricPill(title: "Target", value: target, systemImage: "doc.text", tint: VelaTheme.recoveryColor)
                }
            }
            HStack(spacing: 10) {
                Button(action: { onAccept?() }) {
                    Label("Confirm", systemImage: "checkmark")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(VelaTheme.accent)
                Button(action: { onReject?() }) {
                    Label("Reject", systemImage: "xmark")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .tint(VelaTheme.muted)
            }
        }
        .padding(VelaTheme.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
    }
}

typealias VelaMemoryProposalCard = VelaMemoryProposalCardCompat
// MemoryProposal is defined in AI/Memory/MemoryModels.swift

// MARK: - ImagePicker wrapper (for CoachChatPanel compat)

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

enum VelaMinimalTab: CaseIterable {
    case today, training, insights, settings
}

struct VelaMinimalNavBar: View {
    let title: String
    var body: some View {
        Text(title)
            .font(VelaTheme.title1())
            .foregroundStyle(VelaTheme.fg)
            .padding(.top, 8)
    }
}

struct VelaMinimalFloatingTabBar: View {
    @Binding var selectedTab: VelaMinimalTab
    var onCoachTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(VelaMinimalTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: tab))
                            .font(.system(size: 22))
                        Text(label(for: tab))
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? VelaTheme.accent : VelaTheme.meta)
                }
                .buttonStyle(.plain)
                if tab != VelaMinimalTab.allCases.last { Spacer() }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(.ultraThinMaterial)
    }

    private func icon(for tab: VelaMinimalTab) -> String {
        switch tab {
        case .today: "sun.max"
        case .training: "figure.run"
        case .insights: "heart.text.square"
        case .settings: "gearshape"
        }
    }

    private func label(for tab: VelaMinimalTab) -> String {
        switch tab {
        case .today: "Today"
        case .training: "Training"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }
}

// DataFreshness and DataConfidence defined in TypedContextSchema.swift

// MARK: - Bevel Score Ring (Bevel-style circular gauge)

struct BevelScoreRing: View {
    let score: Double // 0 to 1
    let color: Color
    var useGradient: Bool = false
    var size: CGFloat = 80
    let label: String
    let valueText: String

    @State private var animatedScore: Double = 0.0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track
                Circle()
                    .stroke(VelaTheme.borderSoft, lineWidth: 6.5)
                    .frame(width: size, height: size)
                
                if animatedScore > 0 {
                    // Gradient or solid arc using system gradient to avoid rotation coordinate bugs
                    Circle()
                        .trim(from: 0, to: max(0.01, animatedScore))
                        .stroke(
                            useGradient 
                            ? AnyShapeStyle(color.gradient)
                            : AnyShapeStyle(color),
                            style: StrokeStyle(lineWidth: 6.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: size, height: size)
                }
                
                // Small indicator dot at progress end aligned perfectly on stroke center path
                if animatedScore > 0 {
                    let angle = -90 + (max(0.01, animatedScore) * 360)
                    let radius = (size - 6.5) / 2
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .offset(x: radius * cos(angle * .pi / 180), y: radius * sin(angle * .pi / 180))
                }
                
                // Center Value
                Text(valueText)
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(VelaTheme.fg)
            }
            .frame(width: size, height: size)
            
            Text(label)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
        }
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = newScore
            }
        }
    }
}

// MARK: - Dotted Circle Gauge (Bevel-style circular tick gauge)

struct DottedCircleGauge: View {
    let score: Double // 0 to 100
    let labelText: String // e.g. "低"
    var size: CGFloat = 72
    let color: Color

    @State private var animatedScore: Double = 0.0

    var body: some View {
        ZStack {
            // Dotted circle track
            Circle()
                .stroke(VelaTheme.borderSoft, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, dash: [1.5, 4]))
                .frame(width: size, height: size)
            
            // Colored active dots matching score
            Circle()
                .trim(from: 0, to: max(0.02, animatedScore / 100.0))
                .stroke(color, style: StrokeStyle(lineWidth: 4.5, lineCap: .round, dash: [1.5, 4]))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            
            VStack(spacing: 1) {
                Text("\(Int(animatedScore))")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(VelaTheme.fg)
                Text(labelText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = score
            }
        }
        .onChange(of: score) { _, newScore in
            withAnimation(.spring(response: 0.85, dampingFraction: 0.82, blendDuration: 0)) {
                animatedScore = newScore
            }
        }
    }
}

// MARK: - Segmented Battery Bar (Bevel-style segmented horizontal bar)

struct SegmentedBatteryBar: View {
    let percentage: Double // 0 to 1
    var barCount: Int = 26
    let color: Color

    @State private var animatedPercentage: Double = 0.0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { idx in
                let activeCount = Int(animatedPercentage * Double(barCount))
                RoundedRectangle(cornerRadius: 1)
                    .fill(idx < activeCount ? color : VelaTheme.borderSoft)
                    .frame(width: 4, height: 14)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.1, dampingFraction: 0.82, blendDuration: 0)) {
                animatedPercentage = percentage
            }
        }
        .onChange(of: percentage) { _, newPercentage in
            withAnimation(.spring(response: 1.1, dampingFraction: 0.82, blendDuration: 0)) {
                animatedPercentage = newPercentage
            }
        }
    }
}

// MARK: - Sparkline Line Graph (Bevel-style biomarker sparkline)

struct SparklineLineGraph: View {
    let data: [Double] // Normalized 0...1 values
    let color: Color
    var height: CGFloat = 36
    var width: CGFloat = 80

    var body: some View {
        if data.isEmpty {
            Color.clear.frame(width: width, height: height)
        } else {
            ZStack {
                // Shaded area
                Path { path in
                    guard data.count > 1 else { return }
                    let stepX = width / CGFloat(data.count - 1)
                    path.move(to: CGPoint(x: 0, y: height))
                    for idx in 0..<data.count {
                         let x = CGFloat(idx) * stepX
                         let y = height - (CGFloat(data[idx]) * (height - 6) + 3)
                         path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.12), color.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Line Path
                Path { path in
                    guard data.count > 1 else { return }
                    let stepX = width / CGFloat(data.count - 1)
                    for idx in 0..<data.count {
                        let x = CGFloat(idx) * stepX
                        let y = height - (CGFloat(data[idx]) * (height - 6) + 3)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                // End Dot
                if let lastVal = data.last {
                    let stepX = width / CGFloat(data.count - 1)
                    let x = CGFloat(data.count - 1) * stepX
                    let y = height - (CGFloat(lastVal) * (height - 6) + 3)
                    Circle()
                        .fill(color)
                        .frame(width: 5, height: 5)
                        .position(x: x, y: y)
                }
            }
            .frame(width: width, height: height)
        }
    }
}
