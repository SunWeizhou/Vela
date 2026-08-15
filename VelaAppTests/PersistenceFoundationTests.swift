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

    func testActiveStatusDoesNotPersistAMisleadingExpiry() {
        let suiteName = "ActiveStatusNoExpiry-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ActiveStatusSettings.update(
            status: "active",
            duration: "明天之前",
            defaults: defaults
        )

        XCTAssertEqual(defaults.string(forKey: ActiveStatusSettings.statusKey), "active")
        XCTAssertNil(defaults.string(forKey: ActiveStatusSettings.durationKey))
        XCTAssertNil(defaults.object(forKey: ActiveStatusSettings.expiresAtKey))
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

    @MainActor
    func testDailyScoreEvidenceRoundTripPreservesAuditableMetricSemantics() throws {
        let now = Date(timeIntervalSince1970: 1_785_446_400)
        func metric(_ domain: ScoredHealthDomain, name: String, value: Double) -> MetricResult {
            MetricResult(
                domain: domain,
                name: name,
                value: value,
                band: .normal,
                confidence: .high,
                components: ["raw": value - 4],
                componentWeights: ["raw": 0.75],
                reasons: ["Fixture reason"],
                missingInputs: ["optional_input"],
                dataWindow: DateInterval(start: now.addingTimeInterval(-3_600), end: now),
                source: .mixed,
                algorithmVersion: "\(domain.rawValue).fixture.v2",
                lastUpdated: now
            )
        }

        let envelope = DailyScoreEvidenceEnvelope(
            sleep: metric(.sleep, name: "Sleep Score", value: 81),
            recovery: metric(.recovery, name: "Recovery Score", value: 76),
            strain: metric(.strain, name: "Strain Score", value: 62),
            stress: metric(.physiologicalStress, name: "Stress", value: 35),
            energy: metric(.energy, name: "Energy", value: 70),
            persistedAt: now
        )
        let record = DailyHealthSummaryRecord(dayIdentifier: "2026-07-31", date: now)

        try record.apply(scoreEvidence: envelope)
        let decoded = try XCTUnwrap(record.decodedScoreEvidence())
        let dashboard = DailySummaryUseCase().makeDashboardFromRecord(record)

        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(dashboard.sleepScore, envelope.sleep)
        XCTAssertEqual(dashboard.recovery, envelope.recovery)
        XCTAssertEqual(dashboard.strain, envelope.strain)
        XCTAssertEqual(dashboard.stress, envelope.stress)
        XCTAssertEqual(dashboard.energy, envelope.energy)
        XCTAssertEqual(dashboard.recovery.componentWeights, ["raw": 0.75])
        XCTAssertEqual(dashboard.recovery.algorithmVersion, "recovery.fixture.v2")
    }

    @MainActor
    func testV1StoreMigratesToCurrentSchemaWithoutLosingDailyScores() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VelaV1Migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        let storeURL = root.appending(path: "Vela.store")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func createV1Store() throws {
            let sourceSchema = Schema(VelaSchemaV1.models)
            let sourceConfig = ModelConfiguration(schema: sourceSchema, url: storeURL)
            let sourceContainer = try ModelContainer(
                for: sourceSchema,
                configurations: [sourceConfig]
            )
            sourceContainer.mainContext.insert(VelaSchemaV1.DailyHealthSummaryRecord(
                dayIdentifier: "2026-07-30",
                date: Date(timeIntervalSince1970: 1_785_360_000),
                sleepScore: 83,
                recoveryScore: 74,
                configVersion: "legacy.fixture.v1"
            ))
            try sourceContainer.mainContext.save()
        }

        try createV1Store()
        let migratedContainer = try VelaModelContainer.make(at: storeURL)
        let records = try migratedContainer.mainContext.fetch(
            FetchDescriptor<DailyHealthSummaryRecord>()
        )
        let migrated = try XCTUnwrap(records.first)

        XCTAssertEqual(migrated.dayIdentifier, "2026-07-30")
        XCTAssertEqual(migrated.sleepScore, 83)
        XCTAssertEqual(migrated.recoveryScore, 74)
        XCTAssertEqual(migrated.configVersion, "legacy.fixture.v1")
        XCTAssertNil(migrated.scoreEvidenceData)
    }

    @MainActor
    func testFrozenV2StoreMigratesToV3WithoutLosingDailyScores() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VelaV3Migration-\(UUID().uuidString)", directoryHint: .isDirectory)
        let storeURL = root.appending(path: "Vela.store")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        func createV2Store() throws {
            let sourceSchema = Schema(VelaSchemaV2.models)
            let sourceConfig = ModelConfiguration(schema: sourceSchema, url: storeURL)
            let sourceContainer = try ModelContainer(
                for: sourceSchema,
                configurations: [sourceConfig]
            )
            sourceContainer.mainContext.insert(VelaSchemaV2.DailyHealthSummaryRecord(
                dayIdentifier: "2026-08-12",
                date: Date(timeIntervalSince1970: 1_786_464_000),
                sleepScore: 79,
                recoveryScore: 68,
                configVersion: "device.fixture.v2"
            ))
            try sourceContainer.mainContext.save()
        }

        try createV2Store()
        let migratedContainer = try VelaModelContainer.make(at: storeURL)
        let records = try migratedContainer.mainContext.fetch(
            FetchDescriptor<DailyHealthSummaryRecord>()
        )
        let migrated = try XCTUnwrap(records.first)

        XCTAssertEqual(migrated.dayIdentifier, "2026-08-12")
        XCTAssertEqual(migrated.sleepScore, 79)
        XCTAssertEqual(migrated.recoveryScore, 68)
        XCTAssertEqual(migrated.configVersion, "device.fixture.v2")
        XCTAssertNil(migrated.hrvRmssdMilliseconds)
    }

    @MainActor
    func testIntradayBucketsAggregateAndReconcileDeletedSourceSamples() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = Date(timeIntervalSince1970: 1_785_369_600)
        let points = [
            IntradaySignalPoint(date: start.addingTimeInterval(15), value: 60, sourceIdentifier: "watch"),
            IntradaySignalPoint(date: start.addingTimeInterval(45), value: 90, sourceIdentifier: "watch"),
            IntradaySignalPoint(date: start.addingTimeInterval(320), value: 72, sourceIdentifier: "watch")
        ]
        let buckets = IntradaySignalBucketizer.bucket(
            points: points,
            signal: .workoutHR,
            unit: "bpm",
            sourceIdentifier: "watch"
        )
        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets[0].average, 75)
        XCTAssertEqual(buckets[0].minimum, 60)
        XCTAssertEqual(buckets[0].maximum, 90)
        XCTAssertEqual(buckets[0].sampleCount, 2)

        let container = try VelaModelContainer.make(inMemory: true)
        let repository = HealthSnapshotRepository(
            modelContext: container.mainContext,
            calendar: calendar
        )
        try repository.reconcileIntradayBuckets(
            buckets,
            signal: .workoutHR,
            on: start
        )
        XCTAssertEqual(
            try repository.fetchIntradayBuckets(
                signal: .workoutHR,
                in: DateRangeQuery(start: start, end: start.addingTimeInterval(86_400))
            ).count,
            2
        )

        try repository.reconcileIntradayBuckets(
            [buckets[1]],
            signal: .workoutHR,
            on: start
        )
        let reconciled = try repository.fetchIntradayBuckets(
            signal: .workoutHR,
            in: DateRangeQuery(start: start, end: start.addingTimeInterval(86_400))
        )
        XCTAssertEqual(reconciled.count, 1)
        XCTAssertEqual(reconciled.first?.average, 72)
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
    func testAllLocalDataDeletionIncludesOperationalModelsAndFileBackedMemory() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(ActiveWorkoutDraftRecord(title: "未完成训练"))
        context.insert(ExerciseDefinitionRecord(
            name: "测试动作",
            primaryMuscleGroup: "chest",
            equipment: "none",
            movementPattern: "push"
        ))
        context.insert(TrainingPlanAdaptationRecord(
            planId: UUID(),
            dayId: UUID(),
            adjustment: .reduce,
            reason: "测试"
        ))
        context.insert(MemoryEventRecord(
            source: "test",
            targetFile: "profile.md",
            memoryType: .observation,
            operation: "append",
            content: "测试记忆",
            evidence: "测试证据",
            confidence: 0.8
        ))
        context.insert(DeletedWorkoutRecord(id: "deleted-workout"))
        try context.save()

        let wikiDirectory = FileManager.default.temporaryDirectory
            .appending(path: "VelaPrivacyDeletion-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: wikiDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: wikiDirectory) }
        try Data("private memory".utf8).write(to: wikiDirectory.appending(path: "profile.md"))

        _ = try PrivacyDataDeletionService.delete(
            scope: .allLocalVelaData,
            modelContext: context,
            wikiDirectoryURL: wikiDirectory
        )

        XCTAssertTrue(try context.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ExerciseDefinitionRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TrainingPlanAdaptationRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<MemoryEventRecord>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DeletedWorkoutRecord>()).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: wikiDirectory.path))
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
        let payload = try XCTUnwrap(record.operatingPlanPayload)
        let reasons = record.operatingPlanReasons
        let persistedDecision = try XCTUnwrap(record.trainingDecision)
        let aiContext = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: now
        )
        let adaptation = try XCTUnwrap(aiContext.envelope.strengthTraining?["training_adaptation"])
        let input = AgentFactInputLoader().load(modelContext: context, asOf: now)
        let persistedForAgent = input.canonicalTrainingDecision(for: bodyState)
        let canonicalFacts = AIContextBuilder().buildFacts(
            dashboard: .empty(date: now),
            journalEntries: input.journalContext,
            historicalReports: input.reportContext,
            userWiki: [:],
            bodyState: bodyState,
            trainingDecision: persistedForAgent,
            generatedAt: now
        ).snapshot

        XCTAssertEqual(record.bodyStateHash, bodyState.hash)
        XCTAssertEqual(record.primaryActionType, canonical.decision.rawValue)
        XCTAssertEqual(payload.decision, canonical.decision)
        XCTAssertEqual(payload.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(payload.intensityCap, canonical.intensityCap)
        XCTAssertEqual(payload.summary, canonical.userFacingSummary)
        XCTAssertEqual(reasons, canonical.reasons)
        XCTAssertEqual(persistedDecision, canonical)
        XCTAssertEqual(record.confidence, canonical.confidence)
        XCTAssertEqual(dashboard.trainingDecision.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(dashboard.trainingDecision.maxIntensity, "RPE \(canonical.intensityCap)")
        XCTAssertTrue(adaptation.contains("\(Int((canonical.volumeMultiplier * 100).rounded()))% volume"))
        XCTAssertTrue(adaptation.contains("RPE \(canonical.intensityCap) cap"))
        XCTAssertEqual(canonicalFacts.trainingDecision.readinessLevel, canonical.decision.rawValue)
        XCTAssertEqual(canonicalFacts.trainingDecision.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(canonicalFacts.trainingDecision.maxIntensity, "RPE \(canonical.intensityCap)")
        XCTAssertEqual(canonicalFacts.trainingDecision.readinessGuidance, canonical.userFacingSummary)
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
        XCTAssertNil(TrainingScheduleResolver.resolve(plan: plan.dto, on: beforeStart, events: [], calendar: calendar))

        let week1WednesdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan.dto, on: week1WednesdayDate, events: [], calendar: calendar)?.id,
            week1Wednesday.id
        )

        let week2WednesdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 9, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan.dto, on: week2WednesdayDate, events: [], calendar: calendar)?.id,
            week2Wednesday.id
        )

        let week2ThursdayDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 10, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan.dto, on: week2ThursdayDate, events: [], calendar: calendar)?.id,
            restDay.id
        )

        let skippedDate = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: start))
        XCTAssertEqual(
            TrainingScheduleResolver.resolve(plan: plan.dto, on: skippedDate, events: [], calendar: calendar)?.id,
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
            TrainingScheduleResolver.resolve(plan: plan.dto, on: start, events: [event.dto], calendar: calendar)?.id,
            next.id
        )
    }

    func testWristSnapshotRoundTripsWithoutLosingDecisionOrPlanContext() throws {
        let snapshot = WristSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_783_929_600),
            bodyStateTitle: "恢复稳定",
            summary: "今天适合按计划训练，并保留一组余力。",
            decision: "按计划训练",
            decisionConfidence: 0.86,
            recoveryScore: 82,
            sleepScore: 79,
            strainScore: 31,
            hrvMilliseconds: 48,
            restingHeartRate: 58,
            primaryAction: "开始上肢训练",
            planTitle: "四周力量计划",
            sessionTitle: "上肢推",
            sessionDetail: "45 分钟 · 中强度",
            planProgress: "3/12 已完成"
        )

        let encoded = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WristSnapshot.self, from: encoded)

        XCTAssertEqual(decoded, snapshot)
    }

    @MainActor
    func testDailyAdaptiveProposalIsIdempotentAndDoesNotMutatePlan() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 13,
            hour: 9
        )))
        let day = TrainingDay(
            weekNumber: 1,
            dayNumber: 1,
            title: "Heavy Lower",
            description: "Planned strength session",
            focus: "strength",
            durationMinutes: 60,
            intensity: "high"
        )
        let plan = TrainingPlanRecord(
            title: "Adaptive Plan",
            goalDescription: "Build strength safely",
            startDate: date,
            weeksCount: 1,
            days: [day]
        )
        var dashboard = DashboardSummary.preview(date: date)
        dashboard.recovery.value = 28
        dashboard.recovery.components["hrv_z_score"] = -1.5
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 28,
            restingHeartRate: 72,
            sleepHeartRate: 68,
            respiratoryRate: 17
        )
        dashboard.sleepScore.value = 45
        dashboard.sleepScore.components["sleep_efficiency"] = 0.68
        dashboard.strain.value = 88
        dashboard.stress.value = 82

        let first = try XCTUnwrap(AdaptiveTrainingManager().refreshDailyProposal(
            plan: plan,
            dashboard: dashboard,
            events: [],
            foodLogs: [],
            journalEntries: [],
            modelContext: context,
            date: date,
            calendar: calendar
        ))
        let second = try XCTUnwrap(AdaptiveTrainingManager().refreshDailyProposal(
            plan: plan,
            dashboard: dashboard,
            events: [],
            foodLogs: [],
            journalEntries: [],
            modelContext: context,
            date: date,
            calendar: calendar
        ))

        let stored = try context.fetch(FetchDescriptor<TrainingPlanAdaptationRecord>())
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.status, AdaptationStatus.proposed.rawValue)
        XCTAssertNotEqual(stored.first?.adjustment, AdaptiveTrainingEngine.Adjustment.keep.rawValue)
        XCTAssertEqual(plan.days.first?.title, "Heavy Lower")
        XCTAssertEqual(plan.days.first?.durationMinutes, 60)
    }

    func testTrainingPlanReviewCombinesExecutionAdherenceAndRecoveryCost() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 6)))
        let workoutIDs = [UUID(), UUID(), UUID()]
        let days = (0..<3).map { index in
            TrainingDay(
                weekNumber: 1,
                dayNumber: index + 1,
                title: "Session \(index + 1)",
                description: "",
                focus: "strength",
                durationMinutes: 45,
                intensity: "moderate",
                isCompleted: true,
                linkedWorkoutEventIds: [workoutIDs[index]],
                adherenceScore: 0.9
            )
        }
        let plan = TrainingPlanRecord(
            title: "Review Plan",
            goalDescription: "",
            startDate: start,
            weeksCount: 1,
            days: days
        )
        let responses = workoutIDs.enumerated().map { index, workoutID in
            TrainingResponseRecord(
                workoutId: workoutID,
                date: start.addingTimeInterval(Double(index) * 86_400),
                nextDayDate: start.addingTimeInterval(Double(index + 1) * 86_400),
                primaryMuscleGroups: ["legs"],
                totalEffectiveSets: 10,
                totalVolumeKg: 4_000,
                nextDayRecoveryDelta: -10
            )
        }

        let review = TrainingPlanReviewService.review(
            plan: plan.dto,
            events: [],
            responses: responses.map { $0.dto },
            through: start.addingTimeInterval(3 * 86_400),
            calendar: calendar
        )

        XCTAssertEqual(review.scheduledSessions, 3)
        XCTAssertEqual(review.completedSessions, 3)
        XCTAssertEqual(review.completionRate, 1, accuracy: 0.001)
        XCTAssertEqual(review.averageAdherence ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(review.measuredResponses, 3)
        XCTAssertEqual(review.averageRecoveryDelta ?? 0, -10, accuracy: 0.001)
        XCTAssertEqual(review.statusTitle, "近期恢复成本偏高")
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
        // T5：80kg×5 的 e1RM = 80*(1+5/30) = 93.33；按 8 次反推 = 73.68 kg（不再直接复制 80kg）。
        XCTAssertEqual(draft.exercises.first?.sets.first?.weightKilograms ?? 0, 73.68, accuracy: 0.01)
        XCTAssertEqual(draft.exercises.first?.sets.first?.rpe, 7)
    }

    func testTrainingSessionDraftBuilderPrescribesE1RMBasedProgressionWithCap() {
        // T5 回归：同次数处方保持原重量；低次数（大重量日）处方 e1RM 反推值且增幅封顶 +2.5%。
        func makeHistory(reps: Int, weight: Double) -> StrengthWorkoutRecord {
            StrengthWorkoutRecord(
                title: "Previous",
                startedAt: Date(timeIntervalSince1970: 1_780_000_000),
                durationMinutes: 55,
                exercises: [
                    StrengthExerciseLog(
                        name: "Bench Press",
                        equipment: "barbell",
                        primaryMuscleGroup: "chest",
                        sets: [
                            StrengthSetLog(repetitions: reps, weightKilograms: weight, rpe: 8, isCompleted: true)
                        ]
                    )
                ]
            )
        }

        func draftWeight(history: StrengthWorkoutRecord, targetReps: String) -> Double? {
            let exercises = [
                WorkoutTemplateExercise(
                    name: "Bench Press",
                    targetSets: 1,
                    targetReps: targetReps,
                    targetRPE: 8,
                    restSeconds: 120,
                    notes: nil
                )
            ]
            let exerciseJSON = (try? String(data: JSONEncoder().encode(exercises), encoding: .utf8)) ?? "[]"
            let day = TrainingDay(
                weekNumber: 1, dayNumber: 1, title: "Push", description: "",
                focus: "strength", durationMinutes: 60, intensity: "high",
                plannedExercisesJSON: exerciseJSON
            )
            let decision = DailyTrainingDecision(
                decision: .keep, targetSessionTitle: "Push",
                volumeMultiplier: 1.0, intensityCap: 8,
                reasons: [], userFacingSummary: "Keep.",
                confidence: 0.9, source: "test", safetyNotice: "General guidance only."
            )
            return TrainingSessionDraftBuilder().build(
                day: day, decision: decision, history: [history], scheduledAt: Date()
            ).exercises.first?.sets.first?.weightKilograms
        }

        // 同次数（5→5）：处方 ≈ 80（e1RM 反推回到原重量）。
        XCTAssertEqual(draftWeight(history: makeHistory(reps: 5, weight: 80), targetReps: "5") ?? 0, 80, accuracy: 0.01)
        // 低次数（5→3）：e1RM = 93.33 → 反推 84.85，但增幅封顶 82（80×1.025）。
        XCTAssertEqual(draftWeight(history: makeHistory(reps: 5, weight: 80), targetReps: "3") ?? 0, 82, accuracy: 0.01)
        // 高次数（5→10）：e1RM = 93.33 → 反推 70.0（减重，不做 +2.5% 封顶）。
        XCTAssertEqual(draftWeight(history: makeHistory(reps: 5, weight: 80), targetReps: "10") ?? 0, 70, accuracy: 0.01)
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

    @MainActor
    func testReportingSyncFailureRemainsRetryableAndExposesHealth() async {
        enum ExpectedFailure: Error { case failed }
        let coordinator = AppSyncCoordinator(minimumInterval: 60)
        let executionCount = SyncExecutionCounter()

        let failed = await coordinator.runReporting(source: .healthKit) {
            executionCount.value += 1
            throw ExpectedFailure.failed
        }
        let recovered = await coordinator.runReporting(source: .healthKit) {
            executionCount.value += 1
        }

        XCTAssertFalse(failed)
        XCTAssertTrue(recovered)
        XCTAssertEqual(executionCount.value, 2)
        XCTAssertTrue(coordinator.sourceStatuses[.healthKit]?.isHealthy == true)
        XCTAssertEqual(coordinator.sourceStatuses[.healthKit]?.consecutiveFailures, 0)
    }

    @MainActor
    func testDailyDecisionFeedbackBuildsLocalProductLoop() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date(timeIntervalSince1970: 1_783_900_800)
        let plan = DailyOperatingPlanRecord(
            dayIdentifier: "2026-07-13",
            bodyStateHash: "body-hash",
            generatedAt: now,
            primaryActionType: "strength",
            title: "完成中等强度力量训练",
            payloadJSON: "{}",
            reasonsJSON: "[]",
            confidence: 0.8
        )
        context.insert(plan)
        let service = DailyDecisionFeedbackService()

        let first = try service.recordViewed(
            modelContext: context,
            dayIdentifier: plan.dayIdentifier,
            plan: plan,
            bodyStateHash: plan.bodyStateHash,
            decisionType: plan.primaryActionType,
            decisionTitle: plan.title,
            now: now
        )
        _ = try service.recordViewed(
            modelContext: context,
            dayIdentifier: plan.dayIdentifier,
            plan: plan,
            bodyStateHash: plan.bodyStateHash,
            decisionType: plan.primaryActionType,
            decisionTitle: plan.title,
            now: now.addingTimeInterval(60)
        )
        _ = try service.recordActionStarted(
            modelContext: context,
            dayIdentifier: plan.dayIdentifier,
            plan: plan,
            bodyStateHash: plan.bodyStateHash,
            decisionType: plan.primaryActionType,
            decisionTitle: plan.title,
            destination: "training",
            now: now.addingTimeInterval(120)
        )
        try service.saveFeedback(
            modelContext: context,
            record: first,
            adoptionStatus: "modified",
            accuracyRating: "accurate",
            actualAction: "lighter",
            energyRating: 4,
            fatigueRating: 2,
            painRating: 1,
            satisfactionRating: 5,
            note: "Reduced one set",
            now: now.addingTimeInterval(180)
        )

        let records = try context.fetch(FetchDescriptor<DailyDecisionFeedbackRecord>())
        let events = try context.fetch(FetchDescriptor<VelaEventRecord>())
        let quality = service.qualitySnapshot(
            modelContext: context,
            periodDays: 28,
            now: now.addingTimeInterval(240)
        )

        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(first.isCompleted)
        XCTAssertEqual(events.filter { $0.eventType == VelaProductEventType.dailyDecisionViewed }.count, 1)
        XCTAssertEqual(quality.generatedPlans, 1)
        XCTAssertEqual(quality.startedActions, 1)
        XCTAssertEqual(quality.completedFeedback, 1)
        XCTAssertEqual(quality.adoptionRate, 1)
        XCTAssertEqual(quality.accuracyRate, 1)
    }

    @MainActor
    func testPersonalExperimentComparesBaselineAndExperimentWithoutClaimingEarlyEvidence() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_783_900_800))
        let template = try XCTUnwrap(PersonalExperimentService.templates.first)
        let experiment = try PersonalExperimentService().start(
            template: template,
            modelContext: context,
            now: start,
            calendar: calendar
        )

        var summaries: [DailyHealthSummaryRecord] = []
        for offset in -7..<5 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let record = DailyHealthSummaryRecord(
                dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar),
                date: date,
                sleepScore: offset < 0 ? 70 : 80
            )
            context.insert(record)
            summaries.append(record)
        }
        for offset in 0..<5 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            try PersonalExperimentService().checkIn(
                experiment: experiment,
                followed: offset != 2,
                modelContext: context,
                date: date,
                calendar: calendar
            )
        }
        let checkIns = try context.fetch(FetchDescriptor<ExperimentCheckInRecord>())
        let outcome = PersonalExperimentService().outcome(
            experiment: experiment,
            summaries: summaries,
            checkIns: checkIns,
            now: calendar.date(byAdding: .day, value: 5, to: start)!,
            calendar: calendar
        )

        XCTAssertTrue(outcome.hasEnoughEvidence)
        XCTAssertEqual(outcome.baselineSampleCount, 7)
        XCTAssertEqual(outcome.experimentSampleCount, 5)
        XCTAssertEqual(outcome.delta, 10)
        XCTAssertEqual(outcome.adherenceRate, 0.8, accuracy: 0.001)
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

    /// Regression guard for the on-device "Vela 意外退出" SIGTRAP in
    /// HealthSnapshotRepository.fetchSnapshots(days:endingAt:).
    ///
    /// Root cause (verified via crash-line symbolization, HealthSnapshotRepository.swift:103):
    /// SwiftData's #Predicate date comparison trapped when a stored row carried an
    /// anomalous `date`, hard-crashing the app on the workout-save →
    /// refreshPlan → loadDashboard(42d) path. The fix fetches without a date
    /// #Predicate and filters in memory, so a bad row can no longer crash the fetch.
    ///
    /// This test adds a record with a deliberately extreme/bad `date` (the class
    /// of row the predicate fetch used to trap on) and asserts the fetch still
    /// round-trips the good record without trapping.
    @MainActor
    func testFetchSnapshotsDoesNotTrapAfterSavingExternalStorageBlob() throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "VelaRepro-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storeURL = root.appending(path: "VelaRepro.store")

        let container = try VelaModelContainer.make(at: storeURL)
        let context = container.mainContext
        let calendar = Calendar.current
        // 锚定正午：00:00-04:00 时健康日边界会把「今天」归到前一日，使测试随墙钟波动。
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let todayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: now, calendar: calendar)

        // Good record carrying an external-storage workoutsData blob (emulating aggregateDay).
        let good = DailyHealthSummaryRecord(dayIdentifier: todayIdentifier, date: now)
        good.workoutsData = try JSONEncoder().encode(
            [WorkoutSummary(start: now, end: now.addingTimeInterval(3600), activityName: "测试力量")]
        )
        context.insert(good)

        // A bad row of the kind that previously made the date #Predicate trap.
        // date distant-future, still a valid non-optional Date but outside any
        // normal range — exercises the filter path with a real non-nil value.
        let bad = DailyHealthSummaryRecord(
            dayIdentifier: "distant-bad-row",
            date: Date.distantFuture
        )
        context.insert(bad)
        try context.save()

        // The crash path: fetch snapshots (round-trips good, excludes bad).
        let repository = HealthSnapshotRepository(modelContext: context, calendar: calendar)
        let snapshots = try repository.fetchSnapshots(days: 7, endingAt: now)

        XCTAssertEqual(snapshots.count, 1, "Only the good today-record should survive the range filter")
        XCTAssertEqual(snapshots.first?.workouts.count, 1, "workoutsData blob must decode through toSnapshot")
    }

    /// Regression guard for the concurrent-write race that produced the corrupted
    /// rows behind the fetchSnapshots crash: multiple in-flight async writers
    /// (foreground refresh, BGAppRefreshTask, Settings resync, workout save) all
    /// performed fetch-then-insert on the same @Attribute(.unique) dayIdentifier.
    ///
    /// PersistenceWriteGate.withSerializedWrite now makes each upsert atomic.
    /// This test hammers the same dayIdentifier with many concurrent writers and
    /// asserts exactly one row survives (no unique-key conflict, no duplicate).
    @MainActor
    func testConcurrentUpsertsSameDayDoNotDuplicateRows() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let snapshot = DailyHealthSnapshot(date: day)

        let writers = 24
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<writers {
                group.addTask { @MainActor in
                    let context = ModelContext(container)
                    let repo = SwiftDataDailyHealthSummaryRepository(modelContext: context)
                    do {
                        try repo.upsert(snapshot, calendar: calendar)
                        return true
                    } catch {
                        return false
                    }
                }
            }
            // Drain; each task either writes or fails (unique constraint).
            for await _ in group {}
        }

        let context = ModelContext(container)
        let all = try context.fetch(FetchDescriptor<DailyHealthSummaryRecord>())
        XCTAssertEqual(all.count, 1, "Concurrent upserts to the same dayIdentifier must produce exactly one row, not \(all.count)")
        XCTAssertEqual(all.first?.dayIdentifier, DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar))
    }

    /// 回归：力量训练响应存 StrengthWorkoutRecord.id，计划日关联事件 ID——
    /// review 必须合并两种 ID 空间，否则力量驱动的响应永远匹配不上。
    func testTrainingPlanReviewMatchesStrengthResponsesByLinkedID() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let dayID = UUID()
        let eventID = UUID()
        let strengthID = UUID()
        let day = TrainingDay(
            id: dayID,
            weekNumber: 1, dayNumber: 1, title: "S1", description: "",
            focus: "strength", durationMinutes: 45, intensity: "moderate",
            isCompleted: true, linkedWorkoutEventIds: [eventID], adherenceScore: 0.9
        )
        let plan = TrainingPlanDTO(
            id: UUID(), title: "P", goalDescription: "", startDate: monday,
            weeksCount: 1, isActive: true, days: [day]
        )
        let event = WorkoutEventDTO(
            id: eventID, startedAt: monday, durationMinutes: 45,
            linkedTrainingPlanDayId: dayID, linkedStrengthWorkoutId: strengthID
        )
        let response = TrainingResponseDTO(
            id: UUID(), date: monday, workoutId: strengthID,
            primaryMuscleGroups: ["legs"], totalEffectiveSets: 10, totalVolumeKg: 4000,
            sessionRPE: 8, nextDayRecoveryDelta: -10, nextDayHRVDelta: nil, nextDayRHRDelta: nil
        )
        let review = TrainingPlanReviewService.review(
            plan: plan, events: [event], responses: [response],
            through: monday.addingTimeInterval(6 * 3600), calendar: calendar
        )
        XCTAssertEqual(review.measuredResponses, 1, "力量训练响应必须匹配上，实际 \(review.measuredResponses)")
        XCTAssertEqual(review.scheduledSessions, 1, "计划开始于周一时只应排 1 场，实际 \(review.scheduledSessions)")
    }

    /// 回归：周中建计划时，起始周早于计划日的「幽灵日」不得遮蔽真正错过的训练。
    func testTrainingScheduleResolverSkipsGhostDaysBeforePlanStart() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let wednesday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 12)))
        let thursday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 13)))
        let ghostMonday = TrainingDay(
            weekNumber: 1, dayNumber: 1, title: "Mon", description: "",
            focus: "strength", durationMinutes: 45, intensity: "moderate", isCompleted: false
        )
        let realWednesday = TrainingDay(
            weekNumber: 1, dayNumber: 3, title: "Wed", description: "",
            focus: "strength", durationMinutes: 45, intensity: "moderate", isCompleted: false
        )
        let plan = TrainingPlanDTO(
            id: UUID(), title: "P", goalDescription: "", startDate: wednesday,
            weeksCount: 1, isActive: true, days: [ghostMonday, realWednesday]
        )
        let resolved = TrainingScheduleResolver.resolve(
            plan: plan, on: thursday, events: [], calendar: calendar
        )
        XCTAssertEqual(resolved?.dayNumber, 3, "周四应回落到周三（真实错过日），而非周一幽灵日：实际 dayNumber=\(resolved?.dayNumber ?? -1)")

        let review = TrainingPlanReviewService.review(
            plan: plan, events: [], responses: [],
            through: wednesday.addingTimeInterval(6 * 3600), calendar: calendar
        )
        XCTAssertEqual(review.scheduledSessions, 1, "幽灵日不得计入 scheduled，实际 \(review.scheduledSessions)")
    }

    /// 回归：apply(snapshot:) 必须保留引擎写入的 dailyLoad/workoutLoad（TRIMP 域），
    /// 否则 aggregateDay 会用 session-RPE 域覆盖，历史与当日量纲混用。
    @MainActor
    func testApplySnapshotPreservesEngineDailyLoad() {
        var snapshot = DailyHealthSnapshot(date: Date())
        snapshot.dailyLoad = 103.5
        snapshot.workoutLoad = 88.0
        snapshot.activityLoad = 15.5

        let record = DailyHealthSummaryRecord(dayIdentifier: "engine-load", date: Date())
        record.apply(snapshot: snapshot)

        XCTAssertEqual(record.dailyLoad, 103.5, "apply 必须保留引擎 TRIMP 域 dailyLoad")
        XCTAssertEqual(record.workoutLoad, 88.0, "apply 必须保留引擎 workoutLoad")
    }

    /// 回归：fetchSnapshots 的 04:00 健康日窗口与记录层日历午夜 date 错位，
    /// 曾导致 42 天请求恒只返回 41 条（滚动基线缺最老一天）。
    @MainActor
    func testFetchSnapshotsReturnsAll42Days() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let calendar = Calendar.current
        // 锚定正午：00:00-04:00 时健康日边界会把「今天」归到前一日，使测试随墙钟波动。
        let now = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: Date()) ?? Date()
        let todayStart = calendar.startOfDay(for: now)
        for k in 0..<42 {
            let day = calendar.date(byAdding: .day, value: -k, to: todayStart)!
            let record = DailyHealthSummaryRecord(
                dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar),
                date: day
            )
            record.hrvAverage = 50
            context.insert(record)
        }
        try context.save()

        let repo = HealthSnapshotRepository(modelContext: context, calendar: calendar)
        let snapshots = try repo.fetchSnapshots(days: 42, endingAt: now)
        XCTAssertEqual(snapshots.count, 42, "42 天请求必须返回 42 条，实际 \(snapshots.count)")
    }
}

@MainActor
final class CoachSessionStoreTests: XCTestCase {
    private func makeStoreWithSessions() throws -> (ModelContainer, CoachSessionStore) {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let first = CoachSessionRecord(
            id: UUID(),
            title: "会话一",
            createdAt: Date(),
            updatedAt: Date(),
            serializedMessages: "[]"
        )
        let second = CoachSessionRecord(
            id: UUID(),
            title: "会话二",
            createdAt: Date(),
            updatedAt: Date().addingTimeInterval(-60),
            serializedMessages: "[]"
        )
        context.insert(first)
        context.insert(second)
        try context.save()
        let store = CoachSessionStore()
        store.loadSessions(modelContext: context, isStreaming: false, isAwaitingForegroundRetry: false, messagesHandler: { _ in })
        return (container, store)
    }

    func testDeleteSessionIsRejectedWhileStreaming() throws {
        let (container, store) = try makeStoreWithSessions()
        let context = container.mainContext
        let target = try XCTUnwrap(store.currentSession)

        // 流式中删除当前会话：完成时的 persistThread 会把整段对话写进
        // 另一个会话并覆盖其历史——必须在 store 层拒绝该操作
        store.deleteSession(target, modelContext: context, isStreaming: true, isAwaitingForegroundRetry: false, messagesHandler: { _ in })

        let remaining = try context.fetch(FetchDescriptor<CoachSessionRecord>())
        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(store.currentSession?.id, target.id)
    }

    func testCreateNewSessionIsRejectedWhileStreaming() throws {
        let (container, store) = try makeStoreWithSessions()
        let context = container.mainContext
        let previous = store.currentSession

        store.createNewSession(modelContext: context, isStreaming: true, isAwaitingForegroundRetry: false, messagesHandler: { _ in })

        let sessions = try context.fetch(FetchDescriptor<CoachSessionRecord>())
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(store.currentSession?.id, previous?.id)
    }
}
