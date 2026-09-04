# 0015. Record the staged transition to the accepted iOS 26 and watchOS 26 floor

## Status
Proposed

## Context

ADR 0013 has already accepted iOS 26 and watchOS 26 as the Daily Driver target. The current implementation floor remains iOS 17 and watchOS 10, and the transition has not yet been executed. The repository still contains deployment and compatibility details that must be verified against the actual Xcode project, CI toolchain, and device matrix before changing the minimum deployment target. Agents must not independently remove legacy branches or change project settings while the transition is pending.

## Decision

1. The accepted Daily Driver target is **iOS 26 and watchOS 26**; the current implementation floor remains **iOS 17 and watchOS 10** until the transition lands.
2. This proposal records the transition guardrails. It does **not** change `IPHONEOS_DEPLOYMENT_TARGET`, `WATCHOS_DEPLOYMENT_TARGET`, or compatibility code in this change set.
3. CI may independently improve Xcode reproducibility by selecting and verifying the version declared in `.xcode-version`; that toolchain check does not imply that the deployment-target transition has occurred.
4. The transition requires a separate, reviewable change covering project settings, the selected CI/Xcode version, simulator and real-device coverage, accessibility behavior, and removal (or explicit retention) of legacy presentation paths. Until then, current project settings remain the implementation facts.

This proposal is the transition companion to ADR 0013. It does not supersede or silently implement that accepted direction.

## Consequences

- Agents can design against the accepted current-platform target without making an uncoordinated deployment-target change.
- Release verification must distinguish the accepted target floor from the currently configured floor.
- The platform transition remains a visible release decision instead of an accidental side effect of a UI refactor.
