# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela 4.0 Active Coach OS Design

## Product Loop

Vela 4.0 turns the existing health, training, journal, nutrition, Coach, and Wiki features into one daily operating loop:

`HealthKit + local events -> BodyStateKernel -> TrainingDecisionKernel -> DailyOperatingPlanRecord -> execution -> TrainingResponseRecord -> Coach context -> memory proposal -> next plan`

The loop remains local-first. Raw HealthKit samples never leave the device. AI providers receive only structured summaries. The optional VelaBackend is an alternative provider transport and is not required by the iOS app.

## Architecture

`WorkoutEventRecord` is the canonical workout fact. `WorkoutAggregationService.aggregateDay` is the only writer of workout summary fields on `DailyHealthSummaryRecord`.

`BodyStateKernel` is the canonical daily interpretation layer. It combines dashboard metrics, daily cache, workout events, strength analytics, training responses, food, journal, active plan, and active status into a deterministic `BodyState` with readiness, drivers, local fatigue, confidence, freshness, and a stable hash.

`TrainingDecisionKernel` consumes `BodyState`, the active plan, recent strength summary, training response history, and user constraints. It returns keep, reduce, swap, or rest with a volume multiplier, intensity cap, reasons, and a non-diagnostic user summary.

`DailyOperatingPlanRecord` persists the Home decision. `AgentArtifactRecord` persists structured AI output. `CoachInteractionRecord` archives Coach turns without contaminating Journal correlations. Existing models receive only optional additions where migration compatibility requires it.

## Experience

Home becomes Today OS and presents state, cause, plan, watch, and action in that order. It reads a persisted daily operating plan and remains useful with cached, preview, or missing HealthKit data.

Fitness becomes Training Execution. The active plan and today's session lead the page, followed by logging, last performance, rest controls, PRs, local fatigue, and the next-session suggestion.

Intelligence becomes a workspace. Proactive insight, today's plan artifact, memory inbox, recent artifacts, Wiki files, and chat appear as product objects instead of a chat-only surface.

## Trust And Safety

Every generated recommendation exposes source, confidence, freshness where applicable, and the statement that it is non-diagnostic guidance. Agent runs persist context hash, tool arguments, tool results, and final response for auditability.

## Verification

Focused tests cover sequential Agent tool calls and traces, context training-response deltas, workout aggregation idempotency, zero-completed-set validation, BodyState, TrainingDecision, trend tools, and persistence models. Completion requires a clean iOS simulator build and the full simulator test suite.
