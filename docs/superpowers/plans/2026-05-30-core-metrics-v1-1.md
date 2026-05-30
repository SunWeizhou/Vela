# Core Metrics v1.1 Bugfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore metric component contracts, correct training-load semantics, separate legacy stress inputs, validate PhenoAge units, and prevent beta health-age UI from presenting a biological-age estimate.

**Architecture:** Keep the Core Metrics v1 engine boundaries intact. Add compatibility fields at engine outputs, make strain input assembly asynchronous so workout heart-rate samples reach the engine, and keep fallback behavior explicit. Preserve the existing SwiftUI composition while conditionally replacing biological-age claims with beta trend text.

**Tech Stack:** Swift 6, SwiftUI, HealthKit, SwiftData, XCTest, Xcode simulator tests.

---

### Task 1: Metric component contracts

**Files:**
- Modify: `VelaApp/Scoring/Recovery/RecoveryScoreEngine.swift`
- Modify: `VelaApp/Scoring/Sleep/SleepScoreEngine.swift`
- Modify: `VelaApp/Scoring/Strain/StrainScoreEngine.swift`
- Modify: `VelaApp/Scoring/EnergyBank/EnergyBankEngine.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] Add failing assertions for recovery z-scores, sleep compatibility fields, strain raw fields, and ATL/CTL/TSB/ACWR.
- [ ] Run the focused scoring tests and confirm the new assertions fail because keys are absent.
- [ ] Write the calculated values into `MetricResult.components`.
- [ ] Run the focused scoring tests and confirm the assertions pass.

### Task 2: Strain semantics and HealthKit input

**Files:**
- Modify: `VelaApp/Scoring/ScoreEngineFactory.swift`
- Modify: `VelaApp/Scoring/Strain/StrainScoreEngine.swift`
- Modify: `VelaApp/Core/Utilities/DailySummaryUseCase.swift`
- Modify: `VelaApp/Health/Services/HealthDataRefreshService.swift`
- Modify: `VelaApp/AI/Proactive/BackgroundTaskManager.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`
- Test: `VelaAppTests/HealthFoundationTests.swift`

- [ ] Add failing tests proving samples are passed to workouts, recent suffix history drives acute load, and workout-day activity load is discounted.
- [ ] Run focused tests and confirm failures describe the old empty-sample, prefix-window, and double-counting behavior.
- [ ] Make `ScoreEngineFactory.strain` asynchronous, fetch each workout's heart-rate samples, infer max HR from Wiki or HealthKit age with `220 - age`, and update callers.
- [ ] Use recent suffix windows and a workout-day activity multiplier in `StrainScoreEngine`.
- [ ] Run focused tests and confirm pass.

### Task 3: Stress legacy mode and snapshot compatibility

**Files:**
- Modify: `VelaApp/Scoring/Stress/StressIndexEngine.swift`
- Modify: `VelaApp/Core/Utilities/DailySummaryUseCase.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] Add a failing regression test for historical component scores.
- [ ] Add explicit raw-vitals and legacy-component modes.
- [ ] Use legacy mode when restoring persisted dashboard records.
- [ ] Run focused tests and confirm historical stress is not distorted.

### Task 4: Biological age trust boundary

**Files:**
- Modify: `VelaApp/Scoring/Biology/BiologicalAgeEngine.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift`
- Modify: `VelaApp/Features/Settings/BiologyView.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] Add failing tests for canonical unit conversion and invalid-unit fallback.
- [ ] Add PhenoAge biomarker normalization with strict accepted units.
- [ ] Keep beta engine trend output but hide beta-mode age values and comparisons in both UI entry points.
- [ ] Run focused tests and simulator build.

### Task 5: Daily plan and AI context regressions

**Files:**
- Modify: `VelaApp/Scoring/DailyPlan/DailyPlanBuilder.swift`
- Modify: `VelaAppTests/ScoringEngineTests.swift`
- Modify: `VelaAppTests/ContextBuilderTests.swift`

- [ ] Replace the contradictory sick-flag test with a real limiter-engine assertion for `.rest`.
- [ ] Add AI context assertions that `hrv_z_score`, `tsb_freshness`, and `deep_pct` are not `N/A`.
- [ ] Run focused tests and correct any remaining contract mismatch.

### Task 6: Verification

**Files:**
- Verify all modified files.

- [ ] Run `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=77387550-439D-4817-8DAC-F39370DE17BB' test`.
- [ ] Run `git diff --check`.
- [ ] Review `git status --short` and preserve unrelated user files.
