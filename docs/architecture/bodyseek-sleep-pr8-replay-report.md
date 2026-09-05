# BodySeek ARCH-08 / PR8 Sleep replay evidence

Status: release-ready evidence harness; no scoring formula or algorithm-version change.

This slice freezes a deterministic replay identity for the standalone
`BodySeekDomain.SleepScoreEngine` and records one-input sensitivity cases. The
replay uses Gregorian/UTC, evaluates at `2026-07-31T12:00:00Z`, and keeps the
existing `sleep.v2.0.0` implementation unchanged.

## Baseline identity

The PR0 sleep projection is 465 minutes of sleep against a 450-minute target,
24 awake minutes, and two awake episodes. No current bedtime or five-night
bedtime history is supplied, matching the package golden replay's missing
`todayBedtime` and `recentBedtimesHistory` inputs.

Canonical fingerprint:

`sleep-v2|2026-07-31T12:00:00Z|465.0|450.0|awake=24.0|episodes=2|bedtime=nil|history=0`

Expected output is `77.43` (tolerance `0.01`), medium confidence, duration
component `50.0`, interruption component `4.2`, and missing inputs
`todayBedtime` and `recentBedtimesHistory`. The algorithm version remains
`sleep.v2.0.0`.

## Sensitivity evidence

| Case | Single controlled change | Value | Confidence | Missing inputs |
| --- | --- | ---: | --- | --- |
| baseline | none | 77.43 | medium | todayBedtime, recentBedtimesHistory |
| short-sleep-360 | total sleep = 360 min | 53.62 | medium | todayBedtime, recentBedtimesHistory |
| no-awake-time | awake = 0, episodes = 0 | 100.00 | medium | todayBedtime, recentBedtimesHistory |
| missing-awake-time | awake and episodes unavailable | 79.00 | low | todayBedtime, recentBedtimesHistory, awakeMinutes |
| five-bedtime-history | current bedtime and five matching history values | 84.20 | high | none |

The missing-input case (`totalSleepMinutes = nil`) remains unavailable, retains
low confidence, reports `totalSleepMinutes`, and formats as `--`; it is never
coerced to zero.

The executable assertions live in
`BodySeekDomain/Tests/BodySeekDomainTests/SleepReplaySensitivityTests.swift`.
The machine-readable fixture is
`docs/baselines/sleep-replay-fixtures.json`.
