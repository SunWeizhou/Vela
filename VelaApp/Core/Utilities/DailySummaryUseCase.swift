import Foundation
import SwiftData

enum ActiveStatusSettings {
    static let statusKey = "vela_active_status"
    static let durationKey = "vela_active_status_duration"
    static let expiresAtKey = "vela_active_status_expires_at"
    private static let validStatuses: Set<String> = ["active", "sick", "injured", "resting"]

    static func update(
        status: String,
        duration: String,
        now: Date = Date(),
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current
    ) {
        defaults.set(status, forKey: statusKey)
        guard status != "active" else {
            defaults.removeObject(forKey: durationKey)
            defaults.removeObject(forKey: expiresAtKey)
            return
        }
        defaults.set(duration, forKey: durationKey)
        if let expiresAt = expirationDate(for: duration, now: now, calendar: calendar) {
            defaults.set(expiresAt, forKey: expiresAtKey)
        } else {
            defaults.removeObject(forKey: expiresAtKey)
        }
    }

    static func resolveCurrentStatus(
        now: Date = Date(),
        defaults: UserDefaults = .standard
    ) -> String {
        guard defaults.object(forKey: statusKey) != nil else {
            return "active"
        }

        let storedStatus = defaults.string(forKey: statusKey) ?? "active"
        guard validStatuses.contains(storedStatus) else {
            defaults.set("active", forKey: statusKey)
            defaults.removeObject(forKey: expiresAtKey)
            return "active"
        }

        if let expiresAt = defaults.object(forKey: expiresAtKey) as? Date,
           expiresAt <= now {
            defaults.set("active", forKey: statusKey)
            defaults.removeObject(forKey: expiresAtKey)
            return "active"
        }
        return storedStatus
    }

    static func journalFlags(now: Date = Date(), defaults: UserDefaults = .standard) -> Set<String> {
        let status = resolveCurrentStatus(now: now, defaults: defaults)
        guard ["sick", "injured", "resting"].contains(status) else { return [] }
        return [status]
    }

    private static func expirationDate(for duration: String, now: Date, calendar: Calendar) -> Date? {
        if duration == "长期" {
            return nil
        }
        if duration == "明天之前" {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        guard let days = Int(duration.replacingOccurrences(of: "天", with: "")) else {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        }
        return calendar.date(byAdding: .day, value: days, to: now)
    }
}

@MainActor
final class DailySummaryUseCase {
    private let refreshService: HealthDataRefreshService
    private let queryService: HealthKitQueryService
    private let calendar: Calendar
    private let syncCoordinator: AppSyncCoordinator?

    init(
        refreshService: HealthDataRefreshService? = nil,
        queryService: HealthKitQueryService = HealthKitQueryService(),
        calendar: Calendar = .current,
        syncCoordinator: AppSyncCoordinator? = nil
    ) {
        self.queryService = queryService
        self.refreshService = refreshService ?? HealthDataRefreshService(queryService: queryService)
        self.calendar = calendar
        self.syncCoordinator = syncCoordinator
    }

    static func isDemoDataSeedingEnabled(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        arguments.contains("-velaSeedDemoData")
    }

    func loadDashboard(
        for date: Date = Date(),
        modelContext: ModelContext? = nil,
        syncDays: Int = 3,
        shouldSyncHealthData: Bool = true
    ) async throws -> DashboardSummary {
        let now = date
        
        // 1. Do not fan out HealthKit reads before the user has seen the initial
        // authorization request. This keeps an empty first launch responsive.
        let shouldDeferHealthSync = await HealthAuthorizationService().shouldDeferBackgroundSync()
        if shouldSyncHealthData, let modelContext, !shouldDeferHealthSync {
            let syncEngine = HealthKitSyncEngine(queryService: queryService, modelContext: modelContext, calendar: calendar)
            if let syncCoordinator {
                await syncCoordinator.run(source: .healthKit, force: false) {
                    do {
                        try await syncEngine.syncPastDays(syncDays, endingAt: now, forceRefreshRecentDays: syncDays)
                    } catch {
                        PipelineDiagnosticsLogger.log(
                            modelContext: modelContext,
                            stage: "DailySummaryUseCase.loadDashboard.syncPastDays",
                            isSuccess: false,
                            summary: "HealthKit background sync failed.",
                            error: error
                        )
                    }
                }
            } else {
                do {
                    try await syncEngine.syncPastDays(syncDays, endingAt: now, forceRefreshRecentDays: syncDays)
                } catch {
                    PipelineDiagnosticsLogger.log(
                        modelContext: modelContext,
                        stage: "DailySummaryUseCase.loadDashboard.syncPastDays",
                        isSuccess: false,
                        summary: "HealthKit background sync failed.",
                        error: error
                    )
                }
            }
        }
        
        // 2. Query today's snapshot and 42-day history from SwiftData
        let snapshots42: [DailyHealthSnapshot]
        if let modelContext {
            let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            do {
                snapshots42 = try snapshotRepo.fetchSnapshots(days: 42, endingAt: now)
            } catch {
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "DailySummaryUseCase.loadDashboard.fetchSnapshots",
                    isSuccess: false,
                    summary: "Failed to fetch 42-day snapshot history.",
                    error: error
                )
                snapshots42 = []
            }
        } else {
            snapshots42 = []
        }
        
        // 3. Locate today's snapshot
        let todaySnapshot = snapshots42.first(where: { calendar.isDate($0.date, inSameDayAs: now) })
        
        // 4. Require today's snapshot with real HealthKit-synced data. A debug
        // demo seed is opt-in through a launch argument; a normal device must
        // never receive synthetic health records simply because it is empty.
        guard let snapshot = todaySnapshot,
              (snapshot.hrvAverage != nil || snapshot.restingHeartRate != nil || snapshot.sleepHours != nil) else {
            #if DEBUG
            if Self.isDemoDataSeedingEnabled(),
               let modelContext {
                let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
                let range = DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar)
                let existing = (try? repo.fetch(in: range)) ?? []
                if existing.isEmpty {
                    seedMockDataIfNeeded(modelContext: modelContext, now: now)
                    let dayStart = calendar.startOfDay(for: now)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    if let record = (try? repo.fetch(in: DateRangeQuery(start: dayStart, end: dayEnd)))?.first {
                        return makeDashboardFromRecord(record, source: .preview)
                    }
                }
            }
            // No real data and no mock seed — return empty dashboard
            return DashboardSummary.empty(date: now)
            #else
            return DashboardSummary.empty(date: now)
            #endif
        }
        
        // 5. Build clean DailyHealthContext and historical rolling baselines from snapshots
        let baselineSnapshots = snapshots42.filter {
            !calendar.isDate($0.date, inSameDayAs: now)
        }
        let hrvHistory = baselineSnapshots.compactMap(\.hrvAverage)
        let rhrHistory = baselineSnapshots.compactMap(\.restingHeartRate)
        let respHistory = baselineSnapshots.compactMap(\.respiratoryRate)
        // Get raw workout list from HealthKit for the current day to preserve sample details
        let todayRange = DateRangeQuery.today(containing: now, calendar: calendar)
        let todayStrainSummary = try? await queryService.strainSummary(in: todayRange)
        let rawHKWorkouts = todayStrainSummary?.workouts ?? []
        let workouts: [WorkoutSummary]
        if let modelContext = modelContext {
            try? WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
                rawHKWorkouts,
                on: now,
                modelContext: modelContext,
                calendar: calendar
            )
            workouts = WorkoutAggregationService.shared.aggregateWorkouts(
                healthKitWorkouts: rawHKWorkouts,
                for: now,
                modelContext: modelContext,
                calendar: calendar
            )
        } else {
            workouts = rawHKWorkouts
        }
        let liveExtended = (try? await queryService.extendedMetrics(in: todayRange)) ?? ExtendedHealthMetrics()
        
        let resolvedSleep = try? await queryService.sleepSummary(in: DateRangeQuery.recentDays(2, endingAt: now, calendar: calendar))
        let profileWeight = UserProfileSettings.weightKilograms()
        let profileHeight = UserProfileSettings.heightCentimeters()
        UserProfileSettings.hydrateMissingValuesFromHealth(
            age: liveExtended.age,
            weightKilograms: snapshot.bodyWeight,
            heightCentimeters: liveExtended.heightCm,
            biologicalSex: liveExtended.biologicalSex
        )
        let resolvedWeight = snapshot.bodyWeight ?? profileWeight
        var extendedMetrics = liveExtended
        extendedMetrics.age = extendedMetrics.age ?? UserProfileSettings.age()
        extendedMetrics.heightCm = extendedMetrics.heightCm ?? profileHeight
        extendedMetrics.bmi = snapshot.bmi
            ?? extendedMetrics.bmi
            ?? UserProfileSettings.bodyMassIndex(
                weightKilograms: resolvedWeight,
                heightCentimeters: extendedMetrics.heightCm
            )
        extendedMetrics.oxygenSaturation = snapshot.oxygenSaturation ?? extendedMetrics.oxygenSaturation
        extendedMetrics.bodyTemperature = snapshot.wristTemperature ?? extendedMetrics.bodyTemperature
        
        let recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: snapshot.hrvAverage,
            restingHeartRate: snapshot.restingHeartRate,
            sleepHeartRate: nil,
            respiratoryRate: snapshot.respiratoryRate
        )
        
        let recoveryBaseline = RecoveryMetricSummary(
            hrvMilliseconds: hrvHistory.count >= 5 ? calculateMedian(hrvHistory) : nil,
            restingHeartRate: rhrHistory.count >= 5 ? calculateMedian(rhrHistory) : nil,
            sleepHeartRate: nil,
            respiratoryRate: respHistory.count >= 5 ? calculateMedian(respHistory) : nil
        )
        
        let context = DailyHealthContext(
            date: now,
            sleepSummary: resolvedSleep,
            recoveryMetrics: recoveryMetrics,
            recoveryBaseline: recoveryBaseline,
            strainToday: StrainActivitySummary(
                activeEnergyKilocalories: snapshot.activeCalories,
                exerciseMinutes: snapshot.activeMinutes ?? snapshot.workoutDuration,
                stepCount: snapshot.steps,
                workouts: workouts
            ),
            strainBaselineDaily: StrainActivitySummary(workouts: []),
            bodyMetrics: BodyMetricsSummary(
                vo2Max: nil,
                weightKilograms: resolvedWeight,
                bodyFatPercentage: snapshot.bodyFatPercent,
                leanBodyMassKilograms: nil
            ),
            extendedMetrics: extendedMetrics
        )
        
        // 6. Run the unified computation pipeline. HealthKitSyncEngine uses the same entry point,
        // so background sync, dashboard and AI context read identical score semantics.
        var pipelineSnapshot = snapshot
        pipelineSnapshot.workouts = workouts
        pipelineSnapshot.workoutCount = workouts.count
        pipelineSnapshot.workoutDuration = workouts.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) / 60.0 }
        pipelineSnapshot.activeMinutes = snapshot.activeMinutes ?? pipelineSnapshot.workoutDuration
        pipelineSnapshot.sleepHours = pipelineSnapshot.sleepHours ?? context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 }
        pipelineSnapshot.bedtime = pipelineSnapshot.bedtime ?? context.sleepSummary?.bedtime
        pipelineSnapshot.wakeTime = pipelineSnapshot.wakeTime ?? context.sleepSummary?.wakeTime
        pipelineSnapshot.awakeMinutes = pipelineSnapshot.awakeMinutes ?? context.sleepSummary?.stageMinutes[.awake].map { Double($0) }
        pipelineSnapshot.deepSleepMinutes = pipelineSnapshot.deepSleepMinutes ?? context.sleepSummary?.stageMinutes[.deep].map { Double($0) }
        pipelineSnapshot.remSleepMinutes = pipelineSnapshot.remSleepMinutes ?? context.sleepSummary?.stageMinutes[.rem].map { Double($0) }
        pipelineSnapshot.awakeEpisodeCount = pipelineSnapshot.awakeEpisodeCount ?? context.sleepSummary?.segments.filter { $0.stage == .awake && $0.end.timeIntervalSince($0.start) >= 120 }.count

        let historicalSnapshots = snapshots42.filter { !calendar.isDate($0.date, inSameDayAs: now) }
        let metrics = DailyHealthComputation(calendar: calendar, now: now).compute(
            for: pipelineSnapshot,
            history: historicalSnapshots
        )
        let sleepScore = metrics.sleepScore
        let resolvedSleepSummary = DashboardMetricProjection.resolvedSleepSummary(
            from: context,
            sleepScore: sleepScore.value
        )
        let recovery = metrics.recovery
        let strain = metrics.strain
        let stress = metrics.stress
        let energy = metrics.energy
        
        let healthAge = HealthAgeTrendEngine().calculate(
            from: DashboardMetricProjection.healthAge(
                from: context,
                recovery: recovery,
                sleepScore: sleepScore,
                strain: strain
            )
        )
        
        var activePlan: TrainingPlanRecord?
        var currentDailySummary: DailyHealthSummaryRecord?
        var recentWorkoutEvents: [WorkoutEventRecord] = []
        var recentStrengthWorkouts: [StrengthWorkoutRecord] = []
        var recentTrainingResponses: [TrainingResponseRecord] = []
        var todayFoodLogs: [FoodLogRecord] = []
        var recentJournalEntries: [JournalEntryRecord] = []
        if let modelContext {
            let activePlanFetch = FetchDescriptor<TrainingPlanRecord>(
                predicate: #Predicate<TrainingPlanRecord> { $0.isActive }
            )
            activePlan = (try? modelContext.fetch(activePlanFetch))?.first

            let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: now, calendar: calendar)
            let summaryFetch = FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.dayIdentifier == dayIdentifier }
            )
            currentDailySummary = (try? modelContext.fetch(summaryFetch))?.first

            let recentEventStart = calendar.date(byAdding: .hour, value: -48, to: now) ?? now
            var eventFetch = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= recentEventStart && $0.startedAt <= now },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            eventFetch.fetchLimit = 100
            recentWorkoutEvents = (try? modelContext.fetch(eventFetch)) ?? []

            let recentJournalStart = calendar.date(byAdding: .hour, value: -36, to: now) ?? now
            let journalFetch = FetchDescriptor<JournalEntryRecord>(
                predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= recentJournalStart && $0.createdAt <= now },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            recentJournalEntries = (try? modelContext.fetch(journalFetch)) ?? []

            let recentStrengthStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
            let strengthFetch = FetchDescriptor<StrengthWorkoutRecord>(
                predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= recentStrengthStart && $0.startedAt <= now },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            recentStrengthWorkouts = (try? modelContext.fetch(strengthFetch)) ?? []

            let responseStart = calendar.date(byAdding: .day, value: -28, to: now) ?? now
            let responseFetch = FetchDescriptor<TrainingResponseRecord>(
                predicate: #Predicate<TrainingResponseRecord> { $0.date >= responseStart && $0.date <= now },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            recentTrainingResponses = (try? modelContext.fetch(responseFetch)) ?? []

            let foodRange = DateRangeQuery.today(containing: now, calendar: calendar)
            let foodStart = foodRange.start
            let foodEnd = foodRange.end
            let foodFetch = FetchDescriptor<FoodLogRecord>(
                predicate: #Predicate<FoodLogRecord> { $0.createdAt >= foodStart && $0.createdAt < foodEnd },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            todayFoodLogs = (try? modelContext.fetch(foodFetch)) ?? []
        }

        var dashboard = DashboardSummary(
            date: context.date,
            sleepSummary: resolvedSleepSummary,
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
            dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
            source: .healthKit
        )
        let activeStatus = ActiveStatusSettings.resolveCurrentStatus(now: now)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            dailySummary: currentDailySummary,
            workoutEvents: recentWorkoutEvents,
            strengthWorkouts: recentStrengthWorkouts,
            trainingResponses: recentTrainingResponses,
            foodLogs: todayFoodLogs,
            journalEntries: recentJournalEntries,
            activePlan: activePlan,
            activeStatus: activeStatus,
            generatedAt: now
        ))
        
        let dayId = DailyHealthSummaryRecord.dayIdentifier(for: now, calendar: calendar)
        var matchedExistingDecision: DailyTrainingDecision? = nil
        if let modelContext {
            let opPlanDescriptor = FetchDescriptor<DailyOperatingPlanRecord>(
                predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == dayId }
            )
            if let existingPlan = (try? modelContext.fetch(opPlanDescriptor))?.first,
               existingPlan.bodyStateHash == bodyState.hash {
                matchedExistingDecision = existingPlan.trainingDecision
            }
        }
        
        let dailyTrainingDecision: DailyTrainingDecision
        if let matched = matchedExistingDecision {
            dailyTrainingDecision = matched
        } else {
            let recentStrengthSummary = TrainingAnalyticsService().buildRecentSummary(
                workouts: recentStrengthWorkouts,
                days: 28,
                endingAt: now
            )
            dailyTrainingDecision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
                bodyState: bodyState,
                activePlan: activePlan,
                recentStrengthSummary: recentStrengthSummary,
                trainingResponses: recentTrainingResponses
            ))
        }
        
        dashboard.bodyState = bodyState
        dashboard.trainingDecision = TrainingDecision.compatibilityView(
            of: dailyTrainingDecision,
            bodyState: bodyState
        )
        
        let persistedSnapshot = makeSnapshot(from: dashboard, context: context, date: now)
        if let modelContext {
            let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            do {
                try snapshotRepo.saveDailySnapshot(persistedSnapshot)
                try WorkoutAggregationService.shared.aggregateDay(
                    date: now,
                    modelContext: modelContext,
                    calendar: calendar
                )
                try modelContext.save()
                
                // Only upsert plan if it was recalculated
                if matchedExistingDecision == nil {
                    try DailyOperatingPlanCoordinator.upsert(
                        bodyState: bodyState,
                        decision: dailyTrainingDecision,
                        modelContext: modelContext,
                        calendar: calendar
                    )
                }
            } catch {
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "DailySummaryUseCase.loadDashboard.saveDailySnapshot",
                    isSuccess: false,
                    summary: "Failed to save daily snapshot to repository.",
                    error: error
                )
            }
            await refreshPersonalBaselinesIfNeeded(modelContext: modelContext)
            do {
                try snapshotRepo.pruneOldSnapshots(keepingDays: 90)
            } catch {
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "DailySummaryUseCase.loadDashboard.pruneOldSnapshots",
                    isSuccess: false,
                    summary: "Failed to prune old snapshots.",
                    error: error
                )
            }
            await checkAndAlertAbnormalMetrics(snapshot: persistedSnapshot, modelContext: modelContext)
        }
        return dashboard
    }

    private func calculateMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        } else {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        }
    }



    private func computeSleepTimingBaseline(modelContext: ModelContext, now: Date) async -> (bedtimeOffset: Double?, wakeOffset: Double?)? {
        let thirtyDays = DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar)

        // Query raw sleep data for baseline timing
        guard let currentSleep = try? await queryService.sleepSummary(in: DateRangeQuery.recentDays(2, endingAt: now, calendar: calendar)),
              let todayBedtime = currentSleep.bedtime,
              let todayWaketime = currentSleep.wakeTime else { return nil }

        let episodes = (try? await queryService.sleepEpisodes(in: thirtyDays)) ?? []
        let pastEpisodes = episodes.filter { !calendar.isDate($0.date, inSameDayAs: now) }

        guard !pastEpisodes.isEmpty else { return nil }

        let bedtimes: [Date] = pastEpisodes.compactMap(\.bedtime)
        let bedtimeComponents = bedtimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
        
        // Map bedtime seconds to be relative to 12:00 PM (noon). If bedtime is before 12:00 PM (e.g. 00:30), add 86400 to map it smoothly across midnight.
        let bedtimeSeconds = bedtimeComponents.map { comps -> Double in
            let secs = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
            return secs < 43200.0 ? secs + 86400.0 : secs
        }
        let avgBedtimeSeconds = bedtimeSeconds.isEmpty ? nil : bedtimeSeconds.reduce(0, +) / Double(bedtimeSeconds.count)

        let waketimes: [Date] = pastEpisodes.compactMap(\.wakeTime)
        let waketimeComponents = waketimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let waketimeSeconds = waketimeComponents.map { Double(($0.hour ?? 0) * 3600 + ($0.minute ?? 0) * 60) }
        let avgWaketimeSeconds = waketimeSeconds.isEmpty ? nil : Double(waketimeSeconds.reduce(0, +)) / Double(waketimeSeconds.count)

        guard let avgBedtimeSeconds, let avgWaketimeSeconds else { return nil }

        let todayBedtimeComps = calendar.dateComponents([.hour, .minute], from: todayBedtime)
        var todayBedtimeSeconds = Double((todayBedtimeComps.hour ?? 0) * 3600 + (todayBedtimeComps.minute ?? 0) * 60)
        if todayBedtimeSeconds < 43200.0 {
            todayBedtimeSeconds += 86400.0
        }

        let todayWaketimeComps = calendar.dateComponents([.hour, .minute], from: todayWaketime)
        let todayWaketimeSeconds = Double((todayWaketimeComps.hour ?? 0) * 3600 + (todayWaketimeComps.minute ?? 0) * 60)

        let bedtimeOffset = (todayBedtimeSeconds - avgBedtimeSeconds) / 60.0
        let wakeOffset = (todayWaketimeSeconds - avgWaketimeSeconds) / 60.0

        return (bedtimeOffset, wakeOffset)
    }

    private func refreshPersonalBaselinesIfNeeded(modelContext: ModelContext) async {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        let snapshots = (try? snapshotRepo.fetchSnapshots(days: 30)) ?? []
        guard snapshots.count >= 7 else { return }

        let baselines = PersonalBaselineEngine.computeBaselines(from: snapshots)
        let hasPublishedBaseline = [
            baselines.hrvBaselineMean,
            baselines.rhrBaselineMean,
            baselines.sleepHoursBaseline,
            baselines.strainBaselineMean
        ].contains { $0 != nil }
        guard hasPublishedBaseline else { return }
        PersonalBaselineEngine.saveBaselinesToWiki(baselines)
        WikiSyncManager.sync(modelContext: modelContext)
    }

    private func checkAndAlertAbnormalMetrics(snapshot: DailyHealthSnapshot, modelContext: ModelContext) async {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        let recentSnapshots = (try? snapshotRepo.fetchSnapshots(days: 28)) ?? []
        let baselines = recentSnapshots.count >= 7
            ? PersonalBaselineEngine.computeBaselines(from: recentSnapshots)
            : nil

        // Check yesterday's sleep score for consecutive low sleep detection
        let yesterday = calendar.date(byAdding: .day, value: -1, to: snapshot.date) ?? snapshot.date
        let yesterdaySnapshot = (try? snapshotRepo.fetchSnapshots(days: 7, endingAt: snapshot.date))
            .flatMap { $0.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) }) }

        let notificationService = NotificationService.shared

        // Handle consecutive low sleep check
        if notificationService.checkConsecutiveLowSleep(
            currentSleepScore: snapshot.sleepScore,
            yesterdaySleepScore: yesterdaySnapshot?.sleepScore
        ) {
            notificationService.sendNotification(
                title: "Sleep Alert",
                body: "Your sleep score has been below 50 for 2+ consecutive days. Consider prioritizing rest tonight.",
                category: .abnormalMetric
            )
        }

        notificationService.checkAndAlertAbnormalMetrics(snapshot: snapshot, baselines: baselines)
    }

    func makeSnapshot(
        from dashboard: DashboardSummary,
        context: DailyHealthContext,
        date: Date
    ) -> DailyHealthSnapshot {
        let sleepMetrics = dashboard.sleepScore.metrics
        let strainMetrics = dashboard.strain.metrics

        return DailyHealthSnapshot(
            date: date,
            sleepScore: dashboard.sleepScore.hasData ? dashboard.sleepScore.value : nil,
            recoveryScore: dashboard.recovery.hasData ? dashboard.recovery.value : nil,
            strainScore: dashboard.strain.hasData ? dashboard.strain.value : nil,
            stressIndex: dashboard.stress.hasData ? dashboard.stress.value : nil,
            morningEnergy: dashboard.energy.hasData ? dashboard.energy.morningEnergy : nil,
            currentEnergy: dashboard.energy.hasData ? dashboard.energy.value : nil,
            energyBank: nil,
            healthAge: dashboard.healthAge.trendScore,
            hrvAverage: dashboard.recoveryMetrics.hrvMilliseconds,
            restingHeartRate: dashboard.recoveryMetrics.restingHeartRate,
            sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
            deepSleepPercent: sleepMetrics["deep_pct"].map { HealthUnitNormalizer.normalizeSleepStagePercent($0 / 100.0) },
            remSleepPercent: sleepMetrics["rem_pct"].map { HealthUnitNormalizer.normalizeSleepStagePercent($0 / 100.0) },
            sleepEfficiency: sleepMetrics["sleep_efficiency"].map { HealthUnitNormalizer.normalizeSleepEfficiency($0 / 100.0) },
            steps: strainMetrics["steps_raw"],
            activeCalories: strainMetrics["active_energy_raw"],
            activeMinutes: strainMetrics["exercise_minutes_raw"],
            workoutCount: dashboard.workouts.isEmpty ? nil : dashboard.workouts.count,
            workoutTypes: dashboard.workouts.isEmpty ? nil : Set(dashboard.workouts.map(\.activityName)).sorted().joined(separator: ", "),
            workoutDuration: dashboard.workouts.isEmpty ? nil : dashboard.workouts.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 60.0,
            bodyWeight: context.bodyMetrics.weightKilograms,
            bodyFatPercent: context.bodyMetrics.bodyFatPercentage.map { HealthUnitNormalizer.normalizeBodyFatPercentage($0) },
            bmi: context.extendedMetrics.bmi,
            oxygenSaturation: context.extendedMetrics.oxygenSaturation.map { HealthUnitNormalizer.normalizeOxygenSaturation($0) },
            respiratoryRate: dashboard.recoveryMetrics.respiratoryRate,
            wristTemperature: context.extendedMetrics.bodyTemperature,
            dailyLoad: strainMetrics["daily_load"],
            workoutLoad: strainMetrics["workout_load"],
            activityLoad: strainMetrics["activity_load"],
            trainingLoadRatio: strainMetrics["training_load_ratio"],
            atl: dashboard.energy.metrics["atl"],
            ctl: dashboard.energy.metrics["ctl"],
            tsb: dashboard.energy.metrics["tsb"],
            acwr: dashboard.energy.metrics["acwr"],
            awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
            awakeEpisodeCount: context.sleepSummary?.segments.filter { $0.stage == .awake && $0.end.timeIntervalSince($0.start) >= 120 }.count,
            deepSleepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
            remSleepMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
            workouts: context.strainToday.workouts
        )
    }

    private func dailyInsight(
        recovery: MetricResult,
        sleepScore: MetricResult,
        strain: MetricResult,
        source: DashboardSummary.DataSource
    ) -> String {
        if source == .healthKit {
            return L10n.t(
                "Updated from Apple Health. Recovery \(Int(recovery.score.rounded())), sleep \(Int(sleepScore.score.rounded())), strain \(Int(strain.score.rounded())).",
                "已读取 Apple 健康数据。恢复 \(Int(recovery.score.rounded()))，睡眠 \(Int(sleepScore.score.rounded()))，负荷 \(Int(strain.score.rounded()))。"
            )
        }
        return L10n.t(
            "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
            "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
        )
    }

#if DEBUG
    private func seedMockDataIfNeeded(modelContext: ModelContext, now: Date) {
        let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        
        // Check if there are already records in the last 30 days
        let range = DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar)
        let existing = (try? repo.fetch(in: range)) ?? []
        
        // If there are already records, don't overwrite them
        guard existing.isEmpty else { return }
        
        // Seed 30 days of high-fidelity data
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            
            // Generate realistic variations based on day offset
            let seed = Double(offset)
            let recoveryScore = 55 + sin(seed * 0.8) * 20 + Double((offset * 7) % 8)
            let sleepScore = 65 + cos(seed * 0.6) * 15 + Double((offset * 3) % 10)
            let strainScore = 8 + abs(sin(seed * 1.2)) * 10 + Double((offset * 2) % 4)
            let stressIndex = 25 + cos(seed * 0.9) * 12 + Double((offset * 5) % 15)
            let steps = 4000 + abs(sin(seed * 0.5)) * 8000 + Double((offset * 500) % 3000)
            let activeCalories = 150 + abs(sin(seed * 0.5)) * 400 + Double((offset * 50) % 200)
            let rhr = 58 + cos(seed * 0.7) * 6 + Double((offset * 2) % 4)
            let hrv = 45 + sin(seed * 0.7) * 15 + Double((offset * 3) % 8)
            
            let snapshot = DailyHealthSnapshot(
                date: day,
                sleepScore: sleepScore,
                recoveryScore: recoveryScore,
                strainScore: strainScore,
                stressIndex: stressIndex,
                morningEnergy: 50 + sin(seed * 0.5) * 20,
                currentEnergy: max(10, min(100, 50 + sin(seed * 0.5) * 20 - strainScore * 2)),
                energyBank: 40 + cos(seed * 0.4) * 25,
                healthAge: 26.5,
                hrvAverage: hrv,
                restingHeartRate: rhr,
                sleepHours: 6.5 + cos(seed * 0.6) * 1.5,
                deepSleepPercent: 0.18 + sin(seed * 0.3) * 0.05,
                remSleepPercent: 0.22 + cos(seed * 0.3) * 0.04,
                sleepEfficiency: 0.88 + sin(seed * 0.2) * 0.05,
                steps: steps,
                activeCalories: activeCalories,
                activeMinutes: 20 + abs(sin(seed * 0.5)) * 45,
                workoutCount: offset % 3 == 0 ? 1 : 0,
                workoutTypes: offset % 3 == 0 ? "跑步" : nil,
                workoutDuration: offset % 3 == 0 ? 35.0 : 0.0,
                bodyWeight: 72.0,
                bodyFatPercent: 17.5,
                bmi: 22.8,
                oxygenSaturation: 0.98,
                respiratoryRate: 14.5,
                wristTemperature: 36.6
            )
            
            let record = DailyHealthSummaryRecord(snapshot: snapshot, calendar: calendar)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }
#endif

    func loadCachedDashboard(
        for date: Date = Date(),
        modelContext: ModelContext
    ) throws -> DashboardSummary? {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let records = try SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
            .fetch(in: DateRangeQuery(start: dayStart, end: dayEnd))
        guard let record = records.last else { return nil }
        return makeDashboardFromRecord(record)
    }

    func makeDashboardFromRecord(
        _ record: DailyHealthSummaryRecord,
        source: DashboardSummary.DataSource = .cache
    ) -> DashboardSummary {
        let totalSleepMinutes = max(Int((record.sleepHours ?? 0) * 60), 0)
        let deepMinutes = Int(record.deepSleepMinutes ?? percentMinutes(record.deepSleepPercent, total: totalSleepMinutes))
        let remMinutes = Int(record.remSleepMinutes ?? percentMinutes(record.remSleepPercent, total: totalSleepMinutes))
        let awakeMinutes = Int(record.awakeMinutes ?? 0)
        let coreMinutes = max(totalSleepMinutes - deepMinutes - remMinutes, 0)
        let sleepSummary = SleepSummary(
            date: record.date,
            totalSleepMinutes: totalSleepMinutes,
            bedtime: record.bedtime,
            wakeTime: record.wakeTime,
            stageMinutes: compactStageMinutes([
                .deep: deepMinutes,
                .rem: remMinutes,
                .core: coreMinutes,
                .awake: awakeMinutes
            ]),
            segments: [],
            sleepScore: record.sleepScore
        )

        let sleep = cachedMetric(
            name: "Sleep Score",
            value: record.sleepScore,
            components: compactComponents([
                "duration_minutes": Double(totalSleepMinutes),
                "sleep_efficiency": percentValue(record.sleepEfficiency),
                "deep_pct": percentValue(record.deepSleepPercent),
                "rem_pct": percentValue(record.remSleepPercent),
                "awake_minutes": record.awakeMinutes,
                "awake_episode_count": record.awakeEpisodeCount.map(Double.init)
            ]),
            updatedAt: record.updatedAt
        )
        let recovery = cachedMetric(
            name: "Recovery Score",
            value: record.recoveryScore,
            components: compactComponents([
                "hrv_ms": record.hrvAverage,
                "rhr_bpm": record.restingHeartRate,
                "respiratory_rate": record.respiratoryRate,
                "spo2": percentValue(record.oxygenSaturation)
            ]),
            updatedAt: record.updatedAt
        )
        let targetRange = recommendedStrainRange(for: record.recoveryScore)
        let strain = cachedMetric(
            name: "Strain Score",
            value: record.strainScore,
            components: compactComponents([
                "daily_load": record.dailyLoad,
                "workout_load": record.workoutLoad,
                "activity_load": record.activityLoad,
                "training_load_ratio": record.trainingLoadRatio,
                "steps_raw": record.steps,
                "active_energy_raw": record.activeCalories,
                "exercise_minutes_raw": record.activeMinutes ?? record.workoutDuration,
                "recommended_lower": Double(targetRange.lowerBound),
                "recommended_upper": Double(targetRange.upperBound)
            ]),
            updatedAt: record.updatedAt
        )
        let stress = cachedMetric(
            name: "Physiological Stress Index",
            value: record.stressIndex,
            components: compactComponents(["stress_index": record.stressIndex]),
            updatedAt: record.updatedAt
        )
        let energy = cachedMetric(
            name: "Energy Bank",
            value: record.currentEnergy ?? record.energyBank,
            components: compactComponents([
                "morningEnergy": record.morningEnergy,
                "currentEnergy": record.currentEnergy ?? record.energyBank,
                "atl": record.atl,
                "ctl": record.ctl,
                "tsb": record.tsb,
                "acwr": record.acwr
            ]),
            updatedAt: record.updatedAt
        )
        let snapshot = record.toSnapshot()

        return DashboardSummary(
            date: record.date,
            sleepSummary: sleepSummary,
            sleepScore: sleep,
            recovery: recovery,
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: record.hrvAverage,
                restingHeartRate: record.restingHeartRate,
                sleepHeartRate: nil,
                respiratoryRate: record.respiratoryRate
            ),
            recoveryBaseline: RecoveryMetricSummary(),
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: cachedHealthAgeTrend(record.healthAge),
            bodyMetrics: BodyMetricsSummary(
                vo2Max: nil,
                weightKilograms: record.bodyWeight,
                bodyFatPercentage: record.bodyFatPercent,
                leanBodyMassKilograms: nil
            ),
            extendedMetrics: ExtendedHealthMetrics(
                bmi: record.bmi,
                oxygenSaturation: record.oxygenSaturation,
                bodyTemperature: record.wristTemperature
            ),
            workouts: snapshot.workouts,
            dailyInsight: L10n.t(
                "Showing your latest saved Apple Health snapshot while Vela checks for updates.",
                "正在显示最近一次 Apple 健康快照，Vela 会在后台检查更新。"
            ),
            source: source
        )
    }

    private func cachedMetric(
        name: String,
        value: Double?,
        components: [String: Double],
        updatedAt: Date
    ) -> MetricResult {
        var resolvedComponents = components
        if let value {
            resolvedComponents["cached_score"] = value
        }
        return MetricResult(
            name: name,
            value: value,
            band: value.map(ScoringMath.band(for:)) ?? .low,
            confidence: value == nil ? .low : .medium,
            components: resolvedComponents,
            componentWeights: [:],
            reasons: [L10n.t("Loaded from the latest saved Apple Health snapshot.", "已读取最近一次保存的 Apple 健康快照。")],
            missingInputs: value == nil ? ["cachedValue"] : [],
            dataWindow: DateInterval(start: calendar.startOfDay(for: updatedAt), end: updatedAt),
            source: .derived,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: updatedAt
        )
    }

    private func compactComponents(_ values: [String: Double?]) -> [String: Double] {
        values.reduce(into: [:]) { result, pair in
            if let value = pair.value {
                result[pair.key] = value
            }
        }
    }

    private func compactStageMinutes(_ values: [SleepStage: Int]) -> [SleepStage: Int] {
        values.filter { $0.value > 0 }
    }

    private func percentMinutes(_ value: Double?, total: Int) -> Double {
        guard let value else { return 0 }
        return (value <= 1 ? value : value / 100) * Double(total)
    }

    private func percentValue(_ value: Double?) -> Double? {
        guard let value else { return nil }
        return value <= 1 ? value * 100 : value
    }

    private func recommendedStrainRange(for recoveryScore: Double?) -> ClosedRange<Int> {
        guard let recoveryScore else { return 40...70 }
        if recoveryScore < 40 { return 15...40 }
        if recoveryScore < 70 { return 35...65 }
        return 55...85
    }

    private func cachedHealthAgeTrend(_ score: Double?) -> HealthAgeTrendResult {
        guard let score else {
            return HealthAgeTrendEngine().calculate(from: HealthAgeTrendInput(factors: []))
        }
        let label: HealthAgeTrendLabel
        if score >= 0.35 {
            label = .improving
        } else if score <= -0.35 {
            label = .worsening
        } else {
            label = .stable
        }
        return HealthAgeTrendResult(
            trendScore: score,
            label: label,
            confidence: .medium,
            positiveFactors: [],
            negativeFactors: [],
            reasons: [L10n.t("Loaded from the latest saved trend snapshot.", "已读取最近一次保存的趋势快照。")],
            metrics: ["trend_score": score]
        )
    }

}

@MainActor
final class DailyPlanRefreshCoordinator {
    static let shared = DailyPlanRefreshCoordinator()

    private init() {}

    func refreshPlan(for date: Date = Date(), modelContext: ModelContext) async {
        let useCase = DailySummaryUseCase()
        _ = try? await useCase.loadDashboard(
            for: date,
            modelContext: modelContext,
            shouldSyncHealthData: false
        )
        VelaAppState.shared.markLocalDataChanged()
    }
}
