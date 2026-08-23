# Vela 工程标准审计报告（对标行业基线）

> Status: Audit
> Date: 2026-08-23
> Scope: 对 Vela 仓库（iOS App + Watch stub + Vapor backend）做面向"大厂软件工程标准"的差距审计
> Method: 8 领域并行深潜（代理审计 + 人工取证交叉验证），关键高风险发现由人工逐条复核代码
> 结论性质：个人 Daily Driver 项目的自我基准对照，非发布评审；严重度分级用于排优先级，不构成合规结论

---

## 0. 仓库基线数字

| 维度 | 现状 |
| :--- | :--- |
| 生产代码 | VelaApp 194 文件 / 87,091 LOC（SwiftUI + SwiftData + HealthKit, Swift 6, iOS 17+） |
| 测试 | VelaAppTests 15 文件 / 12,705 LOC / ~456 个 test func（纯单测，无 UI 测试 target） |
| 旁路资产 | VelaWatch 1 文件（未入 scheme）；VelaBackend Vapor 29 文件 2,330 LOC（实验未启用） |
| CI | GitHub Actions 单 workflow：构建（警告即错误）+ iOS 单测 + backend `swift test`；无 lint/coverage/release |
| 文档 | CLAUDE.md / CONTEXT.md（领域语言）/ PRD / TECH_ARCHITECTURE / ADR 0001–0010 / 设计语言 — 结构完整度接近大厂 |
| Git | 150 commits，`feat:/fix:/perf:` 约定；main + feature 分支；无 README/CHANGELOG |
| 本地化 | 自研 L10n（UserDefaults 标志 + 中英双语），Apple 本地化基础设施未启用 |
| 工具链 | SwiftLint 配置存在但**未安装未接线**；SwiftFormat 无；无 xcconfig；Xcode 版本仅 CI 硬编码 |

**总体判断：Vela 的缺口不在"架构与代码能力"，而在"工程脚手架"——文档/领域建模/测试体量已达中上水准，但 CI 门禁、可观测性、本地化、可访问性验证、发布链路这几件"大厂默认具备"的周边工程几乎为零。** 同时存在 1 个会损坏用户数据的真实风险（SwiftData schema 版本管理）和 1 个严重的 HealthKit 错误吞没问题。

---

## 1. 分维度评级

| 维度 | 评级 | 一句话 |
| :--- | :--- | :--- |
| 架构与模块化 | B+ | 分层与 seam 意识强，但 11 个 >1300 行巨型文件 + 依赖注入散乱 |
| 测试质量 | B | 456 个测试、seam 纪律良好；缺 UI/集成/迁移层，无覆盖率门禁 |
| CI/CD 与交付 | C | 最小可用流水线；无 lint/coverage 门禁、无发布链路、工具链未锁定 |
| 静态代码质量 | C+ | SwiftLint 全配置但零执行；1080 处固定字号、543 处内联圆角无人看管 |
| 可靠性/可观测 | C | SwiftData 迁移有结构性风险；HealthKit 错误被吞；无崩溃上报、日志稀疏 |
| 安全与隐私 | B+ | Keychain/ATS/隐私清单/红线合规做得好；数据删除有盲区 |
| 性能与并发 | B | 并发纪律好（DTO 边界、单飞去重）；主线程全表 fetch 与流式重解析是主要拖累 |
| 可访问性/国际化 | C- | 动效无障碍是大厂水准；i18n 近乎重建，Dynamic Type 1080 处缺失 |

---

## 2. 必须优先处理的发现（Critical / High，已人工复核）

### 🔴 C1. SwiftData Schema 版本管理存在数据丢失路径（reliability-0，已复核）
- **证据**：`VelaApp/Persistence/SwiftDataModels/VelaModelContainer.swift` — `VelaSchemaV3.models` 直接返回 `VelaModelContainer.modelTypes`（可变 live 类型）；V3 建立后（b3577992）,PersistenceModels 新增了 `rotationFocuses`/`nextRotationFocus`/`linkedStrengthWorkoutId` 三个字段，`versionIdentifier` 仍是 `(3,0,0)`。
- **风险**：V2 注释自己明确警告过该反模式（"Versioned schemas must never point at the mutable current model type…"）。模型图变化而版本号不变 → 存量设备打开 store 时模型哈希不匹配 → `ModelContainer` 创建失败 → 触发 VelaApp.swift:286-297 的兜底路径：只读安全模式 + `isFallbackStore` + 空内存容器 → 用户 1100 天健康历史在界面上"消失"（数据本机仍在，但界面不可见且进入只读态）。
- **建议**：新建 `VelaSchemaV4` 冻结模型图、每次字段变更递增版本；为 V1/V2/V3 全体模型建 frozen 副本；CI 加"版本号不变但模型字段变化"检查；补升级冒烟测试。**这是当前唯一可能造成真实数据事故的问题，建议本周内处理。**

### 🔴 C2. HealthKit 查询错误被静默当作"无数据"（reliability-1，已复核）
- **证据**：`HealthKitSyncEngine.swift:346-352` 对 sleep/recovery/strain/body 4 路查询全部 `try?`；`HealthKitQueryService.swift:458/506` 用魔法数字把 `code == 4`（授权被拒）/`code == 3`（参数错误）当空数组返回，与该文件自己声明的"只认 errorNoData"策略矛盾；`HealthKitSyncEngine.swift:271-286` 即使 `failedDayIdentifiers` 非空也无条件写 `lastSuccessfulSyncAt = endDate`。
- **风险**：权限被撤销/数据库异常被静默当作"当日无数据"→ 快照以全 nil 持久化、UI 显示 `--`、且后续同步误认为数据新鲜。产品红线"缺失数据客观表达"与"禁止伪造"被实现细节破坏，且完全不可诊断。
- **建议**：区分"无数据"与"查询失败"（失败注入诊断信号/事件记录）；授权错误置 revoked 并在 DataCoverageView 提示；删除魔法数字，统一走 `isBenignHealthKitDataError`；`lastSuccessfulSyncAt` 仅在无失败日时推进。

### 🔴 C3. 本地化基础设施缺失（a11y_i18n-0，已复核）
- **证据**：`Localizable.strings`（zh-Hans）不在任何 target 的 build phase（pbxproj 0 引用）、代码 0 引用；`knownRegions` 只有 `en, Base`；自研 `L10n.t(english, chinese)` + `AppLanguage.stored`（UserDefaults）仅覆盖 27/194 个文件；主视图（Trends/Hero/Vitals/Fitness）在"英文模式"下仍是全中文。
- **风险**：系统语言切换无效；无法接 Xcode 本地化工作流/翻译服务；英文用户看到中英混杂。
- **建议**：迁移 `.xcstrings` String Catalog（英文为 source、中文为 zh-Hans 翻译），删掉死代码 `VelaLoc`（引用 0）与孤儿 `Localizable.strings`，`L10n.t` 作过渡层。

### 🟠 H1. 全库 1080 处固定字号，Dynamic Type 不生效（a11y_i18n-1，已复核计数）
`grep .system(size:` = **1080** 处、`relativeTo` 版本 0 处、`@ScaledMetric` 0 处。`VelaTheme` 字体工厂（monoCaption 12 / metricHeroValue 48 / displayValue 60 等）全部无 `relativeTo:`。旗舰数字在用户放大字号时不变，与设计语言文档"完整支持 Dynamic Type 大号字阶"门禁直接冲突。建议统一 `relativeTo:` + `@ScaledMetric`。

### 🟠 H2. 关键 SwiftData 查询为全表扫描 + 主线程重计算（perf_concurrency，已复核机制）
- `HealthSnapshotRepository.fetchSnapshots` 无谓词 fetch 全表再内存过滤（`HealthSnapshotRepository.swift:92-112`，注释解释是规避一只异常行导致的 SIGTRAP——**工作区可见，但代价是每个调用方都 O(全表)**，调用方包括 `days: 1100` 的 BodyModel 建模与同步引擎 Pass2 逐日循环）；
- 冷启动路径 `loadCachedDashboard` 与完整刷新各跑一遍 4–6 张全表 fetch + BodyModelBuilder 全量建模（`DailySummaryUseCase.swift`、`DashboardViewModel.swift:164`）；
- 全库无任何 SwiftData 显式索引（仅 38 处 `.unique`/`.externalStorage`，0 处 `.index`）；
- Coach 每条消息上下文组装 8+ 次 fetch（含全表）+ 主线程相关性/解释引擎计算；
- 流式气泡 `MarkdownText` 每 0.5s + 每 chunk 对全文重解析 markdown（`MarkdownText.swift:10-24`，已复核）。
- **建议顺序**：① 谓词+索引（本机数据量尚小，收益立竿见影）；② 纯计算移入 `Task.detached`（`SecondaryDataAssembler` 已有现成样板）；③ 流式增量解析。

### 🟠 H3. 后台任务几乎必然超预算（perf_concurrency-6，已复核）
`BackgroundTaskManager.handleRefreshTask` 每次新建 `ModelContainer` + 全量 dashboard 管线 + 一次 LLM 调用（超时 120–180s × 重试 3 次），而 BGAppRefreshTask 通常仅 ~30s。晨报/晚同步会经常被系统掐断并被限流。建议复用主容器、LLM 拆出去或改为前台机会性触发、先做新鲜度检查。

### 🟠 H4. 无崩溃上报、日志稀疏（reliability-2/3，已复核）
`NSSetUncaughtExceptionHandler` 只覆盖 ObjC 异常且覆盖式写入单文件；`fatalError`（VelaServices.swift:196）、`preconditionFailure`（VelaApp.swift:295）无捕获通道；`print` 16 处无 `#if DEBUG`（发布包仍执行，如 CoachView.swift:1220）；os.Logger 仅 9 文件。建议：Sentry/自建轻量端点 + `privacy: .private/.public` 分级 + print 收口 DEBUG。

### 🟠 H5. CI 工具链未锁定 + 无质量门禁（ci_delivery，已复核）
- 硬编码 `DEVELOPER_DIR: /Applications/Xcode_26.5.0.app/...`，无 `.xcode-version`/`mise` 锁文件；
- 模拟器用 `head -n 1` 挑选（非确定）；
- SwiftLint/SwiftFormat/audit_design_tokens.sh 均未接入 CI；无覆盖率收集；
- **无任何发布链路**（无 archive/TestFlight/fastlane/版本自动化），商店交付完全手工；
- 仓库卫生：`device_build.log`、`device_build 2.log` 被 git 追踪（已复核 `git ls-files`），.gitignore 无 `*.log`。

### 🟠 H6. 浅色模式对比度不达标 + 深色模式硬编码（a11y_i18n-3/4，已复核）
实测（WCAG 相对亮度，画布 #F2F5F1）：`stateModerate` #E8A23C **1.98:1**、`statePoor` #E2607A 3.09:1、`accent` #17A35C 2.97:1、`infoBlue` #30A2FF 2.47:1、`strainColor` 2.95:1 — 用作正文均不达 4.5:1（粗体也需 ≥3:1）。另 85 处视图层 `Color(hex:)` 无暗色变体（如 WorkoutDetailView.swift:760 `#EFEAE2` 亮米色轨道）。设计文档声明的"Light/Dark 对比度校验"门禁目前无任何自动化。

### 🟠 H7. 数据删除承诺未完全兑现（security-0，已复核）
"清空 Vela 本地数据"（VelaMinimalCoachView.swift:279-308）只删 SwiftData 模型 + user_wiki + 腕表快照；`DailyLogService` 按天写入 `Application Support/Vela/daily_logs/` 的明文 JSON（含当日 HRV/RHR/血糖等全量身体数据与对话文本，DailyLogService.swift:32-36/83-90/167）**不在删除范围**，且会随 iCloud 备份离机。建议补删除 + 确认页明示 Keychain/Apple Health/备份不会被清除。

### 🟠 H8. 可访问性命中区与 VoiceOver 覆盖（a11y_i18n-2/6，已复核 3 处）
`VelaMinimalVitalsView.swift:47-53` 的"+"按钮 36×36、:195-202 32×32、`JournalEntryCard.swift:38` 删除按钮 28×28 —— 低于 44pt；`accessibilityIdentifier` 全库 0 处、无 UI 测试 target；81 个视图文件中 43 个文件零 `accessibilityLabel`（FitnessView/CoachWelcomeWorkspace/各 Sheet 等）。核心卡片与图表的语义化拼接标签是好实践，应扩散。

---

## 3. 各维度详述

### 3.1 架构与模块化
**长处（已复核）**：分层目录清晰（App / Core / Health / Scoring / Features / AI / Persistence），与 TECH_ARCHITECTURE 文档一致；领域核心有明确 seam 意识——`ScoreEngineFactory` 唯一评分入口、`DailyIntelligenceAssemblyModule`（deletion test）、`BodyStateKernel` / `TrainingDecisionKernel`、`AgentFactSnapshot` 构建器与 `ToolRegistry`；ADR 0001–0010 记录决策背景；领域语言（CONTEXT.md）在类型命名中基本一致。
**差距**：
- **巨型文件**（已复核 `wc -l`）：11 个文件 >1300 行 — PersistenceModels 2435（31 个 @Model 全在一文件）、TodaySubSheets 2416、TrainingHeroSection 2058、AgentTool 1906、TodayHeroCard 1753、CoachView 1556、TrainingAnalyticsService 1535、BiologyView 1499、TodayNutritionStrip 1377、TrainingStatsSection 1372、AIContextBuilder 1367。属于典型的"职责过载"：模型聚合、视图组件、工具执行三处最重。
- **DI 无统一策略**（已复核）：21 个 `static let shared` 单例（HealthKitSyncEngine / LLMProvider / KeychainService / WeatherService / LocationManager / NotificationService / MorningBriefScheduler / EveningWikiSyncAgent…）+ 一个只被 3 处引用的服务定位器 `VelaResolver`（VelaServices.swift:161）——单例与定位器混用，全局可变状态难以替换与测试。
- **分层穿透**（已复核）：视图层直接调仓库，如 `BodyModelViews.swift:530` 在 View 体内 `repo.fetchSnapshots(days: 1100, ...)`——视图→持久层直连，绕过 UseCase/Seam。
- **幽灵目标**：VelaWatch（1 文件 447 LOC）不在任何 scheme 中（grep VelaWatch 于 scheme = 0 匹配），要么删除要么接线；VelaBackend 29 文件被 CI 持续测试但产品文档明确"未启用"——死资产持续消耗维护与 CI 成本。
- **单 target 单体**：87k LOC 全部编译进一个 target，无本地 SPM 模块拆分；文件夹即边界（软约束），大厂标准的模块化边界（显式依赖图）不存在。个人项目此为可接受的权衡，代价是 seam 的 Leverage 只能靠纪律维持。
- **文档漂移**：TECH_ARCHITECTURE 中 `DailyCheckInRecord` 标注"尚未实现"，而代码已有 JournalEntryRecord 推断路径——文档与代码的"计划/已实现"状态需要一次对齐（辅助项）。

### 3.2 测试质量
**长处（已复核）**：456 个 test func / 12.7k LOC；测试命名面向行为（`testPersonalBaselineRequiresSevenValidSamplesPerMetric`、`testSleepScoreEngineProducesValidRange`）；断言多用硬编码期望值（如 `XCTAssertEqual(fallback.volumeMultiplier, 0.60)`，非复算实现）；时间依赖注入已做（`testPersonalBaselineUsesInjectedCalculationTime`）；内核层覆盖不错（BodyStateKernel 被 6 个测试文件引用、TrainingDecisionKernel 被 7 个引用）；VelaModelContainer 相关测试 10 个文件（含持久化集成）；连 VelaTheme 都有 2886 行 token 测试。
**差距**：
- **关键路径零测试**（已复核 grep）：`HealthKitSyncEngine`、`HealthKitQueryService`、`DeepSeekProvider`、`KeychainService`、`MorningBriefScheduler`、`BackgroundTaskManager`、`DailyLogService` 在 VelaAppTests 中引用数 **全部为 0** ——最脆弱的同步引擎与 AI 网络层无任何回归保护。
- **无迁移/升级测试**：VelaAppTests 无任何 migration/schema 测试文件（已复核），而 C1 显示 schema 正处于"改字段不升版本"状态。
- **无 UI 测试层**：无 XCUITest target（pbxproj 0 匹配）、全库 0 个 `accessibilityIdentifier`；无法做端到端/可访问性回归。
- **无覆盖率门禁**：scheme 无 `codeCoverageEnabled`、CI 无 xccov/codecov 步骤（已复核）——测试数量增长没有护栏，删测试不会被发现。
- **无共享 fixture/helper**：VelaAppTests 下无 mocks/fixtures/support 文件，各测试自建数据，重复度高。
- **失衡**：456 个测试中 UI 组装层（TodaySubSheets 等 2400 行文件）0 直接覆盖，Scoring 内核红、视图层空白——与大厂"金字塔"（UI 少量冒烟 + 内核密集）方向一致但缺 E2E 顶层。

### 3.3 CI/CD 与交付
**长处**：concurrency 取消、最小权限（contents: read）、警告即错误、SPM Package.resolved 入库、scheme 测试并行化。
**差距**：见 H5；另有 —— 无 xcconfig（构建配置全内联 pbxproj）、无根 README/CHANGELOG/RELEASING、Scheme 不含 VelaWatch（watch 目标事实上处于"仓库幽灵"状态，要么接线要么删除）、backend 继续被 CI 测试但产品侧未启用（保留需成本，删除需决策）。

### 3.4 静态代码质量
**已核实的事实**：SwiftLint 未安装（`which swiftlint` 无结果）、pbxproj 无任何 Run Script phase（0 match）、CI 无 lint job —— 4 条自定义规则（禁硬编码色/禁固定字号/禁系统语义色/禁内联圆角）**零执行**；违规存量：`Color(hex:` **85**、`.system(size:` **1080**、`RoundedRectangle(cornerRadius:` **543**、系统语义色 2。
**长处（已复核）**：`try!` = **0**；真实强制解包仅 2–3 处且都在 nil 检查之后（如 WeightLogSheetView.swift:149-150）；TODO/FIXME = **0**；提交信息规范（`feat:/fix:/perf:/chore:`）；CI 警告即错误。
**差距**：
- **门禁缺失是最主要问题**：工具都备好了（.swiftlint.yml + scripts/audit_design_tokens.sh），唯独没接进 Xcode/CI——存量违规（1080 固定字号、543 内联圆角）在新增代码中会继续增长。建议 SwiftLint 经 Mint 接入 + CI job（先 warning 后 error 分步清零）。
- **现代化延迟**：`@Observable` = 0 处 vs `ObservableObject` = 15 处（iOS 17+ 项目仍用旧 Observation 协议）；且无 `SWIFT_STRICT_CONCURRENCY` 显式设置（Swift 6 语言模式下默认完整检查，但建议显式声明并配合 warnings-as-errors 让并发规则可见可查）。
- **死代码**（已复核）：`VelaLoc` 枚举（VelaTheme.swift:358）全库 0 引用；`Localizable.strings`（zh-Hans）孤儿文件（不在 target 中）；`TodaySubSheets.swift:2324` 的 `init(coder:)` fatalError 属 SwiftUI 惯例仍属崩溃路径；VelaBackend 29 文件未启用（产品决策）。
- **魔法数字**：阈值类常量（HRV/Sleep/Stress 权重等）散落在 Scoring 各引擎内，建议收敛到带名字的配置结构并纳入测试（部分已由 SCORING_SYSTEM_V1_0.md 文档化，代码侧未完全对齐）。

### 3.5 可靠性、错误处理与可观测性
**长处**：`PipelineDiagnosticsLogger`/`VelaEventRecord` 已有流水线诊断雏形；同步有 cursor 幂等设计；AI 链路有 `AgentLoop` 90s deadline、hash 校验、流式取消生命周期（onTermination）。
**差距**：C1 schema 版本、C2 HealthKit 吞错、H4 无崩溃上报之外 —— 日志无隐私分级（唯一 `privacy: .public` 在 VelaModelContainer.swift:114）；casual 问答路径无整请求 deadline（180s 超时 ×3 重试 ≈ 9 分钟悬挂，CoachRequestRunner.swift:35-41）；SwiftData 迁移计划仅 lightweight stage（VelaModelContainer.swift:345+），无自定义迁移与升级冒烟测试。

### 3.6 安全与隐私
**长处（已复核）**：Keychain 用 `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`（不随备份出境，正确）；ATS 未放开（无 NSAllowsArbitraryLoads，默认 HTTPS-only）；HealthKit/定位/相机/相册/麦克风/日历用途字符串齐全且文案克制；PrivacyInfo.xcprivacy 已声明 UserDefaults/FileTimestamp 两类必需 API 与 reason；产品红线（原始样本不出设备、缺失用 `--`）在 AIContextBuilder/AgentFactSnapshot 结构上成立；iOS 侧零第三方 SDK（无追踪/广告 SDK，隐私面最小）。
**差距**：H7 删除盲区；PrivacyInfo 无 `NSPrivacyCollectedDataTypes`（若按 PRD 向 LLM 传输裁剪快照，严格讲应在"收集数据"声明中体现第三方处理——需产品决策：要么补声明，要么在文档明示"仅个人使用、不上架/不面向公众"）；VelaBackend 作为未启用实验服务仍保留在仓库并被 CI 构建（攻击面小的安全债）。

### 3.7 性能与并发
**长处（已复核）**：`Task.detached` 边界前完成 DTO 转换（DashboardViewModel.swift:598-642），无 Live @Model 跨并发域，符合 CLAUDE.md 规则；`VelaDailyOrchestrator` 同日并发单飞去重 + `AppSyncCoordinator` 30s 节流；wiki 文件签名缓存设计正确；训练页 PR 计算 O(n²)→O(n)。
**差距**：H2 全表扫描/主线程重计算、H3 后台预算、全库无索引；图表数据量有界（30–190 点）暂不构成问题。

### 3.8 可访问性、国际化与 UI 工程
**长处（已复核）**：Reduce Motion/Transparency/Contrast 三件套 134 处引用（Shimmer、图表动画、按压、Tab 过渡全覆盖），`VelaGlassSurfaceModifier` 在 reduceTransparency/increasedContrast 下降级为实底+描边；VoiceOver 语义化拼接（TodaySignalGrid/Trends 的 combine + label 包含方向/置信度/覆盖度）与装饰元素 `accessibilityHidden` 均是大厂水准；主题色 dark 模式全达标（最低 3.98:1）。
**差距**：C3 i18n、H1 Dynamic Type、H6 对比度/硬编码色、H8 命中区/VoiceOver 覆盖 —— 手册写了"门禁"但没有门禁的自动化执行。

---

## 4. 建议执行顺序（按 ROI）

**本周（止损）**
1. C1 Schema V4 冻结 + 版本递增规则 + 升级冒烟测试
2. C2 HealthKit 错误分类与 `lastSuccessfulSyncAt` 条件推进
3. H7 删除盲区修复（daily_logs + 确认页文案）

**两周（门禁化）**
4. H5 SwiftLint 接线（Mint + CI job + 按 4 条自定义规则先清存量）+ SwiftFormat + `*.log` 出 git + `.xcode-version` 锁文件
5. H2-a `fetchSnapshots` 加谓词 + 高频字段索引（配合 .index 迁移）
6. H4 Sentry 接入 + print 收口 + `privacy:` 分级

**一个月（体验与交付）**
7. H1/H6 Dynamic Type 全量 `relativeTo` + 主题色对比度回归脚本 + 视图层硬编码色收敛
8. C3 .xcstrings 迁移
9. 发布链路：fastlane/快速 TestFlight 步骤 + MARKETING_VERSION 唯一来源
10. H3 后台任务拆分与预算适配

**持续**
- `improve-codebase-architecture` 每 1–2 周扫一次：6 个 1300–2400 行巨型文件（PersistenceModels 2435 / TodaySubSheets 2416 / TrainingHeroSection 2058 / AgentTool 1906 / TodayHeroCard 1753 / CoachView 1556）是下一轮深化的主战场
- UI 测试 target（含 accessibilityIdentifier）加入 roadmap，作为可访问性回归的抓手

---

## 5. 附注

- 本报告为只读审计，未修改任何仓库文件。
- 严重度为审计代理判断 + 人工复核修正后的结果；带"已复核/已核实"标记的条目均由本会话人工重新取证（含统计命令结果）。
- 架构、测试、静态质量三个小节由本会话直接人工取证完成（工作流中并行深潜代理因超时被中止，其部分结论未纳入）。
- 涉及 Apple/GitHub 侧不可验证的项（runner 镜像命名、Xcode bundle 名、分支保护设置）已在原文标注低置信度。
