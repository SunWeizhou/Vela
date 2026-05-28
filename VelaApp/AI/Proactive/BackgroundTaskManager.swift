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
                let services = VelaServices(queryService: queryService)
                let refreshService = HealthDataRefreshService(queryService: queryService)
                let context = try await refreshService.refreshContext()

                guard context.hasAnyData else {
                    logger.info("No health data available in background. Skipping.")
                    task.setTaskCompleted(success: true)
                    return
                }

                let sleepTarget = UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60
                let effectiveSleepTarget = sleepTarget > 0 ? sleepTarget : 450
                let sleepScore = SleepScoreEngine().calculate(
                    from: ScoreEngineFactory.sleep(from: context, sleepTarget: effectiveSleepTarget, bedtimeOffsetMinutes: nil, wakeOffsetMinutes: nil)
                )
                let recovery = RecoveryScoreEngine().calculate(
                    from: ScoreEngineFactory.recovery(from: context, sleepScore: sleepScore.score, strainScoreYesterday: nil, hrvHistory: [], rhrHistory: [])
                )
                let strain = StrainScoreEngine().calculate(
                    from: ScoreEngineFactory.strain(from: context, recoveryScore: recovery.score)
                )
                let stress = StressIndexEngine().calculate(
                    from: ScoreEngineFactory.stress(from: context, sleepScore: sleepScore.score, strainScore: strain.score)
                )
                let energy = EnergyBankEngine().calculate(
                    from: ScoreEngineFactory.energyBank(from: context, recoveryScore: recovery.score, sleepScore: context.sleepSummary == nil ? nil : sleepScore.score, strainScore: strain.score, stressIndex: stress.stressIndex, strainHistory: nil)
                )
                let healthAge = HealthAgeTrendEngine().calculate(
                    from: ScoreEngineFactory.healthAge(from: context, recovery: recovery, sleepScore: sleepScore, strain: strain)
                )
                let dashboard = DashboardSummary(
                    date: context.date,
                    sleepSummary: context.sleepSummary ?? SleepSummary(date: context.date, totalSleepMinutes: 0, bedtime: nil, wakeTime: nil, stageMinutes: [:], segments: [], sleepScore: nil),
                    sleepScore: sleepScore,
                    recovery: recovery,
                    recoveryMetrics: context.recoveryMetrics,
                    recoveryBaseline: context.recoveryBaseline,
                    strain: strain,
                    stress: stress,
                    energy: energy,
                    healthAge: healthAge,
                    bodyMetrics: context.bodyMetrics,
                    extendedMetrics: context.extendedMetrics,
                    workouts: context.strainToday.workouts,
                    dailyInsight: "",
                    source: .healthKit
                )

                if config.autoEveningWikiSync, hour >= 0, hour < 4 {
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
