# Vela

个人身体面板与 AI 健康分析助手：建立在 Apple 健康之上，帮助看见当前身体状态和长期趋势，理解变化原因，并将理解转化为训练与生活调整建议。

> 产品规格与领域语言以 `docs/PRD.md` 与 `CONTEXT.md` 为唯一权威；工程规范见 [CLAUDE.md](CLAUDE.md)。

## 技术栈

- **当前实现 floor：iOS 17+ / watchOS 10+** · SwiftUI + SwiftData + HealthKit · Swift 6；ADR 0013 已接受的 Daily Driver 目标为 **iOS 26 / watchOS 26**，迁移仍待单独完成
- 本地确定性评分（`VelaApp/Scoring`）→ 多尺度趋势（`HealthTrendEngine`）→ 权威简报（`PersonalHealthBrief`）→ 四个 canonical surface（Today / Trends / Plan / Coach）
- AI Coach 直连 DeepSeek API（Keychain 存 Key）；原始健康采样永不上传，仅发送裁剪的 `AgentFactSnapshot`

## 构建与测试

```bash
# 编译（模拟器）
xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath ~/Developer/Vela-DerivedData build

# 单测（约 470 个）
xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath ~/Developer/Vela-DerivedData test
```

CI（GitHub Actions `.github/workflows/quality.yml`）包含：schema 版本守卫（`scripts/schema_fingerprint.py`）、显式警告即错误构建、iOS 全量单测、SwiftLint（report-only）、后端测试、xcresult 失败上报。

## 常用脚本

| 脚本 | 用途 |
| :--- | :--- |
| `scripts/schema_fingerprint.py --check` | SwiftData 模型图守卫（CI 门禁；模型变更时按错误提示做版本提升） |
| `scripts/schema_fingerprint.py --emit-frozen` | 重新生成 `VelaSchemaV3Frozen.swift` 冻结快照 |
| `scripts/audit_design_tokens.sh` | 设计 Token 审计 |

## 文档地图

- `docs/PRD.md` — 产品规格（四大 Tab、北极星 Trusted Health Brief Day）
- `CONTEXT.md` — 领域术语表（唯一权威）
- `docs/TECH_ARCHITECTURE.md` — 技术架构与数据流
- `docs/adr/` — 架构决策记录（0001–0013 Accepted；0014–0016 Proposed）
- `docs/AI_AGENT_SPEC.md` — Coach Agent 协议与上下文规格
- `docs/validation/` — 验证与审计证据（含 2026-08-23 工程标准审计报告）
