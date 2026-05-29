# Vela 2.0 Implementation Plan

## 总指令
不要继续堆新页面或新指标。Vela 2.0 的目标是把 HealthKit 数据、AI Coach、Wiki Memory 和 Training Plan 串成每日行动闭环。

## Milestones
- M0 Build Stabilization：构建、pbxproj、schema、测试。
- M1 Daily Plan Domain Layer：TodayPlan、TodayState、DailyAction、WhyThisItem、DailyPlanBuilder。
- M2 Today Plan Hero：首页第一屏展示今日状态与行动建议。
- M3 Why This Explanation Layer：所有建议都能解释。
- M4 Memory Inbox Productization：待确认记忆成为核心入口。
- M5 Adaptive Training：训练计划支持 keep/reduce/swap/rest。
- M6 Coach Command Center：Coach 初始页升级为任务中心。
- M7 Morning Brief + Evening Review：早晚仪式化复盘。
- M8 Baseline Building + Trust Center：校准进度、agent run history、配置。
- M9 QA, Polish, Release：测试、文案、fallback、性能。

## Definition of Done
构建通过；无数据缺失崩溃；AI 长期记忆必须进入 MemoryProposal；所有建议必须有 WhyThisItem；训练调整不破坏原计划；不做医疗诊断。

## Coding Agent Prompt
你正在实现 Vela 2.0。请围绕 Daily Loop 实施：Today Plan Hero、Why This、Memory Inbox、Adaptive Training、Morning/Evening Review。每次改动都要运行构建和测试，给出变更摘要和风险。
