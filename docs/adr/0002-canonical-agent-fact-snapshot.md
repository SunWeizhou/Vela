# ADR 0002: Canonical Agent Fact Snapshot

- Status: Accepted
- Date: 2026-07-11

## Context

Morning reports, evening sync, and Coach previously assembled overlapping health facts independently. Their time windows, available records, ordering, localization, and hashes could differ, so the same user state could produce inconsistent Agent conclusions or false context changes.

## Decision

Use `AgentFactSnapshot` as the locale-neutral fact projection for AI workflows.

- `AgentFactInputLoader` is the shared SwiftData boundary. It applies one 35-day history window, deterministic ordering, and common limits for journals and reports.
- Builders receive an explicit `generatedAt`/`asOf` value. They do not read the current time while mapping metrics.
- The semantic `contentHash` uses sorted JSON keys and excludes snapshot creation time and the hash field itself.
- `CoachCompactContextAdapter` renders the compact localized Coach view and preserves the safety statement and hash under its character budget.
- `LegacyReportContextAdapter` owns the frozen v1 dictionary envelope until report prompts and persisted snapshots can move to a versioned v2 report adapter.
- Feature-entry focus is a separate prompt concern. It may prioritize a metric or workout scope but must not mutate canonical facts.

## Consequences

- Morning, evening, and Coach observe the same persisted evidence.
- Locale and prompt formatting changes no longer alter the underlying health facts.
- Identical semantic inputs produce identical hashes, reducing duplicate Agent work and improving traceability.
- Legacy report fields remain supported behind an explicit compatibility seam.
- New AI workflows must consume `AgentFactSnapshot` and add an adapter instead of building a new fact dictionary.

## Verification

- Characterization tests freeze v1 key sets and no-data semantics.
- Hash tests cover creation-time and dictionary-order independence plus health-signal changes.
- Adapter tests cover deterministic trend ordering, budget enforcement, safety text, and context hash retention.
- Prompt tests cover propagation of metric-entry focus.
