# Vela Bevel 3.0 Parity Design

Date: 2026-05-25
Owner: Codex autonomous implementation
Scope: Vela iOS SwiftUI app

## Boundary

The goal is Bevel 3.0-class parity for personal use: the same daily health loop, information architecture, interaction quality, and feature completeness. Vela must not copy Bevel trademarks, proprietary assets, private algorithms, or branded copy. Vela keeps its own name, logo, local-first architecture, user Wiki, transparent scoring, and configurable model providers.

Public Bevel 3.0 references used for this design:

- Bevel 3.0 feature availability: Intelligence V2, Biological Age, and Health Records.
- Bevel Biological Age confidence model: freshness, completeness, missing/stale inputs, and weekly biological age framing.
- Bevel membership docs: free tracking core plus Pro-style Intelligence, Health Records, and Biological Age value pillars.
- Bevel social sharing docs: shareable metric cards with customization.
- Local repository research: `docs/BEVEL_3_RESEARCH.md`, `docs/BEVEL_PARITY_GAP_TRACKER.md`, `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md`, and `docs/PRD.md`.

## Chosen Approach

Three approaches were considered:

1. Big-bang rewrite into a new Bevel-like app shell.
   - Pros: fastest visual reset.
   - Cons: high risk to existing HealthKit, SwiftData, AI, and scoring code.

2. Autonomous phased parity over the existing architecture.
   - Pros: preserves working engines, reduces regression risk, allows device QA after each page-level milestone.
   - Cons: takes multiple milestones to reach full parity.

3. Feature-first backend expansion before visual parity.
   - Pros: improves long-term capability.
   - Cons: delays the user's explicit UI/UX target and leaves existing capability hidden.

Chosen: phased parity over the existing architecture. Vela already has most hard foundations. The work should convert existing capabilities into Bevel-class product surfaces instead of replacing them.

## Product Architecture

The bottom navigation remains:

- Home
- Journal
- Fitness
- Vitals
- separate `+` Intelligence action

Home, Journal, Fitness, and Vitals are persistent aggregate surfaces. `+` opens Vela Intelligence as an extension workspace. Sleep, Recovery, Strain, Stress, Energy, Biology, Training, Nutrition, Health Records, and sharing are secondary modules entered from cards, rows, and actions.

Every tappable-looking card must navigate, mutate state, or be restyled as static. Detail pages share one pattern:

- large current value;
- date or range context;
- 7D/30D trend;
- baseline or target range;
- drivers/factors;
- confidence or freshness where relevant;
- one concrete action;
- optional Intelligence analysis entry.

## Screen Designs

### Home

Home must answer within the first screen:

- how am I today;
- why;
- what should I do next;
- what is Vela watching;
- whether the data is fresh enough to trust.

Target structure:

1. compact header with date, sync/data freshness, share/profile actions;
2. activity/weather/data chips;
3. three primary rings: Strain, Recovery, Sleep;
4. concise coach guidance;
5. stress and energy module;
6. nutrition summary when available;
7. AI insight carousel and generated artifacts below the fold;
8. customizable lower cards only after the primary daily loop.

Home should feel light, soft, scan-first, and restrained. Metric colors are accents, not page backgrounds.

### Journal

Journal is a daily board first, not a free-form note app.

Target structure:

- month/header context;
- horizontal week/date selector;
- Analyze and more actions;
- Today's entries habit rows with icons, labels, compact value controls, and trailing action;
- recent daily summaries;
- nutrition logs as contextual entries;
- free-form note and tag correlation below the daily board.

Journal records can initially reuse `JournalEntryRecord`; new persistence is added only when a daily checklist value cannot be represented cleanly.

### Fitness

Fitness is the 30-day activity and training surface.

Target structure:

- 30-day activity heatmap;
- activity summary card;
- strain performance trend;
- cardio/load/readiness cards;
- workout list and progression history;
- training plan workspace and calendar cards;
- AI-generated plan actions that create or update structured plan records.

AI plan output must not remain markdown-only. It must become editable calendar/workout artifacts.

### Vitals and Biology

Vitals is the health monitor surface. Recovery is one signal inside it, not the whole tab.

Target structure:

- biological age or health trend hero with confidence;
- core vitals list: HRV, RHR, sleep HR, respiratory rate, blood oxygen, weight/body composition, VO2 Max, stress, energy;
- single-metric drilldowns for every row;
- Biology dashboard with wearable, lifestyle, and lab contributors;
- manual biomarker entry;
- Health Records metadata and local document ingestion roadmap;
- confidence banner showing missing, stale, calibrating, or up-to-date inputs.

Medical language must stay wellness-oriented and avoid diagnosis claims.

### Intelligence

The `+` action opens Vela Intelligence. It is an action workspace first and chat second.

Target structure:

- personality/check-in controls;
- proactive status card;
- primary actions: ask, analyze today, update Wiki, generate plan, log food, add health record;
- Wiki/Files section with file status, last update, and diff/audit entry points;
- artifacts feed for reports, charts, food logs, plans, and records;
- concise chat thread with structured tool results;
- safe settings shortcuts for model keys and agent permissions.

Vela's differentiator is visible memory: user-readable Wiki, agent-written changes, and local audit trail.

### Nutrition

Nutrition should match the Bevel 3.0 expectation of fast logging while being honest about estimates.

Target structure:

- food photo/text/manual entry from Intelligence and Journal;
- editable items, portion, macros, meal time, and confidence;
- saved FoodLog history;
- Nutrition score/quality summary on Home;
- recovery/training-aware advice;
- clear estimate labels.

### Health Records

Health Records starts local-first:

- manual document metadata record;
- import/photo entry point wired to local file selection when available;
- biomarker extraction roadmap;
- Biology integration through manual biomarker records first;
- Intelligence can reference records only when user has imported or entered them.

### Sharing and Polish

Add shareable Vela cards after core screens are stable:

- Overview, Recovery/Sleep/Strain, Stress/Energy, Nutrition, Biological Age;
- light/dark styles;
- privacy preview;
- save/share image through native iOS share sheet.

Microinteractions should be subtle: pressed states, small ring animation, card transitions, loading skeletons, and no distracting decorative effects.

## Design System

Use existing `VelaTheme` tokens but converge on:

- adaptive light-first neutral background;
- white or material surfaces;
- 18-24 pt card radii for major cards, 10-16 pt for rows/chips;
- thin adaptive strokes;
- restrained shadows;
- rounded SF typography;
- compact chips and icon rows;
- semantic metric colors for sleep, strain, recovery, stress, energy, and biology.

Dark mode must be a true adaptive variant, not old dark-dashboard leftovers.

## Data Flow

HealthKit and SwiftData remain the source of structured health state:

HealthKit -> HealthKitQueryService -> DashboardSummary -> scoring engines -> UI view models -> AIContextBuilder -> Intelligence actions.

SwiftData stores:

- daily summaries;
- journal entries;
- food logs;
- AI reports/artifacts;
- coach sessions;
- biomarker records;
- training plans;
- future health record metadata.

AI should receive structured summaries and explicit user Wiki context. AI output that represents a plan, food log, record, or artifact must be parsed into local UI objects when possible.

## Error Handling and Empty States

Every primary surface needs mature empty states:

- missing HealthKit permission;
- calibrating baseline;
- stale data;
- no sleep data;
- no workouts;
- no biomarkers;
- missing API key;
- AI request failure;
- offline or model unavailable.

Empty states should explain the next action and avoid looking broken.

## Testing and QA

For every milestone:

- run Swift tests if project compiles in the local environment;
- run an iOS build with code signing disabled for simulator/generic device when possible;
- inspect changed pages in simulator or connected device;
- verify no bottom safe-area overlap;
- verify light and dark adaptive tokens;
- verify tappable-looking cards route correctly;
- verify no medical overclaim language.

Device QA should compare the current Vela screen against the current Bevel reference when available, but implementation must not depend on private Bevel assets.

## Milestones

### Milestone 1: Home and Shell Parity

- tighten Home first viewport into the Bevel 3.0 daily loop;
- add data freshness/confidence;
- add share/profile affordances;
- remove duplicated lower cards above the fold;
- audit bottom safe area and tappable routes.

### Milestone 2: Intelligence Workspace

- make `+` action hub richer and more structured;
- promote Wiki/Files and artifacts;
- add health record and food logging actions;
- add visible agent audit trail entry points.

### Milestone 3: Vitals and Biology Completion

- add remaining metric drilldowns;
- add biological age confidence and missing/stale inputs;
- add health record metadata scaffolding;
- connect biomarkers more visibly.

### Milestone 4: Fitness and Training Completion

- add workout list/progression history;
- make AI training plans editable calendar artifacts;
- improve training readiness and missed-session adaptation.

### Milestone 5: Journal and Nutrition Completion

- persist daily checklist values where needed;
- make food logs editable;
- add nutrition score/quality summary and trends.

### Milestone 6: Sharing, Customization, and Polish

- build share card preview and native share flow;
- add card customization;
- complete visual QA across major screens.

## Acceptance Criteria

Vela reaches the parity target when:

- the primary Home, Journal, Fitness, Vitals, and Intelligence screens visually read as one coherent product;
- the first Home viewport answers state, cause, action, confidence;
- every visible core metric has a detail route;
- Intelligence can create or surface structured artifacts, not only chat text;
- biological age/records/nutrition/training have visible product surfaces;
- changed screens build and pass available tests;
- no Bevel trademark, branded asset, or proprietary copy is embedded in Vela.
