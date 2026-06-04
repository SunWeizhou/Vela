# Vela 3.0 Audit

> Date: 2026-06-04  
> Scope: Vela 3.0 Active Coach OS upgrade baseline audit before implementation.

## Baseline Verification

- Xcode project: `Vela.xcodeproj`
- Targets found: `Vela`, `VelaTests`
- Scheme found: `Vela`
- iPhoneOS build command: `xcodebuild -project Vela.xcodeproj -scheme Vela -sdk iphoneos -configuration Debug build`
- iPhoneOS build result: succeeded on 2026-06-04.
- iOS test command: `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`
- iOS test result: succeeded on 2026-06-04; 35 tests passed.
- Backend test command: `swift test` in `VelaBackend`
- Backend test result: succeeded on 2026-06-04; 3 tests passed.
- Current branch: `codex/vela-3-active-coach-os`
- Latest commit: `e25f72b` — audit-driven bug fix round (8 fixes: sleep HR, N+1 queries, dailyLoad, baseline roundtrip, confidence degradation, reps parsing, TrainingDay compat, journal correlation)

## Reusable Modules

- Root app state and routing: `VelaApp/App/VelaApp.swift`, `VelaApp/App/AppCoordinator.swift`, `VelaApp/Features/Minimal/VelaMinimalShell.swift`.
- Design tokens and base components: `VelaApp/Core/Theme/VelaTheme.swift`, `VelaApp/Core/DesignSystem/VelaDesignSystem.swift`.
- Dashboard aggregation: `DashboardSummary`, `DashboardViewModel`, `DailySummaryUseCase`, `MetricComputationPipeline`.
- Scoring engines: Sleep, Recovery, Strain, Stress, Energy Bank, Training, Daily Plan, Body Interpreter.
- HealthKit/data cache: `HealthKitQueryService`, `HealthKitSyncEngine`, `DailyHealthSummaryRecord`, `SwiftDataDailyHealthSummaryRepository`.
- Training intelligence: `TrainingAnalyticsService`, `RecoveryTrainingAdapter`, `ExerciseLibraryService`, `TrainingPlanLinkingService`.
- Training persistence: `StrengthWorkoutRecord`, `StrengthExerciseLog`, `StrengthSetLog`, `WorkoutEventRecord`, `WorkoutTemplateRecord`, `ActiveWorkoutDraftRecord`, `TrainingResponseRecord`.
- AI context and memory: `AIContextBuilder`, `TypedContextSchema`, `AgentActionParser`, `MemoryLedger`, `WikiFileService`, `MemoryEventRecord`.
- Backend AI API: Vapor routes for Coach, Today, Training, Insights, Memory, Settings, Trust.

## Pages To Migrate

- Current top-level tabs are `首页 / 手记 / 健身 / 体征 / Coach`.
- Vela 3.0 target tabs are `Today / Training / Insights / Coach / Me`.
- Keep and upgrade current Today as `Today Command Center`.
- Move current Fitness/Training Intelligence under `Training`.
- Move current Vitals/metric detail pages under `Insights`.
- Move Journal, Wiki profile, Settings, Trust Center, Data Coverage, Biology into `Me`.
- Keep Coach chat, but make artifact inbox the first Coach surface.

## Current Data Models

- Daily cache: `DailyHealthSummaryRecord`, `SleepSummaryRecord`.
- Journal and reports: `JournalEntryRecord`, `AIReportRecord`, `FoodLogRecord`.
- Wiki/memory: `UserWikiDocumentRecord`, `MemoryEventRecord`, `AgentRunRecord`.
- Coach sessions: `CoachSessionRecord`.
- Training facts: `StrengthWorkoutRecord`, `WorkoutEventRecord`, `ExerciseDefinitionRecord`, `WorkoutTemplateRecord`, `ActiveWorkoutDraftRecord`.
- Training adaptation/response: `TrainingPlanRecord`, `TrainingPlanAdaptationRecord`, `TrainingResponseRecord`.
- Biomarkers and Xunji mirror/cache are already modeled.

## AI Context / Prompt / Parser Flow

- `AIContextBuilder.build` creates `AgentContextEnvelope` for LLM calls and already includes `strength_training`.
- `AIContextBuilder.buildTyped` creates `TypedAgentContext` and uses `TrainingAnalyticsService` for recent strength summaries.
- `CoachChatVM` streams answers through the configured provider and persists sessions.
- `AgentActionParser` currently parses legacy `[ACTION:...]` blocks for wiki/log actions.
- Missing for Vela 3.0: structured `CoachArtifact` JSON parser, artifact persistence, artifact UI cards, and action routing for artifact buttons.

## Training Record Capability Gaps

- Existing sheet supports template start, exercise list, set logging, warmup flag, RPE/RIR, copy previous set, complete-set button, rest timer, draft save, summary sheet, and DailyHealthSummary sync.
- Existing analytics calculate volume, effective sets, muscle groups, e1RM, PR, density, fatigue, and recent summaries.
- Remaining gaps: make the session loop more explicit from the Training hub, persist post-workout review artifacts, surface readiness alignment in the summary, and make template/action CTAs clearer.

## UI / Design System Gaps

- Current UI has a strong Bevel-like light visual standard. Vela 3.0 docs request dark-first, but repository guidance marks the light Bevel parity style as the current frontend standard.
- Decision: preserve existing Bevel-parity light surface while adding semantic Vela 3.0 components and dark-compatible tokens instead of replacing the entire style.
- Missing named Vela 3.0 components: `VelaPageShell`, `VelaHeroCard`, `MetricScoreCard`, `CoachArtifactCard`, `EvidenceSheet`, `ActionPill`, `SignalRow`, `TrendChartCard`, `DataSourceBadge`, `ConfidenceBadge`, `WorkoutSessionCard`, `SetInputRow`.

## Implementation Decisions

- Do not modify `project.pbxproj` for new Swift files. Extend already registered Swift files and existing test files.
- Add new SwiftData models in `PersistenceModels.swift` and register them in `VelaModelContainer`.
- Reuse existing `HealthSignal` enum name for permissions; use `TodayHealthSignal` for Today evidence rows to avoid a module name collision.
- Treat Vela 3.0 PRD and execution plan as approved specs; no additional user approval gates.

## Implemented Vela 3.0 Scope

- Added Body Model onboarding persistence with goals, training preference, equipment, coaching preference, initial body snapshot, missing data, first brief, and first action plan.
- Added `CoachArtifact` domain objects, parser fallback behavior, SwiftData persistence, schema registration, and post-workout review artifact creation from strength workout saves.
- Added Today Command State and local readiness builder using recovery, sleep, strain, HRV/RHR, recent strength summary, confidence, suggested actions, and evidence rows.
- Added Vela 3.0 semantic UI components while keeping Bevel parity: hero cards, metric cards, artifact cards, evidence sheet, action pills, signal rows, source/confidence badges, and training/session rows.
- Remapped root navigation to `Today / Training / Insights / Coach / Me`; Journal, Wiki, Biology, Data Coverage, Trust Center, AI settings, and Settings are reachable from Me.
- Added Today Command Center to Today, including readiness decision, action routing, evidence sheet, key signals, and latest Coach artifact.
- Added Coach artifact dashboard/inbox above the chat welcome state, with artifact action routing.
- Added onboarding Body Model into legacy and typed AI context through merged `userWiki` keys and metadata sections.

## Final Verification

- `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'`: succeeded on 2026-06-04; 35 tests passed.
- `swift test` in `VelaBackend`: succeeded on 2026-06-04; 3 tests passed.
- `xcodebuild -project Vela.xcodeproj -scheme Vela -sdk iphoneos -configuration Debug build`: succeeded on 2026-06-04 with the configured Apple Development signing profile.
