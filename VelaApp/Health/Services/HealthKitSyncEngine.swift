import Foundation
import SwiftData

@MainActor
final class HealthKitSyncEngine {
    private let queryService: HealthQueryService
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(queryService: HealthQueryService, modelContext: ModelContext, calendar: Calendar = .current) {
        self.queryService = queryService
        self.modelContext = modelContext
        self.calendar = calendar
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
        let recentRefreshCutoff = calendar.date(
            byAdding: .day,
            value: -max(0, refreshWindow - 1),
            to: calendar.startOfDay(for: endDate)
        ) ?? calendar.startOfDay(for: endDate)

        for i in (0..<totalDaysToSync).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            guard dayStart >= recentRefreshCutoff || !cachedDays.contains(dayStart) else { continue }
            
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
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            
            // Load this day's snapshot from SwiftData
            let existingSnapshots: [DailyHealthSnapshot]
            do {
                existingSnapshots = try snapshotRepo.fetchSnapshots(days: 1, endingAt: dayStart)
            } catch {
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
                try snapshotRepo.saveDailySnapshot(snapshot)
                try WorkoutAggregationService.shared.aggregateDay(
                    date: dayStart,
                    modelContext: modelContext,
                    calendar: calendar
                )
                try modelContext.save()
            } catch {
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
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let range = DateRangeQuery(start: dayStart, end: dayEnd)

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

struct ScoredMetricsPipelineResult {
    var sleepScore: MetricResult
    var recovery: MetricResult
    var strain: MetricResult
    var stress: MetricResult
    var energy: MetricResult

    func applying(to snapshot: DailyHealthSnapshot) -> DailyHealthSnapshot {
        var result = snapshot
        result.sleepScore = sleepScore.value
        result.recoveryScore = recovery.value
        result.strainScore = strain.value
        result.stressIndex = stress.value
        result.morningEnergy = energy.components["morningEnergy"]
        result.currentEnergy = energy.value
        result.energyBank = energy.value
        result.dailyLoad = strain.components["daily_load"]
        result.workoutLoad = strain.components["workout_load"]
        result.activityLoad = strain.components["activity_load"]
        result.trainingLoadRatio = strain.components["training_load_ratio"]
        result.atl = energy.components["atl"]
        result.ctl = energy.components["ctl"]
        result.tsb = energy.components["tsb"]
        result.acwr = energy.components["acwr"]
        return result
    }
}

struct DailyHealthComputationProfile: Sendable {
    let sleepTargetMinutes: Double
    let maxHeartRate: Double?
    let biologicalSex: String?

    static func current() -> DailyHealthComputationProfile {
        let age = UserProfileSettings.age() ?? WikiFileService.getAgeFromWiki()
        return DailyHealthComputationProfile(
            sleepTargetMinutes: SleepTargetSettings.targetMinutes(),
            maxHeartRate: UserProfileSettings.maxHeartRate()
                ?? WikiFileService.getMaxHeartRateFromWiki()
                ?? age.map(UserProfileSettings.inferredMaxHeartRate),
            biologicalSex: UserProfileSettings.biologicalSex()
        )
    }
}

final class DailyHealthComputation {
    private let calendar: Calendar
    private let now: Date
    private let profile: DailyHealthComputationProfile

    init(
        calendar: Calendar = .current,
        now: Date = Date(),
        profile: DailyHealthComputationProfile = .current()
    ) {
        self.calendar = calendar
        self.now = now
        self.profile = profile
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

    private func wristTemperatureDelta(
        current: Double?,
        history: [DailyHealthSnapshot]
    ) -> Double? {
        guard let current else { return nil }
        let samples = history.compactMap(\.wristTemperature)
        guard samples.count >= 5, let baseline = calculateMedian(samples) else { return nil }
        return current - baseline
    }

    private func calculateStandardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 2 else { return nil }
        let mean = values.reduce(0.0, +) / Double(values.count)
        let sumSquaredDiffs = values.map { pow($0 - mean, 2) }.reduce(0.0, +)
        let variance = sumSquaredDiffs / Double(values.count - 1)
        let sd = sqrt(variance)
        return sd > 0 ? sd : nil
    }

    func compute(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot]
    ) -> ScoredMetricsPipelineResult {
        // 1. Sleep Scoring Engine
        let pastBedtimes = history.compactMap(\.bedtime)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: snapshot.date) ?? snapshot.date
        let todayBedtime = snapshot.bedtime
            ?? calendar.date(bySettingHour: 23, minute: 30, second: 0, of: previousDay)
        
        let sleepInput = SleepScoreInput(
            totalSleepMinutes: snapshot.sleepHours.map { $0 * 60.0 },
            sleepTargetMinutes: profile.sleepTargetMinutes,
            todayBedtime: todayBedtime,
            recentBedtimes: pastBedtimes,
            awakeMinutes: snapshot.awakeMinutes,
            awakeEpisodeCount: snapshot.awakeEpisodeCount,
            remMinutes: snapshot.remSleepMinutes,
            deepMinutes: snapshot.deepSleepMinutes
        )
        let sleepScore = SleepScoreEngine().calculate(from: sleepInput)

        // 2. Recovery Scoring Engine
        let hrvHistory = history.compactMap(\.hrvAverage)
        let rhrHistory = history.compactMap(\.restingHeartRate)
        let respHistory = history.compactMap(\.respiratoryRate)
        let temperatureDelta = wristTemperatureDelta(current: snapshot.wristTemperature, history: history)
        
        let yesterday = calendar.date(byAdding: .day, value: -1, to: snapshot.date) ?? snapshot.date
        let yesterdayStrain = history.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) })?.strainScore
        
        let recoveryInput = RecoveryScoreInput(
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: calculateMedian(hrvHistory),
            hrvHistory: hrvHistory,
            restingHeartRateToday: snapshot.restingHeartRate,
            restingHeartRateBaseline: calculateMedian(rhrHistory),
            rhrHistory: rhrHistory,
            sleepScoreLastNight: sleepScore.value,
            strainScoreYesterday: yesterdayStrain,
            respiratoryRateToday: snapshot.respiratoryRate,
            respiratoryRateBaseline: calculateMedian(respHistory),
            respiratoryRateHistory: respHistory,
            bodyTempDelta: temperatureDelta,
            SpO2: snapshot.oxygenSaturation
        )
        let recoveryScore = RecoveryScoreEngine().calculate(from: recoveryInput)

        // 3. Strain Scoring Engine
        let dailyLoadsHistory = history.compactMap(\.dailyLoad)
        var workouts: [WorkoutInput] = []
        for w in snapshot.workouts {
            workouts.append(WorkoutInput(
                id: w.id,
                durationMinutes: w.end.timeIntervalSince(w.start) / 60.0,
                averageHeartRate: w.averageHeartRate,
                rpe: w.rpe
            ))
        }

        let strainInput = StrainScoreInput(
            workouts: workouts,
            activeEnergyToday: snapshot.activeCalories,
            exerciseMinutesToday: snapshot.activeMinutes ?? snapshot.workoutDuration,
            stepCount: snapshot.steps,
            restingHR: snapshot.restingHeartRate ?? 0,
            maxHR: profile.maxHeartRate ?? 0,
            biologicalSex: profile.biologicalSex,
            last28DaysDailyLoads: dailyLoadsHistory,
            recoveryScore: recoveryScore.value
        )
        let strainScore = StrainScoreEngine().calculate(from: strainInput)

        // 4. Physiological Stress Index Engine
        let quietHRSD = calculateStandardDeviation(rhrHistory)
        let hrvSD = calculateStandardDeviation(hrvHistory)
        let respRateSD = calculateStandardDeviation(respHistory)

        let stressInput = StressIndexInput(
            quietHRToday: snapshot.restingHeartRate,
            quietHRBaseline: calculateMedian(rhrHistory),
            quietHRSD: quietHRSD,
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: calculateMedian(hrvHistory),
            hrvSD: hrvSD,
            respRateToday: snapshot.respiratoryRate,
            respRateBaseline: calculateMedian(respHistory),
            respRateSD: respRateSD,
            bodyTempDelta: temperatureDelta,
            sleepScoreLastNight: sleepScore.value,
            strainScoreToday: strainScore.value,
            isWithinWorkoutWindow: false
        )
        let stressScore = StressIndexEngine().calculate(from: stressInput)

        // 5. Energy Bank Scoring Engine
        let isToday = calendar.isDate(snapshot.date, inSameDayAs: now)
        let wake = snapshot.wakeTime ?? calendar.date(bySettingHour: 7, minute: 30, second: 0, of: snapshot.date) ?? snapshot.date
        let hoursSinceWake: Double
        if isToday {
            hoursSinceWake = max(0.0, min(24.0, now.timeIntervalSince(wake) / 3600.0))
        } else {
            hoursSinceWake = 16.0
        }

        let energyInput = EnergyBankInput(
            recoveryScore: recoveryScore.value,
            sleepScore: sleepScore.value,
            strainScore: strainScore.value,
            stressIndex: stressScore.value,
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: calculateMedian(hrvHistory),
            rhrToday: snapshot.restingHeartRate,
            rhrBaseline: calculateMedian(rhrHistory),
            sleepHours: snapshot.sleepHours,
            strainHistory: dailyLoadsHistory,
            bodyTempDelta: temperatureDelta,
            hoursSinceWake: hoursSinceWake,
            respiratoryRateZ: nil,
            SpO2: snapshot.oxygenSaturation,
            mindfulMinutes: nil,
            napMinutes: nil,
            trainingLoadStatus: strainScore.trainingLoadStatus
        )
        let energyScore = EnergyBankEngine().calculate(from: energyInput)

        return ScoredMetricsPipelineResult(
            sleepScore: sleepScore,
            recovery: recoveryScore,
            strain: strainScore,
            stress: stressScore,
            energy: energyScore
        )
    }
}
