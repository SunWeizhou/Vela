# VALIDATION EVIDENCE

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 历史视觉与功能验证证据（仅作历史测试回归参考）

---

# Phase T · Strength Set Types · 2026-08-01

## Outcome

- Added Working, Warm-up, Drop, Back-off and Failure set types.
- Existing `isWarmup` JSON remains backward compatible; legacy warm-up sets decode as Warm-up without a SwiftData schema migration.
- Selecting a type updates the compact set badge, color, accessibility label and saved JSON.
- Warm-up sets remain excluded from training volume and effective-set analysis.
- Completed Drop, Back-off and Failure sets continue to use their real repetitions, load, RPE and RIR in analytics rather than receiving fabricated multipliers.
- Workout history displays the saved set type.

## Files

- `VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift`
- `VelaApp/TrainingIntelligence/Views/StrengthWorkoutLogSheetView.swift`
- `VelaApp/TrainingIntelligence/Views/StrengthWorkoutDetailView.swift`
- `VelaAppTests/VelaThemeTests.swift`

## Automated verification

- Simulator: iPhone 17 Pro, iOS 26.5
- Result bundle: `/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_18-36-14-+0800.xcresult`
- Result: 1 passed, 0 failed
  - `testStrengthSetKindsRemainBackwardCompatibleAndExcludeWarmupsFromVolume`
- The test also confirms three completed sets become two effective sets and 900 kg of non-warm-up volume.

## Visual and accessibility verification

- Opened Fitness → Start Strength Workout → Add Exercise → set-type menu.
- Confirmed all five set types and their SF Symbols are exposed in the accessibility tree.
- Confirmed the set-type button announces set number, current type and that it can be changed.
- Screenshot: `docs/validation/bevel-parity/screenshots/phase-t-strength-set-types-2026-08-01.png`
