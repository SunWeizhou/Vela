import Foundation
import XCTest
@testable import BodySeekDomain

final class ScoreContractTests: XCTestCase {
    private let window = DateInterval(
        start: Date(timeIntervalSince1970: 1_751_328_000),
        end: Date(timeIntervalSince1970: 1_751_371_200)
    )

    func testSleepAdapterPreservesGoldenEstimateAndProvenance() throws {
        let metric = MetricResult(
            domain: .sleep,
            name: "Sleep Score",
            value: 77.43,
            band: .high,
            confidence: .medium,
            components: ["duration": 50, "interruption": 4.2],
            componentWeights: ["duration": 50, "interruption": 20],
            reasons: ["fixture"],
            missingInputs: ["recentBedtimesHistory"],
            dataWindow: window,
            source: .healthKit,
            algorithmVersion: ScoringAlgorithmVersions.sleep,
            lastUpdated: window.end
        )

        let evidence = try XCTUnwrap(
            SleepScoreEvidenceAdapter.makeEvidence(from: metric, inputFingerprint: "sleep-fixture")
        )
        XCTAssertEqual(evidence.domain, .sleep)
        XCTAssertEqual(try XCTUnwrap(evidence.estimate.value), 77.43, accuracy: 0.0001)
        XCTAssertEqual(evidence.estimate.components["duration"], 50)
        XCTAssertEqual(evidence.confidence.level, .medium)
        XCTAssertEqual(evidence.confidence.limitingInputs, ["recentBedtimesHistory"])
        XCTAssertEqual(evidence.coverage.status, .substantial)
        XCTAssertEqual(evidence.coverage.requiredSignals.map(\.signalID), ["recentBedtimesHistory"])
        XCTAssertEqual(evidence.provenance.algorithmVersion, ScoringAlgorithmVersions.sleep)
        XCTAssertEqual(evidence.provenance.inputFingerprint, "sleep-fixture")
        XCTAssertEqual(evidence.provenance.dataWindow, window)
    }

    func testUnavailableSleepDoesNotBecomeZeroAndRetainsProvenance() throws {
        let metric = MetricResult(
            domain: .sleep,
            name: "Sleep Score",
            value: nil,
            band: .low,
            confidence: .low,
            reasons: ["缺少睡眠时长数据"],
            missingInputs: ["totalSleepMinutes"],
            dataWindow: window,
            source: .healthKit,
            algorithmVersion: ScoringAlgorithmVersions.sleep,
            lastUpdated: window.end
        )

        let evidence = try XCTUnwrap(SleepScoreEvidenceAdapter.makeEvidence(from: metric))
        XCTAssertNil(evidence.estimate.value)
        XCTAssertEqual(evidence.coverage.status, .unavailable)
        XCTAssertEqual(evidence.coverage.requiredSignals.first?.isUsable, false)
        XCTAssertEqual(evidence.provenance.dataWindow, window)
        XCTAssertEqual(evidence.provenance.evaluatedAt, window.end)
    }

    func testSleepAdapterRejectsOtherDomain() {
        let metric = MetricResult(
            domain: .energy,
            name: "Energy Score",
            value: 42,
            band: .normal,
            confidence: .high,
            dataWindow: window,
            source: .derived,
            algorithmVersion: ScoringAlgorithmVersions.energy,
            lastUpdated: window.end
        )
        XCTAssertNil(SleepScoreEvidenceAdapter.makeEvidence(from: metric))
    }

    func testScoreEvidenceCodableRoundTripIncludesNilEstimateAndUnavailableSignal() throws {
        let evidence = ScoreEvidence(
            domain: .sleep,
            estimate: ScoreEstimate(value: nil, band: .low),
            confidence: ScoreConfidenceReport(
                level: .low,
                reasons: ["missing"],
                limitingInputs: ["totalSleepMinutes"]
            ),
            coverage: ScoreCoverageReport(
                status: .unavailable,
                requiredSignals: [SignalCoverage(signalID: "totalSleepMinutes", isUsable: false)]
            ),
            provenance: ScoreProvenance(
                source: .healthKit,
                dataWindow: window,
                evaluatedAt: window.end,
                algorithmVersion: ScoringAlgorithmVersions.sleep
            ),
            reasons: ["missing"]
        )
        let decoded = try JSONDecoder().decode(ScoreEvidence.self, from: JSONEncoder().encode(evidence))
        XCTAssertEqual(decoded, evidence)
        XCTAssertNil(decoded.estimate.value)
        XCTAssertEqual(decoded.coverage.requiredSignals.first?.isUsable, false)
    }
}
