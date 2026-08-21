import SwiftUI

struct CoreMetricTrendSeries: Equatable {
    var title: String
    var valueText: String
    var icon: String
    var statusLabel: String
    var history: [Double]
}

enum CoreMetricTrendMapper {
    static func series(
        for metric: VelaMetricDetailView.MetricType,
        snapshots: [DailyHealthSnapshot],
        endingAt endDate: Date,
        calendar: Calendar = .current
    ) -> CoreMetricTrendSeries? {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        let values = snapshots
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
            .compactMap { value(for: metric, snapshot: $0) }

        guard let first = values.first, let latest = values.last else { return nil }
        let delta = latest - first
        let unit = unitSuffix(for: metric)
        // 阈值按指标相对化：体重/HRV 等不同量纲不能共用 0.05 一刀切。
        let threshold = max(abs(first) * 0.02, 0.05)
        let statusLabel: String
        if abs(delta) < threshold {
            statusLabel = "近30天基本稳定"
        } else {
            statusLabel = String(format: "近30天 %+.1f%@", delta, unit)
        }

        return CoreMetricTrendSeries(
            title: "近30天\(title(for: metric))",
            valueText: valueText(for: metric, value: latest),
            icon: icon(for: metric),
            statusLabel: statusLabel,
            history: normalize(values)
        )
    }

    private static func value(
        for metric: VelaMetricDetailView.MetricType,
        snapshot: DailyHealthSnapshot
    ) -> Double? {
        switch metric {
        case .strain: snapshot.strainScore
        case .recovery: snapshot.recoveryScore
        case .sleep: snapshot.sleepScore
        case .stress: snapshot.stressIndex
        case .energy: snapshot.currentEnergy ?? snapshot.energyBank
        case .hrv: snapshot.hrvAverage
        case .rhr: snapshot.restingHeartRate
        case .weight: snapshot.bodyWeight
        case .bodyFat: snapshot.bodyFatPercent
        case .respiratoryRate: snapshot.respiratoryRate
        case .bloodOxygen: snapshot.oxygenSaturation
        case .steps: snapshot.steps
        case .activeCalories: snapshot.activeCalories
        case .activeMinutes: snapshot.activeMinutes ?? snapshot.workoutDuration
        }
    }

    private static func title(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .strain: "耗力"
        case .recovery: "恢复"
        case .sleep: "睡眠"
        case .stress: "压力"
        case .energy: "能量"
        case .hrv: "心率变异性"
        case .rhr: "静息心率"
        case .weight: "体重"
        case .bodyFat: "体脂"
        case .respiratoryRate: "呼吸率"
        case .bloodOxygen: "血氧"
        case .steps: "今日步数"
        case .activeCalories: "活动消耗"
        case .activeMinutes: "活跃时长"
        }
    }

    private static func icon(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .strain: "figure.run"
        case .recovery: "heart.circle.fill"
        case .sleep: "moon.stars.fill"
        case .stress: "waveform.path.ecg"
        case .energy: "bolt.fill"
        case .hrv: "waveform.path.ecg"
        case .rhr: "heart.fill"
        case .weight: "scalemass.fill"
        case .bodyFat: "figure.arms.open"
        case .respiratoryRate: "lungs.fill"
        case .bloodOxygen: "drop.fill"
        case .steps: "shoeprints.fill"
        case .activeCalories: "flame.fill"
        case .activeMinutes: "clock.badge.checkmark"
        }
    }

    private static func unitSuffix(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .weight: return " kg"
        case .hrv: return " ms"
        case .rhr: return " bpm"
        default: return ""
        }
    }

    private static func valueText(
        for metric: VelaMetricDetailView.MetricType,
        value: Double
    ) -> String {
        switch metric {
        case .strain, .recovery, .sleep, .energy:
            return VelaMinimalFormatting.roundedPercentage(value)
        case .stress:
            return "\(Int(value.rounded()))"
        case .hrv:
            return "\(Int(value.rounded())) ms"
        case .rhr:
            return "\(Int(value.rounded())) bpm"
        case .weight:
            return String(format: "%.1f kg", value)
        case .bodyFat:
            return String(format: "%.1f%%", value)
        case .respiratoryRate:
            return "\(Int(value.rounded()))/min"
        case .bloodOxygen:
            return "\(Int(value.rounded()))%"
        case .steps:
            return "\(Int(value.rounded())) 步"
        case .activeCalories:
            return "\(Int(value.rounded())) kcal"
        case .activeMinutes:
            return "\(Int(value.rounded())) 分钟"
        }
    }

    private static func normalize(_ values: [Double]) -> [Double] {
        guard let minimum = values.min(), let maximum = values.max() else { return [] }
        let distance = maximum - minimum
        guard distance > 0 else { return values.map { _ in 0.5 } }
        return values.map { ($0 - minimum) / distance }
    }
}

struct TrendItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let statusLabel: String
    let statusColor: Color
    let graphColor: Color
    let history: [Double]
}

struct MetricTrendsSection: View {
    let isSleep: Bool
    let items: [TrendItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("趋势")
                .font(VelaTheme.footnote().weight(.bold))
                .foregroundStyle(VelaTheme.rhythmInk)
            
            VStack(spacing: 0) {
                if items.isEmpty {
                    Label("积累更多数据后显示长期变化", systemImage: "chart.line.uptrend.xyaxis")
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 12))
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                    Text(item.title)
                                        .font(VelaTheme.caption1().weight(.semibold))
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                    Spacer()
                                }
                                
                                HStack(alignment: .bottom) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.value)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .monospacedDigit()
                                            .foregroundStyle(VelaTheme.rhythmInk)
                                        Text(item.statusLabel)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(item.statusColor)
                                    }
                                    Spacer()
                                    
                                    // Live sparkline path graph
                                    if !item.history.isEmpty {
                                        SparklineLineGraph(data: item.history, color: item.graphColor, height: 32, width: 85)
                                    } else {
                                        Text("无可用趋势")
                                            .font(VelaTheme.caption2())
                                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                            .frame(width: 85, height: 32)
                                    }
                                }
                            }
                        }
                        .padding(14)

                        if index < items.count - 1 {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
            }
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            )
        }
    }
}
