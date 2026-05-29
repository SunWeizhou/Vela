# Vela — Handoff Document

## 项目概述

Vela 是一个 local-first 的 iOS 健康分析 App（SwiftUI + SwiftData + HealthKit），对标 Bevel Health。数据留在设备本地，只有结构化摘要发送给 DeepSeek LLM。

2026-05-22 更新：Vela 当前构建已进入 Bevel 3.0-class 打磨阶段，不再只是 MVP。最新产品研究和框架文档：

- `docs/BEVEL_3_RESEARCH.md` — Bevel 3.0 官网/App Store/论坛/真机观察调研。
- `docs/VELA_FULL_STRENGTH_PRODUCT_BLUEPRINT.md` — Vela 满血版产品、设计、工程、AI、路线图。
- `docs/GAP_ANALYSIS.md` — 当前 Vela vs Bevel 3.0 的体验差距。

- **Target**: `Vela`
- **Scheme**: `Vela`  
- **Bundle ID**: `com.sunweizhou.Vela`
- **Deployment**: iPhone (connected via cable/network)
- **Project 路径**: `/Users/sunweizhou/Desktop/AI Project/Vela/Vela.xcodeproj`

## 构建与推送

```bash
# 1. 构建（Debug，目标 iPhone）
cd "/Users/sunweizhou/Desktop/AI Project/Vela"
DEVICE="00008140-00164DE022C3801C"
xcodebuild -project Vela.xcodeproj -scheme Vela -destination "id=$DEVICE" -configuration Debug -allowProvisioningUpdates build

# 2. 推送到手机（用 devicectl，xcodebuild install 不会真正装到设备）
xcrun devicectl device install app --device "$DEVICE" \
  "/Users/sunweizhou/Library/Developer/Xcode/DerivedData/Vela-ggnamhqobqcizngochzqdybdclxf/Build/Products/Debug-iphoneos/Vela.app"
```

注意：`build` 只需要在首次或依赖变化后执行，`install` 会重用已有构建产物推送到手机。如果只改了 Swift 代码，可以直接 `install`。

## 项目结构

```
VelaApp/
├── App/                    # App 入口
│   ├── VelaApp.swift       # @main
│   └── AppCoordinator.swift
├── AI/                     # AI 层
│   ├── Context/            # AIContextBuilder — 构建 LLM 上下文
│   ├── Models/             # AgentContextEnvelope, AIReportType
│   ├── Proactive/          # EveningWikiSyncAgent, MorningBriefScheduler, AgentSkillsConfig
│   ├── Actions/            # AgentActionParser — 解析 [ACTION:update_wiki]
│   ├── Provider/           # DeepSeekProvider — LLM 调用
│   ├── Reports/            # ReportGenerator — 自动报告生成
│   ├── Prompting/          # Wiki 相关服务
│   └── Logs/               # DailyLogService
├── Features/               # UI 层
│   ├── Home/               # 主仪表盘
│   ├── Coach/              # AI 聊天面板
│   ├── Settings/           # 设置页
│   ├── Sleep/              # 睡眠分析
│   ├── Strain/             # 负荷分析
│   ├── Recovery/           # 恢复分析
│   └── SharedComponents/   # MarkdownText, VelaTheme 等
├── Health/                 # HealthKit 数据层
│   ├── Services/           # HealthKitQueryService, HealthDataRefreshService
│   ├── Authorization/      # HealthAuthorizationService
│   ├── Models/             # Data models (WorkoutSummary, SleepSummary 等)
│   ├── Mapping/            # SleepStage mapper
│   └── Queries/            # 查询相关
├── Scoring/                # 评分引擎
│   ├── Sleep/              # SleepScoreEngine
│   ├── Recovery/           # RecoveryScoreEngine
│   ├── Strain/             # StrainScoreEngine
│   ├── Stress/             # StressIndexEngine
│   ├── EnergyBank/         # EnergyBankEngine (TRIMP ATL/CTL/TSB)
│   └── HealthAge/          # HealthAgeTrendEngine
├── Journal/                # 日记子系统
├── Persistence/            # SwiftData 持久化
│   ├── SwiftDataModels/    # CoreData 模型
│   └── Repositories/       # 仓库层
├── Core/                   # 跨模块共享
│   ├── Theme/              # VelaTheme
│   ├── Utilities/          # DashboardSummary, ScoringMath
│   ├── Constants/          # 常量
│   └── Extensions/         # Swift 扩展
└── Resources/              # Assets.xcassets
```

## 数据流架构

HealthKit → HealthKitQueryService → (sleep/recovery/strain/extended/body metrics)
                                   → DailyHealthContext (中间模型)
                                   → DashboardSummary.healthKit() (评分计算)
                                   → AIContextBuilder.build() (→ AgentContextEnvelope)
                                   → LLM Prompt (覆盖 40+ 项指标 + 用户 Wiki)

### 关键数据痛点（已知）

- **Workout 数据已在 AgentContextEnvelope 中包含 workouts 字段**（2026-05-21 修复），包含运动类型、时长、心率、热量、距离
- **ExtendedMetrics 包含 30+ 项细粒度指标**（年龄、性别、血压、血糖、步态、营养等）
- **年龄/性别已在 system prompt 中明确告知 LLM**，基于人口统计学参考值进行分析
- **持久化层只存评分，不存原始指标** — 历史趋势分析受限

## 已完成的特性

- [x] Coach AI 聊天（DeepSeek streaming，含 casual intent detection 防过度回复）
- [x] Coach personalities（Data Nerd / Guardian / Friend / Commander）
- [x] Markdown 渲染（行级 AttributedString 解析，streaming 时不闪）
- [x] 30+ 项 HealthKit 数据读取（睡眠、恢复、负荷、步态、营养、心血管等）
- [x] 睡眠评分引擎（含 REM/Deep/Core 阶段分析和效率计算）
- [x] 恢复评分引擎（HRV Z-score 28-day rolling + RHR 基线对比）
- [x] 负荷评分引擎（TRIMP-inspired + workout intensity load）
- [x] 压力指数（4 因子模型：RHR 抬升、HRV 抑制、睡眠负债、负荷压力）
- [x] 能量银行（Firstbeat charge/discharge + Banister ATL/CTL/TSB）
- [x] 健康年龄趋势
- [x] Energy Bank 引擎增强（HRV/RHR charge efficiency、ATL 7天/CTL 42天指数衰减）
- [x] 用户 Wiki 系统（form-based UI 编辑，非原生 Markdown）
- [x] Personal Baselines 写入 Wiki `baselines.md`
- [x] 夜间 Wiki 同步 Agent（每晚 23:00 自动总结当日数据 → 更新 Wiki）
- [x] 晨间简报 Agent（6:00-11:00 自动生成晨间报告）
- [x] Agent Skills 配置 UI（Settings 页开关 + 时间偏好）
- [x] TrainingView / TrainingCalendarView 初版
- [x] BiologyView / BiologicalAgeEngine / manual biomarker entry 初版
- [x] FoodPhotoAnalyzer 与 food logging tool 初版
- [x] WebSearchService 与 web_search tool 初版
- [x] Coach 侧边栏安全区域适配修复
- [x] Streaming 节流（60ms debounce 防闪烁）
- [x] Workout 数据进入 AI 上下文（2026-05-21）

## 内存系统

项目持久记忆存储在：
`/Users/sunweizhou/.claude/projects/-Users-sunweizhou-Desktop-AI-Project/memory/`

索引文件：`MEMORY.md` — 新对话会自动加载。如需回顾上次会话完整日志：
`/Users/sunweizhou/.claude/projects/-Users-sunweizhou-Desktop-AI-Project-Vela/02c5d742-5732-4c7f-8ff4-e626afd42899.jsonl`

## 待办/开放问题

- [ ] **HRV 历史查询优化** — 当前使用大量 raw HKQuantitySamples，可考虑改用 HKStatisticsCollectionQuery 减少查询次数
- [ ] **TRIMP 算法需要真实 workout HR 数据** — 当前 ATL/CTL 基于 strain 评分计算，未直接接入 workout HR zone minutes
- [ ] **BGAppRefreshTask 后台刷新** — EveningWikiSyncAgent 的 `scheduleBackgroundRefresh()` 仍是空实现
- [ ] **DeepSeek 回复仍然有时过长** — casual intent detection 已缓解，但仍有改进空间
- [x] **Coach 网络搜索能力初版** — WebSearchService 与 web_search tool 已存在；下一步需要接入更清晰的 UI/权限/引用展示。
- [ ] **Coach streaming 仍有闪烁** — memory 有记录，60ms throttle 已缓解但未根除
- [ ] **Coach 回复缺少换行** — line-by-line AttributedString 已解决，但 streaming 过程中换行仍可能丢失
- [x] **Persistence 层已扩展原始指标** — DailyHealthSummaryRecord 已包含 HRV/RHR/sleep/steps/body metrics 等；下一步是补齐 FoodLogRecord、AgentArtifactRecord、HealthRecordDocument。

## 2026-05-22 新优先级

- [ ] **Coach → Intelligence Workspace** — 把聊天、Wiki、Check-ins、Artifacts、Tools 合并成一个主动健康工作台。
- [ ] **Home 首屏再收敛** — 10 秒内回答状态、原因、今日行动、数据置信度。
- [ ] **Training Plan 结构化** — AI 生成的训练计划必须进入日历和训练卡，不停留在 markdown。
- [ ] **Biology 可信化** — Biological Age 增加 freshness/confidence/missing data。
- [ ] **Nutrition 结构化** — 食物照片识别后支持编辑份量、宏量、置信度并保存。
- [ ] **真机体验打磨** — 底部 safe area、长文本、空状态、通知、后台任务。
