import Foundation
import SwiftData

@Model
final class DailyHealthSummaryRecord {
    @Attribute(.unique) var dayIdentifier: String
    var date: Date
    var sleepScore: Double?
    var recoveryScore: Double?
    var strainScore: Double?
    var stressIndex: Double?
    var morningEnergy: Double?
    var currentEnergy: Double?
    var energyBank: Double?
    var configVersion: String
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
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
    
    // Core Metrics v1.3 Additions
    var awakeMinutes: Double?
    var awakeEpisodeCount: Int?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    @Attribute(.externalStorage) var workoutsData: Data?

    init(
        dayIdentifier: String,
        date: Date,
        sleepScore: Double? = nil,
        recoveryScore: Double? = nil,
        strainScore: Double? = nil,
        stressIndex: Double? = nil,
        morningEnergy: Double? = nil,
        currentEnergy: Double? = nil,
        energyBank: Double? = nil,
        healthAge: Double? = nil,
        hrvAverage: Double? = nil,
        restingHeartRate: Double? = nil,
        sleepHours: Double? = nil,
        deepSleepPercent: Double? = nil,
        remSleepPercent: Double? = nil,
        sleepEfficiency: Double? = nil,
        steps: Double? = nil,
        activeCalories: Double? = nil,
        activeMinutes: Double? = nil,
        workoutCount: Int? = nil,
        workoutTypes: String? = nil,
        workoutDuration: Double? = nil,
        bodyWeight: Double? = nil,
        bodyFatPercent: Double? = nil,
        bmi: Double? = nil,
        oxygenSaturation: Double? = nil,
        respiratoryRate: Double? = nil,
        wristTemperature: Double? = nil,
        dailyLoad: Double? = nil,
        workoutLoad: Double? = nil,
        activityLoad: Double? = nil,
        trainingLoadRatio: Double? = nil,
        atl: Double? = nil,
        ctl: Double? = nil,
        tsb: Double? = nil,
        acwr: Double? = nil,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        awakeMinutes: Double? = nil,
        awakeEpisodeCount: Int? = nil,
        deepSleepMinutes: Double? = nil,
        remSleepMinutes: Double? = nil,
        workoutsData: Data? = nil,
        configVersion: String = VelaAppMetadata.configVersion,
        schemaVersion: Int = 2,
        updatedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.dayIdentifier = dayIdentifier
        self.date = date
        self.sleepScore = sleepScore
        self.recoveryScore = recoveryScore
        self.strainScore = strainScore
        self.stressIndex = stressIndex
        self.morningEnergy = morningEnergy
        self.currentEnergy = currentEnergy
        self.energyBank = energyBank
        self.healthAge = healthAge
        self.hrvAverage = hrvAverage
        self.restingHeartRate = restingHeartRate
        self.sleepHours = sleepHours
        self.deepSleepPercent = deepSleepPercent
        self.remSleepPercent = remSleepPercent
        self.sleepEfficiency = sleepEfficiency
        self.steps = steps
        self.activeCalories = activeCalories
        self.activeMinutes = activeMinutes
        self.workoutCount = workoutCount
        self.workoutTypes = workoutTypes
        self.workoutDuration = workoutDuration
        self.bodyWeight = bodyWeight
        self.bodyFatPercent = bodyFatPercent
        self.bmi = bmi
        self.oxygenSaturation = oxygenSaturation
        self.respiratoryRate = respiratoryRate
        self.wristTemperature = wristTemperature
        self.dailyLoad = dailyLoad
        self.workoutLoad = workoutLoad
        self.activityLoad = activityLoad
        self.trainingLoadRatio = trainingLoadRatio
        self.atl = atl
        self.ctl = ctl
        self.tsb = tsb
        self.acwr = acwr
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.awakeMinutes = awakeMinutes
        self.awakeEpisodeCount = awakeEpisodeCount
        self.deepSleepMinutes = deepSleepMinutes
        self.remSleepMinutes = remSleepMinutes
        self.workoutsData = workoutsData
        self.configVersion = configVersion
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

    convenience init(snapshot: DailyHealthSnapshot, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: snapshot.date)
        let wData = try? JSONEncoder().encode(snapshot.workouts)
        self.init(
            dayIdentifier: Self.dayIdentifier(for: day, calendar: calendar),
            date: day,
            sleepScore: snapshot.sleepScore,
            recoveryScore: snapshot.recoveryScore,
            strainScore: snapshot.strainScore,
            stressIndex: snapshot.stressIndex,
            morningEnergy: snapshot.morningEnergy,
            currentEnergy: snapshot.currentEnergy,
            energyBank: snapshot.energyBank,
            healthAge: snapshot.healthAge,
            hrvAverage: snapshot.hrvAverage,
            restingHeartRate: snapshot.restingHeartRate,
            sleepHours: snapshot.sleepHours,
            deepSleepPercent: snapshot.deepSleepPercent,
            remSleepPercent: snapshot.remSleepPercent,
            sleepEfficiency: snapshot.sleepEfficiency,
            steps: snapshot.steps,
            activeCalories: snapshot.activeCalories,
            activeMinutes: snapshot.activeMinutes,
            workoutCount: snapshot.workoutCount,
            workoutTypes: snapshot.workoutTypes,
            workoutDuration: snapshot.workoutDuration,
            bodyWeight: snapshot.bodyWeight,
            bodyFatPercent: snapshot.bodyFatPercent,
            bmi: snapshot.bmi,
            oxygenSaturation: snapshot.oxygenSaturation,
            respiratoryRate: snapshot.respiratoryRate,
            wristTemperature: snapshot.wristTemperature,
            dailyLoad: snapshot.dailyLoad,
            workoutLoad: snapshot.workoutLoad,
            activityLoad: snapshot.activityLoad,
            trainingLoadRatio: snapshot.trainingLoadRatio,
            atl: snapshot.atl,
            ctl: snapshot.ctl,
            tsb: snapshot.tsb,
            acwr: snapshot.acwr,
            bedtime: snapshot.bedtime,
            wakeTime: snapshot.wakeTime,
            awakeMinutes: snapshot.awakeMinutes,
            awakeEpisodeCount: snapshot.awakeEpisodeCount,
            deepSleepMinutes: snapshot.deepSleepMinutes,
            remSleepMinutes: snapshot.remSleepMinutes,
            workoutsData: wData
        )
    }

    func apply(snapshot: DailyHealthSnapshot, calendar: Calendar = .current, updatedAt: Date = Date()) {
        let snapshotWorkoutIDs = Set(snapshot.workouts.map(\.id))
        let preservedManualWorkouts = decodedWorkouts().filter {
            $0.source == "manual" && !snapshotWorkoutIDs.contains($0.id)
        }
        let mergedWorkouts = snapshot.workouts + preservedManualWorkouts
        let preservedManualEnergy = preservedManualWorkouts.compactMap(\.energyKilocalories).reduce(0, +)
        let preservedManualDuration = preservedManualWorkouts.reduce(0) {
            $0 + $1.end.timeIntervalSince($1.start) / 60.0
        }

        date = calendar.startOfDay(for: snapshot.date)
        dayIdentifier = Self.dayIdentifier(for: date, calendar: calendar)
        sleepScore = snapshot.sleepScore
        recoveryScore = snapshot.recoveryScore
        strainScore = snapshot.strainScore
        stressIndex = snapshot.stressIndex
        morningEnergy = snapshot.morningEnergy
        currentEnergy = snapshot.currentEnergy
        energyBank = snapshot.energyBank
        healthAge = snapshot.healthAge
        hrvAverage = snapshot.hrvAverage
        restingHeartRate = snapshot.restingHeartRate
        sleepHours = snapshot.sleepHours
        deepSleepPercent = snapshot.deepSleepPercent
        remSleepPercent = snapshot.remSleepPercent
        sleepEfficiency = snapshot.sleepEfficiency
        steps = snapshot.steps
        activeCalories = Self.adding(snapshot.activeCalories, preservedManualEnergy)
        activeMinutes = Self.adding(snapshot.activeMinutes, preservedManualDuration)
        workoutCount = mergedWorkouts.isEmpty ? snapshot.workoutCount : mergedWorkouts.count
        workoutTypes = mergedWorkouts.isEmpty
            ? snapshot.workoutTypes
            : Set(mergedWorkouts.map(\.activityName)).sorted().joined(separator: ", ")
        workoutDuration = Self.adding(snapshot.workoutDuration, preservedManualDuration)
        bodyWeight = snapshot.bodyWeight
        bodyFatPercent = snapshot.bodyFatPercent
        bmi = snapshot.bmi
        oxygenSaturation = snapshot.oxygenSaturation
        respiratoryRate = snapshot.respiratoryRate
        wristTemperature = snapshot.wristTemperature
        dailyLoad = snapshot.dailyLoad
        workoutLoad = snapshot.workoutLoad
        activityLoad = snapshot.activityLoad
        trainingLoadRatio = snapshot.trainingLoadRatio
        atl = snapshot.atl
        ctl = snapshot.ctl
        tsb = snapshot.tsb
        acwr = snapshot.acwr
        bedtime = snapshot.bedtime
        wakeTime = snapshot.wakeTime
        awakeMinutes = snapshot.awakeMinutes
        awakeEpisodeCount = snapshot.awakeEpisodeCount
        deepSleepMinutes = snapshot.deepSleepMinutes
        remSleepMinutes = snapshot.remSleepMinutes
        workoutsData = try? JSONEncoder().encode(mergedWorkouts)
        configVersion = VelaAppMetadata.configVersion
        self.updatedAt = updatedAt
    }

    static func dayIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return [
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        ]
        .map { String(format: "%02d", $0) }
        .joined(separator: "-")
    }

    func toSnapshot() -> DailyHealthSnapshot {
        return DailyHealthSnapshot(
            date: date,
            createdAt: createdAt,
            sleepScore: sleepScore,
            recoveryScore: recoveryScore,
            strainScore: strainScore,
            stressIndex: stressIndex,
            morningEnergy: morningEnergy,
            currentEnergy: currentEnergy,
            energyBank: energyBank,
            healthAge: healthAge,
            hrvAverage: hrvAverage,
            restingHeartRate: restingHeartRate,
            sleepHours: sleepHours,
            deepSleepPercent: deepSleepPercent,
            remSleepPercent: remSleepPercent,
            sleepEfficiency: sleepEfficiency,
            steps: steps,
            activeCalories: activeCalories,
            activeMinutes: activeMinutes,
            workoutCount: workoutCount,
            workoutTypes: workoutTypes,
            workoutDuration: workoutDuration,
            bodyWeight: bodyWeight,
            bodyFatPercent: bodyFatPercent,
            bmi: bmi,
            oxygenSaturation: oxygenSaturation,
            respiratoryRate: respiratoryRate,
            wristTemperature: wristTemperature,
            dailyLoad: dailyLoad,
            workoutLoad: workoutLoad,
            activityLoad: activityLoad,
            trainingLoadRatio: trainingLoadRatio,
            atl: atl,
            ctl: ctl,
            tsb: tsb,
            acwr: acwr,
            bedtime: bedtime,
            wakeTime: wakeTime,
            awakeMinutes: awakeMinutes,
            awakeEpisodeCount: awakeEpisodeCount,
            deepSleepMinutes: deepSleepMinutes,
            remSleepMinutes: remSleepMinutes,
            workouts: decodedWorkouts()
        )
    }

    private func decodedWorkouts() -> [WorkoutSummary] {
        guard let workoutsData,
              let decoded = try? JSONDecoder().decode([WorkoutSummary].self, from: workoutsData) else {
            return []
        }
        return decoded
    }

    private static func adding(_ base: Double?, _ increment: Double) -> Double? {
        guard base != nil || increment != 0 else { return nil }
        return (base ?? 0) + increment
    }
}

struct StrengthSetLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var repetitions: Int
    var weightKilograms: Double
    var isWarmup: Bool = false
    var rpe: Double?
    var rir: Double?
    var isCompleted: Bool?
    var completedAt: Date?

    var volumeKilograms: Double {
        guard !isWarmup else { return 0 }
        return Double(repetitions) * weightKilograms
    }
}

struct StrengthExerciseLog: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var exerciseDefinitionId: UUID?
    var exerciseCanonicalKey: String?
    var name: String
    var equipment: String
    var primaryMuscleGroup: String?
    var sets: [StrengthSetLog]

    var volumeKilograms: Double {
        sets.reduce(0) { $0 + $1.volumeKilograms }
    }
}

@Model
final class StrengthWorkoutRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var durationMinutes: Int
    var notes: String
    @Attribute(.externalStorage) var exercisesData: Data
    var linkedWorkoutEventId: UUID?
    var sourceTemplateId: UUID?
    var planDayId: UUID?
    var sessionRPE: Double?
    var completedAt: Date?
    var analyticsJSON: String?

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        durationMinutes: Int,
        notes: String = "",
        exercises: [StrengthExerciseLog]
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.notes = notes
        exercisesData = (try? JSONEncoder().encode(exercises)) ?? Data("[]".utf8)
        linkedWorkoutEventId = nil
        sourceTemplateId = nil
        planDayId = nil
        sessionRPE = nil
        completedAt = endedAt
        analyticsJSON = nil
    }

    var exercises: [StrengthExerciseLog] {
        get { (try? JSONDecoder().decode([StrengthExerciseLog].self, from: exercisesData)) ?? [] }
        set { exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8) }
    }

    var endedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationMinutes * 60))
    }

    var exerciseCount: Int {
        exercises.count
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var totalRepetitionCount: Int {
        exercises.reduce(0) { exerciseTotal, exercise in
            exerciseTotal + exercise.sets.reduce(0) { $0 + $1.repetitions }
        }
    }

    var totalVolumeKilograms: Double {
        exercises.reduce(0) { $0 + $1.volumeKilograms }
    }
}

@Model
final class ActiveWorkoutDraftRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var startedAt: Date
    var templateId: UUID?
    @Attribute(.externalStorage) var exercisesJSON: String
    var notes: String
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        title: String,
        startedAt: Date = Date(),
        templateId: UUID? = nil,
        exercisesJSON: String = "[]",
        notes: String = "",
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.templateId = templateId
        self.exercisesJSON = exercisesJSON
        self.notes = notes
        self.lastUpdated = lastUpdated
    }

    @Transient
    var exercises: [StrengthExerciseLog] {
        get {
            guard let data = exercisesJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([StrengthExerciseLog].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                exercisesJSON = str
            } else {
                exercisesJSON = "[]"
            }
        }
    }
}

@Model
final class ExerciseDefinitionRecord {
    @Attribute(.unique) var id: UUID
    var canonicalKey: String = ""
    var name: String
    var aliasesJSON: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroupsJSON: String
    var equipment: String
    var movementPattern: String
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        canonicalKey: String = "",
        name: String,
        aliases: [String] = [],
        primaryMuscleGroup: String,
        secondaryMuscleGroups: [String] = [],
        equipment: String,
        movementPattern: String,
        isCustom: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.canonicalKey = canonicalKey.isEmpty ? name.toCanonicalKey() : canonicalKey
        self.name = name
        self.aliasesJSON = Self.encode(aliases)
        self.primaryMuscleGroup = primaryMuscleGroup
        self.secondaryMuscleGroupsJSON = Self.encode(secondaryMuscleGroups)
        self.equipment = equipment
        self.movementPattern = movementPattern
        self.isCustom = isCustom
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var aliases: [String] {
        get { Self.decode(aliasesJSON) }
        set { aliasesJSON = Self.encode(newValue) }
    }

    var secondaryMuscleGroups: [String] {
        get { Self.decode(secondaryMuscleGroupsJSON) }
        set { secondaryMuscleGroupsJSON = Self.encode(newValue) }
    }

    private static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decode(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

struct WorkoutTemplateExercise: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var exerciseDefinitionId: UUID?
    var exerciseCanonicalKey: String?
    var name: String
    var targetSets: Int
    var targetReps: String
    var targetRPE: Double?
    var restSeconds: Int
    var notes: String?
}

@Model
final class WorkoutTemplateRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var goal: String
    var notes: String
    var exercisesJSON: String
    var estimatedDurationMinutes: Int
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        goal: String = "",
        notes: String = "",
        exercises: [WorkoutTemplateExercise],
        estimatedDurationMinutes: Int = 60,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.goal = goal
        self.notes = notes
        self.exercisesJSON = Self.encode(exercises)
        self.estimatedDurationMinutes = estimatedDurationMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastUsedAt = lastUsedAt
    }

    var exercises: [WorkoutTemplateExercise] {
        get {
            guard let data = exercisesJSON.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([WorkoutTemplateExercise].self, from: data)) ?? []
        }
        set { exercisesJSON = Self.encode(newValue) }
    }

    private static func encode(_ values: [WorkoutTemplateExercise]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

@Model
final class TrainingResponseRecord {
    @Attribute(.unique) var id: UUID
    var workoutId: UUID
    var date: Date
    var nextDayDate: Date
    var primaryMuscleGroupsJSON: String
    var totalEffectiveSets: Int
    var totalVolumeKg: Double
    var sessionRPE: Double?
    var nextDayRecoveryDelta: Double?
    var nextDayHRVDelta: Double?
    var nextDayRHRDelta: Double?
    var nextDaySleepScore: Double?
    var subjectiveTagsJSON: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        workoutId: UUID,
        date: Date,
        nextDayDate: Date,
        primaryMuscleGroups: [String],
        totalEffectiveSets: Int,
        totalVolumeKg: Double,
        sessionRPE: Double? = nil,
        nextDayRecoveryDelta: Double? = nil,
        nextDayHRVDelta: Double? = nil,
        nextDayRHRDelta: Double? = nil,
        nextDaySleepScore: Double? = nil,
        subjectiveTags: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.workoutId = workoutId
        self.date = date
        self.nextDayDate = nextDayDate
        self.primaryMuscleGroupsJSON = Self.encode(primaryMuscleGroups)
        self.totalEffectiveSets = totalEffectiveSets
        self.totalVolumeKg = totalVolumeKg
        self.sessionRPE = sessionRPE
        self.nextDayRecoveryDelta = nextDayRecoveryDelta
        self.nextDayHRVDelta = nextDayHRVDelta
        self.nextDayRHRDelta = nextDayRHRDelta
        self.nextDaySleepScore = nextDaySleepScore
        self.subjectiveTagsJSON = Self.encode(subjectiveTags)
        self.createdAt = createdAt
    }

    var primaryMuscleGroups: [String] {
        get { Self.decode(primaryMuscleGroupsJSON) }
        set { primaryMuscleGroupsJSON = Self.encode(newValue) }
    }

    var subjectiveTags: [String] {
        get { Self.decode(subjectiveTagsJSON) }
        set { subjectiveTagsJSON = Self.encode(newValue) }
    }

    private static func encode(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private static func decode(_ value: String) -> [String] {
        guard let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
}

@Model
final class SleepSummaryRecord {
    @Attribute(.unique) var dayIdentifier: String
    var date: Date
    var totalSleepMinutes: Int
    var bedtime: Date?
    var wakeTime: Date?
    var deepMinutes: Int?
    var remMinutes: Int?
    var coreMinutes: Int?
    var awakeMinutes: Int?
    var sleepScore: Double?
    var updatedAt: Date

    init(summary: SleepSummary, calendar: Calendar = .current, updatedAt: Date = Date()) {
        let day = calendar.startOfDay(for: summary.date)
        dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar)
        date = day
        totalSleepMinutes = summary.totalSleepMinutes
        bedtime = summary.bedtime
        wakeTime = summary.wakeTime
        deepMinutes = summary.stageMinutes[.deep]
        remMinutes = summary.stageMinutes[.rem]
        coreMinutes = summary.stageMinutes[.core]
        awakeMinutes = summary.stageMinutes[.awake]
        sleepScore = summary.sleepScore
        self.updatedAt = updatedAt
    }
}

@Model
final class JournalEntryRecord {
    var createdAt: Date
    var serializedTags: String
    var note: String
    var value: Double?
    var unit: String?

    init(createdAt: Date = Date(), tags: [String], note: String, value: Double? = nil, unit: String? = nil) {
        self.createdAt = createdAt
        serializedTags = tags.joined(separator: ",")
        self.note = note
        self.value = value
        self.unit = unit
    }

    var tags: [String] {
        get {
            serializedTags
                .split(separator: ",")
                .map(String.init)
                .filter { !$0.isEmpty }
        }
        set {
            serializedTags = newValue.joined(separator: ",")
        }
    }

    /// Predefined tag categories for common habit/behavior tracking.
    /// Both Chinese and English labels are provided for bilingual support.
    static let tagCategories: [String: [String]] = [
        "caffeine":     ["caffeine", "咖啡因"],
        "alcohol":      ["alcohol", "酒精"],
        "late_meal":    ["late_meal", "夜宵"],
        "heavy_meal":   ["heavy_meal", "大餐"],
        "exercise":     ["exercise", "锻炼"],
        "stressed":     ["stressed", "压力大"],
        "meditation":   ["meditation", "冥想"],
        "hydration":    ["hydration", "补水"],
        "supplements":  ["supplements", "补剂"],
        "sick":         ["sick", "生病"],
        "travel":       ["travel", "旅行"],
        "menstruation": ["menstruation", "月经"],
        "sunlight":     ["sunlight", "阳光"],
        "mindfulness":  ["mindfulness", "正念"],
        "recovery":     ["recovery", "恢复"],
        "sleep":        ["sleep", "睡眠"],
        "training":     ["training", "训练"],
        "stress":       ["stress", "压力"],
        "mood":         ["mood", "情绪"],
        "supplement":   ["supplement", "补剂"],
    ]

    /// All known tags (flattened from tagCategories).
    static var allKnownTags: [String] {
        tagCategories.values.flatMap { $0 }
    }
}

@Model
final class AIReportRecord {
    var createdAt: Date
    var type: String
    var title: String
    var markdownContent: String
    var serializedContextSnapshot: String
    var serializedTags: String

    init(
        createdAt: Date = Date(),
        type: String,
        title: String,
        markdownContent: String,
        serializedContextSnapshot: String,
        tags: [String] = []
    ) {
        self.createdAt = createdAt
        self.type = type
        self.title = title
        self.markdownContent = markdownContent
        self.serializedContextSnapshot = serializedContextSnapshot
        serializedTags = tags.joined(separator: ",")
    }
}

@Model
final class UserWikiDocumentRecord {
    @Attribute(.unique) var filename: String
    var title: String
    var markdownContent: String
    var updatedAt: Date

    init(filename: String, title: String, markdownContent: String, updatedAt: Date = Date()) {
        self.filename = filename
        self.title = title
        self.markdownContent = markdownContent
        self.updatedAt = updatedAt
    }
}

@Model
final class CoachSessionRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var serializedMessages: String
    var isArchived: Bool
    
    init(
        id: UUID = UUID(),
        title: String = "新对话",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        serializedMessages: String = "[]",
        isArchived: Bool = false
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.serializedMessages = serializedMessages
        self.isArchived = isArchived
    }
}

enum PersistenceSchemaVersion {
    static let current = "v0.1"
}

enum FoodLogSource: String, Codable, CaseIterable {
    case photoAnalysis = "photo_analysis"
    case barcodeLookup = "barcode_lookup"
    case manual
    case coachTool = "coach_tool"
}

struct FoodLogItem: Codable, Hashable, Sendable {
    var name: String
    var portion: String
    var calories: Int

    init(name: String, portion: String, calories: Int) {
        self.name = name
        self.portion = portion
        self.calories = calories
    }
}

@Model
final class FoodLogRecord {
    @Attribute(.unique) var id: UUID
    var mealName: String
    var createdAt: Date
    var updatedAt: Date
    var source: String
    var totalCalories: Int
    var proteinGrams: Int
    var carbsGrams: Int
    var fatGrams: Int
    var fiberGrams: Int
    var healthScore: String
    var rawAnalysis: String
    var serializedFoods: String
    var serializedSuggestions: String

    @Transient
    var foods: [FoodLogItem] {
        get {
            guard let data = serializedFoods.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([FoodLogItem].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let value = String(data: data, encoding: .utf8) {
                serializedFoods = value
            } else {
                serializedFoods = "[]"
            }
        }
    }

    @Transient
    var suggestions: [String] {
        get {
            guard let data = serializedSuggestions.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let value = String(data: data, encoding: .utf8) {
                serializedSuggestions = value
            } else {
                serializedSuggestions = "[]"
            }
        }
    }

    var summaryLine: String {
        let names = foods.map(\.name).joined(separator: ", ")
        let foodText = names.isEmpty ? mealName : names
        return "\(mealName): \(foodText) · \(totalCalories) kcal · P\(proteinGrams) C\(carbsGrams) F\(fatGrams)"
    }

    init(
        id: UUID = UUID(),
        mealName: String,
        foods: [FoodLogItem],
        totalCalories: Int,
        proteinGrams: Int,
        carbsGrams: Int,
        fatGrams: Int,
        fiberGrams: Int,
        healthScore: String,
        suggestions: [String] = [],
        source: FoodLogSource,
        rawAnalysis: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mealName = mealName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.source = source.rawValue
        self.totalCalories = totalCalories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.healthScore = healthScore
        self.rawAnalysis = rawAnalysis
        self.serializedFoods = "[]"
        self.serializedSuggestions = "[]"
        self.foods = foods
        self.suggestions = suggestions
    }

    convenience init(
        analysis: FoodAnalysisResult,
        mealName: String,
        source: FoodLogSource,
        createdAt: Date = Date()
    ) {
        self.init(
            mealName: mealName,
            foods: analysis.foods.map {
                FoodLogItem(name: $0.name, portion: $0.portion, calories: $0.calories)
            },
            totalCalories: analysis.totalCalories,
            proteinGrams: analysis.macros.protein,
            carbsGrams: analysis.macros.carbs,
            fatGrams: analysis.macros.fat,
            fiberGrams: analysis.macros.fiber,
            healthScore: analysis.healthScore,
            suggestions: analysis.suggestions,
            source: source,
            rawAnalysis: analysis.rawAnalysis,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

public struct TrainingDay: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var weekNumber: Int      // 1-indexed
    public var dayNumber: Int       // 1-7 (1 = Monday, 7 = Sunday)
    public var title: String        // e.g. "Cardio Endurance"
    public var description: String  // e.g. "Run for 45 minutes in HR Zone 2."
    public var focus: String        // "cardio" | "strength" | "flexibility" | "rest"
    public var durationMinutes: Int
    public var intensity: String    // "low" | "moderate" | "high"
    public var isCompleted: Bool
    public var completedAt: Date?
    public var loggedStrain: Double?
    
    // Closed-loop training additions
    public var linkedWorkoutEventIds: [UUID]
    public var plannedExercisesJSON: String
    public var actualSummaryJSON: String
    public var adherenceScore: Double?

    public init(
        id: UUID = UUID(),
        weekNumber: Int,
        dayNumber: Int,
        title: String,
        description: String,
        focus: String,
        durationMinutes: Int,
        intensity: String,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        loggedStrain: Double? = nil,
        linkedWorkoutEventIds: [UUID] = [],
        plannedExercisesJSON: String = "[]",
        actualSummaryJSON: String = "{}",
        adherenceScore: Double? = nil
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.dayNumber = dayNumber
        self.title = title
        self.description = description
        self.focus = focus
        self.durationMinutes = durationMinutes
        self.intensity = intensity
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.loggedStrain = loggedStrain
        self.linkedWorkoutEventIds = linkedWorkoutEventIds
        self.plannedExercisesJSON = plannedExercisesJSON
        self.actualSummaryJSON = actualSummaryJSON
        self.adherenceScore = adherenceScore
    }

    enum CodingKeys: String, CodingKey {
        case id, weekNumber, dayNumber, title, description, focus, durationMinutes, intensity
        case isCompleted, completedAt, loggedStrain, linkedWorkoutEventIds
        case plannedExercisesJSON, actualSummaryJSON, adherenceScore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        weekNumber = try container.decode(Int.self, forKey: .weekNumber)
        dayNumber = try container.decode(Int.self, forKey: .dayNumber)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        focus = try container.decode(String.self, forKey: .focus)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        intensity = try container.decode(String.self, forKey: .intensity)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        loggedStrain = try container.decodeIfPresent(Double.self, forKey: .loggedStrain)
        linkedWorkoutEventIds = try container.decodeIfPresent([UUID].self, forKey: .linkedWorkoutEventIds) ?? []
        plannedExercisesJSON = try container.decodeIfPresent(String.self, forKey: .plannedExercisesJSON) ?? "[]"
        actualSummaryJSON = try container.decodeIfPresent(String.self, forKey: .actualSummaryJSON) ?? "{}"
        adherenceScore = try container.decodeIfPresent(Double.self, forKey: .adherenceScore)
    }
}

@Model
public final class TrainingPlanRecord {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var goalDescription: String
    public var startDate: Date
    public var weeksCount: Int
    public var isActive: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var serializedDays: String

    @Transient
    public var days: [TrainingDay] {
        get {
            guard let data = serializedDays.data(using: .utf8) else { return [] }
            return (try? JSONDecoder().decode([TrainingDay].self, from: data)) ?? []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let str = String(data: data, encoding: .utf8) {
                serializedDays = str
            } else {
                serializedDays = "[]"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        title: String,
        goalDescription: String,
        startDate: Date = Date(),
        weeksCount: Int = 4,
        isActive: Bool = true,
        days: [TrainingDay] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.goalDescription = goalDescription
        self.startDate = startDate
        self.weeksCount = weeksCount
        self.isActive = isActive
        self.serializedDays = "[]"
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.days = days
    }
}

@Model
public final class BiomarkerRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String          // e.g., "Vitamin D", "Cortisol", "Ferritin", "Cholesterol"
    public var value: Double
    public var unit: String           // e.g., "ng/mL", "mcg/dL", "mg/dL"
    public var date: Date
    public var isOptimal: Bool
    public var referenceMin: Double
    public var referenceMax: Double
    public var sourceDocumentName: String? // Linked document name if OCR-extracted

    public init(
        id: UUID = UUID(),
        name: String,
        value: Double,
        unit: String,
        date: Date = Date(),
        isOptimal: Bool = true,
        referenceMin: Double,
        referenceMax: Double,
        sourceDocumentName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.date = date
        self.isOptimal = isOptimal
        self.referenceMin = referenceMin
        self.referenceMax = referenceMax
        self.sourceDocumentName = sourceDocumentName
    }
}

@Model
public final class WorkoutEventRecord {
    @Attribute(.unique) public var id: UUID
    public var source: String // "healthKit" | "manual" | "strengthLog"
    public var startedAt: Date
    public var endedAt: Date
    public var dayIdentifier: String = ""
    public var activityType: String
    public var title: String = ""
    public var durationMinutes: Double = 0
    public var energyKilocalories: Double?
    public var averageHeartRate: Double?
    public var rpe: Double?
    public var linkedStrengthWorkoutId: UUID?
    public var linkedHealthKitWorkoutId: UUID?
    public var linkedTrainingPlanDayId: UUID?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        source: String,
        startedAt: Date,
        endedAt: Date,
        activityType: String,
        title: String? = nil,
        energyKilocalories: Double? = nil,
        averageHeartRate: Double? = nil,
        rpe: Double? = nil,
        linkedStrengthWorkoutId: UUID? = nil,
        linkedHealthKitWorkoutId: UUID? = nil,
        linkedTrainingPlanDayId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.id = id
        self.source = source
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: startedAt, calendar: calendar)
        self.activityType = activityType
        self.title = title ?? activityType
        self.durationMinutes = max(0, endedAt.timeIntervalSince(startedAt) / 60)
        self.energyKilocalories = energyKilocalories
        self.averageHeartRate = averageHeartRate
        self.rpe = rpe
        self.linkedStrengthWorkoutId = linkedStrengthWorkoutId
        self.linkedHealthKitWorkoutId = linkedHealthKitWorkoutId
        self.linkedTrainingPlanDayId = linkedTrainingPlanDayId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension String {
    public func toCanonicalKey() -> String {
        let mapping: [String: String] = [
            "杠铃卧推": "barbell_bench_press",
            "哑铃卧推": "dumbbell_bench_press",
            "上斜卧推": "incline_bench_press",
            "双杠臂屈伸": "dips",
            "绳索夹胸": "cable_fly",
            "器械推胸": "chest_press",
            "引体向上": "pull_ups",
            "高位下拉": "lat_pulldown",
            "杠铃划船": "barbell_row",
            "坐姿划船": "seated_row",
            "单臂哑铃划船": "one_arm_dumbbell_row",
            "硬拉": "deadlift",
            "深蹲": "squat",
            "腿举": "leg_press",
            "罗马尼亚硬拉": "romanian_deadlift",
            "腿屈伸": "leg_extension",
            "腿弯举": "leg_curl",
            "保加利亚分腿蹲": "bulgarian_split_squat",
            "臀推": "hip_thrust",
            "推举": "overhead_press",
            "哑铃侧平举": "lateral_raise",
            "俯身飞鸟": "rear_delt_fly",
            "面拉": "face_pull",
            "阿诺德推举": "arnold_press",
            "杠铃弯举": "barbell_curl",
            "哑铃弯举": "dumbbell_curl",
            "绳索下压": "triceps_pushdown",
            "窄距卧推": "close_grip_bench_press",
            "臂屈伸": "triceps_extension",
            "卷腹": "crunch",
            "悬垂举腿": "hanging_leg_raise",
            "平板支撑": "plank",
            "pallof press": "pallof_press"
        ]
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let mapped = mapping[trimmed] {
            return mapped
        }
        for (key, val) in mapping {
            if trimmed.contains(key.lowercased()) {
                return val
            }
        }
        return trimmed
            .replacingOccurrences(of: " ", with: "_")
            .filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
}
