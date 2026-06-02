import Foundation
import SwiftData

final class TrainingPlanLinkingService: Sendable {
    init() {}

    func calculateMatchScore(
        event: WorkoutEventRecord,
        planDay: TrainingDay,
        strengthWorkout: StrengthWorkoutRecord?,
        expectedDate: Date,
        calendar: Calendar = .current
    ) -> Double {
        var score = 0.0

        // 1. Date Match (up to 40 points)
        if calendar.isDate(event.startedAt, inSameDayAs: expectedDate) {
            score += 40.0
        } else {
            let diffDays = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: expectedDate), to: calendar.startOfDay(for: event.startedAt)).day ?? 0)
            if diffDays == 1 {
                score += 15.0
            } else if diffDays == 2 {
                score += 5.0
            }
        }

        // 2. Focus & Activity Match (up to 30 points)
        if planDay.focus == "rest" {
            return 0.0
        }

        let focus = planDay.focus.lowercased()
        let eventActivity = event.activityType.lowercased()

        if focus == "strength" && (eventActivity.contains("strength") || eventActivity.contains("weight") || eventActivity.contains("健身") || eventActivity.contains("力量") || event.linkedStrengthWorkoutId != nil) {
            score += 25.0
        } else if focus == "cardio" && (eventActivity.contains("run") || eventActivity.contains("cycle") || eventActivity.contains("swim") || eventActivity.contains("cardio") || eventActivity.contains("跑步") || eventActivity.contains("有氧") || eventActivity.contains("骑行")) {
            score += 25.0
        } else if focus == "flexibility" && (eventActivity.contains("yoga") || eventActivity.contains("stretch") || eventActivity.contains("瑜伽") || eventActivity.contains("拉伸")) {
            score += 25.0
        }

        // 3. Muscle Group Match (up to 15 points)
        if focus == "strength", let strengthWorkout {
            let workoutMuscles = Set(strengthWorkout.exercises.compactMap { $0.primaryMuscleGroup?.lowercased() })
            let planDayTitle = planDay.title.lowercased()
            let planDayDesc = planDay.description.lowercased()

            var muscleMatched = false
            for muscle in workoutMuscles {
                if planDayTitle.contains(muscle) || planDayDesc.contains(muscle) {
                    muscleMatched = true
                    break
                }
            }
            if muscleMatched {
                score += 15.0
            }
        }

        // 4. Title Text Match (up to 15 points)
        let planTitle = planDay.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let eventTitleClean = event.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if planTitle == eventTitleClean {
            score += 15.0
        } else if eventTitleClean.contains(planTitle) || planTitle.contains(eventTitleClean) {
            score += 8.0
        }

        return score
    }

    func isHighConfidenceMatch(score: Double) -> Bool {
        return score >= 65.0
    }
}
