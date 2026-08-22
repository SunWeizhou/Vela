# Architecture Decision Records (ADRs)

> Status: Canonical
> Last verified: 2026-08-21
> Scope: Vela 核心架构决策记录索引、状态与演进关系

---

## 决策索引清单

| 编号 | 标题 | 状态 | 核心决策摘要 |
| :--- | :--- | :--- | :--- |
| [0001](0001-single-daily-health-computation.md) | Single Daily Health Computation | Accepted | 前台刷新、后台同步与历史回填共用同一个单一、确定性的每日评分计算入口。 |
| [0002](0002-canonical-agent-fact-snapshot.md) | Canonical Agent Fact Snapshot | Accepted | 所有 AI 提示词与工具调用基于确定性、无时区偏差的 Agent Fact Snapshot，排除生成时间噪声。 |
| [0003](0003-independent-scored-health-evidence.md) | Independent Scored Health Evidence | Accepted | 恢复、睡眠、负荷、压力、能量等 5 大评分独立存在，不合并为单一虚假“总健康分”。 |
| [0004](0004-external-in-session-training-execution.md) | External In-Session Training Execution | Accepted | 训练执行与实时心率监控完全由 Apple Watch 承担；iPhone 端不要求用户在训练中手动记组或操作计时器。 |
| [0005](0005-prioritize-health-rhythm-over-compensation.md) | Prioritize Health Rhythm Over Compensation | Accepted | 优先恢复可持续的生活节律；严禁用惩罚性有氧或极端节食来“代偿”过量进食。 |
| [0006](0006-behavior-first-eating-context.md) | Behavior-First Eating Context | Accepted | 饮食记录按行为节律与进食模式理解，不以强制热量/宏量营养素记账为前置条件。 |
| [0007](0007-cross-domain-daily-operating-plan.md) | Cross-Domain Daily Operating Plan | Accepted | 每日行动计划跨域但有界：1 个主行动 + 最多 2 个辅助行动，不做泛日程管理器。 |
| [0008](0008-ai-proposes-user-confirms-plan-changes.md) | AI Proposes, User Confirms Plan Changes | Accepted | 本地确定性规则生成正式计划；AI 只能生成候选 Proposal，重要修改必须经用户显式确认。 |
| [0009](0009-single-user-daily-driver-before-generalization.md) | Single-User Daily Driver Before Generalization | Accepted | 当前阶段优先为产品作者本人的真实数据（~1100 天 Apple 健康数据）与真实习惯打造高可信 Daily Driver 闭环。 |
| [0010](0010-personal-health-brief-as-canonical-product-projection.md) | PersonalHealthBrief as Canonical Product Projection | Accepted | `PersonalHealthBrief` 作为全局权威认知投影对象；训练决策作为下游衍生；确立 `Today / Trends / Vela / Training` 四大工作区。 |
| [0011](0011-daily-intelligence-assembly-module.md) | Shared Daily Intelligence Assembly Module | Accepted | 两个日常 Adapter 跨同一 Seam；确定性 Module 统一 Body State → Personal Health Brief → Training Decision，并显式注入时间语义。 |
