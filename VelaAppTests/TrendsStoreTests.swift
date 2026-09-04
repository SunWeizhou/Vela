import XCTest
@testable import Vela

@MainActor
final class TrendsStoreTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testStorePreservesMissingDaysAsGapsAndDoesNotConnectSegments() async {
        let day = date(2026, 9, 4)
        var first = DailyHealthSnapshot(date: dateAdding(day, -3))
        first.recoveryScore = 60
        var last = DailyHealthSnapshot(date: day)
        last.recoveryScore = 72
        let provider = StaticTrendsHistoryProvider(
            payload: TrendsHistoryPayload(snapshots: [first, last])
        )
        let store = TrendsStore(
            provider: provider,
            selectedDay: day,
            calendar: calendar,
            horizon: .sevenDays,
            metric: .recovery
        )

        await store.send(.appear)

        XCTAssertEqual(store.state.phase, .ready)
        XCTAssertEqual(store.state.series?.points.count, 7)
        XCTAssertEqual(store.state.series?.points.filter { $0.value == nil }.count, 5)
        XCTAssertEqual(store.state.series?.nonMissingSegments.count, 2)
        XCTAssertEqual(store.state.series?.nonMissingSegments.map(\.count), [1, 1])
    }

    func testStoreCarriesBaselineBandAndPointProvenanceWithoutInventingValue() async {
        let day = date(2026, 9, 4)
        var snapshot = DailyHealthSnapshot(date: dateAdding(day, -1))
        snapshot.hrvAverage = 48
        let source = TrendsPointProvenance(
            source: .healthKit,
            sourceLabel: "Apple Health",
            detail: "Nightly HRV average"
        )
        let provider = StaticTrendsHistoryProvider(
            payload: TrendsHistoryPayload(
                snapshots: [snapshot],
                baselineBand: 42...58,
                provenanceByDay: [calendar.startOfDay(for: snapshot.date): source]
            )
        )
        let store = TrendsStore(
            provider: provider,
            selectedDay: day,
            calendar: calendar,
            horizon: .sevenDays,
            metric: .hrv
        )

        await store.send(.appear)

        XCTAssertEqual(store.state.series?.baselineBand, 42...58)
        let point = store.state.series?.points.first { $0.value == 48 }
        XCTAssertEqual(point?.provenance, source)
        XCTAssertNil(store.state.series?.points.first { $0.date == day }?.value)
    }

    func testSelectingPointReturnsMissingPointForExplicitGap() async {
        let day = date(2026, 9, 4)
        let provider = StaticTrendsHistoryProvider(payload: TrendsHistoryPayload())
        let store = TrendsStore(
            provider: provider,
            selectedDay: day,
            calendar: calendar,
            horizon: .sevenDays,
            metric: .sleepScore
        )
        await store.send(.appear)
        let gapDay = dateAdding(day, -2)
        await store.send(.selectPoint(gapDay))
        XCTAssertEqual(store.state.selectedPoint?.date, calendar.startOfDay(for: gapDay))
        XCTAssertNil(store.state.selectedPoint?.value)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func dateAdding(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }
}
