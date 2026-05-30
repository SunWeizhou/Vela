# Bevel Parity Gap Tracker

> Updated: 2026-05-30
> Purpose: concrete page-by-page parity tracker for turning Vela from a Bevel-like shell into a Bevel-class daily health product.

## Root Cause

The previous UI pass mainly changed global theme, Home layout, and tab labels. That made Vela look closer on the first screen, but most non-Home screens still use Vela's old product model:

- Journal is a free-form AI context logger, while Bevel Journal is a daily checklist/habit log with date navigation and measurable entries.
- Fitness is now an aggregate activity surface, but workout/detail drilldowns still need richer parity.
- Vitals is now a broader health-monitor surface, but every listed metric still needs a consistent single-metric drilldown.
- `+` has now moved to a separate glass action target that opens an action-hub first screen, but deeper artifact/file workflows still need richer Bevel-like treatment.
- Sleep has now moved off the generic detail scaffold into a Bevel-like sleep panel; other secondary pages still need the same treatment.

## Current Reference Observations

Observed through iPhone Mirroring on 2026-05-24:

### Bevel Home
- Date header with share/avatar controls.
- Activity/weather chips.
- Three top rings for strain, recovery, and sleep.
- Stress and energy card.
- Nutrition card.
- Bottom tabs: Home, Journal, Fitness, Vitals/Biology, plus.

### Bevel Journal
- Header: Journal and month context.
- Horizontal week/date selector.
- Top-right Analyze and more actions.
- "Today's entries" section.
- Repeated habit rows such as low carbohydrate, caffeine, mood, added sugar, raw diet, hydration.
- Rows use icons, labels, compact value controls, and a trailing action.

### Bevel Fitness
- Header: Fitness, last 30 days, plus action.
- Two-month calendar heatmap.
- Activity summary card.
- Strain/performance trend cards.
- Primary interaction is scan-and-drill, not a single daily strain gauge.

### Bevel Vitals / Biology
- Vitals/Biology is broader than Recovery.
- Metric surfaces include biological age, body metrics, trends, and single-metric drilldowns.
- Drilldown pages use a large value, line chart, range selector, and trend analysis card.

## Parity Workstreams

### P0: Navigation and Shell
- Keep Home / Journal / Fitness / Vitals / `+`.
- Done: the app now uses the native SwiftUI `TabView`, allowing iOS 26 to provide the system Liquid Glass tab bar behavior. The terracotta `+` remains a separate right-side action target.
- Done first pass: `+` opens the Vela Intelligence extension hub instead of switching to a fifth Coach tab.
- Done first pass: bottom transition black flash is addressed by restoring translucent system material behavior and keeping the custom shell inside the safe-area inset.
- Done first pass: global forced light/dark overrides were removed and core theme tokens now adapt to iOS light/dark mode.
- Product rule: bottom tabs are aggregate product surfaces; Home cards and metric rows push into single-metric detail pages.
- Next: verify all secondary screens reserve enough bottom safe area under the glass shell on the connected iPhone.

### P1: Journal
- Done first pass: current free-form-first layout now starts with a Bevel-style daily entry board.
- Done first pass: horizontal date strip.
- Done first pass: "Today entries" habit rows with icons and compact value affordances.
- Done first pass: "Recent records" now groups entries by day and shows a compact daily summary instead of dumping every conversation/note row.
- Keep free-form note as a lower section because it supports Vela's Wiki/Agent memory.
- Preserve existing `JournalEntryRecord`; add a presentation layer for daily checklist items before adding new persistence.

### P1: Fitness
- Done first pass: top of Fitness is now a 35-cell/30-day activity heatmap, not a strain gauge.
- Done first pass: current strain arc moved into a secondary "strain performance" card.
- Done first pass: activity summary uses historical `DailyHealthSummaryRecord` fields for active days, workout time, workout count, and active energy.
- Done first pass: Activity Summary chevron now opens a real 30-day Activity detail page with load total, daily activity chart, activity factors, and AI analysis action.
- Done first pass: recovery-adjusted target range is now a training readiness card in the Fitness feed.
- Done first pass: Home Strain card now routes to a Bevel-like Strain metric drilldown with large value, 7D/30D trend, target zone, load factors, and action guidance.
- Done first pass: Home's primary Strain, Recovery, Sleep, Stress, Energy, and Nutrition-looking cards now have real routes instead of acting as static visual replicas.
- Next: add drilldown interactions and richer workout progression history.

### P1: Vitals
- Done first pass: page semantics now read as Health Monitor/Vitals instead of Recovery detail.
- Done first pass: top section lists core vitals including recovery, HRV, RHR, sleep HR, respiratory rate, blood oxygen, weight/body composition, VO2 Max, and health age trend.
- Done first pass: Recovery ring is now a secondary recovery signals card instead of the whole page.
- Done first pass: Biology card links into the existing Biology dashboard.
- Done first pass: Home Recovery/readiness cards now route to a Bevel-like Recovery metric drilldown with large value, 7D/30D trend, baseline ranges, driver analysis, and action guidance.
- Done first pass: Vitals rows for HRV, resting heart rate, sleep heart rate, respiratory rate, blood oxygen, and weight now push into Bevel-like single-metric detail pages.
- Done first pass: HRV, resting heart rate, respiratory rate, blood oxygen, and weight detail pages can load saved 30-day trend data from `DailyHealthSummaryRecord`.
- Done first pass: the Vitals biological-age Hero now consumes `BiologicalAgeEngine` output and renders a pending state when real inputs are missing instead of using a fixed age delta.
- Done first pass: missing Vitals values now render as `--` with neutral sparklines instead of demo HRV, RHR, weight, and body-fat values.
- Next: add biological-age confidence, freshness, missing-input explanations, weekly trend persistence, and contributor chips.
- Next: apply the same drilldown pattern to VO2 Max, body fat, BMI, stress, energy, health age, and biological age biomarkers.

### P1: `+` Intelligence
- Done first pass: plus entry is now action-hub-first instead of empty-chat-first.
- Done first pass: top actions include ask Vela, analyze today, update Wiki, and generate plan.
- Done first pass: Wiki status, saved AI artifacts, proactive check-ins, personality controls, and quick prompts are visible on the first screen.
- Done first pass: metric detail action cards now show an Apple Intelligence-like live analysis strip and route the latest metric context into Vela Intelligence.
- Next: add a true log-entry action, richer artifact cards, and file/check-in drilldowns.

### P2: Secondary Pages
- Done first pass: Sleep now uses a dedicated Bevel-like sleep panel with score, time asleep, sleep debt, efficiency, stage distribution/timeline, and 7-day trend.
- Done first pass: Training is now a dedicated adaptive plan workspace instead of a Strain/Calendar split; it opens with training readiness, plan actions, and native calendar cards.
- Biology: connect biological age, biomarkers, body metrics, and confidence.
- Settings/Wiki: keep Vela-specific, but use the same light card shell.

## Bug Classes To Track

- Fixed: shared metric detail navigation controls were embedded in the scrollable Hero card. They now stay in a fixed header above the card.
- Visual: invisible low-opacity white strokes on light backgrounds.
- Visual: dark-mode variants need real-device visual QA beyond the adaptive token foundation.
- Layout: controls hidden behind tab bar.
- Interaction: Home cards that look tappable but route to the wrong place or do nothing.
- Interaction: non-Home cards that look tappable still need a full audit; use the same single-metric detail route pattern wherever possible.
- Interaction: modal/detail routes should not unexpectedly switch bottom tabs unless the destination is the `+` Intelligence workspace.
- Semantics: tab label says Fitness/Vitals but page content says Strain/Recovery.
- Data: pages expose raw component scores instead of Bevel-like user-facing metrics.
- Data: historical Fitness now has a view-model history layer, but old summary records may not contain exercise minutes before the new snapshot fields exist.
- AI: `+` action hub exists, but generated artifacts still need more native, editable surfaces.

## Verification Checklist

- Run full simulator tests after every functional change.
- Install on the connected iPhone after each page-level UI milestone when `devicectl` reports the iPhone as available.
- Use simulator visual smoke testing when the physical iPhone is unavailable.
- Capture iPhone Mirroring reference for Bevel and Vela.
- For each page, compare:
  - first-screen hierarchy;
  - primary metric;
  - secondary cards;
  - bottom tab overlap;
  - missing/empty data state;
  - tap targets and route behavior.
