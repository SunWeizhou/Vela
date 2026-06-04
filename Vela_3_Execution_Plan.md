# Vela 3.0 执行计划：从功能集合到主动式身体操作系统

> 文档类型：Implementation Plan  
> 目标版本：Vela 3.0 / Active Coach OS  
> 执行原则：先建立核心闭环，再扩展页面纵深；先把 AI 变成 artifact，再优化聊天；先做训练执行闭环，再做高级训练智能。

---

## 0. 总体执行策略

Vela 3.0 不建议采用“一次性全量重写”。推荐采用 **Strangler Fig Pattern**：保留当前可用模块，围绕新的信息架构逐步替换关键入口。

执行顺序：

```text
信息架构 → Design System → Onboarding → Today → Training Loop → Coach Artifact → Insights/Wiki → QA
```

核心判断：

- Today 是用户每天打开的理由。
- Training 是数据闭环的关键输入。
- Coach Artifact 是 AI 产品化的关键表达。
- Insights 和 Wiki 是长期信任与壁垒。

---

## 1. Phase 0：代码审查与迁移准备

### 1.1 目标

在动手前确认当前 repo 的实际结构、编译状态、关键模型和页面入口，避免盲目重构。

### 1.2 任务

1. 拉取最新 main 分支。  
2. 在 Xcode 中确认项目可编译。  
3. 跑现有测试。  
4. 梳理当前入口：App、Navigation、Tab、Home、Journal、Fitness、Vitals、AI、Training。  
5. 梳理当前 SwiftData models。  
6. 梳理 HealthKit query 和 DailyHealthSummary 数据结构。  
7. 梳理 AI ContextBuilder、PromptComposer、AgentActionParser、MemoryLedger。  
8. 输出 `docs/VELA_3_AUDIT.md`，记录当前可复用模块和需替换模块。

### 1.3 交付物

- `docs/VELA_3_AUDIT.md`
- 编译结果截图或日志
- 测试结果日志
- 当前模块依赖图

### 1.4 验收标准

- 不开始大规模改 UI 前，必须确认当前项目能编译。
- 必须知道哪些旧页面会被保留、迁移、废弃。

---

## 2. Phase 1：信息架构重构

### 2.1 目标

把当前功能模块从“数据/功能分区”改成“用户任务分区”。

### 2.2 新导航结构

建议新 Tab：

```text
Today | Training | Insights | Coach | Me
```

### 2.3 任务

1. 新建或重构根导航组件：`RootTabView` / `VelaMainNavigation`。  
2. 将原 Home 迁移为 Today。  
3. 将 Fitness + TrainingIntelligence 迁移到 Training。  
4. 将 Vitals + Sleep + Scoring drilldown 迁移到 Insights。  
5. 将 Vela Intelligence 迁移到 Coach。  
6. 将 Journal + Wiki + Settings + Trust Center 迁移到 Me。  
7. 保留旧入口但标记为 deprecated，逐步删除。

### 2.4 建议文件结构

```text
VelaApp/Features/
  Today/
    TodayView.swift
    TodayViewModel.swift
    Components/
  Training/
    TrainingHomeView.swift
    WorkoutSessionView.swift
    WorkoutSummaryView.swift
    Components/
  Insights/
    InsightsHomeView.swift
    MetricDetailView.swift
    Components/
  Coach/
    CoachHomeView.swift
    CoachArtifactDetailView.swift
    AskCoachView.swift
    Components/
  Me/
    MeView.swift
    BodyWikiView.swift
    JournalHistoryView.swift
```

### 2.5 验收标准

- App 启动后只出现新的五 Tab。
- 旧功能都能在新结构中找到归属。
- 用户不会看到 Home/Journal/Fitness/Vitals 这种彼此边界模糊的入口命名。

---

## 3. Phase 2：Design System 2.0

### 3.1 目标

先统一视觉语言，再批量升级页面。不要逐页手写风格。

### 3.2 任务

1. 审查当前 `Core/DesignSystem`、`Core/Theme`。  
2. 定义新的 token：spacing、radius、typography、shadow、materials、semantic colors。  
3. 新增核心组件：
   - `VelaPageShell`
   - `VelaHeroCard`
   - `MetricScoreCard`
   - `CoachArtifactCard`
   - `EvidenceSheet`
   - `ActionPill`
   - `SignalRow`
   - `TrendChartCard`
   - `EmptyStateView`
   - `DataSourceBadge`
   - `ConfidenceBadge`
4. 为 Today / Training / Coach 各做一个 preview mock。  
5. 建立暗色优先视觉，适配浅色。

### 3.3 UI 质量要求

- 主卡片层级明确。
- 每屏信息密度可控。
- 数字、状态、解释、行动四者视觉顺序清楚。
- 卡片展开/关闭有动效。
- 关键操作有 haptic feedback。
- 支持 Dynamic Type。

### 3.4 验收标准

- 新页面不再直接使用散乱字体、颜色、圆角、阴影。
- 组件 preview 可独立查看。
- Today 首屏视觉明显比旧版更高级。

---

## 4. Phase 3：First-Day Body Model Onboarding

### 4.1 目标

解决新用户首次进入无上下文、无计划、无个性化的问题。

### 4.2 任务

1. 新建 onboarding flow：`OnboardingFlowView`。  
2. 新建本地模型：
   - `UserGoalProfile`
   - `TrainingPreferenceProfile`
   - `EquipmentProfile`
   - `CoachingPreference`
   - `OnboardingState`
3. 增加 HealthKit 授权步骤。  
4. 导入最近 14/30 天摘要，生成 `InitialBodySnapshot`。  
5. 生成 First Brief。  
6. 生成 3 天 First Action Plan。  
7. Onboarding 可跳过，但必须记录 missing data。

### 4.3 页面步骤

```text
1. Welcome
2. What Vela does
3. Connect Apple Health
4. Choose primary goal
5. Choose training style
6. Choose equipment & schedule
7. Choose body concerns
8. Choose coaching style
9. Import baseline
10. First Brief
```

### 4.4 验收标准

- 新用户不会直接进入空首页。
- Onboarding 完成后 Today 有实际内容。
- 用户目标写入本地 profile。
- AI ContextBuilder 能读取 profile。

---

## 5. Phase 4：Today Command Center

### 5.1 目标

将首页升级为每日决策中心。

### 5.2 任务

1. 新建 `TodayViewModel`，聚合：
   - DailyHealthSummary
   - Recovery score
   - Sleep score
   - Strain score
   - Stress score
   - planned workout
   - recent workout summary
   - journal signals
   - wiki facts
2. 新建 `ReadinessDecisionEngine`，输出 keep/reduce/swap/recover。  
3. 新建 `TodayPlanBuilder` 或升级现有 builder。  
4. 新建 `WhyThisEvidenceSheet`。  
5. 新建 `TodayActionStack`。  
6. 新建数据不足 fallback。  
7. Today 卡片接入 Coach Artifact。

### 5.3 Today 数据模型

```swift
struct TodayCommandState {
    let date: Date
    let bodyStateTitle: String
    let summary: String
    let readinessDecision: ReadinessDecision
    let keySignals: [HealthSignal]
    let actions: [TodayAction]
    let coachArtifact: CoachArtifact?
    let dataConfidence: DataConfidence
}
```

### 5.4 验收标准

- Today 首屏能在一屏内表达状态、决策、行动。
- Why This 可解释至少 3 个证据信号。
- 没有健康数据时不会崩溃或空白。
- 用户可以从 Today 直接进入 Training 或 Check-in。

---

## 6. Phase 5：Training Execution Loop

### 6.1 目标

把 Training 做成每天可用的训练操作台，而不是单纯分析页。

### 6.2 任务

1. 建立动作库基础模型：`Exercise`。  
2. 建立训练模板：`WorkoutTemplate`。  
3. 建立训练记录：`StrengthWorkoutRecord`。  
4. 建立组记录：`ExerciseSetRecord`。  
5. 训练中页面：`WorkoutSessionView`。  
6. 支持复制上次表现。  
7. 支持完成组按钮。  
8. 支持组间计时。  
9. 支持 RPE/RIR。  
10. 训练完成后生成 Summary。  
11. Summary 同步到 DailyHealthSummary。  
12. AI 生成 Post-Workout Review。

### 6.3 优先级

#### P0

- StrengthWorkoutRecord 保存。
- 每组重量/次数记录。
- 完成组按钮。
- 训练总结。
- 同步到 DailyHealthSummary。

#### P1

- 模板库。
- 上次表现自动填充。
- 组间计时。
- e1RM / PR。
- 肌群容量。

#### P2

- 自适应训练调整。
- 周期化训练计划。
- Apple Watch companion。

### 6.4 验收标准

- 用户能完成一次完整力量训练记录。
- 训练结束后生成容量、有效组、肌群、PR、e1RM。
- 第二天 Morning Brief 能引用上一天训练。
- 训练记录对 readiness decision 有影响。

---

## 7. Phase 6：AI Coach Artifact System

### 7.1 目标

把 AI 从聊天框升级为结构化、可持久化、可行动的教练输出系统。

### 7.2 任务

1. 新建 `CoachArtifact` SwiftData model。  
2. 新建 `CoachArtifactType` enum。  
3. 新建 `CoachArtifactRenderer`。  
4. 新建 `CoachArtifactParserTests`。  
5. 升级 PromptComposer：要求输出 JSON artifact。  
6. 升级 AgentActionParser：解析 action buttons。  
7. 新建 `CoachHomeView`：Artifact Inbox + Today Coach Card + Ask Coach。  
8. 实现 Morning Brief。  
9. 实现 Workout Readiness。  
10. 实现 Post-Workout Review。  
11. 实现 Weekly Review skeleton。  
12. 实现 Wiki Update Proposal。

### 7.3 Artifact 生命周期

```text
created → presented → acted / dismissed → feedback collected → optionally written to wiki
```

### 7.4 验收标准

- Coach 首屏不是纯聊天。
- artifact 可持久化。
- artifact action 可执行。
- JSON 解析失败时有 fallback。
- 用户可对建议标记 helpful/not helpful。

---

## 8. Phase 7：Insights Drilldown + Wiki

### 8.1 目标

增强页面纵深和长期记忆能力。

### 8.2 Insights 任务

1. 新建 `InsightsHomeView`。  
2. 统一 `MetricDetailView` 模板。  
3. 为 Recovery / Sleep / Strain / Stress 接入模板。  
4. 每个指标显示：当前值、趋势、baseline、contributor、行动建议、数据来源、置信度。  
5. 支持从 Today 的 key signal 跳转到对应 Metric Detail。

### 8.3 Wiki 任务

1. 新建 `BodyWikiView`。  
2. 新建 wiki 分类。  
3. 支持 Wiki Update Proposal 接受/编辑/拒绝。  
4. 每条记忆显示来源。  
5. Coach ContextBuilder 接入 wiki facts。

### 8.4 验收标准

- 用户可以从 Today drill down 到指标证据。
- 用户可以查看 AI 记住了什么。
- 用户可以编辑/删除 Wiki 记忆。
- AI 建议能引用 Wiki facts。

---

## 9. Phase 8：质量、性能、发布准备

### 9.1 测试任务

必须补齐：

```text
OnboardingStateTests
TodayCommandStateTests
ReadinessDecisionEngineTests
TrainingRecordPersistenceTests
DailyHealthSummarySyncTests
CoachArtifactParserTests
ContextBuilderV2Tests
WikiUpdateProposalTests
```

### 9.2 UI 测试

覆盖以下主流程：

1. 新用户 onboarding → First Brief。  
2. Today → Why This → Training。  
3. Training → record sets → summary。  
4. Coach → artifact → action。  
5. Wiki proposal → accept → wiki page。

### 9.3 性能任务

- Today 首屏加载不能被 AI 请求阻塞。  
- HealthKit aggregation 应缓存。  
- Artifact 生成异步执行。  
- 数据缺失和网络失败要有 fallback。

### 9.4 发布检查

- App 可编译。  
- Tests 通过。  
- 无明显 UI 崩坏。  
- 空状态完整。  
- 隐私说明清楚。  
- README / PRD / AI spec 更新。

---

## 10. 建议 Pull Request 切分

### PR 1：Vela 3.0 Docs + Audit

- 新增 PRD / Execution Plan / Audit。  
- 不改功能。  
- 确认方向。

### PR 2：Navigation IA

- 新 Tab 架构。  
- 旧页面迁移入口。  
- 不做大 UI 美化。

### PR 3：Design System 2.0

- Token + components。  
- Preview。  
- 只替换基础容器。

### PR 4：Onboarding + Body Model

- 新用户建模。  
- Profile persistence。  
- HealthKit permission flow。

### PR 5：Today Command Center

- Today state aggregation。  
- Readiness decision。  
- Why This。

### PR 6：Training Execution P0

- StrengthWorkoutRecord。  
- Set logging。  
- Workout summary。  
- Daily summary sync。

### PR 7：Coach Artifact P0

- CoachArtifact model。  
- Artifact inbox。  
- Morning Brief / Workout Readiness / Post-Workout Review。

### PR 8：Insights + Wiki

- Metric drilldown。  
- Wiki UI。  
- Wiki proposal。

### PR 9：QA + Polish

- Tests。  
- Empty states。  
- Accessibility。  
- Performance。

---

## 11. 风险控制

### 11.1 不要让 Codex 做的事

- 不要一次性重写所有 SwiftUI 页面。  
- 不要改动 HealthKit 原始数据策略。  
- 不要把 AI 输出变成自由文本后直接渲染。  
- 不要做社区、营养数据库、课程库。  
- 不要删除旧模块，除非确认新入口已覆盖。

### 11.2 必须坚持的事

- 每个阶段都要可编译。  
- 每个核心新能力都要有测试。  
- 每个 AI artifact 都要有结构化 schema。  
- 每个建议都要可解释。  
- 每个训练记录都要回流到 DailyHealthSummary。  
- UI 组件化优先于逐页美化。

---

## 12. 最终执行检查清单

```text
[ ] 新五 Tab 信息架构完成
[ ] Onboarding 完成并写入 User Body Model
[ ] Today 页面能显示状态、决策、行动
[ ] Why This 解释可打开
[ ] Training 可完成一次力量训练记录
[ ] Workout Summary 可生成
[ ] StrengthWorkoutRecord 同步到 DailyHealthSummary
[ ] Coach Artifact model 完成
[ ] Morning Brief 可生成并持久化
[ ] Workout Readiness 可生成并驱动训练调整
[ ] Post-Workout Review 可生成
[ ] Wiki Update Proposal 可接受/编辑/拒绝
[ ] Insights 指标详情页统一模板
[ ] Design System 2.0 被新页面使用
[ ] 核心 tests 通过
[ ] 空状态、数据不足、AI 失败 fallback 完成
[ ] README / docs 更新
```
