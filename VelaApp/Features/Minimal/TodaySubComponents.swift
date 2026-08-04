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
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
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

// MARK: - VelaHealthSyncNote(训练数据来源说明)
struct VelaHealthSyncNote: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.brand)
            Text("训练记录自动同步自 Apple 健康 / Fitness，可作为与 Coach 讨论的依据")
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }
}

// MARK: - G1 重设计 · 今日页展示组件
// 统一品牌绿 + 状态色 + SF Rounded 大数字。全部为无副作用纯展示组件,数据由调用方传入。

// MARK: TodayStateRingsStrip(五指标状态色环)
struct TodayStateRingsStrip: View {
    let model: TodayExperienceModel

    private var ordered: [TodayExperienceSignalCard] {
        let order = ["recovery", "sleep", "strain", "stress", "energy"]
        return order.compactMap { id in model.signalCards.first(where: { $0.id == id }) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ordered) { card in
                VStack(spacing: 6) {
                    VelaMetricScoreRing(
                        score: Double(card.value),
                        label: card.title,
                        domain: .neutral,
                        size: 44,
                        accent: VelaTheme.color(for: card.state),
                        showsLabel: false
                    )
                    Text(card.title)
                        .font(VelaTheme.caption2().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 13)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }
}

// MARK: TodayReadinessHero(就绪度大数字 + 趋势线)
struct TodayReadinessHero: View {
    let scoreText: String          // "82" 或 "--"
    let stateText: String          // 例:"状态不错"
    let state: MetricState
    let trend: [Double]

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(scoreText)
                        .font(VelaTheme.displayValue())
                        .foregroundStyle(VelaTheme.color(for: state))
                    Text("/100")
                        .font(VelaTheme.callout().weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                }
                Text("READY · \(stateText)")
                    .font(VelaTheme.caption1().weight(.bold))
                    .foregroundStyle(VelaTheme.color(for: state))
            }
            Spacer(minLength: 12)
            TodayHeroSparkline(values: trend, color: VelaTheme.color(for: state))
                .frame(width: 84, height: 40)
                .padding(.bottom, 6)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: TodayHeroSparkline(迷你趋势线,无数据画虚线)
struct TodayHeroSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height * 0.5))
                p.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(
                    p,
                    with: .color(color.opacity(0.4)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
                )
                return
            }
            let minV = values.min() ?? 0
            let maxV = values.max() ?? 100
            let span = max(maxV - minV, 1)
            let stepX = size.width / CGFloat(values.count - 1)

            func point(_ i: Int, _ v: Double) -> CGPoint {
                let y = size.height * 0.15 + size.height * 0.7 * (1 - CGFloat((v - minV) / span))
                return CGPoint(x: CGFloat(i) * stepX, y: y)
            }

            var path = Path()
            for (i, v) in values.enumerated() {
                let pt = point(i, v)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )
            if let last = values.last {
                let pt = point(values.count - 1, last)
                context.fill(Path(ellipseIn: CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: TodayGuidanceCard(今日指导:洞察 + Coach 入口,无「开始训练」)
struct TodayGuidanceCard: View {
    let title: String
    let summary: String
    let onAskCoach: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日指导")
                .font(VelaTheme.caption2().weight(.bold))
                .foregroundStyle(VelaTheme.muted)
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(summary)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAskCoach) {
                HStack(spacing: 5) {
                    Text("和 Coach 聊聊")
                    Image(systemName: "arrow.right")
                }
                .font(VelaTheme.subheadline().weight(.bold))
                .foregroundStyle(VelaTheme.brand)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("和 Coach 聊聊今日建议")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }
}

// MARK: TodayVitalsGrid(体征 2×2 大卡 + 迷你可视化)
enum TodayVitalKind: String, CaseIterable, Identifiable {
    case hrv, rhr, spo2, sleep
    var id: String { rawValue }
}

struct TodayVitalCardModel: Identifiable {
    let kind: TodayVitalKind
    let label: String
    let value: String          // "68" / "--"
    let unit: String           // "ms" / "bpm" / "%" / "时"
    let status: String
    let isGood: Bool
    let trend: [Double]
    var id: String { kind.rawValue }
}

struct TodayVitalsGrid: View {
    let cards: [TodayVitalCardModel]
    let onTap: (TodayVitalKind) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(cards) { card in
                Button { onTap(card.kind) } label: {
                    TodayVitalCard(card: card)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(card.label) \(card.value)\(card.unit),\(card.status)")
                .accessibilityHint("查看\(card.label)详情")
            }
        }
    }
}

struct TodayVitalCard: View {
    let card: TodayVitalCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.label)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(1)
                    .frame(height: 14)            // 固定标签高 → 四格对齐
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(card.value)
                    .font(VelaTheme.vitalValue())
                    .foregroundStyle(VelaTheme.fg)
                Text(card.unit)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .frame(height: 26, alignment: .bottom)  // 数值同基线 → 对齐
            Text(card.status)
                .font(VelaTheme.caption2().weight(.bold))
                .foregroundStyle(card.isGood ? VelaTheme.stateGood : VelaTheme.stateModerate)
            TodayHeroSparkline(values: card.trend, color: VelaTheme.brand)
                .frame(height: 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
    }
}

// MARK: TodayWeeklyLoadCard(本周负荷柱状)
struct TodayWeeklyLoadCard: View {
    let loads: [Double]          // 最近 7 天负荷
    let acwrText: String

    private var maxLoad: Double { max(loads.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本周负荷")
                    .font(VelaTheme.subheadline().weight(.bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text(acwrText)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(loads.enumerated()), id: \.offset) { index, load in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == loads.count - 1 ? VelaTheme.brand : VelaTheme.fillSoft)
                            .frame(height: max(6, 52 * CGFloat(load / maxLoad)))
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64)
        }
        .padding(14)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }
}
