import Foundation

struct DailyHealthSnapshot: Identifiable, Hashable {
    let id = UUID()
    var date: Date
    var createdAt: Date = Date()
    var sleepScore: Double?
    var recoveryScore: Double?
    var strainScore: Double?
    var stressIndex: Double?
    var morningEnergy: Double?
    var currentEnergy: Double?
    var energyBank: Double?
    // Raw metrics for historical trend analysis
    var healthAge: Double?
    var hrvAverage: Double?
    var restingHeartRate: Double?
    var sleepHours: Double?
    var deepSleepPercent: Double?
    var remSleepPercent: Double?
    var sleepEfficiency: Double?
    var steps: Double?
    var activeCalories: Double?
    var workoutCount: Int?
    var workoutTypes: String?
    var workoutDuration: Double?
    var bodyWeight: Double?
    var bodyFatPercent: Double?
    var bmi: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
}

enum SleepStage: String, Codable, Hashable, CaseIterable {
    case awake
    case rem
    case core
    case deep
    case asleep
    case inBed

    var countsTowardSleepDuration: Bool {
        switch self {
        case .rem, .core, .deep, .asleep:
            return true
        case .awake, .inBed:
            return false
        }
    }
}

struct SleepStageSegment: Identifiable, Codable, Hashable {
    var id = UUID()
    var stage: SleepStage
    var start: Date
    var end: Date

    var durationMinutes: Int {
        max(Int(end.timeIntervalSince(start) / 60), 0)
    }
}

struct SleepSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var totalSleepMinutes: Int
    var bedtime: Date?
    var wakeTime: Date?
    var stageMinutes: [SleepStage: Int]
    var segments: [SleepStageSegment]
    var sleepScore: Double?
}

struct RecoveryMetricSummary: Codable, Hashable {
    var hrvMilliseconds: Double?
    var restingHeartRate: Double?
    var sleepHeartRate: Double?
    var respiratoryRate: Double?
}

struct StrainActivitySummary: Codable, Hashable {
    var activeEnergyKilocalories: Double?
    var exerciseMinutes: Double?
    var stepCount: Double?
    var workouts: [WorkoutSummary]
}

struct WorkoutSummary: Identifiable, Codable, Hashable {
    var id = UUID()
    var start: Date
    var end: Date
    var activityName: String
    var energyKilocalories: Double?
    var averageHeartRate: Double?
    var distanceMeters: Double?
}

struct BodyMetricsSummary: Codable, Hashable {
    var vo2Max: Double?
    var weightKilograms: Double?
    var bodyFatPercentage: Double?
    var leanBodyMassKilograms: Double?
}

/// Extended metrics gathered from the full HealthKit catalog
struct ExtendedHealthMetrics: Codable, Hashable {
    // Personal characteristics (from HKCharacteristicType)
    var age: Int?
    var biologicalSex: String?         // "male" / "female" / "other"
    var heightCm: Double?
    var bmi: Double?

    // Cardiovascular advanced
    var walkingHeartRateAvg: Double?    // bpm
    var oxygenSaturation: Double?      // 0-100 %
    var bloodPressureSystolic: Double?  // mmHg
    var bloodPressureDiastolic: Double? // mmHg

    // Metabolic
    var bloodGlucose: Double?          // mg/dL

    // Mobility & gait
    var walkingSpeed: Double?          // m/s
    var walkingStepLength: Double?     // m
    var walkingAsymmetry: Double?      // % (0-100)
    var walkingDoubleSupport: Double?  // % (0-100)
    var walkingSteadiness: Double?     // % (0-100)
    var stairAscentSpeed: Double?      // m/s
    var stairDescentSpeed: Double?     // m/s
    var sixMinuteWalkDistance: Double?  // meters

    // Activity totals
    var exerciseMinutes: Int?
    var standMinutes: Int?
    var flightsClimbed: Int?
    var distanceKm: Double?
    var cyclingDistanceKm: Double?

    // Environment
    var environmentalNoisedB: Double?
    var headphoneNoisedB: Double?
    var timeInDaylight: Double?        // minutes

    // Temperature
    var bodyTemperature: Double?       // °C

    // Nutrition
    var waterMl: Double?
    var caffeineMg: Double?
    var dietaryEnergyKcal: Double?
    var dietaryProteinG: Double?
    var dietaryCarbsG: Double?
    var dietaryFatG: Double?

    // Wellness
    var mindfulMinutes: Double?
    var sleepBreathingDisturbances: Double? // events/night
}
