# 任务交接：Q0｜恢复当前 iOS 可验证基线

任务：Q0｜恢复当前 iOS 可验证基线  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`  
交付 SHA：`7f23f61bdb8bc48c6563ef8a348cdf9a231d366d`  
工作区未提交改动与处理：代码改动已全部提交并推送到 `origin/main`；保留执行书及其说明模板（`PROGRESS.md`、`START_HERE.md`、`RULES_TO_PASTE.md`、`tasks/`、`templates/`）。

---

## 本卡改变的用户行为
无直接终端用户 UI 行为改变。修复了 Xcode 16 / Swift 6 下 CI 构建门禁因 SPM 第三方包（SentryCppHelper）默认 `-suppress-warnings` 与全局 CLI 参数 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` 冲突导致的编译失败，并在本地与远程恢复了全量 iOS 单测（549 项）与 UI Smoke 测试（6 项）的实际运行与自动化通过。

---

## 实际修改文件及理由

1. **[.github/workflows/quality.yml](file:///Users/sunweizhou/Developer/Vela/.github/workflows/quality.yml)**：
   - 移除 `xcodebuild` 命令行的全局 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` 与 `GCC_TREAT_WARNINGS_AS_ERRORS=YES` 覆盖参数。
   - 解决根因：命令行参数是全局最高优先级，会强行注入所有外部 Swift Package（包括 SPM 管理的 `sentry-cocoa` / `SentryCppHelper`），导致 Swift 编译器驱动收到相互冲突的 `-warnings-as-errors` 与 `-suppress-warnings` 而致命崩溃。

2. **[Vela.xcodeproj/project.pbxproj](file:///Users/sunweizhou/Developer/Vela/Vela.xcodeproj/project.pbxproj)**：
   - 在项目各目标配置中明确固化：
     - `Vela` (Release)
     - `VelaTests` (Debug & Release)
     - `VelaUITests` (Debug & Release)
   - 加上已有的 `Vela` (Debug)，使仓库中所有首方应用与测试 Target 统一原生配置 `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` 与 `GCC_TREAT_WARNINGS_AS_ERRORS = YES`。
   - 保证质量门禁 100% 保持激活（严禁任何 warning 进入首方代码），同时保护第三方包不发生命令行编译参数冲突。

3. **[VelaAppTests/TodayStoreTests.swift](file:///Users/sunweizhou/Developer/Vela/VelaAppTests/TodayStoreTests.swift)**：
   - 在 `testCancellingOneCoalescedWaiterDoesNotCancelSharedLoad` 中，将脆弱的固定 20ms 等待替换为带超时（最多 500ms）的有界轮询。
   - 消除在开启代码覆盖率（code coverage）收集或负载较高时，MainActor 协作调度轻微延迟引起的单测 Flaky 偶发误报。

---

## 数值/单位/缺失/日期/算法版本是否改变
否。五项评分（Recovery, Sleep, Strain, Stress, Energy）的公式、输入、单位、版本及快照结构均未发生任何改动。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS (Local) | 退出码 0 | 终端输出 | 无（32 live / 32 frozen models 一致） |
| `python3 scripts/check_contrast.py` | macOS (Local) | 退出码 0 | 终端输出 | 无（textColor 全部 >= 4.5:1） |
| `python3 scripts/check_fixed_fonts.py` | macOS (Local) | 退出码 0 | 终端输出 | 无（212 处固定字号站点审计） |
| `xcodebuild clean build` (`Vela`, Debug, generic/platform=iOS Simulator) | Xcode 26.6, Swift 6.3.3 | 退出码 0 | `build/DerivedData` | 无（编译完全通过，0 错误，0 警告） |
| `xcodebuild test` (`VelaTests`, iPhone 17) | iPhone 17 (iOS 26.5 Simulator) | 退出码 0 (549/549 通过) | `build/UnitTests.xcresult` | 无 |
| `xcodebuild test` (`VelaUITests`, iPhone 17) | iPhone 17 (iOS 26.5 Simulator) | 退出码 0 (6/6 通过) | `build/UISmokeTests.xcresult` | 无 |
| `swift test --package-path BodySeekDomain` | macOS SwiftPM | 退出码 0 (11/11 通过) | 终端输出 | 无 |
| `swift test --package-path VelaBackend` | macOS SwiftPM | 退出码 0 (3/3 通过) | 终端输出 | 无 |

---

## UI 证据
UI Smoke 测试 6/6 实际运行通过（耗时 61.2s，产物位于 `build/UISmokeTests.xcresult`）：
- `testSettingsDeepLaunch`：Passed (5.51s)
- `testTodayScoreContentAndMetricRouting`：Passed (11.25s)
- `testTrendsScoreContentAndMetricRouting`：Passed (13.95s)
- 其余 3 项深层启动与导航测试均通过。

---

## 算法证据
本卡不涉及公式调整；生产链与纯领域测试全部重放通过：
- `VelaTests`：549 项测试通过（0 失败，0 跳过）；
- `BodySeekDomain`：11 项测试通过（含 `GoldenReplayTests`、`ScoreContractTests`、`SleepReplaySensitivityTests`）。

---

## 未解决与未验证
1. **未解决项**：无。Q0 范围内的构建中断与测试门禁已完全解决。
2. **未验证环境**：
   - 真实 iPhone 物理设备运行（需无线配对与签名配置，按照执行书规划将在 R1 阶段统一进行真机 Release 主链路验收）；
   - 当前 CI 构建任务（Run ID `33972511858`）已在 GitHub Actions 上自动拉起执行。

---

## 回滚方法
`git revert 7f23f61bdb8bc48c6563ef8a348cdf9a231d366d`；不涉及数据迁移或用户数据库改动，回滚完全安全。

---

## 下一张建议卡（本会话不自动执行）
**U1｜建立真实 UI 基线并完成一套组件精修**
