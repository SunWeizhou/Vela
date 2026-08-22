# Vela Technical Architecture Specification

> Status: Canonical
> Last verified: 2026-08-21
> Scope: Vela 当前工程的技术架构、模块分层、数据流管道、持久化模型与状态管理规范
> Does not define: 业务需求与产品优先级（见 [docs/PRD.md](PRD.md)）、领域术语定义（见 [../CONTEXT.md](../CONTEXT.md)）

---

## 1. 架构总览与技术栈

- **平台**: iOS 17+ (SwiftUI + SwiftData + HealthKit)
- **UI 风格**: Apple Native Design System + Rhythm 视觉 Tokens（`VelaTheme`）
- **数据流**: 单向数据流（Unidirectional Data Flow），本地确定性计算优先，AI 作为解释与提案增强
- **运行时 AI 连接**: iOS 端直连 DeepSeek API (`api.deepseek.com`，Keychain 存储 Key)，可选 Kimi Vision 识别食物照片；`VelaBackend` (Vapor 4) 仅作为保留的实验服务，当前未启用。

---

## 2. 端到端数据流管道（Canonical Pipeline）

```text
Apple HealthKit (Raw Samples)
      ↓
HealthKitSyncEngine (2-Pass: Raw Fetch → Snapshot Normalization)
      ↓
Daily Health Snapshot (SwiftData: DailyHealthSummaryRecord)
      ↓
Daily Health Computation (ScoreEngineFactory: 单一确定性计算入口)
      ↓
Scored Health Evidence (0–100 标准化: Recovery, Sleep, Strain, Stress, Energy)
      ↓
HealthTrendEngine (多尺度趋势计算: 7d, 30d, 6m, 3y)
      ↓
Personal Health Brief (全局权威认知与简报投影)
      ↓
DailyIntelligenceAssemblyModule (共享确定性 Seam：Body State → Brief → Training Decision)
      ├───────────────────────┬───────────────────────┬───────────────────────┐
      ↓                       ↓                       ↓                       ↓
Tab 0: Today            Tab 1: Trends           Tab 2: Vela             Tab 3: Training
(今日状态与地平线)      (多尺度趋势与指标)       (Agent Fact Snapshot    (TrainingDecisionKernel
                                                & 流式对话主场)          & 局部肌群负荷)
```

---

## 3. 分层规范与核心组件

### 3.1 数据采集与日快照层（Evidence Layer）

| 规范类型 | 生产者 (Producer) | 消费者 (Consumer) | 缺失规则 | 持久化位置 | 状态 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`DailyHealthSnapshot`** | `HealthKitSyncEngine` / `QueryService` | `DailyHealthComputation` | 标记缺失字段，不伪造默认值 | SwiftData `DailyHealthSummaryRecord` | **Implemented** |
| **`WorkoutEvent`** | HealthKit / Apple Watch | `WorkoutAggregationService` / 训练页 | 无运动记录时为空数组 | SwiftData `WorkoutEventRecord` | **Implemented** |
| **`LivedState` / Check-in** | 用户每日主观自评 | `BodyStateKernel` / `CoachContext` | 可选跳过；未填不代表无压力/无酸痛 | 当前由 `JournalEntryRecord` / 行为标签推断；`DailyCheckInRecord` 尚未实现 | **Partial / Planned** |

### 3.2 每日评分与趋势计算层（Computation Layer）

| 规范类型 | 算法引擎 / 逻辑 | 生产者 | 消费者 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| **`RecoveryScore`** | HRV log-SDNN MAD Z-score (35%) + RHR Z (25%) + Sleep (25%) + Load (15%) | `RecoveryScoreEngine` | `DashboardSummary`, `PersonalHealthBrief` | **Implemented** |
| **`SleepScore`** | Duration (0-50) + Consistency (0-30) + Interruption (0-20) | `SleepScoreEngine` | `DashboardSummary`, `PersonalHealthBrief` | **Implemented** |
| **`StrainScore`** | Lucia/Banister TRIMP + Session RPE → ATL/CTL/ACWR | `StrainScoreEngine` | `DashboardSummary`, `PersonalHealthBrief` | **Implemented** |
| **`StressIndex`** | 6 因子加权: RHR↑, HRV↓, RR↑, Temp, SleepDebt, Load | `StressIndexEngine` | `DashboardSummary`, `PersonalHealthBrief` | **Implemented** |
| **`EnergyBank`** | Firstbeat-inspired 充放电模型 + TSB | `EnergyBankEngine` | `DashboardSummary`, `PersonalHealthBrief` | **Implemented** |
| **`HealthTrendFinding`** | 7d/30d/6m/3y 多尺度统计基线对比与百分位定位 | `HealthTrendEngine` | `VelaTrendsView`, `AgentContextBuilder` | **Implemented** |

### 3.3 认知投影与决策层（Cognitive & Decision Layer）

| 规范类型 | 职责描述 | 生产者 | 消费者 | 状态 |
| :--- | :--- | :--- | :--- | :--- |
| **`PersonalHealthBrief`** | 汇总身体状态、显著变化、驱动因素与行动建议的权威对象 | `HealthTrendEngine` / `BriefBuilder` | Today, Trends, Vela, Training | **Accepted Target** (持续收敛各视图消费路径) |
| **`BodyState`** | 当前身体恢复、负荷与压力承受力的保守解释 | `BodyStateKernel` | `TrainingDecisionKernel`, `AIContextBuilder` | **Implemented** |
| **`TrainingDecision`** | 今日训练定调（keep / reduce / swap / rest）+ 3 大执行边界 | `TrainingDecisionKernel` | Training Tab, Today Hero | **Implemented** |
| **`DailyOperatingPlan`** | 跨域日常行动计划（1 个主行动 + 最多 2 个辅助行动） | `DailyOperatingPlanCoordinator` | Today View, Coach View | **Implemented** |
| **`AgentFactSnapshot`** | 供给 LLM 的无时区偏差、确定性结构化事实快照 | `AIContextBuilder` | `CoachChatVM`, `ReportGenerator`, `ToolExecutionContext` | **Implemented** |

Coach 的 non-casual 请求由 `CoachContextAssembler.buildRequestContext` 一次
构造 `AgentFactSnapshot`，同时渲染消息并将快照透传给
`ToolExecutionContext` → `ToolRegistry` → `AgentLoop`。`HealthTrendTool` 只从
该请求快照（兼容时为 `DashboardSummary.healthTrends`）读取 canonical
`HealthTrendFinding`；SwiftData `DailyHealthSummaryRecord` 只提供用户明确
请求的逐日 points，不触发趋势重算。工具返回 snapshot 的
`context_hash`/`generated_at`/`as_of`，缺失快照时使用 JSON `null`，绝不以
消息 hash 冒充 canonical hash。当前 snapshot 只有 `generatedAt` 一个请求
时间字段，因此 `as_of` 明确映射同一值。Agent trace 以 `contextHashSource` 区分
`agent_fact_snapshot` 与兼容路径的 `message_content`。

### 3.4 Daily Intelligence Assembly Module

`DailyIntelligenceAssemblyModule` 是 Today/dashboard 日常认知装配的共享
Module。`DailySummaryUseCase` 与 `SecondaryDataAssembler` 是两个 Adapter，
都跨同一个 Seam，传入值类型事实及显式 `selectedDay`、`calendar` 与
`activeStatus`。Adapter 先用 wall-clock evaluation time 解析 selected-day
状态，再把显式状态交给纯 Module。

其 Interface 返回 `BodyState`、下游 `DailyTrainingDecision`，以及承载
canonical `PersonalHealthBrief`/趋势发现和兼容投影的 Dashboard。Implementation
是确定性纯计算：先建 Body State，再由 `HealthTrendEngine` 建 Brief，最后把
Brief 注入 `TrainingDecisionKernel`。持久化决策只有在 `bodyStateHash` 和
rotation title 均匹配时复用。HealthKit/SwiftData fetch、DTO 转换、保存、
Watch/计划副作用仍由 Adapter 保留。

这个 Seam 通过 deletion test：删除 Module 后，以上装配顺序、历史状态与
hash 校验必须重新散回两个调用方；因此 Module 具有实际 Leverage 与
Locality，而非 shallow pass-through。

`DailyOperatingPlanBuilder` 是这条链路下游的确定性 Implementation。
`DailyOperatingPlanPayload` schema v2 在保留训练决定、容量与 RPE Interface
的同时，持久化一个主行动和最多两个不同领域的辅助行动。Today、Training、
Vela 本机解释与 Agent facts 均通过这一个计划 Seam 消费结果；旧 schema
仍可由兼容 Adapter 读取，并在下一次刷新时迁移。计划提案保持独立状态，
只有用户在 Today 或 Training 明确采纳后才会跨入正式计划，拒绝或保存失败
不会静默改变其 Implementation。

---

## 4. 前端应用分层与视图映射

```text
VelaApp
├── Features/Minimal/
│   ├── VelaMinimalShell.swift        # 根 TabView 容器（Today / Trends / Vela / Training）
│   ├── VelaMinimalTodayView.swift    # Tab 0: 今日状态、地平线与核心决策
│   ├── VelaMinimalFitnessView.swift  # Tab 3: 训练决策、手表自动同步流与局部肌群图谱
│   └── TrainingHeroSection.swift     # 训练 Tab Hero、三日轮转与分析入口
├── Features/Trends/
│   └── VelaTrendsView.swift           # Tab 1: 多尺度趋势对比与指标图表
├── Features/Coach/
│   ├── CoachView.swift               # Tab 2: AI 分析工作台与流式对话主场
│   ├── CoachWelcomeWorkspace.swift   # 情境生理问候与动态分析提问气泡
│   └── WikiProfileView.swift         # 健康记忆档案（Wiki / Memory Ledger）
└── Features/Settings/
    ├── DataCoverageView.swift        # 数据覆盖与权限
    ├── TrustCenterView.swift         # 数据与 AI 信任设置
    └── BiologyView.swift             # 生理设置
```

---

## 5. 本地规则与 AI 的安全边界与交互协议

1. **确定性评分保护**：
   - 所有的 0–100 健康评分必须由本地 Swift 评分引擎计算；
   - LLM 严禁重新计算或篡改生理分数，只能读取并解释 `AgentFactSnapshot` 中的已有事实。
2. **计划修改需用户确认（User-confirmed Plan Proposals）**：
   - AI 可以基于自然语言对话生成 `Plan Proposal`；
   - 任何改写正式 `DailyOperatingPlanRecord` 的行为，必须经过 UI 交互由用户显式点击确认（Explicit Confirmation）。
3. **语言边界**：
   - AI 在解释体征变化时使用“关联观察”与“候选影响因素”，严禁向用户宣称确定的生理因果关系。
