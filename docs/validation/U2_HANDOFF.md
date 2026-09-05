# 任务交接：U2｜Today 三加二精修到正式可用

任务：U2｜Today 三加二精修到正式可用  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（Q0 交付 HEAD `8fee4d9d`，U1 交付 HEAD `6c8d5d13`，U2 开工前 HEAD `0c09818566035b55be0f3839a5eec644eb488c10`）  
交付 SHA：`358033f9c6d32aaef678d46101c51ef6dd81c7f1`  
工作区未提交改动与处理：修改 3 个 production 文件及 1 个 UI 测试文件；交付包含 6 状态截图矩阵与 1 段导航录像。执行书与任务卡文件按规则保留。

---

## 本卡改变的用户行为

1. **次级“压力与能量”双列自适应布局（Adaptive Layout）**：
   - 在标准字号与常规屏宽下，压力与能量保持并排等宽双列（`HStack(spacing: 12)`）；
   - 在大字号（`dynamicTypeSize >= .xxLarge`）或辅助功能超大字号（Accessibility Sizes）下，自动平滑切换为垂直纵向单列卡片（`VStack(spacing: 12)`），彻底避免双列小卡在超大字号下文字与图表互相挤压的问题，不再依赖 `minimumScaleFactor` 全局强行缩字。

2. **消除无日期的假连续走势折线（遵守规则 7 & U2 要求 5）**：
   - 移除了次卡中的 `TodaySecondaryTrendLine`（在没有真实日期的纯数值序列上绘制平滑伪曲线）；
   - 引入全新的 `TodayStressGauge`（14 段平滑圆角分段式电量表），其视觉语言与右侧 `TodayEnergyGauge` 形成严格对称的卡片图表表达；
   - 压力表根据当前 0–100 分值自适应点亮对应格数（如 35 分点亮前 5 格，剩余 9 格呈微暗底色），并自适应卡宽拉伸。

3. **双重状态表达：文字标签 + 非纯颜色依赖（遵守 U2 要求 3）**：
   - 次卡状态完全消除“仅依靠颜色区分”的无障碍风险：
     - 压力卡明确给出数值与文本档位：`35 低` / `55 适中` / `80 高` / `-- 待同步`；副标题由模糊的“近 7 日趋势”明确修正为“当前生理压力”（或“等待压力数据”）；
     - 能量卡明确给出电量百分比与档位：`85% 充沛` / `50% 适中` / `25% 偏低` / `-- 待同步`；副标题明确为“当前电量储备”（或“等待能量模型”）。

4. **首屏一句解释优先进入“本机依据”（遵守 U2 要求 4）**：
   - 首页一句解释卡片明确标注入目标为“指导依据”（附 ✨ 图标）；
   - 点击指导依据卡片不再直接跳入全屏 AI 聊天，而是优先呼出原生的本地判断依据浮层（`TodayEvidenceSheet`，展示当前训练窗口、基线天数、置信度及生理信号原因），用户在理解本机依据后再决定是否继续追问 AI。

5. **首屏视觉竞争收敛**：
   - 将主卡下方的“今日计划”（`TodayDailyPlanCard`）主行动标题字号从粗重的 `.title3().weight(.bold)` 微调收敛为 `.headline().weight(.semibold)`，使首屏视线自然聚焦在“恢复、睡眠、负荷”三项核心主指标环上。

---

## 实际修改文件及理由

1. **[VelaApp/Features/Minimal/TodaySignalGrid.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodaySignalGrid.swift)**：
   - 次级卡片容器增加 `shouldUseStackedSecondaryLayout`，在 `.xxLarge` 及无障碍大字号下自动切换垂直单列堆叠；
   - 移除 `TodaySecondaryTrendLine`，新增 `TodayStressGauge`（14 段水平进度格，自适应卡宽，高度 20pt，居中于 24pt 图表位）；
   - 增加 `stressStateLabel` 与 `energyStateLabel`，状态值同时包含数值与中文字面标签；
   - `TodayDailyPlanCard` 主行动标题降级至 `.headline().weight(.semibold)`；
   - 将 `onAskCoach` 重命名并重构为 `onInspectGuidance`，无障碍标签与提示更新为查看事实依据。

2. **[VelaApp/Features/Minimal/VelaMinimalTodayView.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalTodayView.swift)**：
   - 将 `TodaySignalGrid` 的 `onInspectGuidance` 回调连接至 `dispatchToday(.openEvidence)`，并设置 `presentedTodaySheet = .evidence`，实现点击进入本机依据页。

3. **[VelaApp/Features/Minimal/TodayEvidenceSheet.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodayEvidenceSheet.swift)**：
   - 为依据浮层容器添加 `.accessibilityIdentifier("today-evidence-sheet")`，便于自动化测试与断言。

4. **[VelaUITests/VelaSmokeUITests.swift](file:///Users/sunweizhou/Developer/Vela/VelaUITests/VelaSmokeUITests.swift)**：
   - 在 `testTodayScoreContentAndMetricRouting` 中增加对 `today-secondary-stress`、`today-secondary-energy` 次卡可达性的断言；
   - 增加对 `today-guidance` 点击打开 `today-evidence-sheet` 并安全关闭的 UI 冒烟测试断言。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 恢复（Recovery, 0–100, %）
- 睡眠（Sleep, 0–100, %）
- 负荷（Strain, 0–21, 无量纲）
- 压力（Stress, 0–100, 无量纲）
- 能量（Energy, 0–100, %）

未修改任何计算引擎、权重算法、聚合公式、数据结构或持久化迁移定义。所有计算均保持 100% 幂等。

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
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:VelaTests` | iPhone 17 Pro (iOS 26.5) | 0 (549/549 passed) | `build/UnitTests_u2.xcresult` | 全部通过，耗时 24.3s |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:VelaUITests` | iPhone 17 Pro (iOS 26.5) | 0 (6/6 passed) | `build/UISmokeTests_u2.xcresult` | 全部通过，包含次卡验证与证据浮层导航 |
| `xcodebuild test -scheme Vela -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData -only-testing:VelaUITests/VelaSmokeUITests/testTodayScoreContentAndMetricRouting` | iPhone 17 Pro (iOS 26.5) | 0 (1/1 passed) | `build/UISmokeTests_u2_video.xcresult` | 完整执行路由测试并完成 2.0MB 录屏 |

---

## UI 证据

### 1. 真实 6 状态截图矩阵（`docs/validation/u2/after/`）

1. **普通宽度浅色（Standard Width Light）**：
   - 路径：[`docs/validation/u2/after/today-preview-light.png`](today-preview-light.png)
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：3 项主环 + 2 项次卡（14 段压力表盘与能量条双列并排），文字字重主次清晰，计划卡视觉降级。

2. **普通宽度深色（Standard Width Dark）**：
   - 路径：[`docs/validation/u2/after/today-preview-dark.png`](today-preview-dark.png)
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：深色沉浸模式下双列卡片对比度合格，无边缘高光溢出。

3. **紧凑宽度（Compact Width）**：
   - 路径：[`docs/validation/u2/after/today-preview-compact.png`](today-preview-compact.png)
   - 设备：iPhone 17e（390pt 宽，iOS 26.5）
   - 验证点：在较窄屏幕上，次卡双列内容完全不发生文字折行或截断，图表水平自适应均匀分布。

4. **无数据状态（Empty State）**：
   - 路径：[`docs/validation/u2/after/today-empty-light.png`](today-empty-light.png)
   - 设备：iPhone 17 Pro（393pt 宽，iOS 26.5）
   - 验证点：主环全 `--`，虚线质感清晰；压力卡展示 `-- 待同步` / “等待压力数据”，能量卡展示 `-- 待同步` / “等待能量模型”；顶部展示“今日数据待同步”状态卡。

5. **部分/学习期数据（Partial / Learning Baseline State）**：
   - 路径：[`docs/validation/u2/after/today-partial-light.png`](today-partial-light.png)
   - 设备：iPhone 17 Pro（参数 `-velaBaselineObservedDays 5`）
   - 验证点：展现基线形成期状态：⏳ “初始基线 · 5/7 天”带进度条；指导依据清晰说明“继续正常佩戴，Vela 正在了解你的日常波动”；各项指标正确附带基线标记。

6. **最大辅助字号无障碍（Accessibility XXXL / AX5）**：
   - 路径：[`docs/validation/u2/after/today-preview-a11y.png`](today-preview-a11y.png)
   - 设备：iPhone 17 Pro（参数 `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL`）
   - 验证点：自适应垂直纵向列表，无文本截断，标签、状态与分数自然排布。

### 2. 真实导航测试录像（Navigation Video）

- 路径：[`docs/validation/u2/after/today-navigation.mp4`](today-navigation.mp4)
- 规格：2.0MB, H.264 视频
- 内容记录：真实执行 `VelaSmokeUITests/testTodayScoreContentAndMetricRouting` 全程：
  1. Today 首屏加载 3+2 五大指标；
  2. 点击“指导依据”卡片呼出原生的“今日指导依据”浮层（`TodayEvidenceSheet`）；
  3. 点击“关闭”回到 Today；
  4. 点击“恢复”分数环 Push 进入恢复指标详情页面（`metric-detail-recovery`）。

---

## 算法证据

纯 UI 结构精修与导航连接，未改动任何算法代码，未触碰评分公式与输入输出，算法版本与快照格式保持不变。

---

## 未解决与未验证

1. **真机触控反馈体验**：触觉反馈 `VelaHaptic.selection()` 已在代码中触发，但触感精细度需在物理真机交付卡（R1）中实测。
2. **长多语种折叠测试**：已在简体中文与基础英文下验证，其他多语种的长文本适配将在全语言专项中覆盖。

---

## 回滚方法

如需回滚，直接执行：
```bash
git revert <本卡提交 SHA>
```
不影响数据存储，不改动数据库迁移版本。

---

## 下一张建议卡（本会话不自动执行）

**U3｜指标详情页标准图表收敛**（遵循 `tasks/U3.md`，基于 `VelaMetricDetailLandscapes.swift` 精修图表）。
