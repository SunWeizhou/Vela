import Foundation
import SwiftUI

/// The smallest Today orchestration boundary.  It owns no persistence context,
/// platform store, or global service; those remain inside the injected reader and
/// effect adapters at the composition root.
@MainActor
final class TodayStore: ObservableObject {
    @Published private(set) var state: TodayViewState

    private let reader: any TodayReadingModule
    private let clock: any AppClock
    private let calendar: Calendar
    private let effects: any TodayEffectRouter
    private struct InFlightLoad {
        let token: UInt64
        let task: Task<TodayDashboardSnapshot, Error>
    }
    private var inFlight: [Date: InFlightLoad] = [:]
    private var nextLoadToken: UInt64 = 0
    private var requestGeneration: UInt64 = 0
    private var lastStableState: TodayViewState

    init(
        reader: any TodayReadingModule,
        clock: any AppClock,
        calendar: Calendar,
        effects: any TodayEffectRouter = NoOpTodayEffectRouter()
    ) {
        self.reader = reader
        self.clock = clock
        self.calendar = calendar
        let day = calendar.startOfDay(for: clock.now)
        let initial = TodayViewState.initial(day: day)
        self.state = initial
        self.lastStableState = initial
        self.effects = effects
    }

    func send(_ action: TodayStoreAction) async {
        switch action {
        case .appear:
            await appear()
        case .selectDay(let day):
            await selectDay(day)
        case .refresh(let force):
            await loadCurrent(policy: force ? .force : .automatic)
        case .retry:
            await loadCurrent(policy: .automatic)
        case .openCalendar:
            await effects.openCalendar()
        case .openMetric(let metric):
            await effects.openMetric(metric)
        case .openEvidence:
            await effects.openEvidence()
        case .openPlan:
            await effects.openPlan()
        case .openSettings:
            await effects.openSettings()
        case .askCoach(let question):
            await effects.askCoach(question)
        case .startTraining:
            await effects.startTraining()
        case .requestWeather:
            await effects.requestWeather()
        case .setLivedStateAlignment(let alignment):
            await effects.saveLivedStateAlignment(alignment)
            state.livedState.alignment = alignment
        case .saveLivedState(let checkIn):
            await effects.saveLivedState(checkIn)
            state.livedState.checkIn = checkIn
        case .submitFeedback(let values):
            await effects.submitFeedback(values)
            state.feedback = TodayFeedbackProjection(isSubmitted: true, summary: values.note.isEmpty ? nil : values.note)
        }
    }

    private func appear() async {
        let day = state.selectedDay
        do {
            if let cached = try await reader.cached(for: day) {
                apply(
                    TodayViewState.projection(
                        snapshot: cached,
                        selectedDay: day,
                        now: clock.now,
                        calendar: calendar
                    ),
                    generation: requestGeneration
                )
            }
        } catch is CancellationError {
            return
        } catch {
            // A cache miss/failure is non-fatal; live load below is the source
            // of truth and will surface a real reader error if it fails too.
        }
        await loadCurrent(policy: .automatic)
    }

    private func selectDay(_ requestedDay: Date) async {
        let day = calendar.startOfDay(for: requestedDay)
        guard !calendar.isDate(day, inSameDayAs: calendar.startOfDay(for: clock.now)) || day <= clock.now else {
            state.error = .invalidDay
            state.phase = .failed(.invalidDay)
            return
        }
        guard day <= clock.now else {
            state.error = .invalidDay
            state.phase = .failed(.invalidDay)
            return
        }

        requestGeneration &+= 1
        let generation = requestGeneration
        state = TodayViewState.initial(day: day)
        lastStableState = state
        // Old tasks may finish, but their generation can no longer publish into
        // this selected day.  Cancellation is only an optimisation.
        let staleKeys = inFlight.keys.filter { $0 != day }
        for key in staleKeys {
            inFlight[key]?.task.cancel()
            inFlight[key] = nil
        }
        do {
            if let cached = try await reader.cached(for: day) {
                let projection = TodayViewState.projection(
                    snapshot: cached,
                    selectedDay: day,
                    now: clock.now,
                    calendar: calendar
                )
                apply(projection, generation: generation)
            }
        } catch is CancellationError {
            return
        } catch {
            // Continue to live load.  The live reader error is the actionable
            // failure and will preserve any stable state from this day.
        }
        await load(day: day, policy: .automatic, generation: generation)
    }

    private func loadCurrent(policy: TodayRefreshPolicy) async {
        await load(day: state.selectedDay, policy: policy, generation: requestGeneration)
    }

    private func load(day: Date, policy: TodayRefreshPolicy, generation: UInt64) async {
        guard generation == requestGeneration, day == state.selectedDay else { return }
        let previous = lastStableState
        state.phase = .loading(previous: previous.phase == .ready || previous.phase == .empty)
        state.error = nil

        let load: InFlightLoad
        if let existing = inFlight[day] {
            load = existing
        } else {
            let reader = self.reader
            let task = Task { @MainActor in
                try await reader.load(for: day, policy: policy)
            }
            nextLoadToken &+= 1
            load = InFlightLoad(token: nextLoadToken, task: task)
            inFlight[day] = load
        }

        do {
            let snapshot = try await withTaskCancellationHandler(operation: {
                try await load.task.value
            }, onCancel: {
                // Tie cancellation of the caller to the shared request.  A
                // date switch also cancels this task explicitly below.
                load.task.cancel()
            })
            defer { removeInFlight(for: day, token: load.token) }
            guard generation == requestGeneration, day == state.selectedDay else { return }
            let projected = TodayViewState.projection(
                snapshot: snapshot,
                selectedDay: day,
                now: clock.now,
                calendar: calendar
            )
            apply(projected, generation: generation)
        } catch is CancellationError {
            removeInFlight(for: day, token: load.token)
            guard generation == requestGeneration, day == state.selectedDay else { return }
            state = lastStableState
        } catch {
            removeInFlight(for: day, token: load.token)
            guard generation == requestGeneration, day == state.selectedDay else { return }
            state.error = .reader(error.localizedDescription)
            state.phase = .failed(state.error!)
        }
    }

    private func apply(_ projected: TodayViewState, generation: UInt64) {
        guard generation == requestGeneration, projected.selectedDay == state.selectedDay else { return }
        state = projected
        lastStableState = projected
    }

    private func removeInFlight(for day: Date, token: UInt64) {
        guard inFlight[day]?.token == token else { return }
        inFlight[day] = nil
    }
}
