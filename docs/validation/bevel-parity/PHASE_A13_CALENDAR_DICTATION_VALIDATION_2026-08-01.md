# VALIDATION EVIDENCE

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 历史视觉与功能验证证据（仅作历史测试回归参考）

---

# Phase A13 · Calendar and Dictation · 2026-08-01

## Outcome

- Added a Coach dictation control backed by Apple Speech and the microphone audio session.
- Dictation only updates the editable, unsent draft; stopping or recognition completion never sends a message automatically.
- Added a Calendar Context sheet with an app-level explanation before the system permission request.
- Calendar reads are limited to the next seven days and only user-selected events are inserted into the unsent Coach draft.
- Added an explicit reviewed event form. A calendar write occurs only after the user enters a title, date and duration and taps `添加`.
- Added microphone, speech-recognition and full-calendar-access purpose strings.
- Existing outbound-data consent remains the boundary applied when the user later sends a draft containing selected calendar context.

## Files

- `VelaApp/Features/Coach/CoachView.swift`
- `VelaApp/Vela-Info.plist`
- `VelaAppTests/VelaThemeTests.swift`

## Automated verification

- Simulator: iPhone 17 Pro, iOS 26.5
- Result bundle: `/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_18-26-11-+0800.xcresult`
- Result: 1 passed, 0 failed
  - `testCalendarContextFormatsOnlyExplicitlySelectedEvents`
- `plutil -lint VelaApp/Vela-Info.plist`: passed.

## Visual and accessibility verification

- Confirmed `添加 Coach 上下文`, `日历上下文`, `开始听写`, and disabled-empty `发送消息` controls in the accessibility tree.
- Confirmed the pre-permission sheet explains the seven-day read window and selected-event-only draft behavior.
- Did not grant calendar or microphone permission during validation.
- Screenshot: `docs/validation/bevel-parity/screenshots/a13-calendar-prepermission-2026-08-01.png`

## Safety boundary

- Calendar reads and writes are triggered by explicit user interaction.
- Calendar data is not silently appended to prompts.
- No event is created from an AI response without the separate system-calendar review form and final Add action.
