# 0014. Keep Vela as the engineering identity and canonicalize primary surface labels

## Status
Proposed

## Context

The repository, Xcode project, bundle identifier, and existing implementation are named **Vela**. Product discussions have also used **BodySeek** (and, inconsistently, BoySeek) as a working name. At the same time, older documentation and implementation comments still use feature-category labels such as `Vela` and `Training`, while the product contract and ADR 0012 define the four primary surfaces as Today, Trends, Plan, and Coach.

Renaming the project or bundle while several agents are changing the product would create unnecessary migration risk. A shared label contract is needed now, without pretending that a formal App Store rename has been approved.

## Decision

1. **Vela remains the engineering identity for this phase.** This ADR does not rename the Xcode project, bundle identifier, module names, repository, or existing Swift symbols.
2. **BodySeek is a product working name only.** It may be used in product and orchestration discussions, but it is not yet an approved display-name or distribution rename. BoySeek does not define a second engineering or product identity in this proposal.
3. **The canonical primary surface labels are exactly `Today`, `Trends`, `Plan`, and `Coach`.** These labels apply to navigation, acceptance criteria, design reviews, and new user-facing documentation. Training is a downstream capability inside Plan and Coach, not a fifth primary tab.
4. Legacy labels may remain temporarily in compatibility code, analytics identifiers, or historical documents, but new work must not introduce them as product-level alternatives.

This proposal clarifies and operationalizes ADR 0012; it does not authorize a code or distribution rename until this ADR is accepted and a migration plan is approved.

## Consequences

- Parallel agents have one unambiguous vocabulary for surface ownership.
- Existing bundle and source compatibility are preserved during the current stabilization phase.
- A future formal rename will still need its own migration checklist for display name, bundle identity, deep links, analytics, and App Store metadata.
