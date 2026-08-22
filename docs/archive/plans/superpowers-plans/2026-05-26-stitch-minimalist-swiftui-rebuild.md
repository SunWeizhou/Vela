# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Stitch Minimalist SwiftUI Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Vela's current SwiftUI front end with a native SwiftUI rebuild derived from the Stitch HTML set, using `vela_vitals_tab_minimalist/code.html` as the canonical visual system.

**Architecture:** Add a focused minimalist UI layer that preserves the existing data and service stack. The first shippable slice creates shared visual primitives, switches the root shell, rebuilds Vitals as the reference page, and wires Today/Fitness/Journal/Coach with matching minimalist screens that can be deepened screen-by-screen.

**Tech Stack:** SwiftUI, SwiftData environment, existing `DashboardViewModel`, existing `VelaAppState`, existing HealthKit/scoring/AI services, Xcode project file references.

---

## File Structure

- Modify `VelaApp/Core/Theme/VelaTheme.swift`: replace warm Claude-style tokens with the canonical Stitch Vitals minimalist palette.
- Modify `VelaApp/Core/Theme/VelaBackground.swift`: add the near-white/cool minimalist background and glass surface modifiers.
- Create `VelaApp/Features/Minimal/VelaMinimalComponents.swift`: shared app bar, floating tab bar, glass panel, bento card, chips, rows, sleep architecture bar, and format helpers.
- Create `VelaApp/Features/Minimal/VelaMinimalShell.swift`: new root shell with top bar, floating bottom nav, tab routing, and existing modal routing.
- Create `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`: Today tab using real dashboard data and Stitch-style cards.
- Create `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift`: canonical Vitals tab rebuilt from `vela_vitals_tab_minimalist`.
- Create `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`: Fitness tab using existing strain/workout data and matching visual style.
- Create `VelaApp/Features/Minimal/VelaMinimalJournalView.swift`: Journal/logging tab with entries/actions and links to existing logging flows.
- Create `VelaApp/Features/Minimal/VelaMinimalCoachView.swift`: Coach tab entry that routes into existing `CoachView`.
- Modify `VelaApp/App/VelaRootView.swift`: replace the current `TabView` shell with `VelaMinimalShell`.
- Modify `Vela.xcodeproj/project.pbxproj`: add new Swift files to the app target.
- Test existing `VelaAppTests/VelaThemeTests.swift`: update theme expectations if they assert old warm tokens.

## Task 1: Encode Minimalist Visual Tokens

**Files:**
- Modify: `VelaApp/Core/Theme/VelaTheme.swift`
- Modify: `VelaApp/Core/Theme/VelaBackground.swift`
- Test: `VelaAppTests/VelaThemeTests.swift`

- [ ] **Step 1: Inspect current theme tests**

Run:

```bash
sed -n '1,220p' VelaAppTests/VelaThemeTests.swift
```

Expected: identify whether tests assert exact old warm colors or only adaptive behavior.

- [ ] **Step 2: Update `VelaTheme.swift` palette**

Change the public token values to match the Vitals minimalist source:

```swift
static let background = adaptiveColor(
    light: UIColor(red: 0.976, green: 0.976, blue: 1.000, alpha: 1),
    dark: UIColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1)
)
static let backgroundSecondary = adaptiveColor(
    light: UIColor(red: 0.945, green: 0.953, blue: 1.000, alpha: 1),
    dark: UIColor(red: 0.090, green: 0.106, blue: 0.133, alpha: 1)
)
static let backgroundTertiary = adaptiveColor(
    light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 1),
    dark: UIColor(red: 0.125, green: 0.141, blue: 0.176, alpha: 1)
)
static let surface = adaptiveColor(
    light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.70),
    dark: UIColor(red: 0.125, green: 0.141, blue: 0.176, alpha: 0.70)
)
static let elevatedSurface = adaptiveColor(
    light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.82),
    dark: UIColor(red: 0.165, green: 0.188, blue: 0.239, alpha: 0.82)
)
static let stroke = adaptiveColor(
    light: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.55),
    dark: UIColor(red: 1.000, green: 1.000, blue: 1.000, alpha: 0.10)
)
static let primaryText = adaptiveColor(
    light: UIColor(red: 0.082, green: 0.110, blue: 0.157, alpha: 1),
    dark: UIColor(red: 0.925, green: 0.941, blue: 1.000, alpha: 1)
)
static let secondaryText = adaptiveColor(
    light: UIColor(red: 0.259, green: 0.278, blue: 0.325, alpha: 1),
    dark: UIColor(red: 0.760, green: 0.784, blue: 0.840, alpha: 1)
)
static let mutedText = adaptiveColor(
    light: UIColor(red: 0.447, green: 0.467, blue: 0.518, alpha: 1),
    dark: UIColor(red: 0.620, green: 0.651, blue: 0.714, alpha: 1)
)
static let accent = adaptiveColor(
    light: UIColor(red: 0.000, green: 0.345, blue: 0.737, alpha: 1),
    dark: UIColor(red: 0.678, green: 0.776, blue: 1.000, alpha: 1)
)
```

Keep semantic colors available:

```swift
static let recovery = adaptiveColor(
    light: UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 1),
    dark: UIColor(red: 0.396, green: 0.859, blue: 0.482, alpha: 1)
)
static let energy = adaptiveColor(
    light: UIColor(red: 1.000, green: 0.800, blue: 0.000, alpha: 1),
    dark: UIColor(red: 1.000, green: 0.843, blue: 0.180, alpha: 1)
)
static let stress = adaptiveColor(
    light: UIColor(red: 1.000, green: 0.231, blue: 0.188, alpha: 1),
    dark: UIColor(red: 1.000, green: 0.455, blue: 0.420, alpha: 1)
)
```

- [ ] **Step 3: Update `VelaBackground.swift`**

Use a cool background with a subtle top glow:

```swift
struct VelaBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [VelaTheme.background, VelaTheme.backgroundSecondary, VelaTheme.backgroundTertiary],
                startPoint: .top,
                endPoint: .bottom
            )
            Circle()
                .fill(VelaTheme.accent.opacity(0.055))
                .frame(width: 420, height: 420)
                .blur(radius: 72)
                .offset(y: -260)
        }
        .ignoresSafeArea()
    }
}
```

Update `CardSurface` and `HeroCardSurface` to use `.thinMaterial` or `VelaTheme.surface` with a white stroke and soft shadow, matching the Vitals glass panels.

- [ ] **Step 4: Run focused tests**

Run:

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:VelaTests/VelaThemeTests
```

Expected: theme tests pass, or failures only show exact old-token expectations that were updated in this task.

- [ ] **Step 5: Commit**

```bash
git add VelaApp/Core/Theme/VelaTheme.swift VelaApp/Core/Theme/VelaBackground.swift VelaAppTests/VelaThemeTests.swift
git commit -m "style: apply Stitch minimalist theme tokens"
```

## Task 2: Add Minimalist Shared Components

**Files:**
- Create: `VelaApp/Features/Minimal/VelaMinimalComponents.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create component file**

Add `VelaMinimalComponents.swift` with:

```swift
import SwiftUI

enum VelaMinimalTab: Int, CaseIterable, Identifiable {
    case today, vitals, fitness, journal, coach
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .today: return L10n.t("Today", "今日")
        case .vitals: return L10n.t("Vitals", "生命体征")
        case .fitness: return L10n.t("Fitness", "健身")
        case .journal: return L10n.t("Journal", "手记")
        case .coach: return L10n.t("Coach", "教练")
        }
    }
    var icon: String {
        switch self {
        case .today: return "square.grid.2x2.fill"
        case .vitals: return "waveform.path.ecg"
        case .fitness: return "figure.run"
        case .journal: return "book.closed.fill"
        case .coach: return "bubble.left.and.bubble.right.fill"
        }
    }
}
```

Add reusable views:

```swift
struct VelaMinimalGlassPanel<Content: View>: View {
    var padding: CGFloat = 20
    var radius: CGFloat = 24
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(VelaTheme.stroke, lineWidth: 0.8))
            .shadow(color: VelaTheme.cardShadowColor, radius: 18, y: 8)
    }
}

struct VelaMinimalValueText: View {
    let value: String
    var unit: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let unit {
                Text(unit)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
    }
}

struct VelaMinimalChip: View {
    let text: String
    var systemImage: String?
    var tint: Color = VelaTheme.accent

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text).font(.caption.weight(.bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.12)))
        .overlay(Capsule(style: .continuous).stroke(tint.opacity(0.18), lineWidth: 0.7))
    }
}
```

Also include `VelaMinimalAppBar`, `VelaMinimalFloatingTabBar`, `VelaMinimalBentoMetricCard`, `VelaMinimalRecordRow`, and `VelaMinimalSleepArchitectureBar` in the same file.

- [ ] **Step 2: Add file to Xcode project**

Add `VelaApp/Features/Minimal/VelaMinimalComponents.swift` to `PBXFileReference`, `PBXBuildFile`, the `VelaApp` group children, and the `Sources` build phase in `Vela.xcodeproj/project.pbxproj`.

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: build succeeds and no new component is unused in a way that causes compile failure.

- [ ] **Step 4: Commit**

```bash
git add VelaApp/Features/Minimal/VelaMinimalComponents.swift Vela.xcodeproj/project.pbxproj
git commit -m "feat: add minimalist SwiftUI components"
```

## Task 3: Build New Shell And Switch Root

**Files:**
- Create: `VelaApp/Features/Minimal/VelaMinimalShell.swift`
- Modify: `VelaApp/App/VelaRootView.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] **Step 1: Create shell**

Add `VelaMinimalShell`:

```swift
import SwiftUI

struct VelaMinimalShell: View {
    @ObservedObject private var appState = VelaAppState.shared
    @State private var selectedTab: VelaMinimalTab = .today
    @State private var showQuickActions = false
    @State private var showBloodLog = false
    @State private var showWeightLog = false

    var body: some View {
        ZStack {
            VelaBackground()
            activeTab
                .padding(.top, 88)
                .safeAreaPadding(.bottom, 104)

            VStack {
                VelaMinimalAppBar(
                    title: "Vela",
                    leadingSystemImage: "person.crop.circle.fill",
                    trailingSystemImage: "bell"
                ) {
                    selectedTab = .coach
                }
                Spacer()
            }

            VStack {
                Spacer()
                VelaMinimalFloatingTabBar(selectedTab: $selectedTab) {
                    showQuickActions = true
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
        .sheet(isPresented: $showQuickActions) {
            VelaQuickActionsSheet()
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBloodLog) {
            BloodLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeightLog) {
            WeightLogSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: appState.triggerBloodLog) { _, newValue in
            if newValue { appState.triggerBloodLog = false; showBloodLog = true }
        }
        .onChange(of: appState.triggerWeightLog) { _, newValue in
            if newValue { appState.triggerWeightLog = false; showWeightLog = true }
        }
        .fullScreenCover(isPresented: $appState.showCoachHub) {
            CoachView()
        }
    }

    @ViewBuilder private var activeTab: some View {
        switch selectedTab {
        case .today: VelaMinimalTodayView()
        case .vitals: VelaMinimalVitalsView()
        case .fitness: VelaMinimalFitnessView()
        case .journal: VelaMinimalJournalView()
        case .coach: VelaMinimalCoachView()
        }
    }
}
```

- [ ] **Step 2: Replace `VelaRootView` body**

Keep the tab-bar UIKit appearance init harmless, but make `body` return:

```swift
var body: some View {
    VelaMinimalShell()
        .tint(VelaTheme.accent)
}
```

- [ ] **Step 3: Add file to Xcode project**

Add `VelaMinimalShell.swift` to project references and app target sources.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: initial failure may report missing `VelaMinimalTodayView` and related feature screens; proceed to Task 4 before final shell commit if those screens are not created yet.

## Task 4: Rebuild Vitals As Canonical Page

**Files:**
- Create: `VelaApp/Features/Minimal/VelaMinimalVitalsView.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] **Step 1: Implement `VelaMinimalVitalsView`**

Use `DashboardViewModel` and `modelContext`. Include hero biological age, sleep architecture, vitals bento grid, health records list, and coach action:

```swift
struct VelaMinimalVitalsView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    biologicalAgeCard
                    sleepArchitectureCard
                    vitalsGrid
                    healthRecordsCard
                    coachCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
    }
}
```

Bind values from:

```swift
viewModel.dashboard.healthAge.trendScore
viewModel.dashboard.sleepSummary
viewModel.dashboard.recoveryMetrics.hrvMilliseconds
viewModel.dashboard.recoveryMetrics.restingHeartRate
viewModel.dashboard.recoveryMetrics.respiratoryRate
viewModel.dashboard.extendedMetrics.oxygenSaturation
viewModel.dashboard.bodyMetrics.weightKilograms
```

- [ ] **Step 2: Wire detail navigation**

Use existing destinations where available:

```swift
VitalsMetricDetailView(metric: .hrv).environmentObject(viewModel)
VitalsMetricDetailView(metric: .restingHeartRate).environmentObject(viewModel)
BiologyView().environmentObject(viewModel)
```

- [ ] **Step 3: Add file to Xcode project**

Add `VelaMinimalVitalsView.swift` to project references and app target sources.

- [ ] **Step 4: Build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: Vitals screen compiles and uses only existing model properties.

- [ ] **Step 5: Commit**

```bash
git add VelaApp/Features/Minimal/VelaMinimalVitalsView.swift Vela.xcodeproj/project.pbxproj
git commit -m "feat: rebuild Vitals in Stitch minimalist SwiftUI"
```

## Task 5: Add Main Tab Screens

**Files:**
- Create: `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`
- Create: `VelaApp/Features/Minimal/VelaMinimalFitnessView.swift`
- Create: `VelaApp/Features/Minimal/VelaMinimalJournalView.swift`
- Create: `VelaApp/Features/Minimal/VelaMinimalCoachView.swift`
- Modify: `Vela.xcodeproj/project.pbxproj`

- [ ] **Step 1: Implement Today**

Create Today with a hero readiness card, next action, metrics grid, and data trust card. Use:

```swift
viewModel.dashboard.recovery
viewModel.dashboard.sleepScore
viewModel.dashboard.strain
viewModel.dashboard.dailyInsight
viewModel.lastUpdated
```

- [ ] **Step 2: Implement Fitness**

Create Fitness with strain score, activity summary, workout rows, and recovery/training recommendation. Use:

```swift
viewModel.dashboard.strain
viewModel.dashboard.workouts
viewModel.fitnessActivityHistory
```

Run `await viewModel.loadFitnessActivityHistory(modelContext: modelContext)` in `.task`.

- [ ] **Step 3: Implement Journal**

Create Journal with glass action rows for journal entry, meal log, health data log, and history. Route existing quick actions through `VelaAppState.shared.triggerBloodLog`, `triggerWeightLog`, and existing sheet or navigation destinations.

- [ ] **Step 4: Implement Coach**

Create Coach landing with an AI summary card and button:

```swift
Button {
    VelaAppState.shared.showCoachHub = true
} label: {
    Label(L10n.t("Open Coach", "打开教练"), systemImage: "sparkles")
}
```

- [ ] **Step 5: Add files to Xcode project**

Add all four files to project references and app target sources.

- [ ] **Step 6: Build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: all five tabs compile and the root shell no longer references missing views.

- [ ] **Step 7: Commit**

```bash
git add VelaApp/Features/Minimal/VelaMinimalTodayView.swift VelaApp/Features/Minimal/VelaMinimalFitnessView.swift VelaApp/Features/Minimal/VelaMinimalJournalView.swift VelaApp/Features/Minimal/VelaMinimalCoachView.swift Vela.xcodeproj/project.pbxproj
git commit -m "feat: add minimalist main tabs"
```

## Task 6: Finish Shell Switch

**Files:**
- Modify: `VelaApp/App/VelaRootView.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalShell.swift`

- [ ] **Step 1: Map old selected tabs to new tab enum**

Keep compatibility with `VelaAppState.selectedTab`:

```swift
private var boundTab: Binding<VelaMinimalTab> {
    Binding(
        get: { VelaMinimalTab(rawValue: appState.selectedTab) ?? .today },
        set: { appState.selectedTab = $0.rawValue }
    )
}
```

Use `boundTab` in the floating tab bar instead of a local-only tab state.

- [ ] **Step 2: Preserve Coach routing**

When `VelaAppState.shared.routeToCoach(question:)` sets `showCoachHub`, keep the existing full-screen `CoachView` behavior. The Coach tab is a landing surface, not a replacement for the chat panel in this slice.

- [ ] **Step 3: Build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: app builds with the new minimalist shell as the default root UI.

- [ ] **Step 4: Commit**

```bash
git add VelaApp/App/VelaRootView.swift VelaApp/Features/Minimal/VelaMinimalShell.swift
git commit -m "feat: switch Vela root to minimalist shell"
```

## Task 7: Verify And Fix Compile/Layout Issues

**Files:**
- Modify only files touched by Tasks 1-6 unless a compile error identifies a direct dependency.

- [ ] **Step 1: Run app build**

Run:

```bash
xcodebuild build -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Run unit tests**

Run:

```bash
xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: existing tests pass, or failures are unrelated to the front-end migration and documented.

- [ ] **Step 3: Smoke primary tabs**

Launch on simulator or connected iPhone. Verify:

- Today renders first meaningful screen.
- Vitals shows biological age, sleep architecture, metrics grid, and health record rows.
- Fitness renders without clipped text.
- Journal action rows open or trigger existing flows.
- Coach tab can open `CoachView`.
- Floating bottom tab does not collide with home indicator.

- [ ] **Step 4: Fix issues**

For compile errors, adjust type/property names against existing models. For layout issues, keep fixes inside `VelaMinimalComponents.swift` or the affected minimal screen.

- [ ] **Step 5: Final commit**

```bash
git add VelaApp Vela.xcodeproj/project.pbxproj VelaAppTests
git commit -m "fix: verify minimalist SwiftUI rebuild"
```

## Self-Review

- Spec coverage: the plan covers canonical tokens, HTML-to-SwiftUI translation, root shell switching, Vitals-first reference implementation, main tab replacement, and preserving existing data/service layers.
- Scope control: secondary screens are acknowledged but not all rebuilt in this first executable slice; the main app can switch once the shell and top-level tabs are native and consistent.
- No web views: every task uses SwiftUI components.
- Risk: manual `project.pbxproj` edits are error-prone in this repo because file references are explicit. Verify build after each task.
