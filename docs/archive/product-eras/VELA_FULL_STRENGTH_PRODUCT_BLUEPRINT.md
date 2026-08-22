# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela Full-Strength Product Blueprint

> Updated: 2026-05-25  
> Viewpoint: senior product, design, engineering, data, and AI team plan for taking the current Vela build to a complete Bevel 3.0-class product.

## 1. Product Thesis

Vela should become a private AI health operating system, not only a fitness dashboard.

The current app already has the hard foundations: HealthKit data, scoring engines, SwiftData persistence, AI chat, report generation, proactive agents, Wiki files, training plan records, food photo analysis, biological age, and notification scaffolding. The remaining work is to turn those capabilities into a coherent daily product loop.

The product loop:

1. Morning: "What is my state, and what should I do today?"
2. Daytime: "How is strain, stress, food, and energy changing?"
3. Training: "What session fits today's recovery and long-term goal?"
4. Evening: "What did we learn, and what should Vela remember?"
5. Weekly: "What patterns are real enough to change behavior?"

## 2. Positioning

### One Sentence

Vela is a local-first AI health coach that turns Apple Watch and personal context into daily readiness, training, sleep, recovery, biology, and life-pattern guidance.

### Differentiation Against Bevel

Bevel's 3.0 advantage is product completeness and polished AI packaging. Vela's advantage must be user-owned memory and local-first transparency:

- user-readable Wiki instead of opaque memory;
- local SwiftData history and baselines;
- explicit source and confidence on every recommendation;
- agent actions that can be inspected and reversed;
- user-configurable LLM provider instead of a locked cloud coach.

## 3. North Star Experience

The first screen should be a cockpit, not a report page.

The Home screen must answer, in order:

1. **State:** recovery, sleep, strain, energy, stress, and confidence.
2. **Cause:** the two or three strongest factors behind the state.
3. **Plan:** one recommended training/recovery/nutrition action.
4. **Watch:** one risk or opportunity Vela is tracking today.
5. **Memory:** whether anything should be written to the Wiki.

The Coach screen must become **Vela Intelligence**:

- chat remains available;
- proactive check-ins are first-class;
- Wiki/Files are visible;
- generated artifacts render inline;
- plans and reminders become actionable cards.

## 4. Current Build State

### Working Foundation

- SwiftUI iOS app with Bevel-like Home, Journal, Fitness, Vitals, Sleep, and `+` Intelligence surfaces.
- Apple-like glass bottom navigation shell with Home, Journal, Fitness, Vitals inside the main material capsule and a separate right-side circular `+` target.
- HealthKit authorization and multi-domain queries.
- SwiftData records for summaries, reports, journal, biomarkers, coach sessions, and training plans.
- Sleep, Recovery, Strain, Stress, Energy Bank, Health Age, and Biological Age engines.
- Local user Wiki under `agent/user_wiki`.
- Evening Wiki sync agent and Morning Brief scheduler.
- Coach chat with personalities, sessions, streaming, quick prompts, tool scaffolding, and a `+` Intelligence action hub.
- Food photo analyzer and food log tool.
- Web search service and agent tool wrapper.
- Training workspace and calendar view.
- Biology view with manual lab result entry.
- Notification service for morning brief, bedtime, abnormal metrics, and check-ins.

### Verified On 2026-05-25

- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug` succeeds.
- Real-device Debug build, install, and launch succeeded on Weizhou's iPhone 16 Pro through `devicectl`.
- Bottom shell now uses translucent system material behavior, preventing the black bottom flash seen during page switching while preserving the iOS glass look.
- Forced app-wide light/dark scheme overrides are removed; shared theme tokens now provide the foundation for iOS light and dark mode.
- The `+` target opens Vela Intelligence as an extension hub, not a fifth tab or direct empty Coach conversation.
- Home's primary visible cards now route to real destinations: Strain, Recovery, Sleep, Stress, Energy, and a compact Nutrition summary.
- Journal recent records now summarize entries by day instead of listing every raw conversation/note row.
- Metric detail action cards now expose live AI analysis with an Apple Intelligence-like marquee before routing latest metric context to Vela Intelligence.
- Home Strain now opens a dedicated Strain metric drilldown with a large value, 7D/30D trend chart, target zone, load factors, and action card.
- Home Recovery/readiness now opens a dedicated Recovery metric drilldown with a large value, 7D/30D trend chart, baseline range bars, driver analysis, and action card.
- Vitals rows for HRV, resting heart rate, sleep heart rate, respiratory rate, blood oxygen, and weight now open single-metric detail pages instead of behaving like static list rows.
- Historical Vitals detail trends use saved `DailyHealthSummaryRecord` fields where available.

### Verified On 2026-05-24

- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug` succeeds.
- Simulator visual smoke test shows the rebuilt Fitness page rendering: 30-day heatmap, activity summary, strain performance, and training readiness.
- The `+` entry now renders as Vela Intelligence: action hub, Wiki status, generated artifacts, proactive check-ins, personality controls, and quick prompts before chat.
- Sleep now renders as a dedicated sleep panel: score, time asleep, bedtime/wake pills, sleep debt, efficiency, stage distribution/timeline, and 7-day trend.
- Training now renders as an adaptive plan workspace: readiness window, plan generation/adjustment actions, and native calendar cards instead of duplicating the Strain detail page.
- iPhone Mirroring was used for Bevel reference inspection; the physical iPhone was unavailable to `devicectl` during the 2026-05-24 install attempt.
- Bevel is also installed and was inspected for UI/product comparison.

### Main Experience Gaps

- `+` has been reframed as the Intelligence entry, but the deeper workspace still needs richer file, artifact editing, and check-in drilldown behavior.
- Home now has a Bevel-like first screen; Journal, Fitness, Vitals, and Sleep have begun moving from old Vela detail pages into Bevel-style product surfaces.
- True 1:1 parity still requires repeated real-device screenshot comparison after each install.
- The user Wiki is a core differentiator but is not prominent enough in daily flows.
- Training plans exist as records and UI, but should become adaptive plan artifacts with calendar-native behavior.
- Biology exists, but Health Records ingestion and biomarker confidence are not complete.
- Food photo analysis exists, but editable portions, confidence, and nutrition history are not mature.
- Background task scheduling remains partially implemented and needs real device validation.

## 5. Information Architecture

Current recommended tab structure for the personal Bevel-like build:

1. **Home**
   - readiness cockpit;
   - daily plan;
   - Nutrition summary when data exists;
   - AI insights;
   - score cards;
   - quick access to generated artifacts.

2. **Journal**
   - Bevel-style daily date strip;
   - "Today's entries" checklist rows for low carb, caffeine, mood, sugar, raw diet, and hydration;
   - free-form notes and daily summarized recent records below the checklist;
   - tag correlations;
   - nutrition records only as a passive context surface until Nutrition productization resumes.

3. **Fitness**
   - 30-day activity heatmap;
   - activity summary;
   - strain performance trend;
   - recovery-adjusted training readiness;
   - training calendar;
   - strength templates.

4. **Vitals**
   - Health Monitor summary;
   - recovery as one signal card;
   - HRV/RHR baseline rows;
   - sleep-linked physiology;
   - blood oxygen and body metrics;
   - biological age trend and biomarkers as drill-down cards;
   - confidence and freshness.
   - Single-metric drilldowns for HRV, RHR, sleep HR, respiratory rate, blood oxygen, and weight.

5. **`+` Intelligence**
   - action hub before chat;
   - check-ins;
   - Wiki memory;
   - artifacts;
   - agent tools;
   - settings shortcuts.

Sleep, Recovery, Stress, Energy, Biology, and Training remain first-class modules, but the bottom tab should follow the daily Bevel-like workflow rather than one tab per score. Sleep and Training now have first secondary-page passes; Biology needs the same native drilldown polish next.

Navigation rule:

- bottom tabs are persistent aggregate workspaces;
- Home score cards open single-metric drilldowns instead of jumping to aggregate tabs;
- the `+` target is a separate bottom-shell extension action and the fastest route into Vela Intelligence actions;
- detail pages should use a consistent Bevel-like pattern: large current value, time range selector, trend chart, baseline/target context, driver analysis, and one recommended action.
- every card that visually reads as tappable must either navigate to a detail page or be restyled as static information.

## 6. Core User Stories

### Daily Readiness

As a user, I open Vela in the morning and immediately know whether to train, recover, or maintain. I can see the reason in under 10 seconds.

Acceptance:

- top card has score, band, confidence, and 2 drivers;
- daily plan is a single action card;
- missing data is explained without looking broken.

### Private Memory

As a user, I can see what Vela knows about me, edit it, and understand when the agent changed it.

Acceptance:

- Intelligence has a Wiki/Memory section;
- each file has last-updated timestamp;
- agent-written changes are logged in AIReportRecord;
- user can manually edit and refresh.

### Adaptive Training

As a user, I can ask for a plan and receive a calendar that adapts to recovery, strain, schedule, equipment, and goals.

Acceptance:

- generated plan is stored as `TrainingPlanRecord`;
- visible calendar cards show sessions, target strain, and status;
- missed workouts can be shifted;
- daily recommendations reference the plan.

### Biology and Records

As a user, I can enter blood biomarkers and health documents, and Vela explains what is driving biological age.

Acceptance:

- manual biomarker entry works;
- factors are grouped into wearable and lab;
- confidence reflects missing/stale data;
- no medical diagnosis language.

### Food and Nutrition

As a user, I can take a food photo, edit the estimate, and let Vela learn patterns without pretending the estimate is exact.

Acceptance:

- identified items are editable;
- portions and macros are editable;
- confidence is shown;
- meal is saved to Journal/nutrition history;
- AI advice is tied to recovery/training goals.

## 7. Design Direction

Vela should now default to a Bevel-like adaptive identity: soft gray/white surfaces in light mode, deep neutral surfaces in dark mode, restrained type, subtle shadows, compact chips, and strong metric colors only where they encode health state.

Design principles:

- one dominant object per screen;
- rings/arcs only where they clarify status;
- cards should not all look equal;
- avoid dashboard clutter above the fold;
- use confidence/freshness badges consistently;
- make AI messages concise and action-led;
- show generated artifacts as UI, not markdown when possible.
- remove old dark-card remnants unless they are an intentional dark-mode variant;
- route all colors through shared adaptive theme tokens before building more page variants.

Home layout target:

1. compact top system line: sync state, date, source;
2. readiness hero with Recovery as primary and Sleep/Strain/Energy as compact companions;
3. Today's Plan card;
4. Today's AI Insights carousel;
5. score cards and trend cards below.

Intelligence layout target:

1. top personality/check-in controls;
2. current proactive insight;
3. quick actions: ask, generate plan, update Wiki, analyze food only after Nutrition resumes;
4. artifacts/files feed;
5. chat thread.

## 8. Engineering Architecture

Keep the existing layered architecture, but formalize five product domains:

1. **Health Domain**
   - HealthKit query service;
   - normalization;
   - daily context;
   - data freshness.

2. **Scoring Domain**
   - score engines;
   - confidence;
   - factor explanations;
   - personal baselines.

3. **Memory Domain**
   - Wiki file service;
   - baseline markdown;
   - agent action parser;
   - audit log.

4. **Intelligence Domain**
   - provider abstraction;
   - context builder;
   - tools;
   - artifacts;
   - proactive schedulers.

5. **Experience Domain**
   - DashboardViewModel;
   - Home/Training/Biology/Intelligence surfaces;
   - notification handling;
   - empty and degraded states.

## 9. Data Model Roadmap

Already present:

- `DailyHealthSummaryRecord`
- `SleepSummaryRecord`
- `JournalEntryRecord`
- `AIReportRecord`
- coach sessions/messages
- biomarker records
- training plan records

Needed next:

- `FoodLogRecord`: items, macros, confidence, source image metadata.
- `HealthRecordDocument`: local file reference, parsed text summary, biomarker extraction status.
- `AgentArtifactRecord`: chart/table/plan/reminder/wiki-diff payload.
- `CheckInRecord`: scheduled proactive insight, state, notification status.
- `WikiChangeRecord`: file, diff summary, agent/user source, timestamp.

## 10. AI Product Rules

The agent must:

- answer with conclusion, evidence, recommendation;
- use personal baselines before population norms;
- show uncertainty;
- avoid diagnosis;
- never hide data gaps;
- write to Wiki only for stable patterns or explicit user preferences;
- create UI artifacts for plans and charts instead of dumping markdown;
- keep casual answers short.

## 11. Roadmap

### Phase A: Documentation and Product Alignment

- update PRD, architecture, AI spec, and gap analysis to current build;
- import Bevel 3.0 research;
- define Vela full-strength product principles.

### Phase B: Intelligence Workspace

- rename/reframe Coach as Intelligence in product copy where appropriate;
- add Memory/Wiki surface to Coach landing;
- render generated training plan and correlation artifacts as cards;
- create visible check-in schedule status.

### Phase C: Home Cockpit Polish

- keep the first viewport in Bevel order: primary rings, Stress/Energy, Nutrition, then AI insights;
- add confidence/data freshness row;
- ensure every visible Home card has a route or a disabled/static visual treatment;
- make daily plan and AI analysis the default next actions.

### Phase D: Adaptive Training

- complete `TrainingPlanRecord` UX;
- add missed workout reschedule;
- connect plan state to daily plan and Coach tools.

### Phase E: Biology and Records

- add biomarker freshness/confidence;
- add health record file metadata and parse pipeline;
- keep medical disclaimers in-context, not intrusive.

### Phase F: Nutrition

- turn food photo result into editable sheet;
- save to structured record;
- connect nutrition to recovery/sleep/journal correlations.

### Phase G: Device Validation

- install on iPhone;
- test HealthKit authorization, background refresh, notifications, Coach streaming, Wiki sync, food photo, training plan, Biology entry.

## 12. Quality Bar

Vela is "full-strength" when:

- it builds cleanly without warnings;
- first launch and HealthKit permission states are polished;
- Home gives useful guidance in 10 seconds;
- Intelligence can answer, remember, schedule, and generate artifacts;
- Wiki changes are inspectable;
- training plans render as plans, not chat blobs;
- Biology shows confidence and avoids overclaiming;
- no core tab has overlapping or clipped UI on the connected iPhone;
- all critical flows work with missing data.
