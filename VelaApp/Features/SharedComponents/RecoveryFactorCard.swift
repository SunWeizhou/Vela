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
                    .background(Circle().fill(tint.opacity(0.12)))

                Text(name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)

                Spacer()
                
                // Top-right weight badge
                Text("\(Int(weight * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.mutedText)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.05)))
            }

            // Middle: today value + delta
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(todayValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)

                if !delta.isEmpty {
                    Text(delta)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(deltaColor)
                }

                Spacer()
            }

            Text(baselineValue)
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(1)

            // Bottom: weight progress bar
            VStack(alignment: .leading, spacing: 2) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 3)
                        
                        Capsule()
                            .fill(tint.opacity(0.7))
                            .frame(width: geo.size.width * weight, height: 3)
                            .shadow(color: tint.opacity(0.3), radius: 1)
                    }
                }
                .frame(height: 3)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.12), Color.black.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
