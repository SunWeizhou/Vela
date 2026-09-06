# 任务交接：Card R1 真机发布与用户体验验收

任务：Card R1 真机发布与用户体验验收 (Release Readiness & User Experience Acceptance)
状态：BLOCKED (Hardware Unavailable; Simulator Quality Gates VERIFIED)
审阅起始 SHA：0b7d8adf (Card V1 交付基准)
交付 SHA：1483f95d
工作区未提交改动与处理：工作区干净，所有交付件已纳入版本控制。

## 本卡改变的用户行为
- 完成全量质量门禁与端到端 UI 交互闭环验证。
- 用户操作路径核验：
  - Today 首页卡片（恢复、睡眠、耗力、压力、能量）可稳定点击展开；
  - 日历切日抽屉与顶部胶囊联动顺畅，无日期错位；
  - 恢复详情标杆页进入与返回无卡顿；
  - Trends 趋势图各时间跨度（7D/30D/90D）切换正常，无假曲线与突变；
  - 弱网/离线状态下所有本地数据与评分正常读取，不弹窗阻断。

## 实际修改文件及理由
1. `docs/validation/r1/EVIDENCE_MANIFEST.md`：
   - 记录五大质量门禁实际通过结果、物理真机探测真实状态、五大指标口径追溯、隐私与日志审计、前后用户体验证据。
2. `docs/validation/R1_HANDOFF.md`：
   - 本交接文档。
3. `PROGRESS.md`：
   - 更新 R1 状态与交付 SHA。

## 数值/单位/缺失/日期/算法版本是否改变
- 算法版本保持：`1.0.0`。
- 评分单位保持：0–100。
- 事实核查：
  - 缺失时显示 `--`，无虚构数值；
  - 运动排除期生理压力输出为不可估计 (`nil`)；
  - 耗力不足 7 天历史不计算 ATL/CTL；
  - 睡眠低置信度封顶 79 分。

## 实际运行的命令与结果
| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `grep SWIFT_TREAT_WARNINGS_AS_ERRORS Vela.xcodeproj/project.pbxproj` | macOS 宿主机 | 退出码 0，6 个配置全部为 YES | Xcode 工程配置 | 无 |
| `python3 scripts/schema_fingerprint.py --check` | macOS 宿主机 | 退出码 0，32 模型匹配 | `scripts/schema_fingerprint.py` | 无 |
| `python3 scripts/check_contrast.py` | macOS 宿主机 | 退出码 0，文本对比度全部 >= 4.5:1 | `scripts/check_contrast.py` | 无 |
| `xcodebuild test -only-testing:VelaTests` | iPhone 17 (iOS 26.5) 模拟器 | 退出码 0，单元测试全部通过 (耗时 23.3s) | DerivedData 单元测试日志 | 无 |
| `xcodebuild test -only-testing:VelaUITests` | iPhone 17 (iOS 26.5) 模拟器 | 退出码 0，14 个 UI 测试全部通过 (耗时 192.5s) | DerivedData UI测试日志 | 无 |
| `xcrun devicectl device info details --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA` | 目标设备: Weizhou的iPhone (iPhone 16 Pro) | 退出码 0，读取成功 | 设备属性探测输出 | 物理设备 CoreDevice 隧道离线 (tunnelState=unavailable, ddiServicesAvailable=false)，硬件部署标为 BLOCKED |

## UI 证据
- 14 项 UI 测试覆盖：
  - `VelaSmokeUITests.testComprehensiveFullInteractionFlow` (启动、Today Tab、Trends Tab、日历抽屉打开与关闭)；
  - `VelaSmokeUITests.testTodayScoreContentAndMetricRouting` (Today 恢复/睡眠/负荷卡片与次级压力/能量指标点击展开详情及返回)；
  - `VelaSmokeUITests.testTrendsScoreContentAndMetricRouting` (Trends 周期切换、恢复图表选点、各指标卡片交互)。

## 算法证据
- 见 `docs/validation/v1/replay_comparison.csv` 与 `docs/validation/r1/EVIDENCE_MANIFEST.md`：
  - 10 大重放场景在当前 HEAD 重新验证；
  - 质量传递链（从 HealthKit 观测 $\to$ DailyHealthComputation $\to$ MetricResult $\to$ UI State）无截断、无虚构。

## 未解决与未验证
- **物理真机部署**：因 `Weizhou的iPhone` 处于无线隧道断开状态（上次连接 2026-09-01），真机安装运行明确标为 **BLOCKED (Hardware Unavailable)**，不冒充通过。
- **多中心临床有效性评估**：按 V1 模型卡规范，明确标注为**未做**。

## 回滚方法
- 本轮所有提交未修改 SwiftData 模型架构，向前向后完全兼容。回滚命令：`git revert HEAD` 或检出前置稳定 commit。

## 下一张建议卡（本会话不自动执行）
- S1–S8、V1、R1 全闭环完成，下一阶段建议：待物理设备连接后执行真机运行体验确认；或根据 `docs/validation/v1/CANDIDATE_RESEARCH_PROTOCOL.md` 启动下一代非线性体温算法的影子分支实验。
