import Charts
import SwiftUI
import SwiftData

struct TrainingView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TrainingPlanRecord.createdAt, order: .reverse)
    private var plans: [TrainingPlanRecord]

    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse)
    private var operatingPlans: [DailyOperatingPlanRecord]

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive })
    }

    private var trainingBodyState: BodyState {
        BodyStateKernel().build(input: BodyStateInput(
            dashboard: viewModel.dashboard,
            activePlan: activePlan,
            activeStatus: ActiveStatusSettings.resolveCurrentStatus(),
            generatedAt: viewModel.dashboard.date
        ))
    }

    private var trainingDecision: DailyTrainingDecision {
        TrainingDecisionKernel().decide(input: TrainingDecisionInput(
            bodyState: trainingBodyState,
            activePlan: activePlan
        ))
    }

    private var todayExperience: TodayExperienceModel {
        TodayExperienceModel.build(
            dashboard: viewModel.dashboard,
            bodyState: trainingBodyState,
            trainingDecision: trainingDecision,
            nutrition: .empty
        )
    }

    private var todayOperatingPlanPayload: DailyOperatingPlanPayload? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: viewModel.dashboard.date)
        guard let plan = operatingPlans.first(where: { $0.dayIdentifier == identifier }),
              let data = plan.payloadJSON.data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: data)
    }

    private var trainingSurfaceSummary: TrainingSurfaceSummaryModel {
        TrainingSurfaceSummaryModel.build(
            dashboard: viewModel.dashboard,
            todayExperience: todayExperience,
            trainingDecision: trainingDecision,
            operatingPlan: todayOperatingPlanPayload
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        trainingReadinessHero
                        trainingQuickActions
                        TrainingCalendarView()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 96)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                trainingHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                
                Divider()
                    .opacity(0.4)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
    }

    private var trainingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Training", "训练"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(activePlan?.title ?? L10n.t("Adaptive plan workspace", "自适应训练计划"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Create or update my training plan based on today's recovery, sleep, strain target, and goals in my Wiki.",
                    "请基于今天的恢复、睡眠、负荷目标和 Wiki 里的目标，创建或更新我的训练计划。"
                ))
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.cardPress)
        }
        .padding(.top, 4)
    }

    private var trainingReadinessHero: some View {
        let summary = trainingSurfaceSummary
        return HStack(alignment: .center, spacing: 18) {
            ArcProgressView(
                score: viewModel.dashboard.strain.score,
                tint: VelaTheme.strain,
                recommendedRange: viewModel.dashboard.strain.recommendedRange,
                size: 122,
                lineWidth: 10
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(summary.confidenceLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)

                    Text(summary.headline)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }

                HStack(spacing: 8) {
                    trainingSignalPill(
                        title: L10n.t("Recovery", "恢复"),
                        value: summary.recoveryValue,
                        tint: VelaTheme.recovery
                    )
                    trainingSignalPill(
                        title: L10n.t("Sleep", "睡眠"),
                        value: summary.sleepValue,
                        tint: VelaTheme.sleep
                    )
                    trainingSignalPill(
                        title: L10n.t("RPE Cap", "RPE 上限"),
                        value: summary.intensityCapText,
                        tint: VelaTheme.energy
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    if let sessionTitle = summary.sessionTitle, !sessionTitle.isEmpty {
                        Text(sessionTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .lineLimit(1)
                    }

                    Text(summary.guidance)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Button {
                        performTrainingSummaryAction(summary)
                    } label: {
                        Label(summary.primaryActionTitle, systemImage: trainingSummaryActionIcon(summary.decision))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(trainingDecisionAccent(summary.decision))
                            )
                    }
                    .buttonStyle(.cardPress)

                    Text(L10n.t("Target", "目标") + " \(summary.targetRangeText)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .velaNativeCard(radius: 20)
    }

    private var trainingQuickActions: some View {
        let summary = trainingSurfaceSummary
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            trainingActionTile(
                title: L10n.t("Generate Plan", "生成计划"),
                subtitle: L10n.t("7-day adaptive block", "7 天自适应周期"),
                icon: "sparkles",
                tint: VelaTheme.accent,
                question: L10n.t(
                    "Generate a 7-day training plan using my current readiness, recent strain, sleep, goals, and constraints. Save it as a training plan if possible.",
                    "请根据我当前准备度、近期负荷、睡眠、目标和限制，生成 7 天训练计划。可以的话保存为训练计划。"
                )
            )

            trainingActionTile(
                title: L10n.t("Adjust Today", "调整今天"),
                subtitle: summary.primaryActionTitle,
                icon: "slider.horizontal.3",
                tint: trainingDecisionAccent(summary.decision),
                question: summary.coachQuestion
            )
        }
    }

    private func trainingSummaryActionIcon(_ decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: return "play.fill"
        case .reduce: return "arrow.down.forward.circle.fill"
        case .swap: return "arrow.triangle.2.circlepath"
        case .rest: return "heart.fill"
        }
    }

    private func trainingDecisionAccent(_ decision: DailyTrainingDecisionType) -> Color {
        switch decision {
        case .keep: return VelaTheme.recovery
        case .reduce: return VelaTheme.strain
        case .swap: return VelaTheme.accent
        case .rest: return VelaTheme.sleep
        }
    }

    private func performTrainingSummaryAction(_ summary: TrainingSurfaceSummaryModel) {
        switch summary.decision {
        case .keep, .reduce, .swap:
            VelaAppState.shared.routeToAdaptiveTrainingStart()
        case .rest:
            VelaAppState.shared.routeToRecoveryDetail()
        }
    }

    private func trainingSignalPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
    }

    private func trainingActionTile(title: String, subtitle: String, icon: String, tint: Color, question: String) -> some View {
        Button {
            VelaAppState.shared.routeToCoach(question: question)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .velaNativeCard(radius: 16)
            .appleIntelligenceGlow(isHighlighted: icon == "sparkles", radius: 16)
        }
        .buttonStyle(.cardPress)
    }

}
