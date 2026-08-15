# Vela 交接文档（2026-08-15）

> 给在 Vela 项目下新开的 agent。先读本文件，再读 `CONTEXT.md`、`CLAUDE.md`、`docs/VELA_FULL_AUDIT_2026-08-13.md`（下面简称《审计日志》）与 `docs/adr/`。
> 本文件只写增量与关键约束，详细修复历史一律引用《审计日志》，不要重复。

## 0. 项目一页纸

- 本地优先 iOS 健康教练（SwiftUI + SwiftData + HealthKit），单人 Personal Edition，中文 UI。
- 北极星：Trusted Decision Day；4 Tab（今日/训练/Vela/个人），Rhythm 设计 Token（暖灰绿画布 + 节律绿 #17A35C）。
- 模型：评分引擎（Recovery/Strain/Sleep/Stress/EnergyBank/…）→ DashboardSummary → TodayCommandBuilder / TrainingDecisionKernel → Coach（DeepSeek 直连，ADR 0008：AI 提议、用户确认）。
- 仓库：`/Users/sunweizhou/Developer/Vela`，分支 `main`，最近提交 `b3577992`。

## 1. 当前会话做了什么（最新 5 个批次，全部已装机）

| 批次 | 内容 | 结果 |
|---|---|---|
| 训练页四模块完善 | 计划轮转/局部训练状态/趋势记录/深入分析接真实数据+交互，英文小字清理 | 数据库序号 2812 |
| 刷新性能专项 | 60 天心率 OR 谓词限窗、O(n+m) 平均、extendedMetrics 并行、60s TTL、下拉刷新不再跑训记网络 | 2820 |
| 三年历史回填（Phase 1+2） | 个人页回填入口+进度（断点续传）、三年健康轨迹页（月曲线+同比）、历年训练量卡；清理策略 90d→1100d | 2828/2836 |
| Layer 1+2+3 模型接入 | `LongTermBaselineEngine`（中位/分位/同比/趋势/训练量百分位）→ Recovery ±3 修正、Stress 双基线门控、决策内核 P85 减量、baselines.md 三年章节、Coach 上下文 | 2844 |
| 身体模型三年拟合 | BodyModel 稳定期规则、三年基线断言、训练-结果配对、生理行为配对（训练日/高活动日/短睡眠夜→次日 HRV/RHR）填充 Impact Matrix | 2852/2860/2868 |

**当前测试：374/374 绿；设备装机数据库序号 2868。**

## 2. 用户最近的状态与已知待办

- 用户设备已回填三年数据：**744 个训练日、0 条手记行为**（基本不写手记）。身体模型已按新规则进稳定期，手记行为轨道独立（不足 6 对时在待验证区域诚实提示）。
- 未完成的候选（用户未明确指派，可作为主动建议）：
  1. **手记行为 0 条**：可从 Coach 对话中 AI 推断行为信号（BehaviorSignalConfidence.aiInferred 已有类型）回填行为配对，或引导用户随手记。
  2. **Layer 4（研究阶段提过、未做）**：`PersonalResponseInsightService` 窗口 60d → 三年（注意历史日无评分，只能用 HRV/RHR 原始变化；`JournalCorrelationEngine.physiologicalInsights` 已示范同思路）。
  3. Strain/EnergyBank 的 CTL 不拉长到三年（历史日无 dailyLoad，语义风险，已在审计日志记为“有意不做”）。
  4. VO2max 三年历史未入库（`DailyHealthSummaryRecord` 无字段且禁改 schema）。
  5. **Git：117 个未提交文件**（整个会话的改动都在工作区）。用户多次被建议分拆提交，未做。新 agent 接手后建议先做一次分主题提交（可参考审计日志批次切分）。

## 3. 关键约束（违反会出事）

- **绝不脚本改 pbxproj**：新代码追加进已有文件（本会话所有新类型都追加在既有文件里）；新文件需用户在 Xcode 手动注册。
- **零 schema 变更**：不给 `DailyHealthSummaryRecord` / `modelTypes` 里的 @Model 加字段（staged migration → readOnlySafetyMode）。三年数据全部写在既有字段上。
- **评分两条路径同源**：`DailyHealthComputation.compute(for:history:longTermBaselines:)` 前台 `DailySummaryUseCase.loadDashboard` 与后台 `HealthKitSyncEngine.syncPastDays` 都要传同一份 `LongTermBaselineReport`（缓存启动路径 `loadCachedDashboard` 也要挂载）。
- **健康日边界 04:00**：`HealthDayBoundary`；记录层 date 存日历午夜；训练按日历日聚合。
- SwiftData 取历史用「fetch 全部再内存过滤」模式（`HealthSnapshotRepository.fetchSnapshots` 注释说明了 #Predicate 日期比较曾 SIGTRAP）。
- Swift 细节：multiline string 里注意三元/插值；`dict[key, default: [:]][k]` 会改临时副本（必须分两步）；type-checker 超时 → 拆小 View。
- 性能红线：训练页 60 天 HK 摘要 60s TTL；`WorkoutHeartRateAverager` 已 O(n+m)；body 重渲染不得做 O(n²) 扫描（个人纪录/肌群日组数已在 `loadDynamicData` 缓存）。
- 风格：Rhythm Token（`rhythmCanvas/rhythmInk/rhythmDeep/...`），无装饰性英文小字（用户明确反感）；内容优先于容器。

## 4. 工作流约定（用户已形成的协作模式）

- 报告 → 用户说“去做吧/行” → 实施。大改动先给方案再动手。
- **每个批次收尾四件套**：① 全量测试 374 绿；② 真机构建+`devicectl` 装机并报告 databaseSequenceNumber；③ 《审计日志》追加条目；④ 回复里说明改动与验证路径。

```bash
cd "/Users/sunweizhou/Developer/Vela"
# 全量测试（iPhone 17 Pro 模拟器）
xcodebuild test -project Vela.xcodeproj -scheme Vela -derivedDataPath build/audit-DerivedData \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -parallel-testing-enabled NO
# 真机构建 + 装机
xcodebuild -project Vela.xcodeproj -scheme Vela -destination "id=B1B2A1DB-2B5C-5C02-A222-B051240A22EA" \
  -configuration Debug -allowProvisioningUpdates -derivedDataPath build/audit-DerivedData build
xcrun devicectl device install app --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA \
  build/audit-DerivedData/Build/Products/Debug-iphoneos/Vela.app
```

## 5. 重要文件地图（本会话新增/改动的核心）

- `VelaApp/Scoring/PersonalBaselineEngine.swift` — `LongTermBaselineEngine`、三年报告/训练量百分位、baselines.md 三年章节。
- `VelaApp/Scoring/ScoreEngineFactory.swift` — 评分唯一入口，长线上下文注入 Recovery/Stress。
- `VelaApp/Scoring/Recovery/RecoveryScoreEngine.swift` — `RecoveryLongTermContext`、P10/P90 ±3 修正。
- `VelaApp/Scoring/Stress/StressIndexEngine.swift` — `longTermQuietHRMedian` 双基线门控。
- `VelaApp/Scoring/Correlation/JournalCorrelationEngine.swift` — `physiologicalInsights`（三年生理配对）。
- `VelaApp/Core/Utilities/BehaviorTagModels.swift` — `BodyModelBuilder` 三年拟合、成熟度规则、`trainingResponsePairing`。
- `VelaApp/Health/Services/HealthKitSyncEngine.swift` — 末尾：回填规划/服务/协调器 + 长线报告传参。
- `VelaApp/Health/Services/HealthKitQueryService.swift` — 逐日聚合（dailyAverages/dailySums/dailyMostRecent/dailySleep）、训练区间心率谓词。
- `VelaApp/Core/Utilities/DailySummaryUseCase.swift` — 长线报告计算与缓存路径挂载、prune 1100d。
- `VelaApp/Core/Utilities/TrainingDecision.swift` — 决策内核三年训练量百分位信号。
- `VelaApp/Features/Minimal/VelaMinimalJournalView.swift` — 个人页：三年健康数据区、回填入口、身体模型自给自足。
- `VelaApp/Features/Minimal/VelaMinimalComponents.swift` — `LongTermHealthTrendView`、`LongTermTrendMath`。
- `VelaApp/Features/Minimal/TrainingStatsSection.swift` — `YearlyTrainingCard`/`YearlyTrainingAggregator`。
- `VelaApp/Features/Minimal/{TrainingHeroSection,VelaMinimalFitnessView,VelaTrainingPlanView}.swift` — 训练页四模块与今日卡。
- `VelaAppTests/VelaThemeTests.swift` — 本会话大部分回归测试（374 总集）。

## 6. 建议技能（新 agent 可按需调用）

- `handoff` — 你已经在读产出；再交接时复用。
- `diagnose` — 用户报 bug（如“点不了/刷新慢”）时先走重现-最小化-假设-修复流程。
- `review` — 117 个未提交文件提交前做一次 Standards/Spec 双轴审查。
- `improve-codebase-architecture` — 训练数据三源（HK/本地/训记）合并、缓存模式等有深化空间。
- `qa` — 用户口语报 bug 时归档成 issue。
- `to-issues` / `request-refactor-plan` — 把上面“待办”拆成可认领任务时。
- `prototype` — 新 UI 模块想多方案对比时。

## 7. 安全与隐私注意

- API 密钥只存 iOS Keychain（account 名：`deepseek_api_key`、`xunji_open_api_key`），**不要**写进文档/日志/上下文。
- 健康原始数据不出设备；只有结构化摘要直发 DeepSeek（`AutoAgentConfig.shared.canSendHealthContextToNetworkAI` 门控）。
- 不要把设备上的真实个人数值（HRV/体重等）复述进仓库文档；示例数据用合成值。
