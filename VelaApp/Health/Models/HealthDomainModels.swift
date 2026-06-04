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
    var activeMinutes: Double?
    var workoutCount: Int?
    var workoutTypes: String?
    var workoutDuration: Double?
    var bodyWeight: Double?
    var bodyFatPercent: Double?
    var bmi: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var dailyLoad: Double?
    var workoutLoad: Double?
    var activityLoad: Double?
    var trainingLoadRatio: Double?
    var atl: Double?
    var ctl: Double?
    var tsb: Double?
    var acwr: Double?
    var bedtime: Date?
    var wakeTime: Date?
    var awakeMinutes: Double?
    var awakeEpisodeCount: Int?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var workouts: [WorkoutSummary] = []
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

public struct WorkoutSummary: Identifiable, Codable, Hashable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var activityName: String
    public var energyKilocalories: Double?
    public var averageHeartRate: Double?
    public var distanceMeters: Double?
    public var source: String?
    public var rpe: Double?

    public init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        activityName: String,
        energyKilocalories: Double? = nil,
        averageHeartRate: Double? = nil,
        distanceMeters: Double? = nil,
        source: String? = nil,
        rpe: Double? = nil
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.activityName = activityName
        self.energyKilocalories = energyKilocalories
        self.averageHeartRate = averageHeartRate
        self.distanceMeters = distanceMeters
        self.source = source
        self.rpe = rpe
    }
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

struct HeartRateSample: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var bpm: Double
}

enum SleepHeartRateRangeResolver {
    static func range(for episodes: [SleepSummary], fallback: DateRangeQuery) -> DateRangeQuery {
        let candidates = episodes.compactMap { episode -> DateRangeQuery? in
            guard let start = episode.bedtime,
                  let end = episode.wakeTime,
                  end > start else {
                return nil
            }
            return DateRangeQuery(start: start, end: end)
        }
        return candidates.max { $0.end < $1.end } ?? fallback
    }
}

enum WorkoutHeartRateAverager {
    static func averageHeartRates(samples: [HeartRateSample], workouts: [WorkoutSummary]) -> [UUID: Double] {
        var result: [UUID: Double] = [:]
        for workout in workouts {
            let matching = samples.filter { sample in
                sample.date >= workout.start && sample.date <= workout.end
            }
            guard !matching.isEmpty else { continue }
            result[workout.id] = matching.map(\.bpm).reduce(0, +) / Double(matching.count)
        }
        return result
    }
}

struct BloodGlucoseReading: Identifiable, Codable, Hashable {
    var id = UUID()
    var date: Date
    var milligramsPerDeciliter: Double
}

struct RouteCoordinate: Identifiable, Codable, Hashable {
    var id = UUID()
    var latitude: Double
    var longitude: Double
}
