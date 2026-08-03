# Phase A14 — Agent Tool Safety 验证

日期：2026-08-01

## 本批补强

- Tool Registry 是每次 Coach 会话的唯一 allowlist；模型请求未注册工具时直接阻断。
- 未知工具的风险默认值改为 `destructive`，不再以只读处理。
- 写入和删除仍必须经过显式确认；缺少确认回调时拒绝执行。
- 工具调用签名会规范化 JSON 并排序字段，语义相同但字段顺序不同的调用只执行一次。
- 现有 call ID 防重、工具预算、单工具超时和持久化写入闸门保持有效。
- 健康、Journal、Nutrition、训练历史及 Wiki 工具的审计参数/结果仅保留哈希与长度。
- 短健康文本也会脱敏；不再因为长度小于 200 字而原样写入 Trace。
- 外部搜索内容继续通过 `WebSearchHelper` 的不可信内容边界进入模型，禁止执行其中的指令、工具调用或伪策略。

## 自动化验证

覆盖：

1. 相同 JSON 不同字段顺序只执行一次。
2. 未知工具在 allowlist 层被阻断。
3. 短健康结果在审计 Trace 中脱敏。
4. 写工具拒绝确认时不执行。
5. 写工具确认后只执行一次。

结果：5 tests，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_18-58-48-+0800.xcresult`

## 边界

- 当前幂等签名覆盖一次 AgentLoop 运行及 provider 传输重试；训练计划另有持久化 `idempotency_key`。
- 对未来新增的写工具，仍要求在工具自身的数据层实现持久化幂等键，不能只依赖会话级防重。

