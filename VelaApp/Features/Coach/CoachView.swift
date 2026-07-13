import SwiftUI
import SwiftData

// MARK: - VelaCoachView — ChatGPT-Style Coach with DeepSeek AI
// 中文默认 · 深色模式 · 欢迎区 · 对话气泡 · 打字指示器 · 底部编辑框 · 侧滑历史对话管理

enum CoachPresentationStyle {
    case embedded
    case quickCover
}

enum CoachChatLayout {
    static let bottomAnchorID = "coach-chat-bottom"

    static func bottomClearance(
        presentation: CoachPresentationStyle,
        keyboardVisible: Bool,
        usesOverlayNavigation: Bool = true
    ) -> CGFloat {
        presentation == .embedded && !keyboardVisible && usesOverlayNavigation
            ? VelaFloatingNavigationMetrics.coachComposerClearance
            : 0
    }
}

struct VelaCoachView: View {
    @Environment(\.velaSurfaceIsActive) private var isActiveSurface
    var presentation: CoachPresentationStyle
    var usesOverlayNavigation: Bool
    @ObservedObject var vm: CoachChatVM

    @Environment(\.colorScheme) private var cs
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices
    @ObservedObject private var appState = VelaAppState.shared

    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    // Keyboard tracking — only used for Tab Bar padding, not for manual layout shift
    @State private var isKeyboardVisible: Bool = false

    // Drawer state management
    @State private var showHistoryDrawer = false
    @State private var isRenamingSession = false
    @State private var renamingSession: CoachSessionRecord? = nil
    @State private var sessionPendingDeletion: CoachSessionRecord? = nil
    @State private var renameText = ""
    @State private var showWikiProfile = false
    @State private var showModelSettings = false
    @State private var handledRouteRevision = -1
    @State private var dataCoverageSummary = DataCoverageSummaryModel.unknown

    @Query(
        filter: #Predicate<JournalEntryRecord> { _ in true },
        sort: \JournalEntryRecord.createdAt, order: .reverse
    ) private var journalEntries: [JournalEntryRecord]

    @Query(
        filter: #Predicate<AIReportRecord> { _ in true },
        sort: \AIReportRecord.createdAt, order: .reverse
    ) private var savedReports: [AIReportRecord]

    @Query(
        filter: #Predicate<MemoryEventRecord> { $0.status == "proposed" },
        sort: \MemoryEventRecord.createdAt, order: .reverse
    ) private var pendingMemoryProposals: [MemoryEventRecord]

    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse)
    private var operatingPlans: [DailyOperatingPlanRecord]
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var agentArtifacts: [AgentArtifactRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var todayOperatingPlan: DailyOperatingPlanRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        return operatingPlans.first(where: { $0.dayIdentifier == identifier })
    }

    init(
        presentation: CoachPresentationStyle = .quickCover,
        usesOverlayNavigation: Bool = false,
        vm: CoachChatVM
    ) {
        self.presentation = presentation
        self.usesOverlayNavigation = usesOverlayNavigation
        self.vm = vm
    }

    var body: some View {
        ZStack {
            // Main Chat Panel
            VStack(spacing: 0) {
                headerView
                    .background(VelaTheme.bg.opacity(0.98))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if vm.messages.isEmpty {
                                CoachWelcomeWorkspace(
                                    vm: vm,
                                    todayOperatingPlan: todayOperatingPlan,
                                    pendingMemoryProposals: pendingMemoryProposals,
                                    agentArtifacts: agentArtifacts,
                                    showWikiProfile: $showWikiProfile,
                                    onSendMessage: { sendMessage($0) }
                                )
                            }

                            ForEach(vm.messages.filter { !$0.isStreaming }) { msg in
                                VStack(alignment: .leading, spacing: 8) {
                                    MessageBubble(
                                        text: msg.content,
                                        isUser: msg.role == .user,
                                        time: msg.timestamp.formatted(.dateTime.hour().minute())
                                    )

                                    if let action = msg.recoveryAction, msg.role == .assistant {
                                        HStack {
                                            CoachRecoveryActionButton(action: action) {
                                                handleRecoveryAction(action)
                                            }
                                            Spacer(minLength: 0)
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                            }

                            if vm.isStreaming {
                                if vm.streamingContent.isEmpty {
                                    TypingIndicator()
                                        .id("typing")
                                } else {
                                    MessageBubble(
                                        text: vm.streamingContent,
                                        isUser: false,
                                        time: "",
                                        isStreaming: true
                                    )
                                    .id("streaming")
                                }
                            }

                            Color.clear
                                .frame(height: 1)
                                .id(CoachChatLayout.bottomAnchorID)
                        }
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isFocused = false
                        }
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.immediately)
                    .onChange(of: vm.messages.count) { _, _ in
                        scrollToBottom(using: proxy, animated: true)
                    }
                    .onChange(of: vm.isStreaming) { _, streaming in
                        guard streaming else { return }
                        scrollToBottom(using: proxy, animated: true)
                    }
                    .onChange(of: vm.streamingContent) { _, content in
                        guard !content.isEmpty else { return }
                        scrollToBottom(using: proxy, animated: false)
                    }
                    .onChange(of: isKeyboardVisible) { _, visible in
                        guard visible else { return }
                        scrollToBottom(using: proxy, animated: true)
                    }
                    .onChange(of: isFocused) { _, focused in
                        guard focused else { return }
                        scrollToBottom(using: proxy, animated: true)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                composerView
                    .padding(.bottom, CoachChatLayout.bottomClearance(
                        presentation: presentation,
                        keyboardVisible: isKeyboardVisible,
                        usesOverlayNavigation: usesOverlayNavigation
                    ))
                    .background(VelaTheme.bg)
            }
            .background(VelaTheme.bg)
            .blur(radius: showHistoryDrawer ? 3 : 0)
            .disabled(showHistoryDrawer)

            // Transparent backdrop for drawer
            if showHistoryDrawer {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showHistoryDrawer = false
                        }
                    }
            }

            // Sliding drawer view
            GeometryReader { geo in
                HStack(spacing: 0) {
                    CoachHistoryDrawer(
                        width: geo.size.width * 0.78,
                        vm: vm,
                        modelContext: modelContext,
                        showHistoryDrawer: $showHistoryDrawer,
                        renamingSession: $renamingSession,
                        renameText: $renameText,
                        isRenamingSession: $isRenamingSession,
                        sessionPendingDeletion: $sessionPendingDeletion
                    )
                    .offset(x: showHistoryDrawer ? 0 : -geo.size.width * 0.78)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .task(id: isActiveSurface) {
            guard isActiveSurface else { return }
            vm.refreshKeyState()
            vm.loadSessions(modelContext: modelContext)
            consumePendingRouteIfVisible()
            try? DailyLogService.refresh(dashboard: dashboard)
            await dashboardVM.refresh(modelContext: modelContext)
            await loadDataCoverageSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                isKeyboardVisible = false
            }
        }
        .onChange(of: appState.coachRouteRevision) { _, _ in
            consumePendingRouteIfVisible()
        }
        .alert("重命名对话", isPresented: $isRenamingSession) {
            TextField("输入新标题...", text: $renameText)
            Button("取消", role: .cancel) {
                renamingSession = nil
            }
            Button("保存") {
                if let session = renamingSession {
                    vm.renameSession(session, to: renameText, modelContext: modelContext)
                }
                renamingSession = nil
            }
        }
        .alert("对话未保存", isPresented: Binding(
            get: { vm.persistenceError != nil },
            set: { if !$0 { vm.persistenceError = nil } }
        )) {
            Button("好", role: .cancel) { vm.persistenceError = nil }
        } message: {
            Text(vm.persistenceError ?? "")
        }
        .confirmationDialog("删除这段对话？", isPresented: Binding(
            get: { sessionPendingDeletion != nil },
            set: { if !$0 { sessionPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("删除对话", role: .destructive) {
                if let sessionPendingDeletion {
                    vm.deleteSession(sessionPendingDeletion, modelContext: modelContext)
                }
                sessionPendingDeletion = nil
            }
            Button("取消", role: .cancel) { sessionPendingDeletion = nil }
        } message: {
            Text("删除后将无法恢复这段本机保存的对话。")
        }
        .sheet(isPresented: $showWikiProfile) {
            NavigationStack {
                WikiProfileView()
            }
        }
        .sheet(isPresented: $showModelSettings) {
            NavigationStack {
                AIModelSettingsView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }



    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showHistoryDrawer = true
                }
            } label: {
                Image(systemName: "sidebar.left")
                    .font(.system(size: 18))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("对话历史")
            .accessibilityHint("打开历史对话列表")

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentSession?.title.isEmpty != false ? "Vela 教练" : vm.currentSession!.title)
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.fg)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle().fill(vm.isReady ? VelaTheme.success : VelaTheme.accent).frame(width: 6, height: 6)
                    Text(vm.isReady ? "AI 增强已开启" : "本机建议可用")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(vm.isReady ? VelaTheme.success : VelaTheme.accent)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                vm.createNewSession(modelContext: modelContext)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新建对话")

            Button {
                showModelSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Coach 模型设置")

            if presentation == .quickCover {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(VelaTheme.surface)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭 Coach")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }



    // MARK: - Composer

    private var composerView: some View {
        VStack(spacing: 8) {
            CoachDataCoverageStrip(model: dataCoverageSummary) {
                appState.showSettings = true
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(vm.isReady ? "询问你的健康与训练…" : "询问今日状态（本机分析）…", text: $inputText, axis: .vertical)
                    .font(VelaTheme.callout())
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(VelaTheme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(isFocused ? VelaTheme.accent : VelaTheme.border, lineWidth: 0.5)
                            )
                    )
                    .onSubmit {
                        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        sendMessage(inputText)
                    }

                Button {
                    guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    sendMessage(inputText)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? VelaTheme.border : VelaTheme.accent)
                        )
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                .buttonStyle(.plusButton)
                .accessibilityLabel("发送消息")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(VelaTheme.bg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VelaTheme.borderSoft)
                .frame(height: 0.5)
        }
    }

    // MARK: - Actions

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool = true) {
        Task { @MainActor in
            await Task.yield()
            if animated {
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(CoachChatLayout.bottomAnchorID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(CoachChatLayout.bottomAnchorID, anchor: .bottom)
            }
        }
    }

    private func consumePendingRouteIfVisible() {
        let expectedDestination: VelaAppState.CoachRouteDestination = presentation == .embedded
            ? .embedded
            : .quickCover
        guard appState.coachRouteDestination == expectedDestination else { return }
        guard presentation == .quickCover || appState.selectedTab == VelaAppState.coachTabIndex else { return }
        guard handledRouteRevision != appState.coachRouteRevision else { return }
        handledRouteRevision = appState.coachRouteRevision

        if appState.forceNewCoachSession {
            vm.createNewSession(modelContext: modelContext)
            appState.forceNewCoachSession = false
        }

        if let question = appState.prefilledCoachQuestion {
            sendMessage(question)
            appState.prefilledCoachQuestion = nil
        }
    }

    private func handleArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        print("[CoachView] handleArtifactAction: type=\(action.type), label=\(action.label)")
        if action.type == "start_check_in" {
            print("[CoachView] Opening post-workout check-in")
            appState.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
            if presentation == .quickCover {
                dismiss()
            }
        } else if action.type == "open_recovery_detail" {
            print("[CoachView] Opening post-workout impact")
            appState.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
            if presentation == .quickCover {
                dismiss()
            }
        } else if action.type.contains("training") || action.type.contains("workout") || action.type.contains("summary") {
            print("[CoachView] Routing to training (tab 1)")
            appState.routeToTraining()
            if presentation == .quickCover {
                dismiss()
            }
        } else if action.type.contains("check") || action.type.contains("journal") {
            print("[CoachView] Triggering journal")
            appState.triggerJournal = true
            if presentation == .quickCover {
                dismiss()
            }
        } else if action.type.contains("recovery") || action.type.contains("vitals") || action.type.contains("insight") {
            print("[CoachView] Routing to recovery (tab 2)")
            appState.routeToRecoveryDetail()
            if presentation == .quickCover {
                dismiss()
            }
        } else {
            print("[CoachView] Routing to coach with question: \(artifact.followUpQuestion ?? action.label)")
            sendMessage(artifact.followUpQuestion ?? action.label)
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

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !vm.isStreaming else { return }
        inputText = ""

        if !vm.isReady {
            vm.appendLocalExchange(
                userText: trimmed,
                response: LocalCoachGuidanceBuilder.response(
                    dashboard: dashboard,
                    operatingPlan: todayOperatingPlan
                ),
                modelContext: modelContext
            )
            return
        }

        vm.submit(
            text: trimmed,
            dashboard: dashboard,
            modelContext: modelContext,
            journalEntries: journalEntries,
            savedReports: savedReports,
            focus: .general,
            services: services
        )
    }

    private func handleRecoveryAction(_ action: LLMErrorRecoveryAction) {
        switch action.destination {
        case .settings:
            if presentation == .quickCover {
                dismiss()
            }
            appState.showSettings = true
        case .retry:
            vm.retryLastFailedRequest(
                dashboard: dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: .general,
                services: services
            )
        }
    }

    private func loadDataCoverageSummary() async {
        let groups = await DataCoverageGroupFactory.loadPriorityGroups()
        let summary = DataCoverageSummaryModel.build(groups: groups)
        withAnimation(VelaTheme.smooth) {
            dataCoverageSummary = summary
        }
    }

}

enum LocalCoachGuidanceBuilder {
    static func response(
        dashboard: DashboardSummary,
        operatingPlan: DailyOperatingPlanRecord?,
        isChinese: Bool = AppLanguage.stored.isChinese
    ) -> String {
        if let operatingPlan {
            let display = DailyOperatingPlanDisplayModel.build(
                payload: operatingPlan.operatingPlanPayload,
                primaryActionType: operatingPlan.primaryActionType,
                source: operatingPlan.source,
                safetyNotice: operatingPlan.safetyNotice,
                confidence: operatingPlan.confidence,
                isChinese: isChinese
            )
            if isChinese {
                return """
                **\(display.statusTitle)**

                \(display.summary)

                - \(display.confidenceLabel)
                - \(display.evidenceLine)
                - 下一步：前往训练页执行或调整计划，完成后记录体感，Vela 会用于后续校准。

                当前回答由本机规则与已同步数据生成；连接 AI 后可继续追问更细的解释。
                """
            }
            return """
            **\(display.statusTitle)**

            \(display.summary)

            - \(display.confidenceLabel)
            - \(display.evidenceLine)
            - Next: open Training to follow or adjust the plan, then log how it felt so Vela can calibrate future guidance.

            This answer was generated locally from synced data and deterministic rules. Connect AI for deeper follow-up questions.
            """
        }

        let hasRecovery = dashboard.recovery.hasData
        if isChinese {
            return hasRecovery
                ? "本机已经读取到部分身体信号，但今日计划仍在生成。请先刷新今日页；在计划完成前，不建议仅凭单项分数提高训练量。一般健康建议，不构成医疗诊断。"
                : "当前还没有足够的恢复与睡眠信号。请先在今日页同步 Apple 健康并建立身体基线；在此之前，保持原有节奏或适度减量，不要根据缺失数据临时加练。一般健康建议，不构成医疗诊断。"
        }
        return hasRecovery
            ? "Some body signals are available, but today's plan is still being generated. Refresh Today first, and do not increase training from a single metric alone. General guidance only; not a medical diagnosis."
            : "Recovery and sleep coverage is still limited. Sync Apple Health from Today and build your baseline first; until then, keep your normal routine or reduce load conservatively. General guidance only; not a medical diagnosis."
    }
}
