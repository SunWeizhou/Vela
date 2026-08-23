# Vela 今日页流畅度专项优化与交接文档 (2026-08-24)

## 1. 问题复盘与根因分析

### 1.1 现象回顾
在 iPhone 16 Pro（iOS 26.6，Debug 构建）上，「今日」Tab 在滑动时出现严重掉帧（22-35fps，单帧最长 94-203ms），即使在无健康数据的冷启动状态下依然存在。

### 1.2 根因定位
通过真机控制台探针打点与 WAL 检查点日志分析，确定了**两大主因**：
1. **视图层级内部 `@Query` 频繁失效与 Faulting 解引用阻塞主线程**：
   - [`TodayTrainingPlanAdaptationCard`](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodayTrainingPlanAdaptationCard.swift) 内包含 2 个 `@Query`，在 SwiftData context 发生微小变化时触发失效重渲染；其 `body` 内访问 `activePlan.days` 触发 SwiftData relationship faulting，单次耗时达到 **+81ms ~ +96ms**。
   - [`VelaMinimalTodayView`](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/VelaMinimalTodayView.swift) 包含 `@Query private var dailyAIInsights: [AIReportRecord]`，同样引入了 context 变动时的重求值开销。
2. **手势冲突与视图渲染循环计算**：
   - 滚动容器全局 `DragGesture` 抢占了 UIKit 硬件加速滚动；
   - 历史趋势与体征卡片在 `body` 中缺乏针对性记忆化（Memoization）。

---

## 2. 架构修复与优化落地

### 2.1 彻底移除 View 层 `@Query`，转为 ViewModel 统一异步抓取
- **`DashboardViewModel` 扩展**：
  在 [`DashboardViewModel.swift`](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/SharedComponents/DashboardViewModel.swift) 的 `performLoadSecondaryData` 中一次性获取：
  - `activeTrainingPlan: TrainingPlanRecord?`
  - `pendingPlanAdaptation: TrainingPlanAdaptationRecord?`
  - `todayAIInsight: DailyAIInsight?`
- **卡片纯参数化改造**：
  [`TodayTrainingPlanAdaptationCard.swift`](file:///Users/sunweizhou/Developer/Vela/VelaApp/Features/Minimal/TodayTrainingPlanAdaptationCard.swift) 改为纯参数驱动视图（`let activePlan: TrainingPlanRecord`, `let pendingProposal: TrainingPlanAdaptationRecord`），完全剥离 `@Query`，并在 `@preconcurrency Equatable` 中精准比对变更属性，彻底斩断每帧重复求值。

### 2.2 清理全部调试探针与插桩
- 清理了 `AppCoordinator.swift` 中的 `VelaFPSMonitor`、`VelaFPSBadge`、`TodayPerfProbe`；
- 移除了 `TodaySignalGrid`、`TodaySubComponents`、`VelaMinimalTodayView` 等全部 `[DEBUG-fps]`、`[DEBUG-time]` 与 `TodayPerfProbe.shared.mark` 打点；
- 移除所有 `[PERF-EXP]` 临时注释，恢复整洁的生产级架构。

---

## 3. 验证结果

1. **单元测试**：全量 470+ 单元测试 **100% 通过（`** TEST SUCCEEDED **`）**。
2. **真机构建**：Xcode Debug/Release 零编译警告（`** BUILD SUCCEEDED **`）。
3. **真机部署**：已通过 CoreDevice 无线隧道成功部署并拉起在 `Weizhou的iPhone`（iPhone 16 Pro）上，滚动顺滑无卡顿。

---

## 4. Git 提交记录（分主题提交并已推送到 GitHub `main`）

* `02e0fa2a` - `docs: document Score-led Today architecture, ADR-0012/0013 and research specs`
* `3419e44c` - `design(figma-make): update tab navigation, styles and prototype pages`
* `356dfe66` - `feat(scoring): enhance baseline formation, multi-scale brief, and today experience model`
* `569d8588` - `feat(coach): polish coach history drawer, welcome workspace, onboarding and trust center`
* `d6a5fd22` - `feat(today): rebuild score-led today surface and eliminate hitching via zero-query cards and memoization`
* `3aa06bdd` - `test: update and expand scoring engine, baseline, and theme tests`

---

## 5. 给后续 Agent / 开发者的建议

1. **SwiftData 查询纪律**：
   - 避免在滚动列表（`ScrollView` / `LazyVStack`）的子卡片中直接使用 `@Query`。
   - 所有页面级数据加载应统一委托给对应页面的 ViewModel（如 `DashboardViewModel`）在后台线程获取并映射为 DTO / 属性发布。
2. **Equatable 隔离**：
   - 子组件实现 `Equatable` 时，入参优先选用不可变模型或纯值类型（如 `TodayExperienceModel`），若包含 `@Model` 类实例，使用 `@preconcurrency Equatable` 并明确字段比较。
