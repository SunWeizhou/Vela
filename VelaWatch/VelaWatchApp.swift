import SwiftUI
@preconcurrency import WatchConnectivity
import HealthKit
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Watch Snapshot & Models

struct WatchSnapshot: Codable, Equatable {
    var generatedAt: Date
    var bodyStateTitle: String
    var summary: String
    var decision: String
    var decisionConfidence: Double
    var recoveryScore: Int?
    var sleepScore: Int?
    var strainScore: Int?
    var stressScore: Int? = nil
    var energyScore: Int? = nil
    var hrvMilliseconds: Int?
    var restingHeartRate: Int?
    var primaryAction: String
    var planTitle: String?
    var sessionTitle: String?
    var sessionDetail: String?
    var planProgress: String?
}

struct WatchStrengthSet: Codable, Equatable, Identifiable {
    var id: UUID
    var repetitions: Int
    var weightKilograms: Double
    var isCompleted: Bool
}

private struct WatchStrengthExercise: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var sets: [WatchStrengthSet]
}

private struct WatchActiveWorkout: Codable, Equatable {
    var draftID: UUID
    var title: String
    var startedAt: Date
    var updatedAt: Date
    var exercises: [WatchStrengthExercise]
}

private struct WatchStrengthSetEdit: Codable {
    var id: UUID
    var draftID: UUID
    var exerciseID: UUID
    var setID: UUID
    var repetitions: Int
    var weightKilograms: Double
    var isCompleted: Bool
}

// MARK: - Watch HealthKit Service (Standalone Wrist Telemetry)

@MainActor
final class WatchHealthKitService: ObservableObject {
    @Published private(set) var latestHeartRate: Double? = nil
    @Published private(set) var restingHeartRate: Double? = nil
    @Published private(set) var activeEnergyBurned: Double? = nil
    @Published private(set) var hrvMilliseconds: Double? = nil
    @Published private(set) var isAuthorized = false
    @Published private(set) var isQuerying = false

    let healthStore = HKHealthStore()

    init() {
        requestAuthorization()
    }

    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let readTypes: Set<HKObjectType> = [
            hrType,
            rhrType,
            energyType,
            hrvType,
            HKObjectType.workoutType()
        ]
        let shareTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            energyType
        ]

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, _ in
            Task { @MainActor in
                self?.isAuthorized = success
                if success {
                    self?.refreshAll()
                }
            }
        }
    }

    func refreshAll() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isQuerying = true
        fetchLatestHeartRate()
        fetchRestingHeartRate()
        fetchActiveEnergy()
        fetchHRV()
    }

    private func fetchLatestHeartRate() {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            guard let sample = results?.first as? HKQuantitySample else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            Task { @MainActor in
                self?.latestHeartRate = bpm
                self?.isQuerying = false
            }
        }
        healthStore.execute(query)
    }

    private func fetchRestingHeartRate() {
        guard let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: rhrType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            guard let sample = results?.first as? HKQuantitySample else { return }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            Task { @MainActor in
                self?.restingHeartRate = bpm
            }
        }
        healthStore.execute(query)
    }

    private func fetchActiveEnergy() {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, stats, _ in
            let kcal = stats?.sumQuantity()?.doubleValue(for: .kilocalorie())
            Task { @MainActor in
                self?.activeEnergyBurned = kcal
            }
        }
        healthStore.execute(query)
    }

    private func fetchHRV() {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sort]) { [weak self] _, results, _ in
            guard let sample = results?.first as? HKQuantitySample else { return }
            let ms = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            Task { @MainActor in
                self?.hrvMilliseconds = ms
            }
        }
        healthStore.execute(query)
    }
}

// MARK: - Watch Workout Engine (Standalone Workout Tracking)

@MainActor
final class WatchWorkoutEngine: NSObject, ObservableObject, HKWorkoutSessionDelegate, HKLiveWorkoutBuilderDelegate {
    enum WorkoutKind: String, CaseIterable, Identifiable {
        case strength = "自由力量"
        case running = "户外跑步"
        case hiit = "高强度间歇"
        case recovery = "柔韧与恢复"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .strength: return "figure.strengthtraining.traditional"
            case .running: return "figure.run"
            case .hiit: return "flame.fill"
            case .recovery: return "figure.flexibility"
            }
        }
        var hkActivityType: HKWorkoutActivityType {
            switch self {
            case .strength: return .traditionalStrengthTraining
            case .running: return .running
            case .hiit: return .highIntensityIntervalTraining
            case .recovery: return .flexibility
            }
        }
        var color: Color {
            switch self {
            case .strength: return Color(red: 0.98, green: 0.55, blue: 0.24)
            case .running: return Color(red: 0.22, green: 0.72, blue: 0.62)
            case .hiit: return Color(red: 0.92, green: 0.34, blue: 0.34)
            case .recovery: return Color(red: 0.48, green: 0.95, blue: 0.82)
            }
        }
    }

    @Published private(set) var isWorkingOut = false
    @Published private(set) var currentKind: WorkoutKind = .strength
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var currentHeartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var completedSetsCount: Int = 0

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var timer: Timer?
    private let healthStore = HKHealthStore()

    func startWorkout(kind: WorkoutKind) {
        currentKind = kind
        elapsedSeconds = 0
        currentHeartRate = 0
        activeCalories = 0
        completedSetsCount = 0
        isWorkingOut = true

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = kind.hkActivityType
        configuration.locationType = kind == .running ? .outdoor : .indoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            builder = session?.associatedWorkoutBuilder()
            session?.delegate = self
            builder?.delegate = self
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

            let startDate = Date()
            session?.startActivity(with: startDate)
            builder?.beginCollection(withStart: startDate) { _, _ in }
        } catch {
            // Fallback: timer proceeds without HK session
        }

        startTimer()
    }

    func logCompletedSet() {
        completedSetsCount += 1
    }

    func finishWorkout() {
        stopTimer()
        let finishDate = Date()
        session?.end()
        builder?.endCollection(withEnd: finishDate) { [weak self] _, _ in
            self?.builder?.finishWorkout { workout, _ in
                Task { @MainActor in
                    self?.isWorkingOut = false
                    self?.session = nil
                    self?.builder = nil
                }
            }
        }
        if session == nil {
            isWorkingOut = false
        }

        // Queue sync payload to iPhone via WCSession
        if WCSession.default.activationState == .activated {
            let summary: [String: Any] = [
                "offlineWorkoutCompleted": true,
                "kind": currentKind.rawValue,
                "duration": elapsedSeconds,
                "calories": activeCalories,
                "completedAt": finishDate.timeIntervalSince1970,
                "completedSets": completedSetsCount
            ]
            WCSession.default.transferUserInfo(summary)
        }
    }

    func cancelWorkout() {
        stopTimer()
        session?.end()
        isWorkingOut = false
        session = nil
        builder = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - HKLiveWorkoutBuilderDelegate
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        for type in collectedTypes {
            guard let quantityType = type as? HKQuantityType else { continue }
            if quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate),
               let stats = workoutBuilder.statistics(for: quantityType),
               let latest = stats.mostRecentQuantity() {
                let bpm = latest.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                Task { @MainActor in self.currentHeartRate = bpm }
            } else if quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                      let stats = workoutBuilder.statistics(for: quantityType),
                      let sum = stats.sumQuantity() {
                let kcal = sum.doubleValue(for: .kilocalorie())
                Task { @MainActor in self.activeCalories = kcal }
            }
        }
    }

    // MARK: - HKWorkoutSessionDelegate
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {}
    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
}

// MARK: - Watch Snapshot Store (WCSession Bridge)

@MainActor
private final class WatchSnapshotStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchSnapshot?
    @Published private(set) var activeWorkout: WatchActiveWorkout?
    @Published private(set) var isRequesting = false

    private let cacheKey = "vela.watch.latest-snapshot"
    private let activeWorkoutCacheKey = "vela.watch.active-workout"

    override init() {
        super.init()
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let isStalePreview = arguments.contains("-velaWatchPreviewStale")
        let isMissingPreview = arguments.contains("-velaWatchPreviewMissing")
        let isPreview = arguments.contains("-velaWatchPreview") || isStalePreview || isMissingPreview
        if isPreview {
            snapshot = WatchSnapshot(
                generatedAt: isStalePreview ? Date().addingTimeInterval(-30 * 3_600) : Date(),
                bodyStateTitle: "恢复状态良好",
                summary: "睡眠与 HRV 位于个人基线范围内，今天可以按计划训练。",
                decision: "按计划训练",
                decisionConfidence: 0.86,
                recoveryScore: isMissingPreview ? nil : 82,
                sleepScore: isMissingPreview ? nil : 79,
                strainScore: isMissingPreview ? nil : 34,
                stressScore: isMissingPreview ? nil : 27,
                energyScore: isMissingPreview ? nil : 73,
                hrvMilliseconds: isMissingPreview ? nil : 58,
                restingHeartRate: isMissingPreview ? nil : 52,
                primaryAction: "开始今日下肢力量训练",
                planTitle: "四周力量进阶",
                sessionTitle: "下肢力量 · Week 2",
                sessionDetail: "50 分钟 · 中强度",
                planProgress: "5/12 已完成"
            )
        }
        if !isPreview, let data = UserDefaults.standard.data(forKey: cacheKey) {
            snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        }
        #else
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: activeWorkoutCacheKey) {
            activeWorkout = try? JSONDecoder().decode(WatchActiveWorkout.self, from: data)
        }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func requestLatest() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        isRequesting = true
        WCSession.default.sendMessage(["command": "latestSnapshot"], replyHandler: { [weak self] response in
            Task { @MainActor in
                if let data = response["snapshot"] as? Data { self?.apply(data) }
                if let data = response["activeWorkout"] as? Data { self?.applyActiveWorkout(data) }
                self?.isRequesting = false
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in self?.isRequesting = false }
        })
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor [weak self] in self?.requestLatest() }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        if applicationContext["clearSnapshot"] as? Bool == true {
            Task { @MainActor [weak self] in self?.clear() }
        }
        if applicationContext["clearActiveWorkout"] as? Bool == true {
            Task { @MainActor [weak self] in self?.clearActiveWorkout() }
        }
        if let data = applicationContext["snapshot"] as? Data {
            Task { @MainActor [weak self] in self?.apply(data) }
        }
        if let data = applicationContext["activeWorkout"] as? Data {
            Task { @MainActor [weak self] in self?.applyActiveWorkout(data) }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let data = message["snapshot"] as? Data else { return }
        Task { @MainActor [weak self] in self?.apply(data) }
    }

    private func apply(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else { return }
        snapshot = decoded
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    private func clear() {
        snapshot = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }

    func updateSet(
        exerciseID: UUID,
        setID: UUID,
        repetitions: Int,
        weightKilograms: Double,
        isCompleted: Bool
    ) {
        guard var workout = activeWorkout,
              let exerciseIndex = workout.exercises.firstIndex(where: { $0.id == exerciseID }),
              let setIndex = workout.exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else { return }
        workout.exercises[exerciseIndex].sets[setIndex].repetitions = min(999, max(0, repetitions))
        workout.exercises[exerciseIndex].sets[setIndex].weightKilograms = min(999.9, max(0, weightKilograms))
        workout.exercises[exerciseIndex].sets[setIndex].isCompleted = isCompleted
        workout.updatedAt = Date()
        activeWorkout = workout
        if let data = try? JSONEncoder().encode(workout) {
            UserDefaults.standard.set(data, forKey: activeWorkoutCacheKey)
        }

        let edit = WatchStrengthSetEdit(
            id: UUID(),
            draftID: workout.draftID,
            exerciseID: exerciseID,
            setID: setID,
            repetitions: workout.exercises[exerciseIndex].sets[setIndex].repetitions,
            weightKilograms: workout.exercises[exerciseIndex].sets[setIndex].weightKilograms,
            isCompleted: isCompleted
        )
        guard let data = try? JSONEncoder().encode(edit) else { return }
        let message: [String: Any] = ["strengthSetEdit": data]
        let session = WCSession.default
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(message, replyHandler: nil) { _ in
                session.transferUserInfo(message)
            }
        } else {
            // Not reachable OR the session isn't activated yet (first seconds after
            // launch). transferUserInfo() queues the transfer and Apple delivers it
            // once the session becomes active+reachable — this must ALWAYS enqueue so
            // an edit made before activation is not silently dropped (the old code
            // had no branch for the not-yet-activated case and lost the edit).
            session.transferUserInfo(message)
        }
    }

    private func applyActiveWorkout(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode(WatchActiveWorkout.self, from: data) else { return }
        activeWorkout = decoded
        UserDefaults.standard.set(data, forKey: activeWorkoutCacheKey)
    }

    private func clearActiveWorkout() {
        activeWorkout = nil
        UserDefaults.standard.removeObject(forKey: activeWorkoutCacheKey)
    }
}

@main
struct VelaWatchApp: App {
    @StateObject private var store = WatchSnapshotStore()
    @StateObject private var healthService = WatchHealthKitService()
    @StateObject private var workoutEngine = WatchWorkoutEngine()

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store, healthService: healthService, workoutEngine: workoutEngine)
        }
    }
}

private struct WatchRootView: View {
    @ObservedObject var store: WatchSnapshotStore
    @ObservedObject var healthService: WatchHealthKitService
    @ObservedObject var workoutEngine: WatchWorkoutEngine

    var body: some View {
        Group {
            if workoutEngine.isWorkingOut {
                WatchWorkoutSessionView(workoutEngine: workoutEngine)
            } else if let snapshot = store.snapshot {
                TabView {
                    readinessPage(snapshot)
                    if let activeWorkout = store.activeWorkout {
                        activeWorkoutPage(activeWorkout)
                    }
                    trainingPage(snapshot)
                    signalsPage(snapshot)
                    complicationsPreviewPage(snapshot)
                }
                .tabViewStyle(.verticalPage)
            } else if let activeWorkout = store.activeWorkout {
                activeWorkoutPage(activeWorkout)
            } else {
                WatchStandaloneHomeView(
                    healthService: healthService,
                    workoutEngine: workoutEngine,
                    onReconnect: { store.requestLatest() }
                )
            }
        }
        .containerBackground(
            LinearGradient(
                colors: [Color.black, Color(red: 0.035, green: 0.10, blue: 0.10)],
                startPoint: .top,
                endPoint: .bottom
            ),
            for: .navigation
        )
        .onAppear {
            store.requestLatest()
            healthService.refreshAll()
        }
    }

    private func activeWorkoutPage(_ workout: WatchActiveWorkout) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("进行中的训练", systemImage: "figure.strengthtraining.traditional")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.mint)
                Text(workout.title)
                    .font(.headline.weight(.bold))

                ForEach(workout.exercises) { exercise in
                    Text(exercise.name)
                        .font(.caption.weight(.semibold))
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        VStack(spacing: 5) {
                            HStack(spacing: 4) {
                                Button { store.updateSet(exerciseID: exercise.id, setID: set.id, repetitions: set.repetitions, weightKilograms: set.weightKilograms, isCompleted: !set.isCompleted) } label: {
                                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                                }
                                .buttonStyle(.plain)
                                Text("\(index + 1)").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg × \(set.repetitions)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                            }
                            HStack(spacing: 5) {
                                compactButton("−2.5") { store.updateSet(exerciseID: exercise.id, setID: set.id, repetitions: set.repetitions, weightKilograms: set.weightKilograms - 2.5, isCompleted: set.isCompleted) }
                                compactButton("+2.5") { store.updateSet(exerciseID: exercise.id, setID: set.id, repetitions: set.repetitions, weightKilograms: set.weightKilograms + 2.5, isCompleted: set.isCompleted) }
                                compactButton("−1") { store.updateSet(exerciseID: exercise.id, setID: set.id, repetitions: set.repetitions - 1, weightKilograms: set.weightKilograms, isCompleted: set.isCompleted) }
                                compactButton("+1") { store.updateSet(exerciseID: exercise.id, setID: set.id, repetitions: set.repetitions + 1, weightKilograms: set.weightKilograms, isCompleted: set.isCompleted) }
                            }
                        }
                        .padding(7)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func compactButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 9, weight: .bold))
            .buttonStyle(.bordered)
            .controlSize(.mini)
    }

    private func readinessPage(_ snapshot: WatchSnapshot) -> some View {
        let isStale = snapshotIsStale(snapshot)
        return ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("VELA")
                        .font(.caption2.weight(.black))
                        .tracking(1.8)
                        .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                    Spacer()
                    freshness(snapshot.generatedAt)
                }

                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: ringProgress(snapshot.recoveryScore))
                        .stroke(recoveryColor(snapshot.recoveryScore), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(snapshot.recoveryScore.map(String.init) ?? "—")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text("恢复")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                .frame(maxWidth: .infinity)
                .opacity(isStale ? 0.55 : 1)

                Text(isStale ? "状态需要更新" : snapshot.decision)
                    .font(.headline.weight(.bold))
                Text(isStale ? "请在 iPhone 打开 Vela 更新今日状态。" : snapshot.primaryAction)
                    .font(.footnote)
                    .foregroundStyle(isStale ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 4)
        }
    }

    private func trainingPage(_ snapshot: WatchSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("今日训练", systemImage: "figure.run")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                if snapshotIsStale(snapshot) {
                    Label("以下计划可能已变化", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Text(snapshot.sessionTitle ?? "今天没有待执行训练")
                    .font(.headline.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = snapshot.sessionDetail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let planTitle = snapshot.planTitle {
                    Divider()
                    Text(planTitle)
                        .font(.footnote.weight(.semibold))
                    Text(snapshot.planProgress ?? "计划进行中")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button {
                    store.requestLatest()
                } label: {
                    Label(store.isRequesting ? "同步中" : "同步最新状态", systemImage: "arrow.clockwise")
                }
                .disabled(store.isRequesting)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.22, green: 0.72, blue: 0.62))
            }
            .padding(.horizontal, 4)
        }
    }

    private func signalsPage(_ snapshot: WatchSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("关键身体信号")
                    .font(.headline.weight(.bold))
                if snapshotIsStale(snapshot) {
                    Label("历史快照", systemImage: "clock.badge.exclamationmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                metricRow("睡眠", snapshot.sleepScore.map(String.init) ?? "—", "moon.fill", recoveryColor(snapshot.sleepScore))
                metricRow("负荷", snapshot.strainScore.map(String.init) ?? "—", "flame.fill", .orange)
                metricRow("压力", snapshot.stressScore.map(String.init) ?? "—", "waveform.path.ecg", stressColor(snapshot.stressScore))
                metricRow("能量", snapshot.energyScore.map { "\($0)%" } ?? "—", "battery.75percent", energyColor(snapshot.energyScore))
                metricRow("HRV", snapshot.hrvMilliseconds.map { "\($0) ms" } ?? "—", "waveform.path.ecg", .mint)
                metricRow("静息心率", snapshot.restingHeartRate.map { "\($0) bpm" } ?? "—", "heart.fill", .red)
                Text(snapshot.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
    }

    private func complicationsPreviewPage(_ snapshot: WatchSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Label("表盘复杂功能", systemImage: "clock")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))

                Text("圆形 (Accessory Circular)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                WatchComplicationCircularView(score: snapshot.recoveryScore)
                    .frame(width: 50, height: 50)
                    .padding(4)

                Divider()

                Text("矩形 (Accessory Rectangular)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                WatchComplicationRectangularView(snapshot: snapshot, fallbackHR: healthService.latestHeartRate)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                Divider()

                Text("单行 (Accessory Inline)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                WatchComplicationInlineView(snapshot: snapshot)
                    .font(.caption2)
            }
            .padding(.horizontal, 4)
        }
    }

    private func metricRow(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
    }

    private func freshness(_ date: Date) -> some View {
        Group {
            if snapshotDateIsStale(date) {
                Label("需更新", systemImage: "clock.badge.exclamationmark")
                    .foregroundStyle(.orange)
            } else {
                Text(date, style: .relative)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 9, weight: .semibold))
    }

    private func ringProgress(_ score: Int?) -> Double {
        guard let score else { return 0 }
        return min(1, max(0, Double(score) / 100))
    }

    private func recoveryColor(_ score: Int?) -> Color {
        guard let score else { return .secondary }
        if score < 40 { return .orange }
        if score < 70 { return .yellow }
        return Color(red: 0.48, green: 0.95, blue: 0.82)
    }

    private func stressColor(_ score: Int?) -> Color {
        guard let score else { return .secondary }
        if score >= 70 { return .orange }
        if score >= 40 { return .yellow }
        return Color(red: 0.48, green: 0.95, blue: 0.82)
    }

    private func energyColor(_ score: Int?) -> Color {
        guard let score else { return .secondary }
        if score < 40 { return .orange }
        if score < 70 { return .yellow }
        return Color(red: 0.48, green: 0.95, blue: 0.82)
    }

    private func snapshotIsStale(_ snapshot: WatchSnapshot) -> Bool {
        snapshotDateIsStale(snapshot.generatedAt)
    }

    private func snapshotDateIsStale(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) > 12 * 3_600 || !Calendar.current.isDateInToday(date)
    }
}

// MARK: - Watch Complications (P3)

struct WatchComplicationCircularView: View {
    let score: Int?

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                Text(score.map(String.init) ?? "—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
        }
    }

    private var ringProgress: Double {
        guard let score = score else { return 0 }
        return min(1, max(0, Double(score) / 100))
    }

    private var scoreColor: Color {
        guard let score = score else { return .gray }
        if score < 40 { return .orange }
        if score < 70 { return .yellow }
        return Color(red: 0.48, green: 0.95, blue: 0.82)
    }
}

struct WatchComplicationRectangularView: View {
    let snapshot: WatchSnapshot?
    let fallbackHR: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                Text("恢复 \(snapshot?.recoveryScore.map { "\($0)%" } ?? "—") · \(snapshot?.decision ?? "独立模式")")
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
            }
            Text(snapshot?.sessionTitle ?? (fallbackHR.map { "当前心率 \(Int($0)) bpm" } ?? "Vela 腕上守护"))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            Text(snapshot?.primaryAction ?? "已启用本地体征感知")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct WatchComplicationInlineView: View {
    let snapshot: WatchSnapshot?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "heart.fill")
                .foregroundStyle(.red)
            Text("恢复 \(snapshot?.recoveryScore.map { "\($0)%" } ?? "—") · \(snapshot?.decision ?? "准备就绪")")
        }
    }
}

// MARK: - Watch Standalone Home View (P3)

struct WatchStandaloneHomeView: View {
    @ObservedObject var healthService: WatchHealthKitService
    @ObservedObject var workoutEngine: WatchWorkoutEngine
    let onReconnect: () -> Void

    @State private var showingLaunchSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                // 顶部独立模式指示
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color(red: 0.48, green: 0.95, blue: 0.82))
                        .frame(width: 6, height: 6)
                    Text("腕上独立模式")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                    Spacer()
                    Button {
                        healthService.refreshAll()
                        onReconnect()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }

                // 实时心率仪表
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("实时心率")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(healthService.latestHeartRate.map { "\(Int($0))" } ?? "—")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                            Text("bpm")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                // 今日活动与体征数据
                VStack(spacing: 6) {
                    HStack {
                        Label("活动能量", systemImage: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                        Spacer()
                        Text(healthService.activeEnergyBurned.map { "\(Int($0)) kcal" } ?? "—")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    HStack {
                        Label("静息心率", systemImage: "waveform.path.ecg")
                            .font(.system(size: 11))
                            .foregroundStyle(.mint)
                        Spacer()
                        Text(healthService.restingHeartRate.map { "\(Int($0)) bpm" } ?? "—")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    if let hrv = healthService.hrvMilliseconds {
                        HStack {
                            Label("HRV", systemImage: "bolt.heart.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
                            Spacer()
                            Text("\(Int(hrv)) ms")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                // 快速开始独立训练按钮
                Button {
                    showingLaunchSheet = true
                } label: {
                    Label("开始独立训练", systemImage: "play.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.22, green: 0.72, blue: 0.62))

                Text("手机不在身边时，Vela 在手腕独立感知并记录训练，重新连接后自动同步至 iPhone。")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 4)
        }
        .sheet(isPresented: $showingLaunchSheet) {
            WatchWorkoutLaunchSheet(workoutEngine: workoutEngine)
        }
    }
}

// MARK: - Watch Workout Launch Sheet & Active Session View

struct WatchWorkoutLaunchSheet: View {
    @ObservedObject var workoutEngine: WatchWorkoutEngine
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("快速发起训练")
                    .font(.headline.weight(.bold))
                    .padding(.bottom, 2)

                ForEach(WatchWorkoutEngine.WorkoutKind.allCases) { kind in
                    Button {
                        workoutEngine.startWorkout(kind: kind)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: kind.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(kind.color)
                                .frame(width: 24)
                            Text(kind.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct WatchWorkoutSessionView: View {
    @ObservedObject var workoutEngine: WatchWorkoutEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                HStack {
                    Label(workoutEngine.currentKind.rawValue, systemImage: workoutEngine.currentKind.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(workoutEngine.currentKind.color)
                    Spacer()
                    Text(timeString(from: workoutEngine.elapsedSeconds))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }

                // 实时指标行
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill").foregroundStyle(.red).font(.system(size: 10))
                            Text(workoutEngine.currentHeartRate > 0 ? "\(Int(workoutEngine.currentHeartRate))" : "—")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        Text("心率 (bpm)").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))

                    VStack(spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill").foregroundStyle(.orange).font(.system(size: 10))
                            Text(workoutEngine.activeCalories > 0 ? "\(Int(workoutEngine.activeCalories))" : "—")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        Text("千卡 (kcal)").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }

                if workoutEngine.currentKind == .strength {
                    HStack {
                        Text("已完成组数: \(workoutEngine.completedSetsCount)")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Button("+ 完成 1 组") {
                            workoutEngine.logCompletedSet()
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 10) {
                    Button("结束训练") {
                        workoutEngine.finishWorkout()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Button("取消") {
                        workoutEngine.cancelWorkout()
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
    }

    private func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

