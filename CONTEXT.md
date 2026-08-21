# Vela Health Intelligence

Vela 是建立在 Apple 健康之上的个人身体面板与 AI 健康分析助手：帮助用户看见当前身体状态和长期趋势，理解变化原因，并将这种理解转化为训练与生活调整建议。

> 核心原则：不做只陈列指标、不能解释个人状态和变化的健康数据面板。
> 价值层级：1. 看见身体数据 → 2. 理解当前状态与长期趋势 → 3. 由 Agent 解释原因并联系不同信号 → 4. 在需要时给出训练与生活建议。

## Language

### Product boundary

**Primary User**:
The owner-developer whose real Apple Watch, training, research-work, eating, and recovery routines define Vela's current product requirements. Hypothetical general users do not outweigh observed Primary User behavior during the personal Daily Driver phase.
_Avoid_: Target persona, early adopter cohort, average user

**Trusted Health Brief Day**:
A day when Vela reliably answers three fundamental questions for the Primary User: (1) How am I overall right now? (2) What has changed recently? (3) Do I need to take action? A day where state is stable and no plan change is needed is just as valuable as a day requiring a decision.
_Avoid_: Active day, engagement day, compliant day, decision-only day

### Health evidence

**Health Signal**:
A measured or user-entered health fact with a source, timestamp, freshness, unit, and availability state.
_Avoid_: Metric value, raw field, data point

**Daily Health Snapshot**:
The normalized set of Health Signals assigned to one calendar day before scores or recommendations are derived.
_Avoid_: Daily record, summary row, cache entry

**Personal Baseline**:
The valid historical window used to interpret a Health Signal relative to the same person; it is never a population diagnosis.
_Avoid_: Normal range, standard value, average user

**Data Coverage**:
The explicit account of which required Health Signals are available, fresh, and authorized for a calculation.
_Avoid_: Data quality score, completeness guess

### Daily interpretation

**Daily Health Computation**:
The single deterministic transformation from a Daily Health Snapshot plus Personal Baselines into scored health evidence. It owns missing-data rules and produces the same result for foreground refresh, background sync, and historical backfill.
_Avoid_: Metric pipeline, score factory, dashboard calculation

**Scored Health Evidence**:
The five independently interpretable 0–100 results produced by Daily Health Computation: Recovery, Sleep, Strain, Physiological Stress, and Energy. Each result carries direction, confidence, Data Coverage, contributing Health Signals, Personal Baseline comparisons, an algorithm version, and a data window. Vela does not collapse these results into one total health score: higher Strain means more load and higher Physiological Stress means more concern, so a single total would create false precision.
_Avoid_: Overall health score, readiness total, wellness grade

**Body State**:
A conservative interpretation of current recovery, load, sleep, stress, and reported constraints derived from scored health evidence.
_Avoid_: Readiness score, diagnosis, physical condition

**Health Trend Finding**:
A multi-scale (7d, 30d, 6m, 3y) statistical finding for a specific health metric, capturing direction, magnitude, baseline deviation, historical percentile position, and uncertainty.
_Avoid_: Raw difference, isolated daily variance

**Personal Health Brief**:
The canonical, structured daily intelligence object answering "How am I overall? What is changing? Is it noteworthy? What might be driving it? Does it need action?". Consumed synchronously by Today, Trends, Agent, and Training.
_Avoid_: Workout prescription, isolated score summary

**Lived State**:
The Primary User's self-reported felt experience at a point in time, including mental stress, training motivation, soreness, perceived energy, appetite disruption, and felt recovery. It is subjective evidence that may agree or disagree with Body State; neither silently replaces the other.
_Avoid_: Mood score, emotion diagnosis, subjective readiness

**Personal Response Model**:
The evolving, uncertainty-aware account of how the Primary User's Health Signals, Lived State, Training Constraints, actions, and later responses relate over time. It supports future decisions but does not convert correlations into diagnoses or permanent traits.
_Avoid_: Digital twin, personality model, user score

**Personal Response Insight**:
A concise, testable claim derived from the Personal Response Model when it is relevant to a current decision. It stays implicit in the primary journey, while an on-demand evidence view exposes supporting observations, confidence, and controls to rate or correct the claim.
_Avoid_: Profile card, hidden label, permanent conclusion

**Training Decision**:
The canonical daily choice to keep, reduce, swap, or recover, with reasons and confidence grounded in Body State and Data Coverage.
_Avoid_: AI recommendation, workout verdict, readiness label

**Daily Operating Plan**:
A persisted, cross-domain plan that protects Health Rhythm through one primary action and at most two supporting actions across training, movement, eating, stress recovery, and sleep. It may contain a Training Decision, but it does not become a general work or calendar manager.
_Avoid_: Today card, generated brief, coach plan

**Plan Proposal**:
A reviewable candidate change to a Daily Operating Plan produced from new context or Coach reasoning. It may explain alternatives and expected trade-offs, but it becomes canonical only after explicit user confirmation.
_Avoid_: AI override, automatic plan, chat suggestion

**Health Rhythm**:
The sustainable pattern formed across sleep, eating, work stress, movement, training, and recovery over time. When short-term fat loss, training continuity, and recovery conflict, Vela protects or restores Health Rhythm before optimizing the narrower goal.
_Avoid_: Perfect routine, wellness score, daily compliance

**Compensatory Action**:
An exercise or eating restriction performed primarily to cancel out a perceived dietary failure. Vela does not prescribe Compensatory Actions; it redirects the Daily Operating Plan toward normal eating, proportionate movement, and recovery.
_Avoid_: Calorie correction, punishment cardio, earning food

**Daily Check-in**:
An optional self-report of current mental stress, training motivation, soreness, pain, or exceptional life context. It may strengthen or change a Daily Operating Plan, but its absence never blocks guidance and never means that the reported condition is normal or absent.
_Avoid_: Required questionnaire, daily compliance task, assumed zero

**Proactive Touchpoint**:
A bounded, optional moment when Vela surfaces information without requiring the user to open the app first. The default cadence is one morning plan, one post-session annotation invitation, and a conditional evening adjustment only when available evidence would materially change the Daily Operating Plan.
_Avoid_: Continuous coaching, engagement notification, mandatory reminder

### Eating context

**Eating Rhythm**:
The sustainable pattern of regular, sufficient, and proportionate eating across days. Vela interprets Eating Rhythm alongside stress, sleep, training, and recovery rather than reducing it to a daily calorie target.
_Avoid_: Diet compliance, calorie score, clean eating

**Eating Disruption**:
A user-reported departure from Eating Rhythm, such as overeating, binge eating, skipped meals, or irregular eating. It is contextual evidence for restoring Health Rhythm, not a moral failure and not a trigger for a Compensatory Action.
_Avoid_: Cheat meal, bad day, dietary failure

**Meal Detail**:
Optional information about a meal, including foods, portions, photos, calories, or nutrients. Meal Detail may improve an explanation but is never required for Vela to recognise an Eating Disruption or provide guidance.
_Avoid_: Required food log, exact intake, inferred consumption

### Training loop

**Training Rotation**:
The user's intended repeating sequence of strength-training focuses. It expresses continuity without fixing each focus to a calendar date, so a Training Decision may delay, reduce, or temporarily substitute the next focus without losing the underlying sequence.
_Avoid_: Fixed schedule, generated program, weekly calendar

**Session Focus**:
The body region or training purpose actually emphasized in a Training Session, such as back, chest, shoulders, legs, accessory muscles, or cardio. A generic activity record does not establish Session Focus unless the user or a linked data source supplies it.
_Avoid_: Workout type, exercise list, inferred muscle group

**Training Constraint**:
A temporary factor that may change the next Training Decision, including incomplete recovery, poor sleep, physiological or mental stress, pain, low motivation, schedule pressure, or disrupted nutrition. It is current context, not a stable trait or diagnosis.
_Avoid_: Excuse, readiness factor, permanent limitation

**Training Session**:
A real-world workout completed by the user and observed by Vela through an external activity record. Vela does not require phone-based exercise, set, repetition, or rest-timer tracking during the session.
_Avoid_: Active workout, in-app workout, training draft

**Training Observation**:
The evidence Vela receives after a Training Session, combining the imported activity record with any optional user-reported experience. It is the factual basis for post-training interpretation and later calibration.
_Avoid_: Workout log, completed plan, execution record

**Session Annotation**:
User-supplied context attached after a Training Session. Its quick layer identifies Session Focus and overall experience; an optional detail layer may add exercises, weights, sets, and a free-form reflection without turning in-session phone logging into a requirement.
_Avoid_: Mandatory workout log, active set tracking, training diary

**Post-Training Check-in**:
A low-friction account of perceived effort, fatigue, pain, and relevant context after a Training Session. It forms the subjective part of a Session Annotation, may be skipped or completed later, and never blocks importing or analysing the session.
_Avoid_: Workout logger, set log, mandatory feedback

### Coach memory

**Agent Fact Snapshot**:
The locale-neutral, deterministic projection of Health Signals, Data Coverage, Body State, Training Decision, and recent training or nutrition facts used by every AI workflow. Its semantic content hash excludes snapshot creation time; chat, reports, and proactive tasks render it through purpose-specific adapters.
_Avoid_: Prompt context, context JSON, AI summary

**Coach Artifact**:
A structured, reviewable output produced by the Coach, such as a readiness explanation, training adjustment, or review.
_Avoid_: AI message, report blob, recommendation card

**Memory Proposal**:
A candidate long-term fact or preference that requires user confirmation before it becomes canonical Coach memory.
_Avoid_: Automatic memory, wiki update, inferred profile

## Flagged ambiguities

- “Summary” previously meant both a Daily Health Snapshot and the scored dashboard projection. Use **Daily Health Snapshot** for evidence before computation; use the concrete projection type for display-only output.
- “Readiness” previously referred to a score, a Body State, and a Training Decision. Use **Body State** for interpretation and **Training Decision** for the actionable choice.
- “Score” without a domain is ambiguous. Name the specific **Scored Health Evidence** result: Recovery, Sleep, Strain, Physiological Stress, or Energy.
- “生活健康” is too broad for a product decision. Use **Health Rhythm** when referring to the cross-domain pattern Vela protects across sleep, eating, work stress, movement, training, and recovery.
- “感觉” is ambiguous. Use **Lived State** for the user's reported experience and **Body State** for Vela's evidence-grounded interpretation; disagreement between them is information to learn from, not an error to hide.

## Example dialogue

> **Domain expert:** Today has fresh sleep and resting heart rate Health Signals, but HRV is unavailable, so Data Coverage is partial.
>
> **Developer:** Daily Health Computation will use the same missing-data rule during foreground refresh and historical backfill, then produce Body State with reduced confidence.
>
> **Domain expert:** Correct. The Training Decision may reduce training, and the Daily Operating Plan must show why. The user completes the Training Session without needing the phone; Vela later builds a Training Observation from the imported activity and any optional Post-Training Check-in. The Coach may create a Coach Artifact, but any long-term inference remains a Memory Proposal until the user confirms it.
