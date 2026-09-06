# 恢复评分指标模型卡 (Recovery Score Model Card)

指标及算法版本：RecoveryScoreEngine v1.0 (ScoringAlgorithmVersions.recovery)
状态：工程回归已验证 / 生理有效性未验证 / 无真实临床队列标注数据

## 1. 用途与不适用用途
- **适用用途**：基于可穿戴设备（Apple Watch）采集的夜间静息心率、心率变异性（HRV SDNN）、前夜睡眠评分及昨日训练负荷，提供日常身体恢复倾向的启发式估计（0–100），辅助日常活动与作息安排。
- **不适用用途**：严禁用于任何医疗诊断、心律失常筛查、感染诊断、心肌炎判断或自主神经病变评估；不能作为急性过劳或过度训练综合征（Overtraining Syndrome）的医疗结论。

## 2. 目标人群与未覆盖人群
- **目标人群**：一般健康成年人群（18–65岁），规律佩戴 Apple Watch 入睡并同步健康数据者。
- **未覆盖人群**：心律失常（房颤、频发室早/房早）、安装心脏起搏器、服用影响自主神经药物（如β受体阻滞剂、抗胆碱能药物）、孕期、轮班倒作息、未成年人及急性重症感染患者。

## 3. 预测/描述的真实目标
- **真实目标**：描述夜间心血管自主神经张力相对个人近期（21–42天）中位稳态的偏离程度，并结合睡眠质量与前日负荷，形成一个相对参考值（非绝对生理负荷真实值）。

## 4. 输入类型、单位、来源、采样窗口
- `hrvToday`：毫秒 (ms)，Apple Watch HealthKit 导出的 SDNN（白天+夜间或夜间加权），采样窗口为昨夜/清晨静息时段。
- `restingHeartRateToday`：次/分 (bpm)，HealthKit 日静息心率，Apple 算法于静息状态测定。
- `sleepScoreLastNight`：0–100 分，由 `SleepScoreEngine` 依据前夜睡眠时长、一致性与中断计算所得。
- `strainScoreYesterday`：0–100 分，由 `StrainScoreEngine` 计算的昨日耗力评分。
- `hrvRmssdToday`（可选）：毫秒 (ms)，用于副交感神经张力指数（PSTI）；如无同方法测量值则不估计 PSTI。
- `bodyTempDelta`（可选）：摄氏度偏离值 (°C)，Apple Watch 夜间手腕温度相对个人基线的偏离。
- `SpO2`（可选）：百分比 (%)，夜间平均血氧饱和度。
- `respiratoryRateToday`（可选）：次/分 (rpm)，夜间呼吸频率。

## 5. 个人基线窗口、有效天数与源/方法变化政策
- **基线窗口**：默认 21–42 天历史中位数（`PersonalBaselineEngine.median`）与稳健标准差（MAD 变换）。
- **有效天数门控**：历史天数不足 5 天时，降级使用单点/有限基线，置信度标记为 `low`。
- **源/方法变化政策**：严格区分 SDNN 与 RMSSD。SDNN 用于恢复主评分（35% 权重），RMSSD 仅在有真实测量且存在同方法基线时计算 PSTI，严禁以 SDNN 冒充 RMSSD。

## 6. 缺失、零值、排除窗口、异常值政策
- **缺失政策**：必须同时具备前夜睡眠信号（`sleepScoreLastNight`）以及至少一项心血管信号（`hrvToday` 或 `restingHeartRateToday`），否则恢复评分严格不可估计（输出 `nil`），显示 `--`，置信度标记为 `low`。
- **零值与负值**：心率与 HRV <= 0 或非有限浮点数自动视为无效数据过滤。
- **异常值钳制**：最终评分严格限制在 [0, 100] 区间。

## 7. 时间 as-of 与输入修订政策
- **As-of 边界**：计算时间戳强制为当日评估切点（历史日为当日 23:59:59，当日为当前调用时间）。
- **未来数据隔离**：基线历史与计算严格过滤 > asOf 的未来时间戳，杜绝信息泄露。

## 8. 公式/参数与每个参数依据
- **主加权公式**：
  Recovery = (0.35 * S_HRV + 0.25 * S_RHR + 0.25 * S_Sleep + 0.15 * (100 - Strain_yesterday)) / Sum(AvailableWeights)
- **HRV 映射**：
  Z_HRV = (ln(HRV) - median(ln(HRV))) / MAD_robust
  S_HRV = clamp(50 + 48 * (2 / (1 + exp(-0.45 * Z_HRV)) - 1), 0, 100)
- **红旗惩罚项**：
  - 手腕体温偏高 >= +1.0°C：扣减 8 分；
  - 呼吸频率 Z >= 1.5：扣减 5 分；
  - 血氧 SpO2 < 94%：扣减 8 分；
  - 静息心率升高且 HRV 显著受抑（Z_RHR > 2.0 且 Z_HRV < -1.0）：扣减 8 分。

## 9. 哪些是文献支持的概念，哪些是本产品启发式
- **文献支持概念**：
  - HRV 对数转换（ln SDNN / ln RMSSD）以改善偏态分布（Plews et al., 2012）。
  - 使用稳健统计量（中位数与 MAD）建立个体化基线以抵抗离群值。
  - 心血管副交感神经活动与睡眠质量对恢复的联合指导意义。
- **本产品启发式**：
  - 权重配比（35% HRV / 25% RHR / 25% Sleep / 15% Prior Strain）；
  - Sigmoid 压缩斜率 0.45 与振幅 48；
  - 体温扣 8 分、呼吸率扣 5 分、血氧扣 8 分的离散惩罚逻辑；
  - 极端高负荷后反常高 HRV（Z > 2.2 且 Strain > 75）上限封顶 65 分的副交感过度激活保护。

## 10. 结果刻度/方向/状态文案
- **刻度**：0–100 分，分值越高代表恢复倾向越充分。
- **分段映射**：
  - 0–33：Low（偏低，建议调整日程或以轻度恢复性活动为主）
  - 34–66：Medium（适中，维持常规日常节奏）
  - 67–100：High（良好，身体准备度充分）

## 11. 数据质量与模型不确定性如何分开
- **数据质量（Confidence）**：由输入缺失情况与基线完整性决定。若缺失睡眠或心血管信号，质量为 unavailable 或 low；基线不足 5 天为 low；完整为 high。
- **模型不确定性（Reasons）**：通过可解释性文本向用户显式说明（如“由于缺少昨日耗力记录，权重已重新归一化分配”）。

## 12. 已执行工程测试与结果
- `RecoveryReplaySensitivityTests.swift`：覆盖 14 种极端/边界测试（单点扰动、完全缺失、极大值溢出、冷启动基线），全部通过。
- `DataCoverageAndEvidenceTests.swift`：10 个重放场景全量对比验证，JSON/CSV 格式对齐输出。

## 13. 对照基线、留出策略与真实样本
- **真实人群留出评估**：**未做（无合法获授权的公开第三方临床金标准数据集）**。
- **现有基线**：以当前规则的合成回归测试集作为工程正确性基线。

## 14. 实际效果/误差/校准/区间
- **临床有效性/AUC/相关系数**：**未做（严禁编造样本量与相关系数）**。

## 15. 已知限制与失败情境
- Apple Watch 间歇性采样导致夜间 HRV 样本稀疏，受当晚睡姿、微觉醒干扰较大；
- 算法对急性酒精摄入敏感（心率剧增、HRV 骤降），但无法区分酒精引起的自主神经紊乱与高强度训练疲劳；
- 感染初期（发热前潜伏期）可能仅表现为体温微弱上升或 HRV 下降，本启发式不能替代体温计或抗原检测。

## 16. 新旧版本影响/下游连锁
- **下游消费**：恢复评分直接作为 `EnergyBankEngine`（能量银行）的起始晨间充能来源，并作为 `StrainScoreEngine`（耗力引擎）推荐负荷区间的决定因子。
- **版本隔离**：`ScoringAlgorithmVersions.recovery = "1.0.0"`，不可估计时不输出伪造随机数，阻断错误传导。

## 17. 发布/回滚条件
- **发布条件**：工程单元测试 100% 通过，质量门禁零警告，无 NaN 或负值输出。
- **回滚条件**：一旦发现历史数据因时间过滤失效导致基线污染，或输入变更引发崩溃，立即回滚至隔离发布分支。

## 18. 来源链接及读取日期
- Task Force of ESC/NASPE. Heart rate variability: standards of measurement, physiological interpretation and clinical use. *Circulation*, 1996. (读取日期: 2026-08-20)
- Plews DJ, et al. Heart rate variability in elite British athletes: dynamic trends in relationship to performance. *Sports Med*, 2012. (读取日期: 2026-08-20)
