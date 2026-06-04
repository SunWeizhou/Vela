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
}
