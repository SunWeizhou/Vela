# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela Epic Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Vela's epic release track through small, verifiable iterations, starting with the Today command center and then expanding into Training, AI coach reliability, nutrition, recovery, trust, performance, and launch readiness.

**Architecture:** Preserve local-first HealthKit/SwiftData and reuse `BodyStateKernel` plus `TrainingDecisionKernel`. Add UI-facing display models per surface so SwiftUI layouts stop owning scientific decision logic directly.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, HealthKit, XCTest, Xcode 17, iOS 17+ with native iOS 26 tab support.

---

## Current Slice: Vela 5.0 Today Command Center

**Files:**

- Modify: `VelaApp/Core/Utilities/DashboardSummary.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`
- Modify: `VelaAppTests/ScoringEngineTests.swift`

- [x] **Step 1: Add failing display-model tests**

Add tests for a healthy dashboard and a missing-data dashboard:

```swift
let model = TodayExperienceModel.build(
    dashboard: dashboard,
    bodyState: bodyState,
    trainingDecision: decision,
    nutrition: .init(calories: 1_420, calorieTarget: 2_100, protein: 118, carbs: 168, fat: 42)
)
```

Expected: compilation fails because `TodayExperienceModel` does not exist.

- [x] **Step 2: Implement `TodayExperienceModel`**

Create display structs for hero, signals, evidence chips, actions, nutrition, and coach preview. Keep this in `DashboardSummary.swift` to avoid pbxproj changes.

- [x] **Step 3: Replace Today first-screen structure**

Route `VelaTodayView.body` through:

```swift
todayExperienceHeroCard(todayExperience)
todaySignalGrid(todayExperience)
todayActionTimeline(todayExperience)
nutritionCommandStrip(todayExperience.nutrition)
aiCoachPreviewCard(todayExperience)
```

- [x] **Step 4: Add native SwiftUI visual details**

Add a readiness dial, mini sparklines, action timeline, evidence chips, macro badges, card entrance animation, and restrained haptic feedback.

- [x] **Step 5: Verify compilation**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug
```

Expected: both succeed.

## Next Slices

### Task 2: Training Execution OS

- [x] Route Today training actions through `VelaAppState.routeToAdaptiveTrainingStart()` instead of only switching tabs.
- [x] Make the Training tab consume adaptive start requests and invoke the existing `TrainingSessionDraftBuilder` path when a resolvable plan day exists.
- [x] Add tests for rest/reduce/swap/keep action mapping in `TodayExperienceModel`.
- [x] Move the legacy `TrainingView` hero summary to consume `TodayExperienceModel` and `DailyOperatingPlanPayload` if that surface remains enabled.
- [x] Add `DailyOperatingPlanDisplayModel` so Training and Coach show localized, user-facing plan summaries instead of raw English payload/source strings.
- [x] Localize default training template names and data-coverage reasons in the Chinese UI without mutating user-created template data.

### Task 3: AI Coach Reliability

- [x] Add provider retry/backoff with explicit non-retryable auth errors.
- [x] Prevent retry from replaying successful write tools.
- [x] Surface one actionable error with a route to Settings.
- [x] Add prompt-level evidence boundaries so training advice follows `TrainingDecisionKernel` / `DailyOperatingPlanPayload`, missing data lowers certainty, and cross-diagnosis patterns only run when required fields exist.
- [x] Replace `MemoryLedgerTests` placeholder coverage with proposal lifecycle tests and clamp memory confidence values to the displayable `0...1` range.
- [x] Replace `PromptComposerTests` placeholder coverage with response-length and web-search policy tests, ensuring personal training/recovery questions use local tools instead of generic web search.
- [x] Replace the empty AgentActionParser placeholder test with action parsing coverage and preserve original action order when multiple legacy action blocks are emitted.
- [x] Make web-search tool output traceable by parsing result URLs into Markdown links and documenting source verification limits in the tool response.
- [x] Detect Chinese supplement/training science queries in `WebSearchTool` source policy routing so Chinese research questions bias toward authoritative medical or sports-science sources.
- [x] Route Coach training-plan cards to the Training tab instead of returning to Today.

### Task 4: Trust And Launch Readiness

- [x] Add data coverage states to Today and Coach.
- [x] Finish export/delete/privacy controls.
- [x] Remove the unused legacy Training strain branch and `PlaceholderInsightCard` component so production sources no longer carry a user-visible placeholder card.
- [x] Remove remaining `try!` regex parsing and background-task `as!` casts from production code, leaving only the standard unavailable coder initializer.
- [x] Remove remaining forced `Range(...)!` unwraps from legacy action parsing and Bing HTML result parsing.
- [x] Replace the HealthFoundation placeholder with simulator-stable HealthKit authorization tier tests and make enhanced/advanced permission requests cumulative.
- [x] Add a Debug-only initial-tab launch argument for repeatable simulator visual QA without affecting normal release startup.
- [x] Add a Debug-only `-velaForceOnboarding` launch argument for repeatable first-run visual QA without changing normal onboarding completion behavior.
- [x] Localize Onboarding stored-value labels and first body-model brief so user-facing setup no longer exposes raw keys such as `muscle_gain` or `strength`.
- [x] Move Onboarding primary actions into a fixed bottom CTA area so first-run users can continue without hunting below the fold.
- [x] Polish Settings and Body Model copy: fix API key/iCloud wording, align weather permission copy with actual location behavior, refresh What's New, and remove mixed Chinese/English stored-value labels from the Me tab and Body Model editor.
- [x] Run full simulator tests after simulator launch is stable.
- [x] Build, install, and launch on the connected iPhone for device QA.

## Verification Notes

- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the Today and Training changes.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/ScoringEngineTests` succeeds after `TrainingSurfaceSummaryModel` and legacy `TrainingView` integration.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the legacy `TrainingView` integration.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=FFB9F219-D1D9-4FAD-B5E6-C6E8A987FBB5' -only-testing:VelaTests/ScoringEngineTests` succeeds.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after the Coach retry and recovery-action changes.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=FFB9F219-D1D9-4FAD-B5E6-C6E8A987FBB5' -only-testing:VelaTests/AgentActionParserTests` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after the Coach evidence-boundary prompt changes.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests/testAgentActionParserPreservesActionOrderAndCleansDisplayText` fails before the parser order fix and succeeds after `AgentActionParser.parse` reverses the internally accumulated matches back to source order.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after replacing the parser placeholder test and fixing action order.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the AgentActionParser action-order fix.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after replacing forced regex range unwraps with guarded ranges.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after removing forced `Range(...)!` unwraps from action parsing and web-search parsing.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after adding traceable web-search result parsing coverage.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after making web-search output include result links.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests/testWebSearchToolDetectsSourcePolicyForChineseHealthAndTrainingQueries` fails before the Chinese policy-keyword fix and succeeds after `WebSearchTool.detectPolicy` recognizes Chinese supplement/training terms.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after the Chinese web-search source-policy fix.
- `rg -n "fatalError|preconditionFailure|try!|as!|Range\\([^\\n]+\\)!|XCTAssertTrue\\(true\\)|TODO|FIXME|not implemented|未实现" VelaApp VelaAppTests` now only reports the ModelContainer last-resort `preconditionFailure` after in-memory fallback fails and the standard unavailable UIKit `init(coder:)` initializer.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after removing the unused Training strain branch and `PlaceholderInsightCard` from the Xcode project.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/AgentActionParserTests` succeeds after replacing parser `try!` regular expressions with safe optional regex fallbacks.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after replacing the background refresh `as!` cast with a guarded task type check.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/MemoryLedgerTests` succeeds after clamping `MemoryEventRecord.confidence` and replacing the placeholder memory tests.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the MemoryLedger confidence clamp.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/PromptComposerTests` succeeds after tightening `ResponseLengthPolicy.needsWebSearch`.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the PromptComposer policy changes.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/HealthFoundationTests` succeeds after the data coverage summary changes.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=FFB9F219-D1D9-4FAD-B5E6-C6E8A987FBB5' -only-testing:VelaTests/HealthFoundationTests` succeeds.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/HealthFoundationTests/testHealthPermissionTiersRequestCumulativeReadTypes` fails before the HealthKit permission tier fix and succeeds after enhanced/advanced tiers become cumulative.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/HealthFoundationTests` succeeds after replacing the HealthFoundation placeholder test.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the HealthAuthorizationService cumulative-tier fix.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/VelaThemeTests` succeeds after adding the Debug initial-tab argument parser, localized data-coverage reason, and localized default workout template titles.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/VelaThemeTests/testOnboardingStoredValuesRenderAsLocalizedLabelsAndBrief` fails before the Onboarding display mapping exists and succeeds after localized setup labels and first-brief text are added.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/VelaThemeTests` succeeds after the Debug force-onboarding launch argument and sticky Onboarding CTA changes.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after Settings copy polish and Body Model display localization.
- `rg -n " / (Low|Medium|High|Muscle|Fat|Performance|Health|Beginner|Intermediate|Advanced|Direct|Detailed|Encouraging|GOAL|PREFERENCE|EQUIPMENT|COACH STYLE)|home \\+ gym" VelaApp/Features/Minimal/VelaMinimalJournalView.swift` reports no remaining mixed-language Body Model labels after the Me tab and editor localization pass.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/ScoringEngineTests/testDailyOperatingPlanDisplayModelLocalizesChineseTrainingFallbacks` fails before `DailyOperatingPlanDisplayModel` exists and succeeds after Training/Coach plan summaries are localized.
- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/ScoringEngineTests` succeeds after adding `DailyOperatingPlanDisplayModel`.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug -only-testing:VelaTests/PersistenceFoundationTests` succeeds after the privacy inventory and deletion controls.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=FFB9F219-D1D9-4FAD-B5E6-C6E8A987FBB5' -only-testing:VelaTests/PersistenceFoundationTests` succeeds.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,id=FFB9F219-D1D9-4FAD-B5E6-C6E8A987FBB5'` succeeds for the full test suite.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after the TrainingView, Coach prompt, placeholder cleanup, parser safety, and background-task safety changes.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after the MemoryLedger confidence clamp.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after replacing PromptComposer placeholder tests and tightening web-search routing.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after AgentActionParser action-order and HealthKit permission-tier fixes.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after removing forced range unwraps from AgentActionParser and WebSearchHelper.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after traceable web-search source formatting.
- `xcodebuild build-for-testing -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds after the Coach plan-card localization and Training-route fix.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after Training/Coach Chinese localization polish.
- `xcodebuild test-without-building -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug` succeeds for the full test suite after Onboarding, Settings, and Body Model localization polish. Latest xcresult: `/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-dvebdodmkwkcafenssskczadjxkj/Logs/Test/Test-Vela-2026.06.18_00-03-37-+0800.xcresult`.
- `rg -n "fatalError|preconditionFailure|try!|as!|Range\\([^\\n]+\\)!|XCTAssertTrue\\(true\\)|TODO|FIXME|not implemented|未实现" VelaApp VelaAppTests` still only reports the ModelContainer last-resort `preconditionFailure` and the standard unavailable UIKit `init(coder:)` initializer.
- `rg -n "fatalError|preconditionFailure|try!|as!|Range\\([^\\n]+\\)!|XCTAssertTrue\\(true\\)|TODO|FIXME|not implemented|未实现" VelaApp VelaAppTests` still only reports the ModelContainer last-resort `preconditionFailure` and the standard unavailable UIKit `init(coder:)` initializer after the latest UI polish pass.
- Simulator visual QA confirms the Today command center renders after cold start. First launch shows the system location permission prompt; dismissing it reveals the rebuilt Today surface with conservative missing-data guidance.
- Simulator visual QA after the data coverage slice confirms Today renders the new data confidence card without blank state or obvious overlap. Screenshot: `/tmp/vela-qa/today-data-coverage-delayed.png`.
- 2026-06-17 23:07 simulator visual QA confirms the rebuilt Today command center launches on iPhone 17 simulator, renders the conservative missing-data state, confidence card, key vitals section, and floating tab bar without blank screen or obvious text overlap. Screenshot: `/tmp/vela-qa/epic-release-today-2307.png`.
- Today content uses `.padding(.bottom, 140)` inside the main `ScrollView`, so lower cards remain reachable above the floating tab bar.
- 2026-06-17 23:36 simulator visual QA confirms the Training tab launches directly with `-velaInitialTab 1`; the adaptive training cockpit is localized in Chinese, source/safety copy is user-facing, default template names are localized, and the floating tab bar does not cover primary actions. Screenshot: `/tmp/vela-qa/training-localized-polished.png`.
- 2026-06-17 23:39 simulator visual QA confirms the Coach tab launches directly with `-velaInitialTab 3`; the intelligence workspace, data coverage strip, and plan card render without blank state, and the visible plan card no longer exposes raw English payload text. Screenshot: `/tmp/vela-qa/coach-localized-plan-card.png`.
- 2026-06-17 23:52 simulator visual QA confirms Onboarding launches directly with `-velaForceOnboarding`, renders localized Chinese setup controls without raw stored-value keys, and keeps the primary Apple Health CTA visible in a fixed bottom action area. Screenshot: `/tmp/vela-qa/onboarding-sticky-cta.png`.
- 2026-06-18 00:02 simulator visual QA confirms the Me tab launches directly with `-velaInitialTab 4`; Body Model cards now show localized equipment and confidence labels without `home + gym` or `Low` leakage. Screenshot: `/tmp/vela-qa/me-localized-body-model.png`.
- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'id=00008140-00164DE022C3801C' -configuration Debug -allowProvisioningUpdates build` succeeds.
- `xcrun devicectl device install app --device 00008140-00164DE022C3801C .../Debug-iphoneos/Vela.app` succeeds.
- `xcrun devicectl device process launch --device 00008140-00164DE022C3801C com.sunweizhou.Vela` succeeds.
- Earlier device re-validation after the privacy/data coverage slices was blocked because Xcode no longer listed the iPhone destination and `xcrun devicectl list devices` reported `Weizhou的iPhone` as `unavailable`.
- 2026-06-17 23:06 device re-validation succeeds: `xcrun devicectl list devices` reports `Weizhou的iPhone` available as `B1B2A1DB-2B5C-5C02-A222-B051240A22EA`.
- `xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS,name=Weizhou的iPhone' -configuration Debug -allowProvisioningUpdates build` succeeds after the AgentActionParser, PromptComposer, HealthAuthorizationService, and MemoryLedger changes.
- `xcrun devicectl device install app --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA /Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-dvebdodmkwkcafenssskczadjxkj/Build/Products/Debug-iphoneos/Vela.app` succeeds.
- `xcrun devicectl device process launch --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA com.sunweizhou.Vela` succeeds.
- 2026-06-18 00:05 device re-validation succeeds after the latest Onboarding/Settings/Body Model polish: device build, install, and `devicectl` launch all succeed for `Weizhou的iPhone`.
