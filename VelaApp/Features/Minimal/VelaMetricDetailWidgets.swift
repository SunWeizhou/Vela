import SwiftUI

struct MetricCustomWidgetsSection: View {
    let metric: VelaMetricDetailView.MetricType
    let isSleep: Bool
    let dashboard: DashboardSummary
    
    // Sleep parameters
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let wakeHour: Int
    let wakeMinute: Int
    let sleepTargetMinutes: Int
    let hasCompleteSleepTimes: Bool
    
    let bedtimeText: String
    let targetBedtimeText: String
    let wakeTimeText: String
    let primarySleepStartText: String
    
    // Timeline
    let selectedFullDateText: String
    
    // Heart Rate Zones
    let isLoadingHeartRateZones: Bool
    let heartRateZoneSummary: HeartRateZoneSummary?
    let heartRateZoneRowAction: (HeartRateZoneSummary.Zone, Double) -> AnyView
    let limitingFactors: [String]
    let metricColor: Color

    var body: some View {
        switch metric {
        case .recovery:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                Text("恢复基线")
                    .font(VelaTheme.footnote().weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                HStack(spacing: 10) {
                    recoveryBaselineMetric(
                        title: "HRV",
                        current: dashboard.recoveryMetrics.hrvMilliseconds,
                        baseline: dashboard.recoveryBaseline.hrvMilliseconds,
                        unit: "ms",
                        higherIsBetter: true
                    )
                    recoveryBaselineMetric(
                        title: "静息心率",
                        current: dashboard.recoveryMetrics.restingHeartRate,
                        baseline: dashboard.recoveryBaseline.restingHeartRate,
                        unit: "bpm",
                        higherIsBetter: false
                    )
                }

                Text("恢复分会结合睡眠、HRV、静息心率及前一日负荷；每项都与个人基线比较。")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .padding(.horizontal, 2)
            }

        case .strain:
            // --- Strain Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Timeline
                HStack {
                    Text("时间线")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.rhythmInk)
                    Spacer()
                }
                
                VelaTimelineCard(
                    items: dashboard.workouts.map { workout in
                        VelaTimelineItem(
                            id: workout.id.uuidString,
                            title: workout.activityName,
                            subtitle: VelaMinimalFormatting.duration(
                                minutes: Int(workout.end.timeIntervalSince(workout.start) / 60.0)
                            ),
                            systemImage: "figure.run",
                            domain: .strain
                        )
                    },
                    emptyMessage: "此期间没有记录到活动。"
                )

                // Heart Rate Zones
                VStack(alignment: .leading, spacing: 10) {
                    Text("心率区间")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.rhythmInk)

                    if isLoadingHeartRateZones {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 72)
                    } else if let heartRateZoneSummary {
                        VStack(spacing: 10) {
                            ForEach(heartRateZoneSummary.zones) { zone in
                                heartRateZoneRowAction(zone, heartRateZoneSummary.totalMinutes)
                            }
                        }
                    } else {
                        Text("此期间没有可用的逐点心率，无法生成分区明细。")
                            .font(VelaTheme.caption1())
                            .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }

        case .sleep:
            // --- Sleep Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Bedtime Circular Dial Wheel Widget
                VStack(alignment: .leading, spacing: 10) {
                    Text("睡眠节奏与时钟")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    
                    VStack(spacing: 16) {
                        // Bedtime target labels
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("入睡时间")
                                    .font(VelaTheme.caption2())
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                Text(bedtimeText)
                                    .font(.system(.body, design: .default, weight: .bold))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("目标就寝时间")
                                    .font(VelaTheme.caption2())
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                Text(targetBedtimeText)
                                    .font(.system(.body, design: .default, weight: .bold))
                                    .foregroundStyle(VelaTheme.sleepColor)
                            }
                        }
                        
                        if hasCompleteSleepTimes {
                            SleepClockWheelView(
                                bedtimeHour: bedtimeHour,
                                bedtimeMinute: bedtimeMinute,
                                wakeHour: wakeHour,
                                wakeMinute: wakeMinute,
                                targetSleepMinutes: sleepTargetMinutes
                            )
                            .frame(height: 220)
                        } else {
                            Text("暂无完整睡眠起止时间，无法绘制睡眠时钟。")
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .frame(maxWidth: .infinity, minHeight: 100)
                        }
                        
                        Divider().background(VelaTheme.rhythmMist)
                        
                        HStack {
                            Text("起床时间: \(wakeTimeText)")
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            Spacer()
                            Text("目标: \(VelaMinimalFormatting.duration(minutes: sleepTargetMinutes))")
                                .font(VelaTheme.caption1().weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(VelaTheme.rhythmCanvasRaised)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                    )
                }

                // Timeline Primary Sleep Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("时间线")
                            .font(VelaTheme.footnote().weight(.bold))
                            .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.rhythmInk)
                        Spacer()
                    }
                    
                    VelaTimelineCard(
                        items: hasCompleteSleepTimes
                            ? [
                                VelaTimelineItem(
                                    id: "primary-sleep",
                                    title: "主要睡眠",
                                    subtitle: primarySleepStartText,
                                    systemImage: "moon.stars.fill",
                                    domain: .sleep
                                )
                            ]
                            : [],
                        emptyMessage: "暂无完整睡眠起止时间。"
                    )
                }
            }

        case .stress:
            // --- Stress Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Stress Trend and Components Card
                VStack(alignment: .leading, spacing: 14) {
                    Text("全天压力趋势")
                        .font(VelaTheme.footnote().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    DailyStressChartView(
                        metric: .stress,
                        selectedDate: dashboard.date,
                        restingHeartRate: dashboard.recoveryBaseline.restingHeartRate ?? dashboard.recoveryMetrics.restingHeartRate,
                        morningEnergy: dashboard.energy.morningEnergy,
                        currentEnergy: dashboard.energy.value,
                        isSleep: isSleep
                    )
                    .frame(height: 140)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }

        case .energy:
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("能量变化")
                                .font(VelaTheme.footnote().weight(.bold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text("从早间储备到当前状态")
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }
                        Spacer()
                        Text("\(Int(dashboard.energy.morningEnergy.rounded())) → \(dashboard.energy.formattedScore)")
                            .font(VelaTheme.subheadline().weight(.bold).monospacedDigit())
                            .foregroundStyle(metricColor)
                    }

                    DailyStressChartView(
                        metric: .energy,
                        selectedDate: dashboard.date,
                        restingHeartRate: dashboard.recoveryBaseline.restingHeartRate
                            ?? dashboard.recoveryMetrics.restingHeartRate,
                        morningEnergy: dashboard.energy.morningEnergy,
                        currentEnergy: dashboard.energy.value,
                        isSleep: isSleep
                    )
                    .frame(height: 145)

                    HStack(spacing: 8) {
                        energyDriver("负荷", value: dashboard.energy.components["strain_drain"])
                        energyDriver("压力", value: dashboard.energy.components["stress_drain"])
                        energyDriver("时间", value: dashboard.energy.components["time_drain"])
                        energyDriver("补充", value: dashboard.energy.components["recharge"], positive: true)
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }

        default:
            // --- Default Evidence List for other metrics ---
            VStack(alignment: .leading, spacing: 10) {
                Text("主要限制因素")
                    .font(VelaTheme.footnote())
                    .fontWeight(.bold)
                    .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(limitingFactors, id: \.self) { factor in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(metricColor)
                                .frame(width: 6, height: 6)
                            Text(factor)
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(isSleep ? VelaTheme.mistGray : VelaTheme.fg2)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }
        }
    }

    private func recoveryBaselineMetric(
        title: String,
        current: Double?,
        baseline: Double?,
        unit: String,
        higherIsBetter: Bool
    ) -> some View {
        let delta = current.flatMap { value in baseline.map { value - $0 } }
        let isPositive = delta.map { higherIsBetter ? $0 >= 0 : $0 <= 0 }
        return VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
            Text(current.map { "\(Int($0.rounded())) \(unit)" } ?? "--")
                .font(VelaTheme.cardValue())
                .foregroundStyle(VelaTheme.rhythmInk)
                .monospacedDigit()
            Text(baseline.map { "基线 \(Int($0.rounded())) \(unit)" } ?? "个人基线建立中")
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            if let delta, let isPositive {
                Label(
                    "\(delta >= 0 ? "+" : "")\(String(format: "%.1f", delta))",
                    systemImage: isPositive ? "arrow.up.right" : "arrow.down.right"
                )
                .font(VelaTheme.caption2().weight(.semibold))
                .foregroundStyle(isPositive ? VelaTheme.recoveryColor : VelaTheme.warn)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }

    private func energyDriver(
        _ title: String,
        value: Double?,
        positive: Bool = false
    ) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
            Text(value.map { "\(positive ? "+" : "−")\(String(format: "%.0f", abs($0)))" } ?? "--")
                .font(VelaTheme.caption1().weight(.bold).monospacedDigit())
                .foregroundStyle(positive ? VelaTheme.recoveryColor : VelaTheme.fg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(VelaTheme.rhythmMist.opacity(0.35), in: RoundedRectangle(cornerRadius: VelaTheme.radiusSm, style: .continuous))
    }
}
