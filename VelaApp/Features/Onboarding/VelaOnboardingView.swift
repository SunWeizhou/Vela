import SwiftUI
import SwiftData

struct VelaOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @State private var authError: String? = nil
    @State private var showingErrorAlert = false
    @State private var missingSignals: [HealthSignal] = []
    @State private var showingMissingAlert = false
    @State private var primaryGoal = "performance"
    @State private var trainingStyle = "strength"
    @State private var weeklyTrainingDays = 5
    @State private var sessionDurationMinutes = 60
    @State private var experienceLevel = "intermediate"
    @State private var coachStyle = "direct"
    @State private var hasGym = true
    @State private var hasHomeEquipment = true
    @State private var hasBodyweight = true
    @State private var currentStep = 0
    @State private var isMovingForward = true

    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]

    var body: some View {
        ZStack {
            VelaTheme.rhythmCanvas.ignoresSafeArea()

            VStack(spacing: 0) {
                onboardingHeader

                ScrollView {
                    Group {
                        switch currentStep {
                        case 0: welcomeStep
                        case 1: modelStep
                        default: healthStep
                        }
                    }
                    .id(currentStep)
                    .transition(stepTransition)
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 150)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            ctaButtons
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
        }
        .alert(isPresented: $showingErrorAlert) {
            Alert(
                title: Text(L10n.t("Unable to Authorize Apple Health", "无法授权 Apple 健康")),
                message: Text(authError ?? L10n.t("Vela requires Health permissions to analyze your wellness indices.", "Vela 需要健康权限来分析您的生理与运动数据。")),
                dismissButton: .default(Text(L10n.t("OK", "好的")))
            )
        }
        .alert(isPresented: $showingMissingAlert) {
            let names = missingSignals.map { $0.name }.joined(separator: ", ")
            return Alert(
                title: Text(L10n.t("Missing Core Permissions", "部分核心权限未开启")),
                message: Text(L10n.t(
                    "We noticed the following core permissions are missing: \(names).\n\nYou can enable them in iOS Settings > Health > Data Access & Devices > Vela to unlock full insights.",
                    "检测到以下核心权限未开启：\(names)。\n\n您可以在系统“设置 > 健康 > 数据与设备 > Vela”中开启它们，以获得完整的健康洞察。"
                )),
                primaryButton: .default(Text(L10n.t("Retry Check", "重新检查")), action: {
                    Task { await retryMissingSignalCheck() }
                }),
                secondaryButton: .cancel(Text(L10n.t("Proceed Anyway", "仍然继续")), action: {
                    finishOnboarding(missingSignals: missingSignals)
                })
            )
        }
    }

    private var onboardingHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(VelaTheme.rhythmDeep)
                .frame(width: 6, height: 6)
            Text("VELA · RHYTHM")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(VelaTheme.rhythmInkSecondary)

            Spacer()

            Text("\(currentStep + 1) / 3")
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 14) {
                Text("RHYTHM INTELLIGENCE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.6)
                    .foregroundStyle(VelaTheme.rhythmDeep)

                Text(L10n.t("Know what your body needs today.", "每天，只回答一个重要问题。"))
                    .font(.system(size: 38, weight: .semibold, design: .default))
                    .tracking(-1.1)
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.t(
                    "Vela turns your health and training signals into one clear next step — with the evidence behind it.",
                    "Vela 会把健康与训练信号整理成一个清晰的下一步，并告诉你判断依据。"
                ))
                .font(.system(.body, design: .default, weight: .regular))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(4)
            }

            VStack(spacing: 0) {
                onboardingValueRow(icon: "sun.max.fill", title: "今天怎么练", detail: "根据恢复、睡眠和近期负荷调整建议")
                Divider().padding(.leading, 52)
                onboardingValueRow(icon: "sparkles", title: "为什么这样建议", detail: "Coach 用自然语言解释证据与不确定性")
                Divider().padding(.leading, 52)
                onboardingValueRow(icon: "lock.shield.fill", title: "数据由你控制", detail: "健康资料默认保存在本机，联网 AI 由你决定")
            }
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(VelaTheme.rhythmMist.opacity(0.8), lineWidth: 0.75)
            )
        }
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("先认识你的训练方式")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("这些信息用于建立初始节律，之后可以随时修改；Vela 不会把计划当作必须完成的课表。")
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
            }

            bodyModelSetupCard
        }
    }

    private var healthStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 60, height: 60)
                .background(VelaTheme.rhythmMist.opacity(0.72), in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg))

            VStack(alignment: .leading, spacing: 8) {
                Text("连接 Apple 健康")
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-0.6)
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text("授权后，Vela 才能结合睡眠、心率、HRV 与训练记录生成个性化建议。")
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(4)
            }

            VStack(spacing: 0) {
                permissionRow(icon: "bed.double.fill", title: "睡眠与恢复", detail: "判断今天是否适合提高训练强度")
                Divider().padding(.leading, 52)
                permissionRow(icon: "heart.fill", title: "心率与 HRV", detail: "建立属于你的个人基线")
                Divider().padding(.leading, 52)
                permissionRow(icon: "figure.run", title: "活动与训练", detail: "理解近期负荷并避免重复记录")
            }
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(VelaTheme.rhythmMist.opacity(0.8), lineWidth: 0.75)
            )

            Label("你可以逐项选择权限；Vela 无法写入或修改 Apple 健康中的原始数据。", systemImage: "lock.fill")
                .font(VelaTheme.footnote())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
    }

    private func onboardingValueRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 38, height: 38)
                .background(VelaTheme.rhythmMist.opacity(0.68), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(VelaTheme.headline()).foregroundStyle(VelaTheme.rhythmInk)
                Text(detail).font(VelaTheme.footnote()).foregroundStyle(VelaTheme.rhythmInkSecondary).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        onboardingValueRow(icon: icon, title: title, detail: detail)
    }

    private var heroSection: some View {
        VStack(spacing: 12) {
            Text(L10n.t("Welcome to", "欢迎使用"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
                .tracking(2)
                .textCase(.uppercase)

            VelaLogoMark(size: 76)

            Text("VELA")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundStyle(VelaTheme.fg)

            Text(L10n.t("Active Coach OS", "主动式身体教练系统"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VelaTheme.fg)

            Text(L10n.t(
                "Build your first body model, connect Apple Health, then let Vela turn readiness, training, and recovery into daily decisions.",
                "先建立你的首日身体模型，再连接 Apple 健康；Vela 会把准备度、训练和恢复合成每日决策。"
            ))
            .font(.system(size: 14))
            .foregroundStyle(VelaTheme.muted.opacity(0.75))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
    }

    private var bodyModelSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("First-Day Body Model", "首日身体模型"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(VelaTheme.fg)

            Picker(L10n.t("Goal", "目标"), selection: $primaryGoal) {
                Text(localizedOnboardingGoal("performance")).tag("performance")
                Text(localizedOnboardingGoal("muscle_gain")).tag("muscle_gain")
                Text(localizedOnboardingGoal("fat_loss")).tag("fat_loss")
                Text(localizedOnboardingGoal("health")).tag("health")
            }
            .pickerStyle(.segmented)

            Picker(L10n.t("Training", "训练"), selection: $trainingStyle) {
                Text(localizedOnboardingTrainingStyle("strength")).tag("strength")
                Text(localizedOnboardingTrainingStyle("hybrid")).tag("hybrid")
                Text(localizedOnboardingTrainingStyle("endurance")).tag("endurance")
            }
            .pickerStyle(.segmented)

            VStack(spacing: 10) {
                Stepper(value: $weeklyTrainingDays, in: 1...7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("\(weeklyTrainingDays)x / week", "每周 \(weeklyTrainingDays) 次"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.fg)
                        Text(L10n.t("training frequency", "训练频次"))
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }

                Stepper(value: $sessionDurationMinutes, in: 20...120, step: 5) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sessionDurationMinutes) min")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.fg)
                        Text(L10n.t("session", "单次时长"))
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }

            Picker(L10n.t("Experience", "经验"), selection: $experienceLevel) {
                Text(localizedOnboardingExperience("beginner")).tag("beginner")
                Text(localizedOnboardingExperience("intermediate")).tag("intermediate")
                Text(localizedOnboardingExperience("advanced")).tag("advanced")
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                equipmentToggle(localizedOnboardingEquipment("gym"), isOn: $hasGym)
                equipmentToggle(localizedOnboardingEquipment("home_equipment"), isOn: $hasHomeEquipment)
                equipmentToggle(localizedOnboardingEquipment("bodyweight"), isOn: $hasBodyweight)
            }

            Picker(L10n.t("Coach Style", "教练风格"), selection: $coachStyle) {
                Text(localizedOnboardingCoachStyle("direct")).tag("direct")
                Text(localizedOnboardingCoachStyle("balanced")).tag("balanced")
                Text(localizedOnboardingCoachStyle("explanatory")).tag("explanatory")
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(VelaTheme.rhythmMist.opacity(0.8), lineWidth: 0.75)
        )
    }

    private var signalPreviewCard: some View {
        VStack(spacing: 10) {
            featureCard(
                icon: "heart.fill",
                bgColor: VelaTheme.recoveryColor.opacity(0.12),
                fgColor: VelaTheme.recoveryColor,
                title: L10n.t("Readiness Decision", "每日准备度决策"),
                detail: L10n.t("Recovery, HRV, resting heart rate, sleep, and strain become one action.", "恢复、HRV、静息心率、睡眠和负荷会合成为一个行动建议。")
            )
            featureCard(
                icon: "figure.strengthtraining.traditional",
                bgColor: VelaTheme.strainColor.opacity(0.12),
                fgColor: VelaTheme.strainColor,
                title: L10n.t("Training Loop", "训练闭环"),
                detail: L10n.t("Templates, set logging, post-workout review, and Coach artifact memory.", "模板、组记录、训练后复盘和 Coach artifact 记忆。")
            )
            featureCard(
                icon: "checkmark.shield.fill",
                bgColor: VelaTheme.success.opacity(0.12),
                fgColor: VelaTheme.success,
                title: L10n.t("Local-first Trust", "本地优先与信任中心"),
                detail: L10n.t("Profiles and health context stay in SwiftData unless you explicitly use network AI.", "资料和健康上下文保存在本机 SwiftData，只有主动使用联网 AI 时才会发送。")
            )
        }
    }

    private var ctaButtons: some View {
        VStack(spacing: 12) {
            Button(action: primaryOnboardingAction) {
                Text(primaryButtonTitle)
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.rhythmDeepOn)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.rhythmDeep))
            }
            .buttonStyle(.cardPress)

            if currentStep > 0 {
                Button {
                    if currentStep == 2 {
                        finishOnboarding(missingSignals: [])
                    } else {
                        isMovingForward = false
                        withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                            currentStep -= 1
                        }
                    }
                } label: {
                    Text(currentStep == 2 ? "稍后连接" : "返回")
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.cardPress)
            }
        }
    }

    private var primaryButtonTitle: String {
        switch currentStep {
        case 0: return "开始设置"
        case 1: return "继续"
        default: return "连接 Apple 健康"
        }
    }

    private func primaryOnboardingAction() {
        if currentStep < 2 {
            isMovingForward = true
            withAnimation(VelaTheme.interfaceAnimation(reduceMotion: reduceMotion)) {
                currentStep += 1
            }
        } else {
            Task { await connectHealthAndFinish() }
        }
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let insertionEdge: Edge = isMovingForward ? .trailing : .leading
        let removalEdge: Edge = isMovingForward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertionEdge).combined(with: .opacity),
            removal: .move(edge: removalEdge).combined(with: .opacity)
        )
    }

    private func equipmentToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOn.wrappedValue ? VelaTheme.rhythmDeepOn : VelaTheme.rhythmInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn.wrappedValue ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.56))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
        }
        .buttonStyle(.cardPress)
    }

    private func connectHealthAndFinish() async {
        do {
            try await HealthAuthorizationService().requestAuthorization(tier: .core)
            let coverageService = HealthSignalCoverageService()
            var missing: [HealthSignal] = []
            for signal in [HealthSignal.hrvSDNN, .restingHR, .sleepAnalysis, .workouts, .activeEnergy, .stepCount] {
                let cov = await coverageService.fetchCoverage(for: signal)
                if cov.authorizationState == .unavailable
                    || cov.authorizationState == .notRequested
                    || cov.authorizationState == .denied {
                    missing.append(signal)
                }
            }
            if missing.isEmpty {
                finishOnboarding(missingSignals: [])
            } else {
                _ = saveOnboardingState(missingSignals: missing, completed: false)
                missingSignals = missing
                showingMissingAlert = true
            }
        } catch {
            authError = error.localizedDescription
            showingErrorAlert = true
        }
    }

    private func retryMissingSignalCheck() async {
        let coverageService = HealthSignalCoverageService()
        var missing: [HealthSignal] = []
        for signal in [HealthSignal.hrvSDNN, .restingHR, .sleepAnalysis, .workouts, .activeEnergy, .stepCount] {
            let cov = await coverageService.fetchCoverage(for: signal)
            if cov.authorizationState == .unavailable || cov.authorizationState == .notRequested {
                missing.append(signal)
            }
        }
        if missing.isEmpty {
            finishOnboarding(missingSignals: [])
        } else {
            _ = saveOnboardingState(missingSignals: missing, completed: false)
            missingSignals = missing
            showingMissingAlert = true
        }
    }

    private func finishOnboarding(missingSignals: [HealthSignal]) {
        guard saveOnboardingState(missingSignals: missingSignals, completed: true) else { return }
        onboardingCompleted = true
        VelaAppState.shared.markLocalDataChanged()
        Task {
            await dashboardVM.refresh(modelContext: modelContext, force: true)
        }
    }

    private func saveOnboardingState(missingSignals: [HealthSignal], completed: Bool) -> Bool {
        let state = onboardingStates.first ?? OnboardingState()
        state.currentStep = completed ? "completed" : "health_permissions"
        state.isCompleted = completed
        state.completedAt = completed ? Date() : nil
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
        state.equipmentProfile = EquipmentProfile(
            equipment: selectedEquipment,
            scheduleNotes: "\(weeklyTrainingDays)x weekly, \(sessionDurationMinutes)m sessions"
        )
        state.coachingPreference = CoachingPreference(
            style: coachStyle,
            explanationDepth: coachStyle == "explanatory" ? "detailed" : "balanced",
            language: "zh-Hans"
        )
        state.initialBodySnapshot = InitialBodySnapshot(
            sleepScore: dashboardVM.dashboard.sleepScore.hasData ? dashboardVM.dashboard.sleepScore.score : nil,
            recoveryScore: dashboardVM.dashboard.recovery.hasData ? dashboardVM.dashboard.recovery.score : nil,
            strainScore: dashboardVM.dashboard.strain.hasData ? dashboardVM.dashboard.strain.score : nil,
            dataConfidence: dataConfidence(from: dashboardVM.dashboard.recovery.confidence),
            missingData: missingSignals.map(\.name)
        )
        state.missingData = missingSignals.map(\.name)
        state.firstBrief = localizedOnboardingFirstBrief(
            primaryGoal: primaryGoal,
            trainingStyle: trainingStyle,
            weeklyTrainingDays: weeklyTrainingDays
        )
        state.firstActionPlan = [
            "完成 Apple 健康授权并建立 HRV/睡眠/负荷基线。",
            "训练时继续使用 Apple Watch；结束后可选填主观感受，动作、重量与组数始终可跳过。",
            "在今日查看行动边界，在 Coach 解释或确认任何计划变化。"
        ]
        state.updatedAt = Date()
        if onboardingStates.isEmpty {
            modelContext.insert(state)
        }
        do {
            try modelContext.save()
            return true
        } catch {
            authError = "无法保存身体模型，请稍后重试。"
            showingErrorAlert = true
            return false
        }
    }

    private var selectedEquipment: [String] {
        var values: [String] = []
        if hasGym { values.append("gym") }
        if hasHomeEquipment { values.append("home_equipment") }
        if hasBodyweight { values.append("bodyweight") }
        return values
    }

    private func dataConfidence(from confidence: MetricConfidence) -> DataConfidence {
        switch confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private func featureCard(icon: String, bgColor: Color, fgColor: Color, title: String, detail: String) -> some View {
        VelaGlassCard(padding: 16, cornerRadius: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(fgColor)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                            .fill(bgColor)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer()
            }
        }
    }
}
