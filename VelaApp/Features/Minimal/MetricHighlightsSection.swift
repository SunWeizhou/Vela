import SwiftUI

struct MetricHighlightsSection: View {
    let isSleep: Bool
    let metricColor: Color
    let leftTitle: String
    let leftIcon: String
    let leftValue: String
    let leftSubtitle: String?
    let rightTitle: String
    let rightIcon: String
    let rightValue: String
    let rightSubtitle: String?
    let guidanceText: String

    var body: some View {
        VStack(spacing: VelaTheme.cardGap) {
            HStack(spacing: VelaTheme.cardGap) {
                // Left Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(leftTitle)
                            .font(VelaTheme.caption1())
                            .fontWeight(.bold)
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        Spacer()
                        Image(systemName: leftIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metricColor)
                    }
                    
                    Text(leftValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                    
                    if let leftSub = leftSubtitle {
                        Text(leftSub)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            .lineLimit(1)
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(isSleep ? Color(hex: "#161512") : Color.white)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )

                // Right Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(rightTitle)
                            .font(VelaTheme.caption1())
                            .fontWeight(.bold)
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        Spacer()
                        Image(systemName: rightIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metricColor)
                    }
                    
                    Text(rightValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                    
                    if let rightSub = rightSubtitle {
                        Text(rightSub)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            .lineLimit(1)
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(isSleep ? Color(hex: "#161512") : Color.white)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }

            // Guidance Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(metricColor)
                    
                    Text("指导")
                        .font(VelaTheme.caption2())
                        .fontWeight(.bold)
                        .textCase(.uppercase)
                        .kerning(0.06)
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                }
                
                Text(guidanceText)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .fill(isSleep ? Color(hex: "#161512") : Color.white)
                    .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
            )
        }
    }
}
