import Foundation
import SwiftData

enum BodyReadiness: String, Codable, Hashable, Sendable {
    case ready
    case caution
    case recovering
    case unknown
}

/// A quick calibration of whether objective scored evidence matches the user's
/// felt experience. It is deliberately separate from the detailed check-in:
/// disagreement changes interpretation confidence, never the five scores.
enum LivedStateAlignment: String, Codable, Hashable, CaseIterable, Sendable {
    case aligned
    case worse
    case better
    case uncertain

    var journalTags: [String] {
        ["lived_state_alignment", "lived_state_alignment_\(rawValue)"]
    }

    var journalNote: String {
        switch self {
        case .aligned: return "身体感受与今日分数一致"
        case .worse: return "身体感受比今日分数更差"
        case .better: return "身体感受比今日分数更好"
        case .uncertain: return "暂时无法判断身体感受是否与今日分数一致"
        }
    }

    /// A mismatch is evidence of uncertainty, not proof that the objective
    /// evidence is wrong and not a diagnosis. Positive alignment never raises
    /// readiness or overwrites deterministic scores.
    var conservativeSeverity: Double {
        self == .worse ? 0.5 : 0
    }

    init?(tags: [String]) {
        let values = Set(tags.map { $0.lowercased() })
        guard values.contains("lived_state_alignment") else { return nil }
        guard let value = Self.allCases.first(where: {
            values.contains("lived_state_alignment_\($0.rawValue)")
        }) else { return nil }
        self = value
    }
}

/// A low-friction subjective snapshot stored through the existing journal Adapter.
/// Values use 0...2 so the model stays stable while the UI can localize labels.
struct LivedStateCheckIn: Codable, Hashable, Sendable {
    var stress: Int       // 0 low, 1 balanced, 2 high
    var energy: Int       // 0 low, 1 steady, 2 high
    var soreness: Int     // 0 none, 1 mild, 2 marked
    var motivation: Int   // 0 low, 1 steady, 2 high
    var note: String

    init(stress: Int, energy: Int, soreness: Int, motivation: Int, note: String = "") {
        self.stress = Self.clamp(stress)
        self.energy = Self.clamp(energy)
        self.soreness = Self.clamp(soreness)
        self.motivation = Self.clamp(motivation)
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var journalTags: [String] {
        [
            "lived_state",
            "stress_\(Self.stressTokens[stress])",
            "energy_\(Self.energyTokens[energy])",
            "soreness_\(Self.sorenessTokens[soreness])",
            "motivation_\(Self.motivationTokens[motivation])"
        ]
    }

    var journalNote: String {
        note.isEmpty ? generatedSummary : "\(generatedSummary)\n\(note)"
    }

    /// Only conservative signals lower readiness; positive self-report never
    /// silently overrides objective health evidence.
    var conservativeSeverity: Double {
        max(
            stress == 2 ? 0.65 : 0,
            energy == 0 ? 0.50 : 0,
            soreness == 2 ? 0.80 : (soreness == 1 ? 0.35 : 0),
            motivation == 0 ? 0.35 : 0
        )
    }

    init?(tags: [String], note: String) {
        let values = Set(tags.map { $0.lowercased() })
        guard values.contains("lived_state") else { return nil }
        let stress = Self.index(in: values, prefix: "stress_", tokens: ["low", "balanced", "high"], fallback: 1)
        let energy = Self.index(in: values, prefix: "energy_", tokens: ["low", "steady", "high"], fallback: 1)
        let soreness = Self.index(in: values, prefix: "soreness_", tokens: ["none", "mild", "marked"], fallback: 0)
        let motivation = Self.index(in: values, prefix: "motivation_", tokens: ["low", "steady", "high"], fallback: 1)
        let summary = Self.summary(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation
        )
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail: String
        if trimmed == summary {
            detail = ""
        } else if trimmed.hasPrefix("\(summary)\n") {
            detail = String(trimmed.dropFirst(summary.count + 1))
        } else {
            detail = trimmed
        }
        self.init(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation,
            note: detail
        )
    }

    private var generatedSummary: String {
        Self.summary(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation
        )
    }

    private static func summary(stress: Int, energy: Int, soreness: Int, motivation: Int) -> String {
        [
            "压力\(stressLabels[stress])",
            "精力\(energyLabels[energy])",
            "酸痛\(sorenessLabels[soreness])",
            "动力\(motivationLabels[motivation])"
        ].joined(separator: " · ")
    }

    private static func clamp(_ value: Int) -> Int { min(2, max(0, value)) }

    private static let stressTokens = ["low", "balanced", "high"]
    private static let energyTokens = ["low", "steady", "high"]
    private static let sorenessTokens = ["none", "mild", "marked"]
    private static let motivationTokens = ["low", "steady", "high"]
    private static let stressLabels = ["低", "适中", "高"]
    private static let energyLabels = ["低", "稳定", "充足"]
    private static let sorenessLabels = ["无", "轻微", "明显"]
    private static let motivationLabels = ["低", "稳定", "强"]

    private static func index(
        in values: Set<String>,
        prefix: String,
        tokens: [String],
        fallback: Int
    ) -> Int {
        tokens.enumerated().first(where: { values.contains(prefix + $0.element) })?.offset ?? fallback
    }
}

// MARK: - Daily Intelligence Assembly Module (shared Seam)

/// The shared Seam for daily cognitive assembly. Adapters own fetches,
/// persistence and side effects; this Module owns the deterministic ordering
/// Body State -> Personal Health Brief -> downstream Training Decision.
struct DailyIntelligenceAssemblyInput: Sendable {
    var dashboard: DashboardSummary
    var selectedDay: Date
    var calendar: Calendar
    var dailySummary: DailyHealthSummaryDTO?
    var bodyStateWorkoutEvents: [WorkoutEventDTO]
    var decisionWorkoutEvents: [WorkoutEventDTO]?
    var strengthWorkouts: [StrengthWorkoutDTO]
    var trainingResponses: [TrainingResponseDTO]
    var foodLogs: [FoodLogDTO]
    var journalEntries: [JournalEntryDTO]
    var activePlan: TrainingPlanDTO?
    var activeStatus: String
    var snapshots: [DailyHealthSnapshot]
    var feedbackCalibration: DecisionFeedbackCalibration?
    var trainingPreference: TrainingPreferenceProfile?
    var persistedDecision: DailyTrainingDecision?
    var persistedBodyStateHash: String?
    /// Adapter-provided persisted rotation title; the operating-plan payload is
    /// the authoritative title when it is available.
    var persistedTargetSessionTitle: String?

    init(
        dashboard: DashboardSummary,
        selectedDay: Date,
        calendar: Calendar,
        dailySummary: DailyHealthSummaryDTO? = nil,
        bodyStateWorkoutEvents: [WorkoutEventDTO] = [],
        decisionWorkoutEvents: [WorkoutEventDTO]? = nil,
        strengthWorkouts: [StrengthWorkoutDTO] = [],
        trainingResponses: [TrainingResponseDTO] = [],
        foodLogs: [FoodLogDTO] = [],
        journalEntries: [JournalEntryDTO] = [],
        activePlan: TrainingPlanDTO? = nil,
        activeStatus: String = "active",
        snapshots: [DailyHealthSnapshot] = [],
        feedbackCalibration: DecisionFeedbackCalibration? = nil,
        trainingPreference: TrainingPreferenceProfile? = nil,
        persistedDecision: DailyTrainingDecision? = nil,
        persistedBodyStateHash: String? = nil,
        persistedTargetSessionTitle: String? = nil
    ) {
        self.dashboard = dashboard
        self.selectedDay = selectedDay
        self.calendar = calendar
        self.dailySummary = dailySummary
        self.bodyStateWorkoutEvents = bodyStateWorkoutEvents
        self.decisionWorkoutEvents = decisionWorkoutEvents
        self.strengthWorkouts = strengthWorkouts
        self.trainingResponses = trainingResponses
        self.foodLogs = foodLogs
        self.journalEntries = journalEntries
        self.activePlan = activePlan
        self.activeStatus = activeStatus
        self.snapshots = snapshots
        self.feedbackCalibration = feedbackCalibration
        self.trainingPreference = trainingPreference
        self.persistedDecision = persistedDecision
        self.persistedBodyStateHash = persistedBodyStateHash
        self.persistedTargetSessionTitle = persistedTargetSessionTitle
    }
}

struct DailyIntelligenceAssembly: Sendable {
    var bodyState: BodyState
    var trainingDecision: DailyTrainingDecision
    var dashboard: DashboardSummary
    var usedPersistedDecision: Bool
}

enum DailyIntelligenceAssemblyModule {
    /// Deep Module implementation: all input is value typed and all three
    /// projections are computed through one deterministic Interface.
    static nonisolated func assemble(
        _ input: DailyIntelligenceAssemblyInput
    ) -> DailyIntelligenceAssembly {
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: input.dashboard,
            dailySummary: input.dailySummary,
            workoutEvents: input.bodyStateWorkoutEvents,
            strengthWorkouts: input.strengthWorkouts,
            trainingResponses: input.trainingResponses,
            foodLogs: input.foodLogs,
            journalEntries: input.journalEntries,
            activePlan: input.activePlan,
            activeStatus: input.activeStatus,
            generatedAt: input.selectedDay,
            calendar: input.calendar
        ))

        var dashboard = input.dashboard
        dashboard.bodyState = bodyState
        let trendAnalysis = HealthTrendEngine().analyze(
            dashboard: dashboard,
            snapshots: input.snapshots,
            longTermBaselines: dashboard.longTermBaselines,
            today: input.selectedDay,
            calendar: input.calendar
        )
        dashboard.personalHealthBrief = trendAnalysis.brief
        dashboard.healthTrends = trendAnalysis.findings

        let rotationFocus = input.activePlan == nil
            ? TrainingRotationResolver.nextFocus(
                profile: input.trainingPreference,
                recentResponses: input.trainingResponses
            )
            : nil
        let expectedRotationTitle = rotationFocus.map(TrainingRotationResolver.title)
        let canReusePersisted = input.persistedDecision != nil
            && input.persistedBodyStateHash == bodyState.hash
            && (expectedRotationTitle == nil || (input.persistedTargetSessionTitle ?? input.persistedDecision?.targetSessionTitle) == expectedRotationTitle)

        let trainingDecision: DailyTrainingDecision
        if canReusePersisted, let persistedDecision = input.persistedDecision {
            trainingDecision = persistedDecision
        } else {
            trainingDecision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
                bodyState: bodyState,
                activePlan: input.activePlan,
                trainingResponses: input.trainingResponses,
                workoutEvents: input.decisionWorkoutEvents ?? input.bodyStateWorkoutEvents,
                longTermTrainingVolume: dashboard.longTermBaselines?.trainingVolume,
                feedbackCalibration: input.feedbackCalibration,
                rotationFocus: rotationFocus,
                personalHealthBrief: trendAnalysis.brief,
                calendar: input.calendar
            ))
        }
        dashboard.trainingDecision = TrainingDecision.compatibilityView(
            of: trainingDecision,
            bodyState: bodyState
        )

        return DailyIntelligenceAssembly(
            bodyState: bodyState,
            trainingDecision: trainingDecision,
            dashboard: dashboard,
            usedPersistedDecision: canReusePersisted
        )
    }
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

struct BodyState: Codable, Hashable, Sendable {
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
    var dailySummary: DailyHealthSummaryDTO?
    var workoutEvents: [WorkoutEventDTO]
    var strengthWorkouts: [StrengthWorkoutDTO]
    var trainingResponses: [TrainingResponseDTO]
    var foodLogs: [FoodLogDTO]
    var journalEntries: [JournalEntryDTO]
    var activePlan: TrainingPlanDTO?
    var activeStatus: String
    var generatedAt: Date
    /// Calendar is part of the temporal contract for deterministic historical assembly.
    var calendar: Calendar

    init(
        dashboard: DashboardSummary,
        dailySummary: DailyHealthSummaryDTO? = nil,
        workoutEvents: [WorkoutEventDTO] = [],
        strengthWorkouts: [StrengthWorkoutDTO] = [],
        trainingResponses: [TrainingResponseDTO] = [],
        foodLogs: [FoodLogDTO] = [],
        journalEntries: [JournalEntryDTO] = [],
        activePlan: TrainingPlanDTO? = nil,
        activeStatus: String = "active",
        generatedAt: Date = Date(),
        calendar: Calendar = .current
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
        self.calendar = calendar
    }
}

struct BodyStateKernel: Sendable {
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

        let dayStart = input.calendar.startOfDay(for: input.generatedAt)
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
        // 算法打通（批次 C）：Lived State（当日自评）接线——此前手记对今日决策
        // 只有 impact 0 的中性展示。现在：负面自评保守方向参与判定，与 Body State
        // 相悖时降低确定性；绝不静默覆盖客观评分（产品方向「主观与客观并立」）。
        let lived = Self.livedStateSignal(
            entries: input.journalEntries.filter {
                $0.createdAt >= input.generatedAt.addingTimeInterval(-36 * 3_600)
            },
            calendar: input.calendar
        )
        if lived.hasEntry {
            drivers.append(BodyStateDriver(
                id: "lived-state",
                kind: .journal,
                title: lived.severity > 0 ? "今日自评" : "近期主观记录",
                detail: lived.evidence,
                impact: lived.severity > 0 ? -lived.severity : 0,
                source: "JournalEntryRecord (Lived State)"
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
            hasData: dashboard.source != .empty,
            calendar: input.calendar
        )
        // Lived State 与 Body State 相悖（自评负面但客观信号良好）→ 确定性降级。
        let livedConflict = lived.severity >= 0.5
            && dashboard.recovery.hasData && dashboard.recovery.score >= 70
            && dashboard.sleepScore.hasData && dashboard.sleepScore.score >= 70
        let confidence = Self.confidence(for: dashboard, freshness: freshness, livedConflict: livedConflict)
        let thresholds = PersonalBaselineEngine.resolveThresholds()
        var readiness: BodyReadiness
        if dashboard.source == .empty {
            readiness = .unknown
            drivers.append(BodyStateDriver(
                id: "data-coverage",
                kind: .dataCoverage,
                title: "数据覆盖不足",
                detail: "健康数据或本地记录不足，Vela 会先使用保守训练窗口（\(thresholds.source)）。",
                impact: -0.6,
                source: "BodyStateKernel"
            ))
        } else if ["sick", "injured", "resting"].contains(input.activeStatus)
                    || (dashboard.recovery.hasData && dashboard.recovery.score < thresholds.recoveryRest) {
            readiness = .recovering
        } else if fatigue.values.contains(where: { $0.fatigueLevel == "high" })
                    || drivers.contains(where: { $0.kind == .trainingResponse })
                    || (dashboard.recovery.hasData && dashboard.recovery.score < thresholds.recoveryCaution)
                    || (dashboard.sleepScore.hasData && dashboard.sleepScore.score < thresholds.sleepCaution) {
            readiness = .caution
        } else {
            readiness = .ready
        }
        // 自评严重负面（疼痛/生病/很累）时，即使客观信号良好也至少进入 caution。
        if readiness == .ready, lived.severity >= 0.8 {
            readiness = .caution
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
        // 计划完成事件可能来自历史导入（startedAt 不在 48h 内），
        // 但它会改变 TrainingScheduleResolver 的解析结果，因此也必须进 hash。
        let scheduleEventHash = input.workoutEvents
            .compactMap { event -> String? in
                guard let dayID = event.linkedTrainingPlanDayId else { return nil }
                return "\(dayID.uuidString):\(event.id.uuidString)"
            }
            .sorted()
            .joined(separator: "|")
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
            DailyHealthSummaryRecord.dayIdentifier(for: dashboard.date, calendar: input.calendar),
            readiness.rawValue,
            "\(dashboard.recovery.score)",
            "\(dashboard.sleepScore.score)",
            "\(dashboard.strain.score)",
            // TrainingDecisionKernel 还会读取压力/能量/TSB/阈值；这些值变化时
            // bodyStateHash 必须变化，否则已持久化计划会错误复用旧决策。
            "\(dashboard.stress.score)",
            "\(dashboard.energy.score)",
            dashboard.energy.metrics["tsb"].map { String(format: "%.1f", $0) } ?? "no-tsb",
            "\(thresholds.recoveryRest)",
            "\(thresholds.recoveryCaution)",
            "\(thresholds.sleepRest)",
            "\(thresholds.sleepCaution)",
            input.activeStatus,
            input.activePlan?.id.uuidString ?? "no-plan",
            eventHash,
            scheduleEventHash,
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
        if dashboard.stress.hasData, dashboard.stress.score > 75 {
            drivers.append(.init(
                id: "stress",
                kind: .stress,
                title: "压力",
                detail: dashboard.stress.reasons.first ?? "生理压力偏高。",
                impact: -0.6,
                source: "StressIndexEngine \(dashboard.stress.algorithmVersion)"
            ))
        }
        // 负荷是训练决策的正式输入之一；超过个人目标上限时，Body State
        // 证据层也必须出现，避免「决策已减量、证据只字不提」。
        if dashboard.strain.hasData,
           dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            let range = dashboard.strain.recommendedRange
            drivers.append(.init(
                id: "strain",
                kind: .strain,
                title: "今日负荷",
                detail: "负荷 \(Int(dashboard.strain.score.rounded())) 已高于个人目标上限 \(range.upperBound)。",
                impact: -0.5,
                source: "StrainScoreEngine \(dashboard.strain.algorithmVersion)"
            ))
        }
        return drivers
    }

    private static func confidence(
        for dashboard: DashboardSummary,
        freshness: DataFreshness,
        livedConflict: Bool = false
    ) -> DataConfidence {
        guard dashboard.source != .empty, freshness != .missing else { return .low }
        if livedConflict { return .low }
        var values = [
            dashboard.recovery.confidence,
            dashboard.sleepScore.confidence,
            dashboard.strain.confidence
        ]
        // 压力与能量也是 TrainingDecisionKernel 的正式输入；任一低置信度时，
        // 整体 Body State 置信度不能继续显示「高」。
        if dashboard.stress.hasData { values.append(dashboard.stress.confidence) }
        if dashboard.energy.hasData { values.append(dashboard.energy.confidence) }
        if freshness == .stale || values.contains(.low) { return .low }
        if values.allSatisfy({ $0 == .high }) { return .high }
        return .medium
    }

    /// 当日自评（Lived State）信号：note + 标签的中英关键词 → 保守严重度 0...1。
    /// 不区分真伪，只按「负面自评」的保守方向使用；中性/积极自评不改判定。
    private static func livedStateSignal(
        entries: [JournalEntryDTO],
        calendar: Calendar
    ) -> (hasEntry: Bool, severity: Double, evidence: String) {
        // Alignment and the detailed check-in are separate facets. Consider the
        // latest of each so a later quick tap cannot erase a structured report
        // (or vice versa), then take the conservative maximum.
        let explicitEntries = entries.filter {
            LivedStateAlignment(tags: $0.tags) != nil
                || LivedStateCheckIn(tags: $0.tags, note: $0.note) != nil
        }
        let latestExplicitDay = explicitEntries
            .max(by: { $0.createdAt < $1.createdAt })
            .map { calendar.startOfDay(for: $0.createdAt) }
        let dailyExplicitEntries = latestExplicitDay.map { dayStart in
            explicitEntries.filter { calendar.isDate($0.createdAt, inSameDayAs: dayStart) }
        } ?? []
        var explicitSignals: [(date: Date, severity: Double, evidence: String)] = []
        if let latestAlignment = dailyExplicitEntries
            .filter({ LivedStateAlignment(tags: $0.tags) != nil })
            .max(by: { $0.createdAt < $1.createdAt }),
           let alignment = LivedStateAlignment(tags: latestAlignment.tags) {
            explicitSignals.append((
                latestAlignment.createdAt,
                alignment.conservativeSeverity,
                latestAlignment.note.isEmpty ? alignment.journalNote : latestAlignment.note
            ))
        }
        if let latestCheckIn = dailyExplicitEntries
            .filter({ LivedStateCheckIn(tags: $0.tags, note: $0.note) != nil })
            .max(by: { $0.createdAt < $1.createdAt }),
           let checkIn = LivedStateCheckIn(tags: latestCheckIn.tags, note: latestCheckIn.note) {
            explicitSignals.append((
                latestCheckIn.createdAt,
                checkIn.conservativeSeverity,
                latestCheckIn.note.isEmpty ? checkIn.journalNote : latestCheckIn.note
            ))
        }
        if !explicitSignals.isEmpty {
            let ordered = explicitSignals.sorted {
                $0.severity == $1.severity ? $0.date > $1.date : $0.severity > $1.severity
            }
            let evidence = ordered.map(\.evidence).reduce(into: [String]()) { result, item in
                if !item.isEmpty && !result.contains(item) { result.append(item) }
            }.joined(separator: "；")
            return (
                true,
                explicitSignals.map(\.severity).max() ?? 0,
                evidence.isEmpty ? "已记录主观状态" : evidence
            )
        }

        guard let latest = entries.max(by: { $0.createdAt < $1.createdAt }) else {
            return (false, 0, "")
        }
        let text = (latest.note + " " + latest.tags.joined(separator: " ")).lowercased()
        let strong = ["疼痛", "剧痛", "受伤", "生病", "pain", "injur", "sick"]
        let medium = ["很累", "非常累", "疲劳", "酸痛", "睡不好", "失眠", "熬夜", "压力大",
                      "stressed", "sore", "exhaust", "poor sleep"]
        let weak = ["睡眠差", "压力", "tired", "fatigue"]
        var severity: Double = 0
        if strong.contains(where: { text.contains($0) }) {
            severity = 1.0
        } else if medium.contains(where: { text.contains($0) }) {
            severity = 0.8
        } else if weak.contains(where: { text.contains($0) }), !text.contains("不累") {
            severity = 0.5
        }
        let evidence = latest.note.isEmpty ? latest.tags.joined(separator: "、") : latest.note
        return (true, severity, evidence.isEmpty ? "已记录主观状态" : evidence)
    }

    private static func freshness(referenceDate: Date, generatedAt: Date, hasData: Bool, calendar: Calendar) -> DataFreshness {
        guard hasData else { return .missing }
        let age = generatedAt.timeIntervalSince(referenceDate)
        if age <= 2 * 3_600 { return .live }
        if calendar.isDate(referenceDate, inSameDayAs: generatedAt) { return .today }
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
