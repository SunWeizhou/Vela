import Foundation
import SwiftData

/// Manages adaptive adjustments to training plans based on daily readiness.
enum AdaptiveTrainingEngine {

    enum Adjustment: String, Codable, Hashable {
        case keep
        case reduce
        case swap
        case rest
        case reschedule
        case deloadWeek
    }

    struct AdjustedDay: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var originalDay: TrainingDay
        var adjustment: Adjustment
        var reason: String
        var suggestedAlternative: String?
    }

    /// Computes the appropriate adjustment for today's training step
    /// based on the user's physiological readiness.
    static func adjustToday(
        plan: TrainingPlanRecord,
        recoveryScore: Double,
        energyScore: Double,
        tsb: Double,
        sleepScore: Double,
        stressIndex: Double
    ) -> AdjustedDay? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayNumber = weekday == 1 ? 7 : weekday - 1

        guard let todayStep = plan.days.first(where: {
            !$0.isCompleted && $0.dayNumber == dayNumber
        }) else {
            return nil
        }

        let adjustment: Adjustment
        let reason: String
        let alternative: String?

        // Recovery-gated decision tree
        if recoveryScore > 75 && energyScore > 60 && tsb > 5 && sleepScore > 80 {
            adjustment = .keep
            reason = "All readiness indicators are optimal. Stick to the plan."
            alternative = nil
        } else if recoveryScore > 50 && energyScore > 40 && tsb > -5 {
            adjustment = .reduce
            reason = "Recovery is moderate. Reduce intensity by 30-40%."
            alternative = buildReducedVersion(of: todayStep)
        } else if recoveryScore > 30 {
            adjustment = .swap
            reason = "Recovery is low. Swap to active recovery today."
            alternative = buildRecoveryAlternative(for: todayStep)
        } else {
            adjustment = .rest
            reason = "Recovery is critically low. Full rest day recommended."
            alternative = nil
        }

        // TSB override: if TSB < -15, always reduce regardless of recovery
        let finalAdjustment: Adjustment
        let finalReason: String
        if tsb < -15 && adjustment == .keep {
            finalAdjustment = .reduce
            finalReason = "TSB is deeply negative (-\(Int(abs(tsb)))). High accumulated fatigue requires reduced load."
        } else if tsb > 10 && adjustment == .reduce {
            finalAdjustment = .keep
            finalReason = "TSB is positive (+\(Int(tsb))). Despite moderate recovery, your chronic fitness allows normal training."
        } else {
            finalAdjustment = adjustment
            finalReason = reason
        }

        return AdjustedDay(
            originalDay: todayStep,
            adjustment: finalAdjustment,
            reason: finalReason,
            suggestedAlternative: finalAdjustment == .keep ? nil : alternative
        )
    }

    /// Per-day adjustment using BodyInterpretation. Used by generateWeekAdjustments
    /// to evaluate each future day independently against the body's current state.
    static func adjust(
        day: TrainingDay,
        interpretation: BodyInterpretation
    ) -> AdjustedDay? {
        let fatigueLevel = interpretation.fatigueLevel

        // Skip rest days — no adjustment needed
        guard day.focus != "rest" else { return nil }

        let adjustment: Adjustment
        let reason: String
        let alternative: String?

        switch (fatigueLevel, interpretation.trainingWindow.isOpen) {
        case (.none, true):
            adjustment = .keep
            reason = "All readiness indicators are optimal."
            alternative = nil
        case (.mild, true):
            if day.intensity == "high" {
                adjustment = .reduce
                reason = "Mild fatigue detected. Reducing high-intensity session."
                alternative = buildReducedVersion(of: day)
            } else {
                adjustment = .keep
                reason = "Mild fatigue but session intensity is appropriate."
                alternative = nil
            }
        case (.moderate, _):
            if day.focus == "strength" || day.focus == "cardio" {
                adjustment = .swap
                reason = "Moderate fatigue. Swapping to active recovery."
                alternative = buildRecoveryAlternative(for: day)
            } else {
                adjustment = .reduce
                reason = "Moderate fatigue. Reducing intensity."
                alternative = buildReducedVersion(of: day)
            }
        case (.significant, _):
            adjustment = .rest
            reason = "Significant fatigue. Rest day recommended."
            alternative = nil
        case (.severe, _):
            adjustment = .deloadWeek
            reason = "Severe fatigue detected. Deload week recommended."
            alternative = "Light stretching or 20 min walk"
        case (_, false) where !interpretation.trainingWindow.isOpen:
            adjustment = .rest
            reason = "Training window is closed."
            alternative = nil
        default:
            adjustment = .keep
            reason = "No significant issues detected."
            alternative = nil
        }

        return AdjustedDay(
            originalDay: day,
            adjustment: adjustment,
            reason: reason,
            suggestedAlternative: adjustment == .keep ? nil : alternative
        )
    }

    // MARK: - Helpers

    private static func buildReducedVersion(of day: TrainingDay) -> String? {
        let reducedDuration = max(15, day.durationMinutes * 60 / 100) // 60% of original
        let reducedIntensity = day.intensity == "high" ? "moderate" : "low"
        return "\(day.title) (reduced): \(reducedDuration) min at \(reducedIntensity) intensity"
    }

    private static func buildRecoveryAlternative(for day: TrainingDay) -> String? {
        switch day.focus {
        case "strength":
            return "Bodyweight mobility routine: 20 min foam rolling + dynamic stretching"
        case "cardio":
            return "Light walk: 20-30 min at Zone 1, focusing on nasal breathing"
        case "flexibility":
            return "Keep flexibility session but reduce hold times to 30s"
        default:
            return "Yoga or stretching: 20 min gentle flow"
        }
    }
}

// MARK: - Training Intelligence

struct PersonalRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    var exerciseName: String
    var kind: String
    var value: Double
    var previousValue: Double?

    var summary: String {
        let unit = kind == "max_reps" ? " reps" : " kg"
        return "\(exerciseName) \(kind): \(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)"
    }
}

struct LocalMuscleFatigue: Codable, Hashable {
    var muscleGroup: String
    var setsLast48h: Int
    var setsLast7d: Int
    var volumeLast7d: Double

    var fatigueLevel: String {
        if setsLast48h >= 8 || setsLast7d >= 18 { return "high" }
        if setsLast48h >= 4 || setsLast7d >= 12 { return "moderate" }
        return "low"
    }

    var recommendation: String {
        switch fatigueLevel {
        case "high": return "Avoid high-volume work for this muscle group today."
        case "moderate": return "Keep volume controlled and avoid failure sets."
        default: return "Available for training if recovery signals permit."
        }
    }
}

struct StrengthWorkoutAnalysis: Codable, Hashable {
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
}

struct RecentTrainingSummary: Codable, Hashable {
    var days: Int
    var sessions: Int
    var effectiveSets: Int
    var volumeKg: Double
    var muscleGroupSets: [String: Int]
    var recentPRs: [PersonalRecord]
    var lastWorkoutSummary: String?
    var localFatigue: [String: LocalMuscleFatigue]

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

enum ExerciseLibraryService {
    static func defaultDefinitions() -> [ExerciseDefinitionRecord] {
        [
            exercise("杠铃卧推", ["bench press", "卧推"], "chest", ["triceps", "shoulders"], "barbell", "push"),
            exercise("哑铃卧推", ["dumbbell bench press"], "chest", ["triceps"], "dumbbell", "push"),
            exercise("上斜卧推", ["incline press"], "chest", ["shoulders", "triceps"], "barbell", "push"),
            exercise("双杠臂屈伸", ["dip"], "chest", ["triceps"], "bodyweight", "push"),
            exercise("绳索夹胸", ["cable fly"], "chest", [], "cable", "isolation"),
            exercise("器械推胸", ["chest press"], "chest", ["triceps"], "machine", "push"),
            exercise("引体向上", ["pull up", "pullup"], "back", ["biceps"], "bodyweight", "pull"),
            exercise("高位下拉", ["lat pulldown"], "back", ["biceps"], "cable", "pull"),
            exercise("杠铃划船", ["barbell row"], "back", ["biceps"], "barbell", "pull"),
            exercise("坐姿划船", ["seated row"], "back", ["biceps"], "cable", "pull"),
            exercise("单臂哑铃划船", ["one arm dumbbell row"], "back", ["biceps"], "dumbbell", "pull"),
            exercise("硬拉", ["deadlift"], "back", ["glutes", "hamstrings"], "barbell", "hinge"),
            exercise("深蹲", ["squat"], "quads", ["glutes", "hamstrings"], "barbell", "squat"),
            exercise("腿举", ["leg press"], "quads", ["glutes"], "machine", "squat"),
            exercise("罗马尼亚硬拉", ["romanian deadlift", "rdl"], "hamstrings", ["glutes"], "barbell", "hinge"),
            exercise("腿屈伸", ["leg extension"], "quads", [], "machine", "isolation"),
            exercise("腿弯举", ["leg curl"], "hamstrings", [], "machine", "isolation"),
            exercise("保加利亚分腿蹲", ["bulgarian split squat"], "quads", ["glutes"], "dumbbell", "lunge"),
            exercise("臀推", ["hip thrust", "臀桥"], "glutes", ["hamstrings"], "barbell", "hinge"),
            exercise("推举", ["overhead press", "shoulder press"], "shoulders", ["triceps"], "barbell", "push"),
            exercise("哑铃侧平举", ["lateral raise"], "shoulders", [], "dumbbell", "isolation"),
            exercise("俯身飞鸟", ["rear delt fly"], "shoulders", [], "dumbbell", "isolation"),
            exercise("面拉", ["face pull"], "shoulders", ["back"], "cable", "pull"),
            exercise("阿诺德推举", ["arnold press"], "shoulders", ["triceps"], "dumbbell", "push"),
            exercise("杠铃弯举", ["barbell curl"], "biceps", [], "barbell", "isolation"),
            exercise("哑铃弯举", ["dumbbell curl"], "biceps", [], "dumbbell", "isolation"),
            exercise("绳索下压", ["triceps pushdown"], "triceps", [], "cable", "isolation"),
            exercise("窄距卧推", ["close grip bench press"], "triceps", ["chest"], "barbell", "push"),
            exercise("臂屈伸", ["triceps extension"], "triceps", [], "bodyweight", "isolation"),
            exercise("卷腹", ["crunch"], "core", [], "bodyweight", "core"),
            exercise("悬垂举腿", ["hanging leg raise"], "core", [], "bodyweight", "core"),
            exercise("平板支撑", ["plank"], "core", [], "bodyweight", "core"),
            exercise("Pallof Press", ["pallof"], "core", [], "cable", "core")
        ]
    }

    static func search(_ query: String, in library: [ExerciseDefinitionRecord]) -> [ExerciseDefinitionRecord] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return library }
        return library.filter { definition in
            definition.name.lowercased().contains(needle)
                || definition.aliases.contains { $0.lowercased().contains(needle) }
                || definition.primaryMuscleGroup.lowercased().contains(needle)
        }
    }

    static func defaultTemplates() -> [WorkoutTemplateRecord] {
        [
            template("Push Day", ["杠铃卧推", "推举", "绳索下压"]),
            template("Pull Day", ["高位下拉", "杠铃划船", "杠铃弯举"]),
            template("Leg Day", ["深蹲", "罗马尼亚硬拉", "腿举"]),
            template("Upper Body", ["杠铃卧推", "高位下拉", "推举", "坐姿划船"]),
            template("Lower Body", ["深蹲", "罗马尼亚硬拉", "腿弯举"]),
            template("Full Body", ["深蹲", "杠铃卧推", "杠铃划船"])
        ]
    }

    @MainActor
    static func seedDefaultsIfNeeded(modelContext: ModelContext) throws {
        let existingDefinitions = try modelContext.fetch(FetchDescriptor<ExerciseDefinitionRecord>())
        let existingNames = Set(existingDefinitions.map(\.name))
        for definition in defaultDefinitions() where !existingNames.contains(definition.name) {
            modelContext.insert(definition)
        }

        let existingTemplates = try modelContext.fetch(FetchDescriptor<WorkoutTemplateRecord>())
        let existingTitles = Set(existingTemplates.map(\.title))
        for template in defaultTemplates() where !existingTitles.contains(template.title) {
            modelContext.insert(template)
        }
        try modelContext.save()
    }

    private static func exercise(
        _ name: String,
        _ aliases: [String],
        _ primary: String,
        _ secondary: [String],
        _ equipment: String,
        _ pattern: String
    ) -> ExerciseDefinitionRecord {
        ExerciseDefinitionRecord(
            name: name,
            aliases: aliases,
            primaryMuscleGroup: primary,
            secondaryMuscleGroups: secondary,
            equipment: equipment,
            movementPattern: pattern
        )
    }

    private static func template(_ title: String, _ exerciseNames: [String]) -> WorkoutTemplateRecord {
        WorkoutTemplateRecord(
            title: title,
            goal: "hypertrophy",
            exercises: exerciseNames.map {
                WorkoutTemplateExercise(name: $0, targetSets: 3, targetReps: "8-12", targetRPE: 8, restSeconds: 90)
            }
        )
    }
}

struct TrainingAnalyticsService {
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

struct RecoveryTrainingInput: Codable, Hashable {
    var recoveryScore: Double
    var sleepScore: Double
    var hrvZScore: Double?
    var restingHRZScore: Double?
    var tsb: Double?
    var energyScore: Double?
    var localFatigue: [String: LocalMuscleFatigue] = [:]
    var plannedFocus: String?
}

struct TrainingAdaptationRecommendation: Codable, Hashable {
    var readinessLevel: String
    var shouldTrain: Bool
    var recommendedIntensity: String
    var volumeMultiplier: Double
    var suggestedFocus: String
    var avoidMuscleGroups: [String]
    var preferredMuscleGroups: [String]
    var reasons: [String]
    var modifiedWorkoutDescription: String
}

struct RecoveryTrainingAdapter {
    func adapt(input: RecoveryTrainingInput) -> TrainingAdaptationRecommendation {
        var reasons: [String] = []
        let baseMultiplier: Double
        let readiness: String
        var intensity: String
        var shouldTrain = true

        switch input.recoveryScore {
        case 80...:
            baseMultiplier = 1.05
            readiness = "high"
            intensity = "high"
        case 60..<80:
            baseMultiplier = 0.9
            readiness = "moderate"
            intensity = "moderate"
        case 40..<60:
            baseMultiplier = 0.65
            readiness = "low"
            intensity = "low"
            reasons.append("Recovery is below the normal training range.")
        default:
            baseMultiplier = 0.35
            readiness = "very_low"
            intensity = "recovery"
            shouldTrain = false
            reasons.append("Recovery is very low. Rest or active recovery is preferred.")
        }

        if input.sleepScore < 75 {
            intensity = intensity == "recovery" ? intensity : "low"
            reasons.append("Sleep is below the threshold for high-intensity training.")
        }
        if let hrv = input.hrvZScore, hrv <= -1 {
            intensity = intensity == "recovery" ? intensity : "low"
            reasons.append("HRV is meaningfully below baseline.")
        }
        if let rhr = input.restingHRZScore, rhr >= 1 {
            intensity = intensity == "recovery" ? intensity : "low"
            reasons.append("Resting heart rate is elevated above baseline.")
        }
        if let tsb = input.tsb, tsb <= -15 {
            intensity = intensity == "recovery" ? intensity : "low"
            reasons.append("Training stress balance is deeply negative.")
        }

        let avoid = input.localFatigue.values.filter { $0.fatigueLevel == "high" }.map(\.muscleGroup).sorted()
        let preferred = input.localFatigue.values.filter { $0.setsLast7d < 6 }.map(\.muscleGroup).sorted()
        if let focus = input.plannedFocus, avoid.contains(focus) {
            reasons.append("\(focus) has accumulated too much local fatigue in the last 48 hours.")
        }
        let focus = preferred.first ?? (shouldTrain ? "balanced" : "active_recovery")
        let multiplier = avoid.contains(input.plannedFocus ?? "") ? min(baseMultiplier, 0.6) : baseMultiplier
        return TrainingAdaptationRecommendation(
            readinessLevel: readiness,
            shouldTrain: shouldTrain,
            recommendedIntensity: intensity,
            volumeMultiplier: multiplier,
            suggestedFocus: focus,
            avoidMuscleGroups: avoid,
            preferredMuscleGroups: preferred,
            reasons: reasons.isEmpty ? ["Current recovery signals support the planned session."] : reasons,
            modifiedWorkoutDescription: shouldTrain
                ? "Use \(Int((multiplier * 100).rounded()))% of planned volume at \(intensity) intensity."
                : "Choose rest, walking, mobility, or light recovery work."
        )
    }
}
