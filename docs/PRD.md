# PRD.md
# Project Vela — Local-first AI Health Coach for Apple Health

> Updated: 2026-05-23  
> Current product target: Bevel 3.0-class health companion, differentiated by local-first architecture and a user-readable, agent-maintained Wiki. Research basis: `docs/BEVEL_3_RESEARCH.md`. Full product blueprint: `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`.

## 0. 当前构建状态

截至 2026-05-23，Vela 已不再是 MVP 骨架，而是一个可在真机运行的本地优先健康助手：

- iOS SwiftUI + SwiftData + HealthKit 主工程可编译通过；
- 已有 Home / Journal / Fitness / Vitals / `+` Intelligence 五个主 Tab，Sleep / Recovery / Strain 作为能力和详情页继续存在；
- 已实现 Sleep、Recovery、Strain、Stress、Energy Bank、Health Age、Biological Age 等评分引擎；
- 已实现 HealthKit 多维数据读取、日摘要缓存、AI 报告、Journal、Coach session、训练计划、生物标志物记录；
- 已实现 DeepSeek Provider、Kimi Vision Food Photo Analyzer、结构化 FoodLog、AIContextBuilder、流式 Coach、Coach Personality、Agent tools、Web Search Service；
- 已实现 user Wiki、夜间 Wiki 同步 Agent、晨间简报、主动洞察、通知配置；
- Home 已加入 Daily Plan 与 Readiness Brief，用“状态、原因、下一步行动”承接 Bevel-style daily loop；
- 2026-05-23 当前 UI 已从旧 dark dashboard 转向 Bevel-like 浅色系统：Home 首屏、Tab bar、共享卡片材质、Journal / Fitness / Vitals / Intelligence 主入口正在按同一视觉语言收敛；
- 真机镜像体验显示旧构建仍偏深色卡片，最新浅色构建需要重新安装到手机后继续逐页校准。

本 PRD 后续按“已具备基础能力，继续打磨成完整产品”来定义，而不是按从零开发定义。

## 1. 产品概述

### 1.1 项目代号
Vela

### 1.2 一句话定位
一个 local-first、Bevel-inspired 的 iOS 健康分析 App：读取 Apple Health / Apple Watch 数据，复刻 Recovery、Sleep、Strain 等核心健康体验，并以内置 AI Health Coach 提供个性化解释与建议。

### 1.3 产品愿景
让用户拥有一个真正理解自己身体数据的私人 AI 健康教练。

Vela 不只是展示健康数据，而是要完成三件事：
1. 把 Apple Health 中分散的身体数据组织成可理解的健康状态；
2. 通过评分体系与趋势分析，帮助用户理解睡眠、恢复、负荷和压力；
3. 通过 AI Health Coach，将数据解释为具体、克制、个性化的行动建议。

---

## 2. 竞品参考与产品策略

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
- 产品作者本人；
- 少量愿意测试的朋友；
- 使用 iPhone + Apple Watch；
- 对睡眠、恢复、运动负荷、健康趋势感兴趣；
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

##### Sleep Score v0.1
第一版主要基于：
- 睡眠总时长是否接近目标；
- 睡眠规律性；
- 夜间清醒时间和睡眠阶段比例保留为可扩展因子，当前不重度参与评分。

##### 页面结构建议
- 顶部 Sleep Score；
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
- 评分解释；
- 分项贡献；
- 近 30 天趋势；
- 指标详情图表。

##### Recovery v0.1 因子
- HRV Score
- Resting Heart Rate Score
- Sleep Score
- Prior Strain Score

具体权重不在第一版写死，采用可配置系数。

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
构建接近 Bevel / Whoop 的全天负荷视图。

##### 必须展示
1. 今日 Strain 总分；
2. Strain 进度环或能量条；
3. 今日所有 Workout；
4. 活动能量；
5. AI 运动建议；
6. 今天是否达到推荐负荷。

##### Strain v0.1 设计原则
综合：
- Workout Load；
- Active Energy；
- Exercise Time；
- Workout HR profile。

第一版要做“全天负荷”，哪怕算法仍是粗糙版。

---

#### 6.1.7 Stress 页面 / Stress 卡片

##### 第一版定义
Stress 是“生理压力代理指标”，不是医学压力诊断。

##### 输入
- HRV 短期波动；
- Heart Rate 相对基线偏移；
- 当前活动上下文；
- 睡眠不足与近期活动负荷。

##### 展示
- 今日 Stress Index；
- 日内 Stress 变化曲线；
- 当前状态描述；
- AI 解读。

---

#### 6.1.8 Energy Bank

##### 第一版定义
把 Sleep、Recovery、Strain、Stress 汇总成“身体电量”。

##### 第一版展示
- Morning Energy；
- Current Energy；
- 文本解释；
- 后续再做更细粒度完整日内曲线。

---

#### 6.1.9 Biological Age / Health Age Trend

##### 第一版策略
不输出强结论式“你的生理年龄是 X 岁”，而输出：
- Health Age Trend；
- 长期健康趋势 Beta；
- 体现趋势改善 / 恶化方向。

##### 可参考输入
- VO₂ Max；
- Resting Heart Rate baseline；
- HRV baseline；
- Weight trend；
- Body Fat；
- Lean Body Mass；
- 睡眠与活动长期趋势。

##### 页面表达
- Health Age Trend Beta；
- 当前趋势：Improving / Stable / Worsening；
- 影响趋势的主要因子；
- AI 长期健康解释。

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

### M0 — 文档与设计约束
- 完成 PRD；
- 完成技术架构；
- 完成 Agent Spec；
- 完成 Stitch Brief。

### M1 — HealthKit 数据层
- 授权；
- 查询；
- 数据标准化；
- 本地存储。

### M2 — 核心 UI
- Home；
- Sleep；
- Recovery；
- Strain。

### M3 — 扩展模块
- Stress；
- Energy Bank；
- Health Age Trend；
- Journal。

### M4 — AI Coach
- DeepSeek Provider；
- Prompt / agent.md；
- 上下文组装；
- 固定报告；
- 历史报告存储。

### M5 — 体验打磨
- UI 细化；
- 错误处理；
- 评分参数调优；
- 真机长期试用。

---

## 10. 产品最终判断
Vela 的第一阶段目标不是“商业化成功”，而是：
- 做出一个你自己真愿意每天使用的 App；
- 完成一次高质量 iOS + HealthKit + AI Agent 的完整产品实践；
- 为未来 App Store、创业化或家庭健康扩展保留空间。

## 11. 当前优先级

1. Intelligence 工作台：把 Coach 从聊天页升级为 chat + check-ins + Wiki + artifacts + tools。
2. Home 首屏收敛：状态、原因、今日计划、数据置信度。
3. Training 计划实体化：日历、训练卡、恢复感知改期。
4. Biology 可信化：手动血检、置信度、新鲜度、健康记录路线。
5. Nutrition 产品化：已完成照片识别后的结构化保存和回看，继续补齐份量编辑、置信度、日/周营养趋势。
6. 真机体验打磨：底部安全区、长文本、空状态、后台任务、通知。
