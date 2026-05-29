# Vela 2.1 Experience System Redesign

Source of truth: Stitch project `6103385464676727977`, design system asset `assets/12061632509050072099`, generated through the official Stitch MCP workflow and downloaded under `StitchExports/Vela21Claude/`.

## 1. Brand Principles

Vela is a premium iOS body intelligence agent. It helps users understand their body, decide how to train or recover today, and learn what works for them over time. The experience must feel calm, precise, trustworthy, premium, personal, intelligent, low-noise, and clinical but warm.

The interface should make three ideas visible on every major screen: what Vela believes, why Vela believes it, and what the user can control.

## 2. Visual Personality

Use a Claude.ai-inspired warm editorial vocabulary translated into native iOS: warm paper backgrounds, precise ink typography, quiet rounded paper cards, clay primary actions, sage/indigo/amber/rose semantic accents, generous scan paths, and concise status language. The result should still feel Apple-native and clinical, not like a web chat product.

Avoid generic gym-app energy, social feeds, neon-heavy panels, sci-fi dashboards, random gradient cards, one-note beige/brown theming, emojis as status primitives, and fake medical diagnosis language.

## 3. Color System

- Canvas: Stitch warm paper `#F7F1E6` in light mode, espresso `#17130F` in dark mode.
- Secondary canvas: parchment `#EFE6D8` and warm dark surface `#211B16`.
- Surface: elevated paper `#FFFDF8` / `#211B16`.
- Elevated surface: warm ivory `#FBF7EE` / `#2A231C`.
- Stroke: warm hairline `#DED2C1` / `#40362D`.
- Primary text: ink `#2B241B` / parchment `#F4EBDD`.
- Secondary text: `#665B4B` / `#CDBFAE`.
- Muted text: `#918576` / `#9E907F`, never used for critical actions.
- Accent: Claude-style clay `#B76445` / `#D08462` for primary actions, active navigation, and Vela agent cues.
- Recovery: sage `#5F8C73`, used for restored capacity and safe improvement.
- Sleep: indigo `#6F73A8`, used only for sleep and circadian context.
- Strain: copper `#B86B4B`, used for training load and high physical demand.
- Stress: rose `#A95665`, used for sympathetic load and mental stress.
- Energy: amber `#B9842E`, used for readiness, confidence, and high-value opportunities.
- Risk: warning uses coral/rose with an icon and label, never color alone.

## 4. Typography Scale

Use native San Francisco through SwiftUI system fonts. Stitch used Public Sans as the generated web-code proxy; SwiftUI translates that intent into SF Pro with editorial spacing, semibold headers, readable body text, and monospaced digits for health metrics. Body text must support Dynamic Type.

- Display: large title, semibold/bold, for top page state only.
- Title: title2/title3, semibold, for hero modules and screen sections.
- Body: body/subheadline, regular or semibold, for explanations.
- Label: caption, semibold, for badges and metric labels.
- Technical metadata: caption, monospaced digit where useful, never below caption2 for essential content.

## 5. Spacing Scale

Use 4 pt increments. Primary screen padding is 20 pt. Card internal padding is 14-20 pt. Dense rows use 10-12 pt vertical padding. Important tap targets are at least 44 pt tall.

## 6. Radius Scale

- Screen hero: 26 pt.
- Primary card: 20 pt.
- Compact card: 16 pt.
- Row/tile: 14 pt.
- Chips and badges: capsule.

## 7. Surface Hierarchy

VelaScreen owns the adaptive warm paper background and scroll layout. VelaHeroSurface is reserved for the first major state module and should feel like elevated paper, not glass. VelaGlassCard is a compatibility name for repeated paper data blocks. Inline controls should not be nested in additional cards unless they are independent repeated items.

## 8. Shadow And Elevation

Use soft shadows only on hero and elevated cards. Dark mode relies more on strokes and tonal separation than heavy shadows. Hairline borders are adaptive and subtle.

## 9. Metric Color Semantics

Body state is summarized with a state label plus a semantic accent. Recovery, sleep, strain, stress, and energy keep stable color identities across every screen. Confidence uses green/amber/coral buckets. Data freshness uses live/today/recent/stale/missing labels with icons.

## 10. Iconography Rules

Use SF Symbols only. Icons support scanning but never replace labels for meaning. Use filled symbols for high-confidence status, outline/secondary symbols for metadata.

## 11. Chart, Ring, And Progress Rules

Rings communicate overall body/readiness states only. Progress bars communicate completion or coverage. Avoid chart clutter; every visualization needs a nearby plain-language interpretation.

## 12. Motion Rules

Use native spring animations for expansion, selection, and accept/ignore transitions. Avoid continuous decorative motion. Motion should clarify hierarchy or state changes.

## 13. Empty, Loading, And Error States

Empty states must tell the user what is missing, why it matters, and the next action. Loading states use ProgressView with a short label. Error states preserve technical transparency but lead with the user-level impact.

## 14. Accessibility Rules

Support Dynamic Type, avoid tiny essential text, maintain contrast in light/dark mode, use 44 pt tap areas, provide accessibility labels for rings and visual-only state, and never rely on color alone.

## 15. Chinese And English Layout Rules

All text must use existing localization patterns: `L10n.t(...)` or `AppLanguage.stored.isChinese`. Chinese labels may be longer; cards and badges must wrap or scale safely. Avoid fixed-width text blocks unless numeric.

## 16. Component Inventory

Required Vela 2.1 components:

- VelaScreen
- VelaPageHeader
- VelaSectionHeader
- VelaHeroSurface
- VelaGlassCard
- VelaMetricPill
- VelaStatusBadge
- VelaConfidenceBadge
- VelaFreshnessBadge
- VelaRiskBadge
- VelaPrimaryActionButton
- VelaSecondaryActionButton
- VelaInlineAlert
- VelaEmptyState
- VelaDataQualityRow
- VelaEvidenceStep
- VelaEvidenceChainView
- VelaAdaptiveTrainingBanner
- VelaMemoryProposalCard
- VelaTrustLogCard
- VelaCoachCommandCard

## 17. Screen Hierarchy Rules

Home starts with Body Intelligence Cockpit: body state, readiness score, fatigue state, primary limiter, training window, confidence, and top actions. Why This is a reasoning timeline. Training centers adaptive proposals. Memory is a confirmation inbox. Data Coverage is a confidence/trust page. Trust Center is an agent audit log. Coach is a proactive command center with chat as one surface, not the whole product.

## Semantic Expression

- Body state: headline, readiness ring, fatigue badge, narrative.
- Recovery: green semantic status plus plain-language rest/training implication.
- Sleep: blue-violet sleep debt, phase, and consistency context.
- Strain: coral training load, training window, and plan impact.
- Stress: rose stress load and downshift recommendations.
- Energy: amber opportunity, confidence, and readiness lift.
- Confidence: confidence badge plus explanation of missing/stale inputs.
- Risk: risk badge with level, source metrics, and conservative next action.
- Data freshness: freshness badge on evidence and coverage rows.
- Evidence chain: vertical reasoning steps from metric to action impact.
- Memory proposal: learned pattern, evidence, confidence, source, target file, why it matters, accept/reject/edit where supported.
- Adaptive training suggestion: original session, suggested change, reason, alternative, accept/keep/ignore.
- Agent audit log: run type, status, time, duration, hashes, output, tools, error, memory/adaptation artifacts.

## Stitch Direction

The selected Vela 2.1 direction uses Stitch's Claude.ai-style warm editorial system plus an agentic command-center structure:

- Project: `Vela 2.1 Claude.ai Experience System`
- Project id: `6103385464676727977`
- Design system: `Vela Claude.ai Warm Clinical System`
- Design system asset: `assets/12061632509050072099`
- Home base: `6359542d585642309bf3800b715ce8ce`
- Variants generated: Warm Editorial A, Command Center B, Agentic Companion C, Minimal Health OS D
- Selected synthesis: Variant A's warm paper editorial visual language plus Variant C's proactive agent command-center hierarchy.

Generated and downloaded screens:

- Home / Today Body Plan
- Home variants A-D
- Why This / Evidence Chain
- Training Calendar with Adaptive Training Proposal
- Memory Inbox / Wiki Confirmation
- Data Coverage / Trust
- Trust Center Audit Log
- Coach Command Center
- Settings / Navigation Hub

The downloaded Stitch HTML and screenshots live in `StitchExports/Vela21Claude/` and are translated into SwiftUI tokens and components instead of pasted into the iOS app.
