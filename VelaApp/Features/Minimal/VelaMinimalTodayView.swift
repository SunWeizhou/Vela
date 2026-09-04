import SwiftUI
import CoreLocation

// MARK: - VelaTodayView — evidence-first daily decision surface

struct VelaTodayView: View {
    enum TodaySheet: Identifiable {
        case calendar
        case metric(VelaMetricDetailView.MetricType)
        case evidence
        case feedback
        case livedState

        var id: String {
            switch self {
            case .calendar: return "calendar"
            case .metric(let metric): return "metric-\(metric.id)"
            case .evidence: return "evidence"
            case .feedback: return "feedback"
            case .livedState: return "lived-state"
            }
        }
    }

    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var cs
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices
    @ObservedObject var appState = VelaAppState.shared
    @ObservedObject var locationManager = LocationManager.shared

    /// The reader is bound to the composition-root objects when the surface
    /// becomes active. Keeping the reader stable lets TodayStore coalesce
    /// lifecycle-triggered loads while the legacy VM remains the renderer's
    /// compatibility projection.
    private let legacyTodayReader: LegacyTodayReadingModule
    @StateObject var todayStore: TodayStore

    init(showCoach: Binding<Bool>, showSettings: Binding<Bool>) {
        self._showCoach = showCoach
        self._showSettings = showSettings
        let reader = LegacyTodayReadingModule()
        self.legacyTodayReader = reader
        self._todayStore = StateObject(
            wrappedValue: TodayStore(
                reader: reader,
                clock: SystemAppClock(),
                calendar: .current
            )
        )
    }
    
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

    private var todayAIInsight: DailyAIInsight? {
        dashboardVM.todayAIInsight
    }

    var todayExperience: TodayExperienceModel {
        dashboardVM.todayExperience ?? makeTodayExperience()
    }

    /// Baseline deviation changes emphasis, never score order or display
    /// grammar. The user can therefore build a stable visual memory over time.
    private var deviatedScoreIDs: Set<String> {
        Set(dashboard.personalHealthBrief?.notableChanges.compactMap { finding in
            guard finding.isNotable else { return nil }
            switch finding.metric {
            case .recovery: return "recovery"
            case .sleepDuration: return "sleep"
            case .strain: return "strain"
            case .stress: return "stress"
            case .energy: return "energy"
            default: return nil
            }
        } ?? [])
    }

    /// The score remains the conclusion. This one short line is a bridge to
    /// Coach, with a deterministic local brief available when AI is offline.
    private var todayAgentSentence: String {
        switch todayExperience.baselineFormation.phase {
        case .waitingForEvidence:
            return "连接 Apple 健康后开始形成个人基线。"
        case .learning:
            return "继续正常佩戴，Vela 正在了解你的日常波动。"
        case .ready:
            break
        }
        let localBrief = dashboard.personalHealthBrief?.subheadline
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = if let localBrief, !localBrief.isEmpty {
            localBrief
        } else if !todayExperience.hero.summary.isEmpty {
            todayExperience.hero.summary
        } else {
            "五项状态已更新，点此继续问我。"
        }
        return compactAgentSentence(candidate)
    }

    private var todayScoreFreshness: DataFreshness {
        guard todayExperience.signalCards.contains(where: { $0.value != "--" }) else {
            return .missing
        }
        guard dashboardVM.isToday else { return .recent }
        guard let lastUpdated = dashboardVM.lastUpdated else { return .today }
        let age = Date().timeIntervalSince(lastUpdated)
        if age <= 2 * 3_600 { return .live }
        if Calendar.current.isDateInToday(lastUpdated) { return .today }
        if age <= 3 * 86_400 { return .recent }
        return .stale
    }

    private func compactAgentSentence(_ input: String) -> String {
        let flattened = input
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
        let sentence = flattened.split(
            whereSeparator: { "。！？!?".contains($0) }
        ).first.map(String.init) ?? flattened
        let limit = 48
        return sentence.count > limit ? String(sentence.prefix(limit)) + "…" : sentence
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
            operatingPlan: dashboardVM.persistedOperatingPlanPayload
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
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay {
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
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
                status: vitalStatusText(hasData: hrv != nil, lastUpdated: updatedDate),
                isGood: vitalAssessment("hrv"), trend: dashboardVM.vitalTrendSeries["hrv"] ?? []
            ),
            TodayVitalCardModel(
                kind: .rhr, label: "静息心率",
                value: rhr.map { "\(Int($0.rounded()))" } ?? "--", unit: "bpm",
                status: vitalStatusText(hasData: rhr != nil, lastUpdated: updatedDate),
                isGood: vitalAssessment("rhr"), trend: dashboardVM.vitalTrendSeries["rhr"] ?? []
            ),
            TodayVitalCardModel(
                kind: .spo2, label: "血氧",
                value: spo2.map { "\(Int($0.rounded()))" } ?? "--", unit: "%",
                status: vitalStatusText(hasData: spo2 != nil, lastUpdated: updatedDate),
                isGood: vitalAssessment("spo2"), trend: dashboardVM.vitalTrendSeries["spo2"] ?? []
            ),
            TodayVitalCardModel(
                kind: .sleep, label: "睡眠",
                value: sleepMin > 0 ? "\(sleepMin / 60):\(String(format: "%02d", sleepMin % 60))" : "--", unit: "时",
                status: vitalStatusText(hasData: sleepMin > 0, lastUpdated: updatedDate),
                isGood: vitalAssessment("sleep"), trend: dashboardVM.vitalTrendSeries["sleep"] ?? []
            )
        ]
    }

    /// 体征卡评估：来自 canonical HealthTrendFinding（7d）的 assessment，
    /// 替代此前固定 isGood: true（P0-D）。
    private func vitalAssessment(_ metricRaw: String) -> Bool {
        let finding = dashboard.healthTrends.first {
            $0.metric.rawValue == metricRaw && $0.horizon == .sevenDays
        }
        guard let finding else { return true }
        switch finding.assessment {
        case .favorable: return true
        case .unfavorable: return false
        case .neutral, .insufficientData: return true
        }
    }

    private static let vitalTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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
        if calendar.isDateInToday(lastUpdated) {
            return "\(Self.vitalTimeFormatter.string(from: lastUpdated)) 同步"
        } else if calendar.isDateInYesterday(lastUpdated) {
            return "昨天 \(Self.vitalTimeFormatter.string(from: lastUpdated))"
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
            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
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
            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
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
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
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

    // A single route prevents mutually exclusive Today sheets from racing.
    @State var presentedTodaySheet: TodaySheet?
    @State var experienceFeedbackTick = 0
    @State var dataCoverageSummary = DataCoverageSummaryModel.unknown
    @State var dailyDecisionFeedback: DailyDecisionFeedbackRecord?
    @State private var selectedLivedStateAlignment: LivedStateAlignment?
    @State private var livedStateSaveError: String?
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
        if let errorMessage = dashboardVM.errorMessage ?? dashboardVM.secondaryDataErrorMessage {
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
            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusCard, style: .continuous)
                    .stroke(VelaTheme.stressColor.opacity(0.3), lineWidth: 1)
            )
        }
    }

    /// A surface-level projection for the short cache/load gap. It keeps the
    /// score grammar conservative (no invented values) while making the
    /// reason for the empty rings explicit to both people and UI tests.
    @ViewBuilder
    private var todayDataStateView: some View {
        let hasSignal = todayExperience.signalCards.contains { $0.value != "--" }
        if dashboardVM.isLoading && dashboardVM.lastUpdated == nil {
            VelaStateCard(
                state: .loading,
                title: "正在同步今日数据",
                message: "先展示保守状态；Apple 健康同步完成后，五项状态会自动更新。"
            )
            .accessibilityIdentifier("today-data-state")
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.bottom, 8)
        } else if !hasSignal {
            VelaStateCard(
                state: .empty,
                title: "今日数据待同步",
                message: "连接 Apple 健康并完成同步后，这里会显示恢复、睡眠、负荷、压力和能量。"
            )
            .accessibilityIdentifier("today-data-state")
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.bottom, 8)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if dashboardVM.errorMessage != nil || dashboardVM.secondaryDataErrorMessage != nil {
                    errorMessageView
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.bottom, 8)
                }

                todayDataStateView

                // ─── Block 1: Fixed five-score dashboard + one Agent sentence ───
                TodaySignalGrid(
                    model: todayExperience,
                    freshness: todayScoreFreshness,
                    deviatedScoreIDs: deviatedScoreIDs,
                    agentSentence: todayAgentSentence,
                    accentColor: signalAccentColor,
                    onAskCoach: { showCoach = true }
                )
                .equatable()
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 4)

                if dashboardVM.isToday {
                    livedStatePrompt
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.top, 12)

                    TodayDailyPlanCard(
                        model: todayExperience,
                        payload: dashboardVM.persistedOperatingPlanPayload,
                        onAction: { performExperienceAction($0) },
                        onOpenPlan: { appState.routeToTraining() }
                    )
                    .equatable()
                    .padding(.horizontal, VelaTheme.pagePadding)
                    .padding(.top, 12)

                    if let activePlan = dashboardVM.activeTrainingPlan,
                       let pendingProposal = dashboardVM.pendingPlanAdaptation {
                        TodayTrainingPlanAdaptationCard(
                            activePlan: activePlan,
                            pendingProposal: pendingProposal
                        )
                        .equatable()
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.top, 12)
                    }
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
                        case .hrv:
                            dispatchToday(.openMetric(.recovery))
                            presentedTodaySheet = .metric(.hrv)
                        case .rhr:
                            dispatchToday(.openMetric(.recovery))
                            presentedTodaySheet = .metric(.rhr)
                        case .spo2:
                            dispatchToday(.openMetric(.recovery))
                            presentedTodaySheet = .metric(.bloodOxygen)
                        case .sleep:
                            dispatchToday(.openMetric(.sleep))
                            presentedTodaySheet = .metric(.sleep)
                        }
                    }
                    .equatable()
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 20)

                VStack(alignment: .leading, spacing: 24) {
                    // ─── Block 4: Downstream action sequence ───
                    if !todayExperience.actions.isEmpty {
                        VelaRhythmActionSequence(
                            actions: todayExperience.actions,
                            onAction: { performExperienceAction($0) },
                            onEvidence: {
                                dispatchToday(.openEvidence)
                                presentedTodaySheet = .evidence
                            }
                        )
                    }

                    // ─── Block 5: Feedback + data coverage ───
                    if persistedOperatingPlan != nil {
                        DailyDecisionFeedbackCard(
                            record: dailyDecisionFeedback,
                            onTap: {
                                guard dailyDecisionFeedback != nil else { return }
                                presentedTodaySheet = .feedback
                            }
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
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                TodayDateAndStatusHeader(
                    selectedDate: dashboardVM.selectedDate,
                    todayShareText: todayShareText,
                    weatherTemp: weatherTemp,
                    weatherStatusText: weatherStatusText,
                    showSimulationLabel: dashboard.source == .preview,
                    onOpenCalendar: {
                        dispatchToday(.openCalendar)
                        presentedTodaySheet = .calendar
                    },
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
            legacyTodayReader.bind(
                dashboardVM: dashboardVM,
                modelContext: modelContext,
                useCase: services.dailySummaryUseCase
            )
            locationManager.startUpdating()
            if pendingLocalDataRefresh {
                pendingLocalDataRefresh = false
                await todayStore.send(.refresh(force: true))
            } else {
                if Calendar.current.isDate(
                    todayStore.state.selectedDay,
                    inSameDayAs: dashboardVM.selectedDate
                ) {
                    await todayStore.send(.appear)
                } else {
                    await todayStore.send(.selectDay(dashboardVM.selectedDate))
                }
            }
            await loadDataCoverageSummary()
            loadTodayLivedStateAlignment()
            trackDailyDecisionViewed()
        }
        .refreshable {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            await todayStore.send(.refresh(force: true))
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
                    await todayStore.send(.refresh(force: false))
                    await loadDataCoverageSummary()
                }
            }
        }
        .onChange(of: dashboardVM.selectedDate) {
            guard isActiveSurface else { return }
            Task { await todayStore.send(.selectDay(dashboardVM.selectedDate)) }
            loadTodayLivedStateAlignment()
            loadDynamicData()
        }
        .onChange(of: appState.localDataRevision) {
            // F2 修复：档案（年龄/体重/身高/maxHR/性别）修改后必须重算评分，
            // 此前只 hydrateFromCache，15 分钟内分数与建议停留在旧档案口径。
            if isActiveSurface {
                Task { await todayStore.send(.refresh(force: true)) }
            } else {
                pendingLocalDataRefresh = true
            }
            loadRealNutritionData()
            loadDynamicData()
        }
        .onChange(of: locationManager.location) {
            fetchLocalWeather()
        }
        .sheet(item: $presentedTodaySheet) { sheet in
            todaySheetContent(sheet)
        }
        .alert("暂时无法记录", isPresented: Binding(
            get: { livedStateSaveError != nil },
            set: { if !$0 { livedStateSaveError = nil } }
        )) {
            Button("好", role: .cancel) { livedStateSaveError = nil }
        } message: {
            Text(livedStateSaveError ?? "请稍后重试。")
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func todaySheetContent(_ sheet: TodaySheet) -> some View {
        switch sheet {
        case .calendar:
            CalendarOverviewSheetView()
                .presentationDetents([.medium, .large])
                .velaSheetSurface()
        case .metric(let metric):
            NavigationStack {
                VelaMetricDetailView(metric: metric)
            }
            .environmentObject(dashboardVM)
            .presentationDetents([.large])
            .velaSheetSurface()
        case .evidence:
            TodayEvidenceSheet(
                state: todayCommandState,
                dashboard: dashboard,
                onAskCoach: { question in
                    presentedTodaySheet = nil
                    dispatchToday(.askCoach(question))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        VelaAppState.shared.routeToCoach(question: question, surface: .home)
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .velaSheetSurface()
        case .feedback:
            if let dailyDecisionFeedback {
                DailyDecisionFeedbackSheet(record: dailyDecisionFeedback) { values in
                    saveDailyDecisionFeedback(values)
                }
                .presentationDetents([.large])
                .velaSheetSurface()
            }
        case .livedState:
            LivedStateCheckInSheet(selectedDate: dashboardVM.selectedDate) {
                appState.markLocalDataChanged()
                loadTodayLivedStateAlignment()
            }
            .presentationDetents([.large])
            .velaSheetSurface()
        }
    }

    func performExperienceAction(_ action: TodayExperienceAction) {
        experienceFeedbackTick += 1
        trackDailyDecisionAction(destination: action.destination)
        switch action.destination {
        case "training":
            dispatchToday(.startTraining)
            appState.routeToTraining()
        case "journal":
            dispatchToday(.openEvidence)
            presentedTodaySheet = .livedState
        case "coach":
            dispatchToday(.askCoach(action.detail))
            VelaAppState.shared.routeToCoach(question: action.detail, surface: .home)
        case "recovery", "sync", "evidence":
            dispatchToday(.openEvidence)
            presentedTodaySheet = .evidence
        default:
            dispatchToday(.openEvidence)
            presentedTodaySheet = .evidence
        }
    }

    private var livedStatePrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("和你的感受一致吗？")
                    .font(VelaTheme.subheadline().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                Spacer()

                Button("补充细节") {
                    VelaHaptic.selection()
                    presentedTodaySheet = .livedState
                }
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
            }

            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(LivedStateAlignment.allCases, id: \.self) { alignment in
                        livedStateAlignmentButton(alignment)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(LivedStateAlignment.allCases, id: \.self) { alignment in
                        livedStateAlignmentButton(alignment)
                    }
                }
            }
        }
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

    private func livedStateLabel(_ alignment: LivedStateAlignment) -> String {
        switch alignment {
        case .aligned: return "一致"
        case .worse: return "更差"
        case .better: return "更好"
        case .uncertain: return "不确定"
        }
    }

    private func livedStateAccessibilityLabel(_ alignment: LivedStateAlignment) -> String {
        switch alignment {
        case .aligned: return "与分数一致"
        case .worse: return "比分数更差"
        case .better: return "比分数更好"
        case .uncertain: return "暂时不确定"
        }
    }

    private func livedStateAlignmentButton(_ alignment: LivedStateAlignment) -> some View {
        let selected = selectedLivedStateAlignment == alignment
        return Button {
            saveLivedStateAlignment(alignment)
        } label: {
            Text(livedStateLabel(alignment))
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(selected ? VelaTheme.rhythmDeepOn : VelaTheme.rhythmInk)
                .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget)
                .background(
                    selected ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.48),
                    in: Capsule(style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("身体感受\(livedStateAccessibilityLabel(alignment))")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func saveLivedStateAlignment(_ alignment: LivedStateAlignment) {
        do {
            try LivedStateJournalAdapter(modelContext: modelContext).saveAlignment(
                alignment,
                for: dashboardVM.selectedDate
            )
            selectedLivedStateAlignment = alignment
            VelaHaptic.selection()
            appState.markLocalDataChanged()
            dispatchToday(.setLivedStateAlignment(alignment))
        } catch {
            livedStateSaveError = error.localizedDescription
        }
    }

    private func loadTodayLivedStateAlignment() {
        selectedLivedStateAlignment = try? LivedStateJournalAdapter(
            modelContext: modelContext
        ).snapshot(for: dashboardVM.selectedDate).alignment
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
            presentedTodaySheet = nil
            VelaAppState.shared.markLocalDataChanged()
            dispatchToday(.submitFeedback(values))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedDate: Date
    let todayShareText: String
    let weatherTemp: String
    let weatherStatusText: String
    let showSimulationLabel: Bool

    let onOpenCalendar: () -> Void
    @Binding var showSettings: Bool
    var requestWeatherUpdate: () -> Void
    let settingsSynced: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .center, spacing: 8) {
                    dateButton
                    Spacer(minLength: 8)
                    headerActions
                }

                weatherBar
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    dateButton
                    weatherBar
                    Spacer()
                    headerActions
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
        // This is navigation chrome, not reading content. Keep it useful at the
        // largest accessibility settings without allowing the custom header to
        // consume most of the viewport; the scroll content below still receives
        // the user's full Dynamic Type size.
        .dynamicTypeSize(headerDynamicTypeSize)
    }

    private var headerDynamicTypeSize: DynamicTypeSize {
        dynamicTypeSize.isAccessibilitySize ? .accessibility1 : dynamicTypeSize
    }

    private var dateButton: some View {
        Button {
            onOpenCalendar()
        } label: {
            HStack(spacing: 5) {
                Text(dateHeaderString(for: selectedDate))
                    .font(.system(.body, design: .default, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .frame(minHeight: VelaTheme.minimumHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel("选择日期")
        .accessibilityValue(dateHeaderString(for: selectedDate))
    }

    private var weatherBar: some View {
        TodayWeatherBar(
            weatherTemp: weatherTemp,
            weatherStatusText: weatherStatusText,
            requestWeatherUpdate: requestWeatherUpdate
        )
    }

    private var headerActions: some View {
        HStack(spacing: 2) {
            ShareLink(item: todayShareText) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .frame(width: VelaTheme.circularControlSize, height: VelaTheme.circularControlSize)
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
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmDeep)
                        }
                    Circle()
                        .fill(VelaTheme.rhythmGlow)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(VelaTheme.rhythmCanvas, lineWidth: 2))
                }
                .frame(width: VelaTheme.circularControlSize, height: VelaTheme.circularControlSize)
            }
            .buttonStyle(.cardPress)
            .accessibilityLabel(settingsSynced ? "个人设置,数据已同步" : "个人设置,数据待同步")
        }
    }

    private static let headerDateFormatterZh: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let headerDateFormatterEn: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.t("Today", "今天")
        } else if calendar.isDateInYesterday(date) {
            return L10n.t("Yesterday", "昨天")
        } else {
            let formatter = AppLanguage.stored.isChinese ? Self.headerDateFormatterZh : Self.headerDateFormatterEn
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedDate: Date
    var onSaved: () -> Void

    @State private var stress = 1
    @State private var energy = 1
    @State private var soreness = 0
    @State private var motivation = 1
    @State private var note = ""
    @State private var saveError: String?
    @State private var didLoadExisting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充你的身体感受")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("它会参与建议，但不会改写五项分数。")
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
                .dynamicTypeSize(
                    dynamicTypeSize.isAccessibilitySize ? .accessibility1 : dynamicTypeSize
                )
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
        .task {
            loadExistingCheckIn()
        }
        .accessibilityIdentifier("lived-state-check-in")
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

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(labels.indices, id: \.self) { index in
                        ratingButton(
                            title: title,
                            label: labels[index],
                            index: index,
                            selection: selection
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(labels.indices, id: \.self) { index in
                        ratingButton(
                            title: title,
                            label: labels[index],
                            index: index,
                            selection: selection
                        )
                    }
                }
            }
        }
    }

    private func ratingButton(
        title: String,
        label: String,
        index: Int,
        selection: Binding<Int>
    ) -> some View {
        let isSelected = selection.wrappedValue == index
        return Button {
            selection.wrappedValue = index
            VelaHaptic.selection()
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? VelaTheme.rhythmDeepOn : VelaTheme.rhythmInk)
                .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget)
                .background(
                    isSelected ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.48),
                    in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        let checkIn = LivedStateCheckIn(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation,
            note: note
        )
        do {
            try LivedStateJournalAdapter(modelContext: modelContext).saveCheckIn(
                checkIn,
                for: selectedDate
            )
            VelaHaptic.success()
            onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadExistingCheckIn() {
        guard !didLoadExisting else { return }
        didLoadExisting = true
        guard let existing = try? LivedStateJournalAdapter(
            modelContext: modelContext
        ).snapshot(for: selectedDate).checkIn else { return }
        stress = existing.stress
        energy = existing.energy
        soreness = existing.soreness
        motivation = existing.motivation
        note = existing.note
    }
}
