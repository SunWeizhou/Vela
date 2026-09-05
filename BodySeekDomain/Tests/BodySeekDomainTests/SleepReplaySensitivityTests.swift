import Foundation
import XCTest
@testable import BodySeekDomain

/// ARCH-08 release evidence for the sleep-only replay slice.
///
/// These cases intentionally exercise the existing v2.0.0 formula without
/// changing it. The canonical input text is also the replay fingerprint
/// recorded in `docs/baselines/sleep-replay-fixtures.json`.
final class SleepReplaySensitivityTests: XCTestCase {
    private lazy var asOf = date("2026-07-31T12:00:00Z")
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testBaselineReplayIdentityAndFingerprint() throws {
        let input = baselineInput()
        let result = SleepScoreEngine(calendar: calendar).calculate(from: input)

        XCTAssertEqual(result.value ?? -1, 77.43, accuracy: 0.01)
        XCTAssertEqual(result.algorithmVersion, ScoringAlgorithmVersions.sleep)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertEqual(result.missingInputs, ["todayBedtime", "recentBedtimesHistory"])
        XCTAssertEqual(result.components["duration"] ?? -1, 50, accuracy: 0.0001)
        XCTAssertEqual(result.components["interruption"] ?? -1, 4.2, accuracy: 0.0001)
        XCTAssertEqual(replayFingerprint(input), "sleep-v2|2026-07-31T12:00:00Z|465.0|450.0|awake=24.0|episodes=2|bedtime=nil|history=0")
    }

    func testMissingSleepInputRemainsUnavailableWithExplicitReason() {
        var input = baselineInput()
        input.totalSleepMinutes = nil
        let result = SleepScoreEngine(calendar: calendar).calculate(from: input)

        XCTAssertNil(result.value)
        XCTAssertEqual(result.dataCoverage, .unavailable)
        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.missingInputs, ["totalSleepMinutes"])
        XCTAssertEqual(result.formattedScore, "--")
    }

    func testSensitivityCasesHaveExactOutputs() {
        let engine = SleepScoreEngine(calendar: calendar)
        let cases: [(String, SleepScoreInput, Double?, MetricConfidence, [String])] = [
            ("baseline", baselineInput(), 77.43, .medium, ["todayBedtime", "recentBedtimesHistory"]),
            ("short-sleep-360", replacing(baselineInput(), totalSleepMinutes: 360), 53.62, .medium, ["todayBedtime", "recentBedtimesHistory"]),
            ("no-awake-time", replacing(baselineInput(), awakeMinutes: 0, awakeEpisodeCount: 0), 100.0, .medium, ["todayBedtime", "recentBedtimesHistory"]),
            ("missing-awake-time", missingAwakeInput(), 79.0, .low, ["todayBedtime", "recentBedtimesHistory", "awakeMinutes"]),
            ("five-bedtime-history", replacing(baselineInput(), todayBedtime: date("2026-07-30T23:15:00Z"), recentBedtimes: bedtimeHistory()), 84.2, .high, [])
        ]

        for (name, input, expected, confidence, missing) in cases {
            let result = engine.calculate(from: input)
            if let expected {
                XCTAssertEqual(result.value ?? -1, expected, accuracy: 0.01, name)
            } else {
                XCTAssertNil(result.value, name)
            }
            XCTAssertEqual(result.confidence, confidence, name)
            XCTAssertEqual(result.missingInputs, missing, name)
        }
    }

    private func baselineInput() -> SleepScoreInput {
        SleepScoreInput(
            asOf: asOf,
            totalSleepMinutes: 465,
            sleepTargetMinutes: 450,
            awakeMinutes: 24,
            awakeEpisodeCount: 2
        )
    }

    private func replacing(
        _ input: SleepScoreInput,
        totalSleepMinutes: Double? = nil,
        awakeMinutes: Double? = nil,
        awakeEpisodeCount: Int? = nil,
        todayBedtime: Date? = nil,
        recentBedtimes: [Date]? = nil
    ) -> SleepScoreInput {
        var copy = input
        if let totalSleepMinutes { copy.totalSleepMinutes = totalSleepMinutes }
        if let awakeMinutes { copy.awakeMinutes = awakeMinutes }
        if let awakeEpisodeCount { copy.awakeEpisodeCount = awakeEpisodeCount }
        if let todayBedtime { copy.todayBedtime = todayBedtime }
        if let recentBedtimes { copy.recentBedtimes = recentBedtimes }
        return copy
    }

    private func bedtimeHistory() -> [Date] {
        (1...5).map { date("2026-07-30T23:15:00Z").addingTimeInterval(Double(-$0 + 1) * 86_400) }
    }

    private func missingAwakeInput() -> SleepScoreInput {
        var input = baselineInput()
        input.awakeMinutes = nil
        input.awakeEpisodeCount = nil
        return input
    }

    private func replayFingerprint(_ input: SleepScoreInput) -> String {
        let bedtime = input.todayBedtime.map(iso8601) ?? "nil"
        let total = input.totalSleepMinutes.map { String($0) } ?? "nil"
        let awake = input.awakeMinutes.map { String($0) } ?? "nil"
        let episodes = input.awakeEpisodeCount.map { String($0) } ?? "nil"
        return "sleep-v2|\(iso8601(input.asOf))|\(total)|\(input.sleepTargetMinutes)|awake=\(awake)|episodes=\(episodes)|bedtime=\(bedtime)|history=\(input.recentBedtimes.count)"
    }

    private func iso8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
