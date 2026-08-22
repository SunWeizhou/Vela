# 0011. Share one Daily Intelligence Assembly Module across daily adapters

## Status
Accepted

## Context

`DailySummaryUseCase.loadDashboard` and `SecondaryDataAssembler.assemble` both
assembled Body State, Personal Health Brief, and downstream Training Decision.
Keeping those rules in two adapters allowed selected-day time semantics,
persisted decision validation, and Brief-to-decision ordering to drift.

## Decision

Both adapters cross the `DailyIntelligenceAssemblyModule` Interface with value-
typed facts and explicit selected day, calendar, and active status. Each Adapter
uses its wall-clock evaluation time to resolve the selected-day active status
before crossing the Seam. The Module's deterministic Implementation owns the
sequence Body State → Personal Health Brief → Training Decision and persisted
body-state hash validation. HealthKit/SwiftData fetches, DTO conversion, persistence, and
other side effects remain in the adapters.

The Personal Health Brief remains the canonical product projection; Training
Decision is only its downstream consumer. UI and Agent callers do not recompute
either projection.
