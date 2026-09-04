# 0016. Keep WidgetKit as internal preview and planned scope for the current release

## Status
Superseded by ADR 0017

## Context

The repository contains WidgetKit snapshot/provider work alongside the Watch integration. The snapshot contract is useful for internal testing and design validation, but public widget packaging, App Group entitlements, refresh guarantees, and release acceptance have not yet been verified as a complete distribution path.

Treating this work as release-complete would allow a parallel agent to add entitlements or promise refresh behavior before the product and privacy boundaries are settled.

## Decision

1. WidgetKit is **internal preview / planned scope** for the current release. It is not a public release acceptance gate.
2. Agents may maintain deterministic widget snapshots and preview surfaces when they do not change the release contract or upload raw HealthKit samples.
3. App Group entitlements, public widget metadata, refresh SLAs, App Store packaging, and production support commitments are out of scope until a separate acceptance decision.
4. Watch standalone execution and complications remain governed by their own device/release verification; this proposal does not make WidgetKit a prerequisite for Watch support.

## Consequences

- Widget work can continue as a bounded experiment without blocking the four primary iOS surfaces.
- The team avoids shipping a partially verified extension or broadening the privacy surface accidentally.
- Promotion from preview to public release requires a follow-up ADR or an explicit acceptance amendment with device, entitlement, and refresh evidence.
