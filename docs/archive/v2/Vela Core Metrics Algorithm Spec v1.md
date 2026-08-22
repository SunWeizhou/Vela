# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

Vela Core Metrics Algorithm Spec v1
0. 所有指标先统一一个输出协议

先让 Agent 新建统一模型，不要每个分数各写各的。

struct MetricResult: Codable, Hashable {
    var name: String
    var value: Double?              // 0–100；如果不可计算则 nil
    var band: MetricBand            // veryLow / low / normal / high / veryHigh
    var confidence: MetricConfidence // low / medium / high
    var components: [String: Double]
    var componentWeights: [String: Double]
    var reasons: [String]
    var missingInputs: [String]
    var dataWindow: DateInterval
    var source: MetricSource         // healthKit / userInput / derived / mixed
    var algorithmVersion: String
    var lastUpdated: Date
}

所有首页指标都必须满足：有值、有 confidence、有 missingInputs、有 reasons、有 algorithmVersion。没有这些字段的分数不要上首页。

1. 睡眠分数 Sleep Score
结论

睡眠分数建议改成 Apple-compatible Sleep Score，不是继续用当前 5 维模型。Apple 官方公开说明 Sleep Score 是 0–100，基于睡眠时长 50 分、入睡时间一致性 30 分、睡眠中断 20 分；一致性参考过去 13 晚，中断参考醒来频率和醒来时长。

当前 Vela 的 SleepScoreEngine 是 5 维模型：duration、efficiency、regularity、architecture、continuity，权重为 25%、20%、20%、20%、15%。 这套模型可以保留到详情页，但首页主分数建议换成 Apple-compatible 结构。

输入

从 SleepSummary 获取：

totalSleepMinutes
bedtime
wakeTime
stageMinutes[.awake]
stageMinutes[.rem]
stageMinutes[.deep]
stageMinutes[.core]
segments

历史窗口：

最近 13 晚有效睡眠记录，用于 bedtime consistency
算法

总分：

SleepScore = DurationScore(0–50)
           + ConsistencyScore(0–30)
           + InterruptionScore(0–20)
1.1 DurationScore：0–50

默认目标睡眠：

target = userSleepTargetMinutes
如果用户未设置，则 target = 450 分钟，也就是 7.5 小时

计算：

diff = totalSleepMinutes - target

建议分段：

if totalSleepMinutes is nil:
    durationScore = nil

else if totalSleepMinutes between target - 30 and target + 60:
    durationScore = 50

else if totalSleepMinutes < target - 30:
    // 低于目标，惩罚较重
    durationScore = 50 * clamp((totalSleepMinutes - 240) / ((target - 30) - 240), 0, 1)

else:
    // 睡太久也扣分，但惩罚较轻
    durationScore = 50 * clamp(1 - (totalSleepMinutes - (target + 60)) / 240, 0.35, 1)

解释：

睡眠少于 4 小时基本很差；
接近个人目标睡眠得满分；
睡太久扣分但不应像睡太少一样严重。
1.2 ConsistencyScore：0–30

用最近 13 晚的 bedtime 建立个人基线。

关键是 bedtime 跨午夜，所以必须用 circular time。

func minutesFromNoon(_ date: Date) -> Double {
    let h = calendar.component(.hour, from: date)
    let m = calendar.component(.minute, from: date)
    var minutes = Double(h * 60 + m)
    if minutes < 12 * 60 {
        minutes += 24 * 60
    }
    return minutes
}

计算：

baselineBedtime = median(minutesFromNoon(last13Bedtimes))
todayBedtime = minutesFromNoon(today.bedtime)
diff = abs(todayBedtime - baselineBedtime)

分数：

if diff <= 30 min: 30
if diff <= 60 min: 24
if diff <= 90 min: 18
if diff <= 120 min: 12
if diff <= 180 min: 6
else: 0

如果历史有效夜晚少于 5 晚：

ConsistencyScore = nil
confidence 降级
1.3 InterruptionScore：0–20

输入：

awakeMinutes = stageMinutes[.awake]
awakeEpisodeCount = number of awake segments >= 2 minutes

算法：

penalty = 0.45 * awakeMinutes + 2.5 * awakeEpisodeCount
interruptionScore = clamp(20 - penalty, 0, 20)

例子：

醒 10 分钟，2 次醒来：
penalty = 4.5 + 5 = 9.5
score = 10.5 / 20

醒 2 分钟，0–1 次醒来：
score 接近 19–20
1.4 缺失策略
如果只有 totalSleepMinutes：
    只算 duration，confidence = low

如果有 bedtime 但历史不足：
    不算 consistency，confidence = medium 或 low

如果没有 awake stages：
    interruptionScore = nil

最终分数用可用组件重新归一化：

availableWeight = sum(weights of non-nil components)
finalScore = sum(componentScore) / availableWeight * 100

但 UI 必须显示：

“睡眠分数可信度：中 / 缺少睡眠中断数据”
2. 恢复分数 Recovery Score
结论

恢复分数应该是 个人基线偏离模型，不要用固定人群标准。当前 Vela 已经用 HRV、RHR、睡眠、前一日耗力四部分，权重为 40%、20%、30%、10%。 方向正确，但需要升级为更稳健的 z-score / robust baseline 体系。

输入
HRV_SDNN_today
HRV_SDNN_history: 最近 21–42 天
RHR_today
RHR_history: 最近 21–42 天
SleepScore_lastNight
Strain_yesterday
RespiratoryRate_today
RespiratoryRate_history
BodyTemperature_delta
SpO2

注意：Apple HealthKit 提供的是 heartRateVariabilitySDNN，Vela 现在也是读取 SDNN，不是 RMSSD。 所以算法命名不要写 RMSSD。

核心算法
2.1 Robust baseline

对 HRV 和 RHR 都用最近 21–42 天有效数据。

baselineMedian = median(history)
MAD = median(abs(x_i - baselineMedian))
robustSD = 1.4826 * MAD

如果 robustSD 太小：

HRV robustSD fallback = baselineMedian * 0.12
RHR robustSD fallback = max(2.5, baselineMedian * 0.04)
2.2 HRV component：35%

HRV 用 log transform：

lnHRV_today = ln(max(HRV_today, 1))
lnHRV_baseline = median(ln(HRV_history))
lnHRV_SD = robustSD(ln(HRV_history))

hrvZ = (lnHRV_today - lnHRV_baseline) / lnHRV_SD

组件分：

hrvComponent = clamp(50 + 18 * hrvZ, 0, 100)

特殊处理：

if hrvZ > 2.2 and strainYesterday > 75:
    hrvComponent = min(hrvComponent, 65)
    reason += "HRV unusually high after heavy strain; possible parasympathetic rebound."
2.3 RHR component：25%
rhrZ = (RHR_today - RHR_baseline) / RHR_SD
rhrComponent = clamp(50 - 18 * rhrZ, 0, 100)

解释：

RHR 高于个人基线 → 恢复变差
RHR 低于个人基线 → 恢复变好
2.4 Sleep component：25%
sleepComponent = SleepScore_lastNight

如果无睡眠：

sleepComponent = nil
missingInputs += ["sleepScore"]
2.5 Prior strain component：15%
priorStrainComponent = clamp(100 - Strain_yesterday, 0, 100)

如果昨天耗力很高，恢复被限制。

2.6 Red flag modifiers

在 weighted average 后扣分：

penalty = 0

if bodyTempDelta >= 0.5°C:
    penalty += 8

if respiratoryRateZ >= 1.5:
    penalty += 5

if SpO2 < 94:
    penalty += 8

if RHR_z > 2 and HRV_z < -1:
    penalty += 8

最终：

RecoveryScore = clamp(weightedAverage - penalty, 0, 100)
Confidence
high: HRV + RHR + Sleep + 至少 14 天历史
medium: HRV/RHR/Sleep 中至少 2 个 + 至少 7 天历史
low: 只有 1 个核心输入或历史不足
nil: 无任何核心输入
3. 耗力分数 Strain Score
结论

当前 Vela 的 Strain 用 active energy、exercise minutes、workout intensity 三部分。 问题是当前 workout load 基本来自当天 workouts 的最大 averageHeartRate 映射，这会丢失训练时长、心率区间、多次训练叠加。

建议改成两层：

Daily Strain Score：今天身体承受了多少负荷，0–100
Training Load Status：最近 7 天 vs 过去 28 天，判断负荷是否可持续

Apple 官方 Training Load 也是比较最近 7 天训练强度和时长与之前 28 天，用于判断身体承受的相对负荷。

输入
workouts
heartRateSamples during workouts
activeEnergy
exerciseMinutes
stepCount
userRestingHR
userMaxHR
age
sex
last 28 days dailyLoad
3.1 Workout Load：首选 HR zone / TRIMP
方法 A：心率区间负荷，推荐先实现

计算 HR reserve：

HRR = (HR - restingHR) / (maxHR - restingHR)

心率区间：

Z1: HRR 0.50–0.60, weight = 1
Z2: HRR 0.60–0.70, weight = 2
Z3: HRR 0.70–0.80, weight = 3
Z4: HRR 0.80–0.90, weight = 5
Z5: HRR 0.90–1.00, weight = 8

按 heartRateSamples 的时间间隔积分：

workoutLoad = Σ minutesInZone_i * zoneWeight_i
方法 B：Banister TRIMP，作为高级版本
HRr = (averageHR - restingHR) / (maxHR - restingHR)

male:
TRIMP = durationMinutes * HRr * 0.64 * exp(1.92 * HRr)

female:
TRIMP = durationMinutes * HRr * 0.86 * exp(1.67 * HRr)

如果 biological sex 不可用，用 zone model，不要硬套性别参数。

3.2 Non-workout Load

非训练日也有步数和活动能量：

activityLoad = 0.02 * activeEnergyKcal + 0.0015 * stepCount + 0.5 * exerciseMinutes

最终每日负荷：

dailyLoad = workoutLoad + activityLoad
3.3 Daily Strain Score：0–100

建立个人基线：

baselineDailyLoad = median(last 28 valid dailyLoad)

如果没有历史：

fallbackBaseline = 60

计算：

loadRatio = dailyLoad / baselineDailyLoad
strainScore = 100 * (1 - exp(-0.75 * loadRatio))

限制：

strainScore = clamp(strainScore, 0, 100)

解释：

loadRatio = 0 → 0
loadRatio = 1 → 约 53
loadRatio = 2 → 约 78
loadRatio = 3 → 约 89

这样避免轻微活动就爆到 90，也避免重训后无限上涨。

3.4 Training Load Status
acute7 = sum(dailyLoad last 7 days)
chronic28Equivalent = sum(dailyLoad previous 28 days) / 4
loadRatio = acute7 / chronic28Equivalent

分类：

< 0.60: wellBelow
0.60–0.85: below
0.85–1.20: optimal
1.20–1.50: elevated
> 1.50: highRisk

UI 不要说“受伤预测”，说：

“近期训练负荷显著高于过去 28 天平均水平，建议控制增量。”
4. 压力指数 Physiological Stress Index
结论

不要叫“心理压力指数”，叫 生理压力指数。可穿戴设备用 HR/HRV 做压力检测有研究基础，但泛化能力和标签可靠性仍是研究难点；系统综述也指出压力数据集、标注协议、统计功效和泛化能力都有明显局限。

输入
quietHeartRate_today
quietHeartRate_baseline
HRV_SDNN_today
HRV_SDNN_baseline
respiratoryRate_today
respiratoryRate_baseline
bodyTemperature_delta
sleepDebt
strainScore
workoutWindows

关键规则：

运动期间和运动后 90 分钟内，不计算静息压力。
算法
StressIndex = weightedAverage([
    RHRStress,
    HRVStress,
    RespStress,
    TempStress,
    SleepDebtStress,
    LoadStress
])

权重：

RHRStress: 25%
HRVStress: 25%
RespStress: 15%
TempStress: 10%
SleepDebtStress: 15%
LoadStress: 10%
4.1 RHRStress
rhrZ = (quietHR_today - quietHR_baseline) / quietHR_SD
RHRStress = clamp(50 + 18 * rhrZ, 0, 100)
4.2 HRVStress
hrvZ = (lnHRV_today - lnHRV_baseline) / lnHRV_SD
HRVStress = clamp(50 - 18 * hrvZ, 0, 100)

HRV 低于基线，压力升高。

4.3 RespStress
respZ = (respRate_today - respRate_baseline) / respRate_SD
RespStress = clamp(50 + 15 * respZ, 0, 100)
4.4 TempStress
if abs(tempDelta) < 0.3:
    TempStress = 20
else if abs(tempDelta) < 0.6:
    TempStress = 50
else:
    TempStress = 80
4.5 SleepDebtStress
SleepDebtStress = clamp(100 - SleepScore, 0, 100)
4.6 LoadStress
LoadStress = StrainScore
输出解释
stressIndex < 25: calm
25–50: normal
50–75: elevated
>75: high

UI 文案：

“这是生理压力代理指标，不是心理压力诊断。”
5. 能量电池 Energy Bank
结论

能量电池不是独立医学指标，而是 综合状态条。它应该综合恢复、睡眠、压力、耗力和一天中的消耗。

当前 Vela 已经有 EnergyBankEngine，方向上包含 recovery、sleep、strain、stress、charge efficiency、ATL/CTL、ACWR、体温、睡眠债。 但当前调用时 strainHistory 传的是 nil，导致历史训练负荷没有真正发挥作用。

输入
SleepScore
RecoveryScore
StrainScore
StressIndex
hoursSinceWake
bodyTempDelta
respiratoryRateZ
strainHistory last 42 days
restSessions / mindfulMinutes
算法
5.1 Morning Energy
OvernightStability = 100

扣分：

if bodyTempDelta > 0.5: OvernightStability -= 15
if respiratoryRateZ > 1.5: OvernightStability -= 10
if SpO2 < 94: OvernightStability -= 10

计算：

MorningEnergy = 0.45 * RecoveryScore
              + 0.35 * SleepScore
              + 0.20 * OvernightStability
5.2 Day Drain
strainDrain = 0.35 * StrainScore
stressDrain = 0.25 * StressIndex

时间消耗：

timeDrain = clamp(hoursSinceWake / 16 * 12, 0, 12)

训练负荷额外消耗：

if trainingLoadStatus == elevated:
    loadDrain = 5
else if trainingLoadStatus == highRisk:
    loadDrain = 10
else:
    loadDrain = 0

恢复行为加分：

recharge = min(8, mindfulMinutes * 0.15 + napMinutes * 0.20)

当前能量：

CurrentEnergy = clamp(
    MorningEnergy - strainDrain - stressDrain - timeDrain - loadDrain + recharge,
    0,
    100
)
输出
0–25: depleted
26–50: low
51–75: stable
76–100: strong

UI 文案：

“能量电池是综合状态估计，主要用于安排今日训练和恢复，不代表医学诊断。”
6. 生物年龄 / 健康年龄
结论

这块必须拆成两个指标：

Health Age Trend：仅用可穿戴和 HealthKit 数据，显示趋势，不显示“真实年龄”
Biological Age Estimate：只有实验室 biomarker 足够时才显示年龄估计

当前 Vela 的 BiologicalAgeEngine 用 RHR、VO2 Max、睡眠、步数、手动 biomarker 算分。 最后用 chronologicalAge * (1.25 - overallScore / 200) 得出生物年龄。 这个公式不应继续作为正式生物年龄算法。

6.1 Health Age Trend

输入：

VO2Max
RHR
steps
sleepScore
bodyFatPercentage
leanMassRatio
bloodPressure if available
waist/weight if user enters

每个因子只判断趋势：

positive = +1
neutral = 0
negative = -1

示例：

VO2Max:
    age/sex percentile > 70% → +1
    30–70% → 0
    <30% → -1

RHR:
    below personal baseline and stable → +1
    within baseline → 0
    above baseline by >1 SD → -1

Sleep:
    SleepScore >= 80 → +1
    60–79 → 0
    <60 → -1

Activity:
    steps >= personal median and training load not excessive → +1
    otherwise neutral/negative

输出：

trendScore = average(factorDirection)

分类：

>= 0.35: improving
-0.35 to 0.35: stable
<= -0.35: worsening

UI 文案：

“健康年龄趋势 Beta”

不要显示：

“你的生物年龄是 18 岁”
6.2 Biological Age Estimate：PhenoAge 模式

只有用户录入足够化验指标时才启用。PhenoAge 这类模型依赖临床 biomarker。Levine 等人的 PhenoAge 模型使用 albumin、creatinine、glucose、CRP、lymphocyte percent、MCV、RDW、alkaline phosphatase、WBC 和年龄等变量。

需要的 biomarker：

albumin
creatinine
glucose
CRP
lymphocytePercent
MCV
RDW
alkalinePhosphatase
WBC
chronologicalAge

Agent 可以先实现输入检查：

if missing any required biomarker:
    return nil, confidence = low, reason = "PhenoAge requires lab biomarkers."

如果全部具备，再实现 PhenoAge。注意单位必须严格校验，因为论文中的变量单位不同。Levine 论文表格列出了变量单位和权重。

7. 今日计划建议与限制因子
目标

今日计划不应该由 LLM 自由发挥，而应该由规则引擎先生成结构化结论，然后 LLM 只负责解释。

输入
SleepScore
RecoveryScore
StrainScore
StressIndex
EnergyBank
TrainingLoadStatus
todayTrainingPlan
journalFlags: sick / injured / sore / poor mood
bodyTempDelta
RHR_z
HRV_z
限制因子 Limiter
struct Limiter {
    var id: String
    var severity: Int // 1–3
    var reason: String
    var recommendation: String
}

规则：

低睡眠:
    if SleepScore < 60 or totalSleep < 6h:
        severity = 2

低恢复:
    if RecoveryScore < 45:
        severity = 3
    else if RecoveryScore < 60:
        severity = 2

高压力:
    if StressIndex > 75:
        severity = 3
    else if StressIndex > 60:
        severity = 2

高训练负荷:
    if trainingLoadStatus == highRisk:
        severity = 3
    else if elevated:
        severity = 2

体温异常:
    if bodyTempDelta > 0.6:
        severity = 3

手记疼痛/生病:
    if journalFlags contains sick or injured:
        severity = 3
今日动作决策
if any severity 3 limiter:
    action = rest_or_recovery
    maxIntensity = zone1_or_mobility

else if totalLimiterSeverity >= 4:
    action = reduce
    maxIntensity = zone2
    volumeMultiplier = 0.6

else if RecoveryScore >= 75 and SleepScore >= 75 and StressIndex < 50:
    action = normal_or_push
    volumeMultiplier = 1.0–1.1

else:
    action = normal
    volumeMultiplier = 0.8–1.0

输出：

TodayPlan {
    action: keep / reduce / swap / rest
    recommendedTrainingType
    maxIntensity
    volumeMultiplier
    limiters
    whyThis
}
8. 习惯与体征关联系数
结论

这块不要做因果，只做 lag correlation。UI 上只能说“相关”，不能说“导致”。

输入

习惯特征：

caffeineMg
alcohol
lateMeal
trainingType
trainingLoad
bedtime
screenTime if available
mindfulMinutes
journalTags
protein
calorieDeficit

结果变量：

nextDayHRV
nextDayRHR
nextDaySleepScore
nextDayRecoveryScore
sameNightSleepScore
样本要求
n < 14: 不显示
14 <= n < 28: confidence = low
28 <= n < 60: confidence = medium
n >= 60: confidence = high
相关计算

连续变量：

SpearmanCorrelation(feature_t, outcome_t+1)

二元变量：

pointBiserialCorrelation(binaryHabit_t, outcome_t+1)

简单混杂控制：

partial correlation controlling:
    dayOfWeek
    trainingLoad
    sleepDuration
输出
struct HabitCorrelationInsight {
    var habit: String
    var outcome: String
    var lagDays: Int
    var correlation: Double
    var sampleSize: Int
    var confidence: MetricConfidence
    var direction: String
    var explanation: String
}

阈值：

abs(correlation) < 0.20: 不展示
0.20–0.35: weak
0.35–0.50: moderate
>0.50: strong

文案示例：

“过去 42 天内，晚间咖啡因摄入与次日 HRV 偏低存在中等负相关。样本量 31 天。该结果不代表因果关系。”
9. 数据同步必须同时改

这些算法成立的前提是数据同步可靠。当前 Vela 主要是刷新时查询 HealthKit：sleepSummary、recoveryMetrics、strainSummary、bodyMetrics 都是即时 query。 这会导致 UI、缓存、后台同步之间不一致。

让 Agent 新建：

HealthKitSyncEngine
DailySnapshotBuilder
MetricComputationPipeline

数据流固定为：

HealthKit raw samples
→ HealthKitSyncEngine
→ RawHealthSampleCache / DailyHealthSnapshot
→ MetricComputationPipeline
→ MetricResult
→ Dashboard UI

不要让首页每次直接查 HealthKit 算分。