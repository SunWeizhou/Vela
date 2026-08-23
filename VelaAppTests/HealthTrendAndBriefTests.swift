import XCTest
@testable import Vela

final class HealthTrendAndBriefTests: XCTestCase {

    func testHealthTrendEngineWithEmptyDashboardReturnsEmptyBrief() {
        let date = Date()
        let emptyDashboard = DashboardSummary.empty(date: date)
        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: emptyDashboard,
            snapshots: [],
            longTermBaselines: nil,
            today: date
        )

        XCTAssertEqual(result.brief.overallState, .insufficientData)
        XCTAssertEqual(result.brief.headline, "正在建立个人健康基线")
        XCTAssertTrue(result.findings.isEmpty)
        XCTAssertTrue(result.brief.notableChanges.isEmpty)
    }

    func testHealthTrendEngineSynthesizesNotableChangesAndBrief() {
        let calendar = Calendar.current
        let today = Date()

        var snapshots: [DailyHealthSnapshot] = []
        for i in (0..<30).reversed() {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            var s = DailyHealthSnapshot(date: d)
            s.hrvAverage = i < 7 ? 40.0 : 65.0 // HRV dropped in the last 7 days
            s.restingHeartRate = i < 7 ? 62.0 : 54.0 // RHR elevated
            s.sleepHours = 7.5
            s.recoveryScore = i < 7 ? 35.0 : 75.0
            s.strainScore = 45.0
            s.stressIndex = 45.0
            snapshots.append(s)
        }

        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 35.0, band: .low, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 40.0,
            restingHeartRate: 62.0,
            sleepHeartRate: nil,
            respiratoryRate: 14.5
        )
        dashboard.sleepScore = MetricResult(
            domain: .sleep, name: "Sleep", value: 75.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots,
            longTermBaselines: nil,
            today: today,
            calendar: calendar
        )

        XCTAssertFalse(result.findings.isEmpty)
        XCTAssertNotEqual(result.brief.overallState, .insufficientData)
        XCTAssertFalse(result.brief.subheadline.isEmpty)

        // Verify notable findings exist for HRV, RHR or Recovery
        let notableMetrics = Set(result.brief.notableChanges.map(\.metric))
        XCTAssertTrue(notableMetrics.contains(.hrv) || notableMetrics.contains(.restingHeartRate) || notableMetrics.contains(.recovery))
        XCTAssertEqual(
            result.brief.notableChanges.map(\.metric).count,
            notableMetrics.count,
            "Personal Health Brief must expose at most one notable finding per metric"
        )
    }

    func testSixMonthTrendCalculationAndNoSilentHorizonFallback() {
        let calendar = Calendar.current
        let today = Date()

        // 1. Only 30 snapshots available: 30d should be available, but 6m (< 60 samples) must be unavailable
        var snapshots30: [DailyHealthSnapshot] = []
        for i in (0..<30).reversed() {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            var s = DailyHealthSnapshot(date: d)
            s.hrvAverage = 60.0
            s.restingHeartRate = 55.0
            s.sleepHours = 7.5
            s.recoveryScore = 70.0
            snapshots30.append(s)
        }

        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 70.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 60.0,
            restingHeartRate: 55.0,
            sleepHeartRate: nil,
            respiratoryRate: 14.0
        )

        let engine = HealthTrendEngine()
        let result30 = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots30,
            longTermBaselines: nil,
            today: today,
            calendar: calendar
        )

        let finding30d = result30.findings.first { $0.metric == .hrv && $0.horizon == .thirtyDays }
        let finding6m = result30.findings.first { $0.metric == .hrv && $0.horizon == .sixMonths }

        XCTAssertNotNil(finding30d)
        XCTAssertTrue(finding30d?.isAvailable == true)

        // 6-month finding must NOT be silently substituted by 30-day data; it must be marked unavailable
        XCTAssertNotNil(finding6m)
        XCTAssertFalse(finding6m?.isAvailable == true)
        XCTAssertEqual(finding6m?.direction, .insufficientData)
        XCTAssertEqual(finding6m?.currentValueFormatted, "--")

        // 2. Now provide 180 snapshots: 6m should become available and calculate true trend
        var snapshots180: [DailyHealthSnapshot] = []
        for i in (0..<180).reversed() {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            var s = DailyHealthSnapshot(date: d)
            s.hrvAverage = i < 60 ? 70.0 : 55.0 // Gradual multi-month improvement
            s.restingHeartRate = 54.0
            s.sleepHours = 7.5
            s.recoveryScore = 75.0
            snapshots180.append(s)
        }

        let result180 = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots180,
            longTermBaselines: nil,
            today: today,
            calendar: calendar
        )

        let finding6mActive = result180.findings.first { $0.metric == .hrv && $0.horizon == .sixMonths }
        XCTAssertNotNil(finding6mActive)
        XCTAssertTrue(finding6mActive?.isAvailable == true)
        XCTAssertEqual(finding6mActive?.direction, .improving)
    }

    func testMissingRecoveryDataDoesNotEvaluateToZeroOrRecovering() {
        let today = Date()
        var dashboard = DashboardSummary.empty(date: today)
        // Recovery is nil/missing
        dashboard.recovery.value = nil
        dashboard.recovery.confidence = .low
        // Sleep is healthy (8.0 hours / score 85)
        dashboard.sleepScore = MetricResult(
            domain: .sleep, name: "Sleep", value: 85.0, band: .high, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.sleepSummary = SleepSummary(
            date: today,
            totalSleepMinutes: 480,
            bedtime: today.addingTimeInterval(-28800),
            wakeTime: today,
            stageMinutes: [.deep: 90, .rem: 100, .awake: 30],
            segments: [],
            sleepScore: 85.0
        )

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: [],
            longTermBaselines: nil,
            today: today
        )

        // Must NOT assume recovery = 0 and jump to .recovering!
        XCTAssertNotEqual(result.brief.overallState, .recovering, "Missing recovery must not be coerced to 0 score")
    }

    func testStrainScaleAndThresholdIsCalibratedTo0To100() {
        let today = Date()
        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 75.0, band: .high, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        // Strain of 45.0 in a 0-100 scale is a normal moderate workout day
        dashboard.strain = MetricResult(
            domain: .strain, name: "Strain", value: 45.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: [],
            longTermBaselines: nil,
            today: today
        )

        // Must NOT be strained simply because 45.0 >= 14!
        XCTAssertNotEqual(result.brief.overallState, .strained, "Strain of 45/100 is normal moderate load, not strained")
    }

    func testHighStrainIsNotHiddenByOptimalRecovery() {
        let today = Date()
        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 80.0, band: .high, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.strain = MetricResult(
            domain: .strain, name: "Strain", value: 85.0, band: .high, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        let result = HealthTrendEngine().analyze(
            dashboard: dashboard,
            snapshots: [],
            longTermBaselines: nil,
            today: today
        )

        XCTAssertEqual(result.brief.overallState, .strained)
    }

    func testThreeYearFindingPublishesValueDirectionAndAssessment() {
        let today = Date()
        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 70.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.recoveryMetrics.hrvMilliseconds = 40.0

        let hrvBaseline = LongTermMetricBaseline(
            metric: .hrv,
            sampleCount: 90,
            threeYearMedian: 60.0,
            percentile10: 45.0,
            percentile25: 52.0,
            percentile75: 68.0,
            percentile90: 75.0,
            recent30DayMean: 40.0,
            longTermDeviationPercent: -33.3,
            yearOverYearDelta: nil,
            trendLabel: "worsening"
        )
        let report = LongTermBaselineReport(
            calculatedAt: today,
            daysOfData: 90,
            earliestDate: today.addingTimeInterval(-90 * 86400),
            latestDate: today,
            baselines: [.hrv: hrvBaseline]
        )

        let result = HealthTrendEngine().analyze(
            dashboard: dashboard,
            snapshots: [],
            longTermBaselines: report,
            today: today
        )
        let finding = result.findings.first { $0.metric == .hrv && $0.horizon == .threeYears }

        XCTAssertEqual(finding?.direction, .declining)
        XCTAssertEqual(finding?.valueDirection, .falling)
        XCTAssertEqual(finding?.assessment, .unfavorable)
    }

    func testMetricPolaritiesAreCorrectlyDefined() {
        XCTAssertEqual(CoreHealthMetric.bodyWeight.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.bodyFat.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.strain.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.steps.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.activeCalories.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.respiratoryRate.polarity, .contextual)
        XCTAssertEqual(CoreHealthMetric.hrv.polarity, .higherIsBetter)
        XCTAssertEqual(CoreHealthMetric.recovery.polarity, .higherIsBetter)
        XCTAssertEqual(CoreHealthMetric.sleepDuration.polarity, .higherIsBetter)
        XCTAssertEqual(CoreHealthMetric.restingHeartRate.polarity, .lowerIsBetter)
        XCTAssertEqual(CoreHealthMetric.stress.polarity, .lowerIsBetter)
    }

    func testStepsAndActiveCaloriesExtractionFromMetrics() {
        let today = Date()
        var dashboard = DashboardSummary.empty(date: today)
        dashboard.strain = MetricResult(
            domain: .strain, name: "Strain", value: 30.0, band: .normal, confidence: .high,
            components: ["steps_raw": 10450.0, "active_energy_raw": 580.0],
            componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 75.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        var snapshots: [DailyHealthSnapshot] = []
        for i in 0..<14 {
            var s = DailyHealthSnapshot(date: Calendar.current.date(byAdding: .day, value: -i, to: today)!)
            s.steps = 9500
            s.activeCalories = 520.0
            snapshots.append(s)
        }

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots,
            longTermBaselines: nil,
            today: today
        )

        let stepFinding = result.findings.first { $0.metric == .steps && $0.horizon == .sevenDays }
        XCTAssertNotNil(stepFinding)
        XCTAssertTrue(stepFinding?.isAvailable == true)
        XCTAssertEqual(stepFinding?.currentValue, 10450)

        let calorieFinding = result.findings.first { $0.metric == .activeCalories && $0.horizon == .sevenDays }
        XCTAssertNotNil(calorieFinding, "activeCalories finding must exist")
        XCTAssertTrue(calorieFinding?.isAvailable == true, "activeCalories finding must be available")
        XCTAssertEqual(calorieFinding?.currentValue, 580.0, "activeCalories should be 580.0 from active_energy_raw")
    }

    func testDecoupledValueDirectionAndAssessmentForRestingHeartRate() {
        let calendar = Calendar.current
        let today = Date()

        var snapshots: [DailyHealthSnapshot] = []
        for i in (0..<30).reversed() {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            var s = DailyHealthSnapshot(date: d)
            // First half: 55 bpm, second half: 65 bpm (RHR value rises)
            s.restingHeartRate = (i > 15) ? 55.0 : 65.0
            snapshots.append(s)
        }

        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recoveryMetrics.restingHeartRate = 65.0
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 50.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots,
            longTermBaselines: nil,
            today: today
        )

        let rhr30d = result.findings.first { $0.metric == .restingHeartRate && $0.horizon == .thirtyDays }
        XCTAssertNotNil(rhr30d)
        XCTAssertTrue(rhr30d?.isAvailable == true)
        // Numerical value went UP
        XCTAssertEqual(rhr30d?.valueDirection, .rising, "RHR value went up, so valueDirection must be rising")
        // Health assessment is unfavorable because lower is better for RHR
        XCTAssertEqual(rhr30d?.assessment, .unfavorable, "RHR rising is unfavorable for health")
    }

    func testSixMonthTrendRejectsClusteredSamplesWithInsufficientTimeSpan() {
        let calendar = Calendar.current
        let today = Date()

        var snapshots: [DailyHealthSnapshot] = []
        // 60 samples but all within the last 30 days (e.g. 2 samples per day or tight span)
        for i in 0..<60 {
            let d = calendar.date(byAdding: .day, value: -(i % 30), to: today)!
            var s = DailyHealthSnapshot(date: d)
            s.hrvAverage = 65.0
            snapshots.append(s)
        }

        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recoveryMetrics.hrvMilliseconds = 65.0
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 70.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )
        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots,
            longTermBaselines: nil,
            today: today
        )

        let hrv6m = result.findings.first { $0.metric == .hrv && $0.horizon == .sixMonths }
        XCTAssertNotNil(hrv6m)
        XCTAssertFalse(hrv6m?.isAvailable == true, "6-month trend must reject samples with less than 90 days span")
    }

    func testEmptyDashboardProducesSafePendingDecisionInKernel() {
        let today = Date()
        let dashboard = DashboardSummary.empty(date: today)
        let bodyState = BodyStateKernel().build(input: BodyStateInput(dashboard: dashboard))

        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
            bodyState: bodyState,
            personalHealthBrief: dashboard.personalHealthBrief
        ))

        // 契约（P0-A）：空数据必须落在保守窗口，而不是 keep@100% 或"等待同步"的含糊措辞。
        XCTAssertEqual(decision.decision, .reduce)
        XCTAssertEqual(decision.volumeMultiplier, 0.60)
        XCTAssertEqual(decision.intensityCap, 7)
        XCTAssertEqual(decision.confidence, 0.0)
        XCTAssertTrue(decision.userFacingSummary.contains("60%"), decision.userFacingSummary)
    }

    func testRobustHalfWindowMedianRejectsSingleDaySpike() {
        let calendar = Calendar.current
        let today = Date()

        var snapshots: [DailyHealthSnapshot] = []
        for i in (0..<30).reversed() {
            let d = calendar.date(byAdding: .day, value: -i, to: today)!
            var s = DailyHealthSnapshot(date: d)
            // 29 days of stable HRV 60ms, with 1 single anomalous spike to 140ms on day 20
            s.hrvAverage = (i == 10) ? 140.0 : 60.0
            snapshots.append(s)
        }

        var dashboard = DashboardSummary.empty(date: today)
        dashboard.recoveryMetrics.hrvMilliseconds = 60.0
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 75.0, band: .normal, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: today, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: today
        )

        let engine = HealthTrendEngine()
        let result = engine.analyze(
            dashboard: dashboard,
            snapshots: snapshots,
            longTermBaselines: nil,
            today: today
        )

        let hrv30d = result.findings.first { $0.metric == .hrv && $0.horizon == .thirtyDays }
        XCTAssertNotNil(hrv30d)
        XCTAssertTrue(hrv30d?.isAvailable == true)
        // The median of both halves is 60.0, so the single day spike does NOT cause a false "improving" or "declining" trend!
        XCTAssertEqual(hrv30d?.direction, .stable, "Robust median trend must reject single-day spike")
    }

    func testTodayExperienceModelBuildsFromPersonalHealthBrief() {
        let date = Date()
        var dashboard = DashboardSummary.empty(date: date)
        dashboard.recovery = MetricResult(
            domain: .recovery, name: "Recovery", value: 80.0, band: .high, confidence: .high,
            components: [:], componentWeights: [:], reasons: [], missingInputs: [],
            dataWindow: DateInterval(start: date, duration: 86400), source: .healthKit,
            algorithmVersion: "1.0", lastUpdated: date
        )
        dashboard.recoveryMetrics = RecoveryMetricSummary(
            hrvMilliseconds: 70.0,
            restingHeartRate: 52.0,
            sleepHeartRate: nil,
            respiratoryRate: 13.5
        )

        let brief = PersonalHealthBrief(
            date: date,
            overallState: .optimal,
            headline: "身体机能处于良好水平",
            subheadline: "恢复得分达 80%，各项核心体征处于基线良好区间。",
            notableChanges: [],
            stableSignals: [],
            confidence: .high,
            confidenceLabel: "数据充足",
            needsAction: false,
            suggestedActionCategory: .training,
            actionHeadline: "机能充沛",
            actionDetail: "体征处于基线良好区间，可按个人节奏正常开展日常工作与训练活动。",
            lifestyleSuggestions: []
        )
        dashboard.personalHealthBrief = brief

        let bodyState = BodyStateKernel().build(input: BodyStateInput(dashboard: dashboard))
        let decision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(bodyState: bodyState))

        let experience = TodayExperienceModel.build(
            dashboard: dashboard,
            bodyState: bodyState,
            trainingDecision: decision
        )

        XCTAssertEqual(experience.hero.decisionTitle, "身体机能处于良好水平")
        XCTAssertEqual(experience.hero.summary, "恢复得分达 80%，各项核心体征处于基线良好区间。")
    }
}
