import XCTest
import SwiftData
@testable import Vela

final class WorkoutAggregationTests: XCTestCase {
    
    func testFosterRPETRIMP() {
        let engine = StrainScoreEngine()
        
        // 1. Foster's session RPE scaled to TRIMP units: duration * rpe * 0.3
        // Case: duration 45 mins, RPE 7
        // Expected load: 45 * 7 * 0.3 = 94.5
        let workout = WorkoutInput(
            durationMinutes: 45,
            rpe: 7
        )
        
        let input = StrainScoreInput(
            workouts: [workout],
            restingHR: 60,
            maxHR: 190,
            last28DaysDailyLoads: [100.0] // baseline load
        )
        
        let result = engine.calculate(from: input)
        
        let workoutLoad = result.components["workout_load"] ?? 0.0
        XCTAssertEqual(workoutLoad, 94.5, accuracy: 0.001)
        
        // Strain score should be calculated from dailyLoad / baseline
        // dailyLoad = 94.5 + activityLoad
        // With no steps/calories, activityLoad = 0
        // dailyLoad = 94.5
        // loadRatio = 94.5 / 100.0 = 0.945
        // strainValue = 100 * (1 - exp(-0.75 * 0.945)) = 100 * (1 - exp(-0.70875)) = 100 * (1 - 0.492257) = 50.77
        XCTAssertEqual(result.score, 50.77, accuracy: 0.1)
    }
    
    @MainActor
    func testWorkoutAggregation() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        
        let calendar = Calendar(identifier: .gregorian)
        let testDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 10)))
        
        // 1. Prepare HealthKit mock workouts
        let hkWorkout = WorkoutSummary(
            id: UUID(),
            start: testDate.addingTimeInterval(-3600), // 1 hour ago
            end: testDate,
            activityName: "Running",
            energyKilocalories: 600,
            averageHeartRate: 150,
            source: "healthKit"
        )
        
        // 2. Insert manual workout event in SwiftData
        let manualEvent = WorkoutEventRecord(
            source: "manual",
            startedAt: testDate.addingTimeInterval(-1800), // 30 mins ago
            endedAt: testDate,
            activityType: "Yoga",
            energyKilocalories: 150,
            rpe: 5.0
        )
        context.insert(manualEvent)
        
        // 3. Insert strength workout event
        let strengthWorkoutId = UUID()
        let strengthEvent = WorkoutEventRecord(
            source: "strengthLog",
            startedAt: testDate.addingTimeInterval(-7200), // 2 hours ago
            endedAt: testDate.addingTimeInterval(-3600),
            activityType: "Strength Training",
            energyKilocalories: 300,
            rpe: 8.0,
            linkedStrengthWorkoutId: strengthWorkoutId
        )
        context.insert(strengthEvent)
        
        try context.save()
        
        // Aggregate
        let service = WorkoutAggregationService.shared
        let aggregated = service.aggregateWorkouts(
            healthKitWorkouts: [hkWorkout],
            for: testDate,
            modelContext: context,
            calendar: calendar
        )
        
        // We should have 3 workouts total (HealthKit running, manual Yoga, strength Training)
        XCTAssertEqual(aggregated.count, 3)
        
        let yoga = aggregated.first { $0.activityName == "Yoga" }
        XCTAssertNotNil(yoga)
        XCTAssertEqual(yoga?.source, "manual")
        XCTAssertEqual(yoga?.rpe, 5.0)
        XCTAssertEqual(yoga?.energyKilocalories, 150)
        
        let strength = aggregated.first { $0.activityName == "Strength Training" }
        XCTAssertNotNil(strength)
        XCTAssertEqual(strength?.source, "strengthLog")
        XCTAssertEqual(strength?.rpe, 8.0)
        
        let running = aggregated.first { $0.activityName == "Running" }
        XCTAssertNotNil(running)
        XCTAssertEqual(running?.source, "healthKit")
        XCTAssertEqual(running?.averageHeartRate, 150)
    }
}
