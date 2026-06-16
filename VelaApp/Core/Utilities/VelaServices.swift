import Foundation

@MainActor
final class AppSyncCoordinator: ObservableObject {
    enum Source: Hashable {
        case healthKit
        case xunji
    }

    @Published private(set) var activeSources: Set<Source> = []

    private let minimumInterval: TimeInterval
    private var inFlight: [Source: Task<Void, Never>] = [:]
    private var lastCompletedAt: [Source: Date] = [:]

    init(minimumInterval: TimeInterval = 30) {
        self.minimumInterval = minimumInterval
    }

    func run(
        source: Source,
        force: Bool = false,
        operation: @escaping @MainActor () async -> Void
    ) async {
        if let running = inFlight[source] {
            await running.value
            return
        }
        if !force,
           let lastCompletedAt = lastCompletedAt[source],
           Date().timeIntervalSince(lastCompletedAt) < minimumInterval {
            return
        }

        activeSources.insert(source)
        let task = Task { @MainActor in
            await operation()
        }
        inFlight[source] = task
        await task.value
        inFlight[source] = nil
        lastCompletedAt[source] = Date()
        activeSources.remove(source)
    }
}

@MainActor
final class VelaServices: ObservableObject {
    let queryService: HealthKitQueryService
    let refreshService: HealthDataRefreshService
    let contextBuilder: AIContextBuilder
    let dailySummaryUseCase: DailySummaryUseCase
    let syncCoordinator: AppSyncCoordinator
    let coachChat = CoachChatVM()

    /// WebSearchService uses a private singleton — expose via computed property.
    var webSearchService: WebSearchService { .shared }

    /// WikiFileService is a stateless enum namespace — reference directly or via this alias.
    typealias Wiki = WikiFileService

    private var providerCache: [String: DeepSeekProvider] = [:]

    init(
        queryService: HealthKitQueryService = HealthKitQueryService()
    ) {
        self.queryService = queryService
        self.refreshService = HealthDataRefreshService(queryService: queryService)
        self.contextBuilder = AIContextBuilder()
        let sync = AppSyncCoordinator()
        self.syncCoordinator = sync
        self.dailySummaryUseCase = DailySummaryUseCase(
            refreshService: refreshService,
            queryService: queryService,
            syncCoordinator: sync
        )
    }

    func deepSeekProvider(apiKey: String) -> DeepSeekProvider {
        let model = DeepSeekTextModel.stored.apiIdentifier
        let cacheKey = "\(apiKey)|\(model)"
        if let cached = providerCache[cacheKey] {
            return cached
        }
        let provider = DeepSeekProvider(apiKey: apiKey, model: model)
        providerCache[cacheKey] = provider
        return provider
    }
}
