import Foundation
import SwiftData

/// Manages adaptive adjustments to training plans based on daily readiness.
enum AdaptiveTrainingEngine {

    enum Adjustment: String, Codable, Hashable {
        case keep
        case reduce
        case swap
        case rest
    }

    struct AdjustedDay: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var originalDay: TrainingDay
        var adjustment: Adjustment
        var reason: String
        var suggestedAlternative: String?
    }

    /// Computes the appropriate adjustment for today's training step
    /// based on the user's physiological readiness.
    static func adjustToday(
        plan: TrainingPlanRecord,
        recoveryScore: Double,
        energyScore: Double,
        tsb: Double,
        sleepScore: Double,
        stressIndex: Double
    ) -> AdjustedDay? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let dayNumber = weekday == 1 ? 7 : weekday - 1

        guard let todayStep = plan.days.first(where: {
            !$0.isCompleted && $0.dayNumber == dayNumber
        }) else {
            return nil
        }

        let adjustment: Adjustment
        let reason: String
        let alternative: String?

        // Recovery-gated decision tree
        if recoveryScore > 75 && energyScore > 60 && tsb > 5 && sleepScore > 80 {
            adjustment = .keep
            reason = "All readiness indicators are optimal. Stick to the plan."
            alternative = nil
        } else if recoveryScore > 50 && energyScore > 40 && tsb > -5 {
            adjustment = .reduce
            reason = "Recovery is moderate. Reduce intensity by 30-40%."
            alternative = buildReducedVersion(of: todayStep)
        } else if recoveryScore > 30 {
            adjustment = .swap
            reason = "Recovery is low. Swap to active recovery today."
            alternative = buildRecoveryAlternative(for: todayStep)
        } else {
            adjustment = .rest
            reason = "Recovery is critically low. Full rest day recommended."
            alternative = nil
        }

        // TSB override: if TSB < -15, always reduce regardless of recovery
        let finalAdjustment: Adjustment
        let finalReason: String
        if tsb < -15 && adjustment == .keep {
            finalAdjustment = .reduce
            finalReason = "TSB is deeply negative (-\(Int(abs(tsb)))). High accumulated fatigue requires reduced load."
        } else if tsb > 10 && adjustment == .reduce {
            finalAdjustment = .keep
            finalReason = "TSB is positive (+\(Int(tsb))). Despite moderate recovery, your chronic fitness allows normal training."
        } else {
            finalAdjustment = adjustment
            finalReason = reason
        }

        return AdjustedDay(
            originalDay: todayStep,
            adjustment: finalAdjustment,
            reason: finalReason,
            suggestedAlternative: finalAdjustment == .keep ? nil : alternative
        )
    }

    // MARK: - Helpers

    private static func buildReducedVersion(of day: TrainingDay) -> String? {
        let reducedDuration = max(15, day.durationMinutes * 60 / 100) // 60% of original
        let reducedIntensity = day.intensity == "high" ? "moderate" : "low"
        return "\(day.title) (reduced): \(reducedDuration) min at \(reducedIntensity) intensity"
    }

    private static func buildRecoveryAlternative(for day: TrainingDay) -> String? {
        switch day.focus {
        case "strength":
            return "Bodyweight mobility routine: 20 min foam rolling + dynamic stretching"
        case "cardio":
            return "Light walk: 20-30 min at Zone 1, focusing on nasal breathing"
        case "flexibility":
            return "Keep flexibility session but reduce hold times to 30s"
        default:
            return "Yoga or stretching: 20 min gentle flow"
        }
    }
}
