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

    @MainActor
    func testStrainScoreNotOverwrittenByAggregator() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let testDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 10)))
        let dayStart = calendar.startOfDay(for: testDate)
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dayStart, calendar: calendar)

        // 1. Pre-populate summary with an existing strainScore
        let record = DailyHealthSummaryRecord(dayIdentifier: identifier, date: dayStart, strainScore: 65.5)
        context.insert(record)
        try context.save()

        // 2. Perform aggregation
        try WorkoutAggregationService.shared.aggregateDay(date: testDate, modelContext: context, calendar: calendar)

        // 3. Verify strainScore is NOT overwritten or blanked out
        let fetched = try context.fetch(FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.dayIdentifier == identifier }
        )).first
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.strainScore, 65.5)
    }

    @MainActor
    func testExerciseDefinitionCanonicalKeyAndTemplateLinkage() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        // 1. Seed defaults
        try ExerciseLibraryService.seedDefaultsIfNeeded(modelContext: context)

        // 2. Query definitions and verify canonicalKey exists and is stable
        let definitions = try context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())
        XCTAssertGreaterThan(definitions.count, 0)

        for def in definitions {
            XCTAssertFalse((def.canonicalKey ?? "").isEmpty)
        }

        // 3. Verify lookup using canonicalKey
        let firstDef = try XCTUnwrap(definitions.first)
        let key = firstDef.canonicalKey ?? ""
        let descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
            predicate: #Predicate<ExerciseDefinitionRecord> { $0.canonicalKey == key }
        )
        let fetched = try context.fetch(descriptor).first
        XCTAssertEqual(fetched?.id, firstDef.id)
    }

    @MainActor
    func testTrainingPlanLinkingConfidenceMatch() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let baseDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 2, hour: 18)))

        let linker = TrainingPlanLinkingService()

        // Case 1: Perfect focus match on expected date (High Confidence)
        let activePlanDay = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Chest Day",
            description: "Targeting chest/triceps",
            focus: "strength",
            durationMinutes: 45,
            intensity: "hard"
        )
        
        let strengthWorkout = StrengthWorkoutRecord(
            title: "Chest Day",
            startedAt: baseDate,
            durationMinutes: 45,
            exercises: [
                StrengthExerciseLog(name: "卧推", equipment: "barbell", primaryMuscleGroup: "chest", sets: [])
            ]
        )
        
        let matchedEvent = WorkoutEventRecord(
            source: "strengthLog",
            startedAt: baseDate,
            endedAt: baseDate.addingTimeInterval(45 * 60),
            activityType: "Chest Day",
            linkedStrengthWorkoutId: strengthWorkout.id
        )

        let highConfidenceScore = linker.calculateMatchScore(
            event: matchedEvent,
            planDay: activePlanDay,
            strengthWorkout: strengthWorkout,
            expectedDate: baseDate,
            calendar: calendar
        )
        XCTAssertTrue(linker.isHighConfidenceMatch(score: highConfidenceScore))

        // Case 2: Rest day mismatch (should return 0.0)
        let restPlanDay = TrainingDay(
            weekNumber: 1,
            dayNumber: 2,
            title: "Rest",
            description: "Rest Day",
            focus: "rest",
            durationMinutes: 0,
            intensity: "easy"
        )

        let restScore = linker.calculateMatchScore(
            event: matchedEvent,
            planDay: restPlanDay,
            strengthWorkout: strengthWorkout,
            expectedDate: calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate,
            calendar: calendar
        )
        XCTAssertEqual(restScore, 0.0)
    }

    @MainActor
    func testActiveWorkoutDraftLifecycle() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)

        // 1. Create a draft workout log
        let draft = ActiveWorkoutDraftRecord(
            title: "下午力量训练",
            startedAt: Date(),
            notes: "感觉状态很好"
        )
        draft.exercises = [
            StrengthExerciseLog(
                name: "杠铃卧推",
                equipment: "barbell",
                primaryMuscleGroup: "chest",
                sets: [
                    StrengthSetLog(repetitions: 10, weightKilograms: 70.0, isWarmup: false, isCompleted: true)
                ]
            )
        ]
        context.insert(draft)
        try context.save()

        // 2. Fetch it back and verify contents
        let fetchedDraft = try XCTUnwrap(context.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>()).first)
        XCTAssertEqual(fetchedDraft.title, "下午力量训练")
        XCTAssertEqual(fetchedDraft.exercises.count, 1)
        XCTAssertEqual(fetchedDraft.exercises.first?.name, "杠铃卧推")

        // 3. Clear draft upon completion
        context.delete(fetchedDraft)
        try context.save()

        let remainingDrafts = try context.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>())
        XCTAssertEqual(remainingDrafts.count, 0)
    }

    @MainActor
    func testNuancedCoverageStates() throws {
        // Direct testing of state mapping values
        XCTAssertEqual(HealthSignalAuthorizationState.authorizedButNoSamples.rawValue, "authorizedButNoSamples")
        XCTAssertEqual(HealthSignalAuthorizationState.noRecentSamples.rawValue, "noRecentSamples")
        XCTAssertEqual(HealthSignalAuthorizationState.deniedOrUnavailable.rawValue, "deniedOrUnavailable")
    }
}
