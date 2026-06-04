import XCTest
import SwiftData
@testable import Vela

final class PersistenceFoundationTests: XCTestCase {
    func testModelContainerSchemaCreatedSuccessfully() {
        let schema = VelaModelContainer.schema
        XCTAssertNotNil(schema)
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
            daysOfData: 28
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
