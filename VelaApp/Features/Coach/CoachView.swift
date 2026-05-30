import SwiftUI
import SwiftData

// MARK: - VelaCoachView — ChatGPT-Style Coach with DeepSeek AI
// 中文默认 · 深色模式 · 欢迎区 · 对话气泡 · 打字指示器 · 底部编辑框 · 侧滑历史对话管理

struct VelaCoachView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var services: VelaServices

    @StateObject private var vm = CoachChatVM()
    @State private var inputText: String = ""
    @FocusState private var isFocused: Bool

    // Drawer state management
    @State private var showHistoryDrawer = false
    @State private var isRenamingSession = false
    @State private var renamingSession: CoachSessionRecord? = nil
    @State private var renameText = ""

    @Query(
        filter: #Predicate<JournalEntryRecord> { _ in true },
        sort: \JournalEntryRecord.createdAt, order: .reverse
    ) private var journalEntries: [JournalEntryRecord]

    @Query(
        filter: #Predicate<AIReportRecord> { _ in true },
        sort: \AIReportRecord.createdAt, order: .reverse
    ) private var savedReports: [AIReportRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

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
                                welcomeView
                            }

                            ForEach(vm.messages) { msg in
                                MessageBubble(
                                    text: msg.content,
                                    isUser: msg.role == .user,
                                    time: msg.timestamp.formatted(.dateTime.hour().minute())
                                )
                            }

                            if vm.isStreaming {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, VelaTheme.pagePadding)
                        .padding(.vertical, 16)
                    }
                    .scrollIndicators(.hidden)
                    .onChange(of: vm.messages.count) { _, _ in
                        if let last = vm.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: vm.isStreaming) { _, streaming in
                        if streaming {
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }
                }

                composerView
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

            if VelaAppState.shared.forceNewCoachSession {
                vm.createNewSession(modelContext: modelContext)
                VelaAppState.shared.forceNewCoachSession = false
            }

            if let question = VelaAppState.shared.prefilledCoachQuestion {
                sendMessage(question)
                VelaAppState.shared.prefilledCoachQuestion = nil
            }

            try? DailyLogService.refresh(dashboard: dashboard)
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
                        .foregroundStyle(Color(hex: "#C56B4A"))
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
                .background(RoundedRectangle(cornerRadius: 22).fill(Color(hex: "#C56B4A")))
                .shadow(color: Color(hex: "#C56B4A").opacity(0.15), radius: 6, y: 3)
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
                                .foregroundStyle(vm.currentSession?.id == session.id ? Color(hex: "#C56B4A") : Color(hex: "#8E8A80"))
                            
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
                                        .foregroundStyle(Color(hex: "#C56B4A"))
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
                                        .stroke(vm.currentSession?.id == session.id ? Color(hex: "#C56B4A").opacity(0.3) : Color.clear, lineWidth: 1)
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
                                colors: [Color(hex: "#C56B4A"), Color(hex: "#E89B7E")],
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
                    Text("Weizhou")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text("Vela 创始会员")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color(hex: "#C56B4A"))
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
        .background(Color(hex: "#F5F3F0"))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(hex: "#E8E4DD"))
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
                    .foregroundStyle(Color(hex: "#C56B4A"))
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
                    Text(vm.isReady ? "在线" : "未连接")
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
                    .foregroundStyle(Color(hex: "#C56B4A"))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle().fill(VelaTheme.surface)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    // MARK: - Welcome

    private var welcomeView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(Color(hex: "#E8E4DD"), lineWidth: 0.8))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)

                AlpacaView(
                    strokeColor: Color(hex: "#C56B4A"),
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
        .padding(.bottom, 28)
        .background(VelaTheme.bg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(VelaTheme.borderSoft)
                .frame(height: 0.5)
        }
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !vm.isStreaming else { return }
        inputText = ""

        Task {
            await vm.send(
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
