# BodySeekDomain

`BodySeekDomain` is the first standalone Foundation-only target in the BodySeek
(engineering identity: Vela) migration. It targets iOS 17 and watchOS 10 with
Swift tools 6.0 and is intentionally not linked into `Vela.xcodeproj` yet.

## PR1 scope

- Public, `Codable`/`Hashable`/`Sendable` evidence values:
  `DailyHealthSnapshot`, `WorkoutSummary`, sleep values, and score metadata.
- Shared score semantics: `MetricResult`, `ScoringMath`, independent domain
  identifiers, data coverage, missing-value (`nil`) behavior, and algorithm
  version constants.
- A parity-preserving migration of the existing Vela `SleepScoreEngine` only.
  The implementation keeps its duration, consistency, interruption,
  renormalization, confidence, low-confidence cap, and legacy Buysse component
  semantics unchanged while taking an explicit `Calendar` for deterministic
  replay.
- `DailyHealthComputation` exposes all five independent evidence slots. Sleep is
  computed; Recovery, Strain, Physiological Stress, and Energy are explicit
  unavailable results until their own engine extractions pass the same oracle.
  No aggregate/readiness score is introduced.

## Boundaries

Production files import `Foundation` only. There is no HealthKit, SwiftData,
SwiftUI, UIKit, UserDefaults, ProcessInfo, persistence, networking, or global
singleton. Health/App adapters remain in the Vela target and are not changed by
PR1. `LongTermBaselineReport` is an intentionally empty seam placeholder;
baseline statistics are deferred to the later baseline contract work.

`MetricResult` compatibility projections are optional or unknown-aware: an
unavailable result never projects to numeric `0`, a default strain range, or a
false state. `StandardScoreResult` remains a legacy adapter-only value for
incremental callers and is not used by `DailyHealthComputation`.

## Verification

```sh
swift test --package-path BodySeekDomain
swift build --package-path BodySeekDomain
git diff --check
```

The package replay test uses the PR0 fixture and asserts Sleep `77.43` within
`0.01`, algorithm version `sleep.v2.0.0`, and nil/unavailable semantics for an
empty snapshot and the not-yet-migrated domains.
