# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela Architecture Debt — Phase 1: Data Flow Decoupling

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 解除 DashboardSummary 上帝对象、AIContextBuilder 手工映射地狱、评分引擎输入构建耦合、Preview 数据手写——四个相互纠缠的数据流问题，一揽子解决。

**Architecture:** 引入三层解耦：(1) `ScoreEngineFactory` — 每个评分引擎的 Input 构建独立成工厂方法，从 DailyHealthContext 中提取所需数据；(2) `DomainContextBuilder` 协议 — 每个领域（Sleep/Recovery/Strain/Stress/Energy/HealthAge/Body/Workout）提供自己的 AI 上下文映射；(3) `PreviewDataFactory` — 使用真实引擎 + 固定种子输入生成 preview，算法变 → preview 自动变。

**Tech Stack:** Swift, SwiftUI, SwiftData, HealthKit（无新依赖）

**Related docs:** `docs/TECH_ARCHITECTURE.md`, `docs/SCORING_SYSTEM_V0_1.md`

---

## 现状诊断

当前四个问题的根因是同一个：**DashboardSummary 承担了太多职责**。

```
当前数据流（问题所在）:
HealthKit → DailyHealthContext
                │
                ▼
DashboardSummary.healthKit()  ←── 400行静态方法，同时做了:
    ├── 构建 SleepScoreInput → SleepScoreEngine.calculate()
    ├── 构建 RecoveryScoreInput → RecoveryScoreEngine.calculate()
    ├── 构建 StrainScoreInput → StrainScoreEngine.calculate()
    ├── 构建 StressIndexInput → StressIndexEngine.calculate()
    ├── 构建 EnergyBankInput → EnergyBankEngine.calculate()
    ├── 构建 HealthAgeTrendInput → HealthAgeTrendEngine.calculate()
    └── 聚合所有结果 → DashboardSummary 实例
                │
                ▼
AIContextBuilder.build()  ←── 400行方法，逐字段映射 DashboardSummary → LLM JSON
                │
                ▼
DashboardSummary.preview() ←── 130行，手工复制了算法输入值的硬编码
```

改动任何一个评分引擎的 Input 参数，要同步改 3 个地方：`healthKit()` + `preview()` + `AIContextBuilder.build()`。

---

## 目标架构

```
目标数据流:
HealthKit → DailyHealthContext
                │
                ▼
DailySummaryUseCase.loadDashboard()
    ├── ScoreEngineFactory.sleep(from: context, history:) → SleepScoreEngine.calculate()
    ├── ScoreEngineFactory.recovery(from: context, history:) → RecoveryScoreEngine.calculate()
    ├── ScoreEngineFactory.strain(from: context, history:) → StrainScoreEngine.calculate()
    ├── ...（每个工厂方法只管自己的 Input 构建）
    │
    └── DashboardSummary(sleep:, recovery:, strain:, ...) ← 纯数据聚合，无逻辑
                │
                ▼
AIContextBuilder.build(dashboard:)
    ├── SleepContextBuilder.build(dashboard.sleepScore, dashboard.sleepSummary) → [String: String]
    ├── RecoveryContextBuilder.build(dashboard.recovery, dashboard.recoveryMetrics) → [String: String]
    ├── ...（每个 builder 只管自己的领域）
    │
    └── AgentContextEnvelope(sleep:, recovery:, ...) ← 组装各领域结果
                │
                ▼
PreviewDataFactory.makeDashboard()  ←── 调用真实引擎 + 固定输入，不再手写 score 值
```

---

## 文件变更清单

| 操作 | 文件 | 职责 |
|------|------|------|
| **Create** | `Scoring/ScoreEngineFactory.swift` | 每个引擎的 Input 构建工厂方法 |
| **Create** | `AI/Context/DomainContextBuilders.swift` | 每个领域的 AI 上下文 builder |
| **Create** | `Core/Utilities/PreviewDataFactory.swift` | 基于真实引擎的 preview 数据工厂 |
| **Modify** | `Core/Utilities/DashboardSummary.swift` | 删除 `healthKit()` 和 `preview()` 静态方法，只保留 struct 定义 + HealthAge 辅助 + DailyPlan + SnapshotDirective |
| **Modify** | `Core/Utilities/DailySummaryUseCase.swift` | 使用 ScoreEngineFactory 替代 DashboardSummary.healthKit() |
| **Modify** | `AI/Context/AIContextBuilder.swift` | 委托给 DomainContextBuilders |
| **Modify** | `Health/Services/HealthDataRefreshService.swift` | 改用 ScoreEngineFactory |
| **Check** | `AI/Proactive/EveningWikiSyncAgent.swift` | 验证是否直接调用 DashboardSummary.healthKit() |
| **Check** | `Features/SharedComponents/DashboardViewModel.swift` | 验证 preview 使用点 |
| **Check** | `Features/Home/*.swift` | 验证 preview 使用点 |

---

### Task 1: ScoreEngineFactory — 提取每个引擎的 Input 构建

**Files:**
- Create: `VelaApp/Scoring/ScoreEngineFactory.swift`
- Modify: `VelaApp/Core/Utilities/DashboardSummary.swift:126-241` (删除 healthKit() 方法)

**背景：** `DashboardSummary.healthKit()` 是一个 120 行的静态方法，包含了 6 个评分引擎的 Input 构建逻辑 + 评分调用 + 结果聚合。每个引擎的 Input 构建逻辑（例如从 DailyHealthContext 中提取 HRV 并计算 Z-score）应该归到工厂方法里。

- [ ] **Step 1: 创建 ScoreEngineFactory.swift**

```swift
import Foundation

/// Factory that builds each scoring engine's Input from a DailyHealthContext + historical data.
/// This extracts the input-building logic from DashboardSummary.healthKit().
enum ScoreEngineFactory {

    // MARK: - Sleep

    static func sleep(
        from context: DailyHealthContext,
        sleepTarget: Double,
        bedtimeOffsetMinutes: Double?,
        wakeOffsetMinutes: Double?
    ) -> SleepScoreInput {
        SleepScoreInput(
            totalSleepMinutes: context.sleepSummary.map { Double($0.totalSleepMinutes) },
            sleepTargetMinutes: sleepTarget,
            bedtimeOffsetMinutes: bedtimeOffsetMinutes,
            wakeOffsetMinutes: wakeOffsetMinutes,
            remMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
            deepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
            awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
            inBedMinutes: context.sleepSummary?.stageMinutes[.inBed].map { Double($0) }
        )
    }

    // MARK: - Recovery

    static func recovery(
        from context: DailyHealthContext,
        sleepScore: Double?,
        strainScoreYesterday: Double?,
        hrvHistory: [Double],
        rhrHistory: [Double]
    ) -> RecoveryScoreInput {
        RecoveryScoreInput(
            hrvToday: context.recoveryMetrics.hrvMilliseconds,
            hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
            hrvHistory: hrvHistory,
            restingHeartRateToday: context.recoveryMetrics.restingHeartRate,
            restingHeartRateBaseline: context.recoveryBaseline.restingHeartRate,
            rhrHistory: rhrHistory,
            sleepScoreLastNight: context.sleepSummary == nil ? nil : sleepScore,
            strainScoreYesterday: strainScoreYesterday
        )
    }

    // MARK: - Strain

    static func strain(
        from context: DailyHealthContext,
        recoveryScore: Double
    ) -> StrainScoreInput {
        let workoutLoad = context.strainToday.workouts
            .compactMap(\.averageHeartRate)
            .max()
            .map { ScoringMath.clamp(($0 - 90) / 80 * 100) }
        return StrainScoreInput(
            activeEnergyToday: context.strainToday.activeEnergyKilocalories,
            activeEnergyBaseline: context.strainBaselineDaily.activeEnergyKilocalories,
            exerciseMinutesToday: context.strainToday.exerciseMinutes,
            exerciseMinutesBaseline: context.strainBaselineDaily.exerciseMinutes,
            workoutIntensityLoad: workoutLoad ?? (context.strainToday.workouts.isEmpty ? nil : 45),
            recoveryScore: recoveryScore,
            stepCount: context.strainToday.stepCount
        )
    }

    // MARK: - Stress

    static func stress(
        from context: DailyHealthContext,
        sleepScore: Double?,
        strainScore: Double
    ) -> StressIndexInput {
        StressIndexInput(
            heartRateElevationScore: stressHeartRateScore(
                today: context.recoveryMetrics.restingHeartRate,
                baseline: context.recoveryBaseline.restingHeartRate
            ),
            hrvSuppressionScore: stressHRVScore(
                today: context.recoveryMetrics.hrvMilliseconds,
                baseline: context.recoveryBaseline.hrvMilliseconds
            ),
            sleepDebtStressScore: context.sleepSummary == nil ? nil : max(0, 100 - (sleepScore ?? 0)),
            recentStrainStressScore: strainScore
        )
    }

    private static func stressHeartRateScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((today - baseline) / baseline) * 250 + 35)
    }

    private static func stressHRVScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((baseline - today) / baseline) * 250 + 35)
    }

    // MARK: - Energy Bank

    static func energyBank(
        from context: DailyHealthContext,
        recoveryScore: Double,
        sleepScore: Double?,
        strainScore: Double,
        stressIndex: Double,
        strainHistory: [Double]?
    ) -> EnergyBankInput {
        EnergyBankInput(
            recoveryScore: recoveryScore,
            sleepScore: sleepScore,
            strainScore: strainScore,
            stressIndex: stressIndex,
            hrvToday: context.recoveryMetrics.hrvMilliseconds,
            hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
            rhrToday: context.recoveryMetrics.restingHeartRate,
            rhrBaseline: context.recoveryBaseline.restingHeartRate,
            sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
            strainHistory: strainHistory,
            bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 }
        )
    }

    // MARK: - Health Age

    static func healthAge(
        from context: DailyHealthContext,
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult
    ) -> HealthAgeTrendInput {
        var factors: [HealthAgeTrendFactor] = []
        if let vo2 = context.bodyMetrics.vo2Max {
            factors.append(.init(name: "VO2 Max", direction: vo2 >= 40 ? .positive : .neutral))
        }
        if let rhr = context.recoveryMetrics.restingHeartRate {
            factors.append(.init(name: "Resting heart rate", direction: rhr <= 62 ? .positive : .negative))
        }
        if let bf = context.bodyMetrics.bodyFatPercentage {
            factors.append(.init(name: "Body fat", direction: (10...30).contains(bf) ? .positive : .negative))
        }
        if let weight = context.bodyMetrics.weightKilograms, let lean = context.bodyMetrics.leanBodyMassKilograms, weight > 0 {
            let leanRatio = lean / weight
            factors.append(.init(name: "Lean mass ratio", direction: leanRatio >= 0.65 ? .positive : .neutral))
        }
        factors.append(.init(name: "Sleep duration", direction: sleepScore.score >= 70 ? .positive : .negative))
        factors.append(.init(name: "Recovery trend", direction: recovery.score >= 70 ? .positive : (recovery.score < 40 ? .negative : .neutral)))
        factors.append(.init(name: "Activity consistency", direction: strain.confidence == .high ? .positive : .neutral))
        return HealthAgeTrendInput(factors: factors)
    }

    // MARK: - Resolved Sleep Summary

    static func resolvedSleepSummary(
        from context: DailyHealthContext,
        sleepScore: Double
    ) -> SleepSummary {
        let summary = context.sleepSummary ?? SleepSummary(
            date: context.date,
            totalSleepMinutes: 0,
            bedtime: nil,
            wakeTime: nil,
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )
        return SleepSummary(
            date: summary.date,
            totalSleepMinutes: summary.totalSleepMinutes,
            bedtime: summary.bedtime,
            wakeTime: summary.wakeTime,
            stageMinutes: summary.stageMinutes,
            segments: summary.segments,
            sleepScore: sleepScore
        )
    }
}
```

- [ ] **Step 2: Build 验证**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add VelaApp/Scoring/ScoreEngineFactory.swift
git commit -m "feat: extract ScoreEngineFactory from DashboardSummary.healthKit()

Each scoring engine's Input-building logic now lives in its own factory method,
taking DailyHealthContext + historical data as input. This decouples input
construction from result aggregation.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: 重构 DailySummaryUseCase 使用 ScoreEngineFactory

**Files:**
- Modify: `VelaApp/Core/Utilities/DailySummaryUseCase.swift:20-81` (loadDashboard 方法)
- Modify: `VelaApp/Core/Utilities/DailySummaryUseCase.swift:83-173` (backfillSleepHistoryIfNeeded 方法)

**背景：** `loadDashboard()` 目前调用 `DashboardSummary.healthKit()` 这个巨大的静态方法。需要改为调用 `ScoreEngineFactory` 的各个工厂方法，然后在本地组装 `DashboardSummary`。

- [ ] **Step 1: 重写 loadDashboard 中的评分编排逻辑**

将 `DailySummaryUseCase.swift` 第 56-65 行的：

```swift
let dashboard = DashboardSummary.healthKit(
    context: context,
    strainScoreYesterday: yesterdayStrain,
    bedtimeOffsetMinutes: sleepTimingBaseline?.bedtimeOffset,
    wakeOffsetMinutes: sleepTimingBaseline?.wakeOffset,
    hrvHistory: hrvHistory,
    rhrHistory: rhrHistory,
    now: now,
    calendar: calendar
)
```

替换为：

```swift
let sleepTarget = UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60
let effectiveSleepTarget = sleepTarget > 0 ? sleepTarget : 450

let sleepScore = SleepScoreEngine().calculate(
    from: ScoreEngineFactory.sleep(
        from: context,
        sleepTarget: effectiveSleepTarget,
        bedtimeOffsetMinutes: sleepTimingBaseline?.bedtimeOffset,
        wakeOffsetMinutes: sleepTimingBaseline?.wakeOffset
    )
)
let resolvedSleepSummary = ScoreEngineFactory.resolvedSleepSummary(
    from: context,
    sleepScore: sleepScore.score
)

let recovery = RecoveryScoreEngine().calculate(
    from: ScoreEngineFactory.recovery(
        from: context,
        sleepScore: sleepScore.score,
        strainScoreYesterday: yesterdayStrain,
        hrvHistory: hrvHistory,
        rhrHistory: rhrHistory
    )
)

let strain = StrainScoreEngine().calculate(
    from: ScoreEngineFactory.strain(
        from: context,
        recoveryScore: recovery.score
    )
)

let stress = StressIndexEngine().calculate(
    from: ScoreEngineFactory.stress(
        from: context,
        sleepScore: sleepScore.score,
        strainScore: strain.score
    )
)

let energy = EnergyBankEngine().calculate(
    from: ScoreEngineFactory.energyBank(
        from: context,
        recoveryScore: recovery.score,
        sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
        strainScore: strain.score,
        stressIndex: stress.stressIndex,
        strainHistory: nil
    )
)

let healthAge = HealthAgeTrendEngine().calculate(
    from: ScoreEngineFactory.healthAge(
        from: context,
        recovery: recovery,
        sleepScore: sleepScore,
        strain: strain
    )
)

let dashboard = DashboardSummary(
    date: context.date,
    sleepSummary: resolvedSleepSummary,
    sleepScore: sleepScore,
    recovery: recovery,
    recoveryMetrics: context.recoveryMetrics,
    recoveryBaseline: context.recoveryBaseline,
    strain: strain,
    stress: stress,
    energy: energy,
    healthAge: healthAge,
    bodyMetrics: context.bodyMetrics,
    extendedMetrics: context.extendedMetrics,
    workouts: context.strainToday.workouts,
    dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
    source: .healthKit
)
```

注意：`dailyInsight()` 方法目前在 `DashboardSummary` 里作为 private static 方法。需要把它也移到 `DailySummaryUseCase` 或一个独立的工具里。这一步先在 `DailySummaryUseCase` 里加一个 private 方法。

- [ ] **Step 2: 在 DailySummaryUseCase 中添加 dailyInsight 方法**

在 `DailySummaryUseCase` 末尾添加：

```swift
private func dailyInsight(
    recovery: StandardScoreResult,
    sleepScore: StandardScoreResult,
    strain: StrainScoreResult,
    source: DashboardSummary.DataSource
) -> String {
    if source == .healthKit {
        return L10n.t(
            "Updated from Apple Health. Recovery \(Int(recovery.score.rounded())), sleep \(Int(sleepScore.score.rounded())), strain \(Int(strain.score.rounded())).",
            "已读取 Apple 健康数据。恢复 \(Int(recovery.score.rounded()))，睡眠 \(Int(sleepScore.score.rounded()))，负荷 \(Int(strain.score.rounded()))。"
        )
    }
    return L10n.t(
        "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
        "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
    )
}
```

- [ ] **Step 3: 更新 backfillSleepHistoryIfNeeded 方法**

在 backfill 循环中（第 121-128 行），同样的替换模式。将 `DashboardSummary.healthKit(context:...)` 替换为上述编排代码，但 `strainScoreYesterday`、`bedtimeOffsetMinutes`、`wakeOffsetMinutes`、`hrvHistory`、`rhrHistory` 传 nil/空数组。

- [ ] **Step 4: Build 验证**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 5: 更新 HealthDataRefreshService 中的调用点**

`HealthDataRefreshService.swift:19` 调用了 `DashboardSummary.healthKit(context:now:calendar:)`。需要改为同样的编排模式，或者如果 HealthDataRefreshService 只需要 snapshot 数据，可以简化。

先检查 `HealthDataRefreshService.refreshToday()` 的完整内容：

```swift
// 第 19 行改为直接使用 ScoreEngineFactory
let sleepScore = SleepScoreEngine().calculate(
    from: ScoreEngineFactory.sleep(from: context, sleepTarget: 450, bedtimeOffsetMinutes: nil, wakeOffsetMinutes: nil)
)
let recovery = RecoveryScoreEngine().calculate(
    from: ScoreEngineFactory.recovery(from: context, sleepScore: sleepScore.score, strainScoreYesterday: nil, hrvHistory: [], rhrHistory: [])
)
let strain = StrainScoreEngine().calculate(
    from: ScoreEngineFactory.strain(from: context, recoveryScore: recovery.score)
)
let stress = StressIndexEngine().calculate(
    from: ScoreEngineFactory.stress(from: context, sleepScore: sleepScore.score, strainScore: strain.score)
)
let energy = EnergyBankEngine().calculate(
    from: ScoreEngineFactory.energyBank(from: context, recoveryScore: recovery.score, sleepScore: nil, strainScore: strain.score, stressIndex: stress.stressIndex, strainHistory: nil)
)
```

- [ ] **Step 6: Build + Test**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED, tests pass

- [ ] **Step 7: Commit**

```bash
git add VelaApp/Core/Utilities/DailySummaryUseCase.swift VelaApp/Health/Services/HealthDataRefreshService.swift
git commit -m "refactor: DailySummaryUseCase uses ScoreEngineFactory instead of DashboardSummary.healthKit()

Removes the 120-line orchestration dependency on DashboardSummary.healthKit().
Each engine call is now explicitly wired in DailySummaryUseCase, making the
data flow visible and each step independently testable.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: 删除 DashboardSummary.healthKit() 静态方法

**Files:**
- Modify: `VelaApp/Core/Utilities/DashboardSummary.swift`

**背景：** 所有调用方已迁移到 ScoreEngineFactory，`healthKit()` 方法可以安全删除。`preview()` 将在 Task 5 中替换。

- [ ] **Step 1: 删除 healthKit() 和相关 private 方法**

在 `DashboardSummary.swift` 中删除以下内容：
- `static func healthKit(...)` 方法（第 126-241 行）
- `private static func stressHeartRateScore(...)`（第 243-246 行）
- `private static func stressHRVScore(...)`（第 248-251 行）
- `private static func healthAgeFactors(...)`（第 253-278 行）
- `private static func dailyInsight(...)`（第 280-296 行）

保留：
- `DashboardSummary` struct 定义
- `DataSource` enum
- `static func preview(...)`（暂时保留，Task 5 替换）
- `DailyPlanKind`、`DailyPlanAccent`、`DailyPlanLimiterKind` enums
- `DailyPlanLimiter`、`DailyPlanRecommendation` structs
- `DailyPlanEngine` enum（它调用 `dashboard.recovery.score` 等属性，不依赖 `healthKit()`）
- `CoachSnapshotDirective` enum（同上）

- [ ] **Step 2: Build 验证**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add VelaApp/Core/Utilities/DashboardSummary.swift
git commit -m "refactor: remove DashboardSummary.healthKit() static method

All callers now use ScoreEngineFactory + explicit engine wiring.
DashboardSummary is now a pure data aggregation struct with no
orchestration logic.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: DomainContextBuilders — 拆分 AIContextBuilder

**Files:**
- Create: `VelaApp/AI/Context/DomainContextBuilders.swift`
- Modify: `VelaApp/AI/Context/AIContextBuilder.swift`

**背景：** `AIContextBuilder.build()` 是 280 行的方法，逐字段从 DashboardSummary 映射到 AgentContextEnvelope。每个领域的映射逻辑应该独立。这遵循 **Open/Closed Principle**：新增健康指标只需新增一个 DomainContextBuilder，不用修改 AIContextBuilder。

- [ ] **Step 1: 创建 DomainContextBuilders.swift**

```swift
import Foundation

/// Each domain provides its own AI context mapping.
/// Add a new builder when adding a new health domain — AIContextBuilder stays unchanged.
protocol DomainContextBuilder {
    /// Returns a [String: String] dict ready for the LLM context envelope.
    func build(from dashboard: DashboardSummary) -> [String: String]
}

// MARK: - Sleep Context

struct SleepContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        let metrics = dashboard.sleepScore.metrics
        return [
            "sleep_score": dashboard.sleepScore.score.formatted(.number.precision(.fractionLength(0))),
            "duration_minutes": "\(dashboard.sleepSummary.totalSleepMinutes)",
            "band": dashboard.sleepScore.band.rawValue,
            "reason": dashboard.sleepScore.reasons.first ?? "",
            "rem_minutes": "\(dashboard.sleepSummary.stageMinutes[.rem] ?? 0)",
            "deep_minutes": "\(dashboard.sleepSummary.stageMinutes[.deep] ?? 0)",
            "core_minutes": "\(dashboard.sleepSummary.stageMinutes[.core] ?? 0)",
            "awake_minutes": "\(dashboard.sleepSummary.stageMinutes[.awake] ?? 0)",
            "sleep_efficiency_pct": metrics["sleep_efficiency"].map { String(format: "%.1f%%", $0) } ?? "N/A",
            "rem_pct": metrics["rem_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A",
            "deep_pct": metrics["deep_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A"
        ]
    }
}

// MARK: - Recovery Context

struct RecoveryContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        let hrvToday = dashboard.recoveryMetrics.hrvMilliseconds
        let hrvBaseline = dashboard.recoveryBaseline.hrvMilliseconds
        let hrvVsBaselinePct: String = {
            if let t = hrvToday, let b = hrvBaseline, b > 0 {
                return String(format: "%+.1f%%", ((t - b) / b) * 100)
            }
            return "N/A"
        }()
        let hrvZ = dashboard.recovery.metrics["hrv_z_score"].map { String(format: "%.2f", $0) } ?? "N/A"

        return [
            "score": dashboard.recovery.score.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.recovery.band.rawValue,
            "confidence": dashboard.recovery.confidence.rawValue,
            "reason": dashboard.recovery.reasons.first ?? "",
            "hrv_ms": hrvToday.map { "\(Int($0))" } ?? "N/A",
            "rhr_bpm": dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))" } ?? "N/A",
            "respiratory_rate": dashboard.recoveryMetrics.respiratoryRate.map { String(format: "%.1f", $0) } ?? "N/A",
            "hrv_z_score": hrvZ,
            "hrv_vs_baseline_pct": hrvVsBaselinePct
        ]
    }
}

// MARK: - Strain Context

struct StrainContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "score": dashboard.strain.score.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.strain.band.rawValue,
            "target_status": dashboard.strain.targetStatus.rawValue,
            "recommended_range": "\(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)",
            "steps": dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "N/A",
            "active_energy_kcal": dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0))" } ?? "N/A",
            "exercise_minutes": dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))" } ?? "N/A"
        ]
    }
}

// MARK: - Stress Context

struct StressContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "stress_index": dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.stress.band.rawValue,
            "confidence": dashboard.stress.confidence.rawValue,
            "proxy_notice": "Stress is a physiological proxy, not a medical or mental health diagnosis."
        ]
    }
}

// MARK: - Energy Bank Context

struct EnergyBankContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "morning_energy": dashboard.energy.morningEnergy.formatted(.number.precision(.fractionLength(0))),
            "current_energy": dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))),
            "status": dashboard.energy.status.rawValue,
            "charge_efficiency": dashboard.energy.metrics["charge_efficiency"].map { String(format: "%.0f%%", $0 * 100) } ?? "N/A",
            "atl_7day": dashboard.energy.metrics["atl"].map { String(format: "%.0f", $0) } ?? "N/A",
            "ctl_42day": dashboard.energy.metrics["ctl"].map { String(format: "%.0f", $0) } ?? "N/A",
            "tsb_freshness": dashboard.energy.metrics["tsb"].map { String(format: "%+.0f", $0) } ?? "N/A"
        ]
    }
}

// MARK: - Health Age Context

struct HealthAgeContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "trend": dashboard.healthAge.label.rawValue,
            "trend_score": dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2))),
            "beta_notice": "Health Age Trend is beta and does not claim biological age."
        ]
    }
}

// MARK: - Workouts Context Builder

struct WorkoutsContextBuilder {
    func build(from workouts: [WorkoutSummary]) -> [String: String] {
        guard !workouts.isEmpty else {
            return ["note": "No workouts recorded today.", "count": "0"]
        }
        let totalKcal = workouts.compactMap(\.energyKilocalories).reduce(0, +)
        let totalDurationMin = workouts.map { Int($0.end.timeIntervalSince($0.start) / 60) }.reduce(0, +)
        let types = Set(workouts.map(\.activityName)).sorted().joined(separator: ", ")
        let workoutList: [[String: String]] = workouts.map { w in
            var d: [String: String] = [
                "type": w.activityName,
                "duration_min": "\(Int(w.end.timeIntervalSince(w.start) / 60))"
            ]
            if let kcal = w.energyKilocalories { d["calories"] = "\(Int(kcal))" }
            if let hr = w.averageHeartRate { d["avg_hr_bpm"] = "\(Int(hr))" }
            if let dist = w.distanceMeters { d["distance_m"] = String(format: "%.0f", dist) }
            return d
        }
        let listJSON = (try? String(data: JSONEncoder().encode(workoutList), encoding: .utf8)) ?? "[]"
        return [
            "count": "\(workouts.count)",
            "types": types,
            "total_energy_kcal": "\(Int(totalKcal))",
            "total_duration_min": "\(totalDurationMin)",
            "list": listJSON
        ]
    }
}

// MARK: - Extended Metrics Context Builder

struct ExtendedMetricsContextBuilder {
    func build(ext: ExtendedHealthMetrics, body: BodyMetricsSummary) -> [String: String] {
        var d: [String: String] = [:]
        let age = WikiFileService.getAgeFromWiki() ?? ext.age ?? 30
        d["age"] = "\(age)"
        if let sex = ext.biologicalSex { d["biological_sex"] = sex }
        if let h = ext.heightCm { d["height_cm"] = String(format: "%.1f", h) }
        if let bmi = ext.bmi { d["bmi"] = String(format: "%.1f", bmi) }
        if let w = body.weightKilograms { d["weight_kg"] = String(format: "%.1f", w) }
        if let bf = body.bodyFatPercentage { d["body_fat_pct"] = String(format: "%.1f", bf) }
        if let lbm = body.leanBodyMassKilograms { d["lean_body_mass_kg"] = String(format: "%.1f", lbm) }
        if let vo2 = body.vo2Max { d["vo2_max"] = String(format: "%.1f", vo2) }
        if let spo2 = ext.oxygenSaturation { d["spo2_pct"] = String(format: "%.0f", spo2) }
        if let sbp = ext.bloodPressureSystolic { d["blood_pressure_systolic"] = "\(Int(sbp))" }
        if let dbp = ext.bloodPressureDiastolic { d["blood_pressure_diastolic"] = "\(Int(dbp))" }
        if let glucose = ext.bloodGlucose { d["blood_glucose_mgdl"] = String(format: "%.0f", glucose) }
        if let ws = ext.walkingSpeed { d["walking_speed_ms"] = String(format: "%.2f", ws) }
        if let wa = ext.walkingAsymmetry { d["walking_asymmetry_pct"] = String(format: "%.1f", wa) }
        if let temp = ext.bodyTemperature { d["body_temp_c"] = String(format: "%.1f", temp) }
        if let water = ext.waterMl { d["water_ml"] = "\(Int(water))" }
        if let caff = ext.caffeineMg { d["caffeine_mg"] = "\(Int(caff))" }
        if let mindful = ext.mindfulMinutes { d["mindful_minutes"] = "\(Int(mindful))" }
        return d
    }
}
```

- [ ] **Step 2: 重构 AIContextBuilder.build() 使用新的 builders**

将 `AIContextBuilder.swift` 中的 `build()` 方法重写为委托模式：

```swift
func build(
    dashboard: DashboardSummary,
    journalEntries: [JournalContextEntry],
    historicalReports: [GeneratedAIReport],
    userWiki: [String: String],
    weeklyTrends: [String: String] = [:],
    foodLogs: [FoodLogRecord] = [],
    generatedAt: Date = Date()
) -> (envelope: AgentContextEnvelope, metadata: ContextSnapshotMetadata) {

    let envelope = AgentContextEnvelope(
        metadata: AgentContextMetadata(generatedAt: generatedAt, contextWindow: "today"),
        todaySummary: [
            "date": dashboard.date.formatted(date: .numeric, time: .omitted),
            "overall_state": dashboard.recovery.band.rawValue.lowercased(),
            "source": dashboard.source.rawValue,
            "top_reason": dashboard.recovery.reasons.first ?? dashboard.dailyInsight
        ],
        sleep: SleepContextBuilder().build(from: dashboard),
        recovery: RecoveryContextBuilder().build(from: dashboard),
        strain: StrainContextBuilder().build(from: dashboard),
        workouts: WorkoutsContextBuilder().build(from: dashboard.workouts),
        stress: StressContextBuilder().build(from: dashboard),
        energyBank: EnergyBankContextBuilder().build(from: dashboard),
        healthAgeTrend: HealthAgeContextBuilder().build(from: dashboard),
        recentTrends: ["note": "Recent trend calculations are v0.1 placeholders until enough cached history exists."],
        weeklyTrends: weeklyTrends.isEmpty ? ["note": "No weekly trend data available yet."] : weeklyTrends,
        nutrition: buildNutritionDict(foodLogs),
        journal: ["entries": journalEntries.map { "\($0.tags.joined(separator: "|")): \($0.text)" }.joined(separator: "\n")],
        historicalAIReports: ["recent": historicalReports.map { "\($0.title): \($0.markdownContent.prefix(160))" }.joined(separator: "\n")],
        userWiki: userWiki,
        agentInstruction: [
            "role": "Private health data analyst and lifestyle coach",
            "safety": "Do not diagnose. Be cautious with stress and health age trend."
        ],
        extendedMetrics: ExtendedMetricsContextBuilder().build(
            ext: dashboard.extendedMetrics,
            body: dashboard.bodyMetrics
        )
    )

    let contextJSON = (try? String(data: JSONEncoder().encode(envelope), encoding: .utf8)) ?? "{}"
    let hash = ContentHash.hash(contextJSON)
    let metadata = ContextSnapshotMetadata(
        schemaVersion: AIContextBuilder.schemaVersion,
        generatedAt: generatedAt,
        hash: hash,
        includedSections: ["today_summary", "sleep", "recovery", "strain", "workouts", "stress", "energy_bank", "health_age_trend", "nutrition", "journal", "user_wiki", "extended_metrics"],
        redactedFields: []
    )
    return (envelope: envelope, metadata: metadata)
}
```

同样的模式更新 `buildTyped()` 方法。

保留 `buildNutritionDict` private 方法在原文件中（暂不拆，等 Nutrition 模块有自己的 builder）。

- [ ] **Step 3: Build 验证**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add VelaApp/AI/Context/DomainContextBuilders.swift VelaApp/AI/Context/AIContextBuilder.swift
git commit -m "refactor: extract DomainContextBuilders from AIContextBuilder

Each health domain now has its own context builder (SleepContextBuilder,
RecoveryContextBuilder, etc.) implementing DomainContextBuilder protocol.
AIContextBuilder.build() becomes a thin orchestrator that delegates to
per-domain builders. Adding a new health metric no longer requires
modifying the 280-line AIContextBuilder.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: PreviewDataFactory — 用真实引擎替代手写 Preview

**Files:**
- Create: `VelaApp/Core/Utilities/PreviewDataFactory.swift`
- Modify: `VelaApp/Core/Utilities/DashboardSummary.swift` (更新 preview() 方法)

**背景：** `DashboardSummary.preview()` 硬编码了每个评分引擎的输入值和输出值。当引擎算法更新时，preview 数据不会同步更新，导致 UI 开发时看到的数据与真实算法输出不一致。

**方案：** 创建 `PreviewDataFactory`，使用固定的种子输入（模拟一个典型用户的真实数据），调用真实引擎计算。这样算法变 → preview 自动变。

- [ ] **Step 1: 创建 PreviewDataFactory.swift**

```swift
import Foundation

/// Generates preview/demo data using real scoring engines with fixed seed inputs.
/// When engine algorithms change, previews update automatically — no manual sync needed.
enum PreviewDataFactory {

    /// A realistic "healthy user" seed input that produces moderate-to-high scores.
    static func makeDashboard(date: Date = Date()) -> DashboardSummary {
        let sleepSummary = PreviewHealthDataProvider.sleepSummary(for: date)

        // Sleep
        let sleepInput = SleepScoreInput(
            totalSleepMinutes: Double(sleepSummary.totalSleepMinutes),
            sleepTargetMinutes: 450,
            bedtimeOffsetMinutes: 45,
            wakeOffsetMinutes: 20
        )
        let sleepScore = SleepScoreEngine().calculate(from: sleepInput)

        // Recovery — simulate a user with HRV slightly below baseline (mild fatigue)
        let recoveryInput = RecoveryScoreInput(
            hrvToday: 42,
            hrvBaseline: 45,
            hrvHistory: [44, 46, 43, 47, 42, 45, 44],
            restingHeartRateToday: 62,
            restingHeartRateBaseline: 60,
            rhrHistory: [59, 60, 61, 58, 62, 60, 59],
            sleepScoreLastNight: sleepScore.score,
            strainScoreYesterday: 58
        )
        let recovery = RecoveryScoreEngine().calculate(from: recoveryInput)

        // Strain
        let strainInput = StrainScoreInput(
            activeEnergyToday: 420,
            activeEnergyBaseline: 500,
            exerciseMinutesToday: 28,
            exerciseMinutesBaseline: 35,
            workoutIntensityLoad: 42,
            recoveryScore: recovery.score
        )
        let strain = StrainScoreEngine().calculate(from: strainInput)

        // Stress
        let stressInput = StressIndexInput(
            heartRateElevationScore: 38,
            hrvSuppressionScore: 45,
            sleepDebtStressScore: max(0, 100 - sleepScore.score),
            recentStrainStressScore: strain.score
        )
        let stress = StressIndexEngine().calculate(from: stressInput)

        // Energy
        let energyInput = EnergyBankInput(
            recoveryScore: recovery.score,
            sleepScore: sleepScore.score,
            strainScore: strain.score,
            stressIndex: stress.stressIndex,
            hrvToday: 42,
            hrvBaseline: 45,
            rhrToday: 62,
            rhrBaseline: 60,
            sleepHours: 7.2,
            strainHistory: [45, 52, 58, 55, 48, 60, 58],
            bodyTempDelta: 0.0
        )
        let energy = EnergyBankEngine().calculate(from: energyInput)

        // Health Age
        let healthAgeInput = HealthAgeTrendInput(
            factors: [
                .init(name: "VO2 Max", direction: .neutral),
                .init(name: "Resting heart rate", direction: .positive),
                .init(name: "Sleep regularity", direction: .negative),
                .init(name: "Activity consistency", direction: .positive)
            ]
        )
        let healthAge = HealthAgeTrendEngine().calculate(from: healthAgeInput)

        return DashboardSummary(
            date: date,
            sleepSummary: sleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: 42,
                restingHeartRate: 62,
                sleepHeartRate: 58,
                respiratoryRate: 14
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: 45,
                restingHeartRate: 60,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: healthAge,
            bodyMetrics: BodyMetricsSummary(
                vo2Max: 42,
                weightKilograms: 72,
                bodyFatPercentage: 18,
                leanBodyMassKilograms: 59
            ),
            extendedMetrics: ExtendedHealthMetrics(age: 28, biologicalSex: "male", heightCm: 175),
            workouts: [],
            dailyInsight: L10n.t(
                "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
                "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
            ),
            source: .preview
        )
    }
}
```

- [ ] **Step 2: 更新 DashboardSummary.preview() 委托给 PreviewDataFactory**

将 `DashboardSummary.swift` 中的 `static func preview(...)` 改为一行委托：

```swift
static func preview(date: Date = Date()) -> DashboardSummary {
    PreviewDataFactory.makeDashboard(date: date)
}
```

- [ ] **Step 3: Build 验证**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
```
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add VelaApp/Core/Utilities/PreviewDataFactory.swift VelaApp/Core/Utilities/DashboardSummary.swift
git commit -m "feat: add PreviewDataFactory using real engines with seed inputs

DashboardSummary.preview() now delegates to PreviewDataFactory which calls
real scoring engines with fixed seed inputs. When engine algorithms change,
preview data updates automatically — no more manual sync between preview
hardcoded values and engine logic.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: 最终验证 — 全量 Build + Test + 真机冒烟

- [ ] **Step 1: 全量编译**

```bash
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED

- [ ] **Step 2: 运行测试**

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug 2>&1 | tail -15
```
Expected: all tests pass

- [ ] **Step 3: 真机安装冒烟测试**

```bash
DEVICE="00008140-00164DE022C3801C"
xcrun devicectl device install app --device "$DEVICE" \
  "/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app"
```

手动验证：
- [ ] App 启动不崩溃
- [ ] Home 页展示评分（非全 0 / 非全 N/A）
- [ ] Coach 对话框正常，AI 回复引用了正确的评分数据
- [ ] 切换 Today / Fitness / Vitals / Journal tab 正常

- [ ] **Step 4: Final commit (if any fixups)**

---

## Phase 2-4 概要（后续独立计划）

### Phase 2: Infrastructure Foundation
- **依赖注入**: 创建 `ServiceContainer` actor，注册 `HealthKitQueryService`、`DeepSeekProvider`、`AIContextBuilder` 等，消除 `VelaAppState.shared`、`KeychainService.shared` 以外的单例
- **统一错误处理**: 创建 `VelaError` enum + `Result` 包装，在 `HealthKitQueryService`、`DeepSeekProvider` 中替换 `try?` → 返回 `Result`，UI 层展示错误状态

### Phase 3: Agent & Background Systems
- **Agent Tool 自动注册**: `ToolRegistry` 改为 `@Tool` macro / property wrapper 自动发现，将 `WebSearchHelper` 从 `CoachChatPanel.swift` 移到 `AI/Agent/`
- **后台任务实现**: 完成 `BGAppRefreshTask` 和 `BGProcessingTask` 的注册和调度，让 `EveningWikiSyncAgent` 在后台真正执行

### Phase 4: UI & Persistence Cleanup
- **删除旧 UI Shell**: 删除 Bevel-style `VelaBevelHomeStyle` 和 glass tab bar 残留代码，`VelaMinimalShell` 成为唯一 shell
- **持久化版本化**: 给 `DailyHealthSummaryRecord` 加 `schemaVersion` 字段，支持 migration block，考虑 `SupplementalMetric` key-value 表存储扩展指标

---

## Self-Review

**1. Spec coverage:**
- Issue 1 (上帝对象) → Task 1-3: ScoreEngineFactory + 删除 healthKit()
- Issue 3 (手工映射) → Task 4: DomainContextBuilders
- Issue 4 (引擎耦合) → Task 1-2: 工厂方法解耦 Input 构建
- Issue 10 (Preview 手写) → Task 5: PreviewDataFactory

**2. Placeholder scan:** 所有步骤包含具体代码和命令，无 TBD/TODO。

**3. Type consistency:** `ScoreEngineFactory` 的返回类型与各引擎的 `Input` 类型完全对应，`DomainContextBuilder` 协议返回 `[String: String]` 直接匹配 `AgentContextEnvelope` 的字典字段。

---

**Plan complete. Phase 1 共 6 个 Tasks，预计改动 6 个文件（3 个新建，3 个修改）。**

Two execution options:

1. **Subagent-Driven (recommended)** — 每个 Task 一个独立 subagent，Task 之间 review，快迭代
2. **Inline Execution** — 在当前 session 中顺序执行所有 Tasks，batch 推进

Which approach?
