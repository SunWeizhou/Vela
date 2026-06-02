# TECH_ARCHITECTURE.md
# Project Vela — Technical Architecture

> Updated: 2026-06-02
> This document reflects the current build. Product context: `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

## 0. 当前技术状态

截至 2026-06-02:

- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug` succeeds (100% pass rate).
- 真机 iPhone 16 Pro 可通过 `devicectl` 构建、安装和启动。
- 项目包含 HealthKit、SwiftData、评分引擎、AI Agent、Wiki、Training Intelligence、Biology、食物分析、通知等模块。
- App shell 使用 Apple Design System + Bevel Parity 视觉体系：`VelaTheme` 设计令牌、`VelaDesignSystem` 复用组件、毛玻璃胶囊底栏、白卡驾驶舱。
- **VelaBackend** (Vapor 4) 提供 Coach chat API、Today Plan、Training Adaptations、Memory、Insights Evidence 等路由。
- **Training Intelligence v3** 模块已落地：模型层、分析服务、恢复联动适配器、计划关联、力量训练视图。
- 当前主分支：`codex/vela-3-training-intelligence`（已同步到 `main`）。

## 1. 技术总览

### 平台
- iOS App (SwiftUI + SwiftData)
- 后端: VelaBackend (Vapor 4 + Fluent + SQLite + JWT)

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
│  Today / Journal / Training /    │
│  Vitals / Coach / Settings       │
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
│  Training Intelligence Engines   │
│    (AdaptiveTraining, Decision,  │
│     Analytics, RecoveryAdapter)  │
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
│  VelaBackend (Vapor 4)           │
└──────────────────────────────────┘
```

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

### 4.3 Training Intelligence Module（Vela 3.0 新增）
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
HealthKitSyncEngine / HealthKitQueryService
    ↓
DailyHealthSummaryRecord (SwiftData 缓存)
    ↓
ScoreEngineFactory.buildSleepInput/buildRecoveryInput/...
    ↓
评分引擎 → MetricResult
    ↓
DashboardSummary (聚合)
    ↓
DashboardViewModel (@EnvironmentObject)
    ↓
UI Refresh
```

### 5.2 AI 上下文构建
```text
DashboardSummary + SwiftData 记录 (journal/foodLog/strengthWorkout)
    ↓
AIContextBuilder.build()
    ↓
AgentContextEnvelope (JSON)
    ↓
VelaBackend / DeepSeekProvider
    ↓
流式响应 → CoachChatPanel 渲染 (MarkdownText)
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

## 6. VelaBackend（Vapor 4）

服务端项目，提供 LLM 代理和轻量业务逻辑。

### 路由摘要
| 方法 | 路径 | LLM 调用 |
|------|------|---------|
| POST | `/api/auth/register`, `/login`, `/refresh` | 否 |
| POST | `/api/coach/chat` | Claude API + Tool Use |
| GET | `/api/today/plan` | Claude JSON |
| GET | `/api/training/adaptations` | Claude JSON |
| POST | `/api/insights/evidence` | Claude JSON |
| GET/PUT | `/api/memory/*` | 读写 DB |
| GET | `/api/data-coverage` | 纯计算 |

### HealthContext 边界
iOS 端只发送结构化摘要 `HealthContext`，原始 HealthKit 数据永不离设备。

## 7. 技术风险

| 风险 | 缓解 |
|------|------|
| HealthKit 数据不可用（VO₂Max/Body Fat 等） | Empty state + `--` + 数据覆盖度说明 |
| Stress/Biological Age 科学性 | 标注 Beta / proxy，引擎可替换 |
| LLM 输出不稳定 | 固定输出结构 / Prompt 约束 / JSON schema |
| SwiftData migration 风险 | 优先 JSON 字段扩展 + 可选字段 |
| pbxproj 冲突 | 不脚本修改 pbxproj，新文件手动 Xcode 注册 |

## 8. 测试

- 测试套件全部通过（100% pass rate）
- 覆盖 ScoringEngineTests、PersistenceFoundationTests、ContextBuilderTests、WorkoutAggregationTests
- 每次功能变更后运行完整 simulator 测试
