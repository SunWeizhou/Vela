import SwiftUI
import SwiftData

struct VelaMeView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Environment(\.colorScheme) private var cs
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared

    private static let lookbackDays = 42
    private var lookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.lookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    @State private var coachArtifacts: [CoachArtifactRecord] = []
    @State private var journalEntries: [JournalEntryRecord] = []
    @State private var dailySummaries: [DailyHealthSummaryRecord] = []
    @State private var strengthWorkouts: [StrengthWorkoutRecord] = []
    @State private var trainingResponses: [TrainingResponseRecord] = []
    @State private var cachedBodyModelState: BodyModelState?

    @State private var selectedWorkoutForDetail: WorkoutSummary?
    @AppStorage("vela_coach_text_model") private var textModel = "DeepSeek V4 Pro"
    @AppStorage("vela_daily_calorie_target") private var dailyCalorieTarget = 2000

    private var onboarding: OnboardingState? { onboardingStates.first }
    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var hasCompletedOnboardingProfile: Bool { onboarding?.isCompleted == true }
    private var profileSummary: String {
        guard hasCompletedOnboardingProfile else {
            return "完善训练目标、偏好和设备后，Coach 会将这些信息纳入个人上下文。"
        }
        return onboarding?.firstBrief.isEmpty == false
            ? onboarding!.firstBrief
            : "训练目标、偏好、设备和健康数据会共同构成 Coach 的个人上下文。"
    }
    private var profileGoalText: String {
        guard hasCompletedOnboardingProfile else { return "尚未设置" }
        return displayGoal(onboarding?.goalProfile.primaryGoal ?? "unknown")
    }
    private var profileExperienceText: String {
        guard hasCompletedOnboardingProfile else { return "待补充" }
        return displayExperience(onboarding?.goalProfile.experienceLevel ?? "unknown")
    }
    private var profileFrequencyText: String {
        guard hasCompletedOnboardingProfile else { return "待设置" }
        return "\(onboarding?.trainingPreference.weeklyTrainingDays ?? 0) 次 / 周"
    }
    private var profileDurationText: String {
        guard hasCompletedOnboardingProfile else { return "待设置" }
        return "\(onboarding?.trainingPreference.sessionDurationMinutes ?? 0) 分钟 / 次"
    }
    private var bodyModelState: BodyModelState {
        cachedBodyModelState ?? buildBodyModelState()
    }

    private func buildBodyModelState() -> BodyModelState {
        BodyModelBuilder().build(
            onboarding: onboarding,
            dailySummaries: Array(dailySummaries.prefix(35)),
            journalEntries: Array(journalEntries.prefix(100)),
            strengthWorkouts: Array(strengthWorkouts.prefix(50)),
            trainingResponses: Array(trainingResponses.prefix(50)),
            asOf: dashboard.date
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                profileHeader
                bodyModelOverviewCard
                coachMemoryCard
                actionSettingsHub
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle(L10n.t("Me", "个人中心"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            loadMeData()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            guard isActiveSurface else { return }
            loadMeData()
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            guard isActiveSurface else { return }
            loadMeData()
        }
    }

    private var bodyModelOverviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("身体数据模型")
                    .font(VelaTheme.caption1().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)

                Spacer()

                NavigationLink(destination: BodyModelDetailView()) {
                    HStack(spacing: 4) {
                        Text("分析与校准")
                        Image(systemName: "chevron.right")
                    }
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                Text(profileSummary)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.fg2)
                    .lineSpacing(3)
                    .lineLimit(3)

                Divider()

                HStack(spacing: 0) {
                    modelFact(title: "训练目标", value: profileGoalText, detail: profileExperienceText)
                    Divider().frame(height: 48).padding(.horizontal, 14)
                    modelFact(title: "训练节奏", value: profileFrequencyText, detail: profileDurationText)
                }

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(VelaTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("模型成熟度 · \(bodyModelMaturityTitle(bodyModelState.maturity.overall))")
                            .font(VelaTheme.subheadline().weight(.semibold))
                            .foregroundStyle(VelaTheme.fg)
                        Text("\(bodyModelState.maturity.behaviorPairs) 个行为信号 · \(bodyModelState.maturity.trainingSessions) 次训练事实")
                            .font(VelaTheme.caption1())
                            .foregroundStyle(VelaTheme.muted)
                    }

                    Spacer(minLength: 0)
                }

                if let missing = onboarding?.missingData, !missing.isEmpty {
                    Label("还有 \(missing.count) 项资料可补充", systemImage: "info.circle")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.warn)
                }
            }
            .padding(16)
            .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
            )
        }
    }

    private func modelFact(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.muted)
            Text(value)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bodyModelUnifiedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.t("Body Model", "身体数据模型"))
                    .font(VelaTheme.caption1())
                    .fontWeight(.bold)
                    .foregroundStyle(VelaTheme.muted)
                    .textCase(.uppercase)
                    .padding(.leading, 2)
                
                Spacer()
                
                NavigationLink(destination: BodyModelDetailView()) {
                    HStack(spacing: 4) {
                        Text("分析与校准")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.cardPress)
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#FFCC00"))
                        .padding(.top, 2)
                    Text(profileSummary)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(VelaTheme.fg2)
                        .lineSpacing(4)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).fill(cs == .dark ? VelaTheme.brandLeaf.opacity(0.08) : VelaTheme.brandLeaf.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).stroke(cs == .dark ? VelaTheme.brandLeaf.opacity(0.15) : VelaTheme.brandLeaf.opacity(0.12), lineWidth: 0.5))

                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("GOAL", "训练目标"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Text(profileGoalText)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(profileExperienceText)
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(cs == .dark ? Color(hex: "#D48463").opacity(0.6) : Color(hex: "#C56B4A").opacity(0.6))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).fill(cs == .dark ? Color(hex: "#D48463").opacity(0.08) : Color(hex: "#C56B4A").opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).stroke(cs == .dark ? Color(hex: "#D48463").opacity(0.15) : Color(hex: "#C56B4A").opacity(0.12), lineWidth: 0.5))

                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.t("TRAINING", "每周频次"))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Text(profileFrequencyText)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(profileDurationText)
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(cs == .dark ? Color(hex: "#D0A050").opacity(0.6) : Color(hex: "#B8843E").opacity(0.6))
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).fill(cs == .dark ? Color(hex: "#D0A050").opacity(0.08) : Color(hex: "#B8843E").opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).stroke(cs == .dark ? Color(hex: "#D0A050").opacity(0.15) : Color(hex: "#B8843E").opacity(0.12), lineWidth: 0.5))
                }

                Divider()

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    profileGridItem(
                        title: "训练风格",
                        value: hasCompletedOnboardingProfile
                            ? displayTrainingStyle(onboarding?.trainingPreference.trainingStyle ?? "unknown")
                            : "待设置",
                        icon: "figure.run",
                        color: VelaTheme.systemOrange
                    )
                    profileGridItem(
                        title: "可用设备",
                        value: equipmentText,
                        icon: "dumbbell.fill",
                        color: VelaTheme.infoBlue
                    )
                }
                .padding(.vertical, 6)

                if let missing = onboarding?.missingData, !missing.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.systemOrange)
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("待补充健康指标")
                                .font(VelaTheme.caption1())
                                .fontWeight(.bold)
                                .foregroundStyle(VelaTheme.fg)
                            Text(missing.joined(separator: ", "))
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
                
                Divider().padding(.vertical, 4)

                bodyModelEvidencePanel(bodyModelState)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            .shadow(color: Color.black.opacity(0.015), radius: 10, y: 4)
        }
    }

    private func calculateTopInsights() -> [HabitCorrelationInsight] {
        let snapshots = (try? HealthSnapshotRepository(modelContext: modelContext).fetchSnapshots(days: 30)) ?? []
        return JournalCorrelationEngine().calculateInsights(journalEntries: journalEntries, snapshots: snapshots)
    }

    private func bodyModelEvidencePanel(_ state: BodyModelState) -> some View {
        JournalTagInsights(state: state)
    }

    private var coachMemoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("Coach Memory", "教练建议与记忆"))
                .font(VelaTheme.caption1())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.muted)
                .textCase(.uppercase)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                NavigationLink(destination: CoachArtifactInboxView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(VelaTheme.accent))
                        
                        Text("建议收件箱")
                            .font(VelaTheme.body())
                            .foregroundStyle(VelaTheme.fg)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Text("\(coachArtifacts.count) 条历史")
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.muted)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.cardPress)

                if !coachArtifacts.isEmpty {
                    Divider().padding(.leading, 54)
                    
                    ForEach(coachArtifacts.prefix(3)) { record in
                        let artifact = record.artifact
                        NavigationLink {
                            CoachArtifactDetailWrapper(artifact: artifact)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: artifactIcon(for: artifact.type))
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(artifactColor(for: artifact.type)))
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(artifactTypeLabel(for: artifact.type))
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(artifactColor(for: artifact.type))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(RoundedRectangle(cornerRadius: 4).fill(artifactColor(for: artifact.type).opacity(0.12)))
                                        
                                        Text(artifact.createdAt.formatted(.dateTime.month().day().hour().minute()))
                                            .font(VelaTheme.caption2())
                                            .foregroundStyle(VelaTheme.muted)
                                    }
                                    
                                    Text(artifact.title)
                                        .font(VelaTheme.subheadline())
                                        .fontWeight(.semibold)
                                        .foregroundStyle(VelaTheme.fg)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VelaTheme.meta)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.cardPress)
                        
                        if record.id != coachArtifacts.prefix(3).last?.id {
                            Divider().padding(.leading, 54)
                        }
                    }
                } else {
                    Divider().padding(.leading, 54)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(Color(hex: cs == .dark ? "#2C2C2E" : "#F2F2F7")))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("暂无教练建议")
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.fg)
                            Text("对话或记录训练后将自动生成历史建议")
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.muted)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
    }

    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact? = nil) {
        VelaAppState.shared.logDebug("[VelaMeView] handleArtifactAction: type=\(action.type), label=\(action.label)")
        if action.type == "start_check_in" {
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.logDebug("[VelaMeView] Opening post-workout impact")
            VelaAppState.shared.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            VelaAppState.shared.logDebug("[VelaMeView] Routing to recovery (tab 2)")
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            VelaAppState.shared.logDebug("[VelaMeView] Routing to training (tab 1)")
            VelaAppState.shared.routeToTraining()
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.logDebug("[VelaMeView] Triggering journal")
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.logDebug("[VelaMeView] Routing to coach with label: \(action.label)")
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact?) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact?.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    private func artifactIcon(for type: CoachArtifactType) -> String {
        switch type {
        case .morningBrief: return "sun.max.fill"
        case .workoutReadiness, .trainingAdjustment: return "figure.strengthtraining.traditional"
        case .postWorkoutReview: return "checkmark.seal.fill"
        case .eveningReview: return "moon.stars.fill"
        case .weeklyReview: return "calendar.badge.clock"
        case .wikiUpdateProposal: return "brain.head.profile"
        case .askCoachAnswer: return "sparkles"
        }
    }

    private func artifactColor(for type: CoachArtifactType) -> Color {
        switch type {
        case .postWorkoutReview, .trainingAdjustment, .workoutReadiness: return VelaTheme.strainColor
        case .eveningReview: return VelaTheme.sleepColor
        case .wikiUpdateProposal: return VelaTheme.systemOrange
        default: return VelaTheme.accent
        }
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 {
            return L10n.t("Good morning", "早上好")
        } else if hour >= 12 && hour < 18 {
            return L10n.t("Good afternoon", "下午好")
        } else if hour >= 18 && hour < 24 {
            return L10n.t("Good evening", "晚上好")
        } else {
            return L10n.t("Good night", "夜深了")
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(VelaTheme.accent.opacity(0.12))
                    .frame(width: 56, height: 56)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("\(timeGreeting), Weizhou", "\(timeGreeting)，Weizhou"))
                    .font(VelaTheme.title2())
                    .foregroundStyle(VelaTheme.fg)
                
                Text(bodyModelMaturityTitle(bodyModelState.maturity.overall))
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(bodyModelMaturityColor(bodyModelState.maturity.overall))

                Text("\(bodyModelState.maturity.behaviorPairs) 个行为信号 · \(bodyModelState.maturity.trainingSessions) 次训练事实")
                    .font(VelaTheme.caption1())
                    .foregroundStyle(VelaTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private var actionSettingsHub: some View {
        let calendar = Calendar.current
        let todayEntries = journalEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: dashboardVM.selectedDate) }
        let journalSub = todayEntries.isEmpty ? "日常状态手记" : "今日已记 \(todayEntries.count) 条"
        
        let wikiSub = "成熟度: \(bodyModelMaturityTitle(bodyModelState.maturity.overall))"
        
        let weightText = dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f kg", $0) } ?? "体重待同步"
        let heartRateText = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "静息心率待同步"
        let bioSub = "\(weightText) · \(heartRateText)"
        
        let aiModelSub = textModel
        
        let signalSub = dashboard.recovery.hasData ? "恢复信号已纳入今日判断" : "正在建立恢复基线"
        
        let settingsSub = "\(dailyCalorieTarget) kcal 目标"

        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("Tools & Settings", "工具与设置"))
                .font(VelaTheme.caption1())
                .fontWeight(.semibold)
                .foregroundStyle(VelaTheme.muted)
                .padding(.leading, 2)
            
            VStack(spacing: 0) {
                hubActionCell(title: "健康手记", sub: journalSub, icon: "book.pages.fill", color: VelaTheme.systemOrange, destination: VelaJournalView())
                Divider().padding(.leading, 58)
                hubActionCell(title: "健康档案", sub: wikiSub, icon: "doc.text.fill", color: VelaTheme.muted, destination: UserWikiArchiveView())
                Divider().padding(.leading, 58)
                if VelaFeatureFlags.biologicalAgeEnabled {
                    hubActionCell(title: "生物资料", sub: bioSub, icon: "person.text.rectangle.fill", color: Color(hex: "#00A896"), destination: BiologyView())
                    Divider().padding(.leading, 58)
                }
                hubActionCell(title: "AI 增强", sub: aiModelSub, icon: "sparkles", color: VelaTheme.accent, destination: AIModelSettingsView())
                Divider().padding(.leading, 58)
                hubActionCell(title: "数据信号", sub: signalSub, icon: "waveform.path.ecg.rectangle.fill", color: VelaTheme.infoBlue, destination: DataCoverageView())
                Divider().padding(.leading, 58)
                hubActionCell(title: "系统设置", sub: settingsSub, icon: "gearshape.fill", color: VelaTheme.indigo, destination: VelaSettingsView())
            }
            .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
            )
        }
    }

    private func hubActionCell<Destination: View>(
        title: String,
        sub: String,
        icon: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(sub)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
    }

    private func profileGridItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(color))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
                Text(value)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusMd).fill(VelaTheme.surface))
    }

    private var equipmentText: String {
        guard hasCompletedOnboardingProfile,
              let equipment = onboarding?.equipmentProfile.equipment,
              !equipment.isEmpty else { return "待设置" }
        let separator = AppLanguage.stored.isChinese ? "、" : ", "
        return equipment.prefix(3)
            .map(localizedOnboardingEquipment)
            .joined(separator: separator)
    }

    private func profileLine(_ title: String, _ value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(color))
            Text(title)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg)
            Spacer()
            Text(value)
                .font(VelaTheme.subheadline())
                .fontWeight(.semibold)
                .foregroundStyle(VelaTheme.muted)
                .lineLimit(1)
        }
    }

    private func settingsLink<Destination: View>(
        _ title: String,
        value: String,
        icon: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: VelaTheme.radiusSm).fill(color))
                Text(title)
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text(value)
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.muted)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func displayGoal(_ goal: String) -> String {
        switch goal {
        case "muscle_gain": return L10n.t("Muscle Gain", "增肌")
        case "fat_loss": return L10n.t("Fat Loss", "减脂")
        case "performance": return L10n.t("Performance", "运动表现提升")
        case "health": return L10n.t("Health", "健康维持")
        default: return L10n.t("Not set", "尚未设置")
        }
    }

    private func displayExperience(_ level: String) -> String {
        switch level {
        case "beginner": return L10n.t("Beginner", "健身新手")
        case "intermediate": return L10n.t("Intermediate", "中级水平")
        case "advanced": return L10n.t("Advanced", "高级水平")
        default: return L10n.t("Not set", "待补充")
        }
    }

    private func displayTrainingStyle(_ style: String) -> String {
        switch style {
        case "mixed": return L10n.t("Mixed", "混合训练")
        case "strength": return L10n.t("Strength", "力量训练")
        case "cardio": return L10n.t("Cardio", "有氧训练")
        case "yoga": return L10n.t("Yoga", "瑜伽伸展")
        default: return L10n.t("Not set", "待设置")
        }
    }

    private func displayCoachingStyle(_ style: String) -> String {
        switch style {
        case "explanatory": return L10n.t("Detailed", "详细解析")
        case "encouraging": return L10n.t("Encouraging", "积极鼓励")
        case "direct": return L10n.t("Direct", "直截了当")
        default: return L10n.t("Not set", "待设置")
        }
    }

    private func bodyModelMaturityTitle(_ level: BodyModelMaturityLevel) -> String {
        switch level {
        case .seed: return "种子期"
        case .learning: return "学习期"
        case .stable: return "稳定期"
        }
    }

    private func bodyModelMaturityColor(_ level: BodyModelMaturityLevel) -> Color {
        switch level {
        case .seed: return VelaTheme.systemOrange
        case .learning: return VelaTheme.accent
        case .stable: return VelaTheme.success
        }
    }

    private func confidenceColor(_ confidence: DataConfidence) -> Color {
        switch confidence {
        case .high: return VelaTheme.success
        case .medium: return VelaTheme.accent
        case .low: return VelaTheme.systemOrange
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

    private func artifactTypeLabel(for type: CoachArtifactType) -> String {
        switch type {
        case .morningBrief: return "晨间简报"
        case .workoutReadiness: return "就绪状态"
        case .trainingAdjustment: return "训练调整"
        case .postWorkoutReview: return "训练总结"
        case .eveningReview: return "夜间回顾"
        case .weeklyReview: return "每周分析"
        case .wikiUpdateProposal: return "档案更新"
        case .askCoachAnswer: return "教练解答"
        }
    }

    private func loadMeData() {
        let calendar = Calendar.current
        let refDate = dashboardVM.selectedDate
        let startOfDayRef = calendar.startOfDay(for: refDate)
        
        let startLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -Self.lookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let endLimit = calendar.date(byAdding: .day, value: 1, to: startOfDayRef) ?? startOfDayRef
        
        let artifactsDesc = FetchDescriptor<CoachArtifactRecord>(
            predicate: #Predicate<CoachArtifactRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.coachArtifacts = (try? modelContext.fetch(artifactsDesc)) ?? []

        let journalDesc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.journalEntries = (try? modelContext.fetch(journalDesc)) ?? []

        let summaryDesc = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        self.dailySummaries = (try? modelContext.fetch(summaryDesc)) ?? []

        let strengthDesc = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= startLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        self.strengthWorkouts = (try? modelContext.fetch(strengthDesc)) ?? []

        let responsesDesc = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        self.trainingResponses = (try? modelContext.fetch(responsesDesc)) ?? []
        self.cachedBodyModelState = buildBodyModelState()
    }
}
