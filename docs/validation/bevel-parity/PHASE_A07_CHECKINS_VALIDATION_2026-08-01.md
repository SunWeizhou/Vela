# Phase A07 — Check-ins 验证

日期：2026-08-01

## 交付结果

- 支持一次性、每小时、每日、每周和每月 Check-in。
- 一次性提醒使用独立通知请求，不会覆盖重复提醒。
- 小时提醒默认关闭；月度日期限制为 1–28，避免短月份丢失。
- 所有 Check-in 都是 iPhone 本机通知，不会发送健康数据或调用联网 AI。
- 设置界面明确说明 iOS 不保证精确到分钟，并在权限缺失时反馈失败。

## 定向验证

- `testCoachCheckInScheduleBuildsHourDayWeekAndMonthTriggers`
- 结果：通过。
- xcresult：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_17-53-37-+0800.xcresult`
