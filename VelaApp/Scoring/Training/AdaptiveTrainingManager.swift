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

    /// Generates adjustments for all upcoming training days in the active plan.
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
                focus: "rest",
                durationMinutes: 0,
                intensity: "low",
                isCompleted: false
            )
        case "reduce":
            let halfDuration = max(15, plan.days[dayIndex].durationMinutes / 2)
            var modified = plan.days[dayIndex]
            modified = TrainingDay(
                id: modified.id,
                weekNumber: modified.weekNumber,
                dayNumber: modified.dayNumber,
                title: modified.title + (AppLanguage.stored.isChinese ? "（减量）" : " (Reduced)"),
                description: record.suggestedAlternative ?? modified.description,
                focus: modified.focus,
                durationMinutes: halfDuration,
                intensity: "moderate",
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
                focus: "flexibility",
                durationMinutes: 30,
                intensity: "low",
                isCompleted: false
            )
        default:
            break
        }

        try modelContext.save()
    }
}
