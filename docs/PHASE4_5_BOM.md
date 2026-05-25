# Phase 4 & 5 — 数据深度 & 体验打磨 BOM

---

# Phase 4 — 数据深度与智能

> 执行顺序：BOM-14 → BOM-15 → BOM-16

---

## 🔧 BOM-14：周/月维度趋势对比

### 发给编程助手的指令：

```
## 任务：添加周/月维度的趋势对比视图

### 背景
Vela 目前只有 30 天趋势线。需要增加周对比和月对比视图，让用户看到"这周 vs 上周"、"这月 vs 上月"的变化。

### 需要新建的文件
- `VelaApp/Features/SharedComponents/PeriodComparisonCard.swift`
- `VelaApp/Features/Home/WeeklySummaryView.swift`

### 需要修改的文件
- `VelaApp/Features/SharedComponents/DashboardViewModel.swift`
- `VelaApp/Features/Home/HomeView.swift`

### 具体要求

#### 1. PeriodComparisonCard 组件

```swift
struct PeriodComparisonCard: View {
    let title: String          // "Recovery"
    let currentValue: Double   // 本期平均
    let previousValue: Double  // 上期平均
    let tint: Color
    let format: String         // "%.0f" or "%.1f"
}
```

视觉设计：
- 标题行：metric name + 趋势箭头（↑/↓）+ 变化百分比
- 数值行：大号当前值 + 小号 "vs 上周 XX"
- 变化为正时用 VelaTheme.recovery（绿），为负用 VelaTheme.stress（红）
- 内嵌一个迷你对比柱状图（两根竖条，一根代表本期，一根代表上期）

#### 2. WeeklySummaryView 页面

从 Home Dashboard 可进入的周总结页面：

```swift
struct WeeklySummaryView: View {
    // 显示内容：
    // - 本周 vs 上周的 Recovery / Sleep / Strain 平均值对比
    // - 本周每天的 Recovery 柱状图（7 根柱子）
    // - 本周总训练时长、总卡路里消耗
    // - 本周 Journal 条目数
}
```

#### 3. DashboardViewModel 数据支持

新增方法：
```swift
func loadWeeklyComparison(modelContext: ModelContext) async {
    // 从 SwiftData 查询最近 14 天数据
    // 分组为 thisWeek / lastWeek
    // 计算各指标平均值和差异
}
```

#### 4. Home 入口

在 Home 的 Streak/Weekly 区域添加一个"查看周报"按钮，NavigationLink 到 WeeklySummaryView。

### 验收标准
- 周对比卡片显示本期 vs 上期的数值和趋势
- 变化用颜色和箭头指示方向
- WeeklySummaryView 有完整的周数据
- 从 Home 可以进入
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 🔧 BOM-15：智能基线建模

### 发给编程助手的指令：

```
## 任务：升级基线计算为自适应滚动统计

### 背景
当前 Recovery 基线（HRV/RHR baseline）是简单的 28 天平均。需要改为更智能的滚动统计，包含标准差、百分位等信息。

### 需要修改的文件
- `VelaApp/Core/Utilities/DashboardSummary.swift`
- `VelaApp/Core/Utilities/DailySummaryUseCase.swift`
- `VelaApp/Features/Recovery/RecoveryView.swift`

### 具体要求

#### 1. 基线模型升级

```swift
struct AdaptiveBaseline {
    let mean: Double
    let standardDeviation: Double
    let p25: Double           // 25th percentile
    let p75: Double           // 75th percentile
    let sampleCount: Int
    let windowDays: Int       // 28
    
    /// 当前值在基线中的位置
    func zScore(for value: Double) -> Double {
        guard standardDeviation > 0 else { return 0 }
        return (value - mean) / standardDeviation
    }
    
    /// 返回定性描述
    func band(for value: Double) -> BaselineBand {
        let z = zScore(for: value)
        switch z {
        case ..<(-1.5): return .significantlyBelow
        case ..<(-0.5): return .belowNormal
        case ...0.5:    return .normal
        case ...1.5:    return .aboveNormal
        default:        return .significantlyAbove
        }
    }
}

enum BaselineBand: String {
    case significantlyBelow, belowNormal, normal, aboveNormal, significantlyAbove
}
```

#### 2. 计算逻辑

在 DailySummaryUseCase 中，查询 28 天的历史记录后：
- 计算 mean 和 standardDeviation
- 排序后计算 p25 和 p75
- 如果数据不足 7 天，标记 confidence 为 low

#### 3. RecoveryView 中使用

RecoveryFactorCard 的对比文案从简单的 "↑12%" 升级为：
- "Normal range" — 在 p25-p75 之间
- "Above baseline (+1.2σ)" — 高于均值 1 个标准差
- 用颜色编码：normal = secondaryText, above = recovery, below = stress

### 验收标准
- 基线包含 mean/SD/p25/p75
- Recovery 因子卡显示基于 z-score 的定性描述
- 数据不足时显示 "Building baseline (X/28 days)"
- 不破坏现有的基线比较功能
```

---

## 🔧 BOM-16：Journal 标签与指标智能关联

### 发给编程助手的指令：

```
## 任务：增强 Journal 标签与健康指标的关联分析

### 背景
Journal 页面已有基础的标签关联统计（30 天内每个标签的 Recovery/Sleep 平均值）。需要增强为可视化的关联热力图。

### 需要修改的文件
- `VelaApp/Journal/Views/JournalView.swift`
- 新建：`VelaApp/Journal/Views/TagCorrelationHeatmap.swift`

### 具体要求

#### 1. TagCorrelationHeatmap 组件

```swift
struct TagCorrelationHeatmap: View {
    let correlations: [TagCorrelationStat]
    // 已有的 TagCorrelationStat 包含：tag, count, avgRecovery, avgSleep
}
```

视觉设计：
- 每个标签一行
- 行内有两个色块：Recovery 影响 + Sleep 影响
- 色块颜色：
  - 深绿 = 平均 Recovery/Sleep ≥ 75（正面关联）
  - 浅绿 = 60-75
  - 灰色 = 45-60
  - 浅红 = 30-45
  - 深红 = <30（负面关联）
- 右侧显示数值
- 标签按影响力（与基线的偏差绝对值）排序
- 底部图例说明颜色含义

#### 2. 集成到 JournalView

在 Tag Insights 部分替换当前的文本列表，改用 TagCorrelationHeatmap。

保留现有的 tagCorrelations 计算逻辑，但新增排序：按与基线偏差排序。

#### 3. 添加 Coach 提示

如果某个标签的 avgRecovery 显著偏离基线（差值 > 15 分），在热力图下方显示一条 AI 提示：
- "Caffeine may be affecting your recovery (-18 avg)"
- "Sunlight days show higher recovery (+12 avg)"

### 验收标准
- 热力图以颜色直观显示各标签的健康影响
- 正面（高 Recovery/Sleep）绿色，负面红色
- 标签按影响力排序
- 有简短的 AI 提示文案
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

# Phase 5 — 体验打磨

> 执行顺序：BOM-17 → BOM-18 → BOM-19

---

## 🔧 BOM-17：iOS Widget

### 发给编程助手的指令：

```
## 任务：添加 iOS 主屏幕和锁屏 Widget

### 背景
需要添加 WidgetKit Widget，让用户不打开 App 就能看到核心指标。

### 需要做的事

#### 1. 添加 Widget Extension Target

在 Xcode 项目中新增 Widget Extension target（名称：VelaWidget），使用 WidgetKit + SwiftUI。

需要共享的数据：使用 App Groups（group.com.sunweizhou.Vela）+ UserDefaults 传递最新指标。

#### 2. 在 App 端写入数据

DashboardViewModel 每次 refresh 后，将核心指标写入共享 UserDefaults：
```swift
let defaults = UserDefaults(suiteName: "group.com.sunweizhou.Vela")
defaults?.set(dashboard.recovery.score, forKey: "widget_recovery")
defaults?.set(dashboard.sleepScore.score, forKey: "widget_sleep")
defaults?.set(dashboard.strain.score, forKey: "widget_strain")
defaults?.set(Date().timeIntervalSince1970, forKey: "widget_updated")
```

#### 3. Widget 类型

**Small Widget（锁屏/小方块）：**
- 显示 Recovery 分数 + 圆环
- Recovery band 文字
- 最后更新时间

**Medium Widget（中等矩形）：**
- 三列：Recovery | Sleep | Strain
- 每列显示分数 + 图标 + band

**锁屏 Widget（accessoryCircular）：**
- Recovery 圆环 + 分数数字

#### 4. 视觉

- 使用 VelaTheme 颜色（但 Widget 不能引用 App 的代码，需要在 Widget target 中复制色值常量）
- 深色背景
- 紧凑布局

### 验收标准
- Small/Medium/Circular 三种 Widget 可用
- Widget 显示最新的 Recovery/Sleep/Strain 分数
- 点击 Widget 打开 App
- Widget 在手机添加界面有预览
```

---

## 🔧 BOM-18：空状态优化

### 发给编程助手的指令：

```
## 任务：优化所有页面的空状态展示

### 背景
新用户首次使用时，所有指标都是 "--"。需要让空状态有引导性而不是一片空白。

### 需要修改的文件
- `VelaApp/Features/Home/HomeView.swift`
- `VelaApp/Features/Sleep/SleepView.swift`
- `VelaApp/Features/Recovery/RecoveryView.swift`
- `VelaApp/Features/Strain/StrainView.swift`
- 新建：`VelaApp/Features/SharedComponents/EmptyStateView.swift`

### 具体要求

#### 1. EmptyStateView 组件

```swift
struct EmptyStateView: View {
    let icon: String           // SF Symbol
    let title: String          
    let message: String        
    let tint: Color
    var actionTitle: String?   
    var action: (() -> Void)?  
}
```

视觉：
- 居中垂直布局
- 大尺寸半透明 SF Symbol 图标（60pt, tint.opacity(0.3)）
- 标题（.headline）+ 描述（.subheadline, secondaryText）
- 可选的 CTA 按钮

#### 2. 各页面空状态

**Home（无数据时）：**
- 图标：heart.text.square
- "Connect Apple Health to get started"
- CTA：重新请求 HealthKit 权限

**Sleep（无睡眠数据）：**
- 图标：moon.zzz.fill
- "Wear your Apple Watch to bed tonight to see your sleep analysis"

**Recovery（无恢复数据）：**
- 图标：waveform.path.ecg
- "Recovery data needs at least one night of tracked sleep and heart rate"

**Strain（无活动数据）：**
- 图标：figure.run
- "Start moving to see your strain score"

#### 3. 渐进式引导

当只有部分数据时（如有 Strain 但没有 Sleep），在空数据区域显示简短提示而非整页空状态。

### 验收标准
- 新用户首次打开不会看到大片空白
- 每个空状态有图标、文案和引导
- 有数据后空状态自动消失
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 🔧 BOM-19：错误处理完善

### 发给编程助手的指令：

```
## 任务：完善全局错误处理和 retry 机制

### 背景
当前的错误处理比较基础（显示 error.localizedDescription）。需要更优雅的错误展示和自动重试。

### 需要修改的文件
- `VelaApp/Features/SharedComponents/DashboardViewModel.swift`
- `VelaApp/Features/Coach/CoachView.swift`（CoachViewModel）
- 新建：`VelaApp/Core/Utilities/ErrorHandler.swift`

### 具体要求

#### 1. ErrorHandler 工具

```swift
enum VelaError: LocalizedError {
    case healthKitNotAuthorized
    case healthKitReadFailed(underlying: Error)
    case apiKeyMissing
    case networkUnavailable
    case aiProviderError(message: String)
    case rateLimited(retryAfter: TimeInterval)
    case unknown(Error)
    
    var localizedTitle: String { ... }
    var localizedMessage: String { ... }
    var isRetryable: Bool { ... }
    var suggestedAction: String? { ... }  // "Open Settings" / "Check API Key"
}
```

#### 2. 自动重试

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 2,
    operation: () async throws -> T
) async throws -> T
```

对网络请求和 HealthKit 查询，失败后自动重试（指数退避）。

#### 3. 错误 Toast

在 DashboardViewModel 中新增：
```swift
@Published var activeError: VelaError?
```

在 HomeView 中用 `.overlay` 显示滑入的错误 Toast：
- 顶部红色/橙色条
- 显示 localizedTitle + 简短 message
- 可重试的错误显示 "Retry" 按钮
- 3 秒后自动消失（不可重试的情况）

#### 4. AI 错误处理

CoachViewModel 中的 AI 调用失败时：
- rate limit → 显示 "请稍后再试（Xsec）"
- network → "网络不可用"
- API key → "请在设置中配置 API Key"

### 验收标准
- 错误分类清晰（HealthKit/网络/AI/未知）
- 可重试错误有 Retry 按钮和自动重试
- 错误 Toast 不阻断使用
- AI 错误有具体的引导
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 全局注意事项

> [!WARNING]
> **每个 BOM 完成后，必须确认新建的文件已添加到 Xcode project.pbxproj 中。**
> Phase 1 的经验表明编程助手经常忘记这一步。在发送每个 BOM 时附加提醒：
> "重要：所有新建的 .swift 文件必须添加到 Vela.xcodeproj/project.pbxproj 的 PBXFileReference、PBXBuildFile、PBXSourcesBuildPhase 和 PBXGroup 中。不这样做会导致 'cannot find in scope' 编译错误。"
