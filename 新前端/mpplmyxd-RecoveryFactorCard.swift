import SwiftUI

struct RecoveryFactorCard: View {
    let name: String
    let icon: String
    let tint: Color
    let todayValue: String
    let baselineValue: String
    let delta: String
    let isPositive: Bool
    let weight: Double

    private var deltaColor: Color {
        isPositive ? VelaTheme.recovery : VelaTheme.stress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top: icon + name
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(tint.opacity(0.15)))

                Text(name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)

                Spacer()
            }

            // Middle: today value + delta
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(todayValue)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(delta)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(deltaColor)

                Spacer()
            }

            Text(baselineValue)
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(1)

            // Bottom: weight
            Text(L10n.t("Weight: \(Int(weight * 100))%", "权重：\(Int(weight * 100))%"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.mutedText.opacity(0.7))
        }
        .compactCard()
    }
}
