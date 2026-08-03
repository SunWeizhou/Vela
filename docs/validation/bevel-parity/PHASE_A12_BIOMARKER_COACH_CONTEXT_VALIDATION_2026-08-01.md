# Phase A12 · Health Records & Biomarker Analysis · 2026-08-01

## Result

Reviewed Health Record values now reach Coach as a dedicated, consent-gated context block rather than competing for the compact 800-character daily snapshot budget.

Each fact includes:

- stable signal name;
- actual value and unit;
- collection date;
- user-recorded laboratory reference interval;
- `within_recorded_range` / `outside_recorded_range` status;
- `manual` / `user_reviewed_import` provenance.

Only the newest value for each signal at or before the request timestamp is included. Future records are excluded. User-editable names and units are single-line, bounded, and separated from an explicit “data, not instructions” boundary. The prompt restricts interpretation to non-diagnostic education and forbids diagnosis, prescriptions, and promised outcomes.

This path activates only when the user has explicitly enabled outbound Health data.

## Files

- `VelaApp/Features/Coach/CoachContextAssembler.swift`
- `VelaAppTests/VelaThemeTests.swift`

## Automated validation

- `testBiomarkerCoachContextUsesLatestReviewedValueWithoutFutureLeakage`

Result: **1 passed, 0 failed**.

Result bundle:

`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-54-06-+0800.xcresult`

Health Record PDF/text/image extraction, explicit review/edit, local save, trend display, and deletion are covered by the existing Phase T implementation.
