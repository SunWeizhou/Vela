import SwiftData
import SwiftUI
import UIKit

/// Minimal web search via Bing.com HTML results.
actor WebSearchHelper {
    static let shared = WebSearchHelper()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    func search(_ query: String, maxResults: Int = 4) async -> String {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.bing.com/search?q=\(encoded)&setlang=en") else {
            return ""
        }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await session.data(for: request),
              let html = String(data: data, encoding: .utf8) else {
            return ""
        }
        return parseResults(from: html, max: maxResults)
    }

    private func parseResults(from html: String, max: Int) -> String {
        var results: [String] = []
        // Bing uses <li class="b_algo"> blocks with <h2> titles and <p class="b_lineclamp*"> snippets
        guard let regex = try? NSRegularExpression(
            pattern: #"<li class="b_algo"[^>]*>(.+?)</li>"#,
            options: [.dotMatchesLineSeparators]
        ) else { return "" }
        let nsRange = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, options: [], range: nsRange).prefix(max) {
            let block = String(html[Range(match.range(at: 1), in: html)!])
            let title = extractBingTitle(from: block)
            let snippet = extractBingSnippet(from: block)
            if !title.isEmpty {
                results.append("[\(title)] \(snippet)")
            }
        }
        return results.isEmpty ? "" : results.joined(separator: "\n")
    }

    private func extractBingTitle(from block: String) -> String {
        guard let range = block.range(of: #"<h2[^>]*>(.+?)</h2>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractBingSnippet(from block: String) -> String {
        guard let range = block.range(of: #"<p class="b_lineclamp[^"]*">(.+?)</p>"#, options: .regularExpression) else { return "" }
        return String(block[range]).replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

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
        L10n.t("How am I doing today?", "我今天状态怎么样？"),
        L10n.t("Should I work out?", "今天适合训练吗？"),
        L10n.t("🏋️ Today's workout plan", "🏋️ 今天的训练建议"),
        L10n.t("🔄 Should I rest today?", "🔄 需要休息吗？"),
        L10n.t("Review my sleep", "分析我的睡眠"),
        L10n.t("📊 Weekly Trends", "📊 本周趋势分析"),
        L10n.t("Morning brief", "早间简报"),
        L10n.t("Update my profile", "更新我的档案"),
    ]

    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    private let kimiApiKeyAccount = FoodPhotoAnalyzer.keychainAccount
    private let contextBuilder = AIContextBuilder()

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
        focus: CoachContextFocus = .general
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
                focus: focus
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
        focus: CoachContextFocus = .general
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
                modelContext: modelContext
            )

            let provider = DeepSeekProvider(apiKey: apiKey)
            let toolRegistry = ToolRegistry(tools: [
                WebSearchTool(),
                UpdateWikiTool(modelContext: modelContext),
                HealthDataTool(),
                JournalCorrelationTool(),
                FoodLogTool(modelContext: modelContext),
                TrainingPlanTool(
                    recoveryScore: dashboard.recovery.score,
                    strainScore: dashboard.strain.score,
                    energyBankScore: dashboard.energy.currentEnergy,
                    atl: dashboard.energy.metrics["atl"] ?? dashboard.strain.score,
                    ctl: dashboard.energy.metrics["ctl"] ?? dashboard.strain.score,
                    tsb: dashboard.energy.metrics["tsb"] ?? 0,
                    sleepScore: dashboard.sleepScore.score,
                    stressIndex: dashboard.stress.stressIndex
                ),
                CreateTrainingPlanTool(modelContext: modelContext),
                RenderCorrelationChartTool(),
            ])

            var agentMessages = chatMessages
            let maxIterations = 3
            var fullResponse = ""
            var wikiFiles: [String] = []

            // Agentic loop: LLM decides whether to call tools or answer
            for _ in 0..<maxIterations {
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
                        if tc.name == "update_user_wiki",
                           let data = tc.arguments.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let file = json["file"] as? String {
                            wikiFiles.append(file)
                        }
                    }

                    streamingContent = ""
                    continue
                }

                // Final text response (no more tool calls)
                fullResponse = response.content
                break
            }

            streamingContent = ""

            if fullResponse.isEmpty {
                fullResponse = L10n.t(
                    "I wasn't able to generate a response. Please try again.",
                    "我无法生成回复，请再试一次。"
                )
            }

            // Also parse legacy [ACTION:] blocks for backward compatibility
            let parsed = AgentActionParser.parse(fullResponse)
            for action in parsed.actions where action.type == .updateWiki {
                try? WikiFileService.updateSection(filename: action.target, content: action.content, mode: .merge)
                if !wikiFiles.contains(action.target) {
                    wikiFiles.append(action.target)
                }
            }

            // Finalize message
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx] = ChatMsg(
                    id: assistantId,
                    role: .assistant,
                    content: parsed.displayText.isEmpty ? fullResponse : parsed.displayText,
                    wikiUpdates: wikiFiles
                )
            }

            // Persist
            persistThread(modelContext: modelContext)
            persistInteraction(userText: userText, assistantText: parsed.displayText, focus: focus, modelContext: modelContext)
            try? DailyLogService.write(dashboard: dashboard, chatMessages: messages.map {
                CoachChatMessage(role: $0.role == .user ? .user : .assistant, content: $0.content, createdAt: $0.timestamp)
            })

            isReady = true
        } catch {
            streamingContent = ""
            if let idx = messages.firstIndex(where: { $0.id == assistantId }) {
                messages[idx] = ChatMsg(id: assistantId, role: .assistant, content: error.localizedDescription)
            }
        }

        isStreaming = false
    }

    // MARK: - Prompt Building

    private func isCasualMessage(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Very short messages are likely greetings
        if trimmed.count < 6 { return true }
        // Common greeting patterns in Chinese and English
        let casualPatterns = [
            "hi", "hello", "hey", "hola", "yo", "sup", "heya",
            "你好", "嗨", "在吗", "在不在", "哈喽", "嘿",
            "早", "早上好", "晚上好", "下午好", "晚安",
            "good morning", "good evening", "good night", "good afternoon",
            "how are you", "what's up", "howdy",
            "你会什么", "你能做什么", "你叫什么", "你是谁",
            "谢谢", "thanks", "thank you", "thx",
            "今天天气", "天气怎么样", "weather",
            "讲个笑话", "joke", "聊天", "聊聊",
        ]
        for pattern in casualPatterns {
            if trimmed.contains(pattern) { return true }
        }
        // Explicit data requests — these are NOT casual
        let dataPatterns = [
            "分析", "数据", "睡眠", "恢复", "压力", "负荷", "能量",
            "analyze", "data", "sleep", "recovery", "strain", "stress", "energy",
            "今天状态", "今日总结", "报告", "怎么样", "总结", "简报",
            "summary", "report", "how am i", "how's my", "check my",
            "建议", "训练", "训练建议", "workout", "training",
            "hrv", "心率", "步态", "gait",
            "搜索", "联网", "查找", "上网", "search", "web",
            "rest", "run", "should i", "適合", "适合", "需要", "休息",
            "训练", "运动", "跑步", "健身", "吃", "饮食", "喝", "水",
            "健康", "心率", "疲劳", "累", "痛", "受伤", "运动科学", "生理"
        ]
        for pattern in dataPatterns {
            if trimmed.contains(pattern) { return false }
        }
        // Default: if the message is short and doesn't ask for data, treat as casual
        return trimmed.count < 20
    }

    private func isGeneralSummaryRequest(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let summaryPatterns = [
            "分析今天的数据", "数据分析", "今日总结", "身体怎么样", "今日状态", "早间简报", "每日简报", "每日报告", "全面分析", "综合分析", "我的状态", "所有状态",
            "daily report", "daily summary", "analyze my day", "how is my data today", "comprehensive analysis", "morning brief",
            "weekly summary", "本周总结", "周报", "总体报告", "概览", "overview"
        ]
        for pattern in summaryPatterns {
            if trimmed.contains(pattern) { return true }
        }
        return false
    }

    /// Returns true when the query would benefit from supplementing with live web search results.
    private func needsWebSearch(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Keywords that suggest a research / current-information need
        let researchPatterns = [
            "研究", "最新", "新研究", "文献", "论文", "期刊", "科学", "指南",
            "推荐", "建议摄入", "摄入量", "标准", "正常范围", "最新指南",
            "research", "study", "studies", "latest", "recent", "new",
            "guidelines", "recommendation", "evidence", "science",
            "nutrition", "diet", "supplement", "vitamin", "mineral",
            "medicine", "drug", "treatment", "therapy",
            "cause", "risk factor", "prevention",
            "what is", "how does", "benefits of", "side effects",
            "calories in", "how many", "how much",
        ]
        for pattern in researchPatterns {
            if trimmed.contains(pattern) { return true }
        }
        // Questions ending with ? that are longer than a casual phrase
        let questionIndicators = ["?", "？", "吗", "啥", "什么", "怎么", "如何", "why", "how", "what", "which", "where", "when"]
        if trimmed.count > 15 {
            for q in questionIndicators {
                if trimmed.contains(q) { return true }
            }
        }
        return false
    }

    private func buildShortPrompt(lang: AppLanguage, personality: CoachPersonality, wikiText: String, baselineText: String) -> String {
        let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none)
        if lang.isChinese {
            return """
            你是 Vela，一位世界顶级私人健康教练。你用自然、温暖、如同极高素养的私人健康搭档般的语调进行对话。

            今天的日期：\(dateStr)

            ## 你的人格设定
            \(personality.systemPrompt)

            ## 联网搜索能力
            你拥有实时联网搜索能力。当用户的问题涉及最新研究、医学指南、营养学知识或任何需要即时信息的查询时，你可以调用搜索功能获取最新资料来辅助回答。

            ## 用户的长期记忆 (User Wiki Profile)
            \(wikiText)

            ## 个人生理基线 (Personal Baselines)
            \(baselineText.isEmpty ? "尚未计算（需要7天以上的数据）" : baselineText)

            ## 核心规则 (CRITICAL)
            - 用户在闲聊或简单问候，你必须**简短回复（2-3 句话以内）**
            - 不要主动展示健康数据或分析，除非用户明确要求
            - 可以主动询问用户今天想关注什么方面
            - 保持温暖、自然、人性化的语调
            """
        } else {
            return """
            You are Vela, a world-class private health coach. Speak naturally, warmly, and empathetically.

            Today's date: \(dateStr)

            ## Your Personality
            \(personality.systemPrompt)

            ## Web Search Capability
            You have real-time web search capability. When users ask about recent studies, medical guidelines, nutrition, or anything requiring up-to-date information, you can search the web to provide the latest findings.

            ## User Wiki Profile (Long-term Memory)
            \(wikiText)

            ## Personal Baselines
            \(baselineText.isEmpty ? "Not yet computed (requires 7+ days of data)." : baselineText)

            ## Critical Rules
            - The user is chatting casually — keep replies **short and concise (2-3 sentences max)**
            - Do NOT dump health data or analysis unless the user explicitly asks
            - You may gently ask what they'd like to focus on today
            - Maintain a warm, natural, human tone
            """
        }
    }

    private func buildChatMessages(
        userText: String,
        dashboard: DashboardSummary,
        journalEntries: [JournalEntryRecord],
        savedReports: [AIReportRecord],
        focus: CoachContextFocus,
        modelContext: ModelContext
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
        let casual = isCasualMessage(userText)

        // Short prompt for casual chat — no health context JSON
        if casual {
            let systemPrompt = buildShortPrompt(lang: lang, personality: personality, wikiText: wikiText, baselineText: baselinePrompt)
            var result: [ChatMessage] = [
                ChatMessage(role: .system, content: systemPrompt),
            ]
            let history = messages.filter { !$0.isStreaming }.suffix(6)
            for msg in history {
                result.append(ChatMessage(role: msg.role == .user ? .user : .assistant, content: msg.content))
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
        let (context, contextMeta) = contextBuilder.build(
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
            foodLogs: Array(foodLogs.prefix(8))
        )
        let contextJSON = (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}"

        let systemPrompt = lang.isChinese ? """
        你是 Vela，一位世界顶级私人健康教练、运动科学家和生活方式医学顾问。你深度掌握用户全方位的健康生理指标（心血管、自主神经、睡眠分期分级、步态平衡、环境噪音及生活习惯等 40 多项维度的精细数据），同时拥有用户的长期个人 Wiki 档案作为持久化记忆。

        今天的日期：\(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))

        ## 用户基本信息 (Demographics)
        你已知用户的年龄、性别、身高、体重、体脂率、BMI 等基础人口学信息。这些信息位于上下文 JSON 的 extendedMetrics 字段中。在分析任何生理指标时，你必须基于用户的年龄和性别进行判断——例如年轻人的正常静息心率、HRV 范围与中年人大不相同；男性和女性的体脂率、HRV 正常范围也存在显著差异。不要使用"群体平均"的抽象概念，而要结合用户的个人基本信息进行精准分析。

        你的终极使命是：将枯燥零散的底层生理指标转化为蕴含运动科学规律、深层因果关联及极极有人文温度的专业指导，帮助用户安全、高效地达成其长远健康与训练目标。

        ## 你的人格设定与沟通风格
        \(personality.systemPrompt)
        请用自然、温暖、如同极高素养的私人健康搭档般的语调进行对话。多用第一人称”我”，避免冰冷生硬的预设套路。

        ## 联网搜索能力
        你拥有实时联网搜索能力。当用户的问题涉及最新研究、指南、营养、疾病机制或任何需要即时信息的查询时，系统会自动获取 Bing 搜索结果作为参考上下文提供给你。你可以引用搜索结果来给出更有据可依的回答。

        ## 用户的长期记忆 (User Wiki Profile)
        这是用户持续维护的真实档案，代表他们的长期背景、体能基础、训练偏好和中长远目标。请随时将当前数据与该档案建立有机结合：
        \(wikiText)
        \(activePlanPrompt)

        ## 个人生理基线 (Personal Baselines)
        \(baselinePrompt.isEmpty ? "尚未计算个人生理基线（需要7天以上的数据）。" : "以下是基于你过去30天真实数据的个人生理基线。分析时请优先使用这些个人基线而非人群平均值：\n\n\(baselinePrompt)")

        ## 用户的多维生理与行为上下文 (Today's Physiology Context)
        包含用户详细生理数据的 JSON 结构。你需要在分析中探索并阐述以下指标间互为因果的关联：
        1. **自主神经与疲劳 (HRV Z-score & RHR)**：
           - 结合 Plews 等运动科学文献，分析用户 HRV 的 rolling 28天个体化 Z-score。
           - 若 HRV Z-Score 为负值且 RHR 上升，表明交感神经过度兴奋、系统性恢复不佳，需建议降低负荷；若 HRV 平稳偏高且 RHR 偏低，则是副交感充能良好，建议冲击高强度。
        2. **睡眠微观结构与恢复力 (Sleep Architecture)**：
           - 睡眠效率（正常应 >= 85%）、REM 比例（理想 20-25%）与深睡眠比例（理想 15-20%）。
           - 寻找前日高负荷、睡前摄入（如咖啡因）或环境噪音对夜间苏醒频次（Continuity）的影响。
        3. **步态力学与神经肌肉状态 (Gait & Mobility)**：
           - 步行速度、双支撑时间比例（正常一般在 20-30% 内）、步幅不对称性（应趋近 0%）。
           - 不对称性异常上升或双支撑比例偏高，是神经肌肉疲劳、下肢代偿或运动损伤风险的明显征兆，应主动警示并给出拉伸或纠正方案。
        4. **环境与习惯暴露因子 (Environment & Habits)**：
           - 水分摄入（理想 >2000ml）、咖啡因（午后两点后若摄入过多易干扰 REM 睡眠）、夜间睡眠腕温及环境噪音（大于 45 dB 会导致微觉醒）。
        5. **今日训练负荷与运动记录 (Workout Load & Activity)**：
           - workouts 字段包含今天所有健身记录的详细列表（运动类型、时长、心率、消耗热量、距离）。
           - 结合 strain 评分与 workout 类型组合分析：高强度训练日是否有充足恢复？训练类型是否过于单一？
           - workouts 为空则说明今天没有记录任何健身活动。
        \(contextJSON)

        ## 日记标签相关性洞察 (Journal Tag Correlation Insights)
        \(correlationText.isEmpty ? "暂无足够的日记标签数据用于相关性分析。" : correlationText)

        ## 你的三大核心执导法则
        1. **多指标深度交叉诊断（Scientific Synthesis）**：
           严禁仅对单一数值进行罗列。务必将多个指标交叉串联，剖析底层生理逻辑。
           当你分析用户数据时，请遵循以下**交叉诊断推理链模式**：
           - **模式 A：自主神经疲劳 + 步态代偿** (条件: HRV Z-Score < -1.0 且 双支撑比例 > 28% 或 步行不对称性 > 3%)
             推理：交感神经过度兴奋 → 中枢性疲劳 → 神经肌肉控制下降 → 下肢代偿性负荷转移。
             行动：建议完全休息日或仅上肢轻量训练，推荐 3 个具体的下肢激活/拉伸动作。
           - **模式 B：睡眠碎片化 + 环境暴露** (条件: 睡眠效率 < 85% 且 夜间环境噪音 > 45dB 或 咖啡因 > 100mg 午后摄入)
             推理：外部环境干扰/咖啡因过度受压 → 微觉醒频率上升 → REM/Deep 比例受损 → 次日 HRV 抑制。
             行动：量化影响（"你的夜间环境噪音达到 XX dB 可能导致了微觉醒"），建议使用白噪音/耳塞或前移咖啡因截止时间。
           - **模式 C：高恢复 + 最佳训练窗口** (条件: HRV Z-Score > +0.5 且 RHR 低于基线 2+ bpm 且 睡眠得分 > 80)
             推理：副交感充能充分 + 神经肌肉完全恢复 → 最佳训练生理窗口期。
             行动：结合 Wiki 中的训练目标，给出具体心率区间、配速及训练量建议。
           - **模式 D：步速下降 + 累积负荷** (条件: 步行速度低于7日均值 5%+ 且 前 3 天 strain 平均 > 65)
             推理：高运动负荷累积 → 外周性肌肉疲劳 → 步态效率与神经反应下降。
             行动：建议 1-2 天主动减载（将训练负荷控制在 strain 30-45 之间）。
           - **模式 E：训练类型与恢复匹配分析** (条件: workouts 非空，结合 strain 和 recovery 评分)
             推理：分析今日运动类型的组合是否合理（如力量训练后有充分的有氧低强度恢复）。
             行动：针对训练频率和类型多样性给出建议；若 workouts 中包含高强度训练，评估恢复得分是否支持高强度连续训练。

           **关键指标参考阈值 (Reference Thresholds for Your Analysis)**：
           - HRV Z-Score: > +1.0 极佳 | +0.3 ~ +1.0 良好 | -0.3 ~ +0.3 基线 | -1.0 ~ -0.3 需关注 | < -1.0 减载
           - 双支撑比例: 20-25% 正常 | 25-30% 轻度代偿 | > 30% 显著疲劳/损伤风险
           - 步行不对称性: < 2% 优秀 | 2-4% 正常 | > 4% 侧偏代偿
           - 睡眠效率: >= 90% 优秀 | 85-90% 良好 | < 85% 需改善
           - REM / 深睡眠比例: REM (20-25%), Deep (15-20%) 为最佳占比

           **Wiki 联动指令**：在交叉诊断中，你**必须**主动将当前数据与 Wiki 中的以下文件内容建立有机联系：
           - goals.md 中的训练目标 -> 今日状态是否是推进目标的好时机？
           - habits.md 中的已知习惯 -> 今日数据是否符合/偏离已知生活模式？
           - training_history.md -> 当前负荷趋势是否与历史训练量契合？
           - health_context.md -> 是否有已知伤病/健康状况需要规避或额外调理？

        2. **极致贴心的个性化实操建议（Elite Pacing Plans）**：
           针对用户的当日生理状态，提供清晰、具体到动作、强度或生活行为的微调方案。
           - 状态爆棚时：规划具体的训练节奏、目标心率区间。
           - 状态欠佳时：提供主动减载（Deload）处方，包含主动恢复动作（如轻度拉伸、深呼吸放松）或睡眠卫生微调。
        3. **个性化训练计划生成（Training Plan Prescription Protocol）**：
           当用户询问训练建议、今日训练计划、是否适合训练或是否需要休息时，你**必须**按以下逻辑进行推荐：
           - **第一步 — 状态评估**：先检查 Recovery（恢复评分）、Energy Bank currentEnergy（当前能量）、TSB（训练压力平衡）三项核心指标。这些数据位于上下文 JSON 的 energy.metrics 字段中。
           - **第二步 — 分级决策**：
             · Recovery > 75 分 且 Energy Bank > 60 分 且 TSB > +5 → **高状态日**：推荐高强度训练。给出具体心率区间（如 Zone 4-5）、配速目标、力量训练组数/次数/重量建议。可积极推动训练目标。
             · Recovery 50-75 分 → **中等状态**：推荐中等强度或主动恢复。建议 Zone 2-3 有氧、中等重量力量训练、瑜伽或技术动作练习。
             · Recovery < 50 分 → **低状态**：推荐休息或极轻度活动。建议散步、泡沫轴放松、静态拉伸、呼吸练习。不要推荐任何高强度训练。
           - **第三步 — 结合 Wiki 目标**：必须查阅用户 Wiki 中 goals.md 的训练目标。减脂目标 → 偏有氧/代谢训练；增肌目标 → 偏力量/肌肥大训练；耐力目标 → 偏有氧基础/阈值训练；柔韧/康复目标 → 偏瑜伽/灵活性训练。
           - **第四步 — TSB 修正**：若 TSB < -15，无论 Recovery 多高，必须降低训练量至少 30-40%（主动减载日）。若 TSB > +10 且 Recovery 高，可适度增加 10-20% 训练量以利用超量补偿窗口。
           - **输出格式**：给出结构化计划——热身（5-10分钟）、主体训练（分项列出具体动作/组数/次数/心率区间/配速）、放松（5-10分钟）。标注每项的时间占比和强度说明。
           - **工具使用**：你可以调用 generate_training_plan 工具获取结构化的生理状态上下文来辅助生成训练计划。
        4. **动态响应模式与极简首回复机制 (CRITICAL)**：
           - **严禁主动展示长篇的今日状态概览、睡眠报告或数据依据，除非用户明确要求**（例如用户说“分析今天的数据”、“今天数据怎么样”、“今日总结”、“身体怎么样”等）。
           - 如果用户只是说简单的问候语（如“你好”、“在吗”、“Hi”）、进行随性闲聊或提出非常具体细微的小问题，你必须**以极简、温暖且高度聚焦的方式进行回复（限制在 2-3 句话以内）**。简单打个招呼，温柔提及“我已为你同步了今日的 30 多项生理指标”，然后主动询问他“今天想重点关注哪个方面？（例如优化睡眠、规划今日训练负荷、或是管理能量消耗）”。
           - **特定问题精准聚焦法则（Concise & Focus Rule）**：当用户向你询问一个非常明确且具体的健康或运动问题（例如：'今天适合训练吗？'，'如何改善我的深睡眠？'），你**必须**紧扣用户问题的核心，仅提取并交叉分析与该问题强相关的生理指标（如：问训练则只看恢复、能量、Strain 和 TSB；问深睡眠则只看睡眠分期与睡前暴露因子）。**严禁主动展示或罗列与问题无关的其它指标**（如问训练时不要主动总结睡眠微觉醒噪音或步行不对称性等），保持回复的高内聚与简洁性。
           - **换行与分段规范（Double Newline Spacing Rule）**：为了提供极佳的排版视觉效果，当你需要进行换行或分段时，你**必须**使用连续的两个换行符来分隔不同的段落或条目。具体来说，在每段结束后加一个空行（即连续按两次回车）。避免使用单个换行符以防止排版在界面中塌陷。
           - 只有当用户确实在进行深度的健康咨询、学术讨论或明确要求分析数据时，才提供结构严密、多维展开的学术级咨询报告，多使用加粗、列表与 Markdown 排版，提升专业阅读体验。

        ## 本周对比分析 (Weekly Trend Comparison)
        你的上下文 JSON 中包含 `weekly_trends` 字段，提供了本周与上周在所有核心指标上的量化对比数据：HRV、静息心率、睡眠评分、恢复评分、负荷评分、压力指数、睡眠时长等。

        这是你进行趋势洞察的关键依据。你必须主动使用这些对比数据：
        - 当用户询问健康进展或总体状态时，**主动**对比本周与上周的变化趋势。
        - 不仅报告数字变化，还要**解释变化背后的生理因果逻辑**。例如："你的 HRV 较上周下降了 12%——这很可能是过去一周训练负荷累积导致自主神经系统疲劳的结果，建议今天进行主动恢复而非高强度训练。"
        - 将每周趋势与用户 Wiki 中的训练目标 (goals.md)、生活习惯 (habits.md) 和健康状况 (health_context.md) 建立有机联系。
        - 如果本周数据出现显著偏差（如 HRV 下降超过 10%、静息心率升高超过 5%、睡眠评分下降超过 10%），应主动标记为需要关注的变化，并结合其他指标交叉分析根本原因。

        ## Wiki 档案自动同步动作 (Memory Update Tag)
        当你在交流中确认了用户新的长期偏好、习惯变化、阶段性伤病康复、目标更新或生理基线变化时，请在回复的最后面附带如下格式的标签，系统会自动将其同步合并到用户的 Wiki Profile 档案中：
        [ACTION:update_wiki]
        file: <文件名>
        <仅写新发现或习惯规律变化，使用 Markdown 清晰呈现，不要重复已有内容>
        [/ACTION]
        可选更新文件：\(wikiFiles)
        （注意：仅在确认了长期且稳定的变化趋势时才使用该动作，不要为单次的临时状况更新）

        ## 安全与学术边界
        - 始终不做医疗诊断。强调 Stress（压力指数）和 Health Age（健康年龄）等仅为生理状态评估工具，不具医学效应。
        - 涉及身体严重不适或极端异常指标时，在给出科学解释之余，以温暖温柔的口吻建议咨询专业医师。
        """ : """
        You are Vela, a world-class private health coach, exercise physiologist, and lifestyle medicine consultant. You possess a comprehensive understanding of the user's multi-system biomarkers (covering 40+ distinct data streams across cardiovascular health, autonomic balance, sleep architecture, gait/mobility dynamics, environmental exposures, and habits) coupled with long-term memory stored in their personal Wiki profile.

        Today's date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))

        ## User Demographics (Critical Context)
        You already KNOW the user's age, biological sex, height, weight, body fat %, and BMI. These are in the extendedMetrics field of the context JSON. You must tailor every analysis to their age and sex — normal resting heart rate and HRV ranges are dramatically different for a 22-year-old vs a 55-year-old; body fat healthy ranges differ by sex. Never default to generic population averages. Use their specific demographics for precise, personalized analysis.

        Your ultimate mission is to translate clinical physiology metrics into holistic, causal sports-science insights and highly actionable, warm, empathetic health plans aligned with their long-term training and health goals.

        ## Personality and Communication Style
        \(personality.systemPrompt)
        Speak naturally, warmly, and empathetically, like an elite, highly knowledgeable personal health partner. Use first-person pronouns ("I", "my") and maintain an organic, fluid conversational flow rather than dumping rigid clinical sections.

        ## Web Search Capability
        You have real-time web search capability. When users ask about recent studies, medical guidelines, nutrition, disease mechanisms, or anything requiring up-to-date information, Bing search results are automatically fetched and provided as reference context. You may cite these results in your responses.

        ## User Wiki Profile (Your Long-term Memory)
        Use these files to continuously ground your advice, training recommendations, and habits context:
        \(wikiText)
        \(activePlanPrompt)

        ## Personal Baselines
        \(baselinePrompt.isEmpty ? "Personal baselines have not been computed yet (requires 7+ days of data)." : "Below are your personal 30-day physiological baselines computed from your own historical data. When comparing today's metrics, use these personal baselines rather than population averages:\n\n\(baselinePrompt)")

        ## Today's Physiological & Behavioral Context (JSON)
        Uncover and explain the causal relationships across these data structures:
        1. **Autonomic Balance (HRV Z-score & RHR)**:
           - Analyze the rolling 28-day individual HRV Z-score. 
           - A negative HRV Z-score with elevated RHR marks sympathetic dominance and fatigue. A high HRV Z-score with lowered RHR represents parasympathetic charging. Customize training load accordingly.
        2. **Sleep Architecture & Quality**:
           - Deep dive into sleep efficiency (ideal >= 85%), REM (ideal 20-25%), and Deep sleep proportions (ideal 15-20%).
           - Identify how training loads, bedtime schedules, caffeine timing, or sleep ambient noise correlate with nighttime awakenings (Continuity).
        3. **Gait Mechanics & Neuromuscular Load (Gait & Mobility)**:
           - Analyze walking speed, walking asymmetry (should be near 0%), and double support percentage (ideal 20-30%).
           - High asymmetry or elevated double support is a strong indicator of localized muscle fatigue, joint stiffness, or compensation patterns. Proactively suggest targeted stretching or kinetic adjustments.
        4. **Exposure & Lifestyle Factors**:
           - Environmental noise (>45 dB average during sleep degrades REM/Deep recovery), wrist temp variations, caffeine (avoid >100mg after 2 PM), and daily hydration (>2000ml).
        5. **Workout Records & Training Load (Activity)**:
           - The workouts field lists all recorded workouts today with type, duration, heart rate, calories, and distance.
           - Cross-reference with strain score: does the workout mix align with recovery status? Are you training with variety or repeating the same type?
           - An empty workouts list means no exercise was recorded today.
        \(contextJSON)

        ## Journal Tag Correlation Insights
        \(correlationText.isEmpty ? "Not enough journal tag data for correlation analysis yet." : correlationText)

        ## Your Three Expert Advisory Principles
        1. **Scientific Causality Synthesis**: Connect the physiological dots instead of reporting separate numbers. Follow these **Cross-Diagnosis Reasoning Patterns**:
           - **Pattern A: Autonomic Fatigue + Gait Compensation** (Condition: HRV Z-Score < -1.0 AND double support % > 28% OR walking asymmetry > 3%)
             Causal Chain: Sympathetic dominance → Central fatigue → Impaired neuromuscular control → Compensatory lower limb load shift.
             Action: Suggest complete rest or light upper-body training only; recommend 3 specific lower-limb mobility drills.
           - **Pattern B: Sleep Fragmentation + Exposure Factors** (Condition: Sleep efficiency < 85% AND night noise > 45dB OR caffeine > 100mg after 2 PM)
             Causal Chain: Ambient noise / stimulant interference → Micro-arousals → Compressed REM/Deep sleep → Next-day suppressed HRV.
             Action: Quantify impact (e.g. "your 52dB noise room likely caused micro-arousals"), recommend white noise/earplugs or early caffeine cutoff.
           - **Pattern C: Peak Readiness + Training Window** (Condition: HRV Z-Score > +0.5 AND RHR below baseline by 2+ bpm AND sleep score > 80)
             Causal Chain: Parasympathetic recovery complete + neuromuscular readiness → Prime biological window for progression.
             Action: Combine with Wiki goals to recommend specific heart rate zones, paces, or workout volume targets.
           - **Pattern D: Decreased Gait Speed + Accumulated Load** (Condition: Walking speed < 7-day avg by 5%+ AND past 3-day average strain > 65)
             Causal Chain: Accumulated training stress → Peripheral muscle fatigue → Degraded gait efficiency.
             Action: Recommend a 1-2 day active deload, keeping training strain low (30-45).
           - **Pattern E: Workout Type & Recovery Balance** (Condition: workouts is non-empty, cross-reference with strain and recovery scores)
             Causal Chain: Workout composition and intensity affect recovery demand.
             Action: Analyze whether the workout mix is balanced (e.g., strength followed by active recovery). If high-intensity workouts are present, check if recovery score supports consecutive hard days.

           **Reference Thresholds for Your Analysis**:
           - HRV Z-Score: > +1.0 Excellent | +0.3 to +1.0 Good | -0.3 to +0.3 Baseline | -1.0 to -0.3 Pay Attention | < -1.0 Deload Recommended
           - Double Support %: 20-25% Normal | 25-30% Mild Compensation | > 30% High Fatigue/Injury Risk
           - Walking Asymmetry: < 2% Excellent | 2-4% Normal | > 4% High Side-compensation
           - Sleep Efficiency: >= 90% Excellent | 85-90% Good | < 85% Needs Improvement
           - REM / Deep Sleep %: REM (20-25%), Deep (15-20%) are optimal ratios.

           **Wiki Integration Directive**: When synthesizing today's analysis, you **must** actively link findings to these Wiki files:
           - goals.md -> Is today an optimal physiological window to push towards the goals?
           - habits.md -> Do today's metrics match or deviate from established lifestyle habits?
           - training_history.md -> Is the current load trend aligned with training history?
           - health_context.md -> Are there active health restrictions or conditions to account for?

        2. **Highly Actionable Pacing & Deload Protocols**:
           - On high-readiness days: Provide precise pacing, heart rate target zones, or workout intensity recommendations.
           - On low-readiness days: Design a concrete active recovery or deload plan, including specific stretches, parasympathetic breathing drills, or sleep hygiene micro-habits.
        3. **Personalized Training Plan Prescription Protocol**:
           When users ask about training recommendations, workout plans, or whether they should train or rest today, you **MUST** follow this decision framework:
           - **Step 1 — State Assessment**: First check Recovery, Energy Bank (currentEnergy), and TSB (Training Stress Balance) as the three core readiness indicators. These are in the context JSON under energy.metrics.
           - **Step 2 — Tiered Decision**:
             · Recovery > 75 AND Energy Bank > 60 AND TSB > +5 → **High Readiness**: Recommend high-intensity training. Provide specific heart rate zones (Zone 4-5), pace targets, strength sets/reps/loading recommendations. Push toward training goals.
             · Recovery 50-75 → **Moderate Readiness**: Recommend moderate intensity or active recovery. Suggest Zone 2-3 cardio, moderate weight strength training, yoga, or skill work.
             · Recovery < 50 → **Low Readiness**: Recommend rest or very light activity only. Suggest walking, foam rolling, static stretching, breathwork. Do NOT recommend any high-intensity training.
           - **Step 3 — Wiki Goals Alignment**: You MUST consult the user's goals.md from their Wiki profile. Fat loss goal → bias cardio/metabolic training; Muscle gain → bias strength/hypertrophy; Endurance → bias aerobic base/threshold; Flexibility/rehab → bias yoga/mobility.
           - **Step 4 — TSB Adjustment**: If TSB < -15, reduce training volume by at least 30-40% regardless of Recovery (active deload day). If TSB > +10 AND Recovery is high, moderately increase volume by 10-20% to capitalize on supercompensation.
           - **Output Format**: Provide a structured plan — Warm-up (5-10 min), Main Session (with specific exercises, sets/reps, heart rate zones, or pace targets), Cool-down (5-10 min). Include time allocations and intensity notes for each segment.
           - **Tool Usage**:
             - For **today's specific single-day workout advice**, you can call the `generate_training_plan` tool to fetch structured autonomic and load reports.
             - For **long-term, multi-week training plans, calendar views, or scheduled training courses** (e.g. "make a 4-week program", "generate a weekly calendar schedule", "training curriculum"), you **MUST** call the `create_training_plan` tool. Explain to the user the high-level plan goals in your text response, then immediately trigger the `create_training_plan` tool. Ensure that you generate details for ALL days in the requested weeks (e.g., for a 4-week program, you must input exactly 28 day entries covering Week 1 Day 1 through Week 4 Day 7. Use `focus: "rest"` and `duration_minutes: 0` for rest days). Once called, the system will save the plan and present it beautifully in the user's "Training Calendar" tab for tracking and haptic check-offs.
        4. **Dynamic Responsive Style & Minimalist First-Response Rule (CRITICAL)**:
           - **NEVER spontaneously dump a long daily status overview, sleep analysis, or metric breakdown unless the user explicitly requests it** (e.g. saying "how is my data today?", "give me a daily summary", or "analyze my sleep").
           - If the user says a simple greeting (e.g. "Hi", "Hello", "Hola"), holds a casual chat, or asks a highly specific quick question, you MUST **reply in a highly concise, warm, and focused manner (limit to 2-3 sentences max)**. Acknowledge their greeting, briefly mention "I have loaded your 30+ health metrics in the background," and ask what they would like to focus on today (e.g. sleeping better, scheduling a workout load, or managing energy levels).
           - **Concise & Focus Rule**: When the user asks a highly specific and concrete health or training question (e.g., 'Is it suitable for me to train today?', 'How can I improve my deep sleep?'), you **must** focus strictly on the core of the user's question, extracting and analyzing only the physiological metrics highly relevant to that question. **Never spontaneously list, summarize, or detail unrelated metrics** (e.g., when asked about training, do not discuss environmental noise during sleep or walking asymmetry). Keep the response highly cohesive and concise.
           - **Double Newline Spacing Rule**: To ensure premium readability and layout, when you need to write line breaks or paragraphs, you **must** separate paragraphs with a blank line (i.e., press Enter twice). Use double newlines between paragraphs and single newlines between lines within the same paragraph. Avoid single newlines for paragraph separation as they collapse in the UI.
           - Reserve comprehensive multi-dimensional analytical reports with beautiful markdown tables and lists exclusively for deep health inquiries or explicit analysis requests.

        ## Weekly Trend Comparison
        Your context JSON includes a `weekly_trends` field with precise week-over-week comparisons for all core metrics: HRV, resting heart rate, sleep score, recovery score, strain score, stress index, sleep hours, and more.

        This is your key analytical asset for trend-based insights. You must actively use these comparisons:
        - When users ask about their progress or general state, **proactively** compare this week vs last week.
        - Go beyond reporting numbers — **explain the physiological narrative behind changes**. For example: "Your HRV dropped 12% this week — likely reflecting accumulated autonomic fatigue from consistent high training loads. I'd recommend active recovery today instead of high-intensity work."
        - Connect weekly trends to the user's Wiki training goals (goals.md), lifestyle habits (habits.md), and health context (health_context.md).
        - If any metric shows a significant deviation (e.g., HRV down over 10%, RHR up over 5%, sleep score down over 10%), proactively flag it as a noteworthy shift and cross-reference with other metrics to surface root causes.

        ## Wiki Long-Term Memory Synced Action (Memory Update Tag)
        If you confirm a new stable habit shift, long-term training preference, recovery progress, or goal update, append the following ACTION block to the very end of your response to persist it:
        [ACTION:update_wiki]
        file: <filename>
        <Write only the new confirmed findings or habit shifts in clear Markdown format; do not repeat existing profile information>
        [/ACTION]
        Available files: \(wikiFiles)
        (Note: Only use this when a stable trend or verified change is confirmed, not for transient single-day fluctuations).

        ## Safety and Science Boundaries
        - Never diagnose medical conditions. Always specify that wellness markers like Stress Index or Health Age are physiological proxies rather than diagnostic tools.
        - Warmly recommend consulting an elite sports physician or doctor if prolonged anomaly patterns or extreme deviations emerge.
        """

        let isSummary = isGeneralSummaryRequest(userText)
        let finalSystemPrompt: String
        if !isSummary {
            let conciseDirective = lang.isChinese ? """
            [⚠️ CRITICAL - CONCISE & TARGETED DIRECTIVE]
            用户正在向你询问一个非常具体、聚焦的问题，因此你必须保持极其简短和精准！
            - 你的整个回复字数必须严格控制在 150 字以内（大约 3-4 句话）。
            - 绝对不要展示或罗列与当前问题无关的其它指标或数据（例如问训练时，绝对不要提睡眠噪音或步行不对称性等）。
            - 仅提取和分析与当前问题直接强相关的 1-2 个指标。
            - 严禁进行主动的大而全的生理状态概览。
            - 直接、具体地回答问题核心，给出直接的建议或结论，保持语调自然温暖。
            
            """ : """
            [⚠️ CRITICAL - CONCISE & TARGETED DIRECTIVE]
            The user is asking a highly specific, focused question. You MUST keep your reply extremely concise and targeted!
            - Your entire response MUST be under 150 words (3-4 sentences max).
            - Absolutely DO NOT list, summarize, or detail any health metrics unrelated to the user's direct question.
            - Focus strictly on the core question, analyze only the 1-2 directly relevant metrics, and provide direct, actionable advice.
            - Never spontaneously dump a general daily summary or comprehensive status overview. Keep it short and warm.
            
            """
            finalSystemPrompt = conciseDirective + systemPrompt
        } else {
            finalSystemPrompt = systemPrompt
        }

        var result: [ChatMessage] = [
            ChatMessage(role: .system, content: finalSystemPrompt),
            ChatMessage(role: .system, content: CoachSnapshotDirective.build(dashboard: dashboard)),
            ChatMessage(role: .system, content: "Focus: \(focus.title)\n\(focus.systemContext)")
        ]

        // Web search: for data-oriented queries that need up-to-date information
        if !casual, needsWebSearch(userText) {
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
        let history = messages.filter { !$0.isStreaming }.suffix(10)
        for msg in history {
            result.append(ChatMessage(role: msg.role == .user ? .user : .assistant, content: msg.content))
        }

        if !isSummary {
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

                        ForEach(vm.messages) { msg in
                            MiniBubble(message: msg)
                                .id(msg.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: vm.messages.count) {
                    if let id = vm.messages.last?.id {
                        withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    }
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
                            focus: focus
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
                    focus: focus
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
