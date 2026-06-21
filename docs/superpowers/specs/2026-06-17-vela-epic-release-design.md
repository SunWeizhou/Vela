# Vela Epic Release Design

## Goal

Turn Vela from a capable internal AI fitness assistant into a release-ready daily fitness operating system: clear command center, scientific evidence, fast local-first workflows, precise AI coach context, and a refined SwiftUI interface that feels calm under repeated use.

## Product Standard

Vela should never show a confident-looking recommendation without showing data freshness, confidence, evidence, and a safe fallback. Every primary screen should answer four questions quickly:

- What is my body ready for today?
- What evidence changed the recommendation?
- What should I do next?
- What does the AI coach know, and how certain is it?

## Architecture Direction

The app keeps the current local-first SwiftUI + SwiftData + HealthKit architecture. Raw HealthKit data stays on device. The main change is a stricter experience layer between scoring kernels and UI:

- `BodyStateKernel` remains the canonical body-state synthesis layer.
- `TrainingDecisionKernel` remains the canonical training-decision layer.
- `TodayExperienceModel` becomes the UI-facing Today model, converting scores, freshness, confidence, nutrition, evidence, and actions into stable display structures.
- SwiftUI views should consume display models instead of embedding scientific decision logic directly in layout code.

## UI Direction

The new Today first screen is a command center, not a metric stack:

- Hero readiness card: recovery score, training recommendation, confidence label, evidence chips, and primary action.
- Signal grid: recovery, sleep, strain, stress, and energy with compact trends and explanations.
- Action timeline: three concrete next actions with visible priority.
- Nutrition strip: calorie progress and macros with one-tap logging.
- AI coach preview: summarizes recommendation confidence and data freshness.

Animation is restrained: score reveal, card entrance, sparkline draw, light haptics on primary action, and no decorative background effects.

## Data Display Rules

- Missing recovery data must show conservative guidance, never fake certainty.
- Confidence is displayed as a user-facing label, not just an internal number.
- Health signals use stable 0-100 display where appropriate and `--` when unavailable.
- Nutrition progress is clamped between 0 and 1.
- Evidence chips are short and derived from kernel reasons or explicit missing-data fallbacks.

## Ten-Version Epic Track

1. Vela 5.0 Today Command Center: rebuild Today around `TodayExperienceModel`, evidence, and action timeline.
2. Vela 5.1 Training Execution OS: make the Training tab consume the same decision and launch the right session with safer plan-day resolution.
3. Vela 5.2 AI Coach Reliability: retry/backoff, cancellation propagation, structured error UX, and no duplicated tool side effects.
4. Vela 5.3 Body Model Maturity: expose baseline maturity, uncertainty, and personal-response learning in user language.
5. Vela 5.4 Nutrition Intelligence: meal logging, macro targets, food photo confidence, and training-day nutrition suggestions.
6. Vela 5.5 Recovery Protocols: actionable recovery day plans, symptom-aware guardrails, and evening sleep protection.
7. Vela 5.6 Data Trust Center: complete privacy controls, export/delete flows, coverage diagnostics, and audit trail polish.
8. Vela 5.7 Performance Release: bounded SwiftData reads, sync dedupe, tab lifecycle instrumentation, and large-history fixtures.
9. Vela 5.8 Visual System Pass: full dark mode QA, accessibility sizing, reduced-motion coverage, and device screenshot review.
10. Vela 6.0 Launch Candidate: release checklist, TestFlight build, device validation, onboarding copy, and final regression suite.

The requested "1000+ updates" is tracked as a long-running quality bar across these versions: component states, copy states, data states, edge cases, animation details, tests, accessibility checks, and device QA items. This first pass starts that track by landing the Today experience model, first-screen redesign, and test coverage.

## Acceptance Criteria

- Today first screen gives a clear recommendation within the first viewport.
- Missing data is conservative and explicit.
- The display model is testable without launching SwiftUI.
- Main app target and test target compile.
- Future iterations can update the model and UI independently without duplicating health-scoring logic.
