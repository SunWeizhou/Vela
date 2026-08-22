# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Native Glass Navigation and Adaptive Theme Design

## Goal

Improve Vela's iPhone navigation polish by removing the misaligned bottom quick-action button, adding restrained content transitions, changing the light canvas to Apple-style white, and making the touched navigation and quick-action surfaces follow the system dark appearance.

## Scope

- Keep the four primary destinations: Today, Training, Vitals, and Coach.
- Remove the quick-action `+` from the bottom navigation.
- Apply the theme update to shared theme tokens, the bottom navigation, and the quick-action sheet chain touched by the `+` flow.
- Preserve the existing iOS 17 and iOS 18 compatibility navigation.
- Preserve the iOS 26 system Tab Bar minimization behavior.

This change does not add a manual appearance setting and does not redesign every feature screen.

## Navigation Design

On iOS 26, the four destination tabs remain in a native `TabView` with `.tabBarMinimizeBehavior(.onScrollDown)`. The bottom navigation does not render a quick-action `+`. This preserves the system Tab Bar alignment and its native scroll minimization animation without introducing a selectable pseudo-tab or a misaligned overlay.

The existing quick-action sheet remains available to existing App Shortcut and internal routing flows.

On iOS 17 and iOS 18, retain the custom floating capsule navigation without a quick-action `+`, and update its colors to adaptive theme tokens.

## Transition Design

Primary destination changes use a restrained opacity transition of approximately `0.18` seconds. Do not add horizontal paging, drag gestures, or large spring motion. The system Tab Bar remains responsible for its own selection and minimization animations.

## Theme Design

Vela follows the iPhone system appearance automatically.

Light appearance:

- Main background: pure white.
- Grouped and elevated surfaces: subtle Apple-style neutral grays.
- Cards: white or lightly separated neutral surfaces.
- Text and borders: adaptive semantic tokens.

Dark appearance:

- Main background: system-like black.
- Grouped and elevated surfaces: layered dark neutral surfaces.
- Cards, text, borders, and controls: adaptive semantic tokens with readable contrast.

Replace touched hard-coded warm canvas colors and fixed black or white foreground colors in the quick-action flow with theme tokens. Preserve semantic accent colors unless contrast requires an adaptive alias.

## Testing

Add regression coverage for:

- The iOS 26 destination list contains exactly four content tabs and excludes quick actions.
- Selecting a content tab still updates the selected destination.
- Theme background tokens resolve to white in light appearance and black in dark appearance.
- Quick-action sheet surfaces use adaptive theme tokens rather than fixed warm canvas colors.

Run targeted tests, the full simulator test suite, a signed device build, and install the result on the connected iPhone.
