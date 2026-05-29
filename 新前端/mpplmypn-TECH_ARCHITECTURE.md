# TECH_ARCHITECTURE.md
# Project Vela — Technical Architecture

> Updated: 2026-05-25  
> This document reflects the current build, not only the original MVP architecture. Product context: `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

## 0. 当前技术状态

Verified on 2026-05-25:

- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug` succeeds.
- The connected iPhone 16 Pro can build, install, and launch current Vela builds through `devicectl`.
- The project contains production-shaped modules for HealthKit, SwiftData, scoring, AI, proactive agents, Wiki, training, biology, food photo analysis, notifications, and settings.
- The app shell now targets a Bevel-like adaptive UI: global `VelaTheme` tokens, `VelaBackground`, shared card modifiers, `DetailScreenScaffold`, glass bottom navigation, and Home/Journaling/Fitness/Vitals/Intelligence entry points are aligned around adaptive light/dark material surfaces.
- The main architecture risk is no longer missing files; it is keeping the many modules coherent and auditably connected.

## 1. 技术总览

### 平台
- iOS App
- Swift
- SwiftUI

### 系统能力
- HealthKit
- SwiftData
- Charts / Swift Charts
- Keychain
- Local file storage for Wiki docs

### AI
- DeepSeek-V4 API
- Provider abstraction
- Streaming Coach chat
- Agent tools
- Web search helper
- Food photo analyzer
- Proactive agents
- User Wiki memory

### 后端
- 第一阶段无自建后端；
- Health data, Wiki, reports, journal, biomarkers, and training records remain local;
- LLM calls may send structured summaries, selected Wiki text, and user prompts to the configured provider.

---

## 2. 架构风格

推荐采用：
- Feature-based modular architecture；
- Service / Repository / Engine 分层；
- ViewModel 驱动 UI；
- Domain Model 与 HealthKit 原始对象隔离。

---

## 3. 高层架构

```text
┌─────────────────────────────┐
│         SwiftUI Views       │
│ Home Journal Fitness Vitals │
│ Intelligence Settings       │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│          ViewModels         │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│        Application Layer    │
│ DailySummaryUseCase         │
│ MorningBriefScheduler       │
│ EveningWikiSyncAgent        │
│ NotificationService         │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│          Domain Layer       │
│ Score Engines               │
│ Health Models               │
│ Agent Context Builder       │
│ Personal Baselines          │
│ Training Plan Logic         │
└──────────────┬──────────────┘
               │
┌──────────────▼──────────────┐
│      Infrastructure Layer   │
│ HealthKit Services           │
│ SwiftData Repositories      │
│ DeepSeek Provider            │
│ Kimi Vision Provider         │
│ Keychain Service             │
│ Wiki File Service            │
│ Web Search Service           │
│ Food Photo Analyzer          │
└─────────────────────────────┘
```

---

## 4. 模块拆分

### 4.1 Health Module
职责：
- 权限请求；
- HealthKit 查询；
- HealthKit Sample → Domain Model 映射；
- 数据聚合。

#### Services
- HealthAuthorizationService
- SleepHealthQueryService
- CardioHealthQueryService
- WorkoutHealthQueryService
- BodyMetricsHealthQueryService

---

### 4.2 Scoring Module
职责：
- 计算 Sleep Score；
- 计算 Recovery；
- 计算 Strain；
- 计算 Stress；
- 计算 Energy Bank；
- 计算 Health Age Trend。
- 计算 Biological Age；
- 计算个人生理基线；
- 输出原因、confidence、可解释 metrics。

#### Interfaces
```swift
protocol ScoreEngine<Input, Output> {
    associatedtype Input
    associatedtype Output
    func calculate(from input: Input) -> Output
}
```

---

### 4.3 AI Module
职责：
- LLM Provider；
- Prompt 构建；
- Agent 上下文组装；
- 报告生成；
- 报告保存。
- Coach session 管理；
- tool calling / tool prompt context；
- Wiki action parsing；
- proactive check-ins；
- artifact 生成路线。

#### Components
- DeepSeekProvider
- AgentContextBuilder
- ReportGenerator
- AIReportRepository
- CoachChatVM / CoachChatPanel
- AgentTool / WebSearchTool / UpdateWikiTool / GenerateTrainingPlanTool / FoodLogTool
- MorningBriefScheduler
- EveningWikiSyncAgent
- ProactiveInsightService
- FoodPhotoAnalyzer
- WebSearchService

---

### 4.4 Persistence Module
职责：
- SwiftData 管理；
- 日摘要缓存；
- 报告存储；
- Journal 存储；
- 健康评分持久化。

---

### 4.5 Wiki Module
职责：
- 加载 agent.md；
- 加载 user_wiki 下的 Markdown；
- 为 Agent 构造长期上下文；
- 支持 AI 维护和 App 内编辑；
- 维护 `baselines.md`；
- 拒绝未知 Wiki 文件写入；
- 合并写入时去重，降低重复记忆污染。

### 4.6 Training Module
职责：
- 展示今日 Strain 与训练负荷；
- 管理训练计划和训练日历；
- 后续承接 AI 生成的 Training Plan / Strength Template；
- 将 Recovery、Strain、Energy Bank、Wiki 目标转成可执行日历。

### 4.7 Biology Module
职责：
- Biological Age 计算；
- 可穿戴指标贡献分析；
- 手动血检 biomarker 录入；
- 后续扩展 Health Records 文档导入、解析、可信度与新鲜度。

### 4.8 Nutrition Module
职责：
- 食物照片识别，使用 Kimi / Moonshot 视觉模型；
- 估算 calories/macros/fiber；
- 将识别结果保存为 `FoodLogRecord`，同时写 Journal 以保留行为相关性；
- 在 AIContextBuilder 的 `nutrition` block 中暴露最近结构化餐食，让 Coach 后续建议能引用真实饮食历史；
- 当前 Journal 页面展示最近 Nutrition 记录；confidence、portion editing、nutrition history 暂缓产品化，当前优先级转向 Home / Intelligence / Training / Biology。

### 4.9 Home Intelligence Module
职责：
- 将评分引擎输出转成首页可消费的每日决策摘要；
- `DailyPlanEngine` 根据 Recovery、Strain、Energy、Stress、Sleep 和 limiter 生成今日计划；
- `HomeReadinessBrief` 根据 `DashboardSummary` 与 `DailyPlanRecommendation` 输出 `statusLabel`、`why`、`nextAction`、`coachQuestion` 和 `accent`；
- Home 的第一屏应从 dashboard complexity 收敛为：readiness cockpit、Stress/Energy、Nutrition summary、proactive insights；
- 用户点击 Readiness Brief 或 Metric AI action 时，通过 `VelaAppState.routeToCoach(question:)` 写入预填问题并打开 Intelligence hub。

### 4.10 UI Shell / Bevel-like Design System
职责：
- `VelaTheme` 提供默认浅色背景、白色浮层、黑色文字、柔和阴影和健康语义色；
- `VelaBackground`、`cardSurface()`、`heroCardSurface(accent:)`、`DateNavigationBar` 和 `DetailScreenScaffold` 统一详情页外壳；
- `VelaRootView` 负责 Bevel-like Tab IA：Home、Journal、Fitness、Vitals 在主玻璃胶囊中，`+` 作为单独玻璃圆形扩展入口打开 Intelligence；
- Home 保留专门的 `VelaBevelHomeStyle` 和三环首屏组件，用来快速逼近 Bevel 首页视觉；
- `VelaIntelligenceMarquee` 作为详情页 AI 行动入口的共享组件，用来表达“正在基于最新数据分析”的状态；
- 其他页面必须优先复用共享外壳，而不是继续各自维护深色卡片、白色低透明边框或孤立背景。

---

## 5. 数据流

### 5.1 健康数据刷新
```text
HealthKit Query
    ↓
Domain Model Mapping
    ↓
Daily / Weekly Aggregation
    ↓
Scoring Engines
    ↓
SwiftData Persist
    ↓
UI Refresh
```

### 5.2 AI 报告生成
```text
User Action or Report Trigger
    ↓
Load Computed Health Summaries
    ↓
Load Journal
    ↓
Load User Wiki
    ↓
Build Structured Agent Context
    ↓
DeepSeek API
    ↓
Parse Response
    ↓
Persist AIReport
    ↓
Render UI
```

### 5.3 Agent Wiki 同步
```text
Daily health summary + recent reports + journal + current Wiki
    ↓
EveningWikiSyncAgent prompt
    ↓
DeepSeek response with [ACTION:update_wiki]
    ↓
AgentActionParser
    ↓
WikiFileService.updateSection(mode: merge)
    ↓
AIReport audit record
```

### 5.4 Full-Strength Intelligence Flow
```text
User question / proactive trigger / scheduled check-in
    ↓
AIContextBuilder
    ↓
Tool selection: search, update_wiki, food_log, training_plan, artifact
    ↓
Structured response + optional artifact payload
    ↓
SwiftData persistence
    ↓
UI card, notification, or Wiki diff
```

### 5.5 Home Daily Loop
```text
HealthKit summaries + scoring results
    ↓
DashboardSummary
    ↓
DailyPlanEngine.recommendation
    ↓
HomeReadinessBrief.make
    ↓
Home: status / why / next action
    ↓
Optional routeToCoach(question)
```

---

## 6. 核心数据模型建议

### 6.1 DailyHealthSummary
```swift
@Model
final class DailyHealthSummary {
    var date: Date
    var sleepScore: Double?
    var recoveryScore: Double?
    var strainScore: Double?
    var stressIndex: Double?
    var morningEnergy: Double?
    var currentEnergy: Double?
}
```

### 6.2 SleepSummary
```swift
@Model
final class SleepSummary {
    var date: Date
    var totalSleepMinutes: Int
    var bedtime: Date?
    var wakeTime: Date?
    var deepMinutes: Int?
    var remMinutes: Int?
    var coreMinutes: Int?
    var awakeMinutes: Int?
    var sleepScore: Double?
}
```

### 6.3 RecoverySummary
```swift
@Model
final class RecoverySummary {
    var date: Date
    var score: Double
    var band: String
    var hrvStatus: String
    var restingHeartRateStatus: String
    var sleepContribution: Double
    var priorStrainContribution: Double
}
```

### 6.4 StrainSummary
```swift
@Model
final class StrainSummary {
    var date: Date
    var score: Double
    var activeEnergy: Double
    var exerciseMinutes: Double
    var workoutCount: Int
    var targetBand: String
}
```

### 6.5 JournalEntry
```swift
@Model
final class JournalEntry {
    var createdAt: Date
    var tags: [String]
    var note: String
}
```

### 6.6 AIReport
```swift
@Model
final class AIReport {
    var createdAt: Date
    var type: String
    var title: String
    var markdownContent: String
    var serializedContextSnapshot: String
}
```

---

## 7. HealthKit 读取建议

### 7.1 Sleep
HealthKit 支持 sleep analysis categories 和睡眠阶段相关值，可直接支撑 Sleep 页面的核心数据读取。

### 7.2 Sleep Chart
SleepChartKit 可作为 Sleep 页面的高价值复用候选。

---

## 8. UI 技术建议

### 推荐
- SwiftUI；
- Swift Charts；
- 自定义卡片组件；
- Design Tokens；
- Stitch 输出转 SwiftUI。

### 组件库建议
- ScoreRingView
- MetricTrendChart
- SleepTimelineView
- HealthSummaryCard
- AIInsightCard
- TagInputView
- MarkdownReportView

---

## 9. LLM 接入架构

### 9.1 Provider 抽象
```swift
protocol LLMProvider {
    func generate(
        systemPrompt: String,
        userPrompt: String,
        context: String
    ) async throws -> String
}
```

### 9.2 DeepSeek Provider
- Endpoint 配置；
- Model 配置；
- API Key 注入；
- 请求超时；
- 错误处理；
- Token 限制预估；
- 日志脱敏。

### 9.3 Kimi Vision Provider
- Food photo analysis uses `FoodPhotoAnalyzer` rather than `DeepSeekProvider`.
- Endpoint: `https://api.moonshot.cn/v1/chat/completions`.
- Default model: `kimi-k2.6`.
- Keychain account: `kimi_api_key`.
- Payload uses OpenAI-compatible `message.content` array with `text` and `image_url` parts.
- The image recognition result is converted into structured nutrition markdown/plain text, inserted into the Coach flow, saved as `FoodLogRecord`, and logged to Journal with `food` / `meal` tags.

---

## 10. 本地安全

### 必须
- API Key 不写死；
- API Key 存 Keychain；
- Prompt 与报告不记录敏感原始明文日志；
- 健康数据不外传至自有服务器；
- 仅将必要摘要发给 LLM API。

---

## 11. Stitch 协作方式

### 产品文档 → Stitch
输入：
- 页面目标；
- 页面区块；
- 卡片内容；
- 风格关键词；
- 参考产品 Bevel。

### Stitch → 开发
输出：
- 页面布局；
- 卡片风格；
- 组件层级；
- 视觉细节；
- 适合 SwiftUI 的界面方案。

---

## 12. 技术风险

### 12.1 HealthKit 数据可用性不一致
某些指标可能不存在：
- VO₂ Max；
- Body Fat；
- Lean Body Mass；
- 睡眠呼吸频率。

解决：
- 全面支持 empty state；
- 指标缺失不阻断主流程。

### 12.2 Stress / Biological Age 的科学性
解决：
- 标注 Beta；
- 强调 proxy；
- 让评分引擎可替换。

### 12.3 LLM 输出不稳定
解决：
- 固定输出结构；
- Prompt 约束；
- 报告结果存储；
- 后续可加 JSON schema / structured output。

---

## 13. 第一阶段技术决策总结

| 领域 | 决策 |
|---|---|
| 平台 | iOS |
| UI | SwiftUI |
| 数据 | HealthKit |
| 存储 | SwiftData |
| API Key | Keychain |
| AI | DeepSeek-V4 Provider |
| 后端 | 无 |
| 设计 | Stitch 生成 UI 原型 |
| Sleep Chart | 优先评估 SleepChartKit |
