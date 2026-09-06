import XCTest
@testable import Vela

final class DataCoverageAndEvidenceTests: XCTestCase {

    func testMetricResultMissingDataReturnsFormattedDashAndUnavailableCoverage() {
        let date = Date()
        let missingMetric = MetricResult(
            domain: .recovery,
            name: "Recovery Score",
            value: nil,
            band: .low,
            confidence: .low,
            components: [:],
            componentWeights: [:],
            reasons: ["No HealthKit signals available"],
            missingInputs: ["hrv", "rhr", "sleep"],
            dataWindow: DateInterval(start: date, duration: 86400),
            source: .derived,
            algorithmVersion: "1.0.0",
            lastUpdated: date
        )

        XCTAssertFalse(missingMetric.hasData)
        XCTAssertEqual(missingMetric.formattedScore, "--")
        XCTAssertEqual(missingMetric.dataCoverage, .unavailable)
        XCTAssertEqual(missingMetric.domain, .recovery)
        XCTAssertEqual(missingMetric.direction, .higherIsBetter)
        XCTAssertEqual(missingMetric.missingInputs, ["hrv", "rhr", "sleep"])
    }

    func testMetricResultWithDataReturnsFormattedNumberAndCompleteOrPartialCoverage() {
        let date = Date()
        let completeMetric = MetricResult(
            domain: .recovery,
            name: "Recovery Score",
            value: 82.4,
            band: .high,
            confidence: .high,
            components: ["hrv": 65.0, "rhr": 55.0],
            componentWeights: ["hrv": 0.6, "rhr": 0.4],
            reasons: ["Good HRV trend"],
            missingInputs: [],
            dataWindow: DateInterval(start: date, duration: 86400),
            source: .healthKit,
            algorithmVersion: "1.0.0",
            lastUpdated: date
        )

        XCTAssertTrue(completeMetric.hasData)
        XCTAssertEqual(completeMetric.formattedScore, "82")
        XCTAssertEqual(completeMetric.dataCoverage, .complete)
        XCTAssertEqual(completeMetric.score, 82.4)
    }

    func testEmptyDashboardProducesUnavailableSignalsAndNoAggregateReadinessScore() {
        let date = Date()
        let emptyDashboard = DashboardSummary.empty(date: date)

        // Verify 5 independent scored health evidence metrics exist and are all unpopulated
        XCTAssertFalse(emptyDashboard.recovery.hasData)
        XCTAssertFalse(emptyDashboard.sleepScore.hasData)
        XCTAssertFalse(emptyDashboard.strain.hasData)
        XCTAssertFalse(emptyDashboard.stress.hasData)
        XCTAssertFalse(emptyDashboard.energy.hasData)

        XCTAssertEqual(emptyDashboard.recovery.formattedScore, "--")
        XCTAssertEqual(emptyDashboard.sleepScore.formattedScore, "--")
        XCTAssertEqual(emptyDashboard.strain.formattedScore, "--")

        // Verify ADR 0003 compliance: domains are distinct and independent
        XCTAssertEqual(emptyDashboard.recovery.domain, .recovery)
        XCTAssertEqual(emptyDashboard.sleepScore.domain, .sleep)
        XCTAssertEqual(emptyDashboard.strain.domain, .strain)
        XCTAssertEqual(emptyDashboard.stress.domain, .physiologicalStress)
        XCTAssertEqual(emptyDashboard.energy.domain, .energy)
    }

    func testTodayExperienceModelBuildsCleanSignalsFromEmptyDashboard() {
        let date = Date()
        let emptyDashboard = DashboardSummary.empty(date: date)
        let bodyState = emptyDashboard.bodyState
        let decision = DailyTrainingDecision(
            decision: .rest,
            volumeMultiplier: 0.5,
            intensityCap: 50,
            reasons: ["Data missing"],
            userFacingSummary: "Waiting for health data",
            confidence: 0.0,
            source: "test",
            safetyNotice: "Notice"
        )

        let experience = TodayExperienceModel.build(
            dashboard: emptyDashboard,
            bodyState: bodyState,
            trainingDecision: decision,
            generatedAt: date
        )

        XCTAssertEqual(experience.signalCards.count, 5)
        for card in experience.signalCards {
            XCTAssertEqual(card.value, "--", "Signal \(card.id) should be formatted as -- when missing data")
            XCTAssertEqual(card.coverageLabel, "暂无覆盖")
        }
    }

    // MARK: - S1: Observation Time vs Recomputation Time
    func testS1ObservationTimePreservedAndIndependentOfRecomputation() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_785_369_600))
        let observedAt = day.addingTimeInterval(8 * 3600) // 08:00 AM
        let recomputedAt = day.addingTimeInterval(22 * 3600) // 22:00 PM
        let hrvWindow = DateInterval(start: day.addingTimeInterval(2 * 3600), end: day.addingTimeInterval(6 * 3600))

        var snapshot = DailyHealthSnapshot(date: day)
        snapshot.hrvAverage = 55
        snapshot.restingHeartRate = 60
        snapshot.oxygenSaturation = 0.98
        snapshot.hrvObservedAt = observedAt
        snapshot.hrvObservedWindow = hrvWindow

        let computation = DailyHealthComputation(
            calendar: calendar,
            now: recomputedAt,
            profile: DailyHealthComputationProfile(sleepTargetMinutes: 480, maxHeartRate: 190, biologicalSex: "other")
        )
        let evidence = computation.compute(for: snapshot, history: [])

        // Recovery result must keep true observation timestamp
        XCTAssertEqual(evidence.recovery.observedAt, observedAt)
        XCTAssertEqual(evidence.recovery.observedWindow, hrvWindow)
        XCTAssertEqual(evidence.recovery.lastUpdated, recomputedAt)
        // Ensure recomputation timestamp does not overwrite observation time
        XCTAssertNotEqual(evidence.recovery.observedAt, recomputedAt)
    }

    // MARK: - S2: Long-Term Baseline Context Validity
    func testS2LongTermBaselineRequiresAtLeast60SamplesAndIgnoresFuture() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_785_369_600))

        // History with 120 days but only 30 samples: context should be nil (< 60)
        let baseline30 = LongTermMetricBaseline(metric: .hrv, sampleCount: 30, threeYearMedian: 50, percentile10: 30, percentile90: 70)
        let report30 = LongTermBaselineReport(
            calculatedAt: day,
            daysOfData: 120,
            earliestDate: day.addingTimeInterval(-120 * 86400),
            latestDate: day,
            baselines: [.hrv: baseline30]
        )

        var snapshot = DailyHealthSnapshot(date: day)
        snapshot.hrvAverage = 20 // Below P10
        snapshot.restingHeartRate = 60

        let computation = DailyHealthComputation(
            calendar: calendar,
            now: day.addingTimeInterval(12 * 3600),
            profile: DailyHealthComputationProfile(sleepTargetMinutes: 480, maxHeartRate: 190, biologicalSex: "other")
        )

        let evidence30 = computation.compute(for: snapshot, history: [], longTermBaselines: report30)
        // Long-term context is only enabled when sampleCount >= 60. With 30 samples, no P10 reason is added.
        XCTAssertFalse(evidence30.recovery.reasons.contains { $0.contains("三年分布 P10") })

        // History with >= 60 samples
        let baseline60 = LongTermMetricBaseline(metric: .hrv, sampleCount: 75, threeYearMedian: 50, percentile10: 25, percentile90: 75)
        let report60 = LongTermBaselineReport(
            calculatedAt: day,
            daysOfData: 120,
            earliestDate: day.addingTimeInterval(-120 * 86400),
            latestDate: day,
            baselines: [.hrv: baseline60]
        )
        let evidence60 = computation.compute(for: snapshot, history: [], longTermBaselines: report60)
        // With 75 samples, long-term context is active and flags hrvToday (20) < p10 (25)
        XCTAssertTrue(evidence60.recovery.reasons.contains { $0.contains("三年分布 P10") })
    }

    // MARK: - S3: PSTI Requires Genuine RMSSD
    func testS3PSTIRequiresGenuineRMSSDAndDoesNotFallbackToSDNN() {
        let asOf = Date()
        let engine = RecoveryScoreEngine()

        // 1. Only SDNN provided (hrvToday), no RMSSD
        let inputSDNNOnly = RecoveryScoreInput(
            asOf: asOf,
            hrvToday: 55, // SDNN
            hrvBaseline: 50,
            hrvHistory: [48, 50, 52],
            hrvRmssdToday: nil, // Missing RMSSD
            hrvRmssdBaseline: nil,
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            sleepScoreLastNight: 75,
            strainScoreYesterday: nil
        )
        let resultSDNNOnly = engine.calculate(from: inputSDNNOnly)
        XCTAssertNil(resultSDNNOnly.components["parasympathetic_tone_index"], "PSTI must NOT be computed without genuine RMSSD")
        XCTAssertNil(resultSDNNOnly.components["psti_z_score"])

        // 2. RMSSD provided with genuine RMSSD baseline and history
        let inputRMSSD = RecoveryScoreInput(
            asOf: asOf,
            hrvToday: 55,
            hrvBaseline: 50,
            hrvRmssdToday: 42,
            hrvRmssdBaseline: 40,
            hrvRmssdHistory: [38, 40, 42, 41],
            restingHeartRateToday: 60,
            restingHeartRateBaseline: 60,
            sleepScoreLastNight: 75,
            strainScoreYesterday: nil
        )
        let resultRMSSD = engine.calculate(from: inputRMSSD)
        XCTAssertNotNil(resultRMSSD.components["parasympathetic_tone_index"], "PSTI must be computed when valid RMSSD is provided")
        XCTAssertNotNil(resultRMSSD.components["psti_z_score"])
    }

    // MARK: - S4: Sleep Target Behavioral vs Physiological Adequacy
    func testS4SleepTargetBehavioralGoalDoesNotClaimAASMPhysiologicalAdequacy() {
        let asOf = Date()
        let engine = SleepScoreEngine()

        // User sets target to 5h (300 min) and sleeps exactly 5h (300 min)
        let inputShortTarget = SleepScoreInput(
            asOf: asOf,
            totalSleepMinutes: 300,
            sleepTargetMinutes: 300,
            awakeMinutes: 15,
            awakeEpisodeCount: nil // missing awake episode count
        )
        let result = engine.calculate(from: inputShortTarget)
        
        // Check reasons for behavioral qualification vs physiological adequacy
        let hasBehavioralNotice = result.reasons.contains { $0.contains("AASM") || $0.contains("生理充分满足") }
        XCTAssertTrue(hasBehavioralNotice, "Short sleep target completion must explicitly clarify behavioral vs physiological adequacy")

        let hasAwakeEstimateNotice = result.reasons.contains { $0.contains("估算") }
        XCTAssertTrue(hasAwakeEstimateNotice, "Missing awake count must be flagged as estimated")
    }

    // MARK: - S5: Workout Deduplication and Method Codes
    func testS5WorkoutDeduplicationAndTRIMPMethodCodes() {
        let asOf = Date()
        let engine = StrainScoreEngine()
        let workoutUUID = UUID()

        // Pass 2 copies of the exact same workout
        let workout = WorkoutInput(
            id: workoutUUID,
            durationMinutes: 45,
            averageHeartRate: 145,
            rpe: nil
        )
        let input = StrainScoreInput(
            asOf: asOf,
            workouts: [workout, workout], // duplicate
            activeEnergyToday: 300,
            exerciseMinutesToday: 45,
            stepCount: 5000,
            restingHR: 60,
            maxHR: 190,
            biologicalSex: "male"
        )
        let result = engine.calculate(from: input)

        // Workout load for 45 min at 145 HR should be ~30-50, definitely not doubled
        let singleWorkoutInput = StrainScoreInput(
            asOf: asOf,
            workouts: [workout],
            activeEnergyToday: 300,
            exerciseMinutesToday: 45,
            stepCount: 5000,
            restingHR: 60,
            maxHR: 190,
            biologicalSex: "male"
        )
        let singleResult = engine.calculate(from: singleWorkoutInput)

        XCTAssertEqual(result.components["workout_load"], singleResult.components["workout_load"], "Duplicate workout UUID must not be double counted")
        XCTAssertEqual(result.components["workout_load_method_code"], 2.0, "Method B (avg HR) should record method code 2.0")
    }

    // MARK: - S6: Discontinuous Load Calendar Decay
    func testS6DiscontinuousCalendarDaysDecayEWMAAndDeactivatesWhenUnder7Days() {
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_785_369_600))
        var snapshot = DailyHealthSnapshot(date: day)
        snapshot.activeCalories = 300
        snapshot.steps = 5000

        // Create sparse history: only 4 valid days in past 28 days
        var sparseHistory: [DailyHealthSnapshot] = []
        for offset in [1, 2, 10, 15] {
            var item = DailyHealthSnapshot(date: calendar.date(byAdding: .day, value: -offset, to: day)!)
            item.dailyLoad = 50.0
            sparseHistory.append(item)
        }

        let computation = DailyHealthComputation(
            calendar: calendar,
            now: day.addingTimeInterval(12 * 3600),
            profile: DailyHealthComputationProfile(sleepTargetMinutes: 480, maxHeartRate: 190, biologicalSex: "other")
        )
        let evidence = computation.compute(for: snapshot, history: sparseHistory)

        // With only 4 observed days (< 7), ATL/CTL should be deactivated
        XCTAssertNil(evidence.strain.components["training_load_ratio"], "ATL/CTL must be deactivated when valid observed days < 7")
        XCTAssertTrue(evidence.strain.reasons.contains { $0.contains("不足 7 天") || $0.contains("尚未形成") })
    }

    // MARK: - S7: Physiological Stress Workout Window Exclusion
    func testS7PhysiologicalStressExcludedDuringWorkoutRecoveryWindow() {
        let now = Date()
        let engine = StressIndexEngine()

        // Within workout recovery window
        let inputWithin = StressIndexInput(
            asOf: now,
            quietHRToday: 75,
            quietHRBaseline: 60,
            hrvToday: 35,
            hrvBaseline: 50,
            isWithinWorkoutWindow: true
        )
        let resultWithin = engine.calculate(from: inputWithin)

        XCTAssertNil(resultWithin.value, "Physiological stress must be nil (excluded), NOT zero, inside workout recovery window")
        XCTAssertTrue(resultWithin.reasons.contains { $0.contains("运动窗口及运动后 90 分钟") })
    }

    // MARK: - S8: Energy Bank Stability When Missing Signals & Quality Propagation
    func testS8EnergyBankOvernightStabilityNeutralWhenMissingAndPropagatesQuality() {
        let asOf = Date()
        let engine = EnergyBankEngine()

        // 1. All overnight signals missing -> overnight_stability should be 50.0 (neutral), not 100.0
        let inputMissingOvernight = EnergyBankInput(
            asOf: asOf,
            recoveryScore: 80,
            sleepScore: 80,
            strainScore: 30,
            stressIndex: 30,
            bodyTempDelta: nil,
            respiratoryRateZ: nil,
            SpO2: nil,
            recoveryConfidence: .high,
            sleepConfidence: .high
        )
        let resultMissing = engine.calculate(from: inputMissingOvernight)
        XCTAssertEqual(resultMissing.components["overnight_stability"], 50.0, "Overnight stability must be neutral 50.0 when temp/resp/SpO2 are missing")
        XCTAssertTrue(resultMissing.missingInputs.contains("overnightStabilitySignals"))
        // Energy confidence cannot be .high without overnight stability signals
        XCTAssertNotEqual(resultMissing.confidence, .high)

        // 2. Upstream low confidence degrades energy confidence
        let inputLowQuality = EnergyBankInput(
            asOf: asOf,
            recoveryScore: 80,
            sleepScore: 80,
            strainScore: 30,
            stressIndex: 30,
            bodyTempDelta: 0.1,
            respiratoryRateZ: 0.2,
            SpO2: 98,
            recoveryConfidence: .low, // upstream recovery is low confidence
            sleepConfidence: .high
        )
        let resultLow = engine.calculate(from: inputLowQuality)
        XCTAssertEqual(resultLow.confidence, .low, "Energy confidence must be .low when upstream recovery confidence is .low")

        // 3. Stress excluded due to workout: strain > 0, stressIndex == nil
        let inputWorkoutExcluded = EnergyBankInput(
            asOf: asOf,
            recoveryScore: 80,
            sleepScore: 80,
            strainScore: 45,
            stressIndex: nil, // stress excluded
            bodyTempDelta: 0.1,
            respiratoryRateZ: 0.2,
            SpO2: 98
        )
        let resultWorkout = engine.calculate(from: inputWorkoutExcluded)
        XCTAssertEqual(resultWorkout.components["stress_drain"], 0.0)
        XCTAssertTrue(resultWorkout.reasons.contains { $0.contains("运动排除窗口") }, "Must explain that stress drain is accounted for by training load")
    }
}
