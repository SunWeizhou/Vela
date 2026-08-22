# ARCHIVED DOCUMENT

> Status: Archived
> Replaced by: docs/PRD.md
> 本文只保留历史背景，不定义当前产品或实现。

---

# Vela UI 重设计 · P0 设计 Token + P1 今日页 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `feature/ui-redesign` 分支上落地新设计语言的基础（品牌绿 + 状态色 + SF Rounded 数字）并重制「今日」旗舰页顶区，保持 274 测试全绿、可随时真机验证。

**Architecture:** 先在 `VelaTheme` 增量新增品牌绿/状态色 Token 与 SF Rounded 字体方法（不改旧 Token 行为）；在 `ScoringCore` 新增可单测的 `MetricResult.state` 纯逻辑（direction+band→状态）；再在 `TodaySubComponents.swift` 新增今日页展示组件（hero/状态色环/指导卡/体征 2×2/周负荷），最后在 `VelaMinimalTodayView` 组装替换原 `TodayHeroCard`+`TodaySignalGrid` 顶区。

**Tech Stack:** SwiftUI, Swift 6 严格并发, XCTest。

**关键约束（每个 Task 都必须遵守）:**
- **绝不脚本修改 pbxproj**：所有新代码加入**已存在**的文件，不新建 Swift 文件。
- 每完成一个 Task 都要 `xcodebuild` 编译通过；涉及逻辑的 Task 先写失败测试再实现（TDD）。
- 编译命令（本机 Debug 校验，不连手机）：
  `xcodebuild -project Vela.xcodeproj -scheme Vela -configuration Debug -derivedDataPath ~/Developer/Vela-DerivedData build 2>&1 | tail -5`
- 测试命令（跑指定测试类即可，快速）：
  `xcodebuild test -project Vela.xcodeproj -scheme Vela -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:VelaAppTests/ScoringEngineTests 2>&1 | tail -15`

---

## 文件结构

| 文件 | 动作 | 职责 |
|---|---|---|
| `VelaApp/Core/Theme/VelaTheme.swift` | 修改 | 新增品牌绿/状态色 Token、SF Rounded 字体方法、状态→颜色映射；`accent` 换为品牌绿 |
| `VelaApp/Scoring/ScoringCore.swift` | 修改 | 新增 `MetricState` 枚举 + `MetricResult.state` 计算属性（纯逻辑,Foundation-only） |
| `VelaAppTests/ScoringEngineTests.swift` | 修改 | 追加 `MetricResult.state` 的单元测试（TDD） |
| `VelaApp/Core/Utilities/TodayExperienceModel.swift` | 修改 | `TodayExperienceSignalCard` 增加 `state` 字段，在 `signal()` 中填充 |
| `VelaApp/Features/Minimal/TodaySubComponents.swift` | 修改 | 新增 5 个今日页展示组件（hero/状态色环/指导卡/体征网格/周负荷） |
| `VelaApp/Features/Minimal/VelaMinimalTodayView.swift` | 修改 | 顶区组装替换 + 新顶栏（日期+天气 / 分享+头像含同步点 / 去训练状态） |

---

## Task 1: 品牌绿 + 状态色 Token（VelaTheme）

**Files:**
- Modify: `VelaApp/Core/Theme/VelaTheme.swift`（在 `enum VelaTheme` 的 Accent 区附近插入）

- [ ] **Step 1: 新增品牌绿与状态色 Token**

在 `// MARK: - Accent` 区块之后插入。全部是增量，不删旧 Token。

```swift
    // MARK: - Brand (Vela 活力绿)

    /// 品牌主色:健康/恢复/活力,与警告色天然区分。
    static let brand       = adaptive("#17A35C", "#3FC97F")
    /// 渐变起点(品牌亮绿)
    static let brandBright = adaptive("#46C87E", "#5FD98F")
    /// 按压态/深色文字
    static let brandDeep   = adaptive("#0C7A44", "#2FA96A")
    /// 浅绿填充底(头像底/徽章/建议块)
    static let brandSoft   = adaptive("#E3F2EA", "#16301F")

    // MARK: - State Colors (G1: 颜色只表达「好不好」,不装饰)

    /// 状态:好(=品牌绿)
    static let stateGood     = adaptive("#17A35C", "#3FC97F")
    /// 状态:注意(暖橙)
    static let stateModerate = adaptive("#E8A23C", "#F2B45C")
    /// 状态:差(玫红)
    static let statePoor     = adaptive("#E2607A", "#FF8299")
```

- [ ] **Step 2: 把 `accent` 换成品牌绿（全 App 品牌色切换）**

将 Accent 区的 `accent` 由 Signal Blue 改为品牌绿（保留 `accentOn/accentHover/accentActive` 语义，同步换为绿色系）：

```swift
    /// Vela 品牌绿:可识别、代表健康,与健康状态色中的「好」一致。
    static let accent        = adaptive("#17A35C", "#3FC97F")
    static let accentOn      = adaptive("#FFFFFF", "#FFFFFF")
    static let accentHover   = adaptive("#148F4F", "#5FD98F")
    static let accentActive  = adaptive("#0C7A44", "#2FA96A")
```

- [ ] **Step 3: 新增 SF Rounded 大数字字体方法**

在 `// MARK: - Typography` 区追加（已有 `metricHeroValue()`/`cardValue()` 是 rounded，这里补更大的展示数字与统一的状态数字）：

```swift
    /// 旗舰大数字(就绪度等),SF Rounded,等宽。
    static func displayValue() -> Font {
        .system(size: 60, weight: .bold, design: .rounded).monospacedDigit()
    }
    /// 体征大卡数值。
    static func vitalValue() -> Font {
        .system(size: 24, weight: .bold, design: .rounded).monospacedDigit()
    }
```

- [ ] **Step 4: 编译验证**

Run: 上面的编译命令。
Expected: `BUILD SUCCEEDED`（纯增量 + accent 换色,无 API 变化）。

- [ ] **Step 5: Commit**

```bash
git add VelaApp/Core/Theme/VelaTheme.swift
git commit -m "feat(theme): 品牌绿 + 状态色 Token + SF Rounded 大数字,accent 切换为品牌绿"
```

---

## Task 2: `MetricResult.state` 纯逻辑（TDD，ScoringCore）

**Files:**
- Modify: `VelaApp/Scoring/ScoringCore.swift`
- Test: `VelaAppTests/ScoringEngineTests.swift`

- [ ] **Step 1: 先写失败测试**

在 `ScoringEngineTests.swift` 的测试类里追加（构造 `MetricResult` 用既有公共初始化器）：

```swift
    private func makeMetric(
        domain: ScoredHealthDomain,
        band: MetricBand
    ) -> MetricResult {
        MetricResult(
            domain: domain,
            name: domain.rawValue,
            value: 50,
            band: band,
            confidence: .high,
            components: [:],
            componentWeights: [:],
            reasons: [],
            missingInputs: [],
            dataWindow: DateInterval(start: Date(timeIntervalSince1970: 0), duration: 86400),
            source: .healthKit,
            algorithmVersion: "test",
            lastUpdated: Date(timeIntervalSince1970: 0)
        )
    }

    func testMetricStateHigherIsBetter() {
        XCTAssertEqual(makeMetric(domain: .recovery, band: .high).state, .good)
        XCTAssertEqual(makeMetric(domain: .sleep, band: .veryHigh).state, .good)
        XCTAssertEqual(makeMetric(domain: .energy, band: .normal).state, .moderate)
        XCTAssertEqual(makeMetric(domain: .recovery, band: .low).state, .poor)
        XCTAssertEqual(makeMetric(domain: .sleep, band: .veryLow).state, .poor)
    }

    func testMetricStateHigherNeedsAttention() {
        XCTAssertEqual(makeMetric(domain: .physiologicalStress, band: .low).state, .good)
        XCTAssertEqual(makeMetric(domain: .physiologicalStress, band: .veryLow).state, .good)
        XCTAssertEqual(makeMetric(domain: .physiologicalStress, band: .normal).state, .moderate)
        XCTAssertEqual(makeMetric(domain: .physiologicalStress, band: .high).state, .poor)
        XCTAssertEqual(makeMetric(domain: .physiologicalStress, band: .veryHigh).state, .poor)
    }

    func testMetricStateHigherIsLoad() {
        XCTAssertEqual(makeMetric(domain: .strain, band: .normal).state, .good)
        XCTAssertEqual(makeMetric(domain: .strain, band: .low).state, .moderate)
        XCTAssertEqual(makeMetric(domain: .strain, band: .high).state, .moderate)
        XCTAssertEqual(makeMetric(domain: .strain, band: .veryLow).state, .poor)
        XCTAssertEqual(makeMetric(domain: .strain, band: .veryHigh).state, .poor)
    }
```

- [ ] **Step 2: 跑测试确认失败**

Run: 上面的测试命令。
Expected: 编译错误 `value of type 'MetricResult' has no member 'state'`。

- [ ] **Step 3: 实现 `MetricState` + `MetricResult.state`**

在 `ScoringCore.swift`（`MetricBand` 之后）新增：

```swift
public enum MetricState: String, Codable, Hashable, Sendable {
    case good
    case moderate
    case poor
}
```

在 `extension MetricResult`（`direction` 计算属性附近）新增：

```swift
    /// G1 状态着色:颜色只表达「好不好」,由 direction + band 推导。
    /// higherIsBetter(恢复/睡眠/能量):越高越好;higherNeedsAttention(压力):越低越好;
    /// higherIsLoad(负荷):落在正常区间为最好。
    public var state: MetricState {
        switch direction {
        case .higherIsBetter:
            switch band {
            case .high, .veryHigh: return .good
            case .normal: return .moderate
            case .low, .veryLow: return .poor
            }
        case .higherNeedsAttention:
            switch band {
            case .low, .veryLow: return .good
            case .normal: return .moderate
            case .high, .veryHigh: return .poor
            }
        case .higherIsLoad:
            switch band {
            case .normal: return .good
            case .low, .high: return .moderate
            case .veryLow, .veryHigh: return .poor
            }
        }
    }
```

- [ ] **Step 4: 跑测试确认通过**

Run: 测试命令。
Expected: 3 个新测试 PASS，其余测试不回归。

- [ ] **Step 5: Commit**

```bash
git add VelaApp/Scoring/ScoringCore.swift VelaAppTests/ScoringEngineTests.swift
git commit -m "feat(scoring): MetricResult.state 状态推导(G1 状态着色),含单测"
```

---

## Task 3: 状态→颜色映射 + 信号卡携带状态（Theme + Model）

**Files:**
- Modify: `VelaApp/Core/Theme/VelaTheme.swift`
- Modify: `VelaApp/Core/Utilities/TodayExperienceModel.swift`

- [ ] **Step 1: VelaTheme 新增状态→颜色映射**

在 `VelaTheme` 内追加（引用 `MetricState`，同 target 可见）：

```swift
    /// 状态→颜色(G1)。视图统一经此取色,不要直接用 stateGood/Moderate/Poor。
    static func color(for state: MetricState) -> Color {
        switch state {
        case .good: return stateGood
        case .moderate: return stateModerate
        case .poor: return statePoor
        }
    }
```

- [ ] **Step 2: `TodayExperienceSignalCard` 增加 `state` 字段**

在 `TodayExperienceModel.swift` 中，给结构体加字段：

```swift
struct TodayExperienceSignalCard: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var value: String
    var directionLabel: String
    var confidenceLabel: String
    var coverageLabel: String
    var subtitle: String
    var trend: [Double]
    var accent: DailyPlanAccent
    var state: MetricState          // 新增:G1 状态色
}
```

在 `signal(...)` 构造处填充（`return TodayExperienceSignalCard(...)` 里加一行）：

```swift
            trend: trend,
            accent: accent,
            state: metric.state      // 新增
        )
```

> 注意：`TodayExperienceModel` 是 `Codable`，`MetricState` 也是 `Codable`，旧缓存若反序列化缺 `state` 字段会失败。为稳妥，给 `state` 一个默认解码：在 `TodayExperienceSignalCard` 加自定义 `init(from:)` 使 `state` 缺省为 `.moderate`。若项目未对 model 做持久化解码（仅内存构建），可省略；执行时以编译/运行验证为准。

- [ ] **Step 3: 编译验证**

Run: 编译命令。
Expected: `BUILD SUCCEEDED`。

- [ ] **Step 4: Commit**

```bash
git add VelaApp/Core/Theme/VelaTheme.swift VelaApp/Core/Utilities/TodayExperienceModel.swift
git commit -m "feat(theme): 状态→颜色映射;信号卡携带 state"
```

---

## Task 4: 今日页新展示组件（TodaySubComponents）

**Files:**
- Modify: `VelaApp/Features/Minimal/TodaySubComponents.swift`（在文件内追加组件;不新建文件）

> 以下组件全部是无副作用的纯展示组件，数据由调用方传入。统一用 `VelaTheme` Token 与 `VelaTheme.color(for:)` 状态色。

- [ ] **Step 1: 状态色五环条 `TodayStateRingsStrip`**

```swift
struct TodayStateRingsStrip: View {
    let model: TodayExperienceModel

    private var ordered: [TodayExperienceSignalCard] {
        let order = ["recovery", "sleep", "strain", "stress", "energy"]
        return order.compactMap { id in model.signalCards.first(where: { $0.id == id }) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ordered) { card in
                VStack(spacing: 6) {
                    VelaMetricScoreRing(
                        score: Double(card.value),
                        label: card.title,
                        domain: .neutral,
                        size: 44,
                        accent: VelaTheme.color(for: card.state),
                        showsLabel: false
                    )
                    Text(card.title)
                        .font(VelaTheme.caption2().weight(.semibold))
                        .foregroundStyle(VelaTheme.fg2)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 13)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }
}
```

- [ ] **Step 2: 就绪度 Hero `TodayReadinessHero`**

```swift
struct TodayReadinessHero: View {
    let scoreText: String          // "82" 或 "--"
    let stateText: String          // 例:"状态不错"
    let state: MetricState
    let trend: [Double]

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(scoreText)
                        .font(VelaTheme.displayValue())
                        .foregroundStyle(VelaTheme.color(for: state))
                    Text("/100")
                        .font(VelaTheme.callout().weight(.bold))
                        .foregroundStyle(VelaTheme.muted)
                }
                Text("READY · \(stateText)")
                    .font(VelaTheme.caption1().weight(.bold))
                    .foregroundStyle(VelaTheme.color(for: state))
            }
            Spacer()
            TodayHeroSparkline(values: trend, color: VelaTheme.color(for: state))
                .frame(width: 84, height: 40)
        }
        .padding(.horizontal, 4)
    }
}

/// 迷你趋势线(无数据时画虚线)。
struct TodayHeroSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height * 0.5))
                p.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(p, with: .color(color.opacity(0.4)),
                               style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
                return
            }
            let minV = values.min() ?? 0, maxV = values.max() ?? 100
            let span = max(maxV - minV, 1)
            let stepX = size.width / CGFloat(values.count - 1)
            var path = Path()
            for (i, v) in values.enumerated() {
                let x = CGFloat(i) * stepX
                let y = size.height * 0.15 + size.height * 0.7 * (1 - CGFloat((v - minV) / span))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            if let last = values.last {
                let x = size.width, y = size.height * 0.15 + size.height * 0.7 * (1 - CGFloat((last - minV) / span))
                context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}
```

- [ ] **Step 3: 今日指导卡 `TodayGuidanceCard`（无「开始训练」,Coach 入口）**

```swift
struct TodayGuidanceCard: View {
    let title: String
    let summary: String
    let onAskCoach: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("今日指导")
                .font(VelaTheme.caption2().weight(.bold))
                .foregroundStyle(VelaTheme.muted)
            Text(title)
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.fg)
            Text(summary)
                .font(VelaTheme.caption1())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onAskCoach) {
                HStack(spacing: 5) {
                    Text("和 Coach 聊聊")
                    Image(systemName: "arrow.right")
                }
                .font(VelaTheme.subheadline().weight(.bold))
                .foregroundStyle(VelaTheme.brand)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .accessibilityLabel("和 Coach 聊聊今日建议")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }
}
```

- [ ] **Step 4: 体征 2×2 网格 `TodayVitalsGrid` + 单元卡**

数据来自 `dashboard.recoveryMetrics`(HRV/RHR/呼吸)、`dashboard.extendedMetrics.oxygenSaturation`(血氧)、`dashboard.sleepSummary`(睡眠时长)。每张卡:固定标签高 + 数值同基线 + 迷你可视化。

```swift
enum TodayVitalKind: String, CaseIterable, Identifiable {
    case hrv, rhr, spo2, sleep
    var id: String { rawValue }
}

struct TodayVitalCardModel: Identifiable {
    let kind: TodayVitalKind
    let label: String
    let value: String          // "68" / "--"
    let unit: String           // "ms" / "bpm" / "%" / "时"
    let status: String         // "高于基线" / "正常" ...
    let isGood: Bool
    let trend: [Double]
    var id: String { kind.rawValue }
}

struct TodayVitalsGrid: View {
    let cards: [TodayVitalCardModel]
    let onTap: (TodayVitalKind) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(cards) { card in
                Button { onTap(card.kind) } label: {
                    TodayVitalCard(card: card)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TodayVitalCard: View {
    let card: TodayVitalCardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(card.label)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.fg2)
                    .lineLimit(1)
                    .frame(height: 14)            // 固定标签高 → 对齐
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.meta)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(card.value)
                    .font(VelaTheme.vitalValue())
                    .foregroundStyle(VelaTheme.fg)
                Text(card.unit)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .frame(height: 26, alignment: .bottom)  // 数值同基线 → 对齐
            Text(card.status)
                .font(VelaTheme.caption2().weight(.bold))
                .foregroundStyle(card.isGood ? VelaTheme.stateGood : VelaTheme.stateModerate)
            TodayHeroSparkline(values: card.trend, color: VelaTheme.brand)
                .frame(height: 24)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
```

- [ ] **Step 5: 周负荷柱状卡 `TodayWeeklyLoadCard`**

数据 = `history` 最近 7 天 `dailyLoad`。

```swift
struct TodayWeeklyLoadCard: View {
    let loads: [Double]          // 7 天负荷,可能不足 7
    let acwrText: String         // 例:"ACWR 1.06"

    private var maxLoad: Double { max(loads.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("本周负荷")
                    .font(VelaTheme.subheadline().weight(.bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text(acwrText)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(loads.enumerated()), id: \.offset) { index, load in
                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(index == loads.count - 1 ? VelaTheme.brand : VelaTheme.fillSoft)
                            .frame(height: max(6, 52 * CGFloat(load / maxLoad)))
                        Text("\(index + 1)")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(VelaTheme.meta)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64)
        }
        .padding(14)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
    }
}
```

- [ ] **Step 6: 编译验证**

Run: 编译命令。
Expected: `BUILD SUCCEEDED`（组件暂未在视图使用,可能有 unused 警告,可接受）。

- [ ] **Step 7: Commit**

```bash
git add VelaApp/Features/Minimal/TodaySubComponents.swift
git commit -m "feat(today): 新增今日页展示组件(hero/状态色环/指导卡/体征网格/周负荷)"
```

---

## Task 5: 今日页组装 + 新顶栏（VelaMinimalTodayView）

**Files:**
- Modify: `VelaApp/Features/Minimal/VelaMinimalTodayView.swift`

- [ ] **Step 1: 顶区替换**

在 `body` 的 `LazyVStack` 中，将原 `TodayHeroCard(...)` 与 `TodaySignalGrid(...)` 两个组件**替换**为下列新顶区（其余 `DataCoverageCompactCard`/`TodayDailyModuleLinks`/`TodayCoachPreview`/`TodayActionTimeline` 等保留不动，后续阶段再统一风格）：

```swift
                TodayReadinessHero(
                    scoreText: recoveryText,
                    stateText: todayExperience.hero.decisionTitle,
                    state: dashboard.recovery.state,
                    trend: todayExperience.signalCards.first(where: { $0.id == "recovery" })?.trend ?? []
                )

                TodayStateRingsStrip(model: todayExperience)

                TodayGuidanceCard(
                    title: todayExperience.hero.decisionTitle,
                    summary: todayExperience.hero.summary,
                    onAskCoach: { showCoach = true }
                )

                TodayVitalsGrid(cards: vitalCards) { _ in
                    // 体征二级页在 P2 接入;此处先留入口(可跳 MetricDetailView)。
                }

                TodayWeeklyLoadCard(loads: weeklyLoads, acwrText: acwrText)
```

- [ ] **Step 2: 新增计算属性提供体征卡与周负荷数据**

在 `VelaTodayView` 内追加：

```swift
    private var vitalCards: [TodayVitalCardModel] {
        let rm = dashboard.recoveryMetrics
        let hrv = rm.hrvMilliseconds
        let rhr = rm.restingHeartRate
        let spo2 = dashboard.extendedMetrics.oxygenSaturation
        let sleepMin = dashboard.sleepSummary.stageMinutes
            .filter { $0.key != .awake }
            .reduce(0) { $0 + $1.value }
        return [
            TodayVitalCardModel(kind: .hrv, label: "心率变异性",
                value: hrv.map { "\(Int($0.rounded()))" } ?? "--", unit: "ms",
                status: "今早", isGood: true, trend: []),
            TodayVitalCardModel(kind: .rhr, label: "静息心率",
                value: rhr.map { "\(Int($0.rounded()))" } ?? "--", unit: "bpm",
                status: "今早", isGood: true, trend: []),
            TodayVitalCardModel(kind: .spo2, label: "血氧",
                value: spo2.map { "\(Int($0.rounded()))" } ?? "--", unit: "%",
                status: "今早", isGood: true, trend: []),
            TodayVitalCardModel(kind: .sleep, label: "睡眠",
                value: sleepMin > 0 ? "\(sleepMin / 60):\(String(format: "%02d", sleepMin % 60))" : "--", unit: "时",
                status: "今早", isGood: true, trend: [])
        ]
    }

    private var weeklyLoads: [Double] {
        dashboardVM.history
            .sorted { $0.date < $1.date }
            .suffix(7)
            .map { $0.dailyLoad ?? 0 }
    }

    private var acwrText: String {
        let c = dashboard.strain.components
        if let acwr = c["acwr"] { return String(format: "ACWR %.2f", acwr) }
        return "本周"
    }
```

> 执行时注意：`dashboardVM.history` 的确切属性名以 `DashboardViewModel` 现有定义为准（若叫别的名字,按实际改）。`dashboard.extendedMetrics` 同理。`SleepStage.awake` 的 case 名以 `SleepSummary` 定义为准。

- [ ] **Step 3: 新顶栏（日期+天气 / 分享+头像含同步点 / 去训练状态）**

修改 `TodayDateAndStatusHeader`：
- 删除「训练状态胶囊」整段（`statusPill` Button 与其 `HStack`），以及不再用的 `resolvedActiveStatus/activeStatusDuration/showActiveStatus` 参数。
- 日期按钮后紧跟 `TodayWeatherBar`（天气挪到日期后）。
- 头像 `person.crop.circle.fill` 右下角加一个 8px 品牌绿圆点（`VelaTheme.brand`）表示「已同步」。

头像段改为：

```swift
                    Button { showSettings = true } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 32, height: 32)
                                .foregroundStyle(VelaTheme.brand)
                            Circle()
                                .fill(VelaTheme.brand)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(VelaTheme.systemGroupedBackground, lineWidth: 2))
                        }
                        .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.cardPress)
                    .accessibilityLabel("个人设置,数据已同步")
```

并把天气从「状态胶囊行」移到日期行内（日期 Button 之后）：

```swift
            HStack(alignment: .center, spacing: 8) {
                Button { showCalendarOverview = true } label: { /* 原日期内容 */ }
                TodayWeatherBar(weatherTemp: weatherTemp, weatherStatusText: weatherStatusText, requestWeatherUpdate: requestWeatherUpdate)
                Spacer()
                // 分享 + 头像
            }
```

> 删除训练状态后，需清理 `statusPillIcon/statusPillColor/statusPillTitle`、`resolvedActiveStatus`、`showActiveStatus` 等不再引用的属性与 `sheet`（若有 `showActiveStatus` 弹窗），确保无残留编译错误。

- [ ] **Step 4: 编译 + 全量测试**

Run: 编译命令 → `BUILD SUCCEEDED`。
Run: 全量测试 `xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`。
Expected: 274 测试全绿（或仅既有 flaky 项,与本次改动无关）。

- [ ] **Step 5: 真机目视确认**

构建并推送真机（按 CLAUDE.md 命令），目视确认今日页顶区为新设计、可右滑切昨天、天气/头像正常。

- [ ] **Step 6: Commit**

```bash
git add VelaApp/Features/Minimal/VelaMinimalTodayView.swift
git commit -m "feat(today): 重制今日页顶区 + 新顶栏(品牌绿/状态色/体征 2×2/周负荷,去训练状态)"
```

---

## Self-Review 结论

- **Spec 覆盖**：本计划覆盖 P0(Token/状态逻辑/字体）与 P1（今日页顶区 + 顶栏）。体征二级页（P2)、训练页重定位（P3)、教练/我的（P4)、收尾收敛（P5）按 spec 属后续独立计划，不在本计划。
- **占位符**：无 TBD；每个代码步骤均给出完整代码。仅有的「以实际定义为准」是属性名核对（`dashboardVM.history`/`extendedMetrics`/`SleepStage.awake`），执行时以编译为准，非逻辑占位。
- **类型一致**：`MetricState` 在 Task 2 定义，Task 3/4/5 一致引用；`VelaTheme.color(for:)` 在 Task 3 定义，Task 4/5 一致使用；`TodayVitalCardModel`/`TodayVitalKind` 在 Task 4 定义，Task 5 使用。
- **风险点**：`TodayExperienceSignalCard` 新增 `state` 字段的 Codable 兼容性（Task 3 已注）；删除训练状态后的残留引用清理（Task 5 Step 3 已列）。
