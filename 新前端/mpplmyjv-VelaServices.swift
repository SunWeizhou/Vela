import Foundation

@MainActor
final class VelaServices: ObservableObject {
    let queryService: HealthKitQueryService
    let refreshService: HealthDataRefreshService
    let contextBuilder: AIContextBuilder
    let dailySummaryUseCase: DailySummaryUseCase

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
        self.dailySummaryUseCase = DailySummaryUseCase(
            refreshService: refreshService,
            queryService: queryService
        )
    }

    func deepSeekProvider(apiKey: String) -> DeepSeekProvider {
        if let cached = providerCache[apiKey] {
            return cached
        }
        let provider = DeepSeekProvider(apiKey: apiKey)
        providerCache[apiKey] = provider
        return provider
    }
}
