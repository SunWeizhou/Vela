import SwiftUI
import SwiftData
import BackgroundTasks

@MainActor
final class VelaAppState: ObservableObject {
    @Published var isFallbackStore = false
    @Published var selectedTab = 0
    @Published var prefilledCoachQuestion: String? = nil

    static let shared = VelaAppState()
}

@main
struct VelaApp: App {
    private let modelContainer: ModelContainer

    init() {
        if let container = try? VelaModelContainer.make() {
            modelContainer = container
        } else if let memoryContainer = try? VelaModelContainer.make(inMemory: true) {
            VelaAppState.shared.isFallbackStore = true
            modelContainer = memoryContainer
        } else {
            preconditionFailure("Vela: Could not create ModelContainer in any configuration.")
        }

        // Register background task handler
        BackgroundTaskManager.register()
        // Schedule the first background refresh
        BackgroundTaskManager.schedule()

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
