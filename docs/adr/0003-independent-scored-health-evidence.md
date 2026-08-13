# ADR 0003: Keep scored health evidence independent

- Status: Accepted
- Date: 2026-07-17

## Context

Vela computes five 0–100 health results: Recovery, Sleep, Strain, Physiological Stress, and Energy. These values do not share one direction: higher Recovery, Sleep, and Energy are favorable; higher Strain represents more load; higher Physiological Stress needs more attention. Combining them into one total health score would hide this difference and make missing inputs difficult to explain.

## Decision

Vela will not publish an aggregate health score.

Each `MetricResult` is typed with a `ScoredHealthDomain` and exposes its `ScoreDirection`, confidence, Data Coverage, contributors, missing inputs, data window, source, algorithm version, and update time. `DailyHealthComputation` remains the deep module that produces all five results from one daily snapshot and prior history.

`BodyState` may interpret the five results, and `TrainingDecision` may turn that interpretation into an action. Neither interface may silently replace missing score evidence with zero or a neutral value. AI may explain deterministic results but may not invent, override, or recompute them.

## Consequences

- Today may visualize the five results as one non-numeric capacity landscape for orientation, but it must keep each scored result independent in the signal/evidence layer with its direction and evidence quality. The landscape cannot be labeled or interpreted as an aggregate score.
- Consumers can no longer infer score meaning from a display name alone.
- Legacy cached `MetricResult` payloads are decoded through a name-based compatibility adapter, while new results persist an explicit domain.
- Missing evidence remains unavailable, reducing visual completeness but preserving trust.
- Cross-domain prioritization belongs to `BodyState` and `TrainingDecision`, not to an opaque total score.
