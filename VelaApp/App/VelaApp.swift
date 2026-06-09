import SwiftUI
import SwiftData
import BackgroundTasks
import AppIntents

@MainActor
final class VelaAppState: ObservableObject {
    static let coachTabIndex = 3

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
    @Published var selectedTab = 0
    @Published var showCoachHub = false
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
    @Published private(set) var deferredQuickAction: DeferredQuickAction?
    
    static let shared = VelaAppState()

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
        logDebug("[VelaAppState] routeToTab called with tab=\(tab)")
        selectedTab = tab
    }

    func routeToFoodScanner(type: String) {
        resetQuickActionSheetTriggers()
        scannerType = type
        triggerFoodScanner = true
    }

    func routeToRecoveryDetail() {
        resetQuickActionSheetTriggers()
        selectedTab = 2
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
        VelaAppState.shared.routeToTab(0)
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
        VelaAppState.shared.routeToFoodScanner(type: "camera")
        return .result()
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
        do {
            modelContainer = try VelaModelContainer.make()
        } catch {
            #if DEBUG
            // In DEBUG, VelaModelContainer.make() already deletes files on catch.
            // But if it still fails, fallback to in-memory:
            if let memoryContainer = try? VelaModelContainer.make(inMemory: true) {
                VelaAppState.shared.isFallbackStore = true
                modelContainer = memoryContainer
            } else {
                preconditionFailure("Vela: Could not create ModelContainer in any configuration.")
            }
            #else
            // In Release, catch schema migration / store failures, activate read-only safety mode,
            // and fallback to in-memory store so the app can launch, preventing data loss.
            VelaAppState.shared.isReadOnlySafetyMode = true
            PersistenceWriteGate.shared.setReadOnly(true)
            VelaAppState.shared.isFallbackStore = true
            if let memoryContainer = try? VelaModelContainer.make(inMemory: true) {
                modelContainer = memoryContainer
            } else {
                preconditionFailure("Vela: Could not create ModelContainer in any configuration.")
            }
            #endif
        }

        // Register background task handler
        BackgroundTaskManager.register()

        // Register notification categories
        NotificationService.shared.registerNotificationCategories()
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
        }
        .modelContainer(modelContainer)
    }
}
