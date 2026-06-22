import XCTest
import SwiftData
@testable import Vela

@MainActor
private final class SyncExecutionCounter {
    var value = 0
}

final class PersistenceFoundationTests: XCTestCase {
    @MainActor
    func testDemoDataSeedRequiresExplicitLaunchArgument() {
        XCTAssertFalse(DailySummaryUseCase.isDemoDataSeedingEnabled(arguments: []))
        XCTAssertFalse(DailySummaryUseCase.isDemoDataSeedingEnabled(arguments: ["-velaInitialTab", "0"]))
        XCTAssertTrue(DailySummaryUseCase.isDemoDataSeedingEnabled(arguments: ["-velaSeedDemoData"]))
    }

    func testActiveStatusDefaultsToActiveWhenNoValueExists() {
        let suiteName = "ActiveStatusDefaults-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            ActiveStatusSettings.resolveCurrentStatus(defaults: defaults),
            "active"
        )
    }

    func testExpiredActiveStatusResetsStoredValueToActive() {
        let suiteName = "ActiveStatusExpiry-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        defaults.set("resting", forKey: ActiveStatusSettings.statusKey)
        defaults.set(now.addingTimeInterval(-1), forKey: ActiveStatusSettings.expiresAtKey)

        let resolved = ActiveStatusSettings.resolveCurrentStatus(
            now: now,
            defaults: defaults
        )

        XCTAssertEqual(resolved, "active")
        XCTAssertEqual(defaults.string(forKey: ActiveStatusSettings.statusKey), "active")
        XCTAssertNil(defaults.object(forKey: ActiveStatusSettings.expiresAtKey))
        XCTAssertTrue(ActiveStatusSettings.journalFlags(now: now, defaults: defaults).isEmpty)
    }

    func testModelContainerSchemaCreatedSuccessfully() {
        let schema = VelaModelContainer.schema
        XCTAssertNotNil(schema)
    }

    func testStoreRecoveryBackupCopiesSidecarsWithoutDeletingOriginals() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VelaRecoveryTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = root.appending(path: "Vela.store")
        let recoveryRoot = root.appending(path: "Recovery", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("store".utf8).write(to: store)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: store.path + "-wal"))
        try Data("shm".utf8).write(to: URL(fileURLWithPath: store.path + "-shm"))

        let backup = try XCTUnwrap(VelaModelContainer.backupStoreFiles(
            at: store,
            recoveryRoot: recoveryRoot,
            timestamp: Date(timeIntervalSince1970: 1_781_004_800)
        ))

        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path + "-wal"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.path + "-shm"))
        XCTAssertEqual(try Data(contentsOf: backup.appending(path: "Vela.store")), Data("store".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appending(path: "Vela.store-wal")), Data("wal".utf8))
        XCTAssertEqual(try Data(contentsOf: backup.appending(path: "Vela.store-shm")), Data("shm".utf8))
    }

    func testPrivacyDataInventoryModelExplainsExportAndDeleteScopes() {
        let model = PrivacyDataInventoryModel.build(counts: [
            "daily_summaries": 2,
            "strength_workouts": 1,
            "journals": 3,
            "coach_sessions": 4,
            "agent_runs": 5
        ])

        XCTAssertEqual(model.totalExportedItems, 6)
        XCTAssertTrue(model.exportCategories.contains { $0.id == "daily_summaries" && $0.count == 2 })
        XCTAssertTrue(model.exportCategories.contains { $0.id == "journals" && $0.count == 3 })
        XCTAssertTrue(model.deleteGroups.contains { $0.id == "ai_history" && $0.isDestructive })
        XCTAssertTrue(model.localOnlyNotice.contains("Apple Health"))
    }

    @MainActor
    func testPrivacyDataInventoryBuilderCountsSwiftDataRecords() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(DailyHealthSummaryRecord(
            dayIdentifier: "2026-06-17",
            date: Date(timeIntervalSince1970: 1_781_654_400)
        ))
        context.insert(JournalEntryRecord(tags: ["sleep"], note: "睡得不错"))
        context.insert(CoachSessionRecord(title: "恢复建议"))
        try context.save()

        let model = PrivacyDataInventoryBuilder.build(modelContext: context)

        XCTAssertEqual(model.category(id: "daily_summaries")?.count, 1)
        XCTAssertEqual(model.category(id: "journals")?.count, 1)
        XCTAssertEqual(model.category(id: "coach_sessions")?.count, 1)
    }

    @MainActor
    func testOnboardingStatePersistsBodyModelProfiles() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let state = OnboardingState(
            currentStep: "first_brief",
            isCompleted: true,
            goalProfile: UserGoalProfile(primaryGoal: "strength", experienceLevel: "intermediate"),
            trainingPreference: TrainingPreferenceProfile(trainingStyle: "strength", weeklyTrainingDays: 4, sessionDurationMinutes: 60),
            equipmentProfile: EquipmentProfile(equipment: ["barbell", "dumbbell"], scheduleNotes: "Mon/Wed/Fri/Sun"),
            coachingPreference: CoachingPreference(style: "direct", explanationDepth: "evidence_first"),
            initialBodySnapshot: InitialBodySnapshot(
                sleepScore: 72,
                recoveryScore: 68,
                strainScore: 42,
                dataConfidence: .medium,
                missingData: ["HRV baseline"]
            ),
            missingData: ["HRV baseline"]
        )
        context.insert(state)
        try context.save()

        let fetched = try XCTUnwrap(context.fetch(FetchDescriptor<OnboardingState>()).first)

        XCTAssertTrue(fetched.isCompleted)
        XCTAssertEqual(fetched.goalProfile.primaryGoal, "strength")
        XCTAssertEqual(fetched.trainingPreference.weeklyTrainingDays, 4)
        XCTAssertEqual(fetched.equipmentProfile.equipment, ["barbell", "dumbbell"])
        XCTAssertEqual(fetched.initialBodySnapshot.dataConfidence, .medium)
        XCTAssertEqual(fetched.missingData, ["HRV baseline"])
    }

    func testBehaviorSignalExtractorKeepsFoodJournalLowFriction() {
        let signals = BehaviorSignalExtractor.extract(
            from: "晚上火锅，喝了两杯啤酒，吃撑了，睡前还喝了咖啡",
            createdAt: Date(timeIntervalSince1970: 1_776_000_000)
        )

        XCTAssertTrue(signals.contains { $0.tag == .alcohol && $0.intensity == .medium })
        XCTAssertTrue(signals.contains { $0.tag == .caffeine && $0.timing == .preSleep })
        XCTAssertTrue(signals.contains { $0.tag == .highFat })
        XCTAssertTrue(signals.contains { $0.tag == .highSalt })
        XCTAssertTrue(signals.contains { $0.tag == .overeating && $0.intensity == .high })
        XCTAssertTrue(signals.allSatisfy { $0.confidence == .aiInferred })
    }

    func testPersonalBaselinesRoundTripThroughWikiMarkdown() throws {
        let url = WikiFileService.localURL(for: "baselines.md")
        let original = try? String(contentsOf: url, encoding: .utf8)
        defer {
            if let original {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? original.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let baselines = PersonalBaselines(
            hrvBaselineMean: 52,
            hrvBaselineSD: 7,
            rhrBaselineMean: 58,
            rhrBaselineSD: 4,
            sleepHoursBaseline: 7.4,
            sleepEfficiencyBaseline: 0.91,
            deepSleepPercentBaseline: 0.18,
            remSleepPercentBaseline: 0.23,
            strainBaselineMean: 42,
            stepsBaseline: 8_500,
            activeCaloriesBaseline: 520,
            calculatedAt: Date(timeIntervalSince1970: 1_776_000_000),
            daysOfData: 28,
            recoveryBaselineMean: 72,
            recoveryBaselineSD: 9,
            sleepScoreBaselineMean: 78,
            sleepScoreBaselineSD: 8
        )

        PersonalBaselineEngine.saveBaselinesToWiki(baselines)
        let loaded = try XCTUnwrap(PersonalBaselineEngine.loadBaselinesFromWiki()?.baselines)

        XCTAssertEqual(loaded.daysOfData, 28)
        XCTAssertEqual(loaded.hrvBaselineMean ?? -1, 52, accuracy: 0.1)
        XCTAssertEqual(loaded.hrvBaselineSD ?? -1, 7, accuracy: 0.1)
        XCTAssertEqual(loaded.rhrBaselineMean ?? -1, 58, accuracy: 0.1)
        XCTAssertEqual(loaded.rhrBaselineSD ?? -1, 4, accuracy: 0.1)
        XCTAssertEqual(loaded.sleepHoursBaseline ?? -1, 7.4, accuracy: 0.1)
        XCTAssertEqual(loaded.sleepEfficiencyBaseline ?? -1, 0.91, accuracy: 0.01)
        XCTAssertEqual(loaded.deepSleepPercentBaseline ?? -1, 0.18, accuracy: 0.01)
        XCTAssertEqual(loaded.remSleepPercentBaseline ?? -1, 0.23, accuracy: 0.01)
        XCTAssertEqual(loaded.strainBaselineMean ?? -1, 42, accuracy: 0.1)
        XCTAssertEqual(loaded.stepsBaseline ?? -1, 8_500, accuracy: 0.1)
        XCTAssertEqual(loaded.activeCaloriesBaseline ?? -1, 520, accuracy: 0.1)
    }

    func testTrainingTemplateRepParserUsesFirstRepTargetNotSetCount() {
        XCTAssertEqual(StrengthWorkoutTemplateParser.reps(from: "3x8-12"), 8)
        XCTAssertEqual(StrengthWorkoutTemplateParser.reps(from: "4 x 6"), 6)
        XCTAssertEqual(StrengthWorkoutTemplateParser.reps(from: "8-12"), 8)
        XCTAssertEqual(StrengthWorkoutTemplateParser.reps(from: "AMRAP"), 10)
    }

    func testStrengthWorkoutSaveValidatorRejectsWorkoutWithOnlyUncompletedSetsWhenIgnoring() {
        let exercises = [
            StrengthExerciseLog(
                name: "杠铃深蹲",
                equipment: "barbell",
                primaryMuscleGroup: "legs",
                sets: [
                    StrengthSetLog(repetitions: 8, weightKilograms: 100, isWarmup: false, rpe: nil, rir: nil, isCompleted: false, completedAt: nil)
                ]
            )
        ]

        let result = StrengthWorkoutSaveValidator.exercisesToSave(
            from: exercises,
            ignoringUncompletedSets: true
        )

        XCTAssertThrowsError(try result.get()) { error in
            XCTAssertEqual(error as? StrengthWorkoutSaveValidator.ValidationError, .emptyCompletedSets)
        }
    }

    @MainActor
    func testVela4RecordsRoundTripWithoutJournalPollution() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let interaction = CoachInteractionRecord(
            userText: "今天适合练腿吗？",
            assistantText: "建议降低容量。",
            focus: "training",
            contextHash: "ctx-1"
        )
        let plan = DailyOperatingPlanRecord(
            dayIdentifier: "2026-06-09",
            bodyStateHash: "body-1",
            primaryActionType: "reduce",
            title: "下调训练容量",
            payloadJSON: #"{"volume_multiplier":0.75}"#,
            reasonsJSON: #"["HRV below baseline"]"#,
            confidence: 0.78,
            status: "proposed"
        )
        let artifact = AgentArtifactRecord(
            type: "training_adjustment",
            title: "今日训练调整",
            payloadJSON: #"{"decision":"reduce"}"#,
            sourceContextHash: "ctx-1",
            confidence: 0.78,
            source: "TrainingDecisionKernel"
        )
        context.insert(interaction)
        context.insert(plan)
        context.insert(artifact)
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<CoachInteractionRecord>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalEntryRecord>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<DailyOperatingPlanRecord>()).first?.confidence, 0.78)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AgentArtifactRecord>()).first?.source, "TrainingDecisionKernel")
    }

    @MainActor
    func testDailyOperatingPlanUpsertIsIdempotentAndCreatesArtifact() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_781_004_800)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .empty(date: now),
            activeStatus: "active",
            generatedAt: now
        ))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        try DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: decision,
            modelContext: context
        )
        try DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: decision,
            modelContext: context
        )

        let plans = try context.fetch(FetchDescriptor<DailyOperatingPlanRecord>())
        let artifacts = try context.fetch(FetchDescriptor<AgentArtifactRecord>())
            .filter { $0.type == "daily_plan" }
        XCTAssertEqual(plans.count, 1)
        XCTAssertEqual(artifacts.count, 1)
        XCTAssertEqual(plans.first?.bodyStateHash, bodyState.hash)
        XCTAssertTrue(plans.first?.safetyNotice?.contains("不构成医疗诊断") == true)
    }

    @MainActor
    func testCanonicalTrainingDecisionMatchesDashboardPersistenceAndAIContext() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_781_004_800)
        var dashboard = DashboardSummary.preview(date: now)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            activeStatus: "resting",
            generatedAt: now
        ))
        let canonical = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))
        dashboard.trainingDecision = TrainingDecision.compatibilityView(
            of: canonical,
            bodyState: bodyState
        )

        try DailyOperatingPlanCoordinator.upsert(
            bodyState: bodyState,
            decision: canonical,
            modelContext: context
        )

        let record = try XCTUnwrap(context.fetch(FetchDescriptor<DailyOperatingPlanRecord>()).first)
        let payloadData = try XCTUnwrap(record.payloadJSON.data(using: .utf8))
        let payload = try JSONDecoder().decode(DailyOperatingPlanPayload.self, from: payloadData)
        let reasonsData = try XCTUnwrap(record.reasonsJSON.data(using: .utf8))
        let reasons = try JSONDecoder().decode([String].self, from: reasonsData)
        let aiContext = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: now
        )
        let adaptation = try XCTUnwrap(aiContext.envelope.strengthTraining?["training_adaptation"])

        XCTAssertEqual(record.bodyStateHash, bodyState.hash)
        XCTAssertEqual(record.primaryActionType, canonical.decision.rawValue)
        XCTAssertEqual(payload.decision, canonical.decision)
        XCTAssertEqual(payload.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(payload.intensityCap, canonical.intensityCap)
        XCTAssertEqual(payload.summary, canonical.userFacingSummary)
        XCTAssertEqual(reasons, canonical.reasons)
        XCTAssertEqual(record.confidence, canonical.confidence)
        XCTAssertEqual(dashboard.trainingDecision.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(dashboard.trainingDecision.maxIntensity, "RPE \(canonical.intensityCap)")
        XCTAssertTrue(adaptation.contains("\(Int((canonical.volumeMultiplier * 100).rounded()))% volume"))
        XCTAssertTrue(adaptation.contains("RPE \(canonical.intensityCap) cap"))
    }

    func testTrainingDayDecodingToleratesLegacyMissingFields() throws {
        let json = """
        {
          "weekNumber": 1,
          "dayNumber": 2,
          "title": "Legacy Day"
        }
        """.data(using: .utf8)!

        let day = try JSONDecoder().decode(TrainingDay.self, from: json)

        XCTAssertEqual(day.weekNumber, 1)
        XCTAssertEqual(day.dayNumber, 2)
        XCTAssertEqual(day.title, "Legacy Day")
        XCTAssertEqual(day.description, "")
        XCTAssertEqual(day.focus, "strength")
        XCTAssertEqual(day.durationMinutes, 0)
        XCTAssertEqual(day.intensity, "moderate")
    }

    func testTrainingScheduleResolverUsesPlanWeekAndDeterministicFallbacks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 12,
            day: 28,
            hour: 9
        )))
        let week1Monday = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Week 1 Push",
            description: "",
            focus: "strength",
            durationMinutes: 60,
            intensity: "moderate",
            isCompleted: true
        )
        let week1Wednesday = TrainingDay(
            weekNumber: 1,
            dayNumber: 3,
            title: "Week 1 Pull",
            description: "",
            focus: "strength",
            durationMinutes: 60,
            intensity: "moderate"
        )
        let week2Wednesday = TrainingDay(
            weekNumber: 2,
            dayNumber: 3,
            title: "Week 2 Legs",
            description: "",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let restDay = TrainingDay(
            weekNumber: 2,
            dayNumber: 4,
            title: "Rest",
            description: "",
            focus: "rest",
            durationMinutes: 0,
            intensity: "low"
        )
        let plan = TrainingPlanRecord(
            title: "Cross-year plan",
            goalDescription: "",
            startDate: start,
            weeksCount: 2,
            days: [week1Monday, week1Wednesday, week2Wednesday, restDay]
        )

        let beforeStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: start))
        XCTAssertNil(TrainingScheduleResolver.resolve(plan: plan, on: beforeStart, events: [], calendar: calendar))

        let week1WednesdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan, on: week1WednesdayDate, events: [], calendar: calendar)?.id,
            week1Wednesday.id
        )

        let week2WednesdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 9, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan, on: week2WednesdayDate, events: [], calendar: calendar)?.id,
            week2Wednesday.id
        )

        let week2ThursdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 10, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan, on: week2ThursdayDate, events: [], calendar: calendar)?.id,
            restDay.id
        )

        let skippedDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan, on: skippedDate, events: [], calendar: calendar)?.id,
            week1Wednesday.id
        )
    }

    func testTrainingScheduleResolverTreatsLinkedEventAsCompleted() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 1)))
        let first = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Push",
            description: "",
            focus: "strength",
            durationMinutes: 50,
            intensity: "moderate"
        )
        let next = TrainingDay(
            weekNumber: 1,
            dayNumber: 2,
            title: "Pull",
            description: "",
            focus: "strength",
            durationMinutes: 50,
            intensity: "moderate"
        )
        let plan = TrainingPlanRecord(
            title: "Plan",
            goalDescription: "",
            startDate: start,
            weeksCount: 1,
            days: [first, next]
        )
        let event = WorkoutEventRecord(
            source: "strengthLog",
            startedAt: start,
            endedAt: start.addingTimeInterval(3_000),
            activityType: "strength",
            linkedTrainingPlanDayId: first.id,
            calendar: calendar
        )

        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan, on: start, events: [event], calendar: calendar)?.id,
            next.id
        )
    }

    func testTrainingSessionDraftBuilderAppliesDecisionWithoutReplacingPlanTargets() throws {
        let exercises = [
            WorkoutTemplateExercise(
                name: "Bench Press",
                targetSets: 4,
                targetReps: "8-10",
                targetRPE: 8,
                restSeconds: 120,
                notes: nil
            )
        ]
        let exerciseJSON = try XCTUnwrap(String(
            data: JSONEncoder().encode(exercises),
            encoding: .utf8
        ))
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Push",
            description: "Chest and triceps",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high",
            plannedExercisesJSON: exerciseJSON
        )
        let decision = DailyTrainingDecision(
            decision: .reduce,
            targetSessionTitle: "Push",
            volumeMultiplier: 0.75,
            intensityCap: 7,
            reasons: ["Sleep below baseline"],
            userFacingSummary: "Reduce volume.",
            confidence: 0.8,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "General guidance only."
        )
        let history = StrengthWorkoutRecord(
            title: "Previous Push",
            startedAt: Date(timeIntervalSince1970: 1_780_000_000),
            durationMinutes: 55,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: "chest",
                    sets: [
                        StrengthSetLog(repetitions: 5, weightKilograms: 80, rpe: 9, isCompleted: true)
                    ]
                )
            ]
        )

        let draft = TrainingSessionDraftBuilder().build(
            day: day,
            decision: decision,
            history: [history],
            scheduledAt: Date(timeIntervalSince1970: 1_781_000_000)
        )

        XCTAssertEqual(draft.action, .strength)
        XCTAssertEqual(draft.title, "Push")
        XCTAssertEqual(draft.planDayId, day.id)
        XCTAssertEqual(draft.exercises.first?.sets.count, 3)
        XCTAssertEqual(draft.exercises.first?.sets.first?.repetitions, 8)
        XCTAssertEqual(draft.exercises.first?.sets.first?.weightKilograms, 80)
        XCTAssertEqual(draft.exercises.first?.sets.first?.rpe, 7)
    }

    @MainActor
    func testAppSyncCoordinatorDeduplicatesAndThrottlesPerSource() async {
        let coordinator = AppSyncCoordinator(minimumInterval: 60)
        let executionCount = SyncExecutionCounter()

        async let first: Void = coordinator.run(source: .healthKit) {
            executionCount.value += 1
            try? await Task.sleep(for: .milliseconds(30))
        }
        async let second: Void = coordinator.run(source: .healthKit) {
            executionCount.value += 1
        }
        _ = await (first, second)

        XCTAssertEqual(executionCount.value, 1)

        await coordinator.run(source: .healthKit) {
            executionCount.value += 1
        }
        XCTAssertEqual(executionCount.value, 1)

        await coordinator.run(source: .healthKit, force: true) {
            executionCount.value += 1
        }
        XCTAssertEqual(executionCount.value, 2)
    }

    func testExerciseLoadDefaultsDoNotInventExternalWeight() {
        XCTAssertEqual(
            ExerciseLoadDefaults.initialWeight(
                equipment: "bodyweight",
                exerciseName: "Pull Up",
                previousSets: []
            ),
            0
        )
        XCTAssertEqual(
            ExerciseLoadDefaults.initialWeight(
                equipment: "barbell",
                exerciseName: "Bench Press",
                previousSets: []
            ),
            0
        )
        XCTAssertEqual(
            ExerciseLoadDefaults.initialWeight(
                equipment: "dumbbell",
                exerciseName: "Row",
                previousSets: [StrengthSetLog(repetitions: 8, weightKilograms: 32, isCompleted: true)]
            ),
            32
        )
    }

    @MainActor
    func testRetentionPolicyPrunesOperationalDataAndPreservesActedCoachArtifacts() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-200 * 86_400)

        context.insert(AgentRunRecord(
            agentName: "old",
            startedAt: old,
            status: .success
        ))
        context.insert(AgentRunRecord(
            agentName: "recent",
            startedAt: now.addingTimeInterval(-5 * 86_400),
            status: .success
        ))
        context.insert(AgentArtifactRecord(
            type: "daily_plan",
            title: "old artifact",
            createdAt: old,
            payloadJSON: "{}",
            sourceContextHash: "old",
            confidence: 0.5,
            source: "test"
        ))
        var actedArtifact = CoachArtifactParser.fallback(
            from: "preserve",
            type: .postWorkoutReview,
            sourceContextHash: "acted"
        )
        actedArtifact.createdAt = old
        actedArtifact.status = .acted
        context.insert(CoachArtifactRecord(artifact: actedArtifact))
        var staleArtifact = CoachArtifactParser.fallback(
            from: "prune",
            type: .askCoachAnswer,
            sourceContextHash: "stale"
        )
        staleArtifact.createdAt = old
        context.insert(CoachArtifactRecord(artifact: staleArtifact))
        context.insert(XunjiDailyCacheRecord(
            datestr: "20200101",
            fetchedAt: old,
            includeFullData: false,
            responseData: Data()
        ))
        try context.save()

        let result = try RetentionPolicyService().prune(modelContext: context, now: now)

        XCTAssertEqual(result.agentRuns, 1)
        XCTAssertEqual(result.agentArtifacts, 1)
        XCTAssertEqual(result.coachArtifacts, 1)
        XCTAssertEqual(result.xunjiCaches, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<AgentRunRecord>()).map(\.agentName), ["recent"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<CoachArtifactRecord>()).map(\.status), ["acted"])
    }

    func testSleepHeartRateRangeUsesMostRecentSleepEpisode() {
        let day = Date(timeIntervalSince1970: 1_776_000_000)
        let early = SleepSummary(
            date: day,
            totalSleepMinutes: 90,
            bedtime: day.addingTimeInterval(1_000),
            wakeTime: day.addingTimeInterval(6_400),
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )
        let recent = SleepSummary(
            date: day,
            totalSleepMinutes: 420,
            bedtime: day.addingTimeInterval(20_000),
            wakeTime: day.addingTimeInterval(45_200),
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )

        let range = SleepHeartRateRangeResolver.range(for: [early, recent], fallback: DateRangeQuery(start: day, end: day.addingTimeInterval(86_400)))

        XCTAssertEqual(range.start, recent.bedtime)
        XCTAssertEqual(range.end, recent.wakeTime)
    }

    func testWorkoutHeartRateAveragerBucketsSamplesByWorkout() {
        let start = Date(timeIntervalSince1970: 1_776_000_000)
        let first = WorkoutSummary(start: start, end: start.addingTimeInterval(1_800), activityName: "Run")
        let second = WorkoutSummary(start: start.addingTimeInterval(3_600), end: start.addingTimeInterval(5_400), activityName: "Ride")
        let samples = [
            HeartRateSample(date: start.addingTimeInterval(60), bpm: 120),
            HeartRateSample(date: start.addingTimeInterval(600), bpm: 140),
            HeartRateSample(date: start.addingTimeInterval(3_900), bpm: 150),
            HeartRateSample(date: start.addingTimeInterval(7_200), bpm: 90)
        ]

        let averages = WorkoutHeartRateAverager.averageHeartRates(samples: samples, workouts: [first, second])

        XCTAssertEqual(averages[first.id] ?? -1, 130, accuracy: 0.1)
        XCTAssertEqual(averages[second.id] ?? -1, 150, accuracy: 0.1)
    }

    @MainActor
    func testBodyModelStateIsConservativeWhenEvidenceIsThin() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let onboarding = OnboardingState(
            isCompleted: true,
            goalProfile: UserGoalProfile(primaryGoal: "performance", experienceLevel: "intermediate"),
            trainingPreference: TrainingPreferenceProfile(trainingStyle: "strength", weeklyTrainingDays: 4, sessionDurationMinutes: 60),
            equipmentProfile: EquipmentProfile(equipment: ["gym", "barbell"]),
            initialBodySnapshot: InitialBodySnapshot(dataConfidence: .low, missingData: ["7-day baseline"])
        )
        context.insert(onboarding)
        context.insert(JournalEntryRecord(
            createdAt: Date(timeIntervalSince1970: 1_776_000_000),
            tags: ["behavior:alcohol", "behavior:late_meal", "intensity:medium"],
            note: "晚上聚餐喝酒"
        ))
        try context.save()

        let state = BodyModelBuilder().build(
            onboarding: onboarding,
            dailySummaries: [],
            journalEntries: try context.fetch(FetchDescriptor<JournalEntryRecord>()),
            strengthWorkouts: [],
            trainingResponses: [],
            asOf: Date(timeIntervalSince1970: 1_776_086_400)
        )

        XCTAssertEqual(state.maturity.overall, .seed)
        XCTAssertTrue(state.uncertainAreas.contains { $0.id == "baseline_history" })
        XCTAssertTrue(state.uncertainAreas.contains { $0.id == "behavior_pairs" })
        XCTAssertTrue(state.claims.allSatisfy { $0.confidence != .high })
    }
}
