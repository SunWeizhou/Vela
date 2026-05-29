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
    var workoutCount: Int?
    var workoutTypes: String?
    var workoutDuration: Double?
    var bodyWeight: Double?
    var bodyFatPercent: Double?
    var bmi: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?

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
        workoutCount: Int? = nil,
        workoutTypes: String? = nil,
        workoutDuration: Double? = nil,
        bodyWeight: Double? = nil,
        bodyFatPercent: Double? = nil,
        bmi: Double? = nil,
        oxygenSaturation: Double? = nil,
        respiratoryRate: Double? = nil,
        wristTemperature: Double? = nil,
        configVersion: String = VelaAppMetadata.configVersion,
        schemaVersion: Int = 1,
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
        self.workoutCount = workoutCount
        self.workoutTypes = workoutTypes
        self.workoutDuration = workoutDuration
        self.bodyWeight = bodyWeight
        self.bodyFatPercent = bodyFatPercent
        self.bmi = bmi
        self.oxygenSaturation = oxygenSaturation
        self.respiratoryRate = respiratoryRate
        self.wristTemperature = wristTemperature
        self.configVersion = configVersion
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.createdAt = createdAt
    }

    convenience init(snapshot: DailyHealthSnapshot, calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: snapshot.date)
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
            workoutCount: snapshot.workoutCount,
            workoutTypes: snapshot.workoutTypes,
            workoutDuration: snapshot.workoutDuration,
            bodyWeight: snapshot.bodyWeight,
            bodyFatPercent: snapshot.bodyFatPercent,
            bmi: snapshot.bmi,
            oxygenSaturation: snapshot.oxygenSaturation,
            respiratoryRate: snapshot.respiratoryRate,
            wristTemperature: snapshot.wristTemperature
        )
    }

    func apply(snapshot: DailyHealthSnapshot, calendar: Calendar = .current, updatedAt: Date = Date()) {
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
        activeCalories = snapshot.activeCalories
        workoutCount = snapshot.workoutCount
        workoutTypes = snapshot.workoutTypes
        workoutDuration = snapshot.workoutDuration
        bodyWeight = snapshot.bodyWeight
        bodyFatPercent = snapshot.bodyFatPercent
        bmi = snapshot.bmi
        oxygenSaturation = snapshot.oxygenSaturation
        respiratoryRate = snapshot.respiratoryRate
        wristTemperature = snapshot.wristTemperature
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
        DailyHealthSnapshot(
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
            workoutCount: workoutCount,
            workoutTypes: workoutTypes,
            workoutDuration: workoutDuration,
            bodyWeight: bodyWeight,
            bodyFatPercent: bodyFatPercent,
            bmi: bmi,
            oxygenSaturation: oxygenSaturation,
            respiratoryRate: respiratoryRate,
            wristTemperature: wristTemperature
        )
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

public struct TrainingDay: Codable, Hashable, Identifiable {
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
        loggedStrain: Double? = nil
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
