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

    func refreshToday(now: Date = Date()) async throws -> DailyHealthSnapshot {
        let context = try await refreshContext(now: now)
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
        guard context.hasAnyData else {
            return DailyHealthSnapshot(
                date: context.date,
                sleepScore: nil,
                recoveryScore: nil,
                strainScore: nil,
                stressIndex: nil,
                morningEnergy: nil,
                currentEnergy: nil
            )
        }

        return DailyHealthSnapshot(
            date: context.date,
            sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
            recoveryScore: recovery.components.isEmpty ? nil : recovery.score,
            strainScore: strain.components.isEmpty ? nil : strain.score,
            stressIndex: stress.components.isEmpty ? nil : stress.stressIndex,
            morningEnergy: energy.morningEnergy,
            currentEnergy: energy.currentEnergy
        )
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
