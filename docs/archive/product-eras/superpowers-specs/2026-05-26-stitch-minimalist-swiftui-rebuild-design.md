# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Stitch Minimalist SwiftUI Rebuild Design

## Context

The `stitch_vela_ios_26_liquid_glass/` folder contains a full HTML front-end concept for Vela. The pages are not visually consistent: some use the `unified_minimalist` language, some use an Apple-blue variant, and some are older tool/detail screens.

The target is to use `stitch_vela_ios_26_liquid_glass/vela_vitals_tab_minimalist/code.html` as the canonical visual reference, normalize the whole Stitch page set to that style, then rebuild the Vela app front end as native SwiftUI and switch the app to the new SwiftUI shell. Existing HealthKit, SwiftData, scoring, AI, persistence, and service layers stay intact.

## Source Pages

The implementation will treat every `code.html` under `stitch_vela_ios_26_liquid_glass/` as source material. Pages already named `*_unified_minimalist` can provide structure, but all colors, spacing, typography, glass surfaces, navigation, and hierarchy must be reconciled against `vela_vitals_tab_minimalist`.

Old or divergent variants, including apple-blue pages and non-minimalist detail pages, should contribute only product content and navigation intent. Their visual language should not be copied directly.

## Canonical Visual System

The SwiftUI rebuild will extract these rules from `Vela Vitals Tab(Minialist)`:

- Background: clean near-white surface with a subtle cool tint and restrained ambient glow.
- Primary color: clinical blue for app identity, active nav state, major values, and key icons.
- Status colors: iOS-like green, yellow, and red for confidence or health state.
- Surfaces: translucent glass panels with blur, white overlay, fine border, and very soft shadows.
- Radius: rounded-xl panels for normal cards, pill/capsule shapes for tab bar and status chips.
- Typography: rounded, high-weight numeric displays; compact uppercase labels; moderate body text.
- Navigation: compact top app bar with Vela centered, leading profile/control, trailing action.
- Bottom nav: floating capsule tab bar, not the current rectangular bottom inset bar.
- Content rhythm: large hero metric, bento metric grid, grouped record/action lists.

SwiftUI should approximate Manrope using system rounded typography unless a bundled font is added later. No web views should be used for the primary app UI.

## SwiftUI Architecture

Create a new native front-end layer rather than embedding the HTML:

- `VelaMinimalTheme`: tokens for colors, radii, spacing, shadows, typography, and semantic state colors.
- `VelaMinimalShell`: replacement root shell with top app bar, floating bottom nav, modal/sheet routing, and tab selection.
- Shared components: glass panel, hero metric, bento metric card, sleep architecture bar, metric row, record list row, action card, chip, and empty/pending states.
- Feature screens: SwiftUI pages mapped from the Stitch HTML source set.

The new layer should consume the existing `DashboardViewModel`, `VelaAppState`, repositories, scoring outputs, Coach routing, and HealthKit-derived summaries. Where a Stitch page shows static demo values, the SwiftUI version should bind to real Vela data when available and use consistent pending states when not available.

## Screen Map

Initial replacement scope:

- Today: dashboard status, body plan, next action, trends and data trust entry points.
- Vitals: canonical page based on `vela_vitals_tab_minimalist`, including biological age, sleep architecture, vitals grid, health records, and relevant detail navigation.
- Fitness: unified training/fitness pages, active workout, workout library, recovery/training cards.
- Journal: unified journal, meal log, and health data logging flows.
- Coach: unified coach page connected to existing `CoachView` and AI routing.

Secondary screens to translate under the same style:

- Health profile
- Stress analysis
- Sleep detail
- Sleep schedule
- Data history/history
- Trends/intelligence trends
- Goal setting
- Notifications

Existing detail views can be kept temporarily only when a replacement screen is not ready, but they should not remain wired as the final front-end.

## Data And Behavior

The rebuild must preserve current product behavior:

- Health refresh and trend loading from `DashboardViewModel`.
- Existing tab and coach routing from `VelaAppState`.
- Existing logging sheets for blood/weight/food or their replacement equivalents.
- Navigation to metric detail screens.
- Local-first storage and existing AI context behavior.
- Localization using `L10n.t` for user-visible text added to SwiftUI.

Static Stitch values are placeholders. They should be replaced with real values from `DashboardSummary`, recovery metrics, body metrics, sleep summary, strain metrics, workouts, journal records, and available persisted data. Missing values should render as `--`, "Building baseline", or a localized pending state.

## Migration Plan

Work in phases:

1. Extract and encode the minimalist design system in SwiftUI.
2. Build the new shell and bottom navigation without removing backend/service code.
3. Rebuild the Vitals tab first because it is the canonical style reference.
4. Rebuild Today, Fitness, Journal, and Coach using the same components.
5. Translate secondary pages and wire navigation.
6. Switch `VelaRootView` to the new shell.
7. Run Swift build/tests and a simulator/device visual smoke pass.

## Testing

Minimum verification:

- `xcodebuild` for the Vela scheme.
- Existing unit tests where practical.
- Manual smoke of every top-level tab.
- Manual smoke of primary navigation from Vitals, Fitness, Journal, and Coach.
- Check loading, empty, and no-Health-data states.
- Check small iPhone layout for text clipping, overlapping cards, and bottom tab safe area.

## Non-Goals

- Do not embed HTML or ship the Stitch pages as web views.
- Do not rewrite HealthKit, scoring, persistence, or AI services as part of the front-end switch.
- Do not preserve apple-blue or old liquid-glass variants as separate app themes.
- Do not add unrelated product features during the visual/front-end migration.
