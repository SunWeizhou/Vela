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
    private var allCoachArtifacts: [CoachArtifactRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var allStrengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var allWorkoutEvents: [WorkoutEventRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var allTrainingResponses: [TrainingResponseRecord]
    @Query(sort: \FoodLogRecord.createdAt, order: .reverse)
    private var allFoodLogs: [FoodLogRecord]
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var allJournalEntries: [JournalEntryRecord]
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse)
    private var allDailySummaries: [DailyHealthSummaryRecord]
    @Query(sort: \TrainingPlanRecord.updatedAt, order: .reverse)
    private var allTrainingPlans: [TrainingPlanRecord]
    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse)
    private var allOperatingPlans: [DailyOperatingPlanRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    /// Lookback window for health-related queries (42 days matches recovery engine baseline)
    private static let healthLookbackDays = 42
    /// Recent window for strength/training queries
    private static let trainingLookbackDays = 30

    private var lookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.healthLookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    private var trainingLookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.trainingLookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    private var coachArtifacts: [CoachArtifactRecord] {
        allCoachArtifacts.filter { $0.createdAt >= trainingLookbackStart }
    }
    private var strengthWorkouts: [StrengthWorkoutRecord] {
        allStrengthWorkouts.filter { $0.startedAt >= trainingLookbackStart }
    }
    private var workoutEvents: [WorkoutEventRecord] {
        allWorkoutEvents.filter { $0.startedAt >= trainingLookbackStart }
    }
    private var trainingResponses: [TrainingResponseRecord] {
        allTrainingResponses.filter { $0.date >= lookbackStart }
    }
    private var foodLogs: [FoodLogRecord] {
        allFoodLogs.filter { $0.createdAt >= lookbackStart }
    }
    private var journalEntries: [JournalEntryRecord] {
        allJournalEntries.filter { $0.createdAt >= lookbackStart }
    }
    private var dailySummaries: [DailyHealthSummaryRecord] {
        allDailySummaries.filter { $0.date >= lookbackStart }
    }
    private var trainingPlans: [TrainingPlanRecord] {
        allTrainingPlans
    }
    private var operatingPlans: [DailyOperatingPlanRecord] {
        allOperatingPlans
    }
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
            activeStatus: ActiveStatusSettings.resolveCurrentStatus(),
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

    // Real scores mapped to 0...1 for BevelScoreRing
    private var strainScore: Double { max(0, min(1.0, dashboard.strain.score / 100.0)) }
    private var recoveryScore: Double { max(0, min(1.0, dashboard.recovery.score / 100.0)) }
    private var sleepScore: Double { max(0, min(1.0, dashboard.sleepScore.score / 100.0)) }

    private var hrvValue: Double { dashboard.recoveryMetrics.hrvMilliseconds ?? 0 }
    private var rhrValue: Double { dashboard.recoveryMetrics.restingHeartRate ?? 0 }

    // Stress & Energy
    private var stressLevel: Double { dashboard.stress.stressIndex }
    private var energyScore: Double { dashboard.energy.currentEnergy }

    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000

    // Dynamic states for nutrition logs
    @State private var todayCalories: Int = 0
    @State private var todayProtein: Int = 0
    @State private var todayCarbs: Int = 0
    @State private var todayFat: Int = 0

    private var calorieFraction: CGFloat {
        CGFloat(min(1.0, Double(todayCalories) / Double(max(dailyCalorieTarget, 1))))
    }

    private var coachMessage: String {
        dashboard.dailyInsight.isEmpty
            ? "正在等待足够的 Apple 健康数据，完成同步后会生成今日指导。"
            : dashboard.dailyInsight
    }

    private var todayShareText: String {
        let recoveryText = dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--"
        let sleepText = dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--"
        let strainText = dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--"
        return "\(dateHeaderString(for: dashboardVM.selectedDate))\n恢复 \(recoveryText) · 睡眠 \(sleepText) · 负荷 \(strainText)\n\(coachMessage)"
    }

    // Dynamic Weather Sync States
    @State private var weatherTemp: String = "--"
    @State private var weatherLocation: String = "天气数据待同步"

    // Active Status Settings Toggles (Replicating Screenshot 2)
    @AppStorage("vela_active_status") private var activeStatusRaw = "active"
    @AppStorage("vela_active_status_duration") private var activeStatusDuration = "明天之前"
    private var resolvedActiveStatus: String {
        ActiveStatusSettings.resolveCurrentStatus()
    }

    // Sheets trigger states
    @State private var showCalendarOverview = false
    @State private var showActiveStatus = false
    @State private var selectedInsightIndex = 0
    @State private var selectedInsight: ProactiveInsight?
    @State private var showTodayEvidence = false
    @State private var animatedEnergyScore: Double = 0.0
    @State private var isVisible = false

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
        case "active": return Color(hex: "#34C759") // Teal green
        case "sick": return Color(hex: "#FF9F0A") // Orange yellow
        case "injured": return Color(hex: "#FF3B30") // Red pink
        default: return Color(hex: "#4285F4") // Blue
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

    @ViewBuilder
    private var errorMessageView: some View {
        if let errorMessage = dashboardVM.errorMessage {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                if let suggestion = dashboardVM.currentError?.recoverySuggestion {
                    Text(suggestion)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Date, Status, and Weather Header
                dateAndStatusHeader
                    .opacity(isVisible ? 1.0 : 0.0)
                    .offset(y: isVisible ? 0.0 : 10.0)
                    .animation(VelaTheme.snappy.delay(0.0), value: isVisible)
 
                errorMessageView

                // 2. Unified Today OS Cockpit Control Center
                todayControlCenterCard
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 10)
                    .animation(VelaTheme.snappy.delay(0.03), value: isVisible)
  
                // 3. Stress & Energy Section (Side-by-Side)
                stressAndEnergySection
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 12)
                    .animation(VelaTheme.snappy.delay(0.06), value: isVisible)
 
                // 4. Daily Activity Section (3-Column Grid)
                dailyActivitySection
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 12)
                    .animation(VelaTheme.snappy.delay(0.09), value: isVisible)
 
                // 5. Nutrition (营养) Section
                nutritionSection
                    .opacity(isVisible ? 1 : 0)
                    .offset(y: isVisible ? 0 : 12)
                    .animation(VelaTheme.snappy.delay(0.12), value: isVisible)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 140) // Floating tab bar safety gap
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            dashboardVM.hydrateFromCache(modelContext: modelContext)
            loadRealNutritionData()
            locationManager.requestPermission()
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
            withAnimation(VelaTheme.snappy) {
                isVisible = true
            }
        }
        .task {
            await refreshDashboard()
            persistDailyOperatingPlan()
            withAnimation(VelaTheme.smooth) {
                animatedEnergyScore = energyScore
            }
        }
        .refreshable {
            await refreshDashboard(force: true)
            persistDailyOperatingPlan()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            dashboardVM.hydrateFromCache(modelContext: modelContext)
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
        }
        .onChange(of: locationManager.location) { _, _ in
            fetchLocalWeather()
        }
        .sheet(isPresented: $showCalendarOverview) {
            CalendarOverviewSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F2F2F7"))
        }
        .sheet(isPresented: $showActiveStatus) {
            ActiveStatusSelectionSheetView(
                activeStatusRaw: $activeStatusRaw,
                activeStatusDuration: $activeStatusDuration
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "#F2F2F7"))
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

    private var todayControlCenterCard: some View {
        let state = bodyState
        let decision = trainingDecision
        let planTitle = persistedOperatingPlan?.title ?? decision.userFacingSummary
        let cause: String
        if let detail = state.drivers.first?.detail {
            cause = localizedDriverDetail(detail)
        } else {
            cause = L10n.t(
                "Local records are available while health baselines are still forming.",
                "健康基线仍在建立，当前先使用本地记录给出保守建议。"
            )
        }
        let watchRaw = state.drivers.first(where: { $0.impact < 0 })?.title
            ?? L10n.t("Training quality and perceived effort", "训练质量与主观用力")
        let watch = localizedDriverTitle(watchRaw)
        let cmdState = todayCommandState
        let accentColor = readinessColor(cmdState.readinessDecision.decision)
        
        return VStack(alignment: .leading, spacing: 16) {
            // Header Row: Readiness & Confidence Info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("TODAY OS", "今日状态决策"))
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(VelaTheme.muted)
                    
                    Text(bodyStateTitle(state.readiness))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(Int((decision.confidence * 100).rounded()))%")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                    
                    Text("\(localizedDataConfidence(state.confidence)) · \(localizedDataFreshness(state.freshness))")
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            
            // Core Rings (Strain, Recovery, Sleep) Side-by-Side inside the OS Card
            HStack(alignment: .center, spacing: 0) {
                // Strain (耗力)
                NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                    BevelScoreRing(
                        score: strainScore,
                        color: VelaTheme.strainColor,
                        useGradient: false,
                        size: 64,
                        label: "耗力",
                        valueText: dashboard.strain.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.strain.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(VelaTheme.borderSoft)
                    .frame(width: 0.5, height: 48)

                // Recovery (恢复)
                NavigationLink(destination: VelaMetricDetailView(metric: .recovery)) {
                    BevelScoreRing(
                        score: recoveryScore,
                        color: VelaTheme.recoveryColor,
                        useGradient: true,
                        size: 64,
                        label: "恢复",
                        valueText: dashboard.recovery.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.recovery.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(VelaTheme.borderSoft)
                    .frame(width: 0.5, height: 48)

                // Sleep (睡眠)
                NavigationLink(destination: VelaMetricDetailView(metric: .sleep)) {
                    BevelScoreRing(
                        score: sleepScore,
                        color: VelaTheme.sleepColor,
                        useGradient: true,
                        size: 64,
                        label: "睡眠",
                        valueText: dashboard.sleepScore.hasData ? VelaMinimalFormatting.roundedPercentage(dashboard.sleepScore.score) : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(VelaTheme.elevatedBg.opacity(0.4))
            )
            
            Divider()
            
            // Reasons & Decisions Rows
            VStack(alignment: .leading, spacing: 10) {
                todayOSRow(label: "原因", value: cause)
                todayOSRow(label: "计划", value: planTitle)
                todayOSRow(label: "观察", value: watch)
            }
            
            // Primary Action Button
            Button {
                if decision.decision == .rest {
                    showTodayEvidence = true
                } else {
                    appState.routeToTab(1)
                }
            } label: {
                HStack {
                    Image(systemName: decision.decision == .rest ? "heart.fill" : "figure.strengthtraining.traditional")
                    Text(primaryActionTitle(decision.decision))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(accentColor))
            }
            .buttonStyle(.plain)
            
            // Quick logging pills (from commandCenter)
            if let artifact = cmdState.coachArtifact, !artifact.actions.isEmpty {
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
            } else if !cmdState.actions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(cmdState.actions.prefix(3)) { action in
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
            
            HStack {
                Text("\(persistedOperatingPlan?.source ?? decision.source) · \(decision.safetyNotice)")
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.muted)
                Spacer()
                Button {
                    showTodayEvidence = true
                } label: {
                    HStack(spacing: 3) {
                        Text("查看决策依据")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(VelaTheme.accent)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(VelaTheme.cardBg)
                .shadow(color: VelaTheme.cardShadow(cs), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
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

    // MARK: - Date, Status & Weather Header
    private var dateAndStatusHeader: some View {
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
                
                // Weather status pill
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.multicolor)
                    
                    Text(weatherTemp)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    
                    Text(weatherLocation)
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(VelaTheme.cardBg))
                .overlay(Capsule().stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                
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

    private func persistDailyOperatingPlan() {
        _ = try? DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: trainingDecision,
            modelContext: modelContext
        )
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
            appState.routeToTab(1)
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
            appState.routeToTab(1)
        case "start_check_in":
            appState.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        case "open_recovery_detail":
            appState.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        default:
            if action.type.contains("training") || action.type.contains("workout") {
                appState.routeToTab(1)
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

    // MARK: - Stress & Energy Section
    private var stressAndEnergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("VITALS", "压力与能量"))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(VelaTheme.muted)
                .padding(.leading, 2)
            
            HStack(spacing: 12) {
                // Left Card: Energy Bank
                NavigationLink(destination: VelaMetricDetailView(metric: .energy)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.energyColor)
                                
                                Text("能量银行")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        
                        HStack(alignment: .bottom) {
                            Text(dashboard.energy.hasData ? "\(Int(energyScore))%" : "--")
                                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(VelaTheme.energyColor)
                            Spacer()
                            
                            // A mini horizontal battery block or gauge
                            HStack(spacing: 1) {
                                ForEach(0..<15, id: \.self) { idx in
                                    let threshold = Double(idx) / 15.0 * 100.0
                                    RoundedRectangle(cornerRadius: 1.0)
                                        .fill(energyScore >= threshold ? VelaTheme.energyColor : VelaTheme.borderSoft)
                                        .frame(width: 2.2, height: 12)
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(VelaTheme.cardBg)
                            .shadow(color: VelaTheme.cardShadow(cs), radius: 8, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                
                // Right Card: Stress Level
                NavigationLink(destination: VelaMetricDetailView(metric: .stress)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "gauge.with.needle.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.stressColor)
                                
                                Text("压力指数")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        
                        HStack(alignment: .bottom) {
                            Text(dashboard.stress.hasData ? "\(Int(stressLevel.rounded()))" : "--")
                                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                                .foregroundStyle(VelaTheme.stressColor)
                            Spacer()
                            
                            if dashboard.stress.hasData {
                                let baseData = [0.15, 0.22, 0.35, 0.30, 0.42, 0.38, 0.50, 0.38, 0.30, 0.25]
                                let factor = max(0.1, min(1.8, stressLevel / 50.0))
                                let stressHistory = baseData.map { max(0.01, min(0.99, $0 * factor)) }
                                SparklineLineGraph(data: stressHistory, color: VelaTheme.stressColor, height: 16, width: 50)
                                    .padding(.bottom, 2)
                            } else {
                                Text("无数据")
                                    .font(.system(size: 10))
                                    .foregroundStyle(VelaTheme.muted)
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(VelaTheme.cardBg)
                            .shadow(color: VelaTheme.cardShadow(cs), radius: 8, y: 3)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Daily Activity Section
    private var dailyActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("DAILY ACTIVITY", "日常活动"))
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(VelaTheme.muted)
                .padding(.leading, 2)
            
            HStack(spacing: 8) {
                // Column 1: Steps
                NavigationLink(destination: VelaMetricDetailView(metric: .steps)) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(dailyActivityColor(for: .steps).opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: dailyActivityIcon(for: .steps))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(dailyActivityColor(for: .steps))
                            )
                        
                        VStack(spacing: 2) {
                            Text(dailyActivityValue(for: .steps))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("步数")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                
                // Column 2: Calories
                NavigationLink(destination: VelaMetricDetailView(metric: .activeCalories)) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(dailyActivityColor(for: .activeCalories).opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: dailyActivityIcon(for: .activeCalories))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(dailyActivityColor(for: .activeCalories))
                            )
                        
                        VStack(spacing: 2) {
                            Text(dailyActivityValue(for: .activeCalories))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("千卡")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                
                // Column 3: Active Minutes
                NavigationLink(destination: VelaMetricDetailView(metric: .activeMinutes)) {
                    VStack(spacing: 8) {
                        Circle()
                            .fill(dailyActivityColor(for: .activeMinutes).opacity(0.12))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: dailyActivityIcon(for: .activeMinutes))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(dailyActivityColor(for: .activeMinutes))
                            )
                        
                        VStack(spacing: 2) {
                            Text(dailyActivityValue(for: .activeMinutes))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("分钟")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
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
            return metrics["steps_raw"].map { "\(Int($0.rounded()))" } ?? "--"
        case .activeCalories:
            return metrics["active_energy_raw"].map { "\(Int($0.rounded()))" } ?? "--"
        case .activeMinutes:
            return metrics["exercise_minutes_raw"].map { "\(Int($0.rounded()))" } ?? "--"
        default:
            return "--"
        }
    }

    // MARK: - Nutrition (营养) Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("NUTRITION", "今日膳食营养"))
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
                        Text(L10n.t("Kcal Intake / Target \(dailyCalorieTarget)", "卡路里已摄入 / 目标 \(dailyCalorieTarget)"))
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
                    macroIndicator(title: L10n.t("Protein", "蛋白质"), target: "90g", current: "\(todayProtein)g", color: Color(hex: "#FF7043"))
                    Spacer()
                    macroIndicator(title: L10n.t("Carbs", "碳水"), target: "220g", current: "\(todayCarbs)g", color: Color(hex: "#FFB74D"))
                    Spacer()
                    macroIndicator(title: L10n.t("Fat", "脂肪"), target: "65g", current: "\(todayFat)g", color: Color(hex: "#42A5F5"))
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
                            Text(localizedReason(reason))
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
