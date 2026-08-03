import Foundation
@preconcurrency import WatchConnectivity

struct WristSnapshot: Codable, Equatable, Sendable {
    var generatedAt: Date
    var bodyStateTitle: String
    var summary: String
    var decision: String
    var decisionConfidence: Double
    var recoveryScore: Int?
    var sleepScore: Int?
    var strainScore: Int?
    var hrvMilliseconds: Int?
    var restingHeartRate: Int?
    var primaryAction: String
    var planTitle: String?
    var sessionTitle: String?
    var sessionDetail: String?
    var planProgress: String?
}

struct WristStrengthSet: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var repetitions: Int
    var weightKilograms: Double
    var isCompleted: Bool
}

struct WristStrengthExercise: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var sets: [WristStrengthSet]
}

struct WristActiveWorkout: Codable, Equatable, Sendable {
    var draftID: UUID
    var title: String
    var startedAt: Date
    var updatedAt: Date
    var exercises: [WristStrengthExercise]
}

struct WristStrengthSetEdit: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var draftID: UUID
    var exerciseID: UUID
    var setID: UUID
    var repetitions: Int
    var weightKilograms: Double
    var isCompleted: Bool
}

extension Notification.Name {
    static let wristStrengthSetEditQueued = Notification.Name("vela.wrist.strength-set-edit-queued")
}

final class WristSnapshotBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WristSnapshotBridge()

    private let cacheKey = "vela.wrist.latest-snapshot"
    private let activeWorkoutCacheKey = "vela.wrist.active-workout"
    private let pendingEditCacheKey = "vela.wrist.pending-strength-edits"
    private let encoder = JSONEncoder()
    private let lock = NSLock()
    private var latestPayload: Data?
    private var latestActiveWorkoutPayload: Data?

    override private init() {
        super.init()
        latestPayload = UserDefaults.standard.data(forKey: cacheKey)
        latestActiveWorkoutPayload = UserDefaults.standard.data(forKey: activeWorkoutCacheKey)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        if WCSession.default.activationState != .activated {
            WCSession.default.activate()
        }
    }

    func publish(
        dashboard: DashboardSummary,
        command: TodayCommandState,
        plan: TrainingPlanRecord?,
        scheduledDay: TrainingDay?
    ) {
        let completed = plan?.days.filter(\.isCompleted).count ?? 0
        let total = plan?.days.count ?? 0
        let snapshot = WristSnapshot(
            generatedAt: Date(),
            bodyStateTitle: command.bodyStateTitle,
            summary: command.summary,
            decision: command.readinessDecision.displayTitle,
            decisionConfidence: command.readinessDecision.confidence,
            recoveryScore: dashboard.recovery.hasData ? Int(dashboard.recovery.score.rounded()) : nil,
            sleepScore: dashboard.sleepScore.hasData ? Int(dashboard.sleepScore.score.rounded()) : nil,
            strainScore: dashboard.strain.hasData ? Int(dashboard.strain.score.rounded()) : nil,
            hrvMilliseconds: dashboard.recoveryMetrics.hrvMilliseconds.map { Int($0.rounded()) },
            restingHeartRate: dashboard.recoveryMetrics.restingHeartRate.map { Int($0.rounded()) },
            primaryAction: command.actions.first(where: \.isPrimary)?.title ?? "打开 iPhone 查看今日建议",
            planTitle: plan?.title,
            sessionTitle: scheduledDay?.title,
            sessionDetail: scheduledDay.map { "\($0.durationMinutes) 分钟 · \(Self.intensityLabel($0.intensity))" },
            planProgress: total > 0 ? "\(completed)/\(total) 已完成" : nil
        )
        guard let data = try? encoder.encode(snapshot) else { return }

        lock.lock()
        latestPayload = data
        lock.unlock()
        UserDefaults.standard.set(data, forKey: cacheKey)

        updateCombinedApplicationContext()
    }

    func publishActiveWorkout(_ draft: ActiveWorkoutDraftRecord) {
        let payload = WristActiveWorkout(
            draftID: draft.id,
            title: draft.title,
            startedAt: draft.startedAt,
            updatedAt: draft.lastUpdated,
            exercises: draft.exercises.map { exercise in
                WristStrengthExercise(
                    id: exercise.id,
                    name: exercise.name,
                    sets: exercise.sets.map {
                        WristStrengthSet(
                            id: $0.id,
                            repetitions: $0.repetitions,
                            weightKilograms: $0.weightKilograms,
                            isCompleted: $0.isCompleted == true
                        )
                    }
                )
            }
        )
        guard let data = try? encoder.encode(payload) else { return }
        lock.lock()
        latestActiveWorkoutPayload = data
        lock.unlock()
        UserDefaults.standard.set(data, forKey: activeWorkoutCacheKey)
        updateCombinedApplicationContext()
    }

    func clearActiveWorkout() {
        lock.lock()
        latestActiveWorkoutPayload = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: activeWorkoutCacheKey)
        updateCombinedApplicationContext()
    }

    func drainPendingStrengthSetEdits() -> [WristStrengthSetEdit] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = UserDefaults.standard.data(forKey: pendingEditCacheKey),
              let edits = try? JSONDecoder().decode([WristStrengthSetEdit].self, from: data) else {
            return []
        }
        UserDefaults.standard.removeObject(forKey: pendingEditCacheKey)
        return edits
    }

    func clearCachedSnapshot() {
        lock.lock()
        latestPayload = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        updateCombinedApplicationContext()
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        if let data = message["strengthSetEdit"] as? Data,
           let edit = try? JSONDecoder().decode(WristStrengthSetEdit.self, from: data) {
            enqueue(edit)
            replyHandler(["status": "queued", "mutationID": edit.id.uuidString])
            return
        }
        guard message["command"] as? String == "latestSnapshot" else {
            replyHandler(["status": "unsupported"])
            return
        }
        lock.lock()
        let payload = latestPayload
        let activeWorkoutPayload = latestActiveWorkoutPayload
        lock.unlock()
        if payload != nil || activeWorkoutPayload != nil {
            var response: [String: Any] = [:]
            if let payload { response["snapshot"] = payload }
            if let activeWorkoutPayload { response["activeWorkout"] = activeWorkoutPayload }
            replyHandler(response)
        } else {
            replyHandler(["status": "pending"])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo["strengthSetEdit"] as? Data,
              let edit = try? JSONDecoder().decode(WristStrengthSetEdit.self, from: data) else { return }
        enqueue(edit)
    }

    private func enqueue(_ edit: WristStrengthSetEdit) {
        lock.lock()
        var edits: [WristStrengthSetEdit] = []
        if let data = UserDefaults.standard.data(forKey: pendingEditCacheKey) {
            edits = (try? JSONDecoder().decode([WristStrengthSetEdit].self, from: data)) ?? []
        }
        if !edits.contains(where: { $0.id == edit.id }) {
            edits.append(edit)
            if let data = try? encoder.encode(Array(edits.suffix(100))) {
                UserDefaults.standard.set(data, forKey: pendingEditCacheKey)
            }
        }
        lock.unlock()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .wristStrengthSetEditQueued, object: nil)
        }
    }

    private func updateCombinedApplicationContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        lock.lock()
        let snapshot = latestPayload
        let activeWorkout = latestActiveWorkoutPayload
        lock.unlock()
        var context: [String: Any] = [:]
        if let snapshot { context["snapshot"] = snapshot } else { context["clearSnapshot"] = true }
        if let activeWorkout { context["activeWorkout"] = activeWorkout } else { context["clearActiveWorkout"] = true }
        try? WCSession.default.updateApplicationContext(context)
    }

    private static func intensityLabel(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return "低强度"
        case "high": return "高强度"
        default: return "中强度"
        }
    }
}
