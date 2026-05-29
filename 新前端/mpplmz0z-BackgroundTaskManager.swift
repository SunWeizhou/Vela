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
            handleRefreshTask(task: task as! BGAppRefreshTask)
        }
        logger.info("BGTask registered: \(self.refreshTaskIdentifier)")
    }

    /// Schedule the next background refresh.
    /// iOS determines the actual fire time based on app usage patterns and system conditions.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 3600)

        do {
            try BGTaskScheduler.shared.submit(request)
            logger.info("Background refresh scheduled.")
        } catch {
            logger.error("Failed to schedule background refresh: \(error.localizedDescription)")
        }
    }

    /// Cancel all pending background tasks (e.g. when user disables the feature).
    static func cancelAll() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: refreshTaskIdentifier)
        logger.info("Pending background refresh cancelled.")
    }

    // MARK: - Handler

    private static func handleRefreshTask(task: BGAppRefreshTask) {
        logger.info("Background refresh task fired.")

        // Schedule the next refresh immediately
        schedule()

        let handle = Task { @MainActor in
            do {
                let config = AutoAgentConfig.shared
                let hour = Calendar.current.component(.hour, from: Date())

                let modelContainer = try VelaModelContainer.make()
                let modelContext = ModelContext(modelContainer)

                // Build DashboardSummary from HealthKit
                let queryService = HealthKitQueryService()
                let refreshService = HealthDataRefreshService(queryService: queryService)
                let context = try await refreshService.refreshContext()
                let dashboard = DashboardSummary.healthKit(context: context, now: Date(), calendar: .current)

                guard context.hasAnyData else {
                    logger.info("No health data available in background. Skipping.")
                    task.setTaskCompleted(success: true)
                    return
                }

                if config.autoEveningWikiSync, hour >= 21 || hour < 4 {
                    logger.info("Running evening wiki sync in background.")
                    await EveningWikiSyncAgent.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: dashboard
                    )
                } else if config.autoMorningBrief, hour >= 6, hour <= 11 {
                    logger.info("Running morning brief in background.")
                    await MorningBriefScheduler.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: dashboard
                    )
                } else {
                    logger.info("No agent scheduled for current hour (\(hour)).")
                }

                task.setTaskCompleted(success: true)
            } catch {
                logger.error("Background task failed: \(error.localizedDescription)")
                task.setTaskCompleted(success: false)
            }
        }

        task.expirationHandler = {
            logger.warning("Background refresh task expired.")
            handle.cancel()
        }
    }
}
