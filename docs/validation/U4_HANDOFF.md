# 任务交接：U4｜睡眠详情精修与真实时间轴

任务：U4｜睡眠详情精修与真实时间轴  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（U3 交付 HEAD `2bffa05b`）  
交付 SHA：`cc67be11`  
工作区未提交改动与处理：包含 4 个核心代码/测试文件及 7 份真实设备截图。无未提交多余文件。

---

## 本卡改变的用户行为

1. **真实睡眠阶段时间轴（Hypnogram）与间隙保留（遵守 U4 要求 1 & 2）**：
   - 彻底废弃了原有的静态进度条堆叠；引入 4 轨道高保真时间轴（深睡、核心、REM、清醒）；
   - 严格按照 HealthKit 样本真实起止时间（`start` 与 `end`）精确定位；用户夜间觉醒或离开床位的时段**如实留空**，严禁使用虚假均值平滑或填补不存在的阶段。

2. **在床时长与实际睡眠时长严格区分（遵守 U4 要求 3）**：
   - 头部统一展示实际睡眠时长（仅统计计入有效睡眠的阶段）与在床时长（包含清醒与在床等待）；
   - 提供跨午夜入睡与起床时间对比（如 `23:42 → 06:26`），计划就寝时间与目标睡眠时长并列展示，杜绝重复标题与歧义。

3. **未分期数据的诚实降级展示（遵守 U4 验收要求）**：
   - 针对老款 Apple Watch 或未开启阶段分析的三方睡眠源，当不存在 REM/深睡分期时，降级渲染单轨“睡眠时间段”，并明确标注“未分期 · 仅记录睡眠总段；此设备记录了睡眠总时间，未记录 REM / 深睡等阶段估计”，严禁发明虚假分期。

4. **自适应有机夜间景观（NightLandscape）（遵守 U4 要求 1）**：
   - 重构 `NightLandscape` 为基于相对比例坐标的响应式矢量图形，夜幕渐变、月相与星光点缀自然融入睡眠卡片背景，深色/浅色模式自适应对比度。

5. **VoiceOver 等价信息与无障碍大字号（遵守 U4 要求 4）**：
   - 为时间轴提供完整的 VoiceOver 旁白（“睡眠阶段时间轴：入睡 xx，起床 xx，实际睡眠 xx，在床 xx，深睡 xx 分钟...”），并支持 Dynamic Type 纵向自适应，不发生文本挤压或截断。

6. **Push 与 Sheet 导航一致性**：
   - 支持从 Today 首页点击睡眠卡片原生 Push 进入（展示返回箭头并支持边缘返回手势），以及从 Deep Link/快速操作以 Sheet 模态呼出（展示左上角关闭按钮）。

---

## 实际修改文件及理由

1. **[VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift)**：
   - 将 `NightLandscape` 从固定绝对像素视口重构成基于 `GeometryReader` 相对坐标的矢量绘图，完美适配各类屏幕宽度。

2. **[VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift)**：
   - 在 `CoreMetricDetailHero` 接入 `NightLandscape` 背景；
   - 新增 `SleepTimelineCard`，实现 4 轨阶段时间轴、真实时间戳投影、空隙保留、在床/实际睡眠双指标、未分期兜底及无障碍描述；
   - 更新 `MetricMethodologyCard` 睡眠计算原理说明。

3. **[VelaApp/Health/Services/PreviewHealthDataProvider.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Health/Services/PreviewHealthDataProvider.swift)**：
   - 增加 `-velaSleepFixtureUnsegmented` 与 `-velaSleepFixtureGap` 预览分支，支持真实验收未分期与带中断间隙的睡眠数据流。

4. **[VelaUITests/VelaSmokeUITests.swift](file:///Users/sunweizhou/Developer/Vela/VelaUITests/VelaSmokeUITests.swift)**：
   - 增加 `testSleepDetailDeepLaunch` 与 `testSleepDetailPushNavigationAndReturn` 自动化验收测试。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 睡眠评分（0–100 分）公式、各阶段权重及充分性计算 100% 保持不变；
- 睡眠阶段数据直接取自原始输入 `SleepSummary`，未修改底层模型；
- 所有时间单位（分钟/小时/百分比）与输入严格对应。

---

## 实际运行的命令与结果

| 命令 | 环境/设备 | 退出码/测试数 | 产物路径 | 未通过或跳过原因 |
|---|---|---|---|---|
| `python3 scripts/schema_fingerprint.py --check` | macOS (Python 3.12) | 0 (32/32 模型匹配) | 终端输出 | 无 |
| `python3 scripts/check_contrast.py` | macOS (Python 3.12) | 0 (textColor >= 4.5:1) | 终端输出 | 无 |
| `python3 scripts/check_fixed_fonts.py` | macOS (Python 3.12) | 0 (212 处文字与设计决策档位) | 终端输出 | 无 |
| `swift test --package-path BodySeekDomain` | macOS Swift 6.0 | 0 (11/11 passed) | 终端输出 | 无 |
| `swift test --package-path VelaBackend` | macOS Swift 6.0 | 0 (3/3 passed) | 终端输出 | 无 |
| `xcodebuild build -scheme Vela -configuration Debug -destination "platform=iOS Simulator,name=iPhone 17 Pro"` | iPhone 17 Pro (iOS 26.5) | 0 (BUILD SUCCEEDED) | `build/DerivedData/Build/Products/Debug-iphonesimulator/Vela.app` | 0 警告，0 错误 (Warnings as Errors 激活) |
| `xcodebuild test ... -only-testing:VelaTests` | iPhone 17 Pro (iOS 26.5) | 0 (549/549 passed) | `build/DerivedData/Logs/Test/` | 全部通过 |
| `xcodebuild test ... -only-testing:VelaUITests/VelaSmokeUITests/testSleepDetail*` | iPhone 17 Pro (iOS 26.5) | 0 (2/2 passed) | `build/DerivedData/Logs/Test/` | Deep Launch 与 Push 导航全部通过 |

---

## UI 证据

真实 7 状态截图矩阵保存在 `docs/validation/u4/after/`：

1. **正常浅色（Standard Light）**：
   - 路径：`docs/validation/u4/after/sleep-detail-normal-light.png`
   - 验证点：`NightLandscape` 星夜背景；实际睡眠 6小时26分，在床 6小时44分；4轨阶段时间轴（深睡/核心/REM/清醒）；跨午夜刻度 `23:42 → 06:26`；分期占比表格。
2. **正常深色（Standard Dark）**：
   - 路径：`docs/validation/u4/after/sleep-detail-normal-dark.png`
   - 验证点：暗色调夜空自然融合深色背景，对比度合格。
3. **未分期降级（Unsegmented Sleep）**：
   - 路径：`docs/validation/u4/after/sleep-detail-unsegmented.png`
   - 验证点：单轨“睡眠时间段”，明确提示“未分期 · 仅记录睡眠总段”，不伪造 REM/深睡。
4. **中断间隙（Gap Preservation）**：
   - 路径：`docs/validation/u4/after/sleep-detail-gap.png`
   - 验证点：夜间 50 分钟中途觉醒间隙如实保留空白，轨道绝不虚构连续连接线。
5. **超大字号无障碍（Accessibility XXXL）**：
   - 路径：`docs/validation/u4/after/sleep-detail-a11y.png`
   - 验证点：超大字号下文字与时间卡片纵向流动，无遮挡与截断。
6. **空数据状态（Empty State）**：
   - 路径：`docs/validation/u4/after/sleep-detail-empty.png`
   - 验证点：主环 `--`，提示“本晚没有可用的睡眠阶段记录”，不填零。
7. **Push 导航与返回（Push Navigation）**：
   - 路径：`docs/validation/u4/after/sleep-detail-push.png`
   - 验证点：导航栏左侧展示原生系统返回按钮（无多余关闭按钮），可侧滑返回。

---

## 算法证据

算法计算逻辑保持 100% 不变。领域层回归测试全部通过：
`BodySeekDomainTests.GoldenReplayTests` 与 `SleepReplaySensitivityTests` 均 100% 吻合。

---

## 未解决与未验证

1. **三方硬件睡眠数据直接导入验证**：模拟器通过预览桩进行了未分期与断档验证；后续在真实设备配合 Oura/Whoop/Garmin 同步时在 R1 统一验证。

---

## 回滚方法

`git revert <commit-sha>`

---

## 下一张建议卡（本会话不自动执行）

U5｜Trends 与首页小趋势的统一数据图形
