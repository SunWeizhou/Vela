import Foundation

/// Store-owned orchestration for one metric.  Persistence, HealthKit, and
/// trend formulas remain behind `TrendsHistoryProviding`; this type only
/// normalizes a value payload into a deterministic chart state.
@MainActor
final class TrendsStore {
    private(set) var state: TrendsViewState

    private let provider: any TrendsHistoryProviding
    private let calendar: Calendar
    private var requestGeneration: UInt64 = 0

    init(
        provider: any TrendsHistoryProviding,
        selectedDay: Date,
        calendar: Calendar = .current,
        horizon: HealthTrendHorizon = .thirtyDays,
        metric: CoreHealthMetric = .recovery
    ) {
        self.provider = provider
        self.calendar = calendar
        let day = calendar.startOfDay(for: selectedDay)
        self.state = TrendsViewState.initial(
            selectedDay: day,
            horizon: horizon,
            metric: metric
        )
    }

    func send(_ action: TrendsStoreAction) async {
        switch action {
        case .appear, .retry:
            await reload()
        case .selectDay(let requestedDay):
            state.selectedDay = calendar.startOfDay(for: requestedDay)
            state.selectedPoint = nil
            await reload()
        case .selectHorizon(let horizon):
            guard state.horizon != horizon else { return }
            state.horizon = horizon
            state.selectedPoint = nil
            await reload()
        case .selectMetric(let metric):
            guard state.metric != metric else { return }
            state.metric = metric
            state.selectedPoint = nil
            await reload()
        case .selectPoint(let date):
            state.selectedPoint = state.series?.points.first { point in
                guard let date else { return false }
                return calendar.isDate(point.date, inSameDayAs: date)
            }
        }
    }

    private func reload() async {
        requestGeneration &+= 1
        let generation = requestGeneration
        state.phase = .loading
        state.series = nil
        state.selectedPoint = nil
        state.errorMessage = nil

        do {
            let payload = try await provider.history(
                metric: state.metric,
                horizon: state.horizon,
                endingAt: state.selectedDay,
                calendar: calendar
            )
            guard generation == requestGeneration else { return }

            let series = makeSeries(from: payload)
            state.series = series
            state.phase = series.hasValue ? .ready : .empty
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            state.phase = .idle
        } catch {
            guard generation == requestGeneration else { return }
            state.phase = .failed
            state.errorMessage = error.localizedDescription
        }
    }

    private func makeSeries(from payload: TrendsHistoryPayload) -> TrendsMetricSeries {
        let selectedDay = calendar.startOfDay(for: state.selectedDay)
        let endExclusive = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        let start = calendar.date(byAdding: .day, value: -(state.horizon.windowDays - 1), to: selectedDay) ?? selectedDay

        let snapshotsByDay = payload.snapshots
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.createdAt < rhs.createdAt
            }
            .reduce(into: [Date: DailyHealthSnapshot]()) { result, snapshot in
                let day = calendar.startOfDay(for: snapshot.date)
                // The final row for a day wins, matching the persistence
                // adapter's newest-summary semantics without fabricating data.
                result[day] = snapshot
            }

        var points: [TrendsChartPoint] = []
        points.reserveCapacity(state.horizon.windowDays)
        var day = start
        while day < endExclusive {
            let snapshot = snapshotsByDay[day]
            let value: Double?
            if let snapshot {
                value = self.value(for: state.metric, snapshot: snapshot)
            } else {
                value = nil
            }
            points.append(
                TrendsChartPoint(
                    date: day,
                    value: value,
                    provenance: payload.provenanceByDay[day]
                )
            )
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? endExclusive
        }

        return TrendsMetricSeries(
            metric: state.metric,
            horizon: state.horizon,
            selectedDay: selectedDay,
            points: points,
            baselineBand: payload.baselineBand,
            finding: payload.finding
        )
    }

    private func value(
        for metric: CoreHealthMetric,
        snapshot: DailyHealthSnapshot
    ) -> Double? {
        switch metric {
        case .hrv: snapshot.hrvAverage
        case .restingHeartRate: snapshot.restingHeartRate
        case .sleepDuration: snapshot.sleepHours
        case .sleepScore: snapshot.sleepScore
        case .recovery: snapshot.recoveryScore
        case .strain: snapshot.strainScore
        case .stress: snapshot.stressIndex
        case .energy: snapshot.currentEnergy ?? snapshot.energyBank ?? snapshot.morningEnergy
        case .respiratoryRate: snapshot.respiratoryRate
        case .oxygenSaturation: snapshot.oxygenSaturation
        case .bodyWeight: snapshot.bodyWeight
        case .bodyFat: snapshot.bodyFatPercent
        case .steps: snapshot.steps
        case .activeCalories: snapshot.activeCalories
        }
    }
}
