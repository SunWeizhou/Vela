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
    @State private var showSettings = false
    @State private var showChat = false
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
        Group {
            if presentation == .embedded && !showChat {
                coachHubSurface
            } else {
                ZStack {
            // Main Chat Panel
            VStack(spacing: 0) {
                headerView
                    .background(.ultraThinMaterial)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if vm.messages.isEmpty {
                                if presentation == .embedded {
                                    makeChatEmptyState
                                } else {
                                    intelligenceWorkspace
                                }
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
                VStack(spacing: 0) {
                    if presentation == .embedded {
                        makeQuickPromptStrip
                    }
                    composerView
                }
                .padding(.bottom, CoachChatLayout.bottomClearance(
                    presentation: presentation,
                    keyboardVisible: isKeyboardVisible,
                    usesOverlayNavigation: usesOverlayNavigation
                ))
                .background(.ultraThinMaterial)
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
            }
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
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                VelaSettingsView()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var coachHubSurface: some View {
        ScrollView {
            VStack(spacing: 0) {
                VelaMakeHeader(title: "Coach", subtitle: "Vela Intelligence") {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Button {
                        showChat = true
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text("开始对话")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.85))
                                Text("问 Vela 任何事情")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("已读取今日体征 · 流式回复 · 支持工具调用")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.8))
                        }
                        .padding(20)
                        .background(
                            LinearGradient(
                                colors: [Color(uiColor: .systemIndigo), VelaTheme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VelaMakeSectionHeader(title: "快捷提问")
                    makeQuickPrompts

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        makeCoachNavigationTile(
                            title: "生成训练计划",
                            subtitle: "基于恢复与目标",
                            icon: "calendar.badge.plus",
                            color: VelaTheme.accent,
                            destination: VelaTrainingPlanView()
                        )
                        makeCoachActionTile(
                            title: "食物拍照",
                            subtitle: "自动识别热量",
                            icon: "fork.knife",
                            color: .green
                        ) {
                            appState.triggerFoodScanner = true
                        }
                        makeCoachNavigationTile(
                            title: "个人 Wiki",
                            subtitle: "记忆与目标",
                            icon: "books.vertical.fill",
                            color: .purple,
                            destination: UserWikiArchiveView()
                        )
                        makeCoachNavigationTile(
                            title: "历史报告",
                            subtitle: "每日 / 每周",
                            icon: "doc.text.fill",
                            color: .orange,
                            destination: VelaReportsView()
                        )
                    }

                    makeCoachPersonalitySection
                    makeRecentArtifactsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 110)
            }
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.systemGroupedBackground)
    }

    private var makeQuickPrompts: some View {
        FlexStack(spacing: 8) {
            ForEach(vm.quickQuestions.prefix(4), id: \.self) { prompt in
                Button(prompt) {
                    showChat = true
                    sendMessage(prompt)
                }
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.fg)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(VelaTheme.cardBg)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
                .buttonStyle(.plain)
            }
        }
    }

    private func makeCoachActionTile(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            coachActionTileLabel(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color
            )
        }
        .buttonStyle(.plain)
    }

    private func makeCoachNavigationTile<Destination: View>(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        destination: Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            coachActionTileLabel(
                title: title,
                subtitle: subtitle,
                icon: icon,
                color: color
            )
        }
        .buttonStyle(.plain)
    }

    private func coachActionTileLabel(
        title: String,
        subtitle: String,
        icon: String,
        color: Color
    ) -> some View {
        VelaMakeCard {
            VStack(alignment: .leading, spacing: 3) {
                VelaMakeIconTile(systemName: icon, color: color)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.top, 7)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
            }
            .frame(minHeight: 94, alignment: .topLeading)
        }
    }

    private var makeCoachPersonalitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VelaMakeSectionHeader(title: "教练人格")
            VStack(spacing: 0) {
                makeCoachRow(
                    icon: "chart.bar.fill",
                    color: .green,
                    title: "数据分析师",
                    subtitle: "直接、量化、关注趋势",
                    trailing: "当前"
                ) {
                    showSettings = true
                }
                Divider().padding(.leading, 60)
                makeCoachRow(
                    icon: "shield.fill",
                    color: .indigo,
                    title: "守护者",
                    subtitle: "保守、安全、关注恢复",
                    trailing: nil
                ) {
                    showSettings = true
                }
            }
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var makeRecentArtifactsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VelaMakeSectionHeader(title: "最近生成")
            NavigationLink(destination: CoachArtifactInboxView()) {
                VStack(spacing: 0) {
                    if agentArtifacts.isEmpty {
                        makeCoachRow(
                            icon: "doc.text.fill",
                            color: .indigo,
                            title: "暂无生成内容",
                            subtitle: "与 Coach 对话后会出现在这里",
                            trailing: nil,
                            action: {}
                        )
                    } else {
                        ForEach(Array(agentArtifacts.prefix(3).enumerated()), id: \.element.id) { index, artifact in
                            makeCoachRow(
                                icon: artifactIcon(artifact.type),
                                color: .indigo,
                                title: artifact.title,
                                subtitle: artifact.type.replacingOccurrences(of: "_", with: " "),
                                trailing: nil,
                                action: {}
                            )
                            if index < min(agentArtifacts.count, 3) - 1 {
                                Divider().padding(.leading, 60)
                            }
                        }
                    }
                }
                .background(VelaTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func makeCoachRow(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        trailing: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VelaMakeIconTile(systemName: icon, color: color, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VelaTheme.fg)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.fg2)
                }
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.accent)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.meta)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
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
                        .foregroundStyle(VelaTheme.accent)
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
                .background(RoundedRectangle(cornerRadius: 22).fill(VelaTheme.accent))
                .shadow(color: VelaTheme.accent.opacity(0.15), radius: 6, y: 3)
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
                                .foregroundStyle(vm.currentSession?.id == session.id ? VelaTheme.accent : Color(hex: "#8E8A80"))
                            
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
                                        .foregroundStyle(VelaTheme.accent)
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
                                        .stroke(vm.currentSession?.id == session.id ? VelaTheme.accent.opacity(0.3) : Color.clear, lineWidth: 1)
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
                                colors: [VelaTheme.accent, VelaTheme.accent.opacity(0.6)],
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
                        .foregroundStyle(VelaTheme.accent)
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
            if presentation == .embedded {
                Button {
                    isFocused = false
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        showChat = false
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 17))
                    }
                    .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showHistoryDrawer = true
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 18))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.surface))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation == .embedded
                    ? "Vela Coach"
                    : (vm.currentSession?.title.isEmpty != false ? "Coach" : vm.currentSession!.title))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.fg)
                    .lineLimit(1)

                if presentation != .embedded {
                    HStack(spacing: 4) {
                        Circle().fill(vm.isReady ? VelaTheme.success : VelaTheme.muted).frame(width: 6, height: 6)
                        Text("\(vm.isReady ? "在线" : "未连接") · \(DeepSeekTextModel.stored.rawValue)")
                            .font(VelaTheme.caption2())
                            .foregroundStyle(vm.isReady ? VelaTheme.success : VelaTheme.muted)
                    }
                }
            }

            Spacer()

            if presentation == .embedded {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showHistoryDrawer = true
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("历史对话")
            } else {
                Button {
                    vm.createNewSession(modelContext: modelContext)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.surface))
                }
                .buttonStyle(.plain)

                Button {
                    showModelSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.surface))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Coach 模型设置")
            }

            if presentation == .quickCover {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VelaTheme.surface))
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

    private var makeChatEmptyState: some View {
        VStack(spacing: 14) {
            Text("今天 · Coach \(vm.isReady ? "在线" : "等待连接")")
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.fg2)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(VelaTheme.elevatedBg))

            HStack(alignment: .bottom, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(uiColor: .systemIndigo), VelaTheme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text("我会基于当前可用的健康数据回答。你可以问我训练、恢复、睡眠或营养问题。")
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.fg)
                        .lineSpacing(3)

                    Label("HealthKit · 训练记录 · 个人基线", systemImage: "waveform.path.ecg")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.meta)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(VelaTheme.elevatedBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(VelaTheme.border, lineWidth: 0.5)
                        )
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var makeQuickPromptStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.quickQuestions, id: \.self) { prompt in
                    Button(prompt) {
                        sendMessage(prompt)
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(VelaTheme.elevatedBg))
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(VelaTheme.borderSoft).frame(height: 0.5)
        }
    }

    private var intelligenceWorkspace: some View {
        VStack(alignment: .leading, spacing: 14) {
            workspaceSectionTitle("INTELLIGENCE WORKSPACE", "主动洞察与可执行产物")

            workspaceCard(
                title: todayCommandState.bodyStateTitle,
                detail: todayCommandState.summary,
                icon: "sparkles",
                confidence: todayCommandState.readinessDecision.confidence
            ) {
                sendMessage("解释今天最重要的身体状态驱动，并给一个具体行动。")
            }

            if let plan = operatingPlans.first {
                workspaceCard(
                    title: plan.title,
                    detail: decodedPlanSummary(plan),
                    icon: "checklist",
                    confidence: plan.confidence
                ) {
                    appState.routeToTab(VelaAppState.todayTabIndex)
                }
            }

            if !pendingMemoryProposals.isEmpty {
                memoryInboxBanner
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !agentArtifacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    workspaceSectionTitle("RECENT ARTIFACTS", "近期产物")
                    ForEach(agentArtifacts.prefix(4)) { artifact in
                        workspaceCard(
                            title: artifact.title,
                            detail: artifact.type.replacingOccurrences(of: "_", with: " "),
                            icon: artifactIcon(artifact.type),
                            confidence: artifact.confidence
                        ) {
                            sendMessage("基于产物 \(artifact.title) 给我下一步行动。")
                        }
                    }
                }
            }

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
            }
            .buttonStyle(.plain)

            welcomeViewWithArtifact
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

    private func workspaceCard(
        title: String,
        detail: String,
        icon: String,
        confidence: Double,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(3)
                    Text("置信度 \(Int((confidence * 100).rounded()))% · 一般健康建议，不构成医疗诊断")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
        }
        .buttonStyle(.plain)
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

    private var memoryInboxBanner: some View {
        Button {
            showWikiProfile = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("待确认长期记忆")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("\(pendingMemoryProposals.count) 条候选内容，确认后才会写入你的档案")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "#FFF8F2"))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(hex: "#E5E5EA"))
                    .frame(height: 0.5)
            }
        }
        .buttonStyle(.plain)
    }

    private var welcomeViewWithArtifact: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 10)

            // Alpaca Logo & Title
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 76, height: 76)
                        .overlay(Circle().stroke(Color(hex: "#E5E5EA"), lineWidth: 0.8))
                        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)

                    AlpacaView(
                        strokeColor: VelaTheme.accent,
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

            // Quick Suggestions
            VStack(alignment: .leading, spacing: 10) {
                Text("快捷提问 / QUICK SUGGESTIONS")
                    .font(VelaTheme.caption2())
                    .fontWeight(.bold)
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
                                .fill(VelaTheme.surface)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .stroke(VelaTheme.border, lineWidth: 0.5)
                                )
                        )
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Composer

    private var composerView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                isFocused = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VelaTheme.fg)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VelaTheme.elevatedBg))
            }
            .buttonStyle(.plain)

            HStack(alignment: .bottom, spacing: 6) {
                TextField("问 Vela…", text: $inputText, axis: .vertical)
                    .font(.system(size: 16))
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit {
                        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        sendMessage(inputText)
                    }

                Button {
                    appState.routeToFoodScanner(type: "camera")
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 17))
                        .foregroundStyle(VelaTheme.fg2)
                }
                .buttonStyle(.plain)

                Button {
                    appState.routeToFoodScanner(type: "library")
                } label: {
                    Image(systemName: "photo")
                        .font(.system(size: 17))
                        .foregroundStyle(VelaTheme.fg2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VelaTheme.elevatedBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isFocused ? VelaTheme.accent : VelaTheme.border, lineWidth: 0.5)
                    )
            )

            Button {
                if inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                    isFocused = true
                } else {
                    sendMessage(inputText)
                }
            } label: {
                Image(systemName: inputText.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "waveform" : "arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? VelaTheme.fg : Color.white)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? VelaTheme.elevatedBg : VelaTheme.accent)
                    )
            }
            .buttonStyle(.plusButton)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
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
            showChat = true
        }

        if let question = appState.prefilledCoachQuestion {
            showChat = true
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
            print("[CoachView] Routing to training")
            appState.routeToTab(VelaAppState.trainingTabIndex)
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

struct VelaReportsView: View {
    @Query(sort: \AIReportRecord.createdAt, order: .reverse)
    private var reports: [AIReportRecord]
    @Query(sort: \AgentArtifactRecord.createdAt, order: .reverse)
    private var artifacts: [AgentArtifactRecord]

    @AppStorage("agent_morning_brief_alerts") private var morningBriefOn = true
    @AppStorage("agent_bedtime_reminders") private var sleepReviewOn = true
    @AppStorage("agent_weekly_review_enabled") private var weeklyReviewOn = true
    @AppStorage("agent_post_workout_checkin_enabled") private var postWorkoutOn = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                morningBriefHero

                VelaMakeSectionHeader(title: "今日")
                reportRows

                VelaMakeSectionHeader(title: "生成物")
                artifactRows

                VelaMakeSectionHeader(title: "自动报告")
                automationRows

                Text("可在「设置 · 通知」中调整时间与开关。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
                    .padding(.horizontal, 4)
            }
            .padding(16)
            .padding(.bottom, 30)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("历史报告")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var morningBriefHero: some View {
        let latest = reports.first
        return VStack(alignment: .leading, spacing: 8) {
            Label("今日 Morning Brief · 6:00", systemImage: "sun.max.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
            Text(latest?.title ?? "今日身体状态简报")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(reportPreview(latest?.markdownContent) ?? "同步健康数据后，Vela 会自动生成恢复、睡眠和训练建议。")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
                .lineLimit(4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [.orange, Color(uiColor: .systemPink)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var reportRows: some View {
        if reports.isEmpty {
            VelaMakeCard {
                Text("暂无历史报告")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.fg2)
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(reports.prefix(5).enumerated()), id: \.element.createdAt) { index, report in
                    reportRow(
                        icon: report.type.contains("sleep") ? "moon.fill" : "sun.max.fill",
                        color: report.type.contains("sleep") ? .indigo : .orange,
                        title: report.title,
                        subtitle: report.createdAt.formatted(.dateTime.month().day().hour().minute())
                    )
                    if index < min(reports.count, 5) - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    @ViewBuilder
    private var artifactRows: some View {
        if artifacts.isEmpty {
            VelaMakeCard {
                Text("暂无生成物")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.fg2)
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(artifacts.prefix(5).enumerated()), id: \.element.id) { index, artifact in
                    reportRow(
                        icon: "doc.text.fill",
                        color: .indigo,
                        title: artifact.title,
                        subtitle: "\(artifact.type.replacingOccurrences(of: "_", with: " ")) · \(artifact.createdAt.formatted(.relative(presentation: .named)))"
                    )
                    if index < min(artifacts.count, 5) - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var automationRows: some View {
        VStack(spacing: 0) {
            automationRow("Morning Brief", "每日 6:00", .blue, $morningBriefOn)
            Divider().padding(.leading, 60)
            automationRow("睡眠回顾", "起床后", .purple, $sleepReviewOn)
            Divider().padding(.leading, 60)
            automationRow("周报", "周日 21:00", .green, $weeklyReviewOn)
            Divider().padding(.leading, 60)
            automationRow("训练后复盘", "训练结束 15 分钟后", .orange, $postWorkoutOn)
        }
        .background(VelaTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func reportRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            VelaMakeIconTile(systemName: icon, color: color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VelaTheme.fg)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.meta)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func automationRow(
        _ title: String,
        _ subtitle: String,
        _ color: Color,
        _ isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VelaMakeIconTile(systemName: "sparkles", color: color, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.fg2)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func reportPreview(_ markdown: String?) -> String? {
        guard let markdown else { return nil }
        return markdown
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
