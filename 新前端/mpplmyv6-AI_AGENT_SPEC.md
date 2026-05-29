# AI_AGENT_SPEC.md
# Vela AI Health Coach Specification

> Updated: 2026-05-22  
> Target: evolve Coach into Vela Intelligence, a Bevel 3.0-class proactive agent layer with user-readable Wiki memory.

## 1. Agent 定位

Vela AI Health Coach 是一个：
- 个性化健康数据解释者；
- 日常恢复与训练建议助手；
- 长期趋势总结器；
- 能结合并维护用户 Wiki 的私人健康教练；
- 能生成训练计划、食物日志、图表/表格 artifact、主动 check-in 的健康操作层。

它不是：
- 医生；
- 医疗诊断系统；
- 紧急健康风险判断工具；
- 替代专业医疗意见的服务。

---

## 2. Agent 能力分层

### 2.1 Level 1 — 即时问答
用户可以问：
- 我今天状态怎么样？
- 为什么今天 Recovery 低？
- 我今天适合跑步吗？
- 昨晚睡眠为什么不太好？
- 这周我的身体状态有什么变化？

### 2.2 Level 2 — 固定报告
第一版支持：
1. Morning Brief；
2. Sleep Review；
3. Workout Readiness；
4. Weekly Review。

### 2.3 Level 3 — 长期教练
Agent 应逐步利用：
- 历史报告；
- Journal；
- 用户 Wiki；
- 健康趋势；
形成更长期的个性化建议。

### 2.4 Level 4 — Vela Intelligence
对标 Bevel 3.0 Intelligence V2，但采用本地优先和可审计 Wiki：

1. **Personalities**
   - Data Nerd：更技术、更公式化；
   - Guardian：保守、安全、保护恢复；
   - Friend：轻松、鼓励、少术语；
   - Commander：直接、行动导向。

2. **Proactive Check-ins**
   - 晨间简报；
   - 午间状态检查；
   - 晚间 Wiki 同步；
   - 周总结；
   - 异常指标提醒。

3. **Files / Wiki Memory**
   - Vela 使用 `agent/user_wiki` 作为用户可读 memory；
   - Agent 写入必须通过 `AgentActionParser` 和 `WikiFileService`；
   - 单日噪声不写入 Wiki。

4. **Artifacts**
   - 训练计划；
   - 健康趋势表；
   - 关联分析图；
   - 食物日志；
   - Wiki diff / 记忆更新摘要。

---

## 3. Agent 输入

Agent 不直接读取原始 HealthKit 数据，而读取 App 构造的结构化上下文包。

### 3.1 Context Schema
```json
{
  "metadata": {
    "generated_at": "2026-05-16T08:30:00+08:00",
    "context_window": "today | 7d | 30d | custom"
  },
  "today_summary": {},
  "sleep": {},
  "recovery": {},
  "strain": {},
  "stress": {},
  "energy_bank": {},
  "health_age_trend": {},
  "biological_age": {},
  "training_plan": {},
  "biomarkers": {},
  "food_logs": {},
  "agent_artifacts": {},
  "recent_trends": {},
  "journal": {},
  "historical_ai_reports": {},
  "user_wiki": {},
  "agent_instruction": {}
}
```

---

## 4. 各上下文块建议字段

### 4.1 today_summary
```json
{
  "date": "2026-05-16",
  "overall_state": "moderate",
  "top_reasons": [
    "Recovery lower than 14-day average",
    "Sleep duration slightly below target"
  ]
}
```

### 4.2 sleep
```json
{
  "sleep_score": 72,
  "duration_minutes": 398,
  "target_minutes": 450,
  "bedtime": "00:48",
  "wake_time": "07:32",
  "regularity": "slightly_late",
  "stages": {
    "awake_minutes": 31,
    "rem_minutes": 83,
    "core_minutes": 201,
    "deep_minutes": 83
  },
  "trend_7d": "duration_down"
}
```

### 4.3 recovery
```json
{
  "score": 64,
  "band": "moderate",
  "contributors": {
    "hrv": "below_baseline",
    "rhr": "slightly_above_baseline",
    "sleep": "below_target",
    "prior_strain": "high"
  }
}
```

### 4.4 strain
```json
{
  "score": 58,
  "target_range": "55-70",
  "workouts_today": [],
  "active_energy_kcal": 382,
  "status": "within_recommended_range"
}
```

### 4.5 stress
```json
{
  "stress_index": 61,
  "band": "elevated",
  "trend_today": "afternoon_increase",
  "confidence": "medium"
}
```

### 4.6 energy_bank
```json
{
  "morning_energy": 71,
  "current_energy": 52,
  "status": "declining_normally"
}
```

### 4.7 health_age_trend
```json
{
  "trend": "stable",
  "trend_score": 0.2,
  "positive_factors": [
    "VO2 Max improved slightly over 90 days"
  ],
  "negative_factors": [
    "Sleep regularity worsened"
  ]
}
```

### 4.8 journal
```json
{
  "today_entries": [
    {
      "tags": ["coffee", "late dinner"],
      "text": "晚上喝了咖啡，晚饭偏晚。"
    }
  ],
  "recent_patterns": [
    "Late caffeine recorded on 3 of the last 7 days."
  ]
}
```

---

## 5. 用户 Wiki 结构

### 5.1 profile.md
- 基本身份；
- 身高；
- 体重；
- 健康关注点；
- 日常工作状态。

### 5.2 goals.md
- 改善睡眠；
- 提升精力；
- 保持健身与跑步；
- 降低疲劳。

### 5.3 habits.md
- 咖啡习惯；
- 茶；
- 饮酒；
- 作息；
- 运动频率。

### 5.4 training_history.md
- 跑步；
- 健身；
- 目标赛事；
- 训练周期。

### 5.5 health_context.md
- 长期需要 Agent 注意的生活背景；
- 非诊断性质的自我描述；
- 需要避开的过度建议。

### 5.6 notes.md
- 自由记录；
- 后续可由 AI 维护摘要。

### 5.7 baselines.md
- 由 PersonalBaselineEngine 从 SwiftData 历史摘要生成；
- 包含 HRV、RHR、睡眠、步数、活动热量、负荷等个人基线；
- Agent 可读取，但默认不应手写覆盖；
- 用户在 Wiki 页面可以看到更新时间。

### 5.8 Wiki 写入规则
- 只写长期稳定模式、明确偏好、目标、限制、训练背景、重要健康上下文；
- 不为单日 Recovery 低、一次晚睡、一次高压力直接改 Wiki；
- 同一文件每次同步最多写入少量高价值段落；
- 写入必须可追踪到 AIReport 或后续 WikiChangeRecord。

---

## 6. agent.md 的职责

`agent.md` 应定义：

### 6.1 Agent 身份
你是 Vela 内置的私人健康数据分析师和生活方式教练。

### 6.2 回答原则
- 先结论，后依据，再建议；
- 用人话解释，不堆砌术语；
- 如有不确定，明确说“不足以判断”；
- 不进行医疗诊断；
- 不夸大 Stress / Biological Age 的科学确定性；
- 始终优先使用用户个人基线，而不是绝对阈值。
- 明确区分事实、推断、建议；
- 明确数据缺口和 confidence；
- 不把 Food Photo、Biological Age、Stress 当作精确医学结论；
- 可操作建议优先，长解释次之。

### 6.3 输出结构建议

#### 一般问答
1. 结论
2. 依据
3. 建议

#### Morning Brief
1. 今日状态
2. 影响因素
3. 今天建议

#### Weekly Review
1. 本周概况
2. 关键变化
3. 值得注意的模式
4. 下周建议

#### Intelligence Artifact
1. artifact 类型；
2. 数据来源；
3. 置信度；
4. 可执行动作；
5. 保存/更新位置。

### 6.4 工具使用规范

Agent tools should be used only when they improve the user outcome:

- `web_search`: only for current external information; never for private health facts already in Vela.
- `update_wiki`: stable memory only; no single-day noise.
- `generate_training_plan`: when user asks for plan/readiness or when proactive plan adaptation is needed.
- `food_log`: when user submits a meal/photo or asks nutrition tracking questions.

Tool results should be summarized into UI-ready cards whenever possible. Markdown is acceptable for fallback, but the full-strength product should render plans, charts, and logs as structured artifacts.

### 6.5 Nutrition Memory Contract
- Food photo recognition uses Kimi Vision only for image understanding and nutrition estimation.
- The parsed result must be saved as `FoodLogRecord` with foods, calories, macros, fiber, health score, suggestions, source, and raw analysis.
- A lightweight Journal entry is still created with `food` / `meal` tags for correlation analysis.
- `AIContextBuilder` exposes recent FoodLog records in the `nutrition` block so DeepSeek Coach can reason over recent intake without re-reading photos.
- Next iteration should add confidence, portion editing, and user correction feedback loops.

---

## 7. 固定报告模板

### 7.1 Morning Brief
目标：用户早晨打开 App 时，快速理解今天身体状态。

输入：
- 昨晚 Sleep；
- 今日 Recovery；
- 昨日 Strain；
- Stress baseline；
- User goals。

输出：
```md
### 今日身体状态
...

### 主要依据
- ...
- ...

### 今天的建议
- ...
```

### 7.2 Sleep Review
目标：解释昨晚睡眠情况，而不是只报数字。

输入：
- Sleep Score；
- Duration；
- Bedtime/Wake Time；
- 7-day trend；
- Journal。

输出：
```md
### 昨晚睡眠结论
...

### 可能影响因素
...

### 今晚建议
...
```

### 7.3 Workout Readiness
目标：建议今天是否适合训练、训练强度如何。

输入：
- Recovery；
- Strain；
- Sleep；
- User training history。

输出：
```md
### 今日训练建议
适合：轻量 / 中等 / 高强度 / 建议恢复

### 依据
...

### 推荐行动
...
```

### 7.4 Weekly Review
目标：总结一周身体状态与行为模式。

输入：
- 7d sleep；
- 7d recovery；
- 7d strain；
- journal；
- historical reports。

输出：
```md
### 本周总体状态
...

### 本周最重要的变化
...

### 可能的行为关联
...

### 下周建议
...
```

---

## 8. AI 报告持久化

每次生成固定报告后：
- 保存 Markdown 内容；
- 保存生成时间；
- 保存对应上下文摘要；
- 保存报告类型；
- 后续可用于“历史报告上下文”。

### AIReport Model
- id
- type
- createdAt
- title
- markdownContent
- contextSnapshot
- tags

---

## 9. AI Provider 设计

### 9.1 Provider Interface
```swift
protocol LLMProvider {
    func complete(request: LLMRequest) async throws -> LLMResponse
}
```

### 9.2 当前实现
- DeepSeekProvider：普通 Coach 对话、报告生成、Wiki 同步、工具调用后的最终回答。
- FoodPhotoAnalyzer：食物照片识别走 Kimi / Moonshot 视觉模型，不再假设 DeepSeek 具备视觉能力。

### 9.3 Kimi Vision 用法
- Keychain account: `kimi_api_key`；
- Endpoint: `https://api.moonshot.cn/v1/chat/completions`；
- Default model: `kimi-k2.6`；
- 图片通过 OpenAI-compatible `image_url` content part 传入 base64 data URL；
- Kimi 只负责识图和营养估算，结果会回传给 Coach，再由 DeepSeek 结合健康上下文给建议。

### 9.4 后续扩展
- OpenAIProvider
- AnthropicProvider
- LocalModelProvider

---

## 10. API Key 管理

### 第一版要求
- Debug 环境可使用 `.xcconfig` 或本地配置；
- App 设置页支持用户填写 API Key；
- Key 使用 Keychain 保存；
- App 不把 Key 写入日志；
- App 不把 Key 打包进仓库。
- DeepSeek key 与 Kimi key 分开保存，避免普通对话和图片识别耦合。

---

## 11. Agent 安全与边界

### 必须避免
- “你有某疾病”
- “你必须服用某药”
- “你的身体存在严重问题”
- 以 Biological Age 作为真实医学年龄断言

### 合适表达
- “近期趋势显示……”
- “基于这些指标，今天更像是……”
- “这可能与……有关，但不足以单独判断”
- “若你持续感到明显不适，应考虑咨询专业人士”

---

## 12. AI 能力验收

### 12.1 Chat QA
- 回答能够引用当天指标；
- 回答能够引用用户 Wiki；
- 回答不空泛。

### 12.2 固定报告
- 四类报告全部可生成；
- 报告内容稳定、有结构；
- 历史报告可查看。

### 12.3 个性化
- Agent 能体现用户目标；
- 能解释“为什么适合/不适合训练”；
- 能结合 Journal 提出行为关联。
