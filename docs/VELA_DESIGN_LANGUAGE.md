# Vela Design Language — Calm Intelligence

Vela should feel like a private health intelligence product, not a dashboard template. The interface is native to iOS, quiet enough for daily use, and decisive when the user needs to act.

## Product principles

1. **One screen, one answer.** Every primary surface should answer one question before presenting supporting detail.
2. **Content before containers.** Use spacing and typography for grouping; add a card only when it represents a distinct object or action.
3. **Action before explanation.** Show the recommended next step first, then evidence, confidence, and methodology on demand.
4. **Calm, not empty.** Minimal interfaces still need warmth, useful empty states, and a clear path forward.
5. **Confidence is part of the data.** Missing or uncertain health data must change the recommendation, not merely add a warning badge.
6. **Native by default.** Prefer system navigation, typography, sheets, controls, Dynamic Type, and SF Symbols.
7. **Motion explains change.** Animate transitions and state changes only; avoid ambient animation and decorative blur.

## Reference synthesis

- **Apple:** platform familiarity, adaptive layout, legibility, and high craft.
- **ChatGPT:** conversation-first composition, restrained chrome, and focus on the user’s content.
- **Google:** explicit hierarchy, understandable state, modular systems, and useful personalization.
- **Claude:** warm editorial tone, generous reading rhythm, and calm collaboration.

These are inputs, not skins. Vela uses its own visual identity: warm neutral surfaces, ink-first typography, and a restrained teal accent associated with calm and trust.

## Visual rules

- Warm neutral page background; white/dark elevated surfaces.
- Teal is reserved for primary actions, selection, and intelligence—not decoration.
- Semantic health colors are muted and never replace a text label.
- Prefer 16–20 pt page margins and an 8 pt spacing rhythm.
- Use one feature card at most above the fold.
- Avoid nested cards, tinted boxes inside tinted boxes, and more than one filled button per section.
- Use sentence case. Avoid uppercase section labels in Chinese.
- Empty states should be compact and always offer a useful action.

## Primary surfaces

- **Today:** current state → one recommendation → immediate actions → evidence.
- **Training:** today’s session → start/record → recent load and history.
- **Coach:** prompt/composer first → contextual suggestions → memory and reports as secondary tools.
- **Me:** identity and model maturity → health profile → grouped settings and privacy.

## Quality gate

Every screen must be checked in light/dark mode, default and accessibility text sizes, with complete and missing data, on the smallest supported iPhone and a current Pro Max device.
