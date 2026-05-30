# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

Vela 是一个 local-first 的 iOS 健康分析 App（SwiftUI + SwiftData + HealthKit），对标 Bevel Health。原始健康数据留在设备本地，只有结构化摘要发送给 DeepSeek LLM（通过 VelaBackend Vapor 服务，Claude API 也可用）。

- **Target**: `Vela`
- **Scheme**: `Vela`
- **Bundle ID**: `com.sunweizhou.Vela`
- **Deployment**: iPhone 00008140-00164DE022C3801C
- **Project**: `/Users/sunweizhou/Desktop/AI Project/Vela/Vela.xcodeproj`
- **Backend**: `/Users/sunweizhou/Desktop/AI Project/Vela/VelaBackend` (Vapor 4, SQLite)

## 构建与推送

```bash
# 构建到手机（先确认手机已连接）
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
DEVICE="00008140-00164DE022C3801C"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination "id=$DEVICE" -configuration Debug -allowProvisioningUpdates build

# 推送已构建产物到手机（只改 Swift 代码时可直接执行）
xcrun devicectl device install app --device "$DEVICE" \
  "/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app"

# 仅检查编译（不连手机）
xcodebuild -project Vela.xcodeproj -scheme Vela -sdk iphoneos -configuration Debug build
```

## 前端架构：Apple Design System（2026-05-29 更新）

所有视图已迁移到新的 Apple Design System，以根目录下 11 个新 Swift 文件为准。

### 核心层

**VelaTheme** (`VelaApp/Core/Theme/VelaTheme.swift`) — 设计 Token 唯一入口：
- Surface: `bg`, `surface`, `cardBg`, `elevatedBg`, `groupedBg`
- Text: `fg`, `fg2`, `muted`, `meta`
- Accent: `accent` (#0071E3/#2997FF)
- Semantic: `strainColor`, `recoveryColor`, `sleepColor`, `stressColor`, `energyColor`
- Typography: `largeTitle()`, `title1()`-`title3()`, `headline()`, `body()`, `callout()`, `subheadline()`, `footnote()`, `caption1()`-`caption2()`
- Spacing: `space1`-`space12` (4-48px, 8px grid), `pagePadding` (20px), `cardGap` (14px)
- 向后兼容别名: `onSurface` → `fg`, `outline` → `borderSoft`, `recovery` → `recoveryColor`, 等

**VelaDesignSystem** (`VelaApp/Core/DesignSystem/VelaDesignSystem.swift`) — 复用组件 + View Modifiers：
- `ScoreRing`, `VitalCard`, `InfoCard`, `InsightCard`, `EmptyStateCard`
- `GlassTabBar`, `StatusCapsule`, `DayPill`, `MessageBubble`, `TypingIndicator`
- `SettingsRow`, `ToggleRow`, `EvidenceStep`, `DataFreshnessBar`
- `SettingsGroup<Content>`, `QuickEntryButton`, `WorkoutCard`, `TagChip`, `PlusAction`
- `.cardSurface()`, `.heroCardSurface()`, `.glassEffect()`, `.sectionSpacing()`
- Button styles: `.cardPress`, `.tabItem`, `.plusButton`
- 向后兼容桩: `VelaHeroSurface`, `VelaMetricPill`, `VelaGlassCard`, `VelaMemoryProposalCard`, `VelaEmptyState`, `VelaStatusBadge`, `VelaInlineAlert`, `VelaDataQualityRow`, `ImagePicker`

**VelaLoc** (`VelaTheme.swift` 内) — 中文默认本地化枚举，所有属性为 computed 以避免 Sendable 警告。

### Shell 与页面（5-Tab）

**VelaShell** (`VelaApp/Features/Minimal/VelaMinimalShell.swift`) — 根导航：
- 5 tabs: 今日 / 手记 / 训练 / 体征 / [+]
- `GlassTabBar` 底部导航，`+` 在最右侧
- 头像按钮 → Settings sheet，Coach 通过 Today 页按钮触发 sheet

| 页面 | 文件 | 数据源 |
|------|------|--------|
| TodayView | `VelaApp/Features/Minimal/VelaMinimalTodayView.swift` | `@EnvironmentObject dashboardVM: DashboardViewModel` |
| JournalView | `VelaApp/Features/Minimal/VelaMinimalCoachView.swift` | SwiftData `JournalEntryRecord`（待接入） |
| TrainingView | `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift` | `@EnvironmentObject dashboardVM` + `DailyPlanEngine` |
| VitalsView | `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift` | `@EnvironmentObject dashboardVM` |
| SettingsView | `VelaApp/Features/Minimal/VelaMinimalJournalView.swift` | `@AppStorage`（notifications/language/theme） |
| CoachView | `VelaApp/Features/Coach/CoachView.swift` | `@StateObject vm: CoachChatVM`（DeepSeek streaming） |
| MetricDetailView | `VelaApp/Features/Minimal/VelaMinimalComponents.swift` | 各页面 onTap 导航进入 |
| PlusActionSheet | `VelaApp/Features/SharedComponents/VelaQuickActionsSheet.swift` | 快速添加动作面板 |

### 关键：文件映射（pbxproj 未变）

由于直接修改 pbxproj 会损坏项目，新文件通过**覆盖现有文件内容**的方式放入：
- `VelaShell.swift` → 覆盖 `VelaMinimalShell.swift`
- `VelaJournalView.swift` → 覆盖 `VelaMinimalCoachView.swift`
- `VelaMetricDetailView.swift` → 覆盖 `VelaMinimalComponents.swift`
- `VelaSettingsView.swift` → 覆盖 `VelaMinimalJournalView.swift`
- `VelaPlusActionSheet.swift` → 覆盖 `VelaQuickActionsSheet.swift`

**绝不通过脚本修改 pbxproj**。新增 Swift 文件时，覆盖一个已存在于 pbxproj 但不再使用的旧文件，或让用户在 Xcode 中手动添加。

### 数据注入模式

```swift
@EnvironmentObject private var dashboardVM: DashboardViewModel  // 健康评分
@EnvironmentObject private var services: VelaServices            // AI Provider 等
@Environment(\.modelContext) private var modelContext            // SwiftData
@StateObject private var vm = CoachChatVM()                      // Coach 专用 VM
```

## 数据流

```
HealthKit → HealthKitQueryService → DailyHealthContext → DashboardSummary.healthKit()
  → 评分引擎 (Sleep/Recovery/Strain/Stress/Energy) → DashboardViewModel
  → AIContextBuilder.build() → AgentContextEnvelope → LLM Prompt (DeepSeek)
```

关键类型：
- `DashboardSummary`: 所有评分的聚合体（`Core/Utilities/DashboardSummary.swift`）
- `DashboardViewModel`: ObservableObject，持有 DashboardSummary，通过 `@EnvironmentObject` 注入页面
- `DailyPlanEngine.recommendation(for: dashboard)` → 今日训练计划
- `CoachChatVM`: Coach 对话的 ViewModel，管理 streaming 状态和消息历史

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

## 评分引擎

每个引擎实现 `ScoreEngine` protocol：
- `SleepScoreEngine` — REM/Deep/Core 阶段分析 + 效率
- `RecoveryScoreEngine` — HRV Z-score 28-day rolling + RHR 基线
- `StrainScoreEngine` — TRIMP-inspired + workout intensity
- `StressIndexEngine` — 4 因子: RHR↑, HRV↓, 睡眠负债, 负荷压力
- `EnergyBankEngine` — Firstbeat charge/discharge + ATL(7d)/CTL(42d)/TSB
- `HealthAgeTrendEngine` — 生物年龄估算
- `ScoreEngineFactory` — 统一创建评分输入

## 注意事项

- **🔥 [CRITICAL] 永久前端视觉标准 (Bevel Parity)**: 2026-05-30 实现的 Bevel 视觉体系（暖白色 `#F5F3F0` 画布、白卡驾驶舱、并排三环仪表、压力虚线仪、格栅电池条、生物年龄大刻度盘、Biomarker Sparkline 平滑小趋势图及悬浮毛玻璃胶囊底栏）是项目的**最终前端标准**。未来的开发和智能代理只能**往里增加内容**（如完善按钮动作、接入详情页、丰富数据字段），**绝不能大改其整体视觉风格与结构**。
- **📁 [Minimal Shell 文件映射说明]**: 为了在不损坏 Xcode `.pbxproj` 索引引用的前提下实现最清晰的文件逻辑，前端文件内容与 Tab 映射如下：
    - `VelaMinimalShell.swift` ➡️ 底栏 Tab 胶囊容器 `VelaShell`
    - `VelaMinimalTodayView.swift` ➡️ Tab 1 今日主页 `VelaTodayView`
    - `VelaMinimalJournalView.swift` ➡️ Tab 2 习惯手记 `VelaJournalView`
    - `VelaMinimalFitnessView.swift` ➡️ Tab 3 训练主页 `VelaTrainingView`
    - `VelaMinimalVitalsView.swift` ➡️ Tab 4 体征主页 `VelaVitalsView`
    - `VelaMinimalCoachView.swift` ➡️ “我的”设置页面 `VelaSettingsView`
    - `VelaMinimalComponents.swift` ➡️ 耗力/睡眠/压力等全量指标高保真详情页 `VelaMetricDetailView`
- 不直接修改 pbxproj，用文件覆盖方式添加新代码
- 新前端代码中 `body` 不能用作存储属性名（与 SwiftUI `body` 冲突），用 `bodyText` 替代
- LocalizedStringKey 在 Swift 6 下有 Sendable 警告，用 computed property 而非 stored let
- 设计 Token 使用新名称（`fg`/`bg`/`cardBg`），旧名称作为向后兼容别名保留
- Coach streaming 使用 60ms throttle（`DeepSeekProvider`），防止 UI 闪烁
- 根目录的 `Vela*.swift` 和 `VelaApple*.swift` 文件是 Stitch 设计参考，实际代码在 `VelaApp/` 中
