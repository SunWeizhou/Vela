import SwiftUI

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
        case .restingHeartRate, .activeMinutes: return VelaTheme.sleepColor
        case .sleepHeartRate: return VelaTheme.energyColor
        case .respiratoryRate: return VelaTheme.recoveryColor
        case .weight: return VelaTheme.fg2
        case .activeCalories: return VelaTheme.strainColor
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
            return L10n.t("Resting heart rate is best interpreted against your personal baseline alongside sleep, stress, and recovery signals.", "静息心率应结合个人基线、睡眠、压力和恢复信号一起观察。")
        case .sleepHeartRate:
            return L10n.t("Sleep heart rate helps reveal overnight cardiovascular load and recovery quality.", "睡眠心率能帮助判断夜间心血管负担和恢复质量。")
        case .respiratoryRate:
            return L10n.t("Respiratory rate is useful as a freshness signal when it moves away from baseline.", "呼吸率偏离基线时，可作为状态变化的观察信号。")
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

enum RecoveryDetailRange: String, CaseIterable, Identifiable {
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

struct DateNavigationBar: View {
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
                        .foregroundStyle(VelaTheme.fg)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.cardPress)

                Spacer()

                Button {
                    showDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(formattedDate)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.fg)
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
                .buttonStyle(.cardPress)
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
                        .foregroundStyle(viewModel.isToday ? VelaTheme.muted : VelaTheme.fg)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.cardPress)
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
                .buttonStyle(.cardPress)
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
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)
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

struct VelaRangeBar: View {
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
                    .foregroundStyle(VelaTheme.muted)
                Spacer()
                if let today = todayValue {
                    Text("\(Int(today))\(unit)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                } else {
                    Text("--")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.muted)
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
                            .fill(VelaTheme.muted.opacity(0.3))
                            .frame(width: 1, height: 6)
                            .offset(x: 0.5 * geo.size.width)

                        let deviationPercent = ((today - baseline) / baseline) * 100
                        let isPositiveDeviation = isLowerBetter ? (today <= baseline) : (today >= baseline)
                        let dotColor = isPositiveDeviation ? VelaTheme.recoveryColor : (abs(deviationPercent) > 15 ? VelaTheme.stressColor : VelaTheme.energyColor)

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
