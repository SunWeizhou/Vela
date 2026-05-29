# Phase 2 — 核心功能补全 BOM

> 执行顺序：BOM-6 → BOM-7 → BOM-8 → BOM-9
> 每个 BOM 可直接复制粘贴给编程助手

---

## 🔧 BOM-6：全局日期导航系统（最高优先级）

### 发给编程助手的指令：

```
## 任务：为 Vela 添加全局日期导航系统

### 背景
Vela 是一个 iOS 健康分析 App（SwiftUI + SwiftData）。目前所有页面只能查看"今天"的数据，无法回看历史日期。需要添加日期导航能力，让用户可以左右滑动或点击日期选择器查看任意一天的详情。

### 当前架构
- `VelaApp/Features/SharedComponents/DashboardViewModel.swift` — 管理数据加载，当前只加载今天
- `VelaApp/Core/Utilities/DailySummaryUseCase.swift` — 调用 HealthKit 和 SwiftData 获取数据
- `VelaApp/Core/Utilities/DashboardSummary.swift` — 数据模型，包含 date 字段
- `VelaApp/Features/SharedComponents/DetailScreenScaffold.swift` — 所有详情页使用的脚手架

### 具体要求

#### 1. DashboardViewModel 添加日期状态

```swift
@Published var selectedDate: Date = Date()

// 新增方法
func selectDate(_ date: Date) {
    selectedDate = date
}

func goToPreviousDay() {
    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
}

func goToNextDay() {
    // 不能超过今天
    let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
    if next <= Date() {
        selectedDate = next
    }
}

var isToday: Bool {
    Calendar.current.isDateInToday(selectedDate)
}
```

当 `selectedDate` 变化时，自动重新调用 `refresh()`。

#### 2. DailySummaryUseCase 支持指定日期

修改 `loadDashboard` 方法签名，接受一个可选的 `date: Date` 参数：
```swift
func loadDashboard(for date: Date = Date(), modelContext: ModelContext?) async throws -> DashboardSummary
```

内部逻辑改为查询指定日期的 HealthKit 数据和 SwiftData 记录。

#### 3. 创建 DateNavigationBar 组件

新建 `VelaApp/Features/SharedComponents/DateNavigationBar.swift`：

```swift
struct DateNavigationBar: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    
    // 显示效果：
    // [<]  周三, 5月20日  [>]
    // 如果是今天，右侧 > 按钮灰色不可点
    // 点击日期文字弹出 DatePicker sheet
    // 左右箭头切换前一天/后一天
}
```

视觉设计：
- 居中显示日期，格式：本地化的 "周X, M月D日"
- 左右两侧有 chevron.left / chevron.right SF Symbol 按钮
- 如果是今天，日期旁显示 "Today" / "今日" 标签
- 如果不是今天，右上角显示一个 "回到今天" 小按钮
- 点击日期文字弹出日期选择器（.graphical 样式），最早可选 90 天前
- 整体紧凑，高度约 44pt
- 使用 VelaTheme 颜色
- 支持左右滑动手势切换日期（DragGesture）

#### 4. 在 DetailScreenScaffold 中集成

修改 `DetailScreenScaffold.swift`，在 title 下方、hero 上方的位置插入 DateNavigationBar。

但由于不是所有页面都需要日期导航（比如 Settings、Journal），所以用一个参数控制：
```swift
struct DetailScreenScaffold<Hero: View, Content: View>: View {
    // ... 现有参数
    var showDateNavigation: Bool = false
    // ...
}
```

#### 5. 在主要详情页启用

以下页面启用日期导航（传 showDateNavigation: true）：
- SleepView
- RecoveryView  
- StrainView

HomeView 因为有自己的 header，不使用 DetailScreenScaffold 的日期导航，而是在 headerBar 下方直接嵌入 DateNavigationBar。

#### 6. 数据刷新逻辑

当日期变化时：
- DashboardViewModel.refresh() 传入 selectedDate
- 趋势数据（sleepTrend 等）根据 selectedDate 为结束日重新加载
- 如果某天没有数据，显示友好的空状态文案

### 验收标准
- 可以左右切换日期查看历史数据
- 可以点击日期弹出选择器跳转到任意日期（90 天内）
- 今天无法向右切换（右箭头禁用）
- 切换日期后数据正确刷新
- 所有主要详情页（Sleep/Recovery/Strain）和 Home 都有日期导航
- 有"回到今天"快捷按钮
- 双语正常
```

---

## 🔧 BOM-7：Strain 页面 Workout 列表

### 发给编程助手的指令：

```
## 任务：在 Strain 页面显示当天 Workout 列表

### 背景
Vela 的 Strain 页面只显示总分数值，不展示当天具体做了什么运动。需要读取 HealthKit 的 Workout 数据并以卡片列表形式展示。

### 需要修改/新建的文件
- 修改：`VelaApp/Features/Strain/StrainView.swift`
- 修改：`VelaApp/Core/Utilities/DashboardSummary.swift`
- 修改：`VelaApp/Health/Services/HealthKitQueryService.swift`
- 新建：`VelaApp/Features/Strain/WorkoutCard.swift`

### 具体要求

#### 1. 数据模型

在 DashboardSummary.swift 中新增：
```swift
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let activityType: String    // "Running", "Strength Training", etc.
    let systemImage: String     // SF Symbol for the activity
    let startTime: Date
    let duration: TimeInterval  // seconds
    let activeCalories: Double
    let averageHeartRate: Double?
    let maxHeartRate: Double?
}
```

在 StrainSummary（或 DashboardSummary）中新增字段：
```swift
var workouts: [WorkoutSummary] = []
```

#### 2. HealthKit Workout 查询

在 `HealthKitQueryService.swift` 中新增方法，查询指定日期的 HKWorkout 样本：
- 查询 HKSampleType.workoutType()
- 时间范围：selectedDate 当天 00:00 到 23:59:59
- 对每个 HKWorkout 提取：activityType, duration, totalEnergyBurned
- 查询每个 workout 期间的心率样本获取平均和最大心率
- 将 HKWorkoutActivityType 映射为中英文名称和 SF Symbol

活动类型映射表（至少覆盖以下常见类型）：
- running → "Running" / "跑步" → "figure.run"
- walking → "Walking" / "步行" → "figure.walk"
- cycling → "Cycling" / "骑行" → "figure.outdoor.cycle"
- swimming → "Swimming" / "游泳" → "figure.pool.swim"
- traditionalStrengthTraining → "Strength" / "力量训练" → "dumbbell.fill"
- yoga → "Yoga" / "瑜伽" → "figure.yoga"
- hiking → "Hiking" / "徒步" → "figure.hiking"
- other → "Workout" / "训练" → "figure.mixed.cardio"

#### 3. WorkoutCard 组件

新建 `WorkoutCard.swift`：
```swift
struct WorkoutCard: View {
    let workout: WorkoutSummary
}
```

视觉设计：
- 左侧：圆角方块图标背景 + SF Symbol
- 中间列：
  - 活动类型名称（粗体）
  - 开始时间（如 "14:30"）+ 时长（如 "45 min"）
- 右侧列：
  - 消耗卡路里（如 "320 kcal"）
  - 平均心率（如 "♡ 142 bpm"），如果有的话
- 使用 VelaTheme.strain 作为主色调
- 使用 .compactCard() 或 elevatedSurface 背景

#### 4. 在 StrainView 中集成

在 StrainView.swift 中，ArcProgressView 下方、趋势图上方的位置新增 workout 列表：

```swift
// Workouts Section
VStack(alignment: .leading, spacing: 12) {
    Label(L10n.t("Today's Workouts", "今日训练"), systemImage: "figure.run")
        .font(.headline)
        .foregroundStyle(VelaTheme.primaryText)
    
    if viewModel.dashboard.strain.workouts.isEmpty {
        Text(L10n.t("No workouts recorded today.", "今天还没有训练记录。"))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.secondaryText)
    } else {
        ForEach(viewModel.dashboard.strain.workouts) { workout in
            WorkoutCard(workout: workout)
        }
    }
}
.cardSurface()
```

### 验收标准
- 当天有 Workout 时显示卡片列表
- 每个卡片显示活动类型、时长、卡路里、心率
- 无 Workout 时显示空状态文案
- 至少覆盖 8 种常见运动类型的名称和图标映射
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 🔧 BOM-8：Sleep Needed 动态指标

### 发给编程助手的指令：

```
## 任务：添加 "Sleep Needed" 动态睡眠需求计算

### 背景
Vela 的睡眠目标当前是 Settings 中的固定值（默认 7.5 小时）。需要根据近期 Strain 和 Sleep Debt 动态计算"今晚需要睡多久"。

### 需要修改的文件
- `VelaApp/Scoring/Sleep/SleepScoreEngine.swift`
- `VelaApp/Core/Utilities/DashboardSummary.swift`
- `VelaApp/Features/Sleep/SleepView.swift`
- `VelaApp/Features/Home/HomeView.swift`

### 具体要求

#### 1. 计算逻辑

在 SleepScoreEngine 或新建一个 helper 中实现：

```swift
struct SleepNeedCalculator {
    /// 计算今晚推荐睡眠时长（小时）
    static func calculate(
        baseTarget: Double,           // 用户设定的基础目标（小时）
        recentStrainAvg: Double,      // 近 3 天平均 Strain (0-100)
        sleepDebtHours: Double,       // 累计睡眠债务（小时）
        recoveryScore: Double         // 今日 Recovery (0-100)
    ) -> SleepNeed
}

struct SleepNeed {
    let recommendedHours: Double     // 推荐时长
    let baseTarget: Double           // 基础目标
    let strainAdjustment: Double     // Strain 调整量
    let debtAdjustment: Double       // 债务调整量
    let reason: String               // 解释文案
}
```

计算规则：
- 基础 = 用户目标（如 7.5h）
- Strain 调整 = (recentStrainAvg - 50) / 50 * 0.5（即 Strain 高时多睡 0.5h，低时可少睡）
- 债务调整 = min(sleepDebtHours * 0.3, 1.0)（债务最多追加 1 小时）
- Recovery 调整 = recovery < 40 ? 0.3 : 0（低恢复时追加 0.3h）
- 最终 = clamp(base + strainAdj + debtAdj + recoveryAdj, 6.0, 10.0)

#### 2. 在 DashboardSummary 中暴露

```swift
// 在 SleepScoreSummary 或单独字段中
var sleepNeed: SleepNeed?
```

在 DailySummaryUseCase 的加载流程中计算并填充。

#### 3. 在 SleepView 中显示

在 Sleep 页面的 Hero 卡片下方添加：

```swift
if let need = viewModel.dashboard.sleepNeed {
    HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("Sleep Needed Tonight", "今晚需要睡眠"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(String(format: "%.1fh", need.recommendedHours))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.sleep)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 4) {
            Text(L10n.t("Base: \(String(format: "%.1f", need.baseTarget))h", "基础: \(String(format: "%.1f", need.baseTarget))h"))
            if need.strainAdjustment > 0.05 {
                Text(L10n.t("Strain: +\(String(format: "%.1f", need.strainAdjustment))h", "负荷: +\(String(format: "%.1f", need.strainAdjustment))h"))
            }
            if need.debtAdjustment > 0.05 {
                Text(L10n.t("Debt: +\(String(format: "%.1f", need.debtAdjustment))h", "债务: +\(String(format: "%.1f", need.debtAdjustment))h"))
            }
        }
        .font(.caption)
        .foregroundStyle(VelaTheme.secondaryText)
    }
    .cardSurface()
}
```

#### 4. 在 Home Dashboard 展示

在 Home 页的 Sleep 三列卡片中，如果有 sleepNeed 数据，在 subtitle 位置显示 "Need: 8.2h" 而非固定 "Score XX"。

### 验收标准
- Sleep Needed 根据 Strain/Debt/Recovery 动态变化
- Sleep 页面展示推荐时长和拆解
- Home Dashboard 的 Sleep 卡片展示推荐时长
- 数值在 6-10 小时的合理范围内
- 双语支持
```

---

## 🔧 BOM-9：趋势图交互增强

### 发给编程助手的指令：

```
## 任务：增强趋势图表的交互能力

### 背景
Vela 的 Recovery/Sleep/Strain 页面都有 30 天趋势图，目前是静态的 Swift Charts。需要添加触摸选择交互——长按或拖动时显示对应日期的数值。

### 需要修改的文件
- `VelaApp/Features/Recovery/RecoveryView.swift`（趋势图部分）
- `VelaApp/Features/Sleep/SleepView.swift`（趋势图部分）
- `VelaApp/Features/Strain/StrainView.swift`（趋势图部分）
- 新建：`VelaApp/Features/SharedComponents/InteractiveTrendChart.swift`

### 具体要求

#### 1. 新建 InteractiveTrendChart 可复用组件

```swift
struct InteractiveTrendChart: View {
    let data: [TrendPoint]
    let tint: Color
    let title: String
    let yDomain: ClosedRange<Double>
    var baselineValue: Double? = nil  // 可选基线参考线
    var height: CGFloat = 160
}
```

功能：
- 基础显示：AreaMark + LineMark + PointMark（和现有一样）
- 交互：使用 `.chartOverlay` + DragGesture 实现
  - 拖动时显示竖直参考线（RuleMark）
  - 参考线顶部显示选中日期的分数值气泡
  - 气泡样式：圆角矩形背景 + 日期 + 分数
  - 手指离开后气泡消失
- 如果提供了 baselineValue，显示水平虚线参考线 + "Avg: XX" 标注
- 图表左侧显示 Y 轴最大/最小标签
- 底部 X 轴显示首尾日期

#### 2. 替换现有图表

将 RecoveryView / SleepView / StrainView 中的 Chart 代码替换为 InteractiveTrendChart 调用：

```swift
InteractiveTrendChart(
    data: viewModel.recoveryTrend.map { TrendPoint(date: $0.date, value: $0.value) },
    tint: VelaTheme.recovery,
    title: L10n.t("30-Day Recovery", "30 天恢复"),
    yDomain: 0...100,
    baselineValue: avg
)
```

### 验收标准
- 拖动时显示竖直参考线和数值气泡
- 气泡显示日期和分数
- 手指离开后气泡消失
- 三个页面的图表都使用统一组件
- 可选的基线参考线正常显示
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 执行顺序

| 顺序 | BOM | 预计复杂度 |
|---|---|---|
| 1️⃣ | BOM-6 日期导航 | 高（涉及多文件联动） |
| 2️⃣ | BOM-7 Workout 列表 | 中 |
| 3️⃣ | BOM-8 Sleep Needed | 低中 |
| 4️⃣ | BOM-9 趋势图交互 | 中 |

> [!IMPORTANT]
> BOM-6 是 Phase 2 的基础。完成后，BOM-7/8/9 可以并行或按序执行。
> 提醒编程助手：**新建的文件必须添加到 Xcode project.pbxproj 中**，否则编译会报 "cannot find in scope"。
