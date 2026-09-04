# BodySeek Today PR3 Closure Contract

Status: proposed follow-up contract
Base: `004b8280`
Authority: `bodyseek-today-pr3-contract.md`

This document closes the remaining PR3 boundary work identified by the final
challenge. It does not change scoring formulas, SwiftData schema, deployment
targets, visual design, Watch behaviour, or the BodySeekDomain package.

## Exit condition

`VelaMinimalTodayView` is a state/action renderer for Today data. It may retain
downstream compatibility adapters for sheets that still require SwiftData
records, but those adapters cannot be the source of dashboard state. Every
Today data read is a value in `TodayViewState`; every Today write is a
`TodayStoreAction` handled by an injected `TodayEffectRouter`.

The exact static guard remains:

```sh
rg -n 'import (SwiftData|HealthKit)|ModelContext|FetchDescriptor|@Query|@AppStorage|UserDefaults\.standard|VelaResolver\.shared|VelaAppState\.shared|LocationManager\.shared|WeatherService\.shared|HealthKitQueryService\(|\.shared|modelContext' \
  VelaApp/Features/Today \
  VelaApp/Features/Minimal/VelaMinimalTodayView.swift \
  VelaApp/Features/Minimal/VelaTodayViewData.swift
```

In addition, a root-specific audit must report zero direct reads of
`DashboardViewModel` data except an explicitly named downstream sheet adapter.

## Follow-up slices and ownership

### C1 — Read-model completion

Owner paths: `VelaServices.swift`, `TodayViewState.swift`,
`TodayLegacyCompatibility.swift`, Today state tests.

Add value-only projections for active/pending plan display, feedback summary,
coverage, and weather status where a stable source exists. SwiftData records
remain inside the compatibility reader and are converted before crossing the
TodayStore boundary. Missing coverage/weather/nutrition remains unavailable;
no zero or default target may represent missing evidence.

Exit: projection tests preserve values and explicit missing semantics; no
`@Model` type appears in `TodayDashboardSnapshot` or `TodayViewState`.

### C2 — Effect ownership

Owner paths: `TodayStoreAction.swift`, `TodayLegacyCompatibility.swift`,
`VelaMinimalShell.swift`, Today root/effect tests.

Extend the injected effect router for weather refresh, check-in persistence,
feedback persistence, and local-data revision notification. Root code dispatches
one action and does not also call a legacy route/write method. Local sheet
presentation can remain a root concern, but persistence/navigation effects must
be observable through the router.

Exit: effect spy tests prove exactly one call per intent, including failures;
the Shell supplies the production adapter and previews supply NoOp/fakes.

### C3 — Selected-day ownership

Owner paths: `TodayStoreAction.swift`, `VelaMinimalShell.swift`,
`VelaMinimalTodayView.swift`, compatibility date adapter tests.

`TodayStore.state.selectedDay` is the Today source of truth. DashboardViewModel
may receive a compatibility mirror for downstream screens, but Today must not
read it to decide which day to load. Calendar selection sends `.selectDay` to
the Store; date races continue to use generation checks.

Exit: date selection tests cover today, historical day, future rejection, and
old-result suppression without reading DashboardViewModel.selectedDate.

### C4 — Root adapter reduction

Owner paths: `VelaMinimalTodayView.swift`,
`TodayLegacyCompatibility.swift`, root UI tests.

Replace direct plan/feedback/coverage/lived-state reads with state projections.
If a downstream component still requires a SwiftData record, isolate the
conversion and environment injection in a named adapter function. Do not
rewrite Plan/Coach/Metric detail in this slice.

Exit: root-specific audit is clean except documented adapter calls; no direct
VM record controls the five-score dashboard or Today loading phase.

## Ordering and parallelism

1. C1 establishes DTO fields and fixture semantics.
2. C2 and C3 may proceed in parallel after C1 because their owned paths are
   disjoint; both depend on the existing Store/action contract.
3. C4 integrates the projections and effects at the root.
4. A two-axis challenge reruns the static guard, standards review, and spec
   review. Only then may ARCH-04/05/06 implementation begin.

No slice may edit `PersistenceModels.swift`, `VelaModelContainer.swift`, score
kernels, BodySeekDomain, Watch bridge, or visual redesign files outside the
listed root adapter paths.

## Required handoff evidence

Each slice reports base SHA, changed paths, DTO/interface impact, exact focused
tests, strict generic build, full-suite result when root wiring changes,
`schema_fingerprint.py --check`, `git diff --check`, static guard output, known
P1/P2 residuals, and the next dependent slice. The orchestrator updates the
ignored control-plane ledger and does not mark PR3 integrated until C4 and the
challenge both pass.
