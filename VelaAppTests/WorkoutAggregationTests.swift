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

    @MainActor
    func testStrengthWorkoutUpsertCreatesOneEventAndAggregatesDailySummary() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let startedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 18)))
        let workout = StrengthWorkoutRecord(
            title: "Push",
            startedAt: startedAt,
            durationMinutes: 50,
            exercises: [
                StrengthExerciseLog(name: "杠铃卧推", equipment: "barbell", sets: [
                    StrengthSetLog(repetitions: 8, weightKilograms: 80, rpe: 8)
                ])
            ]
        )
        context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(
            from: workout,
            modelContext: context,
            sessionRPE: 8,
            calendar: calendar
        )
        try WorkoutAggregationService.shared.upsertWorkoutEvent(
            from: workout,
            modelContext: context,
            sessionRPE: 8,
            calendar: calendar
        )

        let events = try context.fetch(FetchDescriptor<WorkoutEventRecord>())
        let summaries = try context.fetch(FetchDescriptor<DailyHealthSummaryRecord>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.linkedStrengthWorkoutId, workout.id)
        XCTAssertEqual(summaries.first?.workoutCount, 1)
        XCTAssertEqual(summaries.first?.workoutDuration, 50)
        XCTAssertGreaterThan(summaries.first?.workoutLoad ?? 0, 0)
    }

    @MainActor
    func testStrengthWorkoutLinksActivePlanDayAndMarksItCompleted() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let startedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 18)))
        let planDay = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Push",
            description: "Chest and triceps",
            focus: "strength",
            durationMinutes: 45,
            intensity: "moderate"
        )
        let plan = TrainingPlanRecord(title: "Hypertrophy", goalDescription: "Build muscle", startDate: startedAt, days: [planDay])
        let workout = StrengthWorkoutRecord(title: "Push", startedAt: startedAt, durationMinutes: 50, exercises: [])
        context.insert(plan)
        context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(
            from: workout,
            modelContext: context,
            sessionRPE: 7,
            calendar: calendar
        )

        let linkedDay = try XCTUnwrap(plan.days.first)
        XCTAssertTrue(linkedDay.isCompleted)
        XCTAssertNotNil(linkedDay.completedAt)
        XCTAssertEqual(linkedDay.linkedWorkoutEventIds.count, 1)
        XCTAssertNotNil(linkedDay.adherenceScore)
    }

    @MainActor
    func testHealthKitWorkoutMirrorIsIdempotentAndPreservesManualEvents() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let startedAt = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 7)))
        let healthKitWorkout = WorkoutSummary(
            id: UUID(),
            start: startedAt,
            end: startedAt.addingTimeInterval(30 * 60),
            activityName: "Running",
            energyKilocalories: 280,
            averageHeartRate: 148,
            source: "healthKit"
        )
        context.insert(WorkoutEventRecord(
            source: "manual",
            startedAt: startedAt.addingTimeInterval(60 * 60),
            endedAt: startedAt.addingTimeInterval(90 * 60),
            activityType: "Yoga"
        ))

        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            modelContext: context,
            calendar: calendar
        )
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            modelContext: context,
            calendar: calendar
        )

        let events = try context.fetch(FetchDescriptor<WorkoutEventRecord>())
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.filter { $0.source == "healthKit" }.first?.linkedHealthKitWorkoutId, healthKitWorkout.id)
        XCTAssertEqual(events.filter { $0.source == "healthKit" }.first?.averageHeartRate, 148)
        XCTAssertEqual(events.filter { $0.source == "manual" }.count, 1)
    }
}
