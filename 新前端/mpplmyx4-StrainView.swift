import Charts
import SwiftUI

struct StrainView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Strain", "负荷"),
            subtitle: viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted),
            showDateNavigation: true,
            hero: {
                HealthMetricCard(
                    title: L10n.t("Today's Strain", "今日负荷"),
                    value: viewModel.dashboard.strain.hasData ? viewModel.dashboard.strain.score.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: viewModel.dashboard.strain.hasData ? L10n.t("\(viewModel.dashboard.strain.targetStatus.rawValue). Recommended \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound).", "\(localizedTarget(viewModel.dashboard.strain.targetStatus))。建议 \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)。") : L10n.t("No activity data. Start moving to see your strain.", "暂无活动数据，开始运动即可看到负荷。"),
                    tint: VelaTheme.strain,
                    systemImage: "flame.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Energy", "能量"), value: viewModel.dashboard.strain.components["energy_load_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--"),
                    .init(title: L10n.t("Exercise", "锻炼"), value: viewModel.dashboard.strain.components["exercise_duration_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--"),
                    .init(title: L10n.t("Workout", "训练"), value: viewModel.dashboard.strain.components["workout_intensity_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--")
                ])

                MetricRow(items: [
                    .init(title: L10n.t("Active kcal", "活动千卡"), value: viewModel.dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0))" } ?? "--"),
                    .init(title: L10n.t("Exercise min", "锻炼分钟"), value: viewModel.dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))m" } ?? "--"),
                    .init(title: L10n.t("Steps", "步数"), value: viewModel.dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "--")
                ])

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("30-Day Strain Trend", "30 天负荷趋势"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    if viewModel.strainTrend.isEmpty {
                        Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
                    } else {
                        Chart(viewModel.strainTrend) { item in
                            AreaMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [VelaTheme.strain.opacity(0.2), VelaTheme.strain.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(VelaTheme.strain)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(VelaTheme.strain)
                            .symbolSize(20)
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .frame(height: 160)
                    }
                }
                .cardSurface()

                VStack(spacing: 16) {
                    ArcProgressView(
                        score: viewModel.dashboard.strain.score,
                        tint: VelaTheme.strain,
                        recommendedRange: viewModel.dashboard.strain.recommendedRange
                    )

                    Text(localizedTarget(viewModel.dashboard.strain.targetStatus))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                .cardSurface()

                PlaceholderInsightCard(
                    title: L10n.t("Recommended Range", "建议范围"),
                    bodyText: L10n.t("Today's target is derived from recovery: \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound).", "今日目标由恢复状态推导：\(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)。")
                )

                PlaceholderInsightCard(
                    title: L10n.t("Factor Breakdown", "因素拆解"),
                    bodyText: viewModel.dashboard.strain.reasons.map(localizedReason).joined(separator: " ")
                )

                PlaceholderInsightCard(
                    title: L10n.t("AI Workout Readiness", "AI 训练准备度"),
                    bodyText: L10n.t("The first AI version will produce light, moderate, hard, or recovery-day guidance.", "AI 会给出轻量、中等、较高强度或恢复日建议。")
                )

                MetricCoachCard(
                    dashboard: viewModel.dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Strain", "负荷"),
                        systemContext: L10n.t(
                            "Analyze today's strain score, active energy, exercise duration, workouts, recovery-adjusted recommended range, and workout readiness.",
                            "分析今日负荷评分、活动能量、锻炼时长、训练记录、由恢复状态调整的建议范围和训练准备度。"
                        )
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
        }
    }
}
