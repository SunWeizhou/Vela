import Foundation
import SwiftData

struct TrainingAnalyticsService: Sendable {
    
    init() {}

    func summarizeWorkout(
        _ workout: StrengthWorkoutRecord,
        history: [StrengthWorkoutRecord] = [],
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> StrengthWorkoutAnalysis {
        var volume = 0.0
        var sets = 0
        var effectiveSets = 0
        var reps = 0
        var muscleGroupSets: [String: Int] = [:]
        var muscleGroupVolume: [String: Double] = [:]
        var e1RM: [String: Double] = [:]

        for exercise in workout.exercises {
            let muscle = resolvedMuscleGroup(for: exercise, library: exerciseLibrary)
            for set in exercise.sets {
                sets += 1
                reps += set.repetitions
                let setVolume = set.volumeKilograms
                volume += setVolume
                guard isEffective(set, equipment: exercise.equipment) else { continue }
                effectiveSets += 1
                muscleGroupSets[muscle, default: 0] += 1
                muscleGroupVolume[muscle, default: 0] += setVolume
                if set.repetitions >= 1, set.repetitions <= 12, set.weightKilograms > 0 {
                    let value = set.weightKilograms * (1 + Double(set.repetitions) / 30)
                    e1RM[exercise.name] = max(e1RM[exercise.name] ?? 0, value)
                }
            }
        }

        let records = detectPersonalRecords(workout: workout, history: history)
        let density = workout.durationMinutes > 0 ? volume / Double(workout.durationMinutes) : 0
        let muscleText = muscleGroupSets.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ")
        let summary = "\(workout.title): \(effectiveSets) effective sets, \(Int(volume.rounded())) kg\(muscleText.isEmpty ? "" : ", \(muscleText)")"
        return StrengthWorkoutAnalysis(
            totalVolumeKg: volume,
            totalSets: sets,
            effectiveSets: effectiveSets,
            totalReps: reps,
            muscleGroupSets: muscleGroupSets,
            muscleGroupVolume: muscleGroupVolume,
            estimatedOneRepMaxByExercise: e1RM,
            personalRecords: records,
            densityKgPerMinute: density,
            summaryText: summary
        )
    }

    func detectPersonalRecords(workout: StrengthWorkoutRecord, history: [StrengthWorkoutRecord]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        for exercise in workout.exercises {
            let workSets = exercise.sets.filter { !$0.isWarmup }
            guard let maxWeight = workSets.map(\.weightKilograms).max(), !workSets.isEmpty else { continue }
            let maxE1RM = workSets
                .filter { $0.weightKilograms > 0 && $0.repetitions >= 1 && $0.repetitions <= 12 }
                .map { $0.weightKilograms * (1 + Double($0.repetitions) / 30) }
                .max() ?? 0
            let priorSets = history.flatMap(\.exercises).filter { namesMatch($0.name, exercise.name) }.flatMap(\.sets).filter { !$0.isWarmup }
            guard !priorSets.isEmpty else { continue }
            let priorMaxWeight = priorSets.map(\.weightKilograms).max() ?? 0
            let priorMaxE1RM = priorSets
                .filter { $0.weightKilograms > 0 && $0.repetitions >= 1 && $0.repetitions <= 12 }
                .map { $0.weightKilograms * (1 + Double($0.repetitions) / 30) }
                .max() ?? 0
            if maxWeight > priorMaxWeight {
                records.append(PersonalRecord(exerciseName: exercise.name, kind: "max_weight", value: maxWeight, previousValue: priorMaxWeight))
            }
            if maxE1RM > priorMaxE1RM {
                records.append(PersonalRecord(exerciseName: exercise.name, kind: "estimated_1rm", value: maxE1RM, previousValue: priorMaxE1RM))
            }
        }
        return records
    }

    func buildRecentSummary(
        workouts: [StrengthWorkoutRecord],
        days: Int,
        endingAt: Date = Date(),
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> RecentTrainingSummary {
        let start = endingAt.addingTimeInterval(-Double(days) * 86_400)
        let recent = workouts.filter { $0.startedAt >= start && $0.startedAt <= endingAt }
        guard !recent.isEmpty else { return .empty(days: days) }
        var totalSets = 0
        var totalVolume = 0.0
        var muscles: [String: Int] = [:]
        var records: [PersonalRecord] = []
        for workout in recent {
            let prior = workouts.filter { $0.startedAt < workout.startedAt }
            let analysis = summarizeWorkout(workout, history: prior, exerciseLibrary: exerciseLibrary)
            totalSets += analysis.effectiveSets
            totalVolume += analysis.totalVolumeKg
            records.append(contentsOf: analysis.personalRecords)
            for (muscle, count) in analysis.muscleGroupSets {
                muscles[muscle, default: 0] += count
            }
        }
        let latest = recent.max { $0.startedAt < $1.startedAt }
        return RecentTrainingSummary(
            days: days,
            sessions: recent.count,
            effectiveSets: totalSets,
            volumeKg: totalVolume,
            muscleGroupSets: muscles,
            recentPRs: records,
            lastWorkoutSummary: latest.map { latestWorkout in
                summarizeWorkout(
                    latestWorkout,
                    history: workouts.filter { $0.startedAt < latestWorkout.startedAt },
                    exerciseLibrary: exerciseLibrary
                ).summaryText
            },
            localFatigue: computeLocalFatigue(workouts: workouts, endingAt: endingAt, exerciseLibrary: exerciseLibrary)
        )
    }

    func computeLocalFatigue(
        workouts: [StrengthWorkoutRecord],
        endingAt: Date = Date(),
        exerciseLibrary: [ExerciseDefinitionRecord] = ExerciseLibraryService.defaultDefinitions()
    ) -> [String: LocalMuscleFatigue] {
        let start7d = endingAt.addingTimeInterval(-7 * 86_400)
        let start48h = endingAt.addingTimeInterval(-48 * 3_600)
        var result: [String: LocalMuscleFatigue] = [:]
        for workout in workouts where workout.startedAt >= start7d && workout.startedAt <= endingAt {
            for exercise in workout.exercises {
                let muscle = resolvedMuscleGroup(for: exercise, library: exerciseLibrary)
                for set in exercise.sets where isEffective(set, equipment: exercise.equipment) {
                    var fatigue = result[muscle] ?? LocalMuscleFatigue(muscleGroup: muscle, setsLast48h: 0, setsLast7d: 0, volumeLast7d: 0)
                    if workout.startedAt >= start48h { fatigue.setsLast48h += 1 }
                    fatigue.setsLast7d += 1
                    fatigue.volumeLast7d += set.volumeKilograms
                    result[muscle] = fatigue
                }
            }
        }
        return result
    }

    private func isEffective(_ set: StrengthSetLog, equipment: String) -> Bool {
        guard !set.isWarmup, set.repetitions >= 3 else { return false }
        let supportsBodyweight = equipment.lowercased().contains("bodyweight") || equipment.contains("自重")
        guard set.weightKilograms > 0 || supportsBodyweight else { return false }
        if let rpe = set.rpe, rpe < 6 { return false }
        if let rir = set.rir, rir > 4 { return false }
        return true
    }

    private func resolvedMuscleGroup(for exercise: StrengthExerciseLog, library: [ExerciseDefinitionRecord]) -> String {
        if let explicit = exercise.primaryMuscleGroup, !explicit.isEmpty { return explicit }
        if let canonicalKey = exercise.exerciseCanonicalKey,
           let definition = library.first(where: { $0.canonicalKey == canonicalKey }) {
            return definition.primaryMuscleGroup
        }
        if let definition = library.first(where: { namesMatch($0.name, exercise.name) || $0.aliases.contains(where: { namesMatch($0, exercise.name) }) }) {
            return definition.primaryMuscleGroup
        }
        let name = exercise.name.lowercased()
        if name.contains("bench") || name.contains("卧推") || name.contains("夹胸") { return "chest" }
        if name.contains("row") || name.contains("划船") || name.contains("下拉") || name.contains("引体") { return "back" }
        if name.contains("squat") || name.contains("深蹲") || name.contains("腿") { return "quads" }
        if name.contains("curl") || name.contains("弯举") { return "biceps" }
        if name.contains("press") || name.contains("推举") || name.contains("侧平举") { return "shoulders" }
        if name.contains("plank") || name.contains("卷腹") { return "core" }
        return "other"
    }

    private func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == rhs.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
