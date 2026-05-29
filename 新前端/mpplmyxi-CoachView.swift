import SwiftData
import SwiftUI
import UIKit

struct CoachView: View {
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

    // Camera / Food Photo
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var capturedImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                VStack(spacing: 0) {
                    if vm.messages.isEmpty {
                        welcomeView
                    } else {
                        messageList
                    }

                    // Quick questions (only when few messages)
                    if vm.messages.count < 3 && !vm.messages.isEmpty {
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

    // MARK: - Welcome

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                VelaLogoMark(size: 56)
                    .shadow(color: VelaTheme.accent.opacity(0.3), radius: 20)

                Text(L10n.t("Hey! I'm Vela", "嘿！我是 Vela"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(L10n.t(
                    "Your private health coach. I analyze your data, learn your patterns, and keep your profile up to date.",
                    "你的私人健康教练。我分析你的数据，学习你的模式，持续更新你的健康档案。"
                ))
                .font(.subheadline)
                .foregroundStyle(VelaTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

                wikiStatusCard

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                    ForEach(vm.quickQuestions, id: \.self) { q in
                        Button { sendQuestion(q) } label: {
                            Text(q)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(VelaTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(VelaTheme.elevatedSurface)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 20)
            }
            .padding(VelaTheme.screenPadding)
        }
    }

    private var wikiStatusCard: some View {
        NavigationLink {
            WikiProfileView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title3)
                    .foregroundStyle(VelaTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Your Profile", "你的档案"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    let docs = WikiFileService.loadAllDocuments()
                    let filled = docs.filter { $0.content.count > 50 }.count
                    Text(L10n.t("\(filled)/\(docs.count) sections filled", "\(filled)/\(docs.count) 项已填写"))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VelaTheme.accent.opacity(0.15), lineWidth: 0.5)
            )
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
        HStack(spacing: 10) {
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
                Image(systemName: "camera.fill")
                    .font(.body)
                    .foregroundStyle(vm.isStreaming || vm.isAnalyzingFood ? VelaTheme.mutedText : VelaTheme.accent)
                    .frame(width: 40, height: 40)
            }
            .disabled(vm.isStreaming || vm.isAnalyzingFood)

            TextField(
                L10n.t("Ask Vela...", "问 Vela..."),
                text: $vm.draft,
                axis: .vertical
            )
            .lineLimit(1...4)
            .focused($inputFocused)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VelaTheme.elevatedSurface)
            )
            .foregroundStyle(VelaTheme.primaryText)

            Button {
                inputFocused = false
                sendQuestion(vm.draft)
            } label: {
                Group {
                    if vm.isStreaming {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                }
                .frame(width: 40, height: 40)
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
            .foregroundStyle(
                vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? VelaTheme.mutedText
                    : VelaTheme.accent
            )
        }
        .padding(.horizontal, VelaTheme.screenPadding)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(VelaTheme.background.opacity(0.9))
                .overlay(alignment: .top) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 0.5)
                }
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
                        .background(Color.white.opacity(0.08))

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
                            .background(Color.white.opacity(0.08))

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
}

// MARK: - Chat Bubble

private struct ChatBubbleView: View {
    let message: CoachChatVM.ChatMsg
    let streamingContent: String?

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Header
                if message.role == .assistant {
                    HStack(spacing: 4) {
                        VelaLogoMark(size: 14)
                        Text("Vela")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.recovery)
                    }
                }

                // Content — use streamingContent during active streaming to avoid full ChatMsg replacement
                let displayText = (message.isStreaming ? (streamingContent ?? message.content) : message.content)
                MarkdownText(markdown: displayText, font: .subheadline, color: VelaTheme.primaryText, isStreaming: message.isStreaming)

                // Streaming cursor (separate from markdown to avoid breaking parsing)
                if message.isStreaming {
                    Text("▊")
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.accent)
                        .opacity(0.7)
                        .blinking()
                }

                // Wiki update badges
                if !message.wikiUpdates.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.accent)
                        Text(L10n.t("Wiki updated: \(message.wikiUpdates.joined(separator: ", "))", "已更新档案: \(message.wikiUpdates.joined(separator: ", "))"))
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(VelaTheme.accent.opacity(0.1)))
                }

                // Timestamp
                if !message.isStreaming {
                    Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(message.role == .user
                        ? VelaTheme.accent.opacity(0.12)
                        : VelaTheme.surface
                    )
            )

            if message.role == .assistant { Spacer(minLength: 60) }
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
