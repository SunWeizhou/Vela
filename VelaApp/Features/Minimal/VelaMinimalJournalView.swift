import SwiftUI
import SwiftData

struct VelaMeView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
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
            VStack(alignment: .leading, spacing: 16) {
                profileHeader
                bodyModelUnifiedCard
                coachMemoryCard
                actionSettingsHub
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle(L10n.t("Me", "个人中心"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
        .onAppear {
            loadMeData()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            loadMeData()
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            loadMeData()
        }
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
                // Brief Summary Quote Bubble with gold sparkles and sage-green tint
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
                .background(RoundedRectangle(cornerRadius: 12).fill(cs == .dark ? Color(hex: "#73A385").opacity(0.08) : Color(hex: "#5B8C6F").opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(cs == .dark ? Color(hex: "#73A385").opacity(0.15) : Color(hex: "#5B8C6F").opacity(0.12), lineWidth: 0.5))

                HStack(spacing: 12) {
                    // Goal Box (Clay Tint)
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
                    .background(RoundedRectangle(cornerRadius: 12).fill(cs == .dark ? Color(hex: "#D48463").opacity(0.08) : Color(hex: "#C56B4A").opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(cs == .dark ? Color(hex: "#D48463").opacity(0.15) : Color(hex: "#C56B4A").opacity(0.12), lineWidth: 0.5))

                    // Training Box (Amber Tint)
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
                    .background(RoundedRectangle(cornerRadius: 12).fill(cs == .dark ? Color(hex: "#D0A050").opacity(0.08) : Color(hex: "#B8843E").opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(cs == .dark ? Color(hex: "#D0A050").opacity(0.15) : Color(hex: "#B8843E").opacity(0.12), lineWidth: 0.5))
                }

                Divider()

                // 2x2 Grid of Profile details
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    profileGridItem(
                        title: "训练风格",
                        value: hasCompletedOnboardingProfile
                            ? displayTrainingStyle(onboarding?.trainingPreference.trainingStyle ?? "unknown")
                            : "待设置",
                        icon: "figure.run",
                        color: Color(hex: "#FF9F0A")
                    )
                    profileGridItem(
                        title: "可用设备",
                        value: equipmentText,
                        icon: "dumbbell.fill",
                        color: Color(hex: "#30A2FF")
                    )
                    profileGridItem(
                        title: "教练风格",
                        value: hasCompletedOnboardingProfile
                            ? displayCoachingStyle(onboarding?.coachingPreference.style ?? "unknown")
                            : "待设置",
                        icon: "brain.head.profile",
                        color: Color(hex: "#AF52DE")
                    )
                    profileGridItem(
                        title: "数据可信度",
                        value: displayConfidence(onboarding?.initialBodySnapshot.dataConfidence.rawValue.uppercased() ?? dashboard.recovery.confidence.rawValue.uppercased()),
                        icon: "checkmark.seal.fill",
                        color: VelaTheme.success
                    )
                }
                .padding(.vertical, 6)

                    if let missing = onboarding?.missingData, !missing.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.orange)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(bodyModelMaturityColor(state.maturity.overall)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("模型成熟度：\(bodyModelMaturityTitle(state.maturity.overall))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("\(state.maturity.baselineDays) 天基线 · \(state.maturity.behaviorPairs) 条行为信号 · \(state.maturity.trainingSessions) 次训练事实")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
            }

            if !state.claims.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.claims.prefix(3)) { claim in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(confidenceColor(claim.confidence))
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(claim.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text("\(claim.summary) 置信度：\(displayConfidence(claim.confidence.rawValue))，n=\(claim.evidenceCount)。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.muted)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }

            if !state.uncertainAreas.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("暂不下结论")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                        .textCase(.uppercase)
                    ForEach(state.uncertainAreas.prefix(3)) { area in
                        Text("• \(area.title)：\(area.detail)")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.secondaryGroupedBackground))
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
                // Header Navigation Row to Inbox
                NavigationLink(destination: CoachArtifactInboxView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(RoundedRectangle(cornerRadius: 8).fill(VelaTheme.accent))
                        
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
                                    .background(RoundedRectangle(cornerRadius: 8).fill(artifactColor(for: artifact.type)))
                                
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
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: cs == .dark ? "#2C2C2E" : "#F2F2F7")))
                        
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
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
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
            VelaAppState.shared.routeToTab(1)
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
        case .postWorkoutReview, .trainingAdjustment, .workoutReadiness: return VelaTheme.strain
        case .eveningReview: return VelaTheme.sleep
        case .wikiUpdateProposal: return Color(hex: "#FF9F0A")
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
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#007AFF"), Color(hex: "#00C6FF"), Color(hex: "#AF52DE")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: Color(hex: "#007AFF").opacity(0.3), radius: 8, y: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("\(timeGreeting), Weizhou", "\(timeGreeting)，Weizhou"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                
                HStack(spacing: 6) {
                    Text(bodyModelMaturityTitle(bodyModelState.maturity.overall))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(bodyModelMaturityColor(bodyModelState.maturity.overall)))
                    
                    Text("\(bodyModelState.maturity.behaviorPairs) 信号 · \(bodyModelState.maturity.trainingSessions) 训练事实")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
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
        
        let signalSub = "同步质量: \(displayConfidence(onboarding?.initialBodySnapshot.dataConfidence.rawValue.uppercased() ?? dashboard.recovery.confidence.rawValue.uppercased()).prefix(1))"
        
        let trustSub = "已确认 \(coachArtifacts.count) 个建议"
        
        let settingsSub = "\(dailyCalorieTarget) kcal 目标"

        return VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("Action & Settings Hub", "功能与设置中心"))
                .font(VelaTheme.caption1())
                .fontWeight(.bold)
                .foregroundStyle(VelaTheme.muted)
                .textCase(.uppercase)
                .padding(.leading, 2)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                hubActionCell(title: "健康手记", sub: journalSub, icon: "book.pages.fill", color: Color(hex: "#FF9F0A"), destination: VelaJournalView())
                hubActionCell(title: "健康档案", sub: wikiSub, icon: "doc.text.fill", color: VelaTheme.muted, destination: UserWikiArchiveView())
                hubActionCell(title: "生物资料", sub: bioSub, icon: "person.text.rectangle.fill", color: Color(hex: "#00A896"), destination: BiologyView())
                hubActionCell(title: "AI 模型", sub: aiModelSub, icon: "cpu.fill", color: Color(hex: "#AF52DE"), destination: AIModelSettingsView())
                hubActionCell(title: "数据信号", sub: signalSub, icon: "waveform.path.ecg.rectangle.fill", color: Color(hex: "#30A2FF"), destination: DataCoverageView())
                hubActionCell(title: "信任中心", sub: trustSub, icon: "checkmark.shield.fill", color: VelaTheme.success, destination: TrustCenterView())
                hubActionCell(title: "系统设置", sub: settingsSub, icon: "gearshape.fill", color: Color(hex: "#5C6BC0"), destination: VelaSettingsView())
            }
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 8).fill(color))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(sub)
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
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
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.surface))
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
                .background(RoundedRectangle(cornerRadius: 8).fill(color))
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
                    .background(RoundedRectangle(cornerRadius: 8).fill(color))
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
        case .seed: return Color(hex: "#FF9F0A")
        case .learning: return VelaTheme.accent
        case .stable: return VelaTheme.success
        }
    }

    private func confidenceColor(_ confidence: DataConfidence) -> Color {
        switch confidence {
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
    }
}

// MARK: - VelaJournalView — Bevel Replica Journal Tab
// Persisted journal checklist × Golden calendar checks strip × Segments cluster toggles

struct VelaJournalView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared

    private static let lookbackDays = 42
    private var lookbackStart: Date {
        Calendar.current.date(byAdding: .day, value: -Self.lookbackDays, to: dashboardVM.selectedDate) ?? dashboardVM.selectedDate
    }

    @State private var entries: [JournalEntryRecord] = []

    // Local states for custom segmented values (0:✕, 1:–, 2:✓)
    @State private var lowCarbState: Int = 1
    @State private var addedSugarState: Int = 1
    @State private var ketoDietState: Int = 1
    @State private var bedDeviceState: Int = 1
    
    // Log row dynamic display values
    @State private var caffeineValueText: String = "- mg"
    @State private var hydrationValueText: String = "- ml"
    @State private var moodValueText: String = "-"
    @State private var alcoholValueText: String = "- 杯"
    
    // For navigation/sheet triggers
    @State private var showCaffeineLogger = false
    @State private var showMoodLogger = false
    @State private var showWaterLogger = false
    @State private var showAlcoholLogger = false
    @State private var showBehaviorQuickNote = false
    @State private var entryPendingDeletion: JournalEntryRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 1. Journal Header Title Row
                journalHeader
                
                // 2. Weekly Calendar Checks strip
                weeklyChecksStrip

                behaviorQuickNoteCard
                
                // 3. Category daytime title
                VStack(alignment: .leading, spacing: 12) {
                    Text(dateSectionTitle(for: dashboardVM.selectedDate))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .padding(.top, 4)
                    
                    Text("习惯与记录")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                        .textCase(.uppercase)
                        .padding(.leading, 2)
                    
                    // Checklist Rows
                    VStack(spacing: 10) {
                        // Row 1: 低碳水化合物 (Bread icon + segment)
                        segmentedJournalRow(
                            icon: "fork.knife",
                            title: "低碳水化合物",
                            state: $lowCarbState
                        )
                        
                        // Row 2: 咖啡因 (Coffee cup icon + log chevron)
                        inputJournalRow(
                            icon: "cup.and.saucer.fill",
                            title: "咖啡因",
                            valuePlaceholder: caffeineValueText,
                            onTap: { showCaffeineLogger = true }
                        )
                        
                        // Row 3: 每日心情 (Smiling face icon + log chevron)
                        inputJournalRow(
                            icon: "face.smiling.fill",
                            title: "每日心情",
                            valuePlaceholder: moodValueText,
                            onTap: { showMoodLogger = true }
                        )
                        
                        // Row 4: 添加糖 (Candy icon + segment)
                        segmentedJournalRow(
                            icon: "birthday.cake.fill",
                            title: "添加糖",
                            state: $addedSugarState
                        )
                        
                        // Row 5: 生酮饮食 (Avocado/Leaf icon + segment)
                        segmentedJournalRow(
                            icon: "leaf.fill",
                            title: "生酮饮食",
                            state: $ketoDietState
                        )
                        
                        // Row 6: 补水 (Water drop icon + log chevron)
                        inputJournalRow(
                            icon: "drop.fill",
                            title: "补水",
                            valuePlaceholder: hydrationValueText,
                            onTap: { showWaterLogger = true }
                        )
                        
                        // Row 7: 酒 (Wine glass icon + log chevron)
                        inputJournalRow(
                            icon: "wineglass.fill",
                            title: "酒",
                            valuePlaceholder: alcoholValueText,
                            onTap: { showAlcoholLogger = true }
                        )
                        
                        // Row 8: 在床上使用设备 (Phone icon + segment)
                        segmentedJournalRow(
                            icon: "iphone",
                            title: "在床上使用设备",
                            state: $bedDeviceState
                        )
                    }
                }
                
                if !selectedDayEntries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("今日手记历史")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .textCase(.uppercase)
                            .padding(.leading, 2)
                        
                        VStack(spacing: 8) {
                            ForEach(selectedDayEntries) { entry in
                                HStack(spacing: 12) {
                                    Image(systemName: iconForEntry(entry))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(colorForEntry(entry)))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(displayTitleForEntry(entry))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(VelaTheme.fg)
                                            
                                            Text(entry.createdAt.formatted(.dateTime.hour().minute()))
                                                .font(.system(size: 11))
                                                .foregroundStyle(VelaTheme.muted)
                                        }
                                        
                                        if !entry.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(entry.note)
                                                .font(.system(size: 12))
                                                .foregroundStyle(VelaTheme.muted)
                                                .lineLimit(2)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button {
                                        entryPendingDeletion = entry
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(VelaTheme.muted)
                                            .frame(width: 28, height: 28)
                                            .background(Circle().fill(VelaTheme.systemGroupedBackground))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("删除手记：\(displayTitleForEntry(entry))")
                                    .accessibilityHint("删除前会要求确认")
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(VelaTheme.cardBg)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                                )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            loadRealJournalData()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            loadRealJournalData()
        }
        .onChange(of: entries) { _, _ in
            loadRealJournalData()
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            loadRealJournalData()
        }
        .alert(
            "删除这条手记？",
            isPresented: Binding(
                get: { entryPendingDeletion != nil },
                set: { if !$0 { entryPendingDeletion = nil } }
            ),
            presenting: entryPendingDeletion
        ) { entry in
            Button("删除", role: .destructive) {
                deleteEntry(entry)
                entryPendingDeletion = nil
            }
            Button("取消", role: .cancel) {
                entryPendingDeletion = nil
            }
        } message: { entry in
            Text("将永久删除“\(displayTitleForEntry(entry))”。")
        }
        .sheet(isPresented: $showCaffeineLogger) {
            CaffeineLoggerView { amount in
                saveQuickEntry(tags: ["caffeine", "咖啡因"], note: "摄入咖啡因 \(Int(amount)) mg", value: amount, unit: "mg")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showWaterLogger) {
            WaterLoggerView { amount in
                saveQuickEntry(tags: ["hydration", "补水"], note: "饮水 \(Int(amount)) ml", value: amount, unit: "ml")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showMoodLogger) {
            MoodLoggerView { score, note in
                let moodText = formatMoodValue(score)
                saveQuickEntry(tags: ["mood", "每日心情"], note: "心情: \(moodText). 备注: \(note)", value: score)
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showAlcoholLogger) {
            AlcoholLoggerView { amount in
                saveQuickEntry(tags: ["alcohol", "酒"], note: "饮酒 \(amount) 标准杯", value: amount, unit: "杯")
            }
            .presentationDetents([.medium])
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(isPresented: $showBehaviorQuickNote) {
            BehaviorQuickNoteSheet { note in
                saveBehaviorQuickNote(note)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
    }

    private var selectedDayEntries: [JournalEntryRecord] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        return entries.filter { calendar.isDate($0.createdAt, inSameDayAs: targetDay) }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }

    private func iconForEntry(_ entry: JournalEntryRecord) -> String {
        if entry.tags.contains("低碳水化合物") { return "fork.knife" }
        if entry.tags.contains("添加糖") { return "birthday.cake.fill" }
        if entry.tags.contains("生酮饮食") { return "leaf.fill" }
        if entry.tags.contains("在床上使用设备") { return "iphone" }
        if entry.tags.contains("caffeine") || entry.tags.contains("咖啡因") { return "cup.and.saucer.fill" }
        if entry.tags.contains("hydration") || entry.tags.contains("补水") { return "drop.fill" }
        if entry.tags.contains("mood") || entry.tags.contains("每日心情") { return "face.smiling.fill" }
        if entry.tags.contains("alcohol") || entry.tags.contains("酒") { return "wineglass.fill" }
        return "text.bubble.fill"
    }

    private func colorForEntry(_ entry: JournalEntryRecord) -> Color {
        if entry.tags.contains("低碳水化合物") { return Color.orange }
        if entry.tags.contains("添加糖") { return Color.purple }
        if entry.tags.contains("生酮饮食") { return Color.green }
        if entry.tags.contains("在床上使用设备") { return Color.blue }
        if entry.tags.contains("caffeine") || entry.tags.contains("咖啡因") { return Color(hex: "#8B5A2B") }
        if entry.tags.contains("hydration") || entry.tags.contains("补水") { return Color(hex: "#4285F4") }
        if entry.tags.contains("mood") || entry.tags.contains("每日心情") { return Color(hex: "#FFB74D") }
        if entry.tags.contains("alcohol") || entry.tags.contains("酒") { return Color(hex: "#8B0000") }
        return Color(hex: "#5B8C6F")
    }

    private func displayTitleForEntry(_ entry: JournalEntryRecord) -> String {
        if entry.tags.contains("低碳水化合物") { return "低碳水化合物" }
        if entry.tags.contains("添加糖") { return "添加糖" }
        if entry.tags.contains("生酮饮食") { return "生酮饮食" }
        if entry.tags.contains("在床上使用设备") { return "在床上使用设备" }
        if entry.tags.contains("caffeine") || entry.tags.contains("咖啡因") {
            if let val = entry.value {
                return "咖啡因: \(Int(val)) mg"
            }
            return "咖啡因"
        }
        if entry.tags.contains("hydration") || entry.tags.contains("补水") {
            if let val = entry.value {
                return "饮水: \(Int(val)) ml"
            }
            return "补水"
        }
        if entry.tags.contains("mood") || entry.tags.contains("每日心情") {
            return "每日心情"
        }
        if entry.tags.contains("alcohol") || entry.tags.contains("酒") {
            if let val = entry.value {
                return "饮酒: \(val) 杯"
            }
            return "饮酒"
        }
        return entry.tags.first(where: { $0 != "behavior_signal" && !$0.hasPrefix("behavior:") && !$0.hasPrefix("intensity:") && !$0.hasPrefix("timing:") }) ?? "手记"
    }

    private func deleteEntry(_ entry: JournalEntryRecord) {
        modelContext.delete(entry)
        try? modelContext.save()
        loadRealJournalData()
    }

    // MARK: - Date Formatting Helpers
    private func headerDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func dateSectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天的条目"
        } else if calendar.isDateInYesterday(date) {
            return "昨天的条目"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = "M月d日的条目"
            return formatter.string(from: date)
        }
    }

    private func formatMoodValue(_ val: Double) -> String {
        let intVal = Int(val)
        switch intVal {
        case 1: return "😞 糟糕"
        case 2: return "😐 平淡"
        case 3: return "🙂 还行"
        case 4: return "😃 开心"
        case 5: return "🤩 极佳"
        default: return "🙂 还行"
        }
    }

    // MARK: - SwiftData Loading Engine
    private func fetchEntries() {
        let calendar = Calendar.current
        let refDate = dashboardVM.selectedDate
        let startOfDayRef = calendar.startOfDay(for: refDate)
        
        let startLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -Self.lookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let endLimit = calendar.date(byAdding: .day, value: 1, to: startOfDayRef) ?? startOfDayRef
        
        let journalDesc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        self.entries = (try? modelContext.fetch(journalDesc)) ?? []
    }

    private func loadRealJournalData() {
        fetchEntries()
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        
        let dayEntries = entries.filter { entry in
            calendar.isDate(entry.createdAt, inSameDayAs: targetDay)
        }
        
        // Reset local states to default (1: –)
        lowCarbState = 1
        addedSugarState = 1
        ketoDietState = 1
        bedDeviceState = 1
        
        caffeineValueText = "- mg"
        hydrationValueText = "- ml"
        moodValueText = "-"
        alcoholValueText = "- 杯"
        
        let sortedDayEntries = dayEntries.sorted(by: { $0.createdAt > $1.createdAt })
        
        // Populate habit states (latest entry for each habit)
        for entry in sortedDayEntries {
            if entry.tags.contains("低碳水化合物"), let val = entry.value {
                lowCarbState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("添加糖"), let val = entry.value {
                addedSugarState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("生酮饮食"), let val = entry.value {
                ketoDietState = Int(val)
                break
            }
        }
        for entry in sortedDayEntries {
            if entry.tags.contains("在床上使用设备"), let val = entry.value {
                bedDeviceState = Int(val)
                break
            }
        }
        
        // Sum logger values
        let caffeineSum = dayEntries.filter { $0.tags.contains("caffeine") || $0.tags.contains("咖啡因") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if caffeineSum > 0 {
            caffeineValueText = "\(Int(caffeineSum)) mg"
        }
        
        let hydrationSum = dayEntries.filter { $0.tags.contains("hydration") || $0.tags.contains("补水") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if hydrationSum > 0 {
            hydrationValueText = "\(Int(hydrationSum)) ml"
        }
        
        let alcoholSum = dayEntries.filter { $0.tags.contains("alcohol") || $0.tags.contains("酒") }.map { $0.value ?? 0.0 }.reduce(0.0, +)
        if alcoholSum > 0 {
            alcoholValueText = String(format: "%.1f 杯", alcoholSum)
        }
        
        // Latest mood
        if let latestMoodEntry = sortedDayEntries.first(where: { $0.tags.contains("mood") || $0.tags.contains("每日心情") }) {
            if let moodVal = latestMoodEntry.value {
                moodValueText = formatMoodValue(moodVal)
            }
        }
    }

    // MARK: - Journal Header Title Row
    private var journalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("手记")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(headerDateString(for: dashboardVM.selectedDate))
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                // Analysis button
                Button {
                    VelaAppState.shared.routeToCoach(question: journalAnalysisQuestion)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("分析")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .velaNativeCard(radius: 16)
                }
                .buttonStyle(.plain)
                
                // Ellipsis actions
                Menu {
                    Button("记录咖啡因") {
                        showCaffeineLogger = true
                    }
                    Button("记录饮水") {
                        showWaterLogger = true
                    }
                    Button("记录心情") {
                        showMoodLogger = true
                    }
                    Button("记录饮酒") {
                        showAlcoholLogger = true
                    }
                    Button("随手记一餐/行为") {
                        showBehaviorQuickNote = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.cardBg))
                        .overlay(Circle().stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var journalAnalysisQuestion: String {
        "请结合我在 \(dateSectionTitle(for: dashboardVM.selectedDate)) 的手记、标签和健康数据，分析可能影响恢复、睡眠和训练状态的模式，并给出下一步建议。"
    }

    private var behaviorQuickNoteCard: some View {
        Button {
            showBehaviorQuickNote = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: "#5B8C6F")))

                VStack(alignment: .leading, spacing: 4) {
                    Text("随手记一餐或一个行为")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("一句话即可：火锅、啤酒、睡前咖啡、吃撑、喝水少。无需估克重。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekly Calendar Checks strip
    private var weeklyChecksStrip: some View {
        let calendar = Calendar.current
        let selected = dashboardVM.selectedDate
        let weekday = calendar.component(.weekday, from: selected) // 1 = Sunday, 7 = Saturday
        let daysToSubtract = weekday - 1
        let sunday = calendar.date(byAdding: .day, value: -daysToSubtract, to: calendar.startOfDay(for: selected)) ?? selected
        
        let weekDates: [Date] = (0..<7).compactMap { idx in
            calendar.date(byAdding: .day, value: idx, to: sunday)
        }
        
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        
        return HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { idx in
                let date = weekDates[idx]
                let isSelected = calendar.isDate(date, inSameDayAs: selected)
                let isToday = calendar.isDate(date, inSameDayAs: Date())
                let isFuture = calendar.startOfDay(for: date) > calendar.startOfDay(for: Date())
                let dayNumber = calendar.component(.day, from: date)
                
                // Let's check if there are habit entries on this day to show the golden checkmark!
                let hasEntry = entries.contains { entry in
                    calendar.isDate(entry.createdAt, inSameDayAs: date)
                }
                
                Button {
                    dashboardVM.selectDate(date)
                } label: {
                    VStack(spacing: 8) {
                        Text(weekdays[idx])
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                        
                        Text("\(dayNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(isSelected ? Color.white : VelaTheme.fg)
                            .frame(width: 26, height: 26)
                            .background(
                                Group {
                                    if isSelected {
                                        Circle()
                                            .fill(VelaTheme.accent) // Selected circle
                                    } else if isToday {
                                        Circle()
                                            .stroke(VelaTheme.accent, lineWidth: 1.5) // Today indicator
                                    }
                                }
                            )
                        
                        // Golden Circle Checkmark indicator
                        if hasEntry {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "#FFB74D")) // Soft gold/amber
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "#E5E5EA")) // Gray empty circle
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(isFuture)
                .opacity(isFuture ? 0.38 : 1)
                .accessibilityLabel("\(weekdays[idx]) \(dayNumber) 日，\(hasEntry ? "已有记录" : "暂无记录")\(isFuture ? "，未来日期不可选择" : "")")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .velaNativeCard(radius: 18)
    }

    // MARK: - Segmented Action Row (High-Fidelity SF Symbol Toggles)
    private func segmentedJournalRow(icon: String, title: String, state: Binding<Int>) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                // Colored icon
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            
            Spacer()
            
            // Custom segment selector container (✕/circle/✓ SF Symbols)
            HStack(spacing: 0) {
                segmentButton(title: title, index: 0, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, index: 1, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, index: 2, state: state)
            }
            .background(VelaTheme.systemGroupedBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .velaNativeCard(radius: 16)
    }

    private func segmentButton(title: String, index: Int, state: Binding<Int>) -> some View {
        let isActive = state.wrappedValue == index
        let activeLabelText = index == 0 ? "✕" : (index == 2 ? "✓" : "–")
        let accessibilityState = index == 0 ? "否" : (index == 2 ? "是" : "未记录")
        return Button {
            VelaHaptic.selection()
            state.wrappedValue = index
            saveQuickEntry(tags: [title], note: "习惯打卡: \(title) - \(activeLabelText)", value: Double(index))
        } label: {
            Group {
                switch index {
                case 0:
                    Image(systemName: isActive ? "xmark.circle.fill" : "xmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? VelaTheme.danger : VelaTheme.meta)
                case 2:
                    Image(systemName: isActive ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isActive ? VelaTheme.success : VelaTheme.meta)
                default:
                    Image(systemName: isActive ? "circle.fill" : "circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isActive ? VelaTheme.muted : VelaTheme.meta)
                }
            }
            .frame(width: 38, height: 32)
            .background(
                Group {
                    if isActive {
                        VelaTheme.cardBg
                            .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)：\(accessibilityState)")
        .accessibilityHint("设置为\(accessibilityState)")
    }

    // MARK: - Input logger Row (Caffeine, water, mood logs)
    private func inputJournalRow(icon: String, title: String, valuePlaceholder: String, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(alignment: .center) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text(valuePlaceholder)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.meta)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.meta)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(VelaTheme.systemGroupedBackground))
                        .overlay(Circle().stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .velaNativeCard(radius: 16)
        }
        .buttonStyle(.plain)
    }

    // MARK: - SwiftData saving engine
    private func saveQuickEntry(tags: [String], note: String, value: Double? = nil, unit: String? = nil) {
        let calendar = Calendar.current
        let now = Date()
        let selected = dashboardVM.selectedDate
        
        var components = calendar.dateComponents([.year, .month, .day], from: selected)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        
        let targetDate = calendar.date(from: components) ?? selected
        let targetStart = calendar.startOfDay(for: targetDate)
        let targetEnd = calendar.date(byAdding: .day, value: 1, to: targetStart) ?? targetDate
        
        let habitTags = Set(["低碳水化合物", "添加糖", "生酮饮食", "在床上使用设备", "mood", "每日心情"])
        let isHabitOrMood = tags.contains(where: { habitTags.contains($0) })
        
        if isHabitOrMood {
            let descriptor = FetchDescriptor<JournalEntryRecord>(
                predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= targetStart && $0.createdAt < targetEnd }
            )
            if let existingRecords = try? modelContext.fetch(descriptor) {
                if let matched = existingRecords.first(where: { rec in
                    rec.tags.contains(where: { tags.contains($0) })
                }) {
                    matched.value = value
                    matched.note = note
                    matched.unit = unit
                    matched.createdAt = targetDate
                    try? modelContext.save()
                    loadRealJournalData()
                    return
                }
            }
        }
        
        let entry = JournalEntryRecord(createdAt: targetDate, tags: tags, note: note, value: value, unit: unit)
        modelContext.insert(entry)
        do {
            try modelContext.save()
        } catch {
            print("Failed to save journal entry: \(error)")
        }
        loadRealJournalData()
    }

    private func saveBehaviorQuickNote(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let createdAt = selectedDayWithCurrentTime()
        let signals = BehaviorSignalExtractor.extract(from: trimmed, createdAt: createdAt, confidence: .aiInferred)
        let signalTags = signals.flatMap { signal in
            [
                "behavior:\(signal.tag.rawValue)",
                "intensity:\(signal.intensity.rawValue)",
                "timing:\(signal.timing.rawValue)"
            ]
        }
        let tags = Array(Set(["behavior_signal", "随手记"] + signalTags)).sorted()
        let entry = JournalEntryRecord(createdAt: createdAt, tags: tags, note: trimmed)
        modelContext.insert(entry)
        do {
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            print("Failed to save behavior quick note: \(error)")
        }
        loadRealJournalData()
    }

    private func selectedDayWithCurrentTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let selected = dashboardVM.selectedDate
        var components = calendar.dateComponents([.year, .month, .day], from: selected)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: now)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second
        return calendar.date(from: components) ?? selected
    }
}

private struct BehaviorQuickNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    var onSave: (String) -> Void

    private let templates = ["火锅，吃得有点撑", "晚饭很晚", "睡前喝了咖啡", "喝了两杯啤酒", "今天喝水少", "外卖偏咸"]
    private var signals: [BehaviorSignal] {
        BehaviorSignalExtractor.extract(from: note, confidence: .aiInferred)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("随手记", systemImage: "text.bubble.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        Text("记录你觉得可能影响恢复、睡眠或训练的行为。这里不估算热量、克重或宏量营养，只给 Body Model 留低摩擦信号。")
                            .font(.system(size: 13))
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(3)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(templates, id: \.self) { template in
                                    Button {
                                        note = note.isEmpty ? template : "\(note)，\(template)"
                                    } label: {
                                        Text(template)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(VelaTheme.fg)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 7)
                                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !signals.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                                ForEach(signals) { signal in
                                    Text("\(signal.tag.displayTitle) · \(signal.intensity.rawValue)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(VelaTheme.accent)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.accent.opacity(0.12)))
                                }
                            }
                        } else {
                            Text("保存后仍会作为普通手记进入上下文；识别不到标签时不会强行编造。")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))

                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave(note)
                        dismiss()
                    } label: {
                        Text("保存随手记")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.fg))
                    }
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("随手记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

// MARK: - CaffeineLoggerView
struct CaffeineLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customAmount: Double = 80.0
    
    let quickOptions = [
        ("浓缩咖啡", "espresso", 64.0, "cup.and.saucer.fill"),
        ("美式咖啡", "americano", 120.0, "cup.and.saucer"),
        ("拿铁", "latte", 80.0, "cup.and.saucer.fill"),
        ("绿茶", "greentea", 35.0, "leaf.fill")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录咖啡因")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("输入或选择摄入的咖啡因量。这会有助于 AI 预测它对你深度睡眠和能量水平的长期影响。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(customAmount))")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(VelaTheme.accent)
                            Text("mg")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        Slider(value: $customAmount, in: 0...400, step: 5)
                            .tint(VelaTheme.accent)
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷选项")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickOptions, id: \.1) { name, key, val, icon in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        customAmount = val
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(VelaTheme.accent)
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                                            
                                            Text(name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(VelaTheme.fg)
                                            
                                            Text("\(Int(val)) mg")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(VelaTheme.meta)
                                        }
                                        .frame(width: 90, height: 110)
                                        .velaNativeCard(radius: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(customAmount == val ? VelaTheme.accent : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave(customAmount)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                            .shadow(color: VelaTheme.accent.opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - WaterLoggerView
struct WaterLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customAmount: Double = 250.0
    
    let quickOptions = [
        ("小杯", 250.0, "drop.fill"),
        ("中杯", 350.0, "drop.fill"),
        ("大杯", 500.0, "drop.fill"),
        ("整瓶", 750.0, "drop.fill")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录补水")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("记录今天摄入的水分，帮助你回顾补水习惯与后续状态。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(Int(customAmount))")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#4285F4"))
                            Text("ml")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        Slider(value: $customAmount, in: 0...1000, step: 50)
                            .tint(Color(hex: "#4285F4"))
                            .padding(.horizontal, 20)
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("快捷选项")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(quickOptions, id: \.1) { name, val, icon in
                                    Button {
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        customAmount = val
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: icon)
                                                .font(.system(size: 20))
                                                .foregroundStyle(Color(hex: "#4285F4"))
                                                .frame(width: 44, height: 44)
                                                .background(Circle().fill(Color(hex: "#E8F0FE")))
                                            
                                            Text(name)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(VelaTheme.fg)
                                            
                                            Text("\(Int(val)) ml")
                                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                                .foregroundStyle(VelaTheme.meta)
                                        }
                                        .frame(width: 90, height: 110)
                                        .velaNativeCard(radius: 16)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .stroke(customAmount == val ? Color(hex: "#4285F4") : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave(customAmount)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#4285F4")))
                            .shadow(color: Color(hex: "#4285F4").opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - MoodLoggerView
struct MoodLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double, String) -> Void
    
    @State private var selectedScore: Double = 3.0
    @State private var noteText: String = ""
    
    let moodOptions = [
        (1.0, "😞", "糟糕"),
        (2.0, "😐", "平淡"),
        (3.0, "🙂", "还行"),
        (4.0, "😃", "开心"),
        (5.0, "🤩", "极佳")
    ]
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录心情")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("记录今天你的整体情绪感受。AI 会基于心率变异性(HRV)等生理指标与心境波动建立深度习惯网络模型。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    HStack(spacing: 10) {
                        ForEach(moodOptions, id: \.0) { score, emoji, label in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedScore = score
                            } label: {
                                VStack(spacing: 6) {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                    Text(label)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(selectedScore == score ? VelaTheme.fg : VelaTheme.meta)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(selectedScore == score ? Color.white : Color(hex: "#E5E5EA").opacity(0.2))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(selectedScore == score ? VelaTheme.accent : Color.clear, lineWidth: 1.5)
                                )
                                .shadow(color: Color.black.opacity(selectedScore == score ? 0.03 : 0.0), radius: 4, y: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("今日备注 (可选)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                            .padding(.leading, 4)
                        
                        TextField("记录一些让你开心或焦虑的小事...", text: $noteText)
                            .font(.system(size: 14))
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
                            )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    Button {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        onSave(selectedScore, noteText)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(VelaTheme.accent))
                            .shadow(color: VelaTheme.accent.opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

// MARK: - AlcoholLoggerView
struct AlcoholLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Double) -> Void
    
    @State private var customDrinks: Double = 1.0
    
    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Text("记录饮酒")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.meta)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("饮酒可能影响睡眠连续性、夜间心率和次日恢复。影响程度会随摄入量、饮酒时间、睡眠和个体差异而变化；记录后可结合自己的趋势回看。")
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(String(format: "%.1f", customDrinks))
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#8B0000"))
                            Text("标准杯")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        
                        HStack(spacing: 40) {
                            Button {
                                if customDrinks > 0 {
                                    customDrinks -= 0.5
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(VelaTheme.muted)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                customDrinks += 0.5
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(VelaTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .velaNativeCard(radius: 20)
                    .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("标准杯换算")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Text("本页按约 10 克纯酒精记为 1 标准杯，便于统一记录。不同地区的标准不同，实际酒精量应以饮品容量和酒精度为准：\n· 普通啤酒约 330 ml、4.5%\n· 红葡萄酒约 150 ml、12%\n· 烈性酒约 45 ml、40%")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(5)
                    }
                    .padding(18)
                    .velaNativeCard(radius: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
                    )
                    .padding(.horizontal, 20)
                    
                    Button {
                        onSave(customDrinks)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 25, style: .continuous).fill(Color(hex: "#8B0000")))
                            .shadow(color: Color(hex: "#8B0000").opacity(0.2), radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
        }
        .background(VelaTheme.systemGroupedBackground.ignoresSafeArea())
    }
}

struct CoachArtifactInboxView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]
    
    @State private var selectedWorkoutForDetail: WorkoutSummary?
    
    var body: some View {
        List {
            if coachArtifacts.isEmpty {
                VStack(spacing: 12) {
                    Spacer().frame(height: 40)
                    Image(systemName: "tray.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(VelaTheme.muted)
                    Text("收件箱为空")
                        .font(VelaTheme.headline())
                        .foregroundStyle(VelaTheme.fg)
                    Text("与 Coach 聊天、记录训练或查看每日健康分析后，将在此处收到主动生成的分析简报与优化建议。")
                        .font(VelaTheme.caption1())
                        .foregroundStyle(VelaTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else {
                ForEach(coachArtifacts) { record in
                    Section {
                        CoachArtifactCard(artifact: record.artifact, compact: false) { action in
                            handleArtifactAction(action, artifact: record.artifact)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(VelaTheme.systemGroupedBackground)
        .scrollContentBackground(.hidden)
        .navigationTitle("AI 建议收件箱")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
        .onAppear {
            deduplicateArtifacts()
        }
    }

    private func deduplicateArtifacts() {
        guard let records = try? modelContext.fetch(FetchDescriptor<CoachArtifactRecord>()) else { return }
        
        var workoutArtifacts: [String: [CoachArtifactRecord]] = [:]
        var dateTypeArtifacts: [String: [CoachArtifactRecord]] = [:]
        let calendar = Calendar.current
        
        for record in records {
            if record.type == CoachArtifactType.postWorkoutReview.rawValue {
                if let workoutID = extractWorkoutID(from: record.actionsJSON) {
                    workoutArtifacts[workoutID, default: []].append(record)
                }
            } else {
                let dateStr = calendar.startOfDay(for: record.createdAt).description
                let key = "\(record.type)-\(dateStr)"
                dateTypeArtifacts[key, default: []].append(record)
            }
        }
        
        for (_, list) in workoutArtifacts where list.count > 1 {
            let sorted = list.sorted { $0.createdAt > $1.createdAt }
            for dup in sorted.dropFirst() {
                modelContext.delete(dup)
            }
        }
        
        for (_, list) in dateTypeArtifacts where list.count > 1 {
            let sorted = list.sorted { $0.createdAt > $1.createdAt }
            for dup in sorted.dropFirst() {
                modelContext.delete(dup)
            }
        }
        
        try? modelContext.save()
    }
    
    private func extractWorkoutID(from json: String) -> String? {
        guard let range = json.range(of: "\"workout_id\":\"") else { return nil }
        let startIndex = range.upperBound
        guard let endIndex = json[startIndex...].firstIndex(of: "\"") else { return nil }
        return String(json[startIndex..<endIndex])
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        VelaAppState.shared.logDebug("[CoachArtifactInboxView] handleArtifactAction: type=\(action.type), label=\(action.label), payload=\(action.payload)")
        if action.type == "start_check_in" {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Opening post-workout check-in")
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Opening post-workout impact")
            VelaAppState.shared.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        } else if let workoutIDString = action.payload["workout_id"],
           let id = UUID(uuidString: workoutIDString) {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Found workout_id: \(workoutIDString)")
            let descriptor = FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.id == id }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                let summary = WorkoutSummary(
                    id: record.id,
                    start: record.startedAt,
                    end: record.startedAt.addingTimeInterval(TimeInterval(record.durationMinutes * 60)),
                    activityName: record.title,
                    source: "strengthLog"
                )
                VelaAppState.shared.logDebug("[CoachArtifactInboxView] Setting selectedWorkoutForDetail: \(record.title)")
                selectedWorkoutForDetail = summary
            } else {
                VelaAppState.shared.logDebug("[CoachArtifactInboxView] Workout record not found for id: \(id)")
            }
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to recovery (tab 2)")
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to training (tab 1)")
            VelaAppState.shared.routeToTab(1)
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Triggering journal")
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.logDebug("[CoachArtifactInboxView] Routing to coach: \(action.label)")
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }
}

struct CoachArtifactDetailWrapper: View {
    @Environment(\.modelContext) private var modelContext
    let artifact: CoachArtifact
    @State private var selectedWorkoutForDetail: WorkoutSummary?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoachArtifactCard(artifact: artifact, compact: false) { action in
                    handleArtifactAction(action, artifact: artifact)
                }
                .padding(16)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle(artifact.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] handleArtifactAction: type=\(action.type), label=\(action.label), payload=\(action.payload)")
        if action.type == "start_check_in" {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Opening post-workout check-in")
            VelaAppState.shared.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        } else if action.type == "open_recovery_detail" {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Opening post-workout impact")
            VelaAppState.shared.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        } else if let workoutIDString = action.payload["workout_id"],
           let id = UUID(uuidString: workoutIDString) {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Found workout_id: \(workoutIDString)")
            let descriptor = FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.id == id }
            )
            if let record = try? modelContext.fetch(descriptor).first {
                let summary = WorkoutSummary(
                    id: record.id,
                    start: record.startedAt,
                    end: record.startedAt.addingTimeInterval(TimeInterval(record.durationMinutes * 60)),
                    activityName: record.title,
                    source: "strengthLog"
                )
                VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Setting selectedWorkoutForDetail: \(record.title)")
                selectedWorkoutForDetail = summary
            } else {
                VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Workout record not found for id: \(id)")
            }
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to recovery (tab 2)")
            VelaAppState.shared.routeToRecoveryDetail()
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to training (tab 1)")
            VelaAppState.shared.routeToTab(1)
        } else if action.type.contains("check") || action.type.contains("journal") {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Triggering journal")
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.logDebug("[CoachArtifactDetailWrapper] Routing to coach: \(action.label)")
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }

    private func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }
}

struct BodyModelEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Environment(\.colorScheme) private var cs
    
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
            saveError = "本次修改未能写入本机资料，请重试。"
            return false
        }
    }
}

// MARK: - BaselineRangeIndicator
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
                            let pct = 0.5 + (tod - base) / (base * 0.4) // max delta 20%
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

// MARK: - BodyModelDetailView (Cybernetic/Biological Body Calibration Panel)
struct BodyModelDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var cs
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    @State private var journalEntries: [JournalEntryRecord] = []
    @State private var dailySummaries: [DailyHealthSummaryRecord] = []
    @State private var strengthWorkouts: [StrengthWorkoutRecord] = []
    @State private var trainingResponses: [TrainingResponseRecord] = []
    @AppStorage("vela_user_age") private var profileAge = 0
    @AppStorage("vela_user_weight") private var profileWeight = 0.0
    @AppStorage("vela_user_height") private var profileHeight = 0.0
    @AppStorage("vela_user_biological_sex") private var profileSex = ""
    
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
        if (10...100).contains(profileAge) { values.append("\(profileAge) 岁") }
        if (25...350).contains(profileWeight) { values.append(String(format: "%.1f kg", profileWeight)) }
        if (100...250).contains(profileHeight) { values.append(String(format: "%.0f cm", profileHeight)) }
        if let sex = ["male": "男性", "female": "女性", "other": "其他"][profileSex] { values.append(sex) }
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
                // Glowy Bio-Signal Header
                headerCalibrationCard
                
                // Static parameters
                staticParametersSection
                
                // Physiological system calibration range indicators
                physiologicalSection
                
                // Behavioral sensitivity features
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
        VStack(alignment: .leading, spacing: 12) {
            Text("行为信号与待验证区域")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.muted)

            if bodyModelState.maturity.overall == .seed || bodyModelState.uncertainAreas.contains(where: { $0.id == "behavior_pairs" }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.muted)
                    Text("行为-结果配对仍在积累")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                    Text("继续用「随手记」记录酒精、咖啡因、晚餐时间、吃撑、补水等低摩擦信号。Vela 会先积累样本，再把它们和次日睡眠、HRV、RHR、恢复进行配对。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    bodyModelStatsRow(bodyModelState)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            } else {
                VStack(spacing: 12) {
                    bodyModelStatsRow(bodyModelState)
                    ForEach(bodyModelState.claims) { claim in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(claim.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(claim.summary)
                                .font(.system(size: 12))
                                .foregroundStyle(VelaTheme.muted)
                                .lineSpacing(3)
                            Text("置信度 \(displayConfidence(claim.confidence.rawValue)) · n=\(claim.evidenceCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(confidenceColor(claim.confidence))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private func bodyModelStatsRow(_ state: BodyModelState) -> some View {
        HStack(spacing: 8) {
            detailStat("基线", "\(state.maturity.baselineDays)天")
            detailStat("行为", "\(state.maturity.behaviorPairs)条")
            detailStat("训练", "\(state.maturity.trainingSessions)次")
        }
        .padding(.horizontal, 12)
    }

    private func detailStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
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
