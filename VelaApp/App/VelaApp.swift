import SwiftUI
import SwiftData
import BackgroundTasks

@MainActor
final class VelaAppState: ObservableObject {
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
    @Published var scannerType = "camera"
    @Published var forceNewCoachSession = false
    
    static let shared = VelaAppState()

    func routeToCoach(question: String?) {
        if let question = question {
            prefilledCoachQuestion = question
            forceNewCoachSession = false
        } else {
            prefilledCoachQuestion = nil
            forceNewCoachSession = true
        }
        showCoachHub = true
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
