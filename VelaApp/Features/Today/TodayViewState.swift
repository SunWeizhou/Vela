import Foundation

// These values are already immutable projections.  The legacy declarations
// predate Swift concurrency annotations, so the conformance is kept here at
// the feature boundary rather than making the persistence/domain layers know
// about Today.
extension DashboardSummary.DataSource: @unchecked Sendable {}
extension TodayExperienceModel: @unchecked Sendable {}
extension DailyDecisionFeedbackValues: @unchecked Sendable {}

enum TodayMetricID: String, CaseIterable, Codable, Hashable, Sendable {
    case recovery
    case sleep
    case strain
    case stress
    case energy
}

struct TodayScoreProjection: Equatable, Sendable, Identifiable {
    let id: TodayMetricID
    let metric: MetricResult
}

/// The five scores are intentionally separate.  A missing value remains
/// missing all the way to the renderer (`MetricResult.formattedScore == "--"`)
/// and is never converted into an aggregate or a zero.
struct TodayScoreState: Equatable, Sendable {
    var recovery: MetricResult
    var sleep: MetricResult
    var strain: MetricResult
    var stress: MetricResult
    var energy: MetricResult

    var ordered: [TodayScoreProjection] {
        [
            TodayScoreProjection(id: .recovery, metric: recovery),
            TodayScoreProjection(id: .sleep, metric: sleep),
            TodayScoreProjection(id: .strain, metric: strain),
            TodayScoreProjection(id: .stress, metric: stress),
            TodayScoreProjection(id: .energy, metric: energy)
        ]
    }

    func metric(for id: TodayMetricID) -> MetricResult {
        switch id {
        case .recovery: return recovery
        case .sleep: return sleep
        case .strain: return strain
        case .stress: return stress
        case .energy: return energy
        }
    }

    static func empty(for day: Date) -> TodayScoreState {
        func unavailable(_ name: String, _ input: String, _ domain: ScoredHealthDomain) -> MetricResult {
            MetricResult(
                domain: domain,
                name: name,
                value: nil,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: ["Health data unavailable."],
                missingInputs: [input],
                dataWindow: DateInterval(start: day, duration: 86_400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: day
            )
        }

        return TodayScoreState(
            recovery: unavailable("Recovery Score", "recoveryMetrics", .recovery),
            sleep: unavailable("Sleep Score", "sleepSummary", .sleep),
            strain: unavailable("Strain Score", "strain", .strain),
            stress: unavailable("Physiological Stress Index", "stress", .physiologicalStress),
            energy: unavailable("Energy Bank", "energy", .energy)
        )
    }

    init(
        recovery: MetricResult,
        sleep: MetricResult,
        strain: MetricResult,
        stress: MetricResult,
        energy: MetricResult
    ) {
        self.recovery = recovery
        self.sleep = sleep
        self.strain = strain
        self.stress = stress
        self.energy = energy
    }

    init(snapshot: DashboardSummary) {
        self.init(
            recovery: snapshot.recovery,
            sleep: snapshot.sleepScore,
            strain: snapshot.strain,
            stress: snapshot.stress,
            energy: snapshot.energy
        )
    }
}

enum TodayLoadFailure: Equatable, Sendable, LocalizedError {
    case invalidDay
    case reader(String)

    var errorDescription: String? {
        switch self {
        case .invalidDay: return "Today cannot load a future day."
        case .reader(let message): return message
        }
    }
}

struct TodayLivedStateProjection: Equatable, Sendable {
    var alignment: LivedStateAlignment?
    var checkIn: LivedStateCheckIn?

    static let empty = TodayLivedStateProjection(alignment: nil, checkIn: nil)
}

struct TodayFeedbackProjection: Equatable, Sendable {
    var isSubmitted: Bool
    var summary: String?

    static let empty = TodayFeedbackProjection(isSubmitted: false, summary: nil)
}

struct TodayPlanProjection: Equatable, Sendable {
    var title: String
    var detail: String?

    init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
    }
}

struct TodayNutritionProjection: Equatable, Sendable {
    var calories: Int?
    var calorieTarget: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?

    static let empty = TodayNutritionProjection(
        calories: nil,
        calorieTarget: nil,
        protein: nil,
        carbs: nil,
        fat: nil
    )
}

struct TodayNonCriticalState: Equatable, Sendable {
    var weatherMessage: String?
    var nutritionError: String?
    var planError: String?
    var coachError: String?

    static let empty = TodayNonCriticalState(
        weatherMessage: nil,
        nutritionError: nil,
        planError: nil,
        coachError: nil
    )
}

struct TodayViewState: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case idle
        case loading(previous: Bool)
        case ready
        case empty
        case failed(TodayLoadFailure)
    }

    let selectedDay: Date
    var phase: Phase
    var source: DashboardSummary.DataSource
    var freshness: DataFreshness
    var scores: TodayScoreState
    var command: TodayCommandState?
    var experience: TodayExperienceModel?
    var coverage: DataCoverageSummaryModel
    var livedState: TodayLivedStateProjection
    var feedback: TodayFeedbackProjection
    var plan: TodayPlanProjection?
    var nutrition: TodayNutritionProjection?
    var nonCritical: TodayNonCriticalState
    var error: TodayLoadFailure?

    /// Keep the initial state independent from the app language/preferences
    /// store.  Coverage is an explicit unknown until a reader/coverage adapter
    /// supplies a value; it must not consult a global default while rendering
    /// the first frame.
    private static var unknownCoverage: DataCoverageSummaryModel {
        DataCoverageSummaryModel(
            scorePercent: 0,
            status: .unknown,
            title: "Checking data coverage",
            subtitle: "Key health signals are being checked for freshness and completeness.",
            actionTitle: "View data",
            actionSystemImage: "waveform.path.ecg.rectangle",
            domainSummaries: [],
            topBlockers: [],
            coachContextLine: "Data coverage unknown; avoid high-confidence physiological claims until coverage finishes loading."
        )
    }

    static func initial(day: Date) -> TodayViewState {
        TodayViewState(
            selectedDay: day,
            phase: .idle,
            source: .empty,
            freshness: .missing,
            scores: .empty(for: day),
            command: nil,
            experience: nil,
            coverage: Self.unknownCoverage,
            livedState: .empty,
            feedback: .empty,
            plan: nil,
            nutrition: nil,
            nonCritical: .empty,
            error: nil
        )
    }

    static func projection(
        snapshot: TodayDashboardSnapshot,
        selectedDay: Date,
        now: Date,
        calendar: Calendar
    ) -> TodayViewState {
        let dashboard = snapshot.dashboard
        let scores = TodayScoreState(snapshot: dashboard)
        let hasEvidence = scores.ordered.contains { $0.metric.value != nil }
        return TodayViewState(
            selectedDay: selectedDay,
            phase: hasEvidence ? .ready : .empty,
            source: dashboard.source,
            freshness: Self.freshness(
                scores: scores,
                selectedDay: selectedDay,
                now: now,
                calendar: calendar
            ),
            scores: scores,
            // Command and experience are intentionally not rebuilt here.  The
            // reader may provide them in a future DTO; until then the root can
            // render the existing legacy projection without a second kernel.
            command: nil,
            experience: nil,
            coverage: Self.unknownCoverage,
            livedState: .empty,
            feedback: .empty,
            plan: nil,
            nutrition: nil,
            nonCritical: .empty,
            error: nil
        )
    }

    private static func freshness(
        scores: TodayScoreState,
        selectedDay: Date,
        now: Date,
        calendar: Calendar
    ) -> DataFreshness {
        let dates = scores.ordered.compactMap { metric in
            metric.metric.value == nil ? nil : metric.metric.lastUpdated
        }
        guard let latest = dates.max() else { return .missing }
        let age = max(0, now.timeIntervalSince(latest))
        if age <= 2 * 3_600 { return .live }
        if calendar.isDate(latest, inSameDayAs: selectedDay) { return .today }
        if age <= 3 * 86_400 { return .recent }
        return .stale
    }
}
