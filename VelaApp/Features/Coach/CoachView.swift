import SwiftData
import SwiftUI
import UIKit

struct CoachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @Query(sort: \AIReportRecord.createdAt, order: .reverse) private var savedReports: [AIReportRecord]
    @StateObject private var vm = CoachChatVM()
    @EnvironmentObject var dashboardVM: DashboardViewModel
    @FocusState private var inputFocused: Bool

    @State private var showSidebar = false
    @State private var showRenameAlert = false
    @State private var sessionToRename: CoachSessionRecord? = nil
    @State private var renameText = ""
    @State private var activePersonality = CoachPersonality.current
    @State private var showConversation = false
    @ObservedObject private var agentConfig = AutoAgentConfig.shared

    // Camera / Food Photo
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var capturedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                VStack(spacing: 0) {
                    personalityPicker
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    if showConversation {
                        messageList
                    } else {
                        actionHubView
                    }

                    // Quick questions (only when few messages)
                    if showConversation && vm.messages.count < 3 && !vm.messages.isEmpty {
                        quickQuestionsBar
                    }

                    inputBar
                }

                // Bespoke Glassmorphic Sidebar Drawer
                if showSidebar {
                    sidebarOverlay
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(VelaTheme.secondaryText)
                        }

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showSidebar.toggle()
                            }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        } label: {
                            Image(systemName: "sidebar.left")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(VelaTheme.accent)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        VelaLogoMark(size: 20)
                        Text(vm.currentSession?.title ?? "Vela")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 4) {
                        if EveningWikiSyncAgent.shared.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(.trailing, 4)
                        }
                        Menu {
                            Button {
                                Task {
                                    await EveningWikiSyncAgent.shared.runIfNeeded(
                                        modelContext: modelContext,
                                        dashboard: dashboardVM.dashboard,
                                        force: true
                                    )
                                }
                            } label: {
                                Label(L10n.t("Sync Wiki Now", "立即同步 Wiki"), systemImage: "arrow.triangle.2.circlepath")
                            }
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    vm.createNewSession(modelContext: modelContext)
                                    showConversation = false
                                }
                            } label: {
                                Label(L10n.t("New Session", "新建对话"), systemImage: "plus.circle")
                            }
                            Button(role: .destructive) {
                                vm.clearConversation(modelContext: modelContext)
                            } label: {
                                Label(L10n.t("Clear Chat", "清空对话"), systemImage: "trash")
                            }
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Label(L10n.t("Settings", "设置"), systemImage: "gearshape.fill")
                            }
                            NavigationLink {
                                JournalView()
                            } label: {
                                Label(L10n.t("Journal", "日记"), systemImage: "square.and.pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .alert(AppLanguage.stored.isChinese ? "重命名对话" : "Rename Session", isPresented: $showRenameAlert) {
                TextField(AppLanguage.stored.isChinese ? "输入对话名称" : "Session Title", text: $renameText)
                Button(AppLanguage.stored.isChinese ? "取消" : "Cancel", role: .cancel) { sessionToRename = nil }
                Button(AppLanguage.stored.isChinese ? "确定" : "OK") {
                    if let session = sessionToRename {
                        vm.renameSession(session, to: renameText, modelContext: modelContext)
                    }
                    sessionToRename = nil
                }
            }
        }
        .task {
            vm.loadSessions(modelContext: modelContext)
            await dashboardVM.refresh(modelContext: modelContext)
            vm.refreshKeyState()
            if let prefilled = VelaAppState.shared.prefilledCoachQuestion {
                vm.draft = prefilled
                VelaAppState.shared.prefilledCoachQuestion = nil
            }
            if VelaAppState.shared.triggerFoodCamera {
                VelaAppState.shared.triggerFoodCamera = false
                showCameraPicker = true
            } else if VelaAppState.shared.triggerFoodLibrary {
                VelaAppState.shared.triggerFoodLibrary = false
                showPhotoLibraryPicker = true
            }
            // Auto agent: evening wiki sync
            await EveningWikiSyncAgent.shared.runIfNeeded(
                modelContext: modelContext,
                dashboard: dashboardVM.dashboard
            )
        }
        .onAppear {
            if let prefilled = VelaAppState.shared.prefilledCoachQuestion {
                vm.draft = prefilled
                VelaAppState.shared.prefilledCoachQuestion = nil
            }
            if VelaAppState.shared.triggerFoodCamera {
                VelaAppState.shared.triggerFoodCamera = false
                showCameraPicker = true
            } else if VelaAppState.shared.triggerFoodLibrary {
                VelaAppState.shared.triggerFoodLibrary = false
                showPhotoLibraryPicker = true
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImagePicker(sourceType: .camera, selectedImage: $capturedImage)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibraryPicker) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in
            guard let image = newImage else { return }
            Task {
                await vm.analyzeFoodPhoto(
                    image,
                    dashboard: dashboardVM.dashboard,
                    modelContext: modelContext,
                    journalEntries: journalEntries,
                    savedReports: savedReports
                )
            }
        }
    }

    private var actionHubView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VelaHeroSurface(tint: VelaTheme.accent) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VelaLogoMark(size: 48)
                                .shadow(color: VelaTheme.accent.opacity(0.16), radius: 14)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(AppLanguage.stored.isChinese ? "Coach Command Center" : "Coach Command Center")
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(VelaTheme.primaryText)
                                Text(AppLanguage.stored.isChinese
                                     ? "基于今天的身体状态、Wiki 记忆和健康数据，快速发起一次有上下文的行动。"
                                     : "Start a context-aware action from today's body state, Wiki memory, and health data."
                                )
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
                            VelaMetricPill(
                                title: AppLanguage.stored.isChinese ? "恢复" : "Recovery",
                                value: dashboardVM.dashboard.recovery.hasData ? "\(Int(dashboardVM.dashboard.recovery.score))" : "--",
                                systemImage: "heart.fill",
                                tint: VelaTheme.recovery
                            )
                            VelaMetricPill(
                                title: AppLanguage.stored.isChinese ? "睡眠" : "Sleep",
                                value: dashboardVM.dashboard.sleepScore.hasData ? "\(Int(dashboardVM.dashboard.sleepScore.score))" : "--",
                                systemImage: "moon.zzz.fill",
                                tint: VelaTheme.sleep
                            )
                            VelaMetricPill(
                                title: AppLanguage.stored.isChinese ? "负荷" : "Strain",
                                value: dashboardVM.dashboard.strain.hasData ? "\(Int(dashboardVM.dashboard.strain.score))" : "--",
                                systemImage: "figure.run",
                                tint: VelaTheme.strain
                            )
                        }
                    }
                }

                VelaSectionHeader(
                    title: AppLanguage.stored.isChinese ? "主动行动" : "Proactive Actions",
                    subtitle: AppLanguage.stored.isChinese ? "选择一个入口，Vela 会带着当前上下文进入对话。" : "Choose an entry point; Vela carries current context into the chat."
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 154), spacing: 12)], spacing: 12) {
                    VelaCoachCommandCard(
                        title: L10n.t("Analyze Readiness", "分析今日状态"),
                        subtitle: L10n.t("Recovery, sleep, strain, and today's limiter.", "恢复、睡眠、负荷和今日限制因素。"),
                        systemImage: "sparkles",
                        tint: VelaTheme.accent
                    ) {
                        sendQuestion(L10n.t("How am I doing today? Explain the evidence and the best next action.", "我今天状态怎么样？请解释证据和最合适的下一步行动。"))
                    }

                    VelaCoachCommandCard(
                        title: L10n.t("Adjust Training", "调整训练"),
                        subtitle: L10n.t("Decide whether to train, reduce, swap, or recover.", "判断训练、减量、替换或恢复。"),
                        systemImage: "figure.run.circle.fill",
                        tint: VelaTheme.strain
                    ) {
                        sendQuestion(L10n.t("Should I adjust today's training based on recovery and fatigue?", "根据恢复和疲劳情况，今天的训练需要调整吗？"))
                    }

                    VelaCoachCommandCard(
                        title: L10n.t("Optimize Sleep", "优化睡眠"),
                        subtitle: L10n.t("Turn sleep signals into tonight's plan.", "把睡眠信号转成今晚计划。"),
                        systemImage: "moon.stars.fill",
                        tint: VelaTheme.sleep
                    ) {
                        sendQuestion(L10n.t("Review my sleep and give me one concrete optimization for tonight.", "请分析我的睡眠，并给出今晚一个具体优化建议。"))
                    }

                    VelaCoachCommandCard(
                        title: L10n.t("Review Memory", "检查记忆"),
                        subtitle: L10n.t("Open pending memories and profile context.", "打开待确认记忆和个人档案。"),
                        systemImage: "brain.head.profile",
                        tint: VelaTheme.energy
                    ) {
                        showConversation = false
                    }
                    .overlay {
                        NavigationLink {
                            WikiProfileView()
                        } label: {
                            Color.clear
                        }
                    }
                }

                VelaSectionHeader(
                    title: AppLanguage.stored.isChinese ? "信任与数据" : "Trust and Data",
                    subtitle: AppLanguage.stored.isChinese ? "检查 Vela 的输入质量和 Agent 行为记录。" : "Check Vela's input quality and agent behavior records."
                )

                HStack(spacing: 12) {
                    NavigationLink {
                        DataCoverageView()
                    } label: {
                        trustCommandTile(
                            title: AppLanguage.stored.isChinese ? "数据覆盖" : "Data Coverage",
                            subtitle: AppLanguage.stored.isChinese ? "信号新鲜度与置信度" : "Signal freshness and confidence",
                            icon: "waveform.path.ecg.rectangle",
                            tint: VelaTheme.recovery
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        TrustCenterView()
                    } label: {
                        trustCommandTile(
                            title: AppLanguage.stored.isChinese ? "信任中心" : "Trust Center",
                            subtitle: AppLanguage.stored.isChinese ? "Agent 审计日志" : "Agent audit log",
                            icon: "checkmark.shield.fill",
                            tint: VelaTheme.accent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(VelaTheme.screenPadding)
            .padding(.bottom, 24)
        }
    }

    private func trustCommandTile(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        VelaGlassCard(padding: 14, cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.12)))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func suggestionCard(
        title: String,
        description: String,
        icon: String,
        question: String,
        tint: Color
    ) -> some View {
        Button {
            sendQuestion(question)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.08))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VelaTheme.mutedText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(vm.messages) { msg in
                        ChatBubbleView(
                            message: msg,
                            streamingContent: msg.isStreaming ? vm.streamingContent : nil
                        )
                            .id(msg.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) {
                scrollToBottom(proxy)
            }
            .onChange(of: vm.streamingContent) {
                scrollToBottom(proxy)
            }
        }
    }

    // MARK: - Quick Questions Bar

    private var quickQuestionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.quickQuestions.prefix(4), id: \.self) { q in
                    Button { sendQuestion(q) } label: {
                        Text(q)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(VelaTheme.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(VelaTheme.accent.opacity(0.1))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, VelaTheme.screenPadding)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Camera button for food photo analysis
            Menu {
                Button {
                    showCameraPicker = true
                } label: {
                    Label(L10n.t("Take Photo", "拍照"), systemImage: "camera.fill")
                }
                Button {
                    showPhotoLibraryPicker = true
                } label: {
                    Label(L10n.t("Choose from Library", "从相册选择"), systemImage: "photo.on.rectangle")
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VelaTheme.subtleFill))
            }
            .disabled(vm.isStreaming || vm.isAnalyzingFood)
            
            // Capsule containing TextField + Send Button
            HStack(spacing: 4) {
                TextField(
                    L10n.t("Ask Vela...", "问 Vela..."),
                    text: $vm.draft,
                    axis: .vertical
                )
                .lineLimit(1...5)
                .focused($inputFocused)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(VelaTheme.primaryText)
                
                Button {
                    inputFocused = false
                    sendQuestion(vm.draft)
                } label: {
                    Group {
                        if vm.isStreaming {
                            ProgressView()
                                .tint(VelaTheme.inverseText)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.inverseText)
                        }
                    }
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(
                                vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? VelaTheme.mutedText.opacity(0.3)
                                    : VelaTheme.accent
                            )
                    )
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
                .padding(.trailing, 6)
            }
            .background(
                Capsule(style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(VelaTheme.background.opacity(0.8))
                .background(.ultraThinMaterial)
        )
    }

    // MARK: - Glassmorphic Sidebar Drawer

    private var sidebarOverlay: some View {
        let drawerWidth = min(UIScreen.main.bounds.width * 0.78, 320)

        return ZStack(alignment: .leading) {
            // Dismiss area with blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        showSidebar = false
                    }
                }

            // Side Drawer
            GeometryReader { geo in
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(AppLanguage.stored.isChinese ? "对话历史" : "Sessions")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(AppLanguage.stored.isChinese ? "你的私人健康顾问" : "Your private coach")
                                .font(.caption)
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                vm.createNewSession(modelContext: modelContext)
                                showConversation = false
                                showSidebar = false
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.body.weight(.bold))
                                .foregroundStyle(VelaTheme.accent)
                                .padding(8)
                                .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, geo.safeAreaInsets.top + 12)
                    .padding(.bottom, 20)

                    Divider()
                        .background(Color.black.opacity(0.08))

                    // Session List
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(vm.sessions) { session in
                                let isSelected = vm.currentSession?.id == session.id
                                HStack {
                                    Image(systemName: "bubble.left.and.bubble.right.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(isSelected ? VelaTheme.accent : VelaTheme.secondaryText)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(session.title)
                                            .font(.subheadline.weight(isSelected ? .semibold : .medium))
                                            .foregroundStyle(isSelected ? VelaTheme.accent : VelaTheme.primaryText)
                                            .lineLimit(1)
                                        Text(session.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(size: 10))
                                            .foregroundStyle(VelaTheme.mutedText)
                                    }

                                    Spacer()

                                    // Context Menu for Rename / Delete
                                    Menu {
                                        Button {
                                            sessionToRename = session
                                            renameText = session.title
                                            showRenameAlert = true
                                        } label: {
                                            Label(AppLanguage.stored.isChinese ? "重命名" : "Rename", systemImage: "pencil")
                                        }

                                        Button(role: .destructive) {
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                            vm.deleteSession(session, modelContext: modelContext)
                                        } label: {
                                            Label(AppLanguage.stored.isChinese ? "删除" : "Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis")
                                            .font(.caption)
                                            .foregroundStyle(VelaTheme.mutedText)
                                            .padding(6)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(isSelected ? VelaTheme.accent.opacity(0.1) : Color.clear)
                                )
                                .onTapGesture {
                                    withAnimation {
                                        vm.selectSession(session, modelContext: modelContext)
                                        showConversation = true
                                        showSidebar = false
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                }
                            }
                        }
                        .padding(14)
                    }

                    Spacer()

                    // Footer
                    VStack(spacing: 12) {
                        Divider()
                            .background(Color.black.opacity(0.08))

                        NavigationLink {
                            WikiProfileView()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "person.text.rectangle.fill")
                                    .font(.body)
                                    .foregroundStyle(VelaTheme.accent)
                                Text(AppLanguage.stored.isChinese ? "个人健康档案 (Wiki)" : "Personal Health Wiki")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(VelaTheme.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(VelaTheme.mutedText)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.elevatedSurface))
                        }
                        .buttonStyle(.plain)
                        .onTapGesture {
                            showSidebar = false
                        }
                    }
                    .padding(16)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                }
                .frame(width: drawerWidth, height: geo.size.height)
                .background(.ultraThinMaterial)
            }
            .frame(width: drawerWidth)
            .transition(.move(edge: .leading))
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -50 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                showSidebar = false
                            }
                        }
                    }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func sendQuestion(_ text: String) {
        showConversation = true
        Task {
            await vm.send(
                text: text,
                dashboard: dashboardVM.dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports
            )
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        guard let id = vm.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private var personalityPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CoachPersonality.allCases) { p in
                    let isSelected = activePersonality == p
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            activePersonality = p
                            CoachPersonality.current = p
                        }
                        triggerPersonalityHaptic(p)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: p.icon)
                                .font(.system(size: 13, weight: .semibold))
                            Text(p.displayName)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isSelected ? p.tint.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(isSelected ? p.tint.opacity(0.4) : Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(isSelected ? p.tint : VelaTheme.secondaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 38)
    }

    private func triggerPersonalityHaptic(_ personality: CoachPersonality) {
        switch personality {
        case .dataNerd:
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.prepare()
            gen.impactOccurred()
        case .guardian:
            let gen = UINotificationFeedbackGenerator()
            gen.prepare()
            gen.notificationOccurred(.success)
        case .friend:
            let gen = UISelectionFeedbackGenerator()
            gen.prepare()
            gen.selectionChanged()
        case .commander:
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let gen2 = UIImpactFeedbackGenerator(style: .medium)
                gen2.prepare()
                gen2.impactOccurred()
            }
        }
    }
}

private struct CoachReportDetailView: View {
    let report: AIReportRecord

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reportTypeTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(VelaTheme.accent)
                            .textCase(.uppercase)
                        Text(report.title)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(report.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 18)

                    MarkdownText(
                        markdown: report.markdownContent,
                        font: .body,
                        color: VelaTheme.primaryText,
                        isStreaming: false
                    )
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                            .fill(VelaTheme.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    )
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 36)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private var reportTypeTitle: String {
        AIReportType(rawValue: report.type)?.title ?? L10n.t("Artifact", "智能产物")
    }
}

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let message: CoachChatVM.ChatMsg
    let streamingContent: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 72) }

            VStack(alignment: .leading, spacing: 8) {
                // Header (only for assistant)
                if message.role == .assistant {
                    HStack(spacing: 6) {
                        VelaLogoMark(size: 16)
                        Text("Vela AI")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .padding(.bottom, 2)
                }

                // Content
                let displayText = (message.isStreaming ? (streamingContent ?? message.content) : message.content)
                MarkdownText(
                    markdown: displayText,
                    font: .system(size: 14),
                    color: VelaTheme.primaryText,
                    isStreaming: message.isStreaming
                )

                // Wiki update badges
                if !message.wikiUpdates.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.accent)
                        Text(L10n.t("Wiki updated: \(message.wikiUpdates.joined(separator: ", "))", "已更新档案: \(message.wikiUpdates.joined(separator: ", "))"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(VelaTheme.accent.opacity(0.12)))
                    .padding(.top, 4)
                }

                // Timestamp
                if !message.isStreaming {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundStyle(VelaTheme.mutedText)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(message.role == .user
                        ? VelaTheme.subtleFill
                        : VelaTheme.surface.opacity(0.4)
                    )
            )

            if message.role == .assistant { Spacer(minLength: 72) }
        }
    }
}

// MARK: - Blinking Modifier

private struct BlinkingModifier: ViewModifier {
    @State private var isVisible = true

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isVisible)
            .onAppear { isVisible = false }
    }
}

extension View {
    func blinking() -> some View {
        modifier(BlinkingModifier())
    }
}

// MARK: - Image Picker (UIKit wrapper)

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
