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

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

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

                if !pendingMemoryProposals.isEmpty {
                    memoryInboxBanner
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            if vm.messages.isEmpty {
                                welcomeView
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

    private var memoryInboxBanner: some View {
        Button {
            showWikiProfile = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: "#007AFF"))

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

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

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

            Text("你的 AI 身体智能代理。可以讨论训练、恢复、睡眠、营养，我会根据你的健康数据给出个性化建议。")
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            FlexStack(spacing: 8) {
                ForEach(vm.quickQuestions, id: \.self) { text in
                    Button(text) {
                        sendMessage(text)
                    }
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.fg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
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
