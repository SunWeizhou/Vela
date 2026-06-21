import SwiftUI

struct TodayWeatherBar: View {
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)

                Text(weatherStatusText)
                    .font(.system(size: 10))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(VelaTheme.cardBg))
            .overlay(Capsule().stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("天气：\(weatherStatusText)")
        .accessibilityHint("点按更新本地天气")
    }
}
