# 任务交接：U3｜恢复详情标杆页与正确返回

任务：U3｜恢复详情标杆页与正确返回  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（Q0 交付 HEAD `8fee4d9d`，U1 交付 HEAD `6c8d5d13`，U2 交付 HEAD `5df7d1b0`）  
交付 SHA：`2bffa05b`  
工作区未提交改动与处理：修改 11 个 production 文件及 1 个 UI 测试文件；交付包含 5 状态截图矩阵与 1 段完整导航录像。执行书与任务卡文件按规则保留。

---

## 本卡改变的用户行为

1. **Push 与 Sheet 导航返回语义严格分离（遵守 U3 要求 1）**：
   - **Push 导航（Today 页面主卡与次卡点击跳转）**：导航栏 Leading 区域保持系统原生行为，展示返回上级的 Chevron 箭头并支持全屏边缘侧滑返回手势（Interactive Pop Gesture）；彻底消除了既有实现中无条件放置自定义 `xmark` 关闭按钮导致破坏系统返回栈与侧滑手势的问题；
   - **Sheet 浮层（深层路由、快速概览、Trends 浮层等模态弹出）**：显式注入 `isPresentedInSheet = true`，在导航栏左上角展示圆角背景的关闭按钮（`metric-detail-close`），点击平滑退出浮层。

2. **显式日期与有效快照投影收敛（遵守 U3 要求 2）**：
   - 彻底消除了 `VelaMetricDetailView` 隐式直接回读 `dashboardVM.selectedDate` 导致的跨日期异步竞态与闪烁风险；
   - 详情页内部统一通过 `effectiveDate = selectedDate ?? dashboardVM.selectedDate` 以及 `dashboard = dashboardSnapshot ?? dashboardVM.dashboard` 投影，在导航发生时立即锁定当前日期的有效证据快照，杜绝在历史日切换时新旧状态与异步加载结果混乱交织的问题。

3. **恢复标杆页固定阅读顺序（遵守 U3 要求 3）**：
   - 确立清晰且不可折叠遮挡的四级信息流结构：
     1. **主值 + 数据质量**：`CoreMetricDetailHero` 恢复环、HRV/静息心率摘要、基线进度与今日动作指导，紧随 `VelaTrustSection`（方向、置信度、覆盖度、更新时间与未补齐说明）；
     2. **个人比较 / 趋势**：恢复基线对比卡片（HRV 与静息心率相对 14–28 天滚动基线的偏离值与方向）及多周期图表选择器（7天/30天/6个月/3年）；
     3. **HRV / RHR 等生理证据**：`MetricEvidenceSection` 显式呈现基础生理数据依据；
     4. **方法 / 来源 / 限制**：`MetricMethodologyCard` 详细列出 Z 分数加权计算公式、Apple 健康本机数据源（零云端上传、离线可用）以及非医疗设备用途声明与限制。

4. **复用有机背景景观（遵守 U3 要求 4）**：
   - 重构 `ForestLandscape` 为基于 `GeometryReader` 与相对比例贝塞尔曲线的自适应矢量图形，完美适配不同屏宽与不同 Dynamic Type 字号排布；
   - 融入 `CoreMetricDetailHero` 顶部作为恢复专属的宁静、有机背景肌理，并在高对比度模式与深色模式下自适应透明度与线宽，不遮挡文字易读性，不捏造虚假算法数据。

5. **历史首页与详情一致性保证（遵守 U3 要求 5 & 验收标准）**：
   - 日历选择历史日期后，首屏与 Push 详情页的日期更新标签（例如“更新于 2026年9月1日 0:00”）、各项生理读数与算法版本完全一致，返回后首页状态稳定保持。

---

## 实际修改文件及理由

1. **[VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift)**：
   - 将 `ForestLandscape` 重构为自适应 viewport 的矢量绘图，消除硬编码 400x240 视口导致的超宽与小屏拉伸变形。

2. **[VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift)**：
   - 将 `ForestLandscape` 接入 `CoreMetricDetailHero` 的背景，配合柔和渐变蒙版，针对 `.recovery` 营造温和标杆质感；
   - 新增 `MetricMethodologyCard`，承载计算原理（HRV/RHR Z 分数加权）、数据源（Apple 健康本机读取，零云端）与使用限制（日常参考，非医疗设备）；
   - 添加 `.accessibilityIdentifier("metric-detail-hero")` 与 `.accessibilityIdentifier("metric-detail-methodology")`。

3. **[VelaApp/Features/Minimal/VelaMetricDetailData.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailData.swift)**：
   - 将日期时间标签（`metricUpdatedAtLabel`、`displayDateText`、`selectedDateText`、`selectedFullDateText` 等）与走势图点（`chartPoints`、`trendItems`）彻底重定向至 `effectiveDate` 与有效 `dashboard.healthTrends` 快照，消除隐式依赖。

4. **[VelaApp/Features/Minimal/VelaMinimalComponents.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalComponents.swift)**：
   - 为 `VelaMetricDetailView` 增加显式 `selectedDate: Date?`、`dashboardSnapshot: DashboardSummary?` 以及 `isPresentedInSheet: Bool`；
   - 改造工具栏：`isPresentedInSheet == true` 时渲染 `metric-detail-close`；为 `false`（即 Push 场景）时留空 Leading 工具栏，交由系统渲染标准返回按钮；
   - 按 U3 要求调整 `coreMetricContent` 固定阅读顺序：1) 主值+质量 → 2) 趋势/基线 → 3) 数据依据 → 4) 方法与限制。

5. **[VelaApp/Features/Minimal/TodayHeroCard.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodayHeroCard.swift)**：
   - 在 Today 主卡恢复环点击跳转的 `NavigationLink` 中显式传递 `selectedDate`、`dashboardSnapshot` 与 `isPresentedInSheet: false`。

6. **[VelaApp/Features/Minimal/TodaySignalGrid.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodaySignalGrid.swift)**：
   - 增加 `selectedDate` 与 `dashboardSnapshot` 输入，在次级卡片及指标跳转时显式传递，并声明 `isPresentedInSheet: false`。

7. **[VelaApp/Features/Minimal/VelaMinimalTodayView.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalTodayView.swift)**：
   - 向 `TodaySignalGrid` 注入 `todayStore.state.selectedDay` 与 `todayStore.state.dashboard`；
   - 向 `TodayMetricDetailDownstreamAdapter` 注入 `selectedDate`、`dashboardSnapshot` 与 `isPresentedInSheet: true`；
   - 为日历按钮增加 `.accessibilityIdentifier("today-calendar-button")`。

8. **[VelaApp/Features/Minimal/TodaySubSheets.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodaySubSheets.swift)**：
   - 为 `CalendarOverviewSheetView` 添加 `.accessibilityIdentifier("calendar-overview-sheet")`，为日历各日期单元格添加 `.accessibilityIdentifier("calendar-day-\(day)")`。

9. **[VelaApp/Features/Minimal/VelaMinimalShell.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalShell.swift)**：
   - 在主 Shell 的 `recoveryDetail` 模态展示处显式注入当前选定日期、快照与 `isPresentedInSheet: true`。

10. **[VelaApp/Features/Trends/VelaTrendsView.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Trends/VelaTrendsView.swift)**：
    - 在 Trends 详情模态弹出（`sheet`）处显式传递当前日期、快照与 `isPresentedInSheet: true`。

11. **[VelaApp/Features/Minimal/MetricEvidenceSection.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/MetricEvidenceSection.swift)**：
    - 为数据依据区块添加 `.accessibilityIdentifier("metric-detail-evidence")`。

12. **[VelaUITests/VelaSmokeUITests.swift](file:///Users/sunweizhou/Developer/Vela/VelaUITests/VelaSmokeUITests.swift)**：
    - 更新 `testRecoveryDetailDeepLaunch` 验证 Sheet 模态的 `metric-detail-close` 按钮存在且点击后正确关闭；
    - 新增 `testRecoveryDetailPushNavigationAndReturn` 验证 Push 路由下系统返回按钮、不显示关闭按钮、主卡英雄呈现、系统返回后回到 Today 页面；
    - 新增 `testRecoveryDetailHistoricalDateNavigation` 验证日历历史日选择后进入恢复详情、快照同步以及平稳返回。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 恢复分数（Recovery, 0–100, %）
- HRV（毫秒, ms）
- 静息心率（静息 bpm）
- 走势区间（7天/30天/6个月/3年）
- 算法版本与数据流快照（`configVersion`）

未修改任何计算引擎、权重公式或数据库持久化模型。所有公式与数据源合同保持 100% 不变。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS (Python 3.12) | 0 (32/32 模型匹配) | 终端输出 | 无 |
| `python3 scripts/check_contrast.py` | macOS (Python 3.12) | 0 (textColor >= 4.5:1) | 终端输出 | 无 |
| `python3 scripts/check_fixed_fonts.py` | macOS (Python 3.12) | 0 (212 处文字与设计决策档位) | 终端输出 | 无 |
| `swift test --package-path BodySeekDomain` | macOS Swift 6.0 | 0 (11/11 passed) | 终端输出 | 无 |
| `swift test --package-path VelaBackend` | macOS Swift 6.0 | 0 (3/3 passed) | 终端输出 | 无 |
| `xcodebuild build -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData` | iPhone 17 Pro (iOS 26.5) | 0 (BUILD SUCCEEDED) | `build/DerivedData/Build/Products/Debug-iphonesimulator/Vela.app` | 0 警告，0 错误 (Warnings as Errors 激活) |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:VelaTests` | iPhone 17 Pro (iOS 26.5) | 0 (549/549 passed) | `build/UnitTests.xcresult` | 全部通过，耗时 22.8s |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:VelaUITests` | iPhone 17 Pro (iOS 26.5) | 0 (8/8 passed) | `build/UISmokeTests.xcresult` | 全部通过，包含 Push/Sheet 返回语义与历史日期测试 |
| 视频录制与综合导航验证 | iPhone 17 Pro (iOS 26.5) | 0 (3/3 passed) | `docs/validation/u3/after/recovery-detail-navigation.mp4` | 完整记录 Push、Sheet、日历历史日导航 |

---

## UI 证据

### 1. 真实 5 状态截图矩阵（`docs/validation/u3/after/`）

1. **正常宽度浅色（Standard Width Light）**：
   - 路径：`docs/validation/u3/after/recovery-detail-normal-light.png`
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：Sheet 模式左上角展示 `xmark` 关闭按钮；Hero 卡融入 `ForestLandscape` 有机背景；按顺序展示“主值+数据质量”→“恢复基线对比”→“7天/30天/6个月/3年走势图”。

2. **正常宽度深色（Standard Width Dark）**：
   - 路径：`docs/validation/u3/after/recovery-detail-normal-dark.png`
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：深色沉浸模式下林地背景与卡片表面自适应，对比度合格，无边缘溢出。

3. **空数据状态（Empty State）**：
   - 路径：`docs/validation/u3/after/recovery-detail-empty.png`
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：主环显示 `--` 虚线，HRV 与静息心率均为 `--`，基线显示“建立中”，指导给出“先补齐数据，再做判断”，置信度显示“不可用”，覆盖度显示“暂无数据”，说明明确标示“缺少可用读数；当前页面不会用 0 或默认值代替。”，完全不伪造分数。

4. **大字号无障碍（Accessibility XXXL / AX5）**：
   - 路径：`docs/validation/u3/after/recovery-detail-a11y.png`
   - 设备：iPhone 17 Pro（参数 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`）
   - 验证点：超大字体下分数、指标事实、指导文字纵向自适应，不发生文本挤压或截断。

5. **历史日期详情（Historical Day State）**：
   - 路径：`docs/validation/u3/after/recovery-detail-historical.png`
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：从 Today 日历选择历史日进入；顶部展示系统原生 `<` Chevron 返回按钮；更新时间明确为所选历史日（“更新于 2026年9月1日 0:00”）；历史数据与首页保持完全一致。

### 2. 真实导航测试录像（Navigation Video）

- 路径：`docs/validation/u3/after/recovery-detail-navigation.mp4`
- 规格：42MB, H.264 视频
- 内容记录：真实执行 `VelaSmokeUITests` 中涉及恢复详情的全部 3 项关键路由测试：
  1. `testRecoveryDetailDeepLaunch`：Sheet 模态呼出恢复详情，验证左上角关闭按钮，点击关闭；
  2. `testRecoveryDetailHistoricalDateNavigation`：点击 Today 日历选择按钮，呼出日历浮层，选择历史日，点击恢复环 Push 载入该历史日恢复详情，验证日期一致性，点击系统返回按钮平稳返回 Today；
  3. `testRecoveryDetailPushNavigationAndReturn`：从 Today 正常 Push 进入恢复详情，验证 Hero 卡与系统返回按钮（无多余关闭按钮），点击返回安全退回 Today。

---

## 算法证据

纯 UI 标杆页排版、视觉层级收敛与显式参数路由重构，未改动任何算法权重或打分公式，生产链与纯领域测试全部重放通过（`BodySeekDomainTests` 11/11 通过，`VelaTests` 549/549 通过）。

---

## 未解决与未验证

1. **真机全屏边缘滑动手势灵敏度**：原生 NavigationStack 默认启用了边缘右滑（Interactive Pop Gesture），模拟器单测已通过点击系统 Back 验证返回栈有效性；真机下的滑动手感将在 R1 阶段统一验证。

---

## 回滚方法

如需回滚，直接执行：
```bash
git revert 2bffa05b
```
不改动数据库迁移版本，回滚完全安全。

---

## 下一张建议卡（本会话不自动执行）

**U4｜睡眠详情精修与真实时间轴**（基于 U3 的标杆规范，精修睡眠分段图表与真实入睡/醒来时间轴）。
