# Vela Figma Make Integration

This directory contains the complete React/Vite source exported from the
Figma Make file `iOS Fitness App Design` on 2026-06-09.

It is a design reference and runnable web prototype. The production Vela app
is a native SwiftUI application, so these files must not replace files under
`VelaApp/`.

## Run the exported prototype

```bash
cd design/figma-make
pnpm install
pnpm dev
```

Production verification:

```bash
pnpm build
```

## Source mapping

| Figma Make source | Native Vela destination |
| --- | --- |
| `src/styles/theme.css` | `VelaApp/Core/Theme/VelaTheme.swift` |
| `src/app/components/ui/Card.tsx` | `VelaApp/Core/DesignSystem/VelaDesignSystem.swift` |
| `src/app/components/ui/NavBar.tsx` | Native `NavigationStack` and toolbar components |
| `src/app/components/ui/Section.tsx` | `SettingsGroup`, `SettingsRow`, and card primitives |
| `src/app/components/nav/TabBar.tsx` | `VelaApp/Features/Minimal/VelaMinimalShell.swift` |
| `src/app/pages/Home.tsx` | `VelaApp/Features/Minimal/VelaMinimalTodayView.swift` |
| `src/app/pages/Journal.tsx` | `VelaApp/Features/Minimal/VelaMinimalJournalView.swift` |
| `src/app/pages/Fitness.tsx` | `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift` |
| `src/app/pages/Vitals.tsx` | `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift` |
| `src/app/pages/CoachHub.tsx` | Coach entry surface in `VelaApp/Features/Coach/` |
| `src/app/pages/CoachChat.tsx` | `VelaApp/Features/Coach/CoachView.swift` and `CoachChatPanel.swift` |
| `src/app/pages/MetricDetail.tsx` | `VelaApp/Features/Recovery/VitalsMetricDetailView.swift` |
| `src/app/pages/Wiki.tsx` | `VelaApp/Features/Coach/WikiProfileView.swift` |
| `src/app/pages/WikiFile.tsx` | `WikiFileService` backed native editor |
| `src/app/pages/Algorithms.tsx` | Native scoring transparency views backed by `VelaApp/Scoring/` |
| `src/app/pages/Biomarkers.tsx` | `VelaApp/Features/Settings/BiologyView.swift` |
| `src/app/pages/TrainingPlan.tsx` | `VelaApp/Features/Training/` and `TrainingIntelligence/` |

## Integration rules

1. Keep HealthKit and scoring data in the existing native data pipeline.
2. Treat `src/app/data/mock.ts` as visual sample data only.
3. Map CSS tokens to `VelaTheme`; do not hard-code web colors in SwiftUI pages.
4. Reuse `VelaDesignSystem` components before adding new SwiftUI primitives.
5. Preserve local-first privacy: raw HealthKit data stays on device.
6. Implement pages incrementally and verify each one with the native build.

## Export compatibility note

The Make archive contains both `ui/card.tsx` and `ui/Card.tsx`. macOS commonly
uses a case-insensitive filesystem, so the generic shadcn file is preserved as
`ui/shadcn-card.tsx`, while the Vela-specific component remains `ui/card.tsx`.
The current exported app imports the Vela-specific component.
