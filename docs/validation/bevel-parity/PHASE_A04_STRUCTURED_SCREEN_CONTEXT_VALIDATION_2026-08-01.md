# Phase A04 · Structured Screen Context · 2026-08-01

## Result

Coach entry context now has a stable Codable contract instead of relying only on localized prose:

- `surface`: stable route family such as `coach`, `metric_detail`, or `workout_detail`;
- `entityType`: stable semantic identifier such as `hrv`, `sleep`, or `workout`;
- `selectedDate`: ISO-8601 date when the originating page is date-specific.

The context is encoded with sorted keys and included in every Coach prompt path alongside the human-readable title and scope. Core metric detail pages and Workout Detail now supply structured context. The structure deliberately excludes visible health values; health facts continue through the consent-gated canonical fact snapshot.

## Files

- `VelaApp/Features/Coach/CoachChatVM.swift`
- `VelaApp/AI/Prompting/CoachPromptComposer.swift`
- `VelaApp/Features/Minimal/MetricCoachAdviceSection.swift`
- `VelaApp/Features/Training/WorkoutDetailView.swift`
- `VelaAppTests/AgentActionParserTests.swift`
- `VelaAppTests/VelaThemeTests.swift`

## Automated validation

- `testCoachScreenContextUsesStableStructuredIdentifiers`
- `testCoachPromptHonorsMetricEntryFocus`

Result: **2 passed, 0 failed**.

Result bundle:

`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-44-54-+0800.xcresult`

The first run failed only because the test expected escaped quote characters inside a Swift raw string. The assertion was corrected and the production implementation did not require a fallback.
