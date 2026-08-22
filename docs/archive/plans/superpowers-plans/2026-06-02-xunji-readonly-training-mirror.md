# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Xunji Read-Only Training Mirror Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import explicitly selected Xunji training days into Vela's existing local training fact layer without storing credentials outside Keychain or creating duplicate workouts.

**Architecture:** Add two SwiftData mirror records, a pure response decoder and mapper, a read client with an injected transport, and a main-actor import service that reuses `WorkoutAggregationService`. Expose Keychain configuration under Data Sources and a compact one-day import sheet from Fitness. Keep writeback out of this increment.

**Tech Stack:** SwiftUI, SwiftData, URLSession, Keychain, XCTest, existing Vela aggregation services.

---

### Task 1: Mirror Records And Cache Policy

**Files:**
- Modify: `VelaApp/Persistence/SwiftDataModels/PersistenceModels.swift`
- Modify: `VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift`
- Test: `VelaAppTests/PersistenceFoundationTests.swift`

- [ ] Add failing persistence tests for `XunjiDailyCacheRecord`, `XunjiWorkoutMirrorRecord`, and `XunjiCachePolicy`.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/PersistenceFoundationTests`.
- [ ] Add defaulted mirror-record fields, register both models in the schema, and implement the 90-second cache policy.
- [ ] Re-run focused persistence tests and commit `feat: add xunji mirror persistence`.

### Task 2: Read Client And Payload Mapping

**Files:**
- Create: `VelaApp/TrainingIntelligence/Xunji/XunjiTrainingClient.swift`
- Test: `VelaAppTests/XunjiTrainingClientTests.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] Add failing decoder tests for a full v2 response, `kg`, `lb`, unfinished sets, timed metrics, and nested items.
- [ ] Add failing client tests with an injected transport for request body, bearer header, cache-independent errors, and absence of credential text in errors.
- [ ] Implement `XunjiTrainingClient`, response DTOs, `XunjiTrainingMapper`, and user-readable `XunjiTrainingError`.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/XunjiTrainingClientTests`.
- [ ] Commit `feat: decode xunji training exports`.

### Task 3: Idempotent Local Import

**Files:**
- Create: `VelaApp/TrainingIntelligence/Xunji/XunjiTrainingImportService.swift`
- Modify: `VelaApp/Health/Services/WorkoutAggregationService.swift`
- Test: `VelaAppTests/XunjiTrainingImportTests.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] Add failing import tests that create an in-memory container and verify one imported strength workout, one linked event, one mirror record, daily aggregation, cache reuse, and idempotent re-import.
- [ ] Add a narrow aggregation overload for imported records when needed; preserve existing manual and HealthKit paths.
- [ ] Implement the main-actor import service with injected client and Keychain reader.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/XunjiTrainingImportTests`.
- [ ] Commit `feat: mirror xunji workouts into local training facts`.

### Task 4: Secure Settings And Fitness Import Sheet

**Files:**
- Create: `VelaApp/TrainingIntelligence/Xunji/XunjiTrainingViews.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalCoachView.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`
- Test: `VelaAppTests/VelaThemeTests.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] Add failing source-contract tests that require a Keychain-only Xunji settings path, a Data Sources navigation entry, a Fitness sync sheet entry, and no writeback endpoint in UI sources.
- [ ] Implement `XunjiTrainingSettingsView` and `XunjiSyncSheetView`.
- [ ] Add Data Sources navigation and a secondary download button in the Fitness header.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:VelaTests/VelaThemeTests`.
- [ ] Commit `feat: add secure xunji import controls`.

### Task 5: Release Verification

**Files:**
- Verify: `Vela.xcodeproj`

- [ ] Run `plutil -lint VelaApp/Vela-Info.plist`.
- [ ] Run `git diff --check`.
- [ ] Run `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`.
- [ ] Run `xcodebuild build -project Vela.xcodeproj -scheme Vela -configuration Debug -destination 'platform=iOS,id=00008140-00164DE022C3801C'`.
- [ ] Install and launch with `xcrun devicectl`.
- [ ] Review `git status --short --branch`, inspect the diff, and commit any verification-only corrections separately.
