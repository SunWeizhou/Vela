# Phase T — Nutrition Micronutrients 验证

日期：2026-08-01

## 交付

- Nutrition 详情新增微量营养素区：钠、钾、钙、铁、维生素 C、维生素 D。
- 仅使用 Open Food Facts 条码响应中明确存在的 `_100g` 或 `_serving` 标准字段。
- 按 Open Food Facts 官方 Schema，重量型标准字段以克表示；Vela 显示时转换为 mg 或 μg。
- 微量数据连同来源被编码进现有 `rawAnalysis`，不增加 SwiftData 存储列，不触发模型迁移。
- 当天视图只合计已保存记录中的明确标签数值，并显示记录覆盖数。
- 没有可靠微量数据时展示空态；不会根据餐食照片猜测维生素或矿物质。
- 不把标签合计自动换算为个人医学目标或微量营养评分。

官方字段依据：

- [Open Food Facts Product Nutrition Schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/product_nutrition/)
- [Open Food Facts Nutrient Schema](https://openfoodfacts.github.io/documentation/docs/Product-Opener/schemas/schemas/nutrient/)

## 自动化验证

- 验证钠 `0.42 g -> 420 mg`。
- 验证钙 `0.125 g -> 125 mg`。
- 验证维生素 D `0.000005 g -> 5 μg`。
- 验证微量数据经过 `FoodLogRecord.rawAnalysis` 归档后可无损恢复。

结果：1 test，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-08-35-+0800.xcresult`

