import SwiftUI
import SwiftData

struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlanRecord.createdAt, order: .reverse)
    private var plans: [TrainingPlanRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse)
    private var workoutEvents: [WorkoutEventRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var trainingResponses: [TrainingResponseRecord]
    @Query(
        filter: #Predicate<TrainingPlanAdaptationRecord> { $0.status == "proposed" },
        sort: \TrainingPlanAdaptationRecord.createdAt,
        order: .reverse
    )
    private var pendingAdaptations: [TrainingPlanAdaptationRecord]

    @State private var selectedWeek: Int = 1
    @State private var selectedDayForSheet: TrainingDay? = nil
    @State private var mutationError: String?

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive })
    }

    /// Filter pending adaptations to only those matching the active plan.
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
                WorkoutDetailSheet(day: day, plan: plan, onToggle: {
                    toggleCompletion(for: day, in: plan)
                    // Refresh sheet data by updating selected item if still showing
                    if let idx = plan.days.firstIndex(where: { $0.id == day.id }) {
                        selectedDayForSheet = plan.days[idx]
                    }
                })
            }
        }
        .alert("无法更新训练计划", isPresented: Binding(
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

    // MARK: - Pending Adaptations
    private func pendingAdaptationsBanner(plan: TrainingPlanRecord) -> some View {
        let filtered = adaptationsForPlan(plan)
        guard !filtered.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(VelaHeroSurface(tint: VelaTheme.energyColor) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VelaTheme.energyColor)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(VelaTheme.energyColor.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppLanguage.stored.isChinese
                             ? "Vela 建议调整你的计划"
                             : "Vela suggests adjusting your plan"
                        )
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                        Text(AppLanguage.stored.isChinese
                             ? "\(filtered.count) 项训练与今天的身体状态不完全匹配。"
                             : "\(filtered.count) sessions do not fully match today's body state."
                        )
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.fg2)
                    }
                    Spacer()
                    VelaStatusBadge(label: AppLanguage.stored.isChinese ? "待确认" : "Pending", systemImage: "clock.fill", tint: VelaTheme.energyColor)
                }

                ForEach(filtered.prefix(3)) { adaptation in
                    adaptationRow(adaptation, plan: plan)
                }

                if filtered.count > 3 {
                    Text(AppLanguage.stored.isChinese
                         ? "还有 \(filtered.count - 3) 项调整..."
                         : "\(filtered.count - 3) more adjustments..."
                    )
                    .font(.caption)
                    .foregroundStyle(VelaTheme.muted)
                }
            }
        }.appleIntelligenceGlow(isHighlighted: true, radius: 24))
    }

    private func adaptationRow(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: iconForAdjustment(adaptation.adjustment))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.energyColor)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(VelaTheme.energyColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(adaptation.originalDayTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(labelForAdjustment(adaptation.adjustment))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.energyColor)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                trainingAdaptationDetail(
                    title: AppLanguage.stored.isChinese ? "原因" : "Reason",
                    value: adaptation.reason,
                    icon: "list.bullet.clipboard"
                )
                if let alternative = adaptation.suggestedAlternative, !alternative.isEmpty {
                    trainingAdaptationDetail(
                        title: AppLanguage.stored.isChinese ? "建议替代" : "Suggested alternative",
                        value: alternative,
                        icon: "arrow.triangle.swap"
                    )
                }
            }

            HStack(spacing: 10) {
                Button {
                    acceptAdaptation(adaptation, plan: plan)
                } label: {
                    Label(AppLanguage.stored.isChinese ? "接受调整" : "Accept", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Capsule().fill(VelaTheme.accent))
                }
                .buttonStyle(.cardPress)

                Button {
                    rejectAdaptation(adaptation)
                } label: {
                    Label(AppLanguage.stored.isChinese ? "保留原计划" : "Keep original", systemImage: "xmark.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(Capsule().fill(VelaTheme.elevatedBg))
                        .overlay(Capsule().stroke(VelaTheme.borderSoft, lineWidth: 0.7))
                }
                .buttonStyle(.cardPress)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VelaTheme.energyColor.opacity(0.35), lineWidth: 1.0)
        )
        .shadow(color: VelaTheme.energyColor.opacity(0.08), radius: 6, y: 2)
    }

    private func trainingAdaptationDetail(title: String, value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.energyColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.fg2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func acceptAdaptation(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) {
        guard adaptation.planId == plan.id else { return }
        let previousDays = plan.days
        let previousStatus = adaptation.status
        let previousAcceptedAt = adaptation.acceptedAt
        do {
            let manager = AdaptiveTrainingManager()
            guard manager.applyAdaptation(adaptation, to: plan) else {
                mutationError = "当前计划没有可执行的调整位置，原训练计划保持不变。"
                return
            }
            adaptation.status = AdaptationStatus.accepted.rawValue
            adaptation.acceptedAt = Date()
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            plan.days = previousDays
            adaptation.status = previousStatus
            adaptation.acceptedAt = previousAcceptedAt
            mutationError = "本次调整未能保存，原训练计划保持不变。"
        }
    }

    private func rejectAdaptation(_ adaptation: TrainingPlanAdaptationRecord) {
        let previousStatus = adaptation.status
        let previousRejectedAt = adaptation.rejectedAt
        adaptation.status = AdaptationStatus.rejected.rawValue
        adaptation.rejectedAt = Date()
        do {
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            adaptation.status = previousStatus
            adaptation.rejectedAt = previousRejectedAt
            mutationError = "未能保留原计划，请稍后重试。"
        }
    }

    private func iconForAdjustment(_ a: String) -> String {
        switch a {
        case "rest": return "bed.double.fill"
        case "reduce": return "arrow.down.circle.fill"
        case "swap": return "arrow.triangle.swap"
        case "reschedule": return "calendar.badge.clock"
        case "deloadWeek": return "arrow.down.heart.fill"
        default: return "checkmark.circle.fill"
        }
    }

    private func labelForAdjustment(_ a: String) -> String {
        switch a {
        case "rest": return AppLanguage.stored.isChinese ? "建议休息" : "Rest"
        case "reduce": return AppLanguage.stored.isChinese ? "建议减量" : "Reduce"
        case "swap": return AppLanguage.stored.isChinese ? "建议替换" : "Swap"
        case "reschedule": return AppLanguage.stored.isChinese ? "建议改期" : "Reschedule"
        case "deloadWeek": return AppLanguage.stored.isChinese ? "建议减载周" : "Deload Week"
        default: return a
        }
    }

    
    // MARK: - Active Plan View
    private func activePlanView(_ plan: TrainingPlanRecord) -> some View {
        let completedCount = plan.days.filter { $0.isCompleted }.count
        let totalCount = plan.days.count
        let progressRatio = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
        let percent = Int(progressRatio * 100)

        return VStack(alignment: .leading, spacing: 20) {
            // Pending Adaptations Banner
            if !adaptationsForPlan(plan).isEmpty {
                pendingAdaptationsBanner(plan: plan)
            }

            // Plan Header Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Text(plan.goalDescription)
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.fg2)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                Divider().background(Color.black.opacity(0.08))

                // Progress Bar
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(L10n.t("Overall Plan Progress", "课表总进度"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                        
                        Spacer()
                        
                        Text("\(completedCount) / \(totalCount) \(L10n.t("Completed", "已完成")) (\(percent)%)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.recoveryColor)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VelaTheme.accent, VelaTheme.recoveryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                                .shadow(color: VelaTheme.recoveryColor.opacity(0.3), radius: 3)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .padding(16)
            .velaNativeCard(radius: 20)

            planReviewCard(plan)

            // Week Selector Horizontal Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(1...plan.weeksCount, id: \.self) { week in
                        Button(action: {
                            selectedWeek = week
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            Text(L10n.t("Week \(week)", "第 \(week) 周"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selectedWeek == week ? Color.black : VelaTheme.fg2)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedWeek == week ? VelaTheme.accent : VelaTheme.surface)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(selectedWeek == week ? 0 : 0.05), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.cardPress)
                    }
                }
                .padding(.horizontal, 2)
            }

            // Days List
            let daysForWeek = plan.days.filter { $0.weekNumber == selectedWeek }.sorted(by: { $0.dayNumber < $1.dayNumber })
            
            VStack(spacing: 12) {
                ForEach(daysForWeek) { day in
                    workoutCard(day: day, plan: plan)
                }
            }
        }
    }

    private func planReviewCard(_ plan: TrainingPlanRecord) -> some View {
        let review = TrainingPlanReviewService.review(
            plan: plan,
            events: workoutEvents,
            responses: trainingResponses
        )
        return VelaHeroSurface(tint: VelaTheme.recoveryColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("周期复盘", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    Text("\(review.completedSessions)/\(review.scheduledSessions)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(VelaTheme.recoveryColor)
                }

                Text(review.statusTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text(review.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.fg2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    reviewMetric("执行率", "\(Int((review.completionRate * 100).rounded()))%")
                    reviewMetric("有效反馈", "\(review.measuredResponses) 次")
                    reviewMetric(
                        "恢复变化",
                        review.averageRecoveryDelta.map { String(format: "%+.1f", $0) } ?? "待积累"
                    )
                }
                Text("基于计划执行、训练记录和次日反馈的观察性总结，不代表因果关系。")
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.muted)
            }
        }
    }

    private func reviewMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(VelaTheme.muted)
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(VelaTheme.fg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(VelaTheme.elevatedBg, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Workout Card
    private func workoutCard(day: TrainingDay, plan: TrainingPlanRecord) -> some View {
        let focusColor = getFocusColor(day.focus)
        let focusSymbol = getFocusSymbol(day.focus)
        let hasPendingAdaptation = pendingAdaptation(for: day, plan: plan) != nil
        
        return HStack(spacing: 14) {
            Button(action: {
                selectedDayForSheet = day
            }) {
                HStack(spacing: 14) {
                    // Left color-gated bar
                    Rectangle()
                        .fill(day.isCompleted ? VelaTheme.recoveryColor : focusColor)
                        .frame(width: 4)
                        .cornerRadius(2)

                    // Card Body
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            // Day and Focus Label
                            Text(L10n.t("Day \(day.dayNumber) • \(dayName(day.dayNumber))", "第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)

                            Spacer()

                            // Focus Pill
                            HStack(spacing: 3) {
                                Image(systemName: focusSymbol)
                                    .font(.system(size: 8))
                                Text(focusName(day.focus))
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundStyle(focusColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(focusColor.opacity(0.12)))
                        }

                        if hasPendingAdaptation {
                            VelaStatusBadge(
                                label: AppLanguage.stored.isChinese ? "Vela 建议调整" : "Suggested",
                                systemImage: "sparkles",
                                tint: VelaTheme.energyColor
                            )
                        }

                        // Session Title
                        Text(day.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(day.isCompleted ? VelaTheme.muted : VelaTheme.fg)
                            .strikethrough(day.isCompleted, color: VelaTheme.muted)

                        // Subtitle / Timing
                        if day.focus == "rest" {
                            Text(L10n.t("Rest & Restore Energy", "休息以恢复能量储蓄"))
                                .font(.caption2)
                                .foregroundStyle(VelaTheme.muted)
                        } else {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text("\(day.durationMinutes) \(L10n.t("mins", "分钟"))")
                                }
                                
                                Text("•")
                                
                                Text(intensityName(day.intensity))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(getIntensityColor(day.intensity).opacity(0.12)))
                                    .foregroundStyle(getIntensityColor(day.intensity))
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VelaTheme.fg2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.cardPress)

            // Checkbox Circle
            Button(action: {
                toggleCompletion(for: day, in: plan)
            }) {
                ZStack {
                    Circle()
                        .stroke(day.isCompleted ? VelaTheme.recoveryColor : Color.black.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if day.isCompleted {
                        Circle()
                            .fill(VelaTheme.recoveryColor)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.black)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .fill(day.isCompleted ? VelaTheme.surface.opacity(0.4) : VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .stroke(day.isCompleted ? VelaTheme.recoveryColor.opacity(0.12) : Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .appleIntelligenceGlow(isHighlighted: hasPendingAdaptation, radius: VelaTheme.radiusCardLarge)
    }

    // MARK: - Empty Plan View (Bevel CTA Style)
    private var emptyPlanView: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            ZStack {
                Circle()
                    .fill(VelaTheme.accent.opacity(0.08))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 32))
                    .foregroundStyle(VelaTheme.accent)
                    .shadow(color: VelaTheme.accent.opacity(0.4), radius: 6)
            }

            VelaGlassCard(padding: 24, cornerRadius: 20) {
                VStack(spacing: 16) {
                    Text(L10n.t("Your Training Schedule", "你的智能课表"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                    
                    Text(L10n.t("No active training plan. Ask your Coach Agent to generate a multi-week athletic progression program tailored to your recovery, sleep, and fitness goals.", "当前没有激活的训练课表。让你的 AI 教练根据你的恢复、睡眠以及运动目标，为你定制一份长期的多周智能训练计划吧！"))
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.fg2)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }

            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "I want to start a personalized training program. Can you create a 4-week athletic progression plan tailored to my fitness level and save it using your tool?",
                    "我想开始一份专属训练计划，你能根据我的身体状况为我量身定制一份 4 周的智能训练课表，并用工具帮我保存和启用吗？"
                ))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                    Text(L10n.t("Ask AI Coach to Generate Plan", "让 AI 教练制定专属课表"))
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(Color.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Capsule().fill(VelaTheme.accent))
                .shadow(color: VelaTheme.accent.opacity(0.3), radius: 8)
            }
            .buttonStyle(.cardPress)

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Toggle Database Completion
    private func toggleCompletion(for day: TrainingDay, in plan: TrainingPlanRecord) {
        var updatedDays = plan.days
        if let index = updatedDays.firstIndex(where: { $0.id == day.id }) {
            let previousDays = plan.days
            let wasCompleted = updatedDays[index].isCompleted
            updatedDays[index].isCompleted.toggle()
            updatedDays[index].completedAt = updatedDays[index].isCompleted ? Date() : nil
            plan.days = updatedDays

            do {
                try modelContext.save()
                VelaAppState.shared.markLocalDataChanged()
                if !wasCompleted {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                } else {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            } catch {
                plan.days = previousDays
                mutationError = "训练完成状态未能保存，请稍后重试。"
            }
        }
    }

    // MARK: - Helpers
    private func dayName(_ dayNumber: Int) -> String {
        switch dayNumber {
        case 1: return L10n.t("Monday", "周一")
        case 2: return L10n.t("Tuesday", "周二")
        case 3: return L10n.t("Wednesday", "周三")
        case 4: return L10n.t("Thursday", "周四")
        case 5: return L10n.t("Friday", "周五")
        case 6: return L10n.t("Saturday", "周六")
        case 7: return L10n.t("Sunday", "周日")
        default: return ""
        }
    }

    private func getFocusColor(_ focus: String) -> Color {
        switch focus.lowercased() {
        case "cardio": return VelaTheme.strainColor
        case "strength": return VelaTheme.energyColor
        case "flexibility": return VelaTheme.accent
        case "rest": return VelaTheme.sleepColor
        default: return VelaTheme.accent
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

    private func focusName(_ focus: String) -> String {
        switch focus.lowercased() {
        case "cardio": return L10n.t("Cardio", "有氧")
        case "strength": return L10n.t("Strength", "力量")
        case "flexibility": return L10n.t("Flexibility", "拉伸")
        case "rest": return L10n.t("Rest", "休息")
        default: return focus.capitalized
        }
    }

    private func intensityName(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return L10n.t("Low", "低强度")
        case "moderate": return L10n.t("Moderate", "中强度")
        case "high": return L10n.t("High", "高强度")
        default: return intensity.capitalized
        }
    }

    private func getIntensityColor(_ intensity: String) -> Color {
        switch intensity.lowercased() {
        case "low": return VelaTheme.recoveryColor
        case "moderate": return VelaTheme.energyColor
        case "high": return VelaTheme.stressColor
        default: return VelaTheme.fg2
        }
    }
}
