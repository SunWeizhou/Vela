# 任务交接：U5｜Trends 与首页小趋势的统一数据图形

任务：U5｜Trends 与首页小趋势的统一数据图形  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（U4 交付）  
交付 SHA：`cc67be11`  
工作区未提交改动与处理：包含 3 个核心图表与趋势组件文件及 3 份真实设备截图。

---

## 本卡改变的用户行为

1. **小走势图（Sparkline）真实日期分段与空缺断开（遵守 U5 要求 2 & 5）**：
   - 实现了 `DateAwareSparkline`；在遍历多尺度查询窗口时，针对缺失日期的记录不再使用 `compactMap` 直接拼缝，也不强制补零（Zero-filling）；
   - 连续有效数据段绘制连续折线，孤立单个读数如实渲染为独立散点（Circle Point），缺失日期两端彻底断开，关闭任何可能造成过冲或跨缺口伪造的连续贝塞尔平滑。

2. **稀疏数据与个人基线带诚实呈现（遵守 U5 要求 1 & 3）**：
   - 重构 `MetricChartSection`：彻底废弃此前在小于 3 个读数时完全遮蔽图表画面的强制“Calibrating 占位卡”；
   - 当仅有 1 个或 2 个分散读数时（如“7日缺2日”、“仅1点”），图表直接利用 `PointMark` 如实渲染点位事实；
   - 只有当累计读数达到或超过 3 个有效样本时，才渲染个人基线虚线（`effectiveBaseline`）与参考目标区间带（`targetRange`），没有已验证基线时**绝不绘制虚假装饰带**。

3. **单位与量纲严格清晰分离（遵守 U5 要求 4）**：
   - 趋势列表严格区分 0–100 标准化健康评分轴与原始生理指标范围（HRV ms、静息心率 bpm、消耗 kcal、活跃分钟等），杜绝无标注混用。

4. **Trends 多尺度切换与交互共存（遵守 U5 要求 1 & 6）**：
   - 统一“最近 7 天 / 最近 30 天 / 最近 6 个月 / 三年轨迹”选择器样式与字体；
   - 选点查看（Tooltip）与整屏纵向滚动流畅并存，无需横向拖动即可清晰对比。

---

## 实际修改文件及理由

1. **[VelaApp/Core/DesignSystem/VelaChart.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Core/DesignSystem/VelaChart.swift)**：
   - 新增 `DateAwareSparkline` 与 `TrendsChartPoint`，根据日期连续性智能切分绘图段，支持单点与缺口保留。

2. **[VelaApp/Features/Trends/VelaTrendsView.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Trends/VelaTrendsView.swift)**：
   - 引入 `scoreTrendPoints(for:)`，按选定时间窗（7天/30天/180天等）严格逐日生成点位，保留 `nil` 缺失项；接入 `DateAwareSparkline`。

3. **[VelaApp/Features/Minimal/MetricChartSection.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/MetricChartSection.swift)**：
   - 允许少于 3 个点时渲染单点 `PointMark`（`symbolSize: 42`）；
   - 为 `effectiveBaseline` 与 `targetRange` 增加 `points.count >= 3` 保护，防止未验证基线伪造参考带。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 趋势原始数据和计算完全未动；
- 仅重构图形投影层，确保缺失与间隙如实表达。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS (Python 3.12) | 0 (32/32 模型匹配) | 终端输出 | 无 |
| `python3 scripts/check_contrast.py` | macOS (Python 3.12) | 0 (textColor >= 4.5:1) | 终端输出 | 无 |
| `python3 scripts/check_fixed_fonts.py` | macOS (Python 3.12) | 0 (212 处文字与设计决策档位) | 终端输出 | 无 |
| `swift test --package-path BodySeekDomain` | macOS Swift 6.0 | 0 (11/11 passed) | 终端输出 | 无 |
| `swift test --package-path VelaBackend` | macOS Swift 6.0 | 0 (3/3 passed) | 终端输出 | 无 |
| `xcodebuild test ... -only-testing:VelaTests` | iPhone 17 Pro (iOS 26.5) | 0 (549/549 passed) | `build/DerivedData/Logs/Test/` | 全部通过 |
| `xcodebuild test ... -only-testing:VelaUITests/VelaSmokeUITests/testTrendsScoreContentAndMetricRouting` | iPhone 17 Pro (iOS 26.5) | 0 (1/1 passed) | `build/DerivedData/Logs/Test/` | 趋势页内容与路由测试全部通过 |

---

## UI 证据

真实截图保存在 `docs/validation/u5/after/`：

1. **趋势主页浅色（Trends Light）**：
   - 路径：`docs/validation/u5/after/trends-overview-light.png`
   - 验证点：四档时间跨度选择器；5 项核心评分 DateAwareSparkline 清晰对齐；“恢复趋势 · 真实读数 · 缺失日期保留空档”图表。
2. **趋势主页深色（Trends Dark）**：
   - 路径：`docs/validation/u5/after/trends-overview-dark.png`
   - 验证点：深色高对比度下各指标颜色与折线清晰可辨。
3. **超大字号无障碍（Accessibility XXXL）**：
   - 路径：`docs/validation/u5/after/trends-overview-a11y.png`
   - 验证点：大字号下指标名、基线变动文案与走势图自适应下沉换行，无文本截断。

---

## 算法证据

纯视觉与分段渲染改进，未修改趋势统计聚合算法。所有单测与快照测试全绿。

---

## 未解决与未验证

1. **3 年超长跨度点位缩减（Decimation）手感**：目前在模拟器测试 30 天与 7 天手感顺滑；更密集历史点位在旧款物理设备上的帧率在 R1 统一检验。

---

## 回滚方法

`git revert <commit-sha>`

---

## 下一张建议卡（本会话不自动执行）

U6｜其余详情与交互收尾
