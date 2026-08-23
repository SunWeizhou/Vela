import SwiftUI
import SwiftData

struct VelaTrainingPlanView: View {
    @Query(sort: \TrainingPlanRecord.updatedAt, order: .reverse)
    private var plans: [TrainingPlanRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var events: [WorkoutEventRecord]
    // 算法打通（批次 B）：BodyInterpreterEngine + AdaptiveTrainingEngine 产出的
    // 计划调整提案（TrainingPlanAdaptationRecord）此前写在库里但没有任何页面读取——
    // 旧日历页挂在死导航下。这里接上：今日提案展示 + 用户确认（ADR 0008）。
    @Query(
        filter: #Predicate<TrainingPlanAdaptationRecord> { $0.status == "proposed" },
        sort: \TrainingPlanAdaptationRecord.createdAt
    )
    private var pendingAdaptations: [TrainingPlanAdaptationRecord]
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    /// 今天的正式运营计划（决策面板数据源；无则退回恢复信号说明）。
    @State private var todayOperatingPlan: DailyOperatingPlanRecord?

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: \.isActive) ?? plans.first
    }

    /// 深度专项批次 4：提案区覆盖今日 + 未来未完成训练日——
    /// 本机提案（今日）与 AI 练后边界建议（下次训练日）都能被看到并确认。
    private var planAdaptations: [TrainingPlanAdaptationRecord] {
        guard let activePlan else { return [] }
        let upcomingDayIds = Set(activePlan.days.filter { !$0.isCompleted }.map(\.id))
        return pendingAdaptations.filter {
            $0.planId == activePlan.id && upcomingDayIds.contains($0.dayId)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                planHero

                VStack(alignment: .leading, spacing: 14) {
                    VelaRhythmSectionHeader(
                        eyebrow: "",
                        title: "训练轮转",
                        actionTitle: nil,
                        action: {}
                    )
                    planRows
                }

                todayDecisionSection
                if !planAdaptations.isEmpty {
                    adaptationProposalsSection
                }
                coachActions
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("训练计划")
        .velaRhythmDetailChrome()
        .task {
            fetchTodayOperatingPlan()
        }
        .onChange(of: dashboardVM.selectedDate) {
            fetchTodayOperatingPlan()
        }
    }

    private func fetchTodayOperatingPlan() {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(
            for: dashboardVM.selectedDate,
            calendar: .current
        )
        var descriptor = FetchDescriptor<DailyOperatingPlanRecord>(
            predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == identifier },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        todayOperatingPlan = (try? modelContext.fetch(descriptor))?.first
    }

    private var planHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(activePlan?.title ?? "建立可调整的训练轮转")
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(VelaTheme.rhythmInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(planSummary)
                .font(.system(.footnote, design: .default))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(3)

            HStack(spacing: 0) {
                planMetric("已完成", activePlan.map { "\($0.days.filter(\.isCompleted).count)" } ?? "—")
                metricDivider
                planMetric("训练日", activePlan.map { "\($0.days.count)" } ?? "—")
                metricDivider
                planMetric("周期", activePlan.map { "\($0.weeksCount) 周" } ?? "—")
            }
        }
        .padding(.vertical, 10)
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [VelaTheme.rhythmGlow.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 170
            )
            .frame(width: 220, height: 190)
            .offset(x: 30, y: -30)
        }
    }

    @ViewBuilder
    private var planRows: some View {
        if let activePlan, !activePlan.days.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(activePlan.days.enumerated()), id: \.element.id) { index, day in
                    PlanDayRow(day: day, events: events)
                    if index < activePlan.days.count - 1 {
                        Rectangle()
                            .fill(VelaTheme.rhythmMist)
                            .frame(height: 0.75)
                            .padding(.leading, 59)
                    }
                }
            }
            .padding(.horizontal, 15)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("目前没有活动计划。Vela 可以根据恢复、目标与最近训练建立第一版。")
                    .font(.system(.footnote, design: .default))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    /// 今天如何调整：优先展示当天正式决策（容量/RPE 边界 + 理由），
    /// 没有运营计划时退回恢复信号说明——不再是一句通用文案。
    private var todayDecisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今天如何调整")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInk)

            Text(metricContextLine)
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let todayOperatingPlan, let payload = todayOperatingPlan.operatingPlanPayload {
                HStack(spacing: 8) {
                    Text(decisionLabel(payload.decision))
                        .font(.system(.caption, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(VelaTheme.rhythmDeep, in: Capsule())
                    Text(boundaryText(payload))
                        .font(.system(.caption, design: .default, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }

                if !payload.summary.isEmpty {
                    Text(payload.summary)
                        .font(.system(.footnote, design: .default))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                let reasons = todayOperatingPlan.operatingPlanReasons
                if !reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(reasons.prefix(3).enumerated()), id: \.offset) { _, reason in
                            HStack(alignment: .top, spacing: 7) {
                                Circle()
                                    .fill(VelaTheme.rhythmDeep.opacity(0.6))
                                    .frame(width: 5, height: 5)
                                    .padding(.top, 5)
                                Text(reason)
                                    .font(.system(.caption, design: .default))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            } else {
                Text(adaptationText)
                    .font(.system(.footnote, design: .default))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(17)
        .background(VelaTheme.rhythmMist.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func decisionLabel(_ decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: return "保持计划"
        case .reduce: return "建议减量"
        case .swap: return "建议换部位"
        case .rest: return "恢复优先"
        }
    }

    private func boundaryText(_ payload: DailyOperatingPlanPayload) -> String {
        guard payload.decision != .rest else { return "优先恢复 · 轻活动" }
        return "容量 \(Int((payload.volumeMultiplier * 100).rounded()))% · RPE ≤ \(payload.intensityCap)"
    }

    /// 算法打通（批次 B）：今日的 Vela 调整提案（BodyInterpreterEngine 产出）。
    /// 采纳 → 应用到计划；拒绝 → 标记 rejected。ADR 0008：任何计划修改由用户确认。
    private var adaptationProposalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("Vela 的调整提案")
                    .font(.system(.title3, design: .default, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
            }
            ForEach(planAdaptations) { adaptation in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(adaptationLabel(adaptation.adjustment))
                            .font(.system(.caption, design: .default, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeepOn)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(VelaTheme.rhythmDeep, in: Capsule())
                        Text(adaptation.originalDayTitle)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineLimit(1)
                    }
                    Text(adaptation.reason)
                        .font(.system(.footnote, design: .default))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    if let alternative = adaptation.suggestedAlternative, !alternative.isEmpty {
                        Text(alternative)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack(spacing: 10) {
                        Button {
                            acceptAdaptation(adaptation)
                        } label: {
                            Label("采纳", systemImage: "checkmark")
                                .font(.system(.footnote, design: .default, weight: .semibold))
                                .foregroundStyle(VelaTheme.rhythmDeepOn)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(VelaTheme.rhythmDeep, in: Capsule())
                        }
                        .buttonStyle(.cardPress)
                        Button {
                            rejectAdaptation(adaptation)
                        } label: {
                            Label("拒绝", systemImage: "xmark")
                                .font(.system(.footnote, design: .default, weight: .medium))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(VelaTheme.rhythmMist, in: Capsule())
                        }
                        .buttonStyle(.cardPress)
                        Spacer()
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }
            }
            Text("采纳后计划即时更新，今日决策面板将在下次刷新时重算。")
                .font(.system(.caption2, design: .default))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
    }

    private func acceptAdaptation(_ adaptation: TrainingPlanAdaptationRecord) {
        guard let activePlan else { return }
        if AdaptiveTrainingManager().applyAdaptation(adaptation, to: activePlan) {
            adaptation.status = AdaptationStatus.accepted.rawValue
            adaptation.acceptedAt = Date()
            try? modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        }
    }

    private func rejectAdaptation(_ adaptation: TrainingPlanAdaptationRecord) {
        adaptation.status = AdaptationStatus.rejected.rawValue
        adaptation.rejectedAt = Date()
        try? modelContext.save()
    }

    private func adaptationLabel(_ adjustment: String) -> String {
        switch adjustment {
        case "keep": return "保持"
        case "reduce": return "减量"
        case "swap": return "替换"
        case "rest": return "休息"
        case "reschedule": return "改期"
        case "deloadWeek": return "减载周"
        default: return adjustment
        }
    }

    private var coachActions: some View {
        VStack(spacing: 10) {
            Button {
                VelaAppState.shared.routeToCoach(question: coachPlanQuestion)
            } label: {
                Label("和 Vela 调整计划", systemImage: "sparkles")
                    .font(.system(.subheadline, design: .default, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeepOn)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.cardPress)

            Text("Vela 只提出方案；任何影响后续安排的修改都由你确认。")
                .font(.system(.caption2, design: .default))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var planSummary: String {
        guard let activePlan else {
            return "计划不是日历任务，而是背、胸、肩、腿与小肌群之间可移动的下一站。"
        }
        if !activePlan.goalDescription.isEmpty { return activePlan.goalDescription }
        return "保留训练方向，同时允许恢复、科研压力与临时有氧改变当天落点。"
    }

    /// 计划页发给 Coach 的问题：显式带上三指标与身体模型，避免 Agent
    /// 只看到计划文本、脱离当前身体证据。
    private var coachPlanQuestion: String {
        let dashboard = dashboardVM.dashboard
        let recovery = dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--"
        let strain = dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--"
        let stress = dashboard.stress.hasData ? "\(Int(dashboard.stress.stressIndex.rounded()))" : "--"
        return "请根据我最新的恢复 \(recovery)、负荷 \(strain)、压力 \(stress)、局部疲劳、身体模型与健康档案，提出未来一周训练轮转的调整方案；修改前先让我确认。"
    }

    /// 计划页的统一指标依据：恢复、负荷、压力直接来自 DashboardSummary，
    /// 与训练页状态卡和 TrainingDecisionKernel 同源。
    private var metricContextLine: String {
        let dashboard = dashboardVM.dashboard
        var parts: [String] = []
        if dashboard.recovery.hasData {
            parts.append("恢复 \(Int(dashboard.recovery.score.rounded()))")
        }
        if dashboard.strain.hasData {
            let range = dashboard.strain.recommendedRange
            parts.append("负荷 \(Int(dashboard.strain.score.rounded()))（目标 \(range.lowerBound)-\(range.upperBound)）")
        }
        if dashboard.stress.hasData {
            parts.append("压力 \(Int(dashboard.stress.stressIndex.rounded()))")
        }
        return parts.isEmpty ? "恢复、负荷与压力信号尚未同步，先使用保守训练窗口。" : "依据：" + parts.joined(separator: " · ")
    }

    private var adaptationText: String {
        let dashboard = dashboardVM.dashboard
        guard dashboard.recovery.hasData else {
            return "恢复信号尚未同步，无法给出个性化计划调整。先同步 Apple 健康，同时按保守窗口执行。"
        }
        let recovery = dashboard.recovery.score
        let stress = dashboard.stress.hasData ? Int(dashboard.stress.stressIndex.rounded()) : nil
        let loadHigh = dashboard.strain.hasData
            && dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound)
        if recovery >= 70, (stress ?? 0) < 75, !loadHigh {
            return "恢复、压力与负荷支持保留计划方向。训练时按 Apple Watch 记录，容量与强度仍以身体边界为准。"
        }
        return "当前恢复/压力/负荷至少有一项不支持满量执行。建议保留训练习惯但降低容量，或换到疲劳更低的部位；如精神压力明显，恢复也算完成计划。"
    }

    private func planMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .default, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(VelaTheme.rhythmMist)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }
}

// MARK: - Expandable plan day row

/// 计划日行：点开看计划动作、实际执行记录与依从度——计划与事实的闭环。
private struct PlanDayRow: View {
    let day: TrainingDay
    let events: [WorkoutEventRecord]

    @State private var isExpanded = false

    private var plannedExercises: [WorkoutTemplateExercise] {
        guard let data = day.plannedExercisesJSON.data(using: .utf8),
              let list = try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data) else {
            return []
        }
        return list
    }

    private var linkedEvents: [WorkoutEventRecord] {
        events.filter { $0.linkedTrainingPlanDayId == day.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 13) {
                    ZStack {
                        Circle()
                            .fill(day.isCompleted ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist)
                        if day.isCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(day.dayNumber)")
                                .font(.system(.caption, design: .default, weight: .semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                        }
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 7) {
                            Text(day.title)
                                .font(.system(.footnote, design: .default, weight: .semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                                .lineLimit(1)

                            if day.isCompleted {
                                Text("已完成")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)
                            } else if let adherence = day.adherenceScore {
                                Text("依从 \(Int((adherence * 100).rounded()))%")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmDeep)
                            }
                        }

                        Text(day.description.isEmpty ? "边界会在训练当天根据状态调整" : day.description)
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Text(day.focus == "rest" ? "恢复" : "\(day.durationMinutes)′")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.7))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .frame(width: 14, height: 14)
                }
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(day.title)，点按查看计划动作与实际执行")

            if isExpanded {
                expandedPanel
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 11) {
            if !plannedExercises.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("计划动作")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    ForEach(Array(plannedExercises.prefix(6).enumerated()), id: \.element.id) { index, exercise in
                        Text("• \(exercise.name) — \(exercise.targetSets) 组 × \(exercise.targetReps)")
                            .font(.system(.caption, design: .default, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInk)
                    }
                    if plannedExercises.count > 6 {
                        Text("另有 \(plannedExercises.count - 6) 个动作")
                            .font(.system(.caption2, design: .default))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
            }

            if !linkedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("实际执行")
                        .font(.system(.caption2, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    ForEach(Array(linkedEvents.prefix(3).enumerated()), id: \.element.id) { _, event in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(VelaTheme.rhythmDeep)
                                .frame(width: 5, height: 5)
                            Text(eventText(event))
                                .font(.system(.caption, design: .default))
                                .foregroundStyle(VelaTheme.rhythmInk)
                        }
                    }
                }
            } else if !day.isCompleted {
                Text("还没有关联的实际训练记录。")
                    .font(.system(.caption2, design: .default))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            if day.isCompleted, let completedAt = day.completedAt {
                Text("完成于 \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.rhythmMist.opacity(0.45), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.leading, 47)
    }

    private func eventText(_ event: WorkoutEventRecord) -> String {
        let date = event.startedAt.formatted(date: .abbreviated, time: .shortened)
        let name = event.activityType.isEmpty ? "训练" : event.activityType
        return "\(date) · \(name)"
    }
}
