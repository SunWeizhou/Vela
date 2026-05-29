# Home and Shell Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework Vela Home and the bottom shell into a tighter Bevel 3.0-class daily health loop that shows state, cause, action, and data trust in the first viewport.

**Architecture:** Keep the current SwiftUI/SwiftData/HealthKit architecture. Add small Home-specific presentation helpers inside `HomeView.swift` first because the file already owns the Bevel-like Home shell; only extract later if the helper surface grows. Reuse `DashboardSummary`, `DailyPlanRecommendation`, `VelaTheme`, and existing route destinations.

**Tech Stack:** SwiftUI, SwiftData query wrappers, HealthKit-backed `DashboardViewModel`, existing Vela theme tokens, XCTest build/test flow through `xcodebuild`.

---

## Files

- Modify: `VelaApp/Features/Home/HomeView.swift`
  - Add Home data trust presentation.
  - Tighten header actions.
  - Add daily plan/trust row directly under the primary rings.
  - Move duplicated lower score grid below the first daily loop.
- Modify: `VelaApp/App/VelaRootView.swift`
  - Audit bottom shell sizing and labels after Home changes.
- Test: `VelaAppTests/VelaThemeTests.swift`
  - Add a simple adaptive token regression if code changes theme use.
- Reference only: `docs/superpowers/specs/2026-05-25-bevel-3-parity-design.md`

## Task 1: Add Home Data Trust Helpers

- [ ] **Step 1: Add presentation helpers near `HomeReadinessBrief` in `VelaApp/Features/Home/HomeView.swift`**

```swift
private struct HomeDataTrust: Hashable {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color
}

private extension HomeDataTrust {
    static func make(dashboard: DashboardSummary, isLoading: Bool, errorMessage: String?) -> HomeDataTrust {
        if isLoading {
            return HomeDataTrust(
                title: L10n.t("Syncing", "同步中"),
                detail: L10n.t("Refreshing Health data", "正在刷新健康数据"),
                systemImage: "arrow.triangle.2.circlepath",
                tint: VelaTheme.energy
            )
        }

        if errorMessage != nil {
            return HomeDataTrust(
                title: L10n.t("Needs attention", "需要处理"),
                detail: L10n.t("Check Health permissions", "检查健康权限"),
                systemImage: "exclamationmark.triangle.fill",
                tint: VelaTheme.stress
            )
        }

        if dashboard.recovery.hasData || dashboard.sleepScore.hasData || dashboard.strain.hasData {
            return HomeDataTrust(
                title: L10n.t("Fresh today", "今日已更新"),
                detail: L10n.t("Apple Health connected", "Apple Health 已连接"),
                systemImage: "checkmark.seal.fill",
                tint: VelaTheme.recovery
            )
        }

        return HomeDataTrust(
            title: L10n.t("Building baseline", "正在建立基线"),
            detail: L10n.t("Wear Apple Watch overnight", "夜间佩戴 Apple Watch"),
            systemImage: "clock.badge.checkmark",
            tint: VelaTheme.sleep
        )
    }
}
```

- [ ] **Step 2: Build to catch type errors**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds or fails only on pre-existing unrelated signing/device issues.

## Task 2: Tighten Home Header

- [ ] **Step 1: Replace the current `headerBar` body with compact date, trust, share, and profile actions**

Use this shape inside `private var headerBar: some View` while preserving any existing route actions that are still needed:

```swift
private var headerBar: some View {
    let trust = HomeDataTrust.make(
        dashboard: viewModel.dashboard,
        isLoading: viewModel.isLoading,
        errorMessage: viewModel.errorMessage
    )

    return HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedHomeDate)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.secondaryText)

            HStack(spacing: 6) {
                Image(systemName: trust.systemImage)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(trust.tint)
                Text(trust.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(trust.detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(1)
            }
        }

        Spacer()

        Button {
            VelaAppState.shared.routeToCoach(question: L10n.t(
                "Create a concise shareable summary of my current recovery, sleep, strain, stress, energy, and today's action.",
                "请基于我当前的恢复、睡眠、负荷、压力、能量和今日行动，生成一段适合分享的简洁总结。"
            ))
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VelaTheme.primaryText)
                .frame(width: 36, height: 36)
                .background(Circle().fill(VelaTheme.elevatedSurface))
                .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.6))
        }
        .buttonStyle(.plain)

        NavigationLink {
            SettingsView()
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(VelaTheme.primaryText, VelaTheme.elevatedSurface)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: If `headerBar` already contains unique layout/edit controls, move them into the lower customization panel instead of deleting their behavior.**

- [ ] **Step 3: Build**

Run the same generic iOS build command. Expected: build succeeds.

## Task 3: Add Bevel-Style Daily Plan Strip

- [ ] **Step 1: Add a `bevelDailyPlanStrip` computed view below `bevelPrimaryRingsCard` helpers**

```swift
private var bevelDailyPlanStrip: some View {
    let brief = HomeReadinessBrief.make(dashboard: viewModel.dashboard, plan: dailyPlan)
    let trust = HomeDataTrust.make(
        dashboard: viewModel.dashboard,
        isLoading: viewModel.isLoading,
        errorMessage: viewModel.errorMessage
    )

    return VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "target")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(brief.accent.color)
                .frame(width: 34, height: 34)
                .background(Circle().fill(brief.accent.color.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(brief.statusLabel)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(brief.nextAction)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                VelaAppState.shared.routeToCoach(question: brief.coachQuestion)
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(VelaTheme.subtleFill))
            }
            .buttonStyle(.plain)
        }

        HStack(spacing: 8) {
            Label(trust.title, systemImage: trust.systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(trust.tint)
            Text(localizedReason(brief.why))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(2)
        }
    }
    .bevelGlassCard(padding: 14)
}
```

- [ ] **Step 2: Insert the strip immediately after `bevelPrimaryRingsCard` in `bevelHomeDashboard`**

```swift
bevelPrimaryRingsCard
bevelDailyPlanStrip
bevelStressEnergySection
bevelNutritionCard
```

- [ ] **Step 3: Build**

Run the generic iOS build command. Expected: build succeeds.

## Task 4: Reduce First-Viewport Duplication

- [ ] **Step 1: In `HomeView.body`, move the 2x2 score grid below `upgradedInsightCard` and compact cards, or hide it when the primary rings are visible.**

Preferred minimal implementation:

```swift
let visibleScores = layoutStore.layout.scoreCards.filter { $0 != .sleep && $0 != .strain && $0 != .recovery }
```

Use the filtered `visibleScores` for the lower score grid so Sleep/Strain/Recovery do not repeat immediately after the primary rings.

- [ ] **Step 2: Keep Energy visible if the lower grid would otherwise become empty**

If filtering removes all cards and `.energy` is enabled, show Energy. If no score card remains, skip the grid.

- [ ] **Step 3: Build**

Run the generic iOS build command. Expected: build succeeds.

## Task 5: Bottom Shell Safe-Area Audit

- [ ] **Step 1: Inspect `VelaApp/App/VelaRootView.swift`**

Keep the custom shell inside `.safeAreaInset(edge: .bottom)` and ensure page content has at least `88` points of bottom inset, matching current Home behavior.

- [ ] **Step 2: If labels wrap in Chinese or English, lower tab title size no smaller than 9 and keep `.minimumScaleFactor(0.76)`**

Do not remove the central `+` action.

- [ ] **Step 3: Build**

Run the generic iOS build command. Expected: build succeeds.

## Task 6: Verification

- [ ] **Step 1: Run tests**

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug
```

Expected: tests pass if the simulator runtime is installed. If the named simulator is unavailable, run:

```bash
xcrun simctl list devices available
```

Then rerun with an available iPhone simulator.

- [ ] **Step 2: Run a final generic iOS build**

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela -destination 'generic/platform=iOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Expected: build succeeds.

- [ ] **Step 3: Manual visual checks**

Check:

- Home first viewport shows date, data trust, three primary rings, guidance, daily plan/trust strip, stress/energy, and nutrition.
- Sleep/Strain/Recovery are not duplicated immediately below the primary rings.
- Share and profile actions are tappable.
- Bottom shell does not cover Home content.
- No visible text overlaps in English or Chinese.

## Plan Self-Review

- Spec coverage: This plan implements Milestone 1 from the design spec. Later milestones are intentionally covered by separate plans because Intelligence, Vitals/Biology, Fitness/Training, Journal/Nutrition, and Sharing are independent subsystems.
- Placeholder scan: No TBD/TODO placeholders are present.
- Type consistency: New helpers use existing `DashboardSummary`, `ScoreConfidence`, `VelaTheme`, `DailyPlanRecommendation`, `HomeReadinessBrief`, `AppLanguage`, and `L10n` names already present in the project.
