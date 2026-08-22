# Bevel 3.1.4 Observed Visual Tokens

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 外部竞品设计 Token 观察参考（仅供灵感参考，不是当前需求来源）

## Layout

| Token | Initial target | Notes |
| --- | ---: | --- |
| Page horizontal inset | 20 pt | Primary cards and headings share this edge |
| Compact card inset | 12–14 pt | Metric rows and compact summaries |
| Section gap | 22–28 pt | Separates product concepts |
| Card gap | 10–14 pt | Related cards within a section |
| Inline gap | 6–10 pt | Icons, labels and values |
| Bottom content clearance | 104 pt | Content must remain clear of the glass tab bar |
| Minimum hit target | 44 pt | Applies even when visible glyph is smaller |

## Shape

| Token | Initial target | Use |
| --- | ---: | --- |
| Primary card radius | 20–24 pt | Home score card, summaries |
| Secondary card radius | 16–20 pt | Metric rows and supporting cards |
| Pill radius | capsule | Status, weather, filters, ranges |
| Sheet radius | 28–34 pt | Large bottom sheets |
| Circular control | 40–48 pt | Close, more, share and add controls |

## Typography

Use the system font and Dynamic Type. Hard-coded sizes are visual starting points only.

| Role | Initial target | Behavior |
| --- | --- | --- |
| Page title | 24–28 pt, semibold/bold | Slight negative tracking |
| Metric hero value | 40–56 pt, semibold | Tabular figures |
| Card value | 24–34 pt, semibold | Tabular figures |
| Section title | 18–20 pt, semibold | Short and direct |
| Body | 15–17 pt, regular/medium | Comfortable leading |
| Supporting label | 12–14 pt, medium | Must retain contrast over material |
| Micro label | 10–12 pt, medium | Avoid for essential meaning |

## Color Semantics

Exact color values must be sampled and tuned through screenshot overlays.

| Domain | Observed family | Meaning |
| --- | --- | --- |
| Strain | yellow → orange → red | Accumulated load and target range |
| Recovery | lime → green | Readiness |
| Sleep | blue → violet | Sleep quality |
| Stress | green → yellow → orange/red | Increasing physiological stress |
| Energy | red/orange → yellow → green | Remaining body energy |
| Positive trend | blue/green | Improving relative to baseline |
| Attention | orange | Needs attention without alarm |
| Critical | red | High concern or exceeded boundary |

Rules:

- Color communicates metric meaning, never decoration alone.
- Every semantic color also has a text label or icon.
- Normal states use restrained saturation.
- Background light is environmental and low contrast.

## Material and Depth

- Page backgrounds use warm near-white with faint blue, violet or peach environmental light.
- Primary cards are opaque or nearly opaque to protect health-data legibility.
- Floating navigation, action panels and sheets use adaptive material.
- Avoid stacking multiple translucent cards.
- Large sheets use stronger blur and separation than compact pills.
- Use a soft scroll-edge treatment instead of permanent hard dividers.
- Reduce Transparency replaces glass with a high-opacity system surface and clear border.

## Score Ring Contract

- A score ring contains value, label, track, semantic progress and optional target segment.
- Missing data keeps the ring geometry but removes semantic progress and shows `--`.
- Three core rings share a single card and equal geometry.
- Ring animation begins only after real data is available.
- VoiceOver reads metric, value, direction, confidence and data state as one element.
- Strain can visually exceed its normal target without clamping away the overload meaning.

## Charts

- Time ranges use compact pills.
- Current selection uses a vertical cursor and anchored value label.
- Baseline/average is visually secondary to the primary series.
- Target ranges use translucent bands rather than opaque blocks.
- Sparse data stays sparse; do not interpolate across missing periods without disclosure.
- Intraday Stress and Energy require real time buckets.
- Historical charts support full, sparse, calibrating, unavailable and stale states.

## Motion

| Interaction | Target |
| --- | --- |
| Press feedback | Begins on touch-down; scale approximately 0.98 |
| Default state transition | Critically damped spring, response 0.3–0.4 s |
| Sheet / drawer | Damping around 0.8 only when gesture momentum exists |
| Tab selection | Short anchored material transition |
| Metric detail | Symmetric push/pop path |
| Action panel | Origin anchored to bottom-trailing `+` |
| Reduce Motion | 150–220 ms cross-fade, no large translation |

All gesture-driven motion must be interruptible and continue from the current presentation value.

## Acceptance

For every implemented screen:

1. Capture the same device, locale, appearance and data state.
2. Mask time, avatar and live values.
3. Overlay against the frozen reference.
4. Keep key geometry within 2 pt.
5. Keep major static-area pixel difference near or below 5%.
6. Verify default and accessibility text sizes.
7. Verify light, dark, Reduce Motion and Reduce Transparency.
