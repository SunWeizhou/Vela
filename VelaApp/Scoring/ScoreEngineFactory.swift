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

    static func hydrateMissingValuesFromHealth(
        age: Int?,
        weightKilograms: Double?,
        heightCentimeters: Double?,
        biologicalSex: String?,
        defaults: UserDefaults = .standard
    ) {
        if Self.age(defaults: defaults) == nil,
           let age,
           (10...100).contains(age) {
            defaults.set(age, forKey: ageKey)
        }
        if Self.weightKilograms(defaults: defaults) == nil,
           let weightKilograms,
           (25...350).contains(weightKilograms) {
            defaults.set(weightKilograms, forKey: weightKey)
        }
        if Self.heightCentimeters(defaults: defaults) == nil,
           let heightCentimeters,
           (100...250).contains(heightCentimeters) {
            defaults.set(heightCentimeters, forKey: heightKey)
        }
        if Self.biologicalSex(defaults: defaults) == nil,
           let biologicalSex,
           ["male", "female", "other"].contains(biologicalSex) {
            defaults.set(biologicalSex, forKey: biologicalSexKey)
        }
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
