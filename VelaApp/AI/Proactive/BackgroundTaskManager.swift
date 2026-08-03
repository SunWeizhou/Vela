import Foundation
import BackgroundTasks
import SwiftData
import os.log

/// Manages registration and scheduling of BGAppRefreshTask for Vela's background agents.
@MainActor
enum BackgroundTaskManager {
    static let refreshTaskIdentifier = "com.sunweizhou.Vela.refresh"

    private static let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "BackgroundTask")

    /// Call once on app launch to register task handlers with BGTaskScheduler.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                logger.error("Received unexpected background task type for \(self.refreshTaskIdentifier).")
                task.setTaskCompleted(success: false)
                return
            }
            handleRefreshTask(task: refreshTask)
        }
        logger.info("BGTask registered: \(self.refreshTaskIdentifier)")
    }

    /// Schedule the next background refresh targeting the nearest agent time window.
    /// iOS determines the actual fire time based on app usage patterns and system conditions.
    static func schedule() {
        let config = AutoAgentConfig.shared
        guard config.canRunBackgroundNetworkAI else {
            cancelAll()
            logger.info("Background network AI is not enabled by the user; no refresh scheduled.")
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = nextTargetTime(config: config)

        do {
            try BGTaskScheduler.shared.submit(request)
            if let target = request.earliestBeginDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                logger.info("Background refresh scheduled, targeting ~\(formatter.string(from: target)).")
            }
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    /// Calculates the next target time for background refresh.
    /// Targets enabled evening/morning skills, whichever comes next.
    private static func nextTargetTime(config: AutoAgentConfig) -> Date {
        let now = Date()
        let cal = Calendar.current

        let enabledHours = [
            config.autoEveningWikiSync ? config.eveningSyncHour : nil,
            config.autoMorningBrief ? config.morningBriefHour : nil
        ].compactMap { $0 }
        let candidateHours = enabledHours.isEmpty ? [config.morningBriefHour] : enabledHours
        let candidates = candidateHours.map { hour -> Date in
            let today = cal.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
            return today > now ? today : (cal.date(byAdding: .day, value: 1, to: today) ?? today)
        }

        return candidates.min() ?? now.addingTimeInterval(3600)
    }

    /// Cancel all pending background tasks (e.g. when user disables the feature).
    static func cancelAll() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)
        logger.info("Pending background refresh cancelled.")
    }

    // MARK: - Handler

    private static func handleRefreshTask(task: BGAppRefreshTask) {
        logger.info("Background refresh task fired.")

        guard AutoAgentConfig.shared.canRunBackgroundNetworkAI else {
            logger.info("Background network AI consent is absent; refresh skipped.")
            task.setTaskCompleted(success: true)
            return
        }

        // Schedule the next refresh immediately while this one runs.
        schedule()

        let handle = Task { @MainActor in
            // Always signal completion exactly once, even if the async work is
            // cancelled (expirationHandler cancels this task). Failing to call
            // setTaskCompleted lets the OS mark the app as failing background work
            // and throttle future BGAppRefreshTask grants.
            var succeeded = false
            defer { task.setTaskCompleted(success: succeeded) }
            do {
                let config = AutoAgentConfig.shared
                let hour = Calendar.current.component(.hour, from: Date())

                let modelContainer = try VelaModelContainer.make()
                let modelContext = ModelContext(modelContainer)
                let bgRun = AgentRunRecord(
                    agentName: "background_refresh",
                    startedAt: Date(),
                    status: .running,
                    reason: "BGAppRefreshTask",
                    outputSummary: "Background refresh started."
                )
                modelContext.insert(bgRun)
                try? modelContext.save()

                // Build DashboardSummary from HealthKit
                let queryService = HealthKitQueryService()
                VelaResolver.shared.register(HealthQueryService.self) { queryService }
                let services = VelaServices()


                let dashboard = try await DailySummaryUseCase(
                    queryService: queryService
                ).loadDashboard(for: Date(), modelContext: modelContext, syncDays: 7)
                try? DailyLogService.refresh(dashboard: dashboard)

                if config.autoEveningWikiSync, (hour >= 21 || hour < 4) {
                    logger.info("Running daily profile sync in background.")
                    await EveningWikiSyncAgent.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: dashboard,
                        services: services
                    )
                } else if config.autoMorningBrief, hour >= 6, hour <= 11 {
                    logger.info("Running morning brief in background.")
                    await MorningBriefScheduler.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: dashboard,
                        services: services
                    )
                } else {
                    logger.info("No agent scheduled for current hour (\(hour)).")
                }

                bgRun.status = AgentRunStatus.success.rawValue
                bgRun.endedAt = Date()
                bgRun.outputSummary = "Background refresh completed. HealthKit sync window: 7 days."
                try? modelContext.save()
                succeeded = true
            } catch {
                logger.error("Background task failed: \(error.localizedDescription)")
                if let modelContainer = try? VelaModelContainer.make() {
                    let modelContext = ModelContext(modelContainer)
                    modelContext.insert(AgentRunRecord(
                        agentName: "background_refresh",
                        startedAt: Date(),
                        endedAt: Date(),
                        status: .failed,
                        reason: "BGAppRefreshTask",
                        outputSummary: "Background refresh failed.",
                        errorMessage: error.localizedDescription
                    ))
                    try? modelContext.save()
                }
            }
        }

        task.expirationHandler = {
            logger.warning("Background refresh task expired.")
            handle.cancel()
        }
    }
}
