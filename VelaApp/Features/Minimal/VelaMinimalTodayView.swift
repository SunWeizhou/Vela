import SwiftUI
import SwiftData
import CoreLocation

// MARK: - VelaTodayView — Bevel Replica Today Tab
// Warm off-white background (#F2F2F7) × Premium White Cockpit cards with precise shadows

struct VelaTodayView: View {
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var cs
    @Environment(\.velaScrollDirection) var scrollDirection
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @ObservedObject var appState = VelaAppState.shared
    @ObservedObject var locationManager = LocationManager.shared
    
    @State var coachArtifacts: [CoachArtifactRecord] = []
    @State var strengthWorkouts: [StrengthWorkoutRecord] = []
    @State var workoutEvents: [WorkoutEventRecord] = []
    @State var trainingResponses: [TrainingResponseRecord] = []
    @State var foodLogs: [FoodLogRecord] = []
    @State var journalEntries: [JournalEntryRecord] = []
    @State var dailySummaries: [DailyHealthSummaryRecord] = []
    @State var trainingPlans: [TrainingPlanRecord] = []
    @State var operatingPlans: [DailyOperatingPlanRecord] = []

    var dashboard: DashboardSummary { dashboardVM.dashboard }

    /// Lookback window for health-related queries (42 days matches recovery engine baseline)
    static let healthLookbackDays = 42
    /// Recent window for strength/training queries
    static let trainingLookbackDays = 30

    var lookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.healthLookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    var trainingLookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.trainingLookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }
    
    var recentStrengthSummary: RecentTrainingSummary {
        TrainingAnalyticsService().buildRecentSummary(
            workouts: strengthWorkouts,
            days: 7,
            endingAt: dashboardVM.selectedDate
        )
    }
    
    var activePlan: TrainingPlanRecord? {
        trainingPlans.first(where: \.isActive)
    }
    
    var bodyState: BodyState {
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
            activeStatus: ActiveStatusSettings.resolveCurrentStatus(),
            generatedAt: Date()
        ))
    }
    
    var trainingDecision: DailyTrainingDecision {
        TrainingDecisionKernel().decide(input: TrainingDecisionInput(
            bodyState: bodyState,
            activePlan: activePlan,
            recentStrengthSummary: recentStrengthSummary,
            trainingResponses: trainingResponses
        ))
    }
    
    var persistedOperatingPlan: DailyOperatingPlanRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        return operatingPlans.first(where: { $0.dayIdentifier == identifier })
    }
    
    var latestTodayArtifact: CoachArtifact? {
        coachArtifacts
            .map(\.artifact)
            .first { artifact in
                guard let relatedDate = artifact.relatedDate else { return true }
                return Calendar.current.isDate(relatedDate, inSameDayAs: dashboardVM.selectedDate)
            }
    }
    
    var todayCommandState: TodayCommandState {
        TodayCommandBuilder.build(
            from: dashboard,
            recentStrengthSummary: recentStrengthSummary,
            coachArtifact: latestTodayArtifact,
            generatedAt: Date()
        )
    }
    
    var todayExperience: TodayExperienceModel {
        TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: trainingDecision,
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

    var hrvValue: Double { dashboard.recoveryMetrics.hrvMilliseconds ?? 0 }
    var rhrValue: Double { dashboard.recoveryMetrics.restingHeartRate ?? 0 }

    // Stress & Energy
    var stressLevel: Double { dashboard.stress.stressIndex }
    var energyScore: Double { dashboard.energy.currentEnergy }

    @AppStorage("vela_daily_calorie_target") var dailyCalorieTarget = 2000

    // Dynamic states for nutrition logs
    @State var todayCalories: Int = 0
    @State var todayProtein: Int = 0
    @State var todayCarbs: Int = 0
    @State var todayFat: Int = 0

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
    @State var isVisible = false
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
        case "active": return Color(hex: "#34C759") // Teal green
        case "sick": return Color(hex: "#FF9F0A") // Orange yellow
        case "injured": return Color(hex: "#FF3B30") // Red pink
        default: return Color(hex: "#4285F4") // Blue
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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                errorMessageView

                TodayHeroCard(
                    model: todayExperience,
                    recoveryScoreText: dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--",
                    accent: decisionAccent(trainingDecision.decision),
                    primaryActionIcon: primaryExperienceActionIcon(todayExperience),
                    onPrimaryAction: {
                        if let primary = todayExperience.actions.first(where: \.isPrimary) {
                            performExperienceAction(primary)
                        }
                    }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)
                .animation(VelaTheme.snappy.delay(0.03), value: isVisible)

                dataCoverageCompactCard(decisionDataCoverageSummary)
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 12)
                    .animation(VelaTheme.snappy.delay(0.05), value: isVisible)

                TodaySignalGrid(
                    model: todayExperience,
                    freshness: bodyState.freshness,
                    accentColor: { accentColor($0) }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
                .animation(VelaTheme.snappy.delay(0.08), value: isVisible)

                TodayActionTimeline(
                    model: todayExperience,
                    accent: decisionAccent(trainingDecision.decision),
                    onAction: { performExperienceAction($0) },
                    onEvidenceClick: { showTodayEvidence = true }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
                .animation(VelaTheme.snappy.delay(0.11), value: isVisible)

                TodayNutritionStrip(
                    nutrition: todayExperience.nutrition,
                    onAddClick: { VelaAppState.shared.triggerFoodSearch = true }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
                .animation(VelaTheme.snappy.delay(0.14), value: isVisible)

                TodayCoachPreview(
                    model: todayExperience,
                    onClick: { VelaAppState.shared.routeToCoach(question: "根据今天的数据，帮我解释训练建议和优先行动。") }
                )
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 12)
                .animation(VelaTheme.snappy.delay(0.17), value: isVisible)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                dateAndStatusHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                
                Divider()
                    .opacity(0.4)
            }
            .opacity(isVisible ? 1.0 : 0.0)
            .offset(y: isVisible ? 0.0 : -10.0)
            .animation(VelaTheme.snappy.delay(0.0), value: isVisible)
        }
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            loadDynamicData()
            locationManager.startUpdating()
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
            withAnimation(VelaTheme.snappy) {
                isVisible = true
            }
        }
        .task {
            await refreshDashboard()
            await loadDataCoverageSummary()
            persistDailyOperatingPlan()
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
        }
        .refreshable {
            await refreshDashboard(force: true)
            await loadDataCoverageSummary()
            persistDailyOperatingPlan()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadDynamicData()
            Task {
                await refreshDashboard()
                persistDailyOperatingPlan()
                withAnimation(VelaTheme.smooth) {
                    animatedEnergyScore = energyScore
                }
            }
        }
        .onChange(of: energyScore) { _, newEnergy in
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = newEnergy
            }
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            loadDynamicData()
        }
        .onChange(of: locationManager.location) { _, _ in
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

    func dataCoverageCompactCard(_ model: DataCoverageSummaryModel) -> some View {
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
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(accent.opacity(0.16), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("数据可信度 \(model.scorePercent)%")
    }

    func dataCoverageDomainChip(_ domain: DataCoverageDomainSummary) -> some View {
        let accent = dataCoveragePercentColor(domain.scorePercent)
        return AppSegmentChip(accent: accent, domain: domain)
    }

    func macroBadge(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
            Text("\(value)g")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(color.opacity(0.10)))
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

    func decisionAccent(_ decision: DailyTrainingDecisionType) -> Color {
        VelaTheme.accent
    }

    func dataCoverageColor(_ status: DataCoverageSummaryModel.Status) -> Color {
        switch status {
        case .high: return VelaTheme.energyColor
        case .moderate: return VelaTheme.accent
        case .low: return VelaTheme.strainColor
        case .unknown: return VelaTheme.muted
        }
    }

    func dataCoveragePercentColor(_ percent: Int) -> Color {
        if percent >= 80 { return VelaTheme.energyColor }
        if percent >= 50 { return VelaTheme.accent }
        return VelaTheme.strainColor
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

    // MARK: - Date, Status & Weather Header
    var dateAndStatusHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date Row
            HStack(alignment: .center) {
                Button {
                    showCalendarOverview = true
                } label: {
                    HStack(spacing: 6) {
                        Text(dateHeaderString(for: dashboardVM.selectedDate))
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Share button
                    ShareLink(item: todayShareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VelaTheme.muted)
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
                            .frame(width: 32, height: 32)
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .buttonStyle(.plain)
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
                        
                        Text(activeStatusDuration)
                            .font(.system(size: 10))
                            .foregroundStyle(VelaTheme.muted)
                        
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
                
                // Weather only requests location after an explicit user action.
                TodayWeatherBar(
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    requestWeatherUpdate: { requestWeatherUpdate() }
                )
                
                Spacer()
                
                if dashboard.source == .preview {
                    Text("模拟数据")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VelaTheme.accent))
                }
            }
        }
    }
}

// MARK: - Internal segment chip UI helper
struct AppSegmentChip: View {
    let accent: Color
    let domain: DataCoverageDomainSummary
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: domain.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(accent)
            Text(domain.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text("\(domain.usableCount)/\(domain.totalCount)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(accent.opacity(0.09))
        )
    }
}
