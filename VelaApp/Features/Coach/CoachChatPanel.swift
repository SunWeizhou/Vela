import SwiftData
import SwiftUI
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

        enum Role: String, Codable, Hashable {
            case user
            case assistant
        }

        enum CodingKeys: String, CodingKey {
            case id, role, content, timestamp, wikiUpdates
        }

        init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), isStreaming: Bool = false, wikiUpdates: [String] = []) {
            self.id = id
            self.role = role
            self.content = content
            self.timestamp = timestamp
            self.isStreaming = isStreaming
            self.wikiUpdates = wikiUpdates
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

    let quickQuestions: [String] = [
        L10n.t("Today's training advice", "今天的训练建议"),
        L10n.t("Weekly trend analysis", "本周趋势分析"),
        L10n.t("Analyze my sleep", "分析我的睡眠"),
        L10n.t("Update my profile", "更新我的档案"),
    ]

    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    private let kimiApiKeyAccount = FoodPhotoAnalyzer.keychainAccount

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
                content: L10n.t("Please add your Kimi API key in Settings first for food photo analysis.", "请先在设置中添加 Kimi API Key，用于食物照片识别。")
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
            try? modelContext.save()

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
            try? modelContext.save()
            self.sessions = [defaultSession]
            self.currentSession = defaultSession
        } else if self.currentSession == nil {
            self.currentSession = list.first
        }
        
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
        try? modelContext.save()
        
        loadSessions(modelContext: modelContext)
        self.currentSession = newSession
        self.messages = []
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
        try? modelContext.save()
        
        if currentSession?.id == session.id {
            currentSession = nil
        }
        loadSessions(modelContext: modelContext)
    }

    func renameSession(_ session: CoachSessionRecord, to newTitle: String, modelContext: ModelContext) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title = trimmed.isEmpty ? "新对话" : trimmed
        session.updatedAt = Date()
        try? modelContext.save()
        loadSessions(modelContext: modelContext)
    }

    func persistThread(modelContext: ModelContext) {
        guard let currentSession else { return }
        let persistable = messages.filter { !$0.isStreaming }
        guard let data = try? JSONEncoder().encode(persistable),
              let json = String(data: data, encoding: .utf8) else { return }
        
        currentSession.serializedMessages = json
        currentSession.updatedAt = Date()
        try? modelContext.save()
        
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

    func send(
        text: String,
        dashboard: DashboardSummary,
        modelContext: ModelContext,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus = .general,
        services: VelaServices? = nil
    ) async {
        let userText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userText.isEmpty, !isStreaming else { return }
        draft = ""
        refreshKeyState()

        messages.append(ChatMsg(role: .user, content: userText))

        // Auto rename title if it was default on the first query
        if let current = currentSession, (current.title == "新对话" || current.title == "New Chat" || current.title == "New Session" || current.title.isEmpty) {
            let cleanQuery = userText.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayTitle = String(cleanQuery.prefix(12)) + (cleanQuery.count > 12 ? "..." : "")
            current.title = displayTitle.isEmpty ? "新对话" : displayTitle
            try? modelContext.save()
        }

        guard let apiKey = try? keychain.read(account: apiKeyAccount), !apiKey.isEmpty else {
            messages.append(ChatMsg(
                role: .assistant,
                content: L10n.t("Please add your DeepSeek API key in Settings first.", "请先在设置中添加 DeepSeek API Key。")
            ))
            isReady = false
            persistThread(modelContext: modelContext)
            isStreaming = false
            return
        }

        isStreaming = true
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

            let provider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
            let toolRegistry = ToolFactory.makeRegistry(
                modelContext: modelContext,
                dashboard: dashboard
            )

            var agentMessages = chatMessages
            let maxIterations = 3
            var fullResponse = ""
            var wikiFiles: [String] = []
            var wikiUpdateSummaries: [String] = []
            var wasStreamed = false

            // Agentic loop: LLM decides whether to call tools or answer
            for iteration in 0..<maxIterations {
                let response = try await provider.chat(
                    messages: agentMessages,
                    tools: toolRegistry.definitions
                )

                // Tool calls detected → execute and feed back
                if let toolCalls = response.toolCalls, !toolCalls.isEmpty {
                    let toolNames = toolCalls.map { $0.name }.joined(separator: ", ")
                    streamingContent = L10n.t(
                        "🔧 Calling tools: \(toolNames)...",
                        "🔧 正在调用工具: \(toolNames)..."
                    )

                    // Append assistant message with tool_calls and reasoning_content
                    agentMessages.append(ChatMessage(
                        role: .assistant,
                        content: response.content,
                        toolCalls: toolCalls,
                        reasoningContent: response.reasoningContent
                    ))

                    // Execute each tool and append results
                    for tc in toolCalls {
                        let result = await toolRegistry.execute(name: tc.name, arguments: tc.arguments)
                        agentMessages.append(ChatMessage(
                            role: .tool,
                            content: result,
                            toolCallId: tc.id
                        ))
                        // Track wiki updates from tool calls
                        if tc.name == "update_user_wiki", !result.hasPrefix("Error"),
                           let data = tc.arguments.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let file = json["file"] as? String {
                            wikiFiles.append(file)
                            if let content = json["content"] as? String {
                                wikiUpdateSummaries.append("\(file): \(content)")
                            }
                        }
                    }

                    streamingContent = ""
                    
                    // If this was the first or second iteration, we stream the final response!
                    if iteration < maxIterations - 1 {
                        let stream = provider.streamChat(messages: agentMessages)
                        var streamedText = ""
                        wasStreamed = true
                        for try await delta in stream {
                            streamedText += delta
                            streamingContent = streamedText
                        }
                        fullResponse = streamedText
                        break
                    }
                    continue
                }

                // Final text response (no more tool calls)
                fullResponse = response.content
                break
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
            
            if !wasStreamed {
                // Smooth character-by-character typing simulation for non-streamed response
                var accumulated = ""
                for char in finalText {
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms per character
                    accumulated.append(char)
                    streamingContent = accumulated
                }
                streamingContent = ""
            }

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
            persistInteraction(userText: userText, assistantText: parsed.displayText, focus: focus, modelContext: modelContext)
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
        } catch {
            streamingContent = ""
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx] = ChatMsg(id: assistantId, role: .assistant, content: error.localizedDescription)
            }
            persistThread(modelContext: modelContext)
        }

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
        let wikiText = wiki.map { "### \($0.key)\n\($0.value)" }.joined(separator: "\n\n")
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
        let weeklyTrends = (try? HealthSnapshotRepository(modelContext: modelContext).buildWeeklyTrendSummary()) ?? [:]
        let snapshots = (try? HealthSnapshotRepository(modelContext: modelContext).fetchSnapshots(days: 30)) ?? []
        let correlations = JournalCorrelationEngine().correlateTags(
            journalEntries: Array(journalEntries),
            snapshots: snapshots
        )
        let correlationText = JournalCorrelationEngine().formatCorrelationsForAI(
            JournalCorrelationEngine().topCorrelations(correlations: correlations)
        )
        let foodLogs = (try? modelContext.fetch(
            FetchDescriptor<FoodLogRecord>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )) ?? []
        let fourteenDaysAgo = Date().addingTimeInterval(-14 * 24 * 3600)
        let strengthWorkouts = (try? modelContext.fetch(
            FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= fourteenDaysAgo },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
        )) ?? []
        let (context, _) = (services?.contextBuilder ?? AIContextBuilder()).build(
            dashboard: dashboard,
            journalEntries: journalEntries.prefix(12).map { JournalContextEntry(tags: $0.tags, text: $0.note) },
            historicalReports: savedReports.filter { $0.type != "coach_thread" }.prefix(6).map { record in
                GeneratedAIReport(
                    type: AIReportType(rawValue: record.type) ?? .morningBrief,
                    title: record.title,
                    markdownContent: record.markdownContent,
                    contextSnapshot: record.serializedContextSnapshot,
                    createdAt: record.createdAt
                )
            },
            userWiki: wiki,
            weeklyTrends: weeklyTrends,
            foodLogs: Array(foodLogs.prefix(8)),
            strengthWorkouts: strengthWorkouts
        )
        let contextJSON = (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}"

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

        var result: [ChatMessage] = [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .system, content: CoachSnapshotDirective.build(dashboard: dashboard)),
            ChatMessage(role: .system, content: "Focus: \(focus.title)\n\(focus.systemContext)")
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

    private func persistInteraction(userText: String, assistantText: String, focus: CoachContextFocus, modelContext: ModelContext) {
        modelContext.insert(JournalEntryRecord(
            createdAt: Date(),
            tags: ["coach", focus.title.lowercased().replacingOccurrences(of: " ", with: "_")],
            note: userText
        ))
        try? modelContext.save()
    }
}

// MARK: - Legacy bridge for CoachChatMessage used by DailyLogService

struct CoachChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    var id: UUID = UUID()
    var role: Role
    var content: String
    var createdAt: Date = Date()
}

// MARK: - Mini Coach Panel (for MetricCoachCard sheets)

struct CoachChatPanel: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var services: VelaServices
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @Query(sort: \AIReportRecord.createdAt, order: .reverse) private var savedReports: [AIReportRecord]

    let dashboard: DashboardSummary
    let focus: CoachContextFocus
    @StateObject private var vm = CoachChatVM()
    @FocusState private var inputFocused: Bool

    // Camera / Food Photo
    @State private var showCameraPicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var capturedImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        // Welcome
                        if vm.messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.title)
                                    .foregroundStyle(VelaTheme.accent)
                                Text(L10n.t("Ask about \(focus.title)", "询问关于\(focus.title)"))
                                    .font(.headline)
                                    .foregroundStyle(VelaTheme.primaryText)
                            }
                            .padding(.top, 20)
                        }

                        ForEach(vm.messages.filter { !$0.isStreaming }) { msg in
                            MiniBubble(message: msg)
                                .id(msg.id)
                        }

                        if vm.isStreaming {
                            MiniStreamingBubble(content: vm.streamingContent)
                                .id("streaming")
                        }
                    }
                    .padding(16)
                }
                .onChange(of: vm.messages.count) {
                    if let id = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
                }
                .onChange(of: vm.streamingContent) {
                    withAnimation { proxy.scrollTo("streaming", anchor: .bottom) }
                }
            }

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
                }
                .disabled(vm.isStreaming || vm.isAnalyzingFood)

                TextField(L10n.t("Ask...", "提问..."), text: $vm.draft, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($inputFocused)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.elevatedSurface))
                    .foregroundStyle(VelaTheme.primaryText)

                Button {
                    inputFocused = false
                    Task {
                        await vm.send(
                            text: vm.draft,
                            dashboard: dashboard,
                            modelContext: modelContext,
                            journalEntries: journalEntries,
                            savedReports: savedReports,
                            focus: focus,
                            services: services
                        )
                    }
                } label: {
                    Image(systemName: vm.isStreaming ? "hourglass" : "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(VelaTheme.accent)
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isStreaming)
            }
            .padding(12)
        }
        .onAppear { vm.refreshKeyState() }
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
                    dashboard: dashboard,
                    modelContext: modelContext,
                    journalEntries: journalEntries,
                    savedReports: savedReports,
                    focus: focus,
                    services: services
                )
            }
        }
    }
}

private enum MessageSegment: Identifiable {
    var id: String {
        switch self {
        case .text(let t): return "text-\(t.hashValue)"
        case .artifact(let type, let key): return "artifact-\(type)-\(key)"
        }
    }
    case text(String)
    case artifact(type: String, key: String)
}

private func parseMessageContent(_ content: String) -> [MessageSegment] {
    var segments: [MessageSegment] = []
    var currentIndex = content.startIndex
    
    while let range = content[currentIndex...].range(of: "\\[ARTIFACT:[^\\]]+\\]", options: .regularExpression) {
        let prefix = content[currentIndex..<range.lowerBound]
        if !prefix.isEmpty {
            segments.append(.text(String(prefix)))
        }
        
        let tag = content[range]
        let cleanTag = tag.dropFirst().dropLast() // "ARTIFACT:correlation:hrv_vs_sleep"
        let parts = cleanTag.components(separatedBy: ":")
        if parts.count >= 2 {
            let type = parts[1]
            let key = parts.count >= 3 ? parts[2...].joined(separator: ":") : ""
            segments.append(.artifact(type: type, key: key))
        } else {
            segments.append(.text(String(tag)))
        }
        
        currentIndex = range.upperBound
    }
    
    let suffix = content[currentIndex...]
    if !suffix.isEmpty {
        segments.append(.text(String(suffix)))
    }
    
    return segments.isEmpty ? [.text(content)] : segments
}

private struct MiniBubble: View {
    let message: CoachChatVM.ChatMsg

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user
                ? (AppLanguage.stored.isChinese ? "你" : "You")
                : "Vela")
                .font(.caption.weight(.semibold))
                .foregroundStyle(message.role == .user ? VelaTheme.accent : VelaTheme.recovery)

            let segments = parseMessageContent(message.content)
            ForEach(segments) { segment in
                switch segment {
                case .text(let text):
                    MarkdownText(markdown: text, font: .subheadline, color: VelaTheme.primaryText, isStreaming: message.isStreaming)
                case .artifact(let type, let key):
                    if type == "correlation" {
                        CorrelationArtifactView(key: key)
                            .padding(.vertical, 4)
                    } else {
                        Text("[Artifact: \(type) - \(key)]")
                            .font(.caption)
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(message.role == .user ? VelaTheme.elevatedSurface : VelaTheme.surface)
        )
    }
}

private struct MiniStreamingBubble: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vela")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.recovery)
            if content.isEmpty {
                ProgressView()
            } else {
                MarkdownText(
                    markdown: content,
                    font: .subheadline,
                    color: VelaTheme.primaryText,
                    isStreaming: true
                )
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VelaTheme.surface)
        )
    }
}

// MARK: - Journal Correlation Tool

/// Allows the coach to query how specific journal tags correlate with health scores.
/// The correlation data is pre-computed and injected into the system prompt context;
/// this tool provides on-demand access to detailed per-tag correlation information.
struct JournalCorrelationTool: AgentTool {
    let name = "journal_correlation"
    let description = "Query how a specific journal tag (e.g., caffeine, alcohol, meditation, late_meal) correlates with sleep, recovery, strain scores, HRV, and RHR. Returns the average scores on days with vs without this tag. Use this to explain behavioral impacts on health metrics."

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "tag": .object([
                    "type": .string("string"),
                    "description": .string("The journal tag to analyze. Common tags: caffeine, alcohol, late_meal, heavy_meal, exercise, stressed, meditation, hydration, supplements, sick, travel, menstruation, sleep, recovery, training, mood."),
                ]),
            ]),
            "required": .array([.string("tag")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag"] as? String else {
            return "Error: missing 'tag' argument."
        }
        return "Correlation data for tag '\(tag)' is available in the Journal Tag Correlation Insights section of your system prompt. Refer to the markdown table for exact sleep score, recovery score, strain score, and impact direction for this and other tracked tags."
    }
}
