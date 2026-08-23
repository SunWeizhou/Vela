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
    /// The only typed daily decision shown by Today. During the short cache/load
    /// gap, prefer an explicit conservative state over running a second kernel.
    var canonicalTrainingDecision: DailyTrainingDecision {
        dashboardVM.dailyTrainingDecision
            ?? TrainingDecisionFallback.conservative(targetSessionTitle: nil)
    }
    var persistedOperatingPlan: DailyOperatingPlanRecord? { dashboardVM.persistedOperatingPlan }
    var latestTodayArtifact: CoachArtifact? { dashboardVM.latestTodayArtifact }
    
    var todayCommandState: TodayCommandState {
        // The loading fallback is a projection of an explicit conservative value;
        // it never recomputes a competing decision inside the surface Adapter.
        dashboardVM.todayCommandState ?? TodayCommandBuilder.build(
            from: dashboard,
            generatedAt: dashboardVM.selectedDate,
            trainingDecision: canonicalTrainingDecision
        )
    }

    // 深度专项批次 4（管线 A）：晨报附带生成的「AI 今日解读」。
    // #Predicate 宏要求字面量，不能引用 ReportGenerator.dailyInsightReportType。
    @Query(
        filter: #Predicate<AIReportRecord> { $0.type == "daily_ai_insight" },
        sort: \AIReportRecord.createdAt,
        order: .reverse
    )
    private var dailyAIInsights: [AIReportRecord]

    private var todayAIInsight: DailyAIInsight? {
        guard let record = dailyAIInsights.first(where: { Calendar.current.isDateInToday($0.createdAt) }) else {
            return nil
        }
        guard let data = record.serializedContextSnapshot.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DailyAIInsight.self, from: data)
    }

    var todayExperience: TodayExperienceModel {
        dashboardVM.todayExperience ?? makeTodayExperience()
    }

    private var primarySignalCards: [TodayExperienceSignalCard] {
        let ids: [String] = switch todayCommandState.readinessDecision.decision {
        case .keep: ["recovery", "sleep", "energy"]
        case .reduce: ["recovery", "strain", "sleep"]
        case .swap: ["strain", "recovery", "stress"]
        case .recover: ["recovery", "sleep", "stress"]
        }
        return ids.compactMap { id in
            todayExperience.signalCards.first(where: { $0.id == id })
        }
    }

    func makeTodayExperience() -> TodayExperienceModel {
        return TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: canonicalTrainingDecision,
            generatedAt: dashboardVM.selectedDate,
            nutrition: TodayExperienceNutrition(
                calories: todayCalories,
                calorieTarget: dailyCalorieTarget,
                protein: todayProtein,
                carbs: todayCarbs,
                fat: todayFat
            ),
            operatingPlan: persistedOperatingPlan?.operatingPlanPayload
        )
    }

    /// 深度专项批次 4（管线 A）：AI 今日解读卡——本机结论永远优先；
    /// 冲突时整卡降级为灰色参考并标注「以本机今日决定为准」（ADR 0008）。
    private func aiInsightCard(_ insight: DailyAIInsight) -> some View {
        let conflicted = insight.conflictsWithLocal
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        conflicted
                            ? VelaTheme.rhythmInkSecondary
                            : VelaTheme.rhythmDeep
                    )
                Text("AI 增强 · 今日解读")
                    .font(.system(.caption, design: .default, weight: .bold))
                    .foregroundStyle(conflicted ? VelaTheme.rhythmInkSecondary : VelaTheme.rhythmDeep)
                Spacer()
            }

            Text(insight.interpretation)
                .font(.system(.footnote, design: .default, weight: .regular))
                .foregroundStyle(conflicted ? VelaTheme.rhythmInkSecondary.opacity(0.8) : VelaTheme.rhythmInk)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if conflicted {
                Label("AI 与本机判断不一致，以本机今日决定为准", systemImage: "exclamationmark.triangle")
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(VelaTheme.stressColor)
            } else if !insight.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(insight.evidence.prefix(3), id: \.self) { line in
                        HStack(alignment: .top, spacing: 7) {
                            Circle()
                                .fill(VelaTheme.rhythmDeep.opacity(0.7))
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(line)
                                .font(.system(.caption, design: .default))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(VelaTheme.rhythmDeep.opacity(0.35), lineWidth: 1.0)
        }
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
        let updatedDate = dashboardVM.lastUpdated

        return [
            TodayVitalCardModel(
                kind: .hrv, label: "心率变异性",
                value: hrv.map { "\(Int($0.rounded()))" } ?? "--", unit: "ms",
                status: vitalStatusText(hasData: hrv != nil, lastUpdated: updatedDate), isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .rhr, label: "静息心率",
                value: rhr.map { "\(Int($0.rounded()))" } ?? "--", unit: "bpm",
                status: vitalStatusText(hasData: rhr != nil, lastUpdated: updatedDate), isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .spo2, label: "血氧",
                value: spo2.map { "\(Int($0.rounded()))" } ?? "--", unit: "%",
                status: vitalStatusText(hasData: spo2 != nil, lastUpdated: updatedDate), isGood: true, trend: []
            ),
            TodayVitalCardModel(
                kind: .sleep, label: "睡眠",
                value: sleepMin > 0 ? "\(sleepMin / 60):\(String(format: "%02d", sleepMin % 60))" : "--", unit: "时",
                status: vitalStatusText(hasData: sleepMin > 0, lastUpdated: updatedDate), isGood: true, trend: []
            )
        ]
    }

    private func vitalStatusText(hasData: Bool, lastUpdated: Date?) -> String {
        guard hasData else { return "待同步" }
        guard let lastUpdated else { return "已同步" }
        let now = Date()
        let interval = now.timeIntervalSince(lastUpdated)

        if interval < 60 && interval >= 0 {
            return "刚刚同步"
        } else if interval < 3600 && interval >= 60 {
            let mins = Int(interval / 60)
            return "\(mins)分钟前同步"
        }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")

        if calendar.isDateInToday(lastUpdated) {
            formatter.dateFormat = "HH:mm"
            return "\(formatter.string(from: lastUpdated)) 同步"
        } else if calendar.isDateInYesterday(lastUpdated) {
            formatter.dateFormat = "HH:mm"
            return "昨天 \(formatter.string(from: lastUpdated))"
        } else {
            return "已同步"
        }
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

    private func signalAccentColor(_ accent: DailyPlanAccent) -> Color {
        switch accent {
        case .recovery: return VelaTheme.recoveryColor
        case .sleep:    return VelaTheme.sleepColor
        case .strain:   return VelaTheme.strainColor
        case .stress:   return VelaTheme.stressColor
        case .energy:   return VelaTheme.energyColor
        }
    }

    @ViewBuilder
    private var notableChangeCard: some View {
        if let notable = dashboard.personalHealthBrief?.notableChanges.first {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("最值得关注的变化")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Spacer()
                    Button {
                        appState.routeToTrends()
                    } label: {
                        HStack(spacing: 2) {
                            Text("查看趋势")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(.caption2, design: .default, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }

                Text(notable.summary)
                    .font(.system(.footnote, design: .default, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .lineSpacing(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            )
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 16)
        }
    }

    @ViewBuilder
    private var velaInterpretationSection: some View {
        if let insight = todayAIInsight {
            aiInsightCard(insight)
        } else if let brief = dashboard.personalHealthBrief, !brief.subheadline.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text("Vela 解读")
                        .font(.system(.caption, design: .default, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Spacer()
                }

                Text(brief.subheadline)
                    .font(.system(.footnote, design: .default, weight: .regular))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .lineSpacing(3)

                if let insightLine = dashboard.bodyModelState?.insightLine() {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(VelaTheme.rhythmDeep.opacity(0.7))
                            .frame(width: 4, height: 4)
                        Text(insightLine)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            )
        } else {
            personalResponseInsightView
        }
    }

    @ViewBuilder
    private var personalResponseInsightView: some View {
        if dashboardVM.isToday, let insightLine = dashboard.bodyModelState?.insightLine() {
            NavigationLink(destination: BodyModelDetailView()) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text(insightLine)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
                }
                .padding(12)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }
            }
            .buttonStyle(.cardPress)
        }
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

    // Sheets trigger states
    @State var showCalendarOverview = false
    @State var selectedInsightIndex = 0
    @State var selectedInsight: ProactiveInsight?
    @State var showTodayEvidence = false
    @State var showLivedStateCheckIn = false
    @State var showMetricDetail: VelaMetricDetailView.MetricType?
        @State var experienceFeedbackTick = 0
    @State var dataCoverageSummary = DataCoverageSummaryModel.unknown
    @State var dailyDecisionFeedback: DailyDecisionFeedbackRecord?
    @State var showDailyDecisionFeedback = false
    @State private var lastScenePhaseSyncTime: Date?
    // F2 修复：档案修改发生在非 Today 页面时记一笔，回到 Today 立即强制重算。
    @State private var pendingLocalDataRefresh = false

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
                        .foregroundStyle(VelaTheme.stressColor)
                    Text(errorMessage)
                        .font(.system(.footnote, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                }
                if let suggestion = dashboardVM.currentError?.recoverySuggestion {
                    Text(suggestion)
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VelaTheme.stressColor.opacity(0.3), lineWidth: 1)
            )
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if dashboardVM.errorMessage != nil {
                    errorMessageView
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.bottom, 8)
                }

                // ─── Block 1: Integrated Rhythm Horizon Hero (Tri-Dials + Headline + CTA + Curve) ───
                VelaRhythmHorizonHero(
                    model: todayExperience,
                    state: todayCommandState,
                    selectedDate: dashboardVM.selectedDate,
                    isToday: dashboardVM.isToday,
                    restingHeartRate: dashboardVM.dashboard.recoveryMetrics.restingHeartRate,
                    maxHeartRate: DailyHealthComputationProfile.current(
                        ageFallback: dashboardVM.dashboard.extendedMetrics.age
                    ).maxHeartRate,
                    onOpenPlan: { showTodayEvidence = true },
                    onAskCoach: { showCoach = true }
                )
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 4)

                if dashboardVM.isToday {
                    livedStatePrompt
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.top, 12)

                    TodayTrainingPlanAdaptationCard()
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.top, 12)
                }

                // ─── Block 2: Today's Most Notable Change (if present) ───
                notableChangeCard

                // ─── Block 3: Key Vital Stats (HRV / RHR / SpO₂ / Sleep 2×2 Grid) ───
                VStack(alignment: .leading, spacing: 10) {
                    Text("关键体征")
                        .font(VelaTheme.headline())
                        .foregroundStyle(VelaTheme.rhythmInk)
                    TodayVitalsGrid(cards: vitalCards) { kind in
                        switch kind {
                        case .hrv:   showMetricDetail = .hrv
                        case .rhr:   showMetricDetail = .rhr
                        case .spo2:  showMetricDetail = .bloodOxygen
                        case .sleep: showMetricDetail = .sleep
                        }
                    }
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 24) {
                    // ─── Block 4: Vela Interpretation (Unified AI & Response Brief) ───
                    velaInterpretationSection

                    // ─── Block 5: Downstream Action Sequence (建议行动) ───
                    if !todayExperience.actions.isEmpty {
                        VelaRhythmActionSequence(
                            actions: todayExperience.actions,
                            onAction: { performExperienceAction($0) },
                            onEvidence: { showTodayEvidence = true }
                        )
                    }

                    // ─── Block 6: Stress & Energy Gauge Cards ───
                    TodaySignalGrid(
                        model: todayExperience,
                        freshness: dataCoverageSummary.status == .unknown ? .missing : .today,
                        accentColor: signalAccentColor
                    )

                    // ─── Block 7: Feedback + Data Coverage ───
                    if persistedOperatingPlan != nil {
                        DailyDecisionFeedbackCard(
                            record: dailyDecisionFeedback,
                            onTap: { showDailyDecisionFeedback = true }
                        )
                    }

                    DataCoverageCompactCard(
                        model: decisionDataCoverageSummary,
                        showSettings: $showSettings
                    )
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 24)
                .padding(.bottom, VelaTheme.bottomContentClearance)
            }
        }
        .scrollIndicators(.hidden)
        .simultaneousGesture(
            DragGesture(minimumDistance: 28)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
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
                    requestWeatherUpdate: { requestWeatherUpdate() },
                    settingsSynced: dashboardVM.lastUpdated != nil
                )
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.bottom, 6)
                .background(VelaTheme.rhythmCanvas.opacity(0.94))
            }
        }
        .background(VelaTheme.rhythmCanvas)
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            await dashboardVM.hydrateFromCache(modelContext: modelContext)
            locationManager.startUpdating()
            if pendingLocalDataRefresh {
                pendingLocalDataRefresh = false
                await refreshDashboard(force: true)
            } else {
                await refreshDashboard()
            }
            await loadDataCoverageSummary()
            trackDailyDecisionViewed()
            withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
            }
        }
        .refreshable {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            await refreshDashboard(force: true)
            await loadDataCoverageSummary()
        }
        .onChange(of: scenePhase) {
            // Returning to foreground (e.g. after being backgrounded overnight) re-syncs
            // HealthKit and recomputes scores when data is stale. Use force: false so
            // HealthCachePolicy (15-min TTL) prevents redundant 42-day historical sync loops.
            // Introduce a scenePhase freshness check (debounce window) to prevent rapid app toggling
            // from executing redundant refreshes.
            if scenePhase == .active, isActiveSurface {
                let now = Date()
                if let lastSync = lastScenePhaseSyncTime,
                   now.timeIntervalSince(lastSync) < 60 {
                    return
                }
                lastScenePhaseSyncTime = now
                Task {
                    await refreshDashboard(force: false)
                    await loadDataCoverageSummary()
                }
            }
        }
        .onChange(of: dashboardVM.selectedDate) {
            guard isActiveSurface else { return }
            Task { await dashboardVM.hydrateFromCache(modelContext: modelContext) }
            loadDynamicData()
            Task {
                await refreshDashboard()
                withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
                    }
            }
        }
        .onChange(of: energyScore) {
            withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
            }
        }
        .onChange(of: appState.localDataRevision) {
            // F2 修复：档案（年龄/体重/身高/maxHR/性别）修改后必须重算评分，
            // 此前只 hydrateFromCache，15 分钟内分数与建议停留在旧档案口径。
            if isActiveSurface {
                Task { await refreshDashboard(force: true) }
            } else {
                pendingLocalDataRefresh = true
            }
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
        .sheet(item: $showMetricDetail) { metric in
            NavigationStack {
                VelaMetricDetailView(metric: metric)
            }
            .environmentObject(dashboardVM)
            .presentationDetents([.large])
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
        .sheet(isPresented: $showLivedStateCheckIn) {
            LivedStateCheckInSheet {
                appState.markLocalDataChanged()
            }
            .presentationDetents([.large])
            .velaSheetSurface()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    func performExperienceAction(_ action: TodayExperienceAction) {
        experienceFeedbackTick += 1
        trackDailyDecisionAction(destination: action.destination)
        switch action.destination {
        case "training":
            appState.routeToTraining()
        case "journal":
            showLivedStateCheckIn = true
        case "coach":
            VelaAppState.shared.routeToCoach(question: action.detail)
        case "recovery", "sync", "evidence":
            showTodayEvidence = true
        default:
            showTodayEvidence = true
        }
    }

    private var livedStatePrompt: some View {
        Button {
            VelaHaptic.selection()
            showLivedStateCheckIn = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(width: 36, height: 36)
                    .background(VelaTheme.rhythmMist.opacity(0.72), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("你现在感觉如何？")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text("10 秒校准压力、精力、酸痛与训练动力")
                        .font(.footnote)
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text("快速自评")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .background(VelaTheme.rhythmMist.opacity(0.34), in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel("快速自评当前状态")
        .accessibilityHint("记录压力、精力、酸痛与训练动力，并刷新今天的建议")
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
            // 反馈保存后立即回灌：按同类决策的历史准确率重校准今日置信度。
            dashboardVM.applyFeedbackCalibration(modelContext: modelContext)
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
    let settingsSynced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    showCalendarOverview = true
                } label: {
                    HStack(spacing: 5) {
                        Text(dateHeaderString(for: selectedDate))
                            .font(.system(.body, design: .default, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
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

                HStack(spacing: 2) {
                    ShareLink(item: todayShareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel("分享今日摘要")

                    Button {
                        showSettings = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(VelaTheme.rhythmMist)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(VelaTheme.rhythmDeep)
                                }
                            Circle()
                                .fill(VelaTheme.rhythmGlow)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(VelaTheme.rhythmCanvas, lineWidth: 2))
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel(settingsSynced ? "个人设置,数据已同步" : "个人设置,数据待同步")
                }
            }

            if showSimulationLabel {
                HStack {
                    Text(L10n.t("Simulated", "模拟数据"))
                        .font(.system(.caption2, design: .default, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
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

// MARK: - Lived State Check-in

/// A 10-second subjective calibration. It writes through the existing journal
/// Adapter, then Today refreshes the shared Daily Intelligence Module.
struct LivedStateCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var onSaved: () -> Void

    @State private var stress = 1
    @State private var energy = 1
    @State private var soreness = 0
    @State private var motivation = 1
    @State private var note = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("让客观数据听见你的感受")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("主观状态只会让建议更保守，不会覆盖 Apple 健康数据。保存后会立即刷新今日 Brief 与训练边界。")
                            .font(.body)
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 20) {
                        ratingRow(
                            title: "压力",
                            detail: "此刻的心理与生活压力",
                            labels: ["低", "适中", "高"],
                            selection: $stress
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "精力",
                            detail: "现在的清醒度与身体能量",
                            labels: ["低", "稳定", "充足"],
                            selection: $energy
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "酸痛",
                            detail: "肌肉或关节的主观不适",
                            labels: ["无", "轻微", "明显"],
                            selection: $soreness
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "训练动力",
                            detail: "今天投入训练的意愿",
                            labels: ["低", "稳定", "强"],
                            selection: $motivation
                        )
                    }
                    .padding(18)
                    .velaNativeCard(radius: VelaTheme.radiusCardLarge)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充说明（可选）")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        TextField("例如：左肩有刺痛，昨晚临时加班", text: $note, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(
                                VelaTheme.rhythmCanvasRaised,
                                in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                            }
                    }
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(VelaTheme.rhythmCanvas)
            .navigationTitle("校准今日状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Text("保存并刷新今日建议")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            VelaTheme.rhythmDeep,
                            in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                        )
                }
                .buttonStyle(.cardPress)
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .alert("无法保存自评", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "请稍后重试。")
        }
    }

    private func ratingRow(
        title: String,
        detail: String,
        labels: [String],
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            Picker(title, selection: selection) {
                ForEach(labels.indices, id: \.self) { index in
                    Text(labels[index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(title)
        }
    }

    private func save() {
        let checkIn = LivedStateCheckIn(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation,
            note: note
        )
        modelContext.insert(JournalEntryRecord(
            createdAt: Date(),
            tags: checkIn.journalTags,
            note: checkIn.journalNote,
            value: 1 - checkIn.conservativeSeverity,
            unit: "lived_state_0_1"
        ))
        do {
            try modelContext.save()
            VelaHaptic.success()
            onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
