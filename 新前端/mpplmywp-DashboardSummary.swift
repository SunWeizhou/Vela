import Foundation

struct DashboardSummary: Hashable {
    var date: Date
    var sleepSummary: SleepSummary
    var sleepScore: StandardScoreResult
    var recovery: StandardScoreResult
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strain: StrainScoreResult
    var stress: StressIndexResult
    var energy: EnergyBankResult
    var healthAge: HealthAgeTrendResult
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics
    var workouts: [WorkoutSummary]
    var dailyInsight: String
    var source: DataSource

    enum DataSource: String, Hashable {
        case healthKit = "HealthKit"
        case preview = "Preview"
    }

    static func preview(date: Date = Date()) -> DashboardSummary {
        let sleepSummary = PreviewHealthDataProvider.sleepSummary(for: date)
        let sleepScore = SleepScoreEngine().calculate(
            from: SleepScoreInput(
                totalSleepMinutes: Double(sleepSummary.totalSleepMinutes),
                sleepTargetMinutes: 450,
                bedtimeOffsetMinutes: 45,
                wakeOffsetMinutes: 20
            )
        )
        let recovery = RecoveryScoreEngine().calculate(
            from: RecoveryScoreInput(
                hrvToday: 42,
                hrvBaseline: 45,
                restingHeartRateToday: 62,
                restingHeartRateBaseline: 60,
                sleepScoreLastNight: sleepScore.score,
                strainScoreYesterday: 58
            )
        )
        let strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 420,
                activeEnergyBaseline: 500,
                exerciseMinutesToday: 28,
                exerciseMinutesBaseline: 35,
                workoutIntensityLoad: 42,
                recoveryScore: recovery.score
            )
        )
        let stress = StressIndexEngine().calculate(
            from: StressIndexInput(
                heartRateElevationScore: 38,
                hrvSuppressionScore: 45,
                sleepDebtStressScore: max(0, 100 - sleepScore.score),
                recentStrainStressScore: strain.score
            )
        )
        let energy = EnergyBankEngine().calculate(
            from: EnergyBankInput(
                recoveryScore: recovery.score,
                sleepScore: sleepScore.score,
                strainScore: strain.score,
                stressIndex: stress.stressIndex,
                hrvToday: 42,
                hrvBaseline: 45,
                rhrToday: 62,
                rhrBaseline: 60,
                sleepHours: 7.2,
                strainHistory: [45, 52, 58, 55, 48, 60, 58],
                bodyTempDelta: 0.0
            )
        )
        let healthAge = HealthAgeTrendEngine().calculate(
            from: HealthAgeTrendInput(
                factors: [
                    .init(name: "VO2 Max", direction: .neutral),
                    .init(name: "Resting heart rate", direction: .positive),
                    .init(name: "Sleep regularity", direction: .negative),
                    .init(name: "Activity consistency", direction: .positive)
                ]
            )
        )

        return DashboardSummary(
            date: date,
            sleepSummary: sleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: 42,
                restingHeartRate: 62,
                sleepHeartRate: 58,
                respiratoryRate: 14
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: 45,
                restingHeartRate: 60,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: healthAge,
            bodyMetrics: BodyMetricsSummary(
                vo2Max: 42,
                weightKilograms: 72,
                bodyFatPercentage: 18,
                leanBodyMassKilograms: 59
            ),
            extendedMetrics: ExtendedHealthMetrics(age: 28, biologicalSex: "male", heightCm: 175),
            workouts: [],
            dailyInsight: L10n.t(
                "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
                "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
            ),
            source: .preview
        )
    }

    static func healthKit(
        context: DailyHealthContext,
        strainScoreYesterday: Double? = nil,
        bedtimeOffsetMinutes: Double? = nil,
        wakeOffsetMinutes: Double? = nil,
        hrvHistory: [Double] = [],
        rhrHistory: [Double] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardSummary {
        let sleepTarget = UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60
        let effectiveSleepTarget = sleepTarget > 0 ? sleepTarget : 450
        let sleepSummary = context.sleepSummary ?? SleepSummary(
            date: context.date,
            totalSleepMinutes: 0,
            bedtime: nil,
            wakeTime: nil,
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )
        let sleepScore = SleepScoreEngine().calculate(
            from: SleepScoreInput(
                totalSleepMinutes: context.sleepSummary.map { Double($0.totalSleepMinutes) },
                sleepTargetMinutes: effectiveSleepTarget,
                bedtimeOffsetMinutes: bedtimeOffsetMinutes,
                wakeOffsetMinutes: wakeOffsetMinutes,
                remMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
                deepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
                awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
                inBedMinutes: context.sleepSummary?.stageMinutes[.inBed].map { Double($0) }
            )
        )
        let resolvedSleepSummary = SleepSummary(
            date: sleepSummary.date,
            totalSleepMinutes: sleepSummary.totalSleepMinutes,
            bedtime: sleepSummary.bedtime,
            wakeTime: sleepSummary.wakeTime,
            stageMinutes: sleepSummary.stageMinutes,
            segments: sleepSummary.segments,
            sleepScore: sleepScore.score
        )
        let recovery = RecoveryScoreEngine().calculate(
            from: RecoveryScoreInput(
                hrvToday: context.recoveryMetrics.hrvMilliseconds,
                hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
                hrvHistory: hrvHistory,
                restingHeartRateToday: context.recoveryMetrics.restingHeartRate,
                restingHeartRateBaseline: context.recoveryBaseline.restingHeartRate,
                rhrHistory: rhrHistory,
                sleepScoreLastNight: context.sleepSummary == nil ? nil : sleepScore.score,
                strainScoreYesterday: strainScoreYesterday
            )
        )
        let workoutLoad = context.strainToday.workouts
            .compactMap(\.averageHeartRate)
            .max()
            .map { ScoringMath.clamp(($0 - 90) / 80 * 100) }
        let strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: context.strainToday.activeEnergyKilocalories,
                activeEnergyBaseline: context.strainBaselineDaily.activeEnergyKilocalories,
                exerciseMinutesToday: context.strainToday.exerciseMinutes,
                exerciseMinutesBaseline: context.strainBaselineDaily.exerciseMinutes,
                workoutIntensityLoad: workoutLoad ?? (context.strainToday.workouts.isEmpty ? nil : 45),
                recoveryScore: recovery.score,
                stepCount: context.strainToday.stepCount
            )
        )
        let stress = StressIndexEngine().calculate(
            from: StressIndexInput(
                heartRateElevationScore: stressHeartRateScore(today: context.recoveryMetrics.restingHeartRate, baseline: context.recoveryBaseline.restingHeartRate),
                hrvSuppressionScore: stressHRVScore(today: context.recoveryMetrics.hrvMilliseconds, baseline: context.recoveryBaseline.hrvMilliseconds),
                sleepDebtStressScore: context.sleepSummary == nil ? nil : max(0, 100 - sleepScore.score),
                recentStrainStressScore: strain.score
            )
        )
        let energy = EnergyBankEngine().calculate(
            from: EnergyBankInput(
                recoveryScore: recovery.score,
                sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
                strainScore: strain.score,
                stressIndex: stress.stressIndex,
                hrvToday: context.recoveryMetrics.hrvMilliseconds,
                hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
                rhrToday: context.recoveryMetrics.restingHeartRate,
                rhrBaseline: context.recoveryBaseline.restingHeartRate,
                sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
                strainHistory: nil, // populated if available from historical context
                bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 }
            )
        )
        let healthAge = HealthAgeTrendEngine().calculate(
            from: HealthAgeTrendInput(
                factors: healthAgeFactors(context: context, recovery: recovery, sleepScore: sleepScore, strain: strain)
            )
        )

        return DashboardSummary(
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
    }

    private static func stressHeartRateScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((today - baseline) / baseline) * 250 + 35)
    }

    private static func stressHRVScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((baseline - today) / baseline) * 250 + 35)
    }

    private static func healthAgeFactors(
        context: DailyHealthContext,
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult
    ) -> [HealthAgeTrendFactor] {
        var factors: [HealthAgeTrendFactor] = []
        if let vo2 = context.bodyMetrics.vo2Max {
            factors.append(.init(name: "VO2 Max", direction: vo2 >= 40 ? .positive : .neutral))
        }
        if let rhr = context.recoveryMetrics.restingHeartRate {
            factors.append(.init(name: "Resting heart rate", direction: rhr <= 62 ? .positive : .negative))
        }
        if let bf = context.bodyMetrics.bodyFatPercentage {
            // Healthy body fat: roughly 10-20% men, 18-28% women — use a mid-range check
            factors.append(.init(name: "Body fat", direction: (10...30).contains(bf) ? .positive : .negative))
        }
        if let weight = context.bodyMetrics.weightKilograms, let lean = context.bodyMetrics.leanBodyMassKilograms, weight > 0 {
            let leanRatio = lean / weight
            factors.append(.init(name: "Lean mass ratio", direction: leanRatio >= 0.65 ? .positive : .neutral))
        }
        factors.append(.init(name: "Sleep duration", direction: sleepScore.score >= 70 ? .positive : .negative))
        factors.append(.init(name: "Recovery trend", direction: recovery.score >= 70 ? .positive : (recovery.score < 40 ? .negative : .neutral)))
        factors.append(.init(name: "Activity consistency", direction: strain.confidence == .high ? .positive : .neutral))
        return factors
    }

    private static func dailyInsight(
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult,
        source: DataSource
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
}
