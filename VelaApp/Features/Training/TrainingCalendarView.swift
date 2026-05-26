import SwiftUI
import SwiftData

struct TrainingCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrainingPlanRecord.createdAt, order: .reverse)
    private var plans: [TrainingPlanRecord]
    @Query(
        filter: #Predicate<TrainingPlanAdaptationRecord> { $0.status == "proposed" },
        sort: \TrainingPlanAdaptationRecord.createdAt,
        order: .reverse
    )
    private var pendingAdaptations: [TrainingPlanAdaptationRecord]

    @State private var selectedWeek: Int = 1
    @State private var selectedDayForSheet: TrainingDay? = nil

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive })
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
        VStack(alignment: .leading, spacing: 8) {
            Label(
                AppLanguage.stored.isChinese
                    ? "Vela 建议调整 \(pendingAdaptations.count) 项训练"
                    : "Vela suggests \(pendingAdaptations.count) training adjustments",
                systemImage: "exclamationmark.bubble.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(VelaTheme.energy)

            ForEach(pendingAdaptations.prefix(3)) { adaptation in
                adaptationRow(adaptation, plan: plan)
            }

            if pendingAdaptations.count > 3 {
                Text(AppLanguage.stored.isChinese
                     ? "还有 \(pendingAdaptations.count - 3) 项调整..."
                     : "\(pendingAdaptations.count - 3) more adjustments..."
                )
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.energy.opacity(0.06)))
    }

    private func adaptationRow(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconForAdjustment(adaptation.adjustment))
                .font(.caption)
                .foregroundStyle(VelaTheme.energy)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(adaptation.originalDayTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(labelForAdjustment(adaptation.adjustment) + ": " + adaptation.reason)
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    acceptAdaptation(adaptation, plan: plan)
                } label: {
                    Text(AppLanguage.stored.isChinese ? "接受" : "Accept")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(VelaTheme.accent))
                }

                Button {
                    rejectAdaptation(adaptation)
                } label: {
                    Text(AppLanguage.stored.isChinese ? "忽略" : "Ignore")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }
        }
    }

    private func acceptAdaptation(_ adaptation: TrainingPlanAdaptationRecord, plan: TrainingPlanRecord) {
        do {
            let manager = AdaptiveTrainingManager()
            try manager.applyAdaptation(adaptation, to: plan, modelContext: modelContext)
            adaptation.status = AdaptationStatus.accepted.rawValue
            adaptation.acceptedAt = Date()
            try modelContext.save()
        } catch {
            print("Failed to accept adaptation: \(error)")
        }
    }

    private func rejectAdaptation(_ adaptation: TrainingPlanAdaptationRecord) {
        adaptation.status = AdaptationStatus.rejected.rawValue
        adaptation.rejectedAt = Date()
        try? modelContext.save()
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
            if !pendingAdaptations.isEmpty {
                pendingAdaptationsBanner(plan: plan)
            }

            // Plan Header Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Text(plan.goalDescription)
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
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
                            .foregroundStyle(VelaTheme.mutedText)
                        
                        Spacer()
                        
                        Text("\(completedCount) / \(totalCount) \(L10n.t("Completed", "已完成")) (\(percent)%)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.recovery)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 6)
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VelaTheme.accent, VelaTheme.recovery],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                                .shadow(color: VelaTheme.recovery.opacity(0.3), radius: 3)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .heroCardSurface(accent: VelaTheme.accent)

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
                                .foregroundStyle(selectedWeek == week ? Color.black : VelaTheme.secondaryText)
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

    // MARK: - Workout Card
    private func workoutCard(day: TrainingDay, plan: TrainingPlanRecord) -> some View {
        let focusColor = getFocusColor(day.focus)
        let focusSymbol = getFocusSymbol(day.focus)
        
        return HStack(spacing: 14) {
            // Left color-gated bar
            Rectangle()
                .fill(day.isCompleted ? VelaTheme.recovery : focusColor)
                .frame(width: 4)
                .cornerRadius(2)

            // Card Body
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    // Day and Focus Label
                    Text(L10n.t("Day \(day.dayNumber) • \(dayName(day.dayNumber))", "第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))"))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.mutedText)

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

                // Session Title
                Text(day.title)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(day.isCompleted ? VelaTheme.mutedText : VelaTheme.primaryText)
                    .strikethrough(day.isCompleted, color: VelaTheme.mutedText)

                // Subtitle / Timing
                if day.focus == "rest" {
                    Text(L10n.t("Rest & Restore Energy", "休息以恢复能量储蓄"))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
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
                    .foregroundStyle(VelaTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Checkbox Circle
            Button(action: {
                toggleCompletion(for: day, in: plan)
            }) {
                ZStack {
                    Circle()
                        .stroke(day.isCompleted ? VelaTheme.recovery : Color.black.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 24, height: 24)
                    
                    if day.isCompleted {
                        Circle()
                            .fill(VelaTheme.recovery)
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
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .fill(day.isCompleted ? VelaTheme.surface.opacity(0.4) : VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .stroke(day.isCompleted ? VelaTheme.recovery.opacity(0.12) : Color.black.opacity(0.04), lineWidth: 0.5)
        )
        .onTapGesture {
            selectedDayForSheet = day
        }
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

            VStack(spacing: 8) {
                Text(L10n.t("Your Training Schedule", "你的智能课表"))
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                
                Text(L10n.t("No active training plan. Ask your Coach Agent to generate a multi-week athletic progression program tailored to your recovery, sleep, and fitness goals.", "当前没有激活的训练课表。让你的 AI 教练根据你的恢复、睡眠以及运动目标，为你定制一份长期的多周智能训练计划吧！"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 10)
            }
            .cardSurface()

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

            Spacer().frame(height: 40)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Toggle Database Completion
    private func toggleCompletion(for day: TrainingDay, in plan: TrainingPlanRecord) {
        var updatedDays = plan.days
        if let index = updatedDays.firstIndex(where: { $0.id == day.id }) {
            let wasCompleted = updatedDays[index].isCompleted
            updatedDays[index].isCompleted.toggle()
            updatedDays[index].completedAt = updatedDays[index].isCompleted ? Date() : nil
            plan.days = updatedDays
            
            // Trigger beautiful haptic response
            if !wasCompleted {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            
            try? modelContext.save()
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
        case "cardio": return VelaTheme.strain
        case "strength": return VelaTheme.energy
        case "flexibility": return VelaTheme.accent
        case "rest": return VelaTheme.sleep
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
        case "low": return VelaTheme.recovery
        case "moderate": return VelaTheme.energy
        case "high": return VelaTheme.stress
        default: return VelaTheme.secondaryText
        }
    }
}

// MARK: - Workout Detail Sheet Component
struct WorkoutDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let day: TrainingDay
    let plan: TrainingPlanRecord
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            VelaTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header Sheet Bar
                HStack {
                    Text(L10n.t("Workout Session Details", "计划日程详情"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title & Day Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.t("Week \(day.weekNumber) Day \(day.dayNumber) • \(dayName(day.dayNumber))", "第 \(day.weekNumber) 周第 \(day.dayNumber) 天 • \(dayName(day.dayNumber))"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.mutedText)
                            
                            Text(day.title)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(VelaTheme.primaryText)
                        }

                        // Badges Row
                        HStack(spacing: 8) {
                            badgeView(text: focusName(day.focus), symbol: getFocusSymbol(day.focus), color: getFocusColor(day.focus))
                            
                            if day.focus != "rest" {
                                badgeView(text: "\(day.durationMinutes) \(L10n.t("mins", "分钟"))", symbol: "clock", color: VelaTheme.secondaryText)
                                badgeView(text: intensityName(day.intensity), symbol: "waveform.path.ecg", color: getIntensityColor(day.intensity))
                            }
                        }

                        Divider().background(Color.black.opacity(0.08))

                        // Workout Routine / Description Area
                        VStack(alignment: .leading, spacing: 12) {
                            Label(L10n.t("Training Routine", "训练内容及课表细则"), systemImage: "text.alignleft")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)

                            Text(day.description)
                                .font(.system(.body, design: .rounded))
                                .foregroundStyle(VelaTheme.secondaryText)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(VelaTheme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                        )

                        Spacer().frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                }

                // Check-off Action Bottom Bar
                VStack(spacing: 12) {
                    Divider().background(Color.black.opacity(0.08))
                        .padding(.bottom, 8)
                    
                    Button(action: {
                        onToggle()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: day.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16, weight: .bold))
                            
                            Text(day.isCompleted ? L10n.t("Workout Completed", "此日训练已打卡") : L10n.t("Mark Workout as Completed", "完成此日训练打卡"))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(day.isCompleted ? VelaTheme.recovery : VelaTheme.accent)
                        .cornerRadius(14)
                        .shadow(color: (day.isCompleted ? VelaTheme.recovery : VelaTheme.accent).opacity(0.2), radius: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(VelaTheme.surface.opacity(0.4))
            }
        }
    }

    // MARK: - Badge Helper View
    private func badgeView(text: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9))
            Text(text)
                .font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.08)))
        .overlay(Capsule().stroke(color.opacity(0.12), lineWidth: 0.5))
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
        case "cardio": return VelaTheme.strain
        case "strength": return VelaTheme.energy
        case "flexibility": return VelaTheme.accent
        case "rest": return VelaTheme.sleep
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
        case "low": return VelaTheme.recovery
        case "moderate": return VelaTheme.energy
        case "high": return VelaTheme.stress
        default: return VelaTheme.secondaryText
        }
    }
}
