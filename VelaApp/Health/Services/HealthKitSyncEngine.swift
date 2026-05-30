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
    func syncPastDays(_ days: Int, endingAt endDate: Date = Date()) async throws {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)

        // Pass 1: Build and save the raw daily snapshots from HealthKit for the last (42 + days)
        // This ensures the database already has raw data for rolling baseline calculations in Pass 2!
        let totalDaysToSync = 42 + days
        for i in (0..<totalDaysToSync).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            
            // Build raw daily snapshot from HealthKit
            let snapshot = await DailySnapshotBuilder.buildSnapshot(
                for: dayStart,
                queryService: queryService,
                calendar: calendar
            )
            
            // Save the raw snapshot
            try snapshotRepo.saveDailySnapshot(snapshot)
        }

        // Pass 2: Calculate scores day-by-day, pulling correct rolling raw baselines
        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: endDate) else { continue }
            let dayStart = calendar.startOfDay(for: date)
            
            // Load this day's snapshot from SwiftData
            let existingSnapshots = (try? snapshotRepo.fetchSnapshots(days: 1, endingAt: dayStart)) ?? []
            guard var snapshot = existingSnapshots.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) else { continue }
            
            // Fetch past 42 days of historical snapshots (which already have raw data from Pass 1!)
            let pastSnapshots = (try? snapshotRepo.fetchSnapshots(days: 42, endingAt: dayStart)) ?? []
            let historicalSnapshots = pastSnapshots.filter { !calendar.isDate($0.date, inSameDayAs: dayStart) }
            
            // Run computation pipeline
            let pipeline = MetricComputationPipeline()
            let metrics = pipeline.compute(
                for: snapshot,
                history: historicalSnapshots
            )

            // Update the snapshot with computed score values
            snapshot.sleepScore = metrics.sleepScore.value
            snapshot.recoveryScore = metrics.recovery.value
            snapshot.strainScore = metrics.strain.value
            snapshot.stressIndex = metrics.stress.value
            snapshot.morningEnergy = metrics.energy.components["morningEnergy"]
            snapshot.currentEnergy = metrics.energy.value
            snapshot.energyBank = metrics.energy.value

            snapshot.dailyLoad = metrics.strain.components["daily_load"]
            snapshot.workoutLoad = metrics.strain.components["workout_load"]
            snapshot.activityLoad = metrics.strain.components["activity_load"]
            snapshot.trainingLoadRatio = metrics.strain.components["training_load_ratio"]

            try snapshotRepo.saveDailySnapshot(snapshot)
        }
    }
}

final class DailySnapshotBuilder {
    @MainActor
    static func buildSnapshot(
        for date: Date,
        queryService: HealthQueryService,
        calendar: Calendar
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
            snapshot.sleepEfficiency = sleep.stageMinutes[.inBed].map { inBed in
                inBed > 0 ? Double(sleep.totalSleepMinutes) / Double(inBed) * 100.0 : 85.0
            } ?? 85.0
            
            let total = Double(sleep.totalSleepMinutes)
            if total > 0 {
                snapshot.deepSleepPercent = (sleep.stageMinutes[.deep].map { Double($0) } ?? 0.0) / total * 100.0
                snapshot.remSleepPercent = (sleep.stageMinutes[.rem].map { Double($0) } ?? 0.0) / total * 100.0
            }
            snapshot.bedtime = sleep.bedtime
            snapshot.wakeTime = sleep.wakeTime
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
            snapshot.workoutCount = strain.workouts.count
            snapshot.workoutDuration = strain.workouts.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 60.0
            snapshot.workoutTypes = strain.workouts.map(\.activityName).joined(separator: ",")
        }

        // Populate body
        if let body = body {
            snapshot.bodyWeight = body.weightKilograms
            snapshot.bodyFatPercent = body.bodyFatPercentage
            snapshot.bmi = extended.bmi
        }

        // Populate extended
        snapshot.oxygenSaturation = extended.oxygenSaturation
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
}

final class MetricComputationPipeline {
    init() {}

    private func calculateMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        } else {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        }
    }

    func compute(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot]
    ) -> ScoredMetricsPipelineResult {
        let calendar = Calendar.current
        
        // 1. Sleep Scoring Engine
        let pastBedtimes = history.compactMap { snap in
            snap.bedtime ?? calendar.date(bySettingHour: 23, minute: 30, second: 0, of: snap.date.addingTimeInterval(-86400))
        }
        
        let todayBedtime = snapshot.bedtime ?? calendar.date(bySettingHour: 23, minute: 30, second: 0, of: snapshot.date.addingTimeInterval(-86400))
        
        let sleepInput = SleepScoreInput(
            totalSleepMinutes: snapshot.sleepHours.map { $0 * 60.0 },
            sleepTargetMinutes: 450.0,
            todayBedtime: todayBedtime,
            recentBedtimes: pastBedtimes,
            awakeMinutes: 30.0,
            awakeEpisodeCount: 1
        )
        let sleepScore = SleepScoreEngine().calculate(from: sleepInput)

        // 2. Recovery Scoring Engine
        let hrvHistory = history.compactMap(\.hrvAverage)
        let rhrHistory = history.compactMap(\.restingHeartRate)
        let respHistory = history.compactMap(\.respiratoryRate)
        
        let recoveryInput = RecoveryScoreInput(
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: calculateMedian(hrvHistory),
            hrvHistory: hrvHistory,
            restingHeartRateToday: snapshot.restingHeartRate,
            restingHeartRateBaseline: calculateMedian(rhrHistory),
            rhrHistory: rhrHistory,
            sleepScoreLastNight: sleepScore.value,
            strainScoreYesterday: history.first?.strainScore,
            respiratoryRateToday: snapshot.respiratoryRate,
            respiratoryRateBaseline: calculateMedian(respHistory),
            respiratoryRateHistory: respHistory,
            bodyTempDelta: snapshot.wristTemperature.map { $0 - 36.5 },
            SpO2: snapshot.oxygenSaturation
        )
        let recoveryScore = RecoveryScoreEngine().calculate(from: recoveryInput)

        // 3. Strain Scoring Engine
        // ATL/CTL/ACWR 统一使用 raw dailyLoad
        let dailyLoadsHistory = history.compactMap(\.dailyLoad)
        var workouts: [WorkoutInput] = []
        if let duration = snapshot.workoutDuration, duration > 0 {
            workouts.append(WorkoutInput(durationMinutes: duration, averageHeartRate: snapshot.restingHeartRate.map { $0 + 30.0 }))
        }

        let strainInput = StrainScoreInput(
            workouts: workouts,
            activeEnergyToday: snapshot.activeCalories,
            exerciseMinutesToday: snapshot.workoutDuration,
            stepCount: snapshot.steps,
            restingHR: snapshot.restingHeartRate ?? 60.0,
            maxHR: 190.0,
            biologicalSex: nil,
            last28DaysDailyLoads: dailyLoadsHistory,
            recoveryScore: recoveryScore.value
        )
        let strainScore = StrainScoreEngine().calculate(from: strainInput)

        // 4. Physiological Stress Index Engine
        let stressInput = StressIndexInput(
            quietHRToday: snapshot.restingHeartRate,
            quietHRBaseline: calculateMedian(rhrHistory),
            quietHRSD: nil,
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: calculateMedian(hrvHistory),
            hrvSD: nil,
            respRateToday: snapshot.respiratoryRate,
            respRateBaseline: calculateMedian(respHistory),
            respRateSD: nil,
            bodyTempDelta: snapshot.wristTemperature.map { $0 - 36.5 },
            sleepScoreLastNight: sleepScore.value,
            strainScoreToday: strainScore.value,
            isWithinWorkoutWindow: false // Daily summaries calculate quiet averages, workout exclusion is handled real-time
        )
        let stressScore = StressIndexEngine().calculate(from: stressInput)

        // 5. Energy Bank Scoring Engine
        let now = Date()
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
            bodyTempDelta: snapshot.wristTemperature.map { $0 - 36.5 },
            hoursSinceWake: hoursSinceWake,
            respiratoryRateZ: nil,
            SpO2: snapshot.oxygenSaturation,
            mindfulMinutes: nil,
            napMinutes: nil,
            trainingLoadStatus: strainScore.trainingLoadStatus // Pass calculated trainingLoadStatus directly
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
