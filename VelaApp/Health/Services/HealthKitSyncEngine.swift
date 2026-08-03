import Foundation
import SwiftData

struct HealthSyncCursorState: Codable, Equatable {
    var lastSuccessfulSyncAt: Date?
    var pendingDirtyDayIdentifiers: Set<String> = []
}

struct HealthSyncPlan: Equatable {
    var rawRefreshDays: [Date]
    var scoreRecomputeDays: [Date]
}

struct HealthSyncPlanner {
    static func plan(
        requestedDays: Int,
        endingAt endDate: Date,
        cachedDays: Set<Date>,
        state: HealthSyncCursorState,
        forceRefreshRecentDays: Int,
        calendar: Calendar
    ) -> HealthSyncPlan {
        let endDay = calendar.startOfDay(for: endDate)
        let totalDays = max(requestedDays, 1) + 42
        let allDays = (0..<totalDays).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: endDay).map(calendar.startOfDay(for:))
        }
        let recentCutoff = calendar.date(
            byAdding: .day,
            value: -max(0, forceRefreshRecentDays - 1),
            to: endDay
        ) ?? endDay
        let cursorDay = state.lastSuccessfulSyncAt.map(calendar.startOfDay(for:))

        let rawDays = allDays.filter { day in
            let identifier = DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar)
            return !cachedDays.contains(day)
                || day >= recentCutoff
                || state.pendingDirtyDayIdentifiers.contains(identifier)
                || cursorDay.map { day >= $0 } == true
        }
        .sorted()

        let targetStart = calendar.date(
            byAdding: .day,
            value: -max(0, requestedDays - 1),
            to: endDay
        ) ?? endDay
        let scoreDays: [Date]
        if state.lastSuccessfulSyncAt == nil {
            scoreDays = allDays.filter { $0 >= targetStart }.sorted()
        } else if let earliestChanged = rawDays.first {
            scoreDays = allDays.filter { $0 >= min(earliestChanged, targetStart) }.sorted()
        } else {
            scoreDays = []
        }

        return HealthSyncPlan(rawRefreshDays: rawDays, scoreRecomputeDays: scoreDays)
    }
}

final class HealthSyncCursorStore {
    private let defaults: UserDefaults
    private let key = "vela.healthSync.cursor.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HealthSyncCursorState {
        guard let data = defaults.data(forKey: key),
              let state = try? JSONDecoder().decode(HealthSyncCursorState.self, from: data) else {
            return HealthSyncCursorState()
        }
        return state
    }

    func save(_ state: HealthSyncCursorState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func markDirty(_ date: Date, calendar: Calendar = .current) {
        var state = load()
        state.pendingDirtyDayIdentifiers.insert(
            DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar)
        )
        save(state)
    }
}

@MainActor
final class HealthKitSyncEngine {
    private let queryService: HealthQueryService
    private let modelContext: ModelContext
    private let calendar: Calendar
    private let cursorStore: HealthSyncCursorStore

    init(
        queryService: HealthQueryService,
        modelContext: ModelContext,
        calendar: Calendar = .current,
        cursorStore: HealthSyncCursorStore = HealthSyncCursorStore()
    ) {
        self.queryService = queryService
        self.modelContext = modelContext
        self.calendar = calendar
        self.cursorStore = cursorStore
    }

    func markDirty(_ date: Date) {
        cursorStore.markDirty(date, calendar: calendar)
    }

    /// Backfills and calculates metrics for the past N calendar days.
    /// This runs a two-pass synchronization to prevent empty baseline bootstrapping.
    func syncPastDays(
        _ days: Int,
        endingAt endDate: Date = Date(),
        forceRefreshRecentDays: Int? = nil
    ) async throws {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        if let healthKitQueryService = queryService as? HealthKitQueryService {
            let characteristics = healthKitQueryService.queryCharacteristics()
            UserProfileSettings.hydrateMissingValuesFromHealth(
                age: characteristics.age,
                weightKilograms: nil,
                heightCentimeters: nil,
                biologicalSex: characteristics.biologicalSex
            )
        }

        // Pass 1: Build and save the raw daily snapshots from HealthKit for the last (42 + days)
        // This ensures the database already has raw data for rolling baseline calculations in Pass 2!
        let totalDaysToSync = 42 + days
        let cachedSnapshots = (try? snapshotRepo.fetchSnapshots(days: totalDaysToSync, endingAt: endDate)) ?? []
        let cachedDays = Set(cachedSnapshots.map { calendar.startOfDay(for: $0.date) })
        let refreshWindow = forceRefreshRecentDays ?? min(days, 3)
        let cursorState = cursorStore.load()
        let plan = HealthSyncPlanner.plan(
            requestedDays: days,
            endingAt: endDate,
            cachedDays: cachedDays,
            state: cursorState,
            forceRefreshRecentDays: refreshWindow,
            calendar: calendar
        )
        var failedDayIdentifiers = Set<String>()

        for dayStart in plan.rawRefreshDays {
            // Build raw daily snapshot from HealthKit and local workouts
            let snapshot = await DailySnapshotBuilder.buildSnapshot(
                for: dayStart,
                queryService: queryService,
                calendar: calendar,
                modelContext: modelContext
            )
            
            // Save the raw snapshot
            do {
                try snapshotRepo.saveDailySnapshot(snapshot)
                try WorkoutAggregationService.shared.aggregateDay(
                    date: dayStart,
                    modelContext: modelContext,
                    calendar: calendar
                )
                try modelContext.save()
            } catch {
                failedDayIdentifiers.insert(
                    DailyHealthSummaryRecord.dayIdentifier(for: dayStart, calendar: calendar)
                )
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "HealthKitSyncEngine.syncPastDays.saveRawSnapshot",
                    isSuccess: false,
                    summary: "Failed to save raw daily snapshot for \(dayStart).",
                    error: error
                )
            }
        }

        // Pass 2: Calculate scores day-by-day, pulling correct rolling raw baselines
        for dayStart in plan.scoreRecomputeDays {
            // Load this day's snapshot from SwiftData
            let existingSnapshots: [DailyHealthSnapshot]
            do {
                existingSnapshots = try snapshotRepo.fetchSnapshots(days: 1, endingAt: dayStart)
            } catch {
                failedDayIdentifiers.insert(
                    DailyHealthSummaryRecord.dayIdentifier(for: dayStart, calendar: calendar)
                )
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "HealthKitSyncEngine.syncPastDays.fetchExistingSnapshot",
                    isSuccess: false,
                    summary: "Failed to fetch existing snapshot for \(dayStart).",
                    error: error
                )
                existingSnapshots = []
            }
            guard var snapshot = existingSnapshots.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) else { continue }
            
            // Fetch past 42 days of historical snapshots (which already have raw data from Pass 1!)
            let pastSnapshots: [DailyHealthSnapshot]
            do {
                pastSnapshots = try snapshotRepo.fetchSnapshots(days: 42, endingAt: dayStart)
            } catch {
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "HealthKitSyncEngine.syncPastDays.fetchHistory",
                    isSuccess: false,
                    summary: "Failed to fetch historical snapshots for \(dayStart).",
                    error: error
                )
                pastSnapshots = []
            }
            let historicalSnapshots = pastSnapshots.filter { !calendar.isDate($0.date, inSameDayAs: dayStart) }
            
            // Run computation pipeline
            let pipeline = DailyHealthComputation(calendar: calendar, now: endDate)
            let metrics = pipeline.compute(
                for: snapshot,
                history: historicalSnapshots
            )

            snapshot = metrics.applying(to: snapshot)

            do {
                try snapshotRepo.saveDailySnapshot(
                    snapshot,
                    scoreEvidence: DailyScoreEvidenceEnvelope(
                        evidence: metrics,
                        persistedAt: endDate
                    )
                )
                try WorkoutAggregationService.shared.aggregateDay(
                    date: dayStart,
                    modelContext: modelContext,
                    calendar: calendar
                )
                try modelContext.save()
            } catch {
                // A failed score save must be retried. Mark the day dirty so the
                // cursor reconciliation below keeps it in pendingDirtyDayIdentifiers
                // instead of silently dropping it (which previously left the user
                // stuck on a stale/empty score for that day forever).
                failedDayIdentifiers.insert(
                    DailyHealthSummaryRecord.dayIdentifier(for: dayStart, calendar: calendar)
                )
                PipelineDiagnosticsLogger.log(
                    modelContext: modelContext,
                    stage: "HealthKitSyncEngine.syncPastDays.saveComputedSnapshot",
                    isSuccess: false,
                    summary: "Failed to save computed daily snapshot for \(dayStart).",
                    error: error
                )
            }
        }
        
        // Log a successful sync run
        PipelineDiagnosticsLogger.log(
            modelContext: modelContext,
            stage: "HealthKitSyncEngine.syncPastDays.completed",
            isSuccess: true,
            summary: "Successfully synced and computed metrics for past \(days) days."
        )
        var completedState = cursorState
        completedState.lastSuccessfulSyncAt = endDate
        let processedIdentifiers = Set(plan.rawRefreshDays.map {
            DailyHealthSummaryRecord.dayIdentifier(for: $0, calendar: calendar)
        })
        completedState.pendingDirtyDayIdentifiers.subtract(
            processedIdentifiers.subtracting(failedDayIdentifiers)
        )
        completedState.pendingDirtyDayIdentifiers.formUnion(failedDayIdentifiers)
        cursorStore.save(completedState)
        try? syncTrainingIntelligenceInsights(endingAt: endDate)

        // DailySummaryUseCase owns plan derivation after this method returns.
        // Calling DailyPlanRefreshCoordinator here would re-enter health sync and
        // create a sync -> plan -> sync feedback loop with continuous database writes.
    }

    private func syncTrainingIntelligenceInsights(endingAt endDate: Date) throws {
        let snapshots = try HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            .fetchSnapshots(days: 60, endingAt: endDate)
        let strengthWorkouts = try modelContext.fetch(FetchDescriptor<StrengthWorkoutRecord>())
        let foodLogs = try modelContext.fetch(FetchDescriptor<FoodLogRecord>())
        let journalEntries = try modelContext.fetch(FetchDescriptor<JournalEntryRecord>())
        let service = TrainingResponseInsightService()
        _ = try service.captureTrainingResponses(
            modelContext: modelContext,
            snapshots: snapshots,
            workouts: strengthWorkouts,
            calendar: calendar
        )
        let responses = try modelContext.fetch(FetchDescriptor<TrainingResponseRecord>())
        _ = try service.persistWeeklyBodyReportIfNeeded(
            modelContext: modelContext,
            snapshots: snapshots,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: responses,
            endingAt: endDate,
            calendar: calendar
        )
        _ = try service.persistMonthlyBodyReportIfNeeded(
            modelContext: modelContext,
            snapshots: snapshots,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            strengthWorkouts: strengthWorkouts,
            endingAt: endDate,
            calendar: calendar
        )
        _ = try service.proposeStableTrainingResponses(
            modelContext: modelContext,
            responses: responses
        )
    }
}

final class DailySnapshotBuilder {
    @MainActor
    static func buildSnapshot(
        for date: Date,
        queryService: HealthQueryService,
        calendar: Calendar,
        modelContext: ModelContext? = nil
    ) async -> DailyHealthSnapshot {
        let dayStart = calendar.startOfDay(for: date)
        let range = DateRangeQuery.singleDay(dayStart, calendar: calendar)

        // Query components independently with fail-safes
        let sleep = try? await queryService.sleepSummary(in: range)
        let recovery = try? await queryService.recoveryMetrics(in: range)
        let strain = try? await queryService.strainSummary(in: range)
        let body = try? await queryService.bodyMetrics(in: range)
        
        let hkQueryService = queryService as? HealthKitQueryService
        let extended = (try? await hkQueryService?.extendedMetrics(in: range)) ?? ExtendedHealthMetrics()

        var snapshot = DailyHealthSnapshot(date: dayStart)
        
        // Populate sleep
        if let sleep = sleep {
            snapshot.sleepHours = Double(sleep.totalSleepMinutes) / 60.0
            let rawEfficiency = sleep.stageMinutes[.inBed].map { inBed in
                inBed > 0 ? Double(sleep.totalSleepMinutes) / Double(inBed) : 0.85
            } ?? 0.85
            snapshot.sleepEfficiency = HealthUnitNormalizer.normalizeSleepEfficiency(rawEfficiency)
            
            let total = Double(sleep.totalSleepMinutes)
            if total > 0 {
                let rawDeep = (sleep.stageMinutes[.deep].map { Double($0) } ?? 0.0) / total
                let rawRem = (sleep.stageMinutes[.rem].map { Double($0) } ?? 0.0) / total
                snapshot.deepSleepPercent = HealthUnitNormalizer.normalizeSleepStagePercent(rawDeep)
                snapshot.remSleepPercent = HealthUnitNormalizer.normalizeSleepStagePercent(rawRem)
            }
            snapshot.bedtime = sleep.bedtime
            snapshot.wakeTime = sleep.wakeTime
            
            // Core Metrics v1.3 sub-metrics
            snapshot.awakeMinutes = sleep.stageMinutes[.awake].map { Double($0) }
            snapshot.awakeEpisodeCount = sleep.segments.filter { $0.stage == .awake && $0.end.timeIntervalSince($0.start) >= 120 }.count
            snapshot.deepSleepMinutes = sleep.stageMinutes[.deep].map { Double($0) }
            snapshot.remSleepMinutes = sleep.stageMinutes[.rem].map { Double($0) }
        }

        // Populate recovery
        if let recovery = recovery {
            snapshot.hrvAverage = recovery.hrvMilliseconds
            snapshot.restingHeartRate = recovery.restingHeartRate
            snapshot.respiratoryRate = recovery.respiratoryRate
        }

        // Populate strain
        if let strain = strain {
            snapshot.steps = strain.stepCount
            snapshot.activeCalories = strain.activeEnergyKilocalories
            snapshot.activeMinutes = strain.exerciseMinutes
            
            // Consolidate workouts using WorkoutAggregationService
            let aggregated: [WorkoutSummary]
            if let modelContext = modelContext {
                let deletedRecords = (try? modelContext.fetch(FetchDescriptor<DeletedWorkoutRecord>())) ?? []
                let blacklistedIDs = Set(deletedRecords.map(\.id))
                let filteredWorkouts = strain.workouts.filter { !blacklistedIDs.contains($0.id.uuidString) }

                try? WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
                    filteredWorkouts,
                    on: dayStart,
                    modelContext: modelContext,
                    calendar: calendar
                )
                aggregated = WorkoutAggregationService.shared.aggregateWorkouts(
                    healthKitWorkouts: filteredWorkouts,
                    for: dayStart,
                    modelContext: modelContext,
                    calendar: calendar
                )
            } else {
                aggregated = strain.workouts
            }
            
            snapshot.workoutCount = aggregated.count
            snapshot.workoutDuration = aggregated.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 60.0
            snapshot.workoutTypes = Set(aggregated.map(\.activityName)).sorted().joined(separator: ", ")
            snapshot.workouts = aggregated
        }

        // Populate body
        if let body = body {
            snapshot.bodyWeight = body.weightKilograms
            snapshot.bodyFatPercent = body.bodyFatPercentage.map { HealthUnitNormalizer.normalizeBodyFatPercentage($0) }
            snapshot.bmi = extended.bmi
        }

        // Populate extended
        snapshot.oxygenSaturation = extended.oxygenSaturation.map { HealthUnitNormalizer.normalizeOxygenSaturation($0) }
        snapshot.wristTemperature = extended.bodyTemperature

        return snapshot
    }
}
