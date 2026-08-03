# Phase H validation — 2026-07-31

## Result

H01–H12 are implemented in the parity shell. The Home surface now establishes the daily loop without duplicating Recovery, Sleep, and Strain as competing cards.

## Requirement evidence

| ID | Current evidence |
| --- | --- |
| H01 | `TodayDateAndStatusHeader` exposes selected date, account/settings, share, Activity Status, weather, simulation source, and refresh state with 44 pt controls. |
| H02 | `TodayHeroCard` renders Recovery, Sleep, and Strain in one compact shared card using `VelaMetricScoreRing`. |
| H03 | The guidance block uses `TodayExperienceModel` and the persisted daily plan; Target Strain comes directly from `dashboard.strain.recommendedRange`, not parsed or fabricated text. |
| H04 | Stress and Energy are the only secondary score cards. Their detail timelines query real `IntradaySignalBucketRecord` values. Missing periods remain missing. |
| H05 | Home includes Health Monitor, Nutrition, Journal, evidence, and the action timeline with working destinations. |
| H06 | Calendar and month selection remain available; a deliberate horizontal drag switches historical days and cannot move into the future. |
| H07 | Recovery detail adds current-vs-personal-baseline HRV/RHR, evidence, trends, coverage, freshness, and algorithm metadata. |
| H08 | Sleep detail has duration/efficiency highlights, sleep clock, primary-sleep timeline, stage evidence, targets, trends, and metadata. |
| H09 | Strain detail has Target Strain, activities, heart-rate zones, evidence, trends, and metadata. |
| H10 | Stress detail has a real five-minute physiology/activity series, active-period markers, evidence, trends, and an explicit empty state. |
| H11 | Energy detail has morning-to-current energy, real intraday drain points, component drains/recharge, evidence, trends, and an explicit empty state. |
| H12 | Home score cards route to their dedicated detail, shared cards have real destinations, share actions use current selected-day data, and common partial/stale/error states use canonical components. |

## Verification

- Simulator build: `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` — passed.
- Focused intraday authenticity tests:
  - `testIntradayStressSeriesUsesPersistedHeartRateBucketsWithoutInventingMissingPeriods` — passed.
  - `testIntradayEnergySeriesOnlyMovesWhenRealBucketsExist` — passed.
- Result bundle: `/tmp/VelaBevelUpgrade.GBISJh/DerivedData/Logs/Test/Test-Vela-2026.07.31_19-42-26-+0800.xcresult`
- Screenshot: `H-phase-home-light-2026-07-31.png`

## Visual acceptance notes

- Recovery, Sleep, and Strain are visible together without scrolling.
- Stress and Energy are visible on the same initial viewport on the target-size simulator.
- The old oversized dark editorial hero has been removed.
- Target Strain remains visible even when HealthKit recovery samples are unavailable.
- Missing Recovery/Sleep/Energy remain `--`; no default scores or invented intraday curves are rendered.

