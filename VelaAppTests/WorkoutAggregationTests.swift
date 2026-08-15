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

    @MainActor
    func testAggregateDayExcludesBlacklistedWorkouts() throws {
        // P1-1/P1-2 回归：被拉黑（删除）的训练不得从陈旧 workoutsData 复活，
        // aggregateDay 必须按黑名单过滤事件。
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: makeDate())
        let hkID = UUID()

        let event = WorkoutEventRecord(
            source: "healthKit",
            startedAt: day.addingTimeInterval(10 * 3600),
            endedAt: day.addingTimeInterval(11 * 3600),
            activityType: "Running",
            linkedHealthKitWorkoutId: hkID,
            calendar: calendar
        )
        context.insert(event)
        context.insert(DailyHealthSummaryRecord(
            dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar),
            date: day
        ))
        try context.save()

        // 陈旧缓存：workoutsData 里残留该训练（模拟删除前写出的旧 JSON）。
        let staleData = try JSONEncoder().encode([
            WorkoutSummary(
                id: hkID,
                start: day.addingTimeInterval(10 * 3600),
                end: day.addingTimeInterval(11 * 3600),
                activityName: "Running",
                source: "healthKit"
            )
        ])
        let record = try context.fetch(FetchDescriptor<DailyHealthSummaryRecord>()).first
        record?.workoutsData = staleData
        try context.save()

        // 用户删除 → 黑名单。
        WorkoutAggregationService.shared.blacklistWorkout(id: hkID.uuidString, modelContext: context)
        try context.save()

        try WorkoutAggregationService.shared.aggregateDay(date: day, modelContext: context, calendar: calendar)

        let updated = try context.fetch(FetchDescriptor<DailyHealthSummaryRecord>()).first
        XCTAssertEqual(updated?.workoutCount ?? -1, 0, "黑名单训练不得复活进 workoutCount")
        let stored = try XCTUnwrap(updated?.workoutsData)
        let storedWorkouts = try XCTUnwrap(try? JSONDecoder().decode([WorkoutSummary].self, from: stored))
        XCTAssertTrue(storedWorkouts.isEmpty, "黑名单训练不得残留进 workoutsData")
    }

    @MainActor
    func testPlanLinkingMatchesChineseMuscleTitles() throws {
        // P2-5 回归：中文计划标题（「胸 + 三头」）必须能与英文肌群键匹配。
        let linker = TrainingPlanLinkingService()
        let calendar = Calendar.current
        let start = makeDate()
        let day = TrainingDay(
            weekNumber: 1, dayNumber: 1,
            title: "胸 + 三头",
            description: "卧推",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high",
            plannedExercisesJSON: "[]"
        )
        let workout = makeStrengthWorkout(start: start)
        let event = WorkoutEventRecord(
            source: "strengthLog",
            startedAt: start,
            endedAt: start.addingTimeInterval(3600),
            activityType: "Strength Training",
            title: "胸 + 三头",
            linkedStrengthWorkoutId: workout.id,
            calendar: calendar
        )

        let score = linker.calculateMatchScore(
            event: event,
            planDay: day,
            strengthWorkout: workout,
            expectedDate: start,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(score, 65, "中文肌群标题应达到高置信打卡阈值，实际 \(score)")
    }

    @MainActor
    func testUpsertHealthKitWorkoutEventsCreatesAndRemovesMirrorEvents() throws {
        // 回归：前台路径依赖 upsertHealthKitWorkoutEvents 把当天 Apple 健康训练
        // 落成 WorkoutEventRecord；从 HealthKit 消失（健康 App 删除）后必须清理。
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: makeDate())
        let workoutID = UUID()

        let workout = WorkoutSummary(
            id: workoutID,
            start: day.addingTimeInterval(10 * 3600),
            end: day.addingTimeInterval(11 * 3600),
            activityName: "Running",
            energyKilocalories: 320,
            source: "healthKit"
        )
        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [workout], on: day, modelContext: context, calendar: calendar
        )

        let events = try fetchEvents(context)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.linkedHealthKitWorkoutId, workoutID)
        XCTAssertEqual(events.first?.source, "healthKit")
        XCTAssertEqual(events.first?.activityType, "Running")

        try WorkoutAggregationService.shared.upsertHealthKitWorkoutEvents(
            [], on: day, modelContext: context, calendar: calendar
        )
        let after = try fetchEvents(context)
        XCTAssertTrue(after.isEmpty, "从 HealthKit 消失的训练必须删除事件，不得残留在记录里")
    }

    @MainActor
    func testCaptureTrainingResponsesBackfillsNilDeltasForExistingRecords() throws {
        // T1 回归：手动记录路径（upsertTrainingResponseRecord）创建时次日增量留空，
        // capture 必须对已存在记录回填，内核「恢复响应欠佳」分支与校准器才拿得到输入。
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let workoutDay = calendar.date(byAdding: .day, value: -3, to: Date())!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: workoutDay)!

        let workout = makeStrengthWorkout(start: workoutDay)
        context.insert(workout)

        let record = TrainingResponseRecord(
            workoutId: workout.id,
            date: workoutDay,
            nextDayDate: nextDay,
            primaryMuscleGroups: ["chest"],
            totalEffectiveSets: 2,
            totalVolumeKg: 1280,
            sessionRPE: 7
        )
        context.insert(record)
        try context.save()

        let snapshots = [
            DailyHealthSnapshot(date: workoutDay, sleepScore: 80, recoveryScore: 82, hrvAverage: 58, restingHeartRate: 55),
            DailyHealthSnapshot(date: nextDay, sleepScore: 72, recoveryScore: 68, hrvAverage: 49, restingHeartRate: 61)
        ]

        let filled = try TrainingResponseInsightService().captureTrainingResponses(
            modelContext: context,
            snapshots: snapshots,
            workouts: [workout],
            calendar: calendar
        )
        XCTAssertEqual(filled, 1, "已存在记录的增量回填应计数一次")

        let updated = try XCTUnwrap(
            try context.fetch(FetchDescriptor<TrainingResponseRecord>()).first
        )
        XCTAssertEqual(updated.nextDayRecoveryDelta ?? 0, -14, accuracy: 0.01)
        XCTAssertEqual(updated.nextDayHRVDelta ?? 0, -9, accuracy: 0.01)
        XCTAssertEqual(updated.nextDayRHRDelta ?? 0, 6, accuracy: 0.01)
        XCTAssertEqual(updated.nextDaySleepScore ?? 0, 72, accuracy: 0.01)
    }

    @MainActor
    func testCaptureTrainingResponsesDoesNotOverwriteExistingDeltas() throws {
        // T1 边界：已有增量（如训记导入路径填充）不得被回填覆盖。
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        let workoutDay = calendar.date(byAdding: .day, value: -3, to: Date())!
        let nextDay = calendar.date(byAdding: .day, value: 1, to: workoutDay)!

        let workout = makeStrengthWorkout(start: workoutDay)
        context.insert(workout)

        let record = TrainingResponseRecord(
            workoutId: workout.id,
            date: workoutDay,
            nextDayDate: nextDay,
            primaryMuscleGroups: ["chest"],
            totalEffectiveSets: 2,
            totalVolumeKg: 1280,
            sessionRPE: 7,
            nextDayRecoveryDelta: -20
        )
        context.insert(record)
        try context.save()

        let snapshots = [
            DailyHealthSnapshot(date: workoutDay, sleepScore: nil, recoveryScore: 82),
            DailyHealthSnapshot(date: nextDay, sleepScore: nil, recoveryScore: 68)
        ]

        let filled = try TrainingResponseInsightService().captureTrainingResponses(
            modelContext: context,
            snapshots: snapshots,
            workouts: [workout],
            calendar: calendar
        )
        XCTAssertEqual(filled, 0, "无字段需要回填时不应计数")

        let updated = try XCTUnwrap(
            try context.fetch(FetchDescriptor<TrainingResponseRecord>()).first
        )
        XCTAssertEqual(updated.nextDayRecoveryDelta, -20, "已有增量不得被覆盖")
        XCTAssertNil(updated.nextDaySleepScore, "无快照值时保持 nil")
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
            workout.dto,
            history: [],
            exerciseLibrary: ExerciseLibraryService.defaultDefinitionsDTO()
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
            workout.dto,
            history: [],
            exerciseLibrary: ExerciseLibraryService.defaultDefinitionsDTO()
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
                workout.dto,
                history: [],
                exerciseLibrary: ExerciseLibraryService.defaultDefinitionsDTO()
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

    func testLinkActivePlanDayUsesMondayAnchoredScheduledDate() throws {
        let store = try makeStore()
        // 2026-04-01 是周三（04-02 是周四）。计划从周三开始，week1/day3 = 本周三。
        let planStart = makeDate(month: 4, day: 1, hour: 9)
        let day3 = TrainingDay(
            weekNumber: 1,
            dayNumber: 3,
            title: "Chest Day",
            description: "Focus on chest",
            focus: "strength",
            durationMinutes: 60,
            intensity: "moderate"
        )
        let plan = TrainingPlanRecord(
            title: "Wednesday Start Plan",
            goalDescription: "",
            startDate: planStart,
            weeksCount: 1,
            isActive: true,
            days: [day3]
        )
        store.context.insert(plan)
        let workout = makeStrengthWorkout(start: planStart)
        store.context.insert(workout)

        _ = try WorkoutAggregationService.shared.prepareWorkoutEvent(
            from: workout,
            modelContext: store.context,
            sessionRPE: 8
        )

        // 完成标记的期望日期必须与 TrainingScheduleResolver 同锚
        // （planStart 所在周的周一）：day3 = 周三。旧实现锚定 planStart 本身
        // （day3 → 周五），周三的训练永远完不成周三的计划日。
        XCTAssertTrue(plan.days.first?.isCompleted ?? false, "周三的计划日应被周三的训练完成")
        XCTAssertEqual(workout.planDayId, day3.id)
    }

    func testAggregateDayUsesConservativeLoadFactorWhenRPEMissing() throws {
        let store = try makeStore()
        let start = makeDate()
        let workout = makeStrengthWorkout(start: start)
        store.context.insert(workout)

        // sessionRPE 与 workout.sessionRPE 均缺失（用户跳过自评）
        try WorkoutAggregationService.shared.upsertWorkoutEvent(from: workout, modelContext: store.context, sessionRPE: nil)
        try WorkoutAggregationService.shared.aggregateDay(date: start, modelContext: store.context)

        let summary = try XCTUnwrap(fetchDailySummary(store.context, date: start))
        // 60min × 保守轻强度系数 3.0 × 0.3 = 54；
        // 旧实现默认中等强度 5 → 90，把“跳过自评”解释为“中等强度训练”
        XCTAssertEqual(summary.workoutLoad ?? -1, 54, accuracy: 0.1)
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

    func testDailySummaryApplyWritesEngineLoadAndAggregationFields() {
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

        // [10] 修复后：快照含 workouts 时聚合字段随快照落库（不再依赖
        // 「apply 之后必须紧跟 aggregateDay」的隐式契约）。
        XCTAssertEqual(existing.workoutCount, 1)
        XCTAssertEqual(existing.workoutTypes, "Running")
        XCTAssertEqual(existing.workoutDuration, 30)
        // 引擎写入的 dailyLoad/workoutLoad（TRIMP 域）必须随快照落库，
        // 不再被丢弃后由 aggregateDay 以另一套公式覆盖。
        XCTAssertEqual(existing.dailyLoad, 40)
        XCTAssertEqual(existing.workoutLoad, 30)
        let storedWorkouts = try? JSONDecoder().decode([WorkoutSummary].self, from: try XCTUnwrap(existing.workoutsData))
        XCTAssertEqual(storedWorkouts?.first?.activityName, "Running")
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
        let analysis = TrainingAnalyticsService().summarizeWorkout(workout.dto, history: [previous.dto])

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
