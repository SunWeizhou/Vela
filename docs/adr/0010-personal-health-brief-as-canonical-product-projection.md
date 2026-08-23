# 0010. PersonalHealthBrief as Canonical Product Projection & Downstream Training Derivation

## Status
Accepted

## Context
Vela accumulated rich longitudinal health data (~1100 days of Apple Health history, 39 workout events, and physiological snapshots). However, previous architecture over-indexed on generating daily training decisions (`TrainingDecisionKernel`), causing "training decisions" to dominate all surface representations. As a result, the primary product positioning—a trusted personal health panel and AI health analyst—became fragmented across conflicting trend algorithms, ad-hoc score thresholds, and UI components.

## Decision
1. **Restore Core Positioning & 4-Tier Value Hierarchy**:
   Vela is a personal health panel and AI analyst built upon Apple Health:
   $$\text{See Body Data} \longrightarrow \text{Understand Current State \& Trends} \longrightarrow \text{AI Explains \& Correlates} \longrightarrow \text{Adjust Training \& Life}$$

2. **North Star Evolution**:
   The North Star is defined as **`Trusted Health Brief Day`**. Each day, Vela reliably answers:
   - How is my body doing overall?
   - What notable shifts or deviations occurred recently?
   - Do I need to take any adjustment action?
   A stable day where no plan modification is needed carries the exact same complete value as a day requiring load reduction.

3. **`PersonalHealthBrief` as Canonical SSOT**:
   - `DailyHealthComputation` outputs scored health evidence.
   - `HealthTrendEngine` synthesizes multi-scale temporal trends (7d/30d/6m/3y) and baseline deviations into a canonical `PersonalHealthBrief` and `HealthTrendFinding` set.
   - All surfaces (`Today`, `Trends`, `Agent Snapshot & Tools`, `Metric Detail`) consume this single source of truth without separate ad-hoc algorithms.
   - Missing data is never treated as zero.

4. **Training Decision as Downstream Consumer**:
   - `PersonalHealthBrief` evaluates physiological state and general readiness; it does not issue dogmatic training prescriptions.
   - `TrainingDecisionKernel` derives training volume and intensity caps downstream by taking `PersonalHealthBrief` + active training plan + workout rotation context.

5. **Primary surfaces**: superseded by [ADR 0012](0012-score-led-today-and-primary-surfaces.md). The canonical projection remains shared across all replacement surfaces.

6. **Evidence Boundaries & Language**:
   Eliminate unsubstantiated claims ("交感神经张力偏高", "自主神经活性良好", "深睡减少", "生理因果归因"). Use disciplined, observable, and probabilistic language.
