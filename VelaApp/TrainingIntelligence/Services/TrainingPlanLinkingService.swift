import Foundation
import SwiftData

final class TrainingPlanLinkingService: Sendable {
    init() {}

    /// P2-5：肌群键 → 中文别名映射。计划标题是中文（如「胸 + 三头」「推日」）时，
    /// 纯英文键匹配永远失败、自动打卡几乎不触发。
    private static let muscleAliases: [String: [String]] = [
        "chest": ["胸"],
        "back": ["背"],
        "shoulders": ["肩", "三角"],
        "quads": ["腿", "股四头", "深蹲"],
        "hamstrings": ["腿", "腘绳", "腿后"],
        "glutes": ["臀", "腿"],
        "biceps": ["二头", "臂", "弯举"],
        "triceps": ["三头", "臂"],
        "core": ["核心", "腹"],
    ]

    private func muscleMatches(_ muscle: String, title: String, description: String) -> Bool {
        let key = muscle.lowercased()
        if title.contains(key) || description.contains(key) { return true }
        for alias in Self.muscleAliases[key] ?? [] {
            if title.contains(alias) || description.contains(alias) { return true }
        }
        return false
    }

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
        let isStrengthEvent = event.linkedStrengthWorkoutId != nil
            || eventActivity.contains("strength") || eventActivity.contains("weight")
            || eventActivity.contains("健身") || eventActivity.contains("力量")

        // Strength focus match: base 15 pts, full 25 pts only when verified via strength workout
        if focus == "strength" {
            if isStrengthEvent {
                score += 15.0
                // Additional +10 if we have a linked strength workout (verified via muscle/context)
                if let sw = strengthWorkout, !sw.exercises.isEmpty {
                    let library = ExerciseLibraryService.defaultDefinitionsDTO()
                    let workoutMuscles = Set(sw.exercises.map { TrainingAnalyticsService().resolvedMuscleGroup(for: $0, library: library).lowercased() })
                    let planDayTitle = planDay.title.lowercased()
                    let planDayDesc = planDay.description.lowercased()
                    let musclesMatchPlan = workoutMuscles.contains { muscle in
                        muscleMatches(muscle, title: planDayTitle, description: planDayDesc)
                    }
                    // Full strength match bonus: needs both a linked workout AND muscle/title alignment
                    if musclesMatchPlan {
                        score += 10.0 // 15 + 10 = 25 total
                    } else {
                        // linked strength workout exists but targets wrong muscles: no bonus
                        score -= 5.0 // penalty for wrong muscle group
                    }
                }
            }
        } else if focus == "cardio" && (eventActivity.contains("run") || eventActivity.contains("cycle") || eventActivity.contains("swim") || eventActivity.contains("cardio") || eventActivity.contains("跑步") || eventActivity.contains("有氧") || eventActivity.contains("骑行")) {
            score += 25.0
        } else if focus == "flexibility" && (eventActivity.contains("yoga") || eventActivity.contains("stretch") || eventActivity.contains("瑜伽") || eventActivity.contains("拉伸")) {
            score += 25.0
        }

        // 3. Muscle Group Match (up to 15 points)
        if focus == "strength", let strengthWorkout {
            let library = ExerciseLibraryService.defaultDefinitionsDTO()
            let workoutMuscles = Set(strengthWorkout.exercises.map { TrainingAnalyticsService().resolvedMuscleGroup(for: $0, library: library).lowercased() })
            let planDayTitle = planDay.title.lowercased()
            let planDayDesc = planDay.description.lowercased()

            var muscleMatched = false
            for muscle in workoutMuscles {
                if muscleMatches(muscle, title: planDayTitle, description: planDayDesc) {
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

    /// Threshold for high-confidence plan-to-workout matching.
    /// Same-day alone (40) + generic strength match (15) = 55 → below threshold.
    /// Same-day + strength with muscle/title alignment (65+) → high confidence.
    /// Same-day + exact title match (55) → high confidence only with additional match.
    func isHighConfidenceMatch(score: Double) -> Bool {
        return score >= 65.0
    }
}
