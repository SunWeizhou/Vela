import XCTest
@testable import Vela

final class ContextBuilderTests: XCTestCase {
    @MainActor
    func testEveningWikiAgentUsesCanonicalAvailabilityInsteadOfDefaultZeroScores() {
        let snapshot = AIContextBuilder().buildFacts(
            dashboard: .empty(date: Date()),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        ).snapshot

        let prompt = EveningWikiSyncAgent.shared.buildSyncPrompt(
            snapshot: snapshot,
            chatMessages: []
        )

        XCTAssertTrue(prompt.contains("v2.0"))
        XCTAssertTrue(prompt.contains(snapshot.contextHash))
        XCTAssertTrue(prompt.contains("Data Coverage"))
        XCTAssertFalse(prompt.contains("恢复: 0"))
        XCTAssertFalse(prompt.contains("Recovery: 0"))
    }

    func testCanonicalFactsUseTheSameExplicitDataCoverageProjectionAsUI() {
        let coverage = AgentDataCoverageContext(
            availableSections: 2,
            totalSections: 4,
            missingSections: ["recovery", "sleep"],
            confidence: .medium
        )

        let snapshot = AIContextBuilder().buildFacts(
            dashboard: .preview(date: Date()),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            dataCoverage: coverage
        ).snapshot

        XCTAssertEqual(snapshot.dataCoverage, coverage)
    }

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

    func testAIContextIncludesUnifiedWorkoutSummary() throws {
        let generatedAt = makeDate()
        let event = WorkoutEventRecord(
            source: "healthKit+xunji",
            startedAt: generatedAt.addingTimeInterval(-24 * 3600),
            endedAt: generatedAt.addingTimeInterval(-23 * 3600),
            activityType: "TraditionalStrengthTraining",
            title: "背部二头",
            energyKilocalories: 420,
            averageHeartRate: 132,
            linkedStrengthWorkoutId: UUID(),
            linkedHealthKitWorkoutId: UUID()
        )
        let dashboard = DashboardSummary.preview(date: generatedAt)

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            workoutEvents: [event],
            generatedAt: generatedAt
        )

        let unified = try XCTUnwrap(result.envelope.unifiedWorkouts)
        XCTAssertEqual(unified["algorithm_version"], "workoutEvents.v1")
        XCTAssertEqual(unified["sessions_7d"], "1")
        XCTAssertTrue((unified["activity_types_14d"] ?? "").contains("背部二头"))
        XCTAssertTrue((unified["source_mix_14d"] ?? "").contains("healthKit+xunji"))
        XCTAssertTrue((unified["recent_workout_events_json"] ?? "").contains("linked_strength_workout_id"))
    }

    func testStrengthDetailsExcludeUncompletedSetsFromCompletedWork() throws {
        let generatedAt = makeDate()
        let workout = StrengthWorkoutRecord(
            title: "Chest",
            startedAt: generatedAt.addingTimeInterval(-3600),
            durationMinutes: 45,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "barbell",
                    primaryMuscleGroup: "chest",
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isCompleted: true),
                        StrengthSetLog(repetitions: 8, weightKilograms: 90, isCompleted: false)
                    ]
                )
            ]
        )
        let result = AIContextBuilder().build(
            dashboard: .preview(date: generatedAt),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let details = try XCTUnwrap(result.envelope.strengthTraining?["recent_workout_details"])
        XCTAssertTrue(details.contains("1 completed work sets") || details.contains("1 完成工作组"))
        XCTAssertTrue(details.contains("1 uncompleted sets excluded") || details.contains("1 未完成组未计入容量"))
        XCTAssertTrue(details.contains("80.0kg x 8") || details.contains("80kg x 8"))
        XCTAssertFalse(details.contains("90.0kg x 8"))
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

        let typed = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            strengthWorkouts: [workout],
            generatedAt: generatedAt
        )

        let strength = try XCTUnwrap(typed.snapshot.strengthTraining)
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
        let typed = AIContextBuilder().buildFacts(
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
        let typedStrength = try XCTUnwrap(typed.snapshot.strengthTraining)
        XCTAssertEqual(typedStrength.sessions7d, 0)
        XCTAssertTrue(typedStrength.localFatigue.isEmpty)
    }

    func testAIContextMarksUncomputedHealthScoresAsMissing() throws {
        let dashboard = DashboardSummary.empty(date: makeDate())

        let result = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )
        let typed = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:]
        )

        XCTAssertEqual(result.envelope.recovery["score"], "N/A")
        XCTAssertEqual(result.envelope.sleep["sleep_score"], "N/A")
        XCTAssertEqual(result.envelope.strain["score"], "N/A")
        XCTAssertEqual(result.envelope.stress["stress_index"], "N/A")
        XCTAssertEqual(result.envelope.energyBank["current_energy"], "N/A")
        XCTAssertNil(typed.snapshot.recovery.score.value)
        XCTAssertEqual(typed.snapshot.recovery.score.freshness, .missing)
        XCTAssertNil(typed.snapshot.sleep.score.value)
        XCTAssertNil(typed.snapshot.strain.score.value)
        XCTAssertNil(typed.snapshot.stress.stressIndex.value)
        XCTAssertNil(typed.snapshot.energyBank.currentEnergy.value)
    }

    func testLegacyReportContextPreservesV1NoDataContract() {
        let generatedAt = makeDate()
        let result = AIContextBuilder().build(
            dashboard: .empty(date: generatedAt),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: generatedAt
        )

        XCTAssertEqual(result.metadata.schemaVersion, "v1.0")
        XCTAssertEqual(Set(result.envelope.todaySummary.keys), [
            "date", "overall_state", "source", "top_reason",
            "readiness_level", "readiness_guidance"
        ])
        XCTAssertEqual(Set(result.envelope.sleep.keys), [
            "sleep_score", "duration_minutes", "band", "reason",
            "rem_minutes", "deep_minutes", "core_minutes", "awake_minutes",
            "sleep_efficiency_pct", "rem_pct", "deep_pct"
        ])
        XCTAssertEqual(Set(result.envelope.recovery.keys), [
            "score", "band", "confidence", "reason", "hrv_ms", "rhr_bpm",
            "respiratory_rate", "hrv_z_score", "hrv_vs_baseline_pct",
            "hrv_baseline_ms", "rhr_baseline_bpm"
        ])
        // 联通专项批次 1：v1 strain 契约有意扩展（负荷分解指标），
        // stress 契约扩展（六因子）——agent 不再只能看到聚合分数。
        XCTAssertEqual(Set(result.envelope.strain.keys), [
            "score", "band", "target_status", "recommended_range",
            "steps", "active_energy_kcal", "exercise_minutes",
            "training_load_ratio", "acute_7d_load", "chronic_28d_equivalent",
            "training_load_status"
        ])
        XCTAssertEqual(Set(result.envelope.energyBank.keys), [
            "morning_energy", "current_energy", "status", "charge_efficiency",
            "atl_7day", "ctl_42day", "tsb_freshness", "acwr_ratio"
        ])
        XCTAssertEqual(result.envelope.todaySummary["overall_state"], "unavailable")
        XCTAssertEqual(result.envelope.sleep["sleep_score"], "N/A")
        XCTAssertEqual(result.envelope.recovery["score"], "N/A")
        XCTAssertEqual(result.envelope.strain["score"], "N/A")
        XCTAssertEqual(result.envelope.energyBank["current_energy"], "N/A")
    }

    func testLegacyReportHashIgnoresCreationTimeAndDictionaryOrder() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            generatedAt: generatedAt
        ))
        let first = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: Dictionary(uniqueKeysWithValues: [("z", "last"), ("a", "first")]),
            weeklyTrends: ["sleep": "stable", "recovery": "up"],
            bodyState: bodyState,
            generatedAt: generatedAt
        )
        let second = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: Dictionary(uniqueKeysWithValues: [("a", "first"), ("z", "last")]),
            weeklyTrends: ["recovery": "up", "sleep": "stable"],
            bodyState: bodyState,
            generatedAt: generatedAt.addingTimeInterval(60)
        )

        XCTAssertEqual(first.metadata.hash, second.metadata.hash)
    }

    func testCanonicalContentHashIgnoresSnapshotCreationTimeAndDictionaryOrder() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let firstWiki = Dictionary(uniqueKeysWithValues: [("z", "last"), ("a", "first")])
        let secondWiki = Dictionary(uniqueKeysWithValues: [("a", "first"), ("z", "last")])

        let first = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: firstWiki,
            weeklyTrends: ["sleep": "stable", "recovery": "up"],
            generatedAt: generatedAt
        )
        let second = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: secondWiki,
            weeklyTrends: ["recovery": "up", "sleep": "stable"],
            generatedAt: generatedAt.addingTimeInterval(60)
        )

        XCTAssertEqual(first.snapshot.schemaVersion, "v2.0")
        XCTAssertEqual(first.metadata.schemaVersion, first.snapshot.schemaVersion)
        XCTAssertEqual(first.snapshot.contextHash, second.snapshot.contextHash)
        XCTAssertEqual(first.metadata.hash, second.metadata.hash)
    }

    func testCanonicalContentHashRemainsStableWhenPersonalHealthBriefTimestampChanges() {
        let baseDate = makeDate()
        var dashboard1 = DashboardSummary.preview(date: baseDate)
        var dashboard2 = dashboard1

        let brief1 = PersonalHealthBrief(
            date: baseDate,
            overallState: .optimal,
            headline: "状态良好",
            subheadline: "恢复优秀",
            notableChanges: [],
            stableSignals: [],
            confidence: .high,
            confidenceLabel: "高",
            needsAction: false,
            suggestedActionCategory: .training,
            actionHeadline: nil,
            actionDetail: nil,
            lifestyleSuggestions: [],
            generatedAt: baseDate
        )

        let brief2 = PersonalHealthBrief(
            date: baseDate.addingTimeInterval(3600),
            overallState: .optimal,
            headline: "状态良好",
            subheadline: "恢复优秀",
            notableChanges: [],
            stableSignals: [],
            confidence: .high,
            confidenceLabel: "高",
            needsAction: false,
            suggestedActionCategory: .training,
            actionHeadline: nil,
            actionDetail: nil,
            lifestyleSuggestions: [],
            generatedAt: baseDate.addingTimeInterval(7200)
        )

        dashboard1.personalHealthBrief = brief1
        dashboard2.personalHealthBrief = brief2

        let fixedBodyState = dashboard1.bodyState
        let decision = DailyTrainingDecision(
            decision: .keep,
            volumeMultiplier: 1.0,
            intensityCap: 85,
            reasons: ["状态良好"],
            userFacingSummary: "按计划执行",
            confidence: 1.0,
            source: "test",
            safetyNotice: "注意热身"
        )

        let first = AIContextBuilder().buildFacts(
            dashboard: dashboard1,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            bodyState: fixedBodyState,
            trainingDecision: decision,
            generatedAt: baseDate
        )
        let second = AIContextBuilder().buildFacts(
            dashboard: dashboard2,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            bodyState: fixedBodyState,
            trainingDecision: decision,
            generatedAt: baseDate
        )

        XCTAssertEqual(first.snapshot.bodyState, second.snapshot.bodyState, "bodyState must match")
        XCTAssertEqual(first.snapshot.trainingDecision, second.snapshot.trainingDecision, "trainingDecision must match")
        XCTAssertEqual(first.snapshot.dataCoverage, second.snapshot.dataCoverage, "dataCoverage must match")
        XCTAssertEqual(first.snapshot.recovery, second.snapshot.recovery, "recovery must match")
        XCTAssertEqual(first.snapshot.sleep, second.snapshot.sleep, "sleep must match")
        XCTAssertEqual(first.snapshot.strain, second.snapshot.strain, "strain must match")
        XCTAssertEqual(first.snapshot.stress, second.snapshot.stress, "stress must match")
        XCTAssertEqual(first.snapshot.energyBank, second.snapshot.energyBank, "energyBank must match")
        XCTAssertEqual(first.snapshot.training, second.snapshot.training, "training must match")
        XCTAssertEqual(first.snapshot.nutrition, second.snapshot.nutrition, "nutrition must match")
        XCTAssertEqual(first.snapshot.extendedMetrics, second.snapshot.extendedMetrics, "extendedMetrics must match")
        XCTAssertEqual(first.snapshot.strengthTraining, second.snapshot.strengthTraining, "strengthTraining must match")
        XCTAssertEqual(first.snapshot.recentTrends, second.snapshot.recentTrends, "recentTrends must match")
        XCTAssertEqual(first.snapshot.weeklyTrends, second.snapshot.weeklyTrends, "weeklyTrends must match")
        XCTAssertEqual(first.snapshot.journalEntries, second.snapshot.journalEntries, "journalEntries must match")
        XCTAssertEqual(first.snapshot.historicalReports, second.snapshot.historicalReports, "historicalReports must match")
        XCTAssertEqual(first.snapshot.userWiki, second.snapshot.userWiki, "userWiki must match")
        XCTAssertEqual(first.snapshot.dailyOperatingPlan, second.snapshot.dailyOperatingPlan, "dailyOperatingPlan must match")
        XCTAssertEqual(first.snapshot.healthTrends, second.snapshot.healthTrends, "healthTrends must match")

        XCTAssertEqual(first.snapshot.contextHash, second.snapshot.contextHash, "Brief timestamps must be normalized in canonicalContentHash")
    }

    func testCanonicalContentHashChangesWhenAHealthSignalChanges() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        var changed = dashboard
        changed.recovery.value = (dashboard.recovery.value ?? 0) + 1

        let original = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: generatedAt
        )
        let modified = AIContextBuilder().buildFacts(
            dashboard: changed,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            generatedAt: generatedAt
        )

        XCTAssertNotEqual(original.snapshot.contextHash, modified.snapshot.contextHash)
    }

    func testCanonicalMetricsPreserveMeasurementSemanticsAndCoverage() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            generatedAt: generatedAt
        ))
        let result = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            bodyState: bodyState,
            generatedAt: generatedAt
        )

        XCTAssertEqual(result.snapshot.recovery.score.unit, "pts")
        XCTAssertEqual(result.snapshot.recovery.score.source, .computed)
        XCTAssertEqual(result.snapshot.recovery.score.measuredAt, dashboard.recovery.lastUpdated)
        XCTAssertNotEqual(result.snapshot.recovery.score.freshness, .missing)
        XCTAssertEqual(result.snapshot.bodyState.contextHash, bodyState.hash)
        XCTAssertEqual(result.snapshot.trainingDecision.readinessLevel, dashboard.trainingDecision.readinessLevel)
        XCTAssertEqual(result.snapshot.dataCoverage.totalSections, 5)
        XCTAssertTrue(result.snapshot.dataCoverage.missingSections.isEmpty)
    }

    func testCanonicalProfileAgeUsesExplicitInputInsteadOfWikiGlobalState() {
        let generatedAt = makeDate()
        var dashboard = DashboardSummary.preview(date: generatedAt)
        dashboard.extendedMetrics.age = 31

        let result = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            profileAge: 42,
            generatedAt: generatedAt
        )

        XCTAssertEqual(result.snapshot.extendedMetrics.age, 42)
    }

    func testCoachCompactAdapterUsesCanonicalFactsAndStableTrendOrder() {
        let generatedAt = makeDate()
        let dashboard = DashboardSummary.preview(date: generatedAt)
        let canonical = AIContextBuilder().buildFacts(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            weeklyTrends: ["z-last": "2", "a-first": "1"],
            generatedAt: generatedAt
        ).snapshot

        let rendered = CoachCompactContextAdapter().render(
            snapshot: canonical,
            language: .simplifiedChinese,
            maxCharacters: 2_000
        )

        XCTAssertTrue(rendered.contains("恢复 \(Int((canonical.recovery.score.value ?? 0).rounded()))"))
        XCTAssertTrue(rendered.contains(canonical.trainingDecision.readinessLevel))
        XCTAssertTrue(rendered.contains("content_hash: \(canonical.contextHash)"))
        XCTAssertTrue(rendered.contains("一般健康建议，不构成医疗诊断"))
        XCTAssertLessThan(try! XCTUnwrap(rendered.range(of: "a-first")).lowerBound,
                          try! XCTUnwrap(rendered.range(of: "z-last")).lowerBound)
    }

    func testCoachCompactAdapterHonorsBudgetWithoutDroppingSafetyOrHash() {
        let generatedAt = makeDate()
        let canonical = AIContextBuilder().buildFacts(
            dashboard: .preview(date: generatedAt),
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            weeklyTrends: Dictionary(uniqueKeysWithValues: (0..<20).map { ("trend-\($0)", String(repeating: "x", count: 120)) }),
            generatedAt: generatedAt
        ).snapshot

        let rendered = CoachCompactContextAdapter().render(
            snapshot: canonical,
            language: .simplifiedChinese,
            maxCharacters: 800
        )

        XCTAssertLessThanOrEqual(rendered.count, 800)
        XCTAssertTrue(rendered.contains("一般健康建议，不构成医疗诊断"))
        XCTAssertTrue(rendered.contains("content_hash: \(canonical.contextHash)"))
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
        let typed = AIContextBuilder().buildFacts(
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
        XCTAssertEqual(typed.snapshot.userWiki["body_model.training_style"], "strength")
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

        let analysis = TrainingAnalyticsService().summarizeWorkout(workout.dto)
        let recent = TrainingAnalyticsService().buildRecentSummary(
            workouts: [workout.dto],
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

        let analysis = TrainingAnalyticsService().summarizeWorkout(workout.dto)

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

    func testDailyHealthComputationIsDeterministicAcrossEntryAdapters() {
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

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let profile = DailyHealthComputationProfile(
            sleepTargetMinutes: 450,
            maxHeartRate: 190,
            biologicalSex: "other"
        )
        let syncMetrics = DailyHealthComputation(
            calendar: calendar,
            now: date,
            profile: profile
        ).compute(for: snapshot, history: history)
        let dashboardMetrics = DailyHealthComputation(
            calendar: calendar,
            now: date,
            profile: profile
        ).compute(for: snapshot, history: history)

        XCTAssertEqual(syncMetrics, dashboardMetrics)
        XCTAssertEqual(syncMetrics.sleepScore.score, dashboardMetrics.sleepScore.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.recovery.score, dashboardMetrics.recovery.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.strain.score, dashboardMetrics.strain.score, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.stress.stressIndex, dashboardMetrics.stress.stressIndex, accuracy: 0.001)
        XCTAssertEqual(syncMetrics.energy.currentEnergy, dashboardMetrics.energy.currentEnergy, accuracy: 0.001)

        let scoredSnapshot = syncMetrics.applying(to: snapshot)
        XCTAssertEqual(scoredSnapshot.sleepScore, syncMetrics.sleepScore.value)
        XCTAssertEqual(scoredSnapshot.recoveryScore, syncMetrics.recovery.value)
        XCTAssertEqual(scoredSnapshot.strainScore, syncMetrics.strain.value)
        XCTAssertEqual(scoredSnapshot.stressIndex, syncMetrics.stress.value)
        XCTAssertEqual(scoredSnapshot.energyBank, syncMetrics.energy.value)
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

        // D8：signal 级 confidence 字段已删除（此前只被死视图消费），
        // 低置信度语义由 dataConfidence 聚合表达（HRV 缺失 → .low）。
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

    func testJournalCorrelationIgnoresLegacyCoachConversations() {
        let base = makeDate()
        let entries = (0..<8).map { offset in
            JournalEntryRecord(
                createdAt: base.addingTimeInterval(Double(-offset) * 86_400),
                tags: ["coach", "training"],
                note: "Should I train today?"
            )
        }
        var snapshots: [DailyHealthSnapshot] = []
        for offset in 0..<16 {
            let snapshot = DailyHealthSnapshot(
                date: base.addingTimeInterval(Double(-offset) * 86_400),
                sleepScore: Double(60 + offset),
                recoveryScore: Double(55 + offset)
            )
            snapshots.append(snapshot)
        }

        let correlations = JournalCorrelationEngine().correlateTags(
            journalEntries: entries,
            snapshots: snapshots
        )

        XCTAssertTrue(correlations.isEmpty)
    }

    func testJournalCorrelationRejectsUnbalancedSmallExposureEvenWithLargeEffect() {
        let base = makeDate()
        let entries = (0..<6).map { offset in
            JournalEntryRecord(
                createdAt: base.addingTimeInterval(Double(-offset) * 86_400),
                tags: ["late_meal"],
                note: "late"
            )
        }
        let snapshots = (0..<40).map { offset in
            DailyHealthSnapshot(
                date: base.addingTimeInterval(Double(-offset) * 86_400),
                recoveryScore: offset < 6 ? 20 : 90
            )
        }

        let insights = JournalCorrelationEngine().calculateInsights(
            journalEntries: entries,
            snapshots: snapshots
        )

        XCTAssertTrue(insights.isEmpty)
    }

    func testJournalCorrelationKeepsBalancedEffectAfterFalseDiscoveryScreening() {
        let base = makeDate()
        let entries = (0..<20).map { offset in
            JournalEntryRecord(
                createdAt: base.addingTimeInterval(Double(-offset * 2) * 86_400),
                tags: ["alcohol"],
                note: "exposure"
            )
        }
        let taggedDays = Set(entries.map { Calendar.current.startOfDay(for: $0.createdAt) })
        let snapshots = (0..<40).map { offset -> DailyHealthSnapshot in
            let date = base.addingTimeInterval(Double(-offset) * 86_400)
            let tagged = taggedDays.contains(Calendar.current.startOfDay(for: date))
            return DailyHealthSnapshot(date: date, recoveryScore: tagged ? 45 : 82)
        }

        let insights = JournalCorrelationEngine().calculateInsights(
            journalEntries: entries,
            snapshots: snapshots
        )

        XCTAssertTrue(insights.contains {
            $0.habit == "alcohol" && $0.outcome == "Recovery Score" && $0.correlation < -0.7
        })
    }
}
