# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela 4.0 Stabilization Report

Date: 2026-06-14

## Verified Changes

- Workout saves now commit workout, event, artifact, aggregation, and draft deletion as one rollback-safe operation.
- Daily status defaults to active and temporary states expire consistently.
- Daily training guidance is generated from one canonical decision and persisted in `DailyOperatingPlanRecord`.
- Training-plan dates resolve by plan week/day and launch populated strength drafts.
- Store-open failure backs up store/WAL/SHM and enters safety mode without deleting user data.
- Agent final responses use the existing final provider result and record the actual provider call count.
- Coach no longer replays completed responses character by character.
- Provider failures map authentication, offline, timeout, malformed response, and generic errors to actionable messages.
- Training HealthKit refreshes are deduplicated and throttled.
- Training summary reads use a bounded date range.
- New exercises use prior performance or zero external load instead of an invented 20 kg default.
- Operational retention removes old traces, temporary artifacts, and Xunji caches while preserving acted Coach artifacts.

## Verification

- Full `VelaTests` simulator suite: passed on iPhone 17 Pro.
- Clean Debug simulator build with signing disabled: passed.
- Release generic iOS device build with signing disabled: passed.
- `git diff --check`: passed.

## Remaining Gates

- Convert remaining unbounded primary-screen `@Query` properties to date/limit-aware fetches.
- Route all HealthKit and Xunji lifecycle triggers through `AppSyncCoordinator`.
- Validate inactive-tab behavior on iOS 17 and iOS 26.
- Add 30/180/730-day performance fixtures and measure the stated latency budgets.
- Run Instruments for CPU, memory, hangs, network, and energy on a physical device.
- Complete onboarding localization, accessibility audit, data export/deletion, and privacy UI.
- Test migration against archived production/development store fixtures.
- Execute the seven-day seeded manual daily-driver path.
