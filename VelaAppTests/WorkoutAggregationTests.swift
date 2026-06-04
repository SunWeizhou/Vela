import SwiftData
import XCTest
@testable import Vela

@MainActor
final class WorkoutAggregationTests: XCTestCase {
    private struct TestStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeStore() throws -> TestStore {
        let container = try VelaModelContainer.make(inMemory: true)
        return TestStore(container: container, context: ModelContext(container))
    }

    private func makeDate(
        year: Int = 2026,
        month: Int = 4,
        day: Int = 2,
        hour: Int = 10,
        minute: Int = 0
    ) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func makeStrengthWorkout(
        id: UUID = UUID(),
        start: Date,
        duration: Int = 60,
        title: String = "Upper Strength"
    ) -> StrengthWorkoutRecord {
        StrengthWorkoutRecord(
            id: id,
            title: title,
            startedAt: start,
            durationMinutes: duration,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: nil,
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start),
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start)
                    ]
                )
            ]
        )
    }

    private func fetchEvents(_ context: ModelContext) throws -> [WorkoutEventRecord] {
        try context.fetch(FetchDescriptor<WorkoutEventRecord>())
    }

    private func fetchDailySummary(_ context: ModelContext, date: Date) throws -> DailyHealthSummaryRecord? {
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: date)
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.dayIdentifier == identifier }
        )
        return try context.fetch(descriptor).first
    }

    func testStrengthWorkoutUpsertCreatesWorkoutEvent() throws {
        let store = try makeStore()
        let start = makeDate()
        let workout = makeStrengthWorkout(start: start)
        store.context.insert(workout)

        let event = try WorkoutAggregationService.shared.upsertWorkoutEvent(
            from: workout,
            modelContext: store.context,
            sessionRPE: 8
        )

        XCTAssertEqual(event.linkedStrengthWorkoutId, workout.id)
        XCTAssertEqual(event.source, "strengthLog")
        XCTAssertEqual(try fetchEvents(store.context).count, 1)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 60, accuracy: 0.1)
    }

    func testStrengthWorkoutUpsertIsIdempotent() throws {
        let store = try makeStore()
        let start = makeDate()
        let workout = makeStrengthWorkout(start: start)
        store.context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(from: workout, modelContext: store.context, sessionRPE: 8)
        try WorkoutAggregationService.shared.upsertWorkoutEvent(from: workout, modelContext: store.context, sessionRPE: 8)
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        XCTAssertEqual(try fetchEvents(store.context).count, 1)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 60, accuracy: 0.1)
        XCTAssertEqual(summary.workoutLoad ?? -1, 144, accuracy: 0.1)
    }

    func testAggregateDayDoesNotDuplicateHealthKitWorkout() throws {
        let store = try makeStore()
        let start = makeDate(hour: 7)
        let end = start.addingTimeInterval(45 * 60)
        let healthKitID = UUID()
        let healthKitWorkout = WorkoutSummary(
            id: healthKitID,
            start: start,
            end: end,
            activityName: "Running",
            energyKilocalories: 320,
            averageHeartRate: 142,
            source: "healthKit"
        )
        var snapshot = DailyHealthSnapshot(date: start)
        snapshot.workouts = [healthKitWorkout]
        let record = DailyHealthSummaryRecord(snapshot: snapshot)
        store.context.insert(record)
        store.context.insert(WorkoutEventRecord(
            id: UUID(),
            source: "healthKit",
            startedAt: start.addingTimeInterval(30),
            endedAt: end.addingTimeInterval(-20),
            activityType: "Running",
            energyKilocalories: 320,
            averageHeartRate: 142,
            linkedHealthKitWorkoutId: healthKitID
        ))

        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 45, accuracy: 0.1)
        XCTAssertEqual(summary.activeCalories ?? -1, 320, accuracy: 0.1)
    }

    func testAggregateDayPreservesManualWorkoutAfterHealthKitResync() throws {
        let store = try makeStore()
        let start = makeDate(hour: 8)
        let manualStart = makeDate(hour: 18)
        let healthKitWorkout = WorkoutSummary(
            start: start,
            end: start.addingTimeInterval(30 * 60),
            activityName: "Cycling",
            energyKilocalories: 220,
            source: "healthKit"
        )
        var snapshot = DailyHealthSnapshot(date: start)
        snapshot.workouts = [healthKitWorkout]
        let record = DailyHealthSummaryRecord(snapshot: snapshot)
        store.context.insert(record)
        store.context.insert(WorkoutEventRecord(
            source: "manual",
            startedAt: manualStart,
            endedAt: manualStart.addingTimeInterval(50 * 60),
            activityType: "Mobility",
            energyKilocalories: 120,
            rpe: 4
        ))

        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)
        var resync = DailyHealthSnapshot(date: start)
        resync.workouts = [healthKitWorkout]
        resync.activeCalories = 220
        resync.workoutDuration = 30
        record.apply(snapshot: resync)
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.workoutDuration ?? -1, 80, accuracy: 0.1)
        XCTAssertEqual(summary.activeCalories ?? -1, 340, accuracy: 0.1)
    }

    func testXunjiImportIsIdempotentByExternalID() throws {
        let store = try makeStore()
        let start = makeDate(hour: 19)
        let end = start.addingTimeInterval(60 * 60)
        let datestr = "2026-04-02"
        let json = """
        {
          "success": true,
          "res": {
            "trains": [{
              "datestr": "\(datestr)",
              "localid": 123456,
              "title": "胸部训练",
              "start": \(Int64(start.timeIntervalSince1970 * 1000)),
              "end": \(Int64(end.timeIntervalSince1970 * 1000)),
              "rpe": 8,
              "movements": [{
                "name": "杠铃卧推",
                "sets": [
                  { "done": true, "weight": "60", "unit": "kg", "reps": "10" },
                  { "done": true, "weight": "65", "unit": "kg", "reps": "8" }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

        let importer = XunjiTrainingImportService()
        let first = try importer.importResponseData(json, datestr: datestr, modelContext: store.context)
        let second = try importer.importResponseData(json, datestr: datestr, modelContext: store.context)

        XCTAssertEqual(first.importedCount, 1)
        XCTAssertEqual(second.updatedCount, 1)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<StrengthWorkoutRecord>()).count, 1)
        XCTAssertEqual(try fetchEvents(store.context).count, 1)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<XunjiWorkoutMirrorRecord>()).count, 1)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 60, accuracy: 0.1)
    }

    func testWorkoutLoadStableAfterRepeatedDashboardRefresh() throws {
        let store = try makeStore()
        let start = makeDate(hour: 17)
        let workout = makeStrengthWorkout(start: start, duration: 70)
        store.context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(from: workout, modelContext: store.context, sessionRPE: 7)
        let first = try XCTUnwrap(fetchDailySummary(store.context, date: start)).workoutLoad
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)
        let latest = try XCTUnwrap(fetchDailySummary(store.context, date: start)).workoutLoad

        XCTAssertEqual(latest ?? -1, first ?? -2, accuracy: 0.1)
        XCTAssertEqual(latest ?? -1, 147, accuracy: 0.1)
    }

    func testManualWorkoutNotErasedByHealthKitSync() throws {
        let store = try makeStore()
        let day = makeDate(hour: 9)
        let manualStart = makeDate(hour: 20)
        let manualEvent = WorkoutEventRecord(
            source: "manual",
            startedAt: manualStart,
            endedAt: manualStart.addingTimeInterval(25 * 60),
            activityType: "Stretching",
            energyKilocalories: 60,
            rpe: 3
        )
        store.context.insert(manualEvent)
        try WorkoutAggregationService.shared.aggregateDay(date: day, modelContext: store.context)

        let healthKitWorkout = WorkoutSummary(
            start: day,
            end: day.addingTimeInterval(35 * 60),
            activityName: "Walking",
            energyKilocalories: 140,
            source: "healthKit"
        )
        var snapshot = DailyHealthSnapshot(date: day)
        snapshot.workouts = [healthKitWorkout]
        snapshot.activeCalories = 140
        snapshot.workoutDuration = 35
        let record = try XCTUnwrap(fetchDailySummary(store.context, date: day))
        record.apply(snapshot: snapshot)
        try WorkoutAggregationService.shared.aggregateDay(date: day, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: day))
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertTrue(summary.toSnapshot().workouts.contains { $0.source == "manual" && $0.activityName == "Stretching" })
    }
}
