# VALIDATION EVIDENCE

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 历史视觉与功能验证证据（仅作历史测试回归参考）

---

# Phase A01 — 联网 AI 数据授权验证

日期：2026-08-01

## 交付结果

- Coach 第一次联网发送前必须完成明示授权；取消不会发送请求。
- 授权清单逐项覆盖：健康与化验、训练、营养、日志习惯、个人档案、历史报告、当前对话历史、Bing 搜索关键词。
- 未授权类别在 `CoachContextAssembler` 构建提示词之前移除。
- 未授权健康、训练、营养、日志和联网搜索能力不会注册进 Agent tool allowlist。
- 授权保存在本机设置，可在 Coach 模型设置中逐项关闭或全部撤销。
- Ghost 模式仍遵守相同出站授权，并继续限制为只读工具。
- 用户手动输入的问题始终属于要发送的内容；界面对此有明确说明。
- 餐食照片不包含在本授权中，仍需在 Kimi 分析动作中单独确认。

## 定向验证

- `testCoachOutboundPolicyRequiresConsentAndPersistsExactFields`
- `testCoachOutboundPolicyRemovesUnauthorizedReadTools`
- 结果：通过。
- xcresult：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_17-41-17-+0800.xcresult`

## 真实性与隐私结论

授权控制发生在网络请求和工具注册之前，不依赖仅用于说明的 UI 标签。没有授权版本时，策略严格回退为全关闭；不会为了保持旧版 Coach 行为而默认开启健康数据。

