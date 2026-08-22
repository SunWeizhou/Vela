# Bevel 3.1.4 Reference Manifest

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 外部竞品视觉与状态参考（仅供灵感参考，不是当前需求来源）
> Capture date: 2026-07-31  
> Device: iPhone 16 Pro  
> Locale: Simplified Chinese  
> Appearance: Light  
> App state: Free tier, Recovery and Sleep unavailable on the captured day  
> Version basis: App Store reported 3.1.4 on the capture date. The in-app build number was not exposed in the accessible free-tier surfaces.

## R01 — Frozen Environment

| Field | Frozen value |
| --- | --- |
| Device | iPhone 16 Pro |
| Input | Apple Health / Apple Watch data already present on the device |
| Locale | zh-Hans |
| Theme | Light |
| Reference date | 2026-07-31 |
| Activity status | Active |
| Home data state | Strain available; Recovery and Sleep unavailable; Stress and Energy available |
| Biology state | Biological Age locked behind Pro; body metrics available |
| Intelligence state | Locked behind Pro paywall |
| Capture transport | iPhone Mirroring over the local device connection |

The reference is deliberately state-aware. A missing Recovery or Sleep value must remain a designed `--` state instead of being replaced by preview data.

## R02 — Captured Primary Surfaces

| Screen ID | Artifact | Important observations |
| --- | --- | --- |
| HOME.TOP | `R01-home-top-light-zh.png` | Date, share/profile pill, activity/weather pills, promotional banner, three score rings, one guidance block, Stress & Energy |
| JOURNAL.TOP | `R02-journal-top-light-zh.png` | Month context, seven-day strip, completion marks, Analyze and overflow controls, compact habit rows |
| FITNESS.TOP | `R02-fitness-top-light-zh.png` | 30-day context, two-month heat map, Activity Summary, Strain Performance |
| BIOLOGY.TOP | `R02-biology-top-light-zh.png` | Biological Age hero, Pro lock, metric rows with compact sparklines |
| ACTION.PANEL | `R02-action-panel-light-zh.png` | Bottom-trailing `+` expands a 3×3 action grid over a frosted surface |

## R03 — Captured States and Secondary Surfaces

| Screen ID | Artifact | State |
| --- | --- | --- |
| BIOLOGY.LOADING | `R03-biology-loading-light-zh.png` | Loading skeleton and progress copy |
| STRAIN.DETAIL | `R03-strain-detail-top-light-zh.png` | Complete metric state |
| STRESS.DETAIL | `R03-stress-detail-top-light-zh.png` | Complete intraday state |
| STRAIN.REVIEW | `R03-strain-review-prompt-light-zh.png` | In-product review prompt |
| SHARE.OVERVIEW | `R03-share-overview-light-zh.png` | Share sheet with metric filters and preview styles |
| INTELLIGENCE.PAYWALL | `R03-intelligence-paywall-light-zh.png` | Pro-locked state |

## R04 — Motion Evidence

| Interaction | Artifact | Observed behavior |
| --- | --- | --- |
| Tab navigation | `R04-tab-navigation-light-zh.mov` | Native glass selection target, short cross-surface transition, tab bar remains spatially anchored |
| Action panel | `R04-action-panel-motion-light-zh.mov` | The trailing `+` expands/collapses a frosted action surface anchored to its source |
| Capture smoke test | `R04-screen-capture-smoke.mov` | Verifies the reference recording pipeline and exact capture region |

Motion implementation requirements derived from the Apple design skill:

- Feedback begins on touch-down.
- Navigation and sheet motion starts from the current presentation value.
- Gesture-driven transitions remain interruptible.
- Default motion uses a critically damped spring.
- Momentum interactions may use restrained overshoot.
- Reduce Motion replaces large movement with a short cross-fade.

## R05 — Screen / Route / Data / State Matrix

Legend:

- `Captured`: direct evidence from the connected iPhone.
- `Official`: confirmed by current Bevel documentation.
- `Blocked`: inaccessible because the installed account is not Pro or the current day lacks data.

| Screen ID | Proposed Vela route | Primary data | Required states | Evidence |
| --- | --- | --- | --- | --- |
| HOME.TOP | `/home/:day` | Five Scored Health Evidence results, weather, activity status | full, partial, stale, historical | Captured |
| HOME.CALENDAR | `/home/calendar` | Daily summaries | month, selected day, no history | Official |
| RECOVERY.DETAIL | `/metric/recovery/:day` | Recovery evidence and Health Signals | full, partial, calibrating, unavailable | Blocked + Official |
| SLEEP.DETAIL | `/metric/sleep/:day` | Sleep session, stages, need and debt | full, partial, manual, unavailable | Blocked + Official |
| STRAIN.DETAIL | `/metric/strain/:day` | Active/passive strain and target | full, partial, no workout | Captured |
| STRESS.DETAIL | `/metric/stress/:day` | Intraday stress buckets | full, sparse, motion-excluded, stale | Captured |
| ENERGY.DETAIL | `/metric/energy/:day` | Intraday charge/drain buckets | full, sparse, predicted, unavailable | Official |
| JOURNAL.TODAY | `/journal/:day` | Auto/manual behavior tags | incomplete, complete, empty, historical | Captured |
| JOURNAL.INSIGHTS | `/journal/insights/:outcome` | Lagged correlations | insufficient sample, significant, neutral | Official |
| FITNESS.OVERVIEW | `/fitness` | Workout and load history | calibrating, active, empty | Captured |
| FITNESS.ACTIVITY | `/fitness/activity/:id` | Workout detail and zones | full, imported, incomplete | Official |
| STRENGTH.TEMPLATES | `/fitness/strength/templates` | Templates and exercise library | empty, populated, importing | Official |
| STRENGTH.LIVE | `/fitness/strength/live/:id` | Active session and Watch state | running, paused, disconnected, recovered | Official |
| NUTRITION.OVERVIEW | `/nutrition/:day` | Meals, score, goals, contributors | locked score, partial, complete | Official |
| NUTRITION.LOG | `/nutrition/log` | Search, photo, text, barcode | permission, processing, review, error | Captured action + Official |
| BIOLOGY.OVERVIEW | `/biology` | Biological Age and biomarkers | Pro lock, loading, partial, full | Captured |
| BIOMARKER.DETAIL | `/biology/biomarker/:id` | Signal history and source | full, sparse, stale, manual | Official |
| HEALTH_RECORDS | `/biology/records` | Documents and extracted biomarkers | empty, uploading, review, failed | Official |
| INTELLIGENCE.CHAT | `/intelligence/chat/:id` | Agent Fact Snapshot and tools | paywall, streaming, tool run, error | Captured lock + Official |
| INTELLIGENCE.FILES | `/intelligence/files` | Files, artifacts, plans, memories | empty, stale, fixed structure | Official |
| CHECKINS | `/intelligence/checkins` | Scheduled agent runs | empty, active, paused, failed | Official |
| ACTION.PANEL | modal | User-configured quick actions | default, customized, permission-blocked | Captured |
| SHARE | modal | Snapshot projection | metric selection, style, export | Captured |

## Evidence Gaps

The following direct captures remain unavailable without account/data changes and must not be fabricated:

- Recovery complete-data detail.
- Sleep complete-data detail and smart alarm.
- Energy full detail.
- Nutrition complete-day score and CGM detail.
- Biological Age unlocked report and Health Records.
- Intelligence chat, Files, Check-ins, Personality, Ghost Mode and model controls.
- Watch live strength workout.
- Dark mode equivalents.

Until direct evidence becomes available, implementation for these screens must use current official documentation and retain a review flag in the parity tracker.

## Official Reference Links

- Feature versions: <https://help.bevel.health/en/articles/11194113>
- Key terms: <https://help.bevel.health/en/articles/11251073>
- Intelligence capabilities: <https://help.bevel.health/en/articles/11586817>
- Membership matrix: <https://help.bevel.health/en/articles/11583937>
- App Store: <https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249>
