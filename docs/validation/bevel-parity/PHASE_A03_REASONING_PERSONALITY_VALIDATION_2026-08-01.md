# Phase A03 · Reasoning Modes & Personality · 2026-08-01

## Verified behavior

- `Fast` always selects the low-latency Flash model.
- `Thinking` always selects the Pro model.
- `Adaptive` selects Flash for casual/focused questions and Pro for full analysis.
- `CoachRequestRunner` applies that choice to the provider used for the actual request; the setting is not cosmetic.
- The four Coach personalities are persisted locally and injected into every prompt composition path.
- Personality changes tone and presentation only. Each directive retains explicit diagnosis, safety, sustainability, or non-coercion boundaries and cannot override tool-returned health facts.

## Automated validation

- `testCoachReasoningModesSelectExpectedModels`
- `testCoachPersonalitiesHaveDistinctDirectivesWithoutOverridingSafety`

Result: **2 passed, 0 failed**.

Result bundle:

`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-37-54-+0800.xcresult`

## Visual validation

Settings UI exists under Coach model and personality settings. Device screenshot capture remains pending while the Mac login session is locked; no screenshot is claimed here.
