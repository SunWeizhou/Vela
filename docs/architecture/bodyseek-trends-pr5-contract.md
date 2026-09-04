# BodySeek Trends PR5 bounded contract

Status: implementation slice, pending host wiring and challenge review.

## Scope

PR5 introduces a value-only `TrendsStore` seam for one selected metric and one
Swift Charts renderer. The history adapter supplies snapshots, the canonical
`HealthTrendFinding` (when available), an optional personal baseline band, and
per-day provenance. The store does not load SwiftData, call HealthKit, or alter
the existing `HealthTrendEngine` formulas.

## State and actions

`TrendsViewState` owns the selected health day, horizon, metric, load phase,
one `TrendsMetricSeries`, and an optional selected chart point. `TrendsStore`
accepts `appear`, `retry`, day/horizon/metric selection, and point selection
actions. `TrendsHistoryProviding` is the only input seam.

## Rendering invariants

- The series contains one value slot per calendar day in the selected horizon.
  A missing snapshot or missing metric value remains `nil`; it is never changed
  to zero or interpolated.
- `nonMissingSegments` splits the series at every missing slot. A line chart
  may connect points only within one segment, preserving visible gaps.
- A personal baseline band is rendered only when the adapter explicitly
  supplies one. The store does not infer population thresholds or widen a band.
- Point provenance is carried through to the selected point for a downstream
  drill-down. Source labels are adapter-owned and never guessed from values.
- The metric mapping is a direct field projection from `DailyHealthSnapshot`;
  no scoring, aggregation, or formula change is part of PR5.

## Integration boundary

The new files are intentionally not registered in `Vela.xcodeproj` in this
bounded worker slice because the project file is shared by ARCH-04 and ARCH-06.
The orchestrator must register the source and test files in one integration
commit, then run the target focused tests and full suite. Until that happens,
the standalone source parse and diff checks below are the available evidence.
