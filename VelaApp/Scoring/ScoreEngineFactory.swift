import Foundation

enum UserProfileSettings {
    static let ageKey = "vela_user_age"
    static let weightKey = "vela_user_weight"
    static let heightKey = "vela_user_height"
    static let maxHeartRateKey = "vela_max_hr"
    static let biologicalSexKey = "vela_user_biological_sex"

    static func age(defaults: UserDefaults = .standard) -> Int? {
        guard let value = defaults.object(forKey: ageKey) as? NSNumber else { return nil }
        let age = value.intValue
        return (10...100).contains(age) ? age : nil
    }

    static func maxHeartRate(defaults: UserDefaults = .standard) -> Double? {
        guard let value = defaults.object(forKey: maxHeartRateKey) as? NSNumber else { return nil }
        return validatedMaxHeartRate(value.doubleValue)
    }

    static func weightKilograms(defaults: UserDefaults = .standard) -> Double? {
        guard let value = defaults.object(forKey: weightKey) as? NSNumber else { return nil }
        let weight = value.doubleValue
        return (25...350).contains(weight) ? weight : nil
    }

    static func heightCentimeters(defaults: UserDefaults = .standard) -> Double? {
        guard let value = defaults.object(forKey: heightKey) as? NSNumber else { return nil }
        let height = value.doubleValue
        return (100...250).contains(height) ? height : nil
    }

    static func biologicalSex(defaults: UserDefaults = .standard) -> String? {
        let value = defaults.string(forKey: biologicalSexKey)
        return ["male", "female", "other"].contains(value) ? value : nil
    }

    /// One-time migration: UserDefaults previously received Apple Health values via
    /// `hydrateMissingValuesFromHealth`, which (under the new manual-first resolution)
    /// would freeze stale HealthKit values as if they were user overrides.
    /// Reset those auto-filled values once so the profile genuinely follows Apple Health.
    static let priorityMigrationKey = "vela_user_profile_priority_v2_migrated"

    static func migrateLegacyHydratedValuesIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: priorityMigrationKey) else { return }
        defaults.removeObject(forKey: ageKey)
        defaults.removeObject(forKey: weightKey)
        defaults.removeObject(forKey: heightKey)
        defaults.removeObject(forKey: biologicalSexKey)
        defaults.set(true, forKey: priorityMigrationKey)
    }

    static func bodyMassIndex(weightKilograms: Double?, heightCentimeters: Double?) -> Double? {
        guard let weightKilograms,
              let heightCentimeters,
              (25...350).contains(weightKilograms),
              (100...250).contains(heightCentimeters) else { return nil }
        let heightMeters = heightCentimeters / 100
        return weightKilograms / (heightMeters * heightMeters)
    }

    static func inferredMaxHeartRate(age: Int) -> Double {
        Double(max(100, 220 - age))
    }

    static func resolvedMaxHeartRate(
        age: Int,
        wiki: Double? = nil,
        defaults: UserDefaults = .standard
    ) -> Double {
        // explicit 参数此前无任何调用方传入（死参数已删除），
        // 与引擎解析链一致：UserDefaults → wiki → 年龄推断。
        maxHeartRate(defaults: defaults)
            ?? wiki.flatMap(validatedMaxHeartRate)
            ?? inferredMaxHeartRate(age: age)
    }

    private static func validatedMaxHeartRate(_ value: Double) -> Double? {
        (100...240).contains(value) ? value : nil
    }
}

/// Display-only projections derived from canonical Daily Health Computation results.
enum DashboardMetricProjection {
    // MARK: - Health Age

    static func healthAge(
        from context: DailyHealthContext,
        recovery: MetricResult,
        sleepScore: MetricResult,
        strain: MetricResult
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
        sleepScore: Double?
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

// MARK: - Daily Health Computation

/// The five independent Scored Health Evidence results for one Daily Health Snapshot.
/// No aggregate health score is produced because each domain has different directionality.
struct ScoredHealthEvidence: Hashable {
    var sleep: MetricResult
    var recovery: MetricResult
    var strain: MetricResult
    var physiologicalStress: MetricResult
    var energy: MetricResult

    // Compatibility names while callers migrate to the domain language.
    var sleepScore: MetricResult { sleep }
    var stress: MetricResult { physiologicalStress }

    func applying(to snapshot: DailyHealthSnapshot) -> DailyHealthSnapshot {
        var result = snapshot
        result.sleepScore = sleep.value
        result.recoveryScore = recovery.value
        result.strainScore = strain.value
        result.stressIndex = physiologicalStress.value
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

    static func current(
        ageFallback: Int? = nil,
        biologicalSexFallback: String? = nil
    ) -> DailyHealthComputationProfile {
        // M2 修复：与展示/AI 层同源——手动 → HealthKit → wiki。
        // 此前引擎是 manual → wiki → HK，wiki 陈旧年龄会压过 HealthKit 出生日期，
        // 评分与 AI 对同一用户年龄看法不一致。
        let age = UserProfileSettings.age()
            ?? ageFallback
            ?? WikiFileService.getAgeFromWiki()
        return DailyHealthComputationProfile(
            sleepTargetMinutes: SleepTargetSettings.targetMinutes(),
            maxHeartRate: UserProfileSettings.maxHeartRate()
                ?? WikiFileService.getMaxHeartRateFromWiki()
                ?? age.map(UserProfileSettings.inferredMaxHeartRate),
            biologicalSex: UserProfileSettings.biologicalSex()
                ?? biologicalSexFallback
        )
    }
}

/// The sole deterministic transformation from a Daily Health Snapshot plus
/// Personal Baseline history into Scored Health Evidence.
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

    func compute(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        longTermBaselines: LongTermBaselineReport? = nil
    ) -> ScoredHealthEvidence {
        let asOf = evaluationDate(for: snapshot)
        let baselineHistory = personalBaselineHistory(for: snapshot, from: history)
        let hrvHistory = baselineHistory.compactMap(\.hrvAverage)
        let hrvRmssdHistory = baselineHistory.compactMap(\.hrvRmssdMilliseconds)
        let rhrHistory = baselineHistory.compactMap(\.restingHeartRate)
        let respiratoryHistory = baselineHistory.compactMap(\.respiratoryRate)
        let dailyLoadHistory = baselineHistory.compactMap(\.dailyLoad)
        let temperatureDelta = wristTemperatureDelta(
            current: snapshot.wristTemperature,
            history: baselineHistory
        )

        let sleep = SleepScoreEngine().calculate(from: SleepScoreInput(
            asOf: asOf,
            totalSleepMinutes: snapshot.sleepHours.map { $0 * 60 },
            sleepTargetMinutes: profile.sleepTargetMinutes,
            todayBedtime: snapshot.bedtime,
            recentBedtimes: baselineHistory.prefix(13).compactMap(\.bedtime),
            awakeMinutes: snapshot.awakeMinutes,
            awakeEpisodeCount: snapshot.awakeEpisodeCount,
            remMinutes: snapshot.remSleepMinutes,
            deepMinutes: snapshot.deepSleepMinutes
        ))

        let yesterday = calendar.date(byAdding: .day, value: -1, to: snapshot.date) ?? snapshot.date
        let yesterdayStrain = baselineHistory.first {
            calendar.isDate($0.date, inSameDayAs: yesterday)
        }?.strainScore
        let recovery = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            asOf: asOf,
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: PersonalBaselineEngine.median(hrvHistory),
            hrvHistory: hrvHistory,
            hrvRmssdToday: snapshot.hrvRmssdMilliseconds,
            hrvRmssdBaseline: PersonalBaselineEngine.median(hrvRmssdHistory),
            hrvRmssdHistory: hrvRmssdHistory,
            restingHeartRateToday: snapshot.restingHeartRate,
            restingHeartRateBaseline: PersonalBaselineEngine.median(rhrHistory),
            rhrHistory: rhrHistory,
            sleepScoreLastNight: sleep.value,
            strainScoreYesterday: yesterdayStrain,
            respiratoryRateToday: snapshot.respiratoryRate,
            respiratoryRateBaseline: PersonalBaselineEngine.median(respiratoryHistory),
            respiratoryRateHistory: respiratoryHistory,
            bodyTempDelta: temperatureDelta,
            SpO2: snapshot.oxygenSaturation,
            longTermContext: recoveryLongTermContext(from: longTermBaselines)
        ))

        let strain = StrainScoreEngine().calculate(from: StrainScoreInput(
            asOf: asOf,
            workouts: snapshot.workouts.map {
                WorkoutInput(
                    id: $0.id,
                    durationMinutes: $0.end.timeIntervalSince($0.start) / 60,
                    averageHeartRate: $0.averageHeartRate,
                    rpe: $0.rpe
                )
            },
            activeEnergyToday: snapshot.activeCalories,
            exerciseMinutesToday: snapshot.activeMinutes ?? snapshot.workoutDuration,
            stepCount: snapshot.steps,
            restingHR: snapshot.restingHeartRate ?? 0,
            maxHR: profile.maxHeartRate ?? 0,
            biologicalSex: profile.biologicalSex,
            last28DaysDailyLoads: Array(dailyLoadHistory.prefix(28)),
            recoveryScore: recovery.value
        ))

        let respiratorySD = PersonalBaselineEngine.sampleStandardDeviation(respiratoryHistory)
        let physiologicalStress = StressIndexEngine().calculate(from: StressIndexInput(
            asOf: asOf,
            quietHRToday: snapshot.restingHeartRate,
            quietHRBaseline: PersonalBaselineEngine.median(rhrHistory),
            quietHRSD: PersonalBaselineEngine.sampleStandardDeviation(rhrHistory),
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: PersonalBaselineEngine.median(hrvHistory),
            hrvSD: PersonalBaselineEngine.sampleStandardDeviation(hrvHistory),
            respRateToday: snapshot.respiratoryRate,
            respRateBaseline: PersonalBaselineEngine.median(respiratoryHistory),
            respRateSD: respiratorySD,
            bodyTempDelta: temperatureDelta,
            sleepScoreLastNight: sleep.value,
            strainScoreToday: strain.value,
            isWithinWorkoutWindow: isInsideWorkoutRecoveryWindow(
                snapshot: snapshot,
                asOf: asOf
            ),
            longTermQuietHRMedian: longTermBaselines?.baselines[.restingHeartRate]?.threeYearMedian
        ))

        let respiratoryRateZ: Double? = {
            guard let current = snapshot.respiratoryRate,
                  let baseline = PersonalBaselineEngine.median(respiratoryHistory),
                  let respiratorySD else { return nil }
            return (current - baseline) / respiratorySD
        }()
        let energy = EnergyBankEngine().calculate(from: EnergyBankInput(
            asOf: asOf,
            recoveryScore: recovery.value,
            sleepScore: sleep.value,
            strainScore: strain.value,
            stressIndex: physiologicalStress.value,
            hrvToday: snapshot.hrvAverage,
            hrvBaseline: PersonalBaselineEngine.median(hrvHistory),
            rhrToday: snapshot.restingHeartRate,
            rhrBaseline: PersonalBaselineEngine.median(rhrHistory),
            sleepHours: snapshot.sleepHours,
            strainHistory: dailyLoadHistory,
            todayLoad: strain.components["daily_load"],
            bodyTempDelta: temperatureDelta,
            hoursSinceWake: hoursSinceWake(snapshot: snapshot, asOf: asOf),
            respiratoryRateZ: respiratoryRateZ,
            SpO2: snapshot.oxygenSaturation,
            mindfulMinutes: nil,
            napMinutes: nil,
            trainingLoadStatus: strain.trainingLoadStatus
        ))

        return ScoredHealthEvidence(
            sleep: sleep,
            recovery: recovery,
            strain: strain,
            physiologicalStress: physiologicalStress,
            energy: energy
        )
    }

    private func evaluationDate(for snapshot: DailyHealthSnapshot) -> Date {
        if calendar.isDate(snapshot.date, inSameDayAs: now) {
            return now
        }
        let start = calendar.startOfDay(for: snapshot.date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return nextDay.addingTimeInterval(-1)
    }

    /// Layer 3：从三年长线报告提取 HRV 分布上下文（样本不足 60 天时返回 nil，不启用修正）。
    private func recoveryLongTermContext(from report: LongTermBaselineReport?) -> RecoveryLongTermContext? {
        guard let report,
              let hrvBaseline = report.baselines[.hrv],
              hrvBaseline.sampleCount >= 60 else { return nil }
        return RecoveryLongTermContext(
            hrvPercentile10: hrvBaseline.percentile10,
            hrvPercentile90: hrvBaseline.percentile90,
            hrvSampleCount: hrvBaseline.sampleCount
        )
    }

    private func personalBaselineHistory(
        for snapshot: DailyHealthSnapshot,
        from history: [DailyHealthSnapshot]
    ) -> [DailyHealthSnapshot] {
        let dayStart = calendar.startOfDay(for: snapshot.date)
        let earliest = calendar.date(byAdding: .day, value: -42, to: dayStart) ?? .distantPast
        return history
            .filter {
                let date = calendar.startOfDay(for: $0.date)
                return date >= earliest && date < dayStart
            }
            .sorted { $0.date > $1.date }
    }

    private func wristTemperatureDelta(
        current: Double?,
        history: [DailyHealthSnapshot]
    ) -> Double? {
        guard let current else { return nil }
        let samples = history.compactMap(\.wristTemperature)
        guard samples.count >= 5,
              let baseline = PersonalBaselineEngine.median(samples) else { return nil }
        return current - baseline
    }

    private func isInsideWorkoutRecoveryWindow(
        snapshot: DailyHealthSnapshot,
        asOf: Date
    ) -> Bool {
        guard calendar.isDate(snapshot.date, inSameDayAs: asOf) else { return false }
        return snapshot.workouts.contains { workout in
            asOf >= workout.start && asOf <= workout.end.addingTimeInterval(90 * 60)
        }
    }

    private func hoursSinceWake(
        snapshot: DailyHealthSnapshot,
        asOf: Date
    ) -> Double? {
        guard let wakeTime = snapshot.wakeTime, asOf >= wakeTime else { return nil }
        return max(0, min(24, asOf.timeIntervalSince(wakeTime) / 3_600))
    }
}
