import XCTest
@testable import Vela

final class ScoringEngineTests: XCTestCase {
    func testHealthProfileHydrationOnlyFillsMissingValues() {
        let suiteName = "UserProfileSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        UserProfileSettings.hydrateMissingValuesFromHealth(
            age: 29,
            weightKilograms: 71.4,
            heightCentimeters: 178,
            biologicalSex: "male",
            defaults: defaults
        )
        XCTAssertEqual(UserProfileSettings.age(defaults: defaults), 29)
        XCTAssertEqual(UserProfileSettings.weightKilograms(defaults: defaults), 71.4)
        XCTAssertEqual(UserProfileSettings.heightCentimeters(defaults: defaults), 178)
        XCTAssertEqual(UserProfileSettings.biologicalSex(defaults: defaults), "male")

        defaults.set(35, forKey: UserProfileSettings.ageKey)
        UserProfileSettings.hydrateMissingValuesFromHealth(
            age: 29,
            weightKilograms: 70,
            heightCentimeters: 180,
            biologicalSex: "female",
            defaults: defaults
        )
        XCTAssertEqual(UserProfileSettings.age(defaults: defaults), 35)
        XCTAssertEqual(UserProfileSettings.weightKilograms(defaults: defaults), 71.4)
        XCTAssertEqual(UserProfileSettings.heightCentimeters(defaults: defaults), 178)
        XCTAssertEqual(UserProfileSettings.biologicalSex(defaults: defaults), "male")
    }

    func testSleepScoreEngineProducesValidRange() {
        let engine = SleepScoreEngine()
        let input = SleepScoreInput(
            totalSleepMinutes: 420,
            sleepTargetMinutes: 480,
            awakeMinutes: 15,
            awakeEpisodeCount: 2,
            remMinutes: 90,
            deepMinutes: 90
        )
        let result = engine.calculate(from: input)
        XCTAssertGreaterThanOrEqual(result.value ?? 0, 0)
        XCTAssertLessThanOrEqual(result.value ?? 0, 100)
    }

    func testRecoveryScoreEngineHandlesEmptyHistory() {
        let engine = RecoveryScoreEngine()
        let input = RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 50,
            hrvHistory: [],
            restingHeartRateToday: 58,
            restingHeartRateBaseline: 55,
            rhrHistory: [],
            sleepScoreLastNight: 75,
            strainScoreYesterday: 50
        )
        let result = engine.calculate(from: input)
        XCTAssertNotNil(result)
    }

    func testRecoveryReasonsDescribeMeasuredSignalsWithoutPhysiologicalClaims() {
        let result = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 50,
            hrvBaseline: 50,
            hrvHistory: [50, 50, 50, 50, 50],
            restingHeartRateToday: 62,
            restingHeartRateBaseline: 55,
            rhrHistory: [55, 55, 55, 55, 55],
            sleepScoreLastNight: 85,
            strainScoreYesterday: 80
        ))
        let reasons = result.reasons.joined(separator: " ")

        XCTAssertTrue(reasons.contains("静息心率高于近期个人基线"))
        XCTAssertTrue(reasons.contains("昨晚睡眠评分较高"))
        XCTAssertTrue(reasons.contains("昨日训练负荷评分偏高"))
        XCTAssertFalse(reasons.contains("异常"))
        XCTAssertFalse(reasons.contains("系统性修复"))
        XCTAssertFalse(reasons.contains("恢复代偿"))
    }

    func testProactiveTrainingInsightDoesNotPrescribeHighIntensity() {
        let previousLanguage = AppLanguage.stored
        defer { AppLanguage.stored = previousLanguage }
        AppLanguage.stored = .simplifiedChinese

        var dashboard = DashboardSummary.preview(date: Date())
        var recovery = dashboard.recovery
        recovery.components["hrv_z_score"] = 0.8
        recovery.components["rhr_z_score"] = -0.7
        dashboard.recovery = recovery
        var sleep = dashboard.sleepScore
        sleep.value = 86
        dashboard.sleepScore = sleep

        let insight = ProactiveInsightService.evaluate(dashboard: dashboard)
            .first { $0.focus == .training }

        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.title.contains("按计划训练") == true)
        XCTAssertFalse(insight?.coachPresetQuestion.contains("挑战性") == true)
        XCTAssertFalse(insight?.suggestedAction?.contains("渐进超负荷") == true)
    }

    func testLowHRVInsightFramesSignalWithoutPhysiologicalDiagnosis() {
        let previousLanguage = AppLanguage.stored
        defer { AppLanguage.stored = previousLanguage }
        AppLanguage.stored = .simplifiedChinese

        var dashboard = DashboardSummary.preview(date: Date())
        var recovery = dashboard.recovery
        recovery.components["hrv_z_score"] = -1.8
        dashboard.recovery = recovery

        let insight = ProactiveInsightService.evaluate(dashboard: dashboard)
            .first { $0.focus == .recovery }

        XCTAssertNotNil(insight)
        XCTAssertTrue(insight?.body.contains("恢复信号") == true)
        XCTAssertFalse(insight?.body.contains("高压力输出") == true)
        XCTAssertFalse(insight?.body.contains("收益会比风险低") == true)
        XCTAssertTrue(insight?.suggestedAction?.contains("若有不适") == true)
    }

    func testStrainScoreEngineProducesValidRange() {
        let engine = StrainScoreEngine()
        let input = StrainScoreInput(
            workouts: [WorkoutInput(durationMinutes: 45, averageHeartRate: 140, rpe: 6)],
            activeEnergyToday: 500,
            exerciseMinutesToday: 45,
            restingHR: 60,
            maxHR: 180,
            last28DaysDailyLoads: []
        )
        let result = engine.calculate(from: input)
        XCTAssertGreaterThanOrEqual(result.value ?? 0, 0)
        XCTAssertLessThanOrEqual(result.value ?? 0, 100)
    }

    func testStrainScoreDoesNotInventHeartRateReserveWithoutProfile() {
        let result = StrainScoreEngine().calculate(from: StrainScoreInput(
            workouts: [WorkoutInput(durationMinutes: 40, averageHeartRate: 145)],
            activeEnergyToday: 320,
            exerciseMinutesToday: 40,
            restingHR: 0,
            maxHR: 0,
            last28DaysDailyLoads: []
        ))

        XCTAssertTrue(result.reasons.contains { $0.contains("心率数据未用于个体化负荷计算") })
        XCTAssertTrue(result.reasons.contains { $0.contains("尚未形成个人历史负荷基线") })
    }

    func testBodyStateKernelProvidesFallbackWithoutHealthKit() {
        let now = Date()
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .empty(date: now),
            activeStatus: "active",
            generatedAt: now
        ))

        XCTAssertEqual(bodyState.readiness, .unknown)
        XCTAssertEqual(bodyState.confidence, .low)
        XCTAssertEqual(bodyState.freshness, .missing)
        XCTAssertFalse(bodyState.drivers.isEmpty)
        XCTAssertFalse(bodyState.hash.isEmpty)
    }

    func testBodyStateKernelIncludesLocalFatigueAndTrainingResponseDrivers() {
        let now = Date()
        let workout = StrengthWorkoutRecord(
            title: "Leg Day",
            startedAt: now.addingTimeInterval(-6 * 3600),
            durationMinutes: 60,
            exercises: [
                StrengthExerciseLog(
                    name: "Squat",
                    equipment: "barbell",
                    primaryMuscleGroup: "legs",
                    sets: (0..<14).map { _ in
                        StrengthSetLog(repetitions: 8, weightKilograms: 100, rpe: 8, isCompleted: true)
                    }
                )
            ]
        )
        let response = TrainingResponseRecord(
            workoutId: UUID(),
            date: now.addingTimeInterval(-2 * 86_400),
            nextDayDate: now.addingTimeInterval(-86_400),
            primaryMuscleGroups: ["legs"],
            totalEffectiveSets: 12,
            totalVolumeKg: 9_600,
            nextDayRecoveryDelta: -10
        )

        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(date: now),
            strengthWorkouts: [workout],
            trainingResponses: [response],
            activeStatus: "active",
            generatedAt: now
        ))

        XCTAssertEqual(bodyState.localFatigue["legs"]?.fatigueLevel, "high")
        XCTAssertTrue(bodyState.drivers.contains { $0.kind == .localFatigue })
        XCTAssertTrue(bodyState.drivers.contains { $0.kind == .trainingResponse })
    }

    func testBodyStateAndTrainingDecisionUseChineseUserFacingCopy() {
        let now = Date()
        let response = TrainingResponseRecord(
            workoutId: UUID(),
            date: now.addingTimeInterval(-2 * 86_400),
            nextDayDate: now.addingTimeInterval(-86_400),
            primaryMuscleGroups: ["legs"],
            totalEffectiveSets: 12,
            totalVolumeKg: 9_600,
            nextDayRecoveryDelta: -10,
            nextDayHRVDelta: -12,
            nextDayRHRDelta: 6
        )

        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(date: now),
            trainingResponses: [response],
            activeStatus: "active",
            generatedAt: now
        ))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))
        let model = TodayExperienceModel.build(
            dashboard: .preview(date: now),
            bodyState: bodyState,
            trainingDecision: decision,
            generatedAt: now
        )
        let userFacingText = (
            [decision.userFacingSummary, decision.safetyNotice]
            + decision.reasons
            + bodyState.drivers.flatMap { [$0.title, $0.detail] }
            + model.evidenceChips
            + [model.hero.summary, model.coachPreview]
        ).joined(separator: " ")

        XCTAssertFalse(userFacingText.contains("Recent training response"))
        XCTAssertFalse(userFacingText.contains("A legs session"))
        XCTAssertFalse(userFacingText.contains("Reduce planned volume"))
        XCTAssertFalse(userFacingText.contains("not a medical diagnosis"))
        XCTAssertTrue(userFacingText.contains("训练响应"))
        XCTAssertTrue(userFacingText.contains("减量"))
    }

    func testTodayExperienceDoesNotExposeLegacyEnglishDecisionCopy() {
        let previousLanguage = AppLanguage.stored
        AppLanguage.stored = .english
        defer { AppLanguage.stored = previousLanguage }

        let now = Date()
        let dashboard = DashboardSummary.preview(date: now)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            activeStatus: "active",
            generatedAt: now
        ))
        let legacyDecision = DailyTrainingDecision(
            decision: .swap,
            targetSessionTitle: nil,
            volumeMultiplier: 0.65,
            intensityCap: 7,
            reasons: [
                "back local fatigue: 14 effective sets in 48h and 20 in 7d.",
                "Recent training response: back local fatigue."
            ],
            userFacingSummary: "Swap away from back and keep the session controlled.",
            confidence: 0.75,
            source: "legacy",
            safetyNotice: "General guidance only."
        )

        let model = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: legacyDecision,
            generatedAt: now
        )
        let rendered = ([model.hero.summary, model.coachPreview] + model.evidenceChips)
            .joined(separator: " ")

        XCTAssertTrue(rendered.contains("替换"))
        XCTAssertFalse(rendered.contains("Swap away"))
        XCTAssertFalse(rendered.contains("back local fatigue"))
    }

    func testTrainingDecisionKernelRestsForSickStatus() {
        let now = Date()
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(date: now),
            activeStatus: "sick",
            generatedAt: now
        ))

        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        XCTAssertEqual(decision.decision, .rest)
        XCTAssertEqual(decision.volumeMultiplier, 0)
        XCTAssertLessThanOrEqual(decision.intensityCap, 2)
        XCTAssertTrue(decision.safetyNotice.contains("不构成医疗诊断"))
    }

    func testLegacyTrainingDecisionIsACompatibilityViewOfCanonicalDecision() {
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: .preview(),
            activeStatus: "active"
        ))
        let canonical = DailyTrainingDecision(
            decision: .reduce,
            targetSessionTitle: "Upper Strength",
            volumeMultiplier: 0.72,
            intensityCap: 7,
            reasons: ["Sleep: below baseline"],
            userFacingSummary: "建议减量训练。",
            confidence: 0.75,
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "一般健康与训练建议，不构成医疗诊断。"
        )

        let compatibility = TrainingDecision.compatibilityView(
            of: canonical,
            bodyState: bodyState
        )

        XCTAssertEqual(compatibility.kind, .maintain)
        XCTAssertEqual(compatibility.volumeMultiplier, canonical.volumeMultiplier)
        XCTAssertEqual(compatibility.maxIntensity, "RPE 7")
        XCTAssertEqual(compatibility.whyThis, canonical.reasons.joined(separator: " "))
        XCTAssertEqual(compatibility.body, canonical.userFacingSummary)
    }

    func testTodayExperienceModelTurnsHealthyDashboardIntoActionableCommandCenter() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var dashboard = DashboardSummary.preview(date: now)
        dashboard.recovery.value = 82
        dashboard.sleepScore.value = 86
        dashboard.strain.value = 44
        dashboard.stress.value = 32
        dashboard.energy.value = 76
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            activeStatus: "active",
            generatedAt: now
        ))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        let model = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: decision,
            generatedAt: now,
            nutrition: .init(calories: 1_420, calorieTarget: 2_100, protein: 118, carbs: 168, fat: 42)
        )

        XCTAssertEqual(model.hero.scoreTitle, "恢复 82")
        XCTAssertEqual(model.hero.decisionTitle, "按计划训练")
        XCTAssertEqual(model.hero.primaryActionTitle, "开始今日训练")
        XCTAssertEqual(model.signalCards.map(\.id), ["recovery", "sleep", "strain", "stress", "energy"])
        XCTAssertTrue(model.signalCards.allSatisfy { $0.trend.isEmpty })
        XCTAssertEqual(model.actions.count, 3)
        XCTAssertTrue(model.actions[0].title.contains("训练"))
        XCTAssertTrue(model.coachPreview.contains("置信度"))
        XCTAssertEqual(model.nutrition.calorieProgress, 0.676, accuracy: 0.001)
    }

    func testTodayExperienceModelIsConservativeWhenHealthDataIsMissing() {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        let dashboard = DashboardSummary.empty(date: now)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            activeStatus: "active",
            generatedAt: now
        ))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        let model = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: decision,
            generatedAt: now,
            nutrition: .empty
        )

        XCTAssertEqual(model.hero.scoreTitle, "恢复 --")
        XCTAssertEqual(model.hero.decisionTitle, "先保守减量")
        XCTAssertEqual(model.hero.confidenceLabel, "置信度 0% · 数据不足")
        XCTAssertTrue(model.evidenceChips.contains("等待 HealthKit"))
        XCTAssertEqual(model.actions.first?.title, "同步健康数据")
        XCTAssertEqual(model.signalCards.filter { $0.value == "--" }.count, 5)
        XCTAssertTrue(model.signalCards.allSatisfy { $0.trend.isEmpty })
    }

    func testTodayExperienceNutritionClampsProgressAndExplainsUnsetTarget() {
        let overTarget = TodayExperienceNutrition(
            calories: 2_600,
            calorieTarget: 2_100,
            protein: 140,
            carbs: 260,
            fat: 74
        )
        let unsetTarget = TodayExperienceNutrition(
            calories: 840,
            calorieTarget: 0,
            protein: 42,
            carbs: 92,
            fat: 28
        )

        XCTAssertEqual(overTarget.calorieProgress, 1.0)
        XCTAssertEqual(unsetTarget.calorieProgress, 0.0)
        XCTAssertEqual(unsetTarget.calorieText, "840 kcal · 目标未设置")

        let noLogYet = TodayExperienceNutrition(
            calories: 0,
            calorieTarget: 2_000,
            protein: 0,
            carbs: 0,
            fat: 0
        )
        XCTAssertEqual(noLogYet.calorieText, "今日未记录")
        XCTAssertEqual(noLogYet.macroText, "今日营养尚未记录")
    }

    func testTodayExperienceActionPlanMapsEveryTrainingDecision() throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        var dashboard = DashboardSummary.preview(date: now)
        dashboard.recovery.value = 82
        dashboard.sleepScore.value = 86
        dashboard.strain.value = 44
        dashboard.stress.value = 32
        dashboard.energy.value = 76
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            activeStatus: "active",
            generatedAt: now
        ))

        let expectations: [(DailyTrainingDecisionType, String, String, String)] = [
            (.keep, "开始今日训练", "start_training", "training"),
            (.reduce, "减量训练", "reduce_training", "training"),
            (.swap, "替换训练内容", "swap_session", "training"),
            (.rest, "执行恢复日", "recovery_day", "recovery")
        ]

        for (type, title, actionID, destination) in expectations {
            let decision = DailyTrainingDecision(
                decision: type,
                targetSessionTitle: nil,
                volumeMultiplier: type == .keep ? 1.0 : 0.65,
                intensityCap: type == .rest ? 2 : 7,
                reasons: ["Test evidence"],
                userFacingSummary: "Test summary",
                confidence: 0.75,
                source: "test",
                safetyNotice: "test"
            )
            let model = TodayExperienceModel.build(
                dashboard: dashboard,
                bodyState: bodyState,
                trainingDecision: decision,
                generatedAt: now
            )
            let primary = try XCTUnwrap(model.actions.first(where: \.isPrimary))

            XCTAssertEqual(primary.title, title)
            XCTAssertEqual(primary.id, actionID)
            XCTAssertEqual(primary.destination, destination)
        }
    }

    func testTrainingSurfaceSummaryPrefersOperatingPlanPayload() {
        let dashboard = DashboardSummary.preview()
        let bodyState = BodyStateKernel().build(input: BodyStateInput(dashboard: dashboard))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))
        let today = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: decision
        )
        let payload = DailyOperatingPlanPayload(
            decision: .reduce,
            volumeMultiplier: 0.75,
            intensityCap: 7,
            summary: "Reduce today by 25% and keep RPE under 7.",
            targetSessionTitle: "Upper strength"
        )

        let model = TrainingSurfaceSummaryModel.build(
            dashboard: dashboard,
            todayExperience: today,
            trainingDecision: decision,
            operatingPlan: payload
        )

        XCTAssertEqual(model.decision, .reduce)
        XCTAssertEqual(model.sessionTitle, "Upper strength")
        XCTAssertTrue(model.guidance.contains("25%"))
        XCTAssertEqual(model.intensityCapText, "RPE <= 7")
    }

    func testTrainingSurfaceSummaryStaysConservativeWithoutHealthData() {
        let dashboard = DashboardSummary.empty(date: Date(timeIntervalSince1970: 1_781_654_400))
        let bodyState = BodyStateKernel().build(input: BodyStateInput(dashboard: dashboard))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))
        let today = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: decision
        )

        let model = TrainingSurfaceSummaryModel.build(
            dashboard: dashboard,
            todayExperience: today,
            trainingDecision: decision,
            operatingPlan: nil
        )

        XCTAssertEqual(model.confidenceLabel, "数据不足")
        XCTAssertTrue(model.guidance.contains("保守"))
        XCTAssertEqual(model.recoveryValue, "--")
        XCTAssertEqual(model.sleepValue, "--")
    }

    func testDailyOperatingPlanDisplayModelLocalizesChineseTrainingFallbacks() {
        let payload = DailyOperatingPlanPayload(
            decision: .reduce,
            volumeMultiplier: 0.75,
            intensityCap: 7,
            summary: "建议减量训练，动作质量下降时停止加量。",
            targetSessionTitle: nil
        )

        let model = DailyOperatingPlanDisplayModel.build(
            payload: payload,
            primaryActionType: "reduce",
            source: "BodyStateKernel + TrainingDecisionKernel",
            safetyNotice: "一般健康与训练建议，不构成医疗诊断。",
            confidence: 0.5,
            isChinese: true
        )

        XCTAssertEqual(model.actionLabel, "减量")
        XCTAssertEqual(model.statusTitle, "建议训练 · RPE 7")
        XCTAssertTrue(model.summary.contains("75%"))
        XCTAssertTrue(model.summary.contains("动作质量下降"))
        XCTAssertFalse(model.summary.contains("Reduce"))
        XCTAssertFalse(model.evidenceLine.contains("BodyStateKernel"))
        XCTAssertFalse(model.evidenceLine.contains("medical diagnosis"))
        XCTAssertTrue(model.evidenceLine.contains("本地身体状态"))
        XCTAssertEqual(model.confidenceLabel, "置信度 50%")
    }
}
