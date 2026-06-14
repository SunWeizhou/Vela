import Foundation

enum UserProfileSettings {
    static let ageKey = "vela_user_age"
    static let weightKey = "vela_user_weight"
    static let heightKey = "vela_user_height"
    static let maxHeartRateKey = "vela_max_hr"

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
        explicit: Double? = nil,
        wiki: Double? = nil,
        defaults: UserDefaults = .standard
    ) -> Double {
        explicit.flatMap(validatedMaxHeartRate)
            ?? maxHeartRate(defaults: defaults)
            ?? wiki.flatMap(validatedMaxHeartRate)
            ?? inferredMaxHeartRate(age: age)
    }

    private static func validatedMaxHeartRate(_ value: Double) -> Double? {
        (100...240).contains(value) ? value : nil
    }
}

/// Factory that builds each scoring engine's Input from a DailyHealthContext + historical data.
/// This extracts the input-building logic from DashboardSummary.healthKit().
enum ScoreEngineFactory {

    // MARK: - Sleep

    static func sleep(
        from context: DailyHealthContext,
        sleepTarget: Double,
        todayBedtime: Date?,
        recentBedtimes: [Date]
    ) -> SleepScoreInput {
        let awakeCount = context.sleepSummary?.segments.filter { $0.stage == .awake && $0.end.timeIntervalSince($0.start) >= 120 }.count
        return SleepScoreInput(
            totalSleepMinutes: context.sleepSummary.map { Double($0.totalSleepMinutes) },
            sleepTargetMinutes: sleepTarget,
            todayBedtime: todayBedtime ?? context.sleepSummary?.bedtime,
            recentBedtimes: recentBedtimes,
            awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
            awakeEpisodeCount: awakeCount,
            remMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
            deepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
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
            sleepScoreLastNight: sleepScore,
            strainScoreYesterday: strainScoreYesterday,
            respiratoryRateToday: context.recoveryMetrics.respiratoryRate,
            respiratoryRateBaseline: context.recoveryBaseline.respiratoryRate,
            respiratoryRateHistory: [],
            bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 },
            SpO2: context.extendedMetrics.oxygenSaturation
        )
    }

    // MARK: - Strain

    @MainActor
    static func strain(
        from context: DailyHealthContext,
        recoveryScore: Double,
        last28DaysDailyLoads: [Double],
        queryService: HealthQueryService,
        profileAge: Int? = nil,
        profileMaxHeartRate: Double? = nil
    ) async -> StrainScoreInput {
        var workoutInputs: [WorkoutInput] = []
        for workout in context.strainToday.workouts {
            let heartRateSamples = (try? await queryService.heartRateSamples(
                start: workout.start,
                end: workout.end
            )) ?? []
            workoutInputs.append(WorkoutInput(
                id: workout.id,
                durationMinutes: workout.end.timeIntervalSince(workout.start) / 60.0,
                averageHeartRate: workout.averageHeartRate,
                heartRateSamples: heartRateSamples.map(\.bpm),
                rpe: workout.rpe
            ))
        }
        let age = profileAge
            ?? UserProfileSettings.age()
            ?? WikiFileService.getAgeFromWiki()
            ?? context.extendedMetrics.age
            ?? 30
        let maxHeartRate = UserProfileSettings.resolvedMaxHeartRate(
            age: age,
            explicit: profileMaxHeartRate,
            wiki: WikiFileService.getMaxHeartRateFromWiki()
        )

        return StrainScoreInput(
            workouts: workoutInputs,
            activeEnergyToday: context.strainToday.activeEnergyKilocalories,
            exerciseMinutesToday: context.strainToday.exerciseMinutes,
            stepCount: context.strainToday.stepCount,
            restingHR: context.recoveryMetrics.restingHeartRate ?? 60.0,
            maxHR: maxHeartRate,
            biologicalSex: context.extendedMetrics.biologicalSex,
            last28DaysDailyLoads: last28DaysDailyLoads,
            recoveryScore: recoveryScore
        )
    }

    // MARK: - Stress

    static func stress(
        from context: DailyHealthContext,
        sleepScore: Double?,
        strainScore: Double,
        hrvHistory: [Double],
        rhrHistory: [Double]
    ) -> StressIndexInput {
        let quietHRSD = rhrHistory.isEmpty ? nil : Double(10)
        let hrvSD = hrvHistory.isEmpty ? nil : Double(15)
        
        let now = Date()
        let isWorkoutWindow = context.strainToday.workouts.contains { workout in
            now >= workout.start && now <= workout.end.addingTimeInterval(90.0 * 60.0)
        }
        
        return StressIndexInput(
            quietHRToday: context.recoveryMetrics.restingHeartRate,
            quietHRBaseline: context.recoveryBaseline.restingHeartRate,
            quietHRSD: quietHRSD,
            hrvToday: context.recoveryMetrics.hrvMilliseconds,
            hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
            hrvSD: hrvSD,
            respRateToday: context.recoveryMetrics.respiratoryRate,
            respRateBaseline: context.recoveryBaseline.respiratoryRate,
            respRateSD: nil,
            bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 },
            sleepScoreLastNight: sleepScore,
            strainScoreToday: strainScore,
            isWithinWorkoutWindow: isWorkoutWindow
        )
    }

    // MARK: - Energy Bank

    static func energyBank(
        from context: DailyHealthContext,
        recoveryScore: Double,
        sleepScore: Double?,
        strainScore: Double,
        stressIndex: Double,
        strainHistory: [Double]?,
        trainingLoadStatus: TrainingLoadStatus? = nil
    ) -> EnergyBankInput {
        let now = Date()
        let wake = context.sleepSummary?.wakeTime ?? Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: now) ?? now
        let hoursSinceWake = max(0.0, min(24.0, now.timeIntervalSince(wake) / 3600.0))

        return EnergyBankInput(
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
            bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 },
            hoursSinceWake: hoursSinceWake,
            respiratoryRateZ: nil,
            SpO2: context.extendedMetrics.oxygenSaturation,
            mindfulMinutes: context.extendedMetrics.mindfulMinutes,
            napMinutes: nil,
            trainingLoadStatus: trainingLoadStatus
        )
    }

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
