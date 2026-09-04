import SwiftUI
import SwiftData
import CoreLocation
import os.log


private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "Weather")

/// Compatibility reader used while the legacy Today surface is being moved
/// behind `TodayStore`.  The adapter owns the old view-model/context bridge;
/// the Store itself still sees only `TodayDashboardSnapshot` values.
///
/// This is intentionally a transitional seam.  The root view can bind the
/// existing composition-root objects at task time without constructing a
/// second DashboardViewModel or changing any scoring code.
@MainActor
final class LegacyTodayReadingModule: TodayReadingModule {
    private weak var dashboardVM: DashboardViewModel?
    private var modelContext: ModelContext?
    private var useCase: DailySummaryUseCase?

    func bind(
        dashboardVM: DashboardViewModel,
        modelContext: ModelContext,
        useCase: DailySummaryUseCase
    ) {
        self.dashboardVM = dashboardVM
        self.modelContext = modelContext
        self.useCase = useCase
    }

    func cached(for day: Date) async throws -> TodayDashboardSnapshot? {
        guard let modelContext, let useCase else { return nil }
        return try await useCase
            .loadCachedDashboard(for: day, modelContext: modelContext)
            .map(TodayDashboardSnapshot.init(dashboard:))
    }

    func load(for day: Date, policy: TodayRefreshPolicy) async throws -> TodayDashboardSnapshot {
        guard let dashboardVM, let modelContext, let useCase else {
            return TodayDashboardSnapshot(dashboard: DashboardSummary.empty(date: day))
        }

        if policy == .cacheOnly, let cached = try await cached(for: day) {
            return cached
        }

        // The legacy VM remains the single owner of secondary projections and
        // scoring. TodayStore coordinates when this bridge is called; it does
        // not rebuild a competing decision tree.
        if !Calendar.current.isDate(dashboardVM.selectedDate, inSameDayAs: day) {
            dashboardVM.selectedDate = day
        }
        await dashboardVM.refresh(
            modelContext: modelContext,
            force: policy == .force
        )
        // Keep the use case strongly referenced for the duration of the
        // adapter's lifetime. This also makes an unbound/preview path explicit
        // above rather than falling through to a resolver or HealthKit global.
        _ = useCase
        return TodayDashboardSnapshot(dashboard: dashboardVM.dashboard)
    }
}

// MARK: - VelaTodayView Extension for Data Operations
extension VelaTodayView {

    /// Forward UI intent to the Store while preserving the existing route and
    /// sheet behavior during this incremental migration.
    func dispatchToday(_ action: TodayStoreAction) {
        Task { @MainActor in
            await todayStore.send(action)
        }
    }

    func readinessColor(_ decision: ReadinessDecisionKind) -> Color {
        switch decision {
        case .keep: return VelaTheme.success
        case .reduce: return VelaTheme.systemOrange
        case .swap: return VelaTheme.indigo
        case .recover: return VelaTheme.sleepColor
        }
    }

    func icon(for action: TodayAction) -> String {
        switch action.kind {
        case .training: return "figure.run"
        case .recovery: return "heart.fill"
        case .checkIn: return "square.and.pencil"
        case .coach: return "sparkles"
        case .insight: return "list.bullet.clipboard"
        }
    }

    func icon(for action: CoachArtifactAction) -> String {
        if action.type.contains("training") || action.type.contains("workout") { return "figure.run" }
        if action.type.contains("recovery") { return "heart.fill" }
        if action.type.contains("check") { return "square.and.pencil" }
        return "arrow.right"
    }

    func handleTodayAction(_ action: TodayAction) {
        switch action.kind {
        case .training:
            dispatchToday(.startTraining)
            appState.routeToTraining()
        case .recovery, .insight:
            dispatchToday(.openEvidence)
            presentedTodaySheet = .evidence
        case .checkIn:
            dispatchToday(.openEvidence)
            appState.present(.journal)
        case .coach:
            dispatchToday(.askCoach(action.detail))
            appState.routeToCoach(question: action.detail, surface: .home)
        }
    }

    func handleCoachArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        switch action.type {
        case "open_training_summary":
            dispatchToday(.startTraining)
            appState.routeToTraining()
        case "start_check_in":
            dispatchToday(.openEvidence)
            appState.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        case "open_recovery_detail":
            dispatchToday(.openMetric(.recovery))
            appState.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        default:
            if action.type.contains("training") || action.type.contains("workout") {
                dispatchToday(.startTraining)
                appState.routeToTraining()
            } else if action.type.contains("check") || action.type.contains("journal") {
                dispatchToday(.openEvidence)
                appState.present(.journal)
            } else if action.type.contains("recovery") {
                dispatchToday(.openMetric(.recovery))
                appState.routeToRecoveryDetail()
            } else {
                dispatchToday(.askCoach(action.label))
                appState.routeToCoach(question: action.label, surface: .home)
            }
        }
    }

    func workoutID(for action: CoachArtifactAction, artifact: CoachArtifact) -> UUID? {
        if let raw = action.payload["workout_id"], let id = UUID(uuidString: raw) {
            return id
        }
        if let raw = artifact.actions.compactMap({ $0.payload["workout_id"] }).first,
           let id = UUID(uuidString: raw) {
            return id
        }
        return nil
    }

    // MARK: - Date formatting helpers
    func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天, " + formatMonthDayString(date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天, " + formatMonthDayString(date)
        } else {
            return formatMonthDayString(date)
        }
    }

    func formatMonthDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    // MARK: - Weather Sync
    func requestWeatherUpdate() {
        dispatchToday(.requestWeather)
        switch locationManager.authorizationStatus {
        case .notDetermined:
            weatherLocation = "正在请求定位"
            locationManager.requestPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdating()
            fetchLocalWeather()
        case .denied, .restricted:
            weatherLocation = "定位未授权"
        @unknown default:
            weatherLocation = "天气暂不可用"
        }
    }

    func fetchLocalWeather() {
        Task {
            let cached = WeatherLocationStore.load()
            let live = await weatherLocationSnapshot(
                for: locationManager.location,
                fallbackDisplayName: cached?.displayName
            )

            guard let location = WeatherLocationPolicy.preferredSnapshot(
                live: live,
                cached: cached
            ) else {
                return
            }

            if live != nil {
                WeatherLocationStore.save(location)
            }

            do {
                let weather = try await WeatherService.shared.fetchWeather(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                guard !Task.isCancelled else {
                    return
                }

                weatherTemp = "\(Int(weather.temperature.rounded()))°C"
                weatherLocation = location.displayName
            } catch {
                logger.error("Failed to sync weather locally: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func weatherLocationSnapshot(
        for location: CLLocation?,
        fallbackDisplayName: String?
    ) async -> WeatherLocationSnapshot? {
        guard let location else {
            return nil
        }

        let placemark = try? await CLGeocoder()
            .reverseGeocodeLocation(location)
            .first
        let locationName = weatherLocationName(
            locality: placemark?.locality,
            administrativeArea: placemark?.administrativeArea,
            fallback: fallbackDisplayName
        )

        return WeatherLocationSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            displayName: locationName,
            capturedAt: location.timestamp
        )
    }

    func weatherLocationName(
        locality: String?,
        administrativeArea: String?,
        fallback: String?
    ) -> String {
        let parts = [locality, administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        let uniqueParts = parts.reduce(into: [String]()) { result, item in
            if !result.contains(item) {
                result.append(item)
            }
        }

        return uniqueParts.isEmpty
            ? fallback ?? "当前位置"
            : uniqueParts.joined(separator: ", ")
    }

    // MARK: - SwiftData nutrition sync
    func loadRealNutritionData() {
        Task { @MainActor in
            await dashboardVM.loadSecondaryData(modelContext: modelContext)
        }
    }

    func loadDynamicData() {
        Task { @MainActor in
            await dashboardVM.loadSecondaryData(modelContext: modelContext)
        }
    }

    /// Persistence-backed feedback lookup stays in this compatibility
    /// extension while the root view migrates to TodayStore actions.
    func loadDailyDecisionFeedback() {
        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: dashboardVM.selectedDate)
        let descriptor = FetchDescriptor<DailyDecisionFeedbackRecord>(
            predicate: #Predicate { $0.dayIdentifier == dayIdentifier }
        )
        dailyDecisionFeedback = try? modelContext.fetch(descriptor).first
    }

    func refreshDashboard(force: Bool = false) async {
        await dashboardVM.refresh(modelContext: modelContext, force: force)
        fetchLocalWeather()
    }

    func loadDataCoverageSummary() async {
        let groups = await DataCoverageGroupFactory.loadPriorityGroups()
        let summary = DataCoverageSummaryModel.build(groups: groups)
        withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
            dataCoverageSummary = summary
        }
    }
}
