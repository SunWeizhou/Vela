import Foundation

struct PersonalRecord: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var exerciseName: String
    var kind: String
    var value: Double
    var previousValue: Double?

    init(exerciseName: String, kind: String, value: Double, previousValue: Double? = nil) {
        self.exerciseName = exerciseName
        self.kind = kind
        self.value = value
        self.previousValue = previousValue
    }

    var summary: String {
        let unit = kind == "max_reps" ? " reps" : " kg"
        return "\(exerciseName) \(kind): \(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)"
    }
}

struct LocalMuscleFatigue: Codable, Hashable, Sendable {
    var muscleGroup: String
    var setsLast48h: Int
    var setsLast7d: Int
    var volumeLast7d: Double

    init(muscleGroup: String, setsLast48h: Int, setsLast7d: Int, volumeLast7d: Double) {
        self.muscleGroup = muscleGroup
        self.setsLast48h = setsLast48h
        self.setsLast7d = setsLast7d
        self.volumeLast7d = volumeLast7d
    }

    var fatigueLevel: String {
        if setsLast48h >= 8 || setsLast7d >= 18 { return "high" }
        if setsLast48h >= 4 || setsLast7d >= 12 { return "moderate" }
        return "low"
    }

    var recommendation: String {
        switch fatigueLevel {
        case "high": return AppLanguage.stored.isChinese ? "今天应避免针对该肌群的高容量训练。" : "Avoid high-volume work for this muscle group today."
        case "moderate": return AppLanguage.stored.isChinese ? "控制训练容量，避免力竭组。" : "Keep volume controlled and avoid failure sets."
        default: return AppLanguage.stored.isChinese ? "生理信号允许时即可开始训练。" : "Available for training if recovery signals permit."
        }
    }
}

struct StrengthWorkoutAnalysis: Codable, Hashable, Sendable {
    var totalVolumeKg: Double
    var totalSets: Int
    var effectiveSets: Int
    var totalReps: Int
    var muscleGroupSets: [String: Int]
    var muscleGroupVolume: [String: Double]
    var estimatedOneRepMaxByExercise: [String: Double]
    var personalRecords: [PersonalRecord]
    var densityKgPerMinute: Double
    var summaryText: String

    init(
        totalVolumeKg: Double,
        totalSets: Int,
        effectiveSets: Int,
        totalReps: Int,
        muscleGroupSets: [String: Int],
        muscleGroupVolume: [String: Double],
        estimatedOneRepMaxByExercise: [String: Double],
        personalRecords: [PersonalRecord],
        densityKgPerMinute: Double,
        summaryText: String
    ) {
        self.totalVolumeKg = totalVolumeKg
        self.totalSets = totalSets
        self.effectiveSets = effectiveSets
        self.totalReps = totalReps
        self.muscleGroupSets = muscleGroupSets
        self.muscleGroupVolume = muscleGroupVolume
        self.estimatedOneRepMaxByExercise = estimatedOneRepMaxByExercise
        self.personalRecords = personalRecords
        self.densityKgPerMinute = densityKgPerMinute
        self.summaryText = summaryText
    }
}

struct RecentTrainingSummary: Codable, Hashable, Sendable {
    var days: Int
    var sessions: Int
    var effectiveSets: Int
    var volumeKg: Double
    var muscleGroupSets: [String: Int]
    var recentPRs: [PersonalRecord]
    var lastWorkoutSummary: String?
    var localFatigue: [String: LocalMuscleFatigue]

    init(
        days: Int,
        sessions: Int,
        effectiveSets: Int,
        volumeKg: Double,
        muscleGroupSets: [String: Int],
        recentPRs: [PersonalRecord],
        lastWorkoutSummary: String? = nil,
        localFatigue: [String: LocalMuscleFatigue] = [:]
    ) {
        self.days = days
        self.sessions = sessions
        self.effectiveSets = effectiveSets
        self.volumeKg = volumeKg
        self.muscleGroupSets = muscleGroupSets
        self.recentPRs = recentPRs
        self.lastWorkoutSummary = lastWorkoutSummary
        self.localFatigue = localFatigue
    }

    static func empty(days: Int = 7) -> RecentTrainingSummary {
        RecentTrainingSummary(
            days: days,
            sessions: 0,
            effectiveSets: 0,
            volumeKg: 0,
            muscleGroupSets: [:],
            recentPRs: [],
            lastWorkoutSummary: nil,
            localFatigue: [:]
        )
    }
}

struct RecoveryTrainingInput: Codable, Hashable, Sendable {
    var recoveryScore: Double
    var sleepScore: Double
    var hrvZScore: Double?
    var restingHRZScore: Double?
    var tsb: Double?
    var energyScore: Double?
    var localFatigue: [String: LocalMuscleFatigue] = [:]
    var plannedFocus: String?

    init(
        recoveryScore: Double,
        sleepScore: Double,
        hrvZScore: Double? = nil,
        restingHRZScore: Double? = nil,
        tsb: Double? = nil,
        energyScore: Double? = nil,
        localFatigue: [String: LocalMuscleFatigue] = [:],
        plannedFocus: String? = nil
    ) {
        self.recoveryScore = recoveryScore
        self.sleepScore = sleepScore
        self.hrvZScore = hrvZScore
        self.restingHRZScore = restingHRZScore
        self.tsb = tsb
        self.energyScore = energyScore
        self.localFatigue = localFatigue
        self.plannedFocus = plannedFocus
    }
}

struct TrainingAdaptationRecommendation: Codable, Hashable, Sendable {
    var readinessLevel: String
    var shouldTrain: Bool
    var recommendedIntensity: String
    var volumeMultiplier: Double
    var suggestedFocus: String
    var avoidMuscleGroups: [String]
    var preferredMuscleGroups: [String]
    var reasons: [String]
    var modifiedWorkoutDescription: String

    init(
        readinessLevel: String,
        shouldTrain: Bool,
        recommendedIntensity: String,
        volumeMultiplier: Double,
        suggestedFocus: String,
        avoidMuscleGroups: [String],
        preferredMuscleGroups: [String],
        reasons: [String],
        modifiedWorkoutDescription: String
    ) {
        self.readinessLevel = readinessLevel
        self.shouldTrain = shouldTrain
        self.recommendedIntensity = recommendedIntensity
        self.volumeMultiplier = volumeMultiplier
        self.suggestedFocus = suggestedFocus
        self.avoidMuscleGroups = avoidMuscleGroups
        self.preferredMuscleGroups = preferredMuscleGroups
        self.reasons = reasons
        self.modifiedWorkoutDescription = modifiedWorkoutDescription
    }
}
