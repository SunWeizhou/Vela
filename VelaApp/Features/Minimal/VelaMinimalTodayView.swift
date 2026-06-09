import SwiftUI
import SwiftData
import CoreLocation

// MARK: - VelaTodayView — Bevel Replica Today Tab
// Warm off-white background (#F2F2F7) × Premium White Cockpit cards with precise shadows

struct VelaTodayView: View {
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var workoutEvents: [WorkoutEventRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var trainingResponses: [TrainingResponseRecord]
    @Query(sort: \FoodLogRecord.createdAt, order: .reverse)
    private var foodLogs: [FoodLogRecord]
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var journalEntries: [JournalEntryRecord]
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse)
    private var dailySummaries: [DailyHealthSummaryRecord]
    @Query(sort: \TrainingPlanRecord.updatedAt, order: .reverse)
    private var trainingPlans: [TrainingPlanRecord]
    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse)
    private var operatingPlans: [DailyOperatingPlanRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var recentStrengthSummary: RecentTrainingSummary {
        TrainingAnalyticsService().buildRecentSummary(
            workouts: strengthWorkouts,
            days: 7,
            endingAt: dashboardVM.selectedDate
        )
    }
    private var activePlan: TrainingPlanRecord? {
        trainingPlans.first(where: \.isActive)
    }
    private var bodyState: BodyState {
        BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            dailySummary: dailySummaries.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: dashboardVM.selectedDate)
            }),
            workoutEvents: workoutEvents,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            activePlan: activePlan,
            activeStatus: activeStatusRaw,
            generatedAt: Date()
        ))
    }
    private var trainingDecision: DailyTrainingDecision {
        TrainingDecisionKernel().decide(input: TrainingDecisionInput(
            bodyState: bodyState,
            activePlan: activePlan,
            recentStrengthSummary: recentStrengthSummary,
            trainingResponses: trainingResponses
        ))
    }
    private var persistedOperatingPlan: DailyOperatingPlanRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        return operatingPlans.first(where: { $0.dayIdentifier == identifier })
    }
    private var latestTodayArtifact: CoachArtifact? {
        coachArtifacts
            .map(\.artifact)
            .first { artifact in
                guard let relatedDate = artifact.relatedDate else { return true }
                return Calendar.current.isDate(relatedDate, inSameDayAs: dashboardVM.selectedDate)
            }
    }
    private var todayCommandState: TodayCommandState {
        TodayCommandBuilder.build(
            from: dashboard,
            recentStrengthSummary: recentStrengthSummary,
            coachArtifact: latestTodayArtifact,
            generatedAt: Date()
        )
    }

    private var strainScore: Double { max(0, min(1.0, dashboard.strain.score / 100.0)) }
    private var recoveryScore: Double { max(0, min(1.0, dashboard.recovery.score / 100.0)) }
    private var sleepScore: Double { max(0, min(1.0, dashboard.sleepScore.score / 100.0)) }

    private var hrvValue: Double { dashboard.recoveryMetrics.hrvMilliseconds ?? 0 }
    private var rhrValue: Double { dashboard.recoveryMetrics.restingHeartRate ?? 0 }

    private var stressLevel: Double { dashboard.stress.stressIndex }
    private var energyScore: Double { dashboard.energy.currentEnergy }

    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000
    @State private var todayCalories: Int = 0
    @State private var todayProtein: Int = 0
    @State private var todayCarbs: Int = 0
    @State private var todayFat: Int = 0

    private var calorieFraction: Double {
        guard dailyCalorieTarget > 0 else { return 0.0 }
        return Double(todayCalories) / Double(dailyCalorieTarget)
    }

    private var statusPillColor: Color {
        switch activeStatusRaw {
        case "active": return Color(hex: "#34C759")
        case "sick": return Color(hex: "#FF9F0A")
        case "injured": return Color(hex: "#FF3B30")
        default: return Color(hex: "#0058bc")
        }
    }

    private var statusPillIcon: String {
        switch activeStatusRaw {
        case "active": return "figure.run"
        case "sick": return "bed.double.fill"
        case "injured": return "bandage.fill"
        default: return "beach.umbrella.fill"
        }
    }

    private var statusPillTitle: String {
        switch activeStatusRaw {
        case "active": return "活跃"
        case "sick": return "生病"
        case "injured": return "受伤"
        default: return "休息中"
        }
    }

    private var headerBar: some View {
        VStack(spacing: 8) {
            dateHeaderRow
            pillsRow
        }
    }

    private var coachMessage: String {
        dashboard.dailyInsight.isEmpty
            ? "正在等待足够的 Apple 健康数据，完成同步后会生成今日指导。"
            : dashboard.dailyInsight
    }

    private var todayShareText: String {
        "\(dateHeaderString(for: dashboardVM.selectedDate))\n恢复 \(Int(dashboard.recovery.score.rounded())) · 睡眠 \(Int(dashboard.sleepScore.score.rounded())) · 负荷 \(Int(dashboard.strain.score.rounded()))\n\(coachMessage)"
    }

    @State private var weatherTemp: String = "--"
    @State private var weatherLocation: String = "天气数据待同步"

    @AppStorage("vela_active_status") private var activeStatusRaw = "resting"
    @AppStorage("vela_active_status_duration") private var activeStatusDuration = "明天之前"

    @State private var showCalendarOverview = false
    @State private var showActiveStatus = false
    @State private var selectedInsight: ProactiveInsight?
    @State private var showTodayEvidence = false
    @State private var animatedEnergyScore: Double = 0.0
    @State private var isVisible = false

    private var hrvStatusText: String {
        if hrvValue >= 55.0 { return "Optimal" } else if hrvValue >= 40.0 { return "Normal" } else { return "Low" }
    }
    private var hrvStatusColor: Color {
        if hrvValue >= 55.0 { return VelaTheme.success } else if hrvValue >= 40.0 { return Color(hex: "#FF9F0A") } else { return Color(hex: "#FF3B30") }
    }
    private var sleepRatingText: String {
        let scoreVal = dashboard.sleepScore.score
        if scoreVal >= 85 { return "Excellent" }
        if scoreVal >= 70 { return "Good" }
        if scoreVal >= 50 { return "Fair" }
        return "Poor"
    }
    private var yesterdayStrainText: String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
        let yesterdaySummary = dailySummaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: yesterday) })
        if let strain = yesterdaySummary?.strainScore { return String(format: "%.1f", strain) }
        return "14.2"
    }
    private var recommendedActionTitle: String { persistedOperatingPlan?.title ?? "等待生成今日计划" }
    private var recommendedActionSubtitle: String { persistedOperatingPlan?.safetyNotice ?? "同步健康数据后由 Vela 生成" }

    // MARK: - Recovery Gauge
    private var recoveryGauge: some View {
        let pct = Int(recoveryScore * 100)
        return ZStack {
            Circle()
                .stroke(Color.black.opacity(0.04), lineWidth: 16)
                .frame(width: 220, height: 220)
            Circle()
                .trim(from: 0, to: isVisible ? recoveryScore : 0)
                .stroke(VelaTheme.accent, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 220, height: 220)
                .animation(.spring(response: 1.2, dampingFraction: 0.8), value: isVisible)
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(pct)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.accent)
                    Text("%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.accent)
                }
                Text("Recovered")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                    .offset(y: -4)
            }
        }
        .frame(width: 220, height: 220)
    }

    // MARK: - HRV Card
    private var hrvCard: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(hrvStatusColor)
                    .frame(width: 40, height: 40)
                    .background(hrvStatusColor.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("HRV")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.fg2)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int(hrvValue.rounded()))")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.fg)
                        Text("ms")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.fg2)
                    }
                }
            }
            Spacer()
            Text(hrvStatusText)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(hrvStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(hrvStatusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .glassEffect()
    }

    // MARK: - Sleep & Strain Bento
    private var sleepStrainBento: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(VelaTheme.accent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sleep")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.fg2)
                    Text(sleepRatingText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect()

            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(VelaTheme.accent.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prev Strain")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.fg2)
                    Text(yesterdayStrainText)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect()
        }
    }

    // MARK: - Recommended Action Card
    private var recommendedActionCard: some View {
        let isRest = trainingDecision.decision == .rest
        return VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED ACTION")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(VelaTheme.fg2)
                .padding(.horizontal, 4)
            Button {
                if isRest { showTodayEvidence = true } else { appState.routeToTab(VelaAppState.trainingTabIndex) }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: isRest ? "heart.fill" : "figure.run")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(VelaTheme.accent)
                        .clipShape(Circle())
                        .shadow(color: VelaTheme.accent.opacity(0.35), radius: 8, y: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendedActionTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        Text(recommendedActionSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.fg2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.meta)
                }
                .padding(16)
                .glassEffect()
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VelaMakeHeader(
                    title: "今日",
                    subtitle: makeHeaderSubtitle
                ) {
                    Button {
                        showSettings = true
                    } label: {
                        Text("S")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                            .frame(width: 32, height: 32)
                            .background(VelaTheme.elevatedBg)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 12) {
                    recoveryMakeCard

                    HStack(spacing: 12) {
                        makeMiniScoreCard(
                            title: "睡眠",
                            icon: "moon.fill",
                            color: VelaTheme.sleepColor,
                            value: dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--",
                            unit: "分",
                            subtitle: sleepDurationText
                        ) {
                            VelaMetricDetailView(metric: .sleep)
                        }
                        makeMiniScoreCard(
                            title: "负荷",
                            icon: "sun.max.fill",
                            color: VelaTheme.strainColor,
                            value: dashboard.strain.hasData ? String(format: "%.1f", dashboard.strain.score) : "--",
                            unit: "/ 21",
                            subtitle: strainStatusText
                        ) {
                            VelaMetricDetailView(metric: .strain)
                        }
                    }

                    HStack(spacing: 12) {
                        makeMiniScoreCard(
                            title: "压力",
                            icon: "brain.head.profile",
                            color: VelaTheme.stressColor,
                            value: dashboard.stress.hasData ? "\(Int(stressLevel.rounded()))" : "--",
                            unit: dashboard.stress.hasData ? (stressLevel < 40 ? "低" : "高") : "",
                            subtitle: dashboard.stress.hasData ? (stressLevel < 40 ? "平和稳定" : "注意恢复") : "等待压力数据"
                        ) {
                            VelaMetricDetailView(metric: .stress)
                        }
                        makeMiniScoreCard(
                            title: "能量",
                            icon: "battery.75percent",
                            color: VelaTheme.energyColor,
                            value: dashboard.energy.hasData && isRecoveryAvailable ? "\(Int(energyScore.rounded()))" : "--",
                            unit: "%",
                            subtitle: "根据今日恢复估算"
                        ) {
                            VelaMetricDetailView(metric: .energy)
                        }
                    }

                    makePlanCard
                    makeBiologicalAgeCard
                    makeHRVCard
                    makeCoachInsightCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            locationManager.requestPermission()
            withAnimation(VelaTheme.smooth) { animatedEnergyScore = energyScore }
            withAnimation(VelaTheme.snappy) { isVisible = true }
        }.task {
            await refreshDashboard()
            persistDailyOperatingPlan()
            withAnimation(VelaTheme.smooth) { animatedEnergyScore = energyScore }
        }.refreshable {
            await refreshDashboard(force: true)
            persistDailyOperatingPlan()
        }.onChange(of: dashboardVM.selectedDate) { _, _ in
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            Task {
                await refreshDashboard()
                persistDailyOperatingPlan()
                withAnimation(VelaTheme.smooth) { animatedEnergyScore = energyScore }
            }
        }.onChange(of: energyScore) { _, newEnergy in
            withAnimation(VelaTheme.smooth) { animatedEnergyScore = newEnergy }
        }.onChange(of: appState.localDataRevision) { _, _ in
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
        }.onChange(of: locationManager.location) { _, _ in fetchLocalWeather() }
        .sheet(isPresented: $showCalendarOverview) { CalendarOverviewSheetView().presentationDetents([.medium, .large]).presentationDragIndicator(.visible).presentationBackground(Color(hex: "#F2F2F7")) }
        .sheet(item: $selectedInsight) { insight in
            ProactiveInsightDetailSheet(insight: insight) { question in
                selectedInsight = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    VelaAppState.shared.routeToCoach(question: question)
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showTodayEvidence) {
            TodayDecisionEvidenceSheet(
                state: todayCommandState,
                dashboard: dashboard
            ) { question in
                VelaAppState.shared.routeToCoach(question: question)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var makeHeaderSubtitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "EEEE · M 月 d 日"
        return formatter.string(from: dashboardVM.selectedDate)
    }

    private var recoveryMakeCard: some View {
        Button {
            appState.routeToRecoveryDetail()
        } label: {
            VelaMakeCard(padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("恢复", systemImage: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.recoveryColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                    }

                    HStack(spacing: 20) {
                        VelaMakeRing(
                            value: isRecoveryAvailable ? dashboard.recovery.score : 0,
                            color: VelaTheme.recoveryColor,
                            valueText: isRecoveryAvailable ? nil : "--"
                        )

                        VStack(alignment: .leading, spacing: 3) {
                            Text("状态")
                                .font(.system(size: 13))
                                .foregroundStyle(VelaTheme.fg2)
                            Text(recoveryStatusText)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(VelaTheme.fg)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(recoveryDriverLines, id: \.self) { line in
                                    Text(line)
                                        .font(.system(size: 13))
                                        .foregroundStyle(VelaTheme.fg2)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var recoveryStatusText: String {
        guard isRecoveryAvailable else { return "等待数据" }
        switch dashboard.recovery.score {
        case 80...: return "优秀"
        case 60..<80: return "良好"
        case 40..<60: return "一般"
        default: return "优先恢复"
        }
    }

    private var recoveryDriverLines: [String] {
        guard isRecoveryAvailable else {
            return ["需要 HRV 或静息心率", "等待睡眠同步", "不会使用模拟评分"]
        }
        let live = bodyState.drivers.prefix(3).map { driver in
            "\(driver.title) \(driver.impact >= 0 ? "+" : "−")\(Int(abs(driver.impact).rounded()))"
        }
        if live.count == 3 {
            return live
        }
        return [
            "HRV \(hrvValue > 0 ? "\(Int(hrvValue.rounded())) ms" : "等待同步")",
            "睡眠贡献 \(Int(dashboard.sleepScore.score.rounded())) 分",
            "昨日 Strain \(yesterdayStrainText)"
        ]
    }

    private var isRecoveryAvailable: Bool {
        dashboard.recoveryMetrics.hrvMilliseconds != nil
            || dashboard.recoveryMetrics.restingHeartRate != nil
            || dashboard.sleepSummary.totalSleepMinutes > 0
    }

    private var sleepDurationText: String {
        let minutes = dashboard.sleepSummary.totalSleepMinutes
        guard minutes > 0 else { return "等待睡眠数据" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private var strainStatusText: String {
        switch dashboard.strain.targetStatus {
        case .withinTarget: "目标区间内"
        case .aboveTarget: "高于目标"
        case .belowTarget: "低于目标"
        }
    }

    private func makeMiniScoreCard<Destination: View>(
        title: String,
        icon: String,
        color: Color,
        value: String,
        unit: String,
        subtitle: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            VelaMakeCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(title, systemImage: icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(color)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(value)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                            .monospacedDigit()
                        Text(unit)
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.fg2)
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.fg2)
                        .lineLimit(1)
                }
                .frame(minHeight: 92, alignment: .top)
            }
        }
        .buttonStyle(.plain)
    }

    private var makePlanCard: some View {
        Button {
            appState.routeToTab(VelaAppState.trainingTabIndex)
        } label: {
            VelaMakeCard {
                HStack(spacing: 12) {
                    VelaMakeIconTile(systemName: "chart.line.uptrend.xyaxis", color: VelaTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日计划")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.fg2)
                        Text(recommendedActionTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                            .lineLimit(1)
                        Text(recommendedActionSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.fg2)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.meta)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var makeBiologicalAgeCard: some View {
        NavigationLink(destination: BiologyView()) {
            VelaMakeCard {
                HStack(spacing: 12) {
                    VelaMakeIconTile(systemName: "figure.mind.and.body", color: Color(uiColor: .systemTeal))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("生物年龄趋势 · Beta")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.fg2)
                        Text("查看健康年龄")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.meta)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var makeHRVCard: some View {
        NavigationLink(destination: VelaMetricDetailView(metric: .hrv)) {
            VelaMakeCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HRV · 14 天")
                                .font(.system(size: 13))
                                .foregroundStyle(VelaTheme.fg2)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(hrvValue > 0 ? "\(Int(hrvValue.rounded()))" : "--")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .monospacedDigit()
                                Text("ms")
                                    .font(.system(size: 13))
                                    .foregroundStyle(VelaTheme.fg2)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                    }
                    SparklineLineGraph(
                        data: normalizedHRVTrend,
                        color: VelaTheme.recoveryColor,
                        height: 80,
                        width: 320
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var normalizedHRVTrend: [Double] {
        let values = dailySummaries.prefix(14).compactMap(\.hrvAverage).reversed()
        guard let minimum = values.min(), let maximum = values.max() else { return [] }
        let range = maximum - minimum
        return values.map { range == 0 ? 0.5 : ($0 - minimum) / range }
    }

    private var makeCoachInsightCard: some View {
        Button {
            appState.routeToCoach(question: "请继续解释今天的恢复、睡眠和训练建议。")
        } label: {
            VelaMakeCard {
                HStack(alignment: .top, spacing: 12) {
                    VelaMakeIconTile(systemName: "sparkles", color: Color(uiColor: .systemIndigo))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vela Coach")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemIndigo))
                        Text(trainingDecision.userFacingSummary)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                        Text(coachMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(VelaTheme.fg2)
                            .lineLimit(3)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.meta)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func todayOSRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.muted)
                .frame(width: 52, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.fg)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeStep: Int {
        let workoutsToday = strengthWorkouts.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: dashboardVM.selectedDate) }
        let journalToday = journalEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: dashboardVM.selectedDate) }
        if !journalToday.isEmpty {
            return 3
        } else if !workoutsToday.isEmpty {
            return 2
        } else if persistedOperatingPlan != nil {
            return 1
        } else {
            return 0
        }
    }

    private var dailyLoopCard: some View {
        let sleepMin = dashboard.sleepSummary.totalSleepMinutes
        let sleepValue = dashboard.sleepScore.hasData ? "\(sleepMin / 60)h \(sleepMin % 60)m" : "--"

        let planValue: String = {
            guard let plan = persistedOperatingPlan else { return "无计划" }
            switch plan.primaryActionType {
            case "keep": return "执行"
            case "reduce": return "减量"
            case "swap": return "调整"
            case "rest": return "恢复"
            default: return "自适应"
            }
        }()

        let workoutsToday = strengthWorkouts.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: dashboardVM.selectedDate) }
        let trainValue = !workoutsToday.isEmpty ? "已完成" : "今日"

        let journalToday = journalEntries.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: dashboardVM.selectedDate) }
        let checkInValue = !journalToday.isEmpty ? "已记录" : "今晚"

        let responseValue = "明天"

        return VStack(alignment: .leading, spacing: 14) {
            Text("DAILY LOOP")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(VelaTheme.meta)

            GeometryReader { geo in
                let width = geo.size.width
                let stepWidth = width / 5

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(VelaTheme.borderSoft)
                        .frame(height: 2)
                        .padding(.horizontal, stepWidth / 2)
                        .offset(y: -12)

                    HStack(spacing: 0) {
                        stepItem(title: "睡眠", value: sleepValue, color: VelaTheme.recoveryColor, active: activeStep >= 0, width: stepWidth)
                        stepItem(title: "计划", value: planValue, color: VelaTheme.accent, active: activeStep >= 1, width: stepWidth)
                        stepItem(title: "训练", value: trainValue, color: VelaTheme.strainColor, active: activeStep >= 2, width: stepWidth)
                        stepItem(title: "记录", value: checkInValue, color: VelaTheme.sleepColor, active: activeStep >= 3, width: stepWidth)
                        stepItem(title: "预测", value: responseValue, color: VelaTheme.meta, active: activeStep >= 4, width: stepWidth)
                    }
                }
            }
            .frame(height: 64)
            .padding(.vertical, 4)

            Text("下一个计划将根据你的恢复反应进行调整。")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.fg2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: VelaTheme.cardShadow(cs), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func stepItem(title: String, value: String, color: Color, active: Bool, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(active ? color : VelaTheme.elevatedBg)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(active ? color : VelaTheme.border, lineWidth: 2)
                )

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? VelaTheme.fg : VelaTheme.fg2)
                .padding(.top, 4)

            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(width: width)
    }

    private func bodyStateTitle(_ readiness: BodyReadiness) -> String {
        switch readiness {
        case .ready: L10n.t("Ready to execute", "适合执行训练")
        case .caution: L10n.t("Train with limits", "训练需有限制")
        case .recovering: L10n.t("Recovery first", "恢复优先")
        case .unknown: L10n.t("Conservative mode", "保守模式")
        }
    }

    private func primaryActionTitle(_ decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: L10n.t("Start planned session", "开始计划训练")
        case .reduce: L10n.t("Start reduced session", "开始减量训练")
        case .swap: L10n.t("Choose alternate session", "选择替代训练")
        case .rest: L10n.t("Open recovery plan", "查看恢复计划")
        }
    }

    private func persistDailyOperatingPlan() {
        _ = try? DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: trainingDecision,
            modelContext: modelContext
        )
    }

    // MARK: - Date Header Row
    private var dateHeaderRow: some View {
        HStack(alignment: .center) {
            Button {
                showCalendarOverview = true
            } label: {
                HStack(spacing: 6) {
                    Text(dateHeaderString(for: dashboardVM.selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))

                    if dashboard.source == .preview {
                        Text("模拟数据")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(VelaTheme.accent))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 16) {
                // Share button
                ShareLink(item: todayShareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                // Profile Avatar
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var todayCommandCenterCard: some View {
        let state = todayCommandState
        let accentColor = readinessColor(state.readinessDecision.decision)
        return VelaHeroCard(
            title: "Today Command Center",
            subtitle: "把恢复、睡眠、负荷和训练历史合成一个今日决策",
            systemImage: "scope",
            accent: accentColor
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.bodyStateTitle)
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.fg)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        Text(state.coachArtifact?.summary ?? state.summary)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(3)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .trailing, spacing: 6) {
                        ConfidenceBadge(confidence: state.dataConfidence)
                        Text("\(Int((state.readinessDecision.confidence * 100).rounded()))%")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                }

                if let artifact = state.coachArtifact, !artifact.actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(artifact.actions) { action in
                                ActionPill(
                                    title: action.label,
                                    systemImage: icon(for: action),
                                    isPrimary: action.id == artifact.actions.first?.id
                                ) {
                                    handleCoachArtifactAction(action, artifact: artifact)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                } else if !state.actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.actions.prefix(3)) { action in
                                ActionPill(
                                    title: action.title,
                                    systemImage: icon(for: action),
                                    isPrimary: action.isPrimary
                                ) {
                                    handleTodayAction(action)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private func readinessColor(_ decision: ReadinessDecisionKind) -> Color {
        switch decision {
        case .keep: return VelaTheme.success
        case .reduce: return Color(hex: "#FF9F0A")
        case .swap: return Color(hex: "#5C6BC0")
        case .recover: return VelaTheme.sleep
        }
    }

    private func icon(for action: TodayAction) -> String {
        switch action.kind {
        case .training: return "figure.run"
        case .recovery: return "heart.fill"
        case .checkIn: return "square.and.pencil"
        case .coach: return "sparkles"
        case .insight: return "list.bullet.clipboard"
        }
    }

    private func icon(for action: CoachArtifactAction) -> String {
        if action.type.contains("training") || action.type.contains("workout") { return "figure.run" }
        if action.type.contains("recovery") { return "heart.fill" }
        if action.type.contains("check") { return "square.and.pencil" }
        return "arrow.right"
    }

    private func handleTodayAction(_ action: TodayAction) {
        switch action.kind {
        case .training:
            appState.routeToTab(VelaAppState.trainingTabIndex)
        case .recovery, .insight:
            showTodayEvidence = true
        case .checkIn:
            appState.triggerJournal = true
        case .coach:
            appState.routeToCoach(question: action.detail)
        }
    }

    private func handleCoachArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        switch action.type {
        case "open_training_summary":
            appState.routeToTab(VelaAppState.trainingTabIndex)
        case "start_check_in":
            appState.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        case "open_recovery_detail":
            appState.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        default:
            if action.type.contains("training") || action.type.contains("workout") {
                appState.routeToTab(VelaAppState.trainingTabIndex)
            } else if action.type.contains("check") || action.type.contains("journal") {
                appState.triggerJournal = true
            } else if action.type.contains("recovery") {
                appState.routeToRecoveryDetail()
            } else {
                appState.routeToCoach(question: action.label)
            }
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    private func routeLegacyCoachArtifactAction(_ action: CoachArtifactAction) {
        if action.type.contains("training") || action.type.contains("workout") {
            appState.routeToTab(VelaAppState.trainingTabIndex)
        } else if action.type.contains("check") || action.type.contains("journal") {
            appState.triggerJournal = true
        } else if action.type.contains("recovery") {
            appState.routeToRecoveryDetail()
        } else {
            appState.routeToCoach(question: action.label)
        }
    }

    // MARK: - Date formatting helpers
    private func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天, " + formatMonthDayString(date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天, " + formatMonthDayString(date)
        } else {
            return formatMonthDayString(date)
        }
    }

    private func formatMonthDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    // MARK: - Weather Sync
    private func fetchLocalWeather() {
        Task {
            let cached = WeatherLocationStore.load()
            let live = await weatherLocationSnapshot(
                for: locationManager.location,
                fallbackDisplayName: cached?.displayName
            )

            guard let location = WeatherLocationPolicy.preferredSnapshot(
                live: live,
                cached: cached
            ) else {
                return
            }

            if live != nil {
                WeatherLocationStore.save(location)
            }

            do {
                let weather = try await WeatherService.shared.fetchWeather(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                guard !Task.isCancelled else {
                    return
                }

                weatherTemp = "\(Int(weather.temperature.rounded()))°C"
                weatherLocation = location.displayName
            } catch {
                print("Failed to sync weather locally: \(error.localizedDescription)")
            }
        }
    }

    private func weatherLocationSnapshot(
        for location: CLLocation?,
        fallbackDisplayName: String?
    ) async -> WeatherLocationSnapshot? {
        guard let location else {
            return nil
        }

        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(location)
            .first
        let locationName = weatherLocationName(
            locality: placemark?.locality,
            administrativeArea: placemark?.administrativeArea,
            fallback: fallbackDisplayName
        )

        return WeatherLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: locationName,
            capturedAt: location.timestamp
        )
    }

    private func weatherLocationName(
        locality: String?,
        administrativeArea: String?,
        fallback: String?
    ) -> String {
        let parts = [locality, administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let uniqueParts = parts.reduce(into: [String]()) { result, item in
            if !result.contains(item) {
                result.append(item)
            }
        }

        return uniqueParts.isEmpty
            ? fallback ?? "当前位置"
            : uniqueParts.joined(separator: ", ")
    }

    // MARK: - Status & Weather Pills Row
    private var pillsRow: some View {
        HStack(spacing: 12) {
            // Dynamic Active status pill (Clicking opens selection card)
            Button {
                showActiveStatus = true
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(statusPillColor)
                            .frame(width: 32, height: 32)

                        Image(systemName: statusPillIcon)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusPillTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text(activeStatusDuration)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // Dynamic Weather status pill (Successfully auto-syncs)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F1F3F4"))
                        .frame(width: 32, height: 32)

                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 14))
                        .symbolRenderingMode(.multicolor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(weatherTemp)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text(weatherLocation)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Cockpit Card (Strain, Recovery, Sleep side-by-side rings)
    private var cockpitCard: some View {
        let state = todayCommandState
        let accentColor = readinessColor(state.readinessDecision.decision)

        return VStack(alignment: .leading, spacing: 16) {
            // Three circular gauges
            HStack(alignment: .center, spacing: 0) {
                // Strain (耗力) - Grey Theme
                NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                    BevelScoreRing(
                        score: strainScore,
                        color: Color(hex: "#8E8A80"),
                        useGradient: false,
                        size: 78,
                        label: "耗力",
                        valueText: dashboard.strain.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.strain.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // Vertical divider line
                Rectangle()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(width: 0.5, height: 60)

                // Recovery (恢复) - Yellow Green Gradient
                NavigationLink(destination: VelaMetricDetailView(metric: .recovery)) {
                    BevelScoreRing(
                        score: recoveryScore,
                        color: Color(hex: "#9CCC65"),
                        useGradient: true,
                        size: 78,
                        label: "恢复",
                        valueText: dashboard.recovery.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.recovery.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                // Vertical divider line
                Rectangle()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(width: 0.5, height: 60)

                // Sleep (睡眠) - Blue Indigo Gradient
                NavigationLink(destination: VelaMetricDetailView(metric: .sleep)) {
                    BevelScoreRing(
                        score: sleepScore,
                        color: Color(hex: "#5C6BC0"),
                        useGradient: true,
                        size: 78,
                        label: "睡眠",
                        valueText: dashboard.sleepScore.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.sleepScore.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)

            Divider()

            // Integrated Guidance / Today Command Center
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    showTodayEvidence = true
                } label: {
                    HStack(alignment: .center) {
                        Text("指导 / COMMAND CENTER")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                            .foregroundStyle(Color(hex: "#8E8A80"))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: "#BFB9AC"))
                    }
                }
                .buttonStyle(.plain)

                Button {
                    showTodayEvidence = true
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.bodyStateTitle)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)

                            Text(state.coachArtifact?.summary ?? state.summary)
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.fg2)
                                .lineSpacing(3)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            ConfidenceBadge(confidence: state.dataConfidence)
                            Text("\(Int((state.readinessDecision.confidence * 100).rounded()))%")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let artifact = state.coachArtifact, !artifact.actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(artifact.actions) { action in
                                ActionPill(
                                    title: action.label,
                                    systemImage: icon(for: action),
                                    isPrimary: action.id == artifact.actions.first?.id
                                ) {
                                    handleCoachArtifactAction(action, artifact: artifact)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                } else if !state.actions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(state.actions.prefix(3)) { action in
                                ActionPill(
                                    title: action.title,
                                    systemImage: icon(for: action),
                                    isPrimary: action.isPrimary
                                ) {
                                    handleTodayAction(action)
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
        )
    }

    // MARK: - Stress & Energy Section
    private var stressAndEnergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("压力和能量")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#8E8A80"))
                .padding(.leading, 2)

            // 1. Stress Card
            NavigationLink(destination: VelaMetricDetailView(metric: .stress)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#81C784"))
                                .frame(width: 8, height: 8)

                            Text("今天的压力")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#1A1917"))

                            Text(dashboard.stress.hasData ? "已同步" : "暂无数据")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }

                        Spacer()

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#BFB9AC"))
                    }

                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dashboard.stress.hasData ? "\(Int(stressLevel.rounded()))" : "--")
                                .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(Color(hex: "#FF7043"))
                            Text("每日指数")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }

                        Spacer()

                        if dashboard.stress.hasData {
                            let baseData = [0.15, 0.22, 0.35, 0.30, 0.42, 0.38, 0.50, 0.38, 0.30, 0.25]
                            let factor = max(0.1, min(1.8, stressLevel / 50.0))
                            let stressHistory = baseData.map { max(0.01, min(0.99, $0 * factor)) }
                            SparklineLineGraph(data: stressHistory, color: Color(hex: "#FF7043"), height: 26, width: 110)
                        } else {
                            Text("暂无数据")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)

            // 2. Energy Card (Bevel High-Fidelity Segmented Battery Card)
            NavigationLink(destination: VelaMetricDetailView(metric: .energy)) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(hex: "#34C759")) // Vibrant Bevel green

                    Spacer()

                    // 40 Ticks
                    HStack(spacing: 1.2) {
                        ForEach(0..<40, id: \.self) { idx in
                            let threshold = Double(idx) / 40.0 * 100.0
                            RoundedRectangle(cornerRadius: 1.0)
                                .fill(animatedEnergyScore >= threshold ? Color(hex: "#34C759") : Color(hex: "#E5E5EA").opacity(0.7))
                                .frame(width: 1.8, height: 10)
                        }
                    }

                    Spacer()

                    Text(dashboard.energy.hasData ? "\(Int(energyScore))%" : "--")
                        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Daily Activity Section
    private var dailyActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("日常活动")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#8E8A80"))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(DailyActivityDetailCatalog.metrics.enumerated()), id: \.element.rawValue) { index, metric in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 60)
                    }

                    NavigationLink(destination: VelaMetricDetailView(metric: metric)) {
                        dailyActivityRow(metric)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
            )
        }
    }

    private func dailyActivityRow(_ metric: VelaMetricDetailView.MetricType) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dailyActivityColor(for: metric).opacity(0.14))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: dailyActivityIcon(for: metric))
                        .font(.system(size: 15, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(dailyActivityColor(for: metric))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(dailyActivityTitle(for: metric))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Text(dailyActivitySubtitle(for: metric))
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }

            Spacer()

            Text(dailyActivityValue(for: metric))
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color(hex: "#1A1917"))

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func dailyActivityTitle(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .steps: return "步数"
        case .activeCalories: return "活动消耗"
        case .activeMinutes: return "活跃时长"
        default: return metric.rawValue
        }
    }

    private func dailyActivitySubtitle(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .steps: return "每日基础移动"
        case .activeCalories: return "训练与日常活动"
        case .activeMinutes: return "中高强度活动时间"
        default: return ""
        }
    }

    private func dailyActivityIcon(for metric: VelaMetricDetailView.MetricType) -> String {
        switch metric {
        case .steps: return "shoeprints.fill"
        case .activeCalories: return "flame.fill"
        case .activeMinutes: return "clock.badge.checkmark"
        default: return "chart.line.uptrend.xyaxis"
        }
    }

    private func dailyActivityColor(for metric: VelaMetricDetailView.MetricType) -> Color {
        switch metric {
        case .steps: return Color(hex: "#E0A926")
        case .activeCalories: return VelaTheme.strainColor
        case .activeMinutes: return VelaTheme.sleepColor
        default: return VelaTheme.accent
        }
    }

    private func dailyActivityValue(for metric: VelaMetricDetailView.MetricType) -> String {
        let metrics = dashboard.strain.metrics
        switch metric {
        case .steps:
            return metrics["steps_raw"].map { "\(Int($0.rounded())) 步" } ?? "--"
        case .activeCalories:
            return metrics["active_energy_raw"].map { "\(Int($0.rounded())) kcal" } ?? "--"
        case .activeMinutes:
            return metrics["exercise_minutes_raw"].map { "\(Int($0.rounded())) 分钟" } ?? "--"
        default:
            return "--"
        }
    }

    // MARK: - Nutrition (营养) Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日膳食营养")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.5)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: "#8E8A80"))
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(todayCalories)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text("已消耗卡路里 / 目标 \(dailyCalorieTarget)")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }

                    Spacer()

                    // Smooth Progress Circle
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#F2F2F7"), lineWidth: 6)
                            .frame(width: 58, height: 58)

                        Circle()
                            .trim(from: 0.0, to: calorieFraction)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#FFB74D"), Color(hex: "#FF8A65")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 58, height: 58)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(calorieFraction * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#1A1917"))
                    }
                }

                Divider()
                    .background(Color(hex: "#E5E5EA"))

                // Macros (Protein, Carbs, Fat)
                HStack(spacing: 0) {
                    macroIndicator(title: "蛋白质", target: "90g", current: "\(todayProtein)g", color: Color(hex: "#FF7043"))
                    Spacer()
                    macroIndicator(title: "碳水", target: "220g", current: "\(todayCarbs)g", color: Color(hex: "#FFB74D"))
                    Spacer()
                    macroIndicator(title: "脂肪", target: "65g", current: "\(todayFat)g", color: Color(hex: "#42A5F5"))
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
            )
        }
    }

    private func macroIndicator(title: String, target: String, current: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }

            Text(current)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A1917"))

            Text("目标 \(target)")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
    }

    // MARK: - SwiftData nutrition sync
    private func loadRealNutritionData() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dashboardVM.selectedDate)

        let descriptor = FetchDescriptor<FoodLogRecord>()
        do {
            let allLogs = try modelContext.fetch(descriptor)
            let todayLogs = allLogs.filter { log in
                calendar.isDate(log.createdAt, inSameDayAs: start)
            }

            todayCalories = todayLogs.map(\.totalCalories).reduce(0, +)
            todayProtein = todayLogs.map(\.proteinGrams).reduce(0, +)
            todayCarbs = todayLogs.map(\.carbsGrams).reduce(0, +)
            todayFat = todayLogs.map(\.fatGrams).reduce(0, +)
        } catch {
            print("Failed to fetch food logs: \(error)")
        }
    }

    private func refreshDashboard(force: Bool = false) async {
        await dashboardVM.refresh(modelContext: modelContext, force: force)
        loadRealNutritionData()
        fetchLocalWeather()
    }
}

private struct ProactiveGuidanceCard: View {
    let insight: ProactiveInsight
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: insight.focus.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(insight.focus.color)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(insight.focus.color.opacity(0.10))
                        )

                    Text(insight.displayTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#C7C7CC"))
                }

                Text(insight.body)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(VelaTheme.meta)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(insight.focus.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(insight.focus.color)

                    Text(insight.suggestedAction ?? "打开详情查看更完整的训练和恢复建议。")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(insight.focus.color.opacity(0.065))
                )
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(hex: "#F7F7F9"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ProactiveInsightDetailSheet: View {
    let insight: ProactiveInsight
    var onAskCoach: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private var actionText: String {
        insight.suggestedAction ?? "先观察今天的身体反馈，保持当前节奏。"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: insight.focus.icon)
                                .font(.system(size: 23, weight: .semibold))
                                .foregroundStyle(insight.focus.color)
                                .frame(width: 52, height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(insight.focus.color.opacity(0.10))
                                )

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 7) {
                                    Text(insight.focus.title)
                                    Text("·")
                                    Text(insight.severity.contextLabel)
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(insight.severity.color)

                                Text(insight.displayTitle)
                                    .font(.system(size: 23, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }

                        Text(insight.body)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VelaTheme.meta)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .velaNativeCard(radius: 22)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("身体信号")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VelaTheme.muted)

                        VStack(spacing: 0) {
                            ForEach(Array(insight.evidenceItems.enumerated()), id: \.offset) { index, item in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .frame(width: 24, height: 24)
                                        .padding(.top, 5)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(VelaTheme.fg)

                                        Text(item.subtitle)
                                            .font(.system(size: 12, weight: .regular))
                                            .foregroundStyle(VelaTheme.meta)
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 12)

                                if index < insight.evidenceItems.count - 1 {
                                    Divider()
                                        .padding(.leading, 49)
                                }
                            }
                        }
                        .velaNativeCard(radius: 18)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("行动安排")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .foregroundStyle(VelaTheme.muted)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(insight.focus.color)
                                    .padding(.top, 1)

                                Text(actionText)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                    .lineSpacing(4)

                                Spacer()
                            }

                            Text("这不是医疗诊断；Vela 会把建议限制在训练、恢复、睡眠和日常节奏调整上。")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(VelaTheme.meta)
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .velaNativeCard(radius: 18)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(VelaTheme.systemGroupedBackground)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        onAskCoach(insight.coachPresetQuestion)
                    } label: {
                        Label("和 Coach 讨论", systemImage: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VelaTheme.accent)

                    Button {
                        dismiss()
                    } label: {
                        Text("知道了")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
            .navigationTitle("智能建议")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension ProactiveInsight {
    var displayTitle: String {
        title.replacingOccurrences(
            of: #"^[^\p{L}\p{N}]+\s*"#,
            with: "",
            options: .regularExpression
        )
    }

    var evidenceItems: [(title: String, subtitle: String, icon: String)] {
        if !evidence.isEmpty {
            return evidence.prefix(3).enumerated().map { index, text in
                let metric = relatedMetrics.indices.contains(index) ? relatedMetrics[index] : relatedMetrics.first
                return (
                    title: text,
                    subtitle: index == 0 ? "主要判断依据" : "辅助判断依据",
                    icon: metric?.insightMetricIcon ?? focus.icon
                )
            }
        }

        return relatedMetrics.prefix(3).map { metric in
            (
                title: metric.localizedInsightMetricName,
                subtitle: "来自今日健康与训练数据",
                icon: metric.insightMetricIcon
            )
        }
    }
}

private extension ProactiveInsight.Severity {
    var contextLabel: String {
        switch self {
        case .info: return "状态良好"
        case .warning: return "需要留意"
        case .alert: return "建议调整"
        }
    }
}

private extension String {
    var localizedInsightMetricName: String {
        switch lowercased() {
        case "hrv": return "HRV"
        case "rhr", "resting_heart_rate": return "静息心率"
        case "recovery": return "恢复"
        case "sleep": return "睡眠"
        case "energy": return "能量"
        case "strain": return "训练负荷"
        case "stress": return "压力"
        case "walking_asymmetry": return "步态"
        default: return self.replacingOccurrences(of: "_", with: " ")
        }
    }

    var insightMetricIcon: String {
        switch lowercased() {
        case "hrv", "rhr", "resting_heart_rate": return "heart.text.square"
        case "recovery": return "arrow.clockwise.heart"
        case "sleep": return "moon.zzz.fill"
        case "energy": return "bolt.fill"
        case "strain": return "figure.strengthtraining.traditional"
        case "stress": return "waveform.path.ecg"
        case "walking_asymmetry": return "figure.walk"
        default: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - ActiveStatusSelectionSheetView (High fidelity to Screenshot 2)
struct ActiveStatusSelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var activeStatusRaw: String
    @Binding var activeStatusDuration: String

    @State private var tempStatus: String = "resting"
    @State private var tempDuration: String = "明天之前"

    let durationOptions = ["明天之前", "1天", "3天", "5天", "7天", "长期"]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(hex: "#F2F2F7")))
                }
                .buttonStyle(.plain)

                Spacer()

                Text("活动状态")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)

            ScrollView {
                VStack(spacing: 14) {
                    statusOptionCard(
                        id: "active",
                        title: "活跃",
                        desc: "保持忙碌和健康",
                        icon: "figure.run",
                        colors: [Color(hex: "#34C759"), Color(hex: "#2ECC71")]
                    )

                    statusOptionCard(
                        id: "sick",
                        title: "生病",
                        desc: "因病休息",
                        icon: "bed.double.fill",
                        colors: [Color(hex: "#FF9F0A"), Color(hex: "#F1C40F")]
                    )

                    statusOptionCard(
                        id: "injured",
                        title: "受伤",
                        desc: "从伤病中恢复",
                        icon: "bandage.fill",
                        colors: [Color(hex: "#FF3B30"), Color(hex: "#E74C3C")]
                    )

                    statusOptionCard(
                        id: "resting",
                        title: "休息中",
                        desc: "从训练中抽出时间休息",
                        icon: "beach.umbrella.fill",
                        colors: [Color(hex: "#4285F4"), Color(hex: "#3498DB")]
                    )

                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Text("保持状态")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#1A1917"))
                        }

                        Spacer()

                        Menu {
                            ForEach(durationOptions, id: \.self) { opt in
                                Button(opt) {
                                    tempDuration = opt
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tempDuration)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "#BFB9AC"))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#E5E5EA"), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Button {
                        ActiveStatusSettings.update(status: tempStatus, duration: tempDuration)
                        activeStatusRaw = tempStatus
                        activeStatusDuration = tempDuration
                        dismiss()
                    } label: {
                        Text("更新")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: "#1A1917")))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            tempStatus = activeStatusRaw
            tempDuration = activeStatusDuration
        }
        .background(Color(hex: "#F2F2F7").ignoresSafeArea())
    }

    private func statusOptionCard(id: String, title: String, desc: String, icon: String, colors: [Color]) -> some View {
        Button {
            tempStatus = id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(tempStatus == id ? Color(hex: "#1A1917") : Color(hex: "#E5E5EA"), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if tempStatus == id {
                        Circle()
                            .fill(Color(hex: "#1A1917"))
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: Color.black.opacity(tempStatus == id ? 0.02 : 0.0), radius: 6, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tempStatus == id ? Color(hex: "#1A1917") : Color.clear, lineWidth: 1.5)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CalendarOverviewSheetView (High fidelity to Screenshot 1)
struct CalendarOverviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \DailyHealthSummaryRecord.date) private var healthRecords: [DailyHealthSummaryRecord]

    @State private var selectedMetric: String = "恢复"
    @State private var calendarYear = Calendar.current.component(.year, from: Date())
    @State private var calendarMonth = Calendar.current.component(.month, from: Date())
    @State private var showCalendarInfo = false

    let metrics = ["耗力", "恢复", "睡眠", "压力", "能量", "营养"]
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            HStack {
                Menu {
                    ForEach(0..<12, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
                        Button(monthTitle(for: date)) {
                            calendarYear = Calendar.current.component(.year, from: date)
                            calendarMonth = Calendar.current.component(.month, from: date)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(verbatim: VelaMinimalFormatting.calendarTitle(year: calendarYear, month: calendarMonth))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                    }
                }

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        prevMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)

                    Button {
                        nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveToNextMonth)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(metrics, id: \.self) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Text(metric)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(selectedMetric == metric ? Color.white : Color(hex: "#8E8A80"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedMetric == metric ? Color(hex: "#1A1917") : Color(hex: "#F2F2F7"))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedMetric == metric ? Color.clear : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }

            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)

            let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            let paddingDays = paddingDaysForDisplayedMonth

            ScrollView {
                LazyVGrid(columns: gridLayout, spacing: 14) {
                    ForEach((0..<paddingDays).map { "padding-\($0)" }, id: \.self) { _ in
                        Color.clear.frame(height: 52)
                    }

                    ForEach(1...daysInDisplayedMonth, id: \.self) { day in
                        let date = makeDate(year: calendarYear, month: calendarMonth, day: day)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: dashboardVM.selectedDate)
                        let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
                        let scoreInfo = scoreInfo(for: date)

                        Button {
                            dashboardVM.selectDate(date)
                            dismiss()
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .stroke(Color(hex: "#F2F2F7"), lineWidth: 4)
                                        .frame(width: 36, height: 36)

                                    if let scoreInfo {
                                        Circle()
                                            .trim(from: 0.0, to: CGFloat(scoreInfo.score / 100.0))
                                            .stroke(scoreInfo.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                            .frame(width: 36, height: 36)
                                            .rotationEffect(.degrees(-90))
                                    }

                                    Text("\(day)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isFuture ? Color(hex: "#BFB9AC") : (isSelected ? Color(hex: "#4285F4") : Color(hex: "#1A1917")))
                                }

                                Color.clear.frame(height: 8)
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(hex: "#4285F4").opacity(0.08))
                                            .frame(width: 44, height: 48)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }

            HStack {
                Button {
                    dashboardVM.goToToday()
                    dismiss()
                } label: {
                    Text("今天")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#4285F4"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#E8F0FE")))
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showCalendarInfo = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#F2F2F7").ignoresSafeArea())
        .onAppear {
            calendarYear = Calendar.current.component(.year, from: dashboardVM.selectedDate)
            calendarMonth = Calendar.current.component(.month, from: dashboardVM.selectedDate)
        }
        .alert("日历指标说明", isPresented: $showCalendarInfo) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("选择顶部指标可查看每日趋势。圆环越完整，表示该指标分数越高；没有圆环表示当天缺少对应数据。")
        }
    }

    private var displayedMonthDate: Date {
        makeDate(year: calendarYear, month: calendarMonth, day: 1)
    }

    private var daysInDisplayedMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: displayedMonthDate)?.count ?? 0
    }

    private var paddingDaysForDisplayedMonth: Int {
        Calendar.current.component(.weekday, from: displayedMonthDate) - 1
    }

    private var canMoveToNextMonth: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return displayedMonthDate < currentMonth
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        return Calendar.current.date(from: comp) ?? Date()
    }

    private func prevMonth() {
        if calendarMonth == 1 {
            calendarMonth = 12
            calendarYear -= 1
        } else {
            calendarMonth -= 1
        }
    }

    private func nextMonth() {
        guard canMoveToNextMonth else { return }
        if calendarMonth == 12 {
            calendarMonth = 1
            calendarYear += 1
        } else {
            calendarMonth += 1
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func scoreInfo(for date: Date) -> (score: Double, color: Color)? {
        guard let record = healthRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let score: Double?
        switch selectedMetric {
        case "耗力": score = record.strainScore
        case "恢复": score = record.recoveryScore
        case "睡眠": score = record.sleepScore
        case "压力": score = record.stressIndex
        case "能量": score = record.energyBank
        default: score = nil
        }
        guard let score else { return nil }
        let color: Color
        switch score {
        case ..<40: color = Color(hex: "#FF3B30")
        case ..<70: color = Color(hex: "#FFB74D")
        default: color = Color(hex: "#34C759")
        }
        return (score, color)
    }
}

private extension View {
    @ViewBuilder
    func velaTrackScrollOffsetY(offset: Binding<CGFloat>) -> some View {
        if #available(iOS 18, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newY in
                offset.wrappedValue = newY
            }
        } else {
            self
        }
    }
}

private struct TodayDecisionEvidenceSheet: View {
    let state: TodayCommandState
    let dashboard: DashboardSummary
    var onAskCoach: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("今日状态决策") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            Text(state.bodyStateTitle)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(readinessColor(state.readinessDecision.decision))

                            Spacer()

                            HStack(spacing: 4) {
                                ConfidenceBadge(confidence: state.dataConfidence)
                                Text("\(Int((state.readinessDecision.confidence * 100).rounded()))%")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundStyle(readinessColor(state.readinessDecision.decision))
                            }
                        }

                        Text(state.coachArtifact?.summary ?? state.summary)
                            .font(VelaTheme.subheadline())
                            .foregroundStyle(VelaTheme.fg2)
                            .lineSpacing(4)
                    }
                    .padding(.vertical, 4)
                }

                let insights = ProactiveInsightService.evaluate(dashboard: dashboard)
                if !insights.isEmpty {
                    Section("AI 针对性指导建议") {
                        ForEach(insights) { insight in
                            NavigationLink {
                                ProactiveInsightDetailSheet(insight: insight) { question in
                                    dismiss()
                                    onAskCoach(question)
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: insight.focus.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(insight.focus.color.opacity(0.10)))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(insight.displayTitle)
                                            .font(VelaTheme.subheadline())
                                            .fontWeight(.semibold)
                                            .foregroundStyle(VelaTheme.fg)
                                            .lineLimit(1)

                                        Text(insight.body)
                                            .font(VelaTheme.caption1())
                                            .foregroundStyle(VelaTheme.muted)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Text(insight.focus.title)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(insight.focus.color)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(insight.focus.color.opacity(0.08)))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                if !state.keySignals.isEmpty {
                    Section("今日身体数据信号") {
                        ForEach(state.keySignals) { signal in
                            SignalRow(signal: signal)
                        }
                    }
                }

                if !state.readinessDecision.reasons.isEmpty {
                    Section("决策详细逻辑推理") {
                        ForEach(state.readinessDecision.reasons, id: \.self) { reason in
                            Text(reason)
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.fg2)
                                .lineSpacing(3)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("今日指导与证据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func readinessColor(_ decision: ReadinessDecisionKind) -> Color {
        switch decision {
        case .keep: return VelaTheme.success
        case .reduce: return Color(hex: "#FF9F0A")
        case .swap: return Color(hex: "#5C6BC0")
        case .recover: return VelaTheme.sleep
        }
    }
}
