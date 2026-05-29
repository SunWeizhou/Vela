import SwiftUI

struct HealthMetricCard: View {
    enum CardStyle {
        case hero
        case standard
        case compact
    }

    let title: String
    let value: String
    let subtitle: String
    let tint: Color
    var systemImage: String = "circle.fill"
    var minHeight: CGFloat?
    var style: CardStyle = .standard

    private var valueFontSize: CGFloat {
        switch style {
        case .hero: return 48
        case .standard: return 40
        case .compact: return 28
        }
    }

    var body: some View {
        Group {
            switch style {
            case .hero:
                heroLayout
            case .standard:
                standardLayout
            case .compact:
                compactLayout
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
    }

    // MARK: - Hero Layout

    private var heroLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(tint.opacity(0.15)))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)

                Spacer()
            }

            Text(value)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Accent bottom glow strip
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.4), tint.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .cornerRadius(1.5)
        }
        .padding(20)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(VelaTheme.heroCardBackground)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.08), Color.clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: VelaTheme.cardShadowColor, radius: 8, y: 2)
    }

    // MARK: - Standard Layout

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(tint.opacity(0.6))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(tint.opacity(0.15)))

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(1)

                    Spacer()
                }

                Text(value)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Compact Layout

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(tint.opacity(0.15)))

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)

                Spacer()
            }

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VelaTheme.elevatedSurface)
        )
    }
}
