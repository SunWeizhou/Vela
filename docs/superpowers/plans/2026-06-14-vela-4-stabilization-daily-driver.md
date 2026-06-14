# Vela 4.0 Stabilization Daily Driver Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the current Vela 4.0 advanced internal build into a reliable daily-driver that produces one consistent training decision, launches an executable workout, saves data atomically, and remains responsive and recoverable over long-term use.

**Architecture:** Preserve the existing local-first architecture, but make `ActiveStatusSettings`, `BodyStateKernel`, `TrainingDecisionKernel`, `DailyOperatingPlanRecord`, and `WorkoutSaveCoordinator` the only production path for daily training decisions and workout persistence. Move synchronization and retention work out of page lifecycle hooks, introduce bounded reads and versioned persistence recovery, then verify the complete morning-to-next-day loop with integration and performance tests.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, HealthKit, XCTest, `xcodebuild`, signposts/XCTest metrics.

## Execution Status — 2026-06-14

Implemented and verified in this branch:

- P0 atomic workout commit with rollback injection coverage.
- Canonical active status and expiry resolution.
- One persisted daily training-decision path across Dashboard, Today, Training, Coach context, and morning brief.
- Deterministic plan-day resolution and executable strength-session drafts.
- Versioned SwiftData schema registration, non-destructive recovery backup, and read-only fallback.
- Single final Agent generation, provider call counts, and removal of artificial character replay.
- Provider error classification for authentication, offline, timeout, malformed response, and generic failures.
- HealthKit refresh deduplication/throttling for the Training surface.
- Date-bounded Training summary fetches and bounded operational-data retention.
- Exercise-aware zero-load defaults when no prior performance exists.
- Full simulator tests, clean Debug simulator build, and Release iOS device build.

Still open because it requires broader product work or physical-device validation:

- Complete bounded-query conversion across every Today, Journal, Coach, and Training `@Query`.
- Move every Xunji and HealthKit entry point behind the central coordinator.
- iOS 17–25 tab lifecycle redesign and inactive-tab instrumentation.
- Onboarding/localization, accessibility, export/deletion/privacy controls, and personalized post-workout copy.
- 30/180/730-day XCTest performance fixtures, Instruments energy runs, seven-day seeded manual run, and production-store fixture migration.

---

## File Structure

**Create**

- `VelaApp/Core/Utilities/ActiveStatusSettings.swift`: canonical active-status storage, expiry, and resolution.
- `VelaApp/TrainingIntelligence/Services/TrainingScheduleResolver.swift`: resolve plan week/day from plan start date and completion history.
- `VelaApp/TrainingIntelligence/Services/TrainingSessionDraftBuilder.swift`: convert a `TrainingDay` and daily decision into an executable workout draft.
- `VelaApp/TrainingIntelligence/Services/WorkoutSaveCoordinator.swift`: own workout, event, artifact, aggregation, and draft commit semantics.
- `VelaApp/Health/Services/AppSyncCoordinator.swift`: deduplicate and throttle HealthKit/Xunji refreshes.
- `VelaApp/Persistence/Migrations/VelaSchema.swift`: versioned SwiftData schemas and migration plan.
- `VelaApp/Persistence/Services/DataExportService.swift`: portable local backup/export.
- `VelaApp/Persistence/Services/RetentionPolicyService.swift`: bounded retention for traces, artifacts, and caches.
- `VelaAppTests/ActiveStatusSettingsTests.swift`
- `VelaAppTests/TrainingExecutionTests.swift`
- `VelaAppTests/WorkoutSaveCoordinatorTests.swift`
- `VelaAppTests/AgentLoopTests.swift`
- `VelaAppTests/SyncCoordinatorTests.swift`
- `VelaAppTests/MigrationTests.swift`
- `VelaAppTests/DailyDriverIntegrationTests.swift`
- `VelaAppTests/PerformanceTests.swift`

**Modify**

- `VelaApp/Core/Utilities/DailySummaryUseCase.swift`
- `VelaApp/Core/Utilities/DashboardSummary.swift`
- `VelaApp/Scoring/Training/TrainingDecisionEngine.swift`
- `VelaApp/TrainingIntelligence/Services/RecoveryTrainingAdapter.swift`
- `VelaApp/TrainingIntelligence/Views/StrengthWorkoutLogSheetView.swift`
- `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`
- `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`
- `VelaApp/Features/Minimal/VelaMinimalShell.swift`
- `VelaApp/Features/Coach/CoachChatPanel.swift`
- `VelaApp/AI/Agent/AgentLoop.swift`
- `VelaApp/AI/Provider/LLMProvider.swift`
- `VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift`
- `VelaApp/Features/Onboarding/VelaOnboardingView.swift`
- `VelaApp/Features/Minimal/VelaMinimalCoachView.swift`
- `docs/TECH_ARCHITECTURE.md`
- `docs/AI_AGENT_SPEC.md`

---

## P0 Correctness And Data Safety

### Task 1: Canonical active status

- [ ] Add tests proving a fresh install resolves to `active`.
- [ ] Add tests proving `sick`, `injured`, and `resting` expire back to `active`.
- [ ] Move status keys, expiry calculation, and resolution into `ActiveStatusSettings.swift`.
- [ ] Replace direct `@AppStorage("vela_active_status")` decision inputs with `ActiveStatusSettings.resolveCurrentStatus()`.
- [ ] Keep UI bindings synchronized after expiry without requiring an app restart.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:VelaTests/ActiveStatusSettingsTests`.
- [ ] Commit as `fix: make active status canonical and expiry-aware`.

**Acceptance:** A user with no stored status never receives a rest decision solely because the key is absent, and an expired temporary status cannot continue affecting Today, Training, Coach, or notifications.

### Task 2: One training decision source

- [ ] Add a consistency test that builds one daily decision and compares the values exposed to Dashboard, Today, Training, Coach, and morning notifications.
- [ ] Make `BodyStateKernel -> TrainingDecisionKernel -> DailyOperatingPlanRecord` the production decision path.
- [ ] Remove lazy fallback evaluation through `DashboardSummary.trainingDecision`.
- [ ] Convert `TrainingDecisionEngine` and `RecoveryTrainingAdapter` into private kernel helpers or compatibility mappers with no direct UI callers.
- [ ] Update Coach context and post-workout artifacts to use the persisted daily operating plan.
- [ ] Run focused scoring, context, and persistence tests.
- [ ] Commit as `refactor: unify daily training decisions`.

**Acceptance:** For one day and one body-state hash, every product surface shows the same decision, volume multiplier, RPE cap, reasons, and confidence.

### Task 3: Correct plan-day resolution

- [ ] Add tests for week 1/day 1, week 2/day 3, future plans, completed days, skipped days, rest days, and plans crossing month/year boundaries.
- [ ] Implement `TrainingScheduleResolver.resolve(plan:on:events:calendar:)`.
- [ ] Calculate week from `TrainingPlanRecord.startDate`, not only weekday.
- [ ] Define deterministic fallback order: exact scheduled day, explicitly rescheduled day, earliest overdue incomplete day, then next incomplete day.
- [ ] Replace the weekday-only lookup in `VelaMinimalFitnessView`.
- [ ] Run `VelaAppTests/TrainingExecutionTests`.
- [ ] Commit as `fix: resolve the executable training plan day`.

**Acceptance:** A selected date always resolves to the correct plan week/day or an explicit no-session state; it never silently chooses an unrelated first incomplete day.

### Task 4: Plan-to-workout execution

- [ ] Add tests converting a strength `TrainingDay` into title, exercises, target sets/reps/RPE, and decision-adjusted volume.
- [ ] Implement `TrainingSessionDraftBuilder`.
- [ ] Pass a generated draft into `StrengthWorkoutLogSheetView`, not only an optional template ID.
- [ ] Preserve historical performance where available without overwriting plan targets.
- [ ] Handle rest, cardio, flexibility, and unsupported plan days with explicit actions instead of opening a blank strength form.
- [ ] Run training execution and workout-prefill tests.
- [ ] Commit as `feat: launch executable workouts from the daily plan`.

**Acceptance:** Tapping “开始并记录训练” on a Push session opens a populated Push workout whose set count and RPE reflect the persisted daily decision.

### Task 5: Atomic workout commit

- [ ] Add failure-injection tests at record insertion, event upsert, artifact insertion, daily aggregation, and draft deletion.
- [ ] Implement `WorkoutSaveCoordinator.commitNewWorkout` and `commitWorkoutEdit`.
- [ ] Perform one explicit save only after all mutations are prepared.
- [ ] On error, rollback the context and leave the active draft intact.
- [ ] Aggregate the affected old and new dates when an edited workout changes date.
- [ ] Return a committed result only after the daily summary is current.
- [ ] Replace persistence code inside `StrengthWorkoutLogSheetView`.
- [ ] Run coordinator and workout aggregation tests.
- [ ] Commit as `fix: make workout saves atomic and aggregated`.

**Acceptance:** No injected failure can leave an orphan event/artifact, delete the draft, show a false success state, or leave the daily summary stale.

### Task 6: Safe schema migration and recovery

- [ ] Snapshot representative legacy stores from prior schema shapes into test fixtures.
- [ ] Define `VersionedSchema` versions and a `SchemaMigrationPlan`.
- [ ] Remove automatic Debug deletion of `Vela.store`.
- [ ] Before recovery, copy the store, WAL, and SHM into a timestamped recovery directory.
- [ ] Open migration failures in read-only safety mode with a visible export/recovery action.
- [ ] Add migration tests proving workout, journal, food, Wiki, Coach, and training-response records survive.
- [ ] Commit as `feat: add versioned migration and store recovery`.

**Acceptance:** No build configuration deletes the only copy of user data after a migration failure.

---

## P1 AI Correctness And Responsiveness

### Task 7: Single final Agent generation

- [ ] Add a provider spy test asserting one final model generation after sequential tool calls.
- [ ] Extend the provider contract to support tool-aware streaming, or use the existing final `response.content` without replaying the request.
- [ ] Remove the second `streamChat(messages:)` call after a no-tool response.
- [ ] Update the existing test that currently expects the duplicate request.
- [ ] Record actual provider call count in `AgentRunTrace`.
- [ ] Run `VelaAppTests/AgentLoopTests` and existing Agent tests.
- [ ] Commit as `fix: generate agent final responses once`.

**Acceptance:** Two tool calls plus one final answer produce exactly three provider generations, not four.

### Task 8: Remove artificial reply delay

- [ ] Add a view-model test proving a completed non-streaming response is published in one update.
- [ ] Remove the 10 ms per-character replay loop from `CoachChatPanel`.
- [ ] Keep a short opacity transition in the view layer only.
- [ ] Ensure cancellation and backgrounding cannot leave `streamingContent` stuck.
- [ ] Run Coach and Agent tests.
- [ ] Commit as `perf: remove artificial coach typing delay`.

**Acceptance:** Once the provider finishes, the answer is immediately readable regardless of response length.

### Task 9: Provider failure and offline degradation

- [ ] Add tests for missing API key, invalid key, timeout, no network, malformed response, and partial stream interruption.
- [ ] Keep local Today, Training, Journal, and historical analysis available without AI.
- [ ] Show one actionable provider error with a direct route to settings.
- [ ] Prevent failed requests from creating empty Coach interactions or artifacts.
- [ ] Add retry rules that do not duplicate tool side effects.
- [ ] Commit as `fix: make coach failures degrade locally`.

**Acceptance:** AI failure never blocks local health/training workflows and retrying cannot repeat a successful write tool.

---

## P1 Performance And Lifecycle

### Task 10: Bounded SwiftData reads

- [ ] Add seed helpers for 180 and 730 days of records.
- [ ] Add performance baselines for Today first render and Training first render.
- [ ] Replace unbounded Today queries with date predicates and bounded fetch descriptors.
- [ ] Replace Training all-record reads and in-memory month filtering with date-range fetches.
- [ ] Bound Coach, Journal, artifacts, plans, and workout history to the windows each calculation needs.
- [ ] Move reusable date-window logic into `DateRangeQuery`.
- [ ] Run performance tests and compare wall time and fetched-object counts.
- [ ] Commit as `perf: bound primary screen data queries`.

**Acceptance:** Rendering cost is bounded by the required time window rather than total account age.

### Task 11: Central sync coordinator

- [ ] Add tests for concurrent refresh requests, foreground transitions, pull-to-refresh, date changes, and retry throttling.
- [ ] Implement `AppSyncCoordinator` with one in-flight task per source.
- [ ] Move HealthKit and Xunji synchronization out of page `.task` and `.onChange` handlers.
- [ ] Make pages display cache immediately and observe sync state.
- [ ] Add explicit force-refresh and background-refresh policies.
- [ ] Commit as `refactor: centralize health and training sync`.

**Acceptance:** Opening or switching tabs cannot start duplicate HealthKit or Xunji imports.

### Task 12: Tab lifecycle and background work

- [ ] Add instrumentation counters for Today, Training, Vitals, Coach, and Me appearance tasks.
- [ ] Stop keeping all five legacy tab surfaces active on iOS 17–25.
- [ ] Preserve navigation state only where product behavior requires it.
- [ ] Cancel page-specific tasks when a page is no longer active.
- [ ] Verify iOS 17 fallback and iOS 26 native TabView behavior.
- [ ] Commit as `perf: isolate tab lifecycle work`.

**Acceptance:** Launching Today does not execute Training synchronization or Coach page work.

### Task 13: Retention policies

- [ ] Define retention periods for `AgentRunRecord`, `AgentArtifactRecord`, `CoachArtifactRecord`, `XunjiDailyCacheRecord`, and diagnostic logs.
- [ ] Preserve user-authored records and accepted Wiki memory indefinitely unless explicitly deleted.
- [ ] Implement batched pruning after successful startup, never during first render.
- [ ] Add tests proving recent records remain and protected records are never removed.
- [ ] Commit as `feat: add bounded cache and trace retention`.

**Acceptance:** Operational data growth is bounded without deleting user-owned health history.

---

## P1 Product Completion

### Task 14: Exercise-aware defaults

- [ ] Add tests for historical, template, bodyweight, assisted, weighted-bodyweight, barbell, dumbbell, cable, and machine exercises.
- [ ] Remove universal `20 kg x 10` defaults.
- [ ] Use last performance first, then explicit template targets.
- [ ] Use nil/zero external load for bodyweight and require user input for unknown loaded movements.
- [ ] Display rep ranges without inventing a precise load.
- [ ] Commit as `fix: use exercise-aware workout defaults`.

**Acceptance:** A first-time pull-up cannot be prefilled as `20 kg x 10`.

### Task 15: Personalized post-workout guidance

- [ ] Inventory every fixed recovery/nutrition claim shown after training.
- [ ] Replace unsupported fixed claims with values derived from workout volume, session RPE, user goal, body weight, food log, sleep, and TrainingResponse history.
- [ ] Hide recommendations when required inputs are missing.
- [ ] Label general guidance separately from personalized guidance.
- [ ] Add snapshot/content tests for low-data and high-data cases.
- [ ] Commit as `feat: personalize post-workout guidance`.

**Acceptance:** The summary does not claim a fixed sleep duration, recovery window, or nutrient target without supporting user data.

### Task 16: Onboarding and localization closure

- [ ] Replace hard-coded mixed-language onboarding strings with localized keys.
- [ ] Add provider setup or an explicit “稍后设置，AI 功能暂不可用” choice.
- [ ] Explain HealthKit permission degradation before requesting access.
- [ ] Verify Simplified Chinese and English layouts at Dynamic Type accessibility sizes.
- [ ] Add localization-key coverage tests.
- [ ] Commit as `fix: complete onboarding localization and provider setup`.

**Acceptance:** A Chinese onboarding flow contains no unexplained English UI labels and never implies Coach is configured when no API key exists.

### Task 17: Accessibility, empty states, and error states

- [ ] Audit VoiceOver labels, button traits, Dynamic Type, contrast, Reduce Motion, and touch targets on the five core tabs.
- [ ] Define distinct empty, loading, stale-cache, permission-denied, offline, and fatal-storage states.
- [ ] Ensure score colors are never the sole carrier of meaning.
- [ ] Add accessibility identifiers for the daily-driver UI test path.
- [ ] Commit as `fix: harden accessibility and product states`.

**Acceptance:** Core workflows remain understandable with VoiceOver, large text, partial Health permissions, and no network.

### Task 18: Data ownership controls

- [ ] Implement local export for workouts, journal, food, Wiki, plans, Coach interactions, and derived summaries.
- [ ] Implement selective deletion and full local reset with confirmation.
- [ ] Document which structured summaries are sent to the configured AI provider.
- [ ] Add a privacy screen linking export, deletion, provider configuration, and diagnostics.
- [ ] Add round-trip export tests.
- [ ] Commit as `feat: add export deletion and privacy controls`.

**Acceptance:** A user can inspect, export, and delete their local data without developer tools.

---

## P2 Verification And Release Discipline

### Task 19: Daily-driver integration test

- [ ] Seed cached morning health data, an active multi-week plan, prior workout history, and valid provider stubs.
- [ ] Verify launch immediately displays cached state.
- [ ] Verify background refresh updates one persisted operating plan.
- [ ] Verify one training decision appears on every surface.
- [ ] Verify tapping start opens a populated workout.
- [ ] Complete sets, save, and verify workout/event/artifact/daily summary consistency.
- [ ] Record an evening check-in and calculate the next-day TrainingResponse.
- [ ] Verify the next decision and Coach context consume that response.
- [ ] Commit as `test: cover the complete daily driver loop`.

**Acceptance:** The complete morning-to-next-day path passes repeatedly without duplicate plans, events, artifacts, or provider side effects.

### Task 20: Long-term performance and energy validation

- [ ] Generate 30, 180, and 730-day datasets.
- [ ] Measure launch, Today render, Training render, tab switch, and workout-save latency.
- [ ] Add signposts for query, body-state, decision, aggregation, HealthKit, Xunji, and Agent stages.
- [ ] Set budgets: cached Today under 500 ms, Training under 700 ms, local workout commit under 500 ms on the reference simulator/device.
- [ ] Run Instruments on a physical device for CPU, memory, network, hangs, and energy.
- [ ] Record results in `docs/VELA_4_STABILIZATION_REPORT.md`.
- [ ] Commit as `test: establish daily driver performance budgets`.

**Acceptance:** Performance remains within budget at 730 days and inactive tabs perform no network or HealthKit work.

### Task 21: Release gate

- [ ] Run the full iOS simulator test suite.
- [ ] Run a clean Debug simulator build.
- [ ] Run a Release device build without deleting the installed store.
- [ ] Perform migration from the latest production/development store snapshot.
- [ ] Execute the daily-driver manual path for seven consecutive seeded days.
- [ ] Confirm no P0/P1 issue remains open.
- [ ] Update `docs/TECH_ARCHITECTURE.md`, `docs/AI_AGENT_SPEC.md`, and `docs/VELA_4_STABILIZATION_REPORT.md`.
- [ ] Tag the internal release only after all gates pass.

**Commands**

```bash
xcodebuild test \
  -project Vela.xcodeproj \
  -scheme Vela \
  -destination 'platform=iOS Simulator,name=iPhone 17'

xcodebuild \
  -project Vela.xcodeproj \
  -scheme Vela \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  clean build

xcodebuild \
  -project Vela.xcodeproj \
  -scheme Vela \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

**Acceptance:** Build and tests pass, migration preserves data, performance budgets pass, and the full daily loop has no unresolved correctness or data-safety failure.

---

## Current Priority Order

- [x] `P0-1` Atomic workout commit
- [x] `P0-2` Canonical active status
- [x] `P0-3` One training decision source
- [x] `P0-4` Correct plan-day resolution
- [x] `P0-5` Plan-to-workout execution
- [x] `P0-6` Safe migration and recovery
- [x] `P1-1` Single final Agent generation
- [ ] `P1-2` Bounded SwiftData reads
- [ ] `P1-3` Central sync coordinator
- [x] `P1-4` Offline/provider degradation
- [ ] `P1-5` Tab lifecycle isolation
- [x] `P1-6` Exercise-aware defaults
- [ ] `P1-7` Onboarding/localization closure
- [ ] `P1-8` Data ownership controls
- [ ] `P2` Personalization, accessibility, retention, performance, and release verification

## Scope Rule

Until all P0 items and the daily-driver integration test pass:

- Do not add new health metrics.
- Do not add new Agent tools.
- Do not add new primary tabs or product domains.
- Do not expand the backend integration surface.
- New findings must be added to this plan with severity, evidence, acceptance criteria, and a regression-test requirement.
