# 任务交接：Card V1 建立可复跑的算法比较与模型卡

任务：Card V1 建立可复跑的算法比较与模型卡 (Replayable Algorithm Comparison & Model Cards)
状态：VERIFIED
审阅起始 SHA：67827bc0255bf3721389cf7895f5bf1fa3b3e2a0
交付 SHA：待提交后回填
工作区未提交改动与处理：已将可复跑的 10 大场景测试集成于 `VelaAppTests/DataCoverageAndEvidenceTests.swift`，测试实际运行通过并生成产物。

## 本卡改变的用户行为
- 本卡为算法规范、回归防线与研究基础建设卡，不直接改动用户端当前线上界面。
- 用户端行为保持 S1–S8 确立的生理严谨性（缺失显示 `--`，运动排除窗口显示不可估计而非 0 压力，ATL/CTL 不足 7 天停用，RMSSD 缺失不伪造 PSTI）。
- 建立了完备的 5 大指标模型卡，用户和开发者可在文档中清晰追溯每一个指标的输入、生理假设、启发式参数依据、限制与未知边界。

## 实际修改文件及理由
1. `VelaAppTests/DataCoverageAndEvidenceTests.swift`：
   - 增加 `testGenerateV1ReplayComparisonData()`，以生产 `DailyHealthComputation`、`RecoveryScoreEngine` 等真实 Swift 入口对 10 大生理场景进行批量复跑。
   - 覆盖场景：全空、部分输入、基线形成期 (<7天)、正常健康基线、设备方法切换 (SDNN vs RMSSD)、日历断续间隔衰减、未来数据过滤、跨午夜时区作息、运动后 90 分钟自主神经排除、极端异常毛刺钳制。
   - 自动导出生产格式的 JSON 与 CSV。
2. `docs/validation/v1/replay_comparison.json` & `docs/validation/v1/replay_comparison.csv`：
   - 包含 10 个场景下各项指标的 Old vs New、质量（confidence）、缺失清单（missingInputs）、版本号、驱动理由（keyReason）与下游影响。
3. `docs/model_cards/RECOVERY_MODEL_CARD.md`：
   - 详述 RecoveryScoreEngine v1.0 的 20 项规范字段。
4. `docs/model_cards/SLEEP_MODEL_CARD.md`：
   - 详述 SleepScoreEngine v1.0 的 20 项规范字段。
5. `docs/model_cards/STRAIN_MODEL_CARD.md`：
   - 详述 StrainScoreEngine v1.0 的 20 项规范字段。
6. `docs/model_cards/STRESS_MODEL_CARD.md`：
   - 详述 StressIndexEngine v1.0 的 20 项规范字段。
7. `docs/model_cards/ENERGY_MODEL_CARD.md`：
   - 详述 EnergyBankEngine v1.0 的 20 项规范字段。
8. `docs/validation/v1/CANDIDATE_RESEARCH_PROTOCOL.md`：
   - 制定下一代算法候选研究协议，明确隐私知情同意、单一假设消融、天真与生产基线对照、不确定性区间报告与影子双轨准入机制。

## 数值/单位/缺失/日期/算法版本是否改变
- 算法版本保持：`1.0.0`。
- 比较逻辑明确记录：
  - 缺失时不虚构默认值；
  - 运动排除期 Stress 为 nil（非 0）；
  - 方法切换时拒绝跨类型替代；
  - 极端离群值安全钳制在 [0, 100] 且不崩溃。

## 实际运行的命令与结果
| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `xcodebuild test -only-testing:VelaTests/DataCoverageAndEvidenceTests/testGenerateV1ReplayComparisonData` | iPhone 17 模拟器 (iOS 26.5) | 退出码 0，1 个测试全部通过 (0.027s) | `docs/validation/v1/replay_comparison.json`, `docs/validation/v1/replay_comparison.csv` | 无 |

## UI 证据
本卡属于算法验证与文档卡，无 UI 渲染视图变更；现有 UI 继续由 S1–S8 交付件及仪表盘承载。

## 算法证据
- 实际输入：10 组典型边缘/稳态生理特征向量。
- 运行依据：生产级 Swift 入口，杜绝 Python 重复实现造成的漂移。
- 旧新输出对比已完整序列化至 `docs/validation/v1/replay_comparison.csv`。
- 声明：**合成测试通过明确仅代表工程实现的数学正确性与鲁棒性，不证明临床生理有效性**。

## 未解决与未验证
- 真实人群多中心临床标注数据集评估：**未做（无公开授权受试者数据集，严禁虚构 AUC 或样本量）**。
- 下一代非线性体温阶梯候选：已写入研究协议，未获正式医学评审前不合并入正式权重。

## 回滚方法
- 可通过 `git revert` 撤销本卡提交，不涉及 SwiftData Schema 变迁，对用户持久化数据零风险。

## 下一张建议卡（本会话不自动执行）
- Card R1（真机发布与用户体验验收）。
