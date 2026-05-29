# Phase 1 — UI/UX 视觉升级 BOM 任务书

> 执行顺序建议：BOM-5 → BOM-1 → BOM-3 → BOM-4 → BOM-2
> 每个 BOM 可直接复制粘贴给编程助手

---

## 🔧 BOM-5：卡片系统 & 组件基础升级（先做这个）

### 发给编程助手的指令：

```
## 任务：升级 Vela 的卡片系统和共享组件

### 背景
Vela 是一个 iOS 健康分析 App（SwiftUI + SwiftData），参考 Bevel Health。当前所有卡片都使用统一的 .cardSurface() modifier，视觉上缺乏层次差异。需要建立一套更丰富的卡片组件系统。

### 需要修改的文件
- `VelaApp/Features/SharedComponents/HealthMetricCard.swift`
- `VelaApp/Core/Theme/VelaTheme.swift`
- `VelaApp/Core/Theme/VelaBackground.swift`（如有需要）
- 新建 `VelaApp/Features/SharedComponents/VelaCardStyles.swift`

### 具体要求

#### 1. 在 VelaTheme.swift 中新增 Design Tokens
```swift
// 新增这些常量
static let cardBackground = Color(red: 0.08, green: 0.08, blue: 0.10)
static let heroCardBackground = Color(red: 0.10, green: 0.10, blue: 0.13)
static let cardShadowColor = Color.black.opacity(0.3)
static let innerGlowOpacity: Double = 0.06
```

#### 2. 新建 VelaCardStyles.swift，定义 3 级卡片

创建三个 ViewModifier：

**HeroCardModifier** — 用于页面顶部的主指标卡片：
- 更大的圆角 (24pt)
- 顶部有细微的 accent 色渐变光晕 (从 accent.opacity(0.08) 渐变到透明)
- 轻微 shadow
- 内边距更大 (20pt)

**StandardCardModifier** — 用于普通指标卡片：
- 标准圆角 (20pt)
- 标准 surface 背景
- 0.5pt stroke (white.opacity(0.06))
- 内边距 16pt

**CompactCardModifier** — 用于小指标格子：
- 较小圆角 (14pt)
- elevatedSurface 背景
- 无 stroke
- 内边距 14pt

每个 modifier 都应该：
- 有从按下到释放的 0.97 scale 动画（用 .scaleEffect + .animation）
- 提供 `.heroCard(accent:)`, `.standardCard()`, `.compactCard()` 的 View extension

#### 3. 升级 HealthMetricCard.swift

当前的 HealthMetricCard 缺乏区分度。改造方案：

- 新增一个 `style` 参数：`.hero`, `.standard`, `.compact`
- hero 风格：数字更大 (48pt)，有 accent 色的底部渐变光条
- standard 风格：保持现有但使用新的 StandardCardModifier
- compact 风格：精简布局，数字 28pt

#### 4. 新增 SparklineView 组件

创建一个极简的小趋势线组件（用于卡片内嵌入）：
```swift
struct SparklineView: View {
    let data: [Double]   // 7-14 个数据点
    let tint: Color
    var height: CGFloat = 32
    // 使用 Path 绘制平滑曲线，面积填充渐变
}
```

#### 5. 确保向后兼容

当前的 `.cardSurface()` 和 `.heroCardSurface(accent:)` modifier 必须继续工作。新的卡片系统是增量添加，不是替换。

### 验收标准
- 三级卡片在 Preview 中视觉层级清晰
- 按压有 0.97 缩放动画
- SparklineView 能接受 [Double] 数组并渲染平滑曲线
- 现有的 HomeView 和其他页面不会因为这次修改而编译失败
```

---

## 🔧 BOM-1：Sleep 阶段时间轴组件

### 发给编程助手的指令：

```
## 任务：为 Sleep 页面创建睡眠阶段时间轴图表

### 背景
Vela 是一个 iOS 健康分析 App。Sleep 页面当前使用竖状柱状图（BarMark）展示睡眠阶段总分钟数，这丢失了最重要的时序信息。需要创建一个横向的睡眠阶段时间轴，类似 Bevel / Apple Health 的睡眠阶段图。

### 当前代码位置
- Sleep 页面：`VelaApp/Features/Sleep/SleepView.swift`
- 睡眠数据模型：`VelaApp/Health/Models/HealthDomainModels.swift`
- Dashboard 数据：`VelaApp/Core/Utilities/DashboardSummary.swift`
- 主题：`VelaApp/Core/Theme/VelaTheme.swift`

### 需要做的事

#### 1. 新建 `VelaApp/Features/Sleep/SleepStageTimelineView.swift`

创建一个横向睡眠阶段时间轴视图：

**数据输入：**
```swift
struct SleepStageSegment: Identifiable {
    let id = UUID()
    let stage: SleepStage  // .awake, .rem, .core, .deep
    let startTime: Date
    let endTime: Date
}
```

**视觉设计：**
- X 轴：时间（从入睡到起床），底部显示时间刻度（每2小时一个标记）
- Y 轴：4 个阶段层级（从上到下：Awake → REM → Core → Deep）
- 每个阶段段用对应颜色的圆角矩形块填充
- 阶段颜色：
  - Awake: VelaTheme.stress.opacity(0.7)
  - REM: VelaTheme.recovery
  - Core: VelaTheme.accent
  - Deep: VelaTheme.sleep
- 整体高度约 140pt
- 使用 Canvas 或 GeometryReader + 自定义绘制，不要用 Swift Charts（因为 Charts 不太适合这种阶梯式可视化）
- 左侧标签：Awake / REM / Core / Deep，字号 .caption2，颜色 mutedText
- 段与段之间要平滑过渡（可以用直角阶梯，不需要曲线）

**示例效果：**
```
Awake  ████                    ██
REM         ████████      ████████
Core    ████        ██████
Deep              ████████
       ─────────────────────────────
       23:00  01:00  03:00  05:00  07:00
```

#### 2. 确保数据可用

检查 `DashboardSummary` 中的 `sleepSummary` 是否已经包含睡眠阶段的时间段数据（startTime/endTime 粒度）。

如果当前只有总分钟数而没有时间段数据：
- 在 `VelaApp/Health/Models/HealthDomainModels.swift` 中的 SleepSummary 结构体里添加 `stageSegments: [SleepStageSegment]` 字段
- 在 `VelaApp/Health/Services/HealthKitQueryService.swift` 中，查询 HealthKit 睡眠样本时保留每个 HKCategorySample 的 startDate 和 endDate
- 在 `VelaApp/Health/Mapping/HealthKitSleepStageMapper.swift` 中做映射

#### 3. 在 SleepView.swift 中替换图表

替换当前的柱状图部分：
```swift
// 替换这段代码 (大约在第 43-61 行)：
VStack(alignment: .leading, spacing: 12) {
    Label("Sleep Stage Chart", ...)
    Chart(stageRows) { ... BarMark ... }
}
```

替换为：
```swift
VStack(alignment: .leading, spacing: 12) {
    Label(L10n.t("Sleep Stages", "睡眠阶段"), systemImage: "chart.bar.fill")
        .font(.headline)
        .foregroundStyle(VelaTheme.primaryText)
    
    SleepStageTimelineView(
        segments: viewModel.dashboard.sleepSummary.stageSegments,
        bedtime: viewModel.dashboard.sleepSummary.bedtime,
        wakeTime: viewModel.dashboard.sleepSummary.wakeTime
    )
}
.cardSurface()
```

#### 4. Preview 支持

在 SleepStageTimelineView 中提供 Preview，使用模拟数据（生成一晚 7 小时的典型睡眠阶段段）。

### 验收标准
- 时间轴横向展示整晚睡眠，能清楚看到各阶段切换
- 4 个阶段有颜色区分
- 底部显示时间刻度
- 左侧显示阶段名称
- 无数据时显示空状态文案
- Preview 中可直接看到效果
```

---

## 🔧 BOM-3：Strain 弧形进度条

### 发给编程助手的指令：

```
## 任务：为 Strain 页面创建弧形进度条组件

### 背景
Vela 的 Strain 页面需要一个弧形（半圆/270度弧）进度条来展示当天的 Strain 进度，类似 Bevel 的 Strain 可视化。当前 Strain 页只有 ScoreRingView（完整圆环），视觉表达不够好。

### 需要新建的文件
- `VelaApp/Features/SharedComponents/ArcProgressView.swift`

### 修改的文件
- `VelaApp/Features/Strain/StrainView.swift`

### 具体要求

#### 1. ArcProgressView 组件

```swift
struct ArcProgressView: View {
    let score: Double        // 0-100
    let tint: Color
    let recommendedRange: ClosedRange<Int>  // 例如 40...70
    var size: CGFloat = 200
    var lineWidth: CGFloat = 14
}
```

**视觉设计：**
- 270 度弧形（底部缺口 90 度，从左下到右下）
- 背景轨道：白色 opacity(0.06)
- 进度弧：使用 tint 色，带圆角末端 (.round lineCap)
- 推荐范围在弧形上用不同透明度标记（recommendedRange 对应的弧段用 tint.opacity(0.2) 高亮）
- 中心显示分数数字（大号 .system(size: 48, weight: .bold, design: .rounded)）
- 分数下方显示 Band 文字（如 "Within Target"）
- 弧形进度要有出现动画（从 0 到目标值，duration 0.8, easeOut）
- 末端有一个小圆点指示器

#### 2. 在 StrainView.swift 中使用

替换当前第 76-89 行的 ScoreRingView 区域，改用 ArcProgressView 作为 Hero 区域。

布局建议：
```swift
VStack(spacing: 16) {
    ArcProgressView(
        score: viewModel.dashboard.strain.score,
        tint: VelaTheme.strain,
        recommendedRange: viewModel.dashboard.strain.recommendedRange
    )
    
    Text(localizedTarget(viewModel.dashboard.strain.targetStatus))
        .font(.headline.weight(.semibold))
        .foregroundStyle(VelaTheme.primaryText)
}
.cardSurface()
```

### 验收标准
- 弧形从底部缺口展开 270 度
- 进度值 0-100 正确映射到弧长
- 推荐范围在弧上有视觉标记
- 出现时有 0→目标值 的填充动画
- 中心有分数数字
- Preview 可用
```

---

## 🔧 BOM-4：Recovery 页面视觉升级

### 发给编程助手的指令：

```
## 任务：升级 Recovery 详情页的视觉表现

### 背景
Recovery 页面是 Vela 最重要的页面之一。当前版本虽然数据完整，但视觉表现力不够。需要让贡献因子拆解更像 Bevel 的独立小卡片风格，并增强趋势图。

### 修改的文件
- `VelaApp/Features/Recovery/RecoveryView.swift`
- `VelaApp/Features/SharedComponents/ScoreRingView.swift`

### 具体要求

#### 1. 升级 ScoreRingView

当前的 ScoreRingView 比较基础。增加以下特性：
- 环的背景轨道使用 tint.opacity(0.1) 而不是纯白低透明度
- 进度有从 0 到目标值的动画 (duration 1.0, spring 弹性)
- 中心分数数字也有计数动画（从 0 数到目标值）
- 环外围有一圈极淡的 glow 效果 (shadow(color: tint.opacity(0.3), radius: 12))

#### 2. 贡献因子改为独立卡片

替换当前 RecoveryView 中的贡献拆解部分（约第 69-96 行的 ForEach + GeometryReader 进度条），改为 4 个独立的小卡片：

每个因子卡片 `RecoveryFactorCard`：
```swift
struct RecoveryFactorCard: View {
    let name: String           // "HRV"
    let icon: String           // "waveform.path.ecg"
    let tint: Color
    let todayValue: String     // "42ms"
    let baselineValue: String  // "48ms"
    let delta: String          // "↓12%"
    let isPositive: Bool
    let weight: Double         // 0.35
}
```

布局为 2x2 网格：
- 左上：HRV (icon: waveform.path.ecg, tint: recovery)
- 右上：Resting HR (icon: heart.fill, tint: sleep)  
- 左下：Sleep (icon: moon.fill, tint: accent)
- 右下：Prior Strain (icon: flame.fill, tint: strain)

每个卡片内部：
- 顶部：icon + 名称
- 中间：今日值（大号）+ 和基线的对比箭头 (↑/↓ + 百分比)
- 底部：权重百分比文字（如 "Weight: 35%"）
- 正向用 recovery 色，负向用 stress 色

#### 3. 趋势图增加基线参考线

在 30 天 Recovery 趋势图中：
- 增加一条水平虚线表示 28 天基线平均值
- 虚线颜色: VelaTheme.mutedText.opacity(0.5)
- 虚线上方标注 "Avg: XX"

### 验收标准
- ScoreRingView 有出现动画和 glow
- 4 个贡献因子各自独立成卡片，有颜色区分
- 每个因子卡显示今日值 vs 基线对比
- 趋势图有基线参考线
- 整体页面视觉层次比之前丰富
```

---

## 🔧 BOM-2：Home Dashboard 重新设计（最后做）

### 发给编程助手的指令：

```
## 任务：重新设计 Home Dashboard 页面

### 背景
Vela 是一个 iOS 健康分析 App，Home Dashboard 是用户每天第一眼看到的页面。当前版本使用统一的 HealthMetricCard 在 2x2 网格中展示，缺乏视觉冲击力和层级差异。需要参考 Bevel Health 的信息架构，但保持 Vela 自己的 Apple+Claude 视觉风格。

### 当前代码
- `VelaApp/Features/Home/HomeView.swift`（754 行）

### 重要约束
- 不能删除任何现有功能（NavigationLink、数据绑定、HealthKit 连接卡片等）
- 所有数据源继续使用 `viewModel.dashboard`
- 双语 L10n.t() 继续使用
- VelaTheme 色彩系统继续使用

### 具体要求

#### 1. 整体布局重构

将当前的 ScrollView 内容从统一网格改为以下分层结构：

**第一层：Header（保持现有 headerBar，微调）**
- 保留 VelaLogoMark + 问候语 + 最后更新时间

**第二层：Hero 区域（Recovery 主角）**
- 用一个全宽大卡片展示 Recovery
- 左侧：ScoreRingView (size: 110)
- 右侧：Recovery 分数 + Band + 一句话原因
- 底部行：三个迷你指标横排（Sleep Score | Strain Score | Stress Index），用 CompactMetric 风格
- 使用 .heroCard(accent: VelaTheme.recovery) modifier
- 这个卡片点击进入 RecoveryView

**第三层：三列核心指标行**
横向排列 3 个竖向窄卡片，每个有独特颜色标识：
- Sleep 卡片（VelaTheme.sleep）：
  - 月亮 icon
  - 总时长 "7h 12m"
  - 下方小字 "Score 78"
  - 嵌入 SparklineView 显示 7 天趋势
  - 点击进入 SleepView
  
- Strain 卡片（VelaTheme.strain）：
  - 火焰 icon
  - Strain 分数
  - 下方小字 "Within Target"
  - 嵌入小弧形进度指示（可以是简化版 ArcProgressView 或进度条）
  - 点击进入 StrainView
  
- Energy 卡片（VelaTheme.energy）：
  - 电池 icon
  - 当前能量值
  - 下方小字 Status
  - 点击进入 EnergyBankDetailView

使用 HStack(spacing: 10) 布局，每个卡片等宽。

**第四层：AI Daily Insight（全宽）**
保留现有的 dailyInsightCard 但升级视觉：
- 左侧加一个渐变色的 sparkle icon 圆形背景
- 文字区域稍大
- 底部加 "Ask Coach →" CTA 按钮

**第五层：次要指标 2x2 网格**
保留现有的 Stress / Energy / Health Age / Journal 四个 CompactHomeMetric 网格。

**第六层：Apple Health 连接 & Streak**
保留现有的 healthConnectCard 和 streakCard。

#### 2. 删除或合并冗余

- 移除现有的 `sectionLabel("Today's Metrics", ...)` 标题，让布局更沉浸
- Recovery 不再出现在中间的 LazyVGrid 中（已在 Hero 区展示）
- AI Daily Insight 不再出现在 LazyVGrid 中（已独立成卡片）
- Energy 可以既在三列行中出现，也在次要网格中（如果你觉得重复，从次要网格移除 Energy，替换为其他有意义的指标）

#### 3. 过渡动画

- 页面加载时，Hero 区域有从 opacity 0 → 1 的 fade in (duration 0.4)
- 三列卡片依次出现 (staggered delay 0.1s each)
- Pull to refresh 时 Hero 区的 ScoreRing 有短暂的旋转脉冲动画

### 验收标准
- 首屏（不滚动）能看到：Recovery Hero + Sleep/Strain/Energy 三列 + AI Insight
- Hero Recovery 卡片明显区别于其他卡片（更大、更突出）
- 三列指标行有颜色区分和独特内容
- AI Insight 卡片有存在感
- 所有 NavigationLink 正常工作
- 所有数据源正确绑定
- 双语继续正常
- 空数据状态有合理展示
```

---

## 执行顺序总结

| 顺序 | BOM | 说明 |
|---|---|---|
| 1️⃣ | BOM-5 | 先建卡片系统基础 |
| 2️⃣ | BOM-1 | 睡眠时间轴（独立组件） |
| 3️⃣ | BOM-3 | Strain 弧形进度（独立组件） |
| 4️⃣ | BOM-4 | Recovery 视觉升级 |
| 5️⃣ | BOM-2 | Home Dashboard 重做（依赖前面的组件） |

> [!TIP]
> 每完成一个 BOM 后，先在真机或模拟器上验证效果，再继续下一个。
> BOM-2 依赖 BOM-5 的卡片系统和 BOM-1/3 的组件，所以放最后。
