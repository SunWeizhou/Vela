import SwiftUI

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
