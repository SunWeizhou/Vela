import XCTest
import SwiftData
@testable import Vela

final class Milestone1ChallengeTests: XCTestCase {

    // MARK: - 1. Parasympathetic Tone Index (PSTI) Mathematical Correctness

    func testPSTIScoreScalingAndZScoreCorrectness() {
        let engine = RecoveryScoreEngine()

        // Test 1: Normal baseline matching history (Z = 0 -> PSTI = 50)
        let inputBaseline = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 50,
            hrvBaseline: 50,
            hrvHistory: [50, 50, 50, 50, 50],
            hrvRmssdToday: 50,
            hrvRmssdBaseline: 50,
            hrvRmssdHistory: [50, 50, 50, 50, 50],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            rhrHistory: [60, 60, 60, 60, 60],
            sleepScoreLastNight: 80,
            strainScoreYesterday: 40
        )
        let resultBaseline = engine.calculate(from: inputBaseline)
        let pstiBaseline = resultBaseline.components["parasympathetic_tone_index"]
        let zBaseline = resultBaseline.components["psti_z_score"]

        XCTAssertNotNil(pstiBaseline)
        XCTAssertNotNil(zBaseline)
        XCTAssertEqual(zBaseline!, 0.0, accuracy: 0.05, "At baseline, PSTI Z-score should be ~0")
        XCTAssertEqual(pstiBaseline!, 50.0, accuracy: 1.0, "At baseline, PSTI score should be ~50")

        // Test 2: Elevated RMSSD (e.g. RMSSD 85ms vs baseline 50ms) -> Positive Z-score & High PSTI
        let inputElevated = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 85,
            hrvBaseline: 50,
            hrvHistory: [45, 50, 52, 48, 51, 50, 49],
            hrvRmssdToday: 85,
            hrvRmssdBaseline: 50,
            hrvRmssdHistory: [45, 50, 52, 48, 51, 50, 49],
            restingHeartRateToday: 55,
            restingHeartRateBaseline: 60,
            rhrHistory: [60, 60, 60, 60, 60],
            sleepScoreLastNight: 85,
            strainScoreYesterday: 30
        )
        let resultElevated = engine.calculate(from: inputElevated)
        let pstiElevated = resultElevated.components["parasympathetic_tone_index"]!
        let zElevated = resultElevated.components["psti_z_score"]!

        XCTAssertGreaterThan(zElevated, 1.0, "Significantly higher RMSSD should produce positive Z-score > 1.0")
        XCTAssertGreaterThan(pstiElevated, 70.0, "PSTI score should be high (>70) for elevated vagal tone")

        // Test 3: Depressed RMSSD (e.g. RMSSD 20ms vs baseline 50ms) -> Negative Z-score & Low PSTI
        let inputDepressed = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 20,
            hrvBaseline: 50,
            hrvHistory: [45, 50, 52, 48, 51, 50, 49],
            hrvRmssdToday: 20,
            hrvRmssdBaseline: 50,
            hrvRmssdHistory: [45, 50, 52, 48, 51, 50, 49],
            restingHeartRateToday: 70,
            restingHeartRateBaseline: 60,
            rhrHistory: [60, 60, 60, 60, 60],
            sleepScoreLastNight: 50,
            strainScoreYesterday: 80
        )
        let resultDepressed = engine.calculate(from: inputDepressed)
        let pstiDepressed = resultDepressed.components["parasympathetic_tone_index"]!
        let zDepressed = resultDepressed.components["psti_z_score"]!

        XCTAssertLessThan(zDepressed, -1.0, "Significantly lower RMSSD should produce negative Z-score < -1.0")
        XCTAssertLessThan(pstiDepressed, 30.0, "PSTI score should be low (<30) for suppressed vagal tone")

        // Test 4: Extreme boundary values (RMSSD = 0.5ms and RMSSD = 500ms) -> Clamped between 0 and 100
        let inputZero = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 0.5,
            hrvBaseline: 50,
            hrvHistory: [48, 50, 52, 49, 51],
            hrvRmssdToday: 0.5,
            hrvRmssdBaseline: 50,
            hrvRmssdHistory: [48, 50, 52, 49, 51],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            sleepScoreLastNight: 70,
            strainScoreYesterday: 40
        )
        let resultZero = engine.calculate(from: inputZero)
        let pstiZero = resultZero.components["parasympathetic_tone_index"]!
        XCTAssertGreaterThanOrEqual(pstiZero, 0.0)
        XCTAssertLessThanOrEqual(pstiZero, 100.0)

        let inputExtremeHigh = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 500,
            hrvBaseline: 50,
            hrvHistory: [48, 50, 52, 49, 51],
            hrvRmssdToday: 500,
            hrvRmssdBaseline: 50,
            hrvRmssdHistory: [48, 50, 52, 49, 51],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            sleepScoreLastNight: 70,
            strainScoreYesterday: 40
        )
        let resultExtremeHigh = engine.calculate(from: inputExtremeHigh)
        let pstiExtremeHigh = resultExtremeHigh.components["parasympathetic_tone_index"]!
        XCTAssertEqual(pstiExtremeHigh, 100.0, "Extreme high RMSSD should clamp to 100.0")
    }

    func testPSTIFallbackWhenRMSSDIsNilButHRVIsPresent() {
        let engine = RecoveryScoreEngine()

        // When hrvRmssdToday is nil, fallback uses hrvToday
        let input = RecoveryScoreInput(
            asOf: Date(),
            hrvToday: 65,
            hrvBaseline: 50,
            hrvHistory: [48, 50, 52, 49, 51],
            hrvRmssdToday: nil,
            hrvRmssdBaseline: nil,
            hrvRmssdHistory: [],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            sleepScoreLastNight: 75,
            strainScoreYesterday: 40
        )
        let result = engine.calculate(from: input)
        XCTAssertNotNil(result.components["parasympathetic_tone_index"], "Should fallback to hrvToday when hrvRmssdToday is nil")
    }

    // MARK: - 2. FoodLogRecord & Nutrition Aggregation Edge Cases

    func testFoodLogAggregationWithEmptyLogs() {
        let calendar = Calendar.current
        let refDate = Date()

        let assembly = SecondaryDataAssembler.assemble(
            dashboard: .empty(date: refDate),
            refDate: refDate,
            calendar: calendar,
            dailySummaries: [],
            workoutEvents: [],
            strengthWorkouts: [],
            trainingResponses: [],
            foodLogs: [],
            journalEntries: [],
            coachArtifacts: [],
            activePlan: nil,
            persistedDecision: nil
        )

        XCTAssertEqual(assembly.todayCalories, 0)
        XCTAssertEqual(assembly.todayProtein, 0)
        XCTAssertEqual(assembly.todayCarbs, 0)
        XCTAssertEqual(assembly.todayFat, 0)
    }

    func testFoodLogAggregationMultipleMealsOnSameDay() {
        let calendar = Calendar.current
        let refDate = Date()
        let startOfDay = calendar.startOfDay(for: refDate)

        let log1 = FoodLogDTO(
            id: UUID(),
            createdAt: startOfDay.addingTimeInterval(8 * 3600), // Breakfast
            totalCalories: 450,
            proteinGrams: 25,
            carbsGrams: 50,
            fatGrams: 15,
            fiberGrams: 6
        )
        let log2 = FoodLogDTO(
            id: UUID(),
            createdAt: startOfDay.addingTimeInterval(13 * 3600), // Lunch
            totalCalories: 750,
            proteinGrams: 45,
            carbsGrams: 80,
            fatGrams: 25,
            fiberGrams: 8
        )

        let assembly = SecondaryDataAssembler.assemble(
            dashboard: .empty(date: refDate),
            refDate: refDate,
            calendar: calendar,
            dailySummaries: [],
            workoutEvents: [],
            strengthWorkouts: [],
            trainingResponses: [],
            foodLogs: [log1, log2],
            journalEntries: [],
            coachArtifacts: [],
            activePlan: nil,
            persistedDecision: nil
        )

        XCTAssertEqual(assembly.todayCalories, 1200)
        XCTAssertEqual(assembly.todayProtein, 70)
        XCTAssertEqual(assembly.todayCarbs, 130)
        XCTAssertEqual(assembly.todayFat, 40)
    }

    func testFoodLogAggregationDateBoundaryExclusion() {
        let calendar = Calendar.current
        let refDate = Date()
        let startOfDay = calendar.startOfDay(for: refDate)
        let yesterday = startOfDay.addingTimeInterval(-10)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let todayLog = FoodLogDTO(
            id: UUID(),
            createdAt: startOfDay.addingTimeInterval(12 * 3600),
            totalCalories: 500,
            proteinGrams: 30,
            carbsGrams: 60,
            fatGrams: 15,
            fiberGrams: 5
        )
        let yesterdayLog = FoodLogDTO(
            id: UUID(),
            createdAt: yesterday,
            totalCalories: 800,
            proteinGrams: 50,
            carbsGrams: 90,
            fatGrams: 30,
            fiberGrams: 10
        )
        let tomorrowLog = FoodLogDTO(
            id: UUID(),
            createdAt: tomorrow,
            totalCalories: 600,
            proteinGrams: 40,
            carbsGrams: 70,
            fatGrams: 20,
            fiberGrams: 7
        )

        let assembly = SecondaryDataAssembler.assemble(
            dashboard: .empty(date: refDate),
            refDate: refDate,
            calendar: calendar,
            dailySummaries: [],
            workoutEvents: [],
            strengthWorkouts: [],
            trainingResponses: [],
            foodLogs: [todayLog, yesterdayLog, tomorrowLog],
            journalEntries: [],
            coachArtifacts: [],
            activePlan: nil,
            persistedDecision: nil
        )

        XCTAssertEqual(assembly.todayCalories, 500, "Should only aggregate food logs created on refDate")
        XCTAssertEqual(assembly.todayProtein, 30)
        XCTAssertEqual(assembly.todayCarbs, 60)
        XCTAssertEqual(assembly.todayFat, 15)
    }

    func testFoodLogAggregationNegativeValuesHandling() {
        let calendar = Calendar.current
        let refDate = Date()
        let startOfDay = calendar.startOfDay(for: refDate)

        let negativeLog = FoodLogDTO(
            id: UUID(),
            createdAt: startOfDay.addingTimeInterval(10 * 3600),
            totalCalories: -200,
            proteinGrams: -10,
            carbsGrams: -30,
            fatGrams: -5,
            fiberGrams: -2
        )

        let assembly = SecondaryDataAssembler.assemble(
            dashboard: .empty(date: refDate),
            refDate: refDate,
            calendar: calendar,
            dailySummaries: [],
            workoutEvents: [],
            strengthWorkouts: [],
            trainingResponses: [],
            foodLogs: [negativeLog],
            journalEntries: [],
            coachArtifacts: [],
            activePlan: nil,
            persistedDecision: nil
        )

        XCTAssertEqual(assembly.todayCalories, -200)
    }

    // MARK: - 3. scenePhase Debounce & HealthCachePolicy Verification

    @MainActor
    func testDashboardRefreshHonorFreshnessPolicy() async {
        let vm = DashboardViewModel()
        let container = try! VelaModelContainer.make(inMemory: true)
        let context = container.mainContext

        await vm.refresh(modelContext: context, force: false)
        let firstRefreshTime = vm.lastUpdated

        await vm.refresh(modelContext: context, force: false)
        XCTAssertEqual(vm.lastUpdated, firstRefreshTime, "Non-forced refresh within 15-min TTL should reuse cached data and not re-execute full fetch")

        await vm.refresh(modelContext: context, force: true)
        XCTAssertNotNil(vm.lastUpdated)
    }
}
