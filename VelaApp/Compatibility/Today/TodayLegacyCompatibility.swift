import SwiftUI
import SwiftData
import CoreLocation
import Combine
import os.log

/// Explicit composition-root handoff for the parts of the legacy Today
/// surface that still depend on SwiftData, location, weather, and routing.
///
/// The root view only sees this facade. Live construction belongs to the shell
/// (which already owns the environment model context and app objects); the
/// default initializer is deliberately inert for previews and isolated tests.
@MainActor
final class TodayLegacyRuntime {
    enum RuntimeError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "今日兼容运行时暂不可用"
        }
    }

    typealias WeatherFetcher = @Sendable (Double, Double) async throws -> VelaWeather

    private let modelContext: ModelContext?
    private let useCase: DailySummaryUseCase?
    private weak var appState: VelaAppState?
    private weak var locationManager: LocationManager?
    private let fetchWeather: WeatherFetcher
    private let loadWeatherLocation: () -> WeatherLocationSnapshot?
    private let saveWeatherLocation: (WeatherLocationSnapshot) -> Void
    private let readCalorieTarget: () -> Int?
    /// The Store is the source of truth for the selected day.  The runtime
    /// keeps a compatibility copy only so effect adapters can address the
    /// persistence records without asking the root view for a date.
    private(set) var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    private weak var dashboardVM: DashboardViewModel?

    init(
        modelContext: ModelContext? = nil,
        useCase: DailySummaryUseCase? = nil,
        appState: VelaAppState? = nil,
        locationManager: LocationManager? = nil,
        fetchWeather: @escaping WeatherFetcher = { _, _ in throw RuntimeError.unavailable },
        loadWeatherLocation: @escaping () -> WeatherLocationSnapshot? = { nil },
        saveWeatherLocation: @escaping (WeatherLocationSnapshot) -> Void = { _ in },
        readCalorieTarget: @escaping () -> Int? = { nil }
    ) {
        self.modelContext = modelContext
        self.useCase = useCase
        self.appState = appState
        self.locationManager = locationManager
        self.fetchWeather = fetchWeather
        self.loadWeatherLocation = loadWeatherLocation
        self.saveWeatherLocation = saveWeatherLocation
        self.readCalorieTarget = readCalorieTarget
    }

    static let preview = TodayLegacyRuntime()

    var dailyCalorieTarget: Int? {
        guard let value = readCalorieTarget(), value > 0 else { return nil }
        return value
    }

    var localDataRevision: Int {
        appState?.localDataRevision ?? 0
    }

    var authorizationStatus: CLAuthorizationStatus {
        locationManager?.authorizationStatus ?? .notDetermined
    }

    var currentLocation: CLLocation? {
        locationManager?.location
    }

    /// A publisher allows the root surface to react to location changes without
    /// importing CoreLocation or observing the legacy manager directly.
    var locationUpdates: AnyPublisher<CLLocation?, Never> {
        locationManager?.$location.eraseToAnyPublisher()
            ?? Just(nil).eraseToAnyPublisher()
    }

    func bind(reader: LegacyTodayReadingModule, dashboardVM: DashboardViewModel) {
        reader.bind(dashboardVM: dashboardVM, runtime: self)
        self.dashboardVM = dashboardVM
    }

    func setSelectedDay(_ day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
    }

    func startLocationUpdates() {
        locationManager?.startUpdating()
    }

    func requestLocationPermission() {
        locationManager?.requestPermission()
    }

    func routeToTraining() {
        appState?.routeToTraining()
    }

    func routeToTrends() {
        appState?.routeToTrends()
    }

    func routeToRecoveryDetail() {
        appState?.routeToRecoveryDetail()
    }

    func routeToPostWorkoutCheckIn(workoutID: UUID?) {
        appState?.routeToPostWorkoutCheckIn(workoutID: workoutID)
    }

    func routeToPostWorkoutImpact(workoutID: UUID?) {
        appState?.routeToPostWorkoutImpact(workoutID: workoutID)
    }

    func routeToCoach(question: String?, surface: CoachScreenSurface = .home) {
        appState?.routeToCoach(question: question, surface: surface)
    }

    func present(_ sheet: VelaAppState.AppSheet) {
        appState?.present(sheet)
    }

    func markLocalDataChanged() {
        appState?.markLocalDataChanged()
    }

    /// Requesting weather is an effect, not a Today rendering concern. The
    /// location publisher will deliver the eventual coordinate to the
    /// compatibility weather reader used by the surface.
    func requestWeather() {
        switch authorizationStatus {
        case .notDetermined:
            requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func cachedDashboard(for day: Date) async throws -> TodayDashboardSnapshot? {
        guard let modelContext, let useCase else { return nil }
        return try await useCase
            .loadCachedDashboard(for: day, modelContext: modelContext)
            .map { dashboard in
                TodayDashboardSnapshot(
                    dashboard: dashboard,
                    livedState: livedStateProjection(for: day),
                    feedback: decisionFeedbackProjection(for: day)
                )
            }
    }

    func loadDashboard(
        for day: Date,
        policy: TodayRefreshPolicy,
        dashboardVM: DashboardViewModel
    ) async throws -> TodayDashboardSnapshot {
        guard let modelContext, let useCase else {
            return TodayDashboardSnapshot(dashboard: DashboardSummary.empty(date: day))
        }

        if policy == .cacheOnly, let cached = try await cachedDashboard(for: day) {
            return cached
        }

        if !Calendar.current.isDate(dashboardVM.selectedDate, inSameDayAs: day) {
            dashboardVM.selectedDate = day
        }
        await dashboardVM.refresh(
            modelContext: modelContext,
            force: policy == .force
        )
        _ = useCase
        return TodayDashboardSnapshot(
            dashboard: dashboardVM.dashboard,
            livedState: livedStateProjection(for: day),
            feedback: decisionFeedbackProjection(for: day)
        )
    }

    func loadSecondaryData(for dashboardVM: DashboardViewModel) async {
        guard let modelContext else { return }
        await dashboardVM.loadSecondaryData(modelContext: modelContext)
    }

    func refreshDashboard(_ dashboardVM: DashboardViewModel, force: Bool) async {
        guard let modelContext else { return }
        await dashboardVM.refresh(modelContext: modelContext, force: force)
    }

    func fetchWeather(latitude: Double, longitude: Double) async throws -> VelaWeather {
        try await fetchWeather(latitude, longitude)
    }

    func cachedWeatherLocation() -> WeatherLocationSnapshot? {
        loadWeatherLocation()
    }

    func saveWeatherLocation(_ snapshot: WeatherLocationSnapshot) {
        saveWeatherLocation(snapshot)
    }

    func loadDailyDecisionFeedback(for date: Date) -> DailyDecisionFeedbackRecord? {
        guard let modelContext else { return nil }
        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: date)
        let descriptor = FetchDescriptor<DailyDecisionFeedbackRecord>(
            predicate: #Predicate { $0.dayIdentifier == dayIdentifier }
        )
        return try? modelContext.fetch(descriptor).first
    }

    /// Converts the SwiftData journal record into a value-only Today read model
    /// before it crosses the compatibility boundary.  TodayStore/ViewState do
    /// not retain or expose the persistence record.
    func decisionFeedbackProjection(for date: Date) -> TodayFeedbackProjection? {
        guard let record = loadDailyDecisionFeedback(for: date) else { return nil }
        return TodayFeedbackProjection(
            isSubmitted: record.isCompleted,
            summary: record.note.isEmpty ? nil : record.note,
            adoptionStatus: record.adoptionStatus,
            accuracyRating: record.accuracyRating,
            actualAction: record.actualAction,
            energyRating: record.energyRating,
            fatigueRating: record.fatigueRating,
            painRating: record.painRating,
            satisfactionRating: record.satisfactionRating,
            note: record.note.isEmpty ? nil : record.note
        )
    }

    /// The journal adapter already owns decoding and validation.  Return its
    /// immutable value projection rather than leaking the adapter or model
    /// context into TodayStore.
    func livedStateProjection(for date: Date) -> TodayLivedStateProjection {
        TodayLivedStateProjection(
            alignment: livedStateAlignment(for: date),
            checkIn: loadLivedStateCheckIn(for: date)
        )
    }

    func saveLivedStateAlignment(
        _ alignment: LivedStateAlignment,
        for date: Date
    ) throws {
        guard let modelContext else { throw RuntimeError.unavailable }
        try LivedStateJournalAdapter(modelContext: modelContext).saveAlignment(
            alignment,
            for: date
        )
    }

    func livedStateAlignment(for date: Date) -> LivedStateAlignment? {
        guard let modelContext else { return nil }
        return try? LivedStateJournalAdapter(modelContext: modelContext)
            .snapshot(for: date).alignment
    }

    func saveLivedStateCheckIn(_ checkIn: LivedStateCheckIn, for date: Date) throws {
        guard let modelContext else { throw RuntimeError.unavailable }
        try LivedStateJournalAdapter(modelContext: modelContext).saveCheckIn(
            checkIn,
            for: date
        )
    }

    func loadLivedStateCheckIn(for date: Date) -> LivedStateCheckIn? {
        guard let modelContext else { return nil }
        return try? LivedStateJournalAdapter(modelContext: modelContext)
            .snapshot(for: date).checkIn
    }

    @discardableResult
    func recordDecisionViewed(
        plan: DailyOperatingPlanRecord?,
        bodyStateHash: String,
        decisionType: String,
        decisionTitle: String
    ) throws -> DailyDecisionFeedbackRecord {
        guard let modelContext, let plan else { throw RuntimeError.unavailable }
        return try DailyDecisionFeedbackService().recordViewed(
            modelContext: modelContext,
            dayIdentifier: plan.dayIdentifier,
            plan: plan,
            bodyStateHash: bodyStateHash,
            decisionType: decisionType,
            decisionTitle: decisionTitle
        )
    }

    @discardableResult
    func recordDecisionAction(
        plan: DailyOperatingPlanRecord,
        bodyStateHash: String,
        decisionType: String,
        decisionTitle: String,
        destination: String
    ) throws -> DailyDecisionFeedbackRecord {
        guard let modelContext else { throw RuntimeError.unavailable }
        return try DailyDecisionFeedbackService().recordActionStarted(
            modelContext: modelContext,
            dayIdentifier: plan.dayIdentifier,
            plan: plan,
            bodyStateHash: bodyStateHash,
            decisionType: decisionType,
            decisionTitle: decisionTitle,
            destination: destination
        )
    }

    func saveDecisionFeedback(
        _ values: DailyDecisionFeedbackValues,
        record: DailyDecisionFeedbackRecord,
        dashboardVM: DashboardViewModel
    ) throws {
        guard let modelContext else { throw RuntimeError.unavailable }
        try DailyDecisionFeedbackService().saveFeedback(
            modelContext: modelContext,
            record: record,
            adoptionStatus: values.adoptionStatus,
            accuracyRating: values.accuracyRating,
            actualAction: values.actualAction,
            energyRating: values.energyRating,
            fatigueRating: values.fatigueRating,
            painRating: values.painRating,
            satisfactionRating: values.satisfactionRating,
            note: values.note
        )
        dashboardVM.applyFeedbackCalibration(modelContext: modelContext)
    }

    /// Effect-router entry point for feedback. It resolves the current
    /// record inside the compatibility boundary and keeps revision
    /// notification adjacent to the persistence write.
    func saveDecisionFeedback(_ values: DailyDecisionFeedbackValues) throws {
        guard let record = loadDailyDecisionFeedback(for: selectedDay),
              let dashboardVM else { throw RuntimeError.unavailable }
        try saveDecisionFeedback(values, record: record, dashboardVM: dashboardVM)
        markLocalDataChanged()
    }
}
// MARK: - Lived State Check-in

/// A 10-second subjective calibration. It writes through the existing journal
/// Adapter, then Today refreshes the shared Daily Intelligence Module.
struct LivedStateCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.todayLegacyRuntime) private var todayLegacyRuntime
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let selectedDate: Date
    var onSaved: () -> Void
    /// Today supplies this callback to route the write through TodayStore.
    /// Legacy app-sheet callers omit it and retain the existing compatibility
    /// fallback until those surfaces migrate.
    var onSubmit: ((LivedStateCheckIn) -> Void)? = nil

    @State private var stress = 1
    @State private var energy = 1
    @State private var soreness = 0
    @State private var motivation = 1
    @State private var note = ""
    @State private var saveError: String?
    @State private var didLoadExisting = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充你的身体感受")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text("它会参与建议，但不会改写五项分数。")
                            .font(.body)
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 20) {
                        ratingRow(
                            title: "压力",
                            detail: "此刻的心理与生活压力",
                            labels: ["低", "适中", "高"],
                            selection: $stress
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "精力",
                            detail: "现在的清醒度与身体能量",
                            labels: ["低", "稳定", "充足"],
                            selection: $energy
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "酸痛",
                            detail: "肌肉或关节的主观不适",
                            labels: ["无", "轻微", "明显"],
                            selection: $soreness
                        )
                        Divider().overlay(VelaTheme.rhythmMist)
                        ratingRow(
                            title: "训练动力",
                            detail: "今天投入训练的意愿",
                            labels: ["低", "稳定", "强"],
                            selection: $motivation
                        )
                    }
                    .padding(18)
                    .velaNativeCard(radius: VelaTheme.radiusCardLarge)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("补充说明（可选）")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                        TextField("例如：左肩有刺痛，昨晚临时加班", text: $note, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...5)
                            .padding(14)
                            .background(
                                VelaTheme.rhythmCanvasRaised,
                                in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                            }
                    }
                }
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(VelaTheme.rhythmCanvas)
            .navigationTitle("校准今日状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Text("保存并刷新今日建议")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.rhythmDeepOn)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(
                            VelaTheme.rhythmDeep,
                            in: RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                        )
                }
                .buttonStyle(.cardPress)
                .dynamicTypeSize(
                    dynamicTypeSize.isAccessibilitySize ? .accessibility1 : dynamicTypeSize
                )
                .padding(.horizontal, VelaTheme.pagePadding)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
        }
        .alert("无法保存自评", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("好", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "请稍后重试。")
        }
        .task {
            loadExistingCheckIn()
        }
        .accessibilityIdentifier("lived-state-check-in")
    }

    private func ratingRow(
        title: String,
        detail: String,
        labels: [String],
        selection: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    ForEach(labels.indices, id: \.self) { index in
                        ratingButton(
                            title: title,
                            label: labels[index],
                            index: index,
                            selection: selection
                        )
                    }
                }
            } else {
                HStack(spacing: 8) {
                    ForEach(labels.indices, id: \.self) { index in
                        ratingButton(
                            title: title,
                            label: labels[index],
                            index: index,
                            selection: selection
                        )
                    }
                }
            }
        }
    }

    private func ratingButton(
        title: String,
        label: String,
        index: Int,
        selection: Binding<Int>
    ) -> some View {
        let isSelected = selection.wrappedValue == index
        return Button {
            selection.wrappedValue = index
            VelaHaptic.selection()
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? VelaTheme.rhythmDeepOn : VelaTheme.rhythmInk)
                .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget)
                .background(
                    isSelected ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist.opacity(0.48),
                    in: RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title)，\(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save() {
        let checkIn = LivedStateCheckIn(
            stress: stress,
            energy: energy,
            soreness: soreness,
            motivation: motivation,
            note: note
        )
        if let onSubmit {
            onSubmit(checkIn)
            VelaHaptic.success()
            onSaved()
            dismiss()
            return
        }
        do {
            try todayLegacyRuntime.saveLivedStateCheckIn(checkIn, for: selectedDate)
            VelaHaptic.success()
            onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func loadExistingCheckIn() {
        guard !didLoadExisting else { return }
        didLoadExisting = true
        guard let existing = todayLegacyRuntime.loadLivedStateCheckIn(for: selectedDate) else { return }
        stress = existing.stress
        energy = existing.energy
        soreness = existing.soreness
        motivation = existing.motivation
        note = existing.note
    }
}

private struct TodayLegacyRuntimeKey: EnvironmentKey {
    nonisolated static var defaultValue: TodayLegacyRuntime {
        MainActor.assumeIsolated {
            TodayLegacyRuntime.preview
        }
    }
}

extension EnvironmentValues {
    var todayLegacyRuntime: TodayLegacyRuntime {
        get { self[TodayLegacyRuntimeKey.self] }
        set { self[TodayLegacyRuntimeKey.self] = newValue }
    }
}

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "Weather")

/// Composition-root effect adapter for Today actions that leave the Today
/// surface. Local sheets remain surface-owned; cross-app navigation is routed
/// exactly once through this adapter instead of being sent both to
/// `TodayStore` and directly to `VelaAppState` by the root view.
@MainActor
final class TodayLegacyEffectRouter: TodayEffectRouter {
    private weak var runtime: TodayLegacyRuntime?

    func bind(runtime: TodayLegacyRuntime) {
        self.runtime = runtime
    }

    // Calendar, metric, and evidence are local Today sheets. Their Store
    // actions are retained for state/event semantics; presentation is owned by
    // VelaTodayView so the adapter does not need to retain view state.
    func openCalendar() async {}
    func openMetric(_ metric: TodayMetricID) async {}
    func openEvidence() async {}

    func openPlan() async {
        runtime?.routeToTraining()
    }

    func openSettings() async {
        runtime?.present(.settings)
    }

    func askCoach(_ question: String) async {
        runtime?.routeToCoach(question: question, surface: .home)
    }

    func startTraining() async {
        runtime?.routeToTraining()
    }

    func requestWeather() async {
        runtime?.requestWeather()
    }

    func saveLivedStateAlignment(_ alignment: LivedStateAlignment) async {
        guard let runtime else { return }
        do {
            try runtime.saveLivedStateAlignment(alignment, for: runtime.selectedDay)
            runtime.markLocalDataChanged()
        } catch {
            // TodayStore keeps the value projection optimistic; persistence
            // failures remain non-fatal to the renderer and are retried by
            // the next refresh.
        }
    }

    func saveLivedState(_ checkIn: LivedStateCheckIn) async {
        guard let runtime else { return }
        do {
            try runtime.saveLivedStateCheckIn(checkIn, for: runtime.selectedDay)
            runtime.markLocalDataChanged()
        } catch {
            // See alignment handling above.
        }
    }

    func submitFeedback(_ values: DailyDecisionFeedbackValues) async {
        guard let runtime else { return }
        do {
            try runtime.saveDecisionFeedback(values)
        } catch {
            // Feedback is an auxiliary journal; a failed write must not block
            // the primary Today decision surface.
        }
    }
}

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
    // The shell may recreate the environment facade while SwiftUI reevaluates
    // its body. Keep the bound runtime alive for the in-flight TodayStore load;
    // the runtime does not retain this reader, so this is not a cycle.
    private var runtime: TodayLegacyRuntime?

    func bind(
        dashboardVM: DashboardViewModel,
        runtime: TodayLegacyRuntime
    ) {
        self.dashboardVM = dashboardVM
        self.runtime = runtime
    }

    func cached(for day: Date) async throws -> TodayDashboardSnapshot? {
        guard let runtime else { return nil }
        return try await runtime.cachedDashboard(for: day)
    }

    func load(for day: Date, policy: TodayRefreshPolicy) async throws -> TodayDashboardSnapshot {
        guard let dashboardVM, let runtime else {
            return TodayDashboardSnapshot(dashboard: DashboardSummary.empty(date: day))
        }
        let dashboard = try await runtime.loadDashboard(
            for: day,
            policy: policy,
            dashboardVM: dashboardVM
        )
        return TodayDashboardSnapshot(
            dashboard: dashboard.dashboard,
            bodyState: dashboardVM.dashboard.bodyState,
            trainingDecision: dashboardVM.dailyTrainingDecision,
            command: dashboardVM.todayCommandState,
            experience: dashboardVM.todayExperience,
            todayAIInsight: dashboardVM.todayAIInsight,
            nutrition: VelaFeatureFlags.nutritionEnabled
                ? TodayNutritionProjection(
                    calories: dashboardVM.todayCalories,
                    calorieTarget: runtime.dailyCalorieTarget,
                    protein: dashboardVM.todayProtein,
                    carbs: dashboardVM.todayCarbs,
                    fat: dashboardVM.todayFat
                )
                : nil,
            livedState: runtime.livedStateProjection(for: day),
            feedback: runtime.decisionFeedbackProjection(for: day),
            operatingPlanPayload: dashboardVM.persistedOperatingPlanPayload,
            lastUpdated: dashboardVM.lastUpdated,
            vitalTrendSeries: dashboardVM.vitalTrendSeries,
            errorMessage: dashboardVM.errorMessage,
            secondaryDataErrorMessage: dashboardVM.secondaryDataErrorMessage
        )
    }
}

// MARK: - VelaTodayView Extension for Data Operations
extension VelaTodayView {

    /// Legacy renderer projections stay behind this compatibility boundary;
    /// the root view consumes already-built values instead of invoking kernels
    /// from computed properties or body expressions.
    var todayCommandState: TodayCommandState {
        todayStore.state.command
            ?? TodayViewState.unavailableCommand(for: todayStore.state.selectedDay)
    }

    var todayAIInsight: DailyAIInsight? {
        todayStore.state.todayAIInsight
    }

    var todayExperience: TodayExperienceModel {
        todayStore.state.experience
            ?? TodayViewState.unavailableExperience(for: todayStore.state.selectedDay)
    }

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
        case .recovery, .insight:
            dispatchToday(.openEvidence)
            presentedTodaySheet = .evidence
        case .checkIn:
            dispatchToday(.openEvidence)
            todayLegacyRuntime.present(.journal)
        case .coach:
            dispatchToday(.askCoach(action.detail))
        }
    }

    func handleCoachArtifactAction(_ action: CoachArtifactAction, artifact: CoachArtifact) {
        switch action.type {
        case "open_training_summary":
            dispatchToday(.startTraining)
        case "start_check_in":
            dispatchToday(.openEvidence)
            todayLegacyRuntime.routeToPostWorkoutCheckIn(workoutID: workoutID(for: action, artifact: artifact))
        case "open_recovery_detail":
            dispatchToday(.openMetric(.recovery))
            todayLegacyRuntime.routeToPostWorkoutImpact(workoutID: workoutID(for: action, artifact: artifact))
        default:
            if action.type.contains("training") || action.type.contains("workout") {
                dispatchToday(.startTraining)
            } else if action.type.contains("check") || action.type.contains("journal") {
                dispatchToday(.openEvidence)
                todayLegacyRuntime.present(.journal)
            } else if action.type.contains("recovery") {
                dispatchToday(.openMetric(.recovery))
                todayLegacyRuntime.routeToRecoveryDetail()
            } else {
                dispatchToday(.askCoach(action.label))
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
        switch todayLegacyRuntime.authorizationStatus {
        case .notDetermined:
            weatherLocation = "正在请求定位"
        case .authorizedWhenInUse, .authorizedAlways:
            break
        case .denied, .restricted:
            weatherLocation = "定位未授权"
        @unknown default:
            weatherLocation = "天气暂不可用"
        }
    }

    func fetchLocalWeather() {
        Task {
            let cached = todayLegacyRuntime.cachedWeatherLocation()
            let live = await weatherLocationSnapshot(
                for: todayLegacyRuntime.currentLocation,
                fallbackDisplayName: cached?.displayName
            )

            guard let location = WeatherLocationPolicy.preferredSnapshot(
                live: live,
                cached: cached
            ) else {
                return
            }

            if live != nil {
                todayLegacyRuntime.saveWeatherLocation(location)
            }

            do {
                let weather = try await todayLegacyRuntime.fetchWeather(
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
            await todayLegacyRuntime.loadSecondaryData(for: dashboardVM)
        }
    }

    func loadDynamicData() {
        Task { @MainActor in
            await todayLegacyRuntime.loadSecondaryData(for: dashboardVM)
        }
    }

    /// Persistence-backed feedback lookup stays in this compatibility
    /// extension while the root view migrates to TodayStore actions.
    func loadDailyDecisionFeedback() {
        dailyDecisionFeedback = todayLegacyRuntime.loadDailyDecisionFeedback(
            for: todayStore.state.selectedDay
        )
    }

    func refreshDashboard(force: Bool = false) async {
        await todayLegacyRuntime.refreshDashboard(dashboardVM, force: force)
        fetchLocalWeather()
    }

    func loadDataCoverageSummary() async {
        let groups = await DataCoverageGroupFactory.loadPriorityGroups()
        let summary = DataCoverageSummaryModel.build(groups: groups)
        withAnimation(VelaTheme.dataAnimation(reduceMotion: reduceMotion)) {
            dataCoverageSummary = summary
        }
    }

    func saveLivedStateAlignment(_ alignment: LivedStateAlignment) {
        selectedLivedStateAlignment = alignment
        VelaHaptic.selection()
        dispatchToday(.setLivedStateAlignment(alignment))
    }

    func loadTodayLivedStateAlignment() {
        // TodayStore owns the value projection. The persistence lookup stays
        // behind LegacyTodayReadingModule and is not repeated by the root.
        selectedLivedStateAlignment = todayStore.state.livedState.alignment
    }

    func trackDailyDecisionViewed() {
        guard Calendar.current.isDateInToday(todayStore.state.selectedDay),
              let plan = persistedOperatingPlan else {
            loadDailyDecisionFeedback()
            return
        }
        do {
            dailyDecisionFeedback = try todayLegacyRuntime.recordDecisionViewed(
                plan: plan,
                bodyStateHash: bodyState.hash,
                decisionType: plan.primaryActionType,
                decisionTitle: plan.title
            )
        } catch {
            loadDailyDecisionFeedback()
        }
    }

    func trackDailyDecisionAction(destination: String) {
        guard let plan = persistedOperatingPlan else { return }
        do {
            dailyDecisionFeedback = try todayLegacyRuntime.recordDecisionAction(
                plan: plan,
                bodyStateHash: bodyState.hash,
                decisionType: plan.primaryActionType,
                decisionTitle: plan.title,
                destination: destination
            )
        } catch {
            // The user action must never be blocked by local analytics.
        }
    }

    func saveDailyDecisionFeedback(_ values: DailyDecisionFeedbackValues) {
        guard dailyDecisionFeedback != nil else { return }
        // Persistence and revision notification are owned by the injected
        // effect router. The root only emits the single Store intent.
        presentedTodaySheet = nil
        dispatchToday(.submitFeedback(values))
    }
}
