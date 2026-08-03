import Foundation
import SwiftData

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
        let thresholds = PersonalBaselineEngine.resolveThresholds()
        let readiness: BodyReadiness
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
                    || dashboard.recovery.score < thresholds.recoveryRest {
            readiness = .recovering
        } else if fatigue.values.contains(where: { $0.fatigueLevel == "high" })
                    || drivers.contains(where: { $0.kind == .trainingResponse })
                    || dashboard.recovery.score < thresholds.recoveryCaution
                    || dashboard.sleepScore.score < thresholds.sleepCaution {
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
