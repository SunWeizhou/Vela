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

        XCTAssertEqual(result.score, 91.92, accuracy: 0.05)
        XCTAssertEqual(result.band, .high)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.components["duration_score"], 95)
        XCTAssertEqual(result.components["regularity_score"], 85)
        XCTAssertEqual(result.configVersion, VelaAppMetadata.configVersion)
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

        XCTAssertEqual(result.score, 71.67, accuracy: 0.05)
        XCTAssertEqual(result.band, .high)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertNil(result.weights["hrv"])
        XCTAssertEqual(result.weights["rhr"] ?? 0, 0.20 / 0.60, accuracy: 0.001)
        XCTAssertTrue(result.reasons.contains { $0.contains("HRV data unavailable") })
    }

    func testStrainScoreReturnsRecommendedRangeFromRecovery() {
        let result = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 600,
                activeEnergyBaseline: 500,
                exerciseMinutesToday: 45,
                exerciseMinutesBaseline: 45,
                workoutIntensityLoad: 55,
                recoveryScore: 64
            )
        )

        XCTAssertEqual(result.recommendedRange, 35...65)
        XCTAssertEqual(result.targetStatus, .aboveTarget)
        XCTAssertEqual(result.band, .high)
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

        XCTAssertEqual(result.morningEnergy, 43, accuracy: 0.01)
        XCTAssertEqual(result.currentEnergy, 0, accuracy: 0.01)
        XCTAssertEqual(result.status, .depleted)
        XCTAssertEqual(result.configVersion, VelaAppMetadata.configVersion)
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
        let context = AIContextBuilder().build(
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
        let context = AIContextBuilder().build(
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
        dashboard.recovery = StandardScoreResult(
            score: 32,
            band: .low,
            confidence: .high,
            components: ["hrv": 25, "rhr": 35],
            weights: ["hrv": 0.6, "rhr": 0.4],
            reasons: ["HRV significantly below personal baseline"],
            metrics: [:]
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
        dashboard.recovery = StandardScoreResult(
            score: 46,
            band: .moderate,
            confidence: .high,
            components: ["hrv": 52, "rhr": 18, "sleep": 72],
            weights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["Resting heart rate elevated 8 bpm above baseline"],
            metrics: ["rhr_z_score": 2.2]
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
        dashboard.recovery = StandardScoreResult(
            score: 47,
            band: .moderate,
            confidence: .high,
            components: ["hrv": 24, "rhr": 52, "sleep": 64],
            weights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["HRV significantly below personal baseline (z=-1.3)"],
            metrics: ["hrv_z_score": -1.3]
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(hrvMilliseconds: 36, restingHeartRate: 57)
        dashboard.recoveryBaseline = RecoveryMetricSummary(hrvMilliseconds: 45, restingHeartRate: 55)
        dashboard.sleepScore = StandardScoreResult(
            score: 64,
            band: .moderate,
            confidence: .high,
            components: ["duration_score": 64],
            weights: ["duration_score": 1],
            reasons: ["Sleep duration 6h 35m — below target by 12%"],
            metrics: [:]
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
        dashboard.recovery = StandardScoreResult(
            score: 46,
            band: .moderate,
            confidence: .high,
            components: ["hrv": 24, "rhr": 52, "sleep": 64],
            weights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.3],
            reasons: ["HRV significantly below personal baseline (z=-1.3)"],
            metrics: ["hrv_z_score": -1.3]
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(hrvMilliseconds: 36, restingHeartRate: 58)

        let directive = CoachSnapshotDirective.build(
            dashboard: dashboard,
            generatedAt: generatedAt,
            calendar: calendar
        )

        XCTAssertTrue(directive.contains("19:59"))
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
        dashboard.recovery = StandardScoreResult(
            score: 82,
            band: .high,
            confidence: .high,
            components: ["hrv": 90, "rhr": 80, "sleep": 78],
            weights: ["hrv": 0.4, "rhr": 0.2, "sleep": 0.4],
            reasons: ["HRV above baseline"],
            metrics: [:]
        )
        dashboard.strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 180,
                activeEnergyBaseline: 500,
                exerciseMinutesToday: 10,
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
            )
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
        
        // Expected RHR Score: 100
        // Expected VO2Max Score: vo2 = 45 -> score = 30.0 + (45.0 - 28.0) * 3.5 = 89.5
        // Expected Sleep Duration Score: 100
        // Expected Sleep Efficiency Score: 100 (95.0 >= 90)
        // Expected Steps Score: 100
        // Expected Wearable Score: (100 + 89.5 + 100 + 100 + 100) / 5 = 97.9
        XCTAssertEqual(result.wearableScore, 97.9, accuracy: 0.01)
        XCTAssertEqual(result.biomarkerScore, 80.0, accuracy: 0.01) // default neutral
        XCTAssertEqual(result.overallScore, 97.9, accuracy: 0.01) // overall defaults to wearables if biomarkers is empty
        
        // Expected modifier: 1.25 - (97.9 / 200.0) = 0.7605
        // Expected bio age: 30.0 * 0.7605 = 22.815
        XCTAssertEqual(result.biologicalAge, 22.815, accuracy: 0.01)
        
        XCTAssertEqual(result.optimalCount, 5)
        XCTAssertEqual(result.suboptimalCount, 0)
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
        
        XCTAssertEqual(result.wearableScore, 75.0, accuracy: 0.01) // default neutral
        
        // Optimal Biomarker Score: 100
        // Suboptimal Biomarker Score calculation:
        // Mid = (5 + 23) / 2 = 14
        // Range = 23 - 5 = 18
        // Deviation = abs(28 - 14) - (18 / 2) = 14 - 9 = 5
        // Percent Deviation = 5 / 18 = 0.2777...
        // Score = 100 - (0.2777... * 100) = 72.22...
        // Average Biomarker Score: (100 + 72.22...) / 2 = 86.11...
        XCTAssertEqual(result.biomarkerScore, 86.11, accuracy: 0.05)
        XCTAssertEqual(result.overallScore, 86.11, accuracy: 0.05) // overall defaults to biomarkers if wearables are empty
        
        // Expected modifier: 1.25 - (86.11 / 200.0) = 0.8194...
        // Expected bio age: 40.0 * 0.8194 = 32.77
        XCTAssertEqual(result.biologicalAge, 32.77, accuracy: 0.1)
        XCTAssertEqual(result.optimalCount, 1)
        XCTAssertEqual(result.suboptimalCount, 1)
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
        
        // Wearable average: (76.7 + 54.5 + 65.0 + 82.5 + 50.0) / 5 = 65.74
        XCTAssertEqual(result.wearableScore, 65.74, accuracy: 0.1)
        
        // Biomarker average: 100.0
        XCTAssertEqual(result.biomarkerScore, 100.0, accuracy: 0.1)
        
        // Combined Score: 65.74 * 0.65 + 100.0 * 0.35 = 42.731 + 35.0 = 77.731
        XCTAssertEqual(result.overallScore, 77.73, accuracy: 0.1)
        
        // Modifier: 1.25 - (77.73 / 200.0) = 0.86135
        // Bio Age: 30.0 * 0.86135 = 25.84
        XCTAssertEqual(result.biologicalAge, 25.84, accuracy: 0.1)
    }
}

private struct StubLLMProvider: LLMProvider {
    let content: String

    func complete(request: LLMRequest) async throws -> LLMResponse {
        LLMResponse(content: content)
    }
}
