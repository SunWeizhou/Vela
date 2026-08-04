import SwiftUI
import SwiftData
import CoreLocation

// MARK: - VelaTodayView — evidence-first daily decision surface

struct VelaTodayView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var cs
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @ObservedObject var appState = VelaAppState.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var hrvValue: Double { dashboard.recoveryMetrics.hrvMilliseconds ?? 0 }
    private var rhrValue: Double { dashboard.recoveryMetrics.restingHeartRate ?? 0 }

    var bodyState: BodyState { dashboard.bodyState }
    var trainingDecision: TrainingDecision { dashboard.trainingDecision }
    var persistedOperatingPlan: DailyOperatingPlanRecord? { dashboardVM.persistedOperatingPlan }
    var latestTodayArtifact: CoachArtifact? { dashboardVM.latestTodayArtifact }
    
    var todayCommandState: TodayCommandState {
        dashboardVM.todayCommandState ?? TodayCommandBuilder.build(from: dashboard)
    }
    
    var todayExperience: TodayExperienceModel {
        dashboardVM.todayExperience ?? makeTodayExperience()
    }

    func makeTodayExperience() -> TodayExperienceModel {
        let recentStrengthSummary = TrainingAnalyticsService().buildRecentSummary(
            workouts: [],
            days: 7,
            endingAt: dashboardVM.selectedDate
        )
        let dailyTrainingDecision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
            bodyState: bodyState,
            activePlan: nil,
            recentStrengthSummary: recentStrengthSummary,
            trainingResponses: []
        ))
        return TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: dailyTrainingDecision,
            nutrition: TodayExperienceNutrition(
                calories: todayCalories,
                calorieTarget: dailyCalorieTarget,
                protein: todayProtein,
                carbs: todayCarbs,
                fat: todayFat
            )
        )
    }

    // Real scores mapped to 0...1 for BevelScoreRing
    var strainScore: Double { max(0, min(1.0, dashboard.strain.score / 100.0)) }
    var recoveryScore: Double { max(0, min(1.0, dashboard.recovery.score / 100.0)) }
    var sleepScore: Double { max(0, min(1.0, dashboard.sleepScore.score / 100.0)) }

    // Stress & Energy
    var stressLevel: Double { dashboard.stress.stressIndex }
    var energyScore: Double { dashboard.energy.currentEnergy }

    @AppStorage("vela_daily_calorie_target") var dailyCalorieTarget = 2000

    var todayCalories: Int { dashboardVM.todayCalories }
    var todayProtein: Int { dashboardVM.todayProtein }
    var todayCarbs: Int { dashboardVM.todayCarbs }
    var todayFat: Int { dashboardVM.todayFat }

    var calorieFraction: CGFloat {
        CGFloat(min(1.0, Double(todayCalories) / Double(max(dailyCalorieTarget, 1))))
    }

    // MARK: - G1 重设计数据

    private var vitalCards: [TodayVitalCardModel] {
        let rm = dashboard.recoveryMetrics
        let hrv = rm.hrvMilliseconds
        let rhr = rm.restingHeartRate
        let spo2 = dashboard.extendedMetrics.oxygenSaturation
        let sleepMin = dashboard.sleepSummary.stageMinutes
            .filter { $0.key != .awake }
            .reduce(0) { $0 + $1.value }
        return [
            TodayVitalCardModel(
                kind: .hrv, label: "心率变异性",
                value: hrv.map { "\(Int($0.rounded()))" } ?? "--", unit: "ms",
                status: "今早", isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .rhr, label: "静息心率",
                value: rhr.map { "\(Int($0.rounded()))" } ?? "--", unit: "bpm",
                status: "今早", isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .spo2, label: "血氧",
                value: spo2.map { "\(Int($0.rounded()))" } ?? "--", unit: "%",
                status: "今早", isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .sleep, label: "睡眠",
                value: sleepMin > 0 ? "\(sleepMin / 60):\(String(format: "%02d", sleepMin % 60))" : "--", unit: "时",
                status: "今早", isGood: true, trend: []
            )
        ]
    }

    private var weeklyLoads: [Double] {
        Array(dashboardVM.strainTrend.suffix(7).map { $0.value })
    }

    private var acwrText: String {
        if let acwr = dashboard.energy.components["acwr"] {
            return String(format: "ACWR %.2f", acwr)
        }
        return "本周"
    }

    var coachMessage: String {
        dashboard.dailyInsight.isEmpty
            ? "正在等待足够的 Apple 健康数据，完成同步后会生成今日指导。"
            : dashboard.dailyInsight
    }

    var todayShareText: String {
        let recoveryText = dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--"
        let sleepText = dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--"
        let strainText = dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--"
        return "\(dateHeaderString(for: dashboardVM.selectedDate))\n恢复 \(recoveryText) · 睡眠 \(sleepText) · 负荷 \(strainText)\n\(coachMessage)"
    }

    // Dynamic Weather Sync States
    @State var weatherTemp: String = "--"
    @State var weatherLocation: String = "天气数据待同步"

    var weatherStatusText: String {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            return "点击更新天气"
        case .denied, .restricted:
            return "定位未授权"
        default:
            return weatherLocation
        }
    }

    @Query(sort: \ProactiveInsightRecord.priority) private var proactiveRecords: [ProactiveInsightRecord]

    // Sheets trigger states
    @State var showCalendarOverview = false
    @State var selectedInsightIndex = 0
    @State var selectedInsight: ProactiveInsight?
    @State var showTodayEvidence = false
    @State var animatedEnergyScore: Double = 0.0
    @State var experienceFeedbackTick = 0
    @State var dataCoverageSummary = DataCoverageSummaryModel.unknown
    @State var dailyDecisionFeedback: DailyDecisionFeedbackRecord?
    @State var showDailyDecisionFeedback = false

    var decisionDataCoverageSummary: DataCoverageSummaryModel {
        guard dataCoverageSummary.status != .unknown,
              !dashboard.recovery.hasData else { return dataCoverageSummary }

        var adjusted = dataCoverageSummary
        adjusted.domainSummaries = adjusted.domainSummaries.map { domain in
            guard domain.id == "recovery" else { return domain }
            return DataCoverageDomainSummary(
                id: domain.id,
                title: domain.title,
                icon: domain.icon,
                scorePercent: 0,
                usableCount: 0,
                totalCount: domain.totalCount
            )
        }
        let usable = adjusted.domainSummaries.reduce(0) { $0 + $1.usableCount }
        let total = adjusted.domainSummaries.reduce(0) { $0 + $1.totalCount }
        adjusted.scorePercent = total > 0
            ? Int((Double(usable) / Double(total) * 100).rounded())
            : 0
        adjusted.status = adjusted.scorePercent >= 50 ? .moderate : .low
        adjusted.title = "今日恢复数据待同步"
        adjusted.subtitle = "恢复信号尚未更新；今天的训练建议会按保守窗口处理。"
        adjusted.topBlockers = Array((["今日恢复"] + adjusted.topBlockers).prefix(3))
        adjusted.coachContextLine = "Today's recovery signal is unavailable. Keep training guidance conservative until recovery data syncs."
        return adjusted
    }

    @ViewBuilder
    var errorMessageView: some View {
        if let errorMessage = dashboardVM.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                }
                if let suggestion = dashboardVM.currentError?.recoverySuggestion {
                    Text(suggestion)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.cardBg))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    var body: some View {
        let recoveryText = dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--"
        let accentColor = accentColor(trainingDecision.accent)
        let planSafetyNotice = persistedOperatingPlan?.safetyNotice

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                errorMessageView

                TodayReadinessHero(
                    scoreText: recoveryText,
                    stateText: todayExperience.hero.decisionTitle,
                    state: dashboard.recovery.state,
                    trend: todayExperience.signalCards.first(where: { $0.id == "recovery" })?.trend ?? []
                )

                TodayStateRingsStrip(model: todayExperience)

                TodayGuidanceCard(
                    title: todayExperience.hero.decisionTitle,
                    summary: todayExperience.hero.summary,
                    onAskCoach: { showCoach = true }
                )

                if let planSafetyNotice, !planSafetyNotice.isEmpty {
                    Text(planSafetyNotice)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(VelaTheme.meta)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }

                TodayVitalsGrid(cards: vitalCards) { _ in
                    showCoach = true
                }

                TodayWeeklyLoadCard(loads: weeklyLoads, acwrText: acwrText)

                if decisionDataCoverageSummary.status != .high {
                    DataCoverageCompactCard(
                        model: decisionDataCoverageSummary,
                        showSettings: $showSettings
                    )
                }

                TodayDailyModuleLinks(
                    recoveryMetrics: dashboard.recoveryMetrics,
                    nutrition: todayExperience.nutrition,
                    onAddNutrition: {
                        appState.triggerFoodSearch = true
                    },
                    onJournal: {
                        appState.triggerJournal = true
                    }
                )

                TodayCoachPreview(
                    model: todayExperience,
                    onQuestion: { question in
                        VelaAppState.shared.routeToCoach(question: question)
                    }
                )

                TodayActionTimeline(
                    model: todayExperience,
                    accent: accentColor,
                    onAction: { performExperienceAction($0) },
                    onEvidenceClick: { showTodayEvidence = true }
                )

                if persistedOperatingPlan != nil {
                    DailyDecisionFeedbackCard(
                        record: dailyDecisionFeedback,
                        onTap: { showDailyDecisionFeedback = true }
                    )
                }

                if decisionDataCoverageSummary.status == .high {
                    DataCoverageCompactCard(
                        model: decisionDataCoverageSummary,
                        showSettings: $showSettings
                    )
                }

                DigitalTwinSimulatorCard(dashboard: dashboard)
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 12)
            .padding(.bottom, VelaTheme.bottomContentClearance)
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let horizontal = value.predictedEndTranslation.width
                    let vertical = value.predictedEndTranslation.height
                    guard abs(horizontal) > 70,
                          abs(horizontal) > abs(vertical) * 1.35 else {
                        return
                    }
                    withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                        if horizontal > 0 {
                            dashboardVM.goToPreviousDay()
                        } else if !dashboardVM.isToday {
                            dashboardVM.goToNextDay()
                        }
                    }
                }
        )
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                TodayDateAndStatusHeader(
                    selectedDate: dashboardVM.selectedDate,
                    todayShareText: todayShareText,
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    showSimulationLabel: dashboard.source == .preview,
                    showCalendarOverview: $showCalendarOverview,
                    showSettings: $showSettings,
                    requestWeatherUpdate: { requestWeatherUpdate() }
                )
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.bottom, 12)
                .background(.bar)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            loadDynamicData()
            locationManager.startUpdating()
            await refreshDashboard()
            await loadDataCoverageSummary()
            trackDailyDecisionViewed()
            withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
                animatedEnergyScore = energyScore
            }
        }
        .refreshable {
            await refreshDashboard(force: true)
            await loadDataCoverageSummary()
        }
        .onChange(of: scenePhase) {
            // Returning to foreground (e.g. after being backgrounded overnight) must
            // re-sync HealthKit and recompute scores. `.task(id: isActiveSurface)` only
            // re-fires when the tab-selection value CHANGES — if the home tab was already
            // selected, foregrounding showed yesterday's cached/stale scores. Force a
            // refresh on active so the Today view always shows fresh data.
            if scenePhase == .active, isActiveSurface {
                Task {
                    await refreshDashboard(force: true)
                    await loadDataCoverageSummary()
                }
            }
        }
        .onChange(of: dashboardVM.selectedDate) {
            guard isActiveSurface else { return }
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadDynamicData()
            Task {
                await refreshDashboard()
                withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
                    animatedEnergyScore = energyScore
                }
            }
        }
        .onChange(of: energyScore) {
            withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
                animatedEnergyScore = energyScore
            }
        }
        .onChange(of: appState.localDataRevision) {
            guard isActiveSurface else { return }
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            loadDynamicData()
        }
        .onChange(of: locationManager.location) {
            fetchLocalWeather()
        }
        .sheet(isPresented: $showCalendarOverview) {
            CalendarOverviewSheetView()
                .presentationDetents([.medium, .large])
                .velaSheetSurface()
        }
        .sheet(item: $selectedInsight) { insight in
            ProactiveInsightDetailSheet(insight: insight) { question in
                selectedInsight = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    VelaAppState.shared.routeToCoach(question: question)
                }
            }
            .presentationDetents([.medium, .large])
            .velaSheetSurface()
        }
        .sheet(isPresented: $showTodayEvidence) {
            TodayEvidenceSheet(
                state: todayCommandState,
                dashboard: dashboard,
                onAskCoach: { question in
                    VelaAppState.shared.routeToCoach(question: question)
                }
            )
            .presentationDetents([.medium, .large])
            .velaSheetSurface()
        }
        .sheet(isPresented: $showDailyDecisionFeedback) {
            if let dailyDecisionFeedback {
                DailyDecisionFeedbackSheet(record: dailyDecisionFeedback) { values in
                    saveDailyDecisionFeedback(values)
                }
                .presentationDetents([.large])
                .velaSheetSurface()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    func performExperienceAction(_ action: TodayExperienceAction) {
        experienceFeedbackTick += 1
        trackDailyDecisionAction(destination: action.destination)
        switch action.destination {
        case "training":
            appState.routeToAdaptiveTrainingStart()
        case "journal":
            appState.triggerJournal = true
        case "coach":
            VelaAppState.shared.routeToCoach(question: action.detail)
        case "recovery", "sync", "evidence":
            showTodayEvidence = true
        default:
            showTodayEvidence = true
        }
    }

    func trackDailyDecisionViewed() {
        guard Calendar.current.isDateInToday(dashboardVM.selectedDate),
              let plan = persistedOperatingPlan else {
            loadDailyDecisionFeedback()
            return
        }
        do {
            dailyDecisionFeedback = try DailyDecisionFeedbackService().recordViewed(
                modelContext: modelContext,
                dayIdentifier: plan.dayIdentifier,
                plan: plan,
                bodyStateHash: bodyState.hash,
                decisionType: plan.primaryActionType,
                decisionTitle: plan.title
            )
        } catch {
            loadDailyDecisionFeedback()
        }
    }

    func trackDailyDecisionAction(destination: String) {
        guard let plan = persistedOperatingPlan else { return }
        do {
            dailyDecisionFeedback = try DailyDecisionFeedbackService().recordActionStarted(
                modelContext: modelContext,
                dayIdentifier: plan.dayIdentifier,
                plan: plan,
                bodyStateHash: bodyState.hash,
                decisionType: plan.primaryActionType,
                decisionTitle: plan.title,
                destination: destination
            )
        } catch {
            // The user action must never be blocked by local analytics.
        }
    }

    func loadDailyDecisionFeedback() {
        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        let descriptor = FetchDescriptor<DailyDecisionFeedbackRecord>(
            predicate: #Predicate { $0.dayIdentifier == dayIdentifier }
        )
        dailyDecisionFeedback = try? modelContext.fetch(descriptor).first
    }

    func saveDailyDecisionFeedback(_ values: DailyDecisionFeedbackValues) {
        guard let record = dailyDecisionFeedback else { return }
        do {
            try DailyDecisionFeedbackService().saveFeedback(
                modelContext: modelContext,
                record: record,
                adoptionStatus: values.adoptionStatus,
                accuracyRating: values.accuracyRating,
                actualAction: values.actualAction,
                energyRating: values.energyRating,
                fatigueRating: values.fatigueRating,
                painRating: values.painRating,
                satisfactionRating: values.satisfactionRating,
                note: values.note
            )
            showDailyDecisionFeedback = false
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            // Keep the sheet open so the user can retry without losing input.
        }
    }

    func accentColor(_ accent: DailyPlanAccent) -> Color {
        switch accent {
        case .recovery: return VelaTheme.recoveryColor
        case .sleep: return VelaTheme.sleepColor
        case .strain: return VelaTheme.strainColor
        case .energy: return VelaTheme.energyColor
        case .stress: return VelaTheme.stressColor
        }
    }
}

// MARK: - TodayDateAndStatusHeader
struct TodayDateAndStatusHeader: View {
    let selectedDate: Date
    let todayShareText: String
    let weatherTemp: String
    let weatherStatusText: String
    let showSimulationLabel: Bool

    @Binding var showCalendarOverview: Bool
    @Binding var showSettings: Bool
    var requestWeatherUpdate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Row
            HStack(alignment: .center) {
                Button {
                    showCalendarOverview = true
                } label: {
                    HStack(spacing: 6) {
                        Text(dateHeaderString(for: selectedDate))
                            .font(VelaTheme.pageTitle())
                            .foregroundStyle(VelaTheme.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .frame(minHeight: VelaTheme.minimumHitTarget)
                }
                .buttonStyle(.cardPress)
                .accessibilityLabel("选择日期")
                .accessibilityValue(dateHeaderString(for: selectedDate))

                TodayWeatherBar(
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    requestWeatherUpdate: requestWeatherUpdate
                )

                Spacer()

                HStack(spacing: 16) {
                    // Share button
                    ShareLink(item: todayShareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VelaTheme.muted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel("分享今日摘要")

                    // Profile Avatar(右下角小绿点 = 已同步)
                    Button {
                        showSettings = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .foregroundStyle(VelaTheme.brand)
                            Circle()
                                .fill(VelaTheme.brand)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(VelaTheme.systemGroupedBackground, lineWidth: 2))
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel("个人设置,数据已同步")
                }
            }

            if showSimulationLabel {
                HStack {
                    Text(L10n.t("Simulated", "模拟数据"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VelaTheme.accent))
                    Spacer()
                }
            }
        }
    }

    private func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.t("Today", "今天")
        } else if calendar.isDateInYesterday(date) {
            return L10n.t("Yesterday", "昨天")
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = AppLanguage.stored.isChinese ? "M月d日" : "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - DataCoverageCompactCard
struct DataCoverageCompactCard: View {
    let model: DataCoverageSummaryModel
    @Binding var showSettings: Bool

    private var needsCalibrationGuidance: Bool {
        model.status == .low || model.status == .unknown
    }
    
    var body: some View {
        let accent = dataCoverageColor(model.status)
        return Button {
            showSettings = true
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Image(systemName: model.actionSystemImage)
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(accent)
                    Text(model.title)
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    Text(model.status == .unknown ? "--" : "\(model.scorePercent)%")
                        .font(VelaTheme.subheadline().weight(.bold).monospacedDigit())
                        .foregroundStyle(accent)
                    Image(systemName: "chevron.right")
                        .font(VelaTheme.caption2().weight(.semibold))
                        .foregroundStyle(VelaTheme.muted)
                }

                if needsCalibrationGuidance {
                    Text(model.subtitle)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.fg2)
                        .lineLimit(1)
                }

                if !needsCalibrationGuidance {
                    coverageDomains
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                    .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.t("Data coverage", "数据覆盖")) \(model.scorePercent)%。\(model.subtitle)")
        .accessibilityHint(model.actionTitle)
    }

    @ViewBuilder
    private var coverageDomains: some View {
        let domains = Array(model.domainSummaries.prefix(3))
        if !domains.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(domains) { domain in
                        domainLabel(domain)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(domains) { domain in
                        domainLabel(domain)
                    }
                }
            }
        }
    }

    private func domainLabel(_ domain: DataCoverageDomainSummary) -> some View {
        Label("\(domain.title) \(domain.usableCount)/\(domain.totalCount)", systemImage: domain.icon)
            .font(VelaTheme.caption2().weight(.medium))
            .foregroundStyle(dataCoveragePercentColor(domain.scorePercent))
            .lineLimit(1)
    }
    
    private func dataCoverageColor(_ status: DataCoverageSummaryModel.Status) -> Color {
        switch status {
        case .high: return VelaTheme.energyColor
        case .moderate: return VelaTheme.accent
        case .low: return VelaTheme.strainColor
        case .unknown: return VelaTheme.muted
        }
    }

    private func dataCoveragePercentColor(_ percent: Int) -> Color {
        if percent >= 80 { return VelaTheme.energyColor }
        if percent >= 50 { return VelaTheme.accent }
        return VelaTheme.strainColor
    }
}
