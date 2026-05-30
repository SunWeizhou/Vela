import SwiftUI

// MARK: - VelaMetricDetailView — 指标详情 (Bevel iOS 26 Parity Rebuild)
// 100% Visual Parity with Bevel App: Warm-White Canvas, White cockpit cards, Custom Circular dials, Spline Stress Charts & Starry Sleep Dark Mode

struct VelaMetricDetailView: View {
    let metric: MetricType
    @Environment(\.colorScheme) private var cs
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    enum MetricType: String, CaseIterable {
        case strain, recovery, sleep, stress, energy, hrv, rhr
    }

    var body: some View {
        let isSleep = metric == .sleep
        
        ZStack {
            // Background Canvas (Forced dark for sleep, adaptive warm-white for others)
            (isSleep ? Color(hex: "#0A0908") : VelaTheme.bg)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                metricNavigationBar(isSleep: isSleep)
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.vertical, 8)

                ScrollView {
                    VStack(spacing: VelaTheme.cardGap) {
                        // 1. Procedural Landscape Header Card
                        landscapeHeaderSection(isSleep: isSleep)
                            .padding(.top, 8)

                        // 2. Double Highlight metrics
                        doubleHighlightsSection(isSleep: isSleep)

                        // 3. Guidance Card
                        guidanceSection(isSleep: isSleep)

                        // 4. Custom Widgets & Timeline based on Metric Type
                        customWidgetsSection(isSleep: isSleep)

                        // 5. Trend Sparkline Cards List
                        trendsSection(isSleep: isSleep)
                    }
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.bottom, 100) // Clear floating tab bars
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func metricNavigationBar(isSleep: Bool) -> some View {
        HStack {
            metricNavigationButton(
                systemName: "chevron.left",
                isSleep: isSleep,
                action: { dismiss() }
            )

            Spacer()

            VStack(spacing: 2) {
                Text(navTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)

                HStack(spacing: 3) {
                    Text(selectedDateText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 6, weight: .bold))
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                metricNavigationButton(systemName: "square.and.arrow.up", isSleep: isSleep)
                metricNavigationButton(systemName: "info.circle", isSleep: isSleep)
            }
        }
    }

    private func metricNavigationButton(
        systemName: String,
        isSleep: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSleep ? Color.black.opacity(0.4) : Color.white.opacity(0.85))
                )
        }
        .buttonStyle(.plain)
    }

    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(dashboardVM.selectedDate) ? "今天，M月d日" : "M月d日"
        return formatter.string(from: dashboardVM.selectedDate)
    }

    private var selectedFullDateText: String {
        dashboardVM.selectedDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_Hans_CN")))
    }

    // MARK: - 1. Procedural Landscape Header
    private func landscapeHeaderSection(isSleep: Bool) -> some View {
        ZStack {
            // Vector Background Graphic based on Metric
            Group {
                switch metric {
                case .strain:
                    DesertLandscape()
                case .sleep:
                    NightLandscape()
                case .stress:
                    CoastalLandscape()
                case .recovery:
                    ForestLandscape()
                case .energy:
                    MeadowLandscape()
                case .hrv:
                    MountainLakeLandscape()
                case .rhr:
                    CalmSunsetLandscape()
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
            
            // Score Rings & Metric Text Overlays
            VStack(spacing: 8) {
                Spacer()
                
                // Ring/Gauge Container
                ZStack {
                    if metric == .stress {
                        DottedCircleGauge(
                            score: dynamicScore,
                            labelText: "低",
                            size: 110,
                            color: metricColor
                        )
                        .background(
                            Circle()
                                .fill(isSleep ? Color(hex: "#161512").opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        )
                    } else {
                        // Standard Bevel circular progress ring
                        BevelScoreRing(
                            score: max(0.01, dynamicScore / 100.0),
                            color: metricColor,
                            useGradient: true,
                            size: 110,
                            label: "",
                            valueText: dynamicValueText
                        )
                        .background(
                            Circle()
                                .fill(isSleep ? Color(hex: "#161512").opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        )
                    }
                }
                .padding(.bottom, 8)

                // Subtitle/Target Text below the ring
                if metric == .strain {
                    let range = dashboard.strain.recommendedRange
                    Text("目标耗力: \(range.lowerBound) - \(range.upperBound)%")
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSleep ? Color(hex: "#161512").opacity(0.6) : Color.white.opacity(0.6))
                        )
                } else if metric == .sleep {
                    Text("目标睡眠: 8小时0分钟")
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(hex: "#161512").opacity(0.6)))
                } else if metric == .stress {
                    Text("目标压力: 保持平静")
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSleep ? Color(hex: "#161512").opacity(0.6) : Color.white.opacity(0.6)))
                } else {
                    Text(metricSubtitle)
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSleep ? Color(hex: "#161512").opacity(0.6) : Color.white.opacity(0.6)))
                }
                
                Spacer()
                    .frame(height: 16)
            }
        }
        .frame(height: 240)
    }

    // MARK: - 2. Double Highlight Cards (Duration, Calories, Sleep, HRV etc.)
    private func doubleHighlightsSection(isSleep: Bool) -> some View {
        HStack(spacing: VelaTheme.cardGap) {
            // Left Card
            HStack(spacing: 12) {
                Image(systemName: leftIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(metricColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(metricColor.opacity(isSleep ? 0.15 : 0.08)))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(leftTitle)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    Text(leftValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                    if let leftSub = leftSubtitle {
                        Text(leftSub)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
            )

            // Right Card
            HStack(spacing: 12) {
                Image(systemName: rightIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(metricColor)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(metricColor.opacity(isSleep ? 0.15 : 0.08)))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(rightTitle)
                            .font(VelaTheme.caption1())
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        if metric == .strain {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(metricColor)
                        }
                    }
                    Text(rightValue)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                    if let rightSub = rightSubtitle {
                        Text(rightSub)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }
                }
                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                    .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
            )
        }
    }

    // MARK: - 3. Guidance Card
    private func guidanceSection(isSleep: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("指导")
                .font(VelaTheme.caption2())
                .fontWeight(.bold)
                .textCase(.uppercase)
                .kerning(0.06)
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            
            Text(guidanceText)
                .font(VelaTheme.subheadline())
                .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
        )
    }

    // MARK: - 4. Custom Widgets & Timeline based on Metric Type
    @ViewBuilder
    private func customWidgetsSection(isSleep: Bool) -> some View {
        switch metric {
        case .strain:
            // --- Strain Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Timeline
                timelineHeaderSection(isSleep: isSleep)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("无活动")
                        .font(VelaTheme.footnote())
                        .fontWeight(.bold)
                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                    Text("此期间没有进行任何活动。")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
                )

                // Heart Rate Zones
                VStack(alignment: .leading, spacing: 10) {
                    Text("心率区间")
                        .font(VelaTheme.footnote())
                        .fontWeight(.bold)
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    
                    VStack(spacing: 8) {
                        HeartRateZoneRow(zone: 0, duration: "00:00:00", limits: "0 - 97 bpm", color: .gray, isSleep: isSleep)
                        HeartRateZoneRow(zone: 1, duration: "00:00:00", limits: "98 - 116 bpm", color: .blue, isSleep: isSleep)
                        HeartRateZoneRow(zone: 2, duration: "00:00:00", limits: "117 - 136 bpm", color: .green, isSleep: isSleep)
                        HeartRateZoneRow(zone: 3, duration: "00:00:00", limits: "137 - 155 bpm", color: .yellow, isSleep: isSleep)
                        HeartRateZoneRow(zone: 4, duration: "00:00:00", limits: "156 - 175 bpm", color: .orange, isSleep: isSleep)
                        HeartRateZoneRow(zone: 5, duration: "00:00:00", limits: "176 - 194 bpm", color: .red, isSleep: isSleep)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
                    )
                }
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
                                Text("23:22")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#F2EFE8"))
                            }
                        }
                        
                        // Vector Circular Sleep Clock Dial
                        SleepClockWheelView(
                            bedtimeHour: bedtimeHour,
                            bedtimeMinute: bedtimeMinute,
                            wakeHour: wakeHour,
                            wakeMinute: wakeMinute
                        )
                        .frame(height: 220)
                        
                        Divider().background(Color(hex: "#2E2B25"))
                        
                        HStack {
                            Text("起床时间: 07:00")
                                .font(VelaTheme.caption1())
                                .foregroundStyle(Color(hex: "#BFB9AC"))
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(hex: "#7E7A70"))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(Color(hex: "#161512"))
                    )
                }

                // Timeline Primary Sleep Card
                VStack(alignment: .leading, spacing: 10) {
                    timelineHeaderSection(isSleep: isSleep)
                    
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
                            Text("2026/5/30 00:38")
                                .font(VelaTheme.caption2())
                                .foregroundStyle(Color(hex: "#7E7A70"))
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#7E7A70"))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(Color(hex: "#161512"))
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

                    // Daily Stress Spline Line Chart Widget
                    DailyStressChartView(isSleep: isSleep)
                        .frame(height: 120)
                        .padding(.vertical, 8)
                    
                    HStack {
                        Spacer()
                        Text("时长: 10:30:00")
                            .font(VelaTheme.caption2())
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }

                    Divider().background(isSleep ? Color(hex: "#2E2B25") : VelaTheme.borderSoft)

                    // Stress Segment progress bars
                    VStack(spacing: 10) {
                        StressProgressBarRow(label: "高", percent: 0.04, duration: "0:24:00", color: VelaTheme.danger, isSleep: isSleep)
                        StressProgressBarRow(label: "中", percent: 0.25, duration: "2:36:00", color: VelaTheme.warn, isSleep: isSleep)
                        StressProgressBarRow(label: "低", percent: 0.71, duration: "7:30:00", color: VelaTheme.success, isSleep: isSleep)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                        .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
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
                        .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
                )
            }
        }
    }

    private func timelineHeaderSection(isSleep: Bool) -> some View {
        HStack {
            Text("时间线")
                .font(VelaTheme.footnote())
                .fontWeight(.bold)
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            Spacer()
            if metric == .strain {
                // Empty action button
            } else if metric == .sleep {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#7E7A70"))
            }
        }
    }

    // MARK: - 5. Trend Sparkline Cards List
    private func trendsSection(isSleep: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("趋势")
                .font(VelaTheme.footnote())
                .fontWeight(.bold)
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            
            VStack(spacing: VelaTheme.cardGap) {
                ForEach(trendItems) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                                Text(item.title)
                                    .font(VelaTheme.caption1())
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            }
                            
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.value)
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
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
                                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                                        .frame(width: 85, height: 32)
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
                    )
                }
            }
        }
    }

    // MARK: - Dynamic Dashboard Mapping Helpers

    private var navTitle: String {
        switch metric {
        case .strain:   "耗力"
        case .recovery: "恢复"
        case .sleep:    "睡眠"
        case .stress:   "压力"
        case .energy:   "能量"
        case .hrv:      "心率变异性"
        case .rhr:      "静息心率"
        }
    }

    private var metricColor: Color {
        switch metric {
        case .strain:   VelaTheme.strainColor
        case .recovery: VelaTheme.recoveryColor
        case .sleep:    VelaTheme.sleepColor
        case .stress:   VelaTheme.stressColor
        case .energy:   VelaTheme.energyColor
        case .hrv:      VelaTheme.recoveryColor
        case .rhr:      VelaTheme.accent
        }
    }

    private var dynamicScore: Double {
        switch metric {
        case .strain:
            return dashboard.strain.hasData ? dashboard.strain.score : 0
        case .recovery:
            return dashboard.recovery.hasData ? dashboard.recovery.score : 0
        case .sleep:
            return dashboard.sleepScore.hasData ? dashboard.sleepScore.score : 0
        case .stress:
            return dashboard.stress.hasData ? dashboard.stress.stressIndex : 0
        case .energy:
            return dashboard.energy.hasData ? dashboard.energy.currentEnergy : 0
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds ?? 0
        case .rhr:
            return dashboard.recoveryMetrics.restingHeartRate ?? 0
        }
    }

    private var dynamicValueText: String {
        guard hasMetricData else { return "--" }
        if metric == .hrv {
            return "\(Int(dynamicScore)) ms"
        } else if metric == .rhr {
            return "\(Int(dynamicScore)) bpm"
        } else if metric == .stress {
            return "\(Int(dynamicScore))"
        } else {
            return "\(Int(dynamicScore))%"
        }
    }

    private var metricSubtitle: String {
        guard hasMetricData else { return "暂无数据" }
        switch metric {
        case .strain:
            return strainTargetLabel(dashboard.strain.targetStatus)
        case .recovery:
            return scoreBandLabel(dashboard.recovery.band) + "恢复"
        case .sleep:
            return scoreBandLabel(dashboard.sleepScore.band) + "睡眠"
        case .stress:
            return stressBandLabel(dashboard.stress.band) + "压力"
        case .energy:
            return energyStatusLabel(dashboard.energy.status)
        case .hrv:
            return "正常范围"
        case .rhr:
            return "正常范围"
        }
    }

    private var hasMetricData: Bool {
        switch metric {
        case .strain: dashboard.strain.hasData
        case .recovery: dashboard.recovery.hasData
        case .sleep: dashboard.sleepScore.hasData
        case .stress: dashboard.stress.hasData
        case .energy: dashboard.energy.hasData
        case .hrv: dashboard.recoveryMetrics.hrvMilliseconds != nil
        case .rhr: dashboard.recoveryMetrics.restingHeartRate != nil
        }
    }

    // MARK: - Double Highlights Mapping
    private var leftIcon: String {
        switch metric {
        case .strain:   "timer"
        case .sleep:    "bed.double.fill"
        case .stress:   "waveform.path.ecg"
        default:        "heart.fill"
        }
    }

    private var leftTitle: String {
        switch metric {
        case .strain:   "时长"
        case .sleep:    "卧床时间"
        case .stress:   "上次心率变异性"
        case .recovery: "昨日 RHR"
        case .energy:   "日间最高"
        case .hrv:      "基线平均"
        case .rhr:      "基线平均"
        }
    }

    private var leftValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))分钟" } ?? "--"
        case .sleep:
            if let bed = dashboard.sleepSummary.bedtime, let wake = dashboard.sleepSummary.wakeTime {
                let diffMin = Int(wake.timeIntervalSince(bed) / 60)
                let hrs = diffMin / 60
                let mins = diffMin % 60
                return "\(hrs)小时\(mins)分钟"
            }
            return "--"
        case .stress:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .recovery:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .energy:
            return dashboard.energy.hasData ? "\(Int(dashboard.energy.morningEnergy)) 分" : "--"
        case .hrv:
            return dashboard.recoveryBaseline.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .rhr:
            return dashboard.recoveryBaseline.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        }
    }

    private var leftSubtitle: String? {
        if metric == .stress {
            return "更新时间: 10:42"
        }
        return nil
    }

    private var rightIcon: String {
        switch metric {
        case .strain:   "flame.fill"
        case .sleep:    "clock.fill"
        case .stress:   "heart.fill"
        default:        "bolt.fill"
        }
    }

    private var rightTitle: String {
        switch metric {
        case .strain:   "总能量"
        case .sleep:    "睡眠时长"
        case .stress:   "上次心率"
        case .recovery: "今日 HRV"
        case .energy:   "日间最低"
        case .hrv:      "今日读数"
        case .rhr:      "今日读数"
        }
    }

    private var rightValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
        case .sleep:
            let mins = dashboard.sleepSummary.totalSleepMinutes
            if mins > 0 {
                return "\(mins / 60)小时\(mins % 60)分钟"
            }
            return "--"
        case .stress:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        case .recovery:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .energy:
            return dashboard.energy.hasData ? "\(Int(dashboard.energy.currentEnergy)) 分" : "--"
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0)) ms" } ?? "--"
        case .rhr:
            return dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0)) bpm" } ?? "--"
        }
    }

    private var rightSubtitle: String? {
        if metric == .stress {
            return "更新时间: 10:42"
        }
        return nil
    }

    // MARK: - Sleep Clock Helpers
    private var bedtimeHour: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.hour, from: bed)
        }
        return 22
    }
    private var bedtimeMinute: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.minute, from: bed)
        }
        return 52
    }
    private var wakeHour: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.hour, from: wake)
        }
        return 8
    }
    private var wakeMinute: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.minute, from: wake)
        }
        return 39
    }
    private var bedtimeText: String {
        String(format: "%02d:%02d", bedtimeHour, bedtimeMinute)
    }

    // MARK: - Guidance text mapping
    private var guidanceText: String {
        guard hasMetricData else { return "完成 Apple 健康同步后，这里会展示基于真实数据的分析。" }
        switch metric {
        case .strain:
            return "你的身体处于中度恢复状态。进行令你感到舒适的活动。"
        case .sleep:
            return "你的睡眠表现一致。今晚避免在睡前饮食，喝水和锻炼，以改善睡眠。"
        case .stress:
            return "你的压力水平低于平时。继续努力！低压力对于良好的恢复 and 健康机能至关重要。"
        case .recovery:
            return "极佳的恢复状态！生理指标均恢复到你的历史优良区间，是今天进行高质量运动或重体力工作的完美窗口。"
        case .energy:
            return "当前能量非常充足。您的电量储备良好，能够在高强度活动中保持极高的专注力与效能。"
        case .hrv:
            return "HRV 表现稳定，表明您的植物神经系统处于极佳的平衡和适应状态，压力耐受性优秀。"
        case .rhr:
            return "静息心率保持在低点。这代表您的心血管效率良好，心脏不需要过度工作来维持基本代谢。"
        }
    }

    // MARK: - Trend Items Grid mapping
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

    private var trendItems: [TrendItem] {
        []
    }

    private var previewTrendItems: [TrendItem] {
        switch metric {
        case .strain:
            return [
                TrendItem(title: "耗力分数", value: "59%", icon: "sun.max.fill", statusLabel: "低于正常值", statusColor: VelaTheme.accent, graphColor: VelaTheme.strainColor, history: [0.35, 0.42, 0.48, 0.55, 0.46, 0.54, 0.59]),
                TrendItem(title: "锻炼时长", value: "28分钟", icon: "timer", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.strainColor, history: [0.1, 0.25, 0.15, 0.0, 0.35, 0.1, 0.28]),
                TrendItem(title: "日间心率", value: "65 bpm", icon: "heart.fill", statusLabel: "低于正常值", statusColor: VelaTheme.accent, graphColor: VelaTheme.strainColor, history: [0.6, 0.65, 0.62, 0.68, 0.61, 0.63, 0.58]),
                TrendItem(title: "总能量", value: "420 kcal", icon: "flame.fill", statusLabel: "低于正常值", statusColor: VelaTheme.accent, graphColor: VelaTheme.strainColor, history: [0.3, 0.35, 0.38, 0.45, 0.31, 0.39, 0.42]),
                TrendItem(title: "步数", value: "376", icon: "shoeprints.fill", statusLabel: "低于正常值", statusColor: VelaTheme.accent, graphColor: VelaTheme.strainColor, history: [0.4, 0.45, 0.38, 0.42, 0.35, 0.39, 0.31])
            ]
        case .sleep:
            return [
                TrendItem(title: "睡眠评分", value: "83%", icon: "sparkles", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.sleepColor, history: [0.78, 0.82, 0.85, 0.8, 0.84, 0.81, 0.83]),
                TrendItem(title: "睡眠时长", value: "7小时55分钟", icon: "clock.fill", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.sleepColor, history: [0.75, 0.8, 0.82, 0.76, 0.81, 0.78, 0.79]),
                TrendItem(title: "REM 睡眠", value: "1小时51分钟", icon: "moon.fill", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.sleepColor, history: [0.6, 0.65, 0.7, 0.62, 0.68, 0.66, 0.64]),
                TrendItem(title: "深层睡眠", value: "29分钟", icon: "moon.stars.fill", statusLabel: "偏低范围", statusColor: VelaTheme.accent, graphColor: VelaTheme.sleepColor, history: [0.4, 0.45, 0.38, 0.42, 0.35, 0.4, 0.3]),
                TrendItem(title: "睡眠时间", value: "00:38", icon: "bed.double.fill", statusLabel: "正常", statusColor: VelaTheme.success, graphColor: VelaTheme.sleepColor, history: [0.5, 0.48, 0.52, 0.49, 0.51, 0.53, 0.5]),
                TrendItem(title: "起来时间", value: "08:39", icon: "alarm.fill", statusLabel: "正常", statusColor: VelaTheme.success, graphColor: VelaTheme.sleepColor, history: [0.6, 0.62, 0.59, 0.64, 0.61, 0.63, 0.65]),
                TrendItem(title: "入睡时间", value: "无数据", icon: "circle", statusLabel: "无可用趋势", statusColor: .gray, graphColor: VelaTheme.sleepColor, history: [])
            ]
        case .stress:
            return [
                TrendItem(title: "压力分数", value: "22", icon: "waveform.path.ecg", statusLabel: "低于正常值", statusColor: VelaTheme.success, graphColor: VelaTheme.stressColor, history: [0.25, 0.3, 0.28, 0.35, 0.22, 0.26, 0.21]),
                TrendItem(title: "无活动压力", value: "33", icon: "figure.walk", statusLabel: "低于正常值", statusColor: VelaTheme.success, graphColor: VelaTheme.stressColor, history: [0.35, 0.38, 0.32, 0.36, 0.31, 0.34, 0.33]),
                TrendItem(title: "睡眠压力", value: "19", icon: "moon.fill", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.stressColor, history: [0.2, 0.22, 0.18, 0.25, 0.19, 0.21, 0.19])
            ]
        default:
            return [
                TrendItem(title: "恢复评分", value: "83%", icon: "heart.fill", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.recoveryColor, history: [0.78, 0.82, 0.85, 0.8, 0.84, 0.81, 0.83]),
                TrendItem(title: "生物年龄", value: "24", icon: "sparkles", statusLabel: "优于历史值", statusColor: VelaTheme.success, graphColor: VelaTheme.accent, history: [0.8, 0.82, 0.84, 0.83, 0.85, 0.86, 0.88]),
                TrendItem(title: "水分摄入", value: "2000 ml", icon: "drop.fill", statusLabel: "正常范围", statusColor: VelaTheme.success, graphColor: VelaTheme.recoveryColor, history: [0.5, 0.6, 0.55, 0.7, 0.65, 0.8, 0.8])
            ]
        }
    }

    // MARK: - Evidence / Limiting Factors Fallback Helpers
    private func scoreBandLabel(_ band: MetricBand) -> String {
        switch band {
        case .veryLow: return "很低"
        case .low: return "低"
        case .normal: return "正常"
        case .high: return "高"
        case .veryHigh: return "很高"
        }
    }

    private func stressBandLabel(_ band: MetricBand) -> String {
        switch band {
        case .veryLow: return "平静"
        case .low: return "正常"
        case .normal: return "偏高"
        case .high, .veryHigh: return "高"
        }
    }

    private func energyStatusLabel(_ status: EnergyBankStatus) -> String {
        switch status {
        case .depleted: return "耗竭"
        case .low: return "偏低"
        case .stable: return "稳定"
        case .strong: return "充足"
        }
    }

    private func strainTargetLabel(_ target: StrainTargetStatus) -> String {
        switch target {
        case .belowTarget: return "低于目标"
        case .withinTarget: return "在目标范围"
        case .aboveTarget: return "高于目标"
        }
    }

    private var limitingFactors: [String] {
        switch metric {
        case .recovery:
            return ["今日静息心率偏高 (+2 bpm)", "HRV 读数略微受限", "睡眠期间有轻度呼吸干扰"]
        case .energy:
            return ["卡路里盈余稍显不足", "脱水指数轻度上浮", "睡眠深度稍显欠缺"]
        case .hrv:
            return ["昨日压力指数偏高导致轻微压抑", "夜间睡眠觉醒次数超标", "交感神经相对兴奋"]
        case .rhr:
            return ["清晨体温微升", "睡前摄入咖啡因导致残余心跳率上浮", "训练残留中度疲劳"]
        default:
            return ["暂无显著限制因素", "所有体征处于绿色基线"]
        }
    }
}

// MARK: - Heart Rate Zone Row Subview
struct HeartRateZoneRow: View {
    let zone: Int
    let duration: String
    let limits: String
    let color: Color
    let isSleep: Bool
    
    var body: some View {
        HStack {
            Text("\(zone)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 22, height: 22)
                .background(RoundedRectangle(cornerRadius: 6).fill(color))
            
            Text(duration)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(isSleep ? Color(hex: "#BFB9AC") : VelaTheme.fg2)
                .padding(.leading, 8)
            
            Spacer()
            
            Text(limits)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Stress Segment Progress Bar Row
struct StressProgressBarRow: View {
    let label: String
    let percent: Double
    let duration: String
    let color: Color
    let isSleep: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(VelaTheme.caption1())
                .fontWeight(.bold)
                .foregroundStyle(color)
                .frame(width: 16)
            
            // Continuous rounded progress bar
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isSleep ? Color(hex: "#2E2B25") : VelaTheme.borderSoft)
                    .frame(height: 8)
                
                Capsule()
                    .fill(color)
                    .frame(width: max(8, CGFloat(percent) * 160), height: 8)
            }
            .frame(width: 160)
            
            Spacer()
            
            Text("\(Int(percent * 100))%")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
            
            Text(duration)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PROCEDURAL LANDSCAPES (100% Native vector art gradients & dunes)

struct DesertLandscape: View {
    var body: some View {
        ZStack {
            // Sky gradient
            LinearGradient(
                colors: [Color(hex: "#D2E7F9"), Color(hex: "#F5E6D8"), Color(hex: "#FFF6E5")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Distant soft orange sun
            Circle()
                .fill(Color(hex: "#FFDDA1").opacity(0.8))
                .frame(width: 60, height: 60)
                .blur(radius: 6)
                .offset(x: -40, y: -20)
            
            // Sand dunes
            Path { path in
                path.move(to: CGPoint(x: 0, y: 160))
                path.addQuadCurve(to: CGPoint(x: 180, y: 170), control: CGPoint(x: 90, y: 140))
                path.addQuadCurve(to: CGPoint(x: 400, y: 190), control: CGPoint(x: 290, y: 200))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#EFECE7"), Color(hex: "#E5DFD5")], startPoint: .top, endPoint: .bottom))
            
            Path { path in
                path.move(to: CGPoint(x: 160, y: 190))
                path.addQuadCurve(to: CGPoint(x: 400, y: 170), control: CGPoint(x: 280, y: 210))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 160, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#E9E3D9"), Color(hex: "#DFD7C9")], startPoint: .top, endPoint: .bottom))
            
            // Joshua Trees Vector Outline on the right
            MinimalistJoshuaTree(xOffset: 120, scale: 0.85)
            MinimalistJoshuaTree(xOffset: 145, scale: 0.65)
        }
    }
}

struct NightLandscape: View {
    var body: some View {
        ZStack {
            // Midnight sky gradient
            LinearGradient(
                colors: [Color(hex: "#090814"), Color(hex: "#0F0D24"), Color(hex: "#1B173B")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Stars
            RandomStar(x: 30, y: 40, size: 2, opacity: 0.8)
            RandomStar(x: 80, y: 60, size: 3, opacity: 0.5)
            RandomStar(x: 120, y: 30, size: 1.5, opacity: 0.9)
            RandomStar(x: 240, y: 50, size: 2.5, opacity: 0.6)
            RandomStar(x: 290, y: 80, size: 2, opacity: 0.4)
            RandomStar(x: 340, y: 35, size: 3, opacity: 0.8)
            
            // Soft moon
            Circle()
                .fill(Color(hex: "#F5F3ED").opacity(0.12))
                .frame(width: 80, height: 80)
                .blur(radius: 4)
                .offset(x: -120, y: -40)
            
            // Mountain Peak Silhouettes at bottom
            Path { path in
                path.move(to: CGPoint(x: 0, y: 170))
                path.addLine(to: CGPoint(x: 120, y: 120))
                path.addLine(to: CGPoint(x: 260, y: 190))
                path.addLine(to: CGPoint(x: 340, y: 150))
                path.addLine(to: CGPoint(x: 400, y: 190))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#0D0A1E"), Color(hex: "#05030B")], startPoint: .top, endPoint: .bottom))
            
            Path { path in
                path.move(to: CGPoint(x: 80, y: 185))
                path.addLine(to: CGPoint(x: 210, y: 140))
                path.addLine(to: CGPoint(x: 320, y: 200))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 80, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#0A0818"), Color(hex: "#030206")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct CoastalLandscape: View {
    var body: some View {
        ZStack {
            // Calm Sky
            LinearGradient(
                colors: [Color(hex: "#E4F0FB"), Color(hex: "#FFF4ED"), Color(hex: "#FFF1DB")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Soft white setting sun
            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: 50, height: 50)
                .blur(radius: 5)
                .offset(x: -80, y: 0)

            // Rocky sea cliffs on the right
            Path { path in
                path.move(to: CGPoint(x: 220, y: 240))
                path.addLine(to: CGPoint(x: 270, y: 140))
                path.addLine(to: CGPoint(x: 300, y: 160))
                path.addLine(to: CGPoint(x: 350, y: 80))
                path.addLine(to: CGPoint(x: 400, y: 100))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#9AB2C5"), Color(hex: "#7A92A5")], startPoint: .top, endPoint: .bottom))
            
            // Coastal waves at bottom
            Path { path in
                path.move(to: CGPoint(x: 0, y: 190))
                path.addQuadCurve(to: CGPoint(x: 180, y: 200), control: CGPoint(x: 90, y: 215))
                path.addQuadCurve(to: CGPoint(x: 400, y: 175), control: CGPoint(x: 290, y: 180))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#90D1DB"), Color(hex: "#5DB8CA"), Color(hex: "#349BB0")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct ForestLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E3F3EA"), Color(hex: "#FFFEE8")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Green forest silhouette
            Path { path in
                path.move(to: CGPoint(x: 0, y: 200))
                path.addQuadCurve(to: CGPoint(x: 200, y: 180), control: CGPoint(x: 100, y: 210))
                path.addQuadCurve(to: CGPoint(x: 400, y: 190), control: CGPoint(x: 300, y: 170))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#84B094"), Color(hex: "#5C8C6F")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct MeadowLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#D6F2FE"), Color(hex: "#FFF4CE")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Sunny spring meadows
            Path { path in
                path.move(to: CGPoint(x: 0, y: 180))
                path.addQuadCurve(to: CGPoint(x: 400, y: 170), control: CGPoint(x: 200, y: 210))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#D6BF74"), Color(hex: "#BFA456")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct MountainLakeLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#DDF4FE"), Color(hex: "#ECE8FF")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Serene lake reflection peaks
            Path { path in
                path.move(to: CGPoint(x: 0, y: 190))
                path.addQuadCurve(to: CGPoint(x: 200, y: 205), control: CGPoint(x: 100, y: 175))
                path.addQuadCurve(to: CGPoint(x: 400, y: 185), control: CGPoint(x: 300, y: 215))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#87BAC5"), Color(hex: "#6A9AA5")], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct CalmSunsetLandscape: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFE4D5"), Color(hex: "#FFC8B3")],
                startPoint: .top,
                endPoint: .bottom
            )
            // Calm evening wave dunes
            Path { path in
                path.move(to: CGPoint(x: 0, y: 195))
                path.addQuadCurve(to: CGPoint(x: 400, y: 195), control: CGPoint(x: 200, y: 220))
                path.addLine(to: CGPoint(x: 400, y: 240))
                path.addLine(to: CGPoint(x: 0, y: 240))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [Color(hex: "#E89B7D"), Color(hex: "#D48463")], startPoint: .top, endPoint: .bottom))
        }
    }
}

// Minimal Joshua Tree outline helper
struct MinimalistJoshuaTree: View {
    let xOffset: CGFloat
    let scale: CGFloat
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let startX = w - xOffset
            let startY = h - 60
            
            Path { path in
                // Trunk
                path.move(to: CGPoint(x: startX, y: startY))
                path.addLine(to: CGPoint(x: startX, y: startY - (40 * scale)))
                
                // Branch left
                path.move(to: CGPoint(x: startX, y: startY - (30 * scale)))
                path.addLine(to: CGPoint(x: startX - (15 * scale), y: startY - (42 * scale)))
                path.addLine(to: CGPoint(x: startX - (15 * scale), y: startY - (55 * scale)))
                
                // Branch right
                path.move(to: CGPoint(x: startX, y: startY - (35 * scale)))
                path.addLine(to: CGPoint(x: startX + (12 * scale), y: startY - (45 * scale)))
                path.addLine(to: CGPoint(x: startX + (12 * scale), y: startY - (60 * scale)))
            }
            .stroke(Color(hex: "#4A433A"), style: StrokeStyle(lineWidth: 3.5 * scale, lineCap: .round, lineJoin: .round))
            
            // Foliage pom-poms (vector circles)
            Group {
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 14 * scale, height: 14 * scale)
                    .position(x: startX, y: startY - (45 * scale))
                
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 12 * scale, height: 12 * scale)
                    .position(x: startX - (15 * scale), y: startY - (55 * scale))
                
                Circle()
                    .fill(Color(hex: "#5E6D59"))
                    .frame(width: 13 * scale, height: 13 * scale)
                    .position(x: startX + (12 * scale), y: startY - (60 * scale))
            }
        }
    }
}

struct RandomStar: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    
    var body: some View {
        Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .shadow(color: .white.opacity(0.8), radius: size * 1.2)
            .position(x: x, y: y)
    }
}

// MARK: - SLEEP CLOCK WHEEL VIEW (Premium dark clock dial)
struct SleepClockWheelView: View {
    let bedtimeHour: Int
    let bedtimeMinute: Int
    let wakeHour: Int
    let wakeMinute: Int
    
    var body: some View {
        ZStack {
            // Dial background
            Circle()
                .fill(Color(hex: "#100F0D").opacity(0.8))
                .frame(width: 170, height: 170)
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#2E2B25"), style: StrokeStyle(lineWidth: 1.5, dash: [4, 6]))
                )
            
            // Hour markings around the circle (12am, 6am, 12pm, 6pm)
            dialHourText("12am", angle: -90, radius: 68)
            dialHourText("6am", angle: 0, radius: 68)
            dialHourText("12pm", angle: 90, radius: 68)
            dialHourText("6pm", angle: 180, radius: 68)
            
            // Tiny tick dots
            ForEach(0..<12) { idx in
                let deg = Double(idx) * 30.0 - 90.0
                let r = 76.0
                Circle()
                    .fill(Color(hex: "#2E2B25"))
                    .frame(width: 2.5, height: 2.5)
                    .offset(x: r * cos(deg * .pi / 180), y: r * sin(deg * .pi / 180))
            }

            // Sleep Duration Indicator Arc
            // Bedtime 22:52 corresponds to approx 253 deg
            // Wakeup 08:39 corresponds to approx 40 deg
            // Sleep arc goes from 253 deg clockwise to 40 deg (spanning 147 degrees)
            Circle()
                .trim(from: 253.0 / 360.0, to: 1.0)
                .stroke(
                    LinearGradient(colors: [VelaTheme.sleepColor, Color(hex: "#87BAC5")], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7.5, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: 0.0, to: 40.0 / 360.0)
                .stroke(
                    LinearGradient(colors: [Color(hex: "#87BAC5"), Color(hex: "#90D1DB")], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7.5, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(-90))

            // Center icons (moon and sun)
            VStack(spacing: 16) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.sleepColor)
                    .shadow(color: VelaTheme.sleepColor.opacity(0.6), radius: 3)
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#D6BF74"))
            }
            .offset(y: -4)

            // Bedtime Indicator Icon overlay (bed)
            let bedAngle = 253.0 - 90.0
            dialIndicatorPill(icon: "bed.double.fill", color: VelaTheme.sleepColor)
                .offset(x: 70 * cos(bedAngle * .pi / 180), y: 70 * sin(bedAngle * .pi / 180))
            
            // Wake Indicator Icon overlay (clock)
            let wakeAngle = 40.0 - 90.0
            dialIndicatorPill(icon: "alarm.fill", color: Color(hex: "#87BAC5"))
                .offset(x: 70 * cos(wakeAngle * .pi / 180), y: 70 * sin(wakeAngle * .pi / 180))
        }
        .overlay(alignment: .bottom) {
            Text("今晚所需睡眠: 7小时37分钟")
                .font(VelaTheme.caption2())
                .fontWeight(.bold)
                .foregroundStyle(Color(hex: "#BFB9AC"))
                .offset(y: 12)
        }
    }
    
    private func dialHourText(_ label: String, angle: Double, radius: Double) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(Color(hex: "#7E7A70"))
            .position(x: 85 + radius * cos(angle * .pi / 180), y: 85 + radius * sin(angle * .pi / 180))
    }
    
    private func dialIndicatorPill(icon: String, color: Color) -> some View {
        Image(systemName: icon)
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 15, height: 15)
            .background(Circle().fill(color).shadow(color: color.opacity(0.4), radius: 3))
    }
}

// MARK: - STRESS DAILY LINE CHART VIEW
struct DailyStressChartView: View {
    let isSleep: Bool
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack {
                // Background grid lines (horizontal dashed lines)
                VStack(spacing: h / 4 - 1.5) {
                    ForEach(0..<4) { _ in
                        Line()
                            .stroke(isSleep ? Color(hex: "#2E2B25").opacity(0.6) : VelaTheme.borderSoft.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .frame(height: 1)
                    }
                }
                
                // Curve spline Area Gradient Fill
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h - 18))
                    path.addCurve(to: CGPoint(x: w * 0.25, y: h - 55), control1: CGPoint(x: w * 0.1, y: h - 22), control2: CGPoint(x: w * 0.18, y: h - 65))
                    path.addCurve(to: CGPoint(x: w * 0.50, y: h - 25), control1: CGPoint(x: w * 0.32, y: h - 45), control2: CGPoint(x: w * 0.42, y: h - 15))
                    path.addCurve(to: CGPoint(x: w * 0.75, y: h - 85), control1: CGPoint(x: w * 0.60, y: h - 35), control2: CGPoint(x: w * 0.68, y: h - 95))
                    path.addCurve(to: CGPoint(x: w, y: h - 30), control1: CGPoint(x: w * 0.85, y: h - 75), control2: CGPoint(x: w * 0.92, y: h - 25))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [VelaTheme.stressColor.opacity(0.35), VelaTheme.stressColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // Spline multi-colored line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - 18))
                    path.addCurve(to: CGPoint(x: w * 0.25, y: h - 55), control1: CGPoint(x: w * 0.1, y: h - 22), control2: CGPoint(x: w * 0.18, y: h - 65))
                    path.addCurve(to: CGPoint(x: w * 0.50, y: h - 25), control1: CGPoint(x: w * 0.32, y: h - 45), control2: CGPoint(x: w * 0.42, y: h - 15))
                    path.addCurve(to: CGPoint(x: w * 0.75, y: h - 85), control1: CGPoint(x: w * 0.60, y: h - 35), control2: CGPoint(x: w * 0.68, y: h - 95))
                    path.addCurve(to: CGPoint(x: w, y: h - 30), control1: CGPoint(x: w * 0.85, y: h - 75), control2: CGPoint(x: w * 0.92, y: h - 25))
                }
                .stroke(
                    LinearGradient(
                        colors: [VelaTheme.success, VelaTheme.warn, VelaTheme.stressColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                )

                // Highlighting dots at specific key points
                Circle()
                    .fill(VelaTheme.success)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .position(x: w * 0.50, y: h - 25)
                
                Circle()
                    .fill(VelaTheme.stressColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    .position(x: w * 0.75, y: h - 85)
                
                // Timeline x-axis labels
                HStack {
                    Text("00:00")
                    Spacer()
                    Text("06:00")
                    Spacer()
                    Text("12:00")
                    Spacer()
                    Text("18:00")
                }
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                .offset(y: h / 2 + 10)
            }
        }
    }
    
    // Minimal vector gridline drawer
    struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            return path
        }
    }
}
