# Phase T — Cardio Load / Status / Focus / HRR 验证

日期：2026-08-01

## 交付

- Fitness 新增有氧状态卡：Cardio Load、Cardio Status、Cardio Focus、心率恢复。
- Cardio Load 使用最近 7 天真实有氧训练分钟数。
- Cardio Status 将最近 7 天与此前 21 天周均值比较，分为负荷回落、维持、逐步提升、短期陡增。
- 此前 21 天少于 3 次有氧训练时只显示“校准中”，不推断状态。
- Cardio Focus 按最近 7 天真实训练时长最多的运动类型显示。
- 力量、瑜伽、灵活性与活动度训练不会混入有氧负荷。
- HRR 读取 HealthKit 官方 `heartRateRecoveryOneMinute` 类型；至少 3 次才显示中位数。
- HealthKit HRR 样本按训练结束时间就近匹配，每个样本最多归属一次训练，超过 6 小时或负值不会关联。
- 短期负荷超过基线 1.5 倍时显示非医疗性的降量提醒。

## 自动化验证

- 真实基线计算、力量训练排除、负荷陡增、运动重点和 HRR 中位数。
- 基线不足时不产生 Cardio Status 或 HRR。

结果：基础 Cardio 算法 2 tests，HealthKit HRR 接入 3 tests；均为 0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-01-34-+0800.xcresult`

HRR 接入结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_19-12-22-+0800.xcresult`

## 数据边界

- Apple Watch/HealthKit 没有生成 `heartRateRecoveryOneMinute` 样本时仍显示空态；不会用平均心率伪造 HRR。
- macOS 锁屏期间无法完成本批模拟器截图；解锁后需复核 Fitness 卡片在空态和完整态的布局。

官方定义：[Apple HealthKit heartRateRecoveryOneMinute](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartraterecoveryoneminute)
