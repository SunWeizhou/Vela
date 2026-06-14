import XCTest
@testable import Vela

final class ScoringEngineTests: XCTestCase {
    func testSleepScoreEngineProducesValidRange() {
        let engine = SleepScoreEngine()
        let input = SleepScoreInput(
            totalSleepMinutes: 420,
            sleepTargetMinutes: 480,
            awakeMinutes: 15,
            awakeEpisodeCount: 2,
            remMinutes: 90,
            deepMinutes: 90
        )
        let result = engine.calculate(from: input)
        XCTAssertGreaterThanOrEqual(result.value ?? 0, 0)
        XCTAssertLessThanOrEqual(result.value ?? 0, 100)
    }

    func testRecoveryScoreEngineHandlesEmptyHistory() {
        let engine = RecoveryScoreEngine()
        let input = RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 50,
            hrvHistory: [],
            restingHeartRateToday: 58,
            restingHeartRateBaseline: 55,
            rhrHistory: [],
            sleepScoreLastNight: 75,
            strainScoreYesterday: 50
        )
        let result = engine.calculate(from: input)
        XCTAssertNotNil(result)
    }

    func testStrainScoreEngineProducesValidRange() {
        let engine = StrainScoreEngine()
        let input = StrainScoreInput(
            workouts: [WorkoutInput(durationMinutes: 45, averageHeartRate: 140, rpe: 6)],
            activeEnergyToday: 500,
            exerciseMinutesToday: 45,
            restingHR: 60,
            maxHR: 180,
            last28DaysDailyLoads: []
        )
        let result = engine.calculate(from: input)
        XCTAssertGreaterThanOrEqual(result.value ?? 0, 0)
        XCTAssertLessThanOrEqual(result.value ?? 0, 100)
    }

    func testBodyStateKernelProvidesFallbackWithoutHealthKit() {
        let now = Date()
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .empty(date: now),
            activeStatus: "active",
            generatedAt: now
        ))

        XCTAssertEqual(bodyState.readiness, .unknown)
        XCTAssertEqual(bodyState.confidence, .low)
        XCTAssertEqual(bodyState.freshness, .missing)
        XCTAssertFalse(bodyState.drivers.isEmpty)
        XCTAssertFalse(bodyState.hash.isEmpty)
    }

    func testBodyStateKernelIncludesLocalFatigueAndTrainingResponseDrivers() {
        let now = Date()
        let workout = StrengthWorkoutRecord(
            title: "Leg Day",
            startedAt: now.addingTimeInterval(-6 * 3600),
            durationMinutes: 60,
            exercises: [
                StrengthExerciseLog(
                    name: "Squat",
                    equipment: "barbell",
                    primaryMuscleGroup: "legs",
                    sets: (0..<8).map { _ in
                        StrengthSetLog(repetitions: 8, weightKilograms: 100, rpe: 8, isCompleted: true)
                    }
                )
            ]
        )
        let response = TrainingResponseRecord(
            workoutId: UUID(),
            date: now.addingTimeInterval(-2 * 86_400),
            nextDayDate: now.addingTimeInterval(-86_400),
            primaryMuscleGroups: ["legs"],
            totalEffectiveSets: 12,
            totalVolumeKg: 9_600,
            nextDayRecoveryDelta: -10
        )

        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(date: now),
            strengthWorkouts: [workout],
            trainingResponses: [response],
            activeStatus: "active",
            generatedAt: now
        ))

        XCTAssertEqual(bodyState.localFatigue["legs"]?.fatigueLevel, "high")
        XCTAssertTrue(bodyState.drivers.contains { $0.kind == .localFatigue })
        XCTAssertTrue(bodyState.drivers.contains { $0.kind == .trainingResponse })
    }

    func testTrainingDecisionKernelRestsForSickStatus() {
        let now = Date()
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(date: now),
            activeStatus: "sick",
            generatedAt: now
        ))

        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        XCTAssertEqual(decision.decision, .rest)
        XCTAssertEqual(decision.volumeMultiplier, 0)
        XCTAssertLessThanOrEqual(decision.intensityCap, 2)
        XCTAssertTrue(decision.safetyNotice.contains("not a medical diagnosis"))
    }

    func testLegacyTrainingDecisionIsACompatibilityViewOfCanonicalDecision() {
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(),
            activeStatus: "active"
        ))
        let canonical = DailyTrainingDecision(
            decision: .reduce,
            targetSessionTitle: "Upper Strength",
            volumeMultiplier: 0.72,
            intensityCap: 7,
            reasons: ["Sleep: below baseline"],
            userFacingSummary: "Reduce planned volume.",
            confidence: 0.75,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "General guidance only."
        )

        let compatibility = TrainingDecision.compatibilityView(
            of: canonical,
            bodyState: bodyState
        )

        XCTAssertEqual(compatibility.kind, .maintain)
        XCTAssertEqual(compatibility.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(compatibility.maxIntensity, "RPE 7")
        XCTAssertEqual(compatibility.whyThis, canonical.reasons.joined(separator: " "))
        XCTAssertEqual(compatibility.body, canonical.userFacingSummary)
    }
}
