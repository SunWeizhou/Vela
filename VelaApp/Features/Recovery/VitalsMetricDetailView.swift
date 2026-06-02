import Charts
import SwiftUI

struct VitalsMetricDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRange: RecoveryDetailRange = .month

    let metric: VitalsMetricDetailKind

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricHeader
                    DateNavigationBar()
                    hero
                    trendCard
                    contextCard
                    actionCard
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await reload() }
        }
    }

    private var metricHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: metric.coachQuestion)
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(metric.tint.opacity(0.14))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(metric.tint.opacity(0.28), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Image(systemName: metric.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(metric.tint)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(metric.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)

                Text(metric.valueText(in: viewModel.dashboard))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(metric.statusCopy(in: viewModel.dashboard))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: metric.tint)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Trend", "趋势"), systemImage: "chart.xyaxis.line")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                rangeSelector
            }

            if filteredTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more daily summaries are saved.", "保存更多每日摘要后会显示趋势。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                Chart(filteredTrend) { item in
                    LineMark(
                        x: .value("Day", item.date),
                        y: .value(metric.shortTitle, item.value)
                    )
                    .foregroundStyle(metric.tint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", item.date),
                        y: .value(metric.shortTitle, item.value)
                    )
                    .foregroundStyle(metric.tint)

                    if let baseline = metric.baselineValue(in: viewModel.dashboard) {
                        RuleMark(y: .value("Baseline", baseline))
                            .foregroundStyle(VelaTheme.mutedText.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 164)
            }
        }
        .cardSurface()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Context", "指标背景"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            if metric.supportsRangeBar {
                VelaRangeBar(
                    label: metric.shortTitle,
                    todayValue: metric.currentValue(in: viewModel.dashboard),
                    baselineValue: metric.baselineValue(in: viewModel.dashboard),
                    isLowerBetter: metric.lowerIsBetter,
                    unit: metric.unit
                )
            }

            contextRow(
                title: L10n.t("Today", "今日"),
                value: metric.valueText(in: viewModel.dashboard),
                icon: metric.icon,
                tint: metric.tint
            )

            contextRow(
                title: L10n.t("Baseline", "基线"),
                value: metric.baselineText(in: viewModel.dashboard),
                icon: "scope",
                tint: VelaTheme.secondaryText
            )

            Text(metric.explanation)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .lineSpacing(3)
        }
        .cardSurface()
    }

    private var actionCard: some View {
        MetricCoachCard(
            dashboard: viewModel.dashboard,
            focus: CoachContextFocus(title: metric.title, systemContext: metric.explanation),
            suggestedQuestion: metric.coachQuestion
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(RecoveryDetailRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedRange == range ? VelaTheme.inverseText : VelaTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(selectedRange == range ? VelaTheme.strongControl : VelaTheme.subtleFill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredTrend: [TrendPoint] {
        Array(viewModel.vitalsTrend.suffix(selectedRange.days))
    }

    private func reload() async {
        await viewModel.refresh(modelContext: modelContext)
        if let trendMetric = metric.trendMetric {
            await viewModel.loadVitalsTrend(metric: trendMetric, modelContext: modelContext)
        }
    }

    private func contextRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            Spacer()

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VelaTheme.stroke)
                .frame(height: 0.5)
                .padding(.leading, 40)
        }
    }
}

enum VitalsMetricDetailKind {
    case hrv
    case restingHeartRate
    case sleepHeartRate
    case respiratoryRate
    case bloodOxygen
    case weight
    case steps
    case activeCalories
    case activeMinutes

    var title: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return L10n.t("Resting Heart Rate", "静息心率")
        case .sleepHeartRate: return L10n.t("Sleep Heart Rate", "睡眠心率")
        case .respiratoryRate: return L10n.t("Respiratory Rate", "呼吸率")
        case .bloodOxygen: return L10n.t("Blood Oxygen", "血氧")
        case .weight: return L10n.t("Weight", "体重")
        case .steps: return L10n.t("Daily Steps", "今日步数")
        case .activeCalories: return L10n.t("Active Calories", "活动消耗")
        case .activeMinutes: return L10n.t("Active Minutes", "活跃时长")
        }
    }

    var shortTitle: String {
        switch self {
        case .restingHeartRate: return L10n.t("RHR", "静息心率")
        case .sleepHeartRate: return L10n.t("Sleep HR", "睡眠心率")
        case .respiratoryRate: return L10n.t("Resp", "呼吸")
        case .steps: return L10n.t("Steps", "步数")
        case .activeCalories: return L10n.t("Active Burn", "活动消耗")
        case .activeMinutes: return L10n.t("Active Time", "活跃时长")
        default: return title
        }
    }

    var icon: String {
        switch self {
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .sleepHeartRate: return "bed.double.fill"
        case .respiratoryRate: return "lungs.fill"
        case .bloodOxygen: return "drop.fill"
        case .weight: return "scalemass.fill"
        case .steps: return "shoeprints.fill"
        case .activeCalories: return "flame.fill"
        case .activeMinutes: return "clock.badge.checkmark"
        }
    }

    var tint: Color {
        switch self {
        case .hrv, .bloodOxygen, .steps: return VelaTheme.accent
        case .restingHeartRate, .activeMinutes: return VelaTheme.sleep
        case .sleepHeartRate: return VelaTheme.energy
        case .respiratoryRate: return VelaTheme.recovery
        case .weight: return VelaTheme.secondaryText
        case .activeCalories: return VelaTheme.strain
        }
    }

    var unit: String {
        switch self {
        case .hrv: return "ms"
        case .restingHeartRate, .sleepHeartRate: return "bpm"
        case .respiratoryRate: return "/min"
        case .bloodOxygen: return "%"
        case .weight: return "kg"
        case .steps: return ""
        case .activeCalories: return "kcal"
        case .activeMinutes: return "m"
        }
    }

    var lowerIsBetter: Bool {
        switch self {
        case .restingHeartRate, .sleepHeartRate:
            return true
        default:
            return false
        }
    }

    var trendMetric: VitalsTrendMetric? {
        switch self {
        case .hrv: return .hrv
        case .restingHeartRate: return .restingHeartRate
        case .sleepHeartRate: return nil
        case .respiratoryRate: return .respiratoryRate
        case .bloodOxygen: return .bloodOxygen
        case .weight: return .weight
        case .steps: return .steps
        case .activeCalories: return .activeCalories
        case .activeMinutes: return .activeMinutes
        }
    }

    var supportsRangeBar: Bool {
        switch self {
        case .hrv, .restingHeartRate, .respiratoryRate:
            return true
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return false
        }
    }

    var explanation: String {
        switch self {
        case .hrv:
            return L10n.t("HRV is compared to your personal baseline and is one of the strongest recovery drivers.", "HRV 会与个人基线比较，是恢复评分中最重要的信号之一。")
        case .restingHeartRate:
            return L10n.t("Resting heart rate rising above baseline often indicates stress, fatigue, illness, or poor recovery.", "静息心率高于基线通常提示压力、疲劳、疾病风险或恢复不足。")
        case .sleepHeartRate:
            return L10n.t("Sleep heart rate helps reveal overnight cardiovascular load and recovery quality.", "睡眠心率能帮助判断夜间心血管负担和恢复质量。")
        case .respiratoryRate:
            return L10n.t("Respiratory rate is useful as a freshness and illness-watch signal when it moves away from baseline.", "呼吸率偏离基线时，可作为状态新鲜度和疾病风险观察信号。")
        case .bloodOxygen:
            return L10n.t("Blood oxygen is a spot signal from HealthKit. Treat isolated readings cautiously and watch repeated changes.", "血氧是来自健康数据的采样信号。单次读数需要谨慎解读，更应关注重复变化。")
        case .weight:
            return L10n.t("Weight is most useful as a trend when combined with body fat, training load, and recovery.", "体重与体脂、训练负荷和恢复结合起来看，趋势价值最高。")
        case .steps:
            return L10n.t("Steps is a direct indicator of daily base movement and general physical activity.", "步数是每日基础活动量和整体身体活跃度的直接指标。")
        case .activeCalories:
            return L10n.t("Active calories measures the energy expended through exercises and movement.", "活动消耗衡量了通过锻炼和日常身体活动消耗的能量。")
        case .activeMinutes:
            return L10n.t("Active minutes represents the total duration spent in moderate-to-vigorous exercise.", "活跃时长代表了中高强度运动的总持续时间。")
        }
    }

    var actionTitle: String {
        switch self {
        case .hrv: return L10n.t("HRV Decision", "HRV 决策")
        case .restingHeartRate: return L10n.t("Heart Rate Decision", "心率决策")
        case .sleepHeartRate: return L10n.t("Overnight Load", "夜间负担")
        case .respiratoryRate: return L10n.t("Respiratory Check", "呼吸检查")
        case .bloodOxygen: return L10n.t("Oxygen Check", "血氧检查")
        case .weight: return L10n.t("Body Trend", "身体趋势")
        case .steps: return L10n.t("Steps Check", "步数检查")
        case .activeCalories: return L10n.t("Calorie Check", "热量消耗检查")
        case .activeMinutes: return L10n.t("Duration Check", "时长检查")
        }
    }

    var coachQuestion: String {
        switch self {
        case .hrv:
            return L10n.t("Analyze my HRV against baseline and tell me what it means for training and recovery today.", "请分析我的 HRV 与基线的关系，并说明它对今天训练和恢复意味着什么。")
        case .restingHeartRate:
            return L10n.t("Analyze my resting heart rate against baseline and decide whether I should push, maintain, or recover today.", "请分析我的静息心率与基线的关系，并判断今天应该推进、维持还是恢复。")
        case .sleepHeartRate:
            return L10n.t("Analyze my sleep heart rate and explain whether overnight recovery looks normal or elevated.", "请分析我的睡眠心率，并说明夜间恢复是否正常或偏高负担。")
        case .respiratoryRate:
            return L10n.t("Analyze my respiratory rate and tell me if there is anything I should watch today.", "请分析我的呼吸率，并告诉我今天是否有需要关注的事项。")
        case .bloodOxygen:
            return L10n.t("Analyze my blood oxygen reading carefully and explain what repeated changes would mean.", "请谨慎分析我的血氧读数，并说明如果连续变化代表什么。")
        case .weight:
            return L10n.t("Analyze my body weight trend with recovery and training context, and suggest one adjustment.", "请结合恢复和训练背景分析我的体重趋势，并给出一个调整建议。")
        case .steps:
            return L10n.t("Analyze my daily steps and active movement, and suggest one improvement.", "请分析我的每日步数和日常活动，并给出一个改善建议。")
        case .activeCalories:
            return L10n.t("Analyze my active calorie burn trend, and suggest one fitness adjustment.", "请分析我的活动消耗趋势，并给出一个健身调整建议。")
        case .activeMinutes:
            return L10n.t("Analyze my active minutes and training duration, and suggest one time-management improvement.", "请分析我的活跃时长和训练持续时间，并给出一个优化时间分配的建议。")
        }
    }

    func currentValue(in dashboard: DashboardSummary) -> Double? {
        switch self {
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds
        case .restingHeartRate:
            return dashboard.recoveryMetrics.restingHeartRate
        case .sleepHeartRate:
            return dashboard.recoveryMetrics.sleepHeartRate
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation
        case .weight:
            return dashboard.bodyMetrics.weightKilograms
        case .steps:
            return dashboard.strain.metrics["steps_raw"]
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"]
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"]
        }
    }

    func baselineValue(in dashboard: DashboardSummary) -> Double? {
        switch self {
        case .hrv:
            return dashboard.recoveryBaseline.hrvMilliseconds
        case .restingHeartRate:
            return dashboard.recoveryBaseline.restingHeartRate
        case .respiratoryRate:
            return dashboard.recoveryBaseline.respiratoryRate
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return nil
        }
    }

    func valueText(in dashboard: DashboardSummary) -> String {
        guard let value = currentValue(in: dashboard) else { return "--" }
        switch self {
        case .weight:
            return String(format: "%.1fkg", value)
        case .bloodOxygen:
            return "\(Int(value))%"
        case .respiratoryRate:
            return "\(Int(value))/min"
        case .hrv:
            return "\(Int(value))ms"
        case .restingHeartRate, .sleepHeartRate:
            return "\(Int(value))bpm"
        case .steps:
            return "\(Int(value))"
        case .activeCalories:
            return "\(Int(value)) kcal"
        case .activeMinutes:
            return "\(Int(value))m"
        }
    }

    func baselineText(in dashboard: DashboardSummary) -> String {
        guard let baseline = baselineValue(in: dashboard) else {
            return L10n.t("Pending", "待建立")
        }
        switch self {
        case .hrv:
            return "\(Int(baseline))ms"
        case .restingHeartRate:
            return "\(Int(baseline))bpm"
        case .respiratoryRate:
            return "\(Int(baseline))/min"
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return L10n.t("Pending", "待建立")
        }
    }

    func statusCopy(in dashboard: DashboardSummary) -> String {
        guard let today = currentValue(in: dashboard) else {
            return L10n.t("Waiting for Health data to populate this metric.", "等待健康数据填充这个指标。")
        }
        switch self {
        case .steps:
            return L10n.t("Focus on consistent movement to maintain joint health and insulin sensitivity.", "注重持续的身体活动以维持关节健康和胰岛素敏感性。")
        case .activeCalories:
            return L10n.t("Make sure to replenish enough nutrition and energy to support recovery after high burns.", "在高消耗后，确保补充足够的营养和能量以支持恢复。")
        case .activeMinutes:
            return L10n.t("Ensure exercise duration matches your weekly training program requirements.", "确保运动持续时间符合你的每周训练计划要求。")
        default:
            guard let baseline = baselineValue(in: dashboard), baseline > 0 else {
                return L10n.t("Current value is available. More saved days will create a better baseline and trend.", "当前值已可用。保存更多天后会形成更好的基线和趋势。")
            }
            let diff = today - baseline
            let isBetter = lowerIsBetter ? diff <= 0 : diff >= 0
            if isBetter {
                return L10n.t("This is on the favorable side of your current baseline.", "该指标处在相对基线更有利的一侧。")
            }
            return L10n.t("This is away from your favorable baseline and should be interpreted with sleep, strain, and symptoms.", "该指标偏离有利基线，需要结合睡眠、负荷和身体感受一起判断。")
        }
    }

    func actionBody(in dashboard: DashboardSummary) -> String {
        switch self {
        case .hrv, .restingHeartRate, .sleepHeartRate, .respiratoryRate, .steps, .activeCalories, .activeMinutes:
            return statusCopy(in: dashboard)
        case .bloodOxygen:
            return L10n.t("Do not overreact to one sample. Watch repeated drops and pair this with respiratory rate and sleep quality.", "不要因单次样本过度反应。重点关注连续下降，并结合呼吸率和睡眠质量。")
        case .weight:
            return L10n.t("Use this as a multi-week trend, not a single-day judgment. Pair changes with training load and body composition.", "把它作为多周趋势，而不是单日判断。需结合训练负荷和身体组成变化。")
        }
    }
}

private enum RecoveryDetailRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
    var title: String {
        switch self {
        case .week: return L10n.t("7D", "7天")
        case .month: return L10n.t("30D", "30天")
        }
    }
}

// MARK: - Date Navigation Bar

private struct DateNavigationBar: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var showDatePicker = false
    @State private var dragOffset: CGFloat = 0

    private let dateRange: ClosedRange<Date> = {
        let calendar = Calendar.current
        let today = Date()
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        return ninetyDaysAgo...today
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.goToPreviousDay()
                    }
                    onDateChanged()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(formattedDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        if viewModel.isToday {
                            Text(L10n.t("Today", "今日"))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(VelaTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(VelaTheme.accent.opacity(0.15)))
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showDatePicker) {
                    datePickerSheet
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.goToNextDay()
                    }
                    onDateChanged()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(viewModel.isToday ? VelaTheme.mutedText : VelaTheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isToday)
            }
            .padding(.horizontal, 8)
            .frame(height: 44)

            if !viewModel.isToday {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.goToToday()
                    }
                    onDateChanged()
                } label: {
                    Text(L10n.t("Back to today", "回到今天"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.goToPreviousDay()
                        }
                        onDateChanged()
                    } else if value.translation.width < -threshold {
                        if !viewModel.isToday {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.goToNextDay()
                            }
                            onDateChanged()
                        }
                    }
                    dragOffset = 0
                }
        )
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.70))
                .shadow(color: Color.black.opacity(0.05), radius: 14, y: 6)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        if AppLanguage.stored.isChinese {
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日 EEE"
        } else {
            formatter.locale = Locale(identifier: "en_US")
            formatter.dateFormat = "EEE, MMM d"
        }
        return formatter.string(from: viewModel.selectedDate)
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { viewModel.selectedDate },
                        set: { newDate in
                            viewModel.selectedDate = newDate
                            showDatePicker = false
                            onDateChanged()
                        }
                    ),
                    in: dateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle(L10n.t("Select Date", "选择日期"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("Cancel", "取消")) {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func onDateChanged() {
        Task { await viewModel.refresh(modelContext: modelContext) }
    }
}

// MARK: - Vela Range Bar

private struct VelaRangeBar: View {
    let label: String
    let todayValue: Double?
    let baselineValue: Double?
    let isLowerBetter: Bool
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                Spacer()
                if let today = todayValue {
                    Text("\(Int(today))\(unit)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                } else {
                    Text("--")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }

            if let today = todayValue, let baseline = baselineValue, baseline > 0 {
                let minScale = 0.5
                let maxScale = 1.5
                let scaleRange = maxScale - minScale
                let todayRatio = (today / baseline - minScale) / scaleRange
                let clampedTodayRatio = min(max(todayRatio, 0.05), 0.95)

                let normalMinRatio = (0.85 - minScale) / scaleRange
                let normalMaxRatio = (1.15 - minScale) / scaleRange

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: max(4, (normalMaxRatio - normalMinRatio) * geo.size.width), height: 4)
                            .offset(x: normalMinRatio * geo.size.width)

                        Rectangle()
                            .fill(VelaTheme.mutedText.opacity(0.3))
                            .frame(width: 1, height: 6)
                            .offset(x: 0.5 * geo.size.width)

                        let deviationPercent = ((today - baseline) / baseline) * 100
                        let isPositiveDeviation = isLowerBetter ? (today <= baseline) : (today >= baseline)
                        let dotColor = isPositiveDeviation ? VelaTheme.recovery : (abs(deviationPercent) > 15 ? VelaTheme.stress : VelaTheme.energy)

                        Circle()
                            .fill(dotColor)
                            .frame(width: 6, height: 6)
                            .shadow(color: dotColor.opacity(0.4), radius: 2)
                            .offset(x: clampedTodayRatio * geo.size.width - 3, y: -1)
                    }
                }
                .frame(height: 4)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 4)
            }
        }
    }
}
