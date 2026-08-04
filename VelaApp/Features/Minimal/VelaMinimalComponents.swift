import SwiftData
import SwiftUI
import Charts

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

struct VelaDetailBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var tint: Color = VelaTheme.accent
    var label: String = "返回"

    var body: some View {
        Button(action: dismiss.callAsFunction) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(VelaTheme.surface))
                .overlay(Circle().stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel(label)
    }
}

// MARK: - VelaMetricDetailView — calm, evidence-first metric detail



struct VelaMetricDetailView: View {
    let metric: MetricType
    @Environment(\.colorScheme) private var cs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @ObservedObject var appState = VelaAppState.shared
    @State var dailyRecords: [DailyHealthSummaryRecord] = []
    @AppStorage(SleepTargetSettings.hoursKey) var sleepTargetHours = SleepTargetSettings.defaultHours
    @AppStorage("agent_bedtime_hour") var targetBedtimeHour = 22
    @AppStorage("agent_bedtime_minute") var targetBedtimeMinute = 0
    @State var showMetricInfo = false
    @State var heartRateZoneSummary: HeartRateZoneSummary?
    @State var isLoadingHeartRateZones = false
    
    // Default to a range that actually renders: `.day` returns an intentionally
    // empty chart (the metric pages are daily snapshots), so every detail page
    // opened showing "保持记录以显示趋势" even with months of history. Month (30d)
    // shows a real trend immediately.
    @State var selectedRange: DetailTimeRange = .month
    @State var rawSelectedDate: Date? = nil

    var dashboard: DashboardSummary { dashboardVM.dashboard }

    enum MetricType: String, CaseIterable, Identifiable {
        case strain, recovery, sleep, stress, energy, hrv, rhr
        case weight, bodyFat, respiratoryRate, bloodOxygen, steps, activeCalories, activeMinutes
        var id: String { rawValue }
    }

    var body: some View {
        // Every metric follows the user's system appearance. Sleep keeps its
        // semantic indigo accent without forcing an unrelated dark sub-theme.
        let isSleep = false
        
        ZStack {
            VelaTheme.systemGroupedBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                metricNavigationBar(isSleep: isSleep)
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.vertical, 8)
                    .background(VelaTheme.cardBg.opacity(0.96))
                    .overlay(alignment: .bottom) {
                        LinearGradient(
                            colors: [VelaTheme.borderSoft.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 5)
                        .offset(y: 5)
                        .allowsHitTesting(false)
                    }

                ScrollView {
                    VStack(spacing: 16) {
                        // 1. Procedural Chart Header Card (Apple Style)
                        chartHeaderSection(isSleep: isSleep)
                            .padding(.top, 8)

                        // 2. Double Highlight metrics
                        doubleHighlightsSection(isSleep: isSleep)

                        // 3. Deterministic interpretation and next action
                        guidanceSection(isSleep: isSleep)

                        // 4. Continue from the deterministic interpretation into
                        // a screen-aware Coach conversation while context is fresh.
                        coreMetricCoachCard

                        // 5. Direction, confidence, coverage, and freshness
                        trustSection

                        // 6. Score inputs and supporting raw data
                        supportingEvidenceSection(isSleep: isSleep)

                        // 7. Custom Widgets & Timeline based on Metric Type
                        customWidgetsSection(isSleep: isSleep)

                        // 8. Trend Sparkline Cards List
                        trendsSection(isSleep: isSleep)
                    }
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.bottom, 56)
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
        .onAppear {
            loadDailyRecords()
        }
        .onChange(of: dashboardVM.selectedDate) {
            loadDailyRecords()
        }
        .onChange(of: appState.localDataRevision) {
            loadDailyRecords()
        }
    }

    private func loadDailyRecords() {
        let calendar = Calendar.current
        let endDate = calendar.startOfDay(for: dashboardVM.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        // Max range we need for charts is 180 days (.halfYear)
        let start = calendar.date(byAdding: .day, value: -190, to: end) ?? end
        
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= start && $0.date <= end },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        if let fetched = try? modelContext.fetch(descriptor) {
            self.dailyRecords = fetched
        }
    }

    private func metricNavigationBar(isSleep: Bool) -> some View {
        HStack {
            metricNavigationButton(
                systemName: "chevron.left",
                isSleep: isSleep,
                action: { dismiss() }
            )
            .accessibilityLabel("返回")

            Spacer()

            VStack(spacing: 3) {
                Text(navTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)

                Text(displayDateText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
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
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.accent)
                .frame(width: VelaTheme.circularControlSize, height: VelaTheme.circularControlSize)
                .background(VelaTheme.secondaryGroupedBackground, in: Circle())
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel("分享\(navTitle)")
    }

    private func metricNavigationButton(
        systemName: String,
        isSleep: Bool,
        action: @escaping () -> Void = {}
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.accent)
                .frame(width: VelaTheme.circularControlSize, height: VelaTheme.circularControlSize)
                .background(VelaTheme.secondaryGroupedBackground, in: Circle())
        }
        .buttonStyle(.cardPress)
    }













    private var timeRangeSelector: some View {
        Picker("时间区间", selection: $selectedRange) {
            ForEach(DetailTimeRange.allCases) { range in
                Text(range.title).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
    }

    private func chartHeaderSection(isSleep: Bool) -> some View {
        MetricChartSection(
            metric: metric,
            isSleep: isSleep,
            points: chartPoints,
            isBarChart: isBarChart,
            metricColor: metricColor,
            selectedRange: $selectedRange,
            rawSelectedDate: $rawSelectedDate,
            displayDateText: displayDateText,
            dynamicValueText: dynamicValueText,
            metricSubtitle: metricSubtitle,
            targetRange: chartTargetRange
        )
    }

    private var chartTargetRange: ClosedRange<Double>? {
        guard metric == .strain else { return nil }
        let range = dashboard.strain.recommendedRange
        return Double(range.lowerBound)...Double(range.upperBound)
    }









    // MARK: - 1. Procedural Landscape Header
    private func landscapeHeaderSection(isSleep: Bool) -> some View {
        ZStack {
            MetricLandscapeHeader(metric: metric, isSleep: isSleep)
            
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
                                .fill(isSleep ? VelaTheme.inkDark.opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.012), radius: 10, x: 0, y: 3)
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
                                .fill(isSleep ? VelaTheme.inkDark.opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.012), radius: 10, x: 0, y: 3)
                        )
                    case .absoluteValue:
                        ZStack {
                            Circle()
                                .fill(isSleep ? VelaTheme.inkDark.opacity(0.85) : Color.white.opacity(0.85))
                                .frame(width: 140, height: 140)
                                .shadow(color: isSleep ? .clear : Color.black.opacity(0.012), radius: 10, x: 0, y: 3)

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
                        .foregroundStyle(isSleep ? VelaTheme.mistGray : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isSleep ? VelaTheme.inkDark.opacity(0.6) : Color.white.opacity(0.6))
                        )
                } else if metric == .sleep {
                    Text("目标睡眠: \(VelaMinimalFormatting.duration(minutes: sleepTargetMinutes))")
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(VelaTheme.mistGray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VelaTheme.inkDark.opacity(0.6)))
                } else if metric == .stress {
                    Text("目标压力: 保持平静")
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSleep ? VelaTheme.mistGray : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSleep ? VelaTheme.inkDark.opacity(0.6) : Color.white.opacity(0.6)))
                } else {
                    Text(metricSubtitle)
                        .font(VelaTheme.caption1())
                        .fontWeight(.semibold)
                        .foregroundStyle(isSleep ? VelaTheme.mistGray : VelaTheme.fg2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(isSleep ? VelaTheme.inkDark.opacity(0.6) : Color.white.opacity(0.6)))
                }
                
                Spacer()
                    .frame(height: 16)
            }
        }
        .frame(height: 240)
    }

    // MARK: - 2. Double Highlight Cards (Duration, Calories, Sleep, HRV etc.)
    private func doubleHighlightsSection(isSleep: Bool) -> some View {
        MetricHighlightsSection(
            isSleep: isSleep,
            metricColor: metricColor,
            leftTitle: leftTitle,
            leftIcon: leftIcon,
            leftValue: leftValue,
            leftSubtitle: leftSubtitle,
            rightTitle: rightTitle,
            rightIcon: rightIcon,
            rightValue: rightValue,
            rightSubtitle: rightSubtitle
        )
    }

    // MARK: - 3. Guidance Card
    private func guidanceSection(isSleep: Bool) -> some View {
        MetricInterpretationSection(
            title: metricRecommendation.title,
            detail: metricRecommendation.detail,
            evidence: metricRecommendation.evidence,
            symbol: metricRecommendation.symbol,
            tint: metricColor
        )
    }

    private var trustSection: some View {
        MetricTrustSection(
            direction: metricDirectionLabel,
            confidence: metricConfidenceLabel,
            coverage: metricCoverageLabel,
            updatedAt: metricUpdatedAtLabel,
            missingSummary: metricMissingSummary
        )
    }

    // MARK: - 4. Supporting Evidence




    private func supportingEvidenceSection(isSleep: Bool) -> some View {
        MetricEvidenceSection(isSleep: isSleep, items: evidenceItems)
    }

    



    // MARK: - 5. Custom Widgets & Timeline based on Metric Type
    @ViewBuilder
    private func customWidgetsSection(isSleep: Bool) -> some View {
        MetricCustomWidgetsSection(
            metric: metric,
            isSleep: isSleep,
            dashboard: dashboard,
            bedtimeHour: bedtimeHour,
            bedtimeMinute: bedtimeMinute,
            wakeHour: wakeHour,
            wakeMinute: wakeMinute,
            sleepTargetMinutes: sleepTargetMinutes,
            hasCompleteSleepTimes: hasCompleteSleepTimes,
            bedtimeText: bedtimeText,
            targetBedtimeText: targetBedtimeText,
            wakeTimeText: wakeTimeText,
            primarySleepStartText: primarySleepStartText,
            selectedFullDateText: selectedFullDateText,
            isLoadingHeartRateZones: isLoadingHeartRateZones,
            heartRateZoneSummary: heartRateZoneSummary,
            heartRateZoneRowAction: { zone, total in
                AnyView(heartRateZoneRow(zone, totalMinutes: total))
            },
            limitingFactors: limitingFactors,
            metricColor: metricColor
        )
    }

    private func timelineHeaderSection(isSleep: Bool) -> some View {
        HStack {
            Text("时间线")
                .font(VelaTheme.footnote())
                .fontWeight(.bold)
                .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
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
                .monospacedDigit()
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

        guard let age = UserProfileSettings.age()
            ?? WikiFileService.getAgeFromWiki()
            ?? dashboard.extendedMetrics.age,
              let restingHeartRate = dashboard.recoveryMetrics.restingHeartRate else {
            heartRateZoneSummary = nil
            return
        }
        let maxHeartRate = UserProfileSettings.resolvedMaxHeartRate(
            age: age,
            wiki: WikiFileService.getMaxHeartRateFromWiki()
        )
        heartRateZoneSummary = HeartRateZoneCalculator.summarize(
            sampleGroups: sampleGroups,
            restingHeartRate: restingHeartRate,
            maxHeartRate: maxHeartRate
        )
    }

    // MARK: - 5. Trend Sparkline Cards List
    private func trendsSection(isSleep: Bool) -> some View {
        MetricTrendsSection(isSleep: isSleep, items: trendItems)
    }

    // MARK: - Dynamic Dashboard Mapping Helpers













    // MARK: - Double Highlights Mapping
















    // MARK: - Sleep Clock Helpers












    // MARK: - Guidance text mapping


    // MARK: - Trend Items Grid mapping




    private var coreMetricCoachCard: some View {
        let context = CoreMetricCoachContext.make(for: metric)
        return MetricCoachCard(
            dashboard: dashboard,
            focus: context.focus,
            suggestedQuestion: context.suggestedQuestion
        )
    }

    // MARK: - Evidence / Limiting Factors Fallback Helpers











}

enum MetricHeroPresentation: Equatable {
    case scoreGauge
    case stressGauge
    case absoluteValue
}

extension VelaMetricDetailView.MetricType {
    var isScoredHealthDomain: Bool {
        switch self {
        case .strain, .recovery, .sleep, .stress, .energy:
            return true
        case .hrv, .rhr, .weight, .bodyFat, .respiratoryRate, .bloodOxygen, .steps, .activeCalories, .activeMinutes:
            return false
        }
    }

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

// MARK: - Digital Twin Simulator Glass Card

struct DigitalTwinSimulatorCard: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let dashboard: DashboardSummary

    @State private var plannedStrain: Double = 12.0
    @State private var plannedHour: Double = 19.0
    @State private var targetSleepHours: Double = 7.5

    var simulationResult: DigitalTwinSimulationResult {
        let scenario = SimulationScenarioInput(
            plannedWorkoutStrain: plannedStrain,
            plannedWorkoutHour: plannedHour,
            targetSleepDurationHours: targetSleepHours
        )
        return AutonomousHealthDigitalTwin().simulateNextDay(dashboard: dashboard, scenario: scenario)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.accent)
                    Text("数字双胞胎前瞻模拟")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                Text(simulationResult.scenarioTag == "optimal" ? "最佳节奏" : (simulationResult.scenarioTag == "suboptimal_timing" ? "时机风险" : "负荷偏高"))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(simulationResult.scenarioTag == "optimal" ? VelaTheme.systemGreen.opacity(0.18) : (simulationResult.scenarioTag == "suboptimal_timing" ? VelaTheme.systemOrange.opacity(0.18) : VelaTheme.systemRed.opacity(0.18)))
                    )
                    .foregroundStyle(simulationResult.scenarioTag == "optimal" ? VelaTheme.systemGreen : (simulationResult.scenarioTag == "suboptimal_timing" ? VelaTheme.systemOrange : VelaTheme.systemRed))
            }

            // Results Display Grid
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("预测次日恢复")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                    Text("\(Int(simulationResult.predictedNextDayRecovery.rounded()))%")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(simulationResult.predictedNextDayRecovery >= 66 ? VelaTheme.systemGreen : (simulationResult.predictedNextDayRecovery >= 34 ? VelaTheme.systemYellow : VelaTheme.systemRed))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))

                VStack(alignment: .leading, spacing: 4) {
                    Text("预测次日能量")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                    Text("\(Int(simulationResult.predictedEnergyScore.rounded()))%")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(VelaTheme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))
            }

            // Sliders Controls
            VStack(spacing: 10) {
                HStack {
                    Text("计划训练负荷: \(String(format: "%.1f", plannedStrain))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelaTheme.fg2)
                    Spacer()
                }
                Slider(value: $plannedStrain, in: 2.0...21.0, step: 0.5)
                    .tint(VelaTheme.accent)

                HStack {
                    Text("预计训练时间: \(String(format: "%02d:00", Int(plannedHour)))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(VelaTheme.fg2)
                    Spacer()
                }
                Slider(value: $plannedHour, in: 7.0...22.0, step: 1.0)
                    .tint(VelaTheme.accent)
            }

            // Recommendation Line
            Text(simulationResult.recommendation)
                .font(.caption)
                .foregroundStyle(VelaTheme.fg2)
                .lineLimit(2)
                .padding(.top, 2)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }
}
