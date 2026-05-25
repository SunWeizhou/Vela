import Charts
import SwiftUI

struct SleepView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sleepHeader
                        DateNavigationBar()
                        sleepHero
                        sleepRhythmGrid
                        sleepStageCard
                        sleepTrendCard
                        sleepActionCard
                        sleepCoachCard
                    }
                    .padding(VelaTheme.screenPadding)
                    .padding(.bottom, 96)
                }
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.refresh(modelContext: modelContext)
                await viewModel.loadSleepTrend(modelContext: modelContext)
            }
        }
    }

    private var sleepHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Sleep", "睡眠"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(viewModel.isToday ? L10n.t("Last night", "昨晚") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Summarize my sleep and tell me what to do tonight.",
                    "请总结我的睡眠，并告诉我今晚该做什么。"
                ))
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var sleepHero: some View {
        HStack(alignment: .center, spacing: 18) {
            ArcProgressView(
                score: viewModel.dashboard.sleepScore.hasData ? viewModel.dashboard.sleepScore.score : 0,
                tint: VelaTheme.sleep,
                recommendedRange: 80...100,
                size: 132,
                lineWidth: 11
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Time Asleep", "实际睡眠"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                    Text(sleepDurationText(viewModel.dashboard.sleepSummary.totalSleepMinutes))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    compactTimePill(
                        title: L10n.t("Bed", "入睡"),
                        value: viewModel.dashboard.sleepSummary.bedtime?.formatted(date: .omitted, time: .shortened) ?? "--"
                    )
                    compactTimePill(
                        title: L10n.t("Wake", "醒来"),
                        value: viewModel.dashboard.sleepSummary.wakeTime?.formatted(date: .omitted, time: .shortened) ?? "--"
                    )
                }

                Text(primarySleepReason)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.sleep)
    }

    private var sleepRhythmGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            sleepMetricTile(
                title: L10n.t("Need", "目标"),
                value: sleepDurationText(effectiveTargetMinutes),
                subtitle: L10n.t("Target", "目标"),
                tint: VelaTheme.accent
            )
            sleepMetricTile(
                title: L10n.t("Debt", "睡眠债"),
                value: sleepDebtText,
                subtitle: sleepDebtMinutes > 0 ? L10n.t("Behind", "不足") : L10n.t("Covered", "达成"),
                tint: sleepDebtMinutes > 45 ? VelaTheme.energy : VelaTheme.recovery
            )
            sleepMetricTile(
                title: L10n.t("Efficiency", "效率"),
                value: sleepEfficiencyText,
                subtitle: L10n.t("Asleep/In bed", "睡眠/在床"),
                tint: VelaTheme.sleep
            )
        }
    }

    private var sleepStageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(L10n.t("Sleep Stages", "睡眠阶段"), systemImage: "chart.bar.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(stageTotalText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            if viewModel.dashboard.sleepSummary.segments.isEmpty {
                stageDistributionBar
            } else {
                SleepStageTimelineView(
                    segments: viewModel.dashboard.sleepSummary.segments,
                    bedtime: viewModel.dashboard.sleepSummary.bedtime,
                    wakeTime: viewModel.dashboard.sleepSummary.wakeTime
                )
            }

            VStack(spacing: 10) {
                ForEach(stageBreakdown) { stage in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(stage.tint)
                            .frame(width: 9, height: 9)
                        Text(stage.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Spacer()
                        Text(sleepDurationText(stage.minutes))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .monospacedDigit()
                    }
                }
            }
        }
        .cardSurface()
    }

    private var stageDistributionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(stageBreakdown) { stage in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(stage.tint.opacity(stage.minutes > 0 ? 0.95 : 0.16))
                        .frame(width: max(6, geo.size.width * CGFloat(stage.share)))
                }
            }
        }
        .frame(height: 18)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var sleepTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Sleep Trend", "睡眠趋势"), systemImage: "waveform.path.ecg")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(L10n.t("7D", "7 天"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            if viewModel.sleepTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more nights are saved.", "保存更多晚睡眠后会显示趋势。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                Chart(viewModel.sleepTrend) { item in
                    AreaMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [VelaTheme.sleep.opacity(0.20), VelaTheme.sleep.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(VelaTheme.sleep)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    PointMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(VelaTheme.sleep)
                    .symbolSize(24)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 150)
            }
        }
        .cardSurface()
    }

    private var sleepActionCard: some View {
        MetricActionCard(
            title: L10n.t("Tonight's Sleep Move", "今晚睡眠行动"),
            bodyText: L10n.t(
                "Turn last night's duration, stages, timing, and sleep debt into one concrete plan for tonight.",
                "把昨晚的时长、阶段、作息和睡眠债转成今晚的一步具体行动。"
            ),
            actionTitle: L10n.t("Plan tonight with Coach", "让 Coach 规划今晚"),
            systemImage: "moon.zzz.fill",
            tint: VelaTheme.sleep,
            coachQuestion: L10n.t(
                "Review my sleep data and give me one concrete plan for tonight. Include what to change, why it matters, and what I should avoid.",
                "请复盘我的睡眠数据，并给我今晚的一步具体计划。包括要改变什么、为什么重要、以及我应该避免什么。"
            )
        )
    }

    private var sleepCoachCard: some View {
        MetricCoachCard(
            dashboard: viewModel.dashboard,
            focus: CoachContextFocus(
                title: L10n.t("Sleep", "睡眠"),
                systemContext: L10n.t(
                    "Analyze sleep score, total duration, sleep stages, sleep timing, and recent sleep trend.",
                    "分析睡眠评分、总时长、睡眠阶段、入睡/醒来时间和近期睡眠趋势。"
                )
            ),
            suggestedQuestion: L10n.t(
                "Analyze my current sleep data. Start with the conclusion, then evidence, then the single most important sleep action for tonight.",
                "请分析我当前的睡眠数据。先给结论，再给依据，最后给今晚最重要的一步睡眠行动。"
            )
        )
    }

    private var primarySleepReason: String {
        guard viewModel.dashboard.sleepScore.hasData else {
            return L10n.t("Connect Apple Health to see sleep timing, stages, and score.", "连接 Apple 健康后可查看睡眠时间、阶段和评分。")
        }
        return localizedReason(viewModel.dashboard.sleepScore.reasons.first ?? L10n.t("Sleep score is based on duration and regularity.", "睡眠评分基于时长和规律性。"))
    }

    private var effectiveTargetMinutes: Int {
        let targetMinutes = Int(UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60)
        return targetMinutes > 0 ? targetMinutes : 450
    }

    private var sleepDebtMinutes: Int {
        let totalMinutes = viewModel.dashboard.sleepSummary.totalSleepMinutes
        return max(0, effectiveTargetMinutes - totalMinutes)
    }

    private var sleepDebtText: String {
        sleepDebtMinutes > 0 ? sleepDurationText(sleepDebtMinutes) : L10n.t("0m", "0 分")
    }

    private var sleepEfficiencyText: String {
        guard let bedtime = viewModel.dashboard.sleepSummary.bedtime,
              let wakeTime = viewModel.dashboard.sleepSummary.wakeTime else {
            return "--"
        }
        let inBedMinutes = max(1, Int(wakeTime.timeIntervalSince(bedtime) / 60))
        let efficiency = Double(viewModel.dashboard.sleepSummary.totalSleepMinutes) / Double(inBedMinutes)
        return "\(Int((min(efficiency, 1.0) * 100).rounded()))%"
    }

    private var stageBreakdown: [SleepStageDisplay] {
        let minutes = viewModel.dashboard.sleepSummary.stageMinutes
        let stages: [(String, Int, Color)] = [
            (L10n.t("Deep", "深睡"), minutes[.deep] ?? 0, VelaTheme.sleep),
            ("REM", minutes[.rem] ?? 0, VelaTheme.accent),
            (L10n.t("Core", "核心"), minutes[.core] ?? 0, VelaTheme.recovery),
            (L10n.t("Awake", "清醒"), minutes[.awake] ?? 0, VelaTheme.energy)
        ]
        let total = max(1, stages.map(\.1).reduce(0, +))
        return stages.map { SleepStageDisplay(title: $0.0, minutes: $0.1, tint: $0.2, share: Double($0.1) / Double(total)) }
    }

    private var stageTotalText: String {
        sleepDurationText(stageBreakdown.map(\.minutes).reduce(0, +))
    }

    private func compactTimePill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(Color.black.opacity(0.05)))
    }

    private func sleepMetricTile(title: String, value: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: title == L10n.t("Debt", "睡眠债") ? "battery.50" : "moon.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func sleepDurationText(_ minutes: Int) -> String {
        if minutes <= 0 { return "--" }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins)m" }
        if mins == 0 { return "\(hours)h" }
        return "\(hours)h \(mins)m"
    }
}

private struct SleepStageDisplay: Identifiable {
    let id = UUID()
    let title: String
    let minutes: Int
    let tint: Color
    let share: Double
}
