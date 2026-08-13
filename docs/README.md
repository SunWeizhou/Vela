# Vela Documentation

This directory is the source of truth for product, architecture, scoring, AI, reuse, and design decisions.

## Current build direction (2026-08-13)

Vela 进入 **Personal Edition 阶段**：只为产品作者本人服务的主动式健康调节教练。28 天 Daily Driver 验证期的北极星是 `Trusted Decision Day`；Daily Operating Plan 跨域但有界（一个主行动 + 最多两个支持行动）；AI 提议计划变更、用户显式确认；Health Rhythm 优先，不处方代偿行为。Bevel parity 已冻结，仅保留为内部视觉回归开关。

**方向以以下文档为准**（均为 2026-08-13 更新）：

- `VELA_PERSONAL_PRODUCT_DIRECTION.md` — 产品方向总纲（定位、北极星、四个工作区、视觉方向、部署优先级）。
- `../CONTEXT.md` — 领域语言规范（Primary User、Trusted Decision Day、Health Rhythm、Eating Rhythm、Lived State、Plan Proposal 等）。
- `adr/0004-0009` — 方向性决策：训练执行留在 Apple Watch（0004）、Health Rhythm 优先于代偿（0005）、饮食行为优先（0006）、跨域 Daily Operating Plan（0007）、AI 提议用户确认（0008）、单用户优先（0009）。

## 当前文档

- `PRD.md` — 产品需求文档（历史主线，2026-08-13 起以 Personal Edition 方向为准）。
- `TECH_ARCHITECTURE.md` — 技术架构（模块、数据流、评分引擎、AI Agent）。
- `AI_AGENT_SPEC.md` — AI Agent / Coach / Wiki 记忆系统规格。
- `SCORING_SYSTEM_V1_0.md` — 评分系统 V1.0 规格。
- `VELA_TRAINING_INTELLIGENCE_V3.md` — Training Intelligence v3 模块设计。
- `VELA_DESIGN_LANGUAGE.md` — 视觉设计语言（Rhythm：暖灰绿画布 + 节律绿）。
- `STITCH_DESIGN_BRIEF.md` — Stitch 设计参考简报（历史）。
- `agents/` — Agent 工作流文档（issue-tracker / triage-labels / domain）。
- `validation/` — 视觉验证与 rhythm-horizon 素材。

## 已冻结 / 历史文档

Bevel parity 阶段文档已冻结，仅作历史参考，不作为方向依据：

- `BEVEL_3_1_4_PARITY_EXECUTION_PLAN_2026-07-31.md` — Bevel 3.1.4 parity 执行计划（已停止）。
- `BEVEL_PARITY_GAP_TRACKER.md` — Bevel parity 差距追踪（已冻结）。
- `FRONTEND_FREEZE_AND_BACKEND_ALIGNMENT.md` — 前端冻结与后端对齐（已过时）。
- `VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md` — Bevel 3.0 级产品蓝图（已由 Personal Edition 方向取代）。
- `VELA_3_AUDIT.md` / `VELA_4_STABILIZATION_REPORT.md` / `VELA_UI_AUDIT.md` — 历史审计与稳定化报告。
- `archive/` — Vela 2.0 时代文档。
- `reference/bevel-3.1.4` — Bevel 参考素材。
