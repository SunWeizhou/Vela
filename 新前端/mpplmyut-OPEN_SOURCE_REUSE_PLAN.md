# OPEN_SOURCE_REUSE_PLAN.md
# Project Vela — Open Source Reuse Strategy

## 1. 原则

Vela 会积极利用 GitHub 上已有的开源资源，但不采用“随意拼接 Demo”的方式。

### 总原则
- B 为主：复用底层工具、组件、结构思路；
- C 谨慎：成熟开源 App 可以研究和局部吸收，但不盲目 fork；
- 每项复用必须审查：
  - License；
  - 维护状态；
  - 代码质量；
  - 架构契合度；
  - 是否会限制后续产品演进。

---

## 2. 第一批值得评估的开源项目

### 2.1 SleepChartKit

#### 用途
- Apple Health 睡眠阶段图；
- Sleep 页面核心 Timeline Chart；
- 可选圆环图。

#### 价值
- 直接解决最复杂的睡眠阶段可视化；
- 支持 HealthKit 睡眠样本；
- SwiftUI 原生；
- MIT License；
- 结构较清晰。

#### 推荐策略
**优先评估直接集成。**

---

### 2.2 Swift Health Dashboard

#### 用途
- 参考 HealthKit 查询封装；
- 参考 Dashboard Demo 结构；
- 参考 Charts 基础组合。

#### 价值
- 提供 steps、heart rate、sleep 可视化示例；
- 结构简单；
- MIT License。

#### 风险
- 更像 starter demo；
- 不建议作为项目骨架直接 fork。

#### 推荐策略
**仅参考，不直接依赖。**

---

## 3. 可能继续调研的开源方向

### 3.1 HealthKit Query Utilities
需要寻找：
- 统一 HealthKit async query 封装；
- 支持日期窗口聚合；
- 支持 workout sample 批处理。

### 3.2 Chart Components
需要寻找：
- 精致环形 Score Ring；
- Mini trend chart；
- Sparkline；
- Health card layout。

### 3.3 Markdown Rendering
需要寻找：
- SwiftUI Markdown renderer；
- 用于显示 AI Report。

### 3.4 Local File / Wiki Editing
后续需要：
- Markdown 文件读取；
- 编辑器；
- AI-assisted update。

### 3.5 LLM Provider SDK
因为 DeepSeek API 与 OpenAI / Anthropic 风格兼容，可评估是否使用轻量 SDK，或自己封装 HTTP Client。

---

## 4. 复用决策表

| 模块 | 候选 | 推荐策略 |
|---|---|---|
| Sleep Chart | SleepChartKit | 优先直接集成 |
| HealthKit Dashboard | Swift Health Dashboard | 参考 |
| Metrics Charts | 待调研 | 优先自研 + 局部复用 |
| Markdown Report UI | 待调研 | 可引库 |
| LLM HTTP Client | 自研或轻量 SDK | 第一版建议自研封装 |
| HealthKit Query Layer | 自研 | 因业务结构复杂 |

---

## 5. 为什么 HealthKit Query Layer 建议自研

Vela 不只是展示：
- 步数；
- 心率；
- 睡眠。

它还要做：
- Score Engine；
- Recovery；
- Strain；
- Stress；
- Energy Bank；
- Health Age Trend；
- AI Context Builder。

因此数据层最好从一开始就贴合 Vela 自己的领域模型，而不是被某个 Demo 项目的查询结构反向限制。

---

## 6. 复用审查清单

任何计划引入的开源项目，必须记录：

```md
### Repo
- Name:
- URL:
- License:
- Last update:
- Stars:
- Main purpose:

### Fit for Vela
- What problem does it solve?
- Direct use / reference / reject?
- Integration complexity:
- Long-term maintenance risk:
- Replacement plan:
```

---

## 7. 当前明确建议

### 直接评估集成
- SleepChartKit

### 仅供参考
- Swift Health Dashboard

### 后续待调研
- SwiftUI markdown 渲染；
- Score ring / mini chart；
- HealthKit async helpers；
- LLM API SDK。

---

## 8. 项目中的开源策略结论

Vela 不应该“从零写每一根螺丝”，但也不应该“把多个 Demo 拼起来”。

正确策略是：

> **核心领域逻辑自研：Health Domain、Scoring、Agent、App 架构。  
> 高价值非核心组件复用：睡眠图表、Markdown 渲染、局部 UI 组件。**
