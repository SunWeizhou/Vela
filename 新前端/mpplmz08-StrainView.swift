import Charts
import SwiftUI

struct StrainView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Fitness", "健身"),
            subtitle: L10n.t("Past 30 days", "过去 30 天"),
            showDateNavigation: false,
            hero: {
                fitnessHeatmapCard
            },
            content: {
                activitySummaryCard
                strainPerformanceCard
                fitnessOverviewCard
                fitnessMetricBreakdownCard

                MetricActionCard(
                    title: L10n.t("Training Window", "训练窗口"),
                    bodyText: L10n.t(
                        "Today's target range is \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound). Use it to decide whether to add work, hold steady, or stop.",
                        "今天的建议负荷区间是 \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)。用它判断要加练、维持还是停止。"
                    ),
                    actionTitle: L10n.t("Ask for today's session", "生成今日训练建议"),
                    systemImage: "figure.run.circle.fill",
                    tint: VelaTheme.strain,
                    coachQuestion: L10n.t(
                        "Use my strain, recovery-adjusted target range, activity energy, exercise minutes, steps, and workouts to recommend today's training session. If I am above target, tell me what to skip.",
                        "请基于我的负荷、恢复调整后的目标区间、活动消耗、运动时长、步数和训练记录，推荐今天的训练内容。如果我已经超出目标，请告诉我应该跳过什么。"
                    )
                )

                PlaceholderInsightCard(
                    title: L10n.t("Why this score changed", "为什么负荷变化"),
                    bodyText: viewModel.dashboard.strain.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: viewModel.dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Strain", "负荷"),
                        systemContext: L10n.t(
                            "Analyze today's strain score, active energy, exercise duration, workouts, recovery-adjusted recommended range, and workout readiness.",
                            "分析今日负荷评分、活动能量、锻炼时长、训练记录、由恢复状态调整的建议范围和训练准备度。"
                        )
                    ),
                    suggestedQuestion: L10n.t(
                        "Analyze my current strain and tell me whether I should add training, maintain, or stop today. Give one concrete session or recovery action.",
                        "请分析我当前的负荷，并告诉我今天应该加练、维持还是停止。给我一个具体训练或恢复行动。"
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
    }

    private var fitnessHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(monthRangeTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Button {
                    VelaAppState.shared.routeToCoach(question: L10n.t(
                        "Analyze my last 30 days of fitness activity, strain, steps, active energy, and recovery. Tell me the pattern and the next training adjustment.",
                        "请分析我过去 30 天的健身活动、负荷、步数、活动能量和恢复，告诉我模式以及下一步训练调整。"
                    ))
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.85)))
                        .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(heatmapDays) { day in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(heatmapColor(for: day.activityLevel))
                        .frame(height: 9)
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(Color.black.opacity(0.04), lineWidth: 0.4)
                        )
                        .accessibilityLabel(day.accessibilityLabel)
                }
            }

            HStack(spacing: 12) {
                heatmapLegend(color: VelaTheme.recovery.opacity(0.45), label: L10n.t("1 activity", "1 项活动"))
                heatmapLegend(color: VelaTheme.recovery.opacity(0.70), label: L10n.t("2 activities", "2 项活动"))
                heatmapLegend(color: VelaTheme.strain.opacity(0.75), label: L10n.t("3+ activities", "3+ 活动"))
                Spacer()
            }
        }
        .heroCardSurface(accent: VelaTheme.recovery)
    }

    private var activitySummaryCard: some View {
        let activeDays = heatmapDays.filter { $0.activityLevel > 0 }.count
        let workoutCount = max(totalWorkoutCount, viewModel.dashboard.workouts.count)
        let totalMinutes = max(totalWorkoutMinutes, viewModel.dashboard.strain.metrics["exercise_minutes_raw"] ?? 0)
        let totalEnergy = max(totalActiveEnergy, viewModel.dashboard.strain.metrics["active_energy_raw"] ?? 0)

        return NavigationLink {
            FitnessActivityDetailView()
                .environmentObject(viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Label(L10n.t("Activity summary", "活动摘要"), systemImage: "figure.run")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(formattedDateRange(start: monthStartDate, end: Date()))
                            .font(.caption)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(formatMinutes(Int(totalMinutes)))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .minimumScaleFactor(0.72)
                    Spacer()
                }

                HStack(spacing: 8) {
                    fitnessPill(title: L10n.t("Active days", "活跃天数"), value: "\(activeDays)", tint: VelaTheme.recovery)
                    fitnessPill(title: L10n.t("Workouts", "训练"), value: "\(workoutCount)", tint: VelaTheme.energy)
                    fitnessPill(title: L10n.t("Energy", "能量"), value: "\(Int(totalEnergy)) kcal", tint: VelaTheme.strain)
                }
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private var strainPerformanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Label(L10n.t("Strain performance", "负荷表现"), systemImage: "waveform.path.ecg")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(strainDeltaLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(strainDelta >= 0 ? VelaTheme.recovery : VelaTheme.sleep)
                }
                Spacer()
                miniStrainGauge
            }

            if viewModel.strainTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            } else {
                Chart(viewModel.strainTrend) { item in
                    LineMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [VelaTheme.recovery, VelaTheme.energy, VelaTheme.strain],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(VelaTheme.strain.opacity(0.08))
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 120)
            }
        }
        .cardSurface()
    }

    private var miniStrainGauge: some View {
        ArcProgressView(
            score: viewModel.dashboard.strain.score,
            tint: VelaTheme.strain,
            recommendedRange: viewModel.dashboard.strain.recommendedRange,
            size: 78,
            lineWidth: 8
        )
    }

    private struct FitnessHeatmapDay: Identifiable {
        let id: String
        let date: Date
        let activityLevel: Int

        var accessibilityLabel: String {
            "\(date.formatted(date: .abbreviated, time: .omitted)): \(activityLevel)"
        }
    }

    private var heatmapDays: [FitnessHeatmapDay] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let lookup = Dictionary(uniqueKeysWithValues: viewModel.fitnessActivityHistory.map { ($0.dayIdentifier, $0) })

        return (0..<35).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: end) ?? end
            let id = DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar)
            let level = activityLevel(for: lookup[id], isToday: calendar.isDateInToday(date))
            return FitnessHeatmapDay(id: id, date: date, activityLevel: level)
        }
    }

    private var totalWorkoutCount: Int {
        viewModel.fitnessActivityHistory.compactMap(\.workoutCount).reduce(0, +)
    }

    private var totalWorkoutMinutes: Double {
        viewModel.fitnessActivityHistory.compactMap(\.workoutDuration).reduce(0, +)
    }

    private var totalActiveEnergy: Double {
        viewModel.fitnessActivityHistory.compactMap(\.activeCalories).reduce(0, +)
    }

    private var monthStartDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    }

    private var monthRangeTitle: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = "yyyy MMM"
        return "\(formatter.string(from: monthStartDate))   \(formatter.string(from: Date()))"
    }

    private var strainDelta: Double {
        guard let first = viewModel.strainTrend.first?.value,
              let last = viewModel.strainTrend.last?.value,
              first > 0 else { return 0 }
        return ((last - first) / first) * 100
    }

    private var strainDeltaLabel: String {
        let value = Int(strainDelta.rounded())
        if value == 0 { return L10n.t("Stable vs start", "较开始时稳定") }
        return value > 0
            ? L10n.t("+\(value)% vs start", "较开始时 +\(value)%")
            : L10n.t("\(value)% vs start", "较开始时 \(value)%")
    }

    private func activityLevel(for day: FitnessActivityDay?, isToday: Bool) -> Int {
        let workoutCount = day?.workoutCount ?? (isToday ? viewModel.dashboard.workouts.count : 0)
        let activeMinutes = day?.workoutDuration ?? (isToday ? viewModel.dashboard.strain.metrics["exercise_minutes_raw"] : nil) ?? 0
        let activeEnergy = day?.activeCalories ?? (isToday ? viewModel.dashboard.strain.metrics["active_energy_raw"] : nil) ?? 0
        let steps = day?.steps ?? (isToday ? viewModel.dashboard.strain.metrics["steps_raw"] : nil) ?? 0
        let score = day?.strainScore ?? (isToday ? viewModel.dashboard.strain.score : nil) ?? 0

        if workoutCount >= 3 || activeMinutes >= 75 || activeEnergy >= 650 || score >= 75 { return 3 }
        if workoutCount >= 2 || activeMinutes >= 45 || activeEnergy >= 400 || steps >= 10_000 || score >= 50 { return 2 }
        if workoutCount >= 1 || activeMinutes >= 15 || activeEnergy >= 150 || steps >= 4_000 || score >= 20 { return 1 }
        return 0
    }

    private func heatmapColor(for level: Int) -> Color {
        switch level {
        case 1:
            return VelaTheme.recovery.opacity(0.35)
        case 2:
            return VelaTheme.recovery.opacity(0.58)
        case 3...:
            return VelaTheme.strain.opacity(0.75)
        default:
            return Color.black.opacity(0.08)
        }
    }

    private func heatmapLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaTheme.secondaryText)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if AppLanguage.stored.isChinese {
            return "\(hours)小时 \(mins)分钟"
        }
        return "\(hours)h \(mins)m"
    }

    private func formattedDateRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US")
        formatter.dateFormat = AppLanguage.stored.isChinese ? "M月d日" : "MMM d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var fitnessMetricBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Daily load factors", "每日负荷因素"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCardMini(
                    title: L10n.t("Energy Load", "能量评分"),
                    value: viewModel.dashboard.strain.components["energy_load_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "bolt.fill",
                    tint: VelaTheme.energy
                )
                metricCardMini(
                    title: L10n.t("Exercise", "运动评分"),
                    value: viewModel.dashboard.strain.components["exercise_duration_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "figure.run",
                    tint: VelaTheme.recovery
                )
                metricCardMini(
                    title: L10n.t("Intensity", "强度评分"),
                    value: viewModel.dashboard.strain.components["workout_intensity_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "flame.fill",
                    tint: VelaTheme.strain
                )
                NavigationLink(destination: VitalsMetricDetailView(metric: .activeCalories)) {
                    metricCardMini(
                        title: L10n.t("Active Burn", "活动消耗"),
                        value: viewModel.dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--",
                        icon: "flame",
                        tint: VelaTheme.strain
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: VitalsMetricDetailView(metric: .activeMinutes)) {
                    metricCardMini(
                        title: L10n.t("Active Time", "活跃时长"),
                        value: viewModel.dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))m" } ?? "--",
                        icon: "clock.badge.checkmark",
                        tint: VelaTheme.sleep
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: VitalsMetricDetailView(metric: .steps)) {
                    metricCardMini(
                        title: L10n.t("Daily Steps", "今日步数"),
                        value: viewModel.dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "--",
                        icon: "shoeprints.fill",
                        tint: VelaTheme.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .cardSurface()
    }

    private var fitnessOverviewCard: some View {
        let range = viewModel.dashboard.strain.recommendedRange
        let score = Int(viewModel.dashboard.strain.score)
        let status = range.contains(score)
            ? L10n.t("In target", "位于目标")
            : (score > range.upperBound ? L10n.t("Above target", "高于目标") : L10n.t("Below target", "低于目标"))
        let body = range.contains(score)
            ? L10n.t("Your current load is aligned with today's capacity. Keep the next session controlled and stop when form starts to fade.", "当前负荷与今日容量匹配。下一次训练保持可控，动作质量下降时及时停止。")
            : (score > range.upperBound
                ? L10n.t("You have already used more capacity than recommended. Shift the rest of the day toward mobility, walking, and sleep protection.", "今日负荷已超过建议容量。剩余时间转向灵活性、散步和睡眠保护。")
                : L10n.t("You still have room for easy-to-moderate work if recovery feels stable. Prioritize consistency over intensity.", "如果体感稳定，今天仍有轻到中等训练空间。优先保持连续性，而不是强度。"))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("Training readiness", "训练准备度"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(status)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(range.contains(score) ? VelaTheme.recovery : (score > range.upperBound ? VelaTheme.stress : VelaTheme.energy))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill((range.contains(score) ? VelaTheme.recovery : (score > range.upperBound ? VelaTheme.stress : VelaTheme.energy)).opacity(0.12))
                    )
            }

            Text(body)
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .lineSpacing(3)

            HStack(spacing: 8) {
                fitnessPill(title: L10n.t("Target", "目标"), value: "\(range.lowerBound)-\(range.upperBound)", tint: VelaTheme.strain)
                fitnessPill(title: L10n.t("Current", "当前"), value: "\(score)", tint: VelaTheme.energy)
                fitnessPill(title: L10n.t("Steps", "步数"), value: viewModel.dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "--", tint: VelaTheme.accent)
            }
        }
        .cardSurface()
    }

    private func fitnessPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private func metricCardMini(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
    }
}

private struct FitnessActivityDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    private var activityDays: [FitnessActivityDay] {
        viewModel.fitnessActivityHistory.sorted { $0.date < $1.date }
    }

    private var activeDays: Int {
        activityDays.filter { activityLevel(for: $0) > 0 }.count
    }

    private var totalMinutes: Double {
        activityDays.compactMap(\.workoutDuration).reduce(0, +)
    }

    private var totalEnergy: Double {
        activityDays.compactMap(\.activeCalories).reduce(0, +)
    }

    private var workoutCount: Int {
        activityDays.compactMap(\.workoutCount).reduce(0, +)
    }

    private var averageSteps: Int {
        let values = activityDays.compactMap(\.steps)
        guard !values.isEmpty else { return 0 }
        return Int((values.reduce(0, +) / Double(values.count)).rounded())
    }

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Activity", "活动"),
            subtitle: L10n.t("Last 30 days", "过去 30 天"),
            showDateNavigation: false,
            hero: {
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.t("Activity load", "活动负荷"), systemImage: "figure.run")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(formatMinutes(Int(totalMinutes)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .minimumScaleFactor(0.72)

                    HStack(spacing: 8) {
                        detailPill(title: L10n.t("Active days", "活跃天数"), value: "\(activeDays)", tint: VelaTheme.recovery)
                        detailPill(title: L10n.t("Workouts", "训练"), value: "\(workoutCount)", tint: VelaTheme.energy)
                        detailPill(title: L10n.t("Energy", "消耗"), value: "\(Int(totalEnergy))", tint: VelaTheme.strain)
                    }
                }
                .heroCardSurface(accent: VelaTheme.strain)
            },
            content: {
                trendCard
                factorCard
                MetricActionCard(
                    title: L10n.t("Analyze activity trend", "分析活动趋势"),
                    bodyText: L10n.t(
                        "Vela will use your recent active minutes, workouts, steps, active energy, strain, and recovery to explain whether your load is building productively.",
                        "Vela 会结合最近活跃时长、训练、步数、活动消耗、负荷和恢复，判断你的训练负荷是否在有效累积。"
                    ),
                    actionTitle: L10n.t("Ask Vela", "询问 Vela"),
                    systemImage: "sparkles",
                    tint: VelaTheme.strain,
                    coachQuestion: L10n.t(
                        "Analyze my last 30 days of activity: active minutes, workouts, steps, active energy, strain, and recovery. Tell me whether to build, hold, or deload this week.",
                        "请分析我过去 30 天的活动：活跃时长、训练、步数、活动消耗、负荷和恢复。告诉我本周应该增加、维持还是减量。"
                    )
                )
            }
        )
        .task {
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Daily activity", "每日活动"), systemImage: "chart.bar.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            if activityDays.isEmpty {
                Text(L10n.t("Activity history will appear after Vela records more daily summaries.", "Vela 记录更多日摘要后会显示活动历史。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            } else {
                Chart(activityDays) { day in
                    BarMark(
                        x: .value("Day", day.date),
                        y: .value("Minutes", day.workoutDuration ?? 0)
                    )
                    .foregroundStyle(VelaTheme.recovery.gradient)

                    LineMark(
                        x: .value("Day", day.date),
                        y: .value("Strain", (day.strainScore ?? 0) * 1.2)
                    )
                    .foregroundStyle(VelaTheme.strain)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 160)
            }
        }
        .cardSurface()
    }

    private var factorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(L10n.t("Activity factors", "活动因素"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            VStack(spacing: 10) {
                factorRow(title: L10n.t("Average steps", "平均步数"), value: averageSteps == 0 ? "--" : "\(averageSteps)", icon: "shoeprints.fill", tint: VelaTheme.accent)
                factorRow(title: L10n.t("Active energy", "活动消耗"), value: "\(Int(totalEnergy)) kcal", icon: "flame.fill", tint: VelaTheme.strain)
                factorRow(title: L10n.t("Workout consistency", "训练连续性"), value: "\(activeDays)/30", icon: "calendar", tint: VelaTheme.recovery)
            }
        }
        .cardSurface()
    }

    private func factorRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
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
    }

    private func detailPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.10)))
    }

    private func activityLevel(for day: FitnessActivityDay) -> Int {
        let workoutCount = day.workoutCount ?? 0
        let activeMinutes = day.workoutDuration ?? 0
        let activeEnergy = day.activeCalories ?? 0
        let steps = day.steps ?? 0
        let score = day.strainScore ?? 0

        if workoutCount >= 3 || activeMinutes >= 75 || activeEnergy >= 650 || score >= 75 { return 3 }
        if workoutCount >= 2 || activeMinutes >= 45 || activeEnergy >= 400 || steps >= 10_000 || score >= 50 { return 2 }
        if workoutCount >= 1 || activeMinutes >= 15 || activeEnergy >= 150 || steps >= 4_000 || score >= 20 { return 1 }
        return 0
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if AppLanguage.stored.isChinese {
            return "\(hours)小时 \(mins)分钟"
        }
        return "\(hours)h \(mins)m"
    }
}

struct StrainMetricDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRange: MetricRange = .month

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricHeader
                    DateNavigationBar()
                    hero
                    trendCard
                    targetCard
                    factorCard
                    decisionCard
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.refresh(modelContext: modelContext)
                await viewModel.loadStrainTrend(modelContext: modelContext)
            }
        }
    }

    private var metricHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Strain", "负荷"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Explain my strain score and target range. Tell me whether to add training, maintain, or stop today.",
                    "请解释我的负荷评分和目标区间，并告诉我今天应该加练、维持还是停止。"
                ))
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
            ArcProgressView(
                score: viewModel.dashboard.strain.score,
                tint: VelaTheme.strain,
                recommendedRange: viewModel.dashboard.strain.recommendedRange,
                size: 136,
                lineWidth: 11
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Current load", "当前负荷"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                    Text(viewModel.dashboard.strain.hasData ? "\(Int(viewModel.dashboard.strain.score))" : "--")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .monospacedDigit()
                }

                Text(strainStatusCopy)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    metricPill(title: L10n.t("Target", "目标"), value: targetRangeText, tint: VelaTheme.strain)
                    metricPill(title: L10n.t("Steps", "步数"), value: stepsText, tint: VelaTheme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.strain)
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
                Text(L10n.t("Trend data will appear after more days are saved.", "保存更多天后会显示趋势。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                Chart(filteredTrend) { item in
                    AreaMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(VelaTheme.strain.opacity(0.10))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(VelaTheme.strain)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)

                    RuleMark(y: .value("Target min", Double(viewModel.dashboard.strain.recommendedRange.lowerBound)))
                        .foregroundStyle(VelaTheme.recovery.opacity(0.35))
                    RuleMark(y: .value("Target max", Double(viewModel.dashboard.strain.recommendedRange.upperBound)))
                        .foregroundStyle(VelaTheme.energy.opacity(0.35))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 160)
            }
        }
        .cardSurface()
    }

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Target Zone", "目标区间"), systemImage: "target")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            GeometryReader { geo in
                let width = geo.size.width
                let range = viewModel.dashboard.strain.recommendedRange
                let currentRatio = min(max(viewModel.dashboard.strain.score / 100, 0), 1)
                let minRatio = CGFloat(range.lowerBound) / 100
                let maxRatio = CGFloat(range.upperBound) / 100

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(VelaTheme.subtleFill)
                        .frame(height: 10)
                    Capsule()
                        .fill(VelaTheme.strain.opacity(0.22))
                        .frame(width: max(6, (maxRatio - minRatio) * width), height: 10)
                        .offset(x: minRatio * width)
                    Circle()
                        .fill(VelaTheme.strain)
                        .frame(width: 16, height: 16)
                        .shadow(color: VelaTheme.strain.opacity(0.45), radius: 5)
                        .offset(x: CGFloat(currentRatio) * width - 8, y: -3)
                }
            }
            .frame(height: 16)

            Text(L10n.t(
                "The target zone adapts to recovery. Use it as a stoplight for whether more work still makes sense today.",
                "目标区间会随恢复状态变化。用它判断今天是否还适合继续增加训练。"
            ))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.secondaryText)
            .lineSpacing(3)
        }
        .cardSurface()
    }

    private var factorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Load Factors", "负荷因素"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            VStack(spacing: 0) {
                metricRow(title: L10n.t("Active Energy", "活动消耗"), value: activeEnergyText, icon: "flame.fill", tint: VelaTheme.strain)
                metricRow(title: L10n.t("Exercise Time", "运动时间"), value: exerciseText, icon: "clock.fill", tint: VelaTheme.recovery)
                metricRow(title: L10n.t("Workout Intensity", "训练强度"), value: intensityText, icon: "bolt.fill", tint: VelaTheme.energy)
            }
        }
        .cardSurface()
    }

    private var decisionCard: some View {
        MetricActionCard(
            title: L10n.t("Today's Decision", "今日决策"),
            bodyText: strainStatusCopy,
            actionTitle: L10n.t("Ask Vela to decide", "让 Vela 判断"),
            systemImage: "figure.run.circle.fill",
            tint: VelaTheme.strain,
            coachQuestion: L10n.t(
                "Decide today's training based on strain, recovery, sleep, target range, active energy, exercise time, steps, and workouts. Give one exact session or recovery action.",
                "请基于负荷、恢复、睡眠、目标区间、活动消耗、运动时间、步数和训练记录，判断今天训练安排。给出一个明确训练或恢复行动。"
            )
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(MetricRange.allCases) { range in
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
        Array(viewModel.strainTrend.suffix(selectedRange.days))
    }

    private var targetRangeText: String {
        let range = viewModel.dashboard.strain.recommendedRange
        return "\(range.lowerBound)-\(range.upperBound)"
    }

    private var stepsText: String {
        viewModel.dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "--"
    }

    private var activeEnergyText: String {
        viewModel.dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--"
    }

    private var exerciseText: String {
        viewModel.dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))m" } ?? "--"
    }

    private var intensityText: String {
        viewModel.dashboard.strain.components["workout_intensity_score"].map { "\(Int($0))" } ?? "--"
    }

    private var strainStatusCopy: String {
        let range = viewModel.dashboard.strain.recommendedRange
        let score = Int(viewModel.dashboard.strain.score)
        if range.contains(score) {
            return L10n.t("Your load is inside today's recommended window. Maintain quality and stop before form degrades.", "当前负荷位于今日建议窗口内。保持训练质量，并在动作质量下降前停止。")
        }
        if score > range.upperBound {
            return L10n.t("Your load is above today's window. Shift the rest of the day to recovery and protect sleep.", "当前负荷高于今日窗口。剩余时间转向恢复，并保护睡眠。")
        }
        return L10n.t("You still have room for controlled work if recovery and schedule support it.", "如果恢复和日程允许，今天仍有可控训练空间。")
    }

    private func metricPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
    }

    private func metricRow(title: String, value: String, icon: String, tint: Color) -> some View {
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

private enum MetricRange: String, CaseIterable, Identifiable {
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
