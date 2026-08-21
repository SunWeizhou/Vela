import SwiftUI
import SwiftData

struct VelaMeView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    @Environment(\.colorScheme) private var cs
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var appState = VelaAppState.shared
    @ObservedObject private var backfill = HistoricalBackfillCoordinator.shared
    @ObservedObject private var xunjiBackfill = XunjiHistoryBackfillService.shared

    /// 身体模型与行为配对使用三年窗口（回填后立即拟合，而非等 42 天慢慢积累）。
    private static let lookbackDays = 1100
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
        // 个人页自给自足：用自己拉取的三年每日记录计算长线基准，
        // 不依赖 dashboard.longTermBaselines（缓存启动路径可能尚未刷新）。
        let ownReport = LongTermBaselineEngine.compute(
            points: dailySummaries.map(\.longTermBaselinePoint),
            today: dashboard.date
        )
        let dashboardReport = dashboard.longTermBaselines
        let report: LongTermBaselineReport? = (dashboardReport?.daysOfData ?? 0) >= ownReport.daysOfData
            ? dashboardReport
            : ownReport
        return BodyModelBuilder().build(
            onboarding: onboarding,
            dailySummaries: dailySummaries,
            journalEntries: journalEntries,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            longTermBaselines: report,
            asOf: dashboard.date
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                profileHeader
                bodyModelOverviewCard
                dataHistorySection
                coachMemoryCard
                actionSettingsHub
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedWorkoutForDetail) { summary in
            NavigationStack {
                WorkoutDetailView(workout: summary)
            }
        }
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            backfill.refreshState()
            loadMeData()
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            guard isActiveSurface else { return }
            loadMeData()
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            guard isActiveSurface else { return }
            backfill.refreshState()
            loadMeData()
        }
    }

    /// 三年健康数据：轨迹查看 + Apple 健康历史回填（入口 + 进度）。
    private var dataHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaRhythmSectionHeader(
                eyebrow: "",
                title: "三年健康数据",
                actionTitle: nil,
                action: {}
            )

            VStack(spacing: 0) {
                NavigationLink(destination: LongTermHealthTrendView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.rhythmMist.opacity(0.72)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("三年健康轨迹")
                                .font(VelaTheme.body())
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text("静息心率 · HRV · 睡眠 · 体重 · 步数")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.cardPress)

                Divider().padding(.leading, 54)

                NavigationLink(destination: HistoricalBackfillView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.rhythmMist.opacity(0.72)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("回填 Apple 健康历史")
                                .font(VelaTheme.body())
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text(backfill.stateText)
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        Spacer()

                        if backfill.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.cardPress)

                Divider().padding(.leading, 54)

                // 深度专项批次 3：训记历史批量回填（三年 e1RM/容量/肌群轨迹的前置）。
                NavigationLink(destination: XunjiHistoryBackfillView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath.icloud")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.rhythmMist.opacity(0.72)))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("回填训记训练历史")
                                .font(VelaTheme.body())
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text("补全动作、组数与重量历史")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        Spacer()

                        if xunjiBackfill.isRunning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.cardPress)
            }
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
        }
    }

    private var bodyModelOverviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaRhythmSectionHeader(
                eyebrow: "",
                title: "Vela 如何认识你",
                actionTitle: nil,
                action: {}
            )

            NavigationLink(destination: BodyModelDetailView()) {
                bodyModelOverviewContent
            }
            .buttonStyle(.cardPress)
        }
    }

    private var bodyModelOverviewContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(width: 38, height: 38)
                    .background(VelaTheme.rhythmMist.opacity(0.76), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    // 联通专项批次 2：不把成熟度做成常驻标签（产品方向「不做成绩单」）。
                    Text("个人上下文")
                        .font(.system(.headline, design: .default, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
                    .padding(.top, 12)
            }

            Divider().overlay(VelaTheme.rhythmMist)

            HStack(spacing: 0) {
                modelFact(title: "长期目标", value: profileGoalText, detail: profileExperienceText)
                Rectangle()
                    .fill(VelaTheme.rhythmMist)
                    .frame(width: 1, height: 54)
                    .padding(.horizontal, 16)
                modelFact(title: "训练节奏", value: profileFrequencyText, detail: profileDurationText)
            }

            HStack(spacing: 8) {
                contextPill("\(bodyModelState.maturity.behaviorPairs) 个行为信号", icon: "circle.hexagongrid")
                contextPill("\(bodyModelState.maturity.trainingSessions) 次训练事实", icon: "figure.strengthtraining.traditional")
                if bodyModelState.claims.contains(where: { $0.id == "training_outcome_pairing" }) {
                    contextPill("训练-结果已配对", icon: "arrow.trianglehead.2.clockwise.rotate.90")
                }
            }

        }
        .padding(16)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func contextPill(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VelaTheme.rhythmInkSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 9)
            .frame(minHeight: 30)
            .background(VelaTheme.rhythmMist.opacity(0.62), in: Capsule())
    }

    private func modelFact(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(VelaTheme.caption2())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.rhythmInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bodyModelEvidencePanel(_ state: BodyModelState) -> some View {
        JournalTagInsights(state: state)
    }

    private var coachMemoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaRhythmSectionHeader(
                eyebrow: "",
                title: "建议与记忆",
                actionTitle: nil,
                action: {}
            )

            VStack(spacing: 0) {
                NavigationLink(destination: CoachArtifactInboxView()) {
                    HStack(spacing: 12) {
                        Image(systemName: "tray.full.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.rhythmMist.opacity(0.72)))
                        
                        Text("建议收件箱")
                            .font(VelaTheme.body())
                            .foregroundStyle(VelaTheme.rhythmInk)
                        
                        Spacer()
                        
                        HStack(spacing: 6) {
                            Text("\(coachArtifacts.count) 条历史")
                                .font(VelaTheme.subheadline())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
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
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
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
        VStack(alignment: .leading, spacing: 8) {
            Text(timeGreeting)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .padding(.top, 4)
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

        return VStack(alignment: .leading, spacing: 12) {
            VelaRhythmSectionHeader(
                eyebrow: "",
                title: "资料与设置",
                actionTitle: nil,
                action: {}
            )
            
            VStack(spacing: 0) {
                hubActionCell(title: "健康手记", sub: journalSub, icon: "book.pages.fill", color: VelaTheme.systemOrange, destination: VelaJournalView())
                Divider().padding(.leading, 58)
                hubActionCell(title: "档案资料", sub: wikiSub, icon: "doc.text.fill", color: VelaTheme.muted, destination: UserWikiArchiveView())
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
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VelaTheme.rhythmMist.opacity(0.72)))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text(sub)
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.6))
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
        case "strength": return L10n.t("Strength", "力量训练")
        case "hybrid": return L10n.t("Hybrid", "混合训练")
        case "endurance": return L10n.t("Endurance", "耐力训练")
        // 旧版遗留值兼容
        case "mixed": return L10n.t("Mixed", "混合训练")
        case "cardio": return L10n.t("Cardio", "有氧训练")
        case "yoga": return L10n.t("Yoga", "瑜伽伸展")
        default: return L10n.t("Not set", "待设置")
        }
    }

    private func displayCoachingStyle(_ style: String) -> String {
        switch style {
        case "direct": return L10n.t("Direct", "直截了当")
        case "balanced": return L10n.t("Balanced", "平衡适中")
        case "explanatory": return L10n.t("Detailed", "详细解析")
        // 旧版遗留值兼容
        case "encouraging": return L10n.t("Encouraging", "积极鼓励")
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

// MARK: - Historical backfill page

/// 三年 Apple 健康历史回填页面：进度条 + 开始/停止 + 错误提示。
/// 任务由 HistoricalBackfillCoordinator.shared 持有，退出页面也会继续跑。
struct HistoricalBackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var coordinator = HistoricalBackfillCoordinator.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(width: 42, height: 42)
                        .background(VelaTheme.rhythmMist, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("回填三年健康历史")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text(coordinator.stateText)
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)

                Text("把 Apple 健康里近三年的静息心率、HRV、睡眠、步数、活动能量、体重与训练记录读入 Vela。回填后，长期趋势、今年 vs 去年对比与历年训练量立即可用。原始数据只留在本机。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView(value: coordinator.progress.percent)
                        .tint(VelaTheme.rhythmDeep)

                    HStack {
                        Text("\(coordinator.progress.completedDays) / \(coordinator.progress.totalDays) 天")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("可随时停止，进度已保存")
                            .font(.system(size: 10))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }

                if let error = coordinator.lastError {
                    Text("回填中断：\(error)")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.statePoor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    if coordinator.isRunning {
                        coordinator.cancel()
                    } else {
                        coordinator.start(
                            queryService: services.queryService,
                            modelContext: modelContext
                        )
                    }
                } label: {
                    Text(coordinator.isRunning ? "停止回填" : "开始回填")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.cardPress)
                .disabled(coordinator.progress.isComplete && !coordinator.isRunning)

                if coordinator.progress.isComplete {
                    Text("回填已完成。三年健康轨迹与历年训练量现在都已就绪。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("历史回填")
        .velaRhythmDetailChrome()
        .onAppear {
            coordinator.refreshState()
        }
    }
}

/// 深度专项批次 3：训记历史批量回填页——逐日拉取训记训练（动作/组数/重量），
/// 断点续传。三年 e1RM/容量/肌群频率轨迹的前置条件。
struct XunjiHistoryBackfillView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var service = XunjiHistoryBackfillService.shared
    @State private var apiKey = ""
    @State private var loadKeyFailed = false

    private var progressPercent: Double {
        guard service.totalDays > 0 else { return 0 }
        return min(1, Double(service.completedDays) / Double(service.totalDays))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(width: 42, height: 42)
                        .background(VelaTheme.rhythmMist, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("回填训记训练历史")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("逐日补全动作、组数与重量")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                    Spacer()
                }
                .padding(.bottom, 2)

                Text("把训记里的历史训练（动作、组数、重量、时长）逐日读入 Vela，用于个人纪录、容量轨迹与肌群疲劳的长期分析。原始数据只留在本机；进度会保存，可随时停止续传。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if loadKeyFailed {
                    Text("未找到训记密钥。请先在训练页填写训记 API Key。")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.statePoor)
                }

                VStack(alignment: .leading, spacing: 12) {
                    ProgressView(value: progressPercent)
                        .tint(VelaTheme.rhythmDeep)

                    HStack {
                        Text("\(service.completedDays) / \(service.totalDays) 天 · 已导入 \(service.importedCount) 条")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        Spacer()
                        Text("可随时停止，进度已保存")
                            .font(.system(size: 10))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                    }
                }
                .padding(16)
                .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                }

                if let error = service.errorMessage {
                    Text("回填暂停：\(error)")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.statePoor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    Task { await startOrStop() }
                } label: {
                    Text(service.isRunning ? "停止回填" : "开始回填")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.cardPress)

                if service.completedDays >= service.totalDays, service.totalDays > 0 {
                    Text("回填已完成。历史动作、组数与重量已可用于长期分析。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 18)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("训记历史回填")
        .velaRhythmDetailChrome()
        .onAppear {
            if let saved = try? KeychainService.shared.read(account: "xunji_open_api_key") {
                apiKey = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    @MainActor
    private func startOrStop() async {
        if service.isRunning { return }
        guard !apiKey.isEmpty else {
            loadKeyFailed = true
            return
        }
        loadKeyFailed = false
        try? KeychainService.shared.save(apiKey, account: "xunji_open_api_key")
        await service.run(modelContext: modelContext, apiKey: apiKey)
        VelaAppState.shared.markLocalDataChanged()
    }
}
