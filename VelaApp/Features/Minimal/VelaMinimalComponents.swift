import SwiftData
import SwiftUI

enum VelaMinimalFormatting {
    static func roundedPercentage(_ value: Double) -> String {
        "\(Int(value.rounded()))%"
    }

    static func calendarTitle(year: Int, month: Int) -> String {
        "\(year)年\(month)月"
    }

    static func duration(minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        return "\(safeMinutes / 60)小时\(safeMinutes % 60)分钟"
    }

    static func clockTime(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", normalizedHour(hour), normalizedMinute(minute))
    }

    static func sleepDurationMinutes(
        bedtimeHour: Int,
        bedtimeMinute: Int,
        wakeHour: Int,
        wakeMinute: Int
    ) -> Int {
        let bedtime = minutesSinceMidnight(hour: bedtimeHour, minute: bedtimeMinute)
        let wake = minutesSinceMidnight(hour: wakeHour, minute: wakeMinute)
        return (wake - bedtime + 24 * 60) % (24 * 60)
    }

    static func sleepDialAngle(hour: Int, minute: Int) -> Double {
        Double(minutesSinceMidnight(hour: hour, minute: minute)) / Double(24 * 60) * 360.0
    }

    private static func minutesSinceMidnight(hour: Int, minute: Int) -> Int {
        normalizedHour(hour) * 60 + normalizedMinute(minute)
    }

    private static func normalizedHour(_ hour: Int) -> Int {
        (hour % 24 + 24) % 24
    }

    private static func normalizedMinute(_ minute: Int) -> Int {
        min(max(minute, 0), 59)
    }
}

// MARK: - VelaMetricDetailView — 指标详情 (Bevel iOS 26 Parity Rebuild)
// 100% Visual Parity with Bevel App: Warm-White Canvas, White cockpit cards, Custom Circular dials, Spline Stress Charts & Starry Sleep Dark Mode

struct VelaMetricDetailView: View {
    let metric: MetricType
    @Environment(\.colorScheme) private var cs
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \DailyHealthSummaryRecord.date, order: .forward) private var dailyRecords: [DailyHealthSummaryRecord]
    @AppStorage(SleepTargetSettings.hoursKey) private var sleepTargetHours = SleepTargetSettings.defaultHours
    @AppStorage("agent_bedtime_hour") private var targetBedtimeHour = 22
    @AppStorage("agent_bedtime_minute") private var targetBedtimeMinute = 0
    @State private var showMetricInfo = false
    @State private var heartRateZoneSummary: HeartRateZoneSummary?
    @State private var isLoadingHeartRateZones = false

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    enum MetricType: String, CaseIterable {
        case strain, recovery, sleep, stress, energy, hrv, rhr
        case weight, bodyFat, respiratoryRate, bloodOxygen, steps, activeCalories, activeMinutes
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

                        // 4. Score inputs and supporting raw data
                        supportingEvidenceSection(isSleep: isSleep)

                        // 5. Custom Widgets & Timeline based on Metric Type
                        customWidgetsSection(isSleep: isSleep)

                        // 6. Trend Sparkline Cards List
                        trendsSection(isSleep: isSleep)

                        // 7. Metric-specific Coach advice
                        coreMetricCoachCard
                    }
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.bottom, 100) // Clear floating tab bars
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .alert("关于\(navTitle)", isPresented: $showMetricInfo) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(metricInfoText)
        }
        .task(id: strainWorkoutQueryKey) {
            guard metric == .strain else { return }
            await loadHeartRateZones()
        }
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

                Text(selectedDateText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            }

            Spacer()

            HStack(spacing: 8) {
                metricShareButton(isSleep: isSleep)
                metricNavigationButton(
                    systemName: "info.circle",
                    isSleep: isSleep,
                    action: { showMetricInfo = true }
                )
            }
        }
    }

    private func metricShareButton(isSleep: Bool) -> some View {
        ShareLink(item: metricShareText) {
            Image(systemName: "square.and.arrow.up")
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

    private var metricShareText: String {
        "\(selectedFullDateText) Vela \(navTitle): \(dynamicValueText) (\(metricSubtitle))"
    }

    private var metricInfoText: String {
        "该页面展示由 Apple 健康数据和本地评分引擎生成的\(navTitle)摘要。暂无数据时不会展示估算值。"
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
                case .weight:
                    MeadowLandscape()
                case .bodyFat:
                    MeadowLandscape()
                case .respiratoryRate:
                    MountainLakeLandscape()
                case .bloodOxygen:
                    CalmSunsetLandscape()
                case .steps:
                    MeadowLandscape()
                case .activeCalories:
                    DesertLandscape()
                case .activeMinutes:
                    CoastalLandscape()
                }
            }
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
            
            // Score Rings & Metric Text Overlays
            VStack(spacing: 8) {
                Spacer()
                
                // Ring/Gauge Container
                ZStack {
                    switch metric.heroPresentation {
                    case .stressGauge:
                        DottedCircleGauge(
                            score: dynamicScore,
                            labelText: stressBandLabel(dashboard.stress.band),
                            size: 110,
                            color: metricColor
                        )
                        .background(
                            Circle()
                                .fill(isSleep ? Color(hex: "#161512").opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        )
                    case .scoreGauge:
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
                    case .absoluteValue:
                        ZStack {
                            Circle()
                                .fill(isSleep ? Color(hex: "#161512").opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.04), radius: 10, x: 0, y: 4)

                            Circle()
                                .stroke(metricColor.opacity(0.3), lineWidth: 8)
                                .frame(width: 110, height: 110)

                            VStack(spacing: 6) {
                                Image(systemName: leftIcon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(metricColor)

                                Text(dynamicValueText)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.58)
                                    .frame(width: 96)
                            }
                        }
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
                    Text("目标睡眠: \(VelaMinimalFormatting.duration(minutes: sleepTargetMinutes))")
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
                    Text(rightTitle)
                        .font(VelaTheme.caption1())
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
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

    // MARK: - 4. Supporting Evidence
    private struct EvidenceItem: Identifiable {
        let id: String
        let title: String
        let value: String
        let detail: String
    }

    private enum EvidenceFormat {
        case integer(String)
        case decimal(String)
        case signedDecimal(String)
    }

    private func supportingEvidenceSection(isSleep: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("数据依据")
                    .font(VelaTheme.footnote())
                    .fontWeight(.bold)
                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)

                Text("用于解释当前指标的原始读数与评分组成")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(evidenceItems) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(VelaTheme.caption2())
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)

                        Text(item.value)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(item.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSleep ? Color.black.opacity(0.22) : VelaTheme.bg.opacity(0.72))
                    )
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

    private var evidenceItems: [EvidenceItem] {
        switch metric {
        case .strain:
            return [
                evidence("训练负荷", dashboard.strain.metrics["workout_load"], .decimal(""), "训练本身贡献"),
                evidence("日常活动", dashboard.strain.metrics["activity_load"], .decimal(""), "已降低重复计入权重"),
                evidence("今日总负荷", dashboard.strain.metrics["daily_load"], .decimal(""), "训练与非训练活动合计"),
                evidence("负荷比", dashboard.strain.metrics["training_load_ratio"], .decimal("x"), "近期 7 天 / 28 天等效")
            ]
        case .recovery:
            return [
                evidence("HRV 偏离", dashboard.recovery.metrics["hrv_z_score"], .signedDecimal(" z"), "相对个人基线"),
                evidence("RHR 偏离", dashboard.recovery.metrics["rhr_z_score"], .signedDecimal(" z"), "相对个人基线"),
                evidence("呼吸率偏离", dashboard.recovery.metrics["respiratory_rate_z"], .signedDecimal(" z"), "相对个人基线"),
                evidence("体温偏离", dashboard.recovery.metrics["body_temp_delta"], .signedDecimal("°C"), "夜间体温变化"),
                evidence("血氧", dashboard.recovery.metrics["spo2"] ?? dashboard.extendedMetrics.oxygenSaturation, .decimal("%"), "SpO₂")
            ]
        case .sleep:
            return [
                evidence("睡眠效率", dashboard.sleepScore.metrics["sleep_efficiency"], .decimal("%"), "睡眠 / 卧床"),
                evidence("REM 占比", dashboard.sleepScore.metrics["rem_pct"], .decimal("%"), "快速眼动睡眠"),
                evidence("深睡占比", dashboard.sleepScore.metrics["deep_pct"], .decimal("%"), "深度睡眠"),
                evidence("清醒时间", dashboard.sleepScore.metrics["awake_minutes"], .integer(" 分钟"), "睡眠期间"),
                evidence("清醒次数", dashboard.sleepScore.metrics["awake_episode_count"], .integer(" 次"), "睡眠期间")
            ]
        case .stress:
            return [
                evidence("心率压力", dashboard.stress.metrics["rhr_stress"], .integer(""), "静息心率维度"),
                evidence("HRV 压力", dashboard.stress.metrics["hrv_stress"], .integer(""), "自主神经维度"),
                evidence("呼吸压力", dashboard.stress.metrics["resp_stress"], .integer(""), "呼吸率维度"),
                evidence("睡眠债压力", dashboard.stress.metrics["sleep_debt_stress"], .integer(""), "睡眠影响")
            ]
        case .energy:
            return [
                evidence("ATL", dashboard.energy.metrics["atl"], .decimal(""), "7 天急性负荷"),
                evidence("CTL", dashboard.energy.metrics["ctl"], .decimal(""), "42 天慢性负荷"),
                evidence("TSB", dashboard.energy.metrics["tsb"], .signedDecimal(""), "CTL - ATL"),
                evidence("ACWR", dashboard.energy.metrics["acwr"], .decimal("x"), "急性 / 慢性负荷")
            ]
        case .hrv:
            return [
                evidence("今日 HRV", dashboard.recoveryMetrics.hrvMilliseconds, .integer(" ms"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.hrvMilliseconds, .integer(" ms"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["hrv_z_score"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .rhr:
            return [
                evidence("今日 RHR", dashboard.recoveryMetrics.restingHeartRate, .integer(" bpm"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.restingHeartRate, .integer(" bpm"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["rhr_z_score"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .weight:
            return [
                evidence("体重", dashboard.bodyMetrics.weightKilograms, .decimal(" kg"), "最近一次读数"),
                evidence("体脂率", dashboard.bodyMetrics.bodyFatPercentage, .decimal("%"), "身体组成"),
                evidence("BMI", dashboard.extendedMetrics.bmi, .decimal(""), "身高体重换算")
            ]
        case .bodyFat:
            return [
                evidence("体脂率", dashboard.bodyMetrics.bodyFatPercentage, .decimal("%"), "最近一次读数"),
                evidence("体重", dashboard.bodyMetrics.weightKilograms, .decimal(" kg"), "身体组成参考"),
                evidence("去脂体重", dashboard.bodyMetrics.leanBodyMassKilograms, .decimal(" kg"), "身体组成参考")
            ]
        case .respiratoryRate:
            return [
                evidence("今日呼吸率", dashboard.recoveryMetrics.respiratoryRate, .decimal("/min"), "Apple 健康读数"),
                evidence("个人基线", dashboard.recoveryBaseline.respiratoryRate, .decimal("/min"), "用于比较"),
                evidence("基线偏离", dashboard.recovery.metrics["respiratory_rate_z"], .signedDecimal(" z"), "恢复评分输入")
            ]
        case .bloodOxygen:
            return [
                evidence("血氧", dashboard.extendedMetrics.oxygenSaturation, .decimal("%"), "SpO₂ 最近读数"),
                evidence("恢复输入", dashboard.recovery.metrics["spo2"], .decimal("%"), "恢复评分引用"),
                evidence("呼吸率", dashboard.recoveryMetrics.respiratoryRate, .decimal("/min"), "呼吸健康参考")
            ]
        case .steps, .activeCalories, .activeMinutes:
            return [
                evidence("今日步数", dashboard.strain.metrics["steps_raw"], .integer(" 步"), "日常活动"),
                evidence("活动消耗", dashboard.strain.metrics["active_energy_raw"], .integer(" kcal"), "活动能量"),
                evidence("活跃时长", dashboard.strain.metrics["exercise_minutes_raw"], .integer(" 分钟"), "锻炼分钟"),
                evidence("日常活动负荷", dashboard.strain.metrics["activity_load"], .decimal(""), "避免与训练负荷重复计算")
            ]
        }
    }

    private func evidence(
        _ title: String,
        _ value: Double?,
        _ format: EvidenceFormat,
        _ detail: String
    ) -> EvidenceItem {
        EvidenceItem(id: title, title: title, value: evidenceText(value, format: format), detail: detail)
    }

    private func evidenceText(_ value: Double?, format: EvidenceFormat) -> String {
        guard let value else { return "--" }
        switch format {
        case let .integer(suffix):
            return "\(Int(value.rounded()))\(suffix)"
        case let .decimal(suffix):
            return String(format: "%.1f%@", value, suffix)
        case let .signedDecimal(suffix):
            return String(format: "%+.1f%@", value, suffix)
        }
    }

    // MARK: - 5. Custom Widgets & Timeline based on Metric Type
    @ViewBuilder
    private func customWidgetsSection(isSleep: Bool) -> some View {
        switch metric {
        case .strain:
            // --- Strain Custom Views ---
            VStack(alignment: .leading, spacing: VelaTheme.cardGap) {
                // Timeline
                timelineHeaderSection(isSleep: isSleep)
                
                VStack(alignment: .leading, spacing: 8) {
                    if dashboard.workouts.isEmpty {
                        Text("无活动")
                            .font(VelaTheme.footnote())
                            .fontWeight(.bold)
                            .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                        Text("此期间没有进行任何活动。")
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
                        .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
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
                                heartRateZoneRow(zone, totalMinutes: heartRateZoneSummary.totalMinutes)
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
                        .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
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
                            // Vector Circular Sleep Clock Dial
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

                    Text("当前仅有每日压力指数。日内压力曲线和高、中、低时长需要连续采样数据，暂不展示。")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        .padding(.vertical, 8)
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
        }
    }

    private var strainWorkoutQueryKey: [UUID] {
        dashboard.workouts.map(\.id)
    }

    private func heartRateZoneRow(_ zone: HeartRateZoneSummary.Zone, totalMinutes: Double) -> some View {
        let share = totalMinutes > 0 ? zone.minutes / totalMinutes : 0
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.title)
                    .font(VelaTheme.caption1())
                    .fontWeight(.semibold)
                    .foregroundStyle(VelaTheme.fg)
                Text(zone.detail)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
            }
            .frame(width: 68, alignment: .leading)

            GeometryReader { geometry in
                Capsule()
                    .fill(VelaTheme.accent.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(VelaTheme.accent)
                            .frame(width: geometry.size.width * share)
                    }
            }
            .frame(height: 8)

            Text("\(Int(zone.minutes.rounded())) 分钟")
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
                .frame(width: 52, alignment: .trailing)
        }
    }

    @MainActor
    private func loadHeartRateZones() async {
        guard !dashboard.workouts.isEmpty else {
            heartRateZoneSummary = nil
            return
        }

        isLoadingHeartRateZones = true
        defer { isLoadingHeartRateZones = false }

        let queryService = HealthKitQueryService()
        var sampleGroups: [[HeartRateSample]] = []
        for workout in dashboard.workouts {
            let samples = (try? await queryService.heartRateSamples(start: workout.start, end: workout.end)) ?? []
            if !samples.isEmpty {
                sampleGroups.append(samples)
            }
        }

        let age = UserProfileSettings.age()
            ?? WikiFileService.getAgeFromWiki()
            ?? dashboard.extendedMetrics.age
            ?? 30
        let maxHeartRate = UserProfileSettings.resolvedMaxHeartRate(
            age: age,
            wiki: WikiFileService.getMaxHeartRateFromWiki()
        )
        heartRateZoneSummary = HeartRateZoneCalculator.summarize(
            sampleGroups: sampleGroups,
            restingHeartRate: dashboard.recoveryMetrics.restingHeartRate ?? 60,
            maxHeartRate: maxHeartRate
        )
    }

    // MARK: - 5. Trend Sparkline Cards List
    private func trendsSection(isSleep: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("趋势")
                .font(VelaTheme.footnote())
                .fontWeight(.bold)
                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            
            VStack(spacing: VelaTheme.cardGap) {
                if trendItems.isEmpty {
                    Text("暂无可用趋势数据")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                                .fill(isSleep ? Color(hex: "#161512") : VelaTheme.cardBg)
                        )
                } else {
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
        case .weight:           "体重"
        case .bodyFat:          "体脂"
        case .respiratoryRate:  "呼吸率"
        case .bloodOxygen:      "血氧"
        case .steps:            "今日步数"
        case .activeCalories:   "活动消耗"
        case .activeMinutes:    "活跃时长"
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
        case .weight:           Color(hex: "#8E8A80")
        case .bodyFat:          Color(hex: "#8E8A80")
        case .respiratoryRate:  VelaTheme.recoveryColor
        case .bloodOxygen:      VelaTheme.accent
        case .steps:            Color(hex: "#E0A926")
        case .activeCalories:   VelaTheme.strainColor
        case .activeMinutes:    VelaTheme.sleepColor
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
        case .weight:
            return dashboard.bodyMetrics.weightKilograms ?? 0
        case .bodyFat:
            return dashboard.bodyMetrics.bodyFatPercentage ?? 0
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate ?? 0
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation ?? 0
        case .steps:
            return dashboard.strain.metrics["steps_raw"] ?? 0
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"] ?? 0
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"] ?? 0
        }
    }

    private var dynamicValueText: String {
        guard hasMetricData else { return "--" }
        switch metric {
        case .hrv:
            return "\(Int(dynamicScore)) ms"
        case .rhr:
            return "\(Int(dynamicScore)) bpm"
        case .stress:
            return "\(Int(dynamicScore))"
        case .weight:
            return String(format: "%.1f kg", dynamicScore)
        case .bodyFat:
            return String(format: "%.1f%%", dynamicScore)
        case .bloodOxygen:
            return "\(Int(dynamicScore))%"
        case .respiratoryRate:
            return "\(Int(dynamicScore))/min"
        case .steps:
            return "\(Int(dynamicScore))"
        case .activeCalories:
            return "\(Int(dynamicScore)) kcal"
        case .activeMinutes:
            return "\(Int(dynamicScore))m"
        default:
            return VelaMinimalFormatting.roundedPercentage(dynamicScore)
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
        case .weight:
            return "生理特征"
        case .bodyFat:
            return "身体组成"
        case .respiratoryRate:
            return "呼吸频率"
        case .bloodOxygen:
            return "血氧饱和度"
        case .steps:
            return "每日活动量"
        case .activeCalories:
            return "运动消耗"
        case .activeMinutes:
            return "活跃时长"
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
        case .weight: dashboard.bodyMetrics.weightKilograms != nil
        case .bodyFat: dashboard.bodyMetrics.bodyFatPercentage != nil
        case .respiratoryRate: dashboard.recoveryMetrics.respiratoryRate != nil
        case .bloodOxygen: dashboard.extendedMetrics.oxygenSaturation != nil
        case .steps: dashboard.strain.metrics["steps_raw"] != nil
        case .activeCalories: dashboard.strain.metrics["active_energy_raw"] != nil
        case .activeMinutes: dashboard.strain.metrics["exercise_minutes_raw"] != nil
        }
    }

    // MARK: - Double Highlights Mapping
    private var leftIcon: String {
        switch metric {
        case .strain:   "timer"
        case .sleep:    "bed.double.fill"
        case .stress:   "waveform.path.ecg"
        case .weight:           "scalemass.fill"
        case .bodyFat:          "figure.arms.open"
        case .respiratoryRate:  "lungs.fill"
        case .bloodOxygen:      "drop.fill"
        case .steps:            "shoeprints.fill"
        case .activeCalories:   "flame.fill"
        case .activeMinutes:    "clock.fill"
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
        case .weight:           "我的体重"
        case .bodyFat:          "当前体脂"
        case .respiratoryRate:  "基线平均"
        case .bloodOxygen:      "血氧基线"
        case .steps:            "昨日步数"
        case .activeCalories:   "基础代谢"
        case .activeMinutes:    "昨日活跃"
        }
    }

    private var leftValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))分钟" } ?? "--"
        case .sleep:
            if let bed = dashboard.sleepSummary.bedtime, let wake = dashboard.sleepSummary.wakeTime {
                let diffMin = Int(wake.timeIntervalSince(bed) / 60)
                return VelaMinimalFormatting.duration(minutes: diffMin)
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
        case .weight:
            return dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "--"
        case .bodyFat:
            return dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "--"
        case .respiratoryRate:
            return dashboard.recoveryBaseline.respiratoryRate.map { "\(Int($0))/min" } ?? "待建立"
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "--"
        case .steps:
            return dashboard.strain.metrics["steps_raw"].map { "\(Int($0)) 步" } ?? "--"
        case .activeCalories:
            let age = dashboard.extendedMetrics.age ?? 30
            let weight = dashboard.bodyMetrics.weightKilograms ?? 70.0
            let height = dashboard.extendedMetrics.heightCm ?? 175.0
            let bmr = 10.0 * weight + 6.25 * height - 5.0 * Double(age) + 5.0
            return "\(Int(bmr)) kcal"
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0)) 分钟" } ?? "--"
        }
    }

    private var leftSubtitle: String? {
        if metric == .stress {
            return "更新时间: \(dashboard.stress.lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    private var rightIcon: String {
        switch metric {
        case .strain:   "flame.fill"
        case .sleep:    "clock.fill"
        case .stress:   "heart.fill"
        case .weight:           "figure.body.strength"
        case .bodyFat:          "scalemass.fill"
        case .respiratoryRate:  "waveform.path.ecg"
        case .bloodOxygen:      "sparkles"
        case .steps:            "target"
        case .activeCalories:   "flame.circle.fill"
        case .activeMinutes:    "figure.run"
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
        case .weight:           "体脂率"
        case .bodyFat:          "当前体重"
        case .respiratoryRate:  "今日读数"
        case .bloodOxygen:      "今日读数"
        case .steps:            "今日步数"
        case .activeCalories:   "活动消耗"
        case .activeMinutes:    "今日活跃"
        }
    }

    private var rightValue: String {
        switch metric {
        case .strain:
            return dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
        case .sleep:
            let mins = dashboard.sleepSummary.totalSleepMinutes
            if mins > 0 {
                return VelaMinimalFormatting.duration(minutes: mins)
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
        case .weight:
            return dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f%%", $0) } ?? "--"
        case .bodyFat:
            return dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "--"
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate.map { "\(Int($0))/min" } ?? "--"
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "--"
        case .steps:
            return dashboard.strain.metrics["steps_raw"].map { "\(Int($0)) 步" } ?? "--"
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0)) 分钟" } ?? "--"
        }
    }

    private var rightSubtitle: String? {
        if metric == .stress {
            return "更新时间: \(dashboard.stress.lastUpdated.formatted(date: .omitted, time: .shortened))"
        }
        return nil
    }

    // MARK: - Sleep Clock Helpers
    private var hasCompleteSleepTimes: Bool {
        dashboard.sleepSummary.bedtime != nil && dashboard.sleepSummary.wakeTime != nil
    }

    private var bedtimeHour: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.hour, from: bed)
        }
        return 0
    }
    private var bedtimeMinute: Int {
        if let bed = dashboard.sleepSummary.bedtime {
            return Calendar.current.component(.minute, from: bed)
        }
        return 0
    }
    private var wakeHour: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.hour, from: wake)
        }
        return 0
    }
    private var wakeMinute: Int {
        if let wake = dashboard.sleepSummary.wakeTime {
            return Calendar.current.component(.minute, from: wake)
        }
        return 0
    }
    private var bedtimeText: String {
        guard dashboard.sleepSummary.bedtime != nil else { return "--" }
        return VelaMinimalFormatting.clockTime(hour: bedtimeHour, minute: bedtimeMinute)
    }
    private var wakeTimeText: String {
        guard dashboard.sleepSummary.wakeTime != nil else { return "--" }
        return VelaMinimalFormatting.clockTime(hour: wakeHour, minute: wakeMinute)
    }
    private var targetBedtimeText: String {
        VelaMinimalFormatting.clockTime(hour: targetBedtimeHour, minute: targetBedtimeMinute)
    }
    private var sleepTargetMinutes: Int {
        Int((sleepTargetHours * 60.0).rounded())
    }
    private var primarySleepStartText: String {
        guard let bedtime = dashboard.sleepSummary.bedtime else { return "暂无睡眠开始时间" }
        return bedtime.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .hour()
                .minute()
                .locale(Locale(identifier: "zh_Hans_CN"))
        )
    }

    // MARK: - Guidance text mapping
    private var guidanceText: String {
        guard hasMetricData else { return "完成 Apple 健康同步后，这里会展示基于真实数据的分析。" }
        return metricReasons.first ?? "当前指标已更新，请结合趋势和限制因素查看。"
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
        guard let series = CoreMetricTrendMapper.series(
            for: metric,
            snapshots: dailyRecords.map { $0.toSnapshot() },
            endingAt: dashboardVM.selectedDate
        ) else {
            return []
        }

        return [
            TrendItem(
                title: series.title,
                value: series.valueText,
                icon: series.icon,
                statusLabel: series.statusLabel,
                statusColor: metricColor,
                graphColor: metricColor,
                history: series.history
            )
        ]
    }

    private var coreMetricCoachCard: some View {
        let context = CoreMetricCoachContext.make(for: metric)
        return MetricCoachCard(
            dashboard: dashboard,
            focus: context.focus,
            suggestedQuestion: context.suggestedQuestion
        )
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
        let reasons = Array(metricReasons.prefix(3))
        return reasons.isEmpty ? ["暂无可用分析原因"] : reasons
    }

    private var metricReasons: [String] {
        switch metric {
        case .strain:
            dashboard.strain.reasons
        case .sleep:
            dashboard.sleepScore.reasons
        case .stress:
            dashboard.stress.reasons
        case .recovery, .hrv, .rhr:
            dashboard.recovery.reasons
        case .energy:
            dashboard.energy.reasons
        case .weight, .bodyFat, .respiratoryRate, .bloodOxygen:
            [
                "生理体征偏离正常基线时，应当与睡眠、体能负荷和日间自觉症状综合关联评估。",
                "确保每天在相近时间完成测量，以便建立可信度更高的趋势分析基线。"
            ]
        case .steps, .activeCalories, .activeMinutes:
            [
                "运动负荷与能量代谢对明日的心血管恢复存在 12-24 小时的生理滞后性影响。",
                "高负荷日之后注意补充充足的糖原与蛋白质，有利于肌肉纤维重建。"
            ]
        }
    }
}

enum MetricHeroPresentation: Equatable {
    case scoreGauge
    case stressGauge
    case absoluteValue
}

extension VelaMetricDetailView.MetricType {
    var heroPresentation: MetricHeroPresentation {
        switch self {
        case .strain, .recovery, .sleep, .energy:
            return .scoreGauge
        case .stress:
            return .stressGauge
        case .hrv, .rhr, .weight, .bodyFat, .respiratoryRate, .bloodOxygen, .steps, .activeCalories, .activeMinutes:
            return .absoluteValue
        }
    }
}

enum DailyActivityDetailCatalog {
    static let metrics: [VelaMetricDetailView.MetricType] = [
        .steps,
        .activeCalories,
        .activeMinutes
    ]
}

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
        let statusLabel: String
        if abs(delta) < 0.05 {
            statusLabel = "近30天基本稳定"
        } else {
            statusLabel = String(format: "近30天 %+.1f", delta)
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

struct CoreMetricCoachContext {
    var focus: CoachContextFocus
    var suggestedQuestion: String

    static func make(for metric: VelaMetricDetailView.MetricType) -> CoreMetricCoachContext {
        let title: String
        let systemContext: String
        let suggestedQuestion: String

        switch metric {
        case .strain:
            title = L10n.t("Strain", "耗力")
            systemContext = L10n.t("Analyze daily strain, workout load, active movement, and training load balance.", "分析每日耗力、训练负荷、日常活动和训练负荷平衡。")
            suggestedQuestion = L10n.t("Analyze today's strain and tell me whether I should add training, maintain, or recover.", "请分析我今天的耗力，并告诉我应该加练、维持还是恢复。")
        case .recovery:
            title = L10n.t("Recovery", "恢复")
            systemContext = L10n.t("Analyze recovery readiness against HRV, resting heart rate, sleep, and baseline deviation.", "结合 HRV、静息心率、睡眠和基线偏离分析恢复准备度。")
            suggestedQuestion = L10n.t("Analyze today's recovery and give me the single most important action.", "请分析我今天的恢复状态，并给出最重要的一项行动。")
        case .sleep:
            title = L10n.t("Sleep", "睡眠")
            systemContext = L10n.t("Analyze sleep duration, stages, efficiency, awakenings, and recovery impact.", "分析睡眠时长、阶段、效率、清醒情况及其对恢复的影响。")
            suggestedQuestion = L10n.t("Analyze last night's sleep and tell me the best adjustment for tonight.", "请分析昨晚睡眠，并告诉我今晚最值得做的一项调整。")
        case .stress:
            title = L10n.t("Stress", "压力")
            systemContext = L10n.t("Analyze physiological stress carefully without overinterpreting a single reading.", "谨慎分析生理压力，不要过度解读单次读数。")
            suggestedQuestion = L10n.t("Analyze my current stress index and give me one practical downshift action.", "请分析我当前的压力指数，并给我一个可执行的降压行动。")
        case .energy:
            title = L10n.t("Energy Bank", "能量")
            systemContext = L10n.t("Analyze energy bank against recovery, sleep, strain, ATL, CTL, TSB, and ACWR.", "结合恢复、睡眠、耗力、ATL、CTL、TSB 和 ACWR 分析能量储备。")
            suggestedQuestion = L10n.t("Analyze my energy bank and tell me how to allocate effort today.", "请分析我的能量储备，并告诉我今天该如何分配精力。")
        case .hrv:
            title = L10n.t("Heart Rate Variability", "心率变异性")
            systemContext = L10n.t("Analyze HRV against the personal baseline and today's training context.", "结合个人基线和今日训练背景分析 HRV。")
            suggestedQuestion = L10n.t("Analyze my HRV against baseline and explain what it means for today.", "请结合基线分析我的 HRV，并说明它对今天意味着什么。")
        case .rhr:
            title = L10n.t("Resting Heart Rate", "静息心率")
            systemContext = L10n.t("Analyze resting heart rate against baseline and recovery context.", "结合基线和恢复背景分析静息心率。")
            suggestedQuestion = L10n.t("Analyze my resting heart rate against baseline and tell me what to watch today.", "请结合基线分析我的静息心率，并告诉我今天需要关注什么。")
        case .weight:
            title = L10n.t("Weight", "体重")
            systemContext = L10n.t("Analyze body weight trend, body fat percentage, BMR estimation, and composition adjustments.", "分析体重变化趋势、身体体脂率、基础代谢率估算及身体成分调整。")
            suggestedQuestion = L10n.t("Explain my recent weight fluctuations and give me a practical recommendation on body composition.", "请解释我近期的体重波动，并针对身体成分给我一个可行的建议。")
        case .bodyFat:
            title = L10n.t("Body Fat", "体脂")
            systemContext = L10n.t("Analyze body fat percentage trend together with body weight, training load, and recovery.", "结合体重、训练负荷和恢复状态分析体脂率趋势。")
            suggestedQuestion = L10n.t("Analyze my recent body fat trend and give me one practical body composition recommendation.", "请分析我近期的体脂率趋势，并给我一个可执行的身体成分建议。")
        case .respiratoryRate:
            title = L10n.t("Respiratory Rate", "呼吸频率")
            systemContext = L10n.t("Analyze respiratory rate trend, sleep breathing frequency, baseline stability, and potential recovery indicators.", "分析睡眠呼吸频率趋势、呼吸频率稳定性以及潜在的身体恢复指标。")
            suggestedQuestion = L10n.t("Has my breathing frequency stayed within baseline? Explain what it signifies for my recovery.", "我的呼吸频率是否维持在基线范围内？请说明这对我的恢复有什么指示意义。")
        case .bloodOxygen:
            title = L10n.t("Blood Oxygen", "血氧")
            systemContext = L10n.t("Analyze daily blood oxygen levels (SpO2), minimums, averages, and systemic oxygenation trends.", "分析每日血氧饱和度（SpO2）水平、最低值、平均值以及全身氧合趋势。")
            suggestedQuestion = L10n.t("Evaluate my blood oxygen metrics and let me know if everything is in ideal balance.", "评估我的血氧指标，并告诉我一切是否都处于理想的平衡状态。")
        case .steps:
            title = L10n.t("Steps", "步数")
            systemContext = L10n.t("Analyze daily step count, movement trends, cardiovascular health impact, and daily activity baseline.", "分析每日步数、运动趋势、心血管健康影响以及每日活动基线。")
            suggestedQuestion = L10n.t("Analyze my daily steps history and suggest how to optimize my movement levels.", "分析我的每日步数历史，并建议如何优化我的日常活动量。")
        case .activeCalories:
            title = L10n.t("Active Calories", "活动消耗")
            systemContext = L10n.t("Analyze active calorie burn, workout energy expenditure, daily BMR comparison, and metabolic balance.", "分析活动卡路里消耗、运动能量支出、每日基础代谢对比及代谢平衡。")
            suggestedQuestion = L10n.t("Evaluate my active calorie burn and explain how it compares to my metabolic baseline.", "评估我的活动热量消耗，并说明它与我的基础代谢基线相比如何。")
        case .activeMinutes:
            title = L10n.t("Active Minutes", "活跃时间")
            systemContext = L10n.t("Analyze active exercise duration, intensity, weekly activity consistency, and cardio impact.", "分析运动活跃时长、强度分布、每周活动一致性以及心肺健康影响。")
            suggestedQuestion = L10n.t("Analyze my active minutes trend and give me recommendations to optimize my efficiency.", "分析我的活跃分钟数趋势，并给我优化锻炼效率的建议。")
        }

        return CoreMetricCoachContext(
            focus: CoachContextFocus(title: title, systemContext: systemContext),
            suggestedQuestion: suggestedQuestion
        )
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
    let targetSleepMinutes: Int

    private var bedtimeAngle: Double {
        VelaMinimalFormatting.sleepDialAngle(hour: bedtimeHour, minute: bedtimeMinute)
    }

    private var wakeAngle: Double {
        VelaMinimalFormatting.sleepDialAngle(hour: wakeHour, minute: wakeMinute)
    }

    private var sleepDurationFraction: Double {
        Double(
            VelaMinimalFormatting.sleepDurationMinutes(
                bedtimeHour: bedtimeHour,
                bedtimeMinute: bedtimeMinute,
                wakeHour: wakeHour,
                wakeMinute: wakeMinute
            )
        ) / Double(24 * 60)
    }
    
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
            Circle()
                .trim(from: 0.0, to: sleepDurationFraction)
                .stroke(
                    LinearGradient(colors: [VelaTheme.sleepColor, Color(hex: "#87BAC5")], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 7.5, lineCap: .round)
                )
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(bedtimeAngle - 90.0))

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
            dialIndicatorPill(icon: "bed.double.fill", color: VelaTheme.sleepColor)
                .offset(x: 70 * cos((bedtimeAngle - 90.0) * .pi / 180), y: 70 * sin((bedtimeAngle - 90.0) * .pi / 180))
            
            // Wake Indicator Icon overlay (clock)
            dialIndicatorPill(icon: "alarm.fill", color: Color(hex: "#87BAC5"))
                .offset(x: 70 * cos((wakeAngle - 90.0) * .pi / 180), y: 70 * sin((wakeAngle - 90.0) * .pi / 180))
        }
        .overlay(alignment: .bottom) {
            Text("今晚睡眠目标: \(VelaMinimalFormatting.duration(minutes: targetSleepMinutes))")
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
