import SwiftUI
import SwiftData

struct VelaMeView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \OnboardingState.updatedAt, order: .reverse)
    private var onboardingStates: [OnboardingState]
    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var journalEntries: [JournalEntryRecord]
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse)
    private var dailySummaries: [DailyHealthSummaryRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var trainingResponses: [TrainingResponseRecord]

    private var onboarding: OnboardingState? { onboardingStates.first }
    private var dashboard: DashboardSummary { dashboardVM.dashboard }
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
                bodyModelUnifiedCard
                coachMemoryCard
                personalToolsCard
                dataAndTrustCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var bodyModelUnifiedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Body Model")
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
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 14) {
                // Brief Summary Quote Bubble with gold sparkles and sage-green tint
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#FFCC00"))
                        .padding(.top, 2)
                    Text(onboarding?.firstBrief.isEmpty == false ? onboarding!.firstBrief : "你的训练目标、偏好、设备和健康数据已合并为 Coach 的个人上下文。")
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
                            Text("目标 / GOAL")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Text(displayGoal(onboarding?.goalProfile.primaryGoal ?? "maintain"))
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(displayExperience(onboarding?.goalProfile.experienceLevel ?? "unknown"))
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
                            Text("频率 / TRAINING")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                            Text("\(onboarding?.trainingPreference.weeklyTrainingDays ?? 3)x / 周")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text("\(onboarding?.trainingPreference.sessionDurationMinutes ?? 45) min/次")
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

                VStack(spacing: 8) {
                    profileLine("训练风格", displayTrainingStyle(onboarding?.trainingPreference.trainingStyle ?? "mixed"), icon: "figure.run", color: Color(hex: "#FF9F0A"))
                    profileLine("可用设备", equipmentText, icon: "dumbbell.fill", color: Color(hex: "#30A2FF"))
                    profileLine("教练风格", displayCoachingStyle(onboarding?.coachingPreference.style ?? "explanatory"), icon: "brain.head.profile", color: Color(hex: "#AF52DE"))
                    profileLine("数据可信度", displayConfidence(onboarding?.initialBodySnapshot.dataConfidence.rawValue.uppercased() ?? dashboard.recovery.confidence.rawValue.uppercased()), icon: "checkmark.seal.fill", color: VelaTheme.success)

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
            Text("Coach Memory / 教练建议")
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
                .buttonStyle(.plain)

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
                        .buttonStyle(.plain)
                        
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

    private func handleArtifactAction(_ action: CoachArtifactAction) {
        if action.type.contains("training") || action.type.contains("workout") {
            VelaAppState.shared.routeToTab(1)
        } else if action.type.contains("check") {
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.routeToCoach(question: action.label)
        }
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

    private var personalToolsCard: some View {
        VStack(spacing: 0) {
            settingsLink("手记与主观反馈", value: "Journal", icon: "book.pages.fill", color: Color(hex: "#FF9F0A"), destination: VelaJournalView())
            Divider().padding(.leading, 54)
            settingsLink("用户健康档案", value: "Wiki", icon: "doc.text.fill", color: VelaTheme.muted, destination: UserWikiArchiveView())
            Divider().padding(.leading, 54)
            settingsLink("生物学资料", value: "Biology", icon: "person.text.rectangle.fill", color: Color(hex: "#00A896"), destination: BiologyView())
            Divider().padding(.leading, 54)
            settingsLink("完整设置", value: "Settings", icon: "gearshape.fill", color: Color(hex: "#5C6BC0"), destination: VelaSettingsView())
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }

    private var dataAndTrustCard: some View {
        VStack(spacing: 0) {
            settingsLink("数据覆盖", value: "Signals", icon: "waveform.path.ecg.rectangle.fill", color: Color(hex: "#30A2FF"), destination: DataCoverageView())
            Divider().padding(.leading, 54)
            settingsLink("信任中心", value: "Logs", icon: "checkmark.shield.fill", color: VelaTheme.success, destination: TrustCenterView())
            Divider().padding(.leading, 54)
            settingsLink("AI 模型设置", value: "Model", icon: "cpu.fill", color: Color(hex: "#AF52DE"), destination: AIModelSettingsView())
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }

    private var equipmentText: String {
        guard let equipment = onboarding?.equipmentProfile.equipment, !equipment.isEmpty else {
            return "home + gym"
        }
        return equipment.prefix(3).joined(separator: ", ")
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
        case "muscle_gain": return "增肌 / Muscle Gain"
        case "fat_loss": return "减脂 / Fat Loss"
        case "performance": return "运动表现 / Performance"
        case "health": return "健康维持 / Health"
        default: return "维持 / Maintain"
        }
    }

    private func displayExperience(_ level: String) -> String {
        switch level {
        case "beginner": return "新手 / Beginner"
        case "intermediate": return "中级 / Intermediate"
        case "advanced": return "高级 / Advanced"
        default: return "未知 / Unknown"
        }
    }

    private func displayTrainingStyle(_ style: String) -> String {
        switch style {
        case "mixed": return "混合训练 / Mixed"
        case "strength": return "力量训练 / Strength"
        case "cardio": return "有氧训练 / Cardio"
        case "yoga": return "瑜伽伸展 / Yoga"
        default: return style
        }
    }

    private func displayCoachingStyle(_ style: String) -> String {
        switch style {
        case "explanatory": return "详细解析 / Detailed"
        case "encouraging": return "积极鼓励 / Encouraging"
        case "direct": return "直截了当 / Direct"
        default: return style
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
        case "high": return "高 / High"
        case "medium": return "中 / Medium"
        case "low": return "低 / Low"
        case "unavailable": return "不可用"
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
}

// MARK: - VelaJournalView — Bevel Replica Journal Tab
// Persisted journal checklist × Golden calendar checks strip × Segments cluster toggles

struct VelaJournalView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var entries: [JournalEntryRecord]

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
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
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
    private func loadRealJournalData() {
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
                let dayNumber = calendar.component(.day, from: date)
                
                // Let's check if there are habit entries on this day to show the golden checkmark!
                let hasEntry = entries.contains { entry in
                    calendar.isDate(entry.createdAt, inSameDayAs: date)
                }
                
                Button {
                    dashboardVM.selectedDate = date
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
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .velaNativeCard(radius: 18)
    }

    // MARK: - Segmented Action Row (✕, –, ✓ toggles)
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
            
            // Custom segment selector container (✕, –, ✓)
            HStack(spacing: 0) {
                segmentButton(title: title, label: "✕", index: 0, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, label: "–", index: 1, state: state)
                
                Rectangle()
                    .fill(VelaTheme.separatorSoft)
                    .frame(width: 0.5, height: 20)
                
                segmentButton(title: title, label: "✓", index: 2, state: state)
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

    private func segmentButton(title: String, label: String, index: Int, state: Binding<Int>) -> some View {
        Button {
            state.wrappedValue = index
            saveQuickEntry(tags: [title], note: "习惯打卡: \(title) - \(label)", value: Double(index))
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(state.wrappedValue == index ? VelaTheme.fg : VelaTheme.meta)
                .frame(width: 32, height: 30)
                .background(
                    Group {
                        if state.wrappedValue == index {
                            VelaTheme.cardBg
                        }
                    }
                )
        }
        .buttonStyle(.plain)
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
                    Text("记录今天摄入的水分。水分补充充足可以提高身体在睡眠期间的自我恢复效能。")
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
                    Text("酒精摄入会强烈抑制副交感神经系统，导致夜间静息心率(RHR)升高，HRV 暴跌，深度及 REM 睡眠显著减少。")
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
                        Text("💡 什么是 1 标准杯？")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        
                        Text("一标准杯大约含有 10 克纯酒精：\n· 1 杯普通啤酒 (约 330ml, 4.5%)\n· 1 杯红葡萄酒 (约 150ml, 12%)\n· 1 盎司烈性白酒 (约 45ml, 40%)")
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
                    Text("与 Coach 聊天、记录训练或查看每日健康 analysis 后，将在此处收到主动生成的分析简报与优化建议。")
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
                            handleArtifactAction(action)
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
        .navigationTitle("Coach Artifact 收件箱")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction) {
        if action.type.contains("training") || action.type.contains("workout") {
            VelaAppState.shared.routeToTab(1)
        } else if action.type.contains("check") {
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }
}

struct CoachArtifactDetailWrapper: View {
    let artifact: CoachArtifact
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CoachArtifactCard(artifact: artifact, compact: false) { action in
                    handleArtifactAction(action)
                }
                .padding(16)
            }
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle(artifact.title)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func handleArtifactAction(_ action: CoachArtifactAction) {
        if action.type.contains("training") || action.type.contains("workout") {
            VelaAppState.shared.routeToTab(1)
        } else if action.type.contains("check") {
            VelaAppState.shared.triggerJournal = true
        } else {
            VelaAppState.shared.routeToCoach(question: action.label)
        }
    }
}

struct BodyModelEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
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
    
    var body: some View {
        Form {
            Section(header: Text("健身目标 / GOAL")) {
                Picker("主要目标", selection: $primaryGoal) {
                    Text("运动表现 / Performance").tag("performance")
                    Text("增肌 / Muscle").tag("muscle_gain")
                    Text("减脂 / Fat loss").tag("fat_loss")
                    Text("健康 / Health").tag("health")
                }
                .pickerStyle(.menu)
                
                Picker("体能经验", selection: $experienceLevel) {
                    Text("新手 / Beginner").tag("beginner")
                    Text("中级 / Intermediate").tag("intermediate")
                    Text("高级 / Advanced").tag("advanced")
                }
                .pickerStyle(.segmented)
            }
            
            Section(header: Text("训练偏好 / PREFERENCE")) {
                Picker("训练风格", selection: $trainingStyle) {
                    Text("混合训练 / Mixed").tag("mixed")
                    Text("力量训练 / Strength").tag("strength")
                    Text("有氧训练 / Cardio").tag("cardio")
                    Text("瑜伽伸展 / Yoga").tag("yoga")
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
            
            Section(header: Text("训练设备 / EQUIPMENT")) {
                Toggle("健身房设备 (Gym)", isOn: $hasGym)
                    .tint(VelaTheme.accent)
                Toggle("家用器械 (Home Equipment)", isOn: $hasHomeEquipment)
                    .tint(VelaTheme.accent)
                Toggle("自重/无器械 (Bodyweight)", isOn: $hasBodyweight)
                    .tint(VelaTheme.accent)
            }
            
            Section(header: Text("教练指导 / COACH STYLE")) {
                Picker("指导风格", selection: $coachStyle) {
                    Text("直截了当 / Direct").tag("direct")
                    Text("积极鼓励 / Encouraging").tag("encouraging")
                    Text("详细解析 / Detailed").tag("explanatory")
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
                    saveEdits()
                    dismiss()
                }
                .bold()
                .foregroundStyle(VelaTheme.accent)
            }
        }
        .onAppear {
            loadOnboardingState()
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
    
    private func saveEdits() {
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
        state.updatedAt = Date()
        
        if onboardingStates.isEmpty {
            modelContext.insert(state)
        }
        
        try? modelContext.save()
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
                    Text("基线: --")
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
            
            // Linear scale
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Gray background track
                    Capsule()
                        .fill(VelaTheme.separatorSoft)
                        .frame(height: 6)
                    
                    // Highlight baseline zone: +/- 10% around baseline
                    if let base = baseline {
                        let width = geo.size.width
                        let startPct = 0.35
                        let endPct = 0.65
                        Capsule()
                            .fill(VelaTheme.accent.opacity(0.18))
                            .frame(width: width * (endPct - startPct), height: 6)
                            .offset(x: width * startPct)
                        
                        // Baseline center tick
                        Rectangle()
                            .fill(VelaTheme.muted)
                            .frame(width: 1.5, height: 10)
                            .offset(x: width * 0.5, y: -2)
                        
                        // Today's value dot
                        if let tod = today {
                            // Map today relative to baseline. E.g., if tod == base, dot is at 50%.
                            // Let's map delta of +/- 20% to 10% - 90% range.
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
            }
            .frame(height: 10)
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
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse)
    private var journalEntries: [JournalEntryRecord]
    @Query(sort: \DailyHealthSummaryRecord.date, order: .reverse)
    private var dailySummaries: [DailyHealthSummaryRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \TrainingResponseRecord.date, order: .reverse)
    private var trainingResponses: [TrainingResponseRecord]
    
    private var onboarding: OnboardingState? { onboardingStates.first }
    private var dashboard: DashboardSummary { dashboardVM.dashboard }
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
        .navigationTitle("身体机能数字化模型")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadModelData()
        }
    }
    
    private var headerCalibrationCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(LinearGradient(colors: [VelaTheme.accent.opacity(0.4), VelaTheme.accent.opacity(0.0)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(LinearGradient(colors: [Color(hex: "#64D2FF").opacity(0.3), Color(hex: "#64D2FF").opacity(0.0)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                    .frame(width: 110, height: 110)
                
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [VelaTheme.accent, Color(hex: "#64D2FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .padding(.vertical, 8)
            
            Text("Vela Body Model 校准状态")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
            
            Text("整合目标、训练事实、健康基线和随手记信号。样本不足时只显示正在学习的区域，不把早期观察包装成个人规律。")
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 12)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
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
                detailRow(title: "主要健身目标", value: displayGoal(onboarding?.goalProfile.primaryGoal ?? "maintain"))
                Divider().padding(.leading, 16)
                detailRow(title: "体能训练经验", value: displayExperience(onboarding?.goalProfile.experienceLevel ?? "unknown"))
                Divider().padding(.leading, 16)
                detailRow(title: "频次及单次时长", value: "\(onboarding?.trainingPreference.weeklyTrainingDays ?? 3)次/周 · \(onboarding?.trainingPreference.sessionDurationMinutes ?? 45)分钟/次")
                Divider().padding(.leading, 16)
                detailRow(title: "教练指导风格", value: displayCoachingStyle(onboarding?.coachingPreference.style ?? "explanatory"))
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
        let repo = HealthSnapshotRepository(modelContext: modelContext)
        if let snaps = try? repo.fetchSnapshots(days: 30) {
            self.healthSnapshots = snaps
            let engine = JournalCorrelationEngine()
            self.insights = engine.calculateInsights(journalEntries: journalEntries, snapshots: snaps)
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
        case "high": return "高 / High"
        case "medium": return "中 / Medium"
        case "low": return "低 / Low"
        default: return conf
        }
    }
    
    private func displayGoal(_ goal: String) -> String {
        switch goal {
        case "muscle_gain": return "增肌 / Muscle Gain"
        case "fat_loss": return "减脂 / Fat Loss"
        case "performance": return "运动表现 / Performance"
        case "health": return "健康维持 / Health"
        default: return "维持 / Maintain"
        }
    }

    private func displayExperience(_ level: String) -> String {
        switch level {
        case "beginner": return "新手 / Beginner"
        case "intermediate": return "中级 / Intermediate"
        case "advanced": return "高级 / Advanced"
        default: return "未知 / Unknown"
        }
    }

    private func displayCoachingStyle(_ style: String) -> String {
        switch style {
        case "explanatory": return "详细解析 / Detailed"
        case "encouraging": return "积极鼓励 / Encouraging"
        case "direct": return "直截了当 / Direct"
        default: return style
        }
    }
}
