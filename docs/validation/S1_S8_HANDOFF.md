# 任务交接：S1–S8｜科学性与真实数据置信度纠偏

任务：S1–S8｜数据可信度与科学域纠偏（Data credibility and scientific domain correction）  
状态：VERIFIED  
审阅起始 SHA：`e6110f41ac63b6e023ef4513fae885627d308330`  
交付 SHA：`72c0f91ad466259259d84f0b367eed56e19b5aaa`  
工作区未提交改动与处理：代码改动已全部提交并固化为 Git commit；未提交文件仅为本包说明书与模板文件（`START_HERE.md`、`RULES_TO_PASTE.md`、`tasks/`、`templates/`、`EXECUTION_BOOK.md` 等）。

---

## 本卡改变的用户行为

1. **S1 观测时间真实性**：
   - 首页 Today 体征卡（`TodayVitalCardModel`）状态文案区分「观测时间」与「同步时间」。在 08:00 晨间完成观测、22:00 重算或打开 App 时，展示实际观测时间（如 `08:00 观测` 或 `醒于 07:30`），不再把晚间重算或同步时间伪装成体征观测时间；无精确时间点时标明 `观测时间未知`，拒绝制造虚假实时性。
2. **S2 长期基线严谨门控**：
   - 三年长期基线与季节性修正仅在历史真实样本累积 $\ge 60$ 天时方可启用；不足 60 天时不触发长期偏差修正，保留干净的短期基线评估，且绝不对未来样本发生信息泄露。
3. **S3 PSTI 与 RMSSD 方法隔离**：
   - 消除 SDNN 隐式替代 RMSSD 的行为。当仅有 SDNN 测量时，副交感神经张力指数（PSTI）明确处于 `unavailable` 状态，不再将 SDNN 包装成 PSTI 误导用户；当具备同方法 RMSSD 测量及历史时才计算 PSTI。
4. **S4 睡眠目标达成 vs 生理充分性**：
   - 当用户自定义睡眠目标偏短（如 5 小时）并达成时，文案与理由明确标明：达成该目标属于「个人作息行为达成」，依据 AASM（美国睡眠医学会）共识，成人健康生理充足推荐为 7–9 小时，行为达成不等于生理充分满足；缺少唤醒次数时明确标明为估算值。
5. **S5 训练负荷去重与方法溯源**：
   - 负荷引擎基于 Workout UUID 进行强去重，防止重复导入导致的负荷翻倍；在评分 components 中公开 `workout_load_method_code`（1.0 逐搏心率积分、2.0 平均心率后退、3.0 RPE 标定、4.0 时长后退），并将步数/活动能量的倍率启发式明确记录在 reasons 中。
6. **S6 连续日历负荷递推与 EWMA 衰减**：
   - 负荷历史构建以真实日历天为网格：对于监测期内的空白日，正确作为零负荷进行 EWMA 指数移动衰减，彻底禁止将非连续日 `compactMap` 压缩为伪连续序列；当有效观测天数不足 7 天时，安全停用 ATL/CTL/负荷状态输出。
7. **S7 生理压力时间尺度与运动排除**：
   - 运动窗口及运动后 90 分钟自主神经恢复期内，生理压力明确设为 `nil`（excluded，不可估计），禁止用假 0 分伪装；睡眠相关分量明确声明为「单夜睡眠亏欠」，不冒充多日累积睡眠债；缺少核心静息心率与 HRV 时，置信度降为中/低。
8. **S8 能量估计与上游质量传播**：
   - 夜间体温、呼吸率与血氧全部未测时，夜间稳定性采用中性基准 50 并记录缺失原因，不再无依据假设满分 100；当生理压力因运动排除为 `nil` 时，能量引擎说明训练负荷已覆盖该消耗，避免出现无解释的能量回升；若上游恢复或睡眠为低置信度，能量估计置信度严格跟随降级，禁止无条件标为 High。

---

## 实际修改文件及理由

1. **`BodySeekDomain/Sources/BodySeekDomain/ScoringCore.swift`** & **`VelaApp/Scoring/ScoringCore.swift`**:
   - 为 `MetricResult` 扩展可选字段 `observedAt: Date?`、`observedWindow: DateInterval?`、`computedAt: Date?`，并在 `init(from decoder:)` 中使用 `decodeIfPresent`，确保 100% 向后兼容。
2. **`BodySeekDomain/Sources/BodySeekDomain/DomainValues.swift`** & **`VelaApp/Health/Models/HealthDomainModels.swift`**:
   - 在 `DailyHealthSnapshot` 中增加观测时间戳与窗口（`hrvObservedAt`、`rhrObservedAt`、`spo2ObservedAt`、`hrvObservedWindow`）。
3. **`BodySeekDomain/Sources/BodySeekDomain/ScoreContract.swift`**:
   - 更新 `ScoreProvenance` 与 `ScoreEvidenceAdapter`，将观测时间点与窗口向领域契约传递。
4. **`BodySeekDomain/Sources/BodySeekDomain/SleepScoreEngine.swift`** & **`VelaApp/Scoring/Sleep/SleepScoreEngine.swift`**:
   - S4：区分短目标作息行为达成与 AASM 7–9 小时生理充分性；唤醒次数缺省时标明估算。
5. **`VelaApp/Features/Minimal/VelaMinimalTodayView.swift`**:
   - S1：`vitalStatusText` 接入 `dashboard.recovery.observedAt` 与 `dashboard.sleepSummary.wakeTime`，区分实际观测时间与同步时间，缺失时展示「观测时间未知」。
6. **`VelaApp/Scoring/Recovery/RecoveryScoreEngine.swift`**:
   - S3：移除 `hrvRmssdToday ?? hrvToday` 回退；PSTI 严格基于真实 RMSSD 及同方法基线。
   - S1：支持 `observedAt` 与 `observedWindow` 传入并穿透至 `MetricResult`。
7. **`VelaApp/Scoring/Strain/StrainScoreEngine.swift`**:
   - S5：Workout UUID 去重；写入 `workout_load_method_code`；说明步数/活动能量倍率。
   - S6：接收 `validObservedDaysCount`；有效观测天数不足 7 天时停用 ATL/CTL。
8. **`VelaApp/Scoring/ScoreEngineFactory.swift`**:
   - S6：实现 `continuousDailyLoadGrid(for:from:maxDays:)`，按监测起始日至昨日构建连续日历网格，空白天衰减 EWMA，避免 `compactMap` 压缩时间或向历史前填充假零。
   - S8：向 `EnergyBankInput` 传递 `recoveryConfidence` 与 `sleepConfidence`。
9. **`VelaApp/Scoring/Stress/StressIndexEngine.swift`**:
   - S7：运动及恢复期排除明确返回 `nil`；睡眠分量表述改为单夜亏欠；核心静息体征缺失时置信度严控。
10. **`VelaApp/Scoring/EnergyBank/EnergyBankEngine.swift`**:
    - S8：夜间体温/呼吸/血氧均缺失时，夜间稳定性置中性基准 50 并说明原因；运动排除导致压力为 nil 时说明训练负荷覆盖，避免回弹假象；上游质量不佳时降级能量置信度。
11. **`VelaAppTests/DataCoverageAndEvidenceTests.swift`**:
    - 新增 S1–S8 完整单测套件（`testS1ObservationTimePreservedAndIndependentOfRecomputation` 到 `testS8EnergyBankOvernightStabilityNeutralWhenMissingAndPropagatesQuality`）。
12. **`VelaAppTests/Milestone1ChallengeTests.swift`**:
    - 将旧的 PSTI 隐式回退断言修正为 S3 要求的规范断言（当 RMSSD 为 nil 时 PSTI 必须为 nil）。

---

## 数值/单位/缺失/日期/算法版本是否改变

- **主算法版本**：未变（保留 `ScoringAlgorithmVersions` 常量，保持现有测试基准一致）。
- **主评分权重**：未变（未修改任何一类主评分的公式权重）。
- **数据结构**：SwiftData `@Model` 架构零改动，`scripts/schema_fingerprint.py` 100% 吻合。
- **缺失与时间边界**：
  - 缺失值均显式输出原因并保留 `nil` 或中性基准；
  - 观测时间与计算时间完全解耦，`MetricResult.observedAt` 独立承载采样时间点；
  - 负荷递推以日历间隔衰减，不再使用连续数组冒充时间连续。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS Local | 退出码 0 | 终端输出 | 无（32 live / 32 frozen models 完全一致） |
| `python3 scripts/check_contrast.py` | macOS Local | 退出码 0 | 终端输出 | 无（textColor(for:) 全部 >= 4.5:1） |
| `swift test --package-path BodySeekDomain` | macOS SwiftPM | 退出码 0 (11/11 通过) | 终端输出 | 无 |
| `xcodebuild build` (`Vela`, Debug, warnings-as-errors) | iOS Simulator (iPhone 17) | 退出码 0 | `build/DerivedData` | 无（0 警告，0 错误） |
| `xcodebuild test` (`VelaTests`, iPhone 17) | iPhone 17 (iOS 26.5 Simulator) | 退出码 0 (全量通过) | `build/DerivedData/Logs/Test` | 无（含 S1-S8 专项测试及 PR0 Golden 测试） |
| `xcodebuild test` (`VelaUITests`, iPhone 17) | iPhone 17 (iOS 26.5 Simulator) | 退出码 0 (14/14 通过) | `build/DerivedData/Logs/Test` | 无（全量 UI Smoke 测试通过） |

---

## UI 证据

- `VelaSmokeUITests` 14 项 UI 测试在 iPhone 17 模拟器全量实际运行通过（耗时 193.5s，`build/DerivedData/Logs/Test/Test-Vela-2026.09.06_09-06-22-+0800.xcresult`）。
- 重点通过用例：
  - `testTodayScoreContentAndMetricRouting`：Passed
  - `testTrendsScoreContentAndMetricRouting`：Passed
  - `testFourPrimarySurfacesAreReachable`：Passed

---

## 算法证据

- `DataCoverageAndEvidenceTests` 包含针对 S1–S8 的逐项单元测试，全部通过：
  - `testS1ObservationTimePreservedAndIndependentOfRecomputation`：验证 08:00 观测 vs 22:00 重算解耦，SpO₂ 与 HRV 窗口独立。
  - `testS2LongTermBaselineRequiresAtLeast60SamplesAndIgnoresFuture`：验证 30 样本门控关闭，75 样本门控开启且对未来隔离。
  - `testS3PSTIRequiresGenuineRMSSDAndDoesNotFallbackToSDNN`：验证仅 SDNN 时 PSTI 拒绝输出，同方法 RMSSD 具备时准确输出。
  - `testS4SleepTargetBehavioralGoalDoesNotClaimAASMPhysiologicalAdequacy`：验证 5h 目标达成不标注为生理充分满足，唤醒次数标注估算。
  - `testS5WorkoutDeduplicationAndTRIMPMethodCodes`：验证重复 UUID 训练去重，TRIMP 方法代码记录。
  - `testS6DiscontinuousCalendarDaysDecayEWMAAndDeactivatesWhenUnder7Days`：验证断续日历天 EWMA 衰减，少于 7 天停用负荷状态。
  - `testS7PhysiologicalStressExcludedDuringWorkoutRecoveryWindow`：验证运动后 90 分钟窗口压力为 nil（非 0）。
  - `testS8EnergyBankOvernightStabilityNeutralWhenMissingAndPropagatesQuality`：验证夜间信号全缺时中性 50 估计，上游低置信度穿透降级，压力排除时不出现能量回弹。
- 历史 Golden 回放测试保持 100% 数值兼容：
  - `testDailyHealthComputationGoldenFixtureAndVersionConsistency`：Passed（Sleep 77.43, Recovery 60.70, Strain 63.67, Stress 21.08, Energy 42.31）。
  - `testPR0GoldenProjectsExactFiveScoresVersionsSourceAndCompleteness`：Passed。

---

## 未解决与未验证

1. **未解决项**：无。S1–S8 卡目标与约束已全部执行完毕。
2. **未验证环境**：
   - 真实 iPhone 硬件真机部署（按计划需在 R1 进行无线调试通道部署）；当前在 iOS 26.5 Simulator (iPhone 17) 完成全量编译、单元测试与 UI 自动化测试。

---

## 回滚方法

`git revert 72c0f91ad466259259d84f0b367eed56e19b5aaa`；不涉及数据库迁移或破损，回滚完全安全。

---

## 下一张建议卡（本会话不自动执行）

用户明确本次只做 S1–S8。按执行计划，下一张建议卡为 **V1｜建立可复跑的算法比较与模型卡** 或 **R1｜真机发布与用户体验验收**。
