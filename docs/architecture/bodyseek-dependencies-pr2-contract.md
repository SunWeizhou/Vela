# ARCH-02 / PR2：`AppDependencies` 与 Today 依赖接缝契约

> 状态：**contract-ready**（只读勘察；本文件不表示运行时已经迁移）
> 勘察基线：`4f8d0eaa`（ARCH-01 / `BodySeekDomain` standalone package）
> 关联：ADR 0017、`docs/architecture/bodyseek-domain-pr1-contract.md`、PR0
> `docs/baselines/`

本文回答一个具体问题：在不重写现有 Vela（产品名 BodySeek）的 Today 管线、评分公式
或 SwiftData schema 的前提下，怎样把当前隐含的 Service Locator 与系统 singleton
收拢为可测试的显式依赖图。当前结论是：**先给 Today 的读取/刷新管线设一个深接缝，
再逐步把时钟、Health、repository 和 feature effects 放入 composition root；保留
`VelaServices`/`VelaResolver` 兼容桥，直到所有调用方切换。**

这是一份实现前的接口契约，不是把建议写成已实现的状态。当前 `BodySeekDomain` 的
standalone package 不应在本 PR 接入 `Vela.xcodeproj`，也不应因此改动五项评分的
数值、缺失语义或 UI。

## 1. 当前 Today 主链：实际调用关系

### 1.1 Composition root 现在从哪里开始

```text
VelaApp.init()
  ├─ VelaModelContainer.make()                         [App/VelaApp.swift:346]
  ├─ VelaModelContainer.activeContainer = modelContainer
  ├─ BackgroundTaskManager.register()
  └─ .modelContainer(modelContainer)
       ↓
AppCoordinator.init()
  ├─ localServices = VelaServices()                    [App/AppCoordinator.swift:17–20]
  └─ DashboardViewModel(
         useCase: localServices.dailySummaryUseCase,
         services: localServices
     )
       ↓ environmentObject
VelaShell / VelaTodayView
```

`AppCoordinator` 把 `ModelContext` 留在 View 的 environment 中（`:6`），同时把
`DashboardViewModel` 和 `VelaServices` 传给四个工作区（`:31–44`）。启动 task 先
`hydrateFromCache` 再 `refresh`（`:60–72`）；因此 Today 并不是唯一触发源，Trends、
Plan、Coach 的深链启动也会触发同一个 ViewModel。

### 1.2 Today 首屏与刷新

实际调用链为：

```text
VelaTodayView.body
  ├─ .task(id: isActiveSurface)                         [Features/Minimal/VelaMinimalTodayView.swift:696–709]
  │    ├─ dashboardVM.hydrateFromCache(modelContext:)
  │    ├─ refreshDashboard()
  │    │    └─ dashboardVM.refresh(modelContext:)
  │    ├─ loadDataCoverageSummary()
  │    ├─ loadTodayLivedStateAlignment()
  │    └─ trackDailyDecisionViewed()
  ├─ .refreshable → refreshDashboard(force: true)       [:710–714]
  ├─ scenePhase active → refreshDashboard(force: false) [:715–732]
  ├─ selectedDate change → hydrate + secondary + refresh [:734–741]
  └─ localDataRevision change → force refresh/secondary  [:743–753]
```

`DashboardViewModel.refresh` 维护自己的 task/日期/TTL 状态（
`Features/SharedComponents/DashboardViewModel.swift:253–361`），真正计算走：

```text
DashboardViewModel.performRefresh
  └─ VelaDailyOrchestrator.refresh(...)                 [DashboardViewModel.swift:312–319]
       └─ static inFlight[dayKey] 去重                 [DailySummaryUseCase.swift:1357–1392]
            └─ DailySummaryUseCase(...).loadDashboard()
```

目前 `VelaDailyOrchestrator.refresh` 在 `DailySummaryUseCase.swift:1365–1387`
重新构造 `DailySummaryUseCase`，并强行使用 `AppSyncCoordinator.shared`（`:1382`）。
这意味着 ViewModel 注入的 use case 与实际刷新用例不是同一个实例，也不是完整的
依赖图。`DashboardViewModel` 保存的 `services` 字段（`:162,172–174`）在该文件中也
没有其他读取点；它目前不是一条有效依赖边。

### 1.3 `DailySummaryUseCase` 的真实下游

`DailySummaryUseCase` 当前把 `queryService` 声明成**具体**的
`HealthKitQueryService`（`Core/Utilities/DailySummaryUseCase.swift:159–170`），
虽然工程同时存在 `HealthQueryService` 协议。这使测试不能传入简单 fake，协议在这
一条主链上没有成为真正的接缝。直接把字段类型替换成现有协议仍不能编译：该 use case
还调用 `extendedMetrics`（`:370`）和 `intradaySamples`（`:763`），二者没有出现在
`Health/Queries/HealthQueryService.swift:3–16` 的 interface 中。因此 PR2 应优先定义
能一次返回 typed daily evidence 的窄 adapter，或先补齐协议后再切换，不能只改一个
类型标注。

一次有 `ModelContext` 的 Today refresh 按以下顺序发生：

```text
loadDashboard(for:date, modelContext:context)
  ├─ HealthAuthorizationService().shouldDeferBackgroundSync()
  │    └─ HealthStoreProviding 默认 = HealthStoreProvider.shared
  │         [Health/Authorization/HealthAuthorizationService.swift:39–75]
  ├─ HealthKitSyncEngine(queryService, modelContext, calendar)
  │    ├─ syncPastDays(...)                                  [:203–234]
  │    ├─ HealthSnapshotRepository / SwiftData write
  │    └─ WorkoutAggregationService.shared
  ├─ HealthSnapshotRepository.fetchSnapshots(180 days)
  ├─ modelContext.fetch(all DailyHealthSummaryRecord)         [:318–333]
  ├─ HealthKitQueryService.strainSummary(todayRange)          [:342–345]
  ├─ WorkoutAggregationService.shared.upsert/aggregate       [:351–366]
  ├─ HealthKitQueryService.extendedMetrics/bodyMetrics        [:370–375]
  ├─ refreshIntradayBuckets(modelContext:)                    [:376–381]
  ├─ HealthKitQueryService.sleepSummary(todayRange)           [:383–385]
  ├─ UserProfileSettings.* (UserDefaults-first profile)       [:386–400]
  ├─ five engines + PersonalBaselineEngine math
  ├─ DailyIntelligenceAssemblyModule.assemble(...)            [:640–673]
  ├─ HealthSnapshotRepository.saveDailySnapshot(...)          [:681–700]
  │    ├─ WorkoutAggregationService.shared.aggregateDay()
  │    └─ modelContext.save()
  ├─ DailyOperatingPlanCoordinator.upsert(...)                [:702–715]
  └─ refresh baselines / prune / optional notification
```

无真实今日快照时，`loadDashboard` 在 `:287–315` 直接返回
`DashboardSummary.empty(date:)`（仅 DEBUG 且显式 `-velaSeedDemoData` 时才写入演示
数据）；这条“empty 不等于 0”语义必须保持。

### 1.4 ViewModel 的 secondary 管线

`DashboardViewModel.performLoadSecondaryData`（`:583–752`）在 MainActor 上批量读取
CoachArtifact、active TrainingPlan、StrengthWorkout、WorkoutEvent、TrainingResponse、
FoodLog、Journal、DailyHealthSummary、feedback、operating plan、AIReport 等 SwiftData
记录，转换为 DTO 后用 `Task.detached` 调 `SecondaryDataAssembler.assemble`。它还从
`confirmedObservationSummaries(modelContext:)` 读取已确认的 MemoryEvent。这个管线是
Today 的计划、体征 sparkline、反馈和 AI 投影来源，不应在 PR2 里偷偷迁移为第二套
store；应由 PR3 的 `TodayStore` 统一调度并保留结果一致性。

### 1.5 Today View 自己越过依赖接缝的地方

首屏 View 目前不是纯 `ViewState → View`：

| 路径 / 符号 | 直接依赖 | 影响 |
|---|---|---|
| `Features/Minimal/VelaMinimalTodayView.swift:30–36` `VelaTodayView` | `@Environment(\.modelContext)`、`VelaAppState.shared`、`LocationManager.shared` | View 持有持久化 context 与全局导航/定位状态 |
| `VelaMinimalTodayView.swift:696–753` | View 触发 hydrate、refresh、secondary、coverage、feedback | 生命周期触发源分散，容易与 `AppCoordinator` 重复执行 |
| `Features/Minimal/VelaTodayViewData.swift:117–149` `fetchLocalWeather` | `WeatherLocationStore`（UserDefaults）、`CLGeocoder`、`WeatherService.shared` | 天气是网络/定位副作用，和 Today 评分读取混在一起 |
| `Features/Minimal/TodayHeroCard.swift:871–889` | `HealthKitQueryService()` 直接查询小时心率、步数、活动能量 | 即使 DailySummary 被注入，小时图仍绕过 seam；这是 PR4 前必须收口的已知缺口 |
| `Features/Minimal/TodaySubSheets.swift:923` `PostWorkoutImpactSheet` | `private let queryService = HealthKitQueryService()` | sheet 直接访问 HealthKit，属训练下游，不应被 TodayStore 隐式拥有 |
| `Features/Minimal/VelaMinimalTodayView.swift:915–1000` | `LivedStateJournalAdapter(modelContext:)`、`DailyDecisionFeedbackService`、`FetchDescriptor` | 反馈与 lived-state 写入仍是 View effect；PR3 应转成 Action effect |
| `Features/Minimal/TodayNutritionStrip.swift:377–392` | `@Query FoodLogRecord`、多组 `@AppStorage` | Nutrition 是下游能力；不能作为 Today P0 store 的持久化接口 |

`TodayHeroCard` 的小时图尤其重要：`HealthQueryService` 协议只有
`heartRateSamples`，没有 `hourlySteps`/`hourlyActiveEnergy`；具体类
在 `HealthKitQueryService.swift:742–750` 才提供这些方法。若不先补一个窄的 hourly
reading interface，任何 preview/test 都仍会启动真实 HealthKit。

## 2. 隐式全局依赖清单

### 2.1 Service Locator 与 singleton

`VelaServices` 看似是 environment object，实际每个属性都回到同一个
`VelaResolver.shared`：`Core/Utilities/VelaServices.swift:114–146`。resolver 用
`[String: () -> Any]` 和 `[String: Any]` 缓存，并在 `:167–181` 注册：

```text
VelaServices.dailySummaryUseCase
  → VelaResolver.shared.resolve(DailySummaryUseCase.self)
      → HealthQueryService 注册工厂
          → HealthKitQueryService()
      → AppSyncCoordinator 注册工厂
          → AppSyncCoordinator.shared
```

这不是编译器可验证的依赖关系：类型擦除、强制转换（`:117`、`:174`、`:198`）以及
`reset()`（`:203–205`）都可能让同一个 ViewModel 在不同生命周期拿到不同实例。当前
扫描得到至少 30 个 `VelaResolver`/`VelaServices` 相关命中；应将 resolver 视为过渡
桥，而不是新的长期接口。

### 2.2 Today 直接或间接使用的全局状态

| 类别 | 当前证据 | 应归属的未来依赖槽 |
|---|---|---|
| Health store | `HealthStoreProvider.shared`（`HealthAuthorizationService.swift:43`、`HealthKitQueryService.swift:38`） | `HealthDependencies.store` 仅在 composition root 创建；业务只见 value protocol |
| 同步去重 | `AppSyncCoordinator.shared`（`VelaServices.swift:10`） | `SyncCoordinator` adapter；由 `AppDependencies` 持有一个实例 |
| 日级去重 | `VelaDailyOrchestrator.inFlight` 静态字典（`DailySummaryUseCase.swift:1357–1392`） | `TodayReader`/store 的 actor-isolated coordinator；不要在 View 层复制 |
| SwiftData | `@Environment(\.modelContext)`（Today View:30、AppCoordinator:6）；`DailySummaryUseCase` 直接 fetch/save | `DailySnapshotRepository`、`TodayAuxiliaryRepository`；由 ModelActor/主 actor adapter 管理 |
| UserDefaults | `UserProfileSettings.*`（`DailySummaryUseCase.swift:386–400`）；`ActiveStatusSettings`（`:1–96`）；`@AppStorage`（Today/ Nutrition） | `ProfilePreferences`、`TodayPreferences` protocol；测试传入内存 fake |
| App navigation/revision | `VelaAppState.shared`（Today:35、TodayData:40–46、:792、:825、:998） | `TodayEffectRouter`/`LocalDataChangeNotifier`，由宿主注入；View 只发 Action |
| Location | `LocationManager.shared`（Today:36；定义 `Core/Services/LocationManager.swift:7–20`） | `LocationProviding`；天气最好另属 Weather feature |
| Weather network | `WeatherService.shared` 与 `URLSession.shared`（`Core/Services/WeatherService.swift:95–110`） | `WeatherReading` adapter；不阻塞 Today score load |
| Logging/telemetry | `VelaEventService.shared`（`VelaServices.swift:208–253`）、`PipelineDiagnosticsLogger` | `AppLogger`/`TelemetrySink` protocol；写 SwiftData 的 event adapter 留在 App |
| Write safety | `PersistenceWriteGate.shared`（`Core/Utilities/PersistenceWriteGate.swift:9–24`） | `PersistenceGate` adapter；不可被 Domain 或 View 直接看到 |
| AI/keychain/config | `KeychainService.shared`、`AutoAgentConfig.shared`、`VelaEventService.shared` 在 proactive/Coach 链 | `AI/Privacy` feature dependencies；Today P0 只接已持久化、经 redaction 的投影 |
| Clock/calendar | `Date()`、`Calendar.current` 分散在 View、ViewModel、UseCase、Weather policy | `AppClock` + 显式 `Calendar`/`HealthDayBoundary`，默认只在 live factory 解析 |

## 3. 推荐 `AppDependencies` 形状

### 3.1 设计原则

采用 Apple-native modular monolith：不引入第三方 DI，不用 environment key 伪装全局
容器，也不把 `ModelContext` 或 `HKHealthStore` 传播到纯 Domain。`AppDependencies`
是 composition root 的**值**（由 `VelaApp`/`AppCoordinator` 构造一次）；各 feature
拿到的是最小的深模块 interface，而不是整个 locator。

```text
AppDependencies (composition root, @MainActor)
  ├─ runtime: RuntimeDependencies
  │    ├─ clock: any AppClock
  │    ├─ calendar: Calendar
  │    └─ healthDayBoundary: HealthDayBoundary
  ├─ health: HealthDependencies
  │    ├─ authorization: any HealthAuthorizationProviding
  │    ├─ dailyRead: any HealthReading
  │    ├─ hourlyRead: any HourlyHealthReading
  │    └─ sync: any HealthSyncing
  ├─ persistence: PersistenceDependencies
  │    ├─ dailySnapshots: any DailySnapshotRepository
  │    ├─ todayAuxiliary: any TodayAuxiliaryRepository
  │    └─ writeGate: any PersistenceGate
  ├─ domain: DomainDependencies
  │    └─ computation: BodySeekDomain.DailyHealthComputation factory
  ├─ today: TodayDependencies
  │    └─ reader: any TodayReadingModule
  ├─ features: FeatureDependencies
  │    ├─ weather: any WeatherReading (optional/non-critical)
  │    ├─ coverage: any DataCoverageReading
  │    └─ effects: any TodayEffectRouter
  └─ observability: ObservabilityDependencies
       └─ logger/telemetry sinks
```

### 3.2 公开 interface 的最小形状

下列代码是契约示意，名称可在实现 PR 中微调，但方向和禁区不变：

```swift
@MainActor
struct AppDependencies {
    let runtime: RuntimeDependencies
    let health: HealthDependencies
    let persistence: PersistenceDependencies
    let domain: DomainDependencies
    let today: TodayDependencies
    let features: FeatureDependencies
    let observability: ObservabilityDependencies

    static func live(modelContainer: ModelContainer) -> AppDependencies
    static func preview(now: Date, calendar: Calendar) -> AppDependencies
    static func test(fixture: TodayFixture, now: Date, calendar: Calendar) -> AppDependencies
}

struct RuntimeDependencies {
    let clock: any AppClock                 // `now`, 不在 feature 内调用 Date()
    let calendar: Calendar                  // 不在 domain/feature 内读取 .current
    let healthDayBoundary: HealthDayBoundary
}

@MainActor
protocol TodayReadingModule: AnyObject {
    func cached(for day: Date) async throws -> TodayDashboardSnapshot?
    func load(for day: Date, policy: TodayRefreshPolicy) async throws -> TodayDashboardSnapshot
}
```

`TodayDashboardSnapshot` 是 App adapter 的 Sendable 值投影（不是 SwiftData model）；在
PR3 定义完整 `TodayViewState` 后，`TodayStore` 才把它映射成 ViewState。这里的
`TodayReadingModule` 有两个方法，已经覆盖 cache/refresh 深接缝；它隐藏 HealthKit、
SwiftData、评分协调、secondary data 与日志细节，避免把十多个浅 provider 暴露给 View。

建议内部 protocol 分层如下：

```swift
@MainActor
protocol HealthReading {
    func readDailyEvidence(for day: Date) async throws -> DailyHealthEvidence
}

@MainActor
protocol HourlyHealthReading {
    func readHourlyEvidence(for day: Date) async throws -> [HourlyHealthPoint]
}

@MainActor
protocol HealthAuthorizationProviding {
    func shouldDeferBackgroundSync() async -> Bool
}

@MainActor
protocol HealthSyncing {
    func syncRecent(days: Int, endingAt: Date) async throws
}

protocol DailySnapshotRepository: Sendable {
    func fetch(days: Int, endingAt: Date) async throws -> [DailyHealthSnapshot]
    func save(_ snapshot: DailyHealthSnapshot, evidence: DailyScoreEvidenceEnvelope) async throws
}

protocol AppClock: Sendable {
    var now: Date { get }
}
```

约束：

1. `BodySeekDomain` 只接收显式 profile、calendar、now 和 value evidence；五项 score
   仍独立，`nil` 不转为 0。当前 PR1 package 只迁移 Sleep；其余四项在 host adapter
   继续走经 golden 保护的 Vela 实现，直到各自完成 parity migration。
2. repository interface 不暴露 `ModelContext`、`@Model` 或 `FetchDescriptor`；具体
   `SwiftDataDailyHealthSummaryRepository` 可继续在 App adapter 中使用 MainActor/ModelActor。
3. `HealthReading` 的生产 adapter 才持有 `HKHealthStore`；测试/preview adapter 只返回
   fixture。小时图使用单独 `HourlyHealthReading`，不能把 `HealthKitQueryService`
   具体类型下沉到 View。
4. `AppLogger` 只接收结构化、已 redaction 的事件；`VelaEventService` 的 SwiftData
   写入和 `PersistenceWriteGate` 由 adapter 组合。
5. Weather、location、nutrition、AI、Plan 是 `FeatureDependencies` 的可选下游，不
   成为 `TodayReadingModule` 的隐式必需项；天气失败不能让五项评分失败。

### 3.3 live / preview / test factory

`live(modelContainer:)` 是唯一允许创建系统对象的地方：

```text
HKHealthStore() ──> HealthKitQueryService(healthStore:)
                           │
                           ├─ HealthReading adapter
                           └─ HourlyHealthReading adapter
ModelContainer.mainContext ──> SwiftData repositories
AppSyncCoordinator() ──> HealthSyncing adapter
explicit Calendar/clock ──> TodayReadingModule / BodySeekDomain
```

`preview` 使用 `PreviewHealthDataProvider` + in-memory repository + fixed clock；不得
因没有 `ModelContext` 又回退到 `HealthKitQueryService()`。`test` 使用 fixture provider
和可观察 fake repository/logger，能够断言读写次数、取消、TTL、empty/nil 语义。

## 4. Service Locator 迁移的最小阶段

### Phase A：保留桥，建立一个深接缝（PR2 的唯一运行时目标）

1. 新增（或在现有依赖文件中定义）`TodayReadingModule`、`AppClock`、
   `DailySnapshotRepository` 等 protocol；先不删除 `VelaResolver`。
2. 把 `DailySummaryUseCase` 的内部字段/初始化器从具体
   `HealthKitQueryService` 改为扩充后的 `any HealthQueryService`，或更推荐的 typed
   daily-evidence 窄 adapter（须覆盖当前 `extendedMetrics`/`intradaySamples` 调用）。
   保留旧的 `init()` 作为 live 兼容入口，但其实现只能调用显式 factory，不应继续
   散落默认值。
3. `TodayReadingModule.live` 在内部持有当前 `DailySummaryUseCase`、repository、
   sync coordinator，外部只暴露 `cached/load`。这一步先不动 View 的 secondary、天气、
   lived-state 和 feedback。
4. `DashboardViewModel` 增加 `init(todayReader: ...)` 或等价深入口；旧
   `init(useCase:services:)` 暂保留，并由 `VelaServices` bridge 委托到该 reader。
5. `VelaTodayView` 仍可通过 environment 取得旧 ViewModel，但刷新路径只能通过已注入
   reader 走一次；不得在 View 中新增 `VelaResolver.shared.resolve`。

验收是“替换一个 adapter 即可运行 preview/test”，不是删除所有 singleton。旧
`VelaServices` 的其他属性（Coach、Proactive、Workout）可继续 resolver-backed。

### Phase B：收口小时图和 Today effects（PR3/PR4 前）

1. `TodayHeroCard` 注入 `HourlyHealthReading`，删除 `HealthKitQueryService()` 直建。
2. 让 `TodayStore` 接管 refresh、coverage、lived-state、feedback 等 Action effect；
   weather/location 由独立 Weather feature adapter 处理。
3. 将 `VelaAppState.shared.markLocalDataChanged()` 替换为注入的 change notifier，
   仍可由 live factory 用 `VelaAppState.shared` 实现兼容。

### Phase C：移除 locator-backed feature access

每个 feature 完成切换并有 focused tests 后，逐属性删除 `VelaServices` 的 resolver
访问。最后才删除 `VelaResolver`；不能先删 locator 再让四个工作区各自临时创建
singleton。任何 AI/Plan/Coach 依赖不得倒灌回 P0 Today reader。

## 5. shared-file locks 与 project integration 风险

| 文件/区域 | 锁定 owner | 风险 / 协作规则 |
|---|---|---|
| `VelaApp/Core/Utilities/VelaServices.swift` | ARCH-02 单一 owner | 混有 `AppSyncCoordinator`、`VelaResolver`、`VelaEventService` 和 feedback/quality helpers；不要让 PR3/AI agent 同时重排 |
| `VelaApp/Core/Utilities/DailySummaryUseCase.swift` | ARCH-02 单一 owner | 读取、评分、SwiftData 写入、orchestrator 都在同文件；先只改接口与桥，不碰公式 |
| `VelaApp/Features/SharedComponents/DashboardViewModel.swift` | ARCH-03 | 与 Today/Trends/Plan/Coach 共享；PR2 只提出 init seam，实际 ViewState/store 迁移由 PR3 独占 |
| `VelaApp/App/AppCoordinator.swift`、`VelaApp/App/VelaApp.swift` | composition-root owner | live/preview/test factory 最终在此接入；不要让 feature agent 修改启动 fallback、schema 或 notification 初始化 |
| `VelaApp/Health/Queries/HealthQueryService.swift`、`HealthKitQueryService.swift` | Health adapter owner | `HealthQueryService` 当前是 `@MainActor` 且具体类方法多；扩展 hourly/authorization 时要保留协议兼容并单独测试 |
| `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`、`TodayHeroCard.swift` | PR3/PR4 | 这是 UI 共享热点；PR2 不改，避免和 ViewState/3+2 layout 同时冲突 |
| `Vela.xcodeproj/project.pbxproj` | project-integration 单一 owner | 本 PR 不改；未来只由一个 agent 添加 local package/product 依赖，禁止并行编辑 |
| `VelaWatch/VelaWatchApp.swift` | Watch owner | 先验证 package 的 Foundation/Sendable 接口，再单独接入 Watch；不得复制 Domain 类型到 Watch target |

主要风险：SwiftData 的 `ModelContext` 不是跨 actor 的值，任何把它塞入
`AppDependencies` 并标记 `Sendable` 的捷径都会破坏 PR6 的并发假设；`HealthKitQueryService`
默认构造又会悄悄创建 `HealthStoreProvider.shared`，因此 bridge 必须显式传入已有
实例。另一个风险是把 `DashboardSummary`（目前还 import SwiftData 并含 App-only
projection）误当作 Domain contract；PR3 应定义独立 Sendable DTO，而不是把 model
context 传播到 `BodySeekDomain`。

## 6. 与 PR1 `BodySeekDomain` 的宿主接入顺序

当前 `BodySeekDomain/Package.swift` 是 iOS 17/watchOS 10、Foundation-only 的
standalone package；它不应因 PR2 的 dependency survey 自动接入 Xcode。

推荐顺序：

1. **PR1 package parity 完成**：standalone package tests、PR0 golden replay、
   `Sendable`/import guard 全部通过；旧 Vela scoring 继续作为 oracle。
2. **一次 project-integration 变更**：由专门 owner 在 `project.pbxproj` 增加
   `XCLocalSwiftPackageReference(relativePath: "BodySeekDomain")` 与
   `XCSwiftPackageProductDependency(productName: "BodySeekDomain")`。本 survey 不改
   该文件。
3. **先接 iOS `Vela` target 的单一 adapter**：保留旧评分类型，不把 package source
   再加入 Vela source phase；adapter 显式把 SwiftData/HealthKit 值映射为 package
   values，然后对比 golden fixture。
4. **再接 `VelaTests`（如宿主测试需要直接 import）**：package 自己的 XCTest 仍是
   第一层；宿主测试只验证 adapter wiring，不复制 package fixture 类型。
5. **最后接 `VelaWatch`**：只有当 package API 在 watchOS 10 可编译且 Watch 需要该
   domain path 时才加入 product dependency。Watch 不应重新实现同名 `MetricResult`
   或把 iOS-only adapter 复制进 target。

避免 duplicate symbols 的规则：

- 同一份 domain source 只属于 package target；不得把 `Sources/BodySeekDomain/*.swift`
  同时拖进 `Vela`/`VelaWatch` source phase。
- package 的类型以 `BodySeekDomain.` module namespace 暴露；旧 `Vela` 类型在 parity
  和切换完成前仍留在原模块，由 adapter 做显式转换。
- `Vela`、`VelaTests`、`VelaWatch` 的 product dependency 各只添加一次；不要为每个
  target 创建同名本地 package 副本。
- 先接一个 adapter、跑 iOS tests，再接 Watch；任何链接错误都在 project-integration
  变更内修复，不由 PR2/PR3 顺手重排 pbxproj。

## 7. ARCH-03 `TodayStore/ViewState/Action` 的前置契约

### 7.1 Store 的最小职责

`TodayStore`（建议 `@MainActor` class）只负责：

- 保存 selected health day、loading/error/freshness 与一个完整 `TodayViewState`；
- 调用注入的 `TodayReadingModule`，对同日请求做取消/coalescing，丢弃过期日期结果；
- 把 evidence/auxiliary DTO 映射成五项独立 score cards、3+2 projection、coverage、
  lived-state/feedback 状态；
- 把用户输入转成 `TodayAction` effect（refresh、retry、select day、open evidence、
  save lived state、submit feedback、ask coach），不直接执行导航或 SwiftData 写入。

示意：

```swift
enum TodayAction {
    case appear
    case selectDay(Date)
    case refresh(force: Bool)
    case retry
    case openEvidence
    case saveLivedState(LivedStateAlignment)
    case submitFeedback(DailyDecisionFeedbackValues)
    case askCoach(String)
}

@MainActor
final class TodayStore: ObservableObject {
    @Published private(set) var state: TodayViewState
    func send(_ action: TodayAction) async
}
```

具体 `TodayViewState` 字段在 PR3 定稿，但必须覆盖 loading/empty/error/success、
source/freshness、五 score `MetricResult`（含 nil/missingInputs/version）、Today
actions 和非关键下游状态。不要从 state getter 内重新运行 scoring kernel。

### 7.2 View 的硬禁区

ARCH-03/PR4 的 View 不得：

- 读取或保存 `ModelContext`、`FetchDescriptor`、`@Query`；
- import 或实例化 `HealthKit`/`HKHealthStore`/`HealthKitQueryService`；
- 读取 `UserDefaults.standard`、`@AppStorage` 作为 Today score/decision 输入；
- 访问 `VelaResolver.shared`、`VelaServices` locator 属性或任何 `.shared` feature
  singleton；
- 在 `body`、`computed property` 或 loading fallback 中再次计算五项 score/decision；
- 让天气、AI、Nutrition、Plan 的失败覆盖主链的 health evidence error。

允许 View：读取 `@EnvironmentObject TodayStore` 的 `state`，渲染纯值，发出
`send(Action)`，以及持有 SwiftUI 本地展示状态（sheet、动画、焦点）。导航由 effect
router 执行，不能由 domain 或 store 直接操作 `VelaAppState.shared`。

## 8. 验收、测试与下一 handoff

### 8.1 本次 survey 已运行的命令

```sh
rg -n 'VelaResolver\.shared|static let shared|VelaServices\(|HealthStoreProvider\.shared|WeatherService\.shared|VelaAppState\.shared|LocationManager\.shared' \
  VelaApp/Core/Utilities/VelaServices.swift VelaApp/App/AppCoordinator.swift \
  VelaApp/Core/Utilities/DailySummaryUseCase.swift VelaApp/Features/Minimal \
  VelaApp/Health/Authorization/HealthAuthorizationService.swift \
  VelaApp/Health/Services/HealthKitQueryService.swift
# 关键命中：VelaResolver/VelaServices/各类 singleton 与 Today 直建 HealthKit 均存在

rg -n 'modelContext|HealthKitQueryService|UserDefaults|@AppStorage|Calendar\.current|Date\(\)' \
  VelaApp/Features/Minimal/VelaMinimalTodayView.swift \
  VelaApp/Features/Minimal/VelaTodayViewData.swift \
  VelaApp/Features/Minimal/TodayHeroCard.swift \
  VelaApp/Features/Minimal/TodayNutritionStrip.swift | wc -l
# 47 个 Today/下游依赖命中

rg -n 'VelaResolver\.shared|VelaServices' VelaApp --glob '*.swift' | wc -l
# 30 个 locator/service-host 相关命中

rg -n 'DailySummaryUseCase\(|HealthKitQueryService\(' VelaApp --glob '*.swift'
# DailySummaryUseCase、TodayHeroCard、PostWorkoutImpactSheet、WorkoutDetail、后台任务
# 等仍有具体类构造；它们是后续 seam 收口清单

swift test --package-path BodySeekDomain
# 2026-09-04：3 tests passed, 0 failures（standalone PR1 smoke）
```

### 8.2 PR2 focused tests（实现时必须添加）

1. **Factory wiring**：`live` 只创建一个 health provider、一个 sync coordinator、
   一个 Today reader；调用 `today.cached/load` 不再经过 resolver。
2. **Preview/test isolation**：preview/test factory 在无 HealthKit 权限、无网络、
   in-memory store 下完成 loading/success/empty/error；用 tripwire fake 断言真实
   `HKHealthStore` 与 `URLSession` 没有被创建。
3. **DailySummary protocol injection**：fake `HealthReading` 返回 golden/empty fixture，
   断言五项 score、algorithmVersion、missingInputs 和 `nil` 语义未改变。
4. **Concurrency**：同日并发 `load` 只调用一次 reader；切换日期后旧结果不会覆盖新
   state；refresh cancellation 不会把 loading 卡住。
5. **Repository boundary**：repository fake 记录 fetch/save；production adapter 的
   ModelContext 不跨 actor 泄漏；写入仍受 read-only gate 保护。
6. **Static guard**：TodayStore/ViewState/Action production files 不得 import
   SwiftData/HealthKit/UIKit，也不得出现 `.shared`、`UserDefaults.standard` 或
   `FetchDescriptor`。

### 8.3 下一 handoff

- **ARCH-02 / PR2 实现 agent**：只改依赖 protocol、factory、`DailySummaryUseCase`
  注入桥和 focused tests；先锁 `VelaServices.swift`、`DailySummaryUseCase.swift`、
  `AppCoordinator.swift`，不碰 `project.pbxproj`、BodySeekDomain、评分公式或 UI。
- **ARCH-03 / PR3 agent**：在本契约获批后实现 `TodayStore/ViewState/Action`，以
  `TodayReadingModule` 为唯一读取深接缝，并按禁区做静态 guard。
- **PR1 package agent**：继续 standalone package parity；未经 project-integration
  owner 明确 handoff，不编辑 Xcode project。
- **Release review**：在 PR2/PR3 完成后重跑 PR0 golden inventory、完整 iOS tests、
  watch build 和 UI preview；若任何数据值或状态语义变化，退回为独立算法/契约 PR。

本勘察没有发现必须阻塞 PR2 的外部条件；状态为 **contract-ready**。但在
`TodayHeroCard` 的 hourly HealthKit 直连和 `DailySummaryUseCase` 的具体类型签名
收口前，不能宣称“Today 已完成显式依赖迁移”。
