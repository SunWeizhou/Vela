import SwiftUI
import SwiftData
import CoreLocation

// MARK: - VelaTodayView — Bevel Replica Today Tab
// Warm off-white background (#F2F2F7) × Premium White Cockpit cards with precise shadows

struct VelaTodayView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var cs
    @Environment(\.modelContext) var modelContext
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

    // Active Status Settings Toggles (Replicating Screenshot 2)
    @AppStorage("vela_active_status") var activeStatusRaw = "active"
    @AppStorage("vela_active_status_duration") var activeStatusDuration = "明天之前"
    var resolvedActiveStatus: String {
        ActiveStatusSettings.resolveCurrentStatus()
    }

    // Sheets trigger states
    @State var showCalendarOverview = false
    @State var showActiveStatus = false
    @State var selectedInsightIndex = 0
    @State var selectedInsight: ProactiveInsight?
    @State var showTodayEvidence = false
    @State var animatedEnergyScore: Double = 0.0
    @State var experienceFeedbackTick = 0
    @State var dataCoverageSummary = DataCoverageSummaryModel.unknown

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

    var statusPillIcon: String {
        switch resolvedActiveStatus {
        case "active": return "figure.run"
        case "sick": return "bed.double.fill"
        case "injured": return "bandage.fill"
        default: return "beach.umbrella.fill"
        }
    }

    var statusPillColor: Color {
        switch resolvedActiveStatus {
        case "active": return VelaTheme.success
        case "sick": return VelaTheme.warn
        case "injured": return VelaTheme.danger
        default: return VelaTheme.accent
        }
    }

    var statusPillTitle: String {
        switch resolvedActiveStatus {
        case "active": return L10n.t("Active", "活跃")
        case "sick": return L10n.t("Sick", "生病")
        case "injured": return L10n.t("Injured", "受伤")
        default: return L10n.t("Resting", "休息中")
        }
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
        let isStalePlan = persistedOperatingPlan == nil ? false : persistedOperatingPlan!.bodyStateHash != bodyState.hash
        let recoveryText = dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--"
        let accentColor = accentColor(trainingDecision.accent)
        let primaryIcon = primaryExperienceActionIcon(todayExperience)
        let planGeneratedAt = persistedOperatingPlan?.generatedAt
        let planSafetyNotice = persistedOperatingPlan?.safetyNotice

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                errorMessageView

                TodayHeroCard(
                    model: todayExperience,
                    recoveryScoreText: recoveryText,
                    accent: accentColor,
                    primaryActionIcon: primaryIcon,
                    onPrimaryAction: {
                        if let primary = todayExperience.actions.first(where: \.isPrimary) {
                            performExperienceAction(primary)
                        }
                    },
                    generatedAt: planGeneratedAt,
                    safetyNotice: planSafetyNotice,
                    isStale: isStalePlan
                )

                DataCoverageCompactCard(
                    model: decisionDataCoverageSummary,
                    showSettings: $showSettings
                )

                TodayActionTimeline(
                    model: todayExperience,
                    accent: accentColor,
                    onAction: { performExperienceAction($0) },
                    onEvidenceClick: { showTodayEvidence = true }
                )

                TodayCoachPreview(
                    model: todayExperience,
                    onClick: { VelaAppState.shared.routeToCoach(question: "根据今天的数据，帮我解释训练建议和优先行动。") }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                TodayDateAndStatusHeader(
                    selectedDate: dashboardVM.selectedDate,
                    resolvedActiveStatus: resolvedActiveStatus,
                    activeStatusDuration: activeStatusDuration,
                    todayShareText: todayShareText,
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    showSimulationLabel: dashboard.source == .preview,
                    showCalendarOverview: $showCalendarOverview,
                    showActiveStatus: $showActiveStatus,
                    showSettings: $showSettings,
                    requestWeatherUpdate: { requestWeatherUpdate() }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .background(VelaTheme.bg.opacity(0.98))
                
                Divider()
                    .opacity(0.4)
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
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
        }
        .refreshable {
            await refreshDashboard(force: true)
            await loadDataCoverageSummary()
        }
        .onChange(of: dashboardVM.selectedDate) {
            guard isActiveSurface else { return }
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadDynamicData()
            Task {
                await refreshDashboard()
                withAnimation(VelaTheme.smooth) {
                    animatedEnergyScore = energyScore
                }
            }
        }
        .onChange(of: energyScore) {
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
        }
        .onChange(of: appState.localDataRevision) {
            guard isActiveSurface else { return }
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            loadDynamicData()
        }
        .onChange(of: activeStatusRaw) {
            let dateToRefresh = dashboardVM.selectedDate
            let context = modelContext
            Task {
                await DailyPlanRefreshCoordinator.shared.refreshPlan(for: dateToRefresh, modelContext: context)
            }
        }
        .onChange(of: locationManager.location) {
            fetchLocalWeather()
        }
        .sheet(isPresented: $showCalendarOverview) {
            CalendarOverviewSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showActiveStatus) {
            ActiveStatusSelectionSheetView(
                activeStatusRaw: $activeStatusRaw,
                activeStatusDuration: $activeStatusDuration
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
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
            TodayEvidenceSheet(
                state: todayCommandState,
                dashboard: dashboard,
                onAskCoach: { question in
                    VelaAppState.shared.routeToCoach(question: question)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    func primaryExperienceActionIcon(_ model: TodayExperienceModel) -> String {
        guard let action = model.actions.first(where: \.isPrimary) else { return "arrow.right" }
        switch action.destination {
        case "training": return "play.fill"
        case "sync": return "arrow.triangle.2.circlepath"
        case "recovery": return "heart.fill"
        case "journal": return "square.and.pencil"
        case "coach": return "sparkles"
        default: return "arrow.right"
        }
    }

    func performExperienceAction(_ action: TodayExperienceAction) {
        experienceFeedbackTick += 1
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
    let resolvedActiveStatus: String
    let activeStatusDuration: String
    let todayShareText: String
    let weatherTemp: String
    let weatherStatusText: String
    let showSimulationLabel: Bool
    
    @Binding var showCalendarOverview: Bool
    @Binding var showActiveStatus: Bool
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
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择日期")
                .accessibilityValue(dateHeaderString(for: selectedDate))
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Share button
                    ShareLink(item: todayShareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VelaTheme.muted)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("分享今日摘要")
                    
                    // Profile Avatar
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("个人设置")
                }
            }
            
            // Status & Weather Capsules
            HStack(spacing: 8) {
                // Active status pill
                Button {
                    showActiveStatus = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: statusPillIcon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(statusPillColor)
                        
                        Text(statusPillTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        if resolvedActiveStatus != "active" {
                            Text(activeStatusDuration)
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(VelaTheme.cardBg))
                    .overlay(Capsule().stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("当前状态")
                .accessibilityValue(resolvedActiveStatus == "active"
                    ? statusPillTitle
                    : statusPillTitle + "，" + activeStatusDuration)
                .accessibilityHint("轻点更改状态")
                
                // Weather
                TodayWeatherBar(
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    requestWeatherUpdate: requestWeatherUpdate
                )
                
                Spacer()
                
                if showSimulationLabel {
                    Text(L10n.t("Simulated", "模拟数据"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VelaTheme.accent))
                }
            }
        }
    }
    
    private var statusPillIcon: String {
        switch resolvedActiveStatus {
        case "active": return "figure.run"
        case "sick": return "bed.double.fill"
        case "injured": return "bandage.fill"
        default: return "beach.umbrella.fill"
        }
    }

    private var statusPillColor: Color {
        switch resolvedActiveStatus {
        case "active": return VelaTheme.success
        case "sick": return VelaTheme.warn
        case "injured": return VelaTheme.danger
        default: return VelaTheme.accent
        }
    }

    private var statusPillTitle: String {
        switch resolvedActiveStatus {
        case "active": return L10n.t("Active", "活跃")
        case "sick": return L10n.t("Sick", "生病")
        case "injured": return L10n.t("Injured", "受伤")
        default: return L10n.t("Resting", "休息中")
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
    
    var body: some View {
        let accent = dataCoverageColor(model.status)
        return Button {
            showSettings = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: model.actionSystemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    Text(model.status == .unknown ? "--" : "\(model.scorePercent)%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                }

                HStack(spacing: 8) {
                    ForEach(model.domainSummaries.prefix(3)) { domain in
                        Text("\(domain.title) \(domain.usableCount)/\(domain.totalCount)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(dataCoveragePercentColor(domain.scorePercent))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.t("Data credibility", "数据可信度")) \(model.scorePercent)%")
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
