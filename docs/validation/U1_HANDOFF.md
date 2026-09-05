# 任务交接：U1｜建立真实 UI 基线并完成一套组件精修

任务：U1｜建立真实 UI 基线并完成一套组件精修  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（Q0 交付后 HEAD 为 `8fee4d9d67e87c874c04cda03574633b65abe614`）  
交付 SHA：`6c8d5d1345768e91428b34b41ef8517f88e93001`  
工作区未提交改动与处理：代码改动与全套 8 张截图已提交至 `6c8d5d13`；保留根目录执行书与任务模板（`EXECUTION_BOOK.md`、`START_HERE.md`、`RULES_TO_PASTE.md`、`tasks/`、`templates/`）。

---

## 本卡改变的用户行为

1. **主卡三主分视觉重心清晰饱满**：
   - 恢复、睡眠、负荷 3 项主指标在 88pt 分数环内的主数字字号由 22pt（title2）升级为 28pt（`.title` rounded bold），使大数字更加饱满挺拔，消除了环内大面积空旷感；
   - 环线 stroke 线宽公式收敛为 `max(6, (size * 0.088).rounded())`（88pt 环对应 8pt 线宽），与主分数字重形成协调的比例；
   - 缺失数据环的虚线模式从容易产生毛刺的 `[2, 5]` 升级为清晰疏朗的 `[4, 6]`，在缺失状态（`--`）下具有沉稳的设计质感。

2. **基线偏离标记（Deviation Indicator）统一收敛**：
   - 原先偏离个人基线的红色指示点浮在分数环右上角外围（视觉悬空，易与表盘刻度混淆）；
   - 现将其收敛移动至指标名称文字右侧（`HStack(spacing: 3)`），使“恢复·”、“睡眠·”、“负荷·”以及次级“压力·”、“能量·”在发生基线偏离时的视觉语义完全统一。

3. **次级“压力与能量”恢复严格双列对齐与紧凑层级**：
   - 彻底移除了导致列宽溢出并退化为垂直铺满大卡片的 94×94 径向表盘（`TodayStressDial`）；
   - 将压力面板重构为顶部指标名（`压力`）+ 状态与分值（如 `35 低`）+ 24pt 平滑走势折线（`TodaySecondaryTrendLine`）；
   - 将能量面板调整为 14 格等高电量条（`TodayEnergyGauge`），与压力面板在高度（minHeight 96pt）、内边距（16pt）、圆角（20pt，`radiusCardStandard`）完全对齐，稳固呈现清晰并排的横向双列卡片（`HStack(spacing: 12)`）；
   - 卡片右上角保留规范 chevron 箭头，明确传达可点击进入二级详情的语义。

4. **无障碍与超大字号（Dynamic Type AX5）降级自适应**：
   - 在超大字号模式（`accessibility-extra-extra-extra-large`）下，主分数环与次级网格自适应折叠为纵向大卡列表，标签不被截断，分数与状态清晰可读。

---

## 实际修改文件及理由

1. **[VelaApp/Core/DesignSystem/VelaChart.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Core/DesignSystem/VelaChart.swift)**：
   - `scoreRing`: 当 `size > ringMd + 6`（88pt 首页主环）时，主分数字号采用 `.system(.title, design: .rounded, weight: .bold)`，小尺寸保持 `.system(.caption, design: .rounded, weight: .semibold)`，完全兼容 Dynamic Type；
   - `ringStrokeWidth`: 采用 `max(6, (size * 0.088).rounded())`，确保环体与字重平衡；
   - `missingDashPattern`: 优化为 `[4, 6]`，提升空状态表盘的质感与一致性。

2. **[VelaApp/Features/Minimal/TodaySignalGrid.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodaySignalGrid.swift)**：
   - `primaryScores`: 容器内边距收敛为 `VelaTheme.space5`（20pt），圆角采用 `VelaTheme.radiusHero`（24pt）；
   - `scoreRing`: 移除右上角浮动圆点，将基线偏离红点移入指标名称文字旁；
   - `stressPanel` / `energyPanel`: 移除超尺寸 94×94 的 `TodayStressDial`，统一使用标准卡片结构（标题 + 数值与状态 + 24pt 图表控件），次级卡内边距统一 16pt，最小高度 96pt，圆角收敛为 `VelaTheme.radiusCardStandard`（20pt）；
   - `TodayDailyPlanCard`: 圆角统一收敛为 `VelaTheme.radiusCardStandard`（20pt），消除卡片圆角层级混乱。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 恢复（Recovery, 0–100, %）
- 睡眠（Sleep, 0–100, %）
- 负荷（Strain, 0–21, 无量纲）
- 压力（Stress, 0–100, 无量纲）
- 能量（Energy, 0–100, %）

所有指标的计算公式、输入来源、聚合逻辑、日期范围、快照版本（v1）与空数据缺失表现（`--`）保持 100% 不变。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS (Python 3.12) | 0 (32/32 模型通过) | 终端输出 | 无 |
| `python3 scripts/check_contrast.py` | macOS (Python 3.12) | 0 (textColor >= 4.5:1) | 终端输出 | 无 |
| `python3 scripts/check_fixed_fonts.py` | macOS (Python 3.12) | 0 (212 处文字与设计决策档位) | 终端输出 | 无 |
| `swift test --package-path BodySeekDomain` | macOS Swift 6.0 | 0 (11/11 passed) | 终端输出 | 无 |
| `swift test --package-path VelaBackend` | macOS Swift 6.0 | 0 (3/3 passed) | 终端输出 | 无 |
| `xcodebuild build -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | iPhone 17 Pro (iOS 26.5) | 0 (BUILD SUCCEEDED) | `build/DerivedData/Build/Products/Debug-iphonesimulator/Vela.app` | 0 警告，0 错误 (Warnings as Errors 激活) |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VelaTests` | iPhone 17 Pro (iOS 26.5) | 0 (549/549 passed) | `build/UnitTests_u1_final.xcresult` | 全部通过，耗时 ~25s |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VelaUITests` | iPhone 17 Pro (iOS 26.5) | 0 (6/6 passed) | `build/UISmokeTests_u1_final.xcresult` | 全部通过，包含 Today 导航与分数验证 |

---

## UI 证据

使用完全相同的模拟器环境（iPhone 17 Pro, iOS 26.5, UDID: `BCAD01D0-CB5A-4277-B622-269479D0E159`）、完全相同的启动参数（`-AppleLanguages '(zh-Hans)' -AppleLocale zh_CN -velaLegacyInterface -velaInitialTab 0`）与完全相同的数据 fixture 进行前/后对照：

### 1. 浅色模式（Preview Fixture）
- 改前：[`docs/validation/u1/baseline/today-preview-light.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/baseline/today-preview-light.png)
- 改后：[`docs/validation/u1/after/today-preview-light.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/after/today-preview-light.png)
- 差异：
  1. 主卡 3 项分数环内数字（48, 79, 24）由偏小的 22pt 调整为饱满有力的 28pt rounded bold，视觉重心集中；
  2. 偏离基线红点从分数环右上角漂浮移动至“恢复·”、“睡眠·”、“负荷·”文字旁，结构严谨；
  3. 次级“压力与能量”卡片由原先垂直堆叠退化彻底修正为规整的横向双列等高网格（minHeight 96pt），压力面板折线与能量面板 14 格电量条在水平基准线上完美对齐。

### 2. 深色模式（Preview Fixture）
- 改前：[`docs/validation/u1/baseline/today-preview-dark.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/baseline/today-preview-dark.png)
- 改后：[`docs/validation/u1/after/today-preview-dark.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/after/today-preview-dark.png)
- 差异：
  1. 在深色沉浸式背景下，主环线条与次卡走势折线/电量条对比度符合 WCAG AA 规范；
  2. 双列次卡在深色下的卡片边框与微阴影一致，没有高光溢出或多层卡片反差突兀问题。

### 3. 大字无障碍模式（AX5: accessibility-extra-extra-extra-large）
- 改前：[`docs/validation/u1/baseline/today-preview-a11y.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/baseline/today-preview-a11y.png)
- 改后：[`docs/validation/u1/after/today-preview-a11y.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/after/today-preview-a11y.png)
- 差异：
  1. 动态字号平滑放大，主指标平滑转为垂直单列行列表；
  2. 指标名称与基线红点保持同一行，无任何文本截断。

### 4. 空数据模式（Empty State）
- 改前：[`docs/validation/u1/baseline/today-empty-light.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/baseline/today-empty-light.png)
- 改后：[`docs/validation/u1/after/today-empty-light.png`](file:///Users/sunweizhou/Developer/Vela/docs/validation/u1/after/today-empty-light.png)
- 差异：
  1. 缺失数据状态下的主环虚线从原 `[2, 5]`（细碎毛刺）调整为 `[4, 6]`（清晰规整）；
  2. 次卡保持双列对称，分别展示平直虚线和空槽能量格，整齐统一。

### 遗留视觉观察与建议
1. 顶部天气胶囊（`-- 天气暂不可用`）在空数据或未连接网络时的留白可在后续 U2 阶段做微调收敛；
2. 历史趋势图表（Trends 页面）的设计语言尚待 U5 统一对齐。

---

## 算法证据

本卡为纯表现层与设计 Token 规范化重构，未触碰任何健康评分公式、窗口计算或数据结构，算法版本、权重和边界保持原有实现不变。

---

## 未解决与未验证

1. **真机触控与微动效**：在物理真机上对于快速滑动手势的高刷流畅度需在发布前验收卡（R1）中最终回归；
2. **多语言超长文本**：本卡在简体中文（zh-Hans）下验证完整，德语等较长语种的本地化文本折叠需在全语言测试阶段覆盖。

---

## 回滚方法

如需回滚，直接执行：
```bash
git revert 6c8d5d1345768e91428b34b41ef8517f88e93001
```
不修改数据库结构，不影响持久化用户数据，无任何数据破坏风险。

---

## 下一张建议卡（本会话不自动执行）

**U2｜Today 三加二精修到正式可用**（重点关注顶部卡片与主页滚动体验的最终润色，保留评分数据不变）。
