# Frontend Freeze and Backend Alignment

> Effective date: 2026-05-30
> Last reviewed: 2026-06-02

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

## Priority Alignment Work — Current Status (2026-06-02)

### P0: Shared metric details ✅ DONE
- ✅ Metric navigation header outside scrollable Hero card.
- ✅ Hard-coded values replaced with DashboardSummary history.
- ✅ Data freshness and missing-signal states shown (via HealthSignalCoverageService).

### P0: Biological age ✅ DONE
- ✅ BiologicalAgeEngine used for Vitals Hero.
- ✅ Fallback physiology assumptions removed.
- ✅ Pending state rendered when real inputs are missing.
- ⚠️ Confidence, freshness, missing-input explanations, contributor chips — partial, needs verification.
- ⚠️ Persisted weekly trend — pending.

### P0: Coach agent ✅ IN PROGRESS
- ✅ User profile Wiki + daily Wiki files maintained.
- ✅ Coach decides conversational memory placement (profile vs daily vs neither).
- ✅ Real dashboard data, freshness, missing signals available to Coach tools.
- ✅ Keyboard behavior improved: tap/scroll dismiss, keyboard-aware padding, "完成" button removed.
- ✅ MarkdownText paragraph spacing fixed with per-paragraph VStack rendering.
- ✅ StrengthTrainingContext available in default Coach context.
- ⚠️ PersonalResponseInsight weekly report generation — service exists, integration status TBD.
- ⚠️ Auditable memory updates and session continuity tests — partial.

### P1: Remaining surfaces
- ✅ Today: no remaining demo values.
- ✅ Journal: Bevel-style daily entry board with habit rows.
- ✅ Training: heatmap, activity summary, strain trend, strength log sheet, adaptive plan workspace.
- ✅ Vitals: metric drilldown pages for HRV/RHR/SpO2/Weight with 30-day trend data.
- ⚠️ VO2 Max, body fat, BMI drilldowns — need verification.
- ✅ Backend alignment tests around every visible score — 100% test pass rate maintained.

