# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela 3.0 — Training Intelligence 大版本更新文档

> **⚠️ 文档定位**: 本文档是**产品愿景与完整设计蓝图**，不是当前实现状态。文中描述的完整功能（ActiveWorkoutSession、训练中记录、WeeklyBodyReport、TrainingResponseRecord 等）尚未全部落地。
>
> **当前实现状态 (2026-06-02)**: Beta Convergence 阶段已完成。实际已落地：
> - ✅ 训练事实层：StrengthWorkoutRecord 扩展、WorkoutEventRecord、ExerciseDefinitionRecord
> - ✅ 训练分析层：TrainingAnalyticsService、ExerciseLibraryService
> - ✅ 恢复联动层：RecoveryTrainingAdapter
> - ✅ AI 上下文扩展：StrengthTrainingContext 已接入 AIContextBuilder
> - ✅ 计划关联：TrainingPlanLinkingService
> - ✅ 力量训练视图：StrengthWorkoutLogSheetView、StrengthWorkoutDetailView、FitnessActivitySummaryDetailView
> - ❌ 训练中实时记录（ActiveWorkoutSession）—— 尚未实现
> - ❌ PersonalResponseInsight 周报 —— 服务存在但需验证集成状态
> - ❌ TrainingResponseRecord 第二天反应模型 —— 尚未实现
> - ❌ MemoryProposal → Wiki 写入确认流 —— 部分实现
> - ❌ WorkoutTemplateRecord / 模板系统 —— 尚未实现
>
> **实现计划**: 见 `docs/superpowers/plans/2026-06-02-training-intelligence-v3.md`
>
> ---

## 0. 版本定位

本次大版本更新的目标不是简单补几个功能，而是把 Vela 从“健康数据展示 + Coach 聊天 + 初步记录工具”，升级为真正围绕用户训练生活运行的个人健身与恢复智能系统。

当前 Vela 已经具备较好的基础：
- 有 HealthKit 同步、SwiftData 本地持久化、DailyHealthSummaryRecord、评分引擎和 Dashboard。
- 有 StrengthWorkoutRecord，可保存力量训练的动作、器械、组、次数、重量、训练容量。
- 有 Coach Agent、AIContextBuilder、ToolFactory、Wiki/Memory、FoodLog、TrainingPlanRecord 等基础模块。
- 有 Today Plan / Daily Plan / Body Interpreter 等身体状态解释雏形。

但当前最大问题是：各模块仍是“并列存在”，没有形成真正闭环。

本次大版本的目标是打通下面这条主链路：

用户身体状态
→ 今日训练建议
→ 训练中真实记录
→ 训练后总结
→ 次日恢复反馈
→ 个人反应模型
→ 下一次训练自动调整
→ 长期写入 Wiki，形成个人身体理解系统

最终产品应该让一个普通健身用户感觉：
“Vela 不只是告诉我今天恢复几分，而是真的知道我练了什么、练得怎么样、恢复得怎么样、下一次该怎么练。”

---

## 1. 大版本名称

建议版本名称：

Vela 3.0 — Training Intelligence

也可以在 App 内部称为：

训练智能系统
Training Intelligence System
Training-Recovery Loop
Personal Body Intelligence

---

## 2. 核心产品目标

### 2.1 用户视角目标

用户应该可以完成以下完整体验：

1. 早上打开 Vela，看到今日身体状态：
   - 是否适合训练；
   - 适合高强度、中强度、恢复训练还是休息；
   - 主要限制因素是什么：睡眠、HRV、静息心率、训练负荷、局部肌肉疲劳、饮食恢复不足等。

2. 进入训练页，看到今日推荐训练：
   - 如果有训练计划，显示计划中的当天训练；
   - 如果没有计划，根据近期训练、恢复、目标自动建议训练方向；
   - 根据恢复状态自动调整训练容量和强度。

3. 开始训练：
   - 选择训练模板或临时新建训练；
   - 动作自动带出上次表现；
   - 每组可以快速记录重量、次数、RPE/RIR；
   - 支持完成组按钮、组间休息计时；
   - 支持添加/删除动作、复制上一组、快速加减重量。

4. 完成训练后：
   - 显示本次训练总结；
   - 包括总容量、有效组、肌群组数、动作 PR、估算 1RM、训练密度、主观强度；
   - 与上次同类训练对比；
   - 提醒用户补充饮食、睡眠、拉伸或恢复任务。

5. 第二天：
   - Vela 对比训练后的恢复变化；
   - 观察 HRV、静息心率、睡眠、压力、疲劳、主观日志；
   - 形成“用户对某类训练的个人反应”；
   - 例如：腿部高容量训练后，用户第二天 HRV 通常下降 12%，静息心率上升 4 bpm，恢复需要 48 小时。

6. 每周：
   - 生成每周身体报告；
   - 分析训练、睡眠、饮食、压力、咖啡因、熬夜、饮酒、恢复之间的关系；
   - 用户确认后，把稳定规律写入 Wiki，形成长期个人档案。

---

## 3. 当前代码基础与关键现状

### 3.1 已有 StrengthWorkoutRecord

当前项目已经有 StrengthWorkoutRecord、StrengthExerciseLog、StrengthSetLog，可以保存：
- 训练标题；
- 开始时间；
- 时长；
- 备注；
- 动作；
- 器械；
- 每组重量、次数、是否热身；
- 总组数、总次数、总训练容量。

这是本次大版本的基础，不需要推倒重来，应该在现有模型上演进。

### 3.2 当前力量记录的不足

当前 StrengthWorkoutRecord 更像“训练后补录表单”，不是完整的训练中记录系统。缺少：
- 动作库；
- 训练模板；
- 上次表现自动填充；
- 训练中状态；
- 完成组按钮；
- 组间休息计时；
- 有效组判断；
- 肌群映射；
- e1RM；
- PR；
- 局部疲劳；
- 与训练计划的关联；
- 与 DailyHealthSummary 的聚合；
- 与 Coach 默认上下文的整合。

### 3.3 当前 Coach 上下文不足

当前 Coach 有能力通过 tool 查询力量训练历史，但基础 AI Context 默认并不稳定包含最近力量训练摘要。这会导致 Coach 只有在主动调用工具时才知道训练明细。

大版本后，Coach 应该默认知道用户最近训练情况，而不是依赖模型临时想起来调工具。

### 3.4 当前训练计划没有和实际执行闭环

TrainingPlanRecord 能保存计划，但计划与实际训练记录没有强绑定。大版本后，TrainingDay 应能关联真实完成的 WorkoutEvent / StrengthWorkoutRecord，并计算 adherence、计划偏差、实际训练反馈。

---

## 4. 大版本总体架构

本次大版本建议引入四层架构：

### 4.1 训练事实层：Training Fact Layer

负责记录用户真实做了什么。

核心模型建议：

- ExerciseDefinitionRecord
- WorkoutTemplateRecord
- WorkoutTemplateExercise
- ActiveWorkoutSessionState
- StrengthWorkoutRecord 扩展
- WorkoutEventRecord
- MuscleGroupVolumeSummary
- ExercisePerformanceSnapshot

目标：形成统一、结构化、可查询的训练事实。

### 4.2 训练分析层：Training Analytics Layer

负责解释训练数据。

核心能力：
- 总容量；
- 有效组；
- 肌群组数；
- 动作趋势；
- e1RM；
- PR；
- 训练密度；
- 最近 7/14/28 天训练分布；
- 肌群局部疲劳；
- 动作进步/退步；
- 与计划偏差；
- 训练单调性与过载风险。

### 4.3 恢复联动层：Recovery-Training Adaptation Layer

负责把训练事实与身体状态连接。

核心能力：
- 根据恢复分数调整今日容量；
- 根据 HRV/RHR/睡眠判断是否适合高强度；
- 根据肌群最近训练量判断局部疲劳；
- 根据训练后第二天恢复变化形成个人反应模型；
- 根据个人反应模型调整下一次训练建议。

### 4.4 个人身体理解层：Personal Body Intelligence Layer

负责把长期规律沉淀为用户档案。

核心能力：
- 周报；
- 饮食-恢复相关分析；
- 睡眠-训练表现相关分析；
- 咖啡因/压力/熬夜/饮酒/训练表现关联；
- 用户确认后写入 Wiki；
- Coach 后续回答默认引用这些长期规律。

---

## 5. 训练事实层详细设计

### 5.1 ExerciseDefinitionRecord：动作库

新增 SwiftData 模型：

```swift
@Model
final class ExerciseDefinitionRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var aliasesJSON: String
    var primaryMuscleGroup: String
    var secondaryMuscleGroupsJSON: String
    var equipment: String
    var movementPattern: String
    var isCustom: Bool
    var createdAt: Date
    var updatedAt: Date
}

字段说明：

name：动作标准名，例如 Bench Press / 杠铃卧推。
aliasesJSON：别名，例如 “卧推”、“bench”、“barbell bench”。
primaryMuscleGroup：主肌群，例如 chest。
secondaryMuscleGroupsJSON：辅助肌群，例如 triceps, front_delts。
equipment：barbell / dumbbell / cable / machine / bodyweight / kettlebell / other。
movementPattern：push / pull / squat / hinge / lunge / carry / isolation / core。
isCustom：用户自定义动作。
createdAt / updatedAt。

需要提供默认动作库种子数据，至少覆盖：

胸：

杠铃卧推
哑铃卧推
上斜卧推
双杠臂屈伸
绳索夹胸
器械推胸

背：

引体向上
高位下拉
杠铃划船
坐姿划船
单臂哑铃划船
硬拉

腿：

深蹲
腿举
罗马尼亚硬拉
腿屈伸
腿弯举
保加利亚分腿蹲
臀桥 / 臀推

肩：

推举
哑铃侧平举
俯身飞鸟
面拉
阿诺德推举

手臂：

杠铃弯举
哑铃弯举
绳索下压
窄距卧推
臂屈伸

核心：

卷腹
悬垂举腿
平板支撑
Pallof Press

动作库要支持搜索、选择、自定义新增。

5.2 WorkoutTemplateRecord：训练模板

新增 SwiftData 模型：

@Model
final class WorkoutTemplateRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var goal: String
    var notes: String
    var exercisesJSON: String
    var estimatedDurationMinutes: Int
    var createdAt: Date
    var updatedAt: Date
    var lastUsedAt: Date?
}

模板中的每个动作可以用 Codable struct：

struct WorkoutTemplateExercise: Codable, Hashable, Identifiable {
    var id: UUID
    var exerciseDefinitionId: UUID?
    var name: String
    var targetSets: Int
    var targetReps: String
    var targetRPE: Double?
    var restSeconds: Int
    var notes: String?
}

内置模板建议：

Push Day
Pull Day
Leg Day
Upper Body
Lower Body
Full Body
Chest & Triceps
Back & Biceps
Shoulders
自定义模板

模板应该支持：

从历史训练生成模板；
复制模板；
编辑模板；
从模板开始训练；
Coach 创建训练计划时也可以生成模板。
5.3 ActiveWorkoutSession：训练中状态

训练中记录不一定要直接建 SwiftData 模型，可以先用 ObservableObject / StateObject 管理，再在完成时落库。

核心状态：

final class ActiveWorkoutSessionViewModel: ObservableObject {
    @Published var title: String
    @Published var startedAt: Date
    @Published var elapsedSeconds: Int
    @Published var exercises: [ActiveExercise]
    @Published var currentRestTimer: RestTimerState?
    @Published var notes: String
}

动作状态：

struct ActiveExercise: Identifiable, Hashable {
    var id: UUID
    var exerciseDefinitionId: UUID?
    var name: String
    var equipment: String
    var primaryMuscleGroup: String?
    var sets: [ActiveSet]
}

组状态：

struct ActiveSet: Identifiable, Hashable {
    var id: UUID
    var repetitions: Int
    var weightKilograms: Double
    var rpe: Double?
    var rir: Double?
    var isWarmup: Bool
    var isCompleted: Bool
    var completedAt: Date?
}

休息计时：

struct RestTimerState: Hashable {
    var startedAt: Date
    var durationSeconds: Int
    var exerciseName: String
    var setNumber: Int
}

训练中 UI 应支持：

开始训练；
暂停/结束训练；
添加动作；
搜索动作；
每组完成按钮；
完成后自动开始休息计时；
复制上一组重量和次数；
重量快速 +2.5 / -2.5；
次数快速 +1 / -1；
RPE/RIR 可选输入；
热身组标记；
删除组；
添加组；
完成训练；
放弃训练时二次确认。
5.4 StrengthWorkoutRecord 扩展

现有 StrengthWorkoutRecord 不应被破坏，但建议扩展字段或通过 Codable JSON 扩展：

linkedWorkoutEventId
sourceTemplateId
planDayId
perceivedExertion / sessionRPE
totalEffectiveSets
muscleGroupSetsJSON
personalRecordsJSON
estimatedOneRepMaxJSON
trainingDensity
completedAt

如果 SwiftData migration 风险较高，可以优先通过 JSON 字段做兼容扩展，避免频繁破坏已有用户数据。

5.5 WorkoutEventRecord：统一训练事件层

新增模型：

@Model
final class WorkoutEventRecord {
    @Attribute(.unique) var id: UUID
    var source: String
    var startedAt: Date
    var endedAt: Date
    var dayIdentifier: String
    var activityType: String
    var title: String
    var durationMinutes: Double
    var energyKilocalories: Double?
    var averageHeartRate: Double?
    var rpe: Double?
    var linkedStrengthWorkoutId: UUID?
    var linkedHealthKitWorkoutId: UUID?
    var linkedTrainingPlanDayId: UUID?
    var createdAt: Date
    var updatedAt: Date
}

source:

healthKit
manual
strengthLog
imported

目标：

HealthKit workout、手动活动、力量训练都先成为 WorkoutEventRecord；
DailyHealthSummary 由 WorkoutAggregationService 统一聚合；
Coach 和分析模块优先查询 WorkoutEventRecord，而不是直接散查多种来源。
6. 训练分析层详细设计
6.1 TrainingAnalyticsService

新增服务：

struct TrainingAnalyticsService {
    func summarizeWorkout(_ workout: StrengthWorkoutRecord, exerciseLibrary: [ExerciseDefinitionRecord]) -> StrengthWorkoutAnalysis
    func buildRecentTrainingSummary(days: Int, modelContext: ModelContext) throws -> RecentTrainingSummary
    func computeExerciseProgress(exerciseName: String, modelContext: ModelContext) throws -> ExerciseProgressSummary
    func detectPersonalRecords(workout: StrengthWorkoutRecord, history: [StrengthWorkoutRecord]) -> [PersonalRecord]
}

核心输出：

struct StrengthWorkoutAnalysis: Codable, Hashable {
    var totalVolumeKg: Double
    var totalSets: Int
    var effectiveSets: Int
    var totalReps: Int
    var muscleGroupSets: [String: Int]
    var muscleGroupVolume: [String: Double]
    var estimatedOneRepMaxByExercise: [String: Double]
    var personalRecords: [PersonalRecord]
    var densityKgPerMinute: Double
    var summaryText: String
}
6.2 有效组判断

有效组定义建议：

非热身组
且 repetitions >= 3
且 weight > 0 或 bodyweight 动作 repetitions 达到阈值
且 RPE >= 6 或 RIR <= 4

如果没有 RPE/RIR，就用非热身工作组作为默认有效组。

6.3 e1RM 估算

支持 Epley 公式：

e1RM = weight * (1 + reps / 30)

只对：

reps 在 1-12 范围内；
非热身组；
weight > 0；
力量动作；
进行计算。

每个动作取本次最高 e1RM。

6.4 PR 判断

PR 类型：

最大重量 PR；
最大次数 PR；
最大 e1RM PR；
最大容量 PR；
单次训练动作总容量 PR。

PR 需要和历史同名动作比较。

6.5 肌群组数

通过 ExerciseDefinitionRecord 映射：

primary muscle group 计 1.0 set；
secondary muscle group 可计 0.5 set；
也可以第一版只统计主肌群。

输出：

chest
back
quads
hamstrings
glutes
shoulders
biceps
triceps
core
calves
full_body / cardio / other
6.6 训练总结 UI

完成训练后展示：

本次训练名称；
时长；
总容量；
总组数；
有效组；
总次数；
肌群分布；
PR；
e1RM；
和上次同模板/同动作比较；
Coach 建议：
今天训练偏重哪些肌群；
明天是否需要恢复；
饮食建议；
睡眠建议；
下次训练建议。
7. DailyHealthSummary 与训练闭环
7.1 StrengthWorkout 保存后同步 DailyHealthSummary

当 StrengthWorkoutRecord 保存完成后，需要：

创建或更新对应 WorkoutEventRecord。
找到当天 DailyHealthSummaryRecord。
重新聚合当天所有 WorkoutEventRecord。
更新：
workoutCount
workoutTypes
workoutDuration
activeMinutes
activeCalories 如果有估算
workoutLoad
dailyLoad
trainingLoadRatio
strainScore
触发 Dashboard refresh 或 local data changed。

不要在 UI 层直接手写 DailyHealthSummary 字段。应该由 service 统一做。

7.2 WorkoutAggregationService

新增服务：

@MainActor
final class WorkoutAggregationService {
    func upsertWorkoutEvent(from strengthWorkout: StrengthWorkoutRecord, modelContext: ModelContext) throws
    func aggregateDay(date: Date, modelContext: ModelContext) throws
    func rebuildRecentDays(days: Int, modelContext: ModelContext) throws
}
7.3 避免 HealthKit 同步覆盖手动记录

HealthKit 同步时，DailyHealthSummaryRecord.apply(snapshot:) 需要继续保留 manual / strengthLog 来源的 WorkoutEventRecord，不要只依赖 workoutsData 中 source == manual 的老逻辑。

建议长期废弃直接存在 DailyHealthSummaryRecord.workoutsData 里的手动 workout 方案，改为统一从 WorkoutEventRecord 聚合。

8. AI Context 扩展
8.1 新增 StrengthTrainingContext

扩展 TypedContextSchema：

struct StrengthTrainingContext: Codable, Hashable {
    var sessions7d: Int
    var sessions14d: Int
    var hardSets7d: Int
    var hardSets14d: Int
    var volume7dKg: Double
    var volume14dKg: Double
    var muscleGroupSets7d: [String: Int]
    var muscleGroupSets14d: [String: Int]
    var lastWorkoutSummary: String?
    var recentPRs: [String]
    var exercisesProgress: [ExerciseProgressSummary]
    var localFatigue: [String: LocalMuscleFatigue]
}
8.2 Coach 默认上下文必须包含

当用户问：

今天练什么？
我最近练得怎么样？
为什么今天建议休息？
下次胸怎么练？
我最近是不是练太多了？
为什么恢复差？

Coach 不应该必须调 tool 才知道训练记录。基础 context 要直接有最近力量训练摘要。

8.3 StrengthWorkoutHistoryTool 保留

Tool 用于更深查询，比如：

查最近 20 次卧推；
查过去 3 个月腿部容量；
查所有 PR；
查某个动作历史。

默认 context 管“概览”，tool 管“深挖”。

9. 恢复-训练联动详细设计
9.1 RecoveryAdjustedTrainingRecommendation

新增引擎：

struct RecoveryTrainingAdapter {
    func adapt(
        plannedWorkout: PlannedWorkout?,
        recovery: MetricResult,
        sleep: MetricResult,
        strain: MetricResult,
        energy: EnergyBankSummary,
        recentTraining: RecentTrainingSummary,
        localFatigue: [String: LocalMuscleFatigue],
        wiki: [String: String]
    ) -> TrainingAdaptationRecommendation
}

输出：

struct TrainingAdaptationRecommendation: Codable, Hashable {
    var readinessLevel: String
    var shouldTrain: Bool
    var recommendedIntensity: String
    var volumeMultiplier: Double
    var suggestedFocus: String
    var avoidMuscleGroups: [String]
    var preferredMuscleGroups: [String]
    var reasons: [String]
    var modifiedWorkoutDescription: String
}
9.2 恢复分数调整容量

建议第一版规则：

recovery >= 80 且 sleep >= 80 且 HRV 正常：
  volumeMultiplier = 1.0 - 1.15
  可高强度

recovery 60-79：
  volumeMultiplier = 0.85 - 1.0
  正常训练，避免极限组

recovery 40-59：
  volumeMultiplier = 0.5 - 0.75
  降低容量，保留技术练习或轻量泵感

recovery < 40：
  volumeMultiplier = 0 - 0.4
  建议休息、散步、拉伸、灵活性训练
9.3 睡眠与 HRV 高强度判断

高强度训练需要满足：

sleepScore >= 75
recoveryScore >= 65
HRV 不显著低于个人基线
RHR 不显著高于个人基线
TSB 不深度为负
目标肌群局部疲劳不高

如果不满足，则建议：

降低重量；
减少有效组；
避免力竭；
改成技术训练；
改练低疲劳肌群；
改成主动恢复。
9.4 局部肌群疲劳

新增 LocalMuscleFatigue：

struct LocalMuscleFatigue: Codable, Hashable {
    var muscleGroup: String
    var setsLast48h: Int
    var setsLast7d: Int
    var volumeLast7d: Double
    var fatigueLevel: String
    var recommendation: String
}

第一版规则：

过去 48 小时某肌群有效组 >= 8：
  局部疲劳 high，不建议继续大容量训练

过去 7 天某肌群有效组 >= 18：
  周容量偏高，谨慎增加

过去 7 天某肌群有效组 8-16：
  正常增肌区间

过去 7 天某肌群有效组 < 6：
  训练刺激不足，可优先安排
9.5 训练后第二天反应模型

新增模型：

@Model
final class TrainingResponseRecord {
    @Attribute(.unique) var id: UUID
    var workoutId: UUID
    var date: Date
    var nextDayDate: Date
    var primaryMuscleGroupsJSON: String
    var totalEffectiveSets: Int
    var totalVolumeKg: Double
    var sessionRPE: Double?
    var nextDayRecoveryDelta: Double?
    var nextDayHRVDelta: Double?
    var nextDayRHRDelta: Double?
    var nextDaySleepScore: Double?
    var subjectiveTagsJSON: String
    var createdAt: Date
}

逻辑：

训练完成当天先保存 workout。
第二天有 DailyHealthSummary 后，生成 TrainingResponseRecord。
长期统计某类训练对用户恢复的影响。
让 Coach 能说出类似：
“你过去 4 次腿部高容量训练后，第二天恢复平均下降 9 分，所以今天不建议连续腿部高容量。”
10. 个人身体理解系统
10.1 WeeklyBodyReport

新增每周报告生成能力：

struct WeeklyBodyReport {
    var weekStart: Date
    var weekEnd: Date
    var trainingSummary: RecentTrainingSummary
    var recoverySummary: RecoveryWeeklySummary
    var sleepSummary: SleepWeeklySummary
    var nutritionSummary: NutritionWeeklySummary
    var correlations: [BodyCorrelationInsight]
    var recommendations: [String]
    var proposedWikiMemories: [MemoryProposal]
}
10.2 相关分析维度

第一版至少做以下关联：

训练 → 恢复：

高容量训练后第二天恢复变化；
高强度训练后睡眠变化；
某肌群训练后局部疲劳持续时间。

睡眠 → 训练表现：

睡眠分数低时训练容量是否下降；
睡眠不足时 RPE 是否升高；
入睡时间晚是否影响第二天训练。

饮食 → 恢复：

蛋白摄入不足与恢复下降；
训练日热量不足与次日疲劳；
晚餐过晚/大餐与睡眠质量。

咖啡因/酒精/压力/熬夜：

咖啡因过晚与睡眠；
酒精与 HRV/RHR；
压力日志与恢复；
熬夜与训练表现。
10.3 用户确认后写入 Wiki

不要自动把所有推断写入 Wiki。应该创建 MemoryProposal：

Observation:
过去 4 周中，用户在 23:30 后入睡的夜晚，第二天恢复评分平均低 8 分。

Evidence:
基于 12 个夜晚的睡眠与恢复记录。

Confidence:
0.72

Target:
sleep.md 或 observations.md

用户接受后才写入长期 Wiki。

11. UI 更新范围
11.1 Training Tab 重构

训练页建议拆分为：

今日训练建议卡片
今日适合训练吗？
推荐训练类型；
容量调整；
避免训练的肌群；
为什么。
开始训练入口
从模板开始；
空白训练；
继续未完成训练；
最近模板。
训练历史
Apple Health workouts；
Strength workouts；
手动活动；
统一展示 WorkoutEvent。
肌群周容量
过去 7 天每个肌群有效组数；
颜色标记：不足 / 适中 / 偏高。
动作进步
主要动作 e1RM；
最近 PR；
最近退步动作。
11.2 Active Workout UI

一个独立训练中页面：

顶部：
训练名称；
已训练时间；
完成按钮；
更多菜单。
中部：
动作列表；
每个动作卡片显示动作名、肌群、上次表现；
每组显示重量、次数、RPE/RIR、完成按钮。
底部：
添加动作；
休息计时；
快速保存。
11.3 Workout Summary UI

训练完成页：

总览：
时长；
总容量；
有效组；
肌群组数；
PR 数量。
分析：
肌群分布；
动作表现；
与上次比较。
建议：
恢复建议；
饮食建议；
下次训练建议。
12. 工程约束
12.1 不破坏现有功能

必须保留：

当前 Dashboard；
HealthKit 同步；
Coach 聊天；
Wiki；
FoodLog；
TrainingPlan；
Trust Center；
Data Coverage；
现有 StrengthWorkoutRecord 历史数据。
12.2 SwiftData migration 要谨慎

如果新增字段可能导致迁移问题，优先采用：

新增模型；
JSON 字段；
可选字段；
向后兼容初始化。

不要粗暴删除或重命名已有模型字段。

12.3 Local-first

所有训练记录、分析、Wiki、报告默认本地保存。

AI 调用只能发送必要结构化摘要，不能发送原始 HealthKit sample。

12.4 不做伪功能

如果某个功能没有真实数据支撑，不要只做 UI 假展示。

例如：

肌群疲劳必须来自 StrengthWorkoutRecord / ExerciseDefinition；
e1RM 必须来自真实组数据；
PR 必须和历史记录比较；
训练计划完成度必须和真实 WorkoutEvent 关联。
12.5 错误处理

所有保存动作必须：

捕获 SwiftData 保存错误；
显示用户可理解错误；
不造成训练记录丢失；
训练中状态最好支持临时草稿保存。
13. 测试要求

至少补充以下测试：

13.1 TrainingAnalyticsServiceTests
计算总容量；
热身组不计入有效容量；
有效组计算；
肌群组数计算；
e1RM 计算；
PR 检测；
空训练不崩溃。
13.2 WorkoutAggregationServiceTests
StrengthWorkoutRecord 保存后生成 WorkoutEventRecord；
聚合当天 workoutCount；
HealthKit + manual + strengthLog 不互相覆盖；
重复保存不产生重复事件。
13.3 AIContextBuilderTests
context 包含 strength_training；
最近力量训练摘要包含容量、肌群组数、最近 PR；
没有力量训练时 context 不崩溃。
13.4 RecoveryTrainingAdapterTests
低恢复降低 volumeMultiplier；
高恢复允许正常训练；
目标肌群 48 小时训练过多时建议避开；
睡眠差时不建议高强度。
13.5 TrainingPlanLinkTests
TrainingDay 可以关联 WorkoutEvent；
完成训练后更新计划完成状态；
实际训练和计划偏差可计算。
14. 验收标准

大版本完成后，必须满足以下验收标准：

用户可以从训练页开始一次力量训练。
用户可以选择动作、记录重量、次数、RPE/RIR、完成组。
App 能自动带出该动作上次表现。
完成训练后能显示训练总结。
训练总结包含容量、有效组、肌群组数、e1RM、PR。
StrengthWorkoutRecord 保存后，DailyHealthSummary 能感知当天训练。
Dashboard / Training Tab 的训练历史和耗力数据能反映力量训练。
Coach 默认知道最近力量训练摘要。
Coach 能根据恢复、睡眠、HRV、近期肌群训练量给出今日训练调整。
有训练计划时，实际训练可以关联到计划日。
第二天能基于恢复变化生成训练反应记录。
每周报告能分析训练、睡眠、饮食、恢复之间的关系。
稳定洞察通过 MemoryProposal 由用户确认后写入 Wiki。
所有新增核心服务有测试。
App 能正常 build，核心测试通过。
不破坏现有 HealthKit、Dashboard、Coach、FoodLog、Wiki 功能。
15. 推荐实现顺序
Phase 1：稳定地基
整理 SettingsView / VelaSettingsView，避免重复设置页和编译结构问题。
修复 Onboarding：连接 Apple 健康按钮必须真正请求 HealthKit 权限。
新增 HealthSignalCoverageService，统一权限、样本数、新鲜度、置信度。
确保现有 App 可以 clean build。
Phase 2：训练事实层
新增 ExerciseDefinitionRecord。
新增默认动作库种子。
新增 WorkoutTemplateRecord。
新增 WorkoutEventRecord。
新增 WorkoutAggregationService。
StrengthWorkoutRecord 保存后同步 WorkoutEventRecord 和 DailyHealthSummary。
Phase 3：训练中记录体验
新增 ActiveWorkoutSessionViewModel。
新增 ActiveWorkoutView。
支持模板开始训练。
支持动作搜索、添加动作、记录组、完成组、休息计时。
支持上次表现自动填充。
支持训练草稿或未完成训练保护。
完成训练后保存 StrengthWorkoutRecord。
Phase 4：训练分析
新增 TrainingAnalyticsService。
实现容量、有效组、肌群组数、e1RM、PR。
新增 WorkoutSummaryView。
训练页展示肌群周容量、动作进步、最近 PR。
Phase 5：Coach Context 与恢复联动
新增 StrengthTrainingContext。
扩展 AIContextBuilder。
新增 RecoveryTrainingAdapter。
今日训练建议结合恢复、睡眠、HRV、TSB、局部肌群疲劳。
Coach 默认引用最近训练事实。
Phase 6：计划闭环与个人反应模型
TrainingDay 关联 WorkoutEvent。
训练完成后更新计划完成状态。
新增 TrainingResponseRecord。
第二天生成训练反应记录。
长期统计不同训练对恢复的影响。
Phase 7：个人身体理解系统
新增 WeeklyBodyReport。
实现训练-恢复、睡眠-表现、饮食-恢复、咖啡因/压力/熬夜/饮酒关联。
生成 MemoryProposal。
用户确认后写入 Wiki。
Trust Center 能看到相关 Agent/分析记录。
16. 最终目标

本次大版本完成后，Vela 应该具备以下核心差异化能力：

它不是只展示 Apple Health 数据。
它不是只让用户和 Coach 聊天。
它不是只记录训练。

它应该能理解：

用户今天身体是否适合训练；
用户最近练了哪些动作；
哪些肌群已经疲劳；
哪些动作正在进步；
哪类训练会让用户恢复下降；
睡眠、饮食、压力如何影响训练表现；
下一次训练应该如何调整；
哪些长期规律值得写入个人 Wiki。

这才是 Vela 3.0 的目标。