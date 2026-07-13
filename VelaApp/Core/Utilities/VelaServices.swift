import Foundation
import HealthKit
import SwiftData

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
    var queryService: HealthKitQueryService {
        VelaResolver.shared.resolve(HealthQueryService.self) as! HealthKitQueryService
    }
    var refreshService: HealthDataRefreshService {
        VelaResolver.shared.resolve(HealthDataRefreshService.self)
    }
    var contextBuilder: AIContextBuilder {
        VelaResolver.shared.resolve(AIContextBuilder.self)
    }
    var dailySummaryUseCase: DailySummaryUseCase {
        VelaResolver.shared.resolve(DailySummaryUseCase.self)
    }
    var syncCoordinator: AppSyncCoordinator {
        VelaResolver.shared.resolve(AppSyncCoordinator.self)
    }
    var coachChat: CoachChatVM {
        VelaResolver.shared.resolve(CoachChatVM.self)
    }

    /// WebSearchService uses a private singleton — expose via computed property.
    var webSearchService: WebSearchService { .shared }

    /// WikiFileService is a stateless enum namespace — reference directly or via this alias.
    typealias Wiki = WikiFileService

    private var providerCache: [String: DeepSeekProvider] = [:]

    init() {}

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

@MainActor
final class VelaResolver {
    static let shared = VelaResolver()
    
    private var factories: [String: () -> Any] = [:]
    private var cache: [String: Any] = [:]
    
    private init() {
        // Register default implementations
        register(HealthQueryService.self) { HealthKitQueryService() }
        register(HealthDataRefreshService.self) {
            HealthDataRefreshService(queryService: self.resolve(HealthQueryService.self))
        }
        register(AIContextBuilder.self) { AIContextBuilder() }
        register(AppSyncCoordinator.self) { AppSyncCoordinator() }
        register(DailySummaryUseCase.self) {
            DailySummaryUseCase(
                refreshService: self.resolve(HealthDataRefreshService.self),
                queryService: self.resolve(HealthQueryService.self) as! HealthKitQueryService,
                syncCoordinator: self.resolve(AppSyncCoordinator.self)
            )
        }
        register(CoachChatVM.self) { CoachChatVM() }
        register(VelaEventService.self) { VelaEventService.shared }
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
        cache.removeValue(forKey: key)
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        if let cached = cache[key] as? T {
            return cached
        }
        guard let factory = factories[key] else {
            fatalError("No registered factory for \(key)")
        }
        let resolved = factory() as! T
        cache[key] = resolved
        return resolved
    }
    
    func reset() {
        cache.removeAll()
    }
}

@MainActor
final class VelaEventService {
    static let shared = VelaEventService()
    
    private init() {}
    
    func log(
        modelContext: ModelContext,
        type: String,
        title: String,
        detail: String = "",
        metadata: [String: Any] = [:]
    ) {
        let metadataJSON: String
        if let data = try? JSONSerialization.data(withJSONObject: metadata, options: []),
           let json = String(data: data, encoding: .utf8) {
            metadataJSON = json
        } else {
            metadataJSON = "{}"
        }
        
        let record = VelaEventRecord(
            eventType: type,
            timestamp: Date(),
            title: title,
            detail: detail,
            metadataJSON: metadataJSON
        )
        
        modelContext.insert(record)
        try? modelContext.save()
        
        // Notify local app state that data changed
        VelaAppState.shared.markLocalDataChanged()
    }
    
    func fetchEvents(
        modelContext: ModelContext,
        start: Date,
        end: Date
    ) -> [VelaEventRecord] {
        let descriptor = FetchDescriptor<VelaEventRecord>(
            predicate: #Predicate<VelaEventRecord> { $0.timestamp >= start && $0.timestamp <= end },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
