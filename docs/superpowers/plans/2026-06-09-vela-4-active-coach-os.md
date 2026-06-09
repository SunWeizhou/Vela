# Vela 4.0 Active Coach OS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Vela's closed-loop daily body intelligence operating system.

**Architecture:** Make WorkoutEventRecord the workout fact, BodyStateKernel the interpretation fact, TrainingDecisionKernel the action decision, and DailyOperatingPlanRecord the persisted Home contract. Persist Coach interactions, Agent traces, and structured artifacts separately from Journal.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, HealthKit, XCTest, xcodebuild.

---

### Task 1: P0 loop and persistence boundaries

**Files:**
- Modify: `VelaApp/AI/Agent/AgentLoop.swift`
- Modify: `VelaApp/Features/Coach/CoachChatPanel.swift`
- Modify: `VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift`
- Modify: `VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift`
- Modify: `VelaApp/Health/Services/WorkoutAggregationService.swift`
- Modify: `VelaApp/Persistence/Repositories/DailyHealthSummaryRepository.swift`
- Test: `VelaAppTests/AgentActionParserTests.swift`
- Test: `VelaAppTests/PersistenceFoundationTests.swift`
- Test: `VelaAppTests/WorkoutAggregationTests.swift`

- [ ] Add failing tests for trace contents, CoachInteraction persistence, and aggregation-only workout summary writes.
- [ ] Run focused tests and confirm they fail for the missing contracts.
- [ ] Persist Agent trace data through AgentRunRecord and move Coach turns to CoachInteractionRecord.
- [ ] Remove local workout merging from DailyHealthSummaryRecord.apply and route HealthKit workouts through WorkoutEventRecord.
- [ ] Run focused tests and confirm they pass.

### Task 2: Body and training decision kernels

**Files:**
- Modify: `VelaApp/Core/Utilities/DashboardSummary.swift`
- Modify: `VelaApp/Scoring/Training/TrainingDecisionEngine.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] Add failing tests for no-HealthKit fallback, local fatigue drivers, costly training-response drivers, and keep/reduce/swap/rest decisions.
- [ ] Implement deterministic BodyState and TrainingDecision inputs and outputs with hashes, confidence, freshness, source, and safety text.
- [ ] Run focused tests and confirm they pass.

### Task 3: Daily plan and artifact records

**Files:**
- Modify: `VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift`
- Modify: `VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift`
- Test: `VelaAppTests/PersistenceFoundationTests.swift`

- [ ] Add failing round-trip tests for DailyOperatingPlanRecord and AgentArtifactRecord.
- [ ] Implement migration-safe records, JSON helpers, and upsert generation from BodyState and DailyTrainingDecision.
- [ ] Run focused tests and confirm they pass.

### Task 4: Trend and response tools

**Files:**
- Modify: `VelaApp/AI/Agent/AgentTool.swift`
- Modify: `VelaApp/AI/Agent/ToolFactory.swift`
- Test: `VelaAppTests/AgentActionParserTests.swift`

- [ ] Add failing tests for 7/14/30-day health trend queries and workout-to-next-day response payloads.
- [ ] Implement HealthTrendTool and TrainingResponseHistoryTool and register them.
- [ ] Run focused tests and confirm they pass.

### Task 5: Product experience wiring

**Files:**
- Modify: `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`
- Modify: `VelaApp/Features/Coach/CoachView.swift`

- [ ] Wire Today OS to BodyState and the persisted DailyOperatingPlanRecord.
- [ ] Put active plan, today's session, last performance, PRs, rest controls, fatigue, and next suggestion first in Fitness.
- [ ] Render proactive insight, plan, memory inbox, artifacts, Wiki, and chat in Intelligence.
- [ ] Confirm all core tabs render actionable fallback states without real HealthKit data.

### Task 6: Documentation and release verification

**Files:**
- Modify: `docs/PRD.md`
- Modify: `docs/TECH_ARCHITECTURE.md`
- Modify: `docs/AI_AGENT_SPEC.md`

- [ ] Document local-first provider boundaries and the 4.0 kernels and records.
- [ ] Audit recommendation source, confidence, freshness, and non-diagnostic safety language.
- [ ] Run the full iOS simulator test suite.
- [ ] Run a clean simulator build.
- [ ] Re-read Vela_4.0.md and verify each requirement against code, tests, and rendered surfaces.
