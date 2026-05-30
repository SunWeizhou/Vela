# Frontend Freeze and Backend Alignment

> Effective date: 2026-05-30

## Frontend Rule

The current Vela visual direction is **OFFICIALLY FROZEN** as the absolute system standard. All future development, additions, or integrations **MUST PRESERVE and strictly build upon** the existing premium visual architecture. Do not redesign the core design system, overhaul page compositions, or deviate from the established aesthetic.

### Locked Core Visual Standards:
- **Warm Canvas & Solid Cockpit Cards**: A warm off-white `#F5F3F0` background canvas hosting premium solid white rounded cards with delicate shadows (`Color.black.opacity(0.03)`).
- **Corrected Bevel Score Rings**: 3-ring side-by-side dashboard rings (Strain, Recovery, Sleep) rendered with modern iOS `.gradient` fills to bypass rotated stroke clipping bugs, with progress indicator dots perfectly centered at radius `(size - 6.5) / 2`.
- **Unified Shell Navigation ("玻璃胶囊导航 + 右侧独立玻璃圆形 +" 并排布局)**:
  - The root shell uses a custom floating `ZStack` switcher, completely bypassing the native system `TabView` to avoid overlapping double bars and navigation lag.
  - A side-by-side floating `HStack` consists of a 4-tab glass capsule dock ("首页", "手记", "健身", "体征") and an independent circular glass "+" button on the right.
  - Both elements dynamically adopt iOS 26 native interactive glass materials (`.velaInteractiveGlass` mapping to `.glassEffect(.regular.interactive())` when compiled on iOS 26).
  - Selected states must slide seamlessly using `.matchedGeometryEffect` spring animation (`response: 0.35, dampingFraction: 0.78`).

### Incremental-Only Modification Policy:
- **No Redesigns**: Do not introduce alternative color palettes, change default rounded corner radii, alter spacing tokens, or modify the navigation model.
- **Append-Only and Hook-ups**: Future visual updates are restricted strictly to:
  - Hooking up dynamic HealthKit/SwiftData repositories to currently static metrics.
  - Adding micro-interactions (e.g. haptic feedbacks, hover responses, or skeleton loading shimmers).
  - Adjusting safe-area edge paddings or ScrollView bottom margins (e.g. keeping ScrollView bottom padding at `140` to guarantee nutrition card clearance).
  - Enhancing details views (`VelaMetricDetailView` / `VelaMinimalComponents.swift`) without modifying the Today page's primary cockpit card layout.

## Data Contract Rule

Static Stitch values are reference content, not production data. A visible number must come from HealthKit, SwiftData, a scoring engine, or an explicit user record. When data is unavailable, render `--`, a pending state, or a data-coverage explanation. Do not silently substitute demo numbers.

## Priority Alignment Work

### P0: Shared metric details

- Keep the metric navigation header outside the scrollable Hero card.
- Replace hard-coded values, guidance, limiting factors, and trend rows in `VelaMetricDetailView` with `DashboardSummary` and persisted history.
- Show data freshness and missing-signal states.

### P0: Biological age

- Use `BiologicalAgeEngine` for the Vitals Hero instead of fixed age deltas.
- Remove fallback physiology assumptions from the Biology dashboard.
- Add confidence, freshness, missing inputs, contributor chips, and persisted weekly trend.
- Frame biological age as a wellness proxy, not a medical conclusion.

### P0: Coach agent

- Continue maintaining both the user profile Wiki and one JSON-rich daily Wiki file per day.
- Let Coach decide whether conversational information belongs in the durable profile Wiki, the daily Wiki only, or neither.
- Make real dashboard data, freshness, missing signals, and biological-age context available to Coach tools.
- Add auditable memory updates, proactive daily summary generation, and session continuity tests.

### P1: Remaining surfaces

- Audit Today, Journal, Training, and Vitals for demo values.
- Replace placeholder charts with persisted history or a clear pending state.
- Add backend alignment tests around every visible score and metric.

