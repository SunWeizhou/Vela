# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela UI Audit

## Executive assessment

The previous interface was functionally rich but visually fragmented. Its main weakness was not lack of polish; it was lack of editorial priority. Too many cards, badges, colors, and labels competed at the same level, especially when health data was unavailable.

## Product-team lenses

### Apple lens

- Strength: native navigation, SF Symbols, sheets, and platform controls already provide a solid base.
- Gap: fixed font sizes and dense horizontal layouts weaken Dynamic Type support.
- Gap: custom containers sometimes repeat hierarchy the system already communicates.
- Direction: use native typography and navigation; reserve custom surfaces for product-specific objects.

### ChatGPT lens

- Strength: Coach already supports continuous conversation and contextual actions.
- Gap: the empty conversation was a portal of cards instead of an invitation to start thinking.
- Direction: make the prompt and user content primary; history, reports, and memory remain accessible but secondary.

### Google lens

- Strength: Vela has rich state, confidence, provenance, and trend data.
- Gap: missing-data charts and zero-value dashboards looked broken rather than helpful.
- Direction: every empty state explains why it is empty and gives one useful next action.

### Claude lens

- Strength: Vela’s health coaching benefits from a thoughtful, explanatory voice.
- Gap: compressed labels and numerous pills made the product feel mechanical.
- Direction: use calmer reading rhythm, plain language, and fewer visual interruptions.

## Surface audit

| Surface | Primary job | Previous issue | New direction |
| --- | --- | --- | --- |
| Today | Decide what to do now | Repeated status and evidence; too many competing modules | One recommendation, one action, compact evidence |
| Training | Start or adjust today’s training | Blank metrics and charts occupied most of the screen | Session first; useful compact empty states |
| Coach | Ask, understand, decide | Welcome screen behaved like a feature hub | Conversation-first opening with contextual prompts |
| Me | Understand profile and manage the product | Large nested body-model dashboard | Compact model summary and grouped settings |
| Metric detail | Understand change and evidence | Mixed palettes and dense microcopy | Consistent semantic color and progressive disclosure |
| Onboarding | Reach first value safely | Visually decorative and information-heavy | Shorter steps, clearer value, explicit privacy context |
| Settings | Control data and behavior | Useful but visually inconsistent across sections | Native grouped forms and standardized rows |

## Remaining implementation sequence

1. Apply the token system to metric details, onboarding, settings, training details, sheets, and empty/error states.
2. Replace remaining fixed 9–11 pt essential labels with semantic text styles.
3. Run light/dark, Dynamic Type, localization, and missing-data screenshot coverage.
4. Validate touch targets, VoiceOver labels, contrast, reduced motion, and screen-reader order.
5. Conduct a final consistency pass for icon weight, card nesting, wording, and primary-action placement.
