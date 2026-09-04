import Foundation
import SwiftData

/// Immutable source graph for the first shipped migration version.
///
/// The entity inventory is anchored to the 20b24c87 release checkpoint (31
/// entities).  V1 predates `scoreEvidenceData`, `hrvRmssdMilliseconds`, and
/// `IntradaySignalBucketRecord`.  The remaining entities were unchanged at
/// that checkpoint and are deliberately reused from `VelaSchemaV3Frozen`;
/// that file is itself fingerprint-guarded and must never be edited in place.
///
/// This is a migration source only.  Do not use these types for new writes.
enum VelaSchemaV1Frozen {
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
        @Attribute(.externalStorage) var workoutsData: Data?

        init(
            dayIdentifier: String,
            date: Date,
            sleepScore: Double? = nil,
            recoveryScore: Double? = nil,
            configVersion: String = "historical-v1",
            schemaVersion: Int = 1,
            updatedAt: Date = Date(),
            createdAt: Date = Date()
        ) {
            self.dayIdentifier = dayIdentifier
            self.date = date
            self.sleepScore = sleepScore
            self.recoveryScore = recoveryScore
            self.strainScore = nil
            self.stressIndex = nil
            self.morningEnergy = nil
            self.currentEnergy = nil
            self.energyBank = nil
            self.configVersion = configVersion
            self.schemaVersion = schemaVersion
            self.updatedAt = updatedAt
            self.createdAt = createdAt
            self.healthAge = nil
            self.hrvAverage = nil
            self.restingHeartRate = nil
            self.sleepHours = nil
            self.deepSleepPercent = nil
            self.remSleepPercent = nil
            self.sleepEfficiency = nil
            self.steps = nil
            self.activeCalories = nil
            self.activeMinutes = nil
            self.workoutCount = nil
            self.workoutTypes = nil
            self.workoutDuration = nil
            self.bodyWeight = nil
            self.bodyFatPercent = nil
            self.bmi = nil
            self.oxygenSaturation = nil
            self.respiratoryRate = nil
            self.wristTemperature = nil
            self.dailyLoad = nil
            self.workoutLoad = nil
            self.activityLoad = nil
            self.trainingLoadRatio = nil
            self.atl = nil
            self.ctl = nil
            self.tsb = nil
            self.acwr = nil
            self.bedtime = nil
            self.wakeTime = nil
            self.awakeMinutes = nil
            self.awakeEpisodeCount = nil
            self.deepSleepMinutes = nil
            self.remSleepMinutes = nil
            self.workoutsData = nil
        }
    }

    /// Exact 31-entity inventory captured from the V1 release checkpoint.
    static let models: [any PersistentModel.Type] = [
        DailyHealthSummaryRecord.self,
        VelaSchemaV3Frozen.SleepSummaryRecord.self,
        VelaSchemaV3Frozen.JournalEntryRecord.self,
        VelaSchemaV3Frozen.CoachInteractionRecord.self,
        VelaSchemaV3Frozen.AIReportRecord.self,
        VelaSchemaV3Frozen.UserWikiDocumentRecord.self,
        VelaSchemaV3Frozen.CoachSessionRecord.self,
        VelaSchemaV3Frozen.OnboardingState.self,
        VelaSchemaV3Frozen.CoachArtifactRecord.self,
        VelaSchemaV3Frozen.FoodLogRecord.self,
        VelaSchemaV3Frozen.StrengthWorkoutRecord.self,
        VelaSchemaV3Frozen.ActiveWorkoutDraftRecord.self,
        VelaSchemaV3Frozen.ExerciseDefinitionRecord.self,
        VelaSchemaV3Frozen.WorkoutTemplateRecord.self,
        VelaSchemaV3Frozen.TrainingResponseRecord.self,
        VelaSchemaV3Frozen.TrainingPlanRecord.self,
        VelaSchemaV3Frozen.BiomarkerRecord.self,
        VelaSchemaV3Frozen.MemoryEventRecord.self,
        VelaSchemaV3Frozen.AgentRunRecord.self,
        VelaSchemaV3Frozen.DailyOperatingPlanRecord.self,
        VelaSchemaV3Frozen.DailyDecisionFeedbackRecord.self,
        VelaSchemaV3Frozen.PersonalExperimentRecord.self,
        VelaSchemaV3Frozen.ExperimentCheckInRecord.self,
        VelaSchemaV3Frozen.AgentArtifactRecord.self,
        VelaSchemaV3Frozen.TrainingPlanAdaptationRecord.self,
        VelaSchemaV3Frozen.WorkoutEventRecord.self,
        VelaSchemaV3Frozen.XunjiDailyCacheRecord.self,
        VelaSchemaV3Frozen.XunjiWorkoutMirrorRecord.self,
        VelaSchemaV3Frozen.DeletedWorkoutRecord.self,
        VelaSchemaV3Frozen.VelaEventRecord.self,
        VelaSchemaV3Frozen.ProactiveInsightRecord.self,
    ]
}
