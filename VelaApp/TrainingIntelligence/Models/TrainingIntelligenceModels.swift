import Foundation

/// Sendable value-type mirror of `ExerciseDefinitionRecord`, used by the training
/// kernels when they run off the main actor (a `@Model` class cannot cross the
/// actor boundary). The default library is derived from the same spec as the
/// SwiftData-backed `ExerciseLibraryService.defaultDefinitions()`.
struct ExerciseDefinition: Codable, Hashable, Sendable {
    var id: UUID
    var canonicalKey: String
    var name: String
    var aliases: [String]
    var primaryMuscleGroup: String
    var secondaryMuscleGroups: [String]
    var equipment: String
    var movementPattern: String
}

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
        let formattedValue = value.formatted(.number.precision(.fractionLength(0...1)))
        if AppLanguage.stored.isChinese {
            switch kind {
            case "max_weight":
                return "\(exerciseName) 重量新高：\(formattedValue) kg"
            case "estimated_1rm":
                return "\(exerciseName) 估算最大重量新高：\(formattedValue) kg"
            case "max_reps":
                return "\(exerciseName) 次数新高：\(formattedValue) 次"
            default:
                return "\(exerciseName)：\(formattedValue)"
            }
        }

        let unit = kind == "max_reps" ? " reps" : " kg"
        return "\(exerciseName) \(kind): \(formattedValue)\(unit)"
    }
}

extension PersonalRecord {
    /// 聚合一段时间内的 PR：同一动作 + 同一类型只保留数值最高的一条；
    /// 若多条数值相同，保留带 previousValue（即「打破前纪录」）的那条。
    static func bestRecords(from records: [PersonalRecord]) -> [PersonalRecord] {
        var bestByKey: [String: PersonalRecord] = [:]
        for record in records {
            let key = "\(record.exerciseName)|\(record.kind)"
            guard let existing = bestByKey[key] else {
                bestByKey[key] = record
                continue
            }
            if record.value > existing.value {
                bestByKey[key] = record
            } else if record.value == existing.value,
                      existing.previousValue == nil,
                      record.previousValue != nil {
                bestByKey[key] = record
            }
        }
        return Array(bestByKey.values)
            .sorted {
                if $0.exerciseName == $1.exerciseName {
                    return $0.kind < $1.kind
                }
                return $0.exerciseName < $1.exerciseName
            }
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
        if setsLast48h >= 14 || setsLast7d >= 24 { return "high" }
        if setsLast48h >= 8 || setsLast7d >= 14 { return "moderate" }
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
    var plannedSets: Int
    var completedSets: Int
    var uncompletedSets: Int
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
        plannedSets: Int? = nil,
        completedSets: Int? = nil,
        uncompletedSets: Int? = nil,
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
        self.plannedSets = plannedSets ?? totalSets
        self.completedSets = completedSets ?? totalSets
        self.uncompletedSets = uncompletedSets ?? max(0, (plannedSets ?? totalSets) - (completedSets ?? totalSets))
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
