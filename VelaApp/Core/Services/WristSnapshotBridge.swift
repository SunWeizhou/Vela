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

final class WristSnapshotBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WristSnapshotBridge()

    private let cacheKey = "vela.wrist.latest-snapshot"
    private let encoder = JSONEncoder()
    private let lock = NSLock()
    private var latestPayload: Data?

    override private init() {
        super.init()
        latestPayload = UserDefaults.standard.data(forKey: cacheKey)
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

        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        do {
            try WCSession.default.updateApplicationContext(["snapshot": data])
        } catch {
            // The local cache remains authoritative and will be retried on the next dashboard refresh.
        }
    }

    func clearCachedSnapshot() {
        lock.lock()
        latestPayload = nil
        lock.unlock()
        UserDefaults.standard.removeObject(forKey: cacheKey)
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(["clear": true])
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
        guard message["command"] as? String == "latestSnapshot" else {
            replyHandler(["status": "unsupported"])
            return
        }
        lock.lock()
        let payload = latestPayload
        lock.unlock()
        if let payload {
            replyHandler(["snapshot": payload])
        } else {
            replyHandler(["status": "pending"])
        }
    }

    private static func intensityLabel(_ intensity: String) -> String {
        switch intensity.lowercased() {
        case "low": return "低强度"
        case "high": return "高强度"
        default: return "中强度"
        }
    }
}
