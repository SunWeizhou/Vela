# MVP_EXECUTION_PLAN.md
# Project Vela — Development Execution Plan

> Updated: 2026-05-23  
> Status: the original MVP phases are mostly implemented. This file now also defines the next execution path toward the full-strength Vela described in `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

## 1. 执行总原则

Vela 的开发采用“文档先行、Agent 协作、模块化推进”的方式。

### 核心原则
1. 先定产品边界，再写代码；
2. 先跑通数据链路，再做高级算法；
3. 先做可长期使用的私人 App，再考虑公开发布；
4. 每个模块必须留有后续算法升级空间；
5. UI 设计可借助 Stitch 生成，但产品逻辑必须先由 PRD 约束清楚。

---

## 2. 推荐开发顺序

## Current Reality Check — 2026-05-23

The original Phase 0-8 foundation is largely present in the codebase:

- HealthKit foundation: implemented.
- SwiftData persistence: implemented and expanded with raw metrics.
- Scoring engines: implemented for sleep, recovery, strain, stress, energy, health age, biological age.
- Home/Sleep/Recovery/Strain UI: implemented and running on iPhone.
- Coach/AI: implemented with sessions, streaming, personalities, Wiki sync, tools, food photo, web search.
- Training/Biology: implemented as emerging product surfaces.
- 2026-05-23 update: Home now has a tested Readiness Brief layer that explains current status, the top reason, and the next action from Daily Plan.
- 2026-05-23 update: Nutrition foundation exists, but further Nutrition productization is intentionally paused while Home / Intelligence / Training / Biology are advanced.

The execution plan below should now be read as historical foundation plus a new Bevel 3.0-class roadmap.

# Next Roadmap — Full-Strength Vela

## Phase N1 — Intelligence Workspace

目标：把 Coach 从聊天页升级为 Vela Intelligence。

任务：
- 首屏加入 Wiki/Memory 状态、主动 Check-ins、Artifacts、Tool shortcuts；
- 将 Training Plan / Food Log / Correlation Chart 渲染为结构化卡片；
- 加入 Wiki 更新审计入口；
- 收敛 Coach 文案长度，默认输出更短。

验收：
- 用户不发消息也能看到今天 Intelligence 正在做什么；
- Agent 生成物不是只有 markdown；
- 用户能看到 Vela 记住了什么、何时记住、为什么。

## Phase N2 — Home Cockpit Polish

目标：首屏 10 秒内回答“状态、原因、行动”。

任务：
- 收敛 readiness hero；
- 将 Readiness Brief 固定为 Home 的核心解释层；
- 增加 confidence / freshness row；
- 修正底部 safe-area 和卡片遮挡；
- Daily Plan 成为默认下一步行动；
- 点击 Readiness Brief 能带着结构化问题进入 Coach；
- 空数据、building baseline、同步状态统一。

验收：
- iPhone 镜像首屏没有卡片被 Tab Bar 压住；
- 今日计划不用滚动即可看到；
- 用户能在 Home 直接看到 why 和 next action；
- 缺数据时体验不崩坏。

## Phase N3 — Adaptive Training

目标：训练计划变成真正的日历产品。

任务：
- 完成 TrainingPlanRecord 到 UI 日历的闭环；
- 支持 missed workout reschedule；
- 训练卡展示目标 strain、强度、时长、恢复限制；
- Coach 的 generate_training_plan 工具保存结构化计划。

验收：
- 用户能从 Coach 生成计划并在 Training 查看；
- Recovery/Energy 变化会影响今日推荐；
- 计划不是 markdown-only。

## Phase N4 — Biology and Health Records

目标：让 Biological Age 可信。

任务：
- 每个 factor 增加 freshness 和 confidence；
- Blood biomarker 手动录入支持更多指标；
- 新增 HealthRecordDocument 数据模型路线；
- 后续支持本地文档导入和 biomarker extraction。

验收：
- Biological Age 页面说明哪些数据缺失；
- 血检指标不会被当成医疗诊断；
- 用户知道分数为什么变化。

## Phase N5 — Nutrition

目标：把 Food Photo Analyzer 产品化。

当前状态：暂停继续扩展。Kimi Vision、FoodLogRecord、Journal 回看和 Coach 上下文已经具备基础能力；下一轮再做编辑体验和趋势统计。

任务：
- 新增 FoodLogRecord；
- 照片识别后进入可编辑 sheet；
- 可编辑食物、份量、calories、macros、confidence；
- 与 Journal / AI Context 连接。

验收：
- 用户能修正 AI 估算；
- 结构化 nutrition history 可被 Coach 使用；
- 明确标注估算不精确。

## Phase N6 — Device Validation

目标：所有核心流程在真机上可长期使用。

任务：
- HealthKit 权限；
- background refresh；
- notification delivery；
- wiki sync；
- morning brief；
- food photo；
- training plan；
- biomarker entry；
- tab safe area and long text.

验收：
- 真机连续使用 7 天无核心数据断裂；
- 没有关键 UI 遮挡；
- Agent 不产生不可解释的 Wiki 污染。

# Phase 0 — 项目初始化

## 目标
建立工程骨架与文档约束。

## 任务
- 创建 Xcode iOS SwiftUI 项目；
- 设定最低系统版本；
- 建立模块目录；
- 集成基础主题系统；
- 建立 docs/ 与 agent/ 目录；
- 设置 SwiftLint / Format 可选；
- 配置 HealthKit capability；
- 配置 Debug API Key 读取方式。

## 输出
- 可运行空项目；
- 标准目录结构；
- 基础 Tab 导航占位。

---

# Phase 1 — HealthKit Data Foundation

## 目标
稳定读取第一阶段要求的 Apple Health 数据，并形成统一领域模型。

## 数据类型

### Sleep
- Sleep Analysis
- Sleep Stages

### Recovery
- HRV
- Resting Heart Rate
- Sleep Heart Rate
- Respiratory Rate

### Strain
- Active Energy
- Exercise Time
- Steps
- Workouts
- Workout HR

### Biology
- VO₂ Max
- Weight
- Body Fat
- Lean Body Mass

## 任务拆解
1. HealthAuthorizationService
2. HealthQueryService
3. DataNormalizationService
4. DateRangeQuery utilities
5. Demo Data / Preview support
6. Error and permission state handling

## 验收标准
- 用户授权后可读取数据；
- 最近 7 天 / 30 天查询稳定；
- 页面层不直接调用 HealthKit；
- 所有数据先转换为 App Domain Model。

---

# Phase 2 — 本地存储层

## 目标
使用 SwiftData 建立长期存储，用于：
- Cached Daily Health Summary；
- Journal Entries；
- AI Reports；
- User Wiki Metadata；
- Computed Scores。

## 核心模型
- DailyHealthSummary
- SleepSummary
- RecoverySummary
- StrainSummary
- StressSummary
- EnergyBankSnapshot
- HealthAgeTrendSnapshot
- JournalEntry
- AIReport
- UserWikiDocument

## 验收标准
- App 重启后仍可查看历史摘要；
- AI 报告可历史回看；
- Journal 可增删查；
- 指标缓存降低重复 HealthKit 计算。

---

# Phase 3 — Scoring Engine v0.1

## 目标
完成第一版评分系统。

## 模块
1. SleepScoreEngine
2. RecoveryScoreEngine
3. StrainScoreEngine
4. StressIndexEngine
5. EnergyBankEngine
6. HealthAgeTrendEngine

## 设计原则
- 每个 Engine 独立；
- 支持参数配置；
- 每个分数都返回：
  - score；
  - band；
  - reasons；
  - contributing metrics；
  - confidence。

## 验收标准
- 能稳定输出 0–100 分；
- 每个分数都有解释依据；
- AI Coach 可消费这些结构化结果。

---

# Phase 4 — Home Dashboard

## 目标
实现 Bevel-inspired 首页。

## 页面区块
- Header
- Daily summary
- Recovery Card
- Sleep Card
- Strain Card
- AI Daily Insight Card
- Stress Card
- Energy Bank Card
- Health Age Trend Card

## 验收标准
- 首屏有完整产品感；
- 所有卡片可进入详情页；
- 卡片内容与真实评分联动；
- 空数据与权限未开启状态有合理展示。

---

# Phase 5 — Sleep 页面

## 目标
完成睡眠页面 v0.1。

## 必做内容
- Sleep Score；
- Sleep Duration；
- Stage Chart；
- Sleep / Wake time；
- 7 日趋势；
- AI Sleep Review。

## 开源复用建议
优先评估 SleepChartKit，用于睡眠阶段图。

## 验收标准
- 能展示昨夜睡眠；
- 能展示 Apple Health 睡眠阶段；
- 能展示最近 7 天趋势；
- AI 可生成 Sleep Review。

---

# Phase 6 — Recovery 页面

## 目标
完成 Recovery v0.1。

## 必做内容
- Recovery Score；
- Low / Moderate / High 标签；
- Factor breakdown；
- HRV 趋势；
- RHR 趋势；
- Sleep contribution；
- Prior Strain contribution；
- AI Recovery Insight。

## 验收标准
- 分数与趋势图一致；
- 每日 Recovery 变化可解释；
- 可清楚说明“今天为什么恢复偏低/偏高”。

---

# Phase 7 — Strain 页面

## 目标
完成全天负荷模型 v0.1。

## 必做内容
- Strain Score；
- Strain Progress Ring；
- Workouts list；
- Active Energy；
- Suggested load；
- AI Workout Readiness。

## 验收标准
- 无 Workout 的日子也能有基础 Strain；
- 有 Workout 的日子负荷明显抬升；
- AI 能结合 Recovery 与 Strain 给训练建议。

---

# Phase 8 — Stress / Energy / Health Age / Journal

## Stress
- 今日 Stress Index；
- 日内曲线；
- Proxy 标识；
- AI 解读。

## Energy Bank
- Morning Energy；
- Current Energy；
- 解释卡片。

## Health Age Trend
- Beta；
- 长期趋势；
- 影响因子摘要。

## Journal
- 标签；
- 自由文本；
- 日历式浏览可后续再做。

## 验收标准
- 4 个模块都能在 Home 有卡片；
- 页面或详情区域能解释指标；
- Journal 数据能被 Agent 上下文读取。

---

# Phase 9 — AI Health Coach

## 目标
接入 DeepSeek API，完成可对话、可生成报告的 Health Coach。

## 必做能力
- API Key 设置页；
- Debug 配置文件接入；
- Chat page；
- Agent context builder；
- Morning Brief；
- Sleep Review；
- Workout Readiness；
- Weekly Review；
- 报告保存；
- 报告作为未来 Agent 上下文。

## 验收标准
- 用户可输入 API Key；
- Key 存储安全；
- Chat 回答与个人健康数据相关；
- 固定报告一键生成；
- 历史报告可查看。

---

# Phase 10 — 真机验证与打磨

## 目标
让 App 真正成为“每日可用”。

## 任务
- 使用真实 Apple Watch 数据测试；
- 检查无数据场景；
- 检查权限拒绝场景；
- 调整卡片排序；
- 调整 Recovery / Sleep / Strain 文案；
- 优化 AI Prompt；
- 记录长期使用问题。

---

## 3. 开发里程碑建议

| 里程碑 | 目标 |
|---|---|
| M0 | 文档与项目骨架 |
| M1 | HealthKit 数据层 |
| M2 | Scoring Engine v0.1 |
| M3 | Home + Sleep |
| M4 | Recovery + Strain |
| M5 | Stress + Energy + Biology + Journal |
| M6 | AI Coach |
| M7 | 真机打磨 |

---

## 4. 推荐的工程目录

```text
VelaApp/
├── App/
│   ├── VelaApp.swift
│   └── AppCoordinator.swift
│
├── Core/
│   ├── Theme/
│   ├── Utilities/
│   ├── Extensions/
│   └── Constants/
│
├── Health/
│   ├── Authorization/
│   ├── Queries/
│   ├── Mapping/
│   ├── Models/
│   └── Services/
│
├── Scoring/
│   ├── Sleep/
│   ├── Recovery/
│   ├── Strain/
│   ├── Stress/
│   ├── EnergyBank/
│   └── HealthAge/
│
├── AI/
│   ├── Provider/
│   ├── Context/
│   ├── Prompting/
│   ├── Reports/
│   └── Models/
│
├── Journal/
│   ├── Models/
│   ├── Services/
│   └── Views/
│
├── Persistence/
│   ├── SwiftDataModels/
│   ├── Repositories/
│   └── Migrations/
│
├── Features/
│   ├── Home/
│   ├── Sleep/
│   ├── Recovery/
│   ├── Strain/
│   ├── Coach/
│   ├── Settings/
│   └── SharedComponents/
│
└── Resources/
```

---

## 5. 开发策略建议

### 5.1 不要一开始死磕算法
先完成：
- 数据链路；
- 可解释结构；
- 产品体验；
- 再迭代评分科学性。

### 5.2 不要一开始做商业发布标准
当前优先级是：
- 真机能跑；
- 自己愿意用；
- 架构漂亮；
- 文档完备。

### 5.3 一定要区分三种东西
- 原始数据；
- App 计算出的指标；
- AI 生成的自然语言解释。

---

## 6. 最终 Definition of Done

第一阶段完成标准：
1. App 能在个人 iPhone 上安装使用；
2. HealthKit 权限读取正常；
3. 5 个 Tab 页面完整；
4. 评分体系 v0.1 正常输出；
5. Journal 可记录；
6. AI Coach 可聊天、生成 4 类报告；
7. 数据与报告本地持久化；
8. UI 有成熟产品感；
9. 文档足够支持后续 Agent 继续迭代。
