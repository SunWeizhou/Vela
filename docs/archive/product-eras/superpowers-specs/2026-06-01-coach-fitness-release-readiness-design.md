# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Coach and Fitness Release Readiness Design

Date: 2026-06-01

## Scope

Keep the existing warm, card-based Vela UI language. Fix broken data paths and add only the explicitly requested product surfaces:

- Coach text model selection between DeepSeek V4 Flash and DeepSeek V4 Pro.
- Usable embedded Coach header and composer behavior.
- Journal entry point moved from the bottom tab bar into the plus sheet.
- Richer metric, Apple Health workout, and daily activity detail presentation.
- Local strength-workout logging with exercises, equipment, sets, reps, weight, and calculated volume.
- Coach access to structured strength-workout history.

## Model Selection

Expose two product-facing options:

| Display Name | API Identifier |
| --- | --- |
| DeepSeek V4 Flash | `deepseek-v4-flash` |
| DeepSeek V4 Pro | `deepseek-v4-pro` |

Persist the selected display value with the existing `vela_coach_text_model` key. Convert it to an API identifier at the Provider boundary. Every DeepSeek call path must use the same resolver, including the embedded Coach, metric advice card, API connection test, and background providers.

## Coach Interaction

The embedded Coach remains a full tab surface and the quick Coach remains a full-screen shortcut. Both reuse `VelaCoachView`.

The embedded surface will:

- use safe-area-aware header padding rather than a hard-coded top inset;
- keep the composer above the floating tab bar while idle;
- collapse its bottom inset while the keyboard is visible;
- keep the keyboard toolbar dismissal button;
- show the selected model in the connection status line;
- retain timestamped history context so the model receives the concrete date, time, and timezone for prior messages.

No automated acceptance check will send a real Coach message.

## Navigation

The bottom bar becomes four tabs: Home, Fitness, Vitals, Coach. The journal screen is removed from the always-mounted tab surfaces. The plus sheet replaces Search Food with Journal and presents the existing journal screen as a sheet.

Food search remains implemented internally but is no longer a primary quick action.

## Workout Identity And Presentation

HealthKit workout summaries must carry `HKWorkout.uuid` in every mapping path. This stabilizes refresh merges and prevents one HealthKit workout from appearing as a new row after each query.

Apple Health workout rows keep a one-row-per-workout list and add concise secondary metrics. The workout detail page adds:

- dynamic heart-rate range and chart scale;
- distance when present;
- sample count and available workout facts;
- clear missing-data messaging.

## Strength Workout Logging

Use a local SwiftData model with encoded exercise payloads to avoid relationship migration complexity:

- `StrengthWorkoutRecord`: session metadata and encoded exercises.
- `StrengthExerciseLog`: exercise name, equipment, and sets.
- `StrengthSetLog`: reps, kilograms, warm-up flag.

Calculated session fields include set count, rep count, and total volume in kilograms. The Fitness screen adds a strength-log entry point and a recent strength-workout section. A detail screen renders exercises and sets in the existing card style.

## Coach Strength Context

Add a read-only Coach tool that returns recent strength sessions with exercise, equipment, set, rep, weight, and volume details. Register it in `ToolFactory`. The tool does not modify records.

## Metric Details

Keep `VelaMetricDetailView` as the shared framework. Add compact evidence rows for:

- recovery: HRV, resting heart rate, respiratory rate;
- energy: ATL, CTL, TSB, ACWR;
- sleep: efficiency, REM, deep, awake minutes;
- strain: workout load, non-workout activity load, training-load ratio;
- stress: explicit daily-proxy explanation.

Missing values stay visible as unavailable rather than fabricated.

## Verification

- Add focused unit tests for model resolution, stable workout identity helper behavior, strength-record volume and persistence, Coach strength-history tool output, and tab routing constants.
- Run focused tests after each slice.
- Run full simulator tests, Analyze, device build, install, launch, and mirrored UI inspection.
