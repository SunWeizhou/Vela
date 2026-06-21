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

    func testDefaultWorkoutTemplatesUseChineseUserFacingTitles() {
        let titles = ExerciseLibraryService.defaultTemplates().map(\.title)

        XCTAssertTrue(titles.contains("推力训练"))
        XCTAssertTrue(titles.contains("腿部训练"))
        XCTAssertFalse(titles.contains("Push Day"))
        XCTAssertFalse(titles.contains("Leg Day"))
        XCTAssertFalse(titles.contains("Upper Body"))
    }

    func testStrengthWorkoutAnalysisUsesChineseUserFacingSummary() {
        let workout = makeStrengthWorkout(start: makeDate(), title: "上肢训练")

        let analysis = TrainingAnalyticsService().summarizeWorkout(
            workout,
            history: [],
            exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
        )

        XCTAssertTrue(analysis.summaryText.contains("已完成 2/2 组"))
        XCTAssertTrue(analysis.summaryText.contains("有效组"))
        XCTAssertTrue(analysis.summaryText.contains("胸部"))
        XCTAssertFalse(analysis.summaryText.contains("completed sets"))
        XCTAssertFalse(analysis.summaryText.contains("effective sets"))
        XCTAssertFalse(analysis.summaryText.contains("chest 2"))
    }

    func testPersonalRecordUsesChineseUserFacingDescription() {
        let weightRecord = PersonalRecord(
            exerciseName: "卧推",
            kind: "max_weight",
            value: 80,
            previousValue: 75
        )
        let estimatedRecord = PersonalRecord(
            exerciseName: "卧推",
            kind: "estimated_1rm",
            value: 101.3,
            previousValue: 96
        )

        XCTAssertEqual(weightRecord.summary, "卧推 重量新高：80 kg")
        XCTAssertEqual(estimatedRecord.summary, "卧推 估算最大重量新高：101.3 kg")
        XCTAssertFalse(weightRecord.summary.contains("max_weight"))
        XCTAssertFalse(estimatedRecord.summary.contains("estimated_1rm"))
    }

    private func makePostWorkoutArtifact(
        workout: StrengthWorkoutRecord,
        summary: StrengthWorkoutAnalysis
    ) -> CoachArtifactRecord {
        CoachArtifactRecord(artifact: CoachArtifact.postWorkoutReview(
            workout: workout,
            summary: summary,
            readinessDecision: "keep",
            sourceContextHash: "test-\(workout.id.uuidString)"
        ))
    }

    func testWorkoutSaveCoordinatorCommitsWorkoutEventArtifactSummaryAndDraftDeletion() throws {
        let store = try makeStore()
        let start = makeDate()
        let workout = makeStrengthWorkout(start: start)
        let draft = ActiveWorkoutDraftRecord(title: "Draft", startedAt: start)
        store.context.insert(draft)
        try store.context.save()
        let analysis = TrainingAnalyticsService().summarizeWorkout(
            workout,
            history: [],
            exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
        )
        workout.analyticsJSON = try String(
            data: JSONEncoder().encode(analysis),
            encoding: .utf8
        )
        let artifact = makePostWorkoutArtifact(workout: workout, summary: analysis)

        let result = try WorkoutSaveCoordinator().commitNewWorkout(
            workout: workout,
            artifact: artifact,
            sessionRPE: 8,
            modelContext: store.context
        )

        XCTAssertEqual(result.workout.id, workout.id)
        XCTAssertEqual(result.event.linkedStrengthWorkoutId, workout.id)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<StrengthWorkoutRecord>()).count, 1)
        XCTAssertEqual(try fetchEvents(store.context).count, 1)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<CoachArtifactRecord>()).count, 1)
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>()).count, 0)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 60, accuracy: 0.1)
    }

    func testWorkoutSaveCoordinatorRollsBackEveryStageAndPreservesDraft() throws {
        for stage in WorkoutSaveCoordinator.Stage.allCases {
            let store = try makeStore()
            let start = makeDate(minute: stage.rawValue)
            let workout = makeStrengthWorkout(start: start)
            let draft = ActiveWorkoutDraftRecord(title: "Draft", startedAt: start)
            store.context.insert(draft)
            try store.context.save()
            let analysis = TrainingAnalyticsService().summarizeWorkout(
                workout,
                history: [],
                exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
            )
            let artifact = makePostWorkoutArtifact(workout: workout, summary: analysis)
            let coordinator = WorkoutSaveCoordinator { currentStage in
                if currentStage == stage {
                    throw TestCommitError.injected(stage)
                }
            }

            XCTAssertThrowsError(try coordinator.commitNewWorkout(
                workout: workout,
                artifact: artifact,
                sessionRPE: 8,
                modelContext: store.context
            ))

            XCTAssertEqual(
                try store.context.fetch(FetchDescriptor<StrengthWorkoutRecord>()).count,
                0,
                "stage \(stage) left a workout"
            )
            XCTAssertEqual(try fetchEvents(store.context).count, 0, "stage \(stage) left an event")
            XCTAssertEqual(
                try store.context.fetch(FetchDescriptor<CoachArtifactRecord>()).count,
                0,
                "stage \(stage) left an artifact"
            )
            XCTAssertEqual(
                try store.context.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>()).count,
                1,
                "stage \(stage) deleted the draft"
            )
            XCTAssertNil(try fetchDailySummary(store.context, date: start), "stage \(stage) left a daily summary")
        }
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

    func testWorkoutSaveCreatesWorkoutEvent() throws {
        try testStrengthWorkoutUpsertCreatesWorkoutEvent()
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

    func testRepeatedWorkoutSaveDoesNotDuplicateEvent() throws {
        try testStrengthWorkoutUpsertIsIdempotent()
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
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            on: start,
            modelContext: store.context
        )

        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)
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
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            on: start,
            modelContext: store.context
        )
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
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            on: start,
            modelContext: store.context
        )
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.workoutDuration ?? -1, 80, accuracy: 0.1)
        XCTAssertEqual(summary.activeCalories ?? -1, 340, accuracy: 0.1)
    }

    func testManualWorkoutPreservedAfterHealthKitSync() throws {
        try testAggregateDayPreservesManualWorkoutAfterHealthKitResync()
    }

    func testDailySummaryApplyDoesNotWriteWorkoutAggregationFields() {
        let start = makeDate()
        let existing = DailyHealthSummaryRecord(
            dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: start),
            date: start,
            workoutCount: 3,
            workoutTypes: "Strength",
            workoutDuration: 90,
            dailyLoad: 120,
            workoutLoad: 90,
            workoutsData: Data("existing".utf8)
        )
        var snapshot = DailyHealthSnapshot(date: start)
        snapshot.workoutCount = 1
        snapshot.workoutTypes = "Running"
        snapshot.workoutDuration = 30
        snapshot.dailyLoad = 40
        snapshot.workoutLoad = 30
        snapshot.workouts = [
            WorkoutSummary(
                start: start,
                end: start.addingTimeInterval(1800),
                activityName: "Running",
                source: "healthKit"
            )
        ]

        existing.apply(snapshot: snapshot)

        XCTAssertEqual(existing.workoutCount, 3)
        XCTAssertEqual(existing.workoutTypes, "Strength")
        XCTAssertEqual(existing.workoutDuration, 90)
        XCTAssertEqual(existing.dailyLoad, 120)
        XCTAssertEqual(existing.workoutLoad, 90)
        XCTAssertEqual(existing.workoutsData, Data("existing".utf8))
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

    func testXunjiImportCreatesPostWorkoutArtifact() throws {
        let store = try makeStore()
        let start = makeDate(hour: 19)
        let end = start.addingTimeInterval(45 * 60)
        let datestr = "2026-04-02"
        let json = """
        {
          "success": true,
          "res": {
            "trains": [{
              "datestr": "\(datestr)",
              "localid": 778899,
              "title": "背部训练",
              "start": \(Int64(start.timeIntervalSince1970 * 1000)),
              "end": \(Int64(end.timeIntervalSince1970 * 1000)),
              "rpe": 7,
              "movements": [{
                "name": "高位下拉",
                "sets": [
                  { "done": true, "weight": "50", "unit": "kg", "reps": "12", "rpe": 7 },
                  { "done": false, "weight": "55", "unit": "kg", "reps": "10", "rpe": 8 }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

        let summary = try XunjiTrainingImportService().importResponseData(json, datestr: datestr, modelContext: store.context)

        XCTAssertEqual(summary.importedCount, 1)
        let artifact = try XCTUnwrap(store.context.fetch(FetchDescriptor<CoachArtifactRecord>()).first?.artifact)
        XCTAssertEqual(artifact.type, .postWorkoutReview)
        XCTAssertEqual(artifact.decision, "xunji_import")
        XCTAssertTrue(artifact.summary.contains("背部训练"))
        let workout = try XCTUnwrap(store.context.fetch(FetchDescriptor<StrengthWorkoutRecord>()).first)
        XCTAssertEqual(workout.exercises.first?.sets.last?.isCompleted, false)
    }

    func testXunjiImportMergesIntoExistingAppleStrengthWorkoutAndKeepsAppleMetrics() throws {
        let store = try makeStore()
        let start = makeDate(hour: 19)
        let end = start.addingTimeInterval(62 * 60)
        let healthKitID = UUID()
        store.context.insert(WorkoutEventRecord(
            id: healthKitID,
            source: "healthKit",
            startedAt: start,
            endedAt: end,
            activityType: "Traditional Strength Training",
            energyKilocalories: 420,
            averageHeartRate: 138,
            linkedHealthKitWorkoutId: healthKitID
        ))
        try store.context.save()
        let datestr = "2026-04-02"
        let json = """
        {
          "success": true,
          "res": {
            "trains": [{
              "datestr": "\(datestr)",
              "localid": 456789,
              "title": "胸肩三头",
              "start": \(Int64(start.addingTimeInterval(90).timeIntervalSince1970 * 1000)),
              "end": \(Int64(end.addingTimeInterval(-60).timeIntervalSince1970 * 1000)),
              "rpe": 8,
              "movements": [{
                "name": "杠铃卧推",
                "sets": [
                  { "done": true, "weight": "80", "unit": "kg", "reps": "8" }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

        _ = try XunjiTrainingImportService().importResponseData(json, datestr: datestr, modelContext: store.context)

        let events = try fetchEvents(store.context)
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.id, healthKitID)
        XCTAssertEqual(event.linkedHealthKitWorkoutId, healthKitID)
        XCTAssertNotNil(event.linkedStrengthWorkoutId)
        XCTAssertEqual(event.activityType, "胸肩三头")
        XCTAssertEqual(event.title, "胸肩三头")
        XCTAssertEqual(event.energyKilocalories ?? -1, 420, accuracy: 0.1)
        XCTAssertEqual(event.averageHeartRate ?? -1, 138, accuracy: 0.1)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        let workout = try XCTUnwrap(summary.toSnapshot().workouts.first)
        XCTAssertEqual(workout.activityName, "胸肩三头")
        XCTAssertEqual(workout.energyKilocalories ?? -1, 420, accuracy: 0.1)
        XCTAssertEqual(workout.averageHeartRate ?? -1, 138, accuracy: 0.1)
    }

    func testHealthKitSyncMergesIntoExistingXunjiStrengthWorkout() throws {
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
              "localid": 567890,
              "title": "背部二头",
              "start": \(Int64(start.timeIntervalSince1970 * 1000)),
              "end": \(Int64(end.timeIntervalSince1970 * 1000)),
              "rpe": 7,
              "movements": [{
                "name": "高位下拉",
                "sets": [
                  { "done": true, "weight": "60", "unit": "kg", "reps": "10" }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!
        _ = try XunjiTrainingImportService().importResponseData(json, datestr: datestr, modelContext: store.context)
        let healthKitID = UUID()
        let healthKitWorkout = WorkoutSummary(
            id: healthKitID,
            start: start.addingTimeInterval(30),
            end: end.addingTimeInterval(-30),
            activityName: "Traditional Strength Training",
            energyKilocalories: 380,
            averageHeartRate: 132,
            source: "healthKit"
        )

        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            on: start,
            modelContext: store.context
        )
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let events = try fetchEvents(store.context)
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.linkedHealthKitWorkoutId, healthKitID)
        XCTAssertNotNil(event.linkedStrengthWorkoutId)
        XCTAssertEqual(event.activityType, "背部二头")
        XCTAssertEqual(event.energyKilocalories ?? -1, 380, accuracy: 0.1)
        XCTAssertEqual(event.averageHeartRate ?? -1, 132, accuracy: 0.1)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.toSnapshot().workouts.first?.activityName, "背部二头")
    }

    func testXunjiImportDoesNotMergeIntoAppleRunningWorkout() throws {
        let store = try makeStore()
        let start = makeDate(hour: 19)
        let end = start.addingTimeInterval(60 * 60)
        let healthKitID = UUID()
        store.context.insert(WorkoutEventRecord(
            id: healthKitID,
            source: "healthKit",
            startedAt: start,
            endedAt: end,
            activityType: "Running",
            title: "Running",
            energyKilocalories: 520,
            averageHeartRate: 152,
            linkedHealthKitWorkoutId: healthKitID
        ))
        try store.context.save()

        let datestr = "2026-04-02"
        let json = """
        {
          "success": true,
          "res": {
            "trains": [{
              "datestr": "\(datestr)",
              "localid": 678901,
              "title": "胸部训练",
              "start": \(Int64(start.addingTimeInterval(60).timeIntervalSince1970 * 1000)),
              "end": \(Int64(end.addingTimeInterval(-60).timeIntervalSince1970 * 1000)),
              "rpe": 8,
              "movements": [{
                "name": "杠铃卧推",
                "sets": [
                  { "done": true, "weight": "80", "unit": "kg", "reps": "8" }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

        _ = try XunjiTrainingImportService().importResponseData(json, datestr: datestr, modelContext: store.context)

        let events = try fetchEvents(store.context)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.contains { $0.linkedHealthKitWorkoutId == healthKitID && $0.linkedStrengthWorkoutId == nil })
        XCTAssertTrue(events.contains { $0.source == "xunji" && $0.linkedStrengthWorkoutId != nil && $0.linkedHealthKitWorkoutId == nil })
    }

    func testXunjiImportDoesNotMergeWhenStartIsCloseButOverlapIsWeak() throws {
        let store = try makeStore()
        let appleStart = makeDate(hour: 19)
        let appleEnd = appleStart.addingTimeInterval(20 * 60)
        let xunjiStart = appleStart.addingTimeInterval(15 * 60)
        let xunjiEnd = xunjiStart.addingTimeInterval(60 * 60)
        let healthKitID = UUID()
        store.context.insert(WorkoutEventRecord(
            id: healthKitID,
            source: "healthKit",
            startedAt: appleStart,
            endedAt: appleEnd,
            activityType: "Traditional Strength Training",
            title: "Traditional Strength Training",
            energyKilocalories: 120,
            averageHeartRate: 110,
            linkedHealthKitWorkoutId: healthKitID
        ))
        try store.context.save()

        let datestr = "2026-04-02"
        let json = """
        {
          "success": true,
          "res": {
            "trains": [{
              "datestr": "\(datestr)",
              "localid": 789012,
              "title": "腿部训练",
              "start": \(Int64(xunjiStart.timeIntervalSince1970 * 1000)),
              "end": \(Int64(xunjiEnd.timeIntervalSince1970 * 1000)),
              "rpe": 8,
              "movements": [{
                "name": "杠铃深蹲",
                "sets": [
                  { "done": true, "weight": "100", "unit": "kg", "reps": "5" }
                ]
              }]
            }]
          }
        }
        """.data(using: .utf8)!

        _ = try XunjiTrainingImportService().importResponseData(json, datestr: datestr, modelContext: store.context)

        let events = try fetchEvents(store.context)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.contains { $0.linkedHealthKitWorkoutId == healthKitID && $0.linkedStrengthWorkoutId == nil })
        XCTAssertTrue(events.contains { $0.source == "xunji" && $0.title == "腿部训练" })
    }

    func testWorkoutSaveUpdatesDailySummary() throws {
        let store = try makeStore()
        let start = makeDate(hour: 16)
        let workout = makeStrengthWorkout(start: start, duration: 50)
        store.context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(
            from: workout,
            modelContext: store.context,
            sessionRPE: 6
        )

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(summary.workoutCount, 1)
        XCTAssertEqual(summary.workoutDuration ?? -1, 50, accuracy: 0.1)
        XCTAssertEqual(summary.workoutLoad ?? -1, 90, accuracy: 0.1)
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

    func testAggregateDayRemovesPreviousWorkoutLoadFromPollutedActivityLoad() throws {
        let store = try makeStore()
        let start = makeDate(hour: 18)
        let workout = makeStrengthWorkout(start: start, duration: 50)
        store.context.insert(workout)

        try WorkoutAggregationService.shared.upsertWorkoutEvent(from: workout, modelContext: store.context, sessionRPE: 6)
        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        summary.activityLoad = 110
        summary.workoutLoad = 90
        summary.dailyLoad = 110

        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let refreshed = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        XCTAssertEqual(refreshed.workoutLoad ?? -1, 90, accuracy: 0.1)
        XCTAssertEqual(refreshed.activityLoad ?? -1, 20, accuracy: 0.1)
        XCTAssertEqual(refreshed.dailyLoad ?? -1, 110, accuracy: 0.1)
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
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [healthKitWorkout],
            on: day,
            modelContext: store.context
        )
        try WorkoutAggregationService.shared.aggregateDay(date: day, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: day))
        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertTrue(summary.toSnapshot().workouts.contains { $0.source == "manual" && $0.activityName == "Stretching" })
    }

    func testPostWorkoutReviewArtifactPersistsFromWorkoutSummary() throws {
        let store = try makeStore()
        let start = makeDate(hour: 18)
        let previous = makeStrengthWorkout(start: start.addingTimeInterval(-7 * 86_400), title: "Prior Upper")
        let workout = makeStrengthWorkout(start: start, title: "Upper Strength")
        let analysis = TrainingAnalyticsService().summarizeWorkout(workout, history: [previous])

        let artifact = CoachArtifact.postWorkoutReview(
            workout: workout,
            summary: analysis,
            readinessDecision: "reduce",
            sourceContextHash: "ctx-workout"
        )
        let record = CoachArtifactRecord(artifact: artifact)
        store.context.insert(record)
        try store.context.save()

        let fetched = try XCTUnwrap(store.context.fetch(FetchDescriptor<CoachArtifactRecord>()).first)

        XCTAssertEqual(fetched.type, CoachArtifactType.postWorkoutReview.rawValue)
        XCTAssertEqual(fetched.artifact.status, .created)
        XCTAssertEqual(fetched.artifact.sourceContextHash, "ctx-workout")
        XCTAssertTrue(fetched.artifact.summary.contains("Upper Strength"))
        XCTAssertTrue(fetched.artifact.actions.contains { $0.type == "open_training_summary" })
        XCTAssertTrue(fetched.artifact.actions.contains { $0.type == "start_check_in" && $0.payload["workout_id"] == workout.id.uuidString })
        XCTAssertTrue(fetched.artifact.actions.contains { $0.type == "open_recovery_detail" && $0.payload["workout_id"] == workout.id.uuidString })
    }
}

private enum TestCommitError: Error {
    case injected(WorkoutSaveCoordinator.Stage)
}
