# TECH_ARCHITECTURE.md
# Project Vela — Technical Architecture

> Updated: 2026-06-09
> This document reflects the current build. Product context: `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

## 0. 当前技术状态

截至 2026-06-09:

- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug` succeeds (100% pass rate).
- 真机 iPhone 16 Pro 可通过 `devicectl` 构建、安装和启动。
- 项目包含 HealthKit、SwiftData、评分引擎、AI Agent、Wiki、Training Intelligence、Biology、食物分析、通知等模块。
- App shell 使用 Apple Design System + Bevel Parity 视觉体系：`VelaTheme` 设计令牌、`VelaDesignSystem` 复用组件、毛玻璃胶囊底栏、白卡驾驶舱。
- **VelaBackend** (Vapor 4) 存在但 **当前未启用** — iOS 端直连 DeepSeek API (`api.deepseek.com`)。
- **Training Intelligence v3** 模块已落地：模型层、分析服务、恢复联动适配器、计划关联、力量训练视图。
- **Vela 4.0 Active Coach OS** 核心闭环已实施：统一 WorkoutEvent 汇总、BodyStateKernel、TrainingDecisionKernel、DailyOperatingPlan、Agent artifacts、可审计 AgentRun trace。

## 1. 技术总览

### 平台
- iOS App (SwiftUI + SwiftData)
- 可选后端: VelaBackend（当前运行时未启用）

### 系统能力
- HealthKit（睡眠/心率/HRV/运动/体测/血氧/体温等）
- SwiftData 本地持久化
- Charts / Swift Charts
- Keychain API Key 管理
- 本地文件存储（Wiki / agent.md）

### AI
- Claude API（VelaBackend 默认）/ DeepSeek API（iOS 端直连）
- Kimi Vision（食物照片识别）
- Streaming Coach chat
- Agent tools (Web Search, Wiki Update, Training Plan, Food Log)
- Proactive agents (Morning Brief, Evening Wiki Sync, Check-ins)
- Memory Proposal & Confirmation Ledger
- Personal Response Insight (训练反应 + 周报)

## 2. 架构风格

- Feature-based modular architecture
- Service / Repository / Engine 分层
- ViewModel 驱动 UI
- Domain Model 与 HealthKit 原始对象隔离

## 3. 高层架构

```text
┌─────────────────────────────────┐
│          SwiftUI Views           │
│  Today OS / Training Execution / │
│  Intelligence / Vitals / Journal│
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│           ViewModels             │
│  DashboardViewModel              │
│  CoachChatVM                     │
│  ActiveWorkoutSessionViewModel   │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│       Application Layer          │
│  DailySummaryUseCase             │
│  DailyOperatingPlanCoordinator   │
│  AIContextBuilder                │
│  MorningBriefScheduler           │
│  EveningWikiSyncAgent            │
│  PersonalResponseInsightService  │
│  ReportGenerator                 │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│          Domain Layer            │
│  Score Engines (Sleep/Recovery/  │
│    Strain/Stress/Energy/HealthAge)│
│  ScoreEngineFactory              │
│  BodyStateKernel                 │
│  TrainingDecisionKernel          │
│  WorkoutAggregationService       │
│  TrainingAnalyticsService        │
│  BodyInterpreter                 │
│  BiologicalAgeEngine             │
│  JournalCorrelationEngine        │
│  DailyPlanBuilder                │
└──────────────┬──────────────────┘
               │
┌──────────────▼──────────────────┐
│     Infrastructure Layer         │
│  HealthKit Services              │
│  SwiftData Repositories          │
│  KeychainService                 │
│  WikiFileService                 │
│  DeepSeekProvider                │
│  WebSearchService                │
│  FoodPhotoAnalyzer (Kimi)        │
│  Optional inactive VelaBackend   │
└──────────────────────────────────┘
```

### 3.1 Daily Body Intelligence Loop

`HealthKit + local records -> WorkoutEventRecord/DailyHealthSummaryRecord -> BodyStateKernel -> TrainingDecisionKernel -> DailyOperatingPlanRecord -> Training/Journal/Nutrition actions -> TrainingResponseRecord -> Coach context + Memory proposal -> next plan`

`WorkoutAggregationService.aggregateDay` is the only writer of workout count, duration, load, types, and serialized workouts. Home, Coach, Morning Brief, and Training consume the shared kernel output instead of maintaining independent readiness rules.

## 4. 模块拆分

### 4.1 Health Module
- HealthAuthorizationService
- HealthKitQueryService
- HealthKitSyncEngine
- HealthDataRefreshService
- HealthSignalCoverageService
- WorkoutAggregationService

### 4.2 Scoring Module
- SleepScoreEngine, RecoveryScoreEngine, StrainScoreEngine
- StressIndexEngine, EnergyBankEngine
- HealthAgeTrendEngine, BiologicalAgeEngine
- ScoreEngineFactory（统一创建引擎 Input）
- AdaptiveTrainingEngine, TrainingDecisionEngine
- BodyInterpreterEngine
- JournalCorrelationEngine
- DailyPlanLimiterEngine

### 4.3 Training Intelligence Module
位置: `VelaApp/TrainingIntelligence/`

- **Models** (`Models/TrainingIntelligenceModels.swift`): PersonalRecord, LocalMuscleFatigue, StrengthWorkoutAnalysis, RecentTrainingSummary, RecoveryTrainingInput, TrainingAdaptationRecommendation
- **Services**:
  - `TrainingAnalyticsService` — 容量/有效组/肌肉映射/e1RM/PR
  - `RecoveryTrainingAdapter` — 恢复感知训练调整
  - `ExerciseLibraryService` — 默认动作库（胸/背/腿/肩/手臂/核心）
  - `TrainingPlanLinkingService` — 训练事件与计划匹配
- **Views**:
  - `FitnessActivitySummaryDetailView` — 30天活动摘要
  - `StrengthWorkoutDetailView` — 力量训练详情
  - `StrengthWorkoutLogSheetView` — 训练记录表单

### 4.4 AI Module
- DeepSeekProvider（60ms throttle streaming）
- LLMProvider protocol
- AIContextBuilder + DomainContextBuilders
- AgentContextEnvelope / TypedContextSchema
- AgentTool / ToolFactory / AgentLoop
- WebSearchService / FoodPhotoAnalyzer (Kimi Vision)
- CoachChatVM / CoachChatPanel
- MarkdownText（段落间距渲染）
- MorningBriefScheduler / EveningWikiSyncAgent
- PersonalResponseInsightService / ProactiveInsightService
- MemoryLedger / MemoryModels

### 4.5 Persistence Module
- SwiftData models (PersistenceModels.swift)
- DailyHealthSummaryRecord（核心日摘要，含 50+ 字段）
- StrengthWorkoutRecord / ExerciseDefinitionRecord / WorkoutEventRecord
- TrainingPlanRecord / TrainingDay
- CoachInteractionRecord / DailyOperatingPlanRecord / AgentArtifactRecord / AgentRunRecord
- FoodLogRecord / JournalEntryRecord / AIReport
- VelaModelContainer（SwiftData 容器配置）

### 4.6 Wiki Module
- 多文件 Markdown Wiki（`agent/user_wiki/`）
- WikiFileService 读写
- Agent 写入必须通过 AgentActionParser
- baselines.md 由 PersonalBaselineEngine 自动生成
- MemoryProposal → 用户确认 → 写入 Wiki

### 4.7 UI Shell / Design System
- VelaTheme（设计令牌）
- VelaDesignSystem（复用组件 + Modifiers）
- GlassTabBar 胶囊底栏 + 圆形 `+` 动作按钮
- Bevel Parity 视觉标准：#F5F3F0 暖白画布 / 白卡 / 三环仪表

## 5. 数据流（当前架构）

### 5.1 健康数据刷新
```text
HealthKit Raw Samples
    ↓
HealthKitSyncEngine (2-pass: raw snapshot → MetricComputationPipeline)
    ↓
DailyHealthSummaryRecord (SwiftData 缓存，50+ 字段)
    ↓
MetricComputationPipeline 内联构建引擎 Input 并调用
    ↓
评分引擎 → MetricResult
    ↓
DailysummaryUseCase.loadDashboard() 聚合
    ↓
DashboardSummary (聚合体)
    ↓
DashboardViewModel (@Published, @EnvironmentObject 注入全视图树)
    ↓
UI Refresh
```

**注意**: `MetricComputationPipeline` 是主路径，绕过 `ScoreEngineFactory` 直接构建输入。`ScoreEngineFactory` 仅在回填路径 (`backfillSleepHistoryIfNeeded`) 中使用。PreviewDataFactory 用固定种子合成预览数据。**修改引擎算法需同步更新三处**。

### 5.2 AI 上下文构建
```text
DashboardSummary + SwiftData 记录 (journal/foodLog/strengthWorkout/onboarding/wiki)
    ↓
AIContextBuilder.build() / buildTyped() (双路径: v1 dictionary + v2 typed)
    ↓
AgentContextEnvelope (JSON) 或 TypedAgentContext
    ↓
CoachPromptComposer → DeepSeekProvider (直连 api.deepseek.com)
    ↓
SSE 流式响应 → CoachChatPanel 渲染 (MarkdownText)
```

### 5.3 训练闭环
```text
力量训练记录 (StrengthWorkoutLogSheetView)
    ↓
StrengthWorkoutRecord (SwiftData)
    ↓
WorkoutAggregationService → WorkoutEventRecord
    ↓
DailyHealthSummaryRecord 更新 (workoutCount/workoutDuration/strainScore)
    ↓
TrainingAnalyticsService → StrengthWorkoutAnalysis
    ↓
RecoveryTrainingAdapter → TrainingAdaptationRecommendation
    ↓
TrainingView / Coach 上下文
```

## 6. VelaBackend（Vapor 4）— 当前未启用

VelaBackend 是服务端项目，使用 Fluent + SQLite + JWT + Anthropic Claude API。当前 **iOS 端直连 DeepSeek API**，不经过 VelaBackend。

### 路由摘要（设计阶段）
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/register`, `/login`, `/refresh` | JWT 认证 |
| POST | `/api/coach/chat` | Claude API + Tool Use |
| GET | `/api/today/plan` | Claude JSON |
| GET | `/api/training/adaptations` | Claude JSON |
| POST | `/api/insights/evidence` | Claude JSON |
| GET/PUT | `/api/memory/*` | 本地 DB |
| GET | `/api/data-coverage` | 纯计算 |

### HealthContext 边界
iOS 端只发送结构化摘要，原始 HealthKit 数据永不离设备。当前直连 DeepSeek 时同样遵守此边界。

## 7. 技术风险与已知问题

### 当前风险

| 风险 | 缓解 |
|------|------|
| HealthKit 数据不可用（VO₂Max/Body Fat 等） | Empty state + `--` + 数据覆盖度说明 |
| Stress/Biological Age 科学性 | 标注 Beta / proxy，引擎可替换 |
| LLM 输出不稳定 | 固定输出结构 / Prompt 约束 / JSON schema |
| SwiftData migration 风险 | 优先 JSON 字段扩展 + 可选字段 |
| pbxproj 冲突 | 不脚本修改 pbxproj，新文件手动 Xcode 注册 |
| Token budget 超限 | `ContextBudget` 已定义但 `AIContextBuilder` / scheduler 未执行限制 |
| 无 HTTP 重试机制 | DeepSeekProvider / Agent Loop / Scheduler 全链路无 retry/backoff |
| ATL/CTL 用简单平均非 EWMA | EnergyBankEngine 待修正为指数加权 |

### 近期修复 (2026-06-04 audit-driven)

| Bug | 修复内容 |
|-----|---------|
| 睡眠心率查询错误 | 从全天区间改为按最近一次睡眠区间取样 |
| N+1 心率查询 | 逐条查询改为批量取样后按训练分桶 |
| dailyLoad 重复累加 | 防止 `aggregateDay` 多次调用叠加 activityLoad |
| Wiki 基线 nil 字段 | baseline markdown 支持完整 round-trip 解析 |
| 信任度反向 | 关键信号缺失时 Today confidence 降为 `.low` |
| Reps 解析错误 | 训练模板 "3x8-12" 解析目标次数 8 而非组数 3 |
| TrainingDay 解码崩溃 | 兼容旧序列化数据缺字段 |
| 手记伪相关 | 提高最低样本门槛，避免 2 天标签出关联 |

## 8. 测试

- 测试套件全部通过（100% pass rate）
- 覆盖 ScoringEngineTests、PersistenceFoundationTests、ContextBuilderTests、WorkoutAggregationTests
- 每次功能变更后运行完整 simulator 测试
