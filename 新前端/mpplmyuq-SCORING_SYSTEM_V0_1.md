# SCORING_SYSTEM_V0_1.md
# Project Vela — Scoring System Specification v0.1

> Status: Product / engineering specification for the first usable private build  
> Scope: Heuristic, configurable, explainable scoring system  
> Medical status: **Not a medical diagnostic system**. All scores are wellness proxies intended for trend interpretation and product experimentation.

---

# 1. 设计目标

Vela v0.1 的评分系统不是为了在第一阶段精确复现 Bevel 的私有算法，而是为了建立一套：

1. **可解释**：每个分数都能回答“为什么今天是这个分数”；
2. **个体化**：优先相对用户自身基线，而不是使用生硬的绝对阈值；
3. **可配置**：权重、窗口、阈值都应集中配置；
4. **可迭代**：后续可基于论文、公开资料、竞品逆向逐步升级；
5. **可被 Agent 使用**：每个引擎不仅输出分数，还输出原因、贡献项、置信度。

---

# 2. 通用约定

## 2.1 分数范围

所有核心分数统一归一化到：

```text
0 - 100
```

其中：
- `0` 表示非常差 / 非常低；
- `50` 表示中性或接近个人常态；
- `100` 表示非常好 / 非常高。

---

## 2.2 状态分档

### 通用 Band
| 分数区间 | Band |
|---|---|
| 0–39 | Low |
| 40–69 | Moderate |
| 70–100 | High |

某些模块可使用更语义化文案：
- Stress: Calm / Moderate / Elevated / High
- Energy Bank: Depleted / Low / Stable / Strong

---

## 2.3 基线窗口

Vela v0.1 推荐使用滚动个人基线。

| 指标 | 推荐基线窗口 |
|---|---|
| HRV | 最近 28 天 |
| Resting Heart Rate | 最近 28 天 |
| Sleep duration | 最近 14 天 + 用户目标 |
| Bedtime regularity | 最近 14 天 |
| Strain | 最近 14 天 |
| Stress | 最近 14 天 |
| VO₂ Max / Body metrics | 最近 90 天 |

---

## 2.4 数据置信度

所有评分结果建议携带 `confidence`：

| Confidence | 条件 |
|---|---|
| High | 有足够历史数据，关键指标完整 |
| Medium | 部分指标缺失，但核心指标可用 |
| Low | 历史数据不足或关键指标缺失 |

示例：
```json
{
  "score": 72,
  "band": "High",
  "confidence": "Medium"
}
```

---

# 3. 基础数学工具

## 3.1 相对基线偏差

```text
relative_delta = (today_value - baseline_mean) / baseline_mean
```

若值越高越好，例如 HRV：
- 正偏差 = 加分；
- 负偏差 = 扣分。

若值越低越好，例如 RHR：
- 负偏差 = 加分；
- 正偏差 = 扣分。

---

## 3.2 Z-score

```text
z = (today_value - baseline_mean) / baseline_std
```

用途：
- 判断是否明显偏离个人常态；
- 用于生成 AI 原因解释；
- v0.1 可先使用 `z-score clipped to [-2.5, 2.5]`。

---

## 3.3 Clamp

所有中间分数必须截断：

```text
clamp(x, min, max)
```

---

## 3.4 Sigmoid / Piecewise 映射

第一版可优先采用 piecewise 线性映射，便于解释。

示例：
```text
delta <= -20% -> 20
delta = 0%     -> 50
delta >= +20% -> 90
```

---

# 4. Sleep Score v0.1

## 4.1 目标

Sleep Score 用于表示：
- 昨晚睡眠是否接近用户需要；
- 作息是否稳定；
- 为 Recovery 提供输入；
- 为 AI Sleep Review 提供可解释依据。

---

## 4.2 v0.1 输入

### 必需输入
- `total_sleep_minutes`
- `sleep_target_minutes`
- `bedtime`
- `wake_time`
- `bedtime_baseline`
- `wake_time_baseline`

### 可选输入
- `awake_minutes`
- `sleep_stage_summary`

> v0.1 的主评分只使用“总时长 + 规律性”。夜间清醒时长与睡眠阶段比例保留为解释字段，后续再纳入正式算法。

---

## 4.3 分项

### 4.3.1 Duration Score

#### 目标
评估睡眠时长相对目标的完成度。

```text
duration_ratio = total_sleep_minutes / sleep_target_minutes
```

建议映射：

| duration_ratio | duration_score |
|---|---|
| < 0.60 | 10 |
| 0.60–0.75 | 30 |
| 0.75–0.90 | 60 |
| 0.90–1.10 | 95 |
| 1.10–1.25 | 85 |
| > 1.25 | 70 |

### 解释
- 低于目标过多：明显扣分；
- 接近目标：高分；
- 过长睡眠不直接视为越多越好，轻微回落。

---

### 4.3.2 Regularity Score

#### 目标
评估入睡 / 起床时间相对个人近 14 天常态的偏离程度。

```text
bedtime_offset_minutes = abs(today_bedtime - baseline_bedtime)
wake_offset_minutes = abs(today_wake_time - baseline_wake_time)
avg_offset = (bedtime_offset_minutes + wake_offset_minutes) / 2
```

建议映射：

| avg_offset | regularity_score |
|---|---|
| 0–30 min | 95 |
| 31–60 min | 80 |
| 61–90 min | 60 |
| 91–120 min | 40 |
| >120 min | 20 |

---

## 4.4 Sleep Score 总分

```text
SleepScore =
  0.70 * DurationScore
+ 0.30 * RegularityScore
```

### 说明
- v0.1 以“时长”为主；
- “规律性”作为第二因子；
- 后续可加入 `sleep_efficiency`, `awake_minutes`, `stage_balance`。

---

## 4.5 Sleep Score 输出结构

```json
{
  "score": 78,
  "band": "High",
  "confidence": "Medium",
  "components": {
    "duration_score": 82,
    "regularity_score": 69
  },
  "reasons": [
    "Sleep duration reached 94% of target",
    "Bedtime was 52 minutes later than the recent baseline"
  ],
  "metrics": {
    "total_sleep_minutes": 424,
    "sleep_target_minutes": 450,
    "bedtime_offset_minutes": 52,
    "wake_offset_minutes": 18
  }
}
```

---

## 4.6 Sleep Score 伪代码

```swift
func calculateSleepScore(input: SleepScoreInput) -> SleepScoreResult {
    let durationRatio = input.totalSleepMinutes / input.sleepTargetMinutes
    let durationScore = mapDurationRatioToScore(durationRatio)

    let avgOffset = (
        abs(input.bedtimeOffsetMinutes) +
        abs(input.wakeOffsetMinutes)
    ) / 2

    let regularityScore = mapOffsetToRegularityScore(avgOffset)

    let rawScore =
        0.70 * durationScore +
        0.30 * regularityScore

    return SleepScoreResult(
        score: clamp(rawScore, 0, 100),
        band: bandForScore(rawScore),
        confidence: determineSleepConfidence(input),
        components: ...,
        reasons: ...
    )
}
```

---

# 5. Recovery Score v0.1

## 5.1 目标

Recovery Score 反映：
- 今天的身体恢复状态；
- 身体是否处于相对适合训练 / 工作的状态；
- 为 Agent 的 Workout Readiness 与 Morning Brief 提供核心依据。

---

## 5.2 v0.1 输入

### 必需输入
- `hrv_today`
- `hrv_baseline_28d`
- `resting_hr_today`
- `resting_hr_baseline_28d`
- `sleep_score_last_night`
- `strain_score_yesterday`

### 可选输入
- `sleep_heart_rate`
- `respiratory_rate_during_sleep`
- `sleep_debt_proxy`

---

## 5.3 分项

### 5.3.1 HRV Score

#### 逻辑
HRV 高于个人基线通常被视为恢复更好；低于基线则恢复偏弱。

```text
hrv_delta = (hrv_today - hrv_baseline_mean) / hrv_baseline_mean
```

建议映射：

| hrv_delta | hrv_score |
|---|---|
| <= -25% | 15 |
| -25% to -10% | 35 |
| -10% to +5% | 55 |
| +5% to +20% | 80 |
| >= +20% | 95 |

---

### 5.3.2 RHR Score

#### 逻辑
静息心率低于个人基线通常更有利；高于基线则可能反映疲劳、压力或恢复不足。

```text
rhr_delta = (rhr_today - rhr_baseline_mean) / rhr_baseline_mean
```

建议映射：

| rhr_delta | rhr_score |
|---|---|
| >= +10% | 20 |
| +5% to +10% | 40 |
| -5% to +5% | 65 |
| -10% to -5% | 80 |
| <= -10% | 90 |

---

### 5.3.3 Sleep Contribution Score

直接使用：
```text
sleep_component = sleep_score_last_night
```

---

### 5.3.4 Prior Strain Recovery Score

昨天负荷越高，今天 Recovery 通常应受到一定折损。

建议将昨日 Strain 反向映射为恢复贡献：

| yesterday_strain | prior_strain_score |
|---|---|
| 0–30 | 90 |
| 31–55 | 75 |
| 56–75 | 55 |
| 76–90 | 35 |
| 91–100 | 20 |

---

## 5.4 Recovery 总分

### 推荐范式
```text
RecoveryScore =
  w_hrv * HRVScore
+ w_rhr * RHRScore
+ w_sleep * SleepScore
+ w_prior_strain * PriorStrainScore
```

### v0.1 默认配置建议
```json
{
  "hrv": 0.35,
  "rhr": 0.25,
  "sleep": 0.25,
  "prior_strain": 0.15
}
```

> 文档中规定算法范式，但代码应将权重放入配置文件或常量层，后续可调。

---

## 5.5 Recovery 输出结构

```json
{
  "score": 64,
  "band": "Moderate",
  "confidence": "High",
  "components": {
    "hrv_score": 48,
    "rhr_score": 62,
    "sleep_score": 78,
    "prior_strain_score": 55
  },
  "weights": {
    "hrv": 0.35,
    "rhr": 0.25,
    "sleep": 0.25,
    "prior_strain": 0.15
  },
  "reasons": [
    "HRV was below the 28-day baseline",
    "Sleep score was solid",
    "Yesterday's strain was moderate-high"
  ]
}
```

---

# 6. Strain Score v0.1

## 6.1 目标

Strain Score 用于描述：
- 用户当天累积了多大的身体负荷；
- 今天是否已经达到适合的活动强度；
- 与 Recovery 联动，服务 AI 训练建议。

---

## 6.2 v0.1 策略

Vela 第一版要做“全天 Strain”，不只是 Workout Load。

### 输入
- `active_energy_kcal_today`
- `exercise_minutes_today`
- `workouts_today`
- `workout_heart_rate_profile`
- `personal_recent_activity_baseline`

---

## 6.3 分项

### 6.3.1 Activity Energy Load

以个人近 14 天活动能量基线为参照。

```text
energy_ratio = active_energy_today / active_energy_baseline_14d
```

建议映射：

| energy_ratio | energy_load_score |
|---|---|
| < 0.4 | 15 |
| 0.4–0.8 | 35 |
| 0.8–1.2 | 55 |
| 1.2–1.6 | 75 |
| > 1.6 | 90 |

---

### 6.3.2 Exercise Duration Load

```text
exercise_ratio = exercise_minutes_today / exercise_minutes_baseline_14d
```

建议映射与 energy 类似，若用户历史无稳定 exercise baseline，可降权或使用绝对时间占位规则。

---

### 6.3.3 Workout Intensity Load

第一版不强求完整心率区间生理学建模，可采用启发式：

```text
workout_intensity_load =
  sum(workout_duration_minutes * intensity_multiplier)
```

建议倍率：
| 类型 | multiplier |
|---|---|
| Light | 0.8 |
| Moderate | 1.0 |
| Hard | 1.3 |
| Very Hard | 1.6 |

若有心率区间：
- Zone 1–2 → Light
- Zone 3 → Moderate
- Zone 4 → Hard
- Zone 5 → Very Hard

---

## 6.4 Strain 总分

建议 v0.1：

```text
StrainScore =
  0.45 * EnergyLoadScore
+ 0.25 * ExerciseDurationScore
+ 0.30 * WorkoutIntensityScore
```

若当天没有 workout：
- WorkoutIntensityScore 可以为 0；
- 但 Energy 与 Exercise 仍可形成基础 Strain。

---

## 6.5 推荐负荷 Target Range

建议根据 Recovery 给出当天 Strain 目标区间：

| Recovery | Recommended Strain |
|---|---|
| Low | 20–45 |
| Moderate | 40–70 |
| High | 60–85 |

输出文案：
- Below target
- Within target
- Above target

---

## 6.6 Strain 输出结构

```json
{
  "score": 58,
  "band": "Moderate",
  "confidence": "Medium",
  "recommended_range": [40, 70],
  "target_status": "Within target",
  "components": {
    "energy_load_score": 61,
    "exercise_duration_score": 52,
    "workout_intensity_score": 57
  },
  "reasons": [
    "Today's active energy is close to your recent baseline",
    "Workout intensity was moderate",
    "Your current strain is within the recommended range for a moderate recovery day"
  ]
}
```

---

# 7. Stress Index v0.1

## 7.1 目标

Stress Index 是一个“生理压力代理指标”，用于帮助用户理解：
- 今天是否处于相对紧绷状态；
- 压力是否在日内升高；
- 是否与睡眠不足、近期高负荷有关。

---

## 7.2 边界声明

Stress Index：
- 不是医学诊断；
- 不等价于心理压力；
- 不应在文案中断言“你正在焦虑”；
- 只能描述“当前生理指标显示压力代理信号偏高”。

---

## 7.3 输入

- `heart_rate_relative_to_baseline`
- `recent_hrv_relative_to_baseline`
- `current_activity_context`
- `sleep_score`
- `recent_strain`

---

## 7.4 分项

### 7.4.1 HR Elevation Score
静息或低活动状态下，心率相对个人常态升高，压力指数应上升。

### 7.4.2 HRV Suppression Score
短期 HRV 低于常态，压力指数应上升。

### 7.4.3 Sleep / Strain Context
- 睡眠差 → 压力指数轻微加权；
- 近期负荷高 → 压力指数轻微加权。

---

## 7.5 Stress Index 总分

建议采用正向“压力越高，分数越高”的定义：

```text
StressIndex =
  0.40 * HeartRateElevationScore
+ 0.35 * HRVSuppressionScore
+ 0.15 * SleepDebtStressScore
+ 0.10 * RecentStrainStressScore
```

---

## 7.6 Stress Band

| Stress Index | Band |
|---|---|
| 0–24 | Calm |
| 25–49 | Normal |
| 50–74 | Elevated |
| 75–100 | High |

---

## 7.7 Stress 输出结构

```json
{
  "stress_index": 61,
  "band": "Elevated",
  "confidence": "Medium",
  "reasons": [
    "Recent HRV was below baseline",
    "Heart rate was higher than usual during low-activity periods",
    "Last night's sleep was below target"
  ]
}
```

---

# 8. Energy Bank v0.1

## 8.1 目标

Energy Bank 用“身体电量”的比喻，向用户表达：
- 早晨醒来时有多少可用能量；
- 白天当前剩余能量大致如何；
- Strain 与 Stress 如何消耗它。

---

## 8.2 v0.1 输出范围

第一版只做：
1. `Morning Energy`
2. `Current Energy`

暂不做精细完整日内曲线。

---

## 8.3 Morning Energy

建议由 Recovery 与 Sleep 共同决定：

```text
MorningEnergy =
  0.65 * RecoveryScore
+ 0.35 * SleepScore
```

---

## 8.4 Current Energy

```text
CurrentEnergy =
  MorningEnergy
- StrainDrain
- StressDrain
```

### Drain 设计建议
```text
StrainDrain = 0.45 * StrainScore
StressDrain = 0.25 * StressIndex
```

之后进行截断：
```text
CurrentEnergy = clamp(CurrentEnergy, 0, 100)
```

---

## 8.5 解释规则

| Current Energy | Status |
|---|---|
| 0–24 | Depleted |
| 25–49 | Low |
| 50–74 | Stable |
| 75–100 | Strong |

---

## 8.6 输出结构

```json
{
  "morning_energy": 74,
  "current_energy": 52,
  "status": "Stable",
  "reasons": [
    "Morning energy was supported by solid sleep",
    "Today's strain has moderately reduced available energy",
    "Stress index is slightly elevated"
  ]
}
```

---

# 9. Health Age Trend v0.1

## 9.1 目标

Health Age Trend v0.1 不输出“你实际生理年龄是 X 岁”，而是输出：
- 长期健康趋势在改善、稳定还是变差；
- 哪些指标推动趋势变化；
- 作为未来 Biological Age 模块的过渡层。

---

## 9.2 输入

- `vo2max_trend_90d`
- `resting_hr_trend_90d`
- `hrv_trend_90d`
- `weight_trend_90d`
- `body_fat_trend_90d`
- `lean_mass_trend_90d`
- `sleep_regularity_trend_30d`
- `activity_consistency_trend_30d`

---

## 9.3 趋势方向

每个子指标输出：
- Positive
- Neutral
- Negative

示例：
- VO₂ Max 上升 → Positive
- RHR 持续下降或稳定较优 → Positive
- HRV 持续改善 → Positive
- 睡眠规律性下降 → Negative

---

## 9.4 总趋势

建议先不输出 0–100 年龄分，而输出：

```text
TrendScore in [-1, +1]
```

解释：
- `+1`：明显改善；
- `0`：稳定；
- `-1`：明显变差。

### 文案映射
| TrendScore | Label |
|---|---|
| 0.35 to 1.00 | Improving |
| -0.34 to 0.34 | Stable |
| -1.00 to -0.35 | Worsening |

---

## 9.5 输出结构

```json
{
  "trend_score": 0.42,
  "label": "Improving",
  "confidence": "Low",
  "positive_factors": [
    "VO2 Max improved over the last 90 days",
    "Resting heart rate remained slightly below historical average"
  ],
  "negative_factors": [
    "Sleep regularity declined during the last month"
  ]
}
```

---

# 10. Scoring Engine 通用输出协议

所有评分引擎建议统一遵循：

```json
{
  "score": 0,
  "band": "",
  "confidence": "",
  "components": {},
  "reasons": [],
  "metrics": {},
  "config_version": "v0.1"
}
```

特殊引擎可扩展字段：
- `recommended_range`
- `target_status`
- `trend_score`
- `morning_energy`
- `current_energy`

---

# 11. 配置化建议

建议维护：

```text
ScoringConfig.swift
```

或 JSON / plist 配置：

```json
{
  "sleep": {
    "duration_weight": 0.70,
    "regularity_weight": 0.30
  },
  "recovery": {
    "hrv_weight": 0.35,
    "rhr_weight": 0.25,
    "sleep_weight": 0.25,
    "prior_strain_weight": 0.15
  },
  "strain": {
    "energy_weight": 0.45,
    "exercise_weight": 0.25,
    "workout_intensity_weight": 0.30
  },
  "stress": {
    "heart_rate_weight": 0.40,
    "hrv_weight": 0.35,
    "sleep_debt_weight": 0.15,
    "recent_strain_weight": 0.10
  }
}
```

---

# 12. 缺失数据处理

## 12.1 原则
- 不要因为一个指标缺失而让整页崩溃；
- 分数引擎应根据 available inputs 自动重归一化权重；
- 缺失越多，confidence 越低；
- UI 应解释“本分数基于有限数据”。

---

## 12.2 示例：Recovery 缺失 HRV

若 HRV 不可用：
- 移除 HRV 因子；
- 剩余权重重新归一化；
- Confidence 降为 Medium 或 Low；
- reasons 中加入：
  - `"HRV data unavailable; recovery score is based on remaining metrics."`

---

# 13. Agent 可使用的解释字段

Agent 不应自己猜测分数含义，而应直接读取评分结果里的：
- `reasons`
- `components`
- `confidence`
- `band`
- `target_status`

例如：
```json
{
  "reasons": [
    "HRV was 18% below the 28-day baseline",
    "Sleep score was 78, close to the target range"
  ]
}
```

---

# 14. 后续研究路线

v0.1 完成后，建议依次研究：

1. Recovery：
   - 更合理的 HRV / RHR 个体基线建模；
   - Robust z-score；
   - 多日疲劳累积。

2. Sleep：
   - Sleep efficiency；
   - Wake after sleep onset；
   - Sleep regularity index；
   - 睡眠阶段比例是否纳入分数。

3. Strain：
   - TRIMP；
   - 心率区间积分；
   - Training Load；
   - Acute / Chronic workload。

4. Stress：
   - activity-context adjusted HR；
   - HRV 短窗建模；
   - 生理压力 proxy 更稳健估计。

5. Health Age:
   - 更正式的健康年龄或 biological age 研究；
   - 不同指标的长期趋势权重；
   - 与公开健康span研究做概念对齐。

---

# 15. Definition of Done

Scoring System v0.1 完成标准：

- [ ] Sleep Score 可计算；
- [ ] Recovery Score 可计算；
- [ ] Strain Score 可计算；
- [ ] Stress Index 可计算；
- [ ] Morning / Current Energy 可计算；
- [ ] Health Age Trend 可计算；
- [ ] 所有输出均有 reasons；
- [ ] 缺失数据下不中断；
- [ ] 权重可配置；
- [ ] Agent 能直接消费评分结果；
- [ ] UI 能展示核心分数、Band 与主要原因。
