import Charts
import SwiftUI

struct SleepView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Sleep", "睡眠"),
            subtitle: viewModel.isToday ? L10n.t("Last night", "昨晚") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted),
            showDateNavigation: true,
            hero: {
                HealthMetricCard(
                    title: L10n.t("Sleep Score", "睡眠评分"),
                    value: viewModel.dashboard.sleepScore.hasData ? viewModel.dashboard.sleepScore.score.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: viewModel.dashboard.sleepScore.hasData ? localizedReason(viewModel.dashboard.sleepScore.reasons.first ?? L10n.t("Sleep score is based on duration and regularity.", "睡眠评分基于时长和规律性。")) : L10n.t("Connect Apple Health to see your sleep data.", "连接 Apple 健康以查看睡眠数据。"),
                    tint: VelaTheme.sleep,
                    systemImage: "moon.stars.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Total", "总时长"), value: "\(viewModel.dashboard.sleepSummary.totalSleepMinutes / 60)h \(viewModel.dashboard.sleepSummary.totalSleepMinutes % 60)m"),
                    .init(title: L10n.t("Deep", "深睡"), value: "\(viewModel.dashboard.sleepSummary.stageMinutes[.deep] ?? 0)m"),
                    .init(title: "REM", value: "\(viewModel.dashboard.sleepSummary.stageMinutes[.rem] ?? 0)m"),
                    .init(title: L10n.t("Core", "核心"), value: "\(viewModel.dashboard.sleepSummary.stageMinutes[.core] ?? 0)m")
                ])

                if let bedtime = viewModel.dashboard.sleepSummary.bedtime, let wakeTime = viewModel.dashboard.sleepSummary.wakeTime {
                    MetricRow(items: [
                        .init(title: L10n.t("Bedtime", "入睡"), value: bedtime.formatted(date: .omitted, time: .shortened)),
                        .init(title: L10n.t("Wake", "醒来"), value: wakeTime.formatted(date: .omitted, time: .shortened)),
                        .init(title: L10n.t("In Bed", "在床"), value: {
                            let minutes = Int(wakeTime.timeIntervalSince(bedtime) / 60)
                            return "\(minutes / 60)h \(minutes % 60)m"
                        }())
                    ])
                }

                // Sleep debt
                sleepDebtCard

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("Sleep Stages", "睡眠阶段"), systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    SleepStageTimelineView(
                        segments: viewModel.dashboard.sleepSummary.segments,
                        bedtime: viewModel.dashboard.sleepSummary.bedtime,
                        wakeTime: viewModel.dashboard.sleepSummary.wakeTime
                    )
                }
                .cardSurface()

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("7-Day Trend", "7 天趋势"), systemImage: "waveform.path.ecg")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    Chart(viewModel.sleepTrend) { item in
                        AreaMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VelaTheme.sleep.opacity(0.2), VelaTheme.sleep.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        LineMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(VelaTheme.sleep)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        PointMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(VelaTheme.sleep)
                        .symbolSize(20)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .frame(height: 160)
                }
                .cardSurface()

                PlaceholderInsightCard(
                    title: L10n.t("AI Sleep Review", "AI 睡眠复盘"),
                    bodyText: L10n.t("Open Coach to generate a full Sleep Review from structured context, journal entries, and user wiki.", "打开 Coach，基于结构化上下文、日记和用户 Wiki 生成完整睡眠复盘。")
                )

                MetricCoachCard(
                    dashboard: viewModel.dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Sleep", "睡眠"),
                        systemContext: L10n.t(
                            "Analyze sleep score, total duration, sleep stages, sleep timing, and recent sleep trend.",
                            "分析睡眠评分、总时长、睡眠阶段、入睡/醒来时间和近期睡眠趋势。"
                        )
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
        }
    }

    private var sleepDebtCard: some View {
        let totalMinutes = viewModel.dashboard.sleepSummary.totalSleepMinutes
        let targetMinutes = Int(UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60)
        let effectiveTarget = targetMinutes > 0 ? targetMinutes : 450
        let debt = effectiveTarget - totalMinutes

        return HStack(spacing: 14) {
            Image(systemName: debt > 30 ? "battery.25" : "battery.75")
                .font(.title2)
                .foregroundStyle(debt > 60 ? VelaTheme.stress : debt > 30 ? VelaTheme.energy : VelaTheme.recovery)
                .frame(width: 36, height: 36)
                .background(Circle().fill((debt > 60 ? VelaTheme.stress : debt > 30 ? VelaTheme.energy : VelaTheme.recovery).opacity(0.15)))

            VStack(alignment: .leading, spacing: 4) {
                Text(debt > 0
                    ? L10n.t("Sleep Debt: \(debt / 60)h \(debt % 60)m", "睡眠债：\(debt / 60)小时\(debt % 60)分钟")
                    : L10n.t("Sleep target reached", "睡眠目标达成"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(debt > 0
                    ? L10n.t("\(totalMinutes / 60)h \(totalMinutes % 60)m of \(effectiveTarget / 60)h \((effectiveTarget % 60) > 0 ? "\(effectiveTarget % 60)m" : "") target", "实际\(totalMinutes / 60)h\(totalMinutes % 60)m / 目标\(effectiveTarget / 60)h\((effectiveTarget % 60) > 0 ? "\(effectiveTarget % 60)m" : "")")
                    : L10n.t("You're getting enough rest. Keep it up!", "睡眠充足，继续保持！"))
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
            }
            Spacer()
        }
        .cardSurface()
    }
}
