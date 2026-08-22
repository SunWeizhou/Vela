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

    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var workoutEvents: [WorkoutEventRecord]

    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]

    @State private var showPlanSwitcher = false
    @State private var showPlanEditor = false
    @State private var showQuickLog = false
    @State private var showStrengthLog = false
    @State private var selectedWorkoutDetail: WorkoutSummary? = nil
    @State private var activeStrengthDraft: TrainingSessionDraft? = nil

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive }) ?? plans.first
    }

    private var trainingBodyState: BodyState {
        viewModel.dashboard.bodyState
    }

    private var todayOperatingPlan: DailyOperatingPlanRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: viewModel.dashboard.date)
        return operatingPlans.first(where: { $0.dayIdentifier == identifier })
    }

    private var trainingDecision: DailyTrainingDecision {
        viewModel.dailyTrainingDecision
            ?? todayOperatingPlan?.trainingDecision
            ?? TrainingDecisionFallback.conservative(targetSessionTitle: nil)
    }

    private var todayExperience: TodayExperienceModel {
        TodayExperienceModel.build(
            dashboard: viewModel.dashboard,
            bodyState: trainingBodyState,
            trainingDecision: trainingDecision,
            nutrition: .empty,
            operatingPlan: todayOperatingPlan?.operatingPlanPayload
        )
    }

    private var todayOperatingPlanPayload: DailyOperatingPlanPayload? {
        todayOperatingPlan?.operatingPlanPayload
    }

    private var trainingSurfaceSummary: TrainingSurfaceSummaryModel {
        TrainingSurfaceSummaryModel.build(
            dashboard: viewModel.dashboard,
            todayExperience: todayExperience,
            trainingDecision: trainingDecision,
            operatingPlan: todayOperatingPlanPayload
        )
    }

    private var todayWorkouts: [WorkoutEventRecord] {
        workoutEvents.filter {
            Calendar.current.isDate($0.startedAt, inSameDayAs: viewModel.dashboard.date)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        trainingReadinessHero
                        todayCompletedWorkoutsSection
                        trainingQuickActions
                        TrainingCalendarView()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 96)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top) {
                trainingHeader
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(VelaTheme.rhythmCanvas.opacity(0.96))
            }
            .sheet(isPresented: $showPlanSwitcher) {
                planSwitcherSheet
            }
            .sheet(isPresented: $showPlanEditor) {
                TrainingPlanEditorSheet(plan: nil as TrainingPlanRecord?)
            }
            .sheet(isPresented: $showQuickLog) {
                TrainingQuickLogSheet()
            }
            .sheet(isPresented: $showStrengthLog) {
                StrengthWorkoutLogSheetView()
            }
            .sheet(item: $activeStrengthDraft) { draft in
                StrengthWorkoutLogSheetView(initialDraft: draft)
            }
            .sheet(item: $selectedWorkoutDetail) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
    }

    // MARK: - Header
    private var trainingHeader: some View {
        HStack(alignment: .center) {
            Button {
                showPlanSwitcher = true
            } label: {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("训练")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        Text(activePlan?.title ?? "选择或创建自适应计划")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Menu {
                Button {
                    showQuickLog = true
                } label: {
                    Label("快速补录运动", systemImage: "plus.circle")
                }

                Button {
                    showStrengthLog = true
                } label: {
                    Label("力量训练工作台", systemImage: "figure.strengthtraining.traditional")
                }

                Divider()

                Button {
                    showPlanEditor = true
                } label: {
                    Label("新建训练计划", systemImage: "calendar.badge.plus")
                }

                Button {
                    VelaAppState.shared.routeToCoach(question: "请根据我当前的恢复分、睡眠和目标，为我量身定制 7 天自适应训练周期。")
                } label: {
                    Label("让 Vela AI 生成计划", systemImage: "sparkles")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.rhythmCanvasRaised))
                    .overlay(Circle().stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
            }
            .buttonStyle(.cardPress)
        }
    }

    // MARK: - Hero Readiness Card
    private var trainingReadinessHero: some View {
        let summary = trainingSurfaceSummary
        let strainScore = viewModel.dashboard.strain.score
        let strainRange = viewModel.dashboard.strain.recommendedRange

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                // Circular Gauge / Indicator
                ArcProgressView(
                    score: strainScore,
                    tint: VelaTheme.strainColor,
                    recommendedRange: strainRange,
                    size: 108,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.confidenceLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .textCase(.uppercase)

                        Text(summary.headline)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }

                    HStack(spacing: 6) {
                        trainingSignalPill(title: "恢复", value: summary.recoveryValue, tint: VelaTheme.recoveryColor)
                        trainingSignalPill(title: "睡眠", value: summary.sleepValue, tint: VelaTheme.sleepColor)
                        trainingSignalPill(title: "RPE上限", value: summary.intensityCapText, tint: VelaTheme.energyColor)
                    }
                }
            }

            if !summary.guidance.isEmpty {
                Text(summary.guidance)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Quick Actions in Hero
            HStack(spacing: 10) {
                Button {
                    startTodayPlannedSession()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text(summary.primaryActionTitle)
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(trainingDecisionAccent(summary.decision))
                    .cornerRadius(12)
                }
                .buttonStyle(.cardPress)

                Button {
                    VelaAppState.shared.routeToCoach(question: summary.coachQuestion)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                        Text("自适应调整")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(VelaTheme.rhythmCanvas)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                }
                .buttonStyle(.cardPress)
            }
        }
        .padding(16)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    // MARK: - Today's Completed Activity Stream
    private var todayCompletedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日运动实况 (\(todayWorkouts.count))")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                Spacer()

                Button {
                    showQuickLog = true
                } label: {
                    Label("补记", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }

            if todayWorkouts.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 20))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VelaTheme.rhythmCanvas))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("今日尚未记录训练")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("完成训练后会自动从 Apple Watch 同步，或点击右上角快速录入。")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(VelaTheme.rhythmCanvasRaised)
                .cornerRadius(14)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
            } else {
                VStack(spacing: 10) {
                    ForEach(todayWorkouts) { event in
                        workoutEventRow(event)
                    }
                }
            }
        }
    }

    private func workoutEventRow(_ event: WorkoutEventRecord) -> some View {
        Button {
            let summary = WorkoutSummary(
                id: event.id,
                start: event.startedAt,
                end: event.endedAt,
                activityName: event.title.isEmpty ? event.activityType : event.title,
                energyKilocalories: event.energyKilocalories,
                averageHeartRate: event.averageHeartRate,
                source: event.source,
                rpe: event.rpe
            )
            selectedWorkoutDetail = summary
        } label: {
            HStack(spacing: 12) {
                Image(systemName: iconForWorkoutType(event.activityType))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(colorForWorkoutType(event.activityType))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(colorForWorkoutType(event.activityType).opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title.isEmpty ? localizedWorkoutTitle(event.activityType) : event.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    HStack(spacing: 8) {
                        Text("\(Int(event.durationMinutes.rounded())) 分钟")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)

                        if let kcal = event.energyKilocalories, kcal > 0 {
                            Text("· \(Int(kcal.rounded())) kcal")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        if let hr = event.averageHeartRate, hr > 0 {
                            Text("· 均心率 \(Int(hr.rounded()))")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        if let rpe = event.rpe {
                            Text("· RPE \(String(format: "%.1f", rpe))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.strainColor)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmMist)
            }
            .padding(12)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Action Tiles
    private var trainingQuickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            actionCardTile(
                title: "计划生成器",
                subtitle: "7 天自适应周期",
                icon: "sparkles",
                tint: VelaTheme.rhythmDeep,
                action: {
                    showPlanEditor = true
                }
            )

            actionCardTile(
                title: "力量工作台",
                subtitle: "计时 · 组数 · 动作库",
                icon: "figure.strengthtraining.traditional",
                tint: VelaTheme.strainColor,
                action: {
                    showStrengthLog = true
                }
            )
        }
    }

    private func actionCardTile(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
        .buttonStyle(.cardPress)
    }

    // MARK: - Plan Switcher Sheet
    private var planSwitcherSheet: some View {
        NavigationStack {
            ZStack {
                VelaTheme.rhythmCanvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("所有训练计划 (\(plans.count))")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)

                        if plans.isEmpty {
                            Text("暂无计划，点击下方创建新计划")
                                .font(.system(size: 13))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(plans) { plan in
                                    planSwitcherRow(plan)
                                }
                            }
                        }

                        Button {
                            showPlanSwitcher = false
                            showPlanEditor = true
                        } label: {
                            Label("新建训练计划", systemImage: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(VelaTheme.rhythmDeep)
                                .cornerRadius(14)
                        }
                        .padding(.top, 10)
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("训练计划管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { showPlanSwitcher = false }
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }
        }
    }

    private func planSwitcherRow(_ plan: TrainingPlanRecord) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(plan.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    if plan.isActive {
                        Text("当前活跃")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VelaTheme.recoveryColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VelaTheme.recoveryColor.opacity(0.14)))
                    }
                }

                Text("\(plan.weeksCount) 周周期 · \(plan.days.count) 节课表")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            Spacer()

            if !plan.isActive {
                Button("设为活跃") {
                    for p in plans { p.isActive = false }
                    plan.isActive = true
                    try? modelContext.save()
                    showPlanSwitcher = false
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(VelaTheme.rhythmCanvas)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(plan.isActive ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist, lineWidth: plan.isActive ? 1.5 : 0.75))
    }

    // MARK: - Helpers
    private func trainingSignalPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func trainingDecisionAccent(_ decision: DailyTrainingDecisionType) -> Color {
        switch decision {
        case .keep: return VelaTheme.rhythmDeep
        case .reduce: return VelaTheme.strainColor
        case .swap: return VelaTheme.energyColor
        case .rest: return VelaTheme.sleepColor
        }
    }

    private func startTodayPlannedSession() {
        if let plan = activePlan,
           let todaySession = plan.days.first(where: { !$0.isCompleted && $0.focus == "strength" }) {
            let decision = trainingDecision
            let draft = TrainingSessionDraftBuilder().build(
                day: todaySession,
                decision: decision,
                history: strengthWorkouts,
                scheduledAt: Date()
            )
            activeStrengthDraft = draft
        } else {
            showStrengthLog = true
        }
    }

    private func iconForWorkoutType(_ type: String) -> String {
        switch type.lowercased() {
        case "running", "跑步": return "figure.run"
        case "traditionalstrengthtraining", "strength", "力量训练", "力量": return "figure.strengthtraining.traditional"
        case "cycling", "骑行": return "figure.outdoor.cycle"
        case "swimming", "游泳": return "figure.pool.swim"
        case "yoga", "瑜伽": return "figure.mind.and.body"
        case "hiking", "徒步": return "figure.hiking"
        default: return "flame.fill"
        }
    }

    private func colorForWorkoutType(_ type: String) -> Color {
        switch type.lowercased() {
        case "running", "跑步": return VelaTheme.recoveryColor
        case "traditionalstrengthtraining", "strength", "力量训练": return VelaTheme.strainColor
        case "cycling", "骑行": return VelaTheme.energyColor
        case "yoga", "瑜伽": return VelaTheme.sleepColor
        default: return VelaTheme.rhythmDeep
        }
    }

    private func localizedWorkoutTitle(_ type: String) -> String {
        switch type {
        case "running": return "跑步训练"
        case "traditionalStrengthTraining": return "力量训练"
        case "cycling": return "骑行运动"
        case "swimming": return "游泳训练"
        case "yoga": return "瑜伽拉伸"
        case "hiking": return "户外徒步"
        case "walking": return "健步走"
        default: return type
        }
    }
}
