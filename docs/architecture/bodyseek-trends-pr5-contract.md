# BodySeek Trends PR5 bounded contract

Status: integrated seam at `21d9e7d7`; legacy host migration remains a follow-up.

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

The source and test files are registered in `Vela.xcodeproj` by
`21d9e7d7`. The slice intentionally does not replace the legacy
`VelaTrendsView`; wiring that host to `TrendsStore` and `TrendsOneMetricChart`
is a separate migration task so this seam can remain behavior-preserving and
non-overlapping with dashboard work.
