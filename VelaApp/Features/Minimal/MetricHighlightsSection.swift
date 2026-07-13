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
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(leftTitle)
                            .font(VelaTheme.caption1())
                            .fontWeight(.bold)
                            .foregroundStyle(VelaTheme.muted)
                        Spacer()
                        Image(systemName: leftIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metricColor)
                    }
                    
                    Text(leftValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VelaTheme.fg)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                    
                    if let leftSub = leftSubtitle {
                        Text(leftSub)
                            .font(VelaTheme.caption2())
                            .foregroundStyle(VelaTheme.muted)
                            .lineLimit(1)
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 68).padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        Text(rightTitle)
                            .font(VelaTheme.caption1())
                            .fontWeight(.bold)
                            .foregroundStyle(VelaTheme.muted)
                        Spacer()
                        Image(systemName: rightIcon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metricColor)
                    }
                    
                    Text(rightValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VelaTheme.fg)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.vertical, 2)
                    
                    if let rightSub = rightSubtitle {
                        Text(rightSub)
                            .font(VelaTheme.caption2())
                            .foregroundStyle(VelaTheme.muted)
                            .lineLimit(1)
                    } else {
                        Spacer().frame(height: 10)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(metricColor)
                    
                    Text("指导")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.muted)
                }
                
                Text(guidanceText)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.fg2)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
        )
    }
}
