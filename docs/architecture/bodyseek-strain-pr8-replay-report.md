# BodySeek ARCH-08 / PR8 Strain replay evidence

Status: app-target oracle evidence; package parity remains explicitly blocked.
No scoring formula or algorithm-version change is included in this slice.

`StrainScoreEngine` and `StrainScoreInput` currently live under
`VelaApp/Scoring/Strain`. `BodySeekDomain` intentionally reports Strain as
unavailable until an independently reviewed adapter migration is scheduled.
This harness freezes the current app oracle rather than duplicating the formula
in the package.

## Deterministic baseline

The replay evaluates at `2026-07-31T12:00:00Z` using a Gregorian UTC clock.
The input has one 45-minute workout at average heart rate 145, male reserve
heart-rate bounds 60/190, 500 kcal active energy, 45 exercise minutes, 8,000
steps, and 28 daily-load history values. The canonical fingerprint is recorded
in `docs/baselines/strain-replay-fixtures.json`.

The oracle returns `65.5297799653`, confidence `high`, algorithm version
`strain.v2.0.0`, and no missing inputs. The executable assertions live in
`VelaAppTests/StrainReplaySensitivityTests.swift`.

## Sensitivity evidence

| Case | Controlled change | Value | Confidence |
| --- | --- | ---: | --- |
| baseline | none | 65.5297799653 | high |
| short-workout-20 | workout duration 20 minutes | 44.3578249751 | high |
| high-energy-900 | active energy 900 kcal | 66.7659808416 | high |
| high-rpe-9 | average heart rate removed, RPE 9 | 83.2694664989 | high |

When all activity evidence is absent, the result remains `nil`, data coverage
is `unavailable`, formatted score is `--`, confidence is `low`, and all four
required activity input names are retained. No missing value is coerced to zero.

Focused command:

```text
xcodebuild test -project Vela.xcodeproj -scheme Vela \
  -destination 'platform=iOS Simulator,id=BCAD01D0-CB5A-4277-B622-269479D0E159' \
  -only-testing:VelaTests/StrainReplaySensitivityTests
```
