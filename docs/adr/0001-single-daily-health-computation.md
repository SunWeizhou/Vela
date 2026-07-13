# Use one Daily Health Computation for every entry path

Vela will derive scored health evidence through one deterministic Daily Health Computation for foreground refresh, background sync, and historical backfill. HealthKit and SwiftData remain outside this computation; this prevents entry-path-specific defaults and ordering from changing user-visible health interpretation.
