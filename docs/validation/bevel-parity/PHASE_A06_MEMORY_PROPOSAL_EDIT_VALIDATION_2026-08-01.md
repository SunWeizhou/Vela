# Phase A06 — Memory Proposal 编辑与撤销验证

日期：2026-08-01

## 交付

- 待确认记忆新增“编辑”操作。
- 编辑页允许修改最终记忆内容，并可附加用户备注。
- 保存编辑只更新 SwiftData 中的待确认提案，不会直接写入个人 Wiki。
- 用户仍需再次点击“确认”，内容才会进入 Wiki。
- 非 `proposed` 状态不可再编辑，避免修改已应用审计事实。
- 已确认记忆继续保存写入前全文与写入后哈希，满足条件时可真实回滚。

## 自动化验证

- 提案内容会去除首尾空白并保存用户备注。
- 已接受提案无法被后续编辑覆盖。
- 编辑/确认后的 Canonical Facts 可被 AI 上下文读取。
- 回滚会恢复确认前 Wiki 原文。

结果：2 tests，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-05-23-+0800.xcresult`

