# Vela Release-Candidate Acceptance Matrix

Date: 2026-09-01  
Scope: the current four-surface product candidate (Today, Trends, Plan, Coach)

## Release boundary

This milestone is a stabilization pass, not another product expansion. The release candidate keeps the five independent body-state domains (Recovery, Sleep, Strain, Stress, Energy), one short Agent interpretation, a user-owned editable Plan, and Coach follow-up. It does not add a total score, new nutrition scope, public rebranding, or a second navigation redesign.

## Automated gates

| Gate | Current result | Release requirement |
| --- | --- | --- |
| Unit and integration tests | 486/486 passed on iPhone 17 Pro, iOS 26.5 | No failures |
| Schema fingerprint | 32 live / 32 frozen V3 models | Match |
| Contrast guard | Passed; graphic-palette notices remain informational | Text colors pass 4.5:1 |
| Git whitespace validation | Passed | No errors |
| Primary UI smoke tests | 4/4 passed in accessibility XXXL + dark + increased contrast and Pro Max default configurations | Four tabs, Lived State, and key deep routes pass |
| Apple Watch verification | Watch source type-check passed against watchOS 26.5 SDK; runtime unavailable locally | Paired runtime pass before external beta |

Latest unit-test result bundle:

`/tmp/VelaUnitTests-RC-Final2-2026-09-01.xcresult`

Latest UI smoke-test result bundles:

`/tmp/VelaUITests-2026-09-01.xcresult`

`/tmp/VelaUITests-A11y-LivedState-Fixed-2026-09-01.xcresult`

`/tmp/VelaUITests-ProMax-Final-2026-09-01.xcresult`

## Surface and state matrix

Legend: **A** automated smoke coverage, **M** manual visual/interaction check, **R** required before external beta.

| Surface | Stable preview | Missing / baseline forming | Sync or error | Dark mode | Accessibility XXXL | VoiceOver / Reduce Motion |
| --- | --- | --- | --- | --- | --- | --- |
| Today | A, M | M, R | M, R | M | M | R |
| Trends | A, M | M, R | M, R | M | M | R |
| Plan | A, M | M, R | M, R | M | M | R |
| Coach | A, M | M | M, R | M | M | R |
| Lived State check-in | A, M | n/a | M, R | M | M | R |
| Settings | A, M | M | M, R | M | M | R |
| Trust Center | M | M | M | M | M | R |
| Five metric details | Recovery A; all M | M, R | M, R | M | M | R |
| Apple Watch snapshot | M, R | M, R | M, R | n/a | M | R |

The state rows are release requirements because a health product must remain truthful when data is partial. No screen may replace missing evidence with a fabricated score, imply a diagnosis, or silently turn an Agent suggestion into a confirmed plan change.

## Repeatable launch routes

Use these Debug launch arguments with `-vela_onboarding_completed YES`:

| Route | Arguments |
| --- | --- |
| Stable preview | `-velaPreviewDashboard -velaLegacyInterface` |
| Select primary tab | `-velaInitialTab 0|1|2|3` |
| Recovery detail | `-velaOpenRecoveryDetail` |
| Settings | `-velaOpenSettings` |
| Coach history | `-velaOpenCoachHistory` |
| Lived State check-in | `-velaOpenLivedStateCheckIn` |
| Trust Center | `-velaForceTrustCenter` |

The Watch target also supports `-velaWatchPreview`,
`-velaWatchPreviewStale`, and `-velaWatchPreviewMissing` for deterministic
fresh, stale, and unavailable score states once the watchOS runtime is installed.

## Device matrix

Before external beta, capture at least:

1. Compact iPhone and Pro Max, light and dark mode.
2. Default Dynamic Type and accessibility XXXL.
3. Reduce Motion enabled.
4. Increased Contrast enabled.
5. VoiceOver focus order for the hero, five domains, guidance, Plan confirmation, Coach composer, Settings, and Trust Center.
6. Apple Watch paired-device launch, stale snapshot, and missing snapshot.

Current visual pass completed on iPhone 17 Pro in light and dark mode, plus dark
mode with accessibility XXXL and Increased Contrast; the full smoke suite also
passes on iPhone 17 Pro Max at default settings. Shared navigation chrome remains
bounded while scrollable content honors the user's full Dynamic Type size;
Trends, Plan, Today calibration, and Lived State controls reflow instead of
truncating.

## Exit criteria

- All automated gates pass from a clean build.
- There are no P0/P1 failures in the matrix.
- Today communicates the three emphasized domains without hiding access to all five.
- Guidance is concise and Agent-phrased; scores remain primary.
- Missing, stale, syncing, error, and baseline-forming states are visually distinct and truthful.
- Agent-proposed Plan changes require explicit user confirmation and remain editable afterward.
- Coach history, new conversation, keyboard, and return-to-tab flows work without overlap.
- Watch values use the same canonical score meanings as iPhone.
- Untracked visual experiments and the intentionally removed validation screenshot receive an explicit keep/archive/delete decision before release commit.
