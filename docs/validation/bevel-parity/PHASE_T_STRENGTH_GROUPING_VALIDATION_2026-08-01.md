# Phase T — Strength Superset / Circuit 验证

日期：2026-08-01

## 交付结果

- Active Workout 中可以选择两个动作创建 Superset。
- 可以选择两个或更多动作创建 Circuit。
- 创建组合后动作会连续排列，并显示类型与顺序。
- 已有组合可解散；删除组合中的动作会先安全解散整个组合，避免残留单成员组合。
- 组合信息保存在 `StrengthExerciseLog` 的 JSON blob 中，不修改 SwiftData schema。
- 新增字段全部为可选字段，旧训练 JSON 可以继续解码。

## 定向验证

- `testStrengthGroupingPlannerCreatesContiguousSuperset`
- `testStrengthExerciseLegacyJSONDecodesWithoutGroupingFields`
- 结果：通过。
- xcresult：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_17-43-39-+0800.xcresult`

## Phone / Watch Active Workout

- iPhone 会把活动草稿的动作、组次、重量、次数和完成状态同步到 Apple Watch。
- Watch 可直接切换完成状态，并以 `±2.5 kg`、`±1 次`调整组次。
- 可达时使用即时消息；不可达时排队为后台 user info，回到 iPhone 后应用到相同 draft / exercise / set。
- mutation ID 在手机队列去重；错误 draft 或错误 set 不会污染当前训练。
- 完成或丢弃训练会清除 Watch 上的 Active Workout；成功保存后不再留下会被误恢复的旧草稿。
- `VelaWatch` 与 iOS 主目标均通过编译。
- 测试：`testWristStrengthEditAppliesOnlyToMatchingDraftAndSet`。
- xcresult：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_17-48-47-+0800.xcresult`
