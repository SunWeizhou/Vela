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

    func testAIContextFlagsCostlyTrainingResponse() throws {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let response = TrainingResponseRecord(
            workoutId: UUID(),
            date: generatedAt.addingTimeInterval(-86_400),
            nextDayDate: generatedAt,
            primaryMuscleGroups: ["legs"],
            totalEffectiveSets: 12,
            totalVolumeKg: 9_600,
            sessionRPE: 8,
            nextDayRecoveryDelta: -10,
            nextDayHRVDelta: -12,
            nextDayRHRDelta: 4
        )

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [],
            trainingResponses: [response],
            generatedAt: generatedAt
        )
        let contextJSON = try XCTUnwrap(String(data: JSONEncoder().encode(result.envelope), encoding: .utf8))

        XCTAssertTrue(contextJSON.contains("recovery_response_summary"))
        XCTAssertTrue(contextJSON.contains("notable recovery cost"))
        XCTAssertTrue(contextJSON.contains("\"flagged_response_count\":\"1\""))
        XCTAssertTrue(contextJSON.contains("\"average_next_day_recovery_delta\":\"-10.0\""))
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

    @MainActor
    func testAIContextIncludesOnboardingBodyModel() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let onboarding = OnboardingState(
            isCompleted: true,
            goalProfile: UserGoalProfile(
                primaryGoal: "muscle_gain",
                secondaryGoals: ["strength"],
                experienceLevel: "intermediate",
                bodyConcerns: ["shoulder"]
            ),
            trainingPreference: TrainingPreferenceProfile(
                trainingStyle: "strength",
                weeklyTrainingDays: 4,
                sessionDurationMinutes: 60,
                preferredTrainingDays: ["Mon", "Wed", "Fri"]
            ),
            equipmentProfile: EquipmentProfile(
                equipment: ["gym", "barbell"],
                scheduleNotes: "evening sessions"
            ),
            coachingPreference: CoachingPreference(
                style: "direct",
                explanationDepth: "balanced",
                language: "zh-Hans"
            ),
            firstBrief: "Build muscle with conservative progression."
        )

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: ["existing": "keep"],
            onboardingState: onboarding,
            generatedAt: generatedAt
        )
        let typed = AIContextBuilder().buildTyped(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            onboardingState: onboarding,
            generatedAt: generatedAt
        )

        XCTAssertEqual(result.envelope.userWiki["existing"], "keep")
        XCTAssertEqual(result.envelope.userWiki["body_model.primary_goal"], "muscle_gain")
        XCTAssertEqual(result.envelope.userWiki["body_model.weekly_training_days"], "4")
        XCTAssertEqual(typed.context.userWiki["body_model.training_style"], "strength")
        XCTAssertTrue(result.metadata.includedSections.contains("body_model_profile"))
        XCTAssertTrue(typed.metadata.includedSections.contains("body_model_profile"))
    }

    @MainActor
    func testAIContextIncludesBodyModelStateWhenAvailable() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let onboarding = OnboardingState(
            isCompleted: true,
            goalProfile: UserGoalProfile(primaryGoal: "performance", experienceLevel: "intermediate"),
            trainingPreference: TrainingPreferenceProfile(trainingStyle: "strength", weeklyTrainingDays: 4, sessionDurationMinutes: 60),
            equipmentProfile: EquipmentProfile(equipment: ["gym"])
        )
        let bodyModelState = BodyModelBuilder().build(
            onboarding: onboarding,
            dailySummaries: [],
            journalEntries: [
                JournalEntryRecord(
                    createdAt: generatedAt.addingTimeInterval(-86_400),
                    tags: ["behavior:alcohol", "intensity:medium"],
                    note: "晚餐喝酒"
                )
            ],
            strengthWorkouts: [makeWorkout(start: generatedAt.addingTimeInterval(-2 * 86_400))],
            trainingResponses: [],
            asOf: generatedAt
        )

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            onboardingState: onboarding,
            bodyModelState: bodyModelState,
            generatedAt: generatedAt
        )

        XCTAssertEqual(result.envelope.userWiki["body_model.maturity"], "seed")
        XCTAssertTrue((result.envelope.userWiki["body_model.uncertain_areas"] ?? "").contains("behavior_pairs"))
        XCTAssertTrue(result.metadata.includedSections.contains("body_model_state"))
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

    func testTodayCommandStateRecoversWhenRecoveryIsLow() {
        let generatedAt = makeDate()
        var dashboard = DashboardSummary.preview(date: generatedAt)
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 34,
            band: .low,
            confidence: .high,
            components: ["hrv": 32, "rhr": 44, "sleep": 58],
            componentWeights: ["hrv": 0.35, "rhr": 0.25, "sleep": 0.25],
            reasons: ["HRV is below baseline.", "Resting heart rate is elevated."],
            missingInputs: [],
            dataWindow: DateInterval(start: generatedAt, duration: 86_400),
            source: .derived,
            algorithmVersion: "test",
            lastUpdated: generatedAt
        )
        dashboard.sleepScore = MetricResult(
            name: "Sleep Score",
            value: 58,
            band: .low,
            confidence: .high,
            components: ["duration": 58],
            componentWeights: ["duration": 1],
            reasons: ["Sleep duration is below target."],
            missingInputs: [],
            dataWindow: DateInterval(start: generatedAt, duration: 86_400),
            source: .derived,
            algorithmVersion: "test",
            lastUpdated: generatedAt
        )
        dashboard.strain = MetricResult(
            name: "Strain Score",
            value: 42,
            band: .normal,
            confidence: .high,
            components: ["recommended_lower": 35, "recommended_upper": 65],
            componentWeights: ["load": 1],
            reasons: ["Current strain is in range."],
            missingInputs: [],
            dataWindow: DateInterval(start: generatedAt, duration: 86_400),
            source: .derived,
            algorithmVersion: "test",
            lastUpdated: generatedAt
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 36,
            restingHeartRate: 64,
            sleepHeartRate: nil,
            respiratoryRate: nil
        )
        dashboard.recoveryBaseline = RecoveryMetricSummary(
            hrvMilliseconds: 48,
            restingHeartRate: 58,
            sleepHeartRate: nil,
            respiratoryRate: nil
        )

        let state = TodayCommandBuilder.build(from: dashboard, generatedAt: generatedAt)

        XCTAssertEqual(state.readinessDecision.decision, .recover)
        XCTAssertGreaterThanOrEqual(state.readinessDecision.supportingSignals.count, 3)
        XCTAssertTrue(state.readinessDecision.reasons.contains { $0.localizedCaseInsensitiveContains("HRV") })
        XCTAssertTrue(state.actions.contains { $0.kind == .recovery })
        XCTAssertEqual(state.dataConfidence, .high)
    }

    func testTodayCommandConfidenceDropsWhenKeySignalIsUnavailable() {
        let generatedAt = makeDate()
        var dashboard = DashboardSummary.preview(date: generatedAt)
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 72,
            band: .normal,
            confidence: .high,
            components: ["sleep": 72],
            componentWeights: ["sleep": 1],
            reasons: ["Recovery available."],
            missingInputs: [],
            dataWindow: DateInterval(start: generatedAt, duration: 86_400),
            source: .derived,
            algorithmVersion: "test",
            lastUpdated: generatedAt
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: nil,
            restingHeartRate: 58,
            sleepHeartRate: nil,
            respiratoryRate: nil
        )

        let state = TodayCommandBuilder.build(from: dashboard, generatedAt: generatedAt)

        XCTAssertEqual(state.keySignals.first(where: { $0.id == "hrv" })?.confidence, .unavailable)
        XCTAssertEqual(state.dataConfidence, .low)
    }

    func testLegacyJournalCorrelationRequiresEnoughTaggedDays() {
        let base = makeDate()
        let entries = [
            JournalEntryRecord(createdAt: base.addingTimeInterval(-86_400), tags: ["alcohol"], note: "drink"),
            JournalEntryRecord(createdAt: base.addingTimeInterval(-2 * 86_400), tags: ["alcohol"], note: "drink")
        ]
        let snapshots = (0..<10).map { offset in
            DailyHealthSnapshot(
                date: base.addingTimeInterval(Double(-offset) * 86_400),
                sleepScore: 80,
                recoveryScore: 75
            )
        }

        let correlations = JournalCorrelationEngine().correlateTags(journalEntries: entries, snapshots: snapshots)

        XCTAssertTrue(correlations.isEmpty)
    }
}
