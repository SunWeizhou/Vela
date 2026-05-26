# Vela 2.1 Claude.ai Experience System

## Product Definition
Vela is a premium iOS body intelligence agent. It reads Apple Health and Apple Watch data, interprets the user's body state, explains why the body is ready or fatigued, recommends training and recovery actions, adapts training plans, learns personal health patterns, and keeps an auditable trust log.

## Visual Direction
Claude.ai-inspired, Apple-native, calm clinical warmth. Use warm paper neutrals, precise dark ink, quiet borders, spacious editorial hierarchy, and restrained semantic accents. Avoid generic fitness dashboards, neon-heavy UI, gamification, social fitness styling, sci-fi panels, and noisy gradients. Balance the warm Claude feel with Vela's clinical health semantics using sage, blue, mauve, amber, and clay accents.

## Brand Principles
- Calm intelligence: Vela should feel like a thoughtful health agent, not a dashboard full of widgets.
- Evidence first: every recommendation should have a visible reasoning path.
- User control: memory and adaptations ask for confirmation before changing plans or knowledge.
- Native trust: every surface must work in iOS light/dark mode, Dynamic Type, Chinese and English.
- Low-noise precision: show the most important body state, limiter, action, confidence, and audit details without clutter.

## Color System
Light mode: warm paper background #F7F1E6, secondary parchment #EFE6D8, surface #FFFDF8, elevated paper #FBF7EE, border #DED2C1, primary ink #2B241B, secondary ink #665B4B, muted ink #918576. Primary action clay #B76445. Vela trust sage #5F8C73. Sleep indigo #6F73A8. Energy amber #B9842E. Stress rose #A95665. Strain copper #B86B4B.
Dark mode: espresso black #17130F, warm surface #211B16, elevated #2A231C, border #40362D, primary parchment #F4EBDD, secondary parchment #CDBFAE, muted #9E907F. Primary action clay #D08462. Keep semantic colors saturated enough for contrast but never neon.

## Typography
Use native iOS SF Pro semantics. Large editorial headers with `.largeTitle`/`.title2` weight semibold or bold. Body copy should be readable at `.subheadline` or `.body`; essential content never below `.caption`. Metric labels can use `.caption2` only as secondary labels. Use monospaced digits for scores, durations, counts, HRV, sleep, and training load.

## Spacing And Radius
Use 20pt screen padding, 16pt section spacing, 12pt local grouping, 8pt micro spacing. Cards use 18-20pt radius. Hero surfaces use 24-26pt radius. Buttons and pills use capsule radius. Do not use floating cards inside cards.

## Surface Hierarchy
Screen background is warm paper. Hero surfaces are warm elevated paper with subtle radial/linear tint and a hairline border. Cards are solid paper surfaces with warm border, minimal shadow, and generous whitespace. Inline alerts use tinted parchment, not saturated banners.

## Component Rules
- Body state hero: large state sentence, readiness score/ring, limiter, training window, confidence, risk flags.
- Evidence chain: vertical timeline with metric, current vs baseline, trend, interpretation, action impact, confidence, freshness, source.
- Adaptive training: banner must show original session, suggested adjustment, reason, alternative, accept/keep/ignore.
- Memory proposal: pattern, memory type, evidence, confidence, source agent, target file/area, accept/reject/edit if supported.
- Trust log: readable audit card with run type, status, timestamps, duration, hashes, tool calls, outputs, errors.
- Coach: proactive command center with today's context, quick commands, findings, and composer; not a generic chatbot.

## Icons And Charts
SF Symbols only. Icons are small, functional, and paired with text for clarity. Rings/progress should be thin, semantic, and not decorative. Do not rely on color alone.

## Motion
Use subtle native spring expansion for card details and sheet transitions. Avoid animated spectacle. State changes should feel immediate and trustworthy.

## Localization And Accessibility
Chinese and English must both fit. Avoid uppercase-only critical text in Chinese-heavy areas. Do not hardcode English production UI. Dynamic Type must not overflow horizontally. Touch targets are at least 44pt. Contrast must pass in light and dark.

## Screen Hierarchy
Home: Body Intelligence Cockpit. Why This: reasoning timeline. Training: adaptive plan workspace. Memory: confirmation inbox. Data Coverage: reliability and missing-data map. Trust Center: agent audit log. Coach: proactive command center. Settings: navigation to trust/data/wiki/health/training/app controls.
