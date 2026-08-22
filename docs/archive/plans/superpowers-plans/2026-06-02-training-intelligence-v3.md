# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela 3.0 Training Intelligence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a local-first training, recovery, nutrition, sleep, and personal-body-intelligence loop without breaking the existing Vela cockpit.

**Architecture:** Extend the existing SwiftData payload models compatibly, centralize workout-event persistence in `WorkoutAggregationService`, and keep analysis in pure services so the same facts feed UI, scoring, and Coach context. Preserve the current Bevel-style Training tab and add actionable intelligence sections and an active-session editor inside its existing source file to avoid Xcode project index churn.

**Tech Stack:** SwiftUI, SwiftData, HealthKit, XCTest, existing Vela design system.

---

### Task 1: Training Fact Models

**Files:**
- Modify: `VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift`
- Modify: `VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift`
- Test: `VelaAppTests/PersistenceFoundationTests.swift`

- [ ] Add failing persistence tests for exercise definitions, templates, workout event metadata, and training responses.
- [ ] Add compatible optional/defaulted fields and register new SwiftData models.
- [ ] Run focused persistence tests.

### Task 2: Training Analytics And Recovery Adaptation

**Files:**
- Modify: `VelaApp/Scoring/Training/AdaptiveTrainingEngine.swift`
- Modify: `VelaApp/Scoring/Training/TrainingDecisionEngine.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] Add failing tests for volume, effective sets, warmup exclusion, muscle mapping, e1RM, PR detection, empty data, local fatigue, and recovery adaptation.
- [ ] Implement `ExerciseLibraryService`, `TrainingAnalyticsService`, and `RecoveryTrainingAdapter`.
- [ ] Run focused scoring tests.

### Task 3: Workout Event Aggregation And Plan Linkage

**Files:**
- Modify: `VelaApp/Health/Services/WorkoutAggregationService.swift`
- Modify: `VelaApp/Features/SharedComponents/VelaQuickActionsSheet.swift`
- Test: `VelaAppTests/WorkoutAggregationTests.swift`

- [ ] Add failing tests for strength upsert, day summary aggregation, source preservation, idempotency, and training-day completion.
- [ ] Implement event upsert, day aggregation, recent rebuild, and active-plan linkage.
- [ ] Route manual and strength saves through the service.
- [ ] Run focused aggregation tests.

### Task 4: Coach Strength Context And Personal Intelligence

**Files:**
- Modify: `VelaApp/AI/Models/AgentContextSchema.swift`
- Modify: `VelaApp/AI/Context/AIContextBuilder.swift`
- Modify: `VelaApp/AI/Proactive/PersonalResponseInsightService.swift`
- Test: `VelaAppTests/ContextBuilderTests.swift`

- [ ] Add failing tests for expanded `strength_training` context and empty-history degradation.
- [ ] Feed analytics summaries, local fatigue, recent PRs, and recovery adaptation into the default Coach context.
- [ ] Generate next-day response records and weekly-report memory proposals through the existing confirmation ledger.
- [ ] Run focused context tests.

### Task 5: Active Workout And Training Tab

**Files:**
- Modify: `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`

- [ ] Replace the post-workout form with active-set completion, set-level RPE/RIR, quick adjustments, copy, delete, rest timer, prior performance, and discard confirmation.
- [ ] Add exercise search, seeded exercise selection, template start, summary sheet, weekly muscle volume, PR, and recovery-adjusted recommendation cards.
- [ ] Keep the existing visual language and real SwiftData data paths.

### Task 6: Release Verification

**Files:**
- Verify: `Vela.xcodeproj`

- [ ] Run the full simulator test suite.
- [ ] Run simulator and device SDK builds.
- [ ] Review the final diff and verify no `pbxproj` edits or unrelated rewrites.
