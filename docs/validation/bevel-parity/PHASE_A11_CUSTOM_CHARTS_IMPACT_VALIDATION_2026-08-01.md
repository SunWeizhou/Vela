# Phase A11 — Custom Charts / Impact Matrix 验证

日期：2026-08-01

## 本批范围

- 将 Coach 的相关性 Artifact 从占位卡片升级为本地真实数据分析。
- 增加 Journal / 身体模型中的 Impact Matrix。
- 明确样本门槛、滞后关系、预测资格和非因果边界。

## 数据真实性规则

- 分析窗口最多 90 天，只使用已有 `DailyHealthSnapshot` 与 `JournalEntryRecord`。
- 连续指标之间至少需要 14 对同日真实样本。
- 包含行为标签时至少需要 28 对样本，记录日与对照日各至少 8 天。
- 比较当天与次日两个滞后候选；相关强度相同时优先样本更多的候选。
- Sleep / Recovery / Strain / Stress / Energy 派生值只有在对应源信号存在时才参与配对。
- 缺失数据不会被默认分数、零值趋势或演示曲线补齐。
- 只有连续指标、至少 28 对样本且 `|ρ| >= 0.35` 时显示探索性线性估计。
- 所有结果明确标记“相关不等于因果”和“非临床预测”。

## 界面交付

- 自定义相关图：Swift Charts 散点图、Spearman ρ、样本量、当天/次日滞后。
- Impact Matrix：横轴 `|ρ|`，纵轴真实配对 `n`，保留正/负相关颜色。
- 样本不足时展示可解释空态，不绘制趋势。
- 身体模型将真实 `HabitCorrelationInsight` 传入矩阵，不从 Claim 文案反推数值。

## 自动化验证

命令：

```sh
xcodebuild test \
  -project Vela.xcodeproj \
  -scheme Vela \
  -destination 'platform=iOS Simulator,id=4FF5A7B8-60E5-41EB-A0C8-708FCA8512C6' \
  -derivedDataPath DerivedData \
  -parallel-testing-enabled NO \
  -only-testing:VelaTests/VelaThemeTests/testCorrelationArtifactUsesRealPairsAndEnforcesSampleThresholds \
  -only-testing:VelaTests/VelaThemeTests/testImpactMatrixPreservesSignedEvidenceWithoutInventingPoints
```

结果：2 tests，0 failures。

结果包：`/tmp/VelaBevelUpgrade.aw8dn2/DerivedData/Logs/Test/Test-Vela-2026.08.01_18-55-03-+0800.xcresult`

## 视觉验证状态

- 最新 Debug 构建已安装并启动于 iPhone 17 Pro / iOS 26.5 模拟器。
- 本批桌面截图验收因 macOS 锁屏而暂未完成；不以伪造截图替代。
- 解锁后应复核：身体模型空态、Impact Matrix 轴标签、深色模式对比度和 VoiceOver 顺序。

