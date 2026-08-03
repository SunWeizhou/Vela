# Phase T — Biological Age History / Projection 验证

日期：2026-08-01

## 交付

- Biology 二级页新增生物年龄历史曲线。
- 每个历史点只使用该日期之前已经存在的化验记录，并按指标选择当时最新值。
- 只有 Albumin、Creatinine、Glucose、CRP、Lymphocyte、MCV、RDW、ALP、WBC 九项完整且单位可验证时才生成历史 PhenoAge 点。
- 历史图同时显示生物年龄与当时实际年龄，不把普通健康趋势分冒充生物年龄。
- 新增当前与 20 年情景对照；仅保持当前年龄差恒定，并明确不是寿命预测或医学结论。
- 只有一次完整面板时展示“需要第二组完整化验”的真实空态。

## 自动化验证

- 两个完整历史面板生成两个真实点，每点九项证据。
- 指标变化会改变重新计算的历史生物年龄。
- 缺少任意一项标准 PhenoAge 输入时不生成历史点。

结果：1 test，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-15-00-+0800.xcresult`

