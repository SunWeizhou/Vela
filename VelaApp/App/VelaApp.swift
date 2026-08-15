import SwiftUI
import SwiftData
import BackgroundTasks
import AppIntents
import UserNotifications

@MainActor
final class VelaAppState: ObservableObject {
    static let todayTabIndex = 0
    static let trainingTabIndex = 1
    static let coachTabIndex = 2
    static let meTabIndex = 3
    nonisolated private static let validTabIndices = 0...3

    enum CoachRouteDestination {
        case embedded
        case quickCover
    }

    enum DeferredQuickAction: Equatable {
        case coach(String?)
        case foodScanner(String)
        case foodSearch
        case workoutLog
        case journal
    }

    @Published var isFallbackStore = false
    @Published var isReadOnlySafetyMode = false
    @Published var selectedTab = VelaAppState.todayTabIndex
    @Published var showCoachHub = false
    @Published var showSettings = false
    @Published var prefilledCoachQuestion: String? = nil
    @Published var homeNavigationStackId = UUID()
    
    // Quick Actions Triggers
    @Published var triggerFoodCamera = false
    @Published var triggerFoodLibrary = false
    @Published var triggerBloodLog = false
    @Published var triggerWeightLog = false
    @Published var triggerWorkoutLog = false
    @Published var triggerFoodSearch = false
    @Published var triggerFoodScanner = false
    @Published var triggerJournal = false
    @Published var triggerRecoveryDetail = false
    @Published var triggerPostWorkoutCheckIn = false
    @Published var triggerPostWorkoutImpact = false
    @Published var scannerType = "camera"
    @Published var postWorkoutCheckInWorkoutID: UUID?
    @Published var postWorkoutImpactWorkoutID: UUID?
    @Published var forceNewCoachSession = false
    @Published private(set) var coachRouteDestination: CoachRouteDestination?
    @Published private(set) var coachRouteRevision = 0
    @Published private(set) var localDataRevision = 0
    @Published private(set) var adaptiveTrainingStartRequest = 0
    @Published private(set) var deferredQuickAction: DeferredQuickAction?
    
    static let shared = VelaAppState()

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        #if DEBUG
        selectedTab = Self.initialTab(from: arguments)
        #endif
    }

    nonisolated static func initialTab(from arguments: [String]) -> Int {
        guard let flagIndex = arguments.firstIndex(of: "-velaInitialTab"),
              arguments.indices.contains(arguments.index(after: flagIndex)),
              let tab = Int(arguments[arguments.index(after: flagIndex)]),
              validTabIndices.contains(tab) else {
            return 0
        }
        return tab
    }

    func routeToCoach(question: String?) {
        prepareCoachRoute(question: question)
        coachRouteDestination = .embedded
        showCoachHub = false
        selectedTab = Self.coachTabIndex
        coachRouteRevision += 1
    }

    func routeToQuickCoach(question: String?) {
        prepareCoachRoute(question: question)
        coachRouteDestination = .quickCover
        coachRouteRevision += 1
        showCoachHub = true
    }

    private func prepareCoachRoute(question: String?) {
        if let question = question {
            prefilledCoachQuestion = question
            forceNewCoachSession = false
        } else {
            prefilledCoachQuestion = nil
            forceNewCoachSession = true
        }
    }

    func logDebug(_ message: String) {
        print(message)
    }

    func routeToTab(_ tab: Int) {
        guard Self.validTabIndices.contains(tab) else {
            logDebug("[VelaAppState] ignored invalid tab route \(tab)")
            return
        }
        selectedTab = tab
    }

    func routeToTraining() {
        routeToTab(Self.trainingTabIndex)
    }

    func routeToMe() {
        routeToTab(Self.meTabIndex)
    }

    func routeToAdaptiveTrainingStart() {
        resetQuickActionSheetTriggers()
        selectedTab = Self.trainingTabIndex
        adaptiveTrainingStartRequest += 1
    }

    func routeToFoodScanner(type: String) {
        resetQuickActionSheetTriggers()
        scannerType = type
        triggerFoodScanner = true
    }

    func routeToRecoveryDetail() {
        resetQuickActionSheetTriggers()
        triggerRecoveryDetail = true
    }

    func routeToPostWorkoutCheckIn(workoutID: UUID?) {
        resetQuickActionSheetTriggers()
        postWorkoutCheckInWorkoutID = workoutID
        triggerPostWorkoutCheckIn = true
    }

    func routeToPostWorkoutImpact(workoutID: UUID?) {
        resetQuickActionSheetTriggers()
        postWorkoutImpactWorkoutID = workoutID
        triggerPostWorkoutImpact = true
    }

    func deferQuickActionUntilSheetDismisses(_ action: DeferredQuickAction) {
        deferredQuickAction = action
    }

    func runDeferredQuickAction() {
        guard let deferredQuickAction else { return }
        self.deferredQuickAction = nil
        resetQuickActionSheetTriggers()

        switch deferredQuickAction {
        case let .coach(question):
            routeToQuickCoach(question: question)
        case let .foodScanner(type):
            routeToFoodScanner(type: type)
        case .foodSearch:
            triggerFoodSearch = true
        case .workoutLog:
            triggerWorkoutLog = true
        case .journal:
            triggerJournal = true
        }
    }

    private func resetQuickActionSheetTriggers() {
        triggerWeightLog = false
        triggerBloodLog = false
        triggerWorkoutLog = false
        triggerFoodSearch = false
        triggerFoodScanner = false
        triggerJournal = false
        triggerRecoveryDetail = false
        triggerPostWorkoutCheckIn = false
        triggerPostWorkoutImpact = false
    }

    func markLocalDataChanged() {
        localDataRevision += 1
    }
}

struct OpenVelaTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "查看 Vela 今日状态"
    static let description = IntentDescription("打开 Vela 首页查看今日健康状态。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VelaAppState.shared.routeToTab(VelaAppState.todayTabIndex)
        return .result()
    }
}

struct OpenVelaReadinessIntent: AppIntent {
    static let title: LocalizedStringResource = "询问 Vela 就绪状态"
    static let description = IntentDescription("打开 Vela Coach 并分析今天的就绪状态。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        VelaAppState.shared.routeToCoach(question: "请根据我今天的恢复、睡眠和训练负荷，判断当前就绪状态，并给出一个最重要的行动建议。")
        return .result()
    }
}

struct OpenVelaFoodScannerIntent: AppIntent {
    static let title: LocalizedStringResource = "用 Vela 扫描餐食"
    static let description = IntentDescription("打开 Vela 的餐食拍照分析入口。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // 营养功能开关关闭时给出明确反馈，而非静默无响应。
        let dialog: IntentDialog? = VelaFeatureFlags.nutritionEnabled
            ? nil
            : IntentDialog("餐食扫描功能当前未开启。")
        if VelaFeatureFlags.nutritionEnabled {
            VelaAppState.shared.routeToFoodScanner(type: "camera")
        }
        return .result(dialog: dialog ?? IntentDialog("已打开 Vela。"))
    }
}

struct VelaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenVelaTodayIntent(),
            phrases: ["查看 \(.applicationName) 今日状态"],
            shortTitle: "今日状态",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: OpenVelaReadinessIntent(),
            phrases: ["询问 \(.applicationName) 就绪状态"],
            shortTitle: "就绪状态",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: OpenVelaFoodScannerIntent(),
            phrases: ["用 \(.applicationName) 扫描餐食"],
            shortTitle: "扫描餐食",
            systemImageName: "camera.fill"
        )
    }
}

@main
struct VelaApp: App {
    private let modelContainer: ModelContainer

    init() {
        // 诊断用：未捕获 NSException（如 JSONSerialization 的 __SwiftValue 崩溃）
        // 记录完整符号化调用栈——NSLog 会进控制台（devicectl --console 可捕获），
        // 同时落盘到 Application Support/Vela/crash_diagnostic.log 便于事后分析。
        NSSetUncaughtExceptionHandler { exception in
            let symbols = Thread.callStackSymbols.joined(separator: "\n")
            let message = "VELA_UNCAUGHT_EXCEPTION reason=\(exception.reason ?? "nil")\n\(symbols)"
            NSLog("%@", message)
            if let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let url = dir.appendingPathComponent("Vela/crash_diagnostic.log")
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? message.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        // 前台收到本地通知时也要展示（此前无 delegate，前台通知被系统静默抑制）。
        UNUserNotificationCenter.current().delegate = VelaNotificationDelegate.shared

        do {
            modelContainer = try VelaModelContainer.make()
        } catch {
            VelaAppState.shared.isReadOnlySafetyMode = true
            PersistenceWriteGate.shared.setReadOnly(true)
            VelaAppState.shared.isFallbackStore = true
            if let memoryContainer = try? VelaModelContainer.make(inMemory: true) {
                modelContainer = memoryContainer
            } else {
                preconditionFailure("Vela: Could not create ModelContainer in any configuration.")
            }
        }

        // Register background task handler
        BackgroundTaskManager.register()

        // Register notification categories
        NotificationService.shared.registerNotificationCategories()

        // Keep the paired Apple Watch session warm so the latest decision can be delivered in the background.
        WristSnapshotBridge.shared.activate()

    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
        }
        .modelContainer(modelContainer)
    }
}

/// 前台通知展示委托：无此 delegate 时，立即投递的本地通知在前台被系统默认抑制。
final class VelaNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    nonisolated(unsafe) static let shared = VelaNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
