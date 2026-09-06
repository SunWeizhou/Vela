# 任务交接：U6｜其余详情与交互收尾

任务：U6｜其余详情与交互收尾  
状态：VERIFIED  
审阅起始 SHA：`8a13b70229ea3a31c58cd6babff1bd28ac118349`（U5 交付）  
交付 SHA：`cc67be11`  
工作区未提交改动与处理：包含 5 个核心代码文件、1 个 UI 自动化测试文件、6 份详情截图及 1 段完整端到端交互录像。

---

## 本卡改变的用户行为

1. **负荷、压力、能量详情标杆体验收敛（遵守 U6 要求 1）**：
   - **负荷（Strain / 耗力）**：重构并接入 `DesertLandscape`（沙漠沙丘与仙人掌温和矢量剪影），保留训练节律分解、心率区间与活动明细，接入 `MetricMethodologyCard` 明确心率负荷算法与活动范围；
   - **压力（Stress）**：重构并接入 `CoastalLandscape`（海岸波澜与微风矢量肌理），展示心率、HRV、睡眠债与近期负荷 4 项生理计算依据，并标注“尚无可追溯的连续日内压力采样”，不掩盖日内采样稀疏事实；
   - **能量（Energy）**：重构并接入 `MeadowLandscape`（晨光原野与起伏草丘矢量肌理），清晰展示早间储备（70分）与当前剩余（53分），量化负荷（-9）、压力（-9）、时间（-0）等衰减分解，明确估计依据与上游质量。

2. **Push 与 Sheet 全路由语义一致性（遵守 U6 要求 1 & 验收标准）**：
   - 负荷、压力、能量三页与恢复/睡眠完全同构：从 Today 首页卡片点击原生 Push 进入时，顶部提供原生返回按钮与全屏侧滑手势；从 Sheet/Deep Link 呼出时，顶部左上角展示圆角 `xmark` 关闭按钮。

3. **动画防抖与动效减弱（Reduce Motion）友好（遵守 U6 要求 3）**：
   - 修复了多次进入页面时的从零加载刺眼闪烁，复用当前 Store 快照与本地缓存；尊重系统 Reduce Motion 偏好设置，背景景观与圆环平稳渲染。

4. **历史日期切换与返回稳定性（遵守 U6 要求 2 & 4）**：
   - 快速在日历历史日之间切换，首屏与各项详情均锁定当天的快照数据，杜绝异步数据覆盖错乱；返回首屏平滑无卡顿。

---

## 实际修改文件及理由

1. **[VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailLandscapes.swift)**：
   - 将 `DesertLandscape`、`CoastalLandscape`、`MeadowLandscape` 全部重构为自适应 `GeometryReader` 矢量绘图。

2. **[VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMetricDetailWidgets.swift)**：
   - 将三套景观融入 `CoreMetricDetailHero` 对应指标分支；补充各指标的专属依据卡与科学原理说明。

3. **[VelaApp/Features/Minimal/VelaMinimalShell.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalShell.swift)**：
   - 在主 Shell 的 `AppSheet` 处理中补齐 `strainDetail`、`stressDetail`、`energyDetail` 的 Sheet 模态路由。

4. **[VelaApp/App/VelaApp.swift](file:///Users/sunweizhou/Developer/Vela/VelaApp/App/VelaApp.swift)**：
   - 在 App 启动参数中支持 `-velaOpenStrainDetail`、`-velaOpenStressDetail`、`-velaOpenEnergyDetail` 快捷路由。

5. **[VelaUITests/VelaSmokeUITests.swift](file:///Users/sunweizhou/Developer/Vela/VelaUITests/VelaSmokeUITests.swift)**：
   - 增加 `testStrainDetailDeepLaunch`、`testStressDetailDeepLaunch`、`testEnergyDetailDeepLaunch`；
   - 增加全链路交互测试 `testComprehensiveFullInteractionFlow`。

---

## 数值/单位/缺失/日期/算法版本是否改变

否。
- 负荷（0–21）、压力（0–100）、能量（0–100%）打分内核未作任何调整；
- 评分权重与数据库结构保持 100% 不变。

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
| `xcodebuild test ... -only-testing:VelaUITests` | iPhone 17 Pro (iOS 26.5) | 0 (13/13 passed) | `build/DerivedData/Logs/Test/` | 全部 UI 冒烟测试全绿 |
| 交互视频录制 | iPhone 17 Pro (iOS 26.5) | 0 (H.264 7.3MB) | `docs/validation/u6/after/u6-full-interaction.mp4` | 覆盖打开、切日、详情、返回、切趋势、切首页、切后台全流程 |

---

## UI 证据

1. **负荷详情（Strain Detail）**：
   - 浅色：`docs/validation/u6/after/strain-detail-light.png`（`DesertLandscape` 沙漠沙丘背景、参考区间 35-65、活跃时长 28 分钟、训练分解）
   - 深色：`docs/validation/u6/after/strain-detail-dark.png`
2. **压力详情（Stress Detail）**：
   - 浅色：`docs/validation/u6/after/stress-detail-light.png`（`CoastalLandscape` 海岸背景、心率/HRV/睡眠债/负荷 4 项生理依据）
   - 深色：`docs/validation/u6/after/stress-detail-dark.png`
3. **能量详情（Energy Detail）**：
   - 浅色：`docs/validation/u6/after/energy-detail-light.png`（`MeadowLandscape` 原野草丘背景、早间储备 70、当前剩余 53、负荷/压力/时间衰减分解）
   - 深色：`docs/validation/u6/after/energy-detail-dark.png`
4. **全链路交互录像（Full Interaction Video）**：
   - 路径：`docs/validation/u6/after/u6-full-interaction.mp4`
   - 记录完整链路：打开首页 → 切换历史日 → 进入详情 → 返回首页 → 切换趋势 Tab → 切换回今日 Tab → 前后台切换。

---

## 算法证据

纯视觉呈现、路由健壮性与无障碍修复，底层算法与公式未修改。

---

## 未解决与未验证

1. **日内高频压力实时采样**：目前 HealthKit 采样点主要依赖后台心率读数与静息心率估计，日内连续细粒度压力曲线上游数据源合同留待 S7 深化。

---

## 回滚方法

`git revert <commit-sha>`

---

## 下一张建议卡（本会话不自动执行）

S1｜真实观测窗口与质量合同
