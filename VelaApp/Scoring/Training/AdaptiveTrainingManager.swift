import Foundation
import SwiftData

// MARK: - Training Plan Adaptation Record

@Model
final class TrainingPlanAdaptationRecord {
    @Attribute(.unique) var id: UUID
    var planId: UUID
    var dayId: UUID
    var createdAt: Date
    var adjustment: String  // keep, reduce, swap, rest, reschedule, deloadWeek
    var reason: String
    var suggestedAlternative: String?
    var status: String  // proposed, accepted, rejected
    var acceptedAt: Date?
    var rejectedAt: Date?
    var originalDayTitle: String
    var agentRunId: String?

    init(
        id: UUID = UUID(),
        planId: UUID,
        dayId: UUID,
        createdAt: Date = Date(),
        adjustment: AdaptiveTrainingEngine.Adjustment,
        reason: String,
        suggestedAlternative: String? = nil,
        status: AdaptationStatus = .proposed,
        acceptedAt: Date? = nil,
        rejectedAt: Date? = nil,
        originalDayTitle: String = "",
        agentRunId: String? = nil
    ) {
        self.id = id
        self.planId = planId
        self.dayId = dayId
        self.createdAt = createdAt
        self.adjustment = adjustment.rawValue
        self.reason = reason
        self.suggestedAlternative = suggestedAlternative
        self.status = status.rawValue
        self.acceptedAt = acceptedAt
        self.rejectedAt = rejectedAt
        self.originalDayTitle = originalDayTitle
        self.agentRunId = agentRunId
    }
}

enum AdaptationStatus: String, Codable, Hashable, CaseIterable {
    case proposed
    case accepted
    case rejected
}

// MARK: - Adaptive Training Manager 2.0

struct AdaptiveTrainingManager {

    /// Creates at most one state-driven proposal for the executable plan day each calendar day.
    /// The user remains the decision maker: this method never mutates the plan itself.
    @MainActor
    func refreshDailyProposal(
        plan: TrainingPlanRecord,
        dashboard: DashboardSummary,
        events: [WorkoutEventRecord],
        foodLogs: [FoodLogRecord],
        journalEntries: [JournalEntryRecord],
        modelContext: ModelContext,
        date: Date = Date(),
        calendar: Calendar = .current
    ) throws -> TrainingPlanAdaptationRecord? {
        guard dashboard.source != .empty,
              dashboard.recovery.hasData,
              let day = TrainingScheduleResolver.resolve(
                plan: plan.dto,
                on: date,
                events: events.map { $0.dto },
                calendar: calendar
              ),
              day.focus != "rest" else {
            return nil
        }

        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar)
        let runID = "daily-plan-review:\(plan.id.uuidString):\(day.id.uuidString):\(dayIdentifier)"
        var descriptor = FetchDescriptor<TrainingPlanAdaptationRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 100
        if let existing = try modelContext.fetch(descriptor).first(where: { $0.agentRunId == runID }) {
            return existing.status == AdaptationStatus.proposed.rawValue ? existing : nil
        }

        let interpretation = BodyInterpreterEngine().interpret(
            dashboard: dashboard,
            wiki: [:],
            activePlan: plan,
            foodLogs: foodLogs,
            journalEntries: journalEntries
        )
        guard interpretation.overallConfidence != .unavailable,
              let adjusted = AdaptiveTrainingEngine.adjust(day: day, interpretation: interpretation),
              adjusted.adjustment != .keep else {
            return nil
        }

        let proposal = TrainingPlanAdaptationRecord(
            planId: plan.id,
            dayId: day.id,
            adjustment: adjusted.adjustment,
            reason: adjusted.reason,
            suggestedAlternative: adjusted.suggestedAlternative,
            status: .proposed,
            originalDayTitle: day.title,
            agentRunId: runID
        )
        modelContext.insert(proposal)
        try modelContext.save()
        return proposal
    }

    /// Applies an accepted adaptation to the training plan.
    func applyAdaptation(
        _ record: TrainingPlanAdaptationRecord,
        to plan: TrainingPlanRecord
    ) -> Bool {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == record.dayId }) else { return false }

        switch record.adjustment {
        case "rest":
            plan.days[dayIndex] = TrainingDay(
                id: plan.days[dayIndex].id,
                weekNumber: plan.days[dayIndex].weekNumber,
                dayNumber: plan.days[dayIndex].dayNumber,
                title: AppLanguage.stored.isChinese ? "休息日（调整后）" : "Rest Day (Adjusted)",
                description: record.reason,
                focus: "rest", durationMinutes: 0, intensity: "low",
                isCompleted: false
            )
        case "reduce":
            let halfDuration = max(15, plan.days[dayIndex].durationMinutes / 2)
            var modified = plan.days[dayIndex]
            modified = TrainingDay(
                id: modified.id, weekNumber: modified.weekNumber, dayNumber: modified.dayNumber,
                title: modified.title + (AppLanguage.stored.isChinese ? "（减量）" : " (Reduced)"),
                description: record.suggestedAlternative ?? modified.description,
                focus: modified.focus, durationMinutes: halfDuration, intensity: "moderate",
                isCompleted: false
            )
            plan.days[dayIndex] = modified
        case "swap":
            plan.days[dayIndex] = TrainingDay(
                id: plan.days[dayIndex].id,
                weekNumber: plan.days[dayIndex].weekNumber,
                dayNumber: plan.days[dayIndex].dayNumber,
                title: AppLanguage.stored.isChinese ? "主动恢复（调整后）" : "Active Recovery (Adjusted)",
                description: record.suggestedAlternative ?? plan.days[dayIndex].description,
                focus: "flexibility", durationMinutes: 30, intensity: "low",
                isCompleted: false
            )
        case "reschedule":
            // Move the training day to the next available rest day
            var moved = plan.days[dayIndex]
            guard let nextRestIndex = plan.days.indices
                .first(where: { $0 > dayIndex && (plan.days[$0].focus == "rest" || plan.days[$0].focus == "flexibility") }) else {
                return false
            }
            moved = TrainingDay(
                id: moved.id, weekNumber: plan.days[nextRestIndex].weekNumber,
                dayNumber: plan.days[nextRestIndex].dayNumber,
                title: moved.title + (AppLanguage.stored.isChinese ? "（改期）" : " (Rescheduled)"),
                description: moved.description, focus: moved.focus,
                durationMinutes: moved.durationMinutes, intensity: moved.intensity,
                isCompleted: false
            )
            // Mark original day as rest
            plan.days[dayIndex] = TrainingDay(
                id: plan.days[dayIndex].id,
                weekNumber: plan.days[dayIndex].weekNumber,
                dayNumber: plan.days[dayIndex].dayNumber,
                title: AppLanguage.stored.isChinese ? "休息日" : "Rest Day",
                description: AppLanguage.stored.isChinese ? "训练已改期" : "Training rescheduled",
                focus: "rest", durationMinutes: 0, intensity: "low",
                isCompleted: false
            )
            plan.days[nextRestIndex] = moved
        case "deloadWeek":
            // Convert all remaining days this week to light recovery
            let currentWeek = plan.days[dayIndex].weekNumber
            for i in plan.days.indices where plan.days[i].weekNumber == currentWeek && plan.days[i].focus != "rest" {
                plan.days[i] = TrainingDay(
                    id: plan.days[i].id,
                    weekNumber: plan.days[i].weekNumber,
                    dayNumber: plan.days[i].dayNumber,
                    title: AppLanguage.stored.isChinese ? "减载周（调整后）" : "Deload Week (Adjusted)",
                    description: record.reason,
                    focus: "flexibility", durationMinutes: 20, intensity: "low",
                    isCompleted: false
                )
            }
        default:
            return false
        }

        return true
    }
}

// MARK: - Workout Adaptation Service

@MainActor
struct WorkoutAdaptationService: Sendable {
    init() {}

    /// Main entry point for closed-loop post-workout training adaptation.
    /// Called when a workout is completed or post-workout check-in sheet is submitted.
    @discardableResult
    func processWorkoutCompletion(
        workoutID: UUID?,
        modelContext: ModelContext,
        now: Date = Date()
    ) async throws -> TrainingPlanAdaptationRecord? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        // 1. Fetch active plan
        let activePlans = (try? modelContext.fetch(FetchDescriptor<TrainingPlanRecord>(
            predicate: #Predicate { $0.isActive }
        ))) ?? []
        guard let activePlan = activePlans.first else {
            return nil
        }

        // Completion is a canonical product fact even when the current body
        // snapshot cannot produce a new plan proposal. Persist it before the
        // optional adaptation pass so a transient HealthKit failure never
        // erases the completed-workout event.
        VelaEventService.shared.log(
            modelContext: modelContext,
            type: VelaProductEventType.workoutCompleted,
            title: "完成训练记录打卡",
            detail: "训练事实已保存；Vela 会在可用信号足够时更新下一次训练边界。",
            metadata: ["workout_id": workoutID?.uuidString ?? ""]
        )
        try modelContext.save()

        // 2. Re-evaluate from the latest local evidence. Completing a workout
        // must stay fast and deterministic; the normal dashboard refresh owns
        // HealthKit synchronization and can retry independently.
        let dashboard = (try? DailySummaryUseCase().loadCachedDashboard(
            for: now,
            modelContext: modelContext
        )) ?? DashboardSummary.empty(date: today)

        let events = (try? modelContext.fetch(FetchDescriptor<WorkoutEventRecord>())) ?? []
        let foods = (try? modelContext.fetch(FetchDescriptor<FoodLogRecord>())) ?? []
        let journals = (try? modelContext.fetch(FetchDescriptor<JournalEntryRecord>())) ?? []

        // 3. Trigger AdaptiveTrainingManager refreshDailyProposal
        let manager = AdaptiveTrainingManager()
        let proposal: TrainingPlanAdaptationRecord?
        do {
            proposal = try manager.refreshDailyProposal(
                plan: activePlan,
                dashboard: dashboard,
                events: events,
                foodLogs: foods,
                journalEntries: journals,
                modelContext: modelContext,
                date: now,
                calendar: calendar
            )
        } catch {
            // A training fact is more durable than an optional proposal. Keep
            // the saved completion and let a later refresh retry adaptation.
            VelaAppState.shared.markLocalDataChanged()
            return nil
        }

        if let proposal {
            VelaEventService.shared.log(
                modelContext: modelContext,
                type: VelaProductEventType.trainingPlanAdapted,
                title: "智能训练处方微调",
                detail: proposal.reason,
                metadata: [
                    "adjustment": proposal.adjustment,
                    "plan_id": activePlan.id.uuidString
                ]
            )
        }

        try modelContext.save()
        VelaAppState.shared.markLocalDataChanged()

        return proposal
    }
}
