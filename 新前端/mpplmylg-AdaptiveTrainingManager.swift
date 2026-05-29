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

    /// Vela 2.0 Beta: Per-day adjustments using BodyInterpretation.
    /// Each future day is evaluated against the body's current state.
    func generateWeekAdjustments(
        plan: TrainingPlanRecord,
        interpretation: BodyInterpretation
    ) -> [TrainingPlanAdaptationRecord] {
        var records: [TrainingPlanAdaptationRecord] = []

        let upcomingDays = plan.days.filter { !$0.isCompleted }
        for day in upcomingDays.prefix(7) {
            guard let adjusted = AdaptiveTrainingEngine.adjust(
                day: day, interpretation: interpretation
            ), adjusted.adjustment != .keep else { continue }

            records.append(TrainingPlanAdaptationRecord(
                planId: plan.id, dayId: adjusted.originalDay.id,
                adjustment: adjusted.adjustment, reason: adjusted.reason,
                suggestedAlternative: adjusted.suggestedAlternative,
                status: .proposed, originalDayTitle: adjusted.originalDay.title
            ))
        }
        return records
    }

    /// Legacy overload for backward compat — wraps adjustToday.
    func generateWeekAdjustments(
        plan: TrainingPlanRecord,
        recoveryScore: Double,
        energyScore: Double,
        tsb: Double,
        sleepScore: Double,
        stressIndex: Double
    ) -> [TrainingPlanAdaptationRecord] {
        var records: [TrainingPlanAdaptationRecord] = []

        let upcomingDays = plan.days.filter { !$0.isCompleted }
        for day in upcomingDays.prefix(7) {
            let adjusted = AdaptiveTrainingEngine.adjustToday(
                plan: plan,
                recoveryScore: recoveryScore,
                energyScore: energyScore,
                tsb: tsb,
                sleepScore: sleepScore,
                stressIndex: stressIndex
            )

            if let adj = adjusted, adj.adjustment != .keep {
                records.append(TrainingPlanAdaptationRecord(
                    planId: plan.id,
                    dayId: adj.originalDay.id,
                    adjustment: adj.adjustment,
                    reason: adj.reason,
                    suggestedAlternative: adj.suggestedAlternative,
                    status: .proposed,
                    originalDayTitle: adj.originalDay.title
                ))
            }
        }

        // Check if a deload week is needed
        if tsb < -20 && recoveryScore < 40 {
            for day in upcomingDays.prefix(7) {
                if day.focus != "rest" {
                    records.append(TrainingPlanAdaptationRecord(
                        planId: plan.id,
                        dayId: day.id,
                        adjustment: .rest,
                        reason: AppLanguage.stored.isChinese
                            ? "TSB 深度为负且恢复不足，建议减载周"
                            : "TSB deeply negative and recovery low. Deload week recommended.",
                        suggestedAlternative: AppLanguage.stored.isChinese
                            ? "轻量拉伸或散步 20 分钟"
                            : "Light stretching or 20 min walk",
                        status: .proposed,
                        originalDayTitle: day.title
                    ))
                }
            }
        }

        return records
    }

    /// Applies an accepted adaptation to the training plan.
    func applyAdaptation(
        _ record: TrainingPlanAdaptationRecord,
        to plan: TrainingPlanRecord,
        modelContext: ModelContext
    ) throws {
        guard let dayIndex = plan.days.firstIndex(where: { $0.id == record.dayId }) else { return }

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
            if let nextRestIndex = plan.days[moved.weekNumber..<plan.days.count]
                .firstIndex(where: { $0.focus == "rest" || $0.focus == "flexibility" }) {
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
            }
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
            break
        }

        try modelContext.save()
    }
}
