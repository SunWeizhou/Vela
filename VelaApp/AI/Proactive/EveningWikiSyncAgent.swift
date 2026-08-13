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

    @Published var isRunning = false
    @Published var lastSummary: String?
    @Published var lastRunDate: Date?

    private init() {}

    // MARK: - Public

    func runIfNeeded(
        modelContext: ModelContext,
        dashboard: DashboardSummary,
        chatMessages: [CoachChatMessage] = [],
        force: Bool = false,
        services: VelaServices? = nil
    ) async {
        guard force || AutoAgentConfig.shared.autoEveningWikiSync else {
            logger.info("Automated local memory maintenance is not enabled by the user.")
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
            let contextAsOf = Date()
            let input = AgentFactInputLoader().load(
                modelContext: modelContext,
                asOf: contextAsOf
            )
            let personalRulesCreated = runLocalMemoryMaintenance(
                modelContext: modelContext,
                input: input
            )
            let wiki = WikiFileService.loadDictionary()
            let canonicalBodyState = input.bodyState(dashboard: dashboard)
            let coverageSummary = DataCoverageSummaryModel.build(
                groups: await DataCoverageGroupFactory.loadPriorityGroups()
            )
            let (context, contextMeta) = (services?.contextBuilder ?? AIContextBuilder()).buildFacts(
                dashboard: dashboard,
                journalEntries: input.journalContext,
                historicalReports: input.reportContext,
                userWiki: wiki,
                weeklyTrends: input.weeklyTrends,
                foodLogs: input.foodLogs,
                workoutEvents: input.workoutEvents,
                strengthWorkouts: input.strengthWorkouts,
                trainingResponses: input.trainingResponses,
                onboardingState: input.onboardingState,
                bodyState: canonicalBodyState,
                trainingDecision: input.canonicalTrainingDecision(for: canonicalBodyState),
                dataCoverage: coverageSummary.agentFactContext,
                profileAge: WikiFileService.getAgeFromWiki() ?? dashboard.extendedMetrics.age,
                generatedAt: contextAsOf
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let contextJSON = (try? encoder.encode(context))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"

            let networkAIAllowed = force || AutoAgentConfig.shared.canSendHealthContextToNetworkAI
            guard networkAIAllowed,
                  let apiKey = try? keychain.read(account: apiKeyAccount),
                  !apiKey.isEmpty else {
                runRecord.endedAt = Date()
                runRecord.status = AgentRunStatus.success.rawValue
                runRecord.inputContextHash = contextMeta.hash
                runRecord.outputSummary = personalRulesCreated > 0
                    ? "Local memory maintenance proposed \(personalRulesCreated) pattern(s)."
                    : "Local memory maintenance completed; no stable new pattern found."
                runRecord.toolCallsJSON = (try? String(data: JSONEncoder().encode([
                    ["action": "personal_response_scan", "created": "\(personalRulesCreated)"]
                ]), encoding: .utf8)) ?? "[]"
                try modelContext.save()
                lastSummary = runRecord.outputSummary
                lastRunDate = Date()
                scheduleBackgroundRefresh()
                logger.info("Evening local memory maintenance complete without network AI.")
                return
            }

            let prompt = buildSyncPrompt(
                snapshot: context,
                chatMessages: chatMessages
            )

            let provider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
            let response = try await provider.complete(request: LLMRequest(
                systemPrompt: syncSystemPrompt,
                userPrompt: prompt,
                contextJSON: contextJSON
            ))

            // Parse legacy [ACTION:update_wiki] and convert to MemoryProposals
            let parsed = AgentActionParser.parse(response.content)
            var proposalFiles: [String] = []
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
                    proposalFiles.append(action.target)
                    logger.info("Memory proposal created: \(action.target)")
                }
            }

            // Save daily summary report
            let record = AIReportRecord(
                createdAt: Date(),
                type: "daily_sync",
                title: AppLanguage.stored.isChinese ? "每日同步" : "Daily Sync",
                markdownContent: parsed.displayText.isEmpty ? response.content : parsed.displayText,
                serializedContextSnapshot: contextJSON,
                tags: ["daily_sync", "automated"] + proposalFiles
            )
            try PersistenceWriteGate.shared.assertWritable(operation: "EveningWikiSyncAgent: save report", modelContext: modelContext)
            modelContext.insert(record)
            try modelContext.save()

            lastSummary = String(parsed.displayText.prefix(200))
            lastRunDate = Date()
            logger.info("Evening wiki sync complete. Proposed \(proposalFiles.count) memory update(s).")
            try? DailyLogService.write(
                dashboard: dashboard,
                chatMessages: [],
                wikiUpdates: proposalFiles,
                coachArchiveSummary: parsed.displayText.isEmpty ? response.content : parsed.displayText
            )

            // Update run record
            runRecord.endedAt = Date()
            runRecord.status = AgentRunStatus.success.rawValue
            runRecord.inputContextHash = contextMeta.hash
            let personalSummary = personalRulesCreated > 0
                ? "\n\nPersonal Response Model proposed \(personalRulesCreated) new rules."
                : ""
            runRecord.outputSummary = String((parsed.displayText + personalSummary).prefix(500))
            var toolCallsInfo: [[String: String]] = proposalFiles.map { ["file": $0, "action": "propose_memory"] }
            if personalRulesCreated > 0 {
                toolCallsInfo.append(["action": "personal_response_scan", "created": "\(personalRulesCreated)"])
            }
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

    private func runLocalMemoryMaintenance(
        modelContext: ModelContext,
        input: AgentFactInputLoader.Input
    ) -> Int {
        let snapshots = (try? HealthSnapshotRepository(modelContext: modelContext).fetchSnapshots(days: 60)) ?? []
        guard !snapshots.isEmpty else { return 0 }

        let existingDescriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.source == "personal_response_model" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let existingRules = (try? modelContext.fetch(existingDescriptor)) ?? []
        let created = (try? PersonalResponseInsightService().scanAndPropose(
            modelContext: modelContext,
            snapshots: snapshots,
            journalEntries: input.journalRecords,
            foodLogs: input.foodLogs,
            existingRules: existingRules
        )) ?? 0
        if created > 0 {
            logger.info("PersonalResponseModel: \(created) new rules proposed locally")
        }
        return created
    }

    private func alreadyRanToday(modelContext: ModelContext) -> Bool {
        let runDescriptor = FetchDescriptor<AgentRunRecord>(
            predicate: #Predicate { $0.agentName == "evening_wiki_sync" && $0.status == "success" },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        if let latestRun = try? modelContext.fetch(runDescriptor).first,
           Calendar.current.isDateInToday(latestRun.startedAt) {
            return true
        }

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
            2. 如果有值得记录的内容，使用 [ACTION:update_wiki] 标签创建待确认的 Memory Proposal；不要声称已经写入
            3. 如果没有新发现，就不输出任何 ACTION
            4. 输出一段简短的中文摘要（3-5句话），总结今天的关键数据点

            只记录真正的模式变化或新发现，不要为单日波动更新 Wiki。
            """
        }
        return """
        You are Vela's Daily Sync Agent. Your task: review today's data, note key findings, and update the user's Wiki.

        Rules:
        1. Look for changes, new patterns, or stable characteristics worth recording vs the existing Wiki
        2. If something is worth recording, use [ACTION:update_wiki] tags to create a confirmation-required Memory Proposal; do not claim it was already written
        3. If nothing new is worth recording, output NO actions
        4. Output a short summary (3-5 sentences) of today's key data points

        Only record genuine pattern shifts or new findings. Don't update the wiki for single-day fluctuations.
        """
    }

    func buildSyncPrompt(
        snapshot: AgentFactSnapshot,
        chatMessages: [CoachChatMessage]
    ) -> String {
        let chatSummary: String = if chatMessages.isEmpty {
            ""
        } else {
            "\n## 今日对话摘要\n" + chatMessages.suffix(20).map {
                "[\($0.role == .user ? "用户" : "Vela")]: \(String($0.content.prefix(200)))"
            }.joined(separator: "\n")
        }

        if AppLanguage.stored.isChinese {
            return """
            ## 权威事实快照
            - schema: \(snapshot.schemaVersion)
            - content_hash: \(snapshot.contextHash)
            - Data Coverage: \(snapshot.dataCoverage.availableSections)/\(snapshot.dataCoverage.totalSections)
            - 缺失领域: \(snapshot.dataCoverage.missingSections.joined(separator: ", "))
            - Training Decision: \(snapshot.trainingDecision.readinessLevel) · \(snapshot.trainingDecision.readinessGuidance)
            \(chatSummary)

            完整的健康指标、证据状态和当前 Wiki 都在 AgentFactSnapshot JSON 中。只能引用其中 availability 为 available 的指标；总结今天的发现，并仅为稳定模式创建待确认提案。
            """
        }
        return """
        ## Canonical Fact Snapshot
        - schema: \(snapshot.schemaVersion)
        - content_hash: \(snapshot.contextHash)
        - Data Coverage: \(snapshot.dataCoverage.availableSections)/\(snapshot.dataCoverage.totalSections)
        - Missing domains: \(snapshot.dataCoverage.missingSections.joined(separator: ", "))
        - Training Decision: \(snapshot.trainingDecision.readinessLevel) · \(snapshot.trainingDecision.readinessGuidance)
        \(chatSummary)

        The complete metrics, evidence states, and current wiki are in the AgentFactSnapshot JSON. Use only metrics whose availability is available. Summarize today and create confirmation-required proposals only for stable patterns.
        """
    }
}
