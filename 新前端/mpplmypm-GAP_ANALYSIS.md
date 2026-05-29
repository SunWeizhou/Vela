# Vela vs Bevel Health — 产品差距分析

> 作者：产品经理角色  
> 日期：2026-05-20  
> 目的：指导 AI Coding 助手的开发优先级

> 2026-05-22 update: Bevel 3.0 research and iPhone mirror review are now incorporated. See `docs/BEVEL_3_RESEARCH.md` and `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

---

## 1. Vela 当前状态评估

### ✅ 已完成（59 个 Swift 文件）

| 模块 | 状态 | 质量 |
|---|---|---|
| 项目骨架 & 模块目录 | ✅ 完整 | 优秀 |
| HealthKit 授权 & 数据读取 | ✅ 完整 | 良好 |
| SwiftData 持久化层 | ✅ 完整 | 良好 |
| 6 个评分引擎 | ✅ 完整 | 良好 |
| Home Dashboard | ✅ 有基础版 | ⚠️ 需大幅提升 |
| Sleep / Recovery / Strain 详情页 | ✅ 有基础版 | ⚠️ 需大幅提升 |
| Journal (标签 + 剂量 + 关联) | ✅ 完整 | 良好 |
| AI Coach + DeepSeek 接入 | ✅ 可用 | ⚠️ 交互需重做 |
| 4 类报告 + Wiki 系统 | ✅ 完整 | 良好 |
| 设置 / 双语 / Onboarding | ✅ 完整 | 良好 |

**总结：后端逻辑层已基本完成。最大差距在 UI/UX 层。**

### 2026-05-22 当前状态修正

当前 Vela 已超过本表的原始 2026-05-20 评估：

- Home 已有 readiness cockpit、Daily Plan、AI insight、card layout customization；
- Sleep 已有日期导航和睡眠阶段时间轴；
- Strain 已有 target range、30 天趋势、训练日历入口；
- Recovery 已有 baseline comparison、factor breakdown；
- Coach 已有 session、personality、sidebar、food photo、Wiki sync、工具雏形；
- Biology / Biological Age / Biomarker manual entry 已出现；
- TrainingView / TrainingCalendarView 已出现；
- PersonalBaselineEngine、WebSearchService、FoodPhotoAnalyzer、NotificationService 已出现。

新的主要差距不再是“有没有模块”，而是“模块是否形成 Bevel 3.0 级的完整体验闭环”。

---

## 2. 关键差距清单

### 🔴 新差距 0：Coach 还不是 Intelligence Workspace（⭐⭐⭐⭐⭐）
- Bevel 3.0：Intelligence V2 包含 personalities、check-ins、files、artifacts、food logging、training plans。
- Vela：Coach 功能很多，但视觉和信息架构仍是聊天记录页；Wiki、Artifacts、Tools、Check-ins 没有成为同级工作台。
- 方向：把 Coach 产品化为 Intelligence，首屏展示主动洞察、Wiki 状态、工具动作、生成物，再进入聊天。

### 🔴 差距 1：Home Dashboard 缺乏产品感（⭐⭐⭐⭐⭐）
- Bevel：差异化大卡片，每个指标有独特视觉语言，微动画
- Vela：统一的 HealthMetricCard，2x2 网格，没有主次之分

2026-05-22 修正：Vela 首页已具备产品感，但仍需要进一步压缩首屏信息密度。目标不是更多卡，而是更明确的“状态 -> 原因 -> 今日行动”。

### 🔴 差距 2：Sleep 缺少阶段时间轴（⭐⭐⭐⭐⭐）
- Bevel：横向时间轴（X=时间, Y=阶段深度），整晚睡眠波形
- Vela：竖状柱状图按阶段分组，丢失时序信息

### 🔴 差距 3：无日期导航，只能看今天（⭐⭐⭐⭐⭐）
- Bevel：所有页面支持日期切换，可回看历史
- Vela：写死今日数据

### 🟠 差距 4：Strain 缺少锻炼列表（⭐⭐⭐⭐）
- Bevel：显示当天 Workout 卡片（类型/时长/心率区间）
- Vela：只有总分数值

### 🟠 差距 5：AI Coach 交互太基础（⭐⭐⭐⭐）
- Bevel：对话式 chat thread，流式输出，主动推送
- Vela：点按钮→显示结果，无对话历史

2026-05-22 修正：Vela 已有对话历史和 streaming。剩余差距是：
- proactive check-ins 需要作为 UI 对象出现；
- training plan / food log / correlation chart 需要结构化 artifact；
- Wiki 更新需要用户可见的 diff/audit；
- chat 文本需要更短、更行动导向。

### 🟠 差距 6：Recovery 视觉不够丰富（⭐⭐⭐）
### 🟡 差距 7：缺少 Sleep Needed 动态指标（⭐⭐⭐）
### 🟡 差距 8：Strain 非对数刻度（⭐⭐）
### 🟡 差距 9：缺少 HR Zone 分析（⭐⭐）

---

## 3. 五阶段执行路线图

| 阶段 | 目标 | 核心任务 |
|---|---|---|
| **Phase 1** | UI/UX 视觉升级 | Dashboard 重做、Sleep 时间轴、Strain 弧形进度、微动画 |
| **Phase 2** | 核心功能补全 | 日期导航、Workout 列表、Sleep Needed、趋势交互 |
| **Phase 3** | AI Coach 升级 | Chat 界面、流式输出、HR Zone、对数 Strain |
| **Phase 4** | 数据深度 | 周/月对比、智能基线、主动 insight |
| **Phase 5** | 体验打磨 | Widget、空状态、性能优化 |

## 4. Bevel 3.0 后的新优先级

| Priority | Product Gap | Why It Matters | Vela Direction |
|---|---|---|---|
| P0 | Intelligence Workspace | Bevel 3.0 的核心升级点 | Coach 重构为 chat + check-ins + Wiki + artifacts |
| P0 | Home first-viewport clarity | 每日使用频率最高 | 已加入 Readiness Brief；下一步补置信度、新鲜度、真机首屏验证 |
| P1 | Training plan UI | Reddit 反馈明确反感 markdown-only 计划 | 日历和训练卡 |
| P1 | Biology confidence | Biological Age 容易被质疑 | freshness、missing data、factor drilldown |
| P1 | Nutrition editability | Bevel 3.0 用户痛点 | 暂缓；基础 Kimi + FoodLog 已完成，后续再做可编辑份量/宏量/置信度 |
| P2 | Share/customize polish | 增强成熟度和传播 | 指标分享卡、样式选择 |

## 5. 真机体验发现

### Vela

- 首页视觉已经成熟，但部分卡片和 Tab Bar 边界接近，底部安全区仍需要持续检查。
- Sleep / Strain / Recovery 的核心视图可用，日期导航、趋势、factor breakdown 已进入产品态。
- Coach 页面底部输入栏与 Tab Bar 视觉距离较紧；聊天气泡内长段落和 emoji 降低了高级感。
- Wiki 是最大差异化，但入口仍偏隐藏。

### Bevel

- 首页浅色、柔和、信息分层清晰。
- 三个主环 + 一句 guidance + Stress/Energy 模块让用户能立刻理解状态。
- Tab IA 更偏行为闭环：Home、Journal、Fitness、Vitals、plus action。
- Pro upsell 强绑定 Intelligence，而不是普通数据展示。
