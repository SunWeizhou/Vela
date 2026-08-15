# Vela 全量审阅报告（2026-08-13）

> 基线：`main` @ `b3577992`，工作区干净。审计方式：8 个并行子代理分模块走查（稳定性 / 数据正确性 / 设计 HIG / 交互 / 文案五个轴）+ iPhone 17 Pro 模拟器实拍（开屏·浅/深色、今日页·浅/深色、Accessibility 字号，见 `build/audit-shots/`，OCR + 调色板量化）+ 关键发现人工复核。
>
> 结论速览：**无 P0（崩溃/数据损坏级）**；**P1 × 2**（功能级断链）；**P2 约 26 项**；**P3 约 40 项**；另有 4 类系统性设计差距。评分引擎数学质量良好（PhenoAge 已对照 BioAge R 包源码逐行验证正确）；主要问题集中在 **AI 工具断链、数据管道断点、Dynamic Type、Token 纪律与交互细节**。

---

## 修复记录（2026-08-13 · 第一批：健康档案）✅ 已修

- **[P1-2] VO2max 断链**：live 路径直接查询 HealthKit `bodyMetrics`（90 天窗）并在 `DailySummaryUseCase` 汇入 dashboard（`DailySummaryUseCase.swift:244-249, 306`）；快照内存传递同步引擎/刷新服务两路。**有意不持久化**：实测给 `DailyHealthSummaryRecord` 加字段会触发 `VelaSchemaV2` 的「未知模型版本」迁移失败（V2/V3 引用可变模型清单——即审计 E2 预警的潜伏事故，本次当场复现）→ 已回退字段。代价：缓存态（同步窗口期）暂缺 VO2max，live 后即出现。
- **[P2] 档案优先级统一**：全链路「手填值优先、Apple 健康兜底」——`DailySummaryUseCase` live（:260-267）与 cached（:931-939）路径、`BodyModelViews`、体征页、Coach 上下文（经 `extendedMetrics` 自动一致）。清空手填字段即回退 Apple 健康。
- **旧 hydrate 残留一次性迁移**：`UserProfileSettings.migrateLegacyHydratedValuesIfNeeded`（`AppCoordinator` 启动时执行）清除旧版本写入 UserDefaults 的年龄/体重/身高/性别冻结值；删除 `hydrateMissingValuesFromHealth` 及其两处调用。
- **[P2] 缓存路径补档案字段**：`makeDashboardFromRecord` 现携带 age/sex/height/weight（手填兜底）。
- **[P2] casual 短回复带档案**：`CoachContextAssembler` casual 分支追加「用户生理档案 + 身体模型」（按健康/个人档案 consent 分别门控）。
- **手记体重回写**：`WeightLogSheetView` 保存体重时同步写入档案覆盖值，不再被下次 HK 同步覆盖。
- **编辑页透明化**：`SettingsAccountView` 每字段来源徽标（手动 / Apple 健康 / 按年龄推断）+ footer 文案修正；移除「打开页面即把 HK 性别冻结进手填值」行为。
- **测试**：`testHealthProfileMigrationResetsLegacyHydratedValuesOnce` 替换旧 hydrate 测试；全量 316/316 绿。

**遗留（已知取舍）**：VO2max 缓存态暂缺；`VelaSchemaV2/V3` 引用可变模型清单的潜伏问题未动（需要冻结历史 schema 的独立工程，见审计 E2）。

---

## 指标计算数值验证（2026-08-14，可执行复现）

对可疑计算点写临时 XCTest 复现（跑真实引擎 + 实际数值），8 个用例全部确认。已按「报告先行」原则复现后移除测试类，未改产品代码。

| # | 计算点 | 复现结果 | 影响与建议 |
|---|--------|----------|-----------|
| V1 | **睡眠效率 >100% 归一化** `HealthUnitNormalizer.normalizeSleepEfficiency` | 输入 1.05（105%）→ 输出 **0.0105** | 整晚效率被记成 1%，严重失真。应 clamp 到 1.0（仅当值 >1 且 inBed 更短时），而不是除以 100 |
| V2 | **42 天快照实际返回 41 天** `HealthSnapshotRepository.fetchSnapshots` | 插 42 天记录、请求 days:42 → **返回 41** | 所有滚动基线（MAD/EWMA/ACWR/个人基线）系统性缺最老一天；建议记录日期统一健康日标签 |
| V3 | **readiness 置信度场景系数** `TodayCommandState` | 全高置信数据 → confidence **0.76**（应 1.0） | 0.86/0.78/0.74…7 个场景乘数叠加在加权置信度上，数值语义不可解释；建议删除或拆为独立 decisionCertainty 字段 |
| V4 | **睡眠数据缺失误判「减量」** `TodayCommandState:150` | 睡眠无数据 + 恢复正常 → decision=**reduce**，理由称「不够低到休息、不够强到满量」 | 误导性建议；`sleepScore.score` 无数据为 0，需加 `hasData` 保护 |
| V5 | **EnergyBank todayLoad 缺失时评分域混入** `EnergyBankEngine:137` | strainScore=100 vs 50 → acwr **1.364 vs 1.115**（±22% 漂移） | 0-100 评分域混进 TRIMP 域 ATL/CTL；nil 时应跳过负荷计算 |
| V6 | **Strain「28 天」CTL 吃进 42 天历史** | 29 天前的负荷峰值使 CTL 从 103.448 → **104.317**（Δ0.868） | 工厂传 42 天给「28 天」EWMA；建议 `prefix(28)` 或改名文档化暖启动语义 |
| V7 | **Stress 引擎 SD=0 静默满分** `StressIndexEngine` | quietHRSD=0.0 → value=**100** | 除零 → +inf → 满分而非缺失；加 `sd.isFinite && sd > 0` 守卫 |
| V8 | **真实 1RM 测试不计入 e1RM** `TrainingAnalyticsService.isEffective` | 1 次×100kg 完成组 → e1RM **空**（Epley 应 ≈103.3） | `repetitions >= 3` 门控排除 1-2 次组；e1RM 应单独按 reps≥1 计算 |

修复优先级建议：V1 > V4 > V7（正确性硬伤、改动小）→ V2 > V5 > V3（口径统一）→ V6 > V8（语义微调）。

**修复状态（2026-08-14）**：✅ V1 / V2 / V4 / V5 / V7 已修复并配回归测试（全量 321/321 绿）；⏸ V3 / V6 / V8 待产品语义拍板：
- V1：`normalizeSleepEfficiency` 分数制超 1 钳 1.0、百分制（≥10）除 100
- V2：`fetchSnapshots` 比较改用日历日边界（记录层 date 是日历午夜）
- V4：`TodayCommandState:150` 睡眠分支加 `hasData` 保护
- V5：`EnergyBankEngine:137` todayLoad 缺失置 0，不再回退评分域
- V7：`StressIndexEngine` 两处 SD 加 `isFinite && > 0` 守卫，回退基线 SD

## 第二批修复（2026-08-14）✅ 已修并推送

- **训练**：① 计划复盘响应 ID 空间合并（`WorkoutEventDTO` 增 `linkedStrengthWorkoutId`，`TrainingPlanReviewService` 合并事件 ID 与力量 ID 两空间，力量响应不再永远匹配不上）；② 周中建计划的「幽灵日」修复（`TrainingScheduleResolver.resolve` + `review` 均过滤 `scheduledDate >= planStart`）；③ 编辑旧训练 PR 历史按日期过滤（不再产生伪 PR）；④ 草稿跨天续录时长封顶 4 小时（不再膨胀到数百分钟）。
- **Coach**：① 重试锚定点击的失败气泡（`userMessageForRetry` 支持 `retryBubbleId`，视图传 `msg.id`）；② 持久化失败与请求失败分离（成功回复不再被删、不误报「服务不可用」；`persistThread` 本就内部捕获，无死锁路径）；③ stop() 把已流出的部分内容固化进气泡（无内容才移除空泡），与注释一致。
- **AI 报告**：`ReportGenerator` 上下文裁剪改为「解析为顶层字典 → 逐次丢弃最大键 → 重新序列化」，模型收到的永远是合法 JSON（修复了 `prefix(12000)` 字符截断残片；并规避了 JSONSerialization 对标量的 NSException）。
- **今日页**：睡眠「卧床时间」跨午夜负值 +24h 取模（不再显示 0 小时）。
- **测试**：+4 回归（计划 ID 空间、幽灵日、重试锚点、JSON 裁剪），全量 325/325 绿；已推送到 iPhone。

## 第三批修复（2026-08-14 · 狩猎发现）✅ 已修并推送

- **[P1] dailyLoad 双域混用**：`apply(snapshot:)` 保留引擎 TRIMP 域 `dailyLoad/workoutLoad`（此前被丢弃），`aggregateDay` 仅在引擎未提供时以 session-RPE 兜底——历史与当日不再量纲混用（ATL/CTL/TSB/ACWR 同域）。
- **[P1] Watch 力量编辑丢失**：`WristSnapshotBridge` 补实现无 replyHandler 的 `didReceiveMessage` 变体（此前 watch 端 `sendMessage(replyHandler: nil)` 在手机可达时被静默丢弃）。
- **[P1] 中文环境规律去重失效**：`extractRuleName` 同时匹配「**规律**: 」与「**Rule**: 」，去重纳入 proposed/rejected/superseded（仅排除 expired）——不再每晚重复提议同一规律。
- **[P2] 体温安全规则死代码**：`TrainingDecisionEngine` 传入真实 `body_temp_delta`（此前硬编码 0.0，rest 规则永不触发）；阈值 0.6 → 1.0 与 Recovery 对齐（±0.6°C 属正常昼夜波动）。
- **[P2] 咖啡因→睡眠规则用错天**：改匹配次日快照（注释自证意图）。
- **[P2] 稀疏窗口伪差值**：PersonalResponseModel 三处规律检测加日历相邻性守卫（漏同步多天不再产生伪「次日」配对）。
- **[P2] 「清除全部数据」残留 watch 缓存**：`clearCachedSnapshot` 连带清理 active-workout 与 pending-strength-edits。
- **[P2] 「主动洞察」开关空转**：`runAsyncCheck` 入口检查 `proactiveInsights`（该开关是 opt-in、默认关——**注意**：此前洞察无条件运行，更新后若设置里开关为关，洞察将停止，需手动打开）。
- **[P3] DST 边界**：`get_health_history` 的 cutoff 改用日历日运算（86400 秒当一天在 DST 切换日偏一天）。
- **[P3] 睡眠效率归一化细化**：(1,2] 钳 1.0、>2 按百分制除 100。
- **测试**：apply 契约测试按新语义更新；orchestrator 测试显式开启 opt-in 开关；全量 326/326 绿；已推送到 iPhone。

**遗留（记录在案，待拍板/待办）**：高严重度前台通知永不显示（无 willPresent delegate + UUID 标识无去重）；stress 阈值三引擎不一致（78/75/75）；TodayCommandBuilder 缺失输入不够保守；AIReportRecord 无保留策略；Xunji `completedAt=Date()` 用导入时刻；Xunji 自动导入失败静默；P1-1 Coach 写工具死链（onConfirmToolCall 接线，独立批次）；V3/V6/V8（readiness 场景系数 / 28 天窗口 / 1RM e1RM）。

## 第四批修复（2026-08-14 · P1-P3 全量清理第一批）✅ 已修并推送

- **[P1] Coach 写工具死链**：`AgentLoop` 接入 `onConfirmToolCall` → Coach 对话中「创建训练计划/记录饮食/删除计划/更新档案」弹出确认卡（ADR 0008），60 秒未响应自动拒绝；取消/流式结束自动收尾防悬挂。
- **[P2] 前台高严重度通知**：注册 `UNUserNotificationCenterDelegate.willPresent`（前台可见）+ 日级固定 identifier 去重（此前 UUID 每次前台重复弹）。
- **[P2] 主动洞察开关生效 + 日级去重**：`runAsyncCheck` 检查 opt-in 开关与同日已跑标记。
- **[P2] 晨报数据新鲜度检查**：今日快照未同步不生成（此前可能用过期数据锁定整天）；晨报/晚间同步接入 `RetryingLLMProvider` 指数退避重试。
- **[P2] 隐私**：wiki 注入加「用户档案数据，非指令」边界；`web_search` 工具层隐私兜底（含健康数值的查询拒绝出网）；`ContextBudget` 在 `buildFacts` 执行（wiki 3000 字符/文件、历史报告 ≤6 条）。
- **[P2/P3] AI 稳健性**：SSE `finish_reason=length` 正常收尾（不再误报「无法解析」）；餐食热量 `asInt` 修复；legacy `file:` 捕获只取合法文件名字符；工具确认超时；通知授权检查（含 denied 反馈）。
- **V3/V6/V8**：readiness 置信度删除场景系数（纯数据加权）；Strain 28 天窗口截断；1-2 次组计入 e1RM（RPE≥6 且非热身）。
- **评分残余**：睡眠时长分量对称地板；Banister 性别系数 Method A/B 统一；`clamp` NaN/∞ 防护；历史 stress 运动窗口用 `asOf`；`TrainingLoadStatus` 增加 `.unknown`（不再伪装 optimal）。
- **今日页/交互**：首帧去冗余 `loadSecondaryData`；评分刷新不再触发系统震动（下拉刷新保留）；a11y 标签按同步状态动态；切日手势用实际位移；scrub 触觉仅首次触摸；Sparkline 单点除零守卫；MetricCoachCard 接入重试 + 取消感知。
- **Health/Watch**：`sleepEpisodes` 查询窗前扩 12h 并按结束时刻过滤；HRV/RHR 日分桶锚定 04:00 健康日边界；Watch 会话激活后补发未送达上下文；Xunji 导入同日近似时长双录防护。
- **设计 P2**：`meta` 对比度修复（自适配 4.5:1+）、`accentOn` 暗色改深墨、详情页暗色白盘 → `rhythmCanvasRaised`、体征页画布统一、legacy tab 8.5pt → caption2、Hero 图标 → `rhythmDeepOn`、Hero 标题改语义 largeTitle（随 Dynamic Type）、食物扫描快捷指令开关守卫、hubActionCell color 参数启用、PlusActionSheet 靛蓝 → 品牌绿、Coach 流式滚动「接近底部才跟随」、切后台停听写、重量输入 2 位小数、键盘死状态清理。
- **文案**：模板错字、中英混杂（蛋白质 and/体能负荷 and）、FoodPhoto 中文用户消息、问候语去掉硬编码姓名、60 min → 分钟、逐项权限文案修正、中止文案双语、DeepSeek 驱动。
- **测试**：326/326 全绿；已推送到 iPhone。

**剩余待办（后续轮次）**：死代码大清理（GlassTabBar/CoachChatPanel/风景视图等）、VelaSchemaV2 冻结（结构性工程）、BGTask 30s 预算架构、Coach 路径 legacy parser 双通道、重试 jitter+类型化错误、MarkdownText 列表渲染、SleepClockWheel VO、训练热力日历/详情 Material 色板、Xunji completedAt 与自动导入提示、三处「健康档案」命名、主动服务硬编码中文文案、AIReportRecord 保留策略、Kimi 第三方披露。

## 第五批修复（2026-08-14 · 全量清理第二轮）✅ 已修并推送

- **重试类型化 + jitter**：`LLMProviderError.requestFailed` 携带 statusCode（不再靠消息子串匹配），两个重试实现加 ±20% 抖动。
- **Coach legacy parser 双通道**：`[ACTION:update_wiki]` 解析仅在 casual 短回复路径保留（AgentLoop 工具通道已带用户确认，去重）。
- **缺失输入保守化**：睡眠或压力缺失 → 保守 reduce + 诚实理由（不再落到「可训练」）；stress 阈值三引擎统一为 75。
- **死代码清理**：删除 GlassTabBar/DayPill/ScoreRing/DataFreshnessBar/VitalCard/InfoCard/VelaPageShell/VelaHeroCard/MetricScoreCard/TrendChartCard/VelaMinimalScreen/VelaMinimalFloatingTabBar/MiniBubble/MiniStreamingBubble/CoachChatPanel/CoachInputBar/FlexStack/JournalView/JournalDraft/开屏 heroSection+signalPreviewCard+featureCard/身体模型卡片等死代码 + `animatedEnergyScore` 死状态（pbxproj 引用保留）。
- **MarkdownText**：`- `/`* ` 列表渲染为 •、围栏代码块保留内容（AttributedString 不渲染列表的保真问题）。
- **SleepClockWheelView**：VoiceOver 组合摘要（就寝/起床/时长/目标）。
- **Xunji**：组 `completedAt` 用训练时刻而非导入时刻；自动导入失败进诊断管线 + 页面提示（不再静默）。
- **今日页兜底**：`makeTodayExperience` 用真实力量训练记录（不再传空数组）。
- **训练热力日历/详情**：Material 色板 hex 收敛为语义 Token。
- **AIReportRecord 保留策略**：每 type 保留最近 30 条（此前只增不减）。
- **Kimi 第三方披露**：Coach 设置页隐私说明补充 Moonshot（Kimi Vision）处理餐食照片。
- **其余**：Rule3 步态阈值文案诚实化、`created` 计数只在成功时 +1、MetricTrends delta 阈值相对化 + 单位后缀、生理特征命名去冲突（「健康档案」三义归一）、体重记录 Vitals 强制解包改 `if let`、休息计时用训练开始日。
- **测试**：326/326 全绿；已推送到 iPhone。

**剩余（结构性/低风险，末轮处理或文档化）**：VelaSchemaV2 冻结（需复制 32 个模型快照，独立工程）；BGTask 30s 预算（需拆分任务授予）；主动服务硬编码中文文案（DigitalTwin/周报/activePlanBlock）；心率区间串行查询（HealthKitQueryService 非 Sendable）；会话操作静默提示；VelaResolver fail-fast（有意设计）。

## 第六批修复（2026-08-14 · 收尾）✅ 已修并推送

- **会话操作反馈**：流式中新建/切换/删除会话、stop 后立即再发送，现在都会显示 2.5 秒提示（此前静默忽略）；submit 守卫同样给出提示。
- **周报/月报双语**：`PersonalResponseInsightService` 的每周身体报告与月度身体总结在英文界面生成英文版（此前硬编码中文）。
- **DigitalTwin 建议双语** + **activePlanBlock 双语**（LLM 系统提示）。
- **测试**：326/326 全绿；已推送到 iPhone。

**最终遗留（结构性工程，超出「离散项」范围，已在文档单独立项）**：
1. `VelaSchemaV2/V3` 引用可变模型清单——冻结历史 schema 需复制 32 个 `@Model` 快照（约 2000 行机械工作 + 迁移测试），风险高收益为防未来事故；已加注释预警，建议作为独立工程。
2. BGTask ~30s 预算与「7 天同步 + LLM 调用」不匹配——需拆分为独立任务授予或 BGProcessingTask，属后台架构调整。
3. 心率区间串行查询——`HealthKitQueryService` 是 class 非 Sendable，`withTaskGroup` 并发化需要重构为 actor/struct；当前按日遍历为有界小循环（单日训练数有限），风险低。
4. `VelaResolver.resolve` 未注册即 `fatalError`——有意 fail-fast（DI 配置错误应尽早暴露），保留。

---

## 1. 你点名的两个问题（专项核实）

### 1.1 开屏欢迎页「和真实软件风格不搭」

**结论：属实，而且今天的更新刚把它改得更不搭。** 实测证据（`build/audit-shots/01-onboarding-light.png` 调色板采样）：

- 画布色 `#F2F5F1`、墨色 `#10201C` 其实已经对齐 Rhythm 设计系统 ——「不搭」的观感来自三处：
  1. **主按钮用了 `rhythmDeep`（#0D6B50 深墨绿）而非品牌绿 `accent`（#17A35C）**。今天提交 `b3577992` 刚把开屏 CTA 从 `accent` 换成 `rhythmDeep`（`VelaOnboardingView.swift:353`），主 App 的主按钮仍是品牌绿，一屏两绿。
  2. **全屏裸 `.system(size:)` 字号绕过排版 token**（`VelaOnboardingView.swift:90,113,146,169,249` 等 38pt/30pt/10pt），且同屏混用旧 token `fg/muted`（:221,250,272）——整个 App 里 token 合规度最差的一屏。
  3. **「营销海报」式布局**：超大居中标题「每天，只回答一个重要问题。」+ 特性列表 + 全宽按钮，与主 App 的数据面板气质割裂。
- 另有三段 Bevel 时代死代码没删干净：`heroSection`（:217-244，旧欢迎大 Logo 版）、`signalPreviewCard`（:319-343）、`featureCard`（:555-579）。
- 4 个逻辑 bug（高置信）：
  - 重试检查漏判 `.denied`（:459 vs :437 口径不一致）；
  - 「稍后连接」会静默完成 onboarding 且 `missingData=[]`（:360-361）——用户以为跳过了，实则档案留白；
  - `secondaryGoals: [trainingStyle]` 字段错用（:487-488）——把「训练方式」存进了「次要目标」；
  - 引导页选项集与编辑页不一致：开屏选了 `hybrid`/`balanced` 后，Me 页编辑时这两个值无处可显示，落「待设置」（`VelaMinimalJournalView.swift:732-749`）。

**为什么你今天更新后又看到它**：门 key `vela_onboarding_completed` 未改名，但今天更新确实重写了这屏（108 行改动）。若你此前已完成过 onboarding，需确认是否重装过 App / 容器变化导致标记丢失（候选：`devicectl` 重装、安全模式重建 store）。**建议你在手机上确认：是每次都弹，还是只弹了一次。**

### 1.2 健康档案「既没打通 Apple Health，也没打通 Coach」

**结论：链路其实存在，但你感受到的「没打通」有真实代码依据——是优先级倒挂 + 一条真断链。** 完整数据流现状：

```
编辑档案 → UserDefaults(vela_user_*) → DailySummaryUseCase 填充 extendedMetrics
        → 评分引擎 / AIContextBuilder(age/sex/height/weight + body_model.*) → Coach ✅ 已通
Apple Health → hydrateMissingValuesFromHealth 单向回填 UserDefaults ✅ 已通（仅当 UserDefaults 为空）
```

真正的问题，按你的体感排序：

1. **[P1] VO2max 断链**：`HealthKitQueryService` 有 VO2max 查询，但快照构建时被丢弃（`HealthKitSyncEngine.swift:415-435` 只回写体重/体脂/BMI/血氧/体温，无 vo2Max），且两条 DashboardSummary 路径硬编码 `vo2Max: nil`（`DailySummaryUseCase.swift:304, 924`）→ **UI 和 Coach 永远看不到 VO2max**。
2. **[P2] 手动编辑被 Apple 健康静默覆盖**：`DailySummaryUseCase.swift:263-266` 解析顺序是 `HK 值 ?? 手填值`（HK 优先）——只要 HealthKit 有出生日期/身高/体重/性别，你在「账户与特征基准」里填的年龄/体重/身高/性别**点了「应用」后毫无效果，且无任何提示**；而身体模型页（`BodyModelViews.swift:289-292`）又是手填优先——**两个页面口径相反**。这正是「编辑了没用」的直接原因。
3. **[P2] 手动体重不回写 UserDefaults/HealthKit**；缓存路径（`DailySummaryUseCase.swift:918-930`）丢档案字段。
4. **[P3] casual 短回复不带身体模型**（`CoachContextAssembler.swift:236-263`）——轻量对话时 Coach 看起来「不了解你」。

---

## 2. P1 清单（功能级断链）

| # | 问题 | 位置 | 影响 | 建议 |
|---|------|------|------|------|
| P1-1 | **AgentLoop 写工具全拒（死功能）** | `VelaApp/Features/Coach/CoachRequestRunner.swift:65` 构造 `AgentLoop(provider:toolRegistry:)` 未传 `onConfirmToolCall`；`AgentLoop.swift:301-310` 对 write/destructive 工具无回调时一律返回拒绝 | Coach 对话里 `create_training_plan` / `log_food` / `delete_plan` / `update_wiki` 被提示词诱导调用后**必然被拒**，用户看到的只有「工具被拒绝」错误 | 传入确认回调（弹「AI 提议计划变更，是否确认」符合 ADR 0008），或对无 UI 场景走受限白名单 |
| P1-2 | **VO2max 管道断链** | 见 1.2-1 | Coach/UI 永远看不到 VO2max；HealthAgeTrend 等引擎因子缺失 | 快照构建补 `vo2Max` 回写；去掉两处硬编码 nil |

---

## 3. P2 清单（按模块）

### Coach 对话
- **持久化失败 → 删除成功回复 + 可能永久卡死**：`CoachChatVM.swift:622/658/674-678` — 成功响应落库失败会删掉已流出的成功回复换成「AI 服务不可用」；若 catch 内 `persistThread` 再抛错（未 `try?`），`isStreaming` 永为 true、发送守卫永久挡回 → 只能重启 App。建议：持久化失败与请求失败分通道；catch 内改 `try?`。
- **多失败气泡重试点错对象**：`CoachChatVM.swift:134-142` + `CoachView.swift:593-601/1186-1203` — 重试按钮不带气泡身份，Q1、Q2 都失败时点 Q1 的重试会重发 Q2。
- **stop() 丢弃已流出内容 + 幽灵气泡残留**：`CoachChatVM.swift:520-521/650-655` — 点停止后刚看到的内容全部消失，与注释矛盾；幽灵 `ChatMsg(isStreaming:true)` 从不收尾。
- **流式时强制滚到底**：`CoachView.swift:640-643` — 每个 delta 都 scrollToBottom，用户上滑读历史被拽回。建议「接近底部才跟随」。
- **legacy 导航下切 Tab 麦克风不停**：`CoachView.swift:826-828` + `VelaMinimalShell.swift:375-390` — 所有 Tab 常驻（opacity 隐藏），切走不触发 onDisappear，听写继续录音；无 scenePhase 处理。
- **键盘高度状态只写不读**：`CoachView.swift:508/716/722` — `keyboardHeight` 死状态，输入框防遮挡全靠系统自动抬升，无兜底。

### 今日页 / 共享组件
- **首帧重复计算 3-4 次**：`VelaMinimalTodayView.swift:349-361` + `VelaTodayViewData.swift:195-205` — 主线程 7 组 fetch 重复执行。
- **MetricCoachCard 直连 DeepSeek 无重试/超时/取消**：`MetricCoachCard.swift:224-233` — 绕过 RetryingAgentChatProvider，「全链路 retry」声明此处不成立。
- **卧床时间跨午夜为负 → 显示 0 小时**：`VelaMetricDetailData.swift:533-535` — `wake-bed` 应复用 `sleepDurationMinutes`。
- **暗色模式全详情页白斑**：`VelaMinimalComponents.swift:297,312,319` — 圆环背后硬编码 `Color.white.opacity(0.85)` 白盘。
- **每次评分刷新触发系统震动**：`DashboardViewModel.swift:227-228` — 前台/切日/下拉全震。
- **Hero 标题 42pt 固定字号**不随 Dynamic Type：`TodayHeroCard.swift:592`；体征页用 `systemGroupedBackground` 与今日页 `rhythmCanvas` 双画布（`VelaMinimalVitalsView.swift:94`）。
- 中英混杂「体能负荷 and 日间自觉症状」：`VelaMetricDetailData.swift:858`。
- **设置按钮 VoiceOver 标签硬编码「个人设置,数据已同步」**：`VelaMinimalTodayView.swift:626` — 未同步/出错时读屏仍宣称已同步，应按 `lastUpdated`/错误态动态生成。

### 训练
- **计划复盘响应 ID 空间错配**：`TrainingAnalyticsService.swift:1042-1044` — `TrainingDay.linkedWorkoutEventIds` 存事件 ID，力量训练响应存 `StrengthWorkoutRecord.id` → 力量训练响应永远匹配不上，「恢复成本偏高」分支不可达。
- **周中建计划的「幽灵日」永久遮蔽错过训练**：`TrainingAnalyticsService.swift:974-997` — 计划起始周周一/周二的排期早于 planStartDate，`earliestOverdue` 不排除 → 真正错过的训练永远轮不到。
- **编辑旧训练可产生伪 PR**：`StrengthWorkoutLogSheetView.swift:539` — PR 历史未按日期过滤，拿旧训练跟未来记录比。
- **草稿跨天续录时长无上限膨胀**：`StrengthWorkoutLogSheetView.swift:52-61` — 昨晚建草稿今早完成 → durationMinutes 数百分钟，污染容量/负荷/卡路里。
- 详情页硬编码冷蓝 hex（`StrengthWorkoutDetailView.swift:139/223/465-468`）；「蛋白质 and 碳水」中英混杂（`StrengthWorkoutLogSubComponents.swift:510`）。
- 残余：手动补录 + 训记导入同一场训练 → 双记录（三源合并已收敛，仅剩此场景）。

### 评分引擎
- **睡眠数据缺失被误判「减量」**：`TodayCommandState.swift:150` — `sleepScore.score` 无数据时为 0，缺 `hasData` 保护 → 无睡眠数据的早晨得到「reduce」决策 + 误导性理由。
- **Strain「28 天」CTL 实际吃进 42 天窗口**：`StrainScoreEngine.swift:287-291` + `ScoreEngineFactory.swift:363-375` — 窗口不匹配，与 EnergyBank（CTL 42d 名实相符）口径不一致。
- **EnergyBank `todayLoad` 回退混用评分域与 TRIMP 域**：`EnergyBankEngine.swift:137` — nil 时把 0-100 评分混入 TRIMP 历史。
- **Readiness 硬编码场景系数仍在**：`TodayCommandState.swift:107-163` — 0.50/0.30/0.20 加权已实现，但 0.86/0.78/0.74 等 7 个场景系数仍作乘数叠加，置信度数值语义不可解释。
- Stress 引擎 Z-score SD 无下限地板（`StressIndexEngine.swift:135-136/192-193`）——当前路径恰好安全，属隐患。

### HealthKit / 持久化
- **42 天历史实际返回 41 天且整体偏移一天**：`HealthSnapshotRepository.swift:92-108` + `DateRangeQuery.swift:65-77` — 记录 date 存日历午夜，窗口是 04:00 健康日 → 所有滚动基线（MAD/EWMA/ACWR）系统性少最老一天。
- **持久化 dailyLoad 与实时 daily_load 双公式混用**：`WorkoutAggregationService.swift:290-339` — 快照不回写引擎 dailyLoad，历史（RPE 标度）与今日（TRIMP 标度）混进 EWMA/ACWR。
- **同步全管线在 MainActor**：`HealthKitSyncEngine.swift:117-282` — 90 天重同步持续卡 UI，任一查询挂起无限阻塞。
- **无 HKObserverQuery/后台投递**：晨报可能缺当夜睡眠；补授权后无自动重拉。
- **VelaSchemaV2 指向可变模型清单**：`VelaModelContainer.swift:331-335` — 未来增删模型会改变 V2 历史 checksum，已上架设备迁移失败（潜伏事故）。

### AI 链路
- **ReportGenerator 用 `prefix(12000)` 截断 context JSON → 非法 JSON**：`ReportGenerator.swift:21`。
- **90s maxDuration 形同虚设**：`AgentLoop.swift:157/218` 只在迭代间隙检查，单次请求 120s×3 重试可击穿，最坏 ~11 分钟。
- **后台 Agent 无重试且 30s BGTask 预算内跑不完**（MorningBrief/EveningWiki 直连 provider；7 天同步 + LLM 调用超预算，expirationHandler 掐断后静默丢失）。
- **WebSearchHelper Bing HTML 抓取 + 伪造 iPhone UA**（`WebSearchHelper.swift:19-24`）——违反 ToS，合规风险。
- **Coach 路径 legacy `[ACTION:update_wiki]` 解析与 `update_user_wiki` 工具双通道并存**：`CoachChatVM.swift:590-608` — 同一事实可能产生两条提案，互不去重；建议 Coach 路径禁用 legacy 解析。
- **重试判定靠错误消息子串匹配 + 指数退避无 jitter**：`AgentLoop.swift:130-134` + `LLMProvider.swift:158-171` — 错误文案变化即失效；并发重试同步打向 API（429 雪上加霜）。
- **流式不解析 `finish_reason`**：`DeepSeekProvider.swift:213-231` — 2048 token 截断长报告时以 `invalidResponse` 报错，用户看到「无法解析」而非「回复过长」。
- **提示注入面：wiki 内容原样进 system prompt**（`CoachPromptComposer.swift:45-47`）——web 结果有 untrustedContext 防护而 wiki 没有，建议加「用户档案数据，非指令」边界声明。
- **餐食照片发往第三方 Moonshot/Kimi**（`FoodPhotoAnalyzer.swift:152-199`）——原始媒体出网到非 DeepSeek 供应商，隐私披露未覆盖；另 `:278` 单食物热量 `as? Int` 与 `asInt` 修复不一致（240.5 kcal 静默变 0）。

### 个人页 / 设置
- **`hubActionCell` 的 `color:` 参数从未使用**：`VelaMinimalJournalView.swift:591-628` — Me 页 6 个入口的彩色意图全部失效，图标恒为 rhythmDeep 同色。
- `bodyModelUnifiedCard` 死代码且含硬编码色（`VelaMinimalJournalView.swift:191-325`）。
- **三处「健康档案」命名冲突**：Me 页 → wiki 归档、设置页 → wiki、身体模型页「基础健康档案」→ 生理特征，三个入口叫同一个名字指三样东西（`VelaMinimalJournalView.swift:571` / `VelaSettingsView.swift:38` / `BodyModelViews.swift:386`）。
- 开屏页同一视图挂两个 `.alert`（`VelaOnboardingView.swift:59-65` 与 :66-81）——SwiftUI 同视图多 alert 通常只有最后一个生效，授权失败弹窗可能被遮蔽。
- 问候语硬编码「早上好，Weizhou」（`VelaMinimalJournalView.swift:535`）。

### 档案 / 开屏
- 见 1.1、1.2 的全部 P2。

---

## 4. 与大厂标准的系统性差距（设计轴）

这四类是全 App 级问题，单点修复解决不了，建议按序治理：

1. **Dynamic Type 基本失效（最严重）**：全仓库 **885 处固定 `.system(size:)` 字号，`@ScaledMetric` 0 处**；开屏、详情页、训练表单、Coach 头部全部不随系统字号缩放。这是 Apple HIG 审查第一眼就能发现的硬伤。
2. **Token 纪律**：VelaTheme 之外散落 **157 个 hex + 164 个具名系统色 + ~1200 处硬编码间距**（涉及 23/47/69 个文件）；`cardGap=12` 与规范 14 不符；`fillSoft` 残留旧 Signal Blue。
3. **对比度不达标**：`meta` 文字画布上约 **1.9:1**（亮暗均败，WCAG 要求 4.5:1）；`accentOn` 暗色 2.13:1；TodayHeroCard 白色图标压 rhythmDeep 仅 **1.55:1**（`rhythmDeepOn` 存在却未用）。
4. **死代码约 2000+ 行**：`CoachChatPanel`/`CoachInputBar`/`MiniBubble`（~700 行，且与主路径 VM 是两套实例）、`GlassTabBar`/`ScoreRing`/`DayPill`、Journal 视图、今日页风景视图与 G1 组件、开屏 3 段 Bevel 残留、`WebSearchService`。另有一个**用户可感知的死链**：`OpenVelaFoodScannerIntent` 注册进系统快捷指令但无任何响应（`VelaApp.swift:213`）。

### 交互与文案
- 动效：每轮评分系统震动、`animatedEnergyScore` 空跑动画、scrub 每点震动。
- 文案：多处中英混杂（「蛋白质 and 碳水」「体能负荷 and 日间自觉症状」）；FoodPhoto 用户消息硬编码英文进中文对话（`FoodPhotoWorkflow.swift:30-36`）；「模版」错字（`VelaQuickActionsSheet.swift:61-62`）；「由 DeepSeek 提供强力支持」生硬。

---

## 5. P3 精选（低优先级，汇总）

- 睡眠时长分量上下界不对称（睡 11h 惩罚 < 睡 5h）；Method A/B 对「其他」性别参数不一致；历史 Stress 不做运动窗口排除；`trainingLoadStatus` 历史不足默认 `.optimal`；`clamp` NaN→100 无防护；e1RM 被 reps≥3 门控（真实 1RM 不计入）；`buildRecentSummary` 绝对秒窗口不对齐自然日；重量输入 `fractionLength(0...1)` 与 0.25kg 配片冲突；`sleepEpisodes` 未扩窗截断跨 04:00 夜晚；HRV/RHR 分桶锚 1970 午夜差 4h；`VelaResolver.resolve` 未注册即 fatalError；Watch 会话未激活时 `try?` 静默丢 applicationContext；`Meta` 新档案字段在缓存路径丢失；流式会话操作静默忽略无反馈；预览数据绕过唯一评分入口且不覆盖 HR 路径。

---

## 6. 修复路线建议

**第一批 · 正确性（建议 1-2 天内完成，全部可配回归测试）**
P1-1 工具回调、P1-2 VO2max、41/42 天窗口、睡眠缺失误判 reduce、档案优先级统一（HK 优先 + 编辑页明示「覆盖 Apple 健康」开关 + 来源徽标）、Coach 持久化失败隔离、重试锚点、stop() 内容固化、计划响应 ID 空间、幽灵日过滤、编辑伪 PR、ReportGenerator JSON。

**第二批 · 设计系统性治理（按序）**
① `@ScaledMetric` + 语义字号迁移（先开屏/详情页/Hero）；② 硬编码色收敛（先暗色白盘、训练详情冷蓝、体征页双画布）；③ 对比度修复（TodayHeroCard 图标、meta、accentOn）；④ 死代码清理（约 2000 行，含食物扫描 intent 死链）。

**第三批 · 体验**
震动策略（仅显式确认动作）、流式滚动跟随、开屏页重设计（去掉营销海报感 + 按钮回归 accent + 死代码删除 + 4 个逻辑 bug）、中英文案清理、切 Tab 停麦克风。

> 建议每个修复单独提交、附回归测试（当前基线 631 测试全绿）；我会对改动的模块先跑对应测试再交给你。

---

## 算法与数据使用优化（2026-08-14）✅ 六项全部完成并推送

按 C1 → B1 → C2 → B2 → C3 → B3 顺序：

- **C1 决策反馈回灌**：新增 `DecisionFeedbackCalibrator`——`DailyDecisionFeedbackRecord`（此前只写不回）按同类决策近 28 天的准确率校准 readiness 置信度（≥3 样本生效，乘数 0.6+0.4×准确率）；今日页反馈 Sheet 保存后即时重校准。
- **B1 时间衰减个人基线**：`PersonalBaselineEngine.recencyWeightedMean`（近 7 天权重 ×2）——wiki baselines.md 全部均值、RHR/呼吸率基线改用加权（HRV 保留中位数+MAD 稳健性）。
- **C2 个人反应规律进计划**：已确认（accepted）的 observation 类记忆规律（≤2 条、每条 ≤40 字）直接注入今日计划 summary「参考你的长期记录：…」——本地规则引擎也能用，不再只有 AI 知道。
- **B2 数据覆盖度联动**：Hero 头部新增覆盖徽标（完整/中等/有限），低覆盖时显式标注「按保守方案」。
- **C3 训练响应校准**：`TrainingResponseCalibrator` 用近 28 天训练后次日恢复变化均值全局校准容量系数（keep/reduce 参与；平均 +N 分 ≈ +N% 容量，钳 [0.85, 1.1]）；接入生产路径 `TrainingDecisionKernel`（此前 RecoveryTrainingAdapter 只在死代码 TrainingDecisionEngine 中被调用——本次一并发现并接通）。
- **B3 token 预算**：`ContextBudget.estimatedTokenCount`（汉字 1.5/字、ASCII 0.25/字符），wiki 裁剪按 token 而非字符。
- **A1/A3/D1（前序）**：睡眠一致性基线 42d→13 晚；Strain/EnergyBank EWMA 暖启动（初期 7 天均值种子）；HKObserverQuery 后台投递（晨间数据到达即重排刷新）。
- **测试**：+6 回归（校准器×2、加权均值、token、EWMA 离群、训练响应校准），全量 331/331 绿；已推送到 iPhone。

## 个人档案维护与互通专项（2026-08-14）✅ 已修并推送

全新走查（写入冲突/读取不一致/流向断点/闭环缺失）发现并修复：

- **档案建档 4 bug**：①「稍后连接」不再静默留空档案（真实记录缺失信号）；②「重新检查」补上 `.denied` 判定；③ `secondaryGoals` 不再误存训练风格（两处）；④ 编辑页训练风格/教练风格选项集对齐 onboarding（hybrid/endurance/balanced），显示函数补全映射 + 旧值兼容——此前 hybrid/balanced 编辑即丢值。
- **[P1] 年龄解析统一**：AI 上下文 5 处（Coach/晚间同步/MetricCoachCard/DomainContextBuilders/BiologyView）从「wiki 优先」改为「dashboard（手动→HK）优先、wiki 兜底」——手动年龄不再被 wiki 旧值静默覆盖。
- **[P1] 性别引擎补 HK 兜底**：`DailyHealthComputationProfile.current(ageFallback:biologicalSexFallback:)` 增加 HealthKit characteristics 兜底，HealthKitSyncEngine 调用处传入——女用户未手填性别时，Strain 引擎不再误用 "other" 插值系数（0.75/1.80 → 0.86/1.67）。
- **[P1] 引擎年龄补 HK birthdate 兜底**：maxHR 推断链补齐，心率负荷（TRIMP）不再因缺手填年龄被整体跳过。
- **[P2] maxHR `explicit` 死参数删除**：唯一解析链收敛为 UserDefaults → wiki → 年龄推断（显示层与引擎同源）。
- **[P2] baselines.md 手改覆盖**：编辑档案列表排除 baselines.md（引擎自动生成、每次刷新覆盖），与 WikiProfileView 态度一致——手改不再静默丢失。
- **文档化（有意设计）**：本地 TrainingDecision 仅基于生理状态+训练计划（目标/设备/教练风格只进 AI 上下文 `body_model.*`，ADR 0008 语义）；身高缓存态无兜底（record 无 heightCm 字段，避免 schema 变更——与 VO2max 同策略，live 后即恢复）。
- **测试**：331/331 全绿；已推送到 iPhone。

## 健康档案页空白（模板污染 + 解析偏差）修复（2026-08-14）✅ 已修并推送

用户反馈：Coach 三点菜单 → 健康档案仍空白可编辑，但 agent 明显掌握用户档案。复查发现三个叠加根因：

- **[P1] 空模板落盘污染（关键）**：`WikiSyncManager.sync`（每次仪表盘刷新即调用，`DailySummaryUseCase.swift:642`）会把 `defaultContent` 空英文模板写进本地 wiki 文件。上一轮 materializer 的「本地为空才写入」判定被模板挡住（文件非空→跳过），**从未在真机生效**。修复：sync 不再把空模板落盘（模板仅展示兜底）；新增 `WikiFileService.isUninitialized`（空或等于空模板→视为未初始化），materializer 据此一次性修复已污染的 14 个文件；与模板不同的用户手改内容永不覆盖。
- **[P1] 档案页解析器只认英文模板标签**：`WikiProfileView.parseFields` 只匹配 `Age/Activity level/...`，materializer 与 agent 写入的中文标签（`主要目标` 等）一律渲染为空。修复：新增共享 `WikiBulletParser`（任意 `- 标签: 值`，中英文冒号均可），空内容回退模板字段；编辑保存的 `preferredOrder` 改为草稿标签本身，中文标签可原位替换与补齐；补充中文标签占位提示。
- **[P1] 生理档案与 wiki 断链**：agent 经 `update_user_profile` 维护的年龄/体重/身高/最大心率/性别只写 UserDefaults（`vela_user_*`），档案页只读 wiki。修复：`WikiProfileMaterializer.refreshPhysiologicalProfile()` 按标签 upsert（中英文别名均可命中）把这五个字段合并进 profile.md，其余内容一律保留；App 启动（materializeIfNeeded 内）与 `UpdateUserProfileTool` 确认执行后调用——Coach 改完档案，归档即时同步。
- **测试**：+7 回归（sync 不落盘模板 / isUninitialized / 污染模板覆盖 / 手改保护 / 生理字段合并与保留 / 中英文解析 / 模板回退），全量 **338/338** 绿；已推送到 iPhone（databaseSequenceNumber 2548）。

## 数据利用与数据流通专项（2026-08-14，六域审计 + 四批修复）✅ 已修并推送

六域并行审计（摄入评分链路 F / AI 上下文 A / 记忆档案多存储 M / 训练数据流 T / 主动服务与反馈 PR / 只写数据盘点 D）共 ~50 项，其中 **4 项推翻了既往「已修复」结论**（T1 训练响应增量从未回填、T2 RecoveryTrainingAdapter 仍死代码、M2 引擎年龄仍 wiki 优先、CLAUDE.md「反馈未回灌」过时）。四批全部修复，全量 **345/345** 绿，已推送（databaseSequenceNumber 2580）。

**批次 1 — 决策正确性**：F1/M1 前台重算补 HealthKit 年龄/性别兜底（此前覆盖持久化分数时退回 other/缺年龄链）；F2 档案修改触发强制重算（Today onChange + 非活跃页 pending 标记）；F3 `makeSnapshot` energyBank 不再硬编码 nil；T1 `captureTrainingResponses` 对已存在记录回填次日增量（手动训练主路径恢复响应不再恒空）；PR1/PR2 反馈枚举 `rest`↔`recover` 归一化 + 删除死方法 `submitDecisionFeedback`；F5 后台投递脏标记越过 4 小时 TTL；F4 展示决策摘要窗口 7d→28d 与持久化路径一致。

**批次 2 — AI 数据通路**：A1 `compactDailyOperatingPlan` 完整计划（主行动/理由/置信度）入 v2 快照 + 紧凑渲染；A2 持久化 Scored Health Evidence 与 RMSSD 进 `get_today_health`/`get_health_history`/`RecoveryContext`；A3 新增只读 `get_decision_feedback` 工具（16 字段回灌）；A5 wiki 空模板过滤出 AI 上下文（`loadPopulatedDictionary` + mergedUserWiki 过滤）；A9 v2 TrainingContext 死字段补齐（activePlan/workoutListJSON）；T5 负荷处方 e1RM 反推 + 增幅封顶 2.5%（替代复制上一组重量）。

**批次 3 — 效率与死重**：D1 膳食宏量营养素 4 查询加 nutritionEnabled 门控；D2 删除 9 个只写不读的 extendedMetrics 查询；F7 删除死代码 HealthDataRefreshService（保留 DailyHealthContext 定义）；A8 35 天快照 fetch 改 fetchLimit=1；A12 recentTrends 占位符移除；T7 停止写 analyticsJSON（哈希改用训练事实）；T8 XunjiSetMetrics 只保留被消费的 avgHeartRate；D3/PR3 停止持久化 ProactiveInsightRecord + 删除死 @Query；D7/D8 删除 suggestedActions 与 signal 死字段 + 死视图（EvidenceSheet/SignalRow/TodayActionTimeline）；D10 删除 WebSearchService。

**批次 4 — 长期一致性**：M2 引擎年龄解析统一为 手动→HK→wiki；M3 设置页改档案回写 wiki+记录（与 Coach 工具对称）；M4 提案入口拒绝 baselines.md（引擎 .replace 会抹掉已确认基线记忆）；M5 回滚 hash 不匹配写 userNote 不再静默；M6 孤儿 .md 记录日志；M8 `writeFileThrough` 写透 helper 统一全部写入口；M9 merge 子串去重加 ≥8 字符门槛；A4 ContextBudget 字段真正生效（报告 4 条/趋势/计划 14 天/wiki 3000）；A6 晨报迁移到 v2 AgentFactSnapshot（v1 序列化器保留为测试覆盖的兼容层，下轮删除）；A10 计划枚举与 web 结果截断；A11 注入 wiki 剥除生理字段行；T3 计划执行复盘回灌 Coach 上下文；T4 训记去重加 60 分钟窗口；T6 相关引擎三入口统一到 calculateInsights + 图表工具返回真实 r/n；PR4 createProposal 跨源相似度去重；PR5 保留策略扩展（对话交互 90d/产品事件 180d/记忆终态 90d/主动洞察全清，用户内容永久保留）；PR6 晨报新鲜度按 04:00 健康日边界；PR8 历史报告完整正文阅读页；PR9「部分准确」按 0.5 计分（校准只降不升，上限 1.0）；PR11 晨报通知带报告首行正文；F8 快照存原始 HK 体重；F9 数据未变化不推进新鲜度（强制刷新除外）；F10 历史日按日末评估。

**有意保留/延迟（已文档化）**：D4 SleepSummaryRecord 死模型留在 schema（零 schema 变更政策，删除会破坏 staged migration）；D6 CoachArtifact 6 种类型保留为 AI 线格式合同（展示脚手架齐全，等待接入产出端）；T8 组类型（drop/backoff/failure）计入容量语义暂不区分（需训练方法学决策）；A6 v1 序列化器与 DomainContextBuilders 保留（10+ 回归测试覆盖，下轮随测试迁移一并删除）；PR7 BGTask 30s 预算（架构级，需 BGProcessingTask 授权）。

## 今日节律曲线真实化 + 交互（2026-08-14）✅ 已修并推送

审计发现：今日页「今日节律」曲线（`RhythmHorizonVisualization`）此前把 5 个**截面分数**（睡眠/恢复/压力/负荷/能量）用硬编码基准位平铺到「早→晚」假时间轴上——数值真实、时间轴伪造，向用户传达不存在的日内演化信号；训练页两条曲线（30 天耗力趋势 / 12 天耗力对比 + 月度热力图）则一直是真实 `strainScore` 历史。

修复（视觉风格不变，纯数据与交互层改动）：
- **节律曲线真实化**：唯一数据源改为 signal card 自带的真实 7 天历史趋势数组（`RhythmTrendSource.series`，由 `DailyHealthSummaryRecord` 历史评分构成，含当天值）；x 轴「早/午/晚」换成真实日期标签（M/d + 今天）；历史不足时虚线占位不伪造；带宽仍由决策驱动。
- **指标切换交互**：曲线下方新增 5 个同源胶囊（恢复/睡眠/负荷/压力/能量），点击切换指标，弹簧动画过渡。
- **拖动查看数值**：在曲线上拖动，圆点吸附到最近一天并显示「日期 · 指标 数值」气泡（与图表同源的真实分数）；松手回到今天。
- **训练页 30 天曲线同步加交互**：`AreaChartCurveView` 支持拖动查看每天真实耗力分数与日期（值/日期与曲线同序传入）。
- **测试**：+1 回归（`RhythmTrendSource` 必须来自 trend 数组、不足不伪造、越界钳制），全量 **346/346** 绿；已推送到 iPhone（databaseSequenceNumber 2588）。

**节律曲线补充：按天/按小时双粒度（2026-08-14）✅ 已修并推送**

- 曲线下方新增「按天 / 按小时」分段切换（小胶囊，风格不变）。
- **按天**：所选指标（恢复/睡眠/负荷/压力/能量）的真实 7 天趋势（前次实现，不变）。
- **按小时**：当日逐小时心率——`RhythmTrendSource.hourlyHeartRate` 把所选日期 HealthKit 心率样本按小时聚合为均值（30-220 bpm 映射同一垂直区间），x 轴为 0时/12时/24时；拖动显示「14:00 · 72 bpm」；不足 3 个小时有数据时虚线占位不伪造；切换即按需查询（HealthKit 已授权读取心率），按天缓存结果。
- **测试**：+1 回归（逐小时聚合/同日过滤/均值），全量 **347/347** 绿；已推送到 iPhone（databaseSequenceNumber 2596）。

**节律曲线按小时模式扩充为四指标（2026-08-14）✅ 已修并推送**

按小时模式从单一心率扩展为四个真实日内指标（全部来自 HealthKit 真实样本，不做小时级得分伪造——日级得分本质是日粒度）：
- **心率**：逐小时均值 + **静息基线虚线参考**（高于基线=负荷/压力、低于=恢复，呼应恢复/压力评分逻辑）；tooltip 显示「72 bpm（静息 +12）」
- **活动强度**：小时级 TRIMP 启发式——小时平均心率储备率（HR/(maxHR−RHR)）× 覆盖分钟（5 分钟/样本估算，封顶 60）；缺个人静息/最大心率基线时为空不伪造
- **步数**：逐小时步数（当日动态刻度，至少 500 步）
- **能量消耗**：逐小时活动能量 kcal（当日动态刻度，至少 100 kcal）
- 新增 `HealthKitQueryService.hourlySums`（HKStatisticsCollectionQuery 逐小时累计聚合）；四指标一次任务并行加载、按天缓存；任一指标不足 3 个小时有数据时虚线占位。
- **测试**：+1 回归（储备率负荷计算/缺基线空值），全量 **348/348** 绿；已推送到 iPhone（databaseSequenceNumber 2604）。
- **补丁（2612）**：按小时数据加载 `.task(id:)` 此前不含粒度值，切换「按小时」不会重新触发加载，四个指标因此空白——id 加入 granularity 后切换即拉取。
- **数值标注模式（2620）**：点一下曲线 → 每个数据点右侧标数值（步数千位缩写如 1.2k、活动强度保留一位小数）+ 右上角「最高/最低」图例；再点一下恢复干净模式。拖动查看数值不受影响。
- **训练页曲线同款交互（2628）**：12 天耗力对比（SafeZoneWorkloadChartView，传真实分数+日期）与 30 天耗力趋势（AreaChartCurveView，>15 点隔点标注）均支持：点按标数值 + 最高/最低图例、拖动看「日期 · 分数」。
- **Training Rhythm 轮转路径真实化（2636）**：训练 tab 顶部轮转路径（背/胸/肩/腿/臂）此前是纯装饰——无数据、不可交互。现在每个站位接入 `RecentTrainingSummary.localFatigue` 真实数据：站位圆环按疲劳等级着色（避开=红/留量=琥珀/可练=绿描边）、节点下方显示 7 天有效组数（无数据显示 "—"，不伪造）；点选站位 → 顶部胶囊显示「背部 · 7 天 12 组 · 48h 6 组 · 可练」，再点取消；休息日无点选时仍显示「恢复窗口」。
- **Training Rhythm 剂量环重构（2644，四方向头脑风暴后选定「剂量环 + 证据锚点」）**：装饰波浪路径彻底移除，改为居中**剂量环**——弧长=今日容量比例（volumeMultiplier，rest 空环）、颜色=决策性质（keep 节律绿 / reduce、swap 琥珀 / rest 灰）、环心=容量% + RPE 上限；无计划时环外虚线外圈=保守边界。环周 5 个未来站位点（真实肌群疲劳门控 + 7 天组数 + 点选详情胶囊）保留轮转身份；headline 下方新增「为什么」证据层：一行最强理由 + 点按展开完整决策理由与恢复/睡眠/负荷真实评分胶囊；点环 = 展开证据（与站位点选互不干扰）。不依赖激活计划：环由本机决策驱动、站位点由肌群疲劳驱动，无计划同样成立。
- **Training Rhythm 轮转时间轴（2652，用户方向）**：可视化改为「最近训练 → 未来推荐」时间轴——左边 3 天真实训练记录（`TrainingRotationHistory.recentDays`：按天聚合实际练过的肌群，显示 胸/背/腿 等短标签，休息显示「休」）、今天节点（决策+容量/RPE 详情，rest 显示「休」）、右边 3 天最佳部位推荐（`TrainingRotationRecommender.upcomingDays`：排除高疲劳肌群 → 按 48h 组数升序轮转交替 → 恢复评分低于阈值时先插恢复日；每条附「依据：48h X 组 · 7 天 Y 组」）。点任意节点 → 底部胶囊显示详情（昨天练了什么 / 明天为什么推荐腿部）。不依赖激活计划。证据层/边界三连/CTA 保留；剂量环移除（剂量信息并入今天节点详情与边界三连）。
- **训练页布局整改 + 日历热力图（2660，用户方向）**：移除「决定下一次训练」大标题与轮转时间轴，顶部改为**训练节律日历热力图**（`TrainingHeatmapData.weeks`：最近 5 周、周一起始、每格=当天训练强度 0-3 档（workoutCount/热量/时长分档，与 DEEP ANALYSIS 同源规则），无=浅灰/轻=浅绿/中=绿/高=节律绿；今天描边高亮；未来天弱化占位；点格子 → 胶囊显示「8/12 · 胸、肩」真实肌群；下方图例 + 提示）。热力图下是紧凑的今日安排行（左：保持计划/下一站·胸部；右：容量%·RPE·时长）+ 未来推荐条（「接下来 · 明 腿 · 后 背 · 第3天 休」）。证据层/Watch 说明/CTA 保留。测试：热力图周对齐/分档/肌群聚合回归；另修复 2 个在 00:00-04:00 健康日边界下随墙钟波动的既有测试（锚定正午）。
- **热力图放大 + 点按修复 + 当日内容 + 未来三天规划卡（2668）**：格子从 16pt 加大到 26pt（圆角 6、间距 6），点按加 `contentShape` 扩大命中区、同格再点取消（选中格加描边）、详情区改为固定高度（图例↔详情切换不再跳动）；当天详情升级为「力量 胸、肩 · 有氧 30 分 / 休息」（`TrainingHeatmapDay` 增加 `cardioMinutes`，非力量 WorkoutSummary 按天聚合）；数据窗口从 -29 天扩到 -42 天（此前 5 周网格最老一行可能缺数据）；「接下来」一行升级为**未来三天规划三张等宽卡**（明天/后天/第3天 + 推荐部位或「休息」+ 依据短注）。测试补有氧聚合断言。
- **Coach 参与未来三天决策 + HealthKit 训练记录读取修复（2708）**：未来三天规划卡新增「✨ Vela 规划」按钮——`TrainingPlanAdvisor.suggestNextDays` 把真实数据（肌群疲劳组数/恢复睡眠负荷评分/最近 3 天训练/本地推荐）发给 DeepSeek 复核，返回 JSON 规划（解析容忍 markdown 包裹、过滤非法肌群与越界天数、休息日空 groups），成功显示「Vela 建议」徽标 + 卡片 AI 角标 + 「重新生成」，失败静默回退本地建议（ADR 0008：只提议不落盘；联网按 AutoAgentConfig 健康数据门控）。HealthKit 读取修复：`recentWorkouts(limit: 30)`（无谓词只取最新 30 条，训练频繁时热力图/趋势漏旧记录）改为 60 天日期窗口 `workoutSummaries(in:)`。测试 +1（规划解析回归），全量 352/352 绿。
- **健身记录读取链路专项排查（2772，摄取+消费双侧审计 22 项，修复 12 项）**：① [P1] 前台刷新补 `upsertHealthKitWorkoutEvents`（此前当天 Apple 健康训练只在后台同步落事件，前台刷新时热力图分档/时长/热量缺失）；② [P1] `aggregateDay` 不再回读自反馈陈旧的 workoutsData（已删除训练不再复活），改为事件 + 黑名单过滤，删除后 `workoutCount/时长/热量` 正确回滚（`resetActivityTotals` 覆盖 max 语义残留）；③ [P1] 计划日打卡扩展到 Apple Watch 有氧与训记导入（`linkActivePlanDay` 收口，nil 力量时按活动类型匹配）；④ [P2] 中文肌群标题匹配（「胸 + 三头」↔ chest/triceps 别名映射），自动打卡不再失效；⑤ [P2] 删除训练回滚计划日 `isCompleted/打卡字段`；⑥ [P2] 无 strain 时不再提前 return 跳过 `loadDynamicData()`（整页空白）；⑦ [P2] 本地镜像事件按黑名单过滤（删除后列表/计数不再残留）；⑧ [P2] HK 60 天窗口锚定浏览日；⑨ [P2] 后台投递把最近 7 天标脏（晚到训练的历史日重算）；⑩ [P2] 00:00–04:00 训练按日历日聚合（此前写错 record）；⑪ [P3] DeletedWorkoutRecord 双入口查重插入；⑫ [P3] 删除后事件 source 重算、活跃计划按 isActive 谓词取、「蘘绳肌」错字、活动摘要页按 35 天窗口取数。测试 +4（事件 upsert/删除清理、黑名单不复活、中文标题打卡、另有 heatmap 相关），全量 **355/355** 绿。
- **健身记录读取链路补丁（2780）**：摄取侧审计的剩余四项——① 前台 `aggregateWorkouts` 也用黑名单过滤后的列表（此前只过滤了 upsert，合并仍用原始列表，删除的训练会回到当日 dashboard 负荷）；② `isBenignHealthKitDataError` 不再把 `.errorAuthorizationDenied/.errorInvalidArgument` 当空数据，三处 `if error != nil { return [] }` 统一为「良性→空、非良性→抛出」（授权被拒时不再静默显示无数据）；③ `apply(snapshot:)` 在快照含 workouts 时一并落库 `workoutCount/workoutTypes/workoutDuration/workoutsData`，消除「必须紧跟 aggregateDay」的隐式契约（对应测试反转断言）；④ 有氧分类补齐 HIIT/Cross Training/Mixed Cardio/跳绳（此前漏出有氧统计），`displayName` 补 mixedCardio/other。全量 **355/355** 绿；已推送（2780）。已知边界（已文档化）：跨源同场训练仍靠时间/类型启发式去重（Xunji 无稳定外部 ID 无法根治）；60 天窗口心率样本全量拉取 O(n×m) 待按区间限窗优化。
- **热力图详情「恒显示休息」修复（2788）**：热力图点格子显示「休息」的根因——详情数据源此前用异步 `recentWorkouts`（HealthKit 同步完成前为空），且肌群只来自 App 内手动力量记录，HK 同步来的力量/有氧既不进肌群也不进类型名。修复：详情数据源改为 SwiftData 事件（同步即用、含 HealthKit 镜像），`TrainingHeatmapDay` 增加 `activityNames`（当天训练类型：力量训练/跑步/骑行…），点击详情现在显示「力量 胸、肩 · 有氧 30 分」或「力量训练 · 跑步」；`isStrength` 补充 healthKit+xunji/healthKit+strengthLog 合并来源。测试 +1（HK 力量训练必须出现在当天类型里）。
- **训练规划卡重排（2796）**：取消第 3 天，改为「今天 + 明 + 后」三张卡——今天卡由今日决策驱动（目标部位/休息 + 决策徽标 + 容量%·RPE·时长边界，描边强调）；未来卡由本地推荐器（改为 2 天）或「Vela 规划」（AI 提示词同步改为两天）驱动。

## 附录 A：Token 合规 Top Offenders（硬编码值计数，VelaTheme 之外）

| 文件 | hex 色 | 具名系统色 | 固定字号 | 硬编码间距 |
|---|---|---|---|---|
| Features/Minimal/TodaySubSheets.swift | 4 | 8 | 83 | 83 |
| Features/Minimal/TrainingStatsSection.swift | 9 | 0 | 45 | 44 |
| Features/Minimal/VelaMinimalJournalView.swift | 16 | 5 | 29 | 47 |
| Features/Settings/BiologyView.swift | 0 | 8 | 24 | 53 |
| Features/Minimal/JournalComposeSheet.swift | 0 | 8 | 42 | 34 |
| Features/Training/WorkoutDetailView.swift | 23 | 3 | 31 | 24 |
| TrainingIntelligence/Views/StrengthWorkoutDetailView.swift | 11 | 2 | 40 | 25 |
| Features/Coach/CoachWelcomeWorkspace.swift | 0 | 8 | 23 | 40 |
| Features/Minimal/TodayHeroCard.swift | 0 | 6 | 21 | 43 |
| Features/Minimal/SettingsCoachModelView.swift | 1 | 7 | 35 | 26 |
| Core/DesignSystem/VelaDesignSystem.swift | 8 | 7 | 18 | 34 |
| Features/Minimal/VelaMetricDetailLandscapes.swift | 44 | 3 | 4 | 7 |
| 全仓库合计（23/47/69 个文件涉险） | 157 | 164 | 885 | ~1207 |

## 附录 B：验证方法

- 模拟器实拍：`build/audit-shots/` 共 6 张（01 开屏浅 / 02 开屏深 / 03 今日浅 / 04 今日深 / 05-06 Accessibility 字号），OCR 与调色板采样脚本 `build/audit-ocr.swift`（Vision 框架）。
- 关键结论人工复核过的：P1-1（读 `AgentLoop.swift:295-320` 确认无回调即拒）、P1-2（读 `HealthKitSyncEngine.swift:415-435` 与 `DailySummaryUseCase.swift:300-308/918-930` 确认）、档案优先级倒挂（读 `DailySummaryUseCase.swift:255-273`）、开屏按钮色（调色板实测 #0D6B50 vs 规范 #17A35C，且 `git show b3577992` 证实今天刚改）。
- 编译基线：模拟器构建通过（workspace 内 DerivedData，`build/audit-DerivedData`）；测试套件未重跑（CLAUDE.md 记录 631 全绿，如需要可补跑）。

## 训练页四模块完善（2026-08-15 · 计划与轮转 / 局部训练状态 / 趋势与记录 / 深入分析）✅ 已修并推送

训练 tab 主页四个模块此前偏「壳」：计划只是静态列表、局部状态行不可交互、趋势入口无卡片无图、深入分析混用旧设计 Token。本次在保持 Rhythm 风格的前提下全部接入真实数据并补交互（用户要求：完善或重新编排，保持当前风格）。

- **页面重排**：主页顺序改为 计划与轮转 → 局部训练状态 → 趋势与记录（与用户心智模型一致；Hero 与练后反馈卡不动）。
- **计划与轮转**：
  - 主页 `TrainingPlanPortal` 新增**轮转序列条**——活跃计划的训练日序列（最多 7 个：完成=实心勾、今天=节律绿描边、未来=弱化、rest 显示「休」、有氧/灵活显示「有氧/活」，超出显示 +N），数据源为 `TrainingPlanRecord.days` 真实序列。
  - `VelaTrainingPlanView` 计划日行可展开：计划动作（`plannedExercisesJSON` 解码：动作 × 组 × 次数）、**实际执行记录**（`linkedWorkoutEventIds` 反查 WorkoutEventRecord：日期 · 训练类型）、依从度徽标（`adherenceScore`）、完成时间；计划与事实闭环可见。
  - 「今天如何调整」从一句通用文案改为**真实今日决策面板**：当日运营计划（`DailyOperatingPlanRecord`）的决策徽标 + 容量%/RPE 边界 + `summary` + 最多 3 条决策理由；无运营计划时才退回恢复信号说明。
- **局部训练状态**：新增概览胶囊（可练/留量/避开 真实计数）；每个肌群行可点击展开——7 天逐日有效组数迷你柱（`TrainingAnalyticsService.dailySetsByMuscle` 纯函数，锚定浏览日、只数有效组、标签 今/昨/星期）、7 天容量 kg、`LocalMuscleFatigue.recommendation` 建议、「下次可练：至少再休 24–48 小时 / 明天可安排低容量 / 今天可练」。
- **趋势与记录**：入口卡片化（canvasRaised + mist 描边，与计划卡同构）+ 右侧 **30 天耗力迷你趋势线**（真实 `summaryWorkPathPoints`，无数据虚线不伪造）+「个人纪录 N 项」徽标。
- **深入分析**：
  - 新增**个人纪录卡**：窗口内 PR 按「动作 × 类型」去重保留最高值（`PersonalRecord.bestRecords` 纯函数），显示动作/类型/数值/打破前增量。
  - `TrainingStatsSection`/`MuscleVolumeCard`/`SafeZoneWorkloadChartView` 旧 Token 全量替换为 Rhythm Token（fg/muted/meta/accent/cardBg → rhythmInk/rhythmInkSecondary/rhythmDeep/rhythmCanvasRaised 等）；月热力图颜色统一为 rhythmGlow/rhythmDeep 节奏绿梯度，肌群条按组数排序。
- **测试**：+2（`PersonalRecord.bestRecords` 去重与历史值保留；`dailySetsByMuscle` 7 天窗口/最旧优先/有效组过滤/窗口外排除），全量 **357/357** 绿；已推送到 iPhone（databaseSequenceNumber 2804）。

## 训练页去装饰化 + 今日卡具体化 + 模块重排（2026-08-15）✅ 已修并推送

用户反馈：今日计划卡「100% · RPE ≤ 9 · 按体感」太抽象；三模块顺序不佳；装饰性英文小字（TRAINING RHYTHM / ROTATION / LOCAL LOAD / TRAINING FACTS / DEEP ANALYSIS / Cardio Load 等）观感差。

- **今日卡具体化**：今天卡不再只显示边界三连——有当日计划动作时显示前 2 个动作的「组 × 次」预览（如「卧推 3×8 · 上斜哑铃推举 3×10 +2 · 60 分」）+ 第二行「容量 100% · RPE ≤ 9」；休息日显示「优先恢复 · 轻活动 / 散步、拉伸都算」；无计划时显示「自由训练 / 容量 · RPE」。三张卡注记区等高（两行固定槽位）。剂量行「按体感」改为「自由训练」或实际分钟数。
- **模块重排**：主页顺序改为 局部训练状态 → 计划与轮转 → 趋势与记录（身体状态紧跟今日决策之后，计划居中，历史归档最后）。
- **英文小字清理**：训练页顶部副标题「轮转、边界与训练事实」、Hero「TRAINING RHYTHM」行、三个区块 eyebrow（ROTATION / LOCAL LOAD / TRAINING FACTS）、深入分析页「DEEP ANALYSIS」、计划页「LIVING PLAN / FLEXIBLE ROTATION / TODAY'S DECISION」、轮转条「训练日序列」小字、有氧卡「Cardio Load / Status / Focus」全部移除或中文化（有氧负荷 / 有氧状态 / 有氧重点）。`VelaRhythmSectionHeader` 支持空 eyebrow 不渲染。
- 全量 **357/357** 绿；已推送到 iPhone（databaseSequenceNumber 2812）。

## 刷新性能专项（2026-08-15）✅ 已修并推送

用户反馈「刷新一次要好久」。定位到训练页刷新链路上的四处放大耗时的问题并修复：

- **60 天训练摘要的心率拉取限窗**：`workoutSummaries(60天)` 此前对整窗（含训练之间的夜间连续心率）全量 HKSampleQuery，一次刷新转移数十万样本；改为 OR 谓词只查各训练区间并集（`.strictStartDate/.strictEndDate`），无训练直接返回。
- **心率平均 O(n×m) → O(n+m)**：`WorkoutHeartRateAverager` 此前每个训练对全量样本 `filter` 一次（40 训练 × 30 万样本 = 千万级比较 + 大量中间数组）；改为样本/训练双指针单遍归并，重叠训练保持旧语义（同时计入）。测试 +1（乱序输入/区间外排除/重叠双计等价回归）。
- **extendedMetrics 20+ 查询并行化**：此前逐行串行 `try? await`，下拉刷新耗时 = 查询数 × 单查询耗时；改为 `async let` 全量并发发起（营养查询仍按开关门控，正念/睡眠呼吸紊乱提为独立 helper）。语义不变。
- **60 天训练摘要 60 秒 TTL 缓存**：切回训练页、换日期、本地数据变化、下拉刷新连续触发时复用同锚定日 60 秒内的结果，不再重复等待大查询。
- **下拉刷新不再跑训记自动导入**：3 次网络往返从 pull-to-refresh 路径移除（切到训练页时仍机会型执行）。
- **body 重渲染去重**：个人纪录（需历史先例的逐次扫描）与肌群 7 天逐日组数改为 `loadDynamicData` 一次性计算缓存（@State memo），此前每次 body 重渲染都 O(n²) 重算，刷新后主线程被拖住。

全量 **358/358** 绿；已推送到 iPhone（databaseSequenceNumber 2820）。

## 三年 Apple 健康历史回填 + 长期趋势（Phase 1+2，2026-08-15）✅ 已修并推送

用户积累三年 Apple Watch 数据，但 App 只同步 42+3 天、且每日**主动删除 90 天前记录**，所有「等待积累」的功能被 90 天窗口锁死。本批把三年历史接入（零 schema 改动，全部写入 DailyHealthSummaryRecord 已有字段；只写原始事实、不伪造旧日评分）。

- **`SleepDayAggregator`（纯函数）**：睡眠阶段段按 04:00 健康日边界拆分聚合（跨夜睡眠 5h/3h 分摊两天，深睡/REM 分钟随段归属），与同步引擎归属语义一致。
- **`HealthKitQueryService` 逐日聚合**：`dailyAverages/dailySums/dailyMostRecent`（HKStatisticsCollectionQuery、1 天间隔、锚定健康日边界）+ `dailySleep`（品类样本 → 阶段段 → 聚合，向前扩 12h 捕获前夜入睡）。
- **`HistoricalBackfillService` + `HistoricalBackfillPlanner`（纯分块）**：目标 3 年、每块 90 天、避开正常同步的最近 45 天、游标存 UserDefaults 可续传；每块并行聚合 8 组数据（HRV/RHR/睡眠/步数/活动能量/体重/体脂/训练），**create-only**（绝不覆盖正常同步生成的记录）；训练按日历日聚合（与 aggregateDay 同语义）。
- **`HistoricalBackfillCoordinator`**：跨页面存活的回填任务 + 进度发布，可停止可续传。
- **清理策略放宽**：`pruneOldSnapshots(keepingDays: 90 → 1100)`，回填的三年记录不再被每天删掉。
- **入口（个人页新增「三年健康数据」区）**：①「回填 Apple 健康历史」行 + 进度面板（进度条/开始/停止/错误，关掉面板继续跑）；②「三年健康轨迹」→ `LongTermHealthTrendView`：五个指标（静息心率/HRV/睡眠时长/体重/步数）近三年**月均值曲线**（点按标数值/拖动查看）+ **今年 vs 去年同期**对齐时段对比（±差值与改善色）。`LongTermTrendMath` 为纯函数（月聚合/同比）。
- **训练页「深入分析」新增「历年训练量」卡**：`YearlyTrainingAggregator`（纯函数）按年聚合训练天数/次数/总时长/总消耗，年度条+数值；无数据时提示先回填。
- **AI 规划上下文接入长线基线**：三年历史（不含近 90 天）静息心率/HRV 中位数写入「Vela 规划」上下文。
- **测试**：+4（睡眠跨界拆分、分块游标规划、月聚合与同比对齐时段排除、按年聚合），全量 **362/362** 绿；已推送到 iPhone（databaseSequenceNumber 2828）。

已知边界（已文档化）：回填只写原始日汇总，不重放历史评分（Phase 3 待验证后做）；iOS 16 前无睡眠分期数据（旧时段只有总时长）；回填为手动入口 + 断点续传，未挂后台自动续跑。

**回填按钮不可点修复（2836）**：个人页「回填 Apple 健康历史」此前是 `Button` + `sheet` 组合（同一视图还挂着一个 `.sheet(item:)`），点按无响应。改为与页面其余入口（建议收件箱/健康手记等已验证模式）一致的 `NavigationLink` 推入独立页面 `HistoricalBackfillView`（原 sheet 内容转成详情页：进度条/开始/停止/错误/完成态），并移除第二个 sheet。全量 **362/362** 绿；已推送到 iPhone（databaseSequenceNumber 2836）。

## 三年数据接入模型算法（Layer 1+2+3，2026-08-15）✅ 已修并推送

用户确认后实施：三年回填数据从「只看」变成「被模型使用」。原则：不改历史评分语义、不重放旧日评分；长线统计只做「原始事实 + 稳健统计」，评分修正带护栏与回归。

- **Layer 1 — `LongTermBaselineEngine`（纯函数，`PersonalBaselineEngine.swift`）**：输入三年逐日原始点 → 每指标（静息心率/HRV/睡眠时长/体重/步数/活动能量）输出三年中位、P10/P25/P75/P90、近 30 天均值、长期偏离%、今年 vs 去年对齐时段差值、三年月均值最小二乘斜率趋势（年化 |Δ|<1% = stable，方向按指标语义）；训练量独立输出三年逐月分钟、本月分钟、**本月三年月分布百分位**、去年同月。单指标 < 60 天样本不发布（防噪声）；中位/分位抗换表测量漂移。
- **Layer 2 — 消费方接入**：
  - **评分两条路径同源**：`loadDashboard` 与后台 `HealthKitSyncEngine` 都计算同一份报告并传给 `DailyHealthComputation.compute(for:history:longTermBaselines:)`（后台历史日重算也用今日长线窗口，语义一致）。
  - `DashboardSummary.longTermBaselines` 挂载报告；`TodayCommandBuilder` 决策理由追加「长线参照：…」首行（不改变决策分支）。
  - **baselines.md 新增「Three-Year Long-Term Baselines」章节**（30 天表之后；解析器按行名读取互不冲突、round-trip 兼容）→ 自动进入 Coach 上下文（CoachContextAssembler 读 wiki）。
  - **`TrainingDecisionKernel` 长线训练量信号**：本月分钟处于三年月分布 P85+ 时 `.keep` 降为 `.reduce`（0.85 容量/RPE≤8），理由注明百分位与分钟数；由 `SecondaryDataAssembler` 从 `dashboard.longTermBaselines.trainingVolume` 传入。
- **Layer 3 — 引擎语义增强（护栏 + 测试）**：
  - **Recovery**：今日 HRV 低于三年分布 P10 → 评分 -3、高于 P90 → +3，理由注明长期视角；需三年样本 ≥ 60 天，未提供上下文时行为逐位不变（回归验证）。
  - **Stress**：RHR 高于短期基线（z>1.2）但 ≤ 三年中位时，RHR 压力分量中和为 50 并解释「仍在三年长期正常范围内」——只有同时超出短期与长线基线才算压力。
- **测试**：+7（长线统计中位/分位/偏离、最小样本护栏、同比与趋势、训练量百分位、Recovery 修正护栏与等价、Stress 双基线门控、训练决策 P95 减量），全量 **369/369** 绿；已推送到 iPhone（databaseSequenceNumber 2844）。

已知边界（已文档化）：三年样本来自不同 watchOS 版本，测量漂移用中位/分位缓解、但不做版本校准；历史日评分重放（给旧日补恢复/负荷分数）仍不做——长线统计路线足以支撑决策与 Coach 参照。

## 身体模型三年拟合 + 行为配对全窗口（2026-08-15）✅ 已修并推送

用户反馈身体模型停留在「学习期」。根因：身体模型与行为配对全部被短窗口截断——个人页 42 天、详情页 35/100/50/50、相关性快照 30 天。三年数据已经入库却喂不进去。

- **`BodyModelBuilder` 三年拟合**：
  - `build(...)` 新增 `longTermBaselines` 参数；基线天数 = max(近期去重天数, 三年报告天数)（回填后 ~1050 天）。
  - 新断言「三年生理基线已拟合」（RHR/HRV 三年中位 + 近 30 天偏离 + 趋势 + 本月训练量百分位，置信度 high，证据数 = 三年天数）。
  - 新断言「训练后的次日反应已配对」：`trainingResponsePairing` 纯函数——三年内训练日 vs 休息日的次日 HRV/RHR 变化对比（训练日 = workoutCount>0 或时长≥15 分钟；两组各 ≥8 天才发布；效应量超过 HRV 3 ms / RHR 1.5 bpm 阈值才成结论），输出「训练日次日 HRV 平均比休息日多降 X ms（n=…）」。
  - **成熟度规则**：三年已拟合（≥180 天 + ≥8 次训练）时行为配对门槛 12 → 6；「个人基线仍在建立」待检测区在三年数据下不再出现。
- **窗口全部放宽到三年**：个人页 `loadMeData`（42d → 1100d，去掉 prefix 截断）、身体模型详情页（35/100/50/50 + 30d 快照 → 全量 + 1100d 快照）、Coach 上下文/聊天工具/Agent 工具的 JournalCorrelation 快照 30d → 1100d——**Impact Matrix（行为→次日 HRV/RHR/睡眠/恢复）与行为-结果配对现在覆盖全部历史手记**。
- **测试**：+2（三年数据 → 稳定期 + 长线断言 + 基线待检测区消失；训练-结果配对效应与样本护栏），全量 **371/371** 绿；已推送到 iPhone（databaseSequenceNumber 2852）。

## 算法-数据利用全景（2026-08-15 盘点）

| 算法 | 数据窗口 | 三年数据接入 |
|---|---|---|
| RecoveryScoreEngine | 42 天 MAD | ✅ 三年 HRV 分布 P10/P90 ±3 修正 |
| StressIndexEngine | 42 天基线 | ✅ 三年 RHR 中位双基线门控 |
| StrainScoreEngine / EnergyBank | 42 天 dailyLoad | ⚠️ 历史日无 dailyLoad，不拉长（语义风险） |
| SleepScoreEngine | 近 14 天就寝 | ⚠️ 评分用近期一致性是设计使然 |
| PersonalBaselineEngine | 30 天 | ✅ baselines.md 新增三年章节 |
| JournalCorrelationEngine | 30 天 | ✅ 三年快照（本批） |
| TrainingDecisionKernel | 28 天力量 | ✅ 本月训练量三年百分位信号 |
| PersonalResponseInsightService | 60 天 | ⚠️ 待扩（依赖历史评分，仅原始体征可扩） |
| BodyModelBuilder | 35 天 | ✅ 三年拟合 + 训练-结果配对（本批） |
| TodayCommandBuilder / Coach 上下文 | 近期 | ✅ 长线参照行 + 三年基线章节 |
| 长期趋势视图 / 历年训练量 | — | ✅ 三年可视化 |

## 身体模型仍显示学习期 / Impact Matrix 空白修复（2860，2026-08-15）

用户实测反馈身体模型仍「学习期」、Impact Matrix 与行为配对无内容。定位到四个真实断点：

- **缓存启动路径丢长线报告**：App 重启后 dashboard 走 `loadCachedDashboard`，`longTermBaselines` 未填充 → 长线修正/证据/身体模型静默退化为空。修复：缓存路径同样 fetch 全量记录并计算报告挂载。
- **个人页/详情页不再依赖 dashboard 状态**：两处各自用自己拉取的三年记录计算 `LongTermBaselineReport`（取天数多者），即使不刷新也生效。
- **训练事实只数 App 内力量记录**：`trainingSessions` 改为 max(StrengthWorkoutRecord 数, 每日汇总中的训练日数)——Apple 健康 + 训记导入的三年训练日全部计入，成熟度立即满足「8 次训练」门槛。
- **Impact Matrix 只认手记标签**：新增 `JournalCorrelationEngine.physiologicalInsights`——无需手记的三年生理行为配对：训练日 / 高活动日（步数 ≥ 个人 P75）/ 短睡眠夜（≤ 个人 P25）→ 次日 HRV/RHR 点二列相关（曝光与对照各 ≥8 天、|r| ≥ 0.15 才发布）；详情页 insights = 手记配对 + 生理配对合并进矩阵；配对区块条件从「手记不足」改为「矩阵为空」，有内容时直接展示断言卡。
- 个人页概览新增「训练-结果已配对」胶囊（配对断言出现时）。

全量 **373/373** 绿；已推送到 iPhone（databaseSequenceNumber 2860）。

**成熟度规则修正（2868）**：用户实测 0 条手记行为、744 次训练事实仍显示学习期——根因是稳定期门槛要求 6 对手记行为，不写手记就永远稳定不了。修正：整体成熟度以生理拟合为准（三年 ≥180 天 + 训练事实 ≥8 次即稳定期）；手记行为降为独立轨道，「行为-结果配对不足」继续在待验证区域诚实提示，不再阻塞稳定期。+1 回归（零手记 + 三年拟合 → 稳定期），全量 **374/374** 绿；已推送到 iPhone（databaseSequenceNumber 2868）。

## 算法打通专项（2026-08-15，四批次 A→D）✅ 已修并推送

用户方向：算法与数据展示很多但彼此独立，没有真正打通。先做接线全景审计（每引擎输出→消费点，grep 逐条核实），发现并修复：

**审计核心发现（接线图）**：
- 三条活决策链互不相通：`TodayCommandBuilder`（压力>75→recover、任一肌群高疲劳→swap）、`BodyStateKernel`（压力/能量/负荷不进 readiness）、`TrainingDecisionKernel`（无压力/能量/TSB/负荷分支）各吃各的输入子集，同屏可给出「标题说恢复、细节说 100%」的矛盾。
- 最重的分析引擎 BodyInterpreterEngine 唯一生产路径（AdaptiveTrainingManager.refreshDailyProposal）写出的 `TrainingPlanAdaptationRecord` 提案，消费 UI 只有挂在死导航下的旧 TrainingCalendarView → 提案写了没人看得见。
- EnergyBank 的 TSB/ACWR/能量值进 Coach 上下文与详情页，但三个决策层全都不用；「TSB≤-15 减量」只存在于死代码。
- Lived State 未接线：今日手记在 BodyStateKernel 里 impact=0；「主观与客观并立、分歧降置信度」无实现。
- 反馈闭环只校准一半：计划置信度（kernel 档位）不吃 DecisionFeedbackCalibrator。

**批次 A — 单一决策结论源**：
- `TrainingDecisionKernel` 新增门控（只向保守方向收紧）：sick/injured/resting 硬约束最先；恢复缺数据→reduce 0.6；睡眠<休息阈值→rest；压力>75→rest；无计划日任一肌群高疲劳→swap；能量<30→reduce 0.7；TSB≤-15→reduce 0.7（从死代码 AdaptiveTrainingEngine.adjustToday 移植）；负荷>目标上限→reduce 0.75。
- `TodayCommandBuilder.build` 新增 `trainingDecision` 参数：提供时 readiness 结论投影自 kernel（rest↔recover 归一），置信度仍用 rec/sleep/stress 加权公式 + 反馈校准；旧判定树保留为无 kernel 输入时的兜底。生产两处（SecondaryDataAssembler、今日页兜底）均已传 kernel 决策。
- ProactiveInsightService 压力阈值 70→75（与引擎/决策统一）。

**批次 B — BodyInterpreter 接活**：
- 训练计划页（`VelaTrainingPlanView`）新增「Vela 的调整提案」区：今日 pending 提案（BodyInterpreterEngine + AdaptiveTrainingEngine 产出）展示调整类型/理由/替代方案，采纳（applyAdaptation，ADR 0008 确认）或拒绝；此前提案表只写不读。
- `CoachContextAssembler` 全量上下文新增「Body Interpretation」系统消息：疲劳等级/主要限制因素/训练窗口/风险标记（≤3）/恢复任务（≤3）+ 与 kernel 冲突时以 kernel 为准的护栏；按 health+training 授权门控。

**批次 C — 反馈校准补全 + Lived State**：
- `DecisionFeedbackCalibrator.calibratedPlanConfidence` 重载：`DailyOperatingPlanCoordinator.upsert` 持久化时对 kernel 置信度校准（每次从原始基数重算，不累积缩放）——计划/工件/Coach 展示面自动一致。
- `BodyStateKernel` 接入 Lived State：36h 内手记（note+标签）中英关键词→保守严重度（疼痛/生病 1.0、很累/酸痛/睡不好 0.8、压力/疲劳 0.5）；自评严重负面且客观信号良好时 readiness ready→caution；自评与身体状态相悖（severity≥0.5 且恢复/睡眠良好）时置信度→low。中性/积极自评不改判定。

**批次 D — 死代码收敛**（全部零引用核实后删除）：
- `TrainingDecisionEngine` enum（405 行，含体温/咖啡因规则；保留 `TrainingDecision` struct + compatibilityView）。
- `DailyPlanBuilder` 及其 WhyThisItem/DailyAction/TodayPlan（保留 BodyInterpretation 依赖的 DailyState/DailyActionType）。
- `LocalDailyPlanLimiterEngine`（BehaviorTagModels）。
- `RecoveryTrainingAdapter.adapt` + `RecoveryTrainingInput`/`TrainingAdaptationRecommendation`（保留 TrainingResponseCalibrator）。
- `AdaptiveTrainingManager.generateWeekAdjustments` 两个重载 + `AdaptiveTrainingEngine.adjustToday`（保留 adjust(day:interpretation:) 与提案管线）。
- `DailyPlanLimiterEngine` + Input/Result + PlanAction（保留 PlanLimiter）。
- `TrainingDecisionInput.recentStrengthSummary` 死参数（kernel 从不读）及全部调用点。
- 附注：`VelaAppTests/StabilizationTests.swift` 为孤儿文件（未注册 pbxproj、引用了旧 API 不参与编译），已记录在案，未动。

**测试**：+12 回归（kernel 六门控、投影四映射与加权置信度、Lived State 三用例、计划反馈校准、压力投影一致性测试改写），全量 **386/386** 绿；已推送到 iPhone（databaseSequenceNumber 2876）。

## 深度专项批次 1+2（2026-08-15 · 快速修复 + Coach/LLM 稳健性）✅ 已修并推送

五面并行审计（统一调度/三年建模/agent 参与/训练记录/Coach 交互）的合并报告经用户确认后实施。本批 = 全部已复核的函数级修复（15 项）+ Coach/LLM 稳健性（4 项）。

**批次 1 — 正确性/隐私/数据质量（15 项）**：
- 同步去重：`AppSyncCoordinator.shared` 全 App 共享（`VelaServices.swift`），主动洞察（`ProactiveInsightService:318`）与后台任务（`BackgroundTaskManager:136`）改用共享实例——此前回前台并发拉起两条全量管线、inFlight/30s 节流失效。
- P85 长线减量门控恢复：`loadDashboard` kernel 调用补传 `longTermTrainingVolume`（此前被 persistedDecision 遮蔽）。
- 隐私：`force` 不再短路 `canSendHealthContextToNetworkAI`（MorningBriefScheduler:26 + EveningWikiSyncAgent:102 两处）；晚间同步复刻晨报的今日快照 04:00 新鲜度守卫。
- 性能：切历史日期不再触发 HealthKit 2-pass 同步（`DashboardViewModel.performRefresh` 按 isToday 传 syncDays/shouldSync）。
- Coach 竞态：`submit`/`startPendingRequest` 同步置 `isStreaming`（会话新建/切换/删除的窄窗口可致在途回复写进错误会话，数据破坏级）；stop() 立即 `confirmToolCall(false)` 收尾挂起的确认卡。
- Coach 性能：`CoachContextAssembler.buildChatMessages` 增加 `coverageSummary` 参数，CoachView 传入已算好的摘要——每条消息省 9 次串行 HealthKit 覆盖查询。
- 训练记录：训记双录判定收紧为「同日 && 开始差≤60min && 时长差≤10min」（原 `||` 会误合并同日两场不同训练，违反宁重复不丢训练）；`aggregateDay` 无事件且非强制重置时保留回填计数（编辑/删除旧训练不再把回填 HealthKit 计数抹成 0）；通用详情删除补 `resetActivityTotals:true`（max 语义残留）；「历年训练量」训练日判定去掉 calories、总消耗改读 workoutsData 训练能量（不再把全天活动能耗当训练消耗、步行休息日不再算训练日）；热力图 tier 去掉 activeCalories 分档。
- 三年数据：体脂率进入 `LongTermBaselinePoint`/`LongTermBaselineMetric`，体脂率+活动能量进入趋势页 `LongTermMetric` picker；决策理由长线参照 `.first` → 前两行（RHR+HRV）。

**批次 2 — Coach/LLM 稳健性（4 项）**：
- AgentLoop 取消传播修复：用户取消抛 `CancellationError`（此前转成 canned「请求已被中止」成功消息）；工具批次中途取消立即收尾；deadline 到期仍用本地 canned 消息。
- AgentLoop 真实总超时：`providerCall(within:)` 竞速把 `maxDuration` 变成 provider 调用的硬约束（此前单次 120s×3 重试可击穿 90s 预算数倍，最坏 ~20 分钟）。
- 非对话 LLM 调用加 20s deadline：`LLMProviderDeadline.withTimeout` 套在晨报/晚间同步/训练规划三处（BGTask ~30s 预算内不再挂起数分钟）。
- 错误文案按状态码区分（400 请求过长/429 繁忙/5xx 服务端故障）；用户消息 append 后立即 `persistThread`（流式中杀 App 不再连提问一起丢）。

**测试**：+11 回归（年度聚合口径×2、训记去重判定、aggregateDay 保留回填、热力图 tier、LongTermMetric 新指标、长线参照两行、AgentLoop deadline/取消传播、LLMProviderDeadline、状态码文案），全量 **397/397** 绿；已推送到 iPhone（databaseSequenceNumber 2884）。

**遗留（下批）**：批次 3 三年建模（月度 MAD 基线/剂量-反应/脱轨/季节性/训记批量回填）、批次 4 Agent 管线 A+C、批次 5 VelaDailyOrchestrator、批次 6 Agent 管线 B；Coach 覆盖摘要外的相关性/快照 memo、BGTask 拆分为独立授予。

## 深度专项批次 3（2026-08-15 · 三年数据建模落地）✅ 已修并推送

用户确认「三年建模落地」范围。四个纯函数模型挂进三年长线报告 + 三个消费点 + 训记批量回填入口：

- **同期三年月度 MAD 基线**（`MonthlyMADBaseline`，`PersonalBaselineEngine.swift`）：每个日历月取三年内同月逐日值 → 稳健中位 + 1.4826×MAD 波动带（单月 ≥20 天、总 ≥60 天才发布）。消费点：① Recovery 引擎第二门控——今日 HRV 低于「同月带下限（median − 1.5×MAD）」时 -2（只向保守收紧，`RecoveryLongTermContext.hrvMonthlyGateThreshold`）；② 今日决策理由追加「HRV 低于同期三年 X 月带下限」行（`TodayCommandState`）。
- **长线剂量-反应回归**（`BodyModelBuilder.doseResponseCurve`）：训练时长剂量三分位 × 次日 HRV/RHR（各 ≥8 对、总 ≥60 对）；高剂量档次日 HRV 多降 ≥2ms / RHR 多升 ≥1bpm 才成结论，进身体模型断言卡「训练剂量-反应曲线」。只作参考/收紧，绝不据良好反应加量（ADR 0005）。
- **三年轨迹脱轨检测**（`DerailmentSignal`）：三年月均值最小二乘斜率 vs 近 30 天逐日斜率；方向不利（RHR 升/HRV 降）且近期速度 ≥ max(5×长期斜率, 地板) 时触发；挂进 `ProactiveInsightService` 两条 alert 规则（静息心率上升过快 / HRV 下降过快），走现有主动洞察管线（开关门控 + 日级去重）。
- **季节性剖面**（`SeasonalProfile`）：12 个月均值剖面，幅度 >3%（RHR）/>8%（HRV）且 ≥730 天、≥8 个月有样本才判季节性；报告字段就绪（`seasonalHRV/seasonalRHR`），趋势页展示后续接。
- **训记历史批量回填**（`XunjiHistoryBackfillService` + 个人页入口「回填训记训练历史」）：逐日拉取训记（动作/组数/重量，默认近 90 天），UserDefaults 游标断点续传，连续 5 天失败暂停报错；三年 e1RM/容量/肌群频率轨迹的前置条件。
- 全部新字段挂在 `LongTermBaselineReport`（纯结构体，零 schema 变更），`compute()` 一次算齐；`loadDashboard`/缓存路径/个人页沿用同一条链自动生效。

**测试**：+6 回归（月度 MAD 分桶与护栏、脱轨触发与平稳对照、季节性周期与不足两年护栏、剂量-反应高剂量效应与样本护栏、Recovery 月度门控只降不升、脱轨主动洞察），全量 **403/403** 绿；已推送到 iPhone（databaseSequenceNumber 2892）。

## 深度专项批次 4（2026-08-15 · Agent 管线 A+C：agent 主动参与）✅ 已修并推送

用户确认的「Agent 管线 A+C」落地。agent 从此不再只在对话里出现：

**管线 A — 每日 AI 解读进今日页**：
- `ReportGenerator.generateDailyInsight`：晨报生成后附带一次严格 JSON 调用（20s deadline），产出 `DailyAIInsight { interpretation/evidence(≤3)/risks/decisionHint/conflictsWithLocal }`；本地决定（DailyOperatingPlanPayload）作为锚注入提示词，硬规则「不得给出相反结论；矛盾只标注不改写」（ADR 0008）。
- 落 `AIReportRecord(type=daily_ai_insight)`（零 schema），`MorningBriefScheduler` 内嵌生成，解读失败不影响晨报。
- 今日页 Hero 下方新增「AI 增强 · 今日解读」卡：正常时显示解读+证据锚点；`conflictsWithLocal` 时整卡降级灰色并标注「以本机今日决定为准」。本机 `localMorningBrief` 永远是缺省，AI 解读永不替换本机结论；AI 不可用时今日页照常。

**管线 C — 练后 AI 复盘**：
- `WorkoutAdaptationService.processWorkoutCompletion` 在本机提案落库后异步触发 AI 分支（consent 门控 + 20s deadline + 失败静默，训练事实与本地流程不受影响）。
- `PostWorkoutAIBoundary` 严格 JSON（observation/nextVolumeMultiplier/nextIntensityCap/nextSuggestedFocus/rationale），解析时钳制容量 [0.3, 1.0]、RPE [1, 10] 防模型异常输出。
- 产出两路：① 观察性复盘 → `CoachArtifactRecord`（postWorkoutReview，「AI 练后复盘」标注，进个人页历史建议）；② 下次训练边界建议 → `TrainingPlanAdaptationRecord`（proposed 提案状态机，用户确认才生效）。
- 计划页提案区扩展为「今日 + 未来未完成训练日」，AI 的下次边界建议可被看到并确认/拒绝（`VelaTrainingPlanView.planAdaptations`）。

**测试**：+3 回归（DailyAIInsight markdown 包裹解析与拒收、PostWorkoutAIBoundary 钳制护栏、AI 复盘事实文本携带本机决定锚），全量 **406/406** 绿；已推送到 iPhone（databaseSequenceNumber 2900）。

## 深度专项批次 5（2026-08-15 · VelaDailyOrchestrator 统一调度层）✅ 已修并推送

用户确认的「统一调度层」最小方案落地（零 schema、零 pbxproj，追加在 `DailySummaryUseCase.swift`）：

- **`VelaDailyOrchestrator.refresh`**：所有「同步 → 评分 → 计划」触发源的唯一入口。三层幂等：① 内部统一走 `AppSyncCoordinator.shared`（同步 inFlight 去重 + 30s 节流）；② 同一天（dayIdentifier key）的并发触发共享同一次全量计算——回前台 TodayView + 主动洞察双链不再各跑一遍；③ 历史日由调用方传 `shouldSyncHealthData:false`。
- **触发源全部收口**：前台刷新（`DashboardViewModel.performRefresh`，历史日 0 同步）、主动洞察（`ProactiveIntelligenceOrchestrator.runAsyncCheck`）、后台 BGTask（`BackgroundTaskManager.handleRefreshTask`，按 4h TTL + 后台投递脏标记决定 syncDays 0/7）、训练增删触发的计划刷新（`DailyPlanRefreshCoordinator.refreshPlan`，不同步只重算）。全仓不再有裸 `DailySummaryUseCase().loadDashboard` 构造点。
- 幂等原语沿用既有机制（HealthCachePolicy TTL / 脏标记 / bodyStateHash），不新增持久化字段；`DailyHealthComputation.compute` 仍是唯一评分入口，调度层不触碰评分语义。

**测试**：全量 **406/406** 绿（本批为结构性收口，全部既有回归覆盖四条触发源路径）；已推送到 iPhone（databaseSequenceNumber 2908）。

## 深度专项批次 6（2026-08-15 · Agent 管线 B + 收尾）✅ 已修并推送

用户确认的最后一批：

**管线 B — AI 个性化阈值提议（闭环：提议 → 确认 → 生效）**：
- `ThresholdProposalPayload`（严格 JSON，恢复/睡眠四阈值 + 理由）+ `ThresholdProposalGenerator`：每 7 天一次挂到晚间同步（consent 门控、20s deadline、失败静默），输入当前阈值 + 近 28 天决策反馈摘要，输出经范围钳制（recoveryRest 30-50 / recoveryCaution 50-70 / sleepRest 45-60 / sleepCaution 55-75）。
- 落 `MemoryLedger.createProposal(targetFile: strategies.md, memoryType: .baselineUpdate)` → 用户 Memory Inbox 确认 → 写入 wiki → **`PersonalBaselineEngine.resolveThresholds()` 读取 strategies.md 覆盖值生效**（`applyThresholdOverrides` 纯函数，钳制 + 来源标注 "user-confirmed strategies.md"）。确认前评分路径零影响（ADR 0008）；反馈显示多数准确时提示词要求不改动。

**收尾三项**：
- 反馈 push：Coach 系统提示注入「近期决策反馈」摘要（此前模型需自行调 get_decision_feedback 工具，pull 变 push），冲突时以本地决策为准。
- Coach 相关性 memo：`calculateInsights` + 1100 天快照会话内缓存（key = 手记数 + 最后手记时间 + 最新快照日期，≤5 条自动淘汰）——每条消息此前都全表 fetch + Spearman/BH-FDR 重算一遍。
- 反馈摘要函数收敛到 `DecisionFeedbackCalibrator.feedbackSummary`（AI 阈值审阅与 Coach 共用）。

**测试**：+4 回归（阈值覆盖钳制与来源、提案解析与 wiki 行、反馈摘要分组、周级到期门控），全量 **410/410** 绿；已推送到 iPhone（databaseSequenceNumber 2916）。

## 深度专项最终遗留（已文档化，非阻塞）

1. **BGTask 30s 预算与 LLM 拆分**：同步与 LLM 仍在同一个 BGAppRefreshTask 内（已有 20s deadline 缓解但未根治）；彻底方案需拆独立任务授予或 BGProcessingTask（审计 PR7 延续）。
2. **管线 B 的 EWMA 系数等结构性参数**：默认只提议不改（避免破坏 Banister/EWMA 学术口径），需单独设计白名单。
3. **训记三年批量回填后续**：三年 e1RM/容量/肌群频率轨迹需在回填后接入 TrainingAnalyticsService 历史视图（入口已就绪，轨迹视图下一轮）。
4. **季节性剖面展示**：`seasonalHRV/seasonalRHR` 报告字段已就绪，趋势页「月历节律」条未接。
5. **孤儿测试文件**：`VelaAppTests/StabilizationTests.swift` 未注册 pbxproj（引用旧 API 不参与编译），建议下轮修复注册或删除。
6. **Watch 侧**：WristSnapshotBridge 已推送 command+plan，Watch 端展示未纳入本轮范围。

## 联通性专项批次 1（2026-08-15 · 接线与口径修复）✅ 已修并推送

四面并行审计（训练页五模块/身体模型与档案/三指标/agent 联通）合并报告经用户确认后的第一批（9 项，全部函数级）：

- **身体模型注入 Coach**：`CoachContextAssembler.resolvedBodyModelState`（memo 化）计算 BodyModelState 并传入 `buildFacts(bodyModelState:)`——此前该形参零生产调用，Coach 永远看不到成熟度/断言/coachRules；训练/手记/快照变化自动失效。
- **Coach 紧凑视图补局部疲劳**：`CoachCompactContextAdapter.render` 追加 48h/7d 组数 Top3（此前被剥掉，Coach 无法回答「某肌群 48h 练了几组」）。
- **工具口径统一**：`get_strength_workout_history` 的 payload 增加 `effective_sets`/`muscle_group_sets`（经 `summarizeWorkout` 与训练页/快照同一 isEffective 口径 + 肌群映射）——消除「agent 说 8 组 vs 训练页 12 组」的第三套计数口径。
- **详情页补齐成分**：压力详情补 `temp_stress`/`load_stress`（此前 6 因子只展示 4）；恢复详情补 `parasympathetic_tone_index`（此前算了零展示）。
- **Coach 上下文补成分**：v1 `StrainContextBuilder` 补 training_load_ratio/acute_7d/chronic_28d/status；`StressContextBuilder` 补六因子——agent 解释压力/负荷不再依赖 get_today_health 的 evidence 段。
- **今日页证据锚点真实化**：HRV chip 改用基线 z-score（"HRV 基线 +x.x SD"）；driver 证据展示 `reasons.first` 正文而非仅标题。
- **训练页证据锚点升级**：`trainingEvidenceMetrics` 改为「恢复 + 负荷 + 动态第三槽」——压力>75 / TSB≤-15 / 能量<30 触发时抬进证据层（与 kernel 门控同阈值同源），默认睡眠兜底，最多 3 个锚点。
- **AI 规划上下文补档案+目标**：`aiPlanContextText` 增加生理档案（年龄/性别/身高/体重）+ 目标/训练风格/周频 + 压力指数行。
- **疲劳阈值唯一事实源**：`LocalMuscleFatigue` 新增 high/moderate 48h/7d 静态常量，`fatigueLevel` 与 AI 规划中英提示词共用——消除「48h≥14/7d≥24」双源硬编码。
- **未来卡冲突注记**：AI 建议与本地推荐不一致时显示弱注记「Vela 与本地建议不同…本地轮转保持不变」（ADR 0008 一致性）。

**测试**：v1 strain 键集契约测试按有意扩展更新（+4 键），全量 **410/410** 绿；已推送到 iPhone（databaseSequenceNumber 2924）。

## 联通性专项批次 2（2026-08-15 · 个人模型三段式）✅ 已修并推送

按用户确认的方向「收敛为一句洞察模式」实施：

- **一句话 Personal Response Insight**：`DashboardSummary.bodyModelState` 挂载（loadDashboard 计算，BodyModelBuilder 全量拟合）；`BodyModelState.insightLine()` 按价值优先级取最强断言（剂量-反应 > 训练-结果配对 > 三年基线）。今日页 Hero 下方一行（点击 → `BodyModelDetailView` 证据页）；训练页「为什么」证据层展开区同样显示一行。
- **证据页用户校准控件**：`ClaimRatingStore`（UserDefaults 存 claimId→正确/部分正确/不正确）+ `ClaimRatingControl` 三态按钮挂进每个断言卡——产品方向「反馈用于后续校准，一次评价不写成永久结论」的闭环落地。
- **成熟度降级**：Me 页卡标题「个人上下文 · 稳定期」→「个人上下文」（不做成绩单；成熟度仅详情页内部说明）。
- **wiki 清空残留修复**：`WikiProfileMaterializer.refreshPhysiologicalProfile` 对 UserDefaults 为 nil 的字段删除 profile.md 对应中英文别名行（`removeBullets`）——清空手填值后陈旧值不再经 getAgeFromWiki 复活；非生理手改内容仍受保护。
- **AgentTool 改档案触发重算**：`UpdateUserProfileTool` 显式调 `VelaDailyOrchestrator.refresh`（不同步只重算）——在 Coach/Me 停留时改档案，评分与计划也立即按新档案口径更新。

**测试**：wiki 契约测试 2 处按新语义更新（清空=删除生理行、手改备注仍保留），全量 **410/410** 绿；已推送到 iPhone（databaseSequenceNumber 2932）。
