import SwiftUI

// MARK: - TodayReadinessDial
struct TodayReadinessDial: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let score: Double
    let accent: Color

    private var progress: Double {
        min(1, max(0, score / 100.0))
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(VelaTheme.borderSoft, lineWidth: 8)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(VelaTheme.dataAnimation(reduceMotion: reduceMotion), value: progress)

            VStack(spacing: 1) {
                Text(score > 0 ? "\(Int(score.rounded()))" : "--")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.fg)
                Text(L10n.t("Ready", "就绪"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
    }
}

// MARK: - ProactiveGuidanceCard
struct ProactiveGuidanceCard: View {
    let insight: ProactiveInsight
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: insight.focus.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(insight.focus.color)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(insight.focus.color.opacity(0.10))
                        )

                    Text(insight.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C7C7CC"))
                }

                Text(insight.body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(VelaTheme.meta)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(insight.focus.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(insight.focus.color)

                    Text(insight.suggestedAction ?? "打开详情查看更完整的训练和恢复建议。")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(insight.focus.color.opacity(0.065))
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Scroll Extensions
extension View {
    @ViewBuilder
    func velaTrackScrollOffsetY(offset: Binding<CGFloat>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                offset.wrappedValue = newValue
            }
        } else {
            self // fallback
        }
    }
}
