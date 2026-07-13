import Foundation
import SwiftData
import os.log

@MainActor
final class MorningBriefScheduler: ObservableObject {
    static let shared = MorningBriefScheduler()
    
    private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "MorningBriefScheduler")
    
    private let keychain = KeychainService.shared
    private let apiKeyAccount = "deepseek_api_key"
    
    @Published var isGenerating = false
    
    private init() {}
    
    /// Checks if a morning brief needs to be run, and generates/saves it if so.
    /// - Parameters:
    ///   - modelContext: SwiftData modelContext to query and save records
    ///   - dashboard: The current dashboard summary
    ///   - force: If true, runs generation bypassing time window and date checks
    func runIfNeeded(modelContext: ModelContext, dashboard: DashboardSummary, force: Bool = false, services: VelaServices? = nil) async {
        logger.info("runIfNeeded called (force: \(force))")

        guard force || (AutoAgentConfig.shared.backgroundNetworkAIConsent && AutoAgentConfig.shared.autoMorningBrief) else {
            logger.info("Automated morning brief is not enabled by the user. Skipping.")
            return
        }
        
        // 1. If not forced, check time window (06:00 - 11:00)
        if !force {
            let hour = Calendar.current.component(.hour, from: Date())
            guard hour >= 6 && hour < 11 else {
                logger.info("Current hour \(hour) is outside morning window (6-11). Skipping.")
                return
            }
        }
        
        // 2. Check if a morning brief already exists for today's calendar day (unless forced)
        if !force {
            let descriptor = FetchDescriptor<AIReportRecord>(
                predicate: #Predicate<AIReportRecord> { $0.type == "morning_brief" },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            
            do {
                let reports = try modelContext.fetch(descriptor)
                if let latest = reports.first {
                    if Calendar.current.isDateInToday(latest.createdAt) {
                        logger.info("Morning brief already generated today at \(latest.createdAt). Skipping.")
                        return
                    }
                }
            } catch {
                logger.error("Failed to fetch existing morning briefs: \(error.localizedDescription)")
            }
        }
        
        // 3. Read API Key from Keychain
        guard let apiKey = try? keychain.read(account: apiKeyAccount), !apiKey.isEmpty else {
            logger.warning("DeepSeek API Key is not set in Keychain. Cannot generate morning brief.")
            return
        }
        
        logger.info("Starting automated Morning Brief generation...")
        isGenerating = true
        defer { isGenerating = false }

        let runRecord = AgentRunRecord(
            agentName: "morning_brief",
            startedAt: Date(),
            status: .running,
            reason: force ? "forced" : "scheduled",
            inputContextHash: "",
            outputSummary: ""
        )
        modelContext.insert(runRecord)
        try? modelContext.save()

        do {
            // 4. Load the same bounded fact set used by Coach and evening sync.
            let contextAsOf = Date()
            let input = AgentFactInputLoader().load(
                modelContext: modelContext,
                asOf: contextAsOf
            )

            // 5. Load Wiki data
            let wiki = WikiFileService.loadDictionary()

            // 6. Render the frozen v1 report contract from the shared facts.
            let (context, contextMeta) = (services?.contextBuilder ?? AIContextBuilder()).build(
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
                bodyState: input.bodyState(dashboard: dashboard),
                generatedAt: contextAsOf
            )
            
            // 7. Generate Report using ReportGenerator
            let provider = services?.deepSeekProvider(apiKey: apiKey) ?? DeepSeekProvider(apiKey: apiKey)
            let generator = ReportGenerator(provider: provider, language: AppLanguage.stored)
            
            logger.info("Calling ReportGenerator for morning brief...")
            let generatedReport = try await generator.generate(type: .morningBrief, context: context)
            
            // 8. Persist back as a new AIReportRecord in SwiftData modelContext
            let newRecord = AIReportRecord(
                createdAt: generatedReport.createdAt,
                type: generatedReport.type.rawValue,
                title: generatedReport.title,
                markdownContent: generatedReport.markdownContent,
                serializedContextSnapshot: generatedReport.contextSnapshot,
                tags: ["morning_brief", "automated"]
            )
            
            try PersistenceWriteGate.shared.assertWritable(operation: "MorningBriefScheduler: save report", modelContext: modelContext)
            modelContext.insert(newRecord)
            try modelContext.save()
            logger.info("Successfully generated and saved Morning Brief report!")

            // Update the run record
            runRecord.endedAt = Date()
            runRecord.status = AgentRunStatus.success.rawValue
            runRecord.inputContextHash = contextMeta.hash
            runRecord.outputSummary = String(generatedReport.markdownContent.prefix(300))
            try? modelContext.save()

            // Send notification that the morning brief is ready
            NotificationService.shared.scheduleMorningBriefCheck()

        } catch {
            logger.error("Failed to generate Morning Brief: \(error.localizedDescription)")
            runRecord.endedAt = Date()
            runRecord.status = AgentRunStatus.failed.rawValue
            runRecord.errorMessage = error.localizedDescription
            try? modelContext.save()
        }
    }
}
