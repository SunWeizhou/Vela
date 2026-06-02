# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Vela 是一个 local-first 的 iOS 健康分析 App（SwiftUI + SwiftData + HealthKit），对标 Bevel Health。原始健康数据留在设备本地，只有结构化摘要发送给 LLM（通过 VelaBackend Vapor 服务，默认 Claude API，DeepSeek 也可用）。

- **Target**: `Vela`
- **Scheme**: `Vela`
- **Bundle ID**: `com.sunweizhou.Vela`
- **Deployment**: iPhone B1B2A1DB-2B5C-5C02-A222-B051240A22EA
- **Project**: `/Users/sunweizhou/Desktop/AI Project/Vela/Vela.xcodeproj`
- **Backend**: `/Users/sunweizhou/Desktop/AI Project/Vela/VelaBackend` (Vapor 4, SQLite)
- **Current Branch**: `codex/vela-3-training-intelligence` (also synced to `main`)
- **GitHub**: `https://github.com/SunWeizhou/Vela`

## 构建与推送

```bash
# 构建到手机（先确认手机已连接）
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
DEVICE="B1B2A1DB-2B5C-5C02-A222-B051240A22EA"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination "id=$DEVICE" -configuration Debug -allowProvisioningUpdates build

# 推送已构建产物到手机（只改 Swift 代码时可直接执行）
xcrun devicectl device install app --device "$DEVICE" \
  "/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app"

# 仅检查编译（不连手机）
xcodebuild -project Vela.xcodeproj -scheme Vela -sdk iphoneos -configuration Debug build
```

## 前端架构：Apple Design System + Bevel Parity（2026-06-02 更新）

所有视图使用统一的 VelaTheme 和 VelaDesignSystem 组件。

### 核心层

**VelaTheme** (`VelaApp/Core/Theme/VelaTheme.swift`) — 设计 Token 唯一入口：
- Surface: `bg`, `surface`, `cardBg`, `elevatedBg`, `groupedBg`
- Text: `fg`, `fg2`, `muted`, `meta`
- Accent: `accent` (#0071E3/#2997FF)
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

### Shell 与页面（5-Tab）

**VelaShell** (`VelaApp/Features/Minimal/VelaMinimalShell.swift`) — 根导航：
- 5 tabs: 今日 / 手记 / 训练 / 体征 / [+]
- `GlassTabBar` 底部导航，`+` 在最右侧
- 头像按钮 → Settings sheet，Coach 通过 Today 页按钮触发 sheet

| 页面 | 文件 | 数据源 |
|------|------|--------|
| TodayView | `VelaApp/Features/Minimal/VelaMinimalTodayView.swift` | `@EnvironmentObject dashboardVM: DashboardViewModel` |
| JournalView | `VelaApp/Features/Minimal/VelaMinimalCoachView.swift` | SwiftData `JournalEntryRecord` |
| TrainingView | `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift` | `@EnvironmentObject dashboardVM` + TrainingIntelligence 引擎 |
| VitalsView | `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift` | `@EnvironmentObject dashboardVM` |
| SettingsView | `VelaApp/Features/Minimal/VelaMinimalJournalView.swift` | `@AppStorage`（notifications/language/theme） |
| CoachView | `VelaApp/Features/Coach/CoachView.swift` | `@StateObject vm: CoachChatVM`（streaming） |
| MetricDetailView | `VelaApp/Features/Minimal/VelaMinimalComponents.swift` | 各页面 onTap 导航进入 |
| PlusActionSheet | `VelaApp/Features/SharedComponents/VelaQuickActionsSheet.swift` | 快速添加动作面板 |

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

## 数据流（Vela 3.0 当前架构）

```
HealthKit → HealthKitSyncEngine / HealthKitQueryService
  → SwiftData DailyHealthSummaryRecord（本地缓存）
  → ScoreEngineFactory → 各评分引擎计算 MetricResult
  → DashboardSummary（聚合体）→ DashboardViewModel
  → AIContextBuilder.build() → AgentContextEnvelope
  → VelaBackend（Vapor 4）→ Claude API / DeepSeek API → 流式返回
```

关键类型：
- `DashboardSummary`: 所有评分的聚合体（`Core/Utilities/DashboardSummary.swift`）
- `DashboardViewModel`: ObservableObject，持有 DashboardSummary，通过 `@EnvironmentObject` 注入页面
- `ScoreEngineFactory`: 统一创建各评分引擎的 Input struct，替代了旧的 `DashboardSummary.healthKit()` 静态方法
- `PreviewDataFactory`: 用真实引擎 + 固定种子生成预览 DashboardSummary
- `AIContextBuilder`: 构建发给 LLM 的结构化上下文包（AgentContextEnvelope）
- `DomainContextBuilders`: 各领域的上下文构建器（Sleep/Recovery/Strain/Stress/EnergyBank/StrengthTraining 等）
- `CoachChatVM`: Coach 对话的 ViewModel，管理 streaming 状态和消息历史

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

每个引擎实现 `ScoreEngine` protocol（定义在 `Scoring/ScoringCore.swift`）：

| 引擎 | 文件 | 功能 |
|------|------|------|
| `SleepScoreEngine` | `Scoring/Sleep/SleepScoreEngine.swift` | REM/Deep/Core 阶段分析 + 效率 |
| `RecoveryScoreEngine` | `Scoring/Recovery/RecoveryScoreEngine.swift` | HRV Z-score 28-day rolling + RHR 基线 |
| `StrainScoreEngine` | `Scoring/Strain/StrainScoreEngine.swift` | TRIMP-inspired + workout intensity |
| `StressIndexEngine` | `Scoring/Stress/StressIndexEngine.swift` | 4 因子: RHR↑, HRV↓, 睡眠负债, 负荷压力 |
| `EnergyBankEngine` | `Scoring/EnergyBank/EnergyBankEngine.swift` | Firstbeat charge/discharge + ATL(7d)/CTL(42d)/TSB |
| `HealthAgeTrendEngine` | `Scoring/HealthAge/HealthAgeTrendEngine.swift` | 生物年龄估算 |
| `BiologicalAgeEngine` | `Scoring/Biology/BiologicalAgeEngine.swift` | PhenoAge 临床化验模式 |
| `AdaptiveTrainingEngine` | `Scoring/Training/AdaptiveTrainingEngine.swift` | 基于 readiness 的训练日调整 |
| `TrainingDecisionEngine` | `Scoring/Training/TrainingDecisionEngine.swift` | DashboardSummary → TrainingDecision |
| `BodyInterpreterEngine` | `Scoring/BodyInterpreter/BodyInterpreterEngine.swift` | 身体状态综合解读 |
| `JournalCorrelationEngine` | `Scoring/Correlation/JournalCorrelationEngine.swift` | 行为-体征滞后关联分析 |
| `DailyPlanLimiterEngine` | `Scoring/DailyPlan/DailyPlanLimiterEngine.swift` | 训练限制因子判定 |
| `ScoreEngineFactory` | `Scoring/ScoreEngineFactory.swift` | 统一创建引擎 Input struct |

## VelaBackend（Vapor 4）

独立的服务端项目 (`VelaBackend/`)，使用 Fluent + SQLite + JWT。

### API 路由

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

- `LLMService`: actor，封装 Claude API 调用（`chat()` / `jsonCompletion()`），含 3 个 Tool Definition
- `PromptService`: 5 套中文 Prompt 模板（coach/todayInsight/trainingAdaptation/evidenceChain/memoryPattern）
- `JWTService`: Access Token 15min / Refresh Token 7d

### HealthContext 边界

iOS 端只发摘要 `HealthContext`，原始 HealthKit 数据永不离设备。所有 AI prompt 通过 `PromptService.formatHealthContext()` 注入数据。

## AI 模块（VelaApp/AI/）

| 子模块 | 文件 | 职责 |
|--------|------|------|
| Context | `AIContextBuilder.swift` | 构建 AgentContextEnvelope（发给 LLM 的结构化上下文） |
| Context | `DomainContextBuilders.swift` | 各领域上下文构建器 |
| Context | `WikiFileService.swift` | 用户 Wiki 文件读写 |
| Models | `AgentContextSchema.swift` | AgentContextEnvelope 定义 |
| Models | `TypedContextSchema.swift` | 强类型上下文 schema |
| Provider | `DeepSeekProvider.swift` | DeepSeek API streaming（60ms throttle） |
| Provider | `LLMProvider.swift` | LLM Provider 协议 |
| Provider | `WebSearchService.swift` | Web 搜索能力 |
| Agent | `AgentLoop.swift`, `AgentTool.swift` | Agent 工具调用循环 |
| Agent | `ToolFactory.swift` | Tool 工厂注册 |
| Agent | `FoodPhotoAnalyzer.swift` | Kimi Vision 食物照片识别 |
| Proactive | `PersonalResponseInsightService.swift` | 个人反应洞察 + 周报 |
| Proactive | `ProactiveInsightService.swift` | 主动洞察服务 |
| Proactive | `MorningBriefScheduler.swift` | 晨间简报 |
| Proactive | `EveningWikiSyncAgent.swift` | 夜间 Wiki 同步 |
| Memory | `MemoryLedger.swift`, `MemoryModels.swift` | 记忆提议与确认账本 |
| Reports | `ReportGenerator.swift` | AI 报告生成 |

## 注意事项

- **🔥 [CRITICAL] 永久前端视觉标准 (Bevel Parity)**: 2026-05-30 实现的 Bevel 视觉体系（暖白色 `#F5F3F0` 画布、白卡驾驶舱、并排三环仪表、压力虚线仪、格栅电池条、生物年龄大刻度盘、Biomarker Sparkline 平滑小趋势图及悬浮毛玻璃胶囊底栏）是项目的**最终前端标准**。未来的开发和智能代理只能**往里增加内容**（如完善按钮动作、接入详情页、丰富数据字段），**绝不能大改其整体视觉风格与结构**。
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
- Coach streaming 使用 60ms throttle（`DeepSeekProvider`），防止 UI 闪烁
- Coach 键盘交互：通过 `NotificationCenter` 监听 `keyboardWillShow`/`keyboardWillHide`，使用 `isKeyboardVisible` 状态控制底部 padding
- 根目录的 `Vela*.swift` 和 `VelaApple*.swift` 文件是 Stitch 设计参考，实际代码在 `VelaApp/` 中
- **测试**: `xcodebuild test` 测试全部通过（100% pass rate）
