import Foundation
import SwiftData
import os.log

/// Runs nightly (target ~23:00) to auto-sync today's health & chat data into the wiki.
/// Falls back to running on next app launch if the background window was missed.
@MainActor
final class EveningWikiSyncAgent: ObservableObject {
    static let shared = EveningWikiSyncAgent()

    private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "EveningWikiSync")
    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    private let contextBuilder = AIContextBuilder()

    @Published var isRunning = false
    @Published var lastSummary: String?
    @Published var lastRunDate: Date?

    private init() {}

    // MARK: - Public

    func runIfNeeded(
        modelContext: ModelContext,
        dashboard: DashboardSummary,
        chatMessages: [CoachChatMessage] = [],
        force: Bool = false
    ) async {
        guard AutoAgentConfig.shared.autoEveningWikiSync else {
            logger.info("Evening wiki sync is disabled in settings.")
            return
        }

        if !force {
            if alreadyRanToday(modelContext: modelContext) {
                logger.info("Evening wiki sync already ran today. Skipping.")
                return
            }
            let hour = Calendar.current.component(.hour, from: Date())
            guard hour >= 21 || hour < 4 else {
                logger.info("Hour \(hour) outside evening window. Skipping.")
                return
            }
        }

        guard let apiKey = try? keychain.read(account: apiKeyAccount), !apiKey.isEmpty else {
            logger.warning("No API key. Cannot run evening wiki sync.")
            return
        }

        logger.info("Starting evening wiki sync...")
        isRunning = true
        defer { isRunning = false }

        let runRecord = AgentRunRecord(
            agentName: "evening_wiki_sync",
            startedAt: Date(),
            status: .running,
            reason: force ? "forced" : "scheduled",
            inputContextHash: "",
            outputSummary: ""
        )
        modelContext.insert(runRecord)
        try? modelContext.save()

        do {
            let wiki = WikiFileService.loadDictionary()

            let (context, contextMeta) = contextBuilder.build(
                dashboard: dashboard,
                journalEntries: [],
                historicalReports: [],
                userWiki: wiki,
                weeklyTrends: (try? HealthSnapshotRepository(modelContext: modelContext).buildWeeklyTrendSummary()) ?? [:]
            )

            let prompt = buildSyncPrompt(
                dashboard: dashboard,
                wiki: wiki,
                chatMessages: chatMessages
            )

            let provider = DeepSeekProvider(apiKey: apiKey)
            let response = try await provider.complete(request: LLMRequest(
                systemPrompt: syncSystemPrompt,
                userPrompt: prompt,
                contextJSON: (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}"
            ))

            // Parse legacy [ACTION:update_wiki] and convert to MemoryProposals
            let parsed = AgentActionParser.parse(response.content)
            var appliedFiles: [String] = []
            let ledger = MemoryLedger(modelContext: modelContext)
            for action in parsed.actions where action.type == .updateWiki {
                let memType = WikiFileRole.memoryTypeFor(filename: action.target)
                let record = try? ledger.createProposal(
                    targetFile: action.target,
                    memoryType: memType,
                    content: action.content,
                    evidence: "Evening wiki sync auto-detected pattern from daily data.",
                    confidence: 0.6,
                    source: "evening_wiki_sync",
                    linkedAgentRunId: runRecord.id.uuidString
                )
                if record != nil {
                    appliedFiles.append(action.target)
                    logger.info("Memory proposal created: \(action.target)")
                }
            }

            // Save daily summary report
            let record = AIReportRecord(
                createdAt: Date(),
                type: "daily_sync",
                title: AppLanguage.stored.isChinese ? "每日同步" : "Daily Sync",
                markdownContent: parsed.displayText.isEmpty ? response.content : parsed.displayText,
                serializedContextSnapshot: (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}",
                tags: ["daily_sync", "automated"] + appliedFiles
            )
            modelContext.insert(record)
            try modelContext.save()

            lastSummary = String(parsed.displayText.prefix(200))
            lastRunDate = Date()
            logger.info("Evening wiki sync complete. Updated \(appliedFiles.count) files.")

            // Update run record
            runRecord.endedAt = Date()
            runRecord.status = AgentRunStatus.success.rawValue
            runRecord.inputContextHash = contextMeta.hash
            runRecord.outputSummary = String(parsed.displayText.prefix(300))
            let toolCallsInfo: [[String: String]] = appliedFiles.map { ["file": $0, "action": "update_wiki"] }
            runRecord.toolCallsJSON = (try? String(data: JSONEncoder().encode(toolCallsInfo), encoding: .utf8)) ?? "[]"
            try? modelContext.save()

            // Reschedule tomorrow's background refresh
            scheduleBackgroundRefresh()
        } catch {
            logger.error("Evening wiki sync failed: \(error.localizedDescription)")
            runRecord.endedAt = Date()
            runRecord.status = AgentRunStatus.failed.rawValue
            runRecord.errorMessage = error.localizedDescription
            try? modelContext.save()
        }
    }

    /// Schedule the next background refresh (best-effort, iOS may defer)
    func scheduleBackgroundRefresh() {
        BackgroundTaskManager.schedule()
        logger.info("Next background refresh scheduled.")
    }

    // MARK: - Private

    private func alreadyRanToday(modelContext: ModelContext) -> Bool {
        let descriptor = FetchDescriptor<AIReportRecord>(
            predicate: #Predicate { $0.type == "daily_sync" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let reports = try? modelContext.fetch(descriptor), let latest = reports.first else {
            return false
        }
        return Calendar.current.isDateInToday(latest.createdAt)
    }

    private var syncSystemPrompt: String {
        if AppLanguage.stored.isChinese {
            return """
            你是 Vela 的每日同步 Agent。你的任务：查看今天的数据，写下关键发现，并更新用户的 Wiki 档案。

            规则：
            1. 观察今天的数据与 Wiki 中已有记录是否有变化、新模式或值得记录的稳定特征
            2. 如果有值得记录的内容，使用 [ACTION:update_wiki] 标签写入对应的 Wiki 文件
            3. 如果没有新发现，就不输出任何 ACTION
            4. 输出一段简短的中文摘要（3-5句话），总结今天的关键数据点

            只记录真正的模式变化或新发现，不要为单日波动更新 Wiki。
            """
        }
        return """
        You are Vela's Daily Sync Agent. Your task: review today's data, note key findings, and update the user's Wiki.

        Rules:
        1. Look for changes, new patterns, or stable characteristics worth recording vs the existing Wiki
        2. If something is worth recording, use [ACTION:update_wiki] tags to write to the relevant Wiki file
        3. If nothing new is worth recording, output NO actions
        4. Output a short summary (3-5 sentences) of today's key data points

        Only record genuine pattern shifts or new findings. Don't update the wiki for single-day fluctuations.
        """
    }

    private func buildSyncPrompt(
        dashboard: DashboardSummary,
        wiki: [String: String],
        chatMessages: [CoachChatMessage]
    ) -> String {
        let wikiText = wiki.map { "### \($0.key)\n\($0.value)" }.joined(separator: "\n\n")
        let chatSummary: String = if chatMessages.isEmpty {
            ""
        } else {
            "\n## 今日对话摘要\n" + chatMessages.suffix(20).map {
                "[\($0.role == .user ? "用户" : "Vela")]: \(String($0.content.prefix(200)))"
            }.joined(separator: "\n")
        }

        if AppLanguage.stored.isChinese {
            return """
            ## 今日健康数据
            恢复: \(Int(dashboard.recovery.score))分, 睡眠: \(Int(dashboard.sleepScore.score))分, 负荷: \(Int(dashboard.strain.score))分
            能量: 早\(Int(dashboard.energy.morningEnergy))/现\(Int(dashboard.energy.currentEnergy))
            HRV: \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "N/A")
            静息心率: \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "N/A")

            ## 当前 Wiki
            \(wikiText)
            \(chatSummary)

            请总结今天的发现并更新 Wiki。
            """
        }
        return """
        ## Today's Health Data
        Recovery: \(Int(dashboard.recovery.score)), Sleep: \(Int(dashboard.sleepScore.score)), Strain: \(Int(dashboard.strain.score))
        Energy: Morning \(Int(dashboard.energy.morningEnergy))/Current \(Int(dashboard.energy.currentEnergy))
        HRV: \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "N/A")
        RHR: \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "N/A")

        ## Current Wiki
        \(wikiText)
        \(chatSummary)

        Please summarize today's findings and update the wiki.
        """
    }
}
