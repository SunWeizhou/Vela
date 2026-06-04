import SwiftUI
import SwiftData

struct VelaOnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @AppStorage("vela_onboarding_completed") private var onboardingCompleted = false
    @State private var authError: String? = nil
    @State private var showingErrorAlert = false
    @State private var missingSignals: [HealthSignal] = []
    @State private var showingMissingAlert = false
    @State private var primaryGoal = "performance"
    @State private var trainingStyle = "strength"
    @State private var weeklyTrainingDays = 3
    @State private var sessionDurationMinutes = 45
    @State private var experienceLevel = "intermediate"
    @State private var coachStyle = "direct"
    @State private var hasGym = true
    @State private var hasHomeEquipment = true
    @State private var hasBodyweight = true

    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]

    var body: some View {
        ZStack {
            VelaBackground()

            // Top glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            VelaTheme.recovery.opacity(0.12),
                            VelaTheme.recovery.opacity(0.02),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(y: -240)
                .blur(radius: 20)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 18) {
                    heroSection
                    bodyModelSetupCard
                    signalPreviewCard
                    ctaButtons

                    Text(L10n.t(
                        "Your health data stays on-device. Nothing leaves without permission.",
                        "你的健康数据保留在设备本地，不会未经允许离开你的手机。"
                    ))
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 46)
            }
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
                .foregroundStyle(VelaTheme.onSurface)

            Text(L10n.t("Active Coach OS", "主动式身体教练系统"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VelaTheme.onSurface)

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
            Text("First-Day Body Model")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(VelaTheme.onSurface)

            Picker("Goal", selection: $primaryGoal) {
                Text("Performance").tag("performance")
                Text("Muscle").tag("muscle_gain")
                Text("Fat loss").tag("fat_loss")
                Text("Health").tag("health")
            }
            .pickerStyle(.segmented)

            Picker("Training", selection: $trainingStyle) {
                Text("Strength").tag("strength")
                Text("Hybrid").tag("hybrid")
                Text("Endurance").tag("endurance")
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Stepper(value: $weeklyTrainingDays, in: 1...7) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(weeklyTrainingDays)x / week")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text("training frequency")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }

                Stepper(value: $sessionDurationMinutes, in: 20...120, step: 5) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(sessionDurationMinutes) min")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text("session")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }

            Picker("Experience", selection: $experienceLevel) {
                Text("Beginner").tag("beginner")
                Text("Intermediate").tag("intermediate")
                Text("Advanced").tag("advanced")
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                equipmentToggle("Gym", isOn: $hasGym)
                equipmentToggle("Home", isOn: $hasHomeEquipment)
                equipmentToggle("Bodyweight", isOn: $hasBodyweight)
            }

            Picker("Coach Style", selection: $coachStyle) {
                Text("Direct").tag("direct")
                Text("Balanced").tag("balanced")
                Text("Detailed").tag("explanatory")
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VelaTheme.surface.opacity(0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(VelaTheme.outline, lineWidth: 0.5)
                )
        )
    }

    private var signalPreviewCard: some View {
        VStack(spacing: 10) {
            featureCard(
                icon: "heart.fill",
                bgColor: VelaTheme.recovery.opacity(0.12),
                fgColor: VelaTheme.recovery,
                title: L10n.t("Readiness Decision", "每日准备度决策"),
                detail: L10n.t("Recovery, HRV, resting heart rate, sleep, and strain become one action.", "恢复、HRV、静息心率、睡眠和负荷会合成为一个行动建议。")
            )
            featureCard(
                icon: "figure.strengthtraining.traditional",
                bgColor: VelaTheme.strain.opacity(0.12),
                fgColor: VelaTheme.strain,
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
            Button {
                Task { await connectHealthAndFinish() }
            } label: {
                Text(L10n.t("Build Model + Connect Apple Health", "建立模型并连接 Apple 健康"))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 99, style: .continuous)
                    .fill(VelaTheme.recovery)
            )

            Button {
                finishOnboarding(missingSignals: [])
            } label: {
                Text(L10n.t("Build model without Health for now", "先建立模型，稍后连接健康数据"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .buttonStyle(.plain)
        }
    }

    private func equipmentToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isOn.wrappedValue ? VelaTheme.background : VelaTheme.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn.wrappedValue ? VelaTheme.recovery : VelaTheme.surface.opacity(0.7))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(VelaTheme.outline, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func connectHealthAndFinish() async {
        do {
            try await HealthAuthorizationService().requestAuthorization(tier: .core)
            let coverageService = HealthSignalCoverageService()
            var missing: [HealthSignal] = []
            for signal in [HealthSignal.hrvSDNN, .restingHR, .sleepAnalysis, .workouts, .activeEnergy, .stepCount] {
                let cov = await coverageService.fetchCoverage(for: signal)
                if cov.authorizationState == .deniedOrUnavailable || cov.authorizationState == .notDetermined {
                    missing.append(signal)
                }
            }
            if missing.isEmpty {
                finishOnboarding(missingSignals: [])
            } else {
                saveOnboardingState(missingSignals: missing, completed: false)
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
            if cov.authorizationState == .deniedOrUnavailable || cov.authorizationState == .notDetermined {
                missing.append(signal)
            }
        }
        if missing.isEmpty {
            finishOnboarding(missingSignals: [])
        } else {
            saveOnboardingState(missingSignals: missing, completed: false)
            missingSignals = missing
            showingMissingAlert = true
        }
    }

    private func finishOnboarding(missingSignals: [HealthSignal]) {
        saveOnboardingState(missingSignals: missingSignals, completed: true)
        onboardingCompleted = true
    }

    private func saveOnboardingState(missingSignals: [HealthSignal], completed: Bool) {
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
        state.firstBrief = "目标 \(primaryGoal)，训练偏好 \(trainingStyle)，每周 \(weeklyTrainingDays) 次。Vela 会先用保守规则生成今日建议，数据覆盖提升后再提高自动化强度。"
        state.firstActionPlan = [
            "完成 Apple 健康授权并建立 HRV/睡眠/负荷基线。",
            "记录第一周训练组数、RPE/RIR 和训练后主观反馈。",
            "在 Today 查看每日准备度，在 Coach 确认需要写入长期记忆的建议。"
        ]
        state.updatedAt = Date()
        if onboardingStates.isEmpty {
            modelContext.insert(state)
        }
        try? modelContext.save()
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
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(fgColor)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(bgColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VelaTheme.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.outline, lineWidth: 0.5)
                )
        )
    }
}
