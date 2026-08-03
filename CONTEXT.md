# Vela Health Intelligence

Vela turns local health, training, nutrition, and journal facts into conservative daily guidance. The context exists to keep every surface and AI workflow aligned to the same measured evidence and uncertainty rules.

## Language

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

**Training Decision**:
The canonical daily choice to keep, reduce, swap, or recover, with reasons and confidence grounded in Body State and Data Coverage.
_Avoid_: AI recommendation, workout verdict, readiness label

**Daily Operating Plan**:
The persisted daily plan that combines one Training Decision with prioritized actions and safety notices for every product surface.
_Avoid_: Today card, generated brief, coach plan

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

## Example dialogue

> **Domain expert:** Today has fresh sleep and resting heart rate Health Signals, but HRV is unavailable, so Data Coverage is partial.
>
> **Developer:** Daily Health Computation will use the same missing-data rule during foreground refresh and historical backfill, then produce Body State with reduced confidence.
>
> **Domain expert:** Correct. The Training Decision may reduce training, and the Daily Operating Plan must show why. The Coach may create a Coach Artifact, but any long-term inference remains a Memory Proposal until the user confirms it.
