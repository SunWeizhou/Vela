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
                        safetyNotice: "仅提供一般健康与训练建议，不构成医疗诊断。"
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
                    title: "\(Self.localizedMuscleGroup($0.muscleGroup)) 局部疲劳",
                    detail: "过去 48 小时 \($0.setsLast48h) 个有效组，7 天累计 \($0.setsLast7d) 个有效组。",
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
                title: "近期训练响应",
                detail: "\(Self.localizedMuscleGroups(costly.primaryMuscleGroups))训练后，次日恢复变化 \(Self.signed(costly.nextDayRecoveryDelta))。",
                impact: -0.8,
                source: "TrainingResponseRecord"
            ))
        }

        if ["sick", "injured", "resting"].contains(input.activeStatus) {
            drivers.append(BodyStateDriver(
                id: "active-status",
                kind: .activeStatus,
                title: "当前身体状态",
                detail: "你标记为\(Self.localizedActiveStatus(input.activeStatus))，今天会自动降低训练冒险度。",
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
                title: "今日营养记录",
                detail: "今天已记录 \(calories) kcal，蛋白质 \(protein) g。",
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
                title: "近期主观记录",
                detail: latestJournal.note.isEmpty ? latestJournal.tags.joined(separator: ", ") : latestJournal.note,
                impact: 0,
                source: "JournalEntryRecord"
            ))
        }
        if let activePlan = input.activePlan {
            drivers.append(BodyStateDriver(
                id: "active-plan-\(activePlan.id.uuidString)",
                kind: .activePlan,
                title: "当前训练计划",
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
                title: "近期训练负荷",
                detail: "过去 48 小时 \(recentEvents.count) 次训练，累计 \(Int(minutes.rounded())) 分钟。",
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
                title: "数据覆盖不足",
                detail: "健康数据或本地记录不足，Vela 会先使用保守训练窗口。",
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
                title: "恢复",
                detail: reason,
                impact: dashboard.recovery.score >= 70 ? 0.7 : -0.7,
                source: "RecoveryScoreEngine \(dashboard.recovery.algorithmVersion)"
            ))
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 70 {
            drivers.append(.init(
                id: "sleep",
                kind: .sleep,
                title: "睡眠",
                detail: dashboard.sleepScore.reasons.first ?? "睡眠低于适合训练的范围。",
                impact: -0.6,
                source: "SleepScoreEngine \(dashboard.sleepScore.algorithmVersion)"
            ))
        }
        if dashboard.stress.hasData, dashboard.stress.score >= 75 {
            drivers.append(.init(
                id: "stress",
                kind: .stress,
                title: "压力",
                detail: dashboard.stress.reasons.first ?? "生理压力偏高。",
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
        guard let value else { return "尚未测量" }
        return String(format: "%+.1f", value)
    }

    private static func localizedMuscleGroups(_ groups: [String]) -> String {
        let localized = groups.map(localizedMuscleGroup).filter { !$0.isEmpty }
        guard !localized.isEmpty else { return "相关肌群" }
        return localized.joined(separator: "、")
    }

    private static func localizedMuscleGroup(_ group: String) -> String {
        switch group.lowercased() {
        case "chest": return "胸部"
        case "back": return "背部"
        case "shoulders": return "肩部"
        case "biceps": return "肱二头肌"
        case "triceps": return "肱三头肌"
        case "quads", "quadriceps": return "股四头肌"
        case "hamstrings": return "腘绳肌"
        case "glutes": return "臀部"
        case "core", "abs": return "核心"
        case "legs": return "腿部"
        default: return group
        }
    }

    private static func localizedActiveStatus(_ status: String) -> String {
        switch status {
        case "sick": return "生病"
        case "injured": return "受伤"
        case "resting": return "休息中"
        default: return "活跃"
        }
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
            summary = "今天优先休息或轻恢复，避免高强度训练。"
        } else if !highFatigue.isEmpty {
            type = .swap
            multiplier = 0.65
            cap = 7
            summary = "避开\(Self.localizedMuscleGroups(highFatigue))，改做低风险替代训练。"
        } else if state.readiness == .caution || state.readiness == .unknown {
            type = .reduce
            multiplier = state.readiness == .unknown ? 0.6 : 0.75
            cap = 7
            summary = "建议减量训练：降低计划容量，RPE 控制在 7 以内；动作质量或主观用力变差时停止加量。"
        } else {
            type = .keep
            multiplier = 1
            cap = 9
            summary = "可以按计划训练，但保留 1-2 次余力并根据动作质量自我调节。"
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
            reasons: reasons.isEmpty ? ["未发现明显限制因素。"] : reasons,
            userFacingSummary: summary,
            confidence: confidence,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "仅提供一般健康与训练建议，不构成医疗诊断；如出现异常症状，请停止训练并寻求专业帮助。"
        )
    }

    private static func localizedMuscleGroups(_ groups: [String]) -> String {
        let localized = groups.map(localizedMuscleGroup).filter { !$0.isEmpty }
        guard !localized.isEmpty else { return "相关肌群" }
        return localized.joined(separator: "、")
    }

    private static func localizedMuscleGroup(_ group: String) -> String {
        switch group.lowercased() {
        case "chest": return "胸部"
        case "back": return "背部"
        case "shoulders": return "肩部"
        case "biceps": return "肱二头肌"
        case "triceps": return "肱三头肌"
        case "quads", "quadriceps": return "股四头肌"
        case "hamstrings": return "腘绳肌"
        case "glutes": return "臀部"
        case "core", "abs": return "核心"
        case "legs": return "腿部"
        default: return group
        }
    }
}

struct DailyOperatingPlanPayload: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var volumeMultiplier: Double
    var intensityCap: Int
    var summary: String
    var targetSessionTitle: String?
}

struct DailyOperatingPlanDisplayModel: Codable, Hashable {
    var decision: DailyTrainingDecisionType
    var actionLabel: String
    var statusTitle: String
    var summary: String
    var evidenceLine: String
    var confidenceLabel: String

    static func build(
        payload: DailyOperatingPlanPayload?,
        primaryActionType: String?,
        source: String?,
        safetyNotice: String?,
        confidence: Double,
        isChinese: Bool = AppLanguage.stored.isChinese
    ) -> DailyOperatingPlanDisplayModel {
        let decision = payload?.decision
            ?? primaryActionType.flatMap(DailyTrainingDecisionType.init(rawValue:))
            ?? .keep
        let intensityCap = payload?.intensityCap ?? (decision == .rest ? 2 : 7)
        let volumeMultiplier = payload?.volumeMultiplier ?? defaultVolumeMultiplier(for: decision)
        let summary = localizedSummary(
            payloadSummary: payload?.summary,
            decision: decision,
            volumeMultiplier: volumeMultiplier,
            intensityCap: intensityCap,
            isChinese: isChinese
        )
        let evidence = localizedEvidenceLine(
            source: source,
            safetyNotice: safetyNotice,
            isChinese: isChinese
        )
        let roundedConfidence = Int((min(max(confidence, 0), 1) * 100).rounded())

        return DailyOperatingPlanDisplayModel(
            decision: decision,
            actionLabel: actionLabel(for: decision, isChinese: isChinese),
            statusTitle: statusTitle(for: decision, intensityCap: intensityCap, isChinese: isChinese),
            summary: summary,
            evidenceLine: evidence,
            confidenceLabel: isChinese ? "置信度 \(roundedConfidence)%" : "Confidence \(roundedConfidence)%"
        )
    }

    private static func defaultVolumeMultiplier(for decision: DailyTrainingDecisionType) -> Double {
        switch decision {
        case .keep: 1
        case .reduce: 0.75
        case .swap: 0.65
        case .rest: 0
        }
    }

    private static func actionLabel(for decision: DailyTrainingDecisionType, isChinese: Bool) -> String {
        switch decision {
        case .keep: return isChinese ? "按计划" : "KEEP"
        case .reduce: return isChinese ? "减量" : "REDUCE"
        case .swap: return isChinese ? "替换" : "SWAP"
        case .rest: return isChinese ? "恢复" : "REST"
        }
    }

    private static func statusTitle(
        for decision: DailyTrainingDecisionType,
        intensityCap: Int,
        isChinese: Bool
    ) -> String {
        if decision == .rest {
            return isChinese ? "建议恢复或休息" : "Recovery or rest advised"
        }
        return isChinese ? "建议训练 · RPE \(intensityCap)" : "Train today · RPE \(intensityCap)"
    }

    private static func localizedSummary(
        payloadSummary: String?,
        decision: DailyTrainingDecisionType,
        volumeMultiplier: Double,
        intensityCap: Int,
        isChinese: Bool
    ) -> String {
        if !isChinese, let payloadSummary, !payloadSummary.isEmpty {
            return payloadSummary
        }

        let volumePercent = Int((volumeMultiplier * 100).rounded())
        if isChinese {
            switch decision {
            case .keep:
                return "按计划训练，使用 RPE \(intensityCap) 作为上限，并根据动作质量做自我调节。"
            case .reduce:
                return "建议将今天训练容量降至 \(volumePercent)%，RPE 控制在 \(intensityCap) 以内；动作质量下降时停止加量。"
            case .swap:
                return "替换高疲劳部位的训练内容，保留约 \(volumePercent)% 的有效刺激，RPE 控制在 \(intensityCap) 以内。"
            case .rest:
                return "今天优先恢复：选择低强度活动、拉伸和睡眠补偿，避免追求训练量。"
            }
        }

        switch decision {
        case .keep:
            return "Keep the planned session with RPE capped at \(intensityCap) and autoregulate by technique quality."
        case .reduce:
            return "Reduce volume to \(volumePercent)% and keep RPE at or below \(intensityCap); stop adding load if technique deteriorates."
        case .swap:
            return "Swap away from highly fatigued areas, keep about \(volumePercent)% of the stimulus, and cap RPE at \(intensityCap)."
        case .rest:
            return "Prioritize recovery today with low-intensity activity, mobility, and sleep support instead of chasing volume."
        }
    }

    private static func localizedEvidenceLine(
        source: String?,
        safetyNotice: String?,
        isChinese: Bool
    ) -> String {
        if isChinese {
            let sourceText = (source?.isEmpty == false) ? "本地身体状态 + 训练决策" : "本地训练决策"
            let safetyText = (safetyNotice?.isEmpty == false) ? "一般健康与训练建议，不构成医疗诊断。" : "一般建议，不构成医疗诊断。"
            return "\(sourceText) · \(safetyText)"
        }
        let sourceText = source?.isEmpty == false ? source! : "Local training decision"
        let safetyText = safetyNotice?.isEmpty == false ? safetyNotice! : "General guidance only; not a medical diagnosis."
        return "\(sourceText) · \(safetyText)"
    }
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

    private static func numericConfidence(_ confidence: MetricConfidence) -> Double {
        switch confidence {
        case .high: return 1.0
        case .medium: return 0.7
        case .low: return 0.4
        }
    }

    public static func readinessDecision(
        from dashboard: DashboardSummary,
        signals: [TodayHealthSignal],
        recentStrengthSummary: RecentTrainingSummary?
    ) -> (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]) {
        var reasons: [String] = []
        if !dashboard.recovery.hasData {
            return (.reduce, 0.0, ["恢复基线数据不足，先按保守方案执行。"])
        }

        let recConf = dashboard.recovery.hasData ? numericConfidence(dashboard.recovery.confidence) : 0.0
        let sleepConf = dashboard.sleepScore.hasData ? numericConfidence(dashboard.sleepScore.confidence) : 0.0
        let stressConf = dashboard.stress.hasData ? numericConfidence(dashboard.stress.confidence) : 0.0
        
        let computedConf = 0.50 * recConf + 0.30 * sleepConf + 0.20 * stressConf
        let dynamicConfidence = max(0.3, min(1.0, computedConf))

        if let first = dashboard.recovery.reasons.first {
            reasons.append(first)
        }
        if dashboard.recovery.score < 40 {
            reasons.append("Recovery \(Int(dashboard.recovery.score.rounded())) is below the recovery-day threshold.")
            return (.recover, 0.86 * dynamicConfidence, reasons)
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 55 {
            reasons.append("Sleep score \(Int(dashboard.sleepScore.score.rounded())) is limiting readiness.")
            return (.recover, 0.78 * dynamicConfidence, reasons)
        }
        if dashboard.stress.hasData, dashboard.stress.stressIndex > 78 {
            reasons.append("Physiological stress is elevated.")
            return (.recover, 0.74 * dynamicConfidence, reasons)
        }
        if let summary = recentStrengthSummary,
           summary.localFatigue.values.contains(where: { $0.setsLast48h >= 15 || $0.setsLast7d >= 25 }) {
            reasons.append("Local muscle fatigue is high from recent strength work.")
            return (.swap, 0.72 * dynamicConfidence, reasons)
        }
        if dashboard.recovery.score < 62 || dashboard.sleepScore.score < 68 {
            reasons.append("Recovery or sleep is not low enough for rest, but not strong enough for full volume.")
            return (.reduce, 0.68 * dynamicConfidence, reasons)
        }
        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            reasons.append("Current strain is already above today's target range.")
            return (.reduce, 0.70 * dynamicConfidence, reasons)
        }

        if reasons.isEmpty {
            reasons.append("Recovery, sleep, and strain are within an actionable range.")
        }
        return (.keep, 0.76 * dynamicConfidence, reasons)
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

