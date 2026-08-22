import SwiftUI
import SwiftData

struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \TrainingPlanRecord.createdAt, order: .reverse)
    private var plans: [TrainingPlanRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var workoutEvents: [WorkoutEventRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var trainingResponses: [TrainingResponseRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(
        filter: #Predicate<TrainingPlanAdaptationRecord> { $0.status == "proposed" },
        sort: \TrainingPlanAdaptationRecord.createdAt,
        order: .reverse
    )
    private var pendingAdaptations: [TrainingPlanAdaptationRecord]

    @State private var selectedWeek: Int = 1
    @State private var selectedDayForSheet: TrainingDay? = nil
    @State private var editingDay: TrainingDay? = nil
    @State private var showPlanEditor = false
    @State private var planToEdit: TrainingPlanRecord? = nil
    @State private var activeStrengthDraft: TrainingSessionDraft? = nil
    @State private var mutationError: String?

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive }) ?? plans.first
    }

    private func adaptationsForPlan(_ plan: TrainingPlanRecord) -> [TrainingPlanAdaptationRecord] {
        pendingAdaptations.filter { $0.planId == plan.id }
    }

    private func pendingAdaptation(for day: TrainingDay, plan: TrainingPlanRecord) -> TrainingPlanAdaptationRecord? {
        adaptationsForPlan(plan).first { $0.dayId == day.id }
    }

    var body: some View {
        Group {
            if let plan = activePlan {
                activePlanView(plan)
            } else {
                emptyPlanView
            }
        }
        .onAppear {
            autoSelectCurrentWeek()
        }
        .onChange(of: plans) { _, _ in
            autoSelectCurrentWeek()
        }
        .sheet(item: $selectedDayForSheet) { day in
            if let plan = activePlan {
                WorkoutDetailSheet(
                    day: day,
                    plan: plan,
                    onToggle: {
                        toggleCompletion(for: day, in: plan)
                        if let idx = plan.days.firstIndex(where: { $0.id == day.id }) {
                            selectedDayForSheet = plan.days[idx]
                        }
                    },
                    onEdit: {
                        editingDay = day
                    },
                    onStartWorkout: {
                        startWorkoutSession(for: day, in: plan)
                    }
                )
            }
        }
        .sheet(item: $editingDay) { day in
            if let plan = activePlan {
                TrainingDayEditorSheet(day: day) { updatedDay in
                    updateDay(updatedDay, in: plan)
                }
            }
        }
        .sheet(isPresented: $showPlanEditor) {
            TrainingPlanEditorSheet(plan: planToEdit)
        }
        .sheet(item: $activeStrengthDraft) { draft in
            StrengthWorkoutLogSheetView(initialDraft: draft)
        }
        .alert("操作未完成", isPresented: Binding(
            get: { mutationError != nil },
            set: { if !$0 { mutationError = nil } }
        )) {
            Button("好", role: .cancel) { mutationError = nil }
        } message: {
            Text(mutationError ?? "")
        }
    }

    // MARK: - Auto Week Selector
    private func autoSelectCurrentWeek() {
        if let plan = activePlan {
            if let firstIncomplete = plan.days.first(where: { !$0.isCompleted }) {
                selectedWeek = firstIncomplete.weekNumber
            } else {
                selectedWeek = 1
            }
        }
    }

    // MARK: - Active Plan View
    private func activePlanView(_ plan: TrainingPlanRecord) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Plan Header Card
            planHeroCard(plan)

            // Pending Adaptations Banner
            pendingAdaptationsBanner(plan: plan)

            // Review Card
            planReviewCard(plan)

            // Week Selector Pills
            weekSelectorPills(plan: plan)

            // Days for Current Week
            let daysForWeek = plan.days.filter { $0.weekNumber == selectedWeek }.sorted(by: { $0.dayNumber < $1.dayNumber })

            VStack(spacing: 12) {
                ForEach(daysForWeek) { day in
                    workoutCard(day: day, plan: plan)
                }

                // Add Day Button
                Button {
                    let nextDayNum = (daysForWeek.map(\.dayNumber).max() ?? 0) + 1
                    let newDay = TrainingDay(
                        id: UUID(),
                        weekNumber: selectedWeek,
                        dayNumber: min(nextDayNum, 7),
                        title: "自定义训练日",
                        description: "添加训练内容或动作",
                        focus: "strength",
                        durationMinutes: 45,
                        intensity: "moderate",
                        isCompleted: false,
                        plannedExercisesJSON: "[]"
                    )
                    var currentDays = plan.days
                    currentDays.append(newDay)
                    plan.days = currentDays
                    plan.updatedAt = Date()
                    try? modelContext.save()
                    editingDay = newDay
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("添加第 \(selectedWeek) 周训练日")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VelaTheme.rhythmCanvasRaised)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                }
                .buttonStyle(.cardPress)
                .padding(.top, 4)
            }
        }
    }

    private func planHeroCard(_ plan: TrainingPlanRecord) -> some View {
        let totalCount = plan.days.count
        let completedCount = plan.days.filter(\.isCompleted).count
        let progressRatio = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        let percent = Int(progressRatio * 100)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    if !plan.goalDescription.isEmpty {
                        Text(plan.goalDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    planToEdit = plan
                    showPlanEditor = true
                } label: {
                    Label("编辑", systemImage: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VelaTheme.rhythmCanvas)
                        .cornerRadius(8)
                }
            }

            // Progress Bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("周期执行进度")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)

                    Spacer()

                    Text("\(completedCount)/\(totalCount) 天已打卡 (\(percent)%)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.recoveryColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VelaTheme.rhythmMist)
                            .frame(height: 6)

                        Capsule()
                            .fill(VelaTheme.rhythmDeep)
                            .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    private func weekSelectorPills(plan: TrainingPlanRecord) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...max(1, plan.weeksCount), id: \.self) { week in
                    let weekDays = plan.days.filter { $0.weekNumber == week }
                    let weekCompleted = weekDays.filter(\.isCompleted).count
                    let isSelected = selectedWeek == week

                    Button {
                        selectedWeek = week
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Text("第 \(week) 周")
                                .font(.system(size: 13, weight: .semibold))
                            if !weekDays.isEmpty {
                                Text("\(weekCompleted)/\(weekDays.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : VelaTheme.rhythmInkSecondary)
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : VelaTheme.rhythmInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(isSelected ? VelaTheme.rhythmDeep : VelaTheme.rhythmCanvasRaised)
                        )
                        .overlay(
                            Capsule().stroke(VelaTheme.rhythmMist, lineWidth: isSelected ? 0 : 0.75)
                        )
                    }
                    .buttonStyle(.cardPress)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Pending Adaptations
    private func pendingAdaptationsBanner(plan: TrainingPlanRecord) -> some View {
        let filtered = adaptationsForPlan(plan)
        guard !filtered.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.energyColor)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(VelaTheme.energyColor.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vela 智能体建议自适应调整")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("\(filtered.count) 项课表与近期的生理恢复状态不完全匹配。")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }

                ForEach(filtered.prefix(3)) { adaptation in
                    adaptationRow(adaptation, plan: plan)
                }
            }
            .padding(14)
            .background(VelaTheme.rhythmCanvasRaised)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.energyColor.opacity(0.35), lineWidth: 1))
        )
    }

    private func adaptationRow(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(adaptation.reason)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.rhythmInk)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("采纳调整") {
                    applyAdaptation(adaptation, plan: plan)
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(VelaTheme.energyColor))

                Button("忽略") {
                    dismissAdaptation(adaptation)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
        }
        .padding(10)
        .background(VelaTheme.rhythmCanvas)
        .cornerRadius(10)
    }

    // MARK: - Workout Card
    private func workoutCard(day: TrainingDay, plan: TrainingPlanRecord) -> some View {
        let focusColor = getFocusColor(day.focus)
        let focusSymbol = getFocusSymbol(day.focus)
        let hasPendingAdaptation = pendingAdaptation(for: day, plan: plan) != nil
        let exerciseCount = exercisesInDay(day).count

        return HStack(spacing: 12) {
            Button {
                selectedDayForSheet = day
            } label: {
                HStack(spacing: 12) {
                    // Left color bar
                    Rectangle()
                        .fill(day.isCompleted ? VelaTheme.recoveryColor : focusColor)
                        .frame(width: 4)
                        .cornerRadius(2)

                    // Main info
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)

                            Spacer()

                            HStack(spacing: 3) {
                                Image(systemName: focusSymbol)
                                    .font(.system(size: 8))
                                Text(focusName(day.focus))
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(focusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(focusColor.opacity(0.12)))

                            if hasPendingAdaptation {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(VelaTheme.energyColor)
                            }
                        }

                        Text(day.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(day.isCompleted ? VelaTheme.rhythmInkSecondary : VelaTheme.rhythmInk)
                            .strikethrough(day.isCompleted, color: VelaTheme.rhythmInkSecondary)

                        HStack(spacing: 8) {
                            if day.focus != "rest" {
                                Text("\(day.durationMinutes)分钟 · \(intensityName(day.intensity))")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)

                                if exerciseCount > 0 {
                                    Text("· \(exerciseCount) 个动作")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VelaTheme.rhythmDeep)
                                }
                            } else {
                                Text("充分休息与放松")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Actions: Quick toggle or Context Menu
            Menu {
                if day.focus == "strength" {
                    Button {
                        startWorkoutSession(for: day, in: plan)
                    } label: {
                        Label("开始本次力量训练", systemImage: "play.fill")
                    }
                }

                Button {
                    editingDay = day
                } label: {
                    Label("编辑此日课表", systemImage: "pencil")
                }

                Button {
                    swapDayWithNext(day, in: plan)
                } label: {
                    Label("与下一天日程互换", systemImage: "arrow.up.arrow.down")
                }

                Button {
                    toggleCompletion(for: day, in: plan)
                } label: {
                    Label(day.isCompleted ? "取消打卡" : "标记为已完成", systemImage: day.isCompleted ? "circle" : "checkmark.circle.fill")
                }

                Button(role: .destructive) {
                    deleteDay(day, in: plan)
                } label: {
                    Label("删除此日", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .frame(width: 32, height: 32)
            }

            Button {
                toggleCompletion(for: day, in: plan)
            } label: {
                Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(day.isCompleted ? VelaTheme.recoveryColor : VelaTheme.rhythmMist)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.cardPress)
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    private func planReviewCard(_ plan: TrainingPlanRecord) -> some View {
        let review = TrainingPlanReviewService.review(
            plan: plan.dto,
            events: workoutEvents.map { $0.dto },
            responses: trainingResponses.map { $0.dto }
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("周期复盘与依从度", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                Text("\(review.completedSessions)/\(review.scheduledSessions) 次完成")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.recoveryColor)
            }

            Text(review.recommendation)
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(2)

            HStack(spacing: 8) {
                reviewMetric("执行率", "\(Int((review.completionRate * 100).rounded()))%")
                reviewMetric("有效响应", "\(review.measuredResponses) 次")
                reviewMetric("恢复影响", review.averageRecoveryDelta.map { String(format: "%+.1f", $0) } ?? "稳定")
            }
        }
        .padding(14)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    private func reviewMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(VelaTheme.rhythmCanvas)
        .cornerRadius(8)
    }

    // MARK: - Empty Plan View
    private var emptyPlanView: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 70, height: 70)
                .background(Circle().fill(VelaTheme.rhythmDeep.opacity(0.12)))

            VStack(spacing: 6) {
                Text("建立你的个性化自适应计划")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("选择经典分化模板、由 AI 智能生成，或完全自定义创建。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 10) {
                Button {
                    planToEdit = nil
                    showPlanEditor = true
                } label: {
                    Label("从经典模板快速导入", systemImage: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VelaTheme.rhythmDeep)
                        .cornerRadius(14)
                }
                .buttonStyle(.cardPress)

                Button {
                    VelaAppState.shared.routeToCoach(question: "请根据我当前准备度、近期负荷、睡眠、目标和限制，生成 7 天自适应训练计划。")
                } label: {
                    Label("让 Vela AI 智能生成", systemImage: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VelaTheme.rhythmCanvasRaised)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
                }
                .buttonStyle(.cardPress)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .background(VelaTheme.rhythmCanvasRaised)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    // MARK: - Actions
    private func toggleCompletion(for day: TrainingDay, in plan: TrainingPlanRecord) {
        var days = plan.days
        guard let idx = days.firstIndex(where: { $0.id == day.id }) else { return }
        days[idx].isCompleted.toggle()
        days[idx].completedAt = days[idx].isCompleted ? Date() : nil
        plan.days = days
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            Task { @MainActor in
                await dashboardVM.refresh(modelContext: modelContext)
            }
        } catch {
            mutationError = "打卡状态保存失败：\(error.localizedDescription)"
        }
    }

    private func updateDay(_ updatedDay: TrainingDay, in plan: TrainingPlanRecord) {
        var days = plan.days
        if let idx = days.firstIndex(where: { $0.id == updatedDay.id }) {
            days[idx] = updatedDay
        } else {
            days.append(updatedDay)
        }
        plan.days = days
        plan.updatedAt = Date()
        do {
            try modelContext.save()
            Task { @MainActor in
                await dashboardVM.refresh(modelContext: modelContext)
            }
        } catch {
            mutationError = "课表保存失败：\(error.localizedDescription)"
        }
    }

    private func swapDayWithNext(_ day: TrainingDay, in plan: TrainingPlanRecord) {
        var days = plan.days
        guard let idx = days.firstIndex(where: { $0.id == day.id }) else { return }
        let nextDays = days.filter { $0.weekNumber == day.weekNumber && $0.dayNumber > day.dayNumber }.sorted(by: { $0.dayNumber < $1.dayNumber })
        guard let nextDay = nextDays.first, let nextIdx = days.firstIndex(where: { $0.id == nextDay.id }) else {
            mutationError = "该日已是当前周最后一天，无法与后一日交换"
            return
        }

        let tempDayNumber = days[idx].dayNumber
        days[idx].dayNumber = days[nextIdx].dayNumber
        days[nextIdx].dayNumber = tempDayNumber

        plan.days = days
        plan.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteDay(_ day: TrainingDay, in plan: TrainingPlanRecord) {
        var days = plan.days
        days.removeAll(where: { $0.id == day.id })
        plan.days = days
        plan.updatedAt = Date()
        try? modelContext.save()
    }

    private func startWorkoutSession(for day: TrainingDay, in plan: TrainingPlanRecord) {
        let decision = dashboardVM.dailyTrainingDecision
            ?? TrainingDecisionFallback.conservative(targetSessionTitle: day.title)

        let draft = TrainingSessionDraftBuilder().build(
            day: day,
            decision: decision,
            history: strengthWorkouts,
            scheduledAt: Date()
        )
        activeStrengthDraft = draft
    }

    private func applyAdaptation(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) {
        // Apply modification to day
        var days = plan.days
        if let idx = days.firstIndex(where: { $0.id == adaptation.dayId }) {
            // Apply recommended modification
            if adaptation.adjustment.contains("rest") {
                days[idx].focus = "rest"
                days[idx].durationMinutes = 0
                days[idx].intensity = "low"
            } else if adaptation.adjustment.contains("reduce") {
                days[idx].durationMinutes = max(20, Int(Double(days[idx].durationMinutes) * 0.8))
                days[idx].intensity = "moderate"
            }
            plan.days = days
            plan.updatedAt = Date()
        }
        adaptation.status = "accepted"
        adaptation.acceptedAt = Date()
        try? modelContext.save()
    }

    private func dismissAdaptation(_ adaptation: TrainingPlanAdaptationRecord) {
        adaptation.status = "rejected"
        adaptation.rejectedAt = Date()
        try? modelContext.save()
    }

    private func exercisesInDay(_ day: TrainingDay) -> [WorkoutTemplateExercise] {
        guard let data = day.plannedExercisesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) else {
            return []
        }
        return list
    }

    private func dayName(_ dayNumber: Int) -> String {
        switch dayNumber {
        case 1: return "周一"
        case 2: return "周二"
        case 3: return "周三"
        case 4: return "周四"
        case 5: return "周五"
        case 6: return "周六"
        case 7: return "周日"
        default: return ""
        }
    }

    private func focusName(_ focus: String) -> String {
        switch focus.lowercased() {
        case "cardio": return "有氧"
        case "strength": return "力量"
        case "flexibility": return "柔韧"
        case "rest": return "休息"
        default: return "综合"
        }
    }

    private func intensityName(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return "低强度"
        case "moderate": return "中强度"
        case "high": return "高强度"
        default: return intensity.capitalized
        }
    }

    private func getFocusColor(_ focus: String) -> Color {
        switch focus.lowercased() {
        case "cardio": return VelaTheme.energyColor
        case "strength": return VelaTheme.strainColor
        case "flexibility": return VelaTheme.recoveryColor
        case "rest": return VelaTheme.sleepColor
        default: return VelaTheme.rhythmDeep
        }
    }

    private func getFocusSymbol(_ focus: String) -> String {
        switch focus.lowercased() {
        case "cardio": return "flame.fill"
        case "strength": return "dumbbell.fill"
        case "flexibility": return "figure.cooldown"
        case "rest": return "moon.zzz.fill"
        default: return "figure.run"
        }
    }
}
