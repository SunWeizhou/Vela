import SwiftUI

struct TodaySignalGrid: View {
    let model: TodayExperienceModel
    let freshness: DataFreshness
    let accentColor: (DailyPlanAccent) -> Color

    var body: some View {
        let columns = [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("关键体征")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                DataFreshnessIndicator(freshness: freshness)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(model.signalCards) { card in
                    todaySignalCard(card)
                }
            }
        }
    }

    private func todaySignalCard(_ card: TodayExperienceSignalCard) -> some View {
        let accent = accentColor(card.accent)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
                Spacer()
                Text(card.value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.fg)
            }

            if card.trend.count > 1 {
                TodayMiniSparkline(values: card.trend, color: accent)
                    .frame(height: 24)
            } else {
                Text("暂无连续趋势")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            }

            Text(localizedReason(card.subtitle))
                .font(.system(size: 11))
                .lineLimit(2)
                .foregroundStyle(VelaTheme.fg2)
                .frame(minHeight: 28, alignment: .topLeading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 98, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }
}

private struct TodayMiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                var placeholder = Path()
                placeholder.move(to: CGPoint(x: 0, y: size.height * 0.5))
                placeholder.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(
                    placeholder,
                    with: .color(VelaTheme.border),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [4, 5])
                )
                return
            }
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 100
            let span = max(maxValue - minValue, 1)
            let stepX = size.width / CGFloat(values.count - 1)

            var path = Path()
            for (index, value) in values.enumerated() {
                let x = CGFloat(index) * stepX
                let normalized = (value - minValue) / span
                let y = size.height - CGFloat(normalized) * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
            )

            if let last = values.last {
                let normalized = (last - minValue) / span
                let point = CGPoint(
                    x: size.width,
                    y: size.height - CGFloat(normalized) * size.height
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}
