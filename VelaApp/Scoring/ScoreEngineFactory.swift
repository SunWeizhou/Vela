import Foundation

/// Factory that builds each scoring engine's Input from a DailyHealthContext + historical data.
/// This extracts the input-building logic from DashboardSummary.healthKit().
enum ScoreEngineFactory {

    // MARK: - Sleep

    static func sleep(
        from context: DailyHealthContext,
        sleepTarget: Double,
        bedtimeOffsetMinutes: Double?,
        wakeOffsetMinutes: Double?
    ) -> SleepScoreInput {
        SleepScoreInput(
            totalSleepMinutes: context.sleepSummary.map { Double($0.totalSleepMinutes) },
            sleepTargetMinutes: sleepTarget,
            bedtimeOffsetMinutes: bedtimeOffsetMinutes,
            wakeOffsetMinutes: wakeOffsetMinutes,
            remMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
            deepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
            awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
            inBedMinutes: context.sleepSummary?.stageMinutes[.inBed].map { Double($0) }
        )
    }

    // MARK: - Recovery

    static func recovery(
        from context: DailyHealthContext,
        sleepScore: Double?,
        strainScoreYesterday: Double?,
        hrvHistory: [Double],
        rhrHistory: [Double]
    ) -> RecoveryScoreInput {
        RecoveryScoreInput(
            hrvToday: context.recoveryMetrics.hrvMilliseconds,
            hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
            hrvHistory: hrvHistory,
            restingHeartRateToday: context.recoveryMetrics.restingHeartRate,
            restingHeartRateBaseline: context.recoveryBaseline.restingHeartRate,
            rhrHistory: rhrHistory,
            sleepScoreLastNight: context.sleepSummary == nil ? nil : sleepScore,
            strainScoreYesterday: strainScoreYesterday
        )
    }

    // MARK: - Strain

    static func strain(
        from context: DailyHealthContext,
        recoveryScore: Double
    ) -> StrainScoreInput {
        let workoutLoad = context.strainToday.workouts
            .compactMap(\.averageHeartRate)
            .max()
            .map { ScoringMath.clamp(($0 - 90) / 80 * 100) }
        return StrainScoreInput(
            activeEnergyToday: context.strainToday.activeEnergyKilocalories,
            activeEnergyBaseline: context.strainBaselineDaily.activeEnergyKilocalories,
            exerciseMinutesToday: context.strainToday.exerciseMinutes,
            exerciseMinutesBaseline: context.strainBaselineDaily.exerciseMinutes,
            workoutIntensityLoad: workoutLoad ?? (context.strainToday.workouts.isEmpty ? nil : 45),
            recoveryScore: recoveryScore,
            stepCount: context.strainToday.stepCount
        )
    }

    // MARK: - Stress

    static func stress(
        from context: DailyHealthContext,
        sleepScore: Double?,
        strainScore: Double
    ) -> StressIndexInput {
        StressIndexInput(
            heartRateElevationScore: stressHeartRateScore(
                today: context.recoveryMetrics.restingHeartRate,
                baseline: context.recoveryBaseline.restingHeartRate
            ),
            hrvSuppressionScore: stressHRVScore(
                today: context.recoveryMetrics.hrvMilliseconds,
                baseline: context.recoveryBaseline.hrvMilliseconds
            ),
            sleepDebtStressScore: context.sleepSummary == nil ? nil : max(0, 100 - (sleepScore ?? 0)),
            recentStrainStressScore: strainScore
        )
    }

    private static func stressHeartRateScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((today - baseline) / baseline) * 250 + 35)
    }

    private static func stressHRVScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((baseline - today) / baseline) * 250 + 35)
    }

    // MARK: - Energy Bank

    static func energyBank(
        from context: DailyHealthContext,
        recoveryScore: Double,
        sleepScore: Double?,
        strainScore: Double,
        stressIndex: Double,
        strainHistory: [Double]?
    ) -> EnergyBankInput {
        EnergyBankInput(
            recoveryScore: recoveryScore,
            sleepScore: sleepScore,
            strainScore: strainScore,
            stressIndex: stressIndex,
            hrvToday: context.recoveryMetrics.hrvMilliseconds,
            hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
            rhrToday: context.recoveryMetrics.restingHeartRate,
            rhrBaseline: context.recoveryBaseline.restingHeartRate,
            sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
            strainHistory: strainHistory,
            bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 }
        )
    }

    // MARK: - Health Age

    static func healthAge(
        from context: DailyHealthContext,
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult
    ) -> HealthAgeTrendInput {
        var factors: [HealthAgeTrendFactor] = []
        if let vo2 = context.bodyMetrics.vo2Max {
            factors.append(.init(name: "VO2 Max", direction: vo2 >= 40 ? .positive : .neutral))
        }
        if let rhr = context.recoveryMetrics.restingHeartRate {
            factors.append(.init(name: "Resting heart rate", direction: rhr <= 62 ? .positive : .negative))
        }
        if let bf = context.bodyMetrics.bodyFatPercentage {
            factors.append(.init(name: "Body fat", direction: (10...30).contains(bf) ? .positive : .negative))
        }
        if let weight = context.bodyMetrics.weightKilograms, let lean = context.bodyMetrics.leanBodyMassKilograms, weight > 0 {
            let leanRatio = lean / weight
            factors.append(.init(name: "Lean mass ratio", direction: leanRatio >= 0.65 ? .positive : .neutral))
        }
        factors.append(.init(name: "Sleep duration", direction: sleepScore.score >= 70 ? .positive : .negative))
        factors.append(.init(name: "Recovery trend", direction: recovery.score >= 70 ? .positive : (recovery.score < 40 ? .negative : .neutral)))
        factors.append(.init(name: "Activity consistency", direction: strain.confidence == .high ? .positive : .neutral))
        return HealthAgeTrendInput(factors: factors)
    }

    // MARK: - Resolved Sleep Summary

    static func resolvedSleepSummary(
        from context: DailyHealthContext,
        sleepScore: Double
    ) -> SleepSummary {
        let summary = context.sleepSummary ?? SleepSummary(
            date: context.date,
            totalSleepMinutes: 0,
            bedtime: nil,
            wakeTime: nil,
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )
        return SleepSummary(
            date: summary.date,
            totalSleepMinutes: summary.totalSleepMinutes,
            bedtime: summary.bedtime,
            wakeTime: summary.wakeTime,
            stageMinutes: summary.stageMinutes,
            segments: summary.segments,
            sleepScore: sleepScore
        )
    }
}
