# 工程审计修复状态总表（2026-08-23 起）

> 追踪 docs/validation/engineering-audit-2026-08-23.md 各项的修复状态。
> 每个修复均通过：警告即错误构建 + 全量测试套件（约 470+ 测试）。

| 编号 | 审计项 | 状态 | 关键提交 | 备注 |
| :--- | :--- | :--- | :--- | :--- |
| C1 | SwiftData schema 版本管理 | ✅ 完成 | 26906c18 | 冻结快照 + `schema_fingerprint.py` CI 守卫（模型图变更必须与版本提升同提交）；经验证 SwiftData 拒绝同 checksum 双 schema，故 V3=live + 冻结预案；迁移测试恢复通过 |
| C2 | HealthKit 错误吞没 | ✅ 完成 | 26906c18 | 仅 errorNoData 放行；组件级失败分类；核心组件全失败不落全空快照；`lastSuccessfulSyncAt` 条件推进 |
| C3 | 本地化基础设施 | ⚠️ 部分 + 决策待定 | edbd1afc + 50f96090 前 | 已修：未选择时跟随系统语言、a11y 字符串走 L10n；**完整 English 化方案 A/B 需产品决策**（见 `docs/validation/i18n-coverage-2026-08-23.md`，建议方案 C：维持中文优先 + Beta 如实说明） |
| H1 | Dynamic Type | ✅ 大部分（设计项除外） | a300c63c, 35e97839, dc461878, 23ab73e8 | 主题字号 + 设计系统 + 视图层共约 355 处文字字号转系统 TextStyle；剩余 481 处为图标/显示级设计决策项（`scripts/check_fixed_fonts.py` 追踪） |
| H2 | 全表扫描/主线程重计算 | ✅ 完成 | 26906c18, 4863e883 | fetchLimit 有界化、fetchCount、流式 markdown 缓存、BodyModelBuilder 值类型化 + loadDashboard/缓存路径离线计算、bodyModel 记忆化（等价性测试守护） |
| H3 | 后台任务预算 | ✅ 完成 | a300c63c | BGAppRefreshTask 复用 App 容器（省去重复打开 store/迁移检查） |
| H4 | 崩溃上报/日志 | ⚠️ 本地完成，云端待接入 | 50f96090 | 本地：os.Logger 迁移（16 处 print→Logger + privacy 标注）+ 崩溃日志时间戳化轮转（CrashLogStore）；云端：Sentry 方案已设计（DSN 存 Keychain、缺省 no-op、禁 PII/面包屑/采样），本环境 SPM 二进制下载被 TLS 拦截无法验证，待网络允许 + 你提供 DSN 后接入 |
| H5 | CI 门禁与工具链 | ✅ 完成 | 26906c18, 432f8c5f, c295d26d | schema 守卫、对比度守卫、固定字号扫描、SwiftLint（brew 安装真正执行，report-only）、覆盖率采集+报告、xcresult 上传、.xcode-version、工具链校验、日志出仓；**发布链路**（TestFlight/fastlane）需 Apple 账号，未列 |
| H6 | 对比度/硬编码色 | ✅ 完成 | a300c63c, 432f8c5f | `textColor(for:)` 文字变体（WCAG AA ≥4.5:1 实测达标）+ 6 处文字切换 + `check_contrast.py` CI 硬门禁；85 处视图层 `Color(hex:)` 为暗色变体设计项（lint 规则追踪） |
| H7 | 数据删除盲区 | ✅ 完成 | 26906c18 | daily_logs 明文归档 + VelaRecovery 备份纳入「清空本地数据」+ 确认文案明示 Keychain/Apple Health/iCloud 备份；4 个删除完整性测试 |
| H8 | 命中区/VoiceOver | ✅ 完成 | a300c63c, 35e97839, dc461878, c295d26d | 命中区 44pt（+ 月份切换等）、Tab 标识符、3 处手势 accessibilityAction、装饰图标隐藏、关闭/步进/月份按钮标签（L10n 双语）；主屏（Hero/Trends/Fitness/Coach）语义化标签此前已达标 |

## 建议下一步（按价值排序）

1. **你拍板 C3**（读 i18n-coverage 报告；推荐方案 C 归档，或确认 B 后我分批抽取）
2. **Sentry 接入**：在你网络环境下加 SPM 依赖 + 填 DSN（我提供完整 diff 与启用说明）
3. **H1 剩余 481 处**：真机过一遍大字号 AX 设置为设计评审依据
4. **发布链路**：fastlane 配置（需 Apple 账号）
