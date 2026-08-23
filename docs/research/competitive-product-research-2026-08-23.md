# 消费级健康产品竞争研究与 Vela 全量更新计划

> 研究日期：2026-08-23  
> 研究对象：Apple Health / Apple Fitness、Oura、WHOOP、Gentler Streak、Bevel  
> 方法：只引用产品官网、官方帮助中心、官方发布说明、Apple 官方开发文档与 App Store 产品页。本文中的“来源事实”是页面明确表达或产品页可直接观察到的内容；“对 Vela 的推论”是基于这些事实提出的产品判断，不是竞品声称。

## 0. 结论先行

Vela 当前最需要的不是继续增加零散指标，而是完成一次“产品承诺、品牌表达、首日价值、每日决策和 AI 行动闭环”的统一更新。成熟产品的共同点不是功能最多，而是让用户很快知道：

1. 这个产品替我解决哪一个具体问题；
2. 今天打开后我应该看什么、做什么；
3. 它的分数如何连到行动；
4. 它怎样处理不确定性、隐私和用户控制。

建议把 Vela 暂时视为内部产品代号，并把公开产品承诺收敛为：**每天用可信的身体简报回答‘我现在怎么样、最近变了什么、今天需要怎么调整’。** `Today` 负责当前，`Trends` 负责变化，`Plan` 负责行动，`Coach` 负责解释；这比把四个 Tab 解释成四个功能集合更容易形成产品心智，也避免用 App 名称命名一个用户无法预判用途的 Tab。

## 1. 研究边界与 Vela 当前基线

### 1.1 仓库约定

仓库的文档导航规定：`docs/PRD.md` 是唯一当前产品规格，`CONTEXT.md` 是唯一领域术语表，`docs/archive/` 是历史档案，不能作为当前实现依据。因此本文存放于 `docs/research/`，不改动现有规格、代码或其他文档。

### 1.2 Vela 当前基线（仓库事实）

依据 [`docs/PRD.md`](../PRD.md) 与 [`CONTEXT.md`](../../CONTEXT.md)，Vela 当前定位是建立在 Apple Health 之上的个人身体面板与 AI 健康分析助手，价值顺序是“看见数据 → 理解状态与趋势 → Agent 联系信号解释 → 在需要时给训练与生活建议”。其北极星是 `Trusted Health Brief Day`，要回答“我现在总体怎么样、最近发生了什么、是否需要行动”。当前四个工作区是 Today、Trends、Vela、Training；本地确定性引擎负责评分与安全边界，AI 负责解释与候选假设，计划变更必须用户确认。

这些是 Vela 的现有产品意图，不是本轮竞品研究推论。后文建议应与这些不可违背的边界兼容，尤其是：不做医疗诊断、不伪造数据、不把 AI 生成建议静默写入正式计划、不把单一总分当作健康真相。

## 2. 竞品速览矩阵

| 产品 | 名称/品牌可观察到的承诺 | 核心产品循环 | AI/教练形态 | 留存与付费 | 信任表达 |
|---|---|---|---|---|---|
| Apple Health | “Health”是个人健康信息的中心与控制面；Apple Fitness 是活动、训练、趋势与奖励入口 | 设备/HealthKit 汇聚 → Summary/Highlights/趋势 → 目标、训练、分享 | Fitness+ 是内容教练与 Custom Plans，不是开放式健康诊断 AI | Health 免费；Fitness+ 订阅、家庭共享、免费试用、奖励 | 设备端/端到端加密、细粒度权限、用户控制分享 |
| Oura | “Ring”是传感器，Oura App 是个人健康 companion；三项日分数让身体状态可读 | 夜间/全天采集 → Sleep/Activity/Readiness → 标签、Rest Mode、建议 | Oura Advisor 是基于个人短长期数据、手动输入与历史互动的 LLM 助手 | Ring + Membership；标签、目标、趋势、Circles、持续功能更新 | 会员数据控制、数据删除、健康功能与医疗边界清楚 |
| WHOOP | 全大写 WHOOP 作为设备/会员平台；使命是 unlock human performance and Healthspan | 连续采集 → Sleep/Recovery/Strain → 每日目标/训练与 Journal → 次日反馈 | WHOOP Coach 结合生物指标、目标、习惯和生成式 AI；支持个性化问答 | 设备绑定会员；试用、分层 Membership、团队与社交 | 会员隐私原则、第三方 LLM 零保留/零训练政策（以官方政策为准） |
| Gentler Streak | “gentler”直接表达温和、可持续；“Streak”把持续性保留但不把休息视为失败 | HealthKit 读取 → Activity Path/Readiness → 建议运动或休息 → 复盘 | 专家式 Insights 与规则建议，非聊天 AI 主导 | 免费 + Premium；状态（休息/生病/受伤/休假）保护连续性 | 数据留在设备端、不外部处理；明确非医疗器械 |
| Bevel | “Connected Health Coach”把数据连接与教练放在品牌中心；产品名短、适合做 app/icon 品牌 | Apple Health/设备 → Recovery/Sleep/Strain 等 → Journal/趋势 → AI 行动 | Bevel Intelligence：聊天、Files、Artifacts、人格、Check-ins、计划与确认式 Food Cart | 免费完整追踪 + Pro 解锁 AI/Health Records/Biological Age；AI 有周额度 | AI 错误可点踩反馈；健康数据/文件可编辑删除；动作需用户确认 |

表格中的具体事实来源：Apple [`HealthKit`](https://developer.apple.com/documentation/healthkit)、[`Apple Health App Store`](https://apps.apple.com/us/app/apple-health/id1242545199)、[`Apple Fitness App Store`](https://apps.apple.com/us/app/apple-fitness/id1208224953)；Oura [`How it works`](https://ouraring.com/how-it-works)、[`Oura App App Store`](https://apps.apple.com/us/app/oura/id1043837948)、[`Membership`](https://support.ouraring.com/hc/en-us/articles/4409086524819-Oura-Membership)；WHOOP [`About`](https://www.whoop.com/us/en/about/)、[`WHOOP App App Store`](https://apps.apple.com/us/app/whoop/id933944389)、[`Membership Features`](https://support.whoop.com/s/article/Membership-Features-Benefits?language=en_US)；Gentler [`官网`](https://gentler.app/)、[`App Store`](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)、[`Documentation`](https://docs.gentler.app/)；Bevel [`官网`](https://www.bevel.health/)、[`App Store`](https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249)、[`Membership & Pricing`](https://help.bevel.health/en/articles/11583937)、[`Intelligence FAQ`](https://help.bevel.health/en/articles/11586753)。

## 3. 来源事实与产品解读

### 3.1 Apple Health / Apple Fitness：平台型信任与“先理解、后授权”

**来源事实**

- Apple 将 HealthKit 定义为 iPhone 和 Apple Watch 上健康与健身数据的中心仓库；用户授权后，应用才能读写，并且 HealthKit 会合并多来源数据，允许用户在 Health 中删除数据、改变权限。见 [`HealthKit`](https://developer.apple.com/documentation/healthkit)。
- Apple 要求健康应用按数据类型请求权限；用户可以逐项允许或拒绝，应用不能知道“拒绝读取”与“没有该数据”的区别。见 [`Protecting user privacy`](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) 与 [`Authorizing access`](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)。
- Apple HIG 建议只在需要时请求健康数据、用简洁文字解释用途、使用系统权限页面，并让用户在系统隐私设置中统一管理授权；不要在应用内复制一套会造成混淆的权限管理。见 [`HealthKit HIG`](https://developer.apple.com/design/human-interface-guidelines/healthkit)。
- Health App Store 页把产品描述为“中心且安全、由用户控制”的健康信息空间，并突出时间图表、Highlights、趋势、睡眠、心理状态和健康记录。见 [`Apple Health App Store`](https://apps.apple.com/us/app/apple-health/id1242545199)。
- Fitness+ 提供 12 类训练、5–45 分钟内容、实时指标、基于偏好的推荐和 Custom Plans；Fitness App Store 页另外强调 Summary、目标、训练详情、Awards、分享和可暂停的活动环。见 [`Apple Fitness+`](https://www.apple.com/apple-fitness-plus/) 与 [`Apple Fitness App Store`](https://apps.apple.com/us/app/apple-fitness/id1208224953)。
- Apple 的健康隐私原则包括数据最小化、尽可能设备端处理、透明与控制、安全；健康数据在设备锁定时加密。见 [`Consumer Health Personal Data Privacy Policy`](https://www.apple.com/legal/privacy/consumer-health-personal-data/en-ww/)。

**对 Vela 的推论**

1. Vela 依赖 Apple Health，首日体验必须先解释“读哪些数据、为什么读、数据是否会离开设备”，再分批触发权限，而不是一次性索取全部授权。
2. Vela 应把“数据覆盖度”做成用户可理解的产品状态：缺少 HRV 不是静默变成 0，而是显示“本次判断基于哪些证据、哪些证据不可用、置信度怎样”。
3. Apple 解决“数据在哪里”，Vela 应避免复制 Health 的资料仓库定位，集中解决“这些变化对今天意味着什么”。
4. Fitness+ 的 Custom Plans 和 Awards 说明“持续性”可以靠明确计划与反馈建立；Vela 更适合把奖励从打卡次数转为“完成一次可信简报/做出一次合适调整”，与自身北极星一致。

### 3.2 Oura：用三个日分数建立固定的晨间仪式，再把解释逐渐交给 Advisor

**来源事实**

- Oura 官网以“Spend a day with Oura”组织体验：早晨查看 Readiness/Sleep，白天记录活动并可加入 Circles，压力时寻找平衡，睡前由 Oura 解释睡眠并帮助定义作息。见 [`How it works`](https://ouraring.com/how-it-works)。
- Oura App Store 把三项日分数（Sleep、Activity、Readiness）作为核心入口，并把它们连接到个性化指导、Rest Mode、压力韧性、标签和周期洞察。见 [`Oura App`](https://apps.apple.com/us/app/oura/id1043837948)。
- Readiness Score 明确同时看短期与长期指标，包括夜间静息心率/时间、体温、睡眠质量、前日活动、HRV、睡眠和活动平衡。见 [`Readiness Score`](https://support.ouraring.com/hc/en-us/articles/360025589793-An-Introduction-to-Your-Readiness-Score)。
- Oura Advisor 官方介绍称其使用个人短期/长期数据、手动输入和历史互动，能回答问题、绘制趋势图、创建目标计划；用户可选择 conversational 或 direct 语气和 check-in 频率，同时官方明确提醒 LLM 可能出错。见 [`Introducing Oura Advisor`](https://ouraring.com/blog/oura-advisor/)。
- Oura 通过 Labs 先测试 Advisor，再正式向会员开放；官方发布提到测试期有高频使用和可靠性反馈，但这属于 Oura 自报数据，不应当作行业基准。见 [`Advisor in Action`](https://ouraring.com/blog/how-to-use-oura-advisor/)。
- Oura Membership 以 Ring + 会员共同构成体验，提供月付/年付与新用户首月；官方帮助中心同时说明会员管理和数据导出入口。见 [`Oura Membership`](https://support.ouraring.com/hc/en-us/articles/4409086524819-Oura-Membership)。

**对 Vela 的推论**

1. Vela 应设计一个固定的“晨间可信简报”仪式，首屏只回答状态、变化、行动，避免用户先在多个图表中找答案。
2. Vela 可借鉴“总览分数 + 贡献者”的结构，但不应退回单一健康总分；五项独立 Scored Health Evidence 必须保留方向、证据、覆盖度和不确定性。
3. AI 入口应同时存在于全局工作台和具体洞察上下文中：用户可以主动问，也能从一条异常趋势直接进入“为什么/接下来怎么办”。
4. 语气个性化值得做，但必须是表达层设置，不得改变健康安全边界或算法结论；Vela 可先提供“简洁/解释型/直接”三档，后续再扩展。
5. Oura 的标签/目标/Rest Mode 把主观生活上下文接入指标解释；Vela 的 Daily Check-in、Lived State 和 Memory Proposal 可形成同类闭环，但要坚持“候选关联，不宣称因果”。

### 3.3 WHOOP：把“准备承受多少负荷”做成极强的核心循环

**来源事实**

- WHOOP 官方使命是“unlock human performance and Healthspan”，并以 Sleep、Strain、Recovery 的相互关系解释身体状态；创始故事把“过度训练、不知道何时该恢复”定义为原始问题。见 [`About WHOOP`](https://www.whoop.com/us/en/about/)。
- Recovery 是早晨的每日准备度，按百分比与绿/黄/红区间表达；其输入包括 HRV、静息心率、睡眠表现和呼吸率等。见 [`How Does WHOOP Recovery Work`](https://www.whoop.com/us/en/thelocker/how-does-whoop-recovery-work-101/)。
- Strain 是全天生理负荷，WHOOP 说明它不仅包含正式训练，也会纳入持续心率下的日常活动和压力，并根据 Recovery 给出每日目标范围。见 [`Strain explained`](https://www.whoop.com/us/en/thelocker/grosicki-strain-explained/) 与 [`Strain Coach`](https://www.whoop.com/us/en/thelocker/how-does-whoop-strain-work-101/)。
- WHOOP App Store 页把“连续数据 → Sleep/Recovery/Strain/Stress → 睡眠时间与行为建议 → Coach”直接写成产品价值，并强调设备无屏、数据在 app 中；还提供 Journal、Weekly Plan、团队和 Apple Health 集成。见 [`WHOOP App`](https://apps.apple.com/us/app/whoop/id933944389)。
- WHOOP Coach 官方说明把 24/7 生物指标与目标、习惯和用户上下文结合，提供实时个性化建议；隐私政策称第三方 LLM 对 WHOOP 指标采取零保留/零训练政策，并允许删除 Coach 对话。见 [`WHOOP AI guidance`](https://www.whoop.com/us/en/thelocker/new-ai-guidance-from-whoop/) 与 [`Full Privacy Policy`](https://www.whoop.com/us/en/full-privacy-policy/)。
- WHOOP 采用设备 + 会员模式，官方条款说明会员包括设备、App 及恢复/睡眠/负荷等服务，并提供不同期限与层级。见 [`Terms of Use`](https://www.whoop.com/us/en/whoop-terms-of-use/) 与 [`Membership Features`](https://support.whoop.com/s/article/Membership-Features-Benefits?language=en_US)。

**对 Vela 的推论**

1. Vela 的差异化问题也应足够尖锐：不是“我有很多健康数据”，而是“今天我的身体适合承受什么，以及为什么”。
2. Today 应把 Body State 连接到 Training Decision 和 Daily Operating Plan，形成类似“恢复告诉我能承受什么、负荷告诉我实际做了什么、次日再校准”的可重复循环。
3. Vela 不应照搬 WHOOP 的单一 Recovery/Strain 心智。其自身五项证据的独立语义必须可解释，尤其不能把 Strain 与 Stress 或 Energy 误合成为同一好坏分数。
4. Journal 的价值不是让用户多填表，而是让行为上下文能在后续趋势里被检验。Vela 的 Post-Training Check-in 应保持可跳过、延后补录，并在得到后续数据时反馈“你的主观感受与客观状态是否一致”。
5. 会员策略可借鉴“免费可见、付费获得解释与行动”，但 Vela 需要先证明本地 Apple Health 数据能在首日产生价值，不能用权限墙替代产品价值。

### 3.4 Gentler Streak：用“温和但持续”改写健身留存逻辑

**来源事实**

- Gentler Streak 官网的核心文案是“puts your well-being first”“consistency, not constantly”，并称建议根据当天能力适配用户，而不是让用户适配固定目标。见 [`Gentler Streak 官网`](https://gentler.app/)。
- 官网把 Activity Path、Readiness、运动建议、休息/主动恢复、状态（resting、sick、injured）和训练图表组织在同一套体验中；休息会保留长期持续性，而不是让用户因休息产生失败感。见 [`Gentler Streak 官网`](https://gentler.app/) 与 [`Documentation`](https://docs.gentler.app/)。
- App Store 页明确称健康/健身数据通过 Apple HealthKit 保持在设备端、不进行外部处理，并声明产品不是医疗器械、不能替代专业医疗建议。见 [`Gentler Streak App Store`](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)。
- 产品采用免费 + Premium 内购；官方文案把 Apple Watch、Activity Path、workout summaries、Insights、状态与持续运动作为核心体验。见 [`App Store`](https://apps.apple.com/us/app/gentler-streak-workout-tracker/id1576857102)。

**对 Vela 的推论**

1. Vela 的“健康节律优先”不是抽象价值观，应像 Gentler 的休息状态一样成为可见、可操作、可被系统尊重的产品状态。
2. 留存不应奖励连续打开或连续训练，而应奖励“做出适合当日状态的选择”；稳定日不需要强行制造新任务。
3. “休息/生病/受伤/暂停”应进入首日和日常导航的设计，而不是只埋在设置中；它们能降低用户因数据异常或断档而放弃的心理成本。
4. Gentler 的 on-device 叙事为 Vela 提供了清晰的信任参照。若 Vela 使用云端 LLM，必须在每个 AI 入口明确发送了什么、为什么发送、能否删除和是否用于训练。

### 3.5 Bevel：功能最接近 Vela 的对标，优势在 AI 纵向整合，风险在复杂度

**来源事实**

- Bevel 官网将自己定位为“Connected Health Coach”，按 Strain、Sleep、Recovery 等身体信号解释“从身体信号到清晰、可执行的指标”，并使用“Start the day with confidence”作为场景承诺。见 [`Bevel 官网`](https://www.bevel.health/)。
- App Store 页把 Bevel Intelligence 描述为连接数据、即时反馈和个性化建议的智能健康引擎；当前产品页还列出 Files、Personalities、Check-ins、Artifacts、对话式食物记录、训练计划与 Strength Templates 等能力。见 [`Bevel App Store`](https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249)。
- Bevel 帮助中心将 Health Records 与 Files 分开：Health Records 是健康/化验文档，Files 是 AI 用来组织偏好、目标、计划和产物的持久上下文；AI 支持人格、check-in、思考模式、Ghost Mode、计划和图表等。见 [`Bevel Intelligence`](https://help.bevel.health/en/categories/2368129-bevel-intelligence) 与 [`Common Questions`](https://help.bevel.health/en/articles/11586753)。
- Bevel 的 Food Cart 不会自动写入营养日志，用户必须 Review Cart 后确认；AI 错误或不完整回答可通过 thumbs down 反馈。见 [`How to Log Food`](https://help.bevel.health/en/articles/11247745) 与 [`Intelligence Common Questions`](https://help.bevel.health/en/articles/11586753)。
- Bevel 采用 Free + Pro：免费提供完整追踪（Recovery、Sleep、Strain、Stress、Nutrition、Strength 等），Pro 解锁 AI、Health Records、Biological Age；AI 还有按周重置的使用额度。见 [`Membership & Pricing`](https://help.bevel.health/en/articles/11583937)。
- Bevel 的通知包括晨间 Sleep/Recovery summary、目标就寝、Strain 达标、Journal、AI responses ready 和 Check-ins。见 [`Notification Settings`](https://help.bevel.health/en/articles/10430849)。

**对 Vela 的推论**

1. Bevel 证明“AI 不是独立聊天页，而是贯穿数据卡片、动作按钮、通知、文件和计划”的方向有竞争力；Vela 应让 AI 在 Today/Trends/Training 的上下文中可达，而不是只在 Vela Tab 等用户主动进入。
2. Bevel 的 Files/Artifacts 展示了可复用 AI 产物的价值，但也暴露出信息架构风险：Vela 应把 `Personal Health Brief` 作为唯一权威认知对象，AI 生成的报告、图表和洞察都作为可追溯的 `Coach Artifact`，不能形成第二套真相。
3. Food Cart 的确认式动作是 Vela `Plan Proposal → Explicit Confirmation → DailyOperatingPlanRecord` 的直接参照：任何影响计划、训练或外部数据的动作都必须可审阅、可撤销、可追踪。
4. Bevel 的免费“全量追踪 + Pro 解释/教练”结构适合 Vela 做商业验证，但 Vela 要避免过早复制大量功能；第一版付费价值应集中在高质量解释、长期趋势、Coach Artifacts 和计划校准。
5. AI 额度能控制成本，却会伤害健康助手的信任感。若 Vela 采用额度，必须在发送前透明显示消耗规则，并保证核心健康简报不因额度耗尽而消失。

## 4. 命名、Logo 与视觉识别的具体观察

### 4.1 来源事实（可观察层）

- Apple 使用“Health”“Fitness”这种系统级、功能直指型命名；其价值依赖操作系统、设备和 HealthKit 生态，而不是单独塑造一个拟人教练品牌。见 [`Health App Store`](https://apps.apple.com/us/app/apple-health/id1242545199)、[`Fitness App Store`](https://apps.apple.com/us/app/apple-fitness/id1208224953)。
- Oura 使用短的专有名词和环形硬件品牌；App Store 用“personal health companion”补足品牌含义，三个日分数是比 logo 更强的识别资产。见 [`Oura App`](https://apps.apple.com/us/app/oura/id1043837948)。
- WHOOP 使用全大写字标，产品说明反复强化 screenless wearable、会员和三大核心指标；其品牌资产主要是术语体系（Recovery / Strain / Sleep）与黑色无屏设备，而非 app 中大量视觉装饰。见 [`WHOOP App`](https://apps.apple.com/us/app/whoop/id933944389)、[`WHOOP Brand & Design Guidelines`](https://developer.whoop.com/assets/files/WHOOP%20-%20Brand%20%26%20Design%20Guidelines-bdea3554e94b4ea09e68695b1e8dc8e7.pdf)。
- Gentler Streak 的命名本身是产品理念：既保留 streak 的连续行为钩子，又用 gentler 限制“越多越好”的健身语义；官方视觉/文案围绕柔和、路径、状态与休息建立一致性。见 [`Gentler 官网`](https://gentler.app/)。
- Bevel 使用短专有名词，并在官网以“Connected Health Coach”解释品类；其 app 图标、深色渐变、橙色/暖色强调和圆形指标构成可识别的视觉语言（视觉部分为官方官网/App Store 素材的直接观察，不是 Bevel 对命名来源的官方解释）。见 [`Bevel 官网`](https://www.bevel.health/)、[`Bevel App Store`](https://apps.apple.com/us/app/bevel-all-in-one-health-app/id6456176249)。

### 4.2 对 Vela 的推论与选择建议

- “Vela”本身短、易读，可以承载航行/方向隐喻；但当前 App Store 已有多个健康与 wellness 产品使用相同名称，包括 AI 心理陪伴、断食、周期追踪和女性健康产品。见 [`Vela: AI Mental Health Coach`](https://apps.apple.com/us/app/vela-ai-menthal-health-coach/id6761783024)、[`Vela: Intermittent Fasting`](https://apps.apple.com/us/app/vela-intermittent-fasting/id6769411892)、[`Vela: Your Health`](https://apps.apple.com/us/app/vela-your-health/id6774885941) 与 [`Vela Wellness`](https://apps.apple.com/us/app/vela-wellness/id6761030710)。这不能替代商标法律检索，但已经足以判定搜索和口碑传播风险很高。
- **建议把 Vela 保留为内部代号，公开产品名进入强制命名决策门。** 在美国与中国 App Store、目标域名、社交账号、中文发音和基础商标检索通过前，不应把新 Logo 和 App Store 资产固化到 Vela 这个名称上。
- 如果最终仍决定保留 Vela，必须使用稳定的品类副标题：**Vela — Personal Health Brief**（中文“Vela｜个人身体简报”），并接受同名带来的获客和检索成本；这属于降级方案，不是首选。
- Logo 不应模仿 Apple 心形、Oura 环、WHOOP 字标或 Bevel 的圆形分数；建议建立一个能表达“身体信号被组织成方向”的独立符号，例如由两条平衡曲线构成的 `V`/horizon mark，避免把“健康”简化成心脏或十字。
- 视觉系统要优先服务状态可读性：Today 用一条 Rhythm Horizon 作为主视觉锚点；五项证据使用稳定色彩和形状编码；警示不能只依赖颜色，配合文字、图标和数据覆盖度。
- 品牌语气应介于 Apple 的克制、Gentler 的体贴、WHOOP 的决策清晰与 Oura 的陪伴之间；AI 不应使用“万能教练”或医疗权威口吻。

### 4.3 当前品牌资产审计（仓库事实）

当前不是“Logo 还不够漂亮”，而是存在三套互不一致的识别系统：

1. [`AppIcon.png`](../../VelaApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png) 是黑底、青蓝渐变的 `V` 形路径；
2. [`LaunchMark.svg`](../../VelaApp/Resources/Assets.xcassets/LaunchMark.imageset/LaunchMark.svg) 与 [`VelaLogoMark.swift`](../../VelaApp/Features/SharedComponents/VelaLogoMark.swift) 是紫色帆形符号；
3. [`VELA_DESIGN_LANGUAGE.md`](../VELA_DESIGN_LANGUAGE.md) 则把低饱和节律绿与 `Rhythm Horizon` 定义为正式品牌对象。

这会让 Home Screen、启动、应用内和营销物料像来自不同产品时代。新一轮更新必须先确定“名称 → 品类承诺 → 主符号 → 颜色/运动 → 产品主视觉”的单一系统，再做逐屏美化。

## 5. 首日体验与核心产品循环对照

### 5.1 成熟产品的共同首日模式

1. 先给一个可理解的承诺，再请求设备/健康权限（Apple HIG 明确建议权限应在需要时请求，见 [`HealthKit HIG`](https://developer.apple.com/design/human-interface-guidelines/healthkit)）。
2. 首屏展示少量稳定概念，而不是完整数据库：Apple 用 Summary/Highlights，Oura 用三项日分数，WHOOP 用 Sleep/Recovery/Strain，Gentler 用 Activity Path，Bevel 用 Recovery/Sleep/Strain 等核心模块。
3. 让用户完成一次低风险行动：查看晨间状态、选择休息/训练、添加标签或确认一条 AI 建议；不要要求用户先建立复杂计划。
4. 用后续数据反馈形成第二天的理由：睡眠/恢复/负荷会更新，标签与 check-in 会增加解释能力，计划会根据偏好和历史逐步个性化。

### 5.2 Vela 建议的首日体验

**Step 0：品牌承诺**

`Vela｜个人身体简报`  +  “把 Apple Health 的信号，变成今天值得相信的一句话和一个决定。”

**Step 1：最小权限分组**

- 必需组：睡眠、心率/HRV、活动/训练、体重（若用户启用相关功能）；
- 可选组：营养、周期、心理状态、临床记录；
- 每组前用一句话说明“读取什么 → 用来回答什么 → 是否离开设备”。

**Step 2：立即生成可用结果**

即使数据不完整，也展示一张“数据覆盖度卡”：已有信号、缺失信号、基线窗口、结论置信度；禁止空白首页或假精确分数。

**Step 3：首个 Trusted Health Brief**

显示：`当前 Body State`、`一个值得注意的变化`、`今天的 Training Decision / Daily Operating Plan`，每项最多 2–3 个证据。稳定日明确告诉用户“无需改变计划”也是完整结果。

**Step 4：一次可撤销的用户确认**

如果 AI 提出调整，只生成 `Plan Proposal`，让用户选择“接受/稍后/不适用”，并解释会改动什么；不在首日自动写入正式计划。

**Step 5：第二天回访**

用一条可选 Post-Training Check-in 或晨间摘要询问“昨天的建议是否符合你的实际感受”，把反馈纳入 Personal Response Model，但不把不填写解释为“无压力/无酸痛”。

## 6. 全量更新计划（16 周建设 + 28 天 Daily Driver）

### 6.0 目标产品定义

**品类**：Personal Health Brief / 个人身体简报，而不是健康数据仓库、训练记录器或万能 AI 医生。

**一句话承诺**：把 Apple Health 里的身体信号，变成今天可信的一句话、一个决定和可查看的依据。

**三条产品原则**：

1. **Evidence first**：结论必须显示来源、基线、窗口、Data Coverage 和不确定性；
2. **Quiet action**：稳定日可以没有任务；只有证据会改变 Daily Operating Plan 时才打扰用户；
3. **Learn with consent**：AI、Memory Proposal 和 Plan Proposal 都必须可审阅、可否定、可撤销。

**建议一级信息架构**：

```text
Today       我现在怎么样？
Trends      最近发生了什么？
Plan        今天做什么？（Daily Operating Plan，Training Decision 为下游）
Coach       为什么？还有什么候选解释？
    └── Profile / Trust / Data Coverage / Settings
```

这个方案保留四个清晰工作区，但进行两处关键修正：不再用 App 名称命名 AI Tab；不再让 Training 作为与 Personal Health Brief 平级的产品主线，而是进入有界的 `Plan`。

### Phase 0（第 0–2 周）：冻结扩张，重新定义品牌与产品承诺

**目标**：让名称、Logo、定位、导航和北极星说同一件事。

**交付物**

- 品牌简报：名称、副标题、承诺、非目标、语气、命名禁用词；
- 20–30 个候选名 → 5 个可用候选 → 1 个通过 App Store/域名/发音/基础商标筛查的公开名称；Vela 暂作内部代号；
- 3 条 Logo 方向：`Horizon`（承受范围）、`Signal to Direction`（信号变方向）、`Quiet Pulse`（克制的生命感），全部验证 29pt 小尺寸、单色、深色和 tinted appearance；
- Logo/图标/启动页/Widget/通知的视觉规范；
- 一页式产品故事：`信号 → 简报 → 解释 → 决定 → 反馈`；
- 统一术语表映射，禁止 “readiness/overall score/AI recommendation” 在不同页面表示不同对象；
- Today / Trends / Plan / Coach 三套低保真原型与一次真实数据走查；
- 停止新增 Biological Age、营养记账、手机内训练执行、天气装饰等非核心范围；仅修复阻断性问题。

**验收**

- 5 名未参与设计的人在 5 秒内能说出 Vela 是“从 Apple Health 生成个人身体简报和行动建议”，而不是普通运动记录器；
- 新名称不会与目标 App Store 的头部同名产品直接混淆，并完成独立法律检索待办；
- AppIcon、启动页、应用内 Logo、Widget 与 App Store 素材只使用同一个主符号；
- 任意核心页面都能指出当前事实源是 `Personal Health Brief`，不存在第二个总览真相。

### Phase 1（第 1–4 周）：首日价值与信任底座

**目标**：让新用户在第一次授权后获得可信而非空洞的结果。

**交付物**

- 分组、情境化 HealthKit 权限流程；
- 数据覆盖度、最近同步时间、基线窗口和缺失数据状态组件；
- 首次计算的 Personal Health Brief；
- 隐私中心：本地计算/云端 AI 的数据边界、删除/导出、AI 训练政策、第三方传输明细；
- 无数据/部分数据/数据陈旧/权限撤销四套可用状态。

**验收**

- 新用户完成权限后不超过 60 秒看到状态、变化和下一步；
- 任何一个关键分数都能点开贡献证据与覆盖度；
- 权限被拒绝时不显示错误数据、不把空值当 0、不把拒绝当作“没有数据”。

### Phase 2（第 3–7 周）：Today 核心闭环

**目标**：把 Vela 的北极星变成每日可重复体验。

**交付物**

- Today 首屏：Rhythm Horizon、Body State、一个 Training Decision、2–3 个证据、最多 2 个辅助行动；
- 稳定日体验（明确“无需改变计划”）；
- 训练后轻量 Session Annotation；
- 晨间、训练后、条件式晚间 Proactive Touchpoint；
- 通知深链回到具体证据或计划确认，不只打开 app。

**验收**

- 用户不需要进入 Trends 或聊天即可回答“今天怎么办”；
- 通知只在可改变 Daily Operating Plan 时发送；
- 休息、暂停、生病、疼痛和缺失数据不会破坏训练轮转的长期连续性。

### Phase 3（第 5–10 周）：Trends、解释与个人响应模型

**目标**：让“最近发生了什么”可验证，而非只显示图表。

**交付物**

- 7d/30d/6m/3y 多尺度趋势；
- 每条 Health Trend Finding 的方向、幅度、基线偏离、分位数、置信度和数据窗口；
- Candidate Drivers / Observed Correlations 卡片；
- Lived State 与客观 Body State 的一致/不一致视图；
- Insight 反馈（正确/部分正确/不正确）进入 Personal Response Model；
- 可审计的 evidence drawer：显示计算版本、数据源和时间戳。

**验收**

- 每条趋势都能回答“与谁比较、窗口多长、证据完整度如何”；
- AI 不将相关写成因果，不把人口标准伪装成个人诊断；
- 用户修改/否定一条洞察后，后续 Coach 不再无条件重复该结论。

### Phase 4（第 8–13 周）：Coach 从聊天页升级为上下文式健康分析

**目标**：达到 Oura Advisor/Bevel Intelligence 的“可用 AI”，同时保留 Vela 的安全边界。

**交付物**

- 三个入口：全局 Vela 工作台、Today/Trends 洞察上下文、Training 决策上下文；
- 预置高价值问题（“为什么今天恢复下降？”“最近 30 天什么在变化？”“如果我今天训练，边界是什么？”）；
- `Agent Fact Snapshot` 作为唯一事实输入；
- Coach Artifact（报告、图表、解释、训练复盘）可保存、重命名、删除、引用来源；
- Memory Proposal 需要确认；
- Plan Proposal 需要显式确认，支持撤销；
- 模型/云端传输、错误反馈、删除对话和数据保留设置；
- 输出等级：观察事实 → 候选关联 → 可选行动 → 安全边界/何时寻求专业帮助。

**验收**

- AI 不自行重算分数、不越过本地训练安全边界、不静默写入计划；
- 每条建议能回溯到 Health Signal、Personal Baseline 和 Data Coverage；
- 用户能一键标记“不正确/不适用”，并看到修改后的建议状态；
- 云端调用失败时，Today 仍能显示本地计算的最后可信简报和数据新鲜度。

### Phase 5（第 10–16 周）：Plan / Training 落地、留存与商业化

**目标**：把价值变成可持续的健康节律，而不是通知噪声或打卡压力。

**交付物**

- Training Decision：保持/减量/换部位/恢复 + 容量乘数、RPE 上限、建议时长；
- 训练轮转与局部肌群负荷的 3 日/5 周视图；
- 稳定日、恢复日、暂停日均可获得完整反馈；
- 免费层：基本同步、Today 核心简报、基础 Trends；
- Pro 层：深度多尺度解释、Coach Artifacts、Personal Response Model、计划校准与高级训练洞察；
- 不把核心安全状态锁在付费墙后；AI 额度如存在，必须透明且不影响核心简报；
- 以 Trusted Health Brief Day 为主指标，辅以建议采纳率、解释有用率、错误率、权限完成率和 30 日留存。

**验收**

- 用户连续 7 天中至少能在 5 天快速得到可信简报，且稳定日不会被强迫制造任务；
- 用户能说出“今天的建议改变了什么，以及为什么”；
- 付费用户的增量价值来自解释和行动质量，而不是从免费层隐藏基础健康数据。

### Phase 6（建设完成后 28 天）：Primary User Daily Driver

**目标**：在真实 Apple Watch、真实工作压力、真实训练与休息日里证明产品，而不是以“功能已开发”代替成熟度。

**运行规则**

- 每天记录是否形成 Trusted Health Brief Day、失败原因、实际行动与主观有用度；
- 每周只修复影响可信度、理解或闭环的问题，不在 28 天中途扩张功能；
- 覆盖完整、部分、陈旧、未授权、无训练、训练后、旅行/作息异常、云端 AI 不可用等真实状态；
- 第 14 天做中期复盘，第 28 天做继续/重构/砍掉决策。

**放行标准**

- 28 天内至少 24 天形成可理解的 Brief，失败日均有客观原因和可恢复路径；
- 同一事实在 Today、Trends、Plan、Coach 不出现互相矛盾的状态与行动；
- 无数据伪造、无 AI 越权写入、无阻断性崩溃或数据丢失；
- 用户在 10 秒内能说出“今天的身体状态、变化和是否需要行动”。

### 6.7 架构任务（与 Phase 1–5 穿插，不做大爆炸重写）

架构建议使用 Module / Interface / Implementation / Depth / Seam / Adapter / Leverage / Locality 术语，按以下顺序推进：

1. **P0 · Trusted Health Brief Runtime Module**：集中 selected-day、历史窗口、证据新鲜度、计算顺序、Brief 生命周期与持久化验证；HealthKit/SwiftData fetch 和副作用留在 Adapter。它是第一优先，因为 Today、Trends、Plan、Coach 都依赖它。
2. **P0 · Data Coverage Module**：统一 Health Signal 授权/新鲜度、Scored Health Evidence 覆盖度、Body State confidence、Settings/Today/Agent 的可见结论，消除同一天多套覆盖语义。
3. **P1 · Trusted Brief Surface Projection Module**：把 Personal Health Brief、Body State、Training Decision、Daily Operating Plan 投影为统一显示语义；各工作区 Adapter 只决定呈现，不再重算标题、fallback 和行动语言。
4. **P1 · Agent Fact Snapshot Delivery Module**：收紧事实来源、窗口、版本与 hash；Coach、晨报、晚间复盘、工具和报告只通过 purpose-specific Adapter 改变表达。
5. **P1 · Daily Operating Plan Lifecycle Module**：集中 Plan Proposal 的 proposed / confirmed / rejected / deferred / reverted、schema migration 和审计链，保证 Today、Plan、Coach 一致。
6. **P1 · Training Observation Loop Module**：统一 Apple Watch Training Session、Session Annotation、Post-Training Check-in 与次日恢复响应，修补纯 Watch 训练可能无法稳定进入 Personal Response Model 的路径。
7. **P2 · 删除旧产品时代**：迁移后删除 Bevel-parity shell、`Minimal` 历史命名、已隐藏 Nutrition/手机内训练主路径和 compatibility projection；每次删除前用当前 Interface 的回归测试守护。

完整 before/after 图见本轮临时架构报告：`architecture-review-20260823-192933.html`（存放于操作系统临时目录，不进入仓库）。

### 6.8 Bug、界面与交付质量任务

**P0 · 产品正确性**

- 建立 full / partial / stale / denied / no-data / offline / AI-failure 状态矩阵，逐一验证 Brief、Plan 和 Coach；
- 增加 foreground / background / historical backfill 对同一天产生相同 Scored Health Evidence 和 Brief hash 的全链路契约测试；
- 补齐 Apple Watch-only Training Observation、晚到 check-in、重复 workout、删除后重算的端到端测试；
- 修复 PRD 与运行状态冲突：PRD 把虚假健康年龄列为非目标，但当前 `biologicalAgeEnabled` 仍为 `true`；在重新验证前退出主体验；
- Sentry 填入 DSN 并验证真正收到非敏感测试事件，完成 TestFlight/fastlane 首次真实发布演练。

**P0 · 界面系统**

- 建立全新的 UI test target；当前 Xcode 项目只有 `Vela`、`VelaWatch`、`VelaTests`，没有 UI test target；
- 为 iPhone SE、Pro、Pro Max，Light/Dark、AXXXL、Reduce Motion 和高对比度建立 golden screenshot；
- 首屏只允许一个主结论、一个主行动、2–3 个证据；删除卡片套卡片、重复评分和无决策价值的装饰；
- 所有 loading/empty/error 使用同一套状态语言与恢复动作，不再以 `--` 后继续展示假趋势；
- AppIcon 使用 Icon Composer 分层资产并提供 default/dark/clear/tinted 变体，遵守 Apple 最新 [`App Icon`](https://developer.apple.com/design/human-interface-guidelines/app-icons) 指南。

**P1 · 工程质量**

- 把 `TrainingHeroSection.swift`、`CoachView.swift`、`DailySummaryUseCase.swift` 等千行文件的产品语义迁到 deep Module 后再拆 View；目标是提升 Locality，而不是机械按行数切文件；
- 将固定字号报告与审计状态同步为一个自动生成事实源，消除文档仍写 481、脚本已报告约 219 的漂移；
- CI 加入 UI smoke、schema migration、cold cached launch、内存峰值和 HealthKit fixture 契约；
- 继续保持中文优先 + English Beta 的明确状态，不把未完成本地化伪装成完整英文版本。

### 6.9 明确砍掉或降级的范围

- **砍掉公开主线**：Bevel parity、天气装饰、泛 Journal Tab、手机内训练执行、强制营养/热量记账、未经验证的 Biological Age；
- **保留为二级能力**：训练详情、Session Annotation、Coach Artifact、数据导出、AI 高级设置；
- **绝不砍掉**：本地确定性 Scored Health Evidence、Data Coverage、Personal Health Brief、用户确认、Apple Watch 自动训练证据和隐私控制。

## 7. 建议的产品指标与实验纪律

### 7.1 北极星与质量指标

| 指标 | 定义 | 目的 |
|---|---|---|
| Trusted Health Brief Day | 当天同时回答状态、变化、行动，且数据覆盖度达标或明确标注不足 | 衡量真正价值，而非打开次数 |
| Brief usefulness | 用户对简报“有帮助/不适用/不正确”的反馈 | 监测解释质量 |
| Decision adoption | 用户接受、修改或拒绝 Plan Proposal 的比例及理由 | 监测建议是否可执行、是否越权 |
| Evidence traceability | 可回溯至信号、基线、窗口和版本的输出比例 | 防止 AI 黑箱化 |
| Data coverage clarity | 用户能识别缺失/陈旧/拒绝授权的比例 | 监测信任与数据诚实 |
| 30-day health rhythm retention | 30 天后仍使用并有有效简报/反馈的用户比例 | 衡量长期节律，不奖励刷屏 |

### 7.2 不建议作为主指标

打开次数、聊天消息数、通知点击数、连续训练天数、健康总分、单日停留时长。这些指标容易把产品导向强迫打卡、更多聊天、更多分数和更高通知频率，与 Vela 的健康节律和稳定日价值相冲突。

## 8. 关键发现（给决策者的 10 条摘要）

1. **成熟产品卖的是决策框架，不是数据量**：Oura 的 Readiness、WHOOP 的 Recovery/Strain、Gentler 的 Activity Path、Apple 的 Summary 都让用户先看到稳定的解释入口。
2. **Vela 的真正差异化应是“跨信号的可信简报”**，而不是再造一个 Recovery 总分或复制 Bevel 的功能列表。
3. **首日授权是产品体验的一部分**：Apple 明确要求分组、情境化、最小化权限；Vela 必须把 Data Coverage 当作第一等产品对象。
4. **核心循环应从晨间开始、次日闭环**：状态 → 今日决定 → 实际训练/生活 → 主观反馈 → 次日校准。
5. **稳定日也必须有价值**：Gentler 的休息状态说明，长期留存可以建立在“适时停下”而不是每日刺激上。
6. **AI 入口要在上下文中，而不是只在聊天 Tab**：Oura 从洞察进入 Advisor，Bevel 将 AI 放入卡片、动作、Check-ins 和 Files；Vela 应从 Brief/Trend/Training 直接解释。
7. **AI 的资产应是可审计产物**：Bevel 的 Files/Artifacts 很有启发，但 Vela 必须以 Personal Health Brief 作为唯一权威事实源，Coach Artifact 只能引用它。
8. **任何写操作必须确认**：Bevel Food Cart 的 Review → Add 体现了健康数据变更的安全模式；Vela 的计划、记忆、外部同步都应采用 Proposal → Confirm。
9. **隐私是品牌和付费价值，不是法律页**：Apple 的设备端原则、Gentler 的 on-device 叙事、WHOOP 对第三方 LLM 的政策都把“数据如何处理”变成产品选择；Vela 若用云端 AI，必须逐次透明。
10. **商业化应把“解释与行动”作为增量价值**：可参考 Bevel 的免费追踪 + Pro AI，但不能把核心 Body State、安全边界或数据诚实锁在付费墙后。

## 9. 本轮研究未能确认的事项

- 官方资料通常不会公开完整的 onboarding 转化漏斗、真实留存、Logo 命名来源、算法权重或付费墙实验结果；本文不把营销文案或厂商自报使用数据当作行业普遍规律。
- 对竞品 Logo 的判断仅限官方官网/App Store 可观察到的品牌展示；没有对第三方商标注册、设计史或用户认知做二手研究。
- WHOOP、Oura、Bevel 的部分功能和价格会按地区、设备、会员层级与版本变化；正式制定 Vela 价格时应重新核对目标地区 App Store 和官方价格页。
