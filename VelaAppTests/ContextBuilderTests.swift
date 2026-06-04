import XCTest
@testable import Vela

final class ContextBuilderTests: XCTestCase {
    private func makeDate(
        year: Int = 2026,
        month: Int = 4,
        day: Int = 2,
        hour: Int = 12
    ) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func makeWorkout(start: Date) -> StrengthWorkoutRecord {
        StrengthWorkoutRecord(
            title: "Chest Strength",
            startedAt: start,
            durationMinutes: 55,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: nil,
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start),
                        StrengthSetLog(repetitions: 8, weightKilograms: 82.5, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start)
                    ]
                )
            ]
        )
    }

    func testAIContextIncludesRecentStrengthSummary() {
        let generatedAt = makeDate()
        let workout = makeWorkout(start: generatedAt.addingTimeInterval(-24 * 3600))
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = result.envelope.strengthTraining ?? [:]
        XCTAssertEqual(strength["algorithm_version"], "trainingAnalytics.v1")
        XCTAssertEqual(strength["sessions_7d"], "1")
        XCTAssertEqual(strength["hard_sets_7d"], "2")
        XCTAssertTrue((strength["muscle_groups_7d"] ?? "").contains("chest: 2 sets"))
        XCTAssertTrue((strength["last_session_summary"] ?? "").contains("Chest Strength"))
    }

    func testAIContextIncludesLocalFatigue() throws {
        let generatedAt = makeDate()
        let workout = makeWorkout(start: generatedAt.addingTimeInterval(-6 * 3600))
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let typed = AIContextBuilder().buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = try XCTUnwrap(typed.context.strengthTraining)
        let fatigue = strength.localFatigue["chest"]
        XCTAssertEqual(fatigue?.setsLast48h, 2)
        XCTAssertEqual(fatigue?.setsLast7d, 2)
        XCTAssertEqual(strength.muscleGroupSets7d["chest"], 2)
    }

    func testAIContextMarksNoStrengthDataWhenEmpty() throws {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [],
            generatedAt: generatedAt
        )
        let typed = AIContextBuilder().buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [],
            generatedAt: generatedAt
        )

        let strength = result.envelope.strengthTraining ?? [:]
        XCTAssertEqual(strength["confidence"], "unavailable")
        XCTAssertEqual(strength["sessions_7d"], "0")
        XCTAssertTrue((strength["note"] ?? "").contains("No strength training data"))
        let typedStrength = try XCTUnwrap(typed.context.strengthTraining)
        XCTAssertEqual(typedStrength.sessions7d, 0)
        XCTAssertTrue(typedStrength.localFatigue.isEmpty)
    }
}
