# Vela Documentation

This directory is the source of truth for product, architecture, scoring, AI, reuse, and design decisions.

Current build direction as of 2026-05-30:
- The current frontend direction is frozen. Future UI work is limited to incremental fixes and refinements while backend data contracts are aligned. See `FRONTEND_FREEZE_AND_BACKEND_ALIGNMENT.md`.
- Personal Bevel-like adaptive UI across Home, Journal, Fitness, Vitals, Sleep, and `+` Intelligence.
- Vela differentiates through local-first data, transparent scoring, and an agent-maintained user Wiki.
- The bottom shell now uses an Apple-like glass navigation bar: Home, Journal, Fitness, and Vitals sit in one material capsule, while the right-side circular `+` is separate and opens Vela Intelligence.
- Navigation rule: bottom tabs are aggregate workspaces, while Home score cards and metric rows open single-metric drilldowns.
- Journal now starts with a Bevel-style daily entry board while preserving Vela's note/Wiki context layer.
- Journal recent records now group by day and show daily summaries instead of listing every raw conversation/note.
- Home now keeps Nutrition as a compact summary before Today's AI Insights, so the section no longer collapses into an empty heading.
- Fitness now starts with a 30-day activity heatmap, activity summary, strain performance, and training readiness.
- Fitness Activity Summary now opens a real 30-day Activity detail page with activity load, chart, factors, and Vela analysis.
- Vitals now starts as a Health Monitor surface, with Recovery as one card and Biology/body metrics exposed from the first screen.
- Strain and Recovery now have first-pass Bevel-like metric detail pages with large values, 7D/30D trend charts, baseline/target context, driver cards, and action guidance.
- Vitals metric rows now navigate into single-metric detail pages for HRV, resting heart rate, sleep heart rate, respiratory rate, blood oxygen, and weight.
- Metric detail pages now include a live AI analysis strip before opening Vela Intelligence with current metric context.
- Sleep now uses a dedicated sleep panel with score, time asleep, sleep debt, efficiency, stage composition/timeline, and 7-day trend instead of the old generic metric scaffold.
- Training now opens as an adaptive plan workspace with readiness, plan generation/adjustment actions, and native training calendar cards instead of duplicating the old Strain page.
- `+` now opens as a full-screen Vela Intelligence action hub with Ask, Analyze Today, Update Wiki, Generate Plan, Wiki status, artifacts, check-ins, and quick prompts before chat.
- Nutrition image recognition foundation exists through Kimi Vision, but full Nutrition productization is paused while the main UI and non-nutrition flows are brought to parity.

Required documents:
- `PRD.md`
- `MVP_EXECUTION_PLAN.md`
- `AI_AGENT_SPEC.md`
- `TECH_ARCHITECTURE.md`
- `OPEN_SOURCE_REUSE_PLAN.md`
- `SCORING_SYSTEM_V1_0.md`
- `STITCH_DESIGN_BRIEF.md`
- `FRONTEND_FREEZE_AND_BACKEND_ALIGNMENT.md`

Current product strategy documents:
- `BEVEL_3_RESEARCH.md` — public Bevel 3.0 research, iPhone mirror observations, forum feedback, and implications for Vela.
- `BEVEL_PARITY_GAP_TRACKER.md` — live page-by-page gap tracker for Bevel parity, bugs, and verification checkpoints.
- `VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md` — full product, design, engineering, AI, and roadmap blueprint for taking the current build to a Bevel 3.0-class Vela.
- `GAP_ANALYSIS.md` — updated gap analysis against Bevel 3.0 and current Vela phone experience.
