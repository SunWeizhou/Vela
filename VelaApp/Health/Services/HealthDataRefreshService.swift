import Foundation

@MainActor
final class HealthDataRefreshService {
    private let queryService: HealthQueryService
    private let calendar: Calendar

    init(queryService: HealthQueryService, calendar: Calendar = .current) {
        self.queryService = queryService
        self.calendar = calendar
    }

    convenience init() {
        self.init(queryService: HealthKitQueryService())
    }

    func buildTodayRawSnapshot(now: Date = Date()) async throws -> DailyHealthSnapshot {
        let context = try await refreshContext(now: now)
        guard context.hasAnyData else {
            return DailyHealthSnapshot(date: context.date)
        }

        var snapshot = DailyHealthSnapshot(date: context.date)
        
        // Populate sleep
        if let sleep = context.sleepSummary {
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
        
        snapshot.hrvAverage = context.recoveryMetrics.hrvMilliseconds
        snapshot.restingHeartRate = context.recoveryMetrics.restingHeartRate
        snapshot.respiratoryRate = context.recoveryMetrics.respiratoryRate
        
        snapshot.steps = context.strainToday.stepCount
        snapshot.activeCalories = context.strainToday.activeEnergyKilocalories
        snapshot.workoutCount = context.strainToday.workouts.count
        snapshot.workoutDuration = context.strainToday.workouts.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) } / 60.0
        snapshot.workoutTypes = context.strainToday.workouts.map(\.activityName).joined(separator: ",")
        snapshot.workouts = context.strainToday.workouts
        
        snapshot.bodyWeight = context.bodyMetrics.weightKilograms
        snapshot.bodyFatPercent = context.bodyMetrics.bodyFatPercentage.map { HealthUnitNormalizer.normalizeBodyFatPercentage($0) }
        
        snapshot.oxygenSaturation = context.extendedMetrics.oxygenSaturation.map { HealthUnitNormalizer.normalizeOxygenSaturation($0) }
        snapshot.wristTemperature = context.extendedMetrics.bodyTemperature
        
        return snapshot
    }

    func refreshContext(now: Date = Date()) async throws -> DailyHealthContext {
        let todayRange = DateRangeQuery.today(containing: now, calendar: calendar)
        let baselineRange = DateRangeQuery.recentDays(28, endingAt: calendar.startOfDay(for: now), calendar: calendar)

        let resolvedSleep = try? await queryService.sleepSummary(in: DateRangeQuery.recentDays(2, endingAt: now, calendar: calendar))
        let recovery = (try? await queryService.recoveryMetrics(in: todayRange)) ?? RecoveryMetricSummary()
        let recoveryBaseline = (try? await queryService.recoveryMetrics(in: baselineRange)) ?? RecoveryMetricSummary()
        let strain = (try? await queryService.strainSummary(in: todayRange)) ?? StrainActivitySummary(workouts: [])
        let rawStrainBaseline = try? await queryService.strainSummary(in: baselineRange)
        let strainBaseline = rawStrainBaseline?.dailyAverage(days: 28) ?? StrainActivitySummary(workouts: [])
        let body = (try? await queryService.bodyMetrics(in: DateRangeQuery.recentDays(90, endingAt: now, calendar: calendar))) ?? BodyMetricsSummary()

        // Query extended metrics (non-critical, so catch errors gracefully)
        let hkQueryService = queryService as? HealthKitQueryService
        let extended = (try? await hkQueryService?.extendedMetrics(in: todayRange)) ?? ExtendedHealthMetrics()

        return DailyHealthContext(
            date: todayRange.start,
            sleepSummary: resolvedSleep,
            recoveryMetrics: recovery,
            recoveryBaseline: recoveryBaseline,
            strainToday: strain,
            strainBaselineDaily: strainBaseline,
            bodyMetrics: body,
            extendedMetrics: extended
        )
    }
}

struct DailyHealthContext: Hashable {
    var date: Date
    var sleepSummary: SleepSummary?
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strainToday: StrainActivitySummary
    var strainBaselineDaily: StrainActivitySummary
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics = ExtendedHealthMetrics()

    var hasAnyData: Bool {
        sleepSummary != nil ||
        recoveryMetrics.hrvMilliseconds != nil ||
        recoveryMetrics.restingHeartRate != nil ||
        recoveryMetrics.sleepHeartRate != nil ||
        recoveryMetrics.respiratoryRate != nil ||
        strainToday.activeEnergyKilocalories != nil ||
        strainToday.exerciseMinutes != nil ||
        strainToday.stepCount != nil ||
        !strainToday.workouts.isEmpty ||
        bodyMetrics.vo2Max != nil ||
        bodyMetrics.weightKilograms != nil ||
        bodyMetrics.bodyFatPercentage != nil ||
        bodyMetrics.leanBodyMassKilograms != nil
    }
}

extension StrainActivitySummary {
    func dailyAverage(days: Double) -> StrainActivitySummary {
        StrainActivitySummary(
            activeEnergyKilocalories: activeEnergyKilocalories.map { $0 / days },
            exerciseMinutes: exerciseMinutes.map { $0 / days },
            stepCount: stepCount.map { $0 / days },
            workouts: workouts
        )
    }
}
