# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# STITCH_DESIGN_BRIEF.md
# Project Vela — Stitch Design Brief

> Purpose: 用于指导 Stitch MCP + Stitch Skills 为 Vela 生成高质量 iOS UI 设计稿  
> Product: A local-first AI health coach for Apple Health  
> Design stance: **Bevel-like personal UI target + Vela local-first intelligence**

---

# 1. 设计目标

请为一款 iOS 健康分析 App 设计完整的移动端界面系统。

该 App 名称暂定为：

```text
Vela
```

一句话定位：

> A Bevel-like, local-first AI health companion that turns Apple Health data and a user-maintained Wiki into daily readiness, fitness, vitals, journal context, and personalized coaching insights.

---

# 2. 设计参考

## 2.1 主要参考
- Bevel Health：信息架构、仪表盘密度、健康指标卡片组织方式；
- Apple Health：可信赖、系统级清晰度；
- Claude：温暖、克制、安静、高级；
- Oura / Whoop：评分表达与健康状态的仪式感。

---

## 2.2 重要原则
当前个人构建目标：
- 高度贴近 Bevel 的浅色信息架构、卡片节奏、底部导航、指标组织和可扫读性；
- 不复制 Bevel 的 logo、商标、专有插画或无法审计的远端服务；
- Vela 的差异必须体现在 local-first、用户 Wiki、透明评分原因、可替换 AI Provider 和 Agent 行为上。

---

# 3. 设计关键词

```text
Calm
Premium
Minimal
Elegant
Data-rich but not noisy
Soft depth
Bevel-like light mode
Clear hierarchy
Human-centered AI
Subtle glass / blur feeling if appropriate
```

---

# 4. 平台与画板

## 4.1 平台
- iOS native mobile app
- Primary target: modern iPhone viewport
- 建议画板优先使用常见 Pro 尺寸比例

## 4.2 模式
第一版优先生成：
- Light Mode

可选扩展：
- Dark Mode follow-up

原因：
- 当前 iPhone 参考中的 Bevel 首页和主路径以浅色柔和卡片为目标；
- Vela 旧深色构建已经可用，但与用户要求的 1:1 Bevel-like 方向不一致；
- 后续暗色模式应作为主题，而不是默认设计基线。

---

# 5. 全局导航

底部 Tab Bar 固定为：

1. Home
2. Journal
3. Fitness
4. Vitals
5. Plus / Intelligence

图标建议：
- Home: house / dashboard
- Journal: book / square.and.pencil
- Fitness: figure.run / activity
- Vitals: heart / waveform
- Plus / Intelligence: plus circle / sparkle

---

# 6. 全局视觉系统建议

## 6.1 色彩
整体背景：
- 浅灰白 / 微绿灰；
- 白色半透明浮层卡片；
- 卡片层级通过柔和阴影、极轻边框和留白区分。

强调色建议：
- Recovery：柔和青绿 / teal
- Sleep：靛蓝 / violet
- Strain：橙红 / warm coral
- Stress：玫红 / amber 过渡
- Energy：暖黄 / lime
- Coach：中性色 + subtle gradient

## 6.2 字体层级
- 大数字：用于分数与状态；
- 中号标题：模块标题；
- 小字：解释与上下文；
- 辅助标签：Low / Moderate / High。

## 6.3 卡片风格
- 2xl rounded corners
- Soft inner padding
- Subtle borders / low-contrast strokes
- Gentle gradient areas
- Rich but not crowded
- Every card should feel tappable

---

# 7. 页面一：Home Dashboard

## 7.1 页面目标
用户打开 App 3 秒内应知道：
1. 今天恢复怎么样；
2. 昨晚睡得如何；
3. 今天活动负荷到哪里了；
4. AI 对今天的核心建议是什么。

---

## 7.2 页面结构

### 顶部 Header
- Greeting: "Good Morning, Joe"
- Date
- Optional small status line: "Your body looks moderately recovered today"

### Hero Summary Area
一个高级但克制的综合状态区域，可展示：
- Today's readiness / overall status；
- 或视觉上以三个核心 score 摘要组合。

### Card 1 — Recovery
- Large score
- Band: Moderate / High / Low
- Short reason text
- Tiny sparkline or factor summary
- Tappable card

### Card 2 — Sleep
- Sleep Score
- Total duration
- Bedtime / Wake time
- Mini sleep timeline preview
- Tappable card

### Card 3 — Strain
- Today's strain ring / progress
- Target band indicator
- "Within target" or similar text
- Tappable card

### Card 4 — AI Daily Insight
- Prominent text block
- Example:
  > "You recovered moderately well. A lighter training day may fit better than an intense session."
- One subtle CTA: "Ask Coach"

### Card 5 — Stress
- Current stress proxy level
- Mini trend
- Disclaimer-level subtle copy optional

### Card 6 — Energy Bank
- Morning Energy
- Current Energy
- Battery-like visual allowed

### Card 7 — Health Age Trend
- Improving / Stable / Worsening
- Beta label
- Minimal sparkline

---

## 7.3 Home Stitch Prompt

```text
Design a premium Bevel-like light-mode iOS home dashboard for an AI-native Apple Health companion app called Vela. Use a bottom tab bar with Home, Journal, Fitness, Vitals, and a plus Intelligence action. The visual style should feel like Bevel's soft card-based clarity while retaining Vela's local-first AI identity.

The screen should include:
- Greeting header with date and concise body-state summary
- A hero health status area
- Recovery card with 0-100 score, band label, tiny trend
- Sleep card with score, duration, bedtime/wake time, tiny sleep timeline
- Strain card with progress ring and recommended range
- AI Daily Insight card with a concise recommendation and CTA "Ask Coach"
- Stress card with today's proxy level
- Energy Bank card with morning and current energy
- Health Age Trend beta card with improving/stable/worsening status

Use a pale gray-white background, white floating cards, subtle shadows, rounded metric rings, highly legible black typography, and elegant data visualization accents. Make it feel like a product people would open every morning.
```

---

# 8. 页面二：Sleep

## 8.1 页面目标
展示昨晚睡眠，并让用户明白：
- 睡了多久；
- 作息是否规律；
- 睡眠阶段结构；
- AI 怎么解释昨晚的睡眠。

---

## 8.2 页面结构

### Header
- Sleep title
- Date selector or "Last Night"

### Hero Score
- Sleep Score 0–100
- Band label
- One sentence interpretation

### Core Metrics Row
- Total sleep
- Bedtime
- Wake time

### Sleep Stage Timeline
- visually central
- REM / Core / Deep / Awake
- polished timeline

### 7-day Sleep Trend
- small chart
- duration trend

### AI Sleep Review Card
- short analysis
- CTA: "Open full review"

---

## 8.3 Sleep Stitch Prompt

```text
Design a Bevel-like light-mode iOS Sleep detail screen for Vela, an AI-native Apple Health analytics app. The screen should feel premium, calm, and deeply polished. Use Apple-like spacing and Bevel-like card clarity.

Include:
- Header: Sleep, last night date context
- Large Sleep Score with status band
- One-line sleep interpretation
- Three metric tiles: total sleep duration, bedtime, wake time
- A beautiful sleep stage timeline chart with REM, Core, Deep, and Awake
- A 7-day sleep duration trend chart
- An AI Sleep Review card with a concise summary and a CTA

Use light floating surfaces, subtle shadows, clear metric hierarchy, rounded cards, and emotionally calm visual design.
```

---

# 9. 页面三：Recovery

## 9.1 页面目标
让用户理解：
- 今天 Recovery 是多少；
- 为什么是这个分数；
- 哪些指标推动了恢复；
- 近 30 天变化如何。

---

## 9.2 页面结构

### Header
- Recovery
- Today

### Hero Recovery Ring
- 0–100 Score
- Low / Moderate / High
- concise interpretation

### Factor Breakdown
四个贡献项卡片：
- HRV
- Resting Heart Rate
- Sleep
- Prior Strain

每项展示：
- 状态
- 今日值 vs baseline
- 正负向影响

### Trend Area
- HRV 30-day trend
- RHR 30-day trend

### AI Recovery Insight
- why score is high/low today
- CTA: "Ask Coach about recovery"

---

## 9.3 Recovery Stitch Prompt

```text
Design a premium Bevel-like light-mode Vitals screen for Vela. It should communicate recovery, HRV, resting heart rate, and sleep-linked physiology in a calm, elegant, data-rich but uncluttered way.

Include:
- Vitals header
- Large circular recovery score 0-100 with status band
- A short explanatory sentence
- Four contribution cards: HRV, Resting Heart Rate, Sleep, Prior Strain
- Each contribution card shows today's state relative to personal baseline
- A 30-day HRV trend chart
- A 30-day Resting Heart Rate trend chart
- AI Recovery Insight card with CTA

The interface should feel refined, trustworthy, and deeply polished.
```

---

# 10. 页面四：Strain

## 10.1 页面目标
让用户知道：
- 今天累计负荷有多高；
- 是否在推荐区间；
- 做了什么 workout；
- AI 建议今天该继续训练还是收手。

---

## 10.2 页面结构

### Header
- Strain
- Today

### Hero Strain Progress
- Today's Strain Score
- Circular or arc progress visualization
- Recommended range

### Summary Cards
- Active Energy
- Workout count
- Training recommendation / target state

### Today's Workouts
- List of workouts
- duration
- category
- optional strain contribution

### AI Workout Readiness Card
- recommendation
- "Light / Moderate / Hard / Rest"

---

## 10.3 Strain Stitch Prompt

```text
Design a Bevel-like light-mode iOS Fitness screen for Vela, an Apple Health analytics app. Make it look premium, confident, and highly usable, with strain and training readiness as the main daily decision.

Include:
- Fitness header and date
- Large strain score with arc or progress ring
- Recommended strain target range
- Status text: Below target / Within target / Above target
- Cards for Active Energy and today's workout count
- List of today's workouts with elegant cards
- AI Workout Readiness card recommending light, moderate, hard, or recovery day

Use a soft light background, white cards, tasteful accent color, strong numeric hierarchy, and well-balanced spacing.
```

---

# 11. 页面五：Coach

## 11.1 页面目标
把 AI Coach 做成：
- 可问答；
- 可查看日报 / 周报；
- 能感受到“这是一个真正了解我的健康助手”。

---

## 11.2 页面结构

### Header
- Coach
- Optional subtitle: "Your private health analyst"

### Today Insight
- Morning Brief summary
- Quick regenerate / open detail CTA

### Suggested Questions
chips:
- "Why is my recovery low?"
- "Should I train today?"
- "Summarize last night's sleep"
- "What changed this week?"

### Conversation Area
- Recent chat thread
- Chat composer
- Voice input optional future

### Reports Section
- Morning Brief
- Sleep Review
- Workout Readiness
- Weekly Review

---

## 11.3 Coach Stitch Prompt

```text
Design a premium Bevel-like light-mode `+` Intelligence screen for Vela, a local-first Apple Health intelligence app. It should feel like a private, trusted health analyst rather than a generic chatbot.

Include:
- Header: Vela Intelligence, subtitle "Your private health analyst"
- A Today's Insight card summarizing the morning brief
- Suggested question chips such as:
  "Why is my recovery low?"
  "Should I train today?"
  "Summarize last night's sleep"
  "What changed this week?"
- A recent conversation preview area
- A bottom chat composer
- A reports section containing Morning Brief, Sleep Review, Workout Readiness, and Weekly Review

The design should feel AI-native, highly polished, and integrated into a premium health product.
```

---

# 12. 页面六：Journal

## 12.1 页面目标
允许用户用极低成本记录：
- 生活事件；
- 身体感受；
- 情绪；
- 未来供 AI 归纳用户经历。

---

## 12.2 页面结构

### Header
- Journal
- Today

### Quick Tags
- Coffee
- Alcohol
- Late Dinner
- Late Sleep
- Nap
- Workout
- Fatigue
- Mood
- Sick / Unwell
- Custom Tag

### Free Text Input
- "What should Vela remember about today?"

### Recent Entries
- timestamp
- tags
- note preview

### AI Reflection (optional in later build)
- not necessary for first design unless there is room

---

## 12.3 Journal Stitch Prompt

```text
Design a Bevel-like light-mode iOS Journal entry screen for Vela. The screen should feel lightweight, emotionally warm, and easy to use daily. It should allow a user to quickly record daily experiences that Vela Intelligence can later reference.

Include:
- Header: Journal, Today
- Quick selectable tags: Coffee, Alcohol, Late Dinner, Late Sleep, Nap, Workout, Fatigue, Mood, Sick/Unwell, Custom
- A free text input area with placeholder: "What should Vela remember about today?"
- A primary action button to save entry
- Recent entries list with tags and note previews

Use rounded tag pills, soft white cards, subtle shadows, and a refined but approachable visual style.
```

---

# 13. 页面七：Settings / API Key

## 13.1 页面目标
提供：
- DeepSeek API Key 配置；
- Provider 状态；
- 隐私说明；
- Wiki 管理入口。

---

## 13.2 页面结构

### Sections
1. AI Provider
   - DeepSeek selected
   - API Key field
   - Test connection button

2. Privacy
   - Local-first
   - What data is sent to LLM summaries

3. User Wiki
   - View files
   - Edit later / placeholder

4. App
   - Debug info
   - Version

---

## 13.3 Settings Stitch Prompt

```text
Design a Bevel-like light-mode iOS Settings screen for Vela, a local-first AI health app. It should look premium, clear, and privacy-conscious.

Include:
- Section: AI Provider
  - DeepSeek selected
  - Secure API Key input
  - Test connection button
- Section: Privacy
  - concise note that health data stays on-device except summarized context sent to the chosen LLM API
- Section: User Wiki
  - entry point to profile and behavior knowledge documents
- Section: App
  - app version and debug area

Use elegant list cards, clear hierarchy, subtle privacy emphasis, and a calm trust-building aesthetic.
```

---

# 14. 组件系统

请优先建立以下可复用组件：

## 14.1 Metric Cards
- ScoreCard
- TrendCard
- InsightCard
- CompactMetricTile

## 14.2 Visualization Components
- Score Ring
- Arc Progress
- Sparkline
- Sleep Timeline
- Trend Chart
- Energy Bar

## 14.3 AI Components
- Suggestion Chip
- Report Card
- Chat Bubble
- AI Summary Card

## 14.4 Journal Components
- Tag Pill
- Multi-select Chips
- Entry Card

---

# 15. 交互设计要求

## 15.1 可点击性
- 主卡片都应看起来可进入详情；
- AI 卡片 CTA 需清晰；
- Report 卡片应表现出“可展开”。

## 15.2 空状态
请额外生成或预留：
- Health permission not granted；
- No sleep data；
- No workout today；
- API Key missing。

---

# 16. 建议的 Stitch 生成顺序

1. Home Dashboard
2. Recovery
3. Sleep
4. Strain
5. Coach
6. Journal
7. Settings

理由：
- Home 是风格母版；
- Recovery / Sleep / Strain 决定核心健康 UI 语言；
- Coach 再适配同一设计系统。

---

# 17. 设计交付期望

每个页面建议输出：
- 完整页面设计；
- 关键卡片组件；
- 页面中的重要状态变体；
- 可导出的前端结构参考；
- 若 Stitch 支持，保留后续粘贴到 Figma 的良好层级。

---

# 18. 最终验收标准

设计方案应满足：

- [ ] 视觉明显高级，不像普通 Dashboard Demo；
- [ ] 首页一眼看懂 Recovery / Sleep / Strain / AI；
- [ ] 页面层次丰富，但不过度拥挤；
- [ ] 与 Apple + Claude 的气质一致；
- [ ] 参考 Bevel，但没有明显抄袭痕迹；
- [ ] 适合直接交给 SwiftUI 开发实现；
- [ ] 有一致的卡片、颜色、间距与图表系统。
