import SwiftUI
import SwiftData
import UIKit

// MARK: - Shared Types

struct CoachContextFocus: Hashable, Sendable {
    var title: String
    var systemContext: String

    static var general: CoachContextFocus {
        CoachContextFocus(
            title: L10n.t("General Coach", "通用教练"),
            systemContext: L10n.t(
                "General health coaching across recovery, sleep, strain, stress, energy, and journal context.",
                "围绕恢复、睡眠、负荷、压力、能量和日记上下文进行综合健康分析。"
            )
        )
    }
}

enum CoachRequestContinuity {
    static func shouldRetryAfterInterruption(isAppActive: Bool) -> Bool {
        !isAppActive
    }
}

@MainActor
private final class CoachResponseBackgroundLease {
    private var identifier: UIBackgroundTaskIdentifier = .invalid
    private var expirationHandler: (() -> Void)?

    func begin(expirationHandler: @escaping () -> Void) {
        end()
        self.expirationHandler = expirationHandler
        identifier = UIApplication.shared.beginBackgroundTask(withName: "CoachResponse") { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.expirationHandler?()
                self.end()
            }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
        expirationHandler = nil
    }
}

// MARK: - ViewModel

@MainActor
final class CoachChatVM: ObservableObject {

    struct ChatMsg: Identifiable, Hashable, Codable {
        var id: UUID = UUID()
        var role: Role
        var content: String
        var timestamp: Date = Date()
        var isStreaming: Bool = false
        var wikiUpdates: [String] = []
        var recoveryAction: LLMErrorRecoveryAction?

        enum Role: String, Codable, Hashable {
            case user
            case assistant
        }

        enum CodingKeys: String, CodingKey {
            case id, role, content, timestamp, wikiUpdates, recoveryAction
        }

        init(
            id: UUID = UUID(),
            role: Role,
            content: String,
            timestamp: Date = Date(),
            isStreaming: Bool = false,
            wikiUpdates: [String] = [],
            recoveryAction: LLMErrorRecoveryAction? = nil
        ) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
            self.isStreaming = isStreaming
            self.wikiUpdates = wikiUpdates
            self.recoveryAction = recoveryAction
        }
    }

    @Published var messages: [ChatMsg] = []
    @Published var draft = ""
    @Published var isStreaming = false
    @Published var isReady = false
    @Published var streamingContent: String = ""
    @Published var isAnalyzingFood = false
    @Published var isAwaitingForegroundRetry = false
    @Published var persistenceError: String?

    let quickQuestions: [String] = [
        L10n.t("Today's training advice", "今天的训练建议"),
        L10n.t("Weekly trend analysis", "本周趋势分析"),
        L10n.t("Analyze my sleep", "分析我的睡眠"),
        L10n.t("Update my profile", "更新我的档案"),
    ]

    // Delegated stores/helpers
    private let sessionStore = CoachSessionStore()
    private let assembler = CoachContextAssembler()
    private let runner = CoachRequestRunner()
    private let writer = CoachPersistenceWriter()
    private let foodWorkflow = FoodPhotoWorkflow()

    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    private let kimiApiKeyAccount = FoodPhotoAnalyzer.keychainAccount
    private let backgroundLease = CoachResponseBackgroundLease()
    
    private var pendingRequest: PendingRequest?
    private var activeResponseTask: Task<Void, Never>?
    private var isAppActive = true
    private weak var serviceHost: VelaServices?

    private struct PendingRequest {
        var text: String
        var dashboard: DashboardSummary
        var modelContext: ModelContext
        var journalEntries: [JournalEntryRecord]
        var savedReports: [AIReportRecord]
        var focus: CoachContextFocus
    }

    var sessions: [CoachSessionRecord] {
        sessionStore.sessions
    }

    var currentSession: CoachSessionRecord? {
        sessionStore.currentSession
    }

    init() {
        // Wire up persistence error tracking
        sessionStore.$persistenceError
            .assign(to: &$persistenceError)
    }

    static func historyBeforeCurrentPrompt(from messages: [ChatMsg], limit: Int) -> [ChatMsg] {
        Array(messages.filter { !$0.isStreaming }.dropLast().suffix(limit))
    }

    static func timestampedHistoryContent(
        for message: ChatMsg,
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let timestamp = formatter.string(from: message.timestamp)
        return "[Sent at \(timestamp) \(calendar.timeZone.identifier)]\n\(message.content)"
    }

    func refreshKeyState() {
        do {
            isReady = !(try keychain.read(account: apiKeyAccount) ?? "").isEmpty
        } catch {
            isReady = false
        }
    }

    // MARK: - Session Delegation

    func loadSessions(modelContext: ModelContext) {
        sessionStore.loadSessions(
            modelContext: modelContext,
            isStreaming: isStreaming,
            isAwaitingForegroundRetry: isAwaitingForegroundRetry
        ) { [weak self] msgs in
            self?.messages = msgs
        }
    }

    func createNewSession(modelContext: ModelContext) {
        sessionStore.createNewSession(
            modelContext: modelContext,
            isStreaming: isStreaming,
            isAwaitingForegroundRetry: isAwaitingForegroundRetry
        ) { [weak self] msgs in
            self?.messages = msgs
        }
    }

    func selectSession(_ session: CoachSessionRecord, modelContext: ModelContext) {
        sessionStore.selectSession(
            session,
            modelContext: modelContext,
            isStreaming: isStreaming,
            isAwaitingForegroundRetry: isAwaitingForegroundRetry
        ) { [weak self] msgs in
            self?.messages = msgs
        }
    }

    func deleteSession(_ session: CoachSessionRecord, modelContext: ModelContext) {
        sessionStore.deleteSession(
            session,
            modelContext: modelContext,
            isStreaming: isStreaming,
            isAwaitingForegroundRetry: isAwaitingForegroundRetry
        ) { [weak self] msgs in
            self?.messages = msgs
        }
    }

    func renameSession(_ session: CoachSessionRecord, to newTitle: String, modelContext: ModelContext) {
        sessionStore.renameSession(
            session,
            to: newTitle,
            modelContext: modelContext,
            isStreaming: isStreaming,
            isAwaitingForegroundRetry: isAwaitingForegroundRetry
        ) { [weak self] msgs in
            self?.messages = msgs
        }
    }

    func persistThread(modelContext: ModelContext) {
        do {
            try writer.persistThread(messages: messages, currentSession: currentSession, modelContext: modelContext)
        } catch {
            persistenceError = "对话内容未保存。请稍后重试。"
        }
    }

    func clearConversation(modelContext: ModelContext) {
        messages = []
        persistThread(modelContext: modelContext)
    }

    // MARK: - Food Photo Workflow Delegation

    func analyzeFoodPhoto(
        _ image: UIImage,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil
    ) async {
        guard let apiKey = try? keychain.read(account: kimiApiKeyAccount), !apiKey.isEmpty else {
            messages.append(ChatMsg(
                role: .assistant,
                content: L10n.t("Please add your Kimi API key in Settings first for food photo analysis.", "请先在设置中添加 Kimi 密钥，用于食物照片识别。")
            ))
            return
        }
        await foodWorkflow.analyzeFoodPhoto(
            image,
            apiKey: apiKey,
            dashboard: dashboard,
            modelContext: modelContext,
            journalEntries: journalEntries,
            savedReports: savedReports,
            focus: focus,
            services: services,
            chatVM: self
        )
    }

    // MARK: - Send request flow

    func submit(
        text: String,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil
    ) {
        guard activeResponseTask == nil else { return }
        serviceHost = services
        pendingRequest = PendingRequest(
            text: text,
            dashboard: dashboard,
            modelContext: modelContext,
            journalEntries: journalEntries,
            savedReports: savedReports,
            focus: focus
        )
        startPendingRequest(appendingUserMessage: true)
    }

    func handleAppActiveChange(isActive: Bool) {
        isAppActive = isActive
        guard isActive, isAwaitingForegroundRetry else { return }
        startPendingRequest(appendingUserMessage: false)
    }

    func retryLastFailedRequest(
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil
    ) {
        guard activeResponseTask == nil,
              let lastUserText = messages.last(where: { $0.role == .user })?.content else {
            return
        }

        messages.removeAll { $0.role == .assistant && $0.recoveryAction?.destination == .retry }
        serviceHost = services
        pendingRequest = PendingRequest(
            text: lastUserText,
            dashboard: dashboard,
            modelContext: modelContext,
            journalEntries: journalEntries,
            savedReports: savedReports,
            focus: focus
        )
        startPendingRequest(appendingUserMessage: false)
    }

    private func startPendingRequest(appendingUserMessage: Bool) {
        guard activeResponseTask == nil, let pendingRequest else { return }
        isAwaitingForegroundRetry = false
        activeResponseTask = Task { [weak self] in
            guard let self else { return }
            await self.send(
                text: pendingRequest.text,
                dashboard: pendingRequest.dashboard,
                modelContext: pendingRequest.modelContext,
                journalEntries: pendingRequest.journalEntries,
                savedReports: pendingRequest.savedReports,
                focus: pendingRequest.focus,
                services: self.serviceHost,
                appendingUserMessage: appendingUserMessage
            )
            self.activeResponseTask = nil
            if self.isAwaitingForegroundRetry {
                if self.isAppActive {
                    self.startPendingRequest(appendingUserMessage: false)
                }
            } else {
                self.pendingRequest = nil
            }
        }
    }

    private func handleBackgroundTimeExpired() {
        guard activeResponseTask != nil else { return }
        isAwaitingForegroundRetry = true
        activeResponseTask?.cancel()
    }

    func send(
        text: String,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil,
        appendingUserMessage: Bool = true
    ) async {
        let userText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isStreaming else { return }
        draft = ""
        refreshKeyState()

        messages.removeAll { $0.isStreaming }
        streamingContent = ""
        if appendingUserMessage {
            messages.append(ChatMsg(role: .user, content: userText))
        }

        if appendingUserMessage, let current = currentSession, (current.title == "新对话" || current.title == "New Chat" || current.title == "New Session" || current.title.isEmpty) {
            let cleanQuery = userText.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = String(cleanQuery.prefix(12)) + (cleanQuery.count > 12 ? "..." : "")
            current.title = displayTitle.isEmpty ? "新对话" : displayTitle
            try? modelContext.save()
        }

        guard let apiKey = try? keychain.read(account: apiKeyAccount), !apiKey.isEmpty else {
            let providerError = LLMProviderError.missingAPIKey
            messages.append(ChatMsg(
                role: .assistant,
                content: providerError.userFacingMessage(isChinese: AppLanguage.stored.isChinese),
                recoveryAction: providerError.recoveryAction(isChinese: AppLanguage.stored.isChinese)
            ))
            isReady = false
            persistThread(modelContext: modelContext)
            isStreaming = false
            return
        }

        isStreaming = true
        backgroundLease.begin { [weak self] in
            self?.handleBackgroundTimeExpired()
        }
        defer { backgroundLease.end() }

        let assistantId = UUID()
        messages.append(ChatMsg(id: assistantId, role: .assistant, content: "", isStreaming: true))

        do {
            let chatMessages = await assembler.buildChatMessages(
                userText: userText,
                dashboard: dashboard,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                modelContext: modelContext,
                messages: messages
            )

            let contextHash = ContentHash.hash(chatMessages.map(\.content).joined(separator: "\n"))

            let loopResult = try await runner.runRequest(
                userText: userText,
                apiKey: apiKey,
                chatMessages: chatMessages,
                dashboard: dashboard,
                modelContext: modelContext,
                services: services,
                onStreamDelta: { [weak self] delta in
                    self?.streamingContent += delta
                }
            )

            var wikiFiles = loopResult.wikiFiles
            var wikiUpdateSummaries = loopResult.wikiUpdateSummaries
            var fullResponse = loopResult.response

            if fullResponse.isEmpty {
                fullResponse = L10n.t(
                    "I wasn't able to generate a response. Please try again.",
                    "我无法生成回复，请再试一次。"
                )
            }

            let parsed = AgentActionParser.parse(fullResponse)
            let ledger = MemoryLedger(modelContext: modelContext)
            for action in parsed.actions where action.type == .updateWiki {
                let memType = WikiFileRole.memoryTypeFor(filename: action.target)
                let proposal = try? ledger.createProposal(
                    targetFile: action.target,
                    memoryType: memType,
                    content: action.content,
                    evidence: "Coach conversation — AI detected pattern worth recording.",
                    confidence: 0.5,
                    source: "coach_legacy_parser"
                )
                if proposal != nil, !wikiFiles.contains(action.target) {
                    wikiFiles.append(action.target)
                    wikiUpdateSummaries.append("\(action.target): \(action.content)")
                }
            }

            let finalText = parsed.displayText.isEmpty ? fullResponse : parsed.displayText
            
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx] = ChatMsg(
                    id: assistantId,
                    role: .assistant,
                    content: finalText,
                    wikiUpdates: wikiFiles
                )
            }

            persistThread(modelContext: modelContext)
            try writer.persistInteraction(
                userText: userText,
                assistantText: finalText,
                focus: focus,
                contextHash: contextHash,
                currentSession: currentSession,
                modelContext: modelContext
            )

            var agentTrace = loopResult.trace
            agentTrace.finalResponse = finalText
            agentTrace.endedAt = Date()
            try writer.persistAgentTrace(agentTrace, modelContext: modelContext)

            try? DailyLogService.recordInteraction(
                dashboard: dashboard,
                userText: userText,
                assistantText: finalText,
                wikiUpdates: wikiFiles,
                coachArchiveSummary: wikiUpdateSummaries.isEmpty
                    ? nil
                    : "本轮 Coach 主动提出长期档案更新：" + wikiUpdateSummaries.joined(separator: "；")
            )

            isReady = true
            isAwaitingForegroundRetry = false
        } catch {
            streamingContent = ""
            messages.removeAll { $0.id == assistantId }
            let shouldRetry = pendingRequest != nil
                && (isAwaitingForegroundRetry
                    || CoachRequestContinuity.shouldRetryAfterInterruption(isAppActive: isAppActive))
            if shouldRetry {
                isAwaitingForegroundRetry = true
            } else {
                let providerError = LLMProviderError.classify(error)
                messages.append(ChatMsg(
                    id: assistantId,
                    role: .assistant,
                    content: providerError.userFacingMessage(isChinese: AppLanguage.stored.isChinese),
                    recoveryAction: providerError.recoveryAction(isChinese: AppLanguage.stored.isChinese)
                ))
            }
            persistThread(modelContext: modelContext)
        }

        streamingContent = ""
        isStreaming = false
    }
}

// MARK: - CoachSessionStore

@MainActor
final class CoachSessionStore: ObservableObject {
    @Published var sessions: [CoachSessionRecord] = []
    @Published var currentSession: CoachSessionRecord?
    @Published var persistenceError: String?

    init() {}

    func loadSessions(modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let descriptor = FetchDescriptor<CoachSessionRecord>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let list = (try? modelContext.fetch(descriptor)) ?? []
        self.sessions = list
        
        if list.isEmpty {
            let defaultSession = CoachSessionRecord(
                id: UUID(),
                title: "新对话",
                createdAt: Date(),
                updatedAt: Date(),
                serializedMessages: "[]"
            )
            modelContext.insert(defaultSession)
            do {
                try modelContext.save()
                self.sessions = [defaultSession]
                self.currentSession = defaultSession
            } catch {
                modelContext.rollback()
                persistenceError = "无法创建本地对话。请稍后重试。"
            }
        } else if self.currentSession == nil {
            self.currentSession = list.first
        }
        
        guard !isStreaming, !isAwaitingForegroundRetry else { return }

        if let currentSession {
            if let data = currentSession.serializedMessages.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([CoachChatVM.ChatMsg].self, from: data) {
                messagesHandler(decoded)
            } else {
                messagesHandler([])
            }
        }
    }

    func createNewSession(modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let newSession = CoachSessionRecord(
            id: UUID(),
            title: "新对话",
            createdAt: Date(),
            updatedAt: Date(),
            serializedMessages: "[]"
        )
        modelContext.insert(newSession)
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
            self.currentSession = newSession
            messagesHandler([])
        } catch {
            modelContext.rollback()
            persistenceError = "无法创建新对话。请稍后重试。"
        }
    }

    func selectSession(_ session: CoachSessionRecord, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        self.currentSession = session
        if let data = session.serializedMessages.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([CoachChatVM.ChatMsg].self, from: data) {
            messagesHandler(decoded)
        } else {
            messagesHandler([])
        }
        loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
    }

    func deleteSession(_ session: CoachSessionRecord, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        modelContext.delete(session)
        do {
            try modelContext.save()
            if currentSession?.id == session.id {
                currentSession = nil
            }
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
        } catch {
            modelContext.rollback()
            persistenceError = "对话未删除。请稍后重试。"
        }
    }

    func renameSession(_ session: CoachSessionRecord, to newTitle: String, modelContext: ModelContext, isStreaming: Bool, isAwaitingForegroundRetry: Bool, messagesHandler: ([CoachChatVM.ChatMsg]) -> Void) {
        let previousTitle = session.title
        let previousUpdatedAt = session.updatedAt
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title = trimmed.isEmpty ? "新对话" : trimmed
        session.updatedAt = Date()
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext, isStreaming: isStreaming, isAwaitingForegroundRetry: isAwaitingForegroundRetry, messagesHandler: messagesHandler)
        } catch {
            modelContext.rollback()
            session.title = previousTitle
            session.updatedAt = previousUpdatedAt
            persistenceError = "对话标题未保存。请稍后重试。"
        }
    }
}

// MARK: - CoachContextAssembler

@MainActor
struct CoachContextAssembler {
    func buildChatMessages(
        userText: String,
        dashboard: DashboardSummary,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus,
        modelContext: ModelContext,
        messages: [CoachChatVM.ChatMsg]
    ) async -> [ChatMessage] {
        let wiki = WikiFileService.loadDictionary()
        let wikiRawText = wiki.map { "### \($0.key)\n\($0.value)" }.joined(separator: "\n\n")
        let wikiText = ContextBudget.trimWiki(wikiRawText, maxChars: 3000)
        let wikiFiles = WikiFileService.loadAllDocuments().map { "\($0.filename) (\($0.title))" }.joined(separator: ", ")

        let activePlanFetch = FetchDescriptor<TrainingPlanRecord>(
            predicate: #Predicate { $0.isActive }
        )
        let activePlan = (try? modelContext.fetch(activePlanFetch))?.first
        
        var activePlanPrompt = ""
        if let activePlan {
            let completedDays = activePlan.days.filter { $0.isCompleted }.count
            let totalDays = activePlan.days.count
            activePlanPrompt = """
            
            ## 当前处于激活状态的长期训练计划 (Active Training Plan)
            - 计划标题: \(activePlan.title)
            - 目标描述: \(activePlan.goalDescription)
            - 计划周期: \(activePlan.weeksCount) 周
            - 进度详情: 已打卡完成 \(completedDays)/\(totalDays) 天的训练。
            - 计划的每一天日程详情 (打卡状态)：
            """
            for day in activePlan.days {
                let status = day.isCompleted ? "[已完成/Completed]" : "[未完成/Scheduled]"
                activePlanPrompt += "\n  * 第 \(day.weekNumber) 周第 \(day.dayNumber) 天 [类别: \(day.focus)]: \(day.title) (\(day.durationMinutes)分钟, 强度: \(day.intensity)) \(status) - \(day.description)"
            }
        } else {
            activePlanPrompt = "\n- 当前处于激活状态的长期训练计划: 无。如果你建议用户制定长期的、多周的训练计划，你必须使用 `create_training_plan` 工具来保存并启用它。"
        }

        let baselinePrompt: String
        if let baselineContent = wiki["baselines.md"],
           baselineContent.count > 100,
           !baselineContent.contains("will be computed automatically") {
            let compactBaselines = baselineContent
                .components(separatedBy: "\n")
                .filter { $0.contains("|") && !$0.contains("---") && !$0.contains("Metric") }
                .joined(separator: "\n")
            if !compactBaselines.isEmpty {
                baselinePrompt = compactBaselines
            } else {
                baselinePrompt = ""
            }
        } else {
            baselinePrompt = ""
        }

        let personality = CoachPersonality.current
        let lang = AppLanguage.stored
        let policy = ResponseLengthPolicy.forQuery(userText, lang: lang)

        if policy == .casual {
            let composer = CoachPromptComposer(
                lang: lang,
                personality: personality,
                wikiText: wikiText,
                baselinePrompt: baselinePrompt,
                activePlan: activePlan,
                contextJSON: "",
                correlationText: "",
                wikiFiles: wikiFiles
            )
            let systemPrompt = composer.compose(for: .casual)
            var result: [ChatMessage] = [
                ChatMessage(role: .system, content: systemPrompt),
            ]
            let history = CoachChatVM.historyBeforeCurrentPrompt(from: messages, limit: 6)
            for msg in history {
                result.append(ChatMessage(
                    role: msg.role == .user ? .user : .assistant,
                    content: CoachChatVM.timestampedHistoryContent(for: msg)
                ))
            }
            result.append(ChatMessage(role: .user, content: userText))
            return result
        }

        let weeklyTrends = (try? HealthSnapshotRepository(modelContext: modelContext).buildWeeklyTrendSummary()) ?? [:]
        let snapshots = (try? HealthSnapshotRepository(modelContext: modelContext).fetchSnapshots(days: 30)) ?? []
        let correlations = JournalCorrelationEngine().correlateTags(
            journalEntries: Array(journalEntries),
            snapshots: snapshots
        )
        let correlationText = JournalCorrelationEngine().formatCorrelationsForAI(
            JournalCorrelationEngine().topCorrelations(correlations: correlations)
        )
        let fourteenDaysAgo = Date().addingTimeInterval(-14 * 24 * 3600)
        let strengthWorkouts = (try? modelContext.fetch(
            FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= fourteenDaysAgo },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )) ?? []
        let thirtyFiveDaysAgo = Date().addingTimeInterval(-35 * 24 * 3600)
        let dailySummaries = (try? modelContext.fetch(
            FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= thirtyFiveDaysAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        )) ?? []
        let trainingResponses = (try? modelContext.fetch(
            FetchDescriptor<TrainingResponseRecord>(
                predicate: #Predicate<TrainingResponseRecord> { $0.date >= thirtyFiveDaysAgo },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
        )) ?? []
        let workoutEvents = (try? modelContext.fetch(
            FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= thirtyFiveDaysAgo },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )) ?? []
        let foodLogs = (try? modelContext.fetch(
            FetchDescriptor<FoodLogRecord>(
                predicate: #Predicate<FoodLogRecord> { $0.createdAt >= thirtyFiveDaysAgo },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )) ?? []
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            dailySummary: dailySummaries.first,
            workoutEvents: workoutEvents,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            activePlan: activePlan,
            activeStatus: ActiveStatusSettings.resolveCurrentStatus()
        ))
        var onboardingDescriptor = FetchDescriptor<OnboardingState>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        onboardingDescriptor.fetchLimit = 1
        let onboardingState = (try? modelContext.fetch(onboardingDescriptor))?.first

        let biomarkers = (try? modelContext.fetch(
            FetchDescriptor<BiomarkerRecord>(
                sortBy: [SortDescriptor<BiomarkerRecord>(\.date, order: .reverse)]
            )
        )) ?? []

        let contextJSON = budgetCapped(buildCompactContextSnapshot(
            dashboard: dashboard,
            wiki: wiki,
            weeklyTrends: weeklyTrends,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            onboardingState: onboardingState,
            dailySummaries: dailySummaries,
            bodyState: bodyState,
            biomarkers: biomarkers
        ))

        let composer = CoachPromptComposer(
            lang: lang,
            personality: personality,
            wikiText: wikiText,
            baselinePrompt: baselinePrompt,
            activePlan: activePlan,
            contextJSON: contextJSON,
            correlationText: correlationText,
            wikiFiles: wikiFiles
        )
        let systemPrompt = composer.compose(for: policy)
        let coverageSummary = DataCoverageSummaryModel.build(
            groups: await DataCoverageGroupFactory.loadPriorityGroups()
        )

        var result: [ChatMessage] = [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .system, content: """
            ## Data Coverage Guardrail
            \(coverageSummary.coachContextLine)
            If coverage is low or a relevant blocker is listed, lower certainty, avoid pretending missing signals are normal, and tell the user which signal would improve the recommendation.
            """)
        ]

        if policy != .casual, ResponseLengthPolicy.needsWebSearch(userText) {
            let webResults = await WebSearchHelper.shared.search(userText)
            if !webResults.isEmpty {
                result.append(ChatMessage(role: .system, content: """
                ## Web Search Results (live context, triggered by the user's query)
                \(webResults)

                You may reference these results to inform your response — especially for questions about recent studies, guidelines, or general health knowledge.
                """))
            }
        }

        let history = CoachChatVM.historyBeforeCurrentPrompt(from: messages, limit: 10)
        for msg in history {
            result.append(ChatMessage(
                role: msg.role == .user ? .user : .assistant,
                content: CoachChatVM.timestampedHistoryContent(for: msg)
            ))
        }

        if policy == .focused {
            let reinforcement = lang.isChinese ? """
            [系统强制指令：用户以下提出的问题非常聚焦，请用极简短的篇幅（150字以内，3-4句话）直接且针对性地回答，严禁罗列任何无关的健康指标，严禁展示今日状态概览。]
            """ : """
            [SYSTEM FORCED DIRECTIVE: The user's query below is highly focused. Answer in an extremely concise manner (under 150 words, 3-4 sentences max) directly addressing the core question. Do NOT list any unrelated metrics or provide a general daily status summary.]
            """
            result.append(ChatMessage(role: .system, content: reinforcement))
        }

        result.append(ChatMessage(role: .user, content: userText))
        return result
    }

    private func buildCompactContextSnapshot(
        dashboard: DashboardSummary,
        wiki: [String: String],
        weeklyTrends: [String: String],
        strengthWorkouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        onboardingState: OnboardingState?,
        dailySummaries: [DailyHealthSummaryRecord],
        bodyState: BodyState,
        biomarkers: [BiomarkerRecord]
    ) -> String {
        let td = dashboard.trainingDecision
        let hrv = dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0.rounded()))ms" } ?? "N/A"
        let rhr = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded()))bpm" } ?? "N/A"

        var lines: [String] = []
        let bodyDrivers = bodyState.drivers.prefix(3)
            .map { "\($0.title): \($0.detail)" }
            .joined(separator: " | ")

        let lang = AppLanguage.stored
        
        var bioAgeLine = ""
        if let chronologicalAge = WikiFileService.getAgeFromWiki() ?? dashboard.extendedMetrics.age {
            let restingHR = dashboard.recoveryMetrics.restingHeartRate
            let vo2Max = dashboard.bodyMetrics.vo2Max
            let sleepHours = dashboard.sleepSummary.totalSleepMinutes > 0
                ? Double(dashboard.sleepSummary.totalSleepMinutes) / 60.0
                : nil
            let sleepEfficiency = dashboard.sleepScore.metrics["sleep_efficiency"].map { $0 / 100.0 }
            let steps = dashboard.strain.metrics["steps_raw"]
            
            let hasLiveSignal = restingHR != nil
                || vo2Max != nil
                || sleepHours != nil
                || sleepEfficiency != nil
                || steps != nil
                || !biomarkers.isEmpty
                
            if hasLiveSignal {
                let bioAgeResult = BiologicalAgeEngine().calculate(
                    input: BiologicalAgeInput(
                        chronologicalAge: Double(chronologicalAge),
                        restingHR: restingHR,
                        vo2Max: vo2Max,
                        sleepHours: sleepHours,
                        sleepEfficiency: sleepEfficiency,
                        steps: steps,
                        biomarkers: biomarkers
                    )
                )
                
                let isPhenoAge = bioAgeResult.isPhenoAge
                let suboptimalText = bioAgeResult.factors.filter { !$0.isOptimal && $0.type == .biomarker }.map { "\($0.name) (score: \(Int($0.score)))" }.joined(separator: ", ")
                
                if lang.isChinese {
                    bioAgeLine = isPhenoAge
                        ? "- 生物年龄估算: \(String(format: "%.1f", bioAgeResult.biologicalAge)) 岁（实际年龄: \(chronologicalAge) 岁；基于完整 Levine PhenoAge 化验指标）"
                        : "- 健康信号参考: \(bioAgeResult.healthAgeTrendLabel)（基于当前可用可穿戴信号，不等同于生物年龄）"
                    if !suboptimalText.isEmpty {
                        bioAgeLine += "\n- 参考范围外的化验指标: \(suboptimalText)"
                    }
                } else {
                    bioAgeLine = isPhenoAge
                        ? "- Biological age estimate: \(String(format: "%.1f", bioAgeResult.biologicalAge)) yrs (chronological: \(chronologicalAge) yrs; based on complete Levine PhenoAge labs)"
                        : "- Health signal reference: \(bioAgeResult.healthAgeTrendLabel) (from current wearable signals; not a biological-age estimate)"
                    if !suboptimalText.isEmpty {
                        bioAgeLine += "\n- Lab values outside the recorded reference range: \(suboptimalText)"
                    }
                }
            }
        }

        func freshness(for lastUpdated: Date, hasData: Bool) -> DataFreshness {
            guard hasData else { return .missing }
            let age = Date().timeIntervalSince(lastUpdated)
            if age <= 2 * 3_600 { return .live }
            if Calendar.current.isDate(lastUpdated, inSameDayAs: Date()) { return .today }
            if age <= 3 * 86_400 { return .recent }
            return .stale
        }

        func formatMetricWithFreshness(_ metric: MetricResult, labelZh: String, labelEn: String) -> String {
            guard metric.hasData, let val = metric.value else {
                return lang.isChinese
                    ? "\(labelZh): -- (未同步, 新鲜度: 缺失)"
                    : "\(labelEn): -- (not synced, freshness: missing)"
            }
            let valInt = Int(val.rounded())
            let f = freshness(for: metric.lastUpdated, hasData: true)
            let fStrZh: String = switch f {
            case .live: "实时"
            case .today: "今日"
            case .recent: "最近"
            case .stale: "已过期"
            case .missing: "缺失"
            }
            let fStrEn: String = f.rawValue
            
            let timeStrZh: String
            let timeStrEn: String
            if Calendar.current.isDate(metric.lastUpdated, inSameDayAs: Date()) {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                let formattedTime = timeFormatter.string(from: metric.lastUpdated)
                timeStrZh = "今天 \(formattedTime)"
                timeStrEn = "Today \(formattedTime)"
            } else {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM-dd HH:mm"
                let formattedDate = dateFormatter.string(from: metric.lastUpdated)
                timeStrZh = formattedDate
                timeStrEn = formattedDate
            }
            
            return lang.isChinese
                ? "\(labelZh): \(valInt) (最后更新: \(timeStrZh), 新鲜度: \(fStrZh))"
                : "\(labelEn): \(valInt) (last updated: \(timeStrEn), freshness: \(fStrEn))"
        }

        let recoveryLine = formatMetricWithFreshness(dashboard.recovery, labelZh: "恢复", labelEn: "Recovery")
        let sleepLine = formatMetricWithFreshness(dashboard.sleepScore, labelZh: "睡眠", labelEn: "Sleep")
        let strainLine = formatMetricWithFreshness(dashboard.strain, labelZh: "负荷", labelEn: "Strain")
        let energyLine = formatMetricWithFreshness(dashboard.energy, labelZh: "能量", labelEn: "Energy")
        let stressLine = formatMetricWithFreshness(dashboard.stress, labelZh: "压力", labelEn: "Stress")

        if lang.isChinese {
            lines.append("## 今日紧凑快照（完整数据需调用 get_today_health）")
            lines.append("- BodyState \(bodyState.readiness.rawValue) · 置信度 \(bodyState.confidence.rawValue) · 新鲜度 \(bodyState.freshness.rawValue)")
            lines.append("- 驱动: \(bodyDrivers.isEmpty ? "暂无可靠驱动" : bodyDrivers)")
            lines.append("- 来源: \(bodyState.source) · 一般健康建议，不构成医疗诊断")
            if !bioAgeLine.isEmpty {
                lines.append(bioAgeLine)
            }
            lines.append("- \(recoveryLine) · \(sleepLine) · \(strainLine)")
            lines.append("- \(energyLine) · \(stressLine)")
            lines.append("- HRV \(hrv) · 静息心率 \(rhr)")
            lines.append("- 训练准备度 \(td.readinessLevel) · \(td.readinessGuidance)")
            lines.append("- 数据来源 \(dashboard.source.rawValue) · 日期 \(dashboard.date.formatted(date: .numeric, time: .shortened))")
        } else {
            lines.append("## Today's Compact Snapshot (call get_today_health for full data)")
            lines.append("- BodyState \(bodyState.readiness.rawValue) · confidence \(bodyState.confidence.rawValue) · freshness \(bodyState.freshness.rawValue)")
            lines.append("- Drivers: \(bodyDrivers.isEmpty ? "No reliable driver yet" : bodyDrivers)")
            lines.append("- Source: \(bodyState.source) · general wellness guidance, not a medical diagnosis")
            if !bioAgeLine.isEmpty {
                lines.append(bioAgeLine)
            }
            lines.append("- \(recoveryLine) · \(sleepLine) · \(strainLine)")
            lines.append("- \(energyLine) · \(stressLine)")
            lines.append("- HRV \(hrv) · RHR \(rhr)")
            lines.append("- Training Readiness \(td.readinessLevel) · \(td.readinessGuidance)")
            lines.append("- Source \(dashboard.source.rawValue) · Date \(dashboard.date.formatted(date: .numeric, time: .shortened))")
        }

        if !weeklyTrends.isEmpty {
            var trendsBlock = ""
            for (key, value) in weeklyTrends where !value.isEmpty {
                let line = "- \(key): \(value.prefix(120))"
                if trendsBlock.count + line.count + 2 > 500 { break }
                trendsBlock += (trendsBlock.isEmpty ? "" : "\n") + line
            }
            if !trendsBlock.isEmpty {
                lines.append("\n## Weekly Trends\n\(trendsBlock)")
                if trendsBlock.count > 450 {
                    if lang.isChinese {
                        lines.append("[趋势已截断，调用 get_health_history 获取完整数据。]")
                    } else {
                        lines.append("[Trends truncated — call get_health_history for full data.]")
                    }
                }
            }
        }

        if !strengthWorkouts.isEmpty {
            let analytics = TrainingAnalyticsService()
            let recent7d = analytics.buildRecentSummary(workouts: strengthWorkouts, days: 7, endingAt: Date())
            if lang.isChinese {
                lines.append("\n## 力量训练近期\n7d: \(recent7d.sessions)次 \(Int(recent7d.volumeKg))kg \(recent7d.effectiveSets)组 · 调用 get_strength_workout_history 获取详情")
            } else {
                lines.append("\n## Recent Strength\n7d: \(recent7d.sessions) sessions \(Int(recent7d.volumeKg))kg \(recent7d.effectiveSets) sets · call get_strength_workout_history for details")
            }
        }

        if let onboardingState {
            let goal = onboardingState.goalProfile
            if lang.isChinese {
                lines.append("\n## 用户身体模型\n目标: \(goal.primaryGoal) · 经验: \(goal.experienceLevel) · 每周训练 \(onboardingState.trainingPreference.weeklyTrainingDays)天")
            } else {
                lines.append("\n## Body Model\nGoal: \(goal.primaryGoal) · Level: \(goal.experienceLevel) · \(onboardingState.trainingPreference.weeklyTrainingDays) days/week")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func budgetCapped(_ text: String, maxChars: Int = 800) -> String {
        guard text.count > maxChars else { return text }
        let lines = text.components(separatedBy: "\n")
        var result = ""
        for line in lines {
            let candidate = result.isEmpty ? line : "\n\(line)"
            if result.count + candidate.count > maxChars { break }
            result += candidate
        }
        let lang = AppLanguage.stored
        return result + "\n\n" + (lang.isChinese
            ? "[快照已截断以节省 token。调用 get_today_health 获取完整今日数据。]"
            : "[Snapshot truncated to save tokens. Call get_today_health for complete data.]")
    }
}

// MARK: - CoachPersistenceWriter

@MainActor
final class CoachPersistenceWriter {
    func persistThread(messages: [CoachChatVM.ChatMsg], currentSession: CoachSessionRecord?, modelContext: ModelContext) throws {
        guard let currentSession else { return }
        let persistable = messages.filter { !$0.isStreaming }
        let data = try JSONEncoder().encode(persistable)
        guard let json = String(data: data, encoding: .utf8) else { return }
        
        currentSession.serializedMessages = json
        currentSession.updatedAt = Date()
        try modelContext.save()
    }

    func persistInteraction(
        userText: String,
        assistantText: String,
        focus: CoachContextFocus,
        contextHash: String,
        currentSession: CoachSessionRecord?,
        modelContext: ModelContext
    ) throws {
        modelContext.insert(CoachInteractionRecord(
            userText: userText,
            assistantText: assistantText,
            focus: focus.title.lowercased().replacingOccurrences(of: " ", with: "_"),
            contextHash: contextHash,
            sessionId: currentSession?.id
        ))
        try modelContext.save()
    }

    func persistAgentTrace(_ trace: AgentRunTrace, modelContext: ModelContext) throws {
        let toolCallsJSON: String
        if let data = try? JSONEncoder().encode(trace.executedTools),
           let json = String(data: data, encoding: .utf8) {
            toolCallsJSON = json
        } else {
            toolCallsJSON = "[]"
        }
        modelContext.insert(AgentRunRecord(
            id: trace.id,
            agentName: "coach",
            startedAt: trace.startedAt,
            endedAt: trace.endedAt,
            status: .success,
            reason: trace.schemaVersion,
            inputContextHash: trace.contextHash,
            outputSummary: trace.finalResponse,
            toolCallsJSON: toolCallsJSON
        ))
        try modelContext.save()
    }
}

// MARK: - FoodPhotoWorkflow

@MainActor
final class FoodPhotoWorkflow {
    func analyzeFoodPhoto(
        _ image: UIImage,
        apiKey: String,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil,
        chatVM: CoachChatVM
    ) async {
        chatVM.isAnalyzingFood = true
        chatVM.streamingContent = L10n.t("Analyzing your meal with Kimi Vision...", "正在用 Kimi 视觉模型分析你的餐食...")

        do {
            let analyzer = FoodPhotoAnalyzer(apiKey: apiKey)
            let result = try await analyzer.analyzeFoodPhoto(image)

            chatVM.streamingContent = ""
            chatVM.isAnalyzingFood = false

            let formattedResult = result.formattedMarkdown()
            let summaryText = result.plainTextSummary()

            let userMessage = """
            I just took a photo of my meal. Here's the AI-powered nutritional analysis:

            \(formattedResult)

            Based on this analysis and my current health data, can you provide personalized feedback on this meal? Consider my activity level, recovery state, and health goals from my wiki profile.
            """

            await chatVM.send(
                text: userMessage,
                dashboard: dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                services: services
            )

            let foodLog = FoodLogRecord(
                analysis: result,
                mealName: defaultMealName(for: Date()),
                source: .photoAnalysis
            )
            modelContext.insert(foodLog)

            let entry = JournalEntryRecord(
                createdAt: Date(),
                tags: ["food", "meal"],
                note: "[Photo Analysis] \(summaryText)",
                value: Double(result.totalCalories),
                unit: "kcal"
            )
            modelContext.insert(entry)
            
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
        } catch {
            chatVM.streamingContent = ""
            chatVM.isAnalyzingFood = false
            chatVM.messages.append(CoachChatVM.ChatMsg(
                role: .assistant,
                content: L10n.t(
                    "Sorry, I couldn't analyze the food photo: \(error.localizedDescription)",
                    "抱歉，无法分析食物照片：\(error.localizedDescription)"
                )
            ))
        }
    }

    private func defaultMealName(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return "Breakfast"
        case 11..<16:
            return "Lunch"
        case 16..<22:
            return "Dinner"
        default:
            return "Snack"
        }
    }
}

// MARK: - CoachRequestRunner

@MainActor
final class CoachRequestRunner {
    func runRequest(
        userText: String,
        apiKey: String,
        chatMessages: [ChatMessage],
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        services: VelaServices?,
        onStreamDelta: @MainActor @escaping (String) -> Void
    ) async throws -> AgentLoopResult {
        let baseProvider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
        let provider = RetryingAgentChatProvider(base: baseProvider)
        let toolRegistry = ToolFactory.makeRegistry(
            modelContext: modelContext,
            dashboard: dashboard
        )
        
        let lang = AppLanguage.stored
        let policy = ResponseLengthPolicy.forQuery(userText, lang: lang)
        
        if policy == .casual {
            var fullResponse = ""
            let stream = provider.streamChat(messages: chatMessages)
            for try await delta in stream {
                fullResponse += delta
                onStreamDelta(delta)
            }
            
            let trace = AgentRunTrace(
                id: UUID(),
                startedAt: Date(),
                endedAt: Date(),
                inputMessages: chatMessages.map {
                    AgentRunTrace.ChatMessageSnapshot(
                        role: $0.role.rawValue,
                        content: $0.content,
                        toolCalls: $0.toolCalls?.map(\.name)
                    )
                },
                executedTools: [],
                finalResponse: fullResponse,
                contextHash: ContentHash.hash(chatMessages.map(\.content).joined(separator: "\n")),
                schemaVersion: "agentTrace.v1",
                providerCallCount: 1
            )
            return AgentLoopResult(
                response: fullResponse,
                executedTools: [],
                finalMessages: chatMessages,
                wasStreamed: true,
                trace: trace
            )
        } else {
            let agentLoop = AgentLoop(provider: provider, toolRegistry: toolRegistry)
            let snapshotVersion = ContentHash.hash("\(dashboard.date.timeIntervalSince1970)-\(dashboard.source.rawValue)")
            return try await agentLoop.run(
                messages: chatMessages,
                onStreamDelta: { delta in
                    onStreamDelta(delta)
                },
                initialDataVersion: snapshotVersion
            )
        }
    }
}
