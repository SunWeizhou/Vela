# Bevel 3.0 Research Brief

> Updated: 2026-05-24  
> Purpose: translate current public Bevel 3.0 signals into Vela product, design, and engineering decisions.

## 1. Source Snapshot

Primary sources reviewed:

- App Store changelog: https://apps.apple.com/us/app/bevel-ai-health-coach/id6456176249
- Bevel Knowledge Base, feature availability: https://help.bevel.health/en/articles/11194113
- Bevel pricing page: https://help.bevel.health/en/articles/11583937
- Bevel marketing site: https://www.bevel.health/
- Releasebot mirror of Bevel 3.0 release notes: https://releasebot.io/updates/bevel-health
- TechRadar hands-on review and Whoop comparison: https://www.techradar.com/health-fitness/fitness-apps/i-tried-the-app-whoop-just-sued-and-itd-be-a-real-shame-if-it-lost-the-battle
- Reddit feedback on Bevel 3.0 AI/nutrition/pricing: https://www.reddit.com/r/bevelhealth/comments/1t6uksb/bevel_is_becoming_an_llm_skin_instead_of_a_health/
- Reddit feedback on Bevel 3.0 pricing tier: https://www.reddit.com/r/bevelhealth/comments/1t4nr8v/bevel_30_light/
- Reddit feedback on 3.0 quick-add photo logging vs Intelligence food logging: https://www.reddit.com/r/bevelhealth/comments/1t03o5l/bevel_30_discrepancy_between_quick_add_photo_tracking_and_aipowered_food_logging/
- Reddit feedback on AI workout templates and progression history: https://www.reddit.com/r/bevelhealth/comments/1t5l52v/great_30_release_a_few_ideas_to_make_bevel_even_better/
- Reddit Bevel team response on 3.0 direction and upcoming Fitness/Journal/Nutrition work: https://www.reddit.com/r/bevelhealth/comments/1t76tii/responding_to_several_posts_in_the_last_hours/
- Reddit launch thread: https://www.reddit.com/r/bevelhealth/comments/1sx6a5s/introducing_bevel_30/
- Reddit stress/AI concern examples: https://www.reddit.com/r/bevelhealth/comments/1tkv20g/stress_measurement_is_completely_off/

## 2. Bevel 3.0 Product Direction

Bevel 3.0 is no longer only a recovery, sleep, and strain dashboard. It is positioning as a connected health coach where wearable data, clinical records, personal context, food logs, and training plans are merged into a proactive AI layer.

The core 3.0 pillars are:

1. **Bevel Intelligence V2**
   - more personal, proactive AI;
   - coaching personalities;
   - scheduled check-ins;
   - files system replacing memory;
   - generated artifacts such as charts;
   - conversational food logging;
   - AI-generated training plans and strength templates.

2. **Biological Age**
   - long-term health metric;
   - uses wearable data, habits, and bloodwork;
   - weekly recalculation;
   - biomarker contributors across sleep, activity, fitness, lifestyle, and blood biomarkers;
   - confidence indicator based on freshness/completeness.

3. **Health Records**
   - blood tests and documents uploaded into the app;
   - biomarker extraction into Biology;
   - clinical notes, imaging reports, and documents become AI context.

4. **Free vs Pro Strategy**
   - core tracking remains free;
   - Pro is priced around AI, Biological Age, and Health Records;
   - public pricing is $14.99/month or $99.99/year.

## 3. Bevel UX Observations From iPhone Mirror

Observed on 2026-05-22/2026-05-23 in Bevel and Vela on the connected iPhone:

- Bevel defaults to a bright, soft, card-based dashboard with strong whitespace and very low visual friction.
- The first screen has date, sync state, activity/weather chips, three primary rings, a short coach text, Pro upsell, and stress/energy module.
- Bottom tabs are Home, Journal, Fitness, Vitals/Biology, plus a large central action button.
- The Home information hierarchy is very disciplined: one screen immediately tells the user "status, why, what next".
- Bevel's share/customize UI exposes shareable metric cards and style filters, which reinforces polish even if it is not a core health function.
- Vela's old installed build still showed dark cards across Journal, Fitness, Vitals, and Coach; this made the app feel less like Bevel despite similar navigation.
- The latest code target shifts the shell to a Bevel-like light UI: pale background, white cards, black text, subtle borders/shadows, and Bevel-like Home/Journaling/Fitness/Vitals/`+` tabs.

Observed Vela comparison:

- Vela is functionally richer than a prototype: real HealthKit data, scoring, Coach, Wiki, training, biological age, food photo analysis, and proactive agents exist.
- Vela's dark UI is visually coherent, but the experience reads more "power user dashboard" than "daily health companion".
- Vela Coach is useful, but currently looks like a chat history. Bevel Intelligence feels more like an operating layer over the app.
- Vela's differentiator, the user Wiki, is real and should become the main product moat instead of being hidden as a profile editor.

Additional page observations on 2026-05-24:

- Journal is a daily entry board first: date strip, "Today's entries", repeated measurable rows, and Analyze/more actions.
- Fitness is a 30-day activity surface first: two-month heatmap, activity summary, and performance cards. A single daily strain gauge is secondary.
- Vitals/Biology is a broad health monitor: biological age, body metrics, blood/biomarker surfaces, and single-metric drilldowns with chart and trend analysis.

## 4. User Feedback Patterns From Public Forums

Positive signals:

- Users value Bevel as a Whoop-like experience without proprietary hardware.
- The combination of Recovery, Sleep, Strain, Health Monitor, Journal, and AI is perceived as coherent.
- Integrated AI can outperform generic LLM use because it knows workouts, sleep, recovery, and context without manual prompting.
- Biological Age plus biomarkers creates a strong high-end health analytics story.

Negative signals:

- Some users feel 3.0 risks becoming an "LLM skin" over unfinished health analytics.
- Nutrition logging is a visible weakness: food database, serving sizes, accuracy, and UI are recurring complaints.
- 3.0 has an important AI routing lesson: users expect fast-entry flows like plus/camera to use the strongest Intelligence engine, not a weaker legacy recognizer.
- AI-generated training plans need calendar-native UI, not only markdown files.
- Strength training users want editable templates and progression history, so AI plans must update existing artifacts instead of constantly creating new ones.
- Pricing jump creates demand for a lighter AI tier.
- Biological Age credibility depends heavily on confidence, fresh data, and understandable contributors.

## 5. Implications For Vela

Vela should not compete by copying every Bevel screen. It should copy Bevel's clarity and completeness while using a stronger local-first AI memory model.

Product strategy:

1. **Keep health analytics as the product core.**
   AI should explain and operate on strong metrics. It must not become a thin chatbot layer.

2. **Make the Wiki visible as "Vela Memory".**
   Bevel has Files. Vela should have a living Wiki that the user can inspect, edit, and trust.

3. **Turn Coach into Intelligence.**
   The Coach tab should combine chat, check-ins, files/wiki, generated artifacts, and actions.

4. **Treat plans as UI objects.**
   Training plans, strength templates, check-ins, and reminders should render as calendar/cards/artifacts, not only markdown text.

5. **Use confidence everywhere.**
   Recovery, biological age, food logging, and clinical markers must show data freshness, missing inputs, and confidence.

6. **For the personal build, pursue very close visual parity without copying protected assets.**
   Vela should match Bevel's light hierarchy, tab structure, card rhythm, and metric presentation as closely as practical, while keeping Vela's name, Wiki, scoring transparency, local storage, and model-provider architecture distinct.

7. **Keep non-AI product surfaces strong.**
   Public 3.0 feedback shows that users welcome Intelligence, but still judge the app by Fitness, Journal, Nutrition, and metric reliability. Vela's Bevel parity work must keep the core pages useful without requiring chat.

## 6. Full-Strength Vela Target

The "full-strength" Vela target is:

> A local-first AI health operating system for Apple Watch users: daily readiness, sleep, strain, stress, energy, biology, training, food, health records, and a user-maintained Wiki all feeding a proactive coach.

Non-negotiable differentiator:

- Bevel remembers through product-managed Files.
- Vela remembers through a user-readable, agent-maintained Wiki plus local structured baselines.

## 7. Product Requirements Imported From Bevel 3.0

Must-have for Vela next:

- Intelligence workspace with personalities, check-ins, artifacts, Wiki, and tools.
- Home dashboard that answers: "How am I, why, and what should I do today?"
- Biology dashboard with manual blood biomarkers, confidence, and freshness.
- Health Records ingestion roadmap, starting with local document metadata and manual biomarker entry.
- Training plan UI with calendar, workout cards, schedule adaptation, and recovery-aware adjustments.
- Food logging that is honest about confidence and editable portions.
- Share cards and visual summaries as polish after core flows stabilize.

## 8. Product Risks

- **Medical overclaim risk:** Biological Age and stress must stay framed as wellness proxies, not diagnosis.
- **AI trust risk:** The more proactive the agent becomes, the more visible audit trails must be.
- **Nutrition trust risk:** Photo estimates should always be editable and marked as estimates.
- **Privacy risk:** Local-first is valuable only if the app clearly shows what leaves the device.
- **Complexity risk:** Vela already has many modules; Home and Coach must simplify, not expose internal complexity.
