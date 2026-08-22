# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# PRD.md
# Project Vela — Local-first AI Health Coach for Apple Health

> ⚠️ **2026-08-13 方向更新**：Vela 已进入 **Personal Edition 阶段**（只为产品作者本人服务的主动式健康调节教练）。本文档的历史主线和 Bevel 对标策略已冻结，产品方向以 `docs/VELA_PERSONAL_PRODUCT_DIRECTION.md`、`CONTEXT.md` 领域语言与 `docs/adr/0004-0009` 为准。以下内容保留作为功能与架构的历史记录。

> Updated: 2026-07-13
> Current product target: Vela 4.0 Active Coach OS, a closed-loop local-first body intelligence and training execution system.

## 0. 当前构建状态

截至 2026-07-13，Vela 已升级为本地优先 Active Coach OS：

- iOS SwiftUI + SwiftData + HealthKit 主工程可编译通过，全部测试通过（100% pass rate）；
- 已收敛为 Today / Training / Coach / Me 四个主 Tab，优先支持每日判断—行动—反馈闭环；
- 已实现 Sleep、Recovery、Strain、Stress、Energy Bank、Health Age、Biological Age 等 10+ 评分引擎；
- 已实现 HealthKit 多维数据读取、日摘要缓存、AI 报告、Journal、Coach session、训练计划、生物标志物记录；
- 当前 iOS 运行时直连用户配置的 DeepSeek Provider，并使用 Kimi Vision Food Photo Analyzer；VelaBackend 仅保留为未启用的可选实验组件；
- 已实现结构化 FoodLog、AIContextBuilder、流式 Coach、Coach Personality、Agent tools、Web Search；
- 已实现 user Wiki、夜间 Wiki 同步 Agent、晨间简报、主动洞察、通知配置；
- Home 由 `BodyStateKernel`、`TrainingDecisionKernel` 和持久化 `DailyOperatingPlanRecord` 驱动；
- Coach、Morning Brief、Training 与 Intelligence Workspace 共享同一个 BodyState 和可审计 Agent artifact；
- Coach 在未配置云端模型时仍提供基于 Daily Operating Plan 的本机建议，云端 AI 是增强项而非产品可用性的前提；
- 用户界面将 Data Coverage（采集完整度）与判断依据强弱分开表达，不再把内部权重伪装成概率式“置信度”；
- 原始 HealthKit 数据永不离开设备；仅向用户选择的模型服务发送经过裁剪的结构化摘要；
- **Training Intelligence v3** 模块已落地：TrainingAnalyticsService、RecoveryTrainingAdapter、ExerciseLibraryService、TrainingPlanLinkingService、力量训练视图；
- 真机 UI 已切换为 Rhythm 视觉：暖灰绿画布（`rhythmCanvas` `#F2F5F1`）、节律绿品牌色（`accent` `#17A35C`）、深墨文字（`rhythmInk`）和原生 Liquid Glass 导航（2026-08-13 起，Signal Blue 已废弃）；
- 键盘交互已优化为微信式体验：点空白区/下滑收起键盘，键盘弹出时聊天区整体上移。

本 PRD 已从”从零开发”阶段过渡到”持续打磨完整产品”阶段。2026-08-13 起产品边界和优先级以 `docs/VELA_PERSONAL_PRODUCT_DIRECTION.md` 与 `docs/adr/0004-0009` 为准；`VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md` 与 `VELA_TRAINING_INTELLIGENCE_V3.md` 降级为历史参考。

## 1. 产品概述

### 1.1 项目代号
Vela

### 1.2 一句话定位
**Vela 是建立在 Apple 健康之上的个人身体面板与 AI 健康分析助手：帮助用户看见当前身体状态和长期趋势，理解变化原因，并将这种理解转化为训练与生活调整建议。**

> 核心原则：不做只陈列指标、不能解释个人状态和变化的健康数据面板。

### 1.3 核心价值层级（不可颠倒）
1. **看见身体数据**：把 Apple Health 中分散的体征与信号完整汇聚；
2. **理解当前状态与长期变化**：通过多尺度趋势（7天/30天/6个月/3年）与 Personal Health Brief 理解身体；
3. **由 Agent 解释原因、联系不同信号**：AI 分析师提供跨系统关联观察与候选影响因素分析；
4. **在需要时给出训练与生活调整建议**：将身体认知落地为克制、明确的行动。

### 1.4 北极星指标
**`Trusted Health Brief Day`**（可信身体简报日）：一天中，Vela 可靠帮助用户回答：(1) 我现在总体怎么样？ (2) 最近有什么值得注意的变化？ (3) 我是否需要采取行动？身体状态稳定、无需改变计划同样是有价值的一天。

---

## 2. 竞品参考与产品策略

> **2026-08-13 注**：Bevel 对标已整体冻结（像素级 1:1 停止、版本追踪停止），本节保留为历史策略记录；当前信息架构以 `docs/VELA_PERSONAL_PRODUCT_DIRECTION.md` 的四工作区（Today / Training / Vela / Me）为准。

### 2.1 主要参考产品
- Bevel Health / Bevel 3.0
- Athlytic
- Oura / Whoop 的评分表达方式
- Apple Health 的数据呈现方式

### 2.2 本项目对 Bevel 的策略
Vela 的策略从“复刻 Bevel 核心结构”升级为“学习 Bevel 3.0 的完整产品闭环，并做出本地优先、用户可审计的 AI 版本”：

- 学习 Bevel 的 Recovery / Sleep / Strain / Stress / Energy / Biology / Training / Nutrition / Intelligence 组合方式；
- 学习 Bevel 首页和主页面的清晰层级：状态、原因、下一步行动、轻量日志、训练准备度、生命体征；
- 学习 Bevel 3.0 的 Intelligence、Files、Personalities、Check-ins、Artifacts、Training Plans、Health Records、Biological Age；
- 用 Vela 的 user Wiki、local SwiftData、可替换 LLM Provider、透明评分原因，形成差异化；
- 个人自用构建阶段允许高度贴近 Bevel 的信息架构、浅色材质、圆角卡片、底部 Tab 结构和指标表达；仍不复制 Bevel 商标、专有素材或不可审计的远端能力。

### 2.3 与 Bevel 的核心差异
1. local-first，不依赖后端；
2. 用户自己配置 DeepSeek API Key；食物照片识别单独配置 Kimi / Moonshot API Key；
3. AI 读取并维护用户自建 Wiki 文档，具备更强的长期个性化和可审计记忆；
4. 评分算法公开、可配置、可研究迭代；
5. 产品首先服务于开发者本人，而非 App Store 商业化；
6. UI 目标是 Bevel-like 的日常健康操作系统，但产品核心差异必须落在 Vela Wiki、透明评分原因、可替换模型和本地数据所有权上。

### 2.4 Bevel 3.0 对 Vela 的新增要求
外部调研详见 `docs/BEVEL_3_RESEARCH.md`。Vela 下一阶段需要补齐：

- Intelligence Workspace：聊天、主动 Check-in、Wiki/Files、Artifacts、工具调用同屏整合；
- Biology / Biological Age：血检指标、可穿戴指标、数据新鲜度、置信度；
- Health Records：从手动 biomarker 录入扩展到本地健康文档解析；
- Training Plans：计划必须以日历和训练卡呈现，不只停留在 markdown；
- Nutrition：食物照片识别已支持结构化保存和 Journal 回看；产品化编辑份量、置信度和趋势统计暂缓，先推进 Home / Intelligence / Training / Biology；
- 食物照片识别走 Kimi 视觉模型，结果回传给 DeepSeek Coach 做健康上下文建议；
- Pricing 不作为当前目标，但要理解 Bevel Pro 的价值锚点来自 AI + Biology + Records。

---

## 3. 目标用户

### 3.1 第一阶段目标用户
> **2026-08-13 更新（ADR 0009）**：当前阶段只为产品作者本人（Primary User）优化，28 天 Daily Driver 验证完成前不为通用用户扩张范围。
- 产品作者本人（使用 iPhone + Apple Watch；五分化力量训练轮转；长期减脂目标）；
- 愿意通过 API Key 配置 AI。

### 3.2 非目标用户
第一阶段不优先支持：
- Android 用户；
- 无 Apple Watch 的用户；
- 家人共享与家庭健康看板；
- 医疗诊断与疾病预测场景；
- App Store 大规模商业化发布。

---

## 4. 核心产品原则

### 4.1 Local-first
- 不做注册登录；
- 不做云同步；
- 不搭建后端；
- 健康数据、报告、Journal、用户 Wiki 均保存在本地；
- API Key 保存在 Keychain。

### 4.2 Data-first, LLM-second
- App 先计算指标、趋势和摘要；
- LLM 接收结构化上下文，而不是原始 HealthKit 数据；
- LLM 负责解释、总结和建议，不负责直接处理大规模原始传感器数据。

### 4.3 Bevel-like personal UI target
- 信息架构、屏幕层级、卡片密度和日常操作路径以 Bevel 3.0 为主参考；
- 当前个人构建优先追求“看起来、扫读方式、页面节奏都接近 Bevel”，同时保留 Vela 自有名称、Wiki 记忆、Agent 行为和本地优先架构；
- 视觉基调采用浅灰白背景、白色浮层卡片、柔和阴影、黑色主文字、低饱和辅助文字和少量健康语义色；
- 深色界面仅保留在确有必要的沉浸式图表或未来可切换主题中，默认体验为 Bevel-like light mode。

### 4.4 Scientifically cautious
- 所有评分均以“个人趋势分析”和“生活方式建议”为定位；
- 不做医疗诊断；
- Stress、Energy Bank、Biological Age 必须明确标注为行为与生理趋势代理指标，而不是医学结论。

---

## 5. 产品目标与成功标准

### 5.1 第一阶段目标
完成一个可在开发者个人 iPhone 上长期使用的 App，具备：
- HealthKit 数据授权与读取；
- Home Dashboard；
- Sleep 页面；
- Recovery 页面；
- Strain 页面；
- Stress、Energy Bank、Biological Age、Journal 的 v0.1；
- AI Health Coach；
- Morning Brief / Sleep Review / Workout Readiness / Weekly Review；
- 本地保存历史报告；
- 用户 Wiki 与 Agent 指令文档。

### 5.2 成功标准

#### 功能成功
- 能稳定读取最近 30 天核心健康数据；
- 能完成所有 Tab 页面浏览；
- 能输出 Recovery / Sleep / Strain / Stress / Energy Bank / Biological Age v0.1；
- AI 能结合健康数据和用户 Wiki 做出合理回答。

#### 体验成功
- 首页看起来像一个成熟产品，而不是 Demo；
- 数据呈现精致、克制、层次清晰；
- Agent 回答有“知道我是谁”的感觉；
- 用户愿意每天早上打开查看状态。

#### 工程成功
- 架构清晰，可扩展；
- 评分算法与 UI 解耦；
- Agent Provider 可替换；
- 后续可扩展饮食、家庭共享、云同步。

---

## 6. 产品范围

### 6.1 第一阶段 In Scope

#### 6.1.1 HealthKit 数据读取

##### 睡眠相关
- Sleep Analysis
- Sleep stages
- In Bed
- Asleep duration

##### 恢复相关
- HRV
- Resting Heart Rate
- Sleep Heart Rate
- Respiratory Rate during sleep

##### 活动与负荷相关
- Active Energy Burned
- Exercise Time
- Step Count
- Workouts
- Workout Heart Rate samples

##### 长期健康相关
- VO₂ Max
- Weight
- Body Fat Percentage
- Lean Body Mass

##### 其他用于压力和能量建模的原始维度
- General Heart Rate Samples
- Recent HRV fluctuations
- Sleep debt proxy
- Recent activity load

---

#### 6.1.2 App 导航结构
当前底部 Tab 为：

1. 首页 Home
2. 手记 Journal
3. 健身 Fitness
4. 生命体征 Vitals
5. `+` Intelligence / Coach

目标信息架构见 `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`。Sleep / Recovery / Strain 仍是核心评分能力，但底部导航按 Bevel-like 日常路径组织：Home 看状态，Journal 记上下文，Fitness 决策训练，Vitals 查看恢复与生理信号，`+` 进入 Vela Intelligence。

---

#### 6.1.3 Home Dashboard
首页采用 Vela readiness cockpit，而不是普通卡片流：

##### 顶部区
- 今日问候
- 日期
- 用户今天的综合状态提示
- 同步状态、数据源、数据新鲜度

##### 主卡片
1. Recovery Card
2. Sleep Card
3. Strain Card
4. Daily Plan Card
5. Readiness Brief Card
6. AI Daily Insight Card
7. Stress Card
8. Energy Bank Card
9. Biological Age / Health Age Trend Card

##### 卡片要求
- 所有主卡片可点击进入详情页；
- 首屏优先展示 Recovery / Sleep / Strain / AI；
- 其他卡片可以向下滚动浏览。
- 首屏必须回答三个问题：今天状态如何、为什么、下一步做什么；
- Readiness Brief 以 Recovery 分数与 Daily Plan 为输入，输出 statusLabel、why、nextAction、coachQuestion、accent；
- “Why” 优先展示评分引擎原因，其次使用 Daily Plan limiter，再回退到 dailyInsight；
- “Next” 直接使用 Daily Plan 的 primaryActionTitle，并可一键把 coachQuestion 送入 Coach；
- 缺失数据必须以 building baseline / missing permission / syncing 解释，不得显示成崩坏状态。

---

#### 6.1.4 Sleep 页面

##### 必须展示
1. 睡眠总时长；
2. 睡眠阶段图；
3. 入睡时间 / 起床时间；
4. 最近 7 天睡眠趋势；
5. AI 睡眠解读；
6. 简化 Sleep Score。

##### Sleep Score v1.0 (Apple/Levine 兼容)
基于多维睡眠特征与基线评估的 0-100 综合模型：
- **Duration Score (0–50)**：评估睡眠时长相对目标的完成度，接近睡眠目标（默认 7.5 小时）得满分，偏低重度惩罚，偏高轻度扣分。
- **Consistency Score (0–30)**：基于 circular time 算法评估入睡和起床时间，相对近 13 晚个人常态基线的偏离程度。
- **Interruption Score (0–20)**：结合夜间清醒时长 (awakeMinutes) 与醒来次数进行中断惩罚。

##### 页面结构建议
- 顶部 Sleep Score 环；
- 昨夜摘要；
- Sleep Stage Chart；
- 入睡 / 起床指标；
- 7 日趋势；
- AI Sleep Review。

---

#### 6.1.5 Recovery 页面

##### 必须展示
- Recovery 总分 0–100；
- 状态标签：Low / Moderate / High；
- 评分解释与主要驱动原因；
- 分项贡献占比；
- 近 30 天趋势；
- 指标详情图表。

##### Recovery v1.0 (Robust Baseline 个人偏差模型)
采用 28 天滚动中位数 (Median) 与绝对中位偏差 (MAD) 建立 robust 基线 z-score 评估：
- **HRV Component (35%)**：采用对数转换 (log transform) 评估 SDNN，防范过度训练引发的 Parasympathetic Rebound（副交感反弹扣分限制）。
- **RHR Component (25%)**：评估静息心率偏离 z-score，低于基线加分，高于基线扣分。
- **Sleep Component (25%)**：直接由昨晚 Sleep Score 转换贡献。
- **Prior Strain Component (15%)**：昨日活动负荷对今天恢复的合理折损。
- **Red Flag Modifiers (异常扣分项)**：体温异常升高 (bodyTempDelta >= 0.5°C)、SpO2 偏低 (<94%)、呼吸率异常升高 (respiratoryRateZ >= 1.5) 进行综合扣分修正。

##### 页面结构建议
- 顶部 Recovery Ring / Number；
- 当前状态解释；
- 因子拆解卡片；
- HRV 30 天趋势；
- RHR 30 天趋势；
- Sleep contribution；
- Previous day strain contribution；
- AI Recovery Insight。

---

#### 6.1.6 Strain 页面

##### 目标
构建全天生理耗力负荷与长期训练状态双层评估体系。

##### 必须展示
1. 今日 Daily Strain 总分 (0-100)；
2. 耗力进度条或负荷目标区；
3. 今日 Workouts（包含每次运动的心率分布）；
4. 步数与非运动活动热量；
5. 近期负荷可持续性 (Training Load Status)；
6. AI 训练强度与调整建议。

##### Daily Strain & Training Load v1.0
- **Daily Strain Score (0–100)**：每日综合耗力。将 Workout Load（心率区间 Zone/TRIMP 积分）与 Non-workout Load（步数、活动热量、锻炼时间积分）相加得到 dailyLoad，随后基于 exponential decay 模型 `100 * (1 - exp(-0.75 * (dailyLoad / baseline)))` 稳定映射至 0-100。
- **Training Load Status (ACWR)**：计算最近 7 天急性负荷 (acute) 与前 28 天慢性负荷 (chronic) 的比例。判定训练负荷健康度：wellBelow (低负荷)、below (减量)、optimal (最佳区间 0.85-1.2)、elevated (过度)、highRisk (高风险 >1.5)，防范伤病风险。

---

#### 6.1.7 Stress 页面 / Stress 卡片

##### 生理压力指数 Physiological Stress Index v1.0
生理学压力状态的综合量度，明确界定为生理压力代理，而不是医学心理压力诊断。

##### 算法架构
融合 6 因子生理学权重模型：
- RHRStress (25%)：评估低活动心率相对基线偏离。
- HRVStress (25%)：评估 HRV 抑制程度（低于基线则高压）。
- RespStress (15%)：评估呼吸率相对偏离。
- TempStress (10%)：体温偏离修正。
- SleepDebtStress (15%)：由睡眠不足加权。
- LoadStress (10%)：由今日 Strain 物理负荷加权。
- **运动屏蔽规则**：运动期间以及运动后 90 分钟内自动屏蔽压力计算，以排除物理训练心率干扰。

##### 展示
- 今日 Stress Index；
- 日内 Stress 变化曲线；
- 当前状态描述 (Calm / Normal / Elevated / High)；
- AI 生理压力成因解读。

---

#### 6.1.8 Energy Bank

##### 身体能量电池 v1.0
综合多维指标，模拟人体可用“电量”的充放电模型。

##### 算法流程
1. **Morning Energy (初始电量)**：清晨醒来时的身体电量，基于 `0.45 * RecoveryScore + 0.35 * SleepScore + 0.20 * OvernightStability` 计算。
2. **Day Drain (日内消耗)**：电量随一天活动逐渐递减：
   - 物理活动消耗：`0.35 * StrainScore`
   - 生理紧绷消耗：`0.25 * StressIndex`
   - 时间自然衰减：基于醒来时间 `hoursSinceWake / 16 * 12` 扣减
   - 训练累积负荷消耗：依据 Training Load Status（超负荷额外扣减 5-10 分）
3. **Recharge (充电补偿)**：记录 Mindful Minutes (正念正向补电) 或 nap (小憩) 进行能量修复 (上限 +8)。
4. **当前能量**：截断在 `0-100` 范围，展示 Depleted / Low / Stable / Strong 状态。

---

#### 6.1.9 Biological Age / Health Age Trend

##### 生理与健康年龄评估 v1.0
解耦为两个核心表达层，保持严谨与科学：
- **Health Age Trend (健康趋势 Beta)**：利用 VO₂ Max、RHR、睡眠、步数、体脂、肌肉量等可穿戴核心指标的 90 天滚动趋势方向，综合评定当前健康轨迹为：Improving (改善)、Stable (稳定) 或 Worsening (恶化)，引导用户关注正向行为。
- **Biological Age Estimate (Levine PhenoAge 临床化验模式)**：仅在用户手动录入足够且高保真的 9 项临床化验指标时启用 (albumin 蛋白, creatinine 肌酐, glucose 血糖, CRP 反应蛋白, lymphocytePercent 淋巴百分比, MCV 平均红细胞体积, RDW 红细胞分布宽度, alkalinePhosphatase 碱性磷酸酶, WBC 白细胞计数)。基于 PhenoAge 经典衰老模型和严格单位换算，输出具有学术支撑的生物年龄估计，无足够化验单时强制显示 pending state/缺省指引，拒绝盲目猜测。

---

#### 6.1.10 Journal

##### 第一版交互
- 标签选择；
- 自由文本输入；
- AI 后续可维护和总结用户经历。

##### 默认标签
- 咖啡
- 酒精
- 晚饭过晚
- 熬夜
- 午睡
- 运动
- 主观疲劳
- 情绪
- 生病 / 不适
- 自定义事件

##### Journal 用途
- 供 AI 分析行为与指标之间的关系；
- 作为 Weekly Review 的上下文；
- 后续用于维护用户 Wiki。

---

#### 6.1.11 AI Health Coach

##### 三种能力
1. 即时问答；
2. 主动生成固定报告；
3. 长期教练式分析。

##### 第一版固定报告
- Morning Brief；
- Sleep Review；
- Workout Readiness；
- Weekly Review。

##### 回答风格
- 先给结论；
- 再给数据依据；
- 最后给建议；
- 语气理性、温和、克制；
- 不做医学诊断。

---

#### 6.1.12 Agent Wiki / Memory 系统

##### 第一版使用多文件 Markdown Wiki
目录建议：
- profile.md
- goals.md
- habits.md
- training_history.md
- health_context.md
- notes.md

##### 用途
- 提供静态个人背景；
- 补充 HealthKit 无法直接获取的信息；
- 让 AI 长期理解用户。

##### Bevel 3.0 Files 对标要求
Bevel 3.0 用 Files 替代 Memory。Vela 不直接复制 Files，而把 Wiki 升级为用户可读的 Memory：

- 每个 Wiki 文件显示更新时间、来源、完整度；
- Agent 自动更新 Wiki 必须留下 AIReport / WikiChange 审计记录；
- Coach/Intelligence 首页必须显示 Wiki 状态；
- 生理基线 `baselines.md` 属于 Wiki，但需要从 SwiftData 历史指标自动生成；
- Wiki 写入原则：只记录长期偏好、稳定模式、明确目标、重要限制，不记录单日噪声。

---

### 6.2 第一阶段 Out of Scope
以下功能不在第一阶段：
- 家庭共享；
- 登录注册；
- 云同步；
- Web 控制台；
- 饮食 Nutrition；
- App Store 商业化打包；
- 后端服务；
- 医疗诊断；
- Apple Watch 独立 App；
- Widget；
- complication；
- PDF 导出；
- 用户自行编辑复杂评分权重 UI。

---

## 7. UI / 设计方向

### 7.1 视觉气质
- Apple 的克制与层次；
- Claude 的温暖与精致；
- Bevel 的数据密度与高级感。

### 7.2 UI 关键词
- Minimal
- Premium
- Calm
- Data-rich but not noisy
- Soft gradients
- Rich cards
- Clear hierarchy

### 7.3 Stitch 使用策略
Stitch MCP + Stitch Skills 用于：
- 生成 Home / Sleep / Recovery / Strain / Coach 原型；
- 参考 Bevel 的信息架构与卡片密度；
- 保持 Apple + Claude 风格；
- 最终输出供 SwiftUI 实现的视觉稿与组件设计。

---

## 8. 非功能要求

### 8.1 性能
- Dashboard 首屏打开流畅；
- 近 30 天数据加载在可接受范围内；
- 长趋势计算应异步执行。

### 8.2 隐私
- 数据默认本地；
- 无后端；
- LLM 请求只发送摘要化后的结构化指标；
- API Key 使用 Keychain 存储。

### 8.3 可扩展性
- Scoring Engine 可替换；
- AI Provider 可替换；
- HealthKit Query Service 可新增数据类型；
- 后续可加入饮食、家庭共享和云同步。

---

## 9. 里程碑定义

### M0 — 文档与设计约束 ✅
- ✅ PRD, 技术架构, Agent Spec, Stitch Brief

### M1 — HealthKit 数据层 ✅
- ✅ 授权, 查询, 数据标准化, 本地存储

### M2 — 核心 UI ✅
- ✅ Home, Sleep, Recovery, Strain

### M3 — 扩展模块 ✅
- ✅ Stress, Energy Bank, Health Age Trend, Journal

### M4 — AI Coach ✅
- ✅ DeepSeek Provider, Prompt/agent.md, 上下文组装, 固定报告, 历史报告存储
- ✅ VelaBackend (Vapor 4) 提供 Claude API 代理

### M5 — Training Intelligence Beta Convergence ✅
- ✅ TrainingAnalyticsService, RecoveryTrainingAdapter, ExerciseLibraryService
- ✅ StrengthWorkoutLogSheetView, FitnessActivitySummaryDetailView
- ✅ 训练事实层、分析层、恢复联动层模型

### M6 — Training Intelligence Full (进行中)
- ❌ ActiveWorkoutSession 实时训练记录
- ❌ WorkoutTemplateRecord 模板系统
- ❌ TrainingResponseRecord 第二天反应模型
- ❌ WeeklyBodyReport 个人身体理解系统
- ❌ MemoryProposal → Wiki 确认流产品化

### M7 — Bevel Parity 打磨 (进行中)
- ✅ 首页 cockpit, 白卡驾驶舱, 三环仪表
- ✅ 指标详情页 (Strain/Recovery/Sleep/Stress/Energy)
- ✅ Vitals 单指标详情 (HRV/RHR/Sleep HR/SpO2/Weight)
- ⚠️ Biological Age 置信度/新鲜度/贡献因子
- ⚠️ VO₂ Max / Body Fat / BMI drilldowns

---

## 10. 产品最终判断
Vela 的第一阶段目标不是”商业化成功”，而是：
- ✅ 做出一个你自己真愿意每天使用的 App；
- ✅ 完成一次高质量 iOS + HealthKit + AI Agent 的完整产品实践；
- 🟡 为未来 App Store、创业化或家庭健康扩展保留空间。

## 11. 当前优先级（2026-06-02）

1. **Training Intelligence 完善**: ActiveWorkoutSession 训练中体验、模板系统、反应模型。
2. **Personal Body Intelligence**: WeeklyBodyReport、MemoryProposal → Wiki 确认流产品化。
3. **Coach 体验打磨**: PersonalResponseInsight 周报集成验证、session continuity。
4. **Biology 可信化**: 置信度、新鲜度、贡献因子、健康记录路线。
5. **真机体验打磨**: 底部安全区、长文本、空状态、后台任务、通知。
