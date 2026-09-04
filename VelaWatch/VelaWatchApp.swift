import SwiftUI
@preconcurrency import WatchConnectivity

private struct WatchSnapshot: Codable, Equatable {
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

private struct WatchStrengthSet: Codable, Equatable, Identifiable {
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

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store)
        }
    }
}

private struct WatchRootView: View {
    @ObservedObject var store: WatchSnapshotStore

    var body: some View {
        Group {
            if let snapshot = store.snapshot {
                TabView {
                    readinessPage(snapshot)
                    if let activeWorkout = store.activeWorkout {
                        activeWorkoutPage(activeWorkout)
                    }
                    trainingPage(snapshot)
                    signalsPage(snapshot)
                }
                .tabViewStyle(.verticalPage)
            } else if let activeWorkout = store.activeWorkout {
                activeWorkoutPage(activeWorkout)
            } else {
                emptyState
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
        .onAppear { store.requestLatest() }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 34))
                .foregroundStyle(Color(red: 0.48, green: 0.95, blue: 0.82))
            Text("等待 Vela 状态")
                .font(.headline)
            Text("先在 iPhone 打开 Vela 并完成一次同步。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Button("重新连接") { store.requestLatest() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding()
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
