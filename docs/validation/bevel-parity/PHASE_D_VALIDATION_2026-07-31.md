# VALIDATION EVIDENCE

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 历史视觉与功能验证证据（仅作历史测试回归参考）

---

# Phase D Validation — 2026-07-31

## Scope

- D01 frozen layout, shape, type, material, motion and semantic metric tokens.
- D02 canonical score ring, metric card, trend card, evidence row and status pill.
- D03 canonical historical chart, sparse-series segmentation, baseline, target band, stage and event timelines.
- D04 five-destination tab shell, fixed metric header, calendar entry and common sheet surface.
- D05 loading, empty, partial, calibrating, stale, offline and error states.
- D06 touch-down press feedback, critically damped default motion, momentum-only spring and causal haptics.
- D07 Dynamic Type layout branches, combined VoiceOver summaries, Reduce Motion, Reduce Transparency and increased-contrast surfaces.

## Automated evidence

- Simulator build: passed on iPhone 17 Pro / iOS 26.5.
- `testParityGeometryTokensMeetFrozenVisualContract`: passed.
- `testEverySharedPresentationStateHasSpecificCopyAndSymbol`: passed.
- `testSparseChartSeriesBreaksAcrossMissingPeriods`: passed.
- `testStageTimelineClipsIntervalsToVisibleWindow`: passed.
- Result bundle: `/tmp/VelaBevelUpgrade.GBISJh/DerivedData/Logs/Test/Test-Vela-2026.07.31_16-44-18-+0800.xcresult`.

## Migration revalidation

The original read-only simulator store was removed, then the untouched F01 physical-device backup was copied into a fresh app container and opened by the current V2 schema after the intraday model had been added.

- Daily records retained: 53.
- `ZSCOREEVIDENCEDATA` retained.
- `ZINTRADAYSIGNALBUCKETRECORD` created.
- App launched without recovery/read-only mode.

## Visual evidence

- `D-phase-home-light-2026-07-31.png`
- Device: iPhone 17 Pro simulator.
- Locale: Simplified Chinese.
- Appearance: Light.
- Data state: physical-device database backup; HealthKit itself is unavailable in Simulator.

## Remaining visual delta

Phase D only establishes reusable primitives and the shell. The current Home hero is intentionally not accepted as Bevel-parity yet: it is taller, darker and more editorial than the frozen Bevel Home reference. H01–H05 must replace that composition with the compact date/status row, shared three-ring card, concise guidance, and Stress/Energy cards before Home can pass overlay acceptance.
