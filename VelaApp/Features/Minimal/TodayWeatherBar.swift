import SwiftUI

struct TodayWeatherBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let weatherTemp: String
    let weatherStatusText: String
    let requestWeatherUpdate: () -> Void

    var body: some View {
        Button {
            requestWeatherUpdate()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "cloud.sun.fill")
                    .font(.system(size: 12))
                    .symbolRenderingMode(.multicolor)

                Text(weatherTemp)
                    .font(.system(.caption, design: .default, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)

                Text(weatherStatusText)
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(VelaTheme.cardBg, in: weatherShape)
            .overlay(weatherShape.stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            .contentShape(weatherShape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("天气：\(weatherStatusText)")
        .accessibilityHint("点按更新本地天气")
    }

    private var weatherShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: dynamicTypeSize.isAccessibilitySize ? 16 : VelaTheme.radiusPill,
            style: .continuous
        )
    }
}
