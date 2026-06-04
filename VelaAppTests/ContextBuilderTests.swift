import XCTest
@testable import Vela

final class ContextBuilderTests: XCTestCase {
    private func makeDate(
        year: Int = 2026,
        month: Int = 4,
        day: Int = 2,
        hour: Int = 12
    ) -> Date {
        Calendar.current.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    private func makeWorkout(start: Date) -> StrengthWorkoutRecord {
        StrengthWorkoutRecord(
            title: "Chest Strength",
            startedAt: start,
            durationMinutes: 55,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: nil,
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start),
                        StrengthSetLog(repetitions: 8, weightKilograms: 82.5, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start)
                    ]
                )
            ]
        )
    }

    private func makeMixedCompletionWorkout(start: Date) -> StrengthWorkoutRecord {
        StrengthWorkoutRecord(
            title: "Mixed Completion",
            startedAt: start,
            durationMinutes: 45,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: nil,
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isWarmup: false, rpe: 8, rir: 2, isCompleted: true, completedAt: start),
                        StrengthSetLog(repetitions: 8, weightKilograms: 82.5, isWarmup: false, rpe: 8, rir: 2, isCompleted: false, completedAt: nil),
                        StrengthSetLog(repetitions: 8, weightKilograms: 85, isWarmup: false, rpe: 8, rir: 2, isCompleted: nil, completedAt: nil)
                    ]
                )
            ]
        )
    }

    func testAIContextIncludesRecentStrengthSummary() {
        let generatedAt = makeDate()
        let workout = makeWorkout(start: generatedAt.addingTimeInterval(-24 * 3600))
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = result.envelope.strengthTraining ?? [:]
        XCTAssertEqual(strength["algorithm_version"], "trainingAnalytics.v1")
        XCTAssertEqual(strength["sessions_7d"], "1")
        XCTAssertEqual(strength["hard_sets_7d"], "2")
        XCTAssertTrue((strength["muscle_groups_7d"] ?? "").contains("chest: 2 sets"))
        XCTAssertTrue((strength["last_session_summary"] ?? "").contains("Chest Strength"))
    }

    func testAIContextIncludesLocalFatigue() throws {
        let generatedAt = makeDate()
        let workout = makeWorkout(start: generatedAt.addingTimeInterval(-6 * 3600))
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let typed = AIContextBuilder().buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = try XCTUnwrap(typed.context.strengthTraining)
        let fatigue = strength.localFatigue["chest"]
        XCTAssertEqual(fatigue?.setsLast48h, 2)
        XCTAssertEqual(fatigue?.setsLast7d, 2)
        XCTAssertEqual(strength.muscleGroupSets7d["chest"], 2)
    }

    func testAIContextMarksNoStrengthDataWhenEmpty() throws {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [],
            generatedAt: generatedAt
        )
        let typed = AIContextBuilder().buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [],
            generatedAt: generatedAt
        )

        let strength = result.envelope.strengthTraining ?? [:]
        XCTAssertEqual(strength["confidence"], "unavailable")
        XCTAssertEqual(strength["sessions_7d"], "0")
        XCTAssertTrue((strength["note"] ?? "").contains("No strength training data"))
        let typedStrength = try XCTUnwrap(typed.context.strengthTraining)
        XCTAssertEqual(typedStrength.sessions7d, 0)
        XCTAssertTrue(typedStrength.localFatigue.isEmpty)
    }

    func testUncompletedSetsAreNotCountedAsEffectiveSets() {
        let generatedAt = makeDate()
        let workout = makeMixedCompletionWorkout(start: generatedAt.addingTimeInterval(-3600))

        let analysis = TrainingAnalyticsService().summarizeWorkout(workout)
        let recent = TrainingAnalyticsService().buildRecentSummary(
            workouts: [workout],
            days: 7,
            endingAt: generatedAt
        )

        XCTAssertEqual(analysis.plannedSets, 3)
        XCTAssertEqual(analysis.completedSets, 1)
        XCTAssertEqual(analysis.uncompletedSets, 2)
        XCTAssertEqual(analysis.effectiveSets, 1)
        XCTAssertEqual(recent.effectiveSets, 1)
        XCTAssertEqual(recent.muscleGroupSets["chest"], 1)
    }

    func testCompletedSetsAreCounted() {
        let generatedAt = makeDate()
        let workout = makeWorkout(start: generatedAt.addingTimeInterval(-3600))

        let analysis = TrainingAnalyticsService().summarizeWorkout(workout)

        XCTAssertEqual(analysis.plannedSets, 2)
        XCTAssertEqual(analysis.completedSets, 2)
        XCTAssertEqual(analysis.uncompletedSets, 0)
        XCTAssertEqual(analysis.effectiveSets, 2)
        XCTAssertEqual(analysis.totalVolumeKg, 1300, accuracy: 0.1)
    }

    func testAIContextIncludesCompletedSetsOnly() {
        let generatedAt = makeDate()
        let workout = makeMixedCompletionWorkout(start: generatedAt.addingTimeInterval(-3600))
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = result.envelope.strengthTraining ?? [:]
        XCTAssertEqual(strength["hard_sets_7d"], "1")
        XCTAssertTrue((strength["muscle_groups_7d"] ?? "").contains("chest: 1 sets"))
    }

    func testTemplatePrefillsFromPreviousPerformance() {
        let generatedAt = makeDate()
        let previous = makeWorkout(start: generatedAt.addingTimeInterval(-86_400))

        let sets = StrengthWorkoutSessionPrefill.previousCompletedSets(
            for: "Bench Press",
            in: [previous]
        )

        XCTAssertEqual(sets.count, 2)
        XCTAssertEqual(sets.first?.weightKilograms, 80)
        XCTAssertEqual(sets.first?.repetitions, 8)
    }

    @MainActor
    func testNotificationLanguageFollowsAppLanguage() {
        let zh = NotificationService.morningBriefNotificationContent(language: .simplifiedChinese)
        let en = NotificationService.morningBriefNotificationContent(language: .english)
        let snapshot = DailyHealthSnapshot(date: makeDate(), recoveryScore: 32, stressIndex: 84)
        let zhAlerts = NotificationService.abnormalMetricAlertCandidates(
            snapshot: snapshot,
            baselines: nil,
            language: .simplifiedChinese
        )
        let enAlerts = NotificationService.abnormalMetricAlertCandidates(
            snapshot: snapshot,
            baselines: nil,
            language: .english
        )

        XCTAssertEqual(zh.title, "晨间简报已生成")
        XCTAssertEqual(en.title, "Your morning brief is ready")
        XCTAssertTrue(zhAlerts.contains { $0.message.contains("恢复分较低") })
        XCTAssertTrue(enAlerts.contains { $0.message.contains("Recovery is low") })
        XCTAssertFalse(NotificationService.shouldSendAbnormalAlert(previousSeverity: "medium", newSeverity: "medium"))
        XCTAssertTrue(NotificationService.shouldSendAbnormalAlert(previousSeverity: "medium", newSeverity: "high"))
    }

    func testMetricPipelineConsistencyBetweenSyncAndDashboard() {
        let date = makeDate()
        var snapshot = DailyHealthSnapshot(date: date)
        snapshot.sleepHours = 7.5
        snapshot.sleepEfficiency = 0.88
        snapshot.hrvAverage = 48
        snapshot.restingHeartRate = 58
        snapshot.respiratoryRate = 14
        snapshot.activeCalories = 420
        snapshot.activeMinutes = 35
        snapshot.steps = 8_000
        snapshot.workouts = [
            WorkoutSummary(
                start: date.addingTimeInterval(-3_600),
                end: date.addingTimeInterval(-1_800),
                activityName: "Strength Training",
                energyKilocalories: 180,
                averageHeartRate: 130,
                source: "strengthLog",
                rpe: 7
            )
        ]

        let history = (1...7).map { offset -> DailyHealthSnapshot in
            var day = DailyHealthSnapshot(date: date.addingTimeInterval(Double(-offset) * 86_400))
            day.sleepHours = 7.0
            day.hrvAverage = 45
            day.restingHeartRate = 60
            day.respiratoryRate = 14
            day.dailyLoad = 35
            day.strainScore = 45
            return day
        }

        let pipeline = MetricComputationPipeline()
        let syncMetrics = pipeline.compute(for: snapshot, history: history)
        let dashboardMetrics = pipeline.compute(for: snapshot, history: history)

        XCTAssertEqual(syncMetrics.sleepScore.score, dashboardMetrics.sleepScore.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.recovery.score, dashboardMetrics.recovery.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.strain.score, dashboardMetrics.strain.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.stress.stressIndex, dashboardMetrics.stress.stressIndex, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.energy.currentEnergy, dashboardMetrics.energy.currentEnergy, accuracy: 0.001)
    }
}
