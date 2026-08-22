# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela 2.0 产品需求文档 PRD

## 一句话定位
Vela 每天帮用户读懂 iPhone 和 Apple Watch 采集到的身体数据，判断今天的疲劳与准备度，给出可执行的训练/恢复建议，并长期记住什么对用户有效。

## 核心问题
Apple Health / Fitness 保存了大量身体数据，但普通用户只能理解心率、热量、睡眠时长、步数等基础指标。Vela 2.0 要建立身体状态解释层，把多维 HealthKit 数据转化为今日判断、原因解释、行动建议与长期记忆。

## 产品主线
Morning Brief → Today Plan → Adaptive Training → Evening Review → Memory Inbox。

## 核心功能
1. Today Plan Hero：首页顶部直接告诉用户今天身体怎么样、为什么、该做什么。
2. Body Interpreter：把恢复、睡眠、负荷、能量、压力、步态、环境、身体组成等指标转译成身体状态。
3. Why This：每个建议都可展开解释依据。
4. Coach Command Center：Coach 从聊天入口升级为任务指挥中心。
5. Memory Inbox：AI 发现的长期记忆必须经用户确认。
6. Adaptive Training：训练计划根据今日恢复与负荷动态调整。
7. Morning Brief：早晨自动生成今日简报。
8. Evening Review：晚上复盘完成度、身体反应、明日建议，并生成记忆提议。
9. Baseline Building：新手期展示个人模型校准进度。
10. Trust & Safety：不做医疗诊断，所有 agent 行为可控可见。

## Vela 2.0 MVP
必须包含：Today Plan Hero、Why This、Memory Inbox、Adapt Today、Morning Brief。

## 成功体验
早上打开：知道今天身体怎么样。训练前打开：知道该不该练、练多重。晚上打开：知道今天发生了什么，Vela 学到了什么。几周后：感觉 Vela 越来越懂自己。
