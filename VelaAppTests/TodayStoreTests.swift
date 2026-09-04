import XCTest
@testable import Vela

final class TodayStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date { Date(timeIntervalSince1970: 1_780_000_000) }

    @MainActor
    private final class RecordingReader: TodayReadingModule {
        var cachedSnapshot: TodayDashboardSnapshot?
        var loadSnapshot: TodayDashboardSnapshot?
        var cachedCalls = 0
        var loadCalls = 0
        var policies: [TodayRefreshPolicy] = []
        var loadDelayNanoseconds: UInt64 = 0
        var loadError: Error?

        func cached(for day: Date) async throws -> TodayDashboardSnapshot? {
            cachedCalls += 1
            return cachedSnapshot
        }

        func load(for day: Date, policy: TodayRefreshPolicy) async throws -> TodayDashboardSnapshot {
            loadCalls += 1
            policies.append(policy)
            if loadDelayNanoseconds > 0 {
                try await Task.sleep(nanoseconds: loadDelayNanoseconds)
            }
            if let loadError { throw loadError }
            return loadSnapshot ?? TodayDashboardSnapshot(dashboard: .empty(date: day))
        }
    }

    @MainActor
    private final class RecordingEffects: TodayEffectRouter {
        var openedMetrics: [TodayMetricID] = []
        var openedEvidence = 0
        var openedCalendar = 0
        var openedPlan = 0
        var openedSettings = 0
        var coachQuestions: [String] = []
        var startedTraining = 0
        var requestedWeather = 0
        var alignments: [LivedStateAlignment] = []
        var checkIns: [LivedStateCheckIn] = []
        var feedbackCount = 0

        func openCalendar() async { openedCalendar += 1 }
        func openMetric(_ metric: TodayMetricID) async { openedMetrics.append(metric) }
        func openEvidence() async { openedEvidence += 1 }
        func openPlan() async { openedPlan += 1 }
        func openSettings() async { openedSettings += 1 }
        func askCoach(_ question: String) async { coachQuestions.append(question) }
        func startTraining() async { startedTraining += 1 }
        func requestWeather() async { requestedWeather += 1 }
        func saveLivedStateAlignment(_ alignment: LivedStateAlignment) async { alignments.append(alignment) }
        func saveLivedState(_ checkIn: LivedStateCheckIn) async { checkIns.append(checkIn) }
        func submitFeedback(_ values: DailyDecisionFeedbackValues) async { feedbackCount += 1 }
    }

    private func snapshot(
        day: Date,
        source: DashboardSummary.DataSource = .healthKit,
        score: Double? = 77.43,
        updatedAt: Date? = nil
    ) -> TodayDashboardSnapshot {
        var dashboard = DashboardSummary.empty(date: day)
        dashboard.source = source
        for keyPath in [
            \DashboardSummary.recovery,
            \DashboardSummary.sleepScore,
            \DashboardSummary.strain,
            \DashboardSummary.stress,
            \DashboardSummary.energy
        ] {
            var metric = dashboard[keyPath: keyPath]
            metric.value = score
            metric.lastUpdated = updatedAt ?? day
            dashboard[keyPath: keyPath] = metric
        }
        return TodayDashboardSnapshot(dashboard: dashboard)
    }

    @MainActor
    func testAppearUsesCacheThenLiveAndPreservesFiveScoreSemantics() async {
        let reader = RecordingReader()
        let day = calendar.startOfDay(for: now)
        reader.cachedSnapshot = snapshot(day: day, source: .cache, score: nil)
        reader.loadSnapshot = snapshot(day: day, score: 77.43, updatedAt: now)
        let store = TodayStore(
            reader: reader,
            clock: FixedAppClock(now: now),
            calendar: calendar
        )

        await store.send(.appear)

        XCTAssertEqual(reader.cachedCalls, 1)
        XCTAssertEqual(reader.loadCalls, 1)
        XCTAssertEqual(store.state.phase, .ready)
        XCTAssertEqual(store.state.scores.ordered.count, 5)
        XCTAssertEqual(store.state.scores.sleep.value, 77.43)
        XCTAssertEqual(store.state.scores.recovery.algorithmVersion, "1.0.0")
        XCTAssertNil(store.state.command, "Store must not rebuild command state in a getter")
    }

    @MainActor
    func testConcurrentSameDayLoadsCoalesce() async {
        let reader = RecordingReader()
        reader.loadSnapshot = snapshot(day: calendar.startOfDay(for: now), score: 81, updatedAt: now)
        reader.loadDelayNanoseconds = 50_000_000
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)

        async let first: Void = store.send(.refresh(force: false))
        async let second: Void = store.send(.refresh(force: true))
        _ = await (first, second)

        XCTAssertEqual(reader.loadCalls, 1)
        XCTAssertEqual(store.state.scores.recovery.value, 81)
    }

    @MainActor
    func testRefreshForwardsAutomaticAndForcePolicies() async {
        let reader = RecordingReader()
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)

        await store.send(.refresh(force: false))
        await store.send(.refresh(force: true))

        XCTAssertEqual(reader.policies, [.automatic, .force])
    }

    @MainActor
    func testOldDateResultCannotOverwriteNewSelectedDay() async throws {
        let reader = RecordingReader()
        let oldDay = calendar.startOfDay(for: now)
        let newDay = calendar.date(byAdding: .day, value: -1, to: oldDay)!
        reader.loadSnapshot = snapshot(day: oldDay, score: 11, updatedAt: oldDay)
        reader.loadDelayNanoseconds = 100_000_000
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)

        let oldRequest = Task { @MainActor in
            await store.send(.refresh(force: false))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        reader.loadSnapshot = snapshot(day: newDay, score: 22, updatedAt: newDay)
        await store.send(.selectDay(newDay))
        await oldRequest.value

        XCTAssertEqual(store.state.selectedDay, newDay)
        XCTAssertEqual(store.state.scores.recovery.value, 22)
        XCTAssertFalse(store.state.scores.recovery.value == 11)
    }

    @MainActor
    func testEmptyAndReaderFailureAreDistinct() async {
        let reader = RecordingReader()
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)
        await store.send(.refresh(force: false))
        XCTAssertEqual(store.state.phase, .empty)
        XCTAssertNil(store.state.scores.recovery.value)

        reader.loadError = NSError(domain: "TodayStoreTests", code: 1)
        await store.send(.refresh(force: true))
        guard case let .failed(failure) = store.state.phase,
              case .reader = failure else {
            return XCTFail("reader errors must be represented as failed, not empty")
        }
        XCTAssertNil(store.state.scores.energy.value)
    }

    @MainActor
    func testCancellationDoesNotLeaveStoreStuckLoading() async throws {
        let reader = RecordingReader()
        reader.loadDelayNanoseconds = 500_000_000
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)

        let request = Task { @MainActor in
            await store.send(.refresh(force: false))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        request.cancel()
        await request.value

        if case .loading = store.state.phase {
            XCTFail("cancellation must settle the loading phase")
        }
    }

    @MainActor
    func testFutureSelectionIsRejected() async {
        let reader = RecordingReader()
        let store = TodayStore(reader: reader, clock: FixedAppClock(now: now), calendar: calendar)
        let future = calendar.date(byAdding: .day, value: 1, to: now)!

        await store.send(.selectDay(future))

        XCTAssertEqual(store.state.selectedDay, calendar.startOfDay(for: now))
        XCTAssertEqual(store.state.phase, .failed(.invalidDay))
        XCTAssertEqual(reader.cachedCalls, 0)
    }

    @MainActor
    func testIntentActionsRouteToEffectsAndUpdateLocalProjections() async {
        let reader = RecordingReader()
        let effects = RecordingEffects()
        let store = TodayStore(
            reader: reader,
            clock: FixedAppClock(now: now),
            calendar: calendar,
            effects: effects
        )
        let checkIn = LivedStateCheckIn(stress: 2, energy: 1, soreness: 0, motivation: 1)

        await store.send(.openEvidence)
        await store.send(.openMetric(.sleep))
        await store.send(.askCoach("为什么今天要恢复？"))
        await store.send(.startTraining)
        await store.send(.requestWeather)
        await store.send(.setLivedStateAlignment(.worse))
        await store.send(.saveLivedState(checkIn))

        XCTAssertEqual(effects.openedEvidence, 1)
        XCTAssertEqual(effects.openedMetrics, [.sleep])
        XCTAssertEqual(effects.coachQuestions, ["为什么今天要恢复？"])
        XCTAssertEqual(effects.startedTraining, 1)
        XCTAssertEqual(effects.requestedWeather, 1)
        XCTAssertEqual(effects.alignments, [.worse])
        XCTAssertEqual(effects.checkIns, [checkIn])
        XCTAssertEqual(store.state.livedState.alignment, .worse)
        XCTAssertEqual(store.state.livedState.checkIn, checkIn)
    }
}

final class TodayViewStateTests: XCTestCase {
    @MainActor
    func testMissingProjectionKeepsAllScoresUnavailableAndNoAggregate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        let snapshot = TodayDashboardSnapshot(dashboard: .empty(date: day))
        let state = TodayViewState.projection(
            snapshot: snapshot,
            selectedDay: day,
            now: day,
            calendar: calendar
        )

        XCTAssertEqual(state.phase, .empty)
        XCTAssertEqual(state.freshness, .missing)
        XCTAssertEqual(state.scores.ordered.count, 5)
        XCTAssertTrue(state.scores.ordered.allSatisfy { $0.metric.value == nil })
        XCTAssertTrue(state.scores.ordered.allSatisfy { $0.metric.formattedScore == "--" })
        XCTAssertEqual(state.coverage.status, .unknown)
        XCTAssertEqual(state.coverage.title, "Checking data coverage")
        XCTAssertNil(state.command)
        XCTAssertNil(state.experience)
    }

    @MainActor
    func testFreshnessUsesInjectedClockAndMetricTimestamp() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        var dashboard = DashboardSummary.empty(date: day)
        dashboard.recovery.value = 60
        dashboard.recovery.lastUpdated = day.addingTimeInterval(-4 * 3_600)
        let state = TodayViewState.projection(
            snapshot: TodayDashboardSnapshot(dashboard: dashboard),
            selectedDay: day,
            now: day,
            calendar: calendar
        )
        XCTAssertEqual(state.freshness, .today)
    }
}
