import SwiftUI
import SwiftData

struct BodyModelEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    
    private var onboarding: OnboardingState? { onboardingStates.first }
    
    @State private var primaryGoal = "performance"
    @State private var trainingStyle = "strength"
    @State private var weeklyTrainingDays = 3
    @State private var sessionDurationMinutes = 45
    @State private var experienceLevel = "intermediate"
    @State private var coachStyle = "direct"
    @State private var hasGym = true
    @State private var hasHomeEquipment = true
    @State private var hasBodyweight = true
    @State private var saveError: String?
    
    var body: some View {
        Form {
            Section(header: Text("健身目标")) {
                Picker("主要目标", selection: $primaryGoal) {
                    Text(localizedOnboardingGoal("performance")).tag("performance")
                    Text(localizedOnboardingGoal("muscle_gain")).tag("muscle_gain")
                    Text(localizedOnboardingGoal("fat_loss")).tag("fat_loss")
                    Text(localizedOnboardingGoal("health")).tag("health")
                }
                .pickerStyle(.menu)
                
                Picker("体能经验", selection: $experienceLevel) {
                    Text(localizedOnboardingExperience("beginner")).tag("beginner")
                    Text(localizedOnboardingExperience("intermediate")).tag("intermediate")
                    Text(localizedOnboardingExperience("advanced")).tag("advanced")
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("训练偏好")) {
                Picker("训练风格", selection: $trainingStyle) {
                    Text(localizedOnboardingTrainingStyle("mixed")).tag("mixed")
                    Text(localizedOnboardingTrainingStyle("strength")).tag("strength")
                    Text(localizedOnboardingTrainingStyle("cardio")).tag("cardio")
                    Text(localizedOnboardingTrainingStyle("yoga")).tag("yoga")
                }
                .pickerStyle(.menu)
                
                Stepper(value: $weeklyTrainingDays, in: 1...7) {
                    HStack {
                        Text("每周频次")
                        Spacer()
                        Text("\(weeklyTrainingDays) 次 / 周")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(VelaTheme.accent)
                    }
                }
                
                Stepper(value: $sessionDurationMinutes, in: 20...120, step: 5) {
                    HStack {
                        Text("单次时长")
                        Spacer()
                        Text("\(sessionDurationMinutes) 分钟")
                            .font(.system(.body, design: .monospaced).bold())
                            .foregroundStyle(VelaTheme.accent)
                    }
                }
            }
            
            Section(header: Text("训练设备")) {
                Toggle(localizedOnboardingEquipment("gym"), isOn: $hasGym)
                    .tint(VelaTheme.accent)
                Toggle(localizedOnboardingEquipment("home_equipment"), isOn: $hasHomeEquipment)
                    .tint(VelaTheme.accent)
                Toggle(localizedOnboardingEquipment("bodyweight"), isOn: $hasBodyweight)
                    .tint(VelaTheme.accent)
            }
            
            Section(header: Text("教练指导")) {
                Picker("指导风格", selection: $coachStyle) {
                    Text(localizedOnboardingCoachStyle("direct")).tag("direct")
                    Text(localizedOnboardingCoachStyle("encouraging")).tag("encouraging")
                    Text(localizedOnboardingCoachStyle("explanatory")).tag("explanatory")
                }
                .pickerStyle(.segmented)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .scrollContentBackground(.hidden)
        .navigationTitle("编辑身体模型")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    if saveEdits() {
                        dismiss()
                    }
                }
                .bold()
                .foregroundStyle(VelaTheme.accent)
            }
        }
        .onAppear {
            loadOnboardingState()
        }
        .alert("身体模型未保存", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "")
        }
    }
    
    private func loadOnboardingState() {
        guard let state = onboarding else { return }
        primaryGoal = state.goalProfile.primaryGoal
        experienceLevel = state.goalProfile.experienceLevel
        trainingStyle = state.trainingPreference.trainingStyle
        weeklyTrainingDays = state.trainingPreference.weeklyTrainingDays
        sessionDurationMinutes = state.trainingPreference.sessionDurationMinutes
        
        let equip = state.equipmentProfile.equipment
        hasGym = equip.contains("gym")
        hasHomeEquipment = equip.contains("home_equipment")
        hasBodyweight = equip.contains("bodyweight")
        
        coachStyle = state.coachingPreference.style
    }
    
    private func saveEdits() -> Bool {
        let state = onboarding ?? OnboardingState()
        state.goalProfile = UserGoalProfile(
            primaryGoal: primaryGoal,
            secondaryGoals: [trainingStyle],
            experienceLevel: experienceLevel,
            bodyConcerns: []
        )
        state.trainingPreference = TrainingPreferenceProfile(
            trainingStyle: trainingStyle,
            weeklyTrainingDays: weeklyTrainingDays,
            sessionDurationMinutes: sessionDurationMinutes,
            preferredTrainingDays: []
        )
        
        var equip: [String] = []
        if hasGym { equip.append("gym") }
        if hasHomeEquipment { equip.append("home_equipment") }
        if hasBodyweight { equip.append("bodyweight") }
        
        state.equipmentProfile = EquipmentProfile(
            equipment: equip,
            scheduleNotes: "\(weeklyTrainingDays)x weekly, \(sessionDurationMinutes)m sessions"
        )
        state.coachingPreference = CoachingPreference(
            style: coachStyle,
            explanationDepth: coachStyle == "explanatory" ? "detailed" : "balanced",
            language: "zh-Hans"
        )
        state.currentStep = "completed"
        state.isCompleted = true
        state.completedAt = state.completedAt ?? Date()
        state.updatedAt = Date()
        
        if onboardingStates.isEmpty {
            modelContext.insert(state)
        }
        
        do {
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
            Task {
                await dashboardVM.refresh(modelContext: modelContext, force: true)
            }
            return true
        } catch {
            modelContext.rollback()
            saveError = "本次修改未能写入本机资料，请重试。"
            return false
        }
    }
}

struct BaselineRangeIndicator: View {
    let today: Double?
    let baseline: Double?
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let baseVal = baseline {
                    Text("基线: \(Int(baseVal))\(unit)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                } else {
                    Text("个人基线积累中（至少 7 天）")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                
                Spacer()
                
                if let todayVal = today {
                    Text("今日当前: \(Int(todayVal))\(unit)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                } else {
                    Text("今日当前: --")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            
            if let base = baseline {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(VelaTheme.separatorSoft)
                            .frame(height: 6)

                        let width = geo.size.width
                        let startPct = 0.35
                        let endPct = 0.65
                        Capsule()
                            .fill(VelaTheme.accent.opacity(0.18))
                            .frame(width: width * (endPct - startPct), height: 6)
                            .offset(x: width * startPct)
                        
                        Rectangle()
                            .fill(VelaTheme.muted)
                            .frame(width: 1.5, height: 10)
                            .offset(x: width * 0.5, y: -2)
                        
                        if let tod = today {
                            let pct = 0.5 + (tod - base) / (base * 0.4)
                            let clampedPct = min(max(pct, 0.05), 0.95)
                            Circle()
                                .fill(VelaTheme.accent)
                                .frame(width: 10, height: 10)
                                .shadow(color: VelaTheme.accent.opacity(0.5), radius: 3)
                                .offset(x: width * clampedPct - 5, y: -2)
                        }
                    }
                }
                .frame(height: 10)
            } else {
                Text("收集到足够的历史有效样本后，会在这里显示个人范围。")
                    .font(.system(size: 10))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
    }
}

struct BodyModelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    @State private var journalEntries: [JournalEntryRecord] = []
    @State private var dailySummaries: [DailyHealthSummaryRecord] = []
    @State private var strengthWorkouts: [StrengthWorkoutRecord] = []
    @State private var trainingResponses: [TrainingResponseRecord] = []
    
    private var onboarding: OnboardingState? { onboardingStates.first }
    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var hasCompletedProfile: Bool { onboarding?.isCompleted == true }
    private var staticGoalText: String {
        hasCompletedProfile ? displayGoal(onboarding?.goalProfile.primaryGoal ?? "unknown") : "尚未设置"
    }
    private var staticExperienceText: String {
        hasCompletedProfile ? displayExperience(onboarding?.goalProfile.experienceLevel ?? "unknown") : "待补充"
    }
    private var staticFrequencyText: String {
        guard hasCompletedProfile else { return "待设置" }
        return "\(onboarding?.trainingPreference.weeklyTrainingDays ?? 0)次/周 · \(onboarding?.trainingPreference.sessionDurationMinutes ?? 0)分钟/次"
    }
    private var staticCoachStyleText: String {
        hasCompletedProfile ? displayCoachingStyle(onboarding?.coachingPreference.style ?? "unknown") : "待设置"
    }
    private var healthProfileSummary: String {
        var values: [String] = []
        let age = UserProfileSettings.age() ?? dashboard.extendedMetrics.age
        let weight = UserProfileSettings.weightKilograms() ?? dashboard.bodyMetrics.weightKilograms
        let height = UserProfileSettings.heightCentimeters() ?? dashboard.extendedMetrics.heightCm
        let sex = UserProfileSettings.biologicalSex() ?? dashboard.extendedMetrics.biologicalSex
        if let age, (10...100).contains(age) { values.append("\(age) 岁") }
        if let weight, (25...350).contains(weight) { values.append(String(format: "%.1f kg", weight)) }
        if let height, (100...250).contains(height) { values.append(String(format: "%.0f cm", height)) }
        if let sex = ["male": "男性", "female": "女性", "other": "其他"][sex ?? ""] { values.append(sex) }
        return values.isEmpty ? "等待 Apple 健康或手动填写" : values.joined(separator: " · ")
    }
    private var bodyModelState: BodyModelState {
        BodyModelBuilder().build(
            onboarding: onboarding,
            dailySummaries: Array(dailySummaries.prefix(35)),
            journalEntries: Array(journalEntries.prefix(100)),
            strengthWorkouts: Array(strengthWorkouts.prefix(50)),
            trainingResponses: Array(trainingResponses.prefix(50)),
            asOf: dashboard.date
        )
    }
    
    @State private var healthSnapshots: [DailyHealthSnapshot] = []
    @State private var insights: [HabitCorrelationInsight] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCalibrationCard
                staticParametersSection
                physiologicalSection
                behavioralDynamicsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("身体模型")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadModelData()
        }
        .onChange(of: dashboardVM.selectedDate) {
            loadModelData()
        }
    }
    
    private var headerCalibrationCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bolt.heart.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 8).fill(VelaTheme.accent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 5) {
                Text("身体模型校准状态")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("整合目标、训练事实、健康基线和随手记信号；样本不足时仅标记待学习区域。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }
    
    private var staticParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("静态约束与倾向")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
                Spacer()
                NavigationLink(destination: BodyModelEditView()) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("修改设定")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }
            
            VStack(spacing: 0) {
                detailRow(title: "基础健康档案", value: healthProfileSummary)
                Divider().padding(.leading, 16)
                detailRow(title: "主要健身目标", value: staticGoalText)
                Divider().padding(.leading, 16)
                detailRow(title: "体能训练经验", value: staticExperienceText)
                Divider().padding(.leading, 16)
                detailRow(title: "频次及单次时长", value: staticFrequencyText)
                Divider().padding(.leading, 16)
                detailRow(title: "教练指导风格", value: staticCoachStyleText)
            }
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
    }
    
    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(VelaTheme.fg)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var physiologicalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("生理稳态系统标定 (28天生理基线)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("自主神经张力基线 (HRV / 心率变异性)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    BaselineRangeIndicator(
                        today: dashboard.recoveryMetrics.hrvMilliseconds,
                        baseline: dashboard.recoveryBaseline.hrvMilliseconds,
                        unit: " ms"
                    )
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("心脏负荷恢复基线 (RHR / 静息心率)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    BaselineRangeIndicator(
                        today: dashboard.recoveryMetrics.restingHeartRate,
                        baseline: dashboard.recoveryBaseline.restingHeartRate,
                        unit: " bpm"
                    )
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("自主神经呼吸恢复 (Respiratory Rate / 呼吸频率)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    BaselineRangeIndicator(
                        today: dashboard.recoveryMetrics.respiratoryRate,
                        baseline: dashboard.recoveryBaseline.respiratoryRate,
                        unit: " 次/分"
                    )
                }
                
                Divider()
                
                HStack {
                    Text("最大摄氧量标定 (VO2 Max)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Spacer()
                    if let vo2Max = dashboard.bodyMetrics.vo2Max {
                        Text("\(String(format: "%.1f", vo2Max)) mL/kg/min")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.accent)
                    } else {
                        Text("暂无数据 (Apple Watch 户外跑/步行校准)")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
    }
    
    private var behavioralDynamicsSection: some View {
        JournalCorrelationSection(bodyModelState: bodyModelState, insights: insights)
    }
    
    private func loadModelData() {
        var summariesDesc = FetchDescriptor<DailyHealthSummaryRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        summariesDesc.fetchLimit = 35
        self.dailySummaries = (try? modelContext.fetch(summariesDesc)) ?? []
 
        var journalDesc = FetchDescriptor<JournalEntryRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        journalDesc.fetchLimit = 100
        self.journalEntries = (try? modelContext.fetch(journalDesc)) ?? []
 
        var workoutsDesc = FetchDescriptor<StrengthWorkoutRecord>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        workoutsDesc.fetchLimit = 50
        self.strengthWorkouts = (try? modelContext.fetch(workoutsDesc)) ?? []
 
        var responsesDesc = FetchDescriptor<TrainingResponseRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        responsesDesc.fetchLimit = 50
        self.trainingResponses = (try? modelContext.fetch(responsesDesc)) ?? []
 
        let repo = HealthSnapshotRepository(modelContext: modelContext)
        if let snaps = try? repo.fetchSnapshots(days: 30) {
            self.healthSnapshots = snaps
            let engine = JournalCorrelationEngine()
            self.insights = engine.calculateInsights(journalEntries: self.journalEntries, snapshots: snaps)
        }
    }
    
    private func confidenceColor(_ conf: MetricConfidence) -> Color {
        switch conf {
        case .high: return VelaTheme.success
        case .medium: return VelaTheme.accent
        case .low: return Color.orange
        }
    }
 
    private func confidenceColor(_ conf: DataConfidence) -> Color {
        switch conf {
        case .high: return VelaTheme.success
        case .medium: return VelaTheme.accent
        case .low: return Color.orange
        case .unavailable: return VelaTheme.muted
        }
    }
    
    private func displayConfidence(_ conf: String) -> String {
        switch conf.lowercased() {
        case "high": return L10n.t("High", "高")
        case "medium": return L10n.t("Medium", "中")
        case "low": return L10n.t("Low", "低")
        case "unavailable": return L10n.t("Unavailable", "不可用")
        default: return conf
        }
    }
    
    private func displayGoal(_ goal: String) -> String {
        localizedOnboardingGoal(goal)
    }
 
    private func displayExperience(_ level: String) -> String {
        localizedOnboardingExperience(level)
    }
 
    private func displayCoachingStyle(_ style: String) -> String {
        localizedOnboardingCoachStyle(style)
    }
}
