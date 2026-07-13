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
    var hrvMilliseconds: Int?
    var restingHeartRate: Int?
    var primaryAction: String
    var planTitle: String?
    var sessionTitle: String?
    var sessionDetail: String?
    var planProgress: String?
}

@MainActor
private final class WatchSnapshotStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var snapshot: WatchSnapshot?
    @Published private(set) var isRequesting = false

    private let cacheKey = "vela.watch.latest-snapshot"

    override init() {
        super.init()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-velaWatchPreview") {
            snapshot = WatchSnapshot(
                generatedAt: Date(),
                bodyStateTitle: "恢复状态良好",
                summary: "睡眠与 HRV 位于个人基线范围内，今天可以按计划训练。",
                decision: "按计划训练",
                decisionConfidence: 0.86,
                recoveryScore: 82,
                sleepScore: 79,
                strainScore: 34,
                hrvMilliseconds: 58,
                restingHeartRate: 52,
                primaryAction: "开始今日下肢力量训练",
                planTitle: "四周力量进阶",
                sessionTitle: "下肢力量 · Week 2",
                sessionDetail: "50 分钟 · 中强度",
                planProgress: "5/12 已完成"
            )
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: cacheKey) {
            snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
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
            guard let data = response["snapshot"] as? Data else {
                Task { @MainActor in self?.isRequesting = false }
                return
            }
            Task { @MainActor in
                self?.apply(data)
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
        if applicationContext["clear"] as? Bool == true {
            Task { @MainActor [weak self] in self?.clear() }
            return
        }
        guard let data = applicationContext["snapshot"] as? Data else { return }
        Task { @MainActor [weak self] in self?.apply(data) }
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
                    trainingPage(snapshot)
                    signalsPage(snapshot)
                }
                .tabViewStyle(.verticalPage)
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

    private func readinessPage(_ snapshot: WatchSnapshot) -> some View {
        ScrollView {
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
                        .trim(from: 0, to: max(0.02, snapshot.decisionConfidence))
                        .stroke(decisionColor(snapshot.decision), style: StrokeStyle(lineWidth: 8, lineCap: .round))
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

                Text(snapshot.decision)
                    .font(.headline.weight(.bold))
                Text(snapshot.primaryAction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                metricRow("睡眠", snapshot.sleepScore.map(String.init) ?? "—", "moon.fill", .indigo)
                metricRow("负荷", snapshot.strainScore.map(String.init) ?? "—", "flame.fill", .orange)
                metricRow("HRV", snapshot.hrvMilliseconds.map { "\($0) ms" } ?? "—", "waveform.path.ecg", .mint)
                metricRow("静息心率", snapshot.restingHeartRate.map { "\($0)" } ?? "—", "heart.fill", .red)
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
        Text(date, style: .relative)
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
    }

    private func decisionColor(_ decision: String) -> Color {
        if decision.contains("恢复") { return .orange }
        if decision.contains("降低") || decision.contains("替换") { return .yellow }
        return Color(red: 0.48, green: 0.95, blue: 0.82)
    }
}
