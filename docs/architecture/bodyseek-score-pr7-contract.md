# BodySeek Score Contract v2 / PR7

Status: contract-ready design; no runtime implementation or formula change.

Related decisions: ADR 0017, PR0 golden inventory, PR1 `BodySeekDomain`, PR2
dependency seams, PR3 Today state, and PR5 Trends state. This document is the
handoff contract for the ARCH-07 score-contract slice. It deliberately does not
replace the PR5 Trends host or migrate an individual scoring engine.

## Intent

Separate five concepts that are currently carried by one loosely interpreted
`MetricResult` (and, in the app target, by the older `StandardScoreResult`):

1. **Estimate**: the numeric result and its interpretation (`value`, `band`,
   component values, and component weights).
2. **Confidence**: how trustworthy that estimate is for this evaluation, based
   on evidence quality and known limitations.
3. **Coverage**: which required signals are present, fresh, and usable. Coverage
   is an input/evidence fact; it is not a score and must not be inferred from a
   displayed score.
4. **Readiness**: a downstream action/decision state. It may consume several
   independent estimates and lived-state evidence, but it is not an aggregate
   health score and never manufactures one when evidence is unavailable.
5. **Provenance**: where and when the evidence came from, the evaluation window,
   algorithm/config version, and the replay identity needed to audit a result.

The five score domains remain independent: Recovery, Sleep, Strain,
Physiological Stress, and Energy. PR7 is a protocol extraction, not a new
formula and not permission to add a Body/Health/Age aggregate.

## Canonical value contract

The eventual Foundation-only contract should be value-only and `Codable`,
`Hashable`, and `Sendable`. Names below are semantic roles; the implementation
may choose equivalent Swift names after collision review.

```swift
struct ScoreEstimate {
    let value: Double?                 // nil means unavailable, never zero
    let band: MetricBand
    let components: [String: Double]
    let componentWeights: [String: Double]
}

struct ScoreConfidenceReport {
    let level: MetricConfidence
    let reasons: [String]
    let limitingInputs: [String]
}

struct ScoreCoverageReport {
    let status: ScoreDataCoverage       // unavailable/partial/substantial/complete
    let requiredSignals: [SignalCoverage]
}

struct ScoreProvenance {
    let source: MetricSource
    let dataWindow: DateInterval
    let evaluatedAt: Date
    let algorithmVersion: String
    let inputFingerprint: String?
}

struct ScoreEvidence {
    let domain: ScoredHealthDomain
    let estimate: ScoreEstimate
    let confidence: ScoreConfidenceReport
    let coverage: ScoreCoverageReport
    let provenance: ScoreProvenance
    let reasons: [String]
}
```

`SignalCoverage` is expected to carry a stable signal identifier, optional
observed-at/freshness information, and an analytically-usable flag. It must not
contain a SwiftData model, HealthKit object, or UI label. A future typed
`ReadinessDecision` remains a separate downstream value with decision,
guidance, limiting domains, confidence, and safety notice; it has no numeric
aggregate field.

### Invariants

- `estimate.value == nil` implies the estimate is unavailable. No adapter may
  coerce it to `0`, a default range, or a default state.
- A coverage status is derived only from required signal facts. A high numeric
  estimate does not imply high coverage, and high coverage does not imply a high
  estimate.
- Confidence is an evaluation statement, not a signal count alias. Missing
  inputs, stale inputs, lived-state disagreement, and model limitations are
  represented in reasons/limiting inputs and may lower confidence independently.
- Provenance is required even when an estimate is unavailable. An unavailable
  result must still identify the evaluation window, algorithm version, and
  source that established the absence.
- Readiness consumes independent score evidence and may return `unknown` or a
  conservative action. It must not be persisted as a replacement for the five
  domain estimates.
- Unknown and unavailable are distinct: unknown means evaluation has not
  completed; unavailable means the completed evaluation lacks required evidence.

## Existing paths and ownership

| Concern | Current owner | PR7 target owner | Boundary rule |
|---|---|---|---|
| Five score values and metadata | `BodySeekDomain/ScoringCore.swift` `MetricResult`; duplicate app `VelaApp/Scoring/ScoringCore.swift` | `BodySeekDomain` contract; app adapter during migration | Domain owns value semantics; app owns mapping only |
| Sleep parity engine | `BodySeekDomain/SleepScoreEngine.swift` | unchanged in PR7 | No formula or missing-data change |
| Other score engines | `VelaApp/Scoring/*ScoreEngine.swift` via `ScoreEngineFactory.swift` | one-engine-at-a-time adapters in PR8 | PR7 does not extract them |
| Raw snapshot/history | `BodySeekDomain/DomainValues.swift` plus HealthKit/SwiftData adapters | unchanged input seam | No framework types cross the domain seam |
| Baselines | concrete app `LongTermBaselineReport` in `PersonalBaselineEngine.swift`; empty package placeholder in `DailyHealthComputation.swift` | typed baseline adapter feeding coverage/provenance | Resolve duplicate type names without schema change |
| Coverage | `HealthSignalCoverageService` and `DataCoverageSummaryModel` | per-score `ScoreCoverageReport`, global summary remains UI projection | Global coverage cannot stand in for score coverage |
| Readiness/action | `DailyTrainingDecision`, `TrainingDecision`, `BodyState` and Today projections | downstream `ReadinessDecision` adapter | No aggregate readiness number |
| Trends provenance | `HealthTrendFinding`, `TrendsPointProvenance`, `TrendsStore` | consume provenance projection | PR7 does not migrate `VelaTrendsView` |

## Migration seam

1. Add the contract value types to `BodySeekDomain` without changing
   `MetricResult`, `StandardScoreResult`, persistence models, or formulas.
2. Add a pure adapter from existing `MetricResult` to `ScoreEvidence`. For the
   first cut, derive coverage only from explicit `missingInputs` and mark
   freshness/signal lineage as unavailable rather than guessing it.
3. Add the inverse compatibility projection for existing Today, Coach, and
   legacy detail views. It must preserve `nil`, `--`, existing bands, versions,
   and source labels. The app target's non-optional `score`, default strain
   ranges, and non-optional `state` are compatibility liabilities and must not
   be copied into the canonical contract.
4. Migrate Sleep first because it is the only standalone package engine and has
   an executable replay oracle. Then migrate Recovery, Strain, Physiological
   Stress, and Energy independently in PR8, each with its own parity evidence.
5. Introduce the typed readiness adapter only after all consuming paths can read
   the independent evidence slots. Existing `TrainingDecision` strings and
   `DailyTrainingDecision.confidence` remain compatibility projections until
   that adapter is proven equivalent.

## Golden/replay gates

Every PR7/PR8 slice must run the existing PR0 oracle before and after mapping:

- Gregorian calendar, UTC, `2026-07-31T12:00:00Z`, 14 history days, profile
  values from `docs/baselines/golden-inventory.json`.
- Preserve the five expected values (`77.43`, `60.70`, `63.67`, `21.08`,
  `42.31`) and all five algorithm versions within the existing `0.01`
  tolerance.
- Preserve the empty snapshot: all values `nil`, unavailable coverage,
  formatted `--`, and no aggregate readiness score.
- Preserve the lived-state fixture: objective scores unchanged while confidence
  is lowered and the `lived-state` driver remains explicit.
- Add contract replay assertions for: unavailable provenance is still present;
  missing values do not become zero; coverage and confidence can differ; and a
  readiness projection cannot introduce an aggregate number.
- Add Codable round-trip fixtures for each new value type, including `nil`
  estimate and an unavailable signal. These are additive fixtures, not schema
  migration instructions.

## Non-goals

- No scoring formula, threshold, weighting, baseline window, or algorithm
  version change.
- No SwiftData schema migration, HealthKit query rewrite, persistence actor
  change, or Watch protocol change.
- No product rename, deployment-floor change, aggregate score, Health Age, or
  population benchmark.
- No Trends host migration; PR5's `TrendsStore` and chart remain a separate
  bounded task.
- No claim that global data coverage is sufficient evidence for any individual
  score component.

## Evidence gaps blocking implementation sign-off

1. PR0 asserts whole-score values, versions, and missing semantics, but has no
   canonical component-level coverage, freshness, or provenance oracle.
2. `BodySeekDomain.LongTermBaselineReport` is intentionally empty while the app
   target defines a concrete same-named report; the package/app transport type
   and serialization identity are unresolved.
3. `DailyHealthSnapshot` contains source-agnostic fields and no stable per-input
   observation IDs or observed-at timestamps. HealthKit lineage cannot yet be
   audited end to end.
4. `DataCoverageSummaryModel` is a global/UI summary. It does not say which
   score component consumed which signal or whether that signal was fresh at
   evaluation time.
5. `MetricConfidence` currently mixes score-engine missing-input logic with
   lived-state alignment in downstream paths; the authoritative confidence
   composition rule is not frozen.
6. App and package compatibility projections disagree (`value`/`score` optional
   vs zero-coerced, optional vs non-optional `state`, and default strain ranges).
   These must be audited before deleting legacy fields.
7. PR0's 14-day history is insufficient to prove future 21–42-day baseline
   contracts or robust statistics. A separate deterministic baseline fixture is
   required before enabling long-term corrections.
8. Field naming still exposes `hrvAverage` and `hrvRmssdMilliseconds` while the
   product contract references HealthKit SDNN. The canonical metric identity and
   unit normalization need an explicit decision.

ARCH-07 is ready to implement only after these gaps are either covered by
fixtures/contracts or explicitly accepted as adapter limitations. Until then,
PR4/PR8 agents must treat the legacy adapters as behavior-preserving seams,
not as canonical score data.
