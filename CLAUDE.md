# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues for `SunWeizhou/Vela`. See `docs/agents/issue-tracker.md`.

### Triage labels

Use the canonical `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix` labels. See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repository: read `CONTEXT.md` and relevant decisions in `docs/adr/`. See `docs/agents/domain.md`.

## 项目概述

Vela 是一个 local-first 的 iOS 健康分析 App（SwiftUI + SwiftData + HealthKit），对标 Bevel Health。原始健康数据留在设备本地，只有结构化摘要通过 DeepSeek API 直接发送给 LLM（不经过中间服务器）。

- **Target**: `Vela`
- **Scheme**: `Vela`
- **Bundle ID**: `com.sunweizhou.Vela`
- **Deployment**: iPhone B1B2A1DB-2B5C-5C02-A222-B051240A22EA（`Weizhou的iPhone`，iPhone 16 Pro）
- **Project**: `/Users/sunweizhou/Developer/Vela/Vela.xcodeproj`
- **Backend**: `/Users/sunweizhou/Developer/Vela/VelaBackend` (Vapor 4, SQLite) — **当前未启用**，iOS 端直连 DeepSeek API
- **LLM Provider**: DeepSeek (`deepseek-v4-flash` / `deepseek-v4-pro`)，API key 存在 iOS Keychain
- **Current Branch**: `main`（构建与诊断均基于此；已推送至 origin 的 checkpoint `20b24c87`）
- **GitHub**: `https://github.com/SunWeizhou/Vela`

## 构建与推送

```bash
# 构建到手机（先确认手机已连接）
cd "/Users/sunweizhou/Developer/Vela"
DEVICE="B1B2A1DB-2B5C-5C02-A222-B051240A22EA"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination "id=$DEVICE" -configuration Debug -allowProvisioningUpdates build

# 推送已构建产物到手机（只改 Swift 代码时可直接执行）
# 产物路径：~/Developer/Vela-DerivedData/Build/Products/Debug-iphoneos/Vela.app
xcrun devicectl device install app --device "$DEVICE" \
  ~/Developer/Vela-DerivedData/Build/Products/Debug-iphoneos/Vela.app

# 仅检查编译（不连手机，建议 macOS 本机 Debug 仿真校验，避免写在 iCloud 同步目录）
xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug -derivedDataPath ~/Developer/Vela-DerivedData build
```

> ⚠️ **工程必须放在非 iCloud 同步目录**（当前在 `~/Developer/Vela`）。若放回 iCloud 同步的桌面/文稿，xcodebuild 会在 `NSFileCoordinator _blockOnAccessClaim` 处死锁，无法解析工程。`DerivedData` 显式指到 `~/Developer/Vela-DerivedData`，避免默认走 iCloud。

## 前端架构：Apple Design System + Signal Intelligence（2026-07-13 更新）

所有视图使用统一的 VelaTheme 和 VelaDesignSystem 组件。

### 核心层

**VelaTheme** (`VelaApp/Core/Theme/VelaTheme.swift`) — 设计 Token 唯一入口：
- Surface: `bg`, `surface`, `cardBg`, `elevatedBg`, `groupedBg`
- Text: `fg`, `fg2`, `muted`, `meta`
- Accent: `accent` (Signal Blue `#5664E8` / dark `#7F8CFF`)
- Semantic: `strainColor`, `recoveryColor`, `sleepColor`, `stressColor`, `energyColor`
- Typography: `largeTitle()`, `title1()`-`title3()`, `headline()`, `body()`, `callout()`, `subheadline()`, `footnote()`, `caption1()`-`caption2()`
- Spacing: `space1`-`space12` (4-48px, 8px grid), `pagePadding` (20px), `cardGap` (14px)

**VelaDesignSystem** (`VelaApp/Core/DesignSystem/VelaDesignSystem.swift`) — 复用组件 + View Modifiers：
- `ScoreRing`, `VitalCard`, `InfoCard`, `InsightCard`, `EmptyStateCard`
- `GlassTabBar`, `StatusCapsule`, `DayPill`, `MessageBubble`, `TypingIndicator`
- `SettingsRow`, `ToggleRow`, `EvidenceStep`, `DataFreshnessBar`
- `SettingsGroup<Content>`, `QuickEntryButton`, `WorkoutCard`, `TagChip`, `PlusAction`
- `.cardSurface()`, `.heroCardSurface()`, `.glassEffect()`, `.sectionSpacing()`
- Button styles: `.cardPress`, `.tabItem`, `.plusButton`

**VelaLoc** (`VelaTheme.swift` 内) — 中文默认本地化枚举，所有属性为 computed 以避免 Sendable 警告。

### Shell 与页面（4-Tab）

**VelaShell** (`VelaApp/Features/Minimal/VelaMinimalShell.swift`) — 根导航：
- 4 tabs: 今日 / 训练 / 教练 / 我的
- iOS 26 使用系统 Liquid Glass Tab Bar，早期系统使用自定义浮动玻璃导航
- 快速记录与设置由页面内入口和全局 AppState sheet 触发

| Tab | 页面 | 文件 | 数据源 |
|-----|------|------|--------|
| Tab 0 | TodayView | `VelaMinimalTodayView.swift` | `@EnvironmentObject dashboardVM` |
| Tab 1 | TrainingView | `VelaMinimalFitnessView.swift` | `@EnvironmentObject dashboardVM` + TrainingIntelligence |
| Tab 2 | CoachView | `CoachView.swift` | `@StateObject vm: CoachChatVM`（本机建议 + 可选 streaming） |
| Tab 3 | MeView | `VelaMinimalJournalView.swift` | `@AppStorage` + `@Query coachArtifacts` |
| — | SettingsView | `VelaMinimalCoachView.swift` | 手记/Journal 页面 |
| — | MetricDetailView | `VelaMinimalComponents.swift` | 各页面 onTap 导航进入 |
| — | PlusActionSheet | `VelaQuickActionsSheet.swift` | 快速添加动作面板 |

### 关键：文件映射（pbxproj 不可脚本修改）

由于直接修改 pbxproj 会损坏项目，新文件通过**覆盖现有文件内容**的方式放入：
- `VelaShell.swift` → 覆盖 `VelaMinimalShell.swift`
- `VelaJournalView.swift` → 覆盖 `VelaMinimalCoachView.swift`
- `VelaMetricDetailView.swift` → 覆盖 `VelaMinimalComponents.swift`
- `VelaSettingsView.swift` → 覆盖 `VelaMinimalJournalView.swift`
- `VelaPlusActionSheet.swift` → 覆盖 `VelaQuickActionsSheet.swift`

**绝不通过脚本修改 pbxproj**。新增 Swift 文件时，让用户在 Xcode 中手动添加（`Vela.xcodeproj/project.pbxproj` 已被手动编辑过以注册 TrainingIntelligence 模块文件）。

### 数据注入模式

```swift
@EnvironmentObject private var dashboardVM: DashboardViewModel  // 健康评分
@EnvironmentObject private var services: VelaServices            // AI Provider 等
@Environment(\.modelContext) private var modelContext            // SwiftData
@StateObject private var vm = CoachChatVM()                      // Coach 专用 VM
```

### 核心共享组件

- **MarkdownText** (`VelaApp/Features/SharedComponents/MarkdownText.swift`) — Coach 聊天气泡专用 markdown 渲染。按 `\n\n` 拆分段落为独立 `Text`，`VStack(spacing: 10)` 渲染以保证段落间距。
- **CoachChatPanel** (`VelaApp/Features/Coach/CoachChatPanel.swift`) — 消息气泡 + 流式渲染组件（`MiniBubble` / `MiniStreamingBubble`）
- **DashboardViewModel** (`VelaApp/Features/SharedComponents/DashboardViewModel.swift`) — ObservableObject，持有 DashboardSummary
- **MetricCoachCard** (`VelaApp/Features/SharedComponents/MetricCoachCard.swift`) — Apple Intelligence 风格的指标分析入口卡片

## 数据流（当前架构，Vela 3.0 Active Coach OS）

```
HealthKit → HealthKitSyncEngine (2-pass: raw snapshot → DailyHealthComputation)
  → SwiftData DailyHealthSummaryRecord（本地缓存，50+ 字段）
  → DailyHealthComputation → 评分引擎计算 MetricResult
  → DashboardSummary（聚合体）→ DashboardViewModel (@EnvironmentObject)
  → TodayCommandBuilder.build() → TodayCommandState (readiness / actions / signals)
  → AIContextBuilder.build() → AgentContextEnvelope
  → DeepSeek API（iOS 端直连，不经过中间服务器）→ SSE 流式返回
```

**⚠️ VelaBackend 当前未连线**：iOS 端直连 DeepSeek API (`api.deepseek.com`)，模型 `deepseek-v4-flash` / `deepseek-v4-pro`。VelaBackend 是并行设计的服务端替代方案（Claude API + 用户系统 + 审计），尚未集成。

### 引擎调用路径说明

`DailyHealthComputation.compute(for:history:)` 是前台刷新、后台同步和历史计算的唯一评分入口。评估时间、日历和用户配置显式注入；不要在其他路径重新组装评分引擎 Input。PreviewDataFactory 用固定种子合成预览数据。

### 历史数据组装

- `hrvHistory` / `rhrHistory`: 从 SwiftData 42 天快照中 compactMap 提取，用于 Recovery 引擎 MAD 基线计算
- `last28DaysDailyLoads`: 从快照 `dailyLoad` 字段提取，用于 Strain 引擎 ATL/CTL/ACWR（`StrainScoreEngine` 已用 EWMA `2.0/(28+1)`）
- `strainHistory`: 从快照 `strainScore` 提取，用于 EnergyBank 引擎 ATL/CTL/TSB 计算

关键类型：
- `DashboardSummary`: 所有评分的聚合体（`Core/Utilities/DashboardSummary.swift`）
- `DashboardViewModel`: ObservableObject，持有 DashboardSummary，通过 `@EnvironmentObject` 注入页面
- `DailyHealthComputation`: 唯一的每日评分 module，构建 Input 并调用引擎（位于 `Scoring/ScoreEngineFactory.swift`）；HealthKit sync 只负责提供 Daily Health Snapshot
- `DashboardMetricProjection`: 从规范评分结果构建展示所需的睡眠与健康年龄 projection
- `PreviewDataFactory`: 用真实引擎 + 固定种子生成预览 DashboardSummary
- `AIContextBuilder`: 构建发给 LLM 的结构化上下文包（AgentContextEnvelope v1 / TypedAgentContext v2）
- `DomainContextBuilders`: 各领域的上下文构建器（Sleep/Recovery/Strain/Stress/EnergyBank/StrengthTraining 等）
- `CoachChatVM`: Coach 对话的 ViewModel，管理 streaming 状态和消息历史
- `TodayCommandBuilder`: 规则引擎，从 DashboardSummary 产生 TodayCommandState（readiness 判定 + 行动建议）

## Training Intelligence 模块（Vela 3.0 新增）

位置：`VelaApp/TrainingIntelligence/`，已注册到项目 pbxproj。

### 模型（`Models/TrainingIntelligenceModels.swift`）
- `PersonalRecord` — 个人最佳记录（重量/e1RM）
- `LocalMuscleFatigue` — 局部肌群疲劳分析
- `StrengthWorkoutAnalysis` — 训练分析结果
- `RecentTrainingSummary` — 近期训练概览
- `RecoveryTrainingInput` — 恢复-训练联动输入
- `TrainingAdaptationRecommendation` — 训练调整建议

### 服务（`Services/`）
- `TrainingAnalyticsService` — 训练分析：容量、有效组、肌群映射、e1RM、PR 检测
- `RecoveryTrainingAdapter` — 恢复感知训练调整：根据恢复/睡眠/HRV/RHR/TSB 调整容量和强度
- `ExerciseLibraryService` — 默认动作库种子数据（胸/背/腿/肩/手臂/核心）
- `TrainingPlanLinkingService` — 训练事件与计划日期的匹配评分

### 视图（`Views/`）
- `FitnessActivitySummaryDetailView.swift` — 过去 30 天活动摘要详情页
- `StrengthWorkoutDetailView.swift` — 力量训练详情页
- `StrengthWorkoutLogSheetView.swift` — 力量训练记录表单（动作、组、重量、次数）

## 评分引擎

每个引擎实现 `ScoreEngine` protocol（定义在 `Scoring/ScoringCore.swift`），输出统一的 `MetricResult`（value 0-100 / band / confidence / components / reasons）。

| 引擎 | 文件 | 功能 | 学术基础 |
|------|------|------|---------|
| `SleepScoreEngine` | `Scoring/Sleep/SleepScoreEngine.swift` | 3 因子: Duration (0-50) + Consistency (0-30) + Interruption (0-20) | Buysse (1989) PSQI 五维框架，REM/Deep% 匹配 AASM 标准 |
| `RecoveryScoreEngine` | `Scoring/Recovery/RecoveryScoreEngine.swift` | HRV log-SDNN Z-score (35%) + RHR Z (25%) + Sleep (25%) + PriorStrain (15%) + Red Flag modifiers | Plews (2012/2014) 运动员 HRV 监测，MAD 稳健统计 (1.4826 因子)，副交感反弹保护 |
| `StrainScoreEngine` | `Scoring/Strain/StrainScoreEngine.swift` | Lucia's TRIMP (HR zone) / Banister TRIMP (性别参数) / Foster's Session RPE → dailyLoad → ATL/CTL/TSB/ACWR | Banister (1975) 脉冲-响应模型，Lucia (2003)，Foster (2001)，Gabbett (2016) ACWR 阈值 |
| `StressIndexEngine` | `Scoring/Stress/StressIndexEngine.swift` | 6 因子加权: RHR↑ (25%), HRV↓ (25%), RR↑ (15%), Temp (10%), SleepDebt (15%), Load (10%) + 运动窗口排除 | Thayer (2012) HRV-压力 meta-analysis，各单因子有文献 |
| `EnergyBankEngine` | `Scoring/EnergyBank/EnergyBankEngine.swift` | Firstbeat-inspired charge/discharge + ATL(7d)/CTL(42d)/TSB + 正念/小憩充电 | Firstbeat 专有算法启发式还原 (Garmin) |
| `HealthAgeTrendEngine` | `Scoring/HealthAge/HealthAgeTrendEngine.swift` | 多因子趋势方向评分 → improving/stable/worsening | 启发式，VO2Max/RHR/Sleep/Steps 等权重 |
| `BiologicalAgeEngine` | `Scoring/Biology/BiologicalAgeEngine.swift` | Levine PhenoAge 临床化验模型（9 项血液指标 + 年龄）| Levine et al. (2018, *Aging*)，逐字实现论文回归系数（**已接入**，见 `CoachContextAssembler`/`BiologyView`/`Vitals` 调用点） |
| `BodyInterpreterEngine` | `Scoring/BodyInterpreter/BodyInterpreterEngine.swift` | 多系统疲劳分析 + 主要限制因子 + 训练窗口 + 风险标记 + 恢复任务 | 专家推理框架 |
| `JournalCorrelationEngine` | `Scoring/Correlation/JournalCorrelationEngine.swift` | 行为标签 vs 次日体征滞后关联分析 | Spearman + 点二列相关，刚提高最低样本门槛 |
| `DailyPlanLimiterEngine` | `Scoring/DailyPlan/DailyPlanLimiterEngine.swift` | 规则引擎: sleep/recovery/stress/load/temp/手记 → keep/reduce/swap/rest | 保守安全规则，任何 severity 3 → rest |
| `PersonalBaselineEngine` | `Scoring/PersonalBaselineEngine.swift` | 30 天均值 ± SD 个人基线，写入 Wiki baselines.md | 标准运动监测，支持 round-trip markdown 解析 |
| `DailyHealthComputation` | `Scoring/ScoreEngineFactory.swift` | 前台、后台、历史共用的唯一评分入口 | — |

### 已知改进空间

- **HRV 只用了 SDNN**：HealthKit 同时提供 RMSSD（更好的迷走神经代理）和 SDNN，RMSSD 未使用（`HealthKitQueryService` 只请求 `.heartRateVariabilitySDNN`）
- **Readiness 置信度硬编码**：`TodayCommandState` 每场景硬编码 0.86/0.78/0.74/0.72 等，且 `dynamicConfidence` 有 `max(0.3, …)` 下限——数据全低时也会拔高，未以用户 adoption/accuracy feedback 校准（`DailyDecisionFeedbackRecord` 存在但未回灌）
- **局部疲劳阈值双系统不一致**：`TodayCommandState` 用 `setsLast48h >= 15` 触发 swap，`TrainingIntelligenceModels` 用 `>= 14` 判高——两处阈值打架
- **EnergyBankEngine 的 EWMA 用最旧值正向递推**（`ewma` 从 oldest 开始），非 Banister 的今天反向递归，数值略有差异（已确认是 EWMA 而非简单平均）
- **训练数据无单一事实来源**：HealthKit `WorkoutEventRecord` + 本地 `StrengthWorkoutRecord` + XunJi `XunjiWorkoutMirrorRecord` 三条路径合并进 `RecentTrainingSummary`，可能重复计数

## VelaBackend（Vapor 4）— 当前未启用

独立的服务端项目 (`VelaBackend/`)，使用 Fluent + SQLite + JWT + Anthropic Claude API。**当前 iOS 端直连 DeepSeek API，VelaBackend 尚未集成到产品流中。**

### API 路由（设计阶段）

| 方法 | 路径 | 是否走 LLM |
|------|------|-----------|
| POST | `/api/auth/register` | 否 |
| POST | `/api/auth/login` | 否 |
| POST | `/api/auth/refresh` | 否 |
| POST | `/api/coach/chat` | Claude API + Tool Use |
| GET | `/api/today/plan?lang=zh&recovery=72&...` | Claude JSON |
| GET | `/api/training/adaptations` | Claude JSON |
| POST | `/api/insights/evidence` | Claude JSON 证据链 |
| GET | `/api/memory/inbox` | 读 DB |
| PUT | `/api/memory/card/:id` | 更新 DB |
| GET | `/api/data-coverage` | 纯计算（不走 LLM） |
| GET | `/api/trust/audit` | 读 DB |
| PUT | `/api/settings` | 读写 DB |

### 核心服务

- `LLMService`: actor，封装 Anthropic Claude API 调用（`claude-sonnet-4-6`），含 3 个 Tool Definition
- `PromptService`: 5 套中文 Prompt 模板（coach/todayInsight/trainingAdaptation/evidenceChain/memoryPattern）
- `JWTService`: Access Token 15min / Refresh Token 7d

### HealthContext 边界

iOS 端只发摘要 `HealthContext`，原始 HealthKit 数据永不离设备。当前直连 DeepSeek 时同样遵守此边界。

## AI / Memory / Proactive 模块（VelaApp/AI/）

### 上下文构建

| 子模块 | 文件 | 职责 |
|--------|------|------|
| Context | `AIContextBuilder.swift` | 双路径构建 AgentContextEnvelope（v1 dictionary）和 TypedAgentContext（v2 typed）。从 DashboardSummary + journal/wiki/foodLog/strengthWorkout 构建结构化上下文 |
| Context | `DomainContextBuilders.swift` | 各领域上下文构建器（Sleep/Recovery/Strain/Stress/EnergyBank/StrengthTraining/Nutrition/ExtendedMetrics 等） |
| Models | `AgentContextSchema.swift` | AgentContextEnvelope 定义，含 `ContextBudget`（**已定义但 AIContextBuilder / Scheduler 未执行限制**） |
| Models | `TypedContextSchema.swift` | 强类型上下文 schema，`MetricValue<T>` 带 source/freshness/confidence/baseline 元数据 |

### 记忆系统（Artifact + Wiki）

| 子模块 | 文件 | 职责 |
|--------|------|------|
| Artifact | `AgentActionParser.swift` | CoachArtifact 类型定义（8 种: morningBrief, workoutReadiness, trainingAdjustment, postWorkoutReview, eveningReview, weeklyReview, wikiUpdateProposal, askCoachAnswer），CoachArtifactAction/Reason/Status |
| Artifact | `PersistenceModels.swift` (CoachArtifactRecord) | SwiftData 持久化，reasons/actions 存为 JSON blob |
| Memory | `MemoryLedger.swift` | 记忆提议账本: propose → confirm(写入 Wiki) / reject / rollback(标记 superseded) / expire(14天过期) |
| Memory | `MemoryModels.swift` | MemoryEventRecord（8 种类型: fact/observation/hypothesis/strategy/preference/constraint/goalChange/baselineUpdate），MemoryProposalStatus（proposed→accepted/rejected/superseded/expired），AgentRunRecord，WikiFileRole，ContextBudget |
| Wiki | `WikiFileService.swift` | 14 个 Markdown Wiki 文件读写，merge 模式去重（精确+子串+Levenshtein >0.85），baselines.md 由 PersonalBaselineEngine 自动生成 |

### LLM Provider & Agent

| 子模块 | 文件 | 职责 |
|--------|------|------|
| Provider | `DeepSeekProvider.swift` | DeepSeek API（`api.deepseek.com`），SSE streaming（流式逐 delta 下发，**无 60ms throttle**——该说法不实），temperature 0.4，模型 `deepseek-v4-flash`/`deepseek-v4-pro`。**重试在 `AgentLoop.RetryingAgentChatProvider` 层，指数退避、retry 5xx/429/408/网络/超时** |
| Provider | `LLMProvider.swift` | LLM Provider 协议 + ChatMessage/LLMResponse/Value 类型 |
| Provider | `WebSearchService.swift` | DuckDuckGo HTML scraping — **dead code，实际使用 WebSearchHelper (Bing)** |
| Agent | `AgentLoop.swift` | Agent 工具调用循环: 发送消息 → 检查 tool_calls → 执行工具 → 追加结果 → 循环（maxIterations=3）→ 流式最终响应。**重试在 `RetryingAgentChatProvider`（外包一层）；无用户取消传播、整段无总超时（仅 per-tool 20s / per-request 120-180s）** |
| Agent | `AgentTool.swift` | AgentTool 协议 + ToolRegistry + ToolExecutionContext |
| Agent | `ToolFactory.swift` | **14 个 Tool** 注册（`allTools`）: WebSearch, UpdateWiki, TodayHealth, HealthHistory, HealthTrend, UnifiedWorkoutHistory, StrengthWorkoutHistory, TrainingResponseHistory, JournalCorrelation, FoodLog, TrainingPlan, CreateTrainingPlan, DeleteTrainingPlan, RenderCorrelationChart |
| Agent | `WebSearchHelper.swift` | Bing HTML scraping（活跃实现，但违反 ToS） |
| Agent | `FoodPhotoAnalyzer.swift` | Kimi Vision API（Moonshot），`kimi-k2.6` 模型，JPEG 0.7 压缩 → base64 → 解析食物/json |

### 主动服务

| 子模块 | 文件 | 职责 |
|--------|------|------|
| Proactive | `MorningBriefScheduler.swift` | 06:00-11:00 窗口 → AIContextBuilder → ReportGenerator → AIReportRecord → 推送通知。**无超时、无 HealthKit 同步完成检查** |
| Proactive | `EveningWikiSyncAgent.swift` | 21:00-04:00 窗口 → 发送数据给 DeepSeek → 解析 legacy `[ACTION:update_wiki]` 标签 → MemoryProposal。**仍用 legacy parser，未迁移到 AgentLoop** |
| Proactive | `ProactiveInsightService.swift` | 7 条硬编码规则评估 DashboardSummary → [ProactiveInsight]（HRV↓/睡眠↓/训练窗口/能量↓/负荷-恢复不匹配/压力↑） |
| Proactive | `PersonalResponseInsightService.swift` | 60 天快照扫描 → 个人反应模式 → MemoryEventRecord 提议 |
| Proactive | `BackgroundTaskManager.swift` | iOS BGTask 注册与调度 |
| Reports | `ReportGenerator.swift` | AI 报告生成（morning brief/sleep review/etc.），**无 max_tokens 限制** |
| Prompting | `CoachPromptComposer.swift` | 组合式 Prompt 片段: temporal context / personality / web search / wiki / baselines / plan / health context / journal correlations / cross-diagnosis / thresholds / training prescription。三种变体: casual / focused / full。**无 token budget 强制** |

## 注意事项

- **🔥 [CRITICAL] 前端视觉标准 (Signal Intelligence)**: 2026-07-13 起采用冷中性画布 `#F4F6FA`、Signal Blue 品牌色、深色 Daily Focus 卡、克制的健康语义色和原生 Liquid Glass 导航。页面必须优先呈现“一个今日重点 → 判断依据 → 下一步行动”，避免暖纸张、陶土色、装饰性仪表堆叠和无意义渐变。允许持续优化结构，但必须保持语义 Token、动态字体和可访问性。
- **📁 [Minimal Shell 文件映射说明]**: 为了在不损坏 Xcode `.pbxproj` 索引引用的前提下实现最清晰的文件逻辑，前端文件内容与 Tab 映射如下：
    - `VelaMinimalShell.swift` ➡️ 底栏 Tab 胶囊容器 `VelaShell`
    - `VelaMinimalTodayView.swift` ➡️ Tab 1 今日主页 `VelaTodayView`
    - `VelaMinimalJournalView.swift` ➡️ Tab 2 习惯手记 `VelaJournalView`
    - `VelaMinimalFitnessView.swift` ➡️ Tab 3 训练主页 `VelaTrainingView`
    - `VelaMinimalVitalsView.swift` ➡️ Tab 4 体征主页 `VelaVitalsView`
    - `VelaMinimalCoachView.swift` ➡️ "我的"设置页面 `VelaSettingsView`
    - `VelaMinimalComponents.swift` ➡️ 耗力/睡眠/压力等全量指标高保真详情页 `VelaMetricDetailView`
- **pbxproj 规则**: 不直接修改 pbxproj，推荐用文件覆盖方式添加新代码；但 TrainingIntelligence 模块的新文件已通过手动编辑 pbxproj 注册成功。
- 新前端代码中 `body` 不能用作存储属性名（与 SwiftUI `body` 冲突），用 `bodyText` 替代
- LocalizedStringKey 在 Swift 6 下有 Sendable 警告，用 computed property 而非 stored let
- 设计 Token 使用新名称（`fg`/`bg`/`cardBg`），旧名称作为向后兼容别名保留
- Coach streaming 使用 SSE 逐 delta 下发（`DeepSeekProvider`）；历史上 CLAUDE.md 曾写"60ms throttle"，但代码中不存在该节流——以实际实现为准。UI 层的滚动/动画节流在视图层处理。
- Coach 键盘交互：通过 `NotificationCenter` 监听 `keyboardWillShow`/`keyboardWillHide`，使用 `isKeyboardVisible` 状态控制底部 padding
- 根目录的 `Vela*.swift` 和 `VelaApple*.swift` 文件是 Stitch 设计参考，实际代码在 `VelaApp/` 中
- **测试**: `xcodebuild test` 测试全部通过（100% pass rate）
