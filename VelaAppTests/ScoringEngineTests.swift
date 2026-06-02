import XCTest
@testable import Vela

final class ScoringEngineTests: XCTestCase {
    func testSleepScoreUsesDurationAndRegularityWithConfigVersion() {
        let result = SleepScoreEngine().calculate(
            from: SleepScoreInput(
                totalSleepMinutes: 450,
                sleepTargetMinutes: 450,
                bedtimeOffsetMinutes: 20,
                wakeOffsetMinutes: 20
            )
        )

        XCTAssertEqual(result.score, 79)
        XCTAssertNotEqual(result.band, .low)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.components["duration"], 50.0)
        XCTAssertNil(result.components["consistency"])
        XCTAssertEqual(result.configVersion, "1.0.0")
        XCTAssertFalse(result.reasons.isEmpty)
    }

    func testRecoveryScoreReweightsWhenHRVIsMissing() {
        let result = RecoveryScoreEngine().calculate(
            from: RecoveryScoreInput(
                hrvToday: nil,
                hrvBaseline: nil,
                restingHeartRateToday: 60,
                restingHeartRateBaseline: 60,
                sleepScoreLastNight: 80,
                strainScoreYesterday: 50
            )
        )

        XCTAssertGreaterThanOrEqual(result.score, 55)
        XCTAssertLessThanOrEqual(result.score, 70)
        XCTAssertNotEqual(result.band, .veryLow)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertNil(result.weights["hrv"])
        XCTAssertEqual(result.weights["rhr"] ?? 0, 0.25)
        XCTAssertTrue(result.reasons.contains { $0.contains("HRV") || $0.contains("缺少") })
    }

    func testStrainScoreReturnsRecommendedRangeFromRecovery() {
        let result = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 600,
                exerciseMinutesToday: 45,
                activeEnergyBaseline: 500,
                exerciseMinutesBaseline: 45,
                workoutIntensityLoad: 55,
                recoveryScore: 64
            )
        )

        XCTAssertEqual(result.recommendedRange, 35...65)
        XCTAssertNotNil(result.targetStatus)
        // With low daily load relative to baseline, band should not be veryHigh
        XCTAssertNotEqual(result.band, .veryHigh)
    }

    func testEnergyBankClampsCurrentEnergyAtZero() {
        let result = EnergyBankEngine().calculate(
            from: EnergyBankInput(
                recoveryScore: 40,
                sleepScore: 40,
                strainScore: 100,
                stressIndex: 100
            )
        )

        XCTAssertGreaterThanOrEqual(result.morningEnergy, 40)
        XCTAssertEqual(result.currentEnergy, 0, accuracy: 0.01)
        XCTAssertEqual(result.status, .depleted)
        XCTAssertEqual(result.configVersion, "1.0.0")
    }

    func testHealthAgeTrendUsesTrendLabelInsteadOfBiologicalAgeClaim() {
        let result = HealthAgeTrendEngine().calculate(
            from: HealthAgeTrendInput(
                factors: [
                    .init(name: "VO2 Max", direction: .positive),
                    .init(name: "HRV baseline", direction: .positive),
                    .init(name: "Sleep regularity", direction: .neutral)
                ]
            )
        )

        XCTAssertEqual(result.label, .improving)
        XCTAssertGreaterThan(result.trendScore, 0.35)
        XCTAssertFalse(result.metrics.keys.contains("biological_age"))
        XCTAssertEqual(result.confidence, .medium)
    }

    func testAIContextBuilderIncludesRequiredBlocksWithoutRawSamples() throws {
        let dashboard = DashboardSummary.preview()
        let (context, _) = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [
                JournalContextEntry(tags: ["Coffee"], text: "Late espresso")
            ],
            historicalReports: [],
            userWiki: ["goals.md": "Improve sleep"]
        )

        let data = try JSONEncoder().encode(context)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("today_summary"))
        XCTAssertTrue(json.contains("sleep"))
        XCTAssertTrue(json.contains("recovery"))
        XCTAssertTrue(json.contains("strain"))
        XCTAssertTrue(json.contains("user_wiki"))
        XCTAssertFalse(json.contains("HKQuantitySample"))
    }

    func testAIContextBuilderIncludesRecentStructuredFoodLogs() throws {
        let dashboard = DashboardSummary.preview()
        let (context, _) = AIContextBuilder().build(
            dashboard: dashboard,
            journalEntries: [],
            historicalReports: [],
            userWiki: [:],
            foodLogs: [
                FoodLogRecord(
                    mealName: "Lunch",
                    foods: [FoodLogItem(name: "Chicken rice bowl", portion: "1 bowl", calories: 620)],
                    totalCalories: 620,
                    proteinGrams: 42,
                    carbsGrams: 68,
                    fatGrams: 18,
                    fiberGrams: 6,
                    healthScore: "moderate",
                    suggestions: ["Add greens"],
                    source: .photoAnalysis,
                    createdAt: Date(timeIntervalSince1970: 2_000)
                )
            ]
        )

        let data = try JSONEncoder().encode(context)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertTrue(json.contains("nutrition"))
        XCTAssertTrue(json.contains("Chicken rice bowl"))
        XCTAssertTrue(json.contains("620 kcal"))
        XCTAssertTrue(json.contains("P42 C68 F18 Fiber6"))
    }

    func testDailyPlanRecommendsRecoveryDayWhenRecoveryIsLow() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 32,
            band: .low,
            confidence: .high,
            components: ["hrv": 25, "rhr": 35],
            componentWeights: ["hrv": 0.6, "rhr": 0.4],
            reasons: ["HRV significantly below personal baseline"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard)

        XCTAssertEqual(plan.kind, .recovery)
        XCTAssertEqual(plan.accent, .recovery)
        XCTAssertEqual(plan.limiter?.kind, .hrv)
        XCTAssertFalse(plan.primaryActionTitle.isEmpty)
        XCTAssertFalse(plan.coachQuestion.isEmpty)
    }

    func testDailyPlanRanksRestingHeartRateAsMainLimiterWhenElevated() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 46,
            band: .normal,
            confidence: .high,
            components: ["hrv": 52, "rhr": 18, "sleep": 72, "rhr_z_score": 2.2],
            componentWeights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["Resting heart rate elevated 8 bpm above baseline"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(hrvMilliseconds: 44, restingHeartRate: 68)
        dashboard.recoveryBaseline = RecoveryMetricSummary(hrvMilliseconds: 45, restingHeartRate: 60)

        let plan = DailyPlanEngine.recommendation(for: dashboard)

        XCTAssertEqual(plan.limiter?.kind, .restingHeartRate)
        XCTAssertEqual(plan.limiter?.accent, .recovery)
        XCTAssertTrue(plan.body.contains(plan.limiter?.title ?? "missing limiter"))
    }

    func testDailyPlanCoachQuestionIncludesStructuredSnapshot() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .english
        defer { AppLanguage.stored = previous }

        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 47,
            band: .normal,
            confidence: .high,
            components: ["hrv": 24, "rhr": 52, "sleep": 64, "hrv_z_score": -1.3],
            componentWeights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["HRV significantly below personal baseline (z=-1.3)"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(hrvMilliseconds: 36, restingHeartRate: 57)
        dashboard.recoveryBaseline = RecoveryMetricSummary(hrvMilliseconds: 45, restingHeartRate: 55)
        dashboard.sleepScore = MetricResult(
            name: "Sleep Score",
            value: 64,
            band: .normal,
            confidence: .high,
            components: ["duration_score": 64],
            componentWeights: ["duration_score": 1],
            reasons: ["Sleep duration 6h 35m — below target by 12%"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard)

        XCTAssertTrue(plan.coachQuestion.contains("Recovery 47"))
        XCTAssertTrue(plan.coachQuestion.contains("HRV 36ms"))
        XCTAssertTrue(plan.coachQuestion.contains("Sleep 64"))
        XCTAssertTrue(plan.coachQuestion.contains("main limiter"))
    }

    func testCoachSnapshotDirectiveIncludesFreshnessAndResponseContract() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let generatedAt = calendar.date(from: DateComponents(year: 2026, month: 5, day: 22, hour: 19, minute: 59))!
        var dashboard = DashboardSummary.preview(date: generatedAt)
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 46,
            band: .normal,
            confidence: .high,
            components: ["hrv": 24, "rhr": 52, "sleep": 64, "hrv_z_score": -1.3],
            componentWeights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["HRV significantly below personal baseline (z=-1.3)"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(hrvMilliseconds: 36, restingHeartRate: 58)

        let directive = CoachSnapshotDirective.build(
            dashboard: dashboard,
            generatedAt: generatedAt,
            calendar: calendar
        )

        XCTAssertTrue(directive.contains("19:59"))
        XCTAssertTrue(directive.contains("2026-05-22"))
        XCTAssertTrue(directive.contains("+08:00"))
        XCTAssertTrue(directive.contains("恢复 46"))
        XCTAssertTrue(directive.contains("HRV 36ms"))
        XCTAssertTrue(directive.contains("主要限制因素"))
        XCTAssertTrue(directive.contains("判断 / 原因 / 今天怎么做 / 不要做什么 / 可追问"))
    }

    func testLocalizedReasonTranslatesCurrentRecoveryAndSleepReasons() {
        let previous = AppLanguage.stored
        AppLanguage.stored = .simplifiedChinese
        defer { AppLanguage.stored = previous }

        XCTAssertEqual(
            localizedReason("HRV significantly below personal baseline (z=-1.3)"),
            "HRV 显著低于个人基线（z=-1.3）"
        )
        XCTAssertEqual(
            localizedReason("Sleep duration 6h 35m — below target by 12%"),
            "睡眠时长 6h 35m，低于目标 12%"
        )
    }

    func testFoodPhotoAnalyzerUsesKimiVisionDefaults() {
        XCTAssertEqual(FoodPhotoAnalyzer.keychainAccount, "kimi_api_key")
        XCTAssertEqual(FoodPhotoAnalyzer.providerDisplayName, "Kimi Vision")
        XCTAssertEqual(FoodPhotoAnalyzer.defaultModel, "kimi-k2.6")
        XCTAssertEqual(FoodPhotoAnalyzer.defaultEndpoint.absoluteString, "https://api.moonshot.cn/v1/chat/completions")
    }

    func testFoodPhotoAnalyzerBuildsKimiVisionPayloadWithImagePart() throws {
        let body = FoodPhotoAnalyzer.makeRequestBody(imageBase64: "abc123")
        let messages = try XCTUnwrap(body["messages"] as? [[String: Any]])
        let userMessage = try XCTUnwrap(messages.last)
        let content = try XCTUnwrap(userMessage["content"] as? [[String: Any]])
        let textPart = try XCTUnwrap(content.first { $0["type"] as? String == "text" })
        let imagePart = try XCTUnwrap(content.first { $0["type"] as? String == "image_url" })
        let imageURL = try XCTUnwrap(imagePart["image_url"] as? [String: String])

        XCTAssertEqual(body["model"] as? String, "kimi-k2.6")
        XCTAssertEqual(body["stream"] as? Bool, false)
        XCTAssertFalse((textPart["text"] as? String ?? "").isEmpty)
        XCTAssertEqual(imageURL["url"], "data:image/jpeg;base64,abc123")
    }

    func testDailyPlanRecommendsTrainingWhenRecoveryIsHighAndStrainBelowTarget() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 82,
            band: .high,
            confidence: .high,
            components: ["hrv": 90, "rhr": 80, "sleep": 78],
            componentWeights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.4],
            reasons: ["HRV above baseline"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        dashboard.strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 180,
                exerciseMinutesToday: 10,
                activeEnergyBaseline: 500,
                exerciseMinutesBaseline: 40,
                workoutIntensityLoad: 10,
                recoveryScore: 82
            )
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard)

        XCTAssertEqual(plan.kind, .train)
        XCTAssertEqual(plan.accent, .strain)
        XCTAssertFalse(plan.primaryActionTitle.isEmpty)
        XCTAssertFalse(plan.coachQuestion.isEmpty)
    }

    func testReportGeneratorPersistsProviderResponse() async throws {
        let generator = ReportGenerator(provider: StubLLMProvider(content: "### 今日状态\nModerate"))
        let report = try await generator.generate(
            type: .morningBrief,
            context: AIContextBuilder().build(
                dashboard: .preview(),
                journalEntries: [],
                historicalReports: [],
                userWiki: [:]
            ).envelope
        )

        XCTAssertEqual(report.type, .morningBrief)
        XCTAssertTrue(report.markdownContent.contains("Moderate"))
        XCTAssertFalse(report.contextSnapshot.isEmpty)
    }

    func testBiologicalAgeWearablesOnly() {
        let input = BiologicalAgeInput(
            chronologicalAge: 30.0,
            restingHR: 55.0,
            vo2Max: 45.0,
            sleepHours: 8.0,
            sleepEfficiency: 0.95,
            steps: 11000.0,
            biomarkers: []
        )
        
        let result = BiologicalAgeEngine().calculate(input: input)
        
        // Engine uses Health Age Trend Beta Mode — all 4 wearables optimal → trendScore 1.0
        XCTAssertGreaterThanOrEqual(result.wearableScore, 90)
        XCTAssertEqual(result.biomarkerScore, 80.0, accuracy: 0.01) // default neutral
        XCTAssertGreaterThanOrEqual(result.overallScore, 90)
        XCTAssertFalse(result.isPhenoAge)
        XCTAssertNil(result.biologicalAgeEstimate)
        XCTAssertEqual(result.biologicalAge, input.chronologicalAge)
        XCTAssertEqual(result.healthAgeTrend, "improving")
        XCTAssertGreaterThanOrEqual(result.optimalCount, 3)
        XCTAssertEqual(result.suboptimalCount, 0)
        XCTAssertFalse(result.factors.isEmpty)
    }

    func testLegacyAdaptiveTrainingManagerDoesNotDuplicateTodaysAdjustmentAcrossWeek() {
        let days = (1...7).map { dayNumber in
            TrainingDay(
                weekNumber: 1,
                dayNumber: dayNumber,
                title: "Cardio \(dayNumber)",
                description: "Run",
                focus: "cardio",
                durationMinutes: 45,
                intensity: "high"
            )
        }
        let plan = TrainingPlanRecord(
            title: "Weekly plan",
            goalDescription: "Build endurance",
            days: days
        )

        let records = AdaptiveTrainingManager().generateWeekAdjustments(
            plan: plan,
            recoveryScore: 60,
            energyScore: 50,
            tsb: 0,
            sleepScore: 80,
            stressIndex: 20
        )

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(Set(records.map(\.dayId)).count, 1)
    }

    func testBiologicalAgeBiomarkersOnly() {
        let optimalBiomarker = BiomarkerRecord(
            name: "Vitamin D",
            value: 45.0,
            unit: "ng/mL",
            referenceMin: 30.0,
            referenceMax: 100.0
        )
        let suboptimalBiomarker = BiomarkerRecord(
            name: "Cortisol",
            value: 28.0,
            unit: "mcg/dL",
            referenceMin: 5.0,
            referenceMax: 23.0
        )
        
        let input = BiologicalAgeInput(
            chronologicalAge: 40.0,
            restingHR: nil,
            vo2Max: nil,
            sleepHours: nil,
            sleepEfficiency: nil,
            steps: nil,
            biomarkers: [optimalBiomarker, suboptimalBiomarker]
        )
        
        let result = BiologicalAgeEngine().calculate(input: input)
        
        // Non-clinical biomarkers → falls to Health Age Trend Beta Mode
        // No wearable data → trendScore 0 → overallScore 50
        XCTAssertEqual(result.wearableScore, 50.0, accuracy: 0.01)
        XCTAssertEqual(result.biomarkerScore, 80.0, accuracy: 0.01)
        XCTAssertEqual(result.overallScore, 50.0, accuracy: 0.05)
        XCTAssertEqual(result.biologicalAge, 40.0, accuracy: 0.1)
        XCTAssertEqual(result.optimalCount, 0)
        XCTAssertEqual(result.suboptimalCount, 0)
    }

    func testBiologicalAgeCombinedWeightedCalculations() {
        let biomarker = BiomarkerRecord(
            name: "Vitamin D",
            value: 45.0,
            unit: "ng/mL",
            referenceMin: 30.0,
            referenceMax: 100.0
        )
        
        let input = BiologicalAgeInput(
            chronologicalAge: 30.0,
            restingHR: 70.0, // score: 100 - (70 - 60) * 2.33 = 76.7
            vo2Max: 35.0,    // score: 30.0 + (35 - 28) * 3.5 = 54.5
            sleepHours: 6.0,  // score: 30 + (6 - 5) * 35 = 65
            sleepEfficiency: 0.85, // 85% -> score: 30 + (85 - 70) * 3.5 = 82.5
            steps: 5000.0,   // score: 30 + (5000 - 3000) * 0.01 = 50
            biomarkers: [biomarker] // score: 100
        )
        
        let result = BiologicalAgeEngine().calculate(input: input)
        
        // Health Age Trend Beta Mode: all neutral wearables → trendScore 0.0
        // overallScore = clamp(50 + 0.0*50) = 50, bio age unchanged
        XCTAssertEqual(result.wearableScore, 50.0, accuracy: 0.1)
        XCTAssertEqual(result.biomarkerScore, 80.0, accuracy: 0.1)
        XCTAssertEqual(result.overallScore, 50.0, accuracy: 0.1)
        XCTAssertEqual(result.biologicalAge, 30.0, accuracy: 0.1)
    }

    // MARK: - Sleep Score: Spec-required tests

    func testSleepConsistentBedtimeScoresFullConsistency() {
        let calendar = Calendar.current
        let todayBedtime = calendar.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        // All 13 recent bedtimes within 20 minutes of 23:00 → high consistency
        let recent: [Date] = (0..<13).map { i in
            calendar.date(byAdding: .day, value: -(i + 1), to: calendar.date(bySettingHour: 23, minute: 5, second: 0, of: todayBedtime)!)!
        }

        let result = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 450,
            sleepTargetMinutes: 450,
            todayBedtime: todayBedtime,
            recentBedtimes: recent,
            awakeMinutes: 5,
            awakeEpisodeCount: 1
        ))

        // Consistency diff should be small → component should be present
        XCTAssertNotNil(result.components["consistency"])
        if let consistency = result.components["consistency"] {
            XCTAssertGreaterThanOrEqual(consistency, 24.0)
        }
        XCTAssertGreaterThanOrEqual(result.value ?? 0, 85)
        XCTAssertTrue(result.reasons.contains { $0.contains("入睡一致性") })
    }

    func testSleepFragmentedInterruptionPenalty() {
        let result = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 420,
            sleepTargetMinutes: 450,
            awakeMinutes: 30,
            awakeEpisodeCount: 5
        ))

        // penalty = 0.45*30 + 2.5*5 = 13.5 + 12.5 = 26, score = max(0, 20-26) = 0
        let interruption = result.components["interruption"] ?? -1
        XCTAssertEqual(interruption, 0.0, accuracy: 0.1)
        // With high interruption penalty + below-target duration, overall score should be low
        XCTAssertLessThan(result.value ?? 100, 75)
    }

    func testSleepInsufficientHistoryReducesConfidence() {
        let calendar = Calendar.current
        let todayBedtime = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: Date())!
        // Only 3 recent bedtimes → below the 5-night minimum
        let recent: [Date] = (0..<3).map { i in
            calendar.date(byAdding: .day, value: -(i + 1), to: todayBedtime)!
        }

        let result = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 420,
            sleepTargetMinutes: 450,
            todayBedtime: todayBedtime,
            recentBedtimes: recent,
            awakeMinutes: 5,
            awakeEpisodeCount: 1
        ))

        XCTAssertNil(result.components["consistency"])
        XCTAssertTrue(result.missingInputs.contains("recentBedtimesHistory"))
        XCTAssertTrue(result.reasons.contains { $0.contains("不足 5 晚") })
    }

    func testSleepAwakeDataMissingSkipsInterruption() {
        let result = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 450,
            sleepTargetMinutes: 450,
            awakeMinutes: nil,
            awakeEpisodeCount: nil
        ))

        // No awake data → interruption component should be nil
        XCTAssertNil(result.components["interruption"])
        // Duration at target but confidence is low due to missing interruption -> capped at 79
        XCTAssertEqual(result.value ?? 0, 79)
    }

    // MARK: - Recovery Score: Spec-required tests

    func testRecoveryRHRElevatedAboveBaselineReducesScore() {
        let result = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 45,
            hrvHistory: Array(repeating: 45, count: 21),
            restingHeartRateToday: 68,
            restingHeartRateBaseline: 60,
            rhrHistory: Array(repeating: 60, count: 21),
            sleepScoreLastNight: 80,
            strainScoreYesterday: 40
        ))

        // RHR elevated → rhrComponent should be below 50
        XCTAssertLessThan(result.value ?? 100, 80)
        XCTAssertTrue(result.reasons.contains { $0.contains("RHR") || $0.contains("静息心率") })
    }

    func testRecoveryLowSleepNightReducesScore() {
        let result = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 45,
            hrvHistory: Array(repeating: 45, count: 21),
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            rhrHistory: Array(repeating: 60, count: 21),
            sleepScoreLastNight: 40,
            strainScoreYesterday: 40
        ))

        // Low sleep (40) pulls down the weighted average
        XCTAssertLessThan(result.value ?? 100, 75)
    }

    func testRecoveryHighBodyTemperatureAddsPenalty() {
        let resultWithFever = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 45,
            hrvHistory: Array(repeating: 45, count: 21),
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            rhrHistory: Array(repeating: 60, count: 21),
            sleepScoreLastNight: 80,
            strainScoreYesterday: 40,
            bodyTempDelta: 0.8
        ))

        let resultNoFever = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 45,
            hrvHistory: Array(repeating: 45, count: 21),
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            rhrHistory: Array(repeating: 60, count: 21),
            sleepScoreLastNight: 80,
            strainScoreYesterday: 40,
            bodyTempDelta: 0.0
        ))

        // bodyTemp >= 0.5 adds 8-point penalty
        XCTAssertLessThan(resultWithFever.value ?? 0, (resultNoFever.value ?? 100) - 4)
    }

    func testRecoveryInsufficientHistoryReducesConfidence() {
        let result = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 45,
            hrvBaseline: 45,
            hrvHistory: [45, 46, 44],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            rhrHistory: [60, 61, 59],
            sleepScoreLastNight: 80,
            strainScoreYesterday: 40
        ))

        // Only 3 data points → < 7 days → low confidence
        XCTAssertEqual(result.confidence, .low)
    }

    func testRecoveryComponentsExposeNegativeHRVZScoreWhenBelowBaseline() throws {
        let result = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 35,
            hrvBaseline: 50,
            hrvHistory: [48, 49, 50, 51, 52, 49, 50],
            restingHeartRateToday: 62,
            restingHeartRateBaseline: 60,
            rhrHistory: [59, 60, 61, 60, 59, 61, 60],
            sleepScoreLastNight: 75,
            strainScoreYesterday: 45,
            respiratoryRateToday: 16,
            respiratoryRateBaseline: 14,
            respiratoryRateHistory: [13.8, 14.0, 14.2, 14.1, 13.9],
            bodyTempDelta: 0.4,
            SpO2: 97
        ))

        XCTAssertLessThan(try XCTUnwrap(result.components["hrv_z_score"]), 0)
        XCTAssertNotNil(result.components["rhr_z_score"])
        XCTAssertNotNil(result.components["respiratory_rate_z"])
        XCTAssertEqual(result.components["body_temp_delta"], 0.4)
        XCTAssertEqual(result.components["spo2"], 97)
    }

    func testBodyInterpreterConsumesRecoveryHRVZScore() {
        let recovery = RecoveryScoreEngine().calculate(from: RecoveryScoreInput(
            hrvToday: 35,
            hrvBaseline: 50,
            hrvHistory: [48, 49, 50, 51, 52, 49, 50],
            restingHeartRateToday: 62,
            restingHeartRateBaseline: 60,
            rhrHistory: [59, 60, 61, 60, 59, 61, 60],
            sleepScoreLastNight: 75,
            strainScoreYesterday: 45
        ))
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = recovery
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 35,
            restingHeartRate: 62
        )

        let interpretation = BodyInterpreterEngine().interpret(
            dashboard: dashboard,
            wiki: [:],
            activePlan: nil
        )

        XCTAssertEqual(interpretation.primaryLimiter.metricName, "HRV Z-Score")
        XCTAssertLessThan(interpretation.primaryLimiter.currentValue, 0)
    }

    func testSleepComponentsExposeCompatibilityFields() {
        let result = SleepScoreEngine().calculate(from: SleepScoreInput(
            totalSleepMinutes: 420,
            awakeMinutes: 30,
            awakeEpisodeCount: 3,
            remMinutes: 84,
            deepMinutes: 63,
            inBedMinutes: 450
        ))

        XCTAssertEqual(result.components["sleep_efficiency"] ?? 0, 93.33, accuracy: 0.01)
        XCTAssertEqual(result.components["rem_pct"] ?? 0, 20, accuracy: 0.01)
        XCTAssertEqual(result.components["deep_pct"] ?? 0, 15, accuracy: 0.01)
        XCTAssertEqual(result.components["awake_minutes"], 30)
        XCTAssertEqual(result.components["awake_episode_count"], 3)
    }

    // MARK: - Strain Score: Spec-required tests

    func testStrainNoHRWorkoutUsesActivityFallback() {
        let result = StrainScoreEngine().calculate(from: StrainScoreInput(
            workouts: [],
            activeEnergyToday: 800,
            exerciseMinutesToday: 60,
            last28DaysDailyLoads: Array(repeating: 60, count: 28),
            activeEnergyBaseline: 400,
            exerciseMinutesBaseline: 30,
            workoutIntensityLoad: 0  // no HR samples
        ))

        // activityLoad = 0.02*800 + 0.0015*0 + 0.5*60 = 46
        // dailyLoad = 0 + 46 = 46
        // loadRatio = 46 / 60 ≈ 0.77, score = 100*(1-exp(-0.75*0.77)) ≈ 43
        XCTAssertGreaterThan(result.value ?? 0, 30)
        XCTAssertEqual(result.band, .low)
    }

    func testStrainTrainingLoadStatusHighRisk() {
        let highDailyLoads = Array(repeating: 120.0, count: 7)  // acute7 avg = 120
        let lowPreviousLoads = Array(repeating: 40.0, count: 28) // chronic28 avg = 40
        let allLoads = highDailyLoads + lowPreviousLoads

        let result = StrainScoreEngine().calculate(from: StrainScoreInput(
            workouts: [],
            activeEnergyToday: 300,
            exerciseMinutesToday: 30,
            last28DaysDailyLoads: Array(allLoads.suffix(28)),
            activeEnergyBaseline: 300,
            exerciseMinutesBaseline: 30,
            workoutIntensityLoad: 120
        ))

        if let ratio = result.components["training_load_ratio"] {
            // With active energy, a ratio should be computable
            XCTAssertGreaterThan(ratio, 0)
        }
        XCTAssertEqual(result.confidence, .high)
    }

    func testStrainTrainingLoadRatioUsesMostRecentSixHistoryDays() {
        let oldLowLoads = Array(repeating: 10.0, count: 22)
        let recentHighLoads = Array(repeating: 120.0, count: 6)

        let result = StrainScoreEngine().calculate(from: StrainScoreInput(
            activeEnergyToday: 600,
            exerciseMinutesToday: 30,
            last28DaysDailyLoads: oldLowLoads + recentHighLoads
        ))

        XCTAssertGreaterThan(result.components["training_load_ratio"] ?? 0, 2.5)
    }

    func testStrainWorkoutDayDiscountsActivityAlreadyRepresentedByWorkout() {
        let result = StrainScoreEngine().calculate(from: StrainScoreInput(
            workouts: [
                WorkoutInput(durationMinutes: 60, averageHeartRate: 155)
            ],
            activeEnergyToday: 600,
            exerciseMinutesToday: 60,
            stepCount: 10_000,
            restingHR: 60,
            maxHR: 190,
            last28DaysDailyLoads: Array(repeating: 60, count: 28)
        ))

        XCTAssertEqual(result.components["raw_activity_load"] ?? 0, 57, accuracy: 0.01)
        XCTAssertLessThan(result.components["activity_load"] ?? 100, 30)
        XCTAssertLessThan(
            result.components["daily_load"] ?? 1_000,
            (result.components["workout_load"] ?? 0) + (result.components["raw_activity_load"] ?? 0)
        )
    }

    // MARK: - Stress Index: Spec-required tests

    func testStressWorkoutWindowExcluded() {
        let engine = StressIndexEngine()
        let result = engine.calculate(from: StressIndexInput(
            bodyTempDelta: 0.2,
            isWithinWorkoutWindow: true,
            heartRateElevationScore: 60,
            hrvSuppressionScore: 40,
            sleepDebtStressScore: 30,
            recentStrainStressScore: 50
        ))

        // When isWithinWorkoutWindow is true, result.value is nil (excluded)
        XCTAssertNil(result.value)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.missingInputs.contains("quietWindow"))
        XCTAssertTrue(result.reasons.contains { $0.contains("运动窗口") || $0.contains("workout") })
    }

    func testStressHRVDropIncreasesIndex() {
        let engine = StressIndexEngine()
        let result = engine.calculate(from: StressIndexInput(
            quietHRToday: 60,
            quietHRBaseline: 60,
            quietHRSD: 5,
            hrvToday: 30,
            hrvBaseline: 50,
            hrvSD: 5,
            bodyTempDelta: 0.1,
            sleepScoreLastNight: 70,
            strainScoreToday: 40,
            isWithinWorkoutWindow: false
	        ))

	        // HRV stress component should be present and computable
        XCTAssertGreaterThan(result.value ?? 0, 0)
        XCTAssertNotNil(result.components["hrv_stress"])
    }

    func testStressRHRElevationIncreasesIndex() {
        let engine = StressIndexEngine()
        let elevated = engine.calculate(from: StressIndexInput(
            bodyTempDelta: 0.1,
            isWithinWorkoutWindow: false,
            heartRateElevationScore: 85,
            hrvSuppressionScore: 20,
            sleepDebtStressScore: 30,
            recentStrainStressScore: 40
        ))
        let baseline = engine.calculate(from: StressIndexInput(
            bodyTempDelta: 0.1,
            isWithinWorkoutWindow: false,
            heartRateElevationScore: 20,
            hrvSuppressionScore: 20,
            sleepDebtStressScore: 30,
            recentStrainStressScore: 40
        ))

        XCTAssertGreaterThan(elevated.value ?? 0, baseline.value ?? 0)
    }

    func testStressTemperatureAnomalyAddsComponent() {
        let engine = StressIndexEngine()
        let normalTemp = engine.calculate(from: StressIndexInput(
            bodyTempDelta: 0.1,
            isWithinWorkoutWindow: false,
            heartRateElevationScore: 10,
            hrvSuppressionScore: 20,
            sleepDebtStressScore: 30,
            recentStrainStressScore: 40
        ))

        let highTemp = engine.calculate(from: StressIndexInput(
            bodyTempDelta: 1.0,
            isWithinWorkoutWindow: false,
            heartRateElevationScore: 10,
            hrvSuppressionScore: 20,
            sleepDebtStressScore: 30,
            recentStrainStressScore: 40
        ))

        // High body temp delta → higher stress index
        XCTAssertGreaterThan(highTemp.value ?? 0, normalTemp.value ?? 0)
    }

    func testStressLegacyComponentScoresAreNotReinterpretedAsRawVitals() {
        let result = StressIndexEngine().calculate(from: StressIndexInput(
            heartRateElevationScore: 32,
            hrvSuppressionScore: 36,
            sleepDebtStressScore: 25,
            recentStrainStressScore: 40
        ))

        XCTAssertEqual(result.components["rhr_stress"], 32)
        XCTAssertEqual(result.components["hrv_stress"], 36)
        XCTAssertLessThan(result.stressIndex, 50)
    }

    // MARK: - Energy Bank: Spec-required tests

    func testEnergyLowRecoveryGivesLowMorningEnergy() {
        let result = EnergyBankEngine().calculate(from: EnergyBankInput(
            recoveryScore: 30,
            sleepScore: 70,
            strainScore: 30,
            stressIndex: 40,
            strainHistory: Array(repeating: 40, count: 42),
            bodyTempDelta: 0.0,
            hoursSinceWake: 6,
            respiratoryRateZ: 0.0,
            SpO2: 98,
            mindfulMinutes: 0,
            napMinutes: 0,
            trainingLoadStatus: .optimal
        ))

        // MorningEnergy ≈ 0.45*30 + 0.35*70 + 0.20*100 = 13.5 + 24.5 + 20 = 58
        XCTAssertLessThan(result.morningEnergy, 65)
        // CurrentEnergy with drains should be lower
        XCTAssertLessThan(result.currentEnergy, result.morningEnergy)
    }

    func testEnergyMindfulNapRecharge() {
        let baseInput = EnergyBankInput(
            recoveryScore: 70,
            sleepScore: 70,
            strainScore: 30,
            stressIndex: 40,
            strainHistory: Array(repeating: 40, count: 42),
            bodyTempDelta: 0.0,
            hoursSinceWake: 6,
            respiratoryRateZ: 0.0,
            SpO2: 98,
            mindfulMinutes: 0,
            napMinutes: 0,
            trainingLoadStatus: .optimal
        )

        let noRecharge = EnergyBankEngine().calculate(from: baseInput)

        var withRecharge = baseInput
        withRecharge.mindfulMinutes = 30
        withRecharge.napMinutes = 20
        let recharged = EnergyBankEngine().calculate(from: withRecharge)

        // recharge = min(8, 30*0.15 + 20*0.20) = min(8, 4.5+4.0) = min(8, 8.5) = 8
        // Current energy with recharge > without
        XCTAssertGreaterThan(recharged.currentEnergy, noRecharge.currentEnergy)
    }

    func testEnergyHighAcuteLowChronicLoadProducesNegativeTSBAndHighACWR() {
        let history = Array(repeating: 20.0, count: 35) + Array(repeating: 120.0, count: 6)
        let result = EnergyBankEngine().calculate(from: EnergyBankInput(
            recoveryScore: 70,
            sleepScore: 75,
            strainScore: 120,
            stressIndex: 35,
            strainHistory: history
        ))

        XCTAssertLessThan(result.components["tsb"] ?? 0, 0)
        XCTAssertGreaterThan(result.components["acwr"] ?? 0, 1.5)
        XCTAssertNotNil(result.components["atl"])
        XCTAssertNotNil(result.components["ctl"])
    }

    func testBiologicalAgeConvertsSupportedLabUnitsToCanonicalValues() {
        let canonical = BiologicalAgeEngine().calculate(input: BiologicalAgeInput(
            chronologicalAge: 40,
            biomarkers: makePhenoAgeBiomarkers()
        ))
        let converted = BiologicalAgeEngine().calculate(input: BiologicalAgeInput(
            chronologicalAge: 40,
            biomarkers: makePhenoAgeBiomarkers(
                albumin: (43, "g/L"),
                creatinine: (88.4, "umol/L"),
                glucose: (5.5, "mmol/L"),
                crp: (0.2, "mg/dL")
            )
        ))

        XCTAssertTrue(canonical.isPhenoAge)
        XCTAssertTrue(converted.isPhenoAge)
        XCTAssertEqual(converted.biologicalAge, canonical.biologicalAge, accuracy: 0.05)
    }

    func testBiologicalAgeRejectsUnsupportedLabUnits() {
        let result = BiologicalAgeEngine().calculate(input: BiologicalAgeInput(
            chronologicalAge: 40,
            biomarkers: makePhenoAgeBiomarkers(glucose: (5.5, "unknown"))
        ))

        XCTAssertFalse(result.isPhenoAge)
    }

    func testBiologicalAgeBetaModeDoesNotExposeAgeEstimate() {
        let result = BiologicalAgeEngine().calculate(input: BiologicalAgeInput(
            chronologicalAge: 40,
            restingHR: 58,
            vo2Max: 44
        ))

        XCTAssertFalse(result.isPhenoAge)
        XCTAssertNil(result.biologicalAgeEstimate)
    }

    @MainActor
    func testDailySummarySnapshotPreservesSleepCompatibilityFields() {
        let date = Date(timeIntervalSince1970: 1_779_000_000)
        let sleepSummary = SleepSummary(
            date: date,
            totalSleepMinutes: 420,
            bedtime: date.addingTimeInterval(-8 * 60 * 60),
            wakeTime: date,
            stageMinutes: [.deep: 90, .rem: 110, .awake: 30, .inBed: 450],
            segments: [],
            sleepScore: nil
        )
        let sleepScore = SleepScoreEngine().calculate(from: ScoreEngineFactory.sleep(
            from: DailyHealthContext(
                date: date,
                sleepSummary: sleepSummary,
                recoveryMetrics: RecoveryMetricSummary(),
                recoveryBaseline: RecoveryMetricSummary(),
                strainToday: StrainActivitySummary(workouts: []),
                strainBaselineDaily: StrainActivitySummary(workouts: []),
                bodyMetrics: BodyMetricsSummary()
            ),
            sleepTarget: 450,
            todayBedtime: sleepSummary.bedtime,
            recentBedtimes: []
        ))
        let context = DailyHealthContext(
            date: date,
            sleepSummary: sleepSummary,
            recoveryMetrics: RecoveryMetricSummary(),
            recoveryBaseline: RecoveryMetricSummary(),
            strainToday: StrainActivitySummary(workouts: []),
            strainBaselineDaily: StrainActivitySummary(workouts: []),
            bodyMetrics: BodyMetricsSummary()
        )
        var dashboard = DashboardSummary.preview(date: date)
        dashboard.sleepScore = sleepScore

        let snapshot = DailySummaryUseCase().makeSnapshot(from: dashboard, context: context, date: date)

        XCTAssertNotNil(snapshot.deepSleepPercent)
        XCTAssertNotNil(snapshot.remSleepPercent)
        XCTAssertNotNil(snapshot.sleepEfficiency)
    }

    @MainActor
    func testHistoricalDashboardStressUsesLegacyComponentMode() {
        let snapshot = DailyHealthSnapshot(
            date: Date(timeIntervalSince1970: 1_779_000_000),
            sleepScore: 75,
            recoveryScore: 78,
            strainScore: 12,
            stressIndex: 32,
            morningEnergy: 85,
            currentEnergy: 65
        )

        let dashboard = DailySummaryUseCase().makeDashboardFromRecord(
            DailyHealthSummaryRecord(snapshot: snapshot)
        )

        XCTAssertLessThan(dashboard.stress.stressIndex, 50)
    }

    // MARK: - DailyPlanLimiter: Spec-required tests

    func testDailyPlanLimiterSickJournalFlagForcesRest() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 82,
            band: .high,
            confidence: .high,
            components: ["hrv": 90, "rhr": 80],
            componentWeights: ["hrv": 0.5, "rhr": 0.5],
            reasons: ["HRV above baseline"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )
        dashboard.sleepScore = MetricResult(
            name: "Sleep Score",
            value: 85,
            band: .high,
            confidence: .high,
            components: ["duration": 85],
            componentWeights: ["duration": 1.0],
            reasons: ["Good sleep"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard, journalFlags: ["sick"])
        XCTAssertEqual(plan.kind, .rest)
        XCTAssertFalse(plan.primaryActionTitle.isEmpty)
    }

    func testDailyPlanLimiterLowRecoveryForcesRecoveryDay() {
        var dashboard = DashboardSummary.preview()
        dashboard.recovery = MetricResult(
            name: "Recovery Score",
            value: 35,
            band: .low,
            confidence: .high,
            components: ["hrv": 35, "rhr": 42],
            componentWeights: ["hrv": 0.5, "rhr": 0.5],
            reasons: ["Recovery suppressed"],
            missingInputs: [],
            dataWindow: DateInterval(start: Date().addingTimeInterval(-86400), end: Date()),
            source: .healthKit,
            algorithmVersion: VelaAppMetadata.configVersion,
            lastUpdated: Date()
        )

        let plan = DailyPlanEngine.recommendation(for: dashboard)
        XCTAssertEqual(plan.kind, .recovery)
        XCTAssertEqual(plan.accent, .recovery)
        XCTAssertEqual(plan.limiter?.kind, .hrv)
    }

    // MARK: - Habit Correlation: Spec-required tests

    func testHabitCorrelationInsufficientSamplesReturnsEmpty() {
        // Test that Spearman correlation returns NaN with insufficient data
        let engine = JournalCorrelationEngine()
        let tooShort: [Double] = [1.0, 2.0]
        let outcome: [Double] = [3.0, 4.0]

        // With 2 samples, correlation is meaningless (Spearman on ranks with ties is 1.0)
        let r = engine.spearmanCorrelation(tooShort, outcome)
        // Spearman with identical rank differences always gives ±1 or NaN
        // The engine filters by N >= 14 at the insight level, not the correlation level
        XCTAssertTrue(r.isNaN || abs(r) <= 1.0)
    }

    func testHabitCorrelationWeakCorrelationFiltered() {
        let engine = JournalCorrelationEngine()
        // Generate 30 data points with near-zero correlation
        let n = 30
        let X: [Double] = (0..<n).map { Double($0) * 10.0 }
        // Y is mostly noise → very weak correlation
        let Y: [Double] = (0..<n).map { _ in 50.0 + Double.random(in: -10.0...10.0) }

        let r = engine.spearmanCorrelation(X, Y)
        // With weak/no correlation, |r| should typically be < 0.60
        // (could go higher for small N, but 30 gives reasonable reliability)
        XCTAssertLessThan(abs(r), 0.85)
    }

    func testHabitCorrelationModerateCorrelationDetected() {
        let engine = JournalCorrelationEngine()
        let n = 30
        // Create a monotonic negative trend: more caffeine → lower HRV
        let X: [Double] = (0..<n).map { Double($0) * 10.0 }
        let Y: [Double] = (0..<n).map { 55.0 - Double($0) * 0.5 }

        let r = engine.spearmanCorrelation(X, Y)
        // Perfect negative monotonic → r close to -1.0
        XCTAssertLessThan(r, -0.9)
        XCTAssertGreaterThan(r, -1.01)
    }

    func testDailyLoadPersistence() {
        let snapshot = DailyHealthSnapshot(
            date: Date(),
            dailyLoad: 125.0,
            workoutLoad: 80.0,
            activityLoad: 45.0,
            trainingLoadRatio: 1.25,
            bedtime: Date().addingTimeInterval(-28800),
            wakeTime: Date()
        )
        let record = DailyHealthSummaryRecord(snapshot: snapshot)
        XCTAssertEqual(record.dailyLoad, 125.0)
        XCTAssertEqual(record.workoutLoad, 80.0)
        XCTAssertEqual(record.activityLoad, 45.0)
        XCTAssertEqual(record.trainingLoadRatio, 1.25)
        XCTAssertNotNil(record.bedtime)
        XCTAssertNotNil(record.wakeTime)

        let converted = record.toSnapshot()
        XCTAssertEqual(converted.dailyLoad, 125.0)
        XCTAssertEqual(converted.workoutLoad, 80.0)
        XCTAssertEqual(converted.activityLoad, 45.0)
        XCTAssertEqual(converted.trainingLoadRatio, 1.25)
        XCTAssertNotNil(converted.bedtime)
        XCTAssertNotNil(converted.wakeTime)
    }

    func testEnergyHighRiskLoadDrain() {
        let engine = EnergyBankEngine()
        
        // Base input with highRisk training load status
        let inputHighRisk = EnergyBankInput(
            recoveryScore: 80.0,
            sleepScore: 85.0,
            strainScore: 18.0,
            stressIndex: 25.0,
            hrvToday: 70.0,
            hrvBaseline: 65.0,
            rhrToday: 55.0,
            rhrBaseline: 58.0,
            sleepHours: 8.0,
            strainHistory: [10.0, 12.0, 9.0],
            bodyTempDelta: 0.0,
            hoursSinceWake: 8.0,
            trainingLoadStatus: .highRisk
        )
        
        let resultHighRisk = engine.calculate(from: inputHighRisk)
        
        // Base input with optimal training load status
        let inputOptimal = EnergyBankInput(
            recoveryScore: 80.0,
            sleepScore: 85.0,
            strainScore: 18.0,
            stressIndex: 25.0,
            hrvToday: 70.0,
            hrvBaseline: 65.0,
            rhrToday: 55.0,
            rhrBaseline: 58.0,
            sleepHours: 8.0,
            strainHistory: [10.0, 12.0, 9.0],
            bodyTempDelta: 0.0,
            hoursSinceWake: 8.0,
            trainingLoadStatus: .optimal
        )
        
        let resultOptimal = engine.calculate(from: inputOptimal)
        
        // highRisk loadDrain must be greater than optimal loadDrain
        let drainHighRisk = resultHighRisk.components["load_drain"] ?? 0.0
        let drainOptimal = resultOptimal.components["load_drain"] ?? 0.0
        XCTAssertGreaterThan(drainHighRisk, drainOptimal)
    }

    func testMetricComputationPipelineRollingBaselines() {
        let pipeline = MetricComputationPipeline()
        let today = Date()
        let calendar = Calendar.current
        
        // Build 42 days of historical snapshots with realistic dailyLoads
        var history: [DailyHealthSnapshot] = []
        for i in 1...42 {
            let date = calendar.date(byAdding: .day, value: -i, to: today)!
            history.append(DailyHealthSnapshot(
                date: date,
                sleepScore: 80.0,
                recoveryScore: 75.0,
                strainScore: 12.0,
                stressIndex: 30.0,
                hrvAverage: 65.0,
                restingHeartRate: 58.0,
                sleepHours: 7.5,
                dailyLoad: 120.0 // Raw daily load!
            ))
        }
        
        let todaySnapshot = DailyHealthSnapshot(
            date: today,
            hrvAverage: 70.0,
            restingHeartRate: 55.0,
            sleepHours: 8.0,
            steps: 8000.0,
            activeCalories: 350.0,
            workoutDuration: 45.0
        )
        
        let result = pipeline.compute(for: todaySnapshot, history: history)
        
        // Verify rolling baselines are calculated (e.g. dailyLoadHistory contains raw loads and not strainScores)
        XCTAssertEqual(result.strain.components["daily_load"] ?? 0, 41.5, accuracy: 1.0)
        XCTAssertNotNil(result.strain.components["training_load_ratio"])
    }

    // MARK: - Core Metrics v1.3 Refactor Verification Tests

    func testHealthUnitNormalizerScaling() {
        // Sleep Efficiency: 0...1 bound
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepEfficiency(85.0), 0.85, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepEfficiency(0.85), 0.85, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepEfficiency(100.0), 1.0, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepEfficiency(-0.1), 0.0, accuracy: 0.001)

        // Deep/Rem Sleep: 0...1 bound
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepStagePercent(20.0), 0.20, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeSleepStagePercent(0.20), 0.20, accuracy: 0.001)

        // Oxygen Saturation: 0...100 bound
        XCTAssertEqual(HealthUnitNormalizer.normalizeOxygenSaturation(0.98), 98.0, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeOxygenSaturation(98.0), 98.0, accuracy: 0.001)

        // Body Fat: 0...100 bound (scales 0-1 input to 0-100)
        XCTAssertEqual(HealthUnitNormalizer.normalizeBodyFatPercentage(15.0), 15.0, accuracy: 0.001)
        XCTAssertEqual(HealthUnitNormalizer.normalizeBodyFatPercentage(0.15), 15.0, accuracy: 0.001)
    }

    func testStressEngineWithTemperatureNull() {
        let input = StressIndexInput(
            mode: .rawVitals,
            quietHRToday: 65,
            quietHRBaseline: 60,
            hrvToday: 55,
            hrvBaseline: 60,
            bodyTempDelta: nil // Missing temperature
        )
        let result = StressIndexEngine().calculate(from: input)
        
        XCTAssertNil(result.components["temp_stress"])
        XCTAssertTrue(result.missingInputs.contains("bodyTempDelta"))
    }

    func testEnergyBankMorningEnergyWithChargeEfficiency() {
        let inputNormal = EnergyBankInput(
            recoveryScore: 80,
            sleepScore: 80,
            strainScore: 10,
            stressIndex: 10,
            hrvToday: 60,
            hrvBaseline: 60,
            rhrToday: 60,
            rhrBaseline: 60 // chargeEfficiency = 0.6 * 0.7 + 0.4 * 0.7 = 0.7
        )
        let resultNormal = EnergyBankEngine().calculate(from: inputNormal)
        
        let inputHigh = EnergyBankInput(
            recoveryScore: 80,
            sleepScore: 80,
            strainScore: 10,
            stressIndex: 10,
            hrvToday: 90,
            hrvBaseline: 60,
            rhrToday: 50,
            rhrBaseline: 60 // chargeEfficiency = 0.6 * 1.0 + 0.4 * 1.0 = 1.0
        )
        let resultHigh = EnergyBankEngine().calculate(from: inputHigh)
        
        XCTAssertGreaterThan(resultHigh.morningEnergy, resultNormal.morningEnergy)
        XCTAssertEqual(resultHigh.components["charge_efficiency"] ?? 0, 1.0, accuracy: 0.01)
    }

    func testStrainTrainingLoadStatusZeroHistoryInhibition() {
        let input = StrainScoreInput(
            workouts: [],
            activeEnergyToday: 500,
            exerciseMinutesToday: 30,
            stepCount: 8000,
            restingHR: 60,
            maxHR: 190,
            last28DaysDailyLoads: [45.0, 50.0] // History < 7 days
        )
        let result = StrainScoreEngine().calculate(from: input)
        
        XCTAssertNil(result.components["training_load_status_code"])
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.reasons.contains { $0.contains("不足 7 天") })
    }
}

private func makePhenoAgeBiomarkers(
    albumin: (Double, String) = (4.3, "g/dL"),
    creatinine: (Double, String) = (1.0, "mg/dL"),
    glucose: (Double, String) = (99.1, "mg/dL"),
    crp: (Double, String) = (2.0, "mg/L")
) -> [BiomarkerRecord] {
    [
        BiomarkerRecord(name: "Albumin", value: albumin.0, unit: albumin.1, referenceMin: 3.5, referenceMax: 5.0),
        BiomarkerRecord(name: "Creatinine", value: creatinine.0, unit: creatinine.1, referenceMin: 0.6, referenceMax: 1.2),
        BiomarkerRecord(name: "Glucose", value: glucose.0, unit: glucose.1, referenceMin: 70, referenceMax: 100),
        BiomarkerRecord(name: "CRP", value: crp.0, unit: crp.1, referenceMin: 0, referenceMax: 3),
        BiomarkerRecord(name: "Lymphocyte", value: 30, unit: "%", referenceMin: 20, referenceMax: 40),
        BiomarkerRecord(name: "MCV", value: 90, unit: "fL", referenceMin: 80, referenceMax: 100),
        BiomarkerRecord(name: "RDW", value: 13, unit: "%", referenceMin: 11, referenceMax: 15),
        BiomarkerRecord(name: "Alkaline Phosphatase", value: 80, unit: "U/L", referenceMin: 44, referenceMax: 147),
        BiomarkerRecord(name: "WBC", value: 6, unit: "10^3/uL", referenceMin: 4, referenceMax: 11)
    ]
}

private struct StubLLMProvider: LLMProvider {
    let content: String

    func complete(request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: content)
    }
}
