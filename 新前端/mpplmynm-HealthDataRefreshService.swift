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
        let dashboard = DashboardSummary.healthKit(context: context, now: now, calendar: calendar)
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
            sleepScore: context.sleepSummary == nil ? nil : dashboard.sleepScore.score,
            recoveryScore: dashboard.recovery.components.isEmpty ? nil : dashboard.recovery.score,
            strainScore: dashboard.strain.components.isEmpty ? nil : dashboard.strain.score,
            stressIndex: dashboard.stress.components.isEmpty ? nil : dashboard.stress.stressIndex,
            morningEnergy: dashboard.energy.morningEnergy,
            currentEnergy: dashboard.energy.currentEnergy
        )
    }

    func refreshContext(now: Date = Date()) async throws -> DailyHealthContext {
        let todayRange = DateRangeQuery.today(containing: now, calendar: calendar)
        let baselineRange = DateRangeQuery.recentDays(28, endingAt: calendar.startOfDay(for: now), calendar: calendar)

        let resolvedSleep = try await queryService.sleepSummary(in: DateRangeQuery.recentDays(2, endingAt: now, calendar: calendar))
        let recovery = try await queryService.recoveryMetrics(in: todayRange)
        let recoveryBaseline = try await queryService.recoveryMetrics(in: baselineRange)
        let strain = try await queryService.strainSummary(in: todayRange)
        let strainBaseline = try await queryService.strainSummary(in: baselineRange).dailyAverage(days: 28)
        let body = try await queryService.bodyMetrics(in: DateRangeQuery.recentDays(90, endingAt: now, calendar: calendar))

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
