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
        presentation == .embedded && !keyboardVisible && usesOverlayNavigation ? 92 : 0
    }
}

struct VelaCoachView: View {
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
    @State private var renameText = ""
    @State private var showWikiProfile = false
    @State private var showModelSettings = false
    @State private var handledRouteRevision = -1

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

    @Query(sort: \CoachArtifactRecord.createdAt, order: .reverse)
    private var coachArtifacts: [CoachArtifactRecord]

    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse)
    private var strengthWorkouts: [StrengthWorkoutRecord]
    @Query(sort: \DailyOperatingPlanRecord.generatedAt, order: .reverse)
    private var operatingPlans: [DailyOperatingPlanRecord]
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var agentArtifacts: [AgentArtifactRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var recentStrengthSummary: RecentTrainingSummary {
        TrainingAnalyticsService().buildRecentSummary(workouts: strengthWorkouts, days: 7)
    }
    private var todayCommandState: TodayCommandState {
        TodayCommandBuilder.build(
            from: dashboard,
            recentStrengthSummary: recentStrengthSummary,
            coachArtifact: coachArtifacts.first?.artifact
        )
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
                    .background(.ultraThinMaterial)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if vm.messages.isEmpty {
                                intelligenceWorkspace
                            }

                            ForEach(vm.messages.filter { !$0.isStreaming }) { msg in
                                MessageBubble(
                                    text: msg.content,
                                    isUser: msg.role == .user,
                                    time: msg.timestamp.formatted(.dateTime.hour().minute())
                                )
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
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: vm.isStreaming) { _, streaming in
                        guard streaming else { return }
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: vm.streamingContent) { _, content in
                        guard !content.isEmpty else { return }
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: isKeyboardVisible) { _, visible in
                        guard visible else { return }
                        scrollToBottom(using: proxy)
                    }
                    .onChange(of: isFocused) { _, focused in
                        guard focused else { return }
                        scrollToBottom(using: proxy)
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
                    historyDrawerView(width: geo.size.width * 0.78)
                        .offset(x: showHistoryDrawer ? 0 : -geo.size.width * 0.78)
                    Spacer()
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            vm.loadSessions(modelContext: modelContext)
            consumePendingRouteIfVisible()
            try? DailyLogService.refresh(dashboard: dashboard)
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

    // MARK: - History Drawer View
    
    private func historyDrawerView(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Drawer Header
            HStack {
                Text("历史对话")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showHistoryDrawer = false
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(hex: "#007AFF"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 16)
            
            // New Chat Button
            Button {
                vm.createNewSession(modelContext: modelContext)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showHistoryDrawer = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Text("新建对话")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#007AFF")))
                .shadow(color: Color(hex: "#007AFF").opacity(0.15), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider().padding(.horizontal, 20).padding(.bottom, 12)
            
            // Sessions Scroll List
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(vm.sessions) { session in
                        HStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(vm.currentSession?.id == session.id ? Color(hex: "#007AFF") : Color(hex: "#8E8A80"))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title.isEmpty ? "新对话" : session.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#1A1917"))
                                    .lineLimit(1)
                                
                                Text(session.updatedAt.formatted(.dateTime.month().day().hour().minute()))
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#BFB9AC"))
                            }
                            
                            Spacer()
                            
                            if vm.currentSession?.id == session.id {
                                Button {
                                    renamingSession = session
                                    renameText = session.title
                                    isRenamingSession = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#007AFF"))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                                
                                Button {
                                    vm.deleteSession(session, modelContext: modelContext)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(hex: "#FF3B30"))
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(vm.currentSession?.id == session.id ? Color.white : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(vm.currentSession?.id == session.id ? Color(hex: "#007AFF").opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 14)
                        .onTapGesture {
                            vm.selectSession(session, modelContext: modelContext)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showHistoryDrawer = false
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Drawer Footer
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#007AFF"), Color(hex: "#64D2FF")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("本机健康资料")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text("Local-first 存储")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#007AFF"))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
            .background(Color.white.opacity(0.4))
        }
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(Color(hex: "#F2F2F7"))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(hex: "#E5E5EA"))
                .frame(width: 0.5)
        }
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
                    .foregroundStyle(Color(hex: "#007AFF"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.currentSession?.title.isEmpty != false ? "Coach" : vm.currentSession!.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle().fill(vm.isReady ? VelaTheme.success : VelaTheme.muted).frame(width: 6, height: 6)
                    Text("\(vm.isReady ? "在线" : "未连接") · \(DeepSeekTextModel.stored.rawValue)")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(vm.isReady ? VelaTheme.success : VelaTheme.muted)
                }
            }

            Spacer()

            Button {
                vm.createNewSession(modelContext: modelContext)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#007AFF"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)

            Button {
                showModelSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#007AFF"))
                    .frame(width: 36, height: 36)
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
                        .foregroundStyle(Color(hex: "#007AFF"))
                        .frame(width: 36, height: 36)
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

    // MARK: - Welcome

    private var welcomeHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(Color(hex: "#E5E5EA"), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)

                AlpacaView(
                    strokeColor: Color(hex: "#007AFF"),
                    size: 58,
                    lineWidth: 2.6
                )
            }

            Text("Coach")
                .font(VelaTheme.title2())
                .foregroundStyle(VelaTheme.fg)

            Text("你的 AI 身体智能代理。你可以与我讨论训练、恢复、睡眠或营养，我将基于你的健康数据为你提供个性化建议。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)
        }
        .padding(.vertical, 8)
    }

    private var workspaceCarousel: some View {
        VStack(alignment: .leading, spacing: 10) {
            workspaceSectionTitle(L10n.t("INTELLIGENCE WORKSPACE", "智能决策舱"), L10n.t("Active insights & actionable plans", "主动智能洞察与建议"))
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    carouselCard(
                        title: todayCommandState.bodyStateTitle,
                        detail: todayCommandState.summary,
                        icon: "sparkles",
                        footer: "置信度 \(Int((todayCommandState.readinessDecision.confidence * 100).rounded()))% · 身体状态"
                    ) {
                        sendMessage("解释今天最重要的身体状态驱动，并给一个具体行动。")
                    }

                    if let plan = operatingPlans.first {
                        carouselCard(
                            title: plan.title,
                            detail: decodedPlanSummary(plan),
                            icon: "checklist",
                            footer: "置信度 \(Int((plan.confidence * 100).rounded()))% · 训练建议"
                        ) {
                            appState.routeToTab(0)
                        }
                    }

                    if !pendingMemoryProposals.isEmpty {
                        carouselCard(
                            title: "待确认长期记忆",
                            detail: "\(pendingMemoryProposals.count) 条候选内容，确认后才会写入你的档案。",
                            icon: "brain.head.profile",
                            footer: "点击进行归档确认",
                            accentColor: Color.orange
                        ) {
                            showWikiProfile = true
                        }
                    }

                    ForEach(agentArtifacts.prefix(3)) { artifact in
                        carouselCard(
                            title: artifact.title,
                            detail: localizedArtifactType(artifact.type),
                            icon: artifactIcon(artifact.type),
                            footer: "置信度 \(Int((artifact.confidence * 100).rounded()))% · 历史产物"
                        ) {
                            sendMessage("基于产物 \(artifact.title) 给我下一步行动。")
                        }
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
    }

    private func carouselCard(
        title: String,
        detail: String,
        icon: String,
        footer: String,
        accentColor: Color = VelaTheme.accent,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(accentColor)
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(accentColor.opacity(0.12)))
                    
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(3)
                    .frame(height: 54, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
                
                Text(footer)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(1)
            }
            .frame(width: 250, height: 132)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(VelaTheme.cardBg))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var intelligenceWorkspace: some View {
        VStack(alignment: .leading, spacing: 18) {
            welcomeHeader
            
            workspaceCarousel
            
            Button {
                showWikiProfile = true
            } label: {
                HStack {
                    Label("身体 Wiki 与长期记忆", systemImage: "books.vertical.fill")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.fg)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Suggestion questions
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("QUICK SUGGESTIONS", "快捷提问"))
                    .font(VelaTheme.caption2().weight(.bold))
                    .foregroundStyle(VelaTheme.muted)
                    .tracking(0.5)
                    .padding(.leading, 4)

                FlexStack(spacing: 8) {
                    ForEach(vm.quickQuestions, id: \.self) { text in
                        Button(text) {
                            sendMessage(text)
                        }
                        .font(VelaTheme.subheadline())
                        .foregroundStyle(VelaTheme.fg)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(VelaTheme.cardBg)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(VelaTheme.borderSoft, lineWidth: 0.7)
                                )
                        )
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func workspaceSectionTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.accent)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(VelaTheme.muted)
        }
    }

    private func decodedPlanSummary(_ plan: DailyOperatingPlanRecord) -> String {
        guard let data = plan.payloadJSON.data(using: .utf8),
              let payload = try? JSONDecoder().decode(DailyOperatingPlanPayload.self, from: data) else {
            return plan.primaryActionType
        }
        return payload.summary
    }

    private func artifactIcon(_ type: String) -> String {
        switch type {
        case "daily_plan": "calendar.badge.checkmark"
        case "training_adjustment": "slider.horizontal.3"
        case "weekly_report": "chart.line.uptrend.xyaxis"
        case "correlation_chart": "point.3.connected.trianglepath.dotted"
        case "wiki_diff": "doc.badge.gearshape"
        case "nutrition_feedback": "fork.knife"
        default: "doc.text.fill"
        }
    }

    // MARK: - Composer

    private var composerView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入消息…", text: $inputText, axis: .vertical)
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
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? VelaTheme.border : VelaTheme.accent)
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plusButton)
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

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            await Task.yield()
            withAnimation {
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
            appState.routeToTab(1)
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

}

// MARK: - FlexStack (wrapping HStack for suggestion chips)

struct FlexStack: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.size.height }.max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for item in row {
                subviews[item.index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            let rowH = row.map { $0.size.height }.max() ?? 0
            y += rowH + spacing
        }
    }

    struct Item { let index: Int; let size: CGSize }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [[Item]] {
        let maxW = proposal.width ?? .infinity
        var rows: [[Item]] = [[]]
        var currentRowW: CGFloat = 0

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let fits = rows.last?.isEmpty == true || currentRowW + size.width <= maxW
            if !fits {
                rows.append([])
                currentRowW = 0
            }
            rows[rows.count - 1].append(Item(index: i, size: size))
            currentRowW += size.width + spacing
        }
        return rows
    }
}
