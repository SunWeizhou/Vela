# Phase 3 — AI Coach 体验升级 BOM

> 执行顺序：BOM-10 → BOM-11 → BOM-12 → BOM-13
> BOM-10/11 是核心（AI Chat），BOM-12/13 是算法补齐

---

## 🔧 BOM-10：对话式 AI Chat 界面

### 发给编程助手的指令：

```
## 任务：将 Coach 页面重做为对话式 Chat 界面

### 背景
Vela 的 Coach 页面当前是"点按钮 → 显示结果"模式，不是真正的对话体验。需要改造为类似 iMessage / ChatGPT 的消息气泡界面，支持对话历史。

### 当前代码
- `VelaApp/Features/Coach/CoachView.swift`（383 行，包含 ViewModel）
- `VelaApp/Features/Coach/CoachChatPanel.swift`

### 需要新建的文件
- `VelaApp/Features/Coach/ChatMessageView.swift`
- `VelaApp/Features/Coach/ChatInputBar.swift`

### 具体要求

#### 1. 数据模型

在 CoachViewModel 中新增：
```swift
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp: Date
    var isStreaming: Bool = false
    
    enum Role {
        case user
        case assistant
    }
}

@Published var messages: [ChatMessage] = []
```

在页面加载时，从 savedReports 中恢复最近的对话（最多 20 条），按时间排序。

#### 2. ChatMessageView 组件

```swift
struct ChatMessageView: View {
    let message: ChatMessage
}
```

视觉设计：
- **用户消息**：右对齐，VelaTheme.accent.opacity(0.15) 背景，accent 色文字
- **AI 消息**：左对齐，VelaTheme.elevatedSurface 背景，primaryText 色
- AI 消息头部显示 "Vela" + 小 VelaLogoMark 图标
- 时间戳显示在消息下方，mutedText 色，.caption2 字号
- AI 消息内容使用 MarkdownText 渲染（支持 Markdown 格式）
- 消息气泡圆角 16pt，padding 12pt
- 消息出现时有 fade-in + 轻微上移动画

#### 3. ChatInputBar 组件

页面底部固定的输入栏：
```swift
struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
}
```

视觉设计：
- TextField + 发送按钮（arrow.up.circle.fill）
- TextField 圆角胶囊形，elevatedSurface 背景
- 发送按钮在有文字时显示 accent 色，无文字时 mutedText
- 加载中时发送按钮变为 ProgressView
- 上方可选区域显示 2-3 个 Suggested Questions 横向滚动药丸

#### 4. CoachView 重构

重做 CoachView 的布局：
```
NavigationStack {
    VStack(spacing: 0) {
        // 顶部：Coach 状态栏
        // 中间：ScrollView + ScrollViewReader 的消息列表
        // 底部：ChatInputBar（固定）
    }
}
```

关键行为：
- 新消息添加后自动滚动到底部（用 ScrollViewReader.scrollTo）
- 用户发送消息时：追加 user message → 追加空的 assistant message（isStreaming: true）→ 调用 AI → 更新 assistant message 内容
- 保留现有的 Reports 按钮，但改为 NavigationLink 到一个子页面（ReportsListView）
- 保留 Weekly Review 按钮，放在导航栏的 toolbar 中
- 保留 Settings / Journal 的 NavigationLink，放在 toolbar menu 中

#### 5. 快捷问题

在消息列表为空时，显示居中的欢迎卡片 + 快捷问题网格。用户点击快捷问题后，等同于发送该问题。

### 验收标准
- 消息气泡左右对齐，视觉区分用户/AI
- 消息支持 Markdown 渲染
- 新消息自动滚动到底部
- 输入栏固定在底部
- 快捷问题可点击发送
- 空状态有欢迎界面
- Reports / Settings / Journal 功能不丢失
- 双语支持
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 🔧 BOM-11：AI 流式输出

### 发给编程助手的指令：

```
## 任务：为 AI Coach 添加流式输出（打字机效果）

### 背景
当前 AI 响应是一次性返回的。需要改为流式输出，让文字逐步出现（打字机效果），提升交互感。

### 需要修改的文件
- `VelaApp/AI/Provider/DeepSeekProvider.swift`
- `VelaApp/AI/Provider/LLMProvider.swift`
- `VelaApp/Features/Coach/CoachView.swift`（CoachViewModel 部分）

### 具体要求

#### 1. LLMProvider 协议添加流式方法

```swift
protocol LLMProvider {
    func complete(request: LLMRequest) async throws -> LLMResponse
    func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error>  // 新增
}
```

#### 2. DeepSeekProvider 实现 SSE 流式

使用 URLSession 的 `bytes(for:)` API 读取 Server-Sent Events (SSE)：

```swift
func stream(request: LLMRequest) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            // 构建请求，设置 "stream": true
            // 使用 URLSession.shared.bytes(for: urlRequest)
            // 逐行读取 "data: {...}" 
            // 解析 JSON 提取 delta.content
            // 每收到一个 token 调用 continuation.yield(token)
            // 收到 [DONE] 时调用 continuation.finish()
        }
    }
}
```

DeepSeek API 的流式格式和 OpenAI 兼容：
- 每行格式: `data: {"choices":[{"delta":{"content":"token"}}]}`
- 结束标记: `data: [DONE]`

#### 3. CoachViewModel 使用流式

在 `ask()` 方法中：
```swift
// 1. 追加空的 assistant message (isStreaming = true)
// 2. 调用 provider.stream(request:)
// 3. for try await token in stream { 
//        messages[lastIndex].content += token 
//    }
// 4. 完成后 messages[lastIndex].isStreaming = false
```

#### 4. UI 端响应

ChatMessageView 中，当 `message.isStreaming` 为 true 时：
- 消息末尾显示闪烁的光标（▊，0.5s 闪烁动画）
- 消息气泡底部不显示时间戳（等完成后再显示）

### 验收标准
- AI 回复逐 token 出现，有打字机效果
- 流式过程中显示闪烁光标
- 流式完成后光标消失，显示时间戳
- 网络错误时优雅降级（显示错误消息气泡）
- 现有的非流式 complete() 方法继续保留作为 fallback
```

---

## 🔧 BOM-12：心率区间分析

### 发给编程助手的指令：

```
## 任务：添加 Workout 心率区间分析和可视化

### 背景
需要在 Strain 页面的 Workout 详情中添加心率区间（HR Zone 1-5）分布分析。

### 需要修改/新建的文件
- 修改：`VelaApp/Health/Services/HealthKitQueryService.swift`
- 修改：`VelaApp/Core/Utilities/DashboardSummary.swift`（WorkoutSummary）
- 新建：`VelaApp/Features/Strain/HRZoneBarView.swift`
- 修改：`VelaApp/Features/Strain/WorkoutCard.swift`

### 具体要求

#### 1. HR Zone 计算

在 WorkoutSummary 中新增：
```swift
struct HRZoneDistribution {
    let zone1Minutes: Double  // <60% max HR (Warm Up)
    let zone2Minutes: Double  // 60-70% (Fat Burn)
    let zone3Minutes: Double  // 70-80% (Cardio)
    let zone4Minutes: Double  // 80-90% (Hard)
    let zone5Minutes: Double  // 90-100% (Max)
}
var hrZones: HRZoneDistribution?
```

Max HR 估算：220 - age（age 从 HealthKit 的出生日期计算，如果不可用默认 30 岁，即 maxHR = 190）。

在 HealthKit 查询 Workout 的心率样本后，按区间统计每个 zone 的时间。

#### 2. HRZoneBarView 组件

横向堆叠柱状图，5 个区间从左到右：
- Zone 1: 灰色
- Zone 2: VelaTheme.recovery（绿）
- Zone 3: VelaTheme.energy（黄）
- Zone 4: VelaTheme.strain（橙）
- Zone 5: VelaTheme.stress（红/粉）
- 每段宽度按时间占比
- 高度 20pt
- 圆角
- 下方标注每个区间的分钟数

#### 3. WorkoutCard 展开显示

WorkoutCard 添加可展开功能：
- 默认折叠状态显示基本信息
- 点击展开显示 HRZoneBarView
- 使用 DisclosureGroup 或自定义 expand/collapse 动画

### 验收标准
- Workout 有心率数据时显示 HR Zone 分布
- 5 个区间颜色正确
- 堆叠柱状图宽度按时间比例
- 点击可展开/折叠
- 无心率数据时不显示 Zone 区域
- 记得把新文件添加到 Xcode 项目 (project.pbxproj) 中！
```

---

## 🔧 BOM-13：Strain 对数算法

### 发给编程助手的指令：

```
## 任务：将 Strain 评分改为对数刻度

### 背景
当前 Strain 使用线性加权平均。真实的生理负荷是对数性质的——越高的负荷越难达到。需要改为对数刻度，使 Strain 0-100 的分布更符合生理现实。

### 需要修改的文件
- `VelaApp/Scoring/Strain/StrainScoreEngine.swift`

### 具体要求

#### 1. 对数化改造

将最终 Strain 分数通过对数映射：

```swift
// 原来的线性分数（0-100）
let linearScore = calculateLinearStrain(...)

// 对数化：让高分更难达到
// 使用公式：logScore = 100 * ln(1 + linearScore/100 * (e-1)) / ln(e)
// 简化为：logScore = 100 * log(1 + linearScore * 0.01718) / log(2.718)
// 这使得：linear 50 -> log ~69, linear 80 -> log ~88, linear 95 -> log ~97

// 或者更简单的幂函数映射：
let logScore = 100 * pow(linearScore / 100, 0.7)
// 这使得：linear 50 -> 61, linear 30 -> 40, linear 80 -> 86
```

选择 `pow(x, 0.7)` 映射，因为它：
- 低负荷时数值稍高（更鼓励轻度活动）
- 高负荷时增长变缓（模拟真实的边际递减）

#### 2. 保持可解释性

在 StrainSummary 的 reasons 中说明：
- "Strain uses logarithmic scaling — higher loads are progressively harder to achieve"
- "负荷使用对数刻度——越高的负荷越难达到"

#### 3. 确保不破坏现有逻辑

- 推荐范围（recommendedRange）的计算要基于对数后的分数
- targetStatus 的判定也基于对数后的分数
- components 中的子项分数保持线性（只有总分对数化）

### 验收标准
- Strain 总分使用对数刻度
- 低负荷略有提升，高负荷增长变缓
- 推荐范围和目标状态基于对数分数
- reasons 中有对数说明
- 单元测试（如果存在）更新
```
