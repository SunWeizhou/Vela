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
        case .strain:
            // --- Strain Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Timeline
                HStack {
                    Text("时间线")
                        .font(VelaTheme.footnote())
                        .fontWeight(.bold)
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    if dashboard.workouts.isEmpty {
                        Text("无活动")
                            .font(VelaTheme.footnote())
                            .fontWeight(.bold)
                            .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                        Text("此期间没有记录到活动。")
                            .font(VelaTheme.caption1())
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    } else {
                        ForEach(dashboard.workouts) { workout in
                            Text("\(workout.activityName) · \(VelaMinimalFormatting.duration(minutes: Int(workout.end.timeIntervalSince(workout.start) / 60.0)))")
                                .font(VelaTheme.caption1())
                                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.cardBg)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )

                // Heart Rate Zones
                VStack(alignment: .leading, spacing: 10) {
                    Text("心率区间")
                        .font(VelaTheme.footnote())
                        .fontWeight(.bold)
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)

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
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.cardBg)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }

        case .sleep:
            // --- Sleep Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Bedtime Circular Dial Wheel Widget
                VStack(alignment: .leading, spacing: 10) {
                    Text("分析")
                        .font(VelaTheme.footnote())
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: "#7E7A70"))
                    
                    VStack(spacing: 16) {
                        // Bedtime target labels
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("卧床")
                                    .font(VelaTheme.caption2())
                                    .foregroundStyle(Color(hex: "#7E7A70"))
                                Text(bedtimeText)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#F2EFE8"))
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("目标睡觉时间")
                                    .font(VelaTheme.caption2())
                                    .foregroundStyle(Color(hex: "#7E7A70"))
                                Text(targetBedtimeText)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#F2EFE8"))
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
                                .foregroundStyle(Color(hex: "#7E7A70"))
                                .frame(maxWidth: .infinity, minHeight: 100)
                        }
                        
                        Divider().background(Color(hex: "#2E2B25"))
                        
                        HStack {
                            Text("起床时间: \(wakeTimeText)")
                                .font(VelaTheme.caption1())
                                .foregroundStyle(Color(hex: "#BFB9AC"))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(Color(hex: "#161512"))
                            .shadow(color: Color.black.opacity(0.0), radius: 10, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }

                // Timeline Primary Sleep Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("时间线")
                            .font(VelaTheme.footnote())
                            .fontWeight(.bold)
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        Spacer()
                    }
                    
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(metricColor)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(metricColor.opacity(0.15)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("主要睡眠")
                                .font(VelaTheme.subheadline())
                                .fontWeight(.semibold)
                                .foregroundStyle(Color(hex: "#F2EFE8"))
                            Text(primarySleepStartText)
                                .font(VelaTheme.caption2())
                                .foregroundStyle(Color(hex: "#7E7A70"))
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(Color(hex: "#161512"))
                            .shadow(color: Color.black.opacity(0.0), radius: 10, y: 4)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                }
            }

        case .stress:
            // --- Stress Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedFullDateText)
                                .font(VelaTheme.caption2())
                                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            Text("今天的压力")
                                .font(VelaTheme.footnote())
                                .fontWeight(.bold)
                                .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                        }
                        Spacer()
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }

                    DailyStressChartView(isSleep: isSleep)
                        .frame(height: 145)
                        .padding(.vertical, 8)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.cardBg)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }

        default:
            // --- Default Evidence List for other metrics ---
            VStack(alignment: .leading, spacing: 10) {
                Text("主要限制因素")
                    .font(VelaTheme.footnote())
                    .fontWeight(.bold)
                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(limitingFactors, id: \.self) { factor in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(metricColor)
                                .frame(width: 6, height: 6)
                            Text(factor)
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(VelaTheme.cardBg)
                        .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.01), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .stroke(isSleep ? Color.white.opacity(0.08) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }
        }
    }
}
