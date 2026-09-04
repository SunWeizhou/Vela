# ARCH-01 / PR1：`BodySeekDomain` 抽取契约与低风险接入勘察

> 状态：contract-ready（survey；本文件不改运行时代码）
> 勘察基线：`4d87be951279e5189c79caa2818c1ab81b3fa93c4`
> 关联基线：ARCH-00 / PR0（`docs/baselines/`）与 ADR 0017

本文把当前 Vela 工程的“纯领域核心”与 Apple/持久化适配器分开描述，为下一步
实现提供可执行的契约。它不是把现有代码直接复制进 Package 的许可；任何抽取都
必须在 golden fixture 前后对照通过，并保持当前五项评分、缺失数据和算法版本语义不变。

## 1. 结论摘要

建议采用两阶段接入：

1. **先建 standalone local Swift Package**：创建 `BodySeekDomain/Package.swift`
   和 `Sources/BodySeekDomain`，其 production target 只依赖 Foundation；先在 Package
   自己的 XCTest 中编译和回放，暂不编辑 `Vela.xcodeproj/project.pbxproj`。
2. **契约验收后再接主工程**：由单独的 project-integration 变更把本地 package 加入
   iOS、watchOS 和测试目标；当前 PR1 survey 不触碰工程文件，也不替换 VelaApp 中的
   旧实现。这样可以把 Swift 访问控制、Swift 6 Sendable 和导入边界问题限制在一个
   可删除、可独立测试的目录中。

PR1 的最低可交付不是“迁移所有 Scoring 文件”，而是一个能承载以下值类型和算法
契约的编译保护层：`DailyHealthSnapshot`（纯子集）、`WorkoutSummary`、五项输入/输出
类型、`MetricResult`/`ScoringMath`、`PersonalBaseline` 的纯数学子集，以及显式 profile
输入的 `DailyHealthComputation`。`Today`/`Trends` UI、HealthKit 查询、SwiftData、
UserDefaults/Wiki 和训练/Coach 下游仍属于 App adapter。

## 2. 当前候选清单与 import/依赖图

### 2.1 逐文件清单

| 当前文件 | 可进入 `BodySeekDomain` 的部分 | 必须留在 VelaApp adapter 或暂缓的部分 |
|---|---|---|
| `VelaApp/Scoring/ScoringCore.swift` | `ScoreEngine`、`MetricBand`、`MetricConfidence`、`MetricState`、`MetricSource`、`ScoredHealthDomain`、`ScoreDirection`、`ScoreDataCoverage`、`MetricResult`、`ScoringMath`；`StandardScoreResult` 可作为兼容类型 | `ScoringAlgorithmVersions` 需在 Package 内成为受控常量；“SwiftUI views”注释不是依赖，但 UI projection 不应放入 Domain |
| `VelaApp/Scoring/Recovery/RecoveryScoreEngine.swift` | `RecoveryLongTermContext`、`RecoveryScoreInput`、`RecoveryScoreEngine` | 依赖 `PersonalBaselineEngine` 的数学函数，抽取时必须同批进入 Domain；不得引入 HealthKit |
| `VelaApp/Scoring/Sleep/SleepScoreEngine.swift` | `SleepScoreInput`、`SleepDetailAnalysis`、`SleepScoreEngine` | `SleepTargetSettings.targetMinutes(UserDefaults)` 留在 adapter；Domain 只接受显式 `sleepTargetMinutes` |
| `VelaApp/Scoring/Strain/StrainScoreEngine.swift` | `WorkoutInput`、`StrainScoreInput`、`StrainScoreEngine`、若需要则 `HeartRateZoneSummary`/TRIMP 数学 | `HeartRateZoneCalculator` 当前吃 App 的 `HeartRateSample`，应在值类型拆分后再入 Package；显示 title/detail 不是核心契约 |
| `VelaApp/Scoring/Stress/StressIndexEngine.swift` | `StressIndexInput`、`StressIndexInputMode`、`StressIndexEngine` | 无外部 import，但只允许消费值类型和 Domain 常量 |
| `VelaApp/Scoring/EnergyBank/EnergyBankEngine.swift` | `EnergyBankInput`、`EnergyBankEngine`，以及 `TrainingLoadStatus` | 仍需与 `MetricResult`、`ScoringMath` 共包；不得从评分域回读持久化 |
| `VelaApp/Scoring/ScoreEngineFactory.swift` | `ScoredHealthEvidence`、`DailyHealthComputationProfile`（改为显式初始化）、`DailyHealthComputation` 的纯计算部分 | `UserProfileSettings` 全部 `UserDefaults` 读写、`WikiFileService` fallback、`DashboardMetricProjection`、Health Age/SleepSummary display projection 留在 adapter |
| `VelaApp/Scoring/PersonalBaselineEngine.swift` | `PersonalBaselineFormation`、`PersonalBaselines`、`LongTermBaselinePoint`、`LongTermBaselineMetric`、`LongTermMetricBaseline`、`TrainingVolume*`、`LongTermBaselineReport`、`Monthly*`、`DerailmentSignal`、`SeasonalProfile` 及 median/MAD/回归等纯数学 | `saveBaselinesToWiki`/`loadBaselinesFromWiki`、`formatForWiki`/AI、`resolveThresholds` 读取 Wiki、`DailyHealthSummaryRecord` extension 必须留在 adapter；`visualRegressionValue` 的 ProcessInfo flag 也不要进入 production Domain |
| `VelaApp/Scoring/HealthTrendEngine.swift` | 趋势窗口/统计算法、`HealthTrendInput`、history provider seam，以及纯趋势输出类型 | 当前签名直接吃 `DashboardSummary`，需要改成 Domain 的 `TrendCurrentEvidence` 值输入；所有 View/文案 projection 留在 App |
| `VelaApp/Core/Utilities/PersonalHealthBrief.swift` | `HealthTrendHorizon`、`HealthTrendDirection`、`MetricPolarity`、`CoreHealthMetric`、`TrendValueDirection`、`TrendAssessment`、`HealthTrendFinding`、`PersonalHealthBrief` 均只有 Foundation，可作为 Trends 第二阶段的 Domain 输出 | 中文标题、SF Symbol 和本地化文案最好由 App projection 包装；PR1 可只定义契约，不迁移 UI 文案 |
| `VelaApp/Health/Models/HealthDomainModels.swift` | 从文件拆出的 `DailyHealthSnapshot`、`SleepStage`、`SleepStageSegment`、`SleepSummary`、`RecoveryMetricSummary`、`StrainActivitySummary`、`WorkoutSummary`、`BodyMetricsSummary`、`HeartRateSample`；`SleepDayAggregator` 等纯函数可在后续纳入 | 顶部 `@preconcurrency import HealthKit`、`HealthQueryOutcomeKind`/`Diagnostic`/`HealthKitQueryOutcomeClassifier`、HealthKit 映射、`ExtendedHealthMetrics` catalog 保留 adapter；不要让一个文件同时成为两层的桥 |
| `VelaApp/Core/Utilities/DateRangeQuery.swift` | `HealthDayBoundary`、`DateRangeQuery` 的显式 calendar/boundary 版本 | `HealthDaySettings.boundaryMinutes(UserDefaults)` 和默认 `.current` 解析留在 adapter；Package API 必须要求调用方传入 boundary |
| `VelaApp/Health/Mapping/SleepSampleNormalizer.swift` | `sleepDuration`、`summary`、episode grouping 的纯版本（要求显式 `Calendar`/boundary） | 不要让默认 `.current` 或系统 HealthKit sample 进入 Domain；HealthKit sample 拉取仍在 Health adapter |
| `VelaApp/Health/Mapping/HealthUnitNormalizer.swift` | 这些归一化函数本身是 Foundation-only，可作为 adapter-side reusable utility | 它们描述的是外部 HealthKit 单位边界，不是评分核心；PR1 不迁移，避免把 HealthKit 单位语义和 Domain schema 绑定 |
| `VelaApp/Health/Services/HealthDataRefreshService.swift` | `DailyHealthContext` 若未来改造成纯 evidence DTO 可重做 | 当前包含 `ExtendedHealthMetrics`，且职责是旧刷新适配；不进入 PR1 |
| `VelaApp/Core/Utilities/BodyState.swift` | `LivedStateAlignment`/`LivedStateCheckIn` 的纯值类型未来可迁移；BodyState 输出可在后续重塑 | 当前文件导入 SwiftData，并把 `DashboardSummary`、`DailyHealthSummaryDTO`、训练/食物/手记 DTO、`TrainingAnalyticsService` 和 `PersonalBaselineEngine.resolveThresholds` 混在一起；PR1 明确不迁移 `BodyStateKernel`/assembly |
| `VelaApp/Core/Utilities/DashboardSummary.swift` | 不进入 Domain；可为后续 Today adapter 定义 `DashboardEvidenceProjection` | 依赖 SwiftData、`HealthAgeTrendResult`、`BodyModelState`、BodyState fallback 与 Preview；它是 App projection，不是证据模型 |
| `VelaApp/Core/Utilities/TrainingDecision.swift`、`DailyOperatingPlan.swift` | 仅保留为后续 PR 的候选 | SwiftData/训练 DTO/计划写入与 P0 Domain 解耦；不属于 PR1 |

### 2.2 import 事实与隐式同模块依赖

直接扫描得到：五个评分引擎、`ScoringCore.swift`、`ScoreEngineFactory.swift`、
`HealthTrendEngine.swift`、`PersonalBaselineEngine.swift`、`DateRangeQuery.swift`、
`SleepSampleNormalizer.swift`、`PersonalHealthBrief.swift` 的显式 import 只有
`Foundation`（`HealthDomainModels.swift` 另有 `@preconcurrency import HealthKit`；
`DashboardSummary`/`BodyState`/`TrainingDecision` 另有 `SwiftData`）。这并不表示它们
现在可直接复制：它们依赖 Vela target 中的内部符号。主要隐式边如下：

```text
Foundation
  └─ ScoringCore
       ├─ MetricResult / ScoringMath / algorithm versions
       ├─ RecoveryScoreEngine ─┐
       ├─ SleepScoreEngine ────┼─ PersonalBaselineEngine (median, robust SD, baselines)
       ├─ StrainScoreEngine ───┤
       ├─ StressIndexEngine ───┤
       └─ EnergyBankEngine ────┘

HealthKit ── HealthDomainModels (mixed file)
   ├─ pure DailyHealthSnapshot/WorkoutSummary/SleepSummary candidates
   └─ query diagnostics + mapper + ExtendedHealthMetrics (adapter only)

DailyHealthComputation (ScoreEngineFactory)
   ├─ five engines + baseline math
   ├─ DailyHealthSnapshot / LongTermBaselineReport
   └─ [adapter today] UserDefaults → WikiFileService → explicit Profile

HealthTrendEngine
   ├─ DailyHealthSnapshot / LongTermBaselineReport
   ├─ PersonalHealthBrief / HealthTrendFinding
   └─ [current App coupling] DashboardSummary  ← replace with value projection

App-only projection
   DashboardSummary / BodyState / DailySummaryUseCase
   └─ SwiftData + HealthKit queries + DTOs + Views + persistence side effects
```

当前 `rg` 还确认了以下硬边界：`PersonalBaselineEngine.swift:335-343,506` 直接
调用 `WikiFileService`；`PersonalBaselineEngine.swift:683-697` 扩展
`DailyHealthSummaryRecord`；`ScoreEngineFactory.swift:3-80,181-197` 读写
`UserDefaults`/Wiki；`HealthDomainModels.swift:2,7-69` 依赖 HealthKit。它们是拆分
时必须保留在 App adapter 的明确锁点，而不是可以靠 `import Foundation` 推断掉的依赖。

## 3. 推荐 Package/target/product 契约

### 3.1 目录和 manifest

```text
BodySeekDomain/
├── Package.swift
├── Sources/
│   └── BodySeekDomain/
│       ├── Evidence/          # DailyHealthSnapshot, WorkoutSummary, sleep values
│       ├── Scoring/           # MetricResult, math, five engines, computation
│       ├── Baselines/         # pure baseline/report values and statistics
│       ├── Trends/            # value input and deterministic trend output (later)
│       └── Time/              # explicit HealthDayBoundary/DateRangeQuery (later)
└── Tests/
    └── BodySeekDomainTests/   # package replay + focused algebra tests
```

建议 manifest 形状（实现 PR 不应偷偷扩大范围）：

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BodySeekDomain",
    platforms: [.iOS(.v17), .watchOS(.v10)],
    products: [.library(name: "BodySeekDomain", targets: ["BodySeekDomain"])],
    targets: [
        .target(name: "BodySeekDomain"),
        .testTarget(name: "BodySeekDomainTests", dependencies: ["BodySeekDomain"])
    ]
)
```

production target 的可接受 import 只有 `Foundation`。测试 target 可以使用 XCTest，
但不能把测试辅助类型反向发布到 production。所有跨 actor 的值类型应为
`Sendable`；日期、数组、字典和可选缺失值必须拥有显式初始化与确定性排序规则。

### 3.2 最小公开契约

第一轮建议公开以下 API（具体命名可由实现 agent 提交后评审，但语义不可变）：

```swift
public struct DailyHealthSnapshot: Codable, Hashable, Sendable { ... }
public struct WorkoutSummary: Codable, Hashable, Sendable { ... }
public struct DailyHealthComputationProfile: Sendable {
    public let sleepTargetMinutes: Double
    public let maxHeartRate: Double?
    public let biologicalSex: String?
}
public struct ScoredHealthEvidence: Hashable, Sendable {
    public let sleep: MetricResult
    public let recovery: MetricResult
    public let strain: MetricResult
    public let physiologicalStress: MetricResult
    public let energy: MetricResult
}
public struct DailyHealthComputation: Sendable {
    public init(calendar: Calendar, now: Date, profile: DailyHealthComputationProfile)
    public func compute(
        for snapshot: DailyHealthSnapshot,
        history: [DailyHealthSnapshot],
        longTermBaselines: LongTermBaselineReport?
    ) -> ScoredHealthEvidence
}
```

五个 engine 的 input/output 继续使用现有字段语义；输入里的 `sleepTargetMinutes`、
max HR、biological sex 等由 adapter 解决后显式传入。`nil` 仍表示不可用，禁止把缺失
转为 0；五个 score 独立，禁止在 Domain 添加 aggregate/readiness/Health Age。

### 3.3 宿主边界

- iOS 17 / watchOS 10 是当前 shipping floor；Swift 6/Xcode 26.x 是工程约束。
- iOS 26/watchOS 26 API 只能由宿主 `#available` 渐进使用，不能写进 Domain 的最低平台
  契约，也不能借 PR1 提升 deployment target。
- Domain 禁止 `SwiftUI`、`UIKit`、`HealthKit`、`SwiftData`、`UserDefaults`、
  `ProcessInfo`、Keychain、网络、文件 Wiki、通知和 global singleton。
- Domain 不保存 ModelContext，不创建 HealthStore，不知道 `DailyHealthSummaryRecord`
  或任一 SwiftData schema。Repository/ModelActor 只在下一层把记录转换成值输入。
- 所有 UI 文案、SF Symbol、颜色、`ViewState`、Action 和导航留在 Features。

## 4. Xcode 接入的最低风险方案

### 4.1 为什么先 standalone

当前 `Vela.xcodeproj/project.pbxproj` 只有一个远程 Sentry package：
`XCRemoteSwiftPackageReference` 位于约 896–902 行，`packageReferences` 约 940–942
行；Vela target 的 `packageProductDependencies` 约 834–836 行。当前有
`Vela`、`VelaWatch`、`VelaTests`、`VelaUITests` 四个 native targets，且 iOS/watchOS
源码仍是一个大 target source phase。直接把一组文件从 source phase 移除并同时加本地
Package 会扩大 diff、制造 duplicate symbol/访问控制和 project merge 冲突。

因此 PR1 实现顺序应为：

1. 在 `BodySeekDomain/` 内生成 package 和 tests；运行 `swift test --package-path BodySeekDomain`。
2. 在 package tests 中重放同一 golden fixture；不改变 VelaApp 旧路径。
3. 经 review 确认 public API、`Sendable` 和 parity 后，另开 project-integration 变更。
4. 接入时只增量添加本地 package 引用和产品依赖，旧 VelaApp 实现先保留为 oracle；
   通过 `import BodySeekDomain` 的单一 adapter 逐步切换，最后再删除重复实现。

### 4.2 后续 project.pbxproj 锁点（本 survey 不修改）

接入变更预期只触碰这些结构，且应由一个 agent 独占 `project.pbxproj`：

1. 新增 `XCLocalSwiftPackageReference`（`relativePath = BodySeekDomain`），并加入
   `PBXProject.packageReferences`。
2. 新增 `XCSwiftPackageProductDependency`（product `BodySeekDomain`），加入需要
   编译 Domain 的 `Vela`、`VelaWatch`；若测试直接 import package，再加入 `VelaTests`。
3. 不重写既有 source phase，不删除旧评分文件，不修改 Sentry remote package。
4. 接入前后分别执行 `xcodebuild -resolvePackageDependencies -project Vela.xcodeproj`
   与 iOS/watchOS build/test；如果 Xcode 自动产生 workspace/project 变化，应单独审阅。

这把锁是必要的：该文件目前由四个 target 共用，且 Sentry package 条目已经存在；并行
agent 不得同时编辑它。

## 5. Golden parity 与测试契约

### 5.1 PR1 前后必须一致的事实

`docs/baselines/golden-inventory.json` 是唯一数值 oracle。它固定 Gregorian/UTC、
2026-07-31 12:00、14 天历史、profile（sleep target 450、max HR 190、sex other）、
一项 Strength Training workout，以及五个输出（容差 0.01）：

```text
Sleep 77.43
Recovery 60.70
Strain 63.67
Physiological Stress 21.08
Energy 42.31
```

算法版本必须仍为 `sleep.v2.0.0`、`recovery.v2.0.0`、`strain.v2.0.0`、
`physiologicalStress.v2.0.0`、`energy.v2.0.0`。空状态 fixture 必须保持五项均为
`nil`、`hasData == false`、显示 `--`，且没有 aggregate score；lived-state fixture
仍需保持 objective scores 84/86、confidence low、driver impact -0.5。

### 5.2 推荐 replay 流程

```text
基线（旧 Vela target）
  └─ VelaTests/ScoringEngineTests/
       testDailyHealthComputationGoldenFixtureAndVersionConsistency
  └─ 保存 result summary 与五项 JSON/文本值

Package（新 BodySeekDomain target）
  └─ BodySeekDomainTests/GoldenReplayTests
       同一 fixture 输入、同一 profile/calendar/asOf
  └─ 比较数值、algorithmVersion、missingInputs、nil/-- 语义

宿主接入（仅 adapter 切换后）
  └─ 重跑旧 focused test + package test + full iOS/watchOS gates
```

“byte-for-byte equivalent” 对 JSON 编码不应盲目依赖字典顺序；验收应比较稳定的
规范化 projection（按 domain 固定顺序、数值按 inventory 容差、字符串和 missingInputs
精确比较），并保留原始 `MetricResult` Codable round-trip 测试。任何数值、缺失规则、
时间窗口、算法版本或排序变化都不是 PR1 的“顺便修复”，应退回并单独开算法 PR。

### 5.3 当前基线复核结果

ARCH-00 已记录完整 iOS 单元/UI 结果：`/tmp/Vela-Wave4-Release.xcresult`，520/520
通过（6 UI + 514 unit/integration）。PR1 实现 agent 必须在同一 simulator/测试命令
上取得 focused parity；不能以 package 能编译替代宿主回归。

## 6. 依赖倒置与后续 seams

### 6.1 PR1 应留下的方向

```text
Features (SwiftUI/ViewState/Actions)
             ↓
App orchestration / adapters (HealthKit, SwiftData, UserDefaults, AI)
             ↓ value DTOs only
BodySeekDomain (Foundation-only deterministic computation)
```

反向依赖（Domain import App、Domain 查询 SwiftData、View 直接构建 HealthKit snapshot）
都应被视为 contract violation。App adapter 可以依赖 Domain；Domain 不能依赖 adapter。

### 6.2 给 ARCH-02 的 seam proposal（显式依赖图）

- `AppDependencies` 作为 composition root，持有 `HealthSnapshotRepository`、
  `DailyHealthComputation`、趋势 provider、AI provider 和 clock/calendar；先以 wrapper
  方式并存 `VelaResolver`，不在 PR1 重写 Service Locator。
- `ProfileProvider` 将 UserDefaults/Wiki/HealthKit characteristic 解析成不可变的
  `DailyHealthComputationProfile`；Domain 只接受 profile，不知道来源优先级。
- `HealthSnapshotRepository` 只返回 `DailyHealthSnapshot`/历史值；SwiftData/HealthKit
  fetch 和 schema mapping 留在 ModelActor/adapter。
- `TrendHistoryProvider` 继续沿用现有 provider seam，但把 `DashboardSummary` 换成
  `TrendCurrentEvidence`（五项 MetricResult + 原始 signal projection），避免趋势引擎
  依赖整张 App dashboard。

### 6.3 给 ARCH-03 的 seam proposal（Today Store）

- `TodayStore` 订阅 `AppDependencies`，读取 Domain `DailyHealthComputation` 的值结果，
  生成 `TodayViewState`，只发出 `TodayAction`（refresh/selectDay/checkIn/openCoach 等）。
- View 不持有 `ModelContext`、`HKHealthStore`、`UserDefaults`、global singleton；Store
  负责 effect 与错误映射，View 只消费 state。
- `DashboardSummary`/`BodyState` 在 PR3 前继续作为兼容 projection；不要在 PR1 为了
  “清理命名”做外部产品 rename 或全量迁移。

## 7. 明确不属于 PR1 的内容

- 任何睡眠、恢复、负荷、压力、能量公式、权重、阈值或 algorithm version 改动；
- iOS/watchOS deployment floor bump、iOS 26-only API、Widget target、Widget extension；
- `Vela`→`BodySeek` 全仓 rename、bundle ID/工程名变更；
- SwiftData schema、历史迁移、ModelActor/同步并发重写；
- HealthKit authorization/query、Watch pairing、background delivery；
- Today/Trends SwiftUI 重写、Charts/3+2 dashboard layout、ViewState/Action（ARCH-03/04/05）；
- `BodyStateKernel`、Training Decision、Daily Operating Plan、Coach/AI、Biological Age；
- 把五项分数合成 aggregate/readiness/Health Age；
- 通过 PR1 顺便修复当前发现的 Watch drain adapter 或历史 schema fixture 缺口（分别属于
  CC08/CC04 review handoff）。

## 8. 风险、验收门和下一 handoff

### 风险清单

| 风险 | 证据/影响 | 缓解 |
|---|---|---|
| 同名类型/访问控制 | 现有大量类型是 target-internal；复制后若未 `public` 会导致宿主 import 失败，若两份同时暴露会 duplicate symbol | standalone 先编译；旧实现保留 oracle；一次只迁一个 adapter seam |
| 隐式 app 依赖 | Foundation-only import 掩盖了 Wiki/UserDefaults/SwiftData/HealthKit 同模块符号 | 按 2.1 拆纯子集；对 Domain 做 forbidden-import 静态门 |
| Swift 6 Sendable/日期非确定性 | `Date()`、`.current`、不稳定排序会造成 watch/iOS 或 replay 漂移 | profile/clock/calendar/boundary 显式传入；固定 tie-break 和 UTC fixture |
| parity 回退 | package 重排文件时很容易改动公式或缺失语义 | PR0 inventory + focused replay + full 520 gate；数值/版本/`nil` 精确审查 |
| pbxproj 并行冲突 | 当前四个 target 和 Sentry package 共用一个工程文件 | project integration 独占锁，晚于 standalone contract |
| 过早扩大范围 | Trends/BodyState/Plan 引入 SwiftData/DTO 后会把 Domain 重新耦合 | PR1 只做值类型和算法；下游按 ARCH-02/03/04/05 排队 |

### PR1 contract-ready 验收门

实现 agent 返回以下证据后才能进入 project integration：

1. `BodySeekDomain/Package.swift` 与 source/test 目录存在，production target 仅 Foundation；
2. `swift test --package-path BodySeekDomain` 通过，包含 golden、empty、Codable/
   Sendable/缺失值测试；
3. `git diff --check`、forbidden-import scan 通过；
4. 旧 Vela focused golden test 仍通过，且五项数值、版本、missingInputs 与 PR0 一致；
5. 无 `Vela.xcodeproj/project.pbxproj` 或任何 `VelaApp`/`VelaWatch` source 改动；
6. handoff 明确列出每个已迁移文件、留在 adapter 的部分，以及待 ARCH-02 的 seam。

### 下一 handoff

将本文件交给 `arch_pr1_domain_implementation`（或等价 agent）：从 standalone package
开始，只在 `BodySeekDomain/**` 内工作；不得提交 project integration，不得改公式/部署目标。
实现完成后把状态标为 `contract-ready`（若 package 无法在 Swift 6/iOS17/watchOS10
约束下编译，提供最小复现并标为 `blocked`），再由 orchestrator 安排 ARCH-02。

## 9. 本次勘察的可复现命令与结果

以下命令均为只读检查，执行于 `4d87be951279e5189c79caa2818c1ab81b3fa93c4`：

```text
git rev-parse HEAD
→ 4d87be951279e5189c79caa2818c1ab81b3fa93c4

xcodebuild -version
→ Xcode 26.6 / Build version 17F113

swift --version
→ Apple Swift version 6.3.3 (swift-driver 1.148.6)

xcodebuild -list -project Vela.xcodeproj
→ Targets: Vela, VelaWatch, VelaTests, VelaUITests
→ Schemes: Vela, VelaWatch, VelaWatch (Notification)

xcodebuild -showBuildSettings -project Vela.xcodeproj -scheme Vela
  | rg 'SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|SUPPORTED_PLATFORMS|PRODUCT_BUNDLE_IDENTIFIER'
→ SWIFT_VERSION=6.0; IPHONEOS_DEPLOYMENT_TARGET=17.0;
  SUPPORTED_PLATFORMS=iphoneos iphonesimulator; PRODUCT_BUNDLE_IDENTIFIER=com.sunweizhou.Vela4

python3 scripts/schema_fingerprint.py --check
→ schema fingerprint OK: 32 live models (VelaSchemaV3 3.0.0), 32 frozen V3 models

rg -n '^(@preconcurrency )?import (SwiftUI|UIKit|SwiftData|HealthKit|Combine)' \
  VelaApp/Scoring VelaApp/Health/Models VelaApp/Health/Mapping \
  VelaApp/Core/Utilities/{DateRangeQuery.swift,PersonalHealthBrief.swift}
→ HealthKit only in HealthDomainModels.swift and HealthKitSleepStageMapper.swift;
  SwiftData only in BodyInterpreter/AdaptiveTraining files and App utility files;
  no forbidden import in the Foundation-only scoring files themselves.

git diff --check
→ exit 0
```

> 注：`xcodebuild -showBuildSettings` 的 host 结果是 iOS；watchOS floor 由
> `project.pbxproj` 的 `VelaWatch` configuration 为 10.0，已在 PR0 manifest 中记录。
