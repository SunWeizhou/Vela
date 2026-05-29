import SwiftData
import SwiftUI

struct VelaMinimalFitnessView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    fitnessHero
                    activityGrid
                    workoutCard
                    trainingCoachCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
        .onAppear {
            viewModel.resetDateIfNeeded()
        }
    }

    private var fitnessHero: some View {
        VelaMinimalGlassPanel(padding: 24, radius: 28) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        VelaMinimalSectionTitle(title: L10n.t("Fitness", "健身"), subtitle: L10n.t("Past 30 days", "过去 30 天"))
                        VelaMinimalValueText(
                            value: VelaMinimalFormat.whole(viewModel.dashboard.strain.hasData ? viewModel.dashboard.strain.score : nil),
                            unit: L10n.t("strain", "负荷"),
                            size: 64,
                            tint: VelaTheme.accent
                        )
                    }
                    Spacer()
                    Image(systemName: "figure.run")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }

                VelaMinimalChip(
                    text: "\(L10n.t("Target", "目标")) \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)",
                    systemImage: "target",
                    tint: VelaTheme.strain
                )
            }
        }
    }

    private var activityGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            VelaMinimalBentoMetricCard(
                title: L10n.t("Workouts", "训练"),
                value: "\(viewModel.dashboard.workouts.count)",
                subtitle: L10n.t("Today", "今日"),
                systemImage: "dumbbell.fill",
                tint: VelaTheme.strain
            )
            VelaMinimalBentoMetricCard(
                title: L10n.t("Active Burn", "活动消耗"),
                value: VelaMinimalFormat.whole(viewModel.dashboard.strain.metrics["active_energy_raw"]),
                unit: "kcal",
                subtitle: L10n.t("From Health", "来自健康数据"),
                systemImage: "flame.fill",
                tint: VelaTheme.energy
            )
            VelaMinimalBentoMetricCard(
                title: L10n.t("Active Time", "活跃时长"),
                value: VelaMinimalFormat.whole(viewModel.dashboard.strain.metrics["exercise_minutes_raw"]),
                unit: "min",
                subtitle: L10n.t("Exercise minutes", "运动分钟"),
                systemImage: "timer",
                tint: VelaTheme.recovery
            )
            NavigationLink {
                TrainingView()
                    .environmentObject(viewModel)
            } label: {
                VelaMinimalBentoMetricCard(
                    title: L10n.t("Library", "训练库"),
                    value: "\(max(viewModel.fitnessActivityHistory.count, 0))",
                    subtitle: L10n.t("Open plans", "打开计划"),
                    systemImage: "list.bullet.rectangle.portrait.fill",
                    tint: VelaTheme.accent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(title: L10n.t("Recent Workouts", "最近训练"))
            VelaMinimalGlassPanel(padding: 0, radius: 22) {
                VStack(spacing: 0) {
                    if viewModel.dashboard.workouts.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("No workout logged today", "今天还没有训练记录"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(L10n.t("Vela will summarize sessions from Apple Health.", "Vela 会从 Apple Health 汇总训练。"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                        .padding(18)
                    } else {
                        ForEach(Array(viewModel.dashboard.workouts.prefix(4).enumerated()), id: \.element.id) { index, workout in
                            VelaMinimalRecordRow(
                                title: workout.activityName,
                                detail: workoutDuration(workout),
                                systemImage: "figure.run",
                                tint: VelaTheme.strain
                            )
                            .padding(.horizontal, 16)
                            if index < min(viewModel.dashboard.workouts.count, 4) - 1 {
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                }
            }
        }
    }

    private var trainingCoachCard: some View {
        VelaMinimalGlassPanel(padding: 18, radius: 22) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Build today's session", "生成今日训练"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Use strain, recovery, and workouts", "结合负荷、恢复和训练记录"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                Spacer()
                Button {
                    VelaAppState.shared.routeToCoach(question: L10n.t(
                        "Use my strain, recovery, activity energy, exercise minutes, and workouts to recommend today's training session.",
                        "请基于我的负荷、恢复、活动消耗、运动时长和训练记录，推荐今天的训练内容。"
                    ))
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workoutDuration(_ workout: WorkoutSummary) -> String {
        let minutes = max(1, Int(workout.end.timeIntervalSince(workout.start) / 60))
        return "\(minutes) min"
    }
}

