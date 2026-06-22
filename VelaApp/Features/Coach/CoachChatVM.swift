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

// MARK: - Unified ViewModel

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
    /// Holds the accumulated streaming text without replacing messages[] entries.
    /// This avoids full view tree rebuilds on each token batch.
    @Published var streamingContent: String = ""
    /// True while the food photo is being analyzed by the vision LLM.
    @Published var isAnalyzingFood = false
    @Published private(set) var isAwaitingForegroundRetry = false
    @Published var persistenceError: String?

    let quickQuestions: [String] = [
        L10n.t("Today's training advice", "今天的训练建议"),
        L10n.t("Weekly trend analysis", "本周趋势分析"),
        L10n.t("Analyze my sleep", "分析我的睡眠"),
        L10n.t("Update my profile", "更新我的档案"),
    ]

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

    // MARK: - Key State

    func refreshKeyState() {
        do {
            isReady = !(try keychain.read(account: apiKeyAccount) ?? "").isEmpty
        } catch {
            isReady = false
        }
    }

    // MARK: - Food Photo Analysis

    /// Captures a food photo, sends it to Kimi vision for nutritional analysis,
    /// and injects the structured result as a user message context for the coach.
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

        isAnalyzingFood = true
        streamingContent = L10n.t("Analyzing your meal with Kimi Vision...", "正在用 Kimi 视觉模型分析你的餐食...")

        do {
            let analyzer = FoodPhotoAnalyzer(apiKey: apiKey)
            let result = try await analyzer.analyzeFoodPhoto(image)

            streamingContent = ""
            isAnalyzingFood = false

            let formattedResult = result.formattedMarkdown()
            let summaryText = result.plainTextSummary()

            // Build the user message that includes the food photo analysis context
            let userMessage = """
            I just took a photo of my meal. Here's the AI-powered nutritional analysis:

            \(formattedResult)

            Based on this analysis and my current health data, can you provide personalized feedback on this meal? Consider my activity level, recovery state, and health goals from my wiki profile.
            """

            // Call the normal send flow with the analysis context
            await send(
                text: userMessage,
                dashboard: dashboard,
                modelContext: modelContext,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                services: services
            )

            // Also auto-log the food entry into structured Nutrition plus Journal context.
            let foodLog = FoodLogRecord(
                analysis: result,
                mealName: Self.defaultMealName(for: Date()),
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
            do {
                try modelContext.save()
                VelaAppState.shared.markLocalDataChanged()
            } catch {
                modelContext.rollback()
                persistenceError = L10n.t(
                    "The meal analysis is complete, but its local nutrition log was not saved.",
                    "餐食分析已经完成，但本地营养记录未保存。"
                )
            }

        } catch {
            streamingContent = ""
            isAnalyzingFood = false
            messages.append(ChatMsg(
                role: .assistant,
                content: L10n.t(
                    "Sorry, I couldn't analyze the food photo: \(error.localizedDescription)",
                    "抱歉，无法分析食物照片：\(error.localizedDescription)"
                )
            ))
        }
    }

    private static func defaultMealName(for date: Date, calendar: Calendar = .current) -> String {
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

    // MARK: - Sessions & Persistence

    @Published var sessions: [CoachSessionRecord] = []
    @Published var currentSession: CoachSessionRecord?

    func loadSessions(modelContext: ModelContext) {
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
               let decoded = try? JSONDecoder().decode([ChatMsg].self, from: data) {
                self.messages = decoded
            } else {
                self.messages = []
            }
        }
    }

    func createNewSession(modelContext: ModelContext) {
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
            loadSessions(modelContext: modelContext)
            self.currentSession = newSession
            self.messages = []
        } catch {
            modelContext.rollback()
            persistenceError = "无法创建新对话。请稍后重试。"
        }
    }

    func selectSession(_ session: CoachSessionRecord, modelContext: ModelContext) {
        self.currentSession = session
        if let data = session.serializedMessages.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ChatMsg].self, from: data) {
            self.messages = decoded
        } else {
            self.messages = []
        }
        loadSessions(modelContext: modelContext)
    }

    func deleteSession(_ session: CoachSessionRecord, modelContext: ModelContext) {
        modelContext.delete(session)
        do {
            try modelContext.save()
            if currentSession?.id == session.id {
                currentSession = nil
            }
            loadSessions(modelContext: modelContext)
        } catch {
            modelContext.rollback()
            persistenceError = "对话未删除。请稍后重试。"
        }
    }

    func renameSession(_ session: CoachSessionRecord, to newTitle: String, modelContext: ModelContext) {
        let previousTitle = session.title
        let previousUpdatedAt = session.updatedAt
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title = trimmed.isEmpty ? "新对话" : trimmed
        session.updatedAt = Date()
        do {
            try modelContext.save()
            loadSessions(modelContext: modelContext)
        } catch {
            modelContext.rollback()
            session.title = previousTitle
            session.updatedAt = previousUpdatedAt
            persistenceError = "对话标题未保存。请稍后重试。"
        }
    }

    func persistThread(modelContext: ModelContext) {
        guard let currentSession else { return }
        let persistable = messages.filter { !$0.isStreaming }
        guard let data = try? JSONEncoder().encode(persistable),
              let json = String(data: data, encoding: .utf8) else { return }
        
        let previousMessages = currentSession.serializedMessages
        let previousUpdatedAt = currentSession.updatedAt
        currentSession.serializedMessages = json
        currentSession.updatedAt = Date()
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            currentSession.serializedMessages = previousMessages
            currentSession.updatedAt = previousUpdatedAt
            persistenceError = "对话内容未保存。请稍后重试。"
            return
        }
        
        // Reload list to keep list in sync
        let descriptor = FetchDescriptor<CoachSessionRecord>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        self.sessions = (try? modelContext.fetch(descriptor)) ?? []
    }

    func restoreHistory(from reports: [AIReportRecord]) {
        // Legacy compatibility
    }

    func clearConversation(modelContext: ModelContext) {
        messages = []
        persistThread(modelContext: modelContext)
    }

    // MARK: - Send

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

        // Auto rename title if it was default on the first query
        if appendingUserMessage, let current = currentSession, (current.title == "新对话" || current.title == "New Chat" || current.title == "New Session" || current.title.isEmpty) {
            let cleanQuery = userText.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = String(cleanQuery.prefix(12)) + (cleanQuery.count > 12 ? "..." : "")
            current.title = displayTitle.isEmpty ? "新对话" : displayTitle
            _ = save(modelContext, failureMessage: "对话标题未保存。请稍后重试。")
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
            let chatMessages = await buildChatMessages(
                userText: userText,
                dashboard: dashboard,
                journalEntries: journalEntries,
                savedReports: savedReports,
                focus: focus,
                modelContext: modelContext,
                services: services
            )

            let baseProvider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
            let provider = RetryingAgentChatProvider(base: baseProvider)
            let toolRegistry = ToolFactory.makeRegistry(
                modelContext: modelContext,
                dashboard: dashboard
            )

            let agentMessages = chatMessages
            var fullResponse = ""
            var wikiFiles: [String] = []
            var wikiUpdateSummaries: [String] = []
            var agentTrace: AgentRunTrace?
            let agentStartedAt = Date()
            let contextHash = ContentHash.hash(chatMessages.map(\.content).joined(separator: "\n"))

            let lang = AppLanguage.stored
            let policy = ResponseLengthPolicy.forQuery(userText, lang: lang)

            if policy == .casual {
                // Direct streaming for casual chat to bypass agentic tool calling
                let stream = provider.streamChat(messages: agentMessages)
                for try await delta in stream {
                    fullResponse += delta
                    streamingContent = fullResponse
                }
                agentTrace = AgentRunTrace(
                    id: UUID(),
                    startedAt: agentStartedAt,
                    endedAt: Date(),
                    inputMessages: agentMessages.map {
                        AgentRunTrace.ChatMessageSnapshot(
                            role: $0.role.rawValue,
                            content: $0.content,
                            toolCalls: $0.toolCalls?.map(\.name)
                        )
                    },
                    executedTools: [],
                    finalResponse: fullResponse,
                    contextHash: contextHash,
                    schemaVersion: "agentTrace.v1",
                    providerCallCount: 1
                )
            } else {
                let agentLoop = AgentLoop(provider: provider, toolRegistry: toolRegistry)
                let snapshotVersion = ContentHash.hash("\(dashboard.date.timeIntervalSince1970)-\(dashboard.source.rawValue)")
                let loopResult = try await agentLoop.run(
                    messages: agentMessages,
                    onStreamDelta: { @MainActor [weak self] delta in
                        guard let self else { return }
                        self.streamingContent += delta
                    },
                    initialDataVersion: snapshotVersion
                )
                wikiFiles = loopResult.wikiFiles
                wikiUpdateSummaries = loopResult.wikiUpdateSummaries
                fullResponse = loopResult.response
                var loopTrace = loopResult.trace
                loopTrace.contextHash = contextHash
                agentTrace = loopTrace
            }

            if fullResponse.isEmpty {
                fullResponse = L10n.t(
                    "I wasn't able to generate a response. Please try again.",
                    "我无法生成回复，请再试一次。"
                )
            }

            // Parse legacy [ACTION:] blocks for backward compatibility
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
            
            // Finalize message
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx] = ChatMsg(
                    id: assistantId,
                    role: .assistant,
                    content: finalText,
                    wikiUpdates: wikiFiles
                )
            }

            // Persist
            persistThread(modelContext: modelContext)
            persistInteraction(
                userText: userText,
                assistantText: finalText,
                focus: focus,
                contextHash: contextHash,
                modelContext: modelContext
            )
            if var agentTrace {
                agentTrace.finalResponse = finalText
                agentTrace.endedAt = Date()
                persistAgentTrace(agentTrace, modelContext: modelContext)
            }
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

    // MARK: - Prompt Building

    private func buildChatMessages(
        userText: String,
        dashboard: DashboardSummary,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus,
        modelContext: ModelContext,
        services: VelaServices? = nil
    ) async -> [ChatMessage] {
        let wiki = WikiFileService.loadDictionary()
        let wikiRawText = wiki.map { "### \($0.key)\n\($0.value)" }.joined(separator: "\n\n")
        let wikiText = ContextBudget.trimWiki(wikiRawText, maxChars: 3000)
        let wikiFiles = WikiFileService.loadAllDocuments().map { "\($0.filename) (\($0.title))" }.joined(separator: ", ")

        // Fetch active training plan context
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
            activePlanPrompt = "\n- 当前处于激活状态的长期训练计划: 无。如果你建议用户制定长期的、多周的训练计划，你必须使用 `create_training_plan` 工具来保存和启用它。"
        }

        // Read personal baselines if available
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

        // Casual chat — short prompt, no health context JSON
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
            let history = Self.historyBeforeCurrentPrompt(from: messages, limit: 6)
            for msg in history {
                result.append(ChatMessage(
                    role: msg.role == .user ? .user : .assistant,
                    content: Self.timestampedHistoryContent(for: msg)
                ))
            }
            result.append(ChatMessage(role: .user, content: userText))
            return result
        }

        // Full prompt for health data inquiries
        // Build a compact context snapshot — the LLM must use tools for detailed data.
        // This avoids stale/mismatched data between the inline JSON and tool responses.
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

        // Web search: for data-oriented queries that need up-to-date information
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

        // Conversation history (skip streaming, take last 10)
        let history = Self.historyBeforeCurrentPrompt(from: messages, limit: 10)
        for msg in history {
            result.append(ChatMessage(
                role: msg.role == .user ? .user : .assistant,
                content: Self.timestampedHistoryContent(for: msg)
            ))
        }

        // Focused policy: add a reinforcement directive before the user message
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

    /// Builds a compact snapshot inline context — scores, bands, key reasons, and data-source pointers.
    /// The LLM MUST use tools (get_today_health, get_health_history, etc.) for detailed metrics.
    /// This avoids the stale mismatch between inline JSON and tool-returned data.
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
        
        // Calculate Biological Age
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

        // ── Scores at a glance ──
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

        // ── Weekly trends summary (compact, budget-trimmed) ──
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

        // ── Strength recap — only show counts, details moved to tools ──
        if !strengthWorkouts.isEmpty {
            let analytics = TrainingAnalyticsService()
            let recent7d = analytics.buildRecentSummary(workouts: strengthWorkouts, days: 7, endingAt: Date())
            if lang.isChinese {
                lines.append("\n## 力量训练近期\n7d: \(recent7d.sessions)次 \(Int(recent7d.volumeKg))kg \(recent7d.effectiveSets)组 · 调用 get_strength_workout_history 获取详情")
            } else {
                lines.append("\n## Recent Strength\n7d: \(recent7d.sessions) sessions \(Int(recent7d.volumeKg))kg \(recent7d.effectiveSets) sets · call get_strength_workout_history for details")
            }
        }

        // ── Body model onboarding flags (compact) ──
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

    /// Trims the snapshot to fit within the context budget, preserving the most critical lines.
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

    private func persistInteraction(
        userText: String,
        assistantText: String,
        focus: CoachContextFocus,
        contextHash: String,
        modelContext: ModelContext
    ) {
        modelContext.insert(CoachInteractionRecord(
            userText: userText,
            assistantText: assistantText,
            focus: focus.title.lowercased().replacingOccurrences(of: " ", with: "_"),
            contextHash: contextHash,
            sessionId: currentSession?.id
        ))
        _ = save(modelContext, failureMessage: "Coach 交互记录未保存。请稍后重试。")
    }

    private func persistAgentTrace(_ trace: AgentRunTrace, modelContext: ModelContext) {
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
        _ = save(modelContext, failureMessage: "Coach 运行记录未保存。请稍后重试。")
    }

    @discardableResult
    private func save(_ modelContext: ModelContext, failureMessage: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            persistenceError = failureMessage
            return false
        }
    }
}
