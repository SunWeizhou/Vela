# Apple Xunji Workout Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Apple Watch workouts the canonical training record while allowing Xunji strength logs to enrich matching Apple strength workouts.

**Architecture:** Keep the existing `WorkoutEventRecord` + `StrengthWorkoutRecord` model. Add a single matching policy in `WorkoutAggregationService`, then use it from both HealthKit upsert and Xunji import so either sync order produces the same canonical row.

**Tech Stack:** Swift 6, SwiftData, XCTest, existing Vela training services.

---

### Task 1: Add Regression Tests For Match Boundaries

**Files:**
- Modify: `VelaAppTests/WorkoutAggregationTests.swift`

- [ ] **Step 1: Add a test proving Xunji does not merge into non-strength Apple workouts**

Add a test that inserts a HealthKit running event, imports an overlapping Xunji strength workout, and asserts two events remain.

- [ ] **Step 2: Add a test proving close starts without overlap do not merge**

Add a test that inserts an Apple strength event from 19:00-19:20, imports Xunji from 19:15-20:15, and asserts two events remain because overlap is too weak.

- [ ] **Step 3: Add a test proving later Apple sync upgrades Xunji-only**

Import Xunji first, then call `upsertHealthKitWorkoutEvents` with an overlapping Apple strength workout. Assert one event with source `healthKit+xunji`, Apple metrics, and Xunji title.

- [ ] **Step 4: Run the focused tests**

Run:

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/WorkoutAggregationTests
```

Expected: newly added boundary tests fail before implementation.

### Task 2: Centralize Workout Matching

**Files:**
- Modify: `VelaApp/Health/Services/WorkoutAggregationService.swift`

- [ ] **Step 1: Add a merge candidate API for Xunji**

Expose an internal method that takes a `StrengthWorkoutRecord` and event list, returning the best `WorkoutEventRecord` only when confidence is high.

- [ ] **Step 2: Score by strength compatibility and overlap**

Require Apple candidate source to be HealthKit or an Apple-linked event, require strength-compatible activity, require overlap ratio >= 0.50, and use start/end closeness as secondary scoring.

- [ ] **Step 3: Reuse the same policy for HealthKit backfill**

Update `findMergeCandidate(for:)` and `eventRepresentsSameRealWorkout` to use the same overlap-first policy, preventing start-time-only false positives.

- [ ] **Step 4: Keep Apple metrics authoritative**

When a merged event has `linkedHealthKitWorkoutId`, never overwrite Apple start/end/energy/average heart rate from Xunji.

### Task 3: Use Matching Policy From Xunji Import

**Files:**
- Modify: `VelaApp/TrainingIntelligence/Services/TrainingAnalyticsService.swift`

- [ ] **Step 1: Replace start-time-only matching**

Replace the current `abs(ev.startedAt - workout.startedAt) <= 30m` match with `WorkoutAggregationService.shared.findMergeCandidate(for:workout, in:events, calendar:)`.

- [ ] **Step 2: Preserve Xunji-only rows**

If no Apple strength candidate matches, create or update a source `xunji` event linked to the strength workout. Do not add estimated Apple metrics.

- [ ] **Step 3: Preserve mirror idempotency**

Keep `XunjiWorkoutMirrorRecord.externalID` as the upsert key and update its linked workout/event IDs after merge or xunji-only creation.

### Task 4: Verify Aggregation And Device Build

**Files:**
- Test: `VelaAppTests/WorkoutAggregationTests.swift`

- [ ] **Step 1: Run focused tests**

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/WorkoutAggregationTests
```

- [ ] **Step 2: Run full tests**

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

- [ ] **Step 3: Build for the connected iPhone**

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela -sdk iphoneos -configuration Debug -destination 'platform=iOS,id=00008140-00164DE022C3801C' -allowProvisioningUpdates build
```

- [ ] **Step 4: Install the app**

```bash
xcrun devicectl device install app --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA /Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app
```
