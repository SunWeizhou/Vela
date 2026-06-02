# Coach and Fitness Release Readiness Plan

Date: 2026-06-01

## 1. DeepSeek Resolver And Coach Usability

- Add failing tests for display-name to API-identifier resolution and default behavior.
- Add a shared DeepSeek model resolver.
- Route Provider caching, direct advice generation, background providers, and settings connection tests through the resolver.
- Replace Coach hard-coded header inset with safe-area-aware layout and display the active model.

## 2. Bottom Navigation And Journal Entry

- Reduce bottom tabs to Home, Fitness, Vitals, Coach.
- Update the Coach tab index.
- Add a deferred journal action and journal sheet.
- Replace Search Food in the plus grid with Journal.

## 3. Stable Apple Health Workouts

- Add a failing helper-level identity test.
- Ensure both HealthKit workout mapping paths preserve `HKWorkout.uuid`.
- Improve workout list rows and workout detail metrics without changing the visual language.

## 4. Strength Workout Records

- Add failing persistence and volume tests.
- Add SwiftData strength session model with Codable exercise and set payloads.
- Register the model in `VelaModelContainer`.
- Add a strength workout editor, Fitness entry point, recent list, and detail screen.

## 5. Coach Strength Tool

- Add a failing tool-output test.
- Add and register a read-only recent strength-history tool.
- Include enough structured detail for Coach to reason about movement patterns and volume.

## 6. Metric Detail Refinement

- Add compact supporting evidence cards for core metrics.
- Keep unavailable data honest and consistent.
- Verify existing metric detail tests and snapshots.

## 7. Release Checks

- Run focused tests during implementation.
- Run full simulator test suite.
- Run Analyze.
- Build, install, and launch on the connected iPhone.
- Inspect key screens through iPhone mirroring without sending Coach messages.
