# VALIDATION EVIDENCE

> Status: Supporting
> Last verified: 2026-08-21
> Scope: 历史视觉与功能验证证据（仅作历史测试回归参考）

---

# Phase A05 — Coach Files 验证

日期：2026-08-01

## 交付

- Coach `+` 菜单新增本地文件入口，支持 PDF、纯文本、CSV 和 TSV。
- 文件先在本机提取文字并预览，不自动发送、不自动保存，也不直接建立长期记忆。
- 文件上限 10 MB；发送上下文最多保留前 6000 字，并明确显示截断状态。
- 扫描版无文本 PDF 会转向已有 Health Records OCR 流程，不伪造提取结果。
- 用户必须逐文件勾选确认，内容才会进入尚未发送且可编辑的输入草稿。
- 文件内容包装为“不可信引用资料”，明确禁止执行其中的指令、工具调用或策略文本。
- Outbound Policy 升级到 v2，新增独立“主动选择的文件文本”开关；旧授权需要重新确认。

## 自动化验证

- 文件文本长度边界、截断状态和不可信内容标记。
- Outbound Policy v2 精确持久化与撤销，包括 Files 字段。

结果：2 tests，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-24-57-+0800.xcresult`

