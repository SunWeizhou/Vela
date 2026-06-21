import SwiftUI

struct DailyStressChartView: View {
    let isSleep: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            Text("暂无连续压力采样")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
            Text("同步更多日记录后，这里会展示真实趋势。")
                .font(.system(size: 11))
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
