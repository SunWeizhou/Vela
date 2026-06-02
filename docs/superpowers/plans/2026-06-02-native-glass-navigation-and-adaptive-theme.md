# Native Glass Navigation and Adaptive Theme Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the misaligned iOS 26 bottom quick action, add restrained destination transitions, and make the touched Vela surfaces follow system light and dark appearance.

**Architecture:** Keep native `TabView` navigation for the four destinations on iOS 26 and omit quick actions from the bottom navigation so the system owns alignment and scroll minimization. Centralize the touched light and dark colors in `VelaTheme`, use a small navigation policy for testable behavior, and preserve the existing custom fallback navigation for older releases.

**Tech Stack:** SwiftUI, XCTest, iOS 17 compatibility, iOS 26 Liquid Glass APIs

---

### Task 1: Remove Quick Actions from iOS 26 Bottom Navigation

**Files:**
- Modify: `VelaApp/Features/Minimal/VelaMinimalShell.swift`
- Test: `VelaAppTests/VelaThemeTests.swift`

- [ ] **Step 1: Write failing regression tests**

Add a test that requires `VelaTabSelection.contentTabs` to exclude quick actions.

```swift
func testNativeDestinationTabsExcludeQuickAction() {
    XCTAssertEqual(VelaTabSelection.contentTabs, [.today, .training, .vitals, .coach])
}

```

- [ ] **Step 2: Verify the new tests fail**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VelaTests/VelaThemeTests/testNativeDestinationTabsExcludeQuickAction \
  test
```

Expected: FAIL because `contentTabs` is not exposed by `VelaTabSelection`.

- [ ] **Step 3: Implement the independent action**

In `VelaMinimalShell.swift`:

- Remove `.quickAdd` from `VelaTab`.
- Make `VelaTabSelection.contentTabs` the canonical content destination list.
- Remove the iOS 26 `.search` role `Tab`.
- Do not render a trailing overlay quick-action button.
- Keep the system `TabView` responsible for bottom navigation alignment and `.tabBarMinimizeBehavior(.onScrollDown)`.
- Remove the independent `+` from the iOS 17 and iOS 18 compatibility navigation.

- [ ] **Step 4: Verify the targeted tests pass**

Run the Task 1 command again.

Expected: `** TEST SUCCEEDED **`.

### Task 2: Add Restrained Destination Transitions

**Files:**
- Modify: `VelaApp/Features/Minimal/VelaMinimalShell.swift`
- Test: `VelaAppTests/VelaThemeTests.swift`

- [ ] **Step 1: Write a failing transition-policy test**

```swift
func testDestinationTransitionUsesRestrainedOpacityDuration() {
    XCTAssertEqual(VelaNavigationMotion.destinationFadeDuration, 0.18, accuracy: 0.001)
}
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VelaTests/VelaThemeTests/testDestinationTransitionUsesRestrainedOpacityDuration \
  test
```

Expected: FAIL because `VelaNavigationMotion` does not exist.

- [ ] **Step 3: Implement the transition policy**

Add:

```swift
enum VelaNavigationMotion {
    static let destinationFadeDuration = 0.18
}
```

Use the duration for the native content opacity transition and for the fallback tab content change. Keep the animation limited to opacity.

- [ ] **Step 4: Verify the targeted test passes**

Run the Task 2 command again.

Expected: `** TEST SUCCEEDED **`.

### Task 3: Adopt Apple-Style Adaptive Theme Tokens

**Files:**
- Modify: `VelaApp/Core/Theme/VelaTheme.swift`
- Modify: `VelaApp/Features/Minimal/VelaMinimalShell.swift`
- Modify: `VelaApp/Features/SharedComponents/VelaQuickActionsSheet.swift`
- Test: `VelaAppTests/VelaThemeTests.swift`

- [ ] **Step 1: Write failing token tests**

Add tests that resolve adaptive UI colors under explicit light and dark traits.

```swift
func testThemeBackgroundUsesAppleWhiteAndBlackCanvases() {
    XCTAssertEqual(VelaTheme.backgroundUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)), UIColor.white)
    XCTAssertEqual(VelaTheme.backgroundUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)), UIColor.black)
}
```

- [ ] **Step 2: Verify the test fails**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:VelaTests/VelaThemeTests/testThemeBackgroundUsesAppleWhiteAndBlackCanvases \
  test
```

Expected: FAIL because `backgroundUIColor` does not exist and the current light and dark canvas values are warm neutrals.

- [ ] **Step 3: Implement adaptive theme tokens**

In `VelaTheme.swift`:

- Expose a testable adaptive `backgroundUIColor`.
- Change `bg` to use pure white in light appearance and pure black in dark appearance.
- Update grouped, surface, card, elevated, border, and subtle fill aliases to adaptive Apple-style neutral values.

In `VelaMinimalShell.swift` and `VelaQuickActionsSheet.swift`:

- Replace touched fixed warm canvases with `VelaTheme.bg`.
- Replace touched fixed white cards, dark text, muted text, and borders with adaptive tokens.
- Keep semantic accent colors.

- [ ] **Step 4: Verify the targeted theme test passes**

Run the Task 3 command again.

Expected: `** TEST SUCCEEDED **`.

### Task 4: Verify and Deploy

**Files:**
- Verify: all modified files

- [ ] **Step 1: Check patch formatting**

Run:

```bash
git diff --check
```

Expected: no output and exit code `0`.

- [ ] **Step 2: Run the full simulator suite**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Build the signed iPhone app**

Run:

```bash
xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug \
  -destination 'platform=iOS,id=00008140-00164DE022C3801C' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Install and launch on the connected iPhone**

Run:

```bash
xcrun devicectl device install app \
  --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA \
  '/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app'
xcrun devicectl device process launch \
  --device B1B2A1DB-2B5C-5C02-A222-B051240A22EA \
  com.sunweizhou.Vela
```

Expected: installation succeeds and Vela launches.
