# Vela × Bevel 3.1.4 高一致性对标执行计划

> 日期：2026-07-31  
> 状态：规划基线，尚未开始本计划内的代码实施  
> 参考版本：Bevel 3.1.4，以用户 iPhone 上的实际版本为最终视觉与交互基准

## 1. 执行结论

这不是一次首页换皮，而是把 Vela 已经具备的健康数据、评分、训练、营养、Journal 和 Agent 能力，收敛成一个达到 Bevel 级完整度的产品。

本计划采用以下边界：

1. 保留 SwiftUI、SwiftData、HealthKit 和现有原生架构。当前精致度问题不是 SwiftUI 导致的。
2. 对标 Bevel 可观察到的页面结构、信息密度、交互流程、状态和公开功能。
3. 不复制 Bevel 的商标、图标、插画、整段文案、源代码或不可见的专有算法。
4. Vela 的评分继续使用可审计、可版本化的独立实现；不声称等同于 Bevel 的内部公式。
5. 第一目标是私人真机 daily-driver。若未来提交 App Store，需要在完整功能对标后再做一次 Vela 自有视觉身份收敛，避免 Copycat 风险。
6. 先完成每日核心闭环，再扩展 Nutrition、Biology、Health Records、Intelligence、Cycle 和 Watch 实时训练。

## 2. 对“1:1”的定义

“1:1”拆成五个可验收维度，每项 0–5 分：

| 维度 | 5 分定义 |
| --- | --- |
| Visual fidelity | 页面层级、几何、间距、字体、颜色、材质和图表与冻结参考高度一致 |
| Interaction fidelity | 页面切换、滑动、Sheet、图表选择、反馈和动效行为一致 |
| Data authenticity | 所有数值来自真实 Health Signal、用户记录或明确的空状态，不伪造曲线 |
| State completeness | 完整、部分、缺失、校准中、过期、离线、错误和历史日期均有设计 |
| Reliability | 首页、详情、Watch 和 Agent 对同一天、同一算法版本给出一致结果 |

一个页面只有总分至少 22/25，且任何单项不低于 4，才可以标记为完成。

动态数值和头像遮罩后，关键页面截图的目标是：

- 关键几何偏差不超过 2 pt；
- 主要静态区域像素差控制在约 5% 内；
- 所有可点击外观都必须有真实路由；
- 44 pt 最小触控区、Dynamic Type、VoiceOver、深浅色和 Reduce Motion 全部通过。

## 3. 当前 Vela 的真实起点

Vela 不是从零开始，当前已经具备：

- Recovery、Sleep、Strain、Physiological Stress、Energy 五项独立 Scored Health Evidence；
- Personal Baseline、Data Coverage、Body State、Training Decision 和 Daily Operating Plan；
- HealthKit 查询、同步、SwiftData 历史记录和 Apple Watch 快照；
- 力量训练记录、计划、负荷分析、RPE/RIR、HealthKit 与训记数据合并；
- Journal、食物图片/条码/手工记录、Biological Age 初版；
- Agent Fact Snapshot、Coach Artifact、Memory Proposal、工具调用和写操作确认。

现状的核心缺口：

1. 当前生产导航是 `Today / Training / Coach / Me`，和 Bevel 的 `Home / Journal / Fitness / Biology / +` 产品模型不一致。
2. 首页已经有分数，但 Recovery、Sleep、Strain 在 Hero 与 Signal Grid 重复，信息主次仍不够清楚。
3. Nutrition、Vitals、部分 Proactive Intelligence 已有代码，但不可达或没有进入生产首页。
4. 14 类指标大多套用通用详情模板，只有 Sleep、Strain、Stress 有较明显的领域专属页面。
5. 实时 MetricResult 与缓存记录不完全等价，缓存会丢失权重、原因、缺失输入、数据窗口和算法版本等解释信息。
6. 日级历史无法支撑真实的日内 Stress 与 Energy 曲线。
7. HealthKit 授权、查询、Coverage 和持久化使用的 Health Signal 集合没有完全统一。
8. 当前评分引擎虽有单元测试，但缺少校准生命周期、Golden Dataset、纵向回测和误差指标。
9. Agent 的 canonical 趋势仍有占位内容，Check-in、Files 和持续工作流没有成为首页的一等产品层。
10. Watch 目前主要是只读快照，不是 Bevel 式 Live Strength 执行端。
11. 当前只有 Unit Test target，缺少 XCUITest 和截图回归体系。

旧的 `docs/BEVEL_PARITY_GAP_TRACKER.md` 中“High”主要表示页面已经存在，不能继续等同于产品完成度。

## 4. 冻结的 Bevel 产品范围

### 4.1 每日核心闭环

```text
Strain（今天消耗）
→ Sleep（补足需求）
→ Recovery（明日准备度）
→ Target Strain（今天应达到的行动目标）
```

其上叠加：

- 实时状态：Stress、Energy Bank；
- 当日行为：Nutrition、Journal、Timeline、Activity Status；
- 长期系统：Fitness、Strength、Biology、Biological Age、Health Records；
- 执行层：Intelligence、Files、Artifacts、Check-ins、训练与营养计划。

### 4.2 P0 页面

1. Onboarding、HealthKit 权限与 Calibration
2. Home Dashboard
3. Daily Calendar 与 Month Calendar
4. Recovery 与 Recovery Insights
5. Sleep、Primary Sleep、Sleep Needed、Alarm
6. Strain
7. Stress
8. Energy Bank
9. Timeline 与 Trends
10. Journal Today 与 Journal Insights
11. Fitness Overview 与 Activity Detail
12. Strength Templates、编辑模板、Live Workout、Workout Summary
13. Nutrition Overview、记录入口、Food Cart、Food Detail、Goals、My Foods
14. Biology、Biological Age、Biomarker Detail、All Biomarkers
15. Health Records 上传、审核、详情
16. Intelligence Chat、Sidebar、Files、Artifacts、Check-ins、Personality 和 Settings
17. Profile、Customization、Data Sources

### 4.3 P1 页面

- Cycle Tracking 全套；
- Widgets、Lock Screen、Live Activities、Dynamic Island；
- Apple Watch Dashboard 与 Watch Live Workout；
- 社交分享卡；
- Calendar integrations；
- CGM 完整曲线；
- Activity Status 对 Sick、Injured、On Break 的完整适配。

## 5. 高推理阶段必须先冻结的决定

以下决定不能交给低 Token 模式临场判断。

### H0：发布边界

默认：先作为私人真机 daily-driver；未来 App Store 版本保留功能结构，但进行 Vela 品牌与视觉差异化。

### H1：参考版本

默认：冻结 2026-07-31 用户 iPhone 上的 Bevel 3.1.4。官网与帮助中心只补功能清单，不替代真机截图。

### H2：信息架构

推荐目标：

```text
Home | Journal | Fitness | Biology | +
```

`+` 是可自定义动作入口；Intelligence 可由 `+`、首页建议和页面上下文进入。Settings、Profile、Files 等采用二级入口。

### H3：评分语义

- 保留五项独立 Scored Health Evidence，不制造含义不清的 Overall Health Score。
- 首页主角为 Recovery、Sleep、Strain 三环；Stress 与 Energy 是日内实时层。
- 每项都必须携带方向、置信度、Data Coverage、贡献信号、基线比较、算法版本和数据窗口。
- Bevel 未公开的权重由 Vela 独立设计和校准。

### H4：本地与云端

推荐前四个里程碑保持 local-first。可靠的定时 Check-in、跨设备记忆、云端文件处理和日历 OAuth 单独作为 Cloud Epic，不能依赖 iOS 本地后台任务假装准时。

### H5：持久化迁移

在增加 Intraday、Health Records、Cycle 或完整 Score Evidence 模型前，先设计 SwiftData V2/V3 迁移、真实数据库副本测试和回滚路径。

### H6：AI 数据边界

逐字段定义哪些 Health Signal、Journal、Nutrition、文件和记忆可以发给第三方模型。首次发送前必须明确披露接收方和字段，并取得显式同意。

### H7：健康与医疗边界

Biological Age 和所有建议默认定位为 wellness estimate，不作诊断、治疗或处方。算法页面必须公开数据来源、方法边界和不确定性。

## 6. 工程依赖顺序

```text
冻结参考截图/录像
→ 信息架构与设计 Token
→ Health Signal Catalog
→ 增量同步与 SwiftData 迁移
→ 完整 Score Evidence 与日内序列
→ Body State / Training Decision
→ Home 与五项详情
→ Journal / Fitness / Nutrition / Biology
→ Agent Fact Snapshot
→ Intelligence / Files / Check-ins
→ Watch / Widgets / Live Activities
→ 自动化视觉与真机验收
```

不得跳过数据基础直接绘制看似精致但没有真实来源的日内曲线。

## 7. 分阶段执行计划

### Phase R：建立参考基线

预计 4–6 个低模式批次。

- R01：记录 Bevel 版本、设备尺寸、语言、主题和数据状态。
- R02：通过 iPhone Mirroring 捕获全部一级页面。
- R03：捕获 P0 二级页以及完整、部分、缺失、校准中和历史日期状态。
- R04：录制 Tab、日期滑动、卡片展开、图表选择、Sheet、返回、长按和训练流程。
- R05：建立 `Screen ID → Route → Data → State → Interaction` 矩阵。
- R06：测量边距、字体、圆角、环形图、卡片、材质和动效，生成视觉 Token 表。

门槛：P0 页面都有截图、录像、状态表和真实数据来源；不再凭印象实现。

### Phase F：修复数据与持久化基础

预计 8–10 个低模式批次。

- F01：冻结当前构建、单元测试、真机截图和本地数据库备份。
- F02：为新版界面增加 feature flag，旧界面暂不删除。
- F03：建立唯一 `HealthSignalCatalog`，同时驱动授权、查询、Coverage、单位和持久化。
- F04：修正 HealthKit 读取权限表达：只能说“未读取到数据”，不能断言用户拒绝读取。
- F05：将完整、版本化的 Score Evidence 持久化，保证实时、缓存、后台重算语义一致。
- F06：实现 SwiftData V2 迁移并用真实数据库副本验证。
- F07：实现增量同步游标、脏日期重算、来源去重和删除对账。
- F08：建立 Intraday Signal Bucket，用于真实 Stress、Energy、HR 和活动时间轴。
- F09：统一健康日边界，处理睡眠跨午夜、旅行时区和可配置 wake time。
- F10：建立算法 Golden Fixtures、回测、无未来数据泄漏和版本一致性测试。

门槛：相同输入重复同步不产生重复记录；首页、详情、Watch、缓存和 Agent 对同一分数完全一致。

### Phase D：设计系统与导航壳

预计 5–7 个低模式批次。

- D01：冻结颜色、字体、间距、圆角、阴影、材质和语义色 Token。
- D02：统一 Score Ring、Metric Card、Trend Card、Evidence Row、Status Pill。
- D03：统一折线、面积、阶段、范围选择、目标区间和 Timeline 图表。
- D04：实现目标 Tab Shell、Header、Calendar、Sheet 和详情固定导航。
- D05：建立 loading、empty、partial、calibrating、stale、offline、error 组件。
- D06：加入按下即反馈、可中断弹簧、速度连续和轻量触觉反馈。
- D07：完成 Dynamic Type、VoiceOver、Reduce Motion、Reduce Transparency 和高对比适配。

Apple-style 动效门槛：

- 触摸按下立即反馈；
- 手势驱动动画可以中途抓住、反向和重新定向；
- 默认使用临界阻尼，只有动量手势允许轻微回弹；
- Reduce Motion 使用短交叉淡入，不做大幅位移。

### Phase H：每日核心闭环

预计 10–12 个低模式批次；这是第一个真机交付点。

- H01：Home 日期、账号、Activity Status、天气与同步状态。
- H02：首屏同卡 Recovery、Sleep、Strain 三环。
- H03：三环下方的真实 Agent 今日解释与 Target Strain。
- H04：Stress 与 Energy 的真实日内卡片。
- H05：Health Monitor、Nutrition、Journal 与 Timeline 模块。
- H06：左右滑动历史日期、日历选日和月视图。
- H07：Recovery 专属详情。
- H08：Sleep 专属详情。
- H09：Strain 专属详情。
- H10：Stress 专属详情。
- H11：Energy 专属详情。
- H12：所有路由、分享、空状态、错误状态和页面上下文。

门槛：

- 目标 iPhone 首屏无需滚动即可看见三项核心分数；
- 每个分数都有分项、趋势、证据、Coverage、Freshness 和算法版本；
- 同一分数不会在首页不同模块中重复争夺视觉主角；
- 所有看起来可点击的卡片都能进入正确详情页；
- 页面五轴评分达到 22/25。

### Phase T：Journal、Fitness、Strength、Nutrition、Biology

预计 18–28 个低模式批次。

Journal：

- 日期条、每日行为板、自定义标签、默认值、复制昨日；
- 自动与手动指标；
- Recovery / Sleep Insights；
- 最少样本门槛、滞后关系和“相关不等于因果”提示。

Fitness：

- Calendar、Activity Summary、Strain Performance；
- Cardio Load、Cardio Status、Cardio Focus、Heart Rate Recovery；
- Strength Progression、Muscle Distribution、Workout Detail。

Strength：

- 模板、动作库、组次类型、Superset/Circuit；
- RPE/RIR、休息计时、Plate Calculator、进阶历史；
- Active Workout、崩溃恢复、Live Activities；
- Phone/Watch Live Sync、Watch 编辑重量与次数。

Nutrition：

- Nutrition Score、Food Quality、Net Energy、Macro/Micro；
- 搜索、照片、描述、条码、导入、Favorites、Recipes、History；
- Food Cart 审核、餐食编辑、Goals、My Foods；
- 可选 CGM Glucose Impact。

Biology：

- Biological Age、Confidence、历史、贡献因子和 20 年 Projection；
- VO2 Max、HRV/RHR Baseline、Weight、Body Fat、Lean Mass、Blood Pressure；
- Biomarker 分类、收藏、搜索、趋势和手工记录；
- Health Records 的上传、解析、审核、修改和删除。

### Phase A：Intelligence 成为执行层

预计 12–18 个低模式批次。

- A01：第三方 AI 明示同意和逐字段出站清单。
- A02：Chat、历史、搜索、重命名、Ghost Mode。
- A03：Fast / Thinking / Adaptive 与 Personality。
- A04：Screen Context 使用结构化页面上下文。
- A05：Files、Artifacts、Plans、Notes、Logs 与可管理 Memory。
- A06：Memory Proposal 确认、编辑、撤销和删除。
- A07：一次性、小时、日、周、月 Check-ins。
- A08：日/周/月总结。
- A09：训练计划、力量/有氧模板与渐进超负荷建议。
- A10：营养记录、餐单、购物清单和 Food Cart。
- A11：自定义图表、Impact Matrix、相关分析与预测。
- A12：Health Records 与 Biomarker 分析。
- A13：Calendar、Dictation、通知与后台任务。
- A14：工具 allowlist、幂等、写操作确认、prompt injection 防护和审计。

门槛：

- AI 的健康事实都带信号、日期或明确的“未知”；
- 所有写操作经过用户确认且可以回看；
- 相同 tool call 不会重复执行；
- 未经许可的数据不会离开设备；
- 固定安全题集做到零诊断、零处方、零越过 Training Decision 的高风险建议。

### Phase Q：发布级硬化

预计 8–12 个低模式批次。

- Q01：新增 VelaUITests 与截图测试 target。
- Q02：覆盖首次授权、Home、五项详情、Journal、训练、Nutrition、Biology、Coach 和删除数据。
- Q03：目标 iPhone、小屏 iPhone、Pro Max 的尺寸矩阵。
- Q04：中英文、深浅色、默认与辅助字号、VoiceOver。
- Q05：冷启动、热启动、90 天重算、滚动、后台恢复和内存性能。
- Q06：锁屏、解锁、飞行模式、API 失败、权限变化、时区和夏令时。
- Q07：隐私政策、App Privacy、Review Notes 和 HealthKit 数据清单。
- Q08：连续 7 天真机 daily-driver。
- Q09：零 P0/P1 缺陷后才标记候选版本。
- Q10：若启用云端，追加威胁模型、账号/数据删除、备份与灾难恢复。

## 8. 预期交付节奏

批次数比墙钟时间更可靠，因为 HealthKit 数据成熟度和真机反馈不能完全压缩。

| 里程碑 | 预计批次 | 现实预期 |
| --- | ---: | --- |
| M1：首屏三环 + 五项专属详情达到 Bevel 级 | 18–25 | 约 2–4 周 |
| M2：Journal / Fitness / Strength / Nutrition / Biology 可日用 | 累计 40–60 | 约 6–12 周 |
| M3：Intelligence / Records / Watch 形成完整产品 | 累计 60–85 | 约 12–20 周 |
| M4：App Store 级硬化 | 额外 8–12 | 约 2–4 周 |

如果只追求私人侧载的视觉演示，可以更快；如果要求真实数据、边缘状态、迁移安全和连续日用，就不应压缩验证阶段。

## 9. 低 Token 模式的执行协议

每次只执行一个编号任务，并遵守：

1. 一个明确结果；
2. 通常只修改 1–4 个生产文件和 1 个对应测试文件；
3. 一次不同时改导航、算法和数据模型；
4. 每批必须构建、运行定向测试并生成一张对比截图；
5. 每批结束记录：修改文件、测试结果、截图、未解决差异；
6. 不允许用默认分数、随机值或伪造曲线填充视觉；
7. 不删除旧实现，直到 feature flag 下的新流程完整通过；
8. 页面通过验收后再进入下一个编号。

推荐的低模式提示词：

> 按 `docs/BEVEL_3_1_4_PARITY_EXECUTION_PLAN_2026-07-31.md` 只执行任务 R01。不要实施其他编号；完成规定产物、验证和记录后停止。

之后依次将 R01 替换为 R02、R03 等。

## 10. 必须切回高推理模式的停止条件

出现以下任一情况时，低模式必须停止：

- 需要改变评分权重、阈值、Personal Baseline 或医学措辞；
- 需要新增或修改 SwiftData 模型，但没有迁移说明；
- Bevel 参考截图之间冲突；
- 需要决定 local-first 还是云端；
- 涉及新的 HealthKit、照片、日历、麦克风或第三方 AI 权限；
- 涉及后台自动发送健康数据；
- 需要扩大 Agent 工具权限或增加写操作；
- 修改扩散到 5 个以上无关模块；
- 只有伪造数据才能做出参考视觉；
- 需要更换框架、删除旧数据或进行不可逆迁移。

## 11. 主要风险

### 视觉与知识产权

Apple App Review 4.1 不允许简单复制热门 App 的名称或 UI。内部参考可以追求高一致性，但公开版本必须保留 Vela 品牌、文案、资产和可辨识的产品价值。

### 专有算法

Bevel 没有公开 Recovery、Sleep、Stress、Energy、Target Strain、Biological Age 的完整权重和缺失值处理。Vela 只能做到输入语义、输出范围和用户体验对标，内部公式必须独立实现。

### HealthKit 隐私

App 无法知道用户是否拒绝 HealthKit 读取；锁屏时也可能无法读取加密数据。UI 必须表达“暂无可用样本/使用缓存”，不能伪装成精确权限诊断。

### 数据迁移

继续向现有 SwiftData 模型机械加字段，会威胁用户已有数据。所有新模型先迁移、备份、真实数据库副本测试。

### 日内真实性

Stress 与 Energy 的精致曲线必须来自时间桶 Health Signal 和活动排除逻辑；日总分不能伪装成日内曲线。

### Agent 与后台

iOS 本地后台任务不能保证准时。可靠 Check-in、云端文件处理、跨设备记忆和 Calendar OAuth 需要明确的后端架构。

## 12. 参考资料

- Bevel App Store：<https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249>
- Bevel 官方帮助中心：<https://help.bevel.health/en>
- Bevel 功能版本：<https://help.bevel.health/en/articles/11194113>
- Bevel 关键指标：<https://help.bevel.health/en/articles/11251073>
- Bevel Intelligence：<https://help.bevel.health/en/articles/11586817>
- Apple App Review Guidelines：<https://developer.apple.com/app-store/review/guidelines/>
- Apple HealthKit Privacy：<https://developer.apple.com/documentation/healthkit/protecting-user-privacy>
- Apple HealthKit HIG：<https://developer.apple.com/design/human-interface-guidelines/healthkit>

## 13. 下一步

切换到低 Token 模式后不要立刻改首页。第一项应执行 R01：冻结用户 iPhone 上 Bevel 3.1.4 的版本、设备、语言、主题和数据状态；随后完成 R02–R06 的全量真机参考采集。只有参考矩阵完成后，才开始 F01。
