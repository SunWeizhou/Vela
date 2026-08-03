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
}
