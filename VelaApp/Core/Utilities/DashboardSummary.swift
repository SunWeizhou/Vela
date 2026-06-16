import Foundation
import SwiftData

struct DashboardSummary: Hashable, @unchecked Sendable {
    var date: Date
    var sleepSummary: SleepSummary
    var sleepScore: MetricResult
    var recovery: MetricResult
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strain: MetricResult
    var stress: MetricResult
    var energy: MetricResult
    var healthAge: HealthAgeTrendResult
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics
    var workouts: [WorkoutSummary]
    var dailyInsight: String
    var source: DataSource
    
    private var _trainingDecision: TrainingDecision?
    var trainingDecision: TrainingDecision {
        get {
            guard let _trainingDecision else {
                return TrainingDecision.compatibilityView(
                    of: DailyTrainingDecision(
                        decision: .rest,
                        volumeMultiplier: 0.5,
                        intensityCap: 50,
                        reasons: ["等待综合身体状态分析"],
                        userFacingSummary: "等待数据同步完成后生成",
                        confidence: 0.0,
                        source: "DashboardSummary.fallback",
                        safetyNotice: "General wellness and training guidance only."
                    ),
                    bodyState: bodyState
                )
            }
            return _trainingDecision
        }
        set {
            _trainingDecision = newValue
        }
    }

    private var _bodyState: BodyState?
    var bodyState: BodyState {
        get {
            _bodyState ?? BodyState(
                date: date,
                readiness: .unknown,
                recovery: MetricResult(
                    name: "Recovery", value: nil, band: .low, confidence: .low,
                    components: [:], componentWeights: [:], reasons: ["No data"],
                    missingInputs: ["hrv", "rhr", "sleep"],
                    dataWindow: DateInterval(start: date, end: date),
                    source: .derived, algorithmVersion: "1.0", lastUpdated: date
                ),
                sleep: MetricResult(
                    name: "Sleep", value: nil, band: .low, confidence: .low,
                    components: [:], componentWeights: [:], reasons: ["No data"],
                    missingInputs: ["duration"],
                    dataWindow: DateInterval(start: date, end: date),
                    source: .derived, algorithmVersion: "1.0", lastUpdated: date
                ),
                strain: MetricResult(
                    name: "Strain", value: nil, band: .low, confidence: .low,
                    components: [:], componentWeights: [:], reasons: ["No data"],
                    missingInputs: ["daily_load"],
                    dataWindow: DateInterval(start: date, end: date),
                    source: .derived, algorithmVersion: "1.0", lastUpdated: date
                ),
                energy: MetricResult(
                    name: "Energy Bank", value: nil, band: .low, confidence: .low,
                    components: [:], componentWeights: [:], reasons: ["No data"],
                    missingInputs: ["recovery", "sleep"],
                    dataWindow: DateInterval(start: date, end: date),
                    source: .derived, algorithmVersion: "1.0", lastUpdated: date
                ),
                stress: MetricResult(
                    name: "Stress", value: nil, band: .low, confidence: .low,
                    components: [:], componentWeights: [:], reasons: ["No data"],
                    missingInputs: ["hrv", "rhr"],
                    dataWindow: DateInterval(start: date, end: date),
                    source: .derived, algorithmVersion: "1.0", lastUpdated: date
                ),
                localFatigue: [:],
                drivers: [],
                confidence: .unavailable,
                freshness: .stale,
                source: "DashboardSummary.fallback",
                activeStatus: "active",
                hash: ""
            )
        }
        set { _bodyState = newValue }
    }

    init(
        date: Date,
        sleepSummary: SleepSummary,
        sleepScore: MetricResult,
        recovery: MetricResult,
        recoveryMetrics: RecoveryMetricSummary,
        recoveryBaseline: RecoveryMetricSummary,
        strain: MetricResult,
        stress: MetricResult,
        energy: MetricResult,
        healthAge: HealthAgeTrendResult,
        bodyMetrics: BodyMetricsSummary,
        extendedMetrics: ExtendedHealthMetrics,
        workouts: [WorkoutSummary],
        dailyInsight: String,
        source: DataSource
    ) {
        self.date = date
        self.sleepSummary = sleepSummary
        self.sleepScore = sleepScore
        self.recovery = recovery
        self.recoveryMetrics = recoveryMetrics
        self.recoveryBaseline = recoveryBaseline
        self.strain = strain
        self.stress = stress
        self.energy = energy
        self.healthAge = healthAge
        self.bodyMetrics = bodyMetrics
        self.extendedMetrics = extendedMetrics
        self.workouts = workouts
        self.dailyInsight = dailyInsight
        self.source = source
        self._trainingDecision = nil
        self._bodyState = nil
    }

    enum DataSource: String, Hashable {
        case healthKit = "HealthKit"
        case cache = "Cached HealthKit"
        case empty = "Empty"
        case preview = "Preview"
    }

    static func preview(date: Date = Date()) -> DashboardSummary {
        PreviewDataFactory.makeDashboard(date: date)
    }

    static func empty(date: Date = Date()) -> DashboardSummary {
        func emptyMetric(name: String, reason: String) -> MetricResult {
            MetricResult(
                name: name,
                value: nil,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: [reason],
                missingInputs: ["healthData"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            )
        }

        return DashboardSummary(
            date: date,
            sleepSummary: SleepSummary(
                date: date,
                totalSleepMinutes: 0,
                bedtime: nil,
                wakeTime: nil,
                stageMinutes: [:],
                segments: [],
                sleepScore: nil
            ),
            sleepScore: MetricResult(
                name: "Sleep Score",
                value: nil,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: ["Sleep data unavailable."],
                missingInputs: ["sleepSummary"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            ),
            recovery: MetricResult(
                name: "Recovery Score",
                value: 0,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: ["Recovery data unavailable."],
                missingInputs: ["recoveryMetrics"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            ),
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: nil,
                restingHeartRate: nil,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: nil,
                restingHeartRate: nil,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            strain: emptyMetric(name: "Strain Score", reason: "Strain data unavailable."),
            stress: emptyMetric(name: "Physiological Stress Index", reason: "Stress data unavailable."),
            energy: emptyMetric(name: "Energy Bank", reason: "Energy data unavailable."),
            healthAge: HealthAgeTrendEngine().calculate(from: HealthAgeTrendInput(factors: [])),
            bodyMetrics: BodyMetricsSummary(
                vo2Max: nil,
                weightKilograms: nil,
                bodyFatPercentage: nil,
                leanBodyMassKilograms: nil
            ),
            extendedMetrics: ExtendedHealthMetrics.empty,
            workouts: [],
            dailyInsight: "",
            source: .empty
        )
    }
}

enum BodyReadiness: String, Codable, Hashable, Sendable {
    case ready
    case caution
    case recovering
    case unknown
}

struct BodyStateDriver: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case recovery
        case sleep
        case strain
        case stress
        case energy
        case localFatigue
        case trainingResponse
        case activeStatus
        case dataCoverage
        case nutrition
        case journal
        case activePlan
        case recentActivity
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var impact: Double
    var source: String
}

struct BodyState: Codable, Hashable {
    var date: Date
    var readiness: BodyReadiness
    var recovery: MetricResult
    var sleep: MetricResult
    var strain: MetricResult
    var energy: MetricResult
    var stress: MetricResult
    var localFatigue: [String: LocalMuscleFatigue]
    var drivers: [BodyStateDriver]
    var confidence: DataConfidence
    var freshness: DataFreshness
    var source: String
    var activeStatus: String
    var hash: String
}

struct BodyStateInput {
    var dashboard: DashboardSummary
    var dailySummary: DailyHealthSummaryRecord?
    var workoutEvents: [WorkoutEventRecord]
    var strengthWorkouts: [StrengthWorkoutRecord]
    var trainingResponses: [TrainingResponseRecord]
    var foodLogs: [FoodLogRecord]
    var journalEntries: [JournalEntryRecord]
    var activePlan: TrainingPlanRecord?
    var activeStatus: String
    var generatedAt: Date

    init(
        dashboard: DashboardSummary,
        dailySummary: DailyHealthSummaryRecord? = nil,
        workoutEvents: [WorkoutEventRecord] = [],
        strengthWorkouts: [StrengthWorkoutRecord] = [],
        trainingResponses: [TrainingResponseRecord] = [],
        foodLogs: [FoodLogRecord] = [],
        journalEntries: [JournalEntryRecord] = [],
        activePlan: TrainingPlanRecord? = nil,
        activeStatus: String = "active",
        generatedAt: Date = Date()
    ) {
        self.dashboard = dashboard
        self.dailySummary = dailySummary
        self.workoutEvents = workoutEvents
        self.strengthWorkouts = strengthWorkouts
        self.trainingResponses = trainingResponses
        self.foodLogs = foodLogs
        self.journalEntries = journalEntries
        self.activePlan = activePlan
        self.activeStatus = activeStatus
        self.generatedAt = generatedAt
    }
}

struct BodyStateKernel {
    func build(input: BodyStateInput) -> BodyState {
        let dashboard = input.dashboard
        let fatigue = TrainingAnalyticsService().computeLocalFatigue(
            workouts: input.strengthWorkouts,
            endingAt: input.generatedAt
        )
        var drivers = metricDrivers(dashboard)
        drivers.append(contentsOf: fatigue.values
            .filter { $0.fatigueLevel != "low" }
            .sorted { $0.setsLast48h > $1.setsLast48h }
            .map {
                BodyStateDriver(
                    id: "fatigue-\($0.muscleGroup)",
                    kind: .localFatigue,
                    title: "\($0.muscleGroup) local fatigue",
                    detail: "\($0.setsLast48h) effective sets in 48h and \($0.setsLast7d) in 7d.",
                    impact: $0.fatigueLevel == "high" ? -0.9 : -0.5,
                    source: "StrengthWorkoutRecord via TrainingAnalyticsService"
                )
            })

        let recentResponses = input.trainingResponses.filter {
            $0.date >= input.generatedAt.addingTimeInterval(-28 * 86_400)
                && $0.date <= input.generatedAt
        }
        if let costly = recentResponses
            .filter({ ($0.nextDayRecoveryDelta ?? 0) <= -8
                || ($0.nextDayHRVDelta ?? 0) <= -10
                || ($0.nextDayRHRDelta ?? 0) >= 5 })
            .min(by: { ($0.nextDayRecoveryDelta ?? 0) > ($1.nextDayRecoveryDelta ?? 0) }) {
            drivers.append(BodyStateDriver(
                id: "training-response-\(costly.id.uuidString)",
                kind: .trainingResponse,
                title: "Recent training response",
                detail: "A \(costly.primaryMuscleGroups.joined(separator: ", ")) session was followed by a \(Self.signed(costly.nextDayRecoveryDelta)) recovery change.",
                impact: -0.8,
                source: "TrainingResponseRecord"
            ))
        }

        if ["sick", "injured", "resting"].contains(input.activeStatus) {
            drivers.append(BodyStateDriver(
                id: "active-status",
                kind: .activeStatus,
                title: "Active status",
                detail: "User status is \(input.activeStatus).",
                impact: -1,
                source: "ActiveStatusSettings"
            ))
        }

        let dayStart = Calendar.current.startOfDay(for: input.generatedAt)
        let todayFood = input.foodLogs.filter { $0.createdAt >= dayStart }
        if !todayFood.isEmpty {
            let calories = todayFood.reduce(0) { $0 + $1.totalCalories }
            let protein = todayFood.reduce(0) { $0 + $1.proteinGrams }
            drivers.append(BodyStateDriver(
                id: "nutrition-coverage",
                kind: .nutrition,
                title: "Nutrition logged",
                detail: "\(calories) kcal and \(protein) g protein recorded today.",
                impact: 0.15,
                source: "FoodLogRecord"
            ))
        }
        if let latestJournal = input.journalEntries
            .filter({ $0.createdAt >= input.generatedAt.addingTimeInterval(-36 * 3_600) })
            .max(by: { $0.createdAt < $1.createdAt }) {
            drivers.append(BodyStateDriver(
                id: "journal-\(Int(latestJournal.createdAt.timeIntervalSince1970))",
                kind: .journal,
                title: "Recent self-report",
                detail: latestJournal.note.isEmpty ? latestJournal.tags.joined(separator: ", ") : latestJournal.note,
                impact: 0,
                source: "JournalEntryRecord"
            ))
        }
        if let activePlan = input.activePlan {
            drivers.append(BodyStateDriver(
                id: "active-plan-\(activePlan.id.uuidString)",
                kind: .activePlan,
                title: "Active training plan",
                detail: activePlan.title,
                impact: 0.1,
                source: "TrainingPlanRecord"
            ))
        }
        let recentEvents = input.workoutEvents.filter {
            $0.startedAt >= input.generatedAt.addingTimeInterval(-48 * 3_600)
                && $0.startedAt <= input.generatedAt
        }
        if !recentEvents.isEmpty {
            let minutes = recentEvents.reduce(0) { $0 + $1.durationMinutes }
            drivers.append(BodyStateDriver(
                id: "recent-activity",
                kind: .recentActivity,
                title: "Recent training load",
                detail: "\(recentEvents.count) sessions and \(Int(minutes.rounded())) minutes in 48h.",
                impact: minutes >= 120 ? -0.35 : 0,
                source: "WorkoutEventRecord"
            ))
        }

        let freshness = Self.freshness(
            referenceDate: input.dailySummary?.updatedAt ?? dashboard.date,
            generatedAt: input.generatedAt,
            hasData: dashboard.source != .empty
        )
        let confidence = Self.confidence(for: dashboard, freshness: freshness)
        let readiness: BodyReadiness
        if dashboard.source == .empty {
            readiness = .unknown
            drivers.append(BodyStateDriver(
                id: "data-coverage",
                kind: .dataCoverage,
                title: "Limited data coverage",
                detail: "Vela is using a conservative fallback until health or local records are available.",
                impact: -0.6,
                source: "BodyStateKernel"
            ))
        } else if ["sick", "injured", "resting"].contains(input.activeStatus)
                    || dashboard.recovery.score < 40 {
            readiness = .recovering
        } else if fatigue.values.contains(where: { $0.fatigueLevel == "high" })
                    || drivers.contains(where: { $0.kind == .trainingResponse })
                    || dashboard.recovery.score < 62
                    || dashboard.sleepScore.score < 68 {
            readiness = .caution
        } else {
            readiness = .ready
        }

        let fatigueHash = fatigue.values
            .sorted { $0.muscleGroup < $1.muscleGroup }
            .map { fatigue in
                "\(fatigue.muscleGroup):\(fatigue.setsLast48h):\(fatigue.setsLast7d)"
            }
            .joined(separator: "|")
        let responseHash = recentResponses
            .map { response in
                "\(response.id.uuidString):\(response.nextDayRecoveryDelta ?? 0)"
            }
            .joined(separator: "|")
        let eventHash = recentEvents.map(\.id.uuidString).sorted().joined(separator: "|")
        let nutritionHash = todayFood
            .map { food in "\(food.id.uuidString):\(food.totalCalories):\(food.proteinGrams)" }
            .sorted()
            .joined(separator: "|")
        let journalHash = input.journalEntries
            .filter { $0.createdAt >= input.generatedAt.addingTimeInterval(-36 * 3_600) }
            .map { "\(Int($0.createdAt.timeIntervalSince1970)):\($0.note)" }
            .sorted()
            .joined(separator: "|")
        let hashInput = [
            DailyHealthSummaryRecord.dayIdentifier(for: dashboard.date),
            readiness.rawValue,
            "\(dashboard.recovery.score)",
            "\(dashboard.sleepScore.score)",
            "\(dashboard.strain.score)",
            input.activeStatus,
            input.activePlan?.id.uuidString ?? "no-plan",
            eventHash,
            nutritionHash,
            journalHash,
            fatigueHash,
            responseHash
        ].joined(separator: "#")

        return BodyState(
            date: dashboard.date,
            readiness: readiness,
            recovery: dashboard.recovery,
            sleep: dashboard.sleepScore,
            strain: dashboard.strain,
            energy: dashboard.energy,
            stress: dashboard.stress,
            localFatigue: fatigue,
            drivers: Array(drivers.sorted { $0.impact < $1.impact }.prefix(5)),
            confidence: confidence,
            freshness: freshness,
            source: "DashboardSummary + local SwiftData records via BodyStateKernel",
            activeStatus: input.activeStatus,
            hash: ContentHash.hash(hashInput)
        )
    }

    private func metricDrivers(_ dashboard: DashboardSummary) -> [BodyStateDriver] {
        var drivers: [BodyStateDriver] = []
        if let reason = dashboard.recovery.reasons.first, dashboard.recovery.hasData {
            drivers.append(.init(
                id: "recovery",
                kind: .recovery,
                title: "Recovery",
                detail: reason,
                impact: dashboard.recovery.score >= 70 ? 0.7 : -0.7,
                source: "RecoveryScoreEngine \(dashboard.recovery.algorithmVersion)"
            ))
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 70 {
            drivers.append(.init(
                id: "sleep",
                kind: .sleep,
                title: "Sleep",
                detail: dashboard.sleepScore.reasons.first ?? "Sleep is below the normal training range.",
                impact: -0.6,
                source: "SleepScoreEngine \(dashboard.sleepScore.algorithmVersion)"
            ))
        }
        if dashboard.stress.hasData, dashboard.stress.score >= 75 {
            drivers.append(.init(
                id: "stress",
                kind: .stress,
                title: "Stress",
                detail: dashboard.stress.reasons.first ?? "Physiological stress is elevated.",
                impact: -0.6,
                source: "StressIndexEngine \(dashboard.stress.algorithmVersion)"
            ))
        }
        return drivers
    }

    private static func confidence(for dashboard: DashboardSummary, freshness: DataFreshness) -> DataConfidence {
        guard dashboard.source != .empty, freshness != .missing else { return .low }
        let values = [
            dashboard.recovery.confidence,
            dashboard.sleepScore.confidence,
            dashboard.strain.confidence
        ]
        if freshness == .stale || values.contains(.low) { return .low }
        if values.allSatisfy({ $0 == .high }) { return .high }
        return .medium
    }

    private static func freshness(referenceDate: Date, generatedAt: Date, hasData: Bool) -> DataFreshness {
        guard hasData else { return .missing }
        let age = generatedAt.timeIntervalSince(referenceDate)
        if age <= 2 * 3_600 { return .live }
        if Calendar.current.isDate(referenceDate, inSameDayAs: generatedAt) { return .today }
        if age <= 3 * 86_400 { return .recent }
        return .stale
    }

    private static func signed(_ value: Double?) -> String {
        guard let value else { return "not yet measured" }
        return String(format: "%+.1f", value)
    }
}

enum DailyTrainingDecisionType: String, Codable, Hashable, Sendable {
    case keep
    case reduce
    case swap
    case rest
}

struct DailyTrainingDecision: Codable, Hashable, Sendable {
    var decision: DailyTrainingDecisionType
    var targetSessionTitle: String?
    var volumeMultiplier: Double
    var intensityCap: Int
    var reasons: [String]
    var userFacingSummary: String
    var confidence: Double
    var source: String
    var safetyNotice: String
}

struct TrainingDecisionInput {
    var bodyState: BodyState
    var activePlan: TrainingPlanRecord?
    var recentStrengthSummary: RecentTrainingSummary?
    var trainingResponses: [TrainingResponseRecord]
    var userConstraints: [String]

    init(
        bodyState: BodyState,
        activePlan: TrainingPlanRecord? = nil,
        recentStrengthSummary: RecentTrainingSummary? = nil,
        trainingResponses: [TrainingResponseRecord] = [],
        userConstraints: [String] = []
    ) {
        self.bodyState = bodyState
        self.activePlan = activePlan
        self.recentStrengthSummary = recentStrengthSummary
        self.trainingResponses = trainingResponses
        self.userConstraints = userConstraints
    }
}

struct TrainingDecisionKernel {
    func decide(input: TrainingDecisionInput) -> DailyTrainingDecision {
        let state = input.bodyState
        let highFatigue = state.localFatigue.values
            .filter { $0.fatigueLevel == "high" }
            .map(\.muscleGroup)
            .sorted()
        let type: DailyTrainingDecisionType
        let multiplier: Double
        let cap: Int
        let summary: String

        if ["sick", "injured", "resting"].contains(state.activeStatus)
            || state.readiness == .recovering {
            type = .rest
            multiplier = 0
            cap = 2
            summary = "Prioritize rest or light recovery work today."
        } else if !highFatigue.isEmpty {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "Swap away from \(highFatigue.joined(separator: ", ")) and keep the session controlled."
        } else if state.readiness == .caution || state.readiness == .unknown {
            type = .reduce
            multiplier = state.readiness == .unknown ? 0.6 : 0.75
            cap = 7
            summary = "Reduce planned volume and stop if technique or perceived effort deteriorates."
        } else {
            type = .keep
            multiplier = 1
            cap = 9
            summary = "Keep the planned session with normal autoregulation."
        }

        let reasons = state.drivers.prefix(3).map { "\($0.title): \($0.detail)" }
        let confidence: Double = switch state.confidence {
        case .high: 0.9
        case .medium: 0.75
        case .low: 0.5
        case .unavailable: 0.3
        }
        return DailyTrainingDecision(
            decision: type,
            targetSessionTitle: input.activePlan?.title,
            volumeMultiplier: multiplier,
            intensityCap: cap,
            reasons: reasons.isEmpty ? ["No material limiter was detected."] : reasons,
            userFacingSummary: summary,
            confidence: confidence,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "General wellness and training guidance only; not a medical diagnosis. Stop and seek qualified care for concerning symptoms."
        )
    }
}

struct DailyOperatingPlanPayload: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var volumeMultiplier: Double
    var intensityCap: Int
    var summary: String
    var targetSessionTitle: String?
}

@MainActor
enum DailyOperatingPlanCoordinator {
    @discardableResult
    static func upsert(
        bodyState: BodyState,
        decision: DailyTrainingDecision,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws -> DailyOperatingPlanRecord {
        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: bodyState.date, calendar: calendar)
        let payload = DailyOperatingPlanPayload(
            decision: decision.decision,
            volumeMultiplier: decision.volumeMultiplier,
            intensityCap: decision.intensityCap,
            summary: decision.userFacingSummary,
            targetSessionTitle: decision.targetSessionTitle
        )
        let payloadJSON = Self.json(payload)
        let reasonsJSON = Self.json(decision.reasons)
        let descriptor = FetchDescriptor<DailyOperatingPlanRecord>(
            predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == dayIdentifier }
        )
        let record: DailyOperatingPlanRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
            record.bodyStateHash = bodyState.hash
            record.generatedAt = Date()
            record.primaryActionType = decision.decision.rawValue
            record.title = title(for: decision.decision)
            record.payloadJSON = payloadJSON
            record.reasonsJSON = reasonsJSON
            record.confidence = decision.confidence
            record.status = "active"
            record.source = decision.source
            record.safetyNotice = decision.safetyNotice
        } else {
            record = DailyOperatingPlanRecord(
                dayIdentifier: dayIdentifier,
                bodyStateHash: bodyState.hash,
                primaryActionType: decision.decision.rawValue,
                title: title(for: decision.decision),
                payloadJSON: payloadJSON,
                reasonsJSON: reasonsJSON,
                confidence: decision.confidence,
                status: "active",
                source: decision.source,
                safetyNotice: decision.safetyNotice
            )
            modelContext.insert(record)
        }

        let artifacts = try modelContext.fetch(FetchDescriptor<AgentArtifactRecord>())
        if let artifact = artifacts.first(where: {
            $0.type == AgentArtifactType.dailyPlan.rawValue && $0.sourceContextHash == bodyState.hash
        }) {
            artifact.title = record.title
            artifact.payloadJSON = payloadJSON
            artifact.confidence = decision.confidence
            artifact.status = "active"
            artifact.source = decision.source
            artifact.safetyNotice = decision.safetyNotice
        } else {
            modelContext.insert(AgentArtifactRecord(
                type: AgentArtifactType.dailyPlan.rawValue,
                title: record.title,
                payloadJSON: payloadJSON,
                sourceContextHash: bodyState.hash,
                confidence: decision.confidence,
                source: decision.source,
                safetyNotice: decision.safetyNotice
            ))
        }
        try modelContext.save()
        return record
    }

    private static func json<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func title(for decision: DailyTrainingDecisionType) -> String {
        switch decision {
        case .keep: "Keep today's plan"
        case .reduce: "Reduce today's training"
        case .swap: "Swap today's session"
        case .rest: "Recovery day"
        }
    }
}

private extension ExtendedHealthMetrics {
    static let empty = ExtendedHealthMetrics(
        age: nil, biologicalSex: nil, heightCm: nil, bmi: nil,
        walkingHeartRateAvg: nil, oxygenSaturation: nil,
        bloodPressureSystolic: nil, bloodPressureDiastolic: nil,
        bloodGlucose: nil,
        walkingSpeed: nil, walkingStepLength: nil, walkingAsymmetry: nil,
        walkingDoubleSupport: nil, walkingSteadiness: nil,
        stairAscentSpeed: nil, stairDescentSpeed: nil, sixMinuteWalkDistance: nil,
        exerciseMinutes: nil, standMinutes: nil, flightsClimbed: nil,
        distanceKm: nil, cyclingDistanceKm: nil,
        environmentalNoisedB: nil, headphoneNoisedB: nil, timeInDaylight: nil,
        bodyTemperature: nil,
        waterMl: nil, caffeineMg: nil, dietaryEnergyKcal: nil,
        dietaryProteinG: nil, dietaryCarbsG: nil, dietaryFatG: nil,
        mindfulMinutes: nil, sleepBreathingDisturbances: nil
    )
}

enum ReadinessDecisionKind: String, Codable, Hashable, CaseIterable {
    case keep
    case reduce
    case swap
    case recover
}

struct TodayHealthSignal: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var value: String
    var baseline: String?
    var interpretation: String
    var source: HealthDataSource
    var confidence: DataConfidence
    var metricKey: String
}

struct TodayAction: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, Hashable, CaseIterable {
        case training
        case recovery
        case checkIn
        case coach
        case insight
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var destination: String
    var isPrimary: Bool
}

struct ReadinessDecision: Codable, Hashable {
    var decision: ReadinessDecisionKind
    var confidence: Double
    var reasons: [String]
    var supportingSignals: [TodayHealthSignal]
    var suggestedActions: [TodayAction]
    var userOverrideAvailable: Bool

    var displayTitle: String {
        switch decision {
        case .keep: return "按计划训练"
        case .reduce: return "降低容量"
        case .swap: return "替换训练"
        case .recover: return "恢复优先"
        }
    }
}

struct TodayCommandState: Codable, Hashable {
    var date: Date
    var bodyStateTitle: String
    var summary: String
    var readinessDecision: ReadinessDecision
    var keySignals: [TodayHealthSignal]
    var actions: [TodayAction]
    var coachArtifact: CoachArtifact?
    var dataConfidence: DataConfidence
}

enum TodayCommandBuilder {
    static func build(
        from dashboard: DashboardSummary,
        recentStrengthSummary: RecentTrainingSummary? = nil,
        coachArtifact: CoachArtifact? = nil,
        generatedAt: Date = Date()
    ) -> TodayCommandState {
        let signals = keySignals(from: dashboard, recentStrengthSummary: recentStrengthSummary)
        let decision = readinessDecision(from: dashboard, signals: signals, recentStrengthSummary: recentStrengthSummary)
        let actions = actions(for: decision.decision, dashboard: dashboard)
        let artifact = coachArtifact ?? localMorningBrief(from: dashboard, decision: decision, generatedAt: generatedAt)
        let confidence = aggregateConfidence(dashboard: dashboard, signals: signals)

        return TodayCommandState(
            date: dashboard.date,
            bodyStateTitle: title(for: decision.decision, dashboard: dashboard),
            summary: summary(for: decision.decision, dashboard: dashboard),
            readinessDecision: ReadinessDecision(
                decision: decision.decision,
                confidence: decision.confidence,
                reasons: decision.reasons,
                supportingSignals: signals,
                suggestedActions: actions,
                userOverrideAvailable: true
            ),
            keySignals: Array(signals.prefix(5)),
            actions: actions,
            coachArtifact: artifact,
            dataConfidence: confidence
        )
    }

    private static func readinessDecision(
        from dashboard: DashboardSummary,
        signals: [TodayHealthSignal],
        recentStrengthSummary: RecentTrainingSummary?
    ) -> (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]) {
        var reasons: [String] = []
        if !dashboard.recovery.hasData {
            return (.reduce, 0.32, ["恢复基线数据不足，先按保守方案执行。"])
        }

        if let first = dashboard.recovery.reasons.first {
            reasons.append(first)
        }
        if dashboard.recovery.score < 40 {
            reasons.append("Recovery \(Int(dashboard.recovery.score.rounded())) is below the recovery-day threshold.")
            return (.recover, 0.86, reasons)
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 55 {
            reasons.append("Sleep score \(Int(dashboard.sleepScore.score.rounded())) is limiting readiness.")
            return (.recover, 0.78, reasons)
        }
        if dashboard.stress.hasData, dashboard.stress.stressIndex > 78 {
            reasons.append("Physiological stress is elevated.")
            return (.recover, 0.74, reasons)
        }
        if let summary = recentStrengthSummary,
           summary.localFatigue.values.contains(where: { $0.setsLast48h >= 10 || $0.setsLast7d >= 18 }) {
            reasons.append("Local muscle fatigue is high from recent strength work.")
            return (.swap, 0.72, reasons)
        }
        if dashboard.recovery.score < 62 || dashboard.sleepScore.score < 68 {
            reasons.append("Recovery or sleep is not low enough for rest, but not strong enough for full volume.")
            return (.reduce, 0.68, reasons)
        }
        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            reasons.append("Current strain is already above today's target range.")
            return (.reduce, 0.7, reasons)
        }

        if reasons.isEmpty {
            reasons.append("Recovery, sleep, and strain are within an actionable range.")
        }
        return (.keep, 0.76, reasons)
    }

    private static func keySignals(
        from dashboard: DashboardSummary,
        recentStrengthSummary: RecentTrainingSummary?
    ) -> [TodayHealthSignal] {
        var signals: [TodayHealthSignal] = []
        signals.append(TodayHealthSignal(
            id: "recovery",
            title: "Recovery",
            value: dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--",
            baseline: nil,
            interpretation: dashboard.recovery.reasons.first ?? "恢复数据仍在建立基线。",
            source: .computed,
            confidence: confidence(from: dashboard.recovery.confidence),
            metricKey: "recovery"
        ))
        signals.append(TodayHealthSignal(
            id: "sleep",
            title: "Sleep",
            value: dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--",
            baseline: dashboard.sleepSummary.totalSleepMinutes > 0 ? "\(dashboard.sleepSummary.totalSleepMinutes) min" : nil,
            interpretation: dashboard.sleepScore.reasons.first ?? "睡眠数据不足。",
            source: .computed,
            confidence: confidence(from: dashboard.sleepScore.confidence),
            metricKey: "sleep"
        ))
        let hrvValue = dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "--"
        let hrvBaseline = dashboard.recoveryBaseline.hrvMilliseconds.map { "\(Int($0.rounded())) ms baseline" }
        signals.append(TodayHealthSignal(
            id: "hrv",
            title: "HRV vs baseline",
            value: hrvValue,
            baseline: hrvBaseline,
            interpretation: hrvInterpretation(dashboard),
            source: .healthKit,
            confidence: dashboard.recoveryMetrics.hrvMilliseconds == nil ? .unavailable : .high,
            metricKey: "recovery"
        ))
        let rhrValue = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--"
        let rhrBaseline = dashboard.recoveryBaseline.restingHeartRate.map { "\(Int($0.rounded())) bpm baseline" }
        signals.append(TodayHealthSignal(
            id: "rhr",
            title: "Resting HR",
            value: rhrValue,
            baseline: rhrBaseline,
            interpretation: rhrInterpretation(dashboard),
            source: .healthKit,
            confidence: dashboard.recoveryMetrics.restingHeartRate == nil ? .unavailable : .high,
            metricKey: "recovery"
        ))
        signals.append(TodayHealthSignal(
            id: "strain",
            title: "Training load",
            value: dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--",
            baseline: "target \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)",
            interpretation: dashboard.strain.reasons.first ?? "负荷数据不足。",
            source: .computed,
            confidence: confidence(from: dashboard.strain.confidence),
            metricKey: "strain"
        ))
        if let summary = recentStrengthSummary, !summary.muscleGroupSets.isEmpty {
            let top = summary.muscleGroupSets.sorted { $0.value > $1.value }.first
            signals.append(TodayHealthSignal(
                id: "local_fatigue",
                title: "Local fatigue",
                value: top.map { "\($0.key) \($0.value) sets" } ?? "--",
                baseline: "7d effective sets",
                interpretation: "近期肌群组数会影响今天是否换部位或减量。",
                source: .computed,
                confidence: .medium,
                metricKey: "training"
            ))
        }
        return signals
    }

    private static func actions(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> [TodayAction] {
        switch decision {
        case .keep:
            return [
                TodayAction(id: "start_training", kind: .training, title: "开始今日训练", detail: "按计划执行，训练中保留 1-2 次余力。", destination: "training", isPrimary: true),
                TodayAction(id: "why_this", kind: .insight, title: "查看证据", detail: "打开 HRV、睡眠、负荷和恢复解释。", destination: "evidence", isPrimary: false)
            ]
        case .reduce:
            return [
                TodayAction(id: "reduce_volume", kind: .training, title: "训练容量降低 20%", detail: "保留动作模式，减少组数或 RPE。", destination: "training", isPrimary: true),
                TodayAction(id: "check_in", kind: .checkIn, title: "记录疲劳/酸痛", detail: "把主观反馈写入今天的上下文。", destination: "journal", isPrimary: false)
            ]
        case .swap:
            return [
                TodayAction(id: "swap_workout", kind: .training, title: "替换训练部位", detail: "避开高疲劳肌群，改做低冲击训练。", destination: "training", isPrimary: true),
                TodayAction(id: "ask_coach_swap", kind: .coach, title: "让 Coach 改计划", detail: dashboard.trainingDecision.coachQuestion, destination: "coach", isPrimary: false)
            ]
        case .recover:
            return [
                TodayAction(id: "recovery_plan", kind: .recovery, title: "执行恢复日", detail: "轻量活动、补水、晚间提前睡眠。", destination: "recovery", isPrimary: true),
                TodayAction(id: "why_this", kind: .insight, title: "为什么这样安排", detail: "查看 HRV、RHR、睡眠和压力证据。", destination: "evidence", isPrimary: false)
            ]
        }
    }

    private static func localMorningBrief(
        from dashboard: DashboardSummary,
        decision: (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]),
        generatedAt: Date
    ) -> CoachArtifact {
        CoachArtifact(
            type: .morningBrief,
            title: "今日身体简报",
            summary: summary(for: decision.decision, dashboard: dashboard),
            createdAt: generatedAt,
            relatedDate: dashboard.date,
            decision: decision.decision.rawValue,
            confidence: decision.confidence,
            reasons: decision.reasons.prefix(3).map {
                CoachArtifactReason(signal: "readiness", value: decision.decision.rawValue, explanation: $0)
            },
            actions: actions(for: decision.decision, dashboard: dashboard).map {
                CoachArtifactAction(type: $0.destination, label: $0.title, payload: ["action_id": $0.id])
            },
            sourceContextHash: ContentHash.hash("\(dashboard.date.timeIntervalSince1970)-\(dashboard.recovery.score)-\(dashboard.sleepScore.score)-\(dashboard.strain.score)")
        )
    }

    private static func title(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> String {
        switch decision {
        case .keep: return "状态可训练"
        case .reduce: return "可训练，但建议减量"
        case .swap: return "建议换训练内容"
        case .recover: return "恢复优先"
        }
    }

    private static func summary(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> String {
        let recovery = Int(dashboard.recovery.score.rounded())
        let sleep = Int(dashboard.sleepScore.score.rounded())
        let strain = Int(dashboard.strain.score.rounded())
        switch decision {
        case .keep:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天可以按计划训练，保持技术质量。"
        case .reduce:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天不需要完全休息，但应降低容量或强度。"
        case .swap:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。近期局部疲劳偏高，建议替换训练内容。"
        case .recover:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天优先恢复，避免高强度训练。"
        }
    }

    private static func hrvInterpretation(_ dashboard: DashboardSummary) -> String {
        guard let hrv = dashboard.recoveryMetrics.hrvMilliseconds,
              let baseline = dashboard.recoveryBaseline.hrvMilliseconds,
              baseline > 0 else {
            return "HRV 基线仍在建立。"
        }
        let delta = (hrv - baseline) / baseline
        if delta < -0.10 { return "HRV 低于个人基线，提示自主神经恢复压力偏高。" }
        if delta > 0.10 { return "HRV 高于个人基线，恢复信号较积极。" }
        return "HRV 接近个人基线。"
    }

    private static func rhrInterpretation(_ dashboard: DashboardSummary) -> String {
        guard let rhr = dashboard.recoveryMetrics.restingHeartRate,
              let baseline = dashboard.recoveryBaseline.restingHeartRate else {
            return "静息心率基线仍在建立。"
        }
        if rhr >= baseline + 4 { return "静息心率高于基线，可能存在恢复压力。" }
        if rhr <= baseline - 3 { return "静息心率低于基线，恢复信号较好。" }
        return "静息心率接近基线。"
    }

    private static func aggregateConfidence(dashboard: DashboardSummary, signals: [TodayHealthSignal]) -> DataConfidence {
        if !dashboard.recovery.hasData { return .unavailable }
        if signals.contains(where: { $0.confidence == .unavailable }) { return .low }
        if [dashboard.recovery.confidence, dashboard.sleepScore.confidence, dashboard.strain.confidence].contains(.low) {
            return .low
        }
        if [dashboard.recovery.confidence, dashboard.sleepScore.confidence, dashboard.strain.confidence].contains(.medium) {
            return .medium
        }
        return .high
    }

    private static func confidence(from metricConfidence: MetricConfidence) -> DataConfidence {
        switch metricConfidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

enum BehaviorTag: String, Codable, Hashable, CaseIterable {
    case alcohol
    case caffeine
    case lateMeal
    case highFat
    case highSalt
    case highSugar
    case overeating
    case lowHydration
    case spicy
    case lowProtein

    var displayTitle: String {
        switch self {
        case .alcohol: return "饮酒"
        case .caffeine: return "咖啡因"
        case .lateMeal: return "晚餐过晚"
        case .highFat: return "高油"
        case .highSalt: return "高盐"
        case .highSugar: return "高糖"
        case .overeating: return "吃撑"
        case .lowHydration: return "补水不足"
        case .spicy: return "辛辣"
        case .lowProtein: return "蛋白不足"
        }
    }
}

enum BehaviorIntensity: String, Codable, Hashable, CaseIterable {
    case low
    case medium
    case high
}

enum BehaviorTiming: String, Codable, Hashable, CaseIterable {
    case morning
    case midday
    case evening
    case preSleep
    case unknown
}

enum BehaviorSignalConfidence: String, Codable, Hashable, CaseIterable {
    case userConfirmed
    case aiInferred
    case photoAssisted
}

struct BehaviorSignal: Codable, Hashable, Identifiable {
    var id: String
    var tag: BehaviorTag
    var intensity: BehaviorIntensity
    var timing: BehaviorTiming
    var confidence: BehaviorSignalConfidence
    var sourceNote: String
    var createdAt: Date
}

enum BehaviorSignalExtractor {
    static func extract(
        from text: String,
        createdAt: Date = Date(),
        confidence: BehaviorSignalConfidence = .aiInferred
    ) -> [BehaviorSignal] {
        let lowered = text.lowercased()
        var signals: [BehaviorTag: BehaviorSignal] = [:]

        func timing(default fallback: BehaviorTiming = .unknown) -> BehaviorTiming {
            if lowered.contains("睡前") || lowered.contains("临睡") || lowered.contains("before bed") { return .preSleep }
            if lowered.contains("早上") || lowered.contains("早餐") || lowered.contains("morning") { return .morning }
            if lowered.contains("中午") || lowered.contains("午餐") || lowered.contains("lunch") { return .midday }
            if lowered.contains("晚上") || lowered.contains("晚餐") || lowered.contains("夜宵") || lowered.contains("dinner") { return .evening }
            return fallback
        }

        func intensity(for tag: BehaviorTag) -> BehaviorIntensity {
            if tag == .overeating, lowered.contains("吃撑") || lowered.contains("撑") {
                return .high
            }
            if lowered.contains("两杯") || lowered.contains("2杯") || lowered.contains("中等") || lowered.contains("medium") {
                return .medium
            }
            if lowered.contains("一点") || lowered.contains("少量") || lowered.contains("一杯") || lowered.contains("1杯") {
                return .low
            }
            if lowered.contains("很多") || lowered.contains("大量") || lowered.contains("high") {
                return .high
            }
            switch tag {
            case .overeating: return .high
            case .alcohol: return .medium
            default: return .medium
            }
        }

        func add(_ tag: BehaviorTag, timing explicitTiming: BehaviorTiming? = nil) {
            signals[tag] = BehaviorSignal(
                id: "\(Int(createdAt.timeIntervalSince1970))-\(tag.rawValue)",
                tag: tag,
                intensity: intensity(for: tag),
                timing: explicitTiming ?? timing(default: .unknown),
                confidence: confidence,
                sourceNote: text,
                createdAt: createdAt
            )
        }

        if lowered.contains("酒") || lowered.contains("啤酒") || lowered.contains("红酒") || lowered.contains("白酒") || lowered.contains("alcohol") || lowered.contains("beer") {
            add(.alcohol)
        }
        if lowered.contains("咖啡") || lowered.contains("拿铁") || lowered.contains("美式") || lowered.contains("caffeine") || lowered.contains("coffee") {
            add(.caffeine, timing: lowered.contains("睡前") ? .preSleep : nil)
        }
        if lowered.contains("夜宵") || lowered.contains("很晚") || lowered.contains("晚吃") || lowered.contains("late meal") {
            add(.lateMeal)
        }
        if lowered.contains("火锅") || lowered.contains("油炸") || lowered.contains("炸鸡") || lowered.contains("烧烤") || lowered.contains("高油") || lowered.contains("high fat") {
            add(.highFat)
        }
        if lowered.contains("火锅") || lowered.contains("烧烤") || lowered.contains("外卖") || lowered.contains("咸") || lowered.contains("高盐") || lowered.contains("high salt") {
            add(.highSalt)
        }
        if lowered.contains("甜") || lowered.contains("奶茶") || lowered.contains("蛋糕") || lowered.contains("高糖") || lowered.contains("sugar") {
            add(.highSugar)
        }
        if lowered.contains("吃撑") || lowered.contains("撑了") || lowered.contains("过饱") || lowered.contains("overeating") {
            add(.overeating)
        }
        if lowered.contains("没喝水") || lowered.contains("喝水少") || lowered.contains("缺水") || lowered.contains("low hydration") {
            add(.lowHydration)
        }
        if lowered.contains("辣") || lowered.contains("辛辣") || lowered.contains("spicy") {
            add(.spicy)
        }
        if lowered.contains("蛋白不足") || lowered.contains("没吃蛋白") || lowered.contains("low protein") {
            add(.lowProtein)
        }
        return signals.values.sorted { $0.tag.rawValue < $1.tag.rawValue }
    }

    static func extract(from entry: JournalEntryRecord) -> [BehaviorSignal] {
        var signals = extract(from: entry.note, createdAt: entry.createdAt)
        for tag in entry.tags {
            guard tag.hasPrefix("behavior:"),
                  let behavior = BehaviorTag(rawValue: String(tag.dropFirst("behavior:".count))) else {
                continue
            }
            if !signals.contains(where: { $0.tag == behavior }) {
                signals.append(BehaviorSignal(
                    id: "\(Int(entry.createdAt.timeIntervalSince1970))-\(behavior.rawValue)",
                    tag: behavior,
                    intensity: intensity(from: entry.tags),
                    timing: .unknown,
                    confidence: .userConfirmed,
                    sourceNote: entry.note,
                    createdAt: entry.createdAt
                ))
            }
        }
        return signals.sorted { $0.tag.rawValue < $1.tag.rawValue }
    }

    private static func intensity(from tags: [String]) -> BehaviorIntensity {
        if tags.contains("intensity:high") { return .high }
        if tags.contains("intensity:low") { return .low }
        return .medium
    }
}

enum BodyModelMaturityLevel: String, Codable, Hashable, CaseIterable {
    case seed
    case learning
    case stable
}

struct BodyModelMaturity: Codable, Hashable {
    var overall: BodyModelMaturityLevel
    var baselineDays: Int
    var behaviorPairs: Int
    var trainingSessions: Int
}

struct BodyModelClaim: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var confidence: DataConfidence
    var evidenceCount: Int
}

struct BodyModelUncertainArea: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var detail: String
}

struct BodyModelState: Codable, Hashable {
    var generatedAt: Date
    var maturity: BodyModelMaturity
    var claims: [BodyModelClaim]
    var uncertainAreas: [BodyModelUncertainArea]
    var behaviorSignals: [BehaviorSignal]
    var trainingPatternSummary: String
    var coachRules: [String]
}

struct BodyModelBuilder {
    func build(
        onboarding: OnboardingState?,
        dailySummaries: [DailyHealthSummaryRecord],
        journalEntries: [JournalEntryRecord],
        strengthWorkouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> BodyModelState {
        let baselineDays = Set(dailySummaries.map { calendar.startOfDay(for: $0.date) }).count
        let behaviorSignals = journalEntries.flatMap { BehaviorSignalExtractor.extract(from: $0) }
        let behaviorPairs = behaviorSignals.count
        let trainingSessions = strengthWorkouts.count
        let maturity = BodyModelMaturity(
            overall: maturityLevel(baselineDays: baselineDays, behaviorPairs: behaviorPairs, trainingSessions: trainingSessions),
            baselineDays: baselineDays,
            behaviorPairs: behaviorPairs,
            trainingSessions: trainingSessions
        )

        var claims: [BodyModelClaim] = []
        if let onboarding {
            claims.append(BodyModelClaim(
                id: "profile_seed",
                title: "目标与训练偏好已建立",
                summary: "目标 \(onboarding.goalProfile.primaryGoal)，训练风格 \(onboarding.trainingPreference.trainingStyle)，每周 \(onboarding.trainingPreference.weeklyTrainingDays) 次。",
                confidence: onboarding.isCompleted ? .medium : .low,
                evidenceCount: 1
            ))
        }
        if trainingSessions > 0 {
            let analysis = TrainingAnalyticsService().buildRecentSummary(workouts: strengthWorkouts, days: 28, endingAt: asOf)
            claims.append(BodyModelClaim(
                id: "training_facts",
                title: "训练事实正在积累",
                summary: "近 28 天 \(analysis.sessions) 次训练，\(analysis.effectiveSets) 个有效组；这些数据会先用于局部疲劳和训练后反应观察。",
                confidence: trainingSessions >= 6 ? .medium : .low,
                evidenceCount: trainingSessions
            ))
        }
        if behaviorPairs >= 6 {
            let grouped = Dictionary(grouping: behaviorSignals, by: \.tag)
            if let top = grouped.max(by: { $0.value.count < $1.value.count }) {
                claims.append(BodyModelClaim(
                    id: "behavior_pattern_\(top.key.rawValue)",
                    title: "行为信号样本开始可用",
                    summary: "\(top.key.displayTitle) 已记录 \(top.value.count) 次。下一步会和次日睡眠、HRV、RHR、恢复进行配对分析。",
                    confidence: .medium,
                    evidenceCount: top.value.count
                ))
            }
        }

        var uncertain: [BodyModelUncertainArea] = []
        if baselineDays < 7 {
            uncertain.append(BodyModelUncertainArea(
                id: "baseline_history",
                title: "个人基线仍在建立",
                detail: "需要至少 7 天健康摘要，才能把 HRV、RHR、睡眠和负荷判断从通用规则转向个人基线。"
            ))
        }
        if behaviorPairs < 6 {
            uncertain.append(BodyModelUncertainArea(
                id: "behavior_pairs",
                title: "行为-结果配对不足",
                detail: "饮食、咖啡因、饮酒、补水等行为至少需要约 6 次配对记录后才报告个人化影响。"
            ))
        }
        if trainingSessions < 3 || trainingResponses.count < 3 {
            uncertain.append(BodyModelUncertainArea(
                id: "training_response",
                title: "训练后反应样本不足",
                detail: "需要更多训练事实和次日恢复反馈，才能判断不同肌群/容量对你的恢复冲击。"
            ))
        }

        return BodyModelState(
            generatedAt: asOf,
            maturity: maturity,
            claims: claims,
            uncertainAreas: uncertain,
            behaviorSignals: behaviorSignals,
            trainingPatternSummary: trainingSummary(strengthWorkouts, asOf: asOf),
            coachRules: coachRules(for: maturity, uncertainAreas: uncertain)
        )
    }

    private func maturityLevel(baselineDays: Int, behaviorPairs: Int, trainingSessions: Int) -> BodyModelMaturityLevel {
        if baselineDays >= 28, behaviorPairs >= 12, trainingSessions >= 8 { return .stable }
        if baselineDays >= 7 || behaviorPairs >= 6 || trainingSessions >= 3 { return .learning }
        return .seed
    }

    private func trainingSummary(_ workouts: [StrengthWorkoutRecord], asOf: Date) -> String {
        guard !workouts.isEmpty else { return "尚无训练事实。训记或 Vela 训练记录同步后会开始学习训练反应。" }
        let summary = TrainingAnalyticsService().buildRecentSummary(workouts: workouts, days: 28, endingAt: asOf)
        return "近 28 天 \(summary.sessions) 次训练，\(summary.effectiveSets) 个有效组，容量 \(Int(summary.volumeKg.rounded())) kg。"
    }

    private func coachRules(for maturity: BodyModelMaturity, uncertainAreas: [BodyModelUncertainArea]) -> [String] {
        var rules = [
            "只把样本充足的模式描述为个人规律；样本不足时使用“正在学习”。",
            "训练建议必须同时展示证据、置信度和可替代行动。"
        ]
        if maturity.overall == .seed {
            rules.append("Body Model 处于种子期，Coach 默认采用保守训练建议。")
        }
        if uncertainAreas.contains(where: { $0.id == "behavior_pairs" }) {
            rules.append("行为影响暂不下结论，只收集低摩擦手记信号。")
        }
        return rules
    }
}

enum DailyPlanKind: String, Codable, Hashable {
    case rest
    case recovery
    case train
    case maintain
    case protectSleep
    case downshift
}

enum DailyPlanAccent: String, Codable, Hashable {
    case recovery
    case sleep
    case strain
    case energy
    case stress
}

enum DailyPlanLimiterKind: String, Codable, Hashable {
    case hrv
    case restingHeartRate
    case sleep
    case strain
    case energy
    case stress
}

struct DailyPlanLimiter: Codable, Hashable {
    var kind: DailyPlanLimiterKind
    var accent: DailyPlanAccent
    var title: String
    var detail: String
    var severity: Double
}

struct DailyPlanRecommendation: Codable, Hashable {
    var kind: DailyPlanKind
    var accent: DailyPlanAccent
    var title: String
    var body: String
    var primaryActionTitle: String
    var secondaryActionTitle: String?
    var coachQuestion: String
    var limiter: DailyPlanLimiter?
}

enum DailyPlanEngine {
    static func recommendation(
        for dashboard: DashboardSummary,
        journalFlags: Set<String> = []
    ) -> DailyPlanRecommendation {
        let limiter = mainLimiter(for: dashboard)

        if !journalFlags.isDisjoint(with: ["sick", "injured"]) {
            return DailyPlanRecommendation(
                kind: .rest,
                accent: .recovery,
                title: L10n.t("Make today a rest day", "今天安排休息"),
                body: L10n.t(
                    "Your journal reports illness or injury. Skip training and focus on recovery. Seek medical advice if symptoms are significant or persistent.",
                    "你的日志记录了生病或受伤。今天停止训练，专注恢复。如果症状明显或持续，请咨询医生。"
                ),
                primaryActionTitle: L10n.t("Plan a rest day", "规划休息日"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Build a rest-day recovery plan for me. My journal reports illness or injury, so do not prescribe training.",
                    "请为我制定休息日恢复计划。我的日志记录了生病或受伤，因此不要安排训练。"
                ),
                limiter: nil
            )
        }

        if journalFlags.contains("resting") {
            return DailyPlanRecommendation(
                kind: .rest,
                accent: .recovery,
                title: L10n.t("Keep today as a rest day", "今天保持休息"),
                body: L10n.t(
                    "You marked today as a rest period. Skip planned training and focus on recovery habits.",
                    "你已将今天标记为休息期。暂停计划训练，优先安排恢复习惯。"
                ),
                primaryActionTitle: L10n.t("Plan a rest day", "规划休息日"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Build a rest-day recovery plan for me. I marked today as a rest period, so do not prescribe training.",
                    "请为我制定休息日恢复计划。我已将今天标记为休息期，因此不要安排训练。"
                ),
                limiter: nil
            )
        }

        if !dashboard.recovery.hasData {
            return DailyPlanRecommendation(
                kind: .maintain,
                accent: .energy,
                title: L10n.t("Connect your baseline", "先建立你的基线"),
                body: L10n.t(
                    "Vela needs Apple Health recovery data before it can make a confident daily plan.",
                    "Vela 需要 Apple 健康的恢复数据，才能给出可信的今日计划。"
                ),
                primaryActionTitle: L10n.t("Ask what to set up", "询问如何设置"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Tell me what health permissions and data I need to enable so Vela can generate a reliable daily plan.",
                    "请告诉我需要开启哪些健康权限和数据，才能让 Vela 生成可靠的今日计划。"
                ),
                limiter: nil
            )
        }

        if dashboard.recovery.score < 40 {
            return DailyPlanRecommendation(
                kind: .recovery,
                accent: .recovery,
                title: L10n.t("Make today a recovery day", "今天按恢复日处理"),
                body: bodyWithLimiter(
                    L10n.t(
                    "Recovery is low. Keep training very light and spend your effort on sleep, food, hydration, and lowering physiological stress.",
                    "恢复偏低。训练保持很轻，把精力放在睡眠、饮食、补水和降低生理压力上。"
                    ),
                    limiter: limiter
                ),
                primaryActionTitle: L10n.t("Plan recovery day", "规划恢复日"),
                secondaryActionTitle: L10n.t("Check limiting factor", "查看限制因素"),
                coachQuestion: coachQuestion(
                    base: L10n.t(
                    "Build a recovery day plan for me based on today's recovery, sleep, strain, stress, and energy. Be specific and tell me what training to avoid.",
                    "请基于今天的恢复、睡眠、负荷、压力和能量，为我制定一个恢复日计划。要具体，并告诉我哪些训练应该避免。"
                    ),
                    dashboard: dashboard,
                    limiter: limiter
                ),
                limiter: limiter
            )
        }

        if dashboard.recovery.score >= 70 && dashboard.strain.score < Double(dashboard.strain.recommendedRange.lowerBound) {
            return DailyPlanRecommendation(
                kind: .train,
                accent: .strain,
                title: L10n.t("Training window is open", "今天有训练窗口"),
                body: bodyWithLimiter(
                    L10n.t(
                    "Recovery is strong and current strain is still below target. This is a good window to add a controlled training stimulus.",
                    "恢复较好，而且当前负荷还低于目标区间。今天适合加入一次可控训练刺激。"
                    ),
                    limiter: limiter
                ),
                primaryActionTitle: L10n.t("Build today's session", "生成今日训练"),
                secondaryActionTitle: L10n.t("Set target strain", "设定目标负荷"),
                coachQuestion: coachQuestion(
                    base: L10n.t(
                    "Use my recovery, strain target range, energy, stress, sleep, and training history to create today's training session. Include warm-up, main work, intensity, and when to stop.",
                    "请基于我的恢复、负荷目标区间、能量、压力、睡眠和训练历史，生成今天的训练内容。包括热身、主训练、强度和停止条件。"
                    ),
                    dashboard: dashboard,
                    limiter: limiter
                ),
                limiter: limiter
            )
        }

        return DailyPlanRecommendation(
            kind: .maintain,
            accent: .energy,
            title: L10n.t("Keep the day controlled", "今天保持可控"),
            body: bodyWithLimiter(
                L10n.t(
                "Your signals are mixed. Keep the day steady: avoid chasing a high strain score and protect tonight's sleep.",
                "今天信号比较混合。保持节奏稳定：不要强行追高负荷，优先保护今晚睡眠。"
                ),
                limiter: limiter
            ),
            primaryActionTitle: L10n.t("Get today's plan", "获取今日计划"),
            secondaryActionTitle: L10n.t("Review signals", "复盘关键指标"),
            coachQuestion: coachQuestion(
                base: L10n.t(
                "Give me a controlled daily plan based on today's recovery, sleep, strain, stress, and energy. Start with what I should do, then what I should avoid.",
                "请基于今天的恢复、睡眠、负荷、压力和能量，给我一个可控的今日计划。先说我应该做什么，再说应该避免什么。"
                ),
                dashboard: dashboard,
                limiter: limiter
            ),
            limiter: limiter
        )
    }

    private static func mainLimiter(for dashboard: DashboardSummary) -> DailyPlanLimiter? {
        var candidates: [DailyPlanLimiter] = []

        if let hrvScore = dashboard.recovery.components["hrv"], hrvScore < 50 {
            let z = dashboard.recovery.metrics["hrv_z_score"].map { String(format: "%.1f", $0) }
            candidates.append(.init(
                kind: .hrv,
                accent: .recovery,
                title: L10n.t("HRV is the limiter", "HRV 是主要限制因素"),
                detail: z.map { L10n.t("HRV z-score \($0)", "HRV z 值 \($0)") } ?? L10n.t("Autonomic recovery is below baseline", "自主神经恢复低于基线"),
                severity: 100 - hrvScore
            ))
        }

        if let rhrScore = dashboard.recovery.components["rhr"], rhrScore < 50 {
            let today = dashboard.recoveryMetrics.restingHeartRate
            let baseline = dashboard.recoveryBaseline.restingHeartRate
            let detail: String
            if let today, let baseline {
                detail = L10n.t("RHR \(Int(today))bpm vs \(Int(baseline))bpm baseline", "静息心率 \(Int(today))bpm，基线 \(Int(baseline))bpm")
            } else {
                detail = L10n.t("Resting heart rate is above baseline", "静息心率高于基线")
            }
            candidates.append(.init(
                kind: .restingHeartRate,
                accent: .recovery,
                title: L10n.t("Resting HR is elevated", "静息心率偏高"),
                detail: detail,
                severity: 100 - rhrScore
            ))
        }

        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 70 {
            candidates.append(.init(
                kind: .sleep,
                accent: .sleep,
                title: L10n.t("Sleep is limiting recovery", "睡眠限制恢复"),
                detail: dashboard.sleepScore.reasons.first.map(localizedReason) ?? L10n.t("Sleep score is below target", "睡眠评分低于目标"),
                severity: 70 - dashboard.sleepScore.score
            ))
        }

        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            candidates.append(.init(
                kind: .strain,
                accent: .strain,
                title: L10n.t("Strain is above target", "负荷高于目标"),
                detail: L10n.t("Current strain \(Int(dashboard.strain.score)) vs target \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)", "当前负荷 \(Int(dashboard.strain.score))，目标 \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)"),
                severity: dashboard.strain.score - Double(dashboard.strain.recommendedRange.upperBound)
            ))
        }

        if dashboard.energy.hasData, dashboard.energy.currentEnergy < 35 {
            candidates.append(.init(
                kind: .energy,
                accent: .energy,
                title: L10n.t("Energy reserve is low", "能量储备偏低"),
                detail: L10n.t("Current energy \(Int(dashboard.energy.currentEnergy))", "当前能量 \(Int(dashboard.energy.currentEnergy))"),
                severity: 35 - dashboard.energy.currentEnergy
            ))
        }

        if dashboard.stress.hasData, dashboard.stress.stressIndex > 70 {
            candidates.append(.init(
                kind: .stress,
                accent: .stress,
                title: L10n.t("Stress load is high", "压力负荷偏高"),
                detail: L10n.t("Stress index \(Int(dashboard.stress.stressIndex))", "压力指数 \(Int(dashboard.stress.stressIndex))"),
                severity: dashboard.stress.stressIndex - 70
            ))
        }

        return candidates.max { $0.severity < $1.severity }
    }

    private static func bodyWithLimiter(_ body: String, limiter: DailyPlanLimiter?) -> String {
        guard let limiter else { return body }
        return L10n.t(
            "\(body) Main limiter: \(limiter.title).",
            "\(body) 主要限制因素：\(limiter.title)。"
        )
    }

    private static func coachQuestion(base: String, dashboard: DashboardSummary, limiter: DailyPlanLimiter?) -> String {
        let limiterText = limiter.map { "\($0.title) - \($0.detail)" } ?? L10n.t("none detected", "暂未识别")
        let snapshot = L10n.t(
            "Snapshot: Recovery \(Int(dashboard.recovery.score)), Sleep \(Int(dashboard.sleepScore.score)), Strain \(Int(dashboard.strain.score)), Energy \(Int(dashboard.energy.currentEnergy)), HRV \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "N/A"), RHR \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "N/A"), main limiter: \(limiterText).",
            "今日快照：恢复 \(Int(dashboard.recovery.score))，睡眠 \(Int(dashboard.sleepScore.score))，负荷 \(Int(dashboard.strain.score))，能量 \(Int(dashboard.energy.currentEnergy))，HRV \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "无")，静息心率 \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "无")，主要限制因素：\(limiterText)。"
        )
        return "\(base)\n\n\(snapshot)"
    }
}

enum CoachSnapshotDirective {
    static func build(
        dashboard: DashboardSummary,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let plan = dashboard.trainingDecision
        let limiterText = plan.limiter.map { "\($0.title) - \($0.detail)" } ?? L10n.t("none detected", "暂未识别")
        let time = formattedTime(generatedAt, calendar: calendar)
        let hrv = dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0.rounded()))ms" } ?? "N/A"
        let rhr = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded()))bpm" } ?? "N/A"
        let targetRange = "\(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)"

        if AppLanguage.stored.isChinese {
            return """
            ## 当前健康快照协议（必须优先于旧对话）
            - 生成时间：\(time)
            - 恢复 \(Int(dashboard.recovery.score.rounded()))，睡眠 \(Int(dashboard.sleepScore.score.rounded()))，负荷 \(Int(dashboard.strain.score.rounded()))（目标 \(targetRange)），能量 \(Int(dashboard.energy.currentEnergy.rounded()))，压力 \(Int(dashboard.stress.stressIndex.rounded()))
            - HRV \(hrv)，静息心率 \(rhr)
            - 主要限制因素：\(limiterText)

            回答健康或训练问题时，必须以这份最新快照为准；如果历史聊天与它冲突，以这里的数据为准。输出结构保持为：判断 / 原因 / 今天怎么做 / 不要做什么 / 可追问。不要把旧对话里的过期分数当成当前状态。
            """
        }

        return """
        ## Current Health Snapshot Protocol (fresh data has priority over old chat)
        - Generated at: \(time)
        - Recovery \(Int(dashboard.recovery.score.rounded())), Sleep \(Int(dashboard.sleepScore.score.rounded())), Strain \(Int(dashboard.strain.score.rounded())) (target \(targetRange)), Energy \(Int(dashboard.energy.currentEnergy.rounded())), Stress \(Int(dashboard.stress.stressIndex.rounded()))
        - HRV \(hrv), resting heart rate \(rhr)
        - Main limiter: \(limiterText)

        For health or training questions, treat this snapshot as the source of truth. If prior chat history conflicts with it, use these values. Keep the answer structure: judgment / reason / what to do today / what to avoid / follow-up. Do not reuse stale scores from older conversation turns as current state.
        """
    }

    private static func formattedTime(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm XXX"
        return formatter.string(from: date)
    }
}
