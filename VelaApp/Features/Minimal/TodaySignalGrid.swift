import SwiftUI

// MARK: - Today score dashboard

/// The score-led opening of Today. The hierarchy is deliberately stable:
/// Recovery / Sleep / Strain are always primary, while Stress / Energy are
/// always secondary. Baseline deviation adds emphasis without reordering.
struct TodaySignalGrid: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let model: TodayExperienceModel
    let freshness: DataFreshness
    let deviatedScoreIDs: Set<String>
    let agentSentence: String
    let accentColor: (DailyPlanAccent) -> Color
    let onAskCoach: () -> Void

    /// The Today contract has five independent metrics. Keep the descriptor
    /// list at the rendering boundary so a partial/legacy payload cannot make
    /// a metric disappear from the dashboard. Missing cards are represented by
    /// an explicit `--` value; no score or aggregate is fabricated.
    private struct SignalDescriptor {
        let id: String
        let title: String
        let accent: DailyPlanAccent
    }

    private static let requiredSignals = [
        SignalDescriptor(id: "recovery", title: "恢复", accent: .recovery),
        SignalDescriptor(id: "sleep", title: "睡眠", accent: .sleep),
        SignalDescriptor(id: "strain", title: "负荷", accent: .strain),
        SignalDescriptor(id: "stress", title: "压力", accent: .stress),
        SignalDescriptor(id: "energy", title: "能量", accent: .energy)
    ]

    private var primaryDescriptors: ArraySlice<SignalDescriptor> {
        Self.requiredSignals.prefix(3)
    }

    private var primaryCards: [TodayExperienceSignalCard] {
        primaryDescriptors.map(card(for:))
    }

    private var stressCard: TodayExperienceSignalCard {
        card(for: Self.requiredSignals[3])
    }

    private var energyCard: TodayExperienceSignalCard {
        card(for: Self.requiredSignals[4])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            primaryScores
            secondaryScores
        }
    }

    private var showsBaselineContext: Bool {
        switch model.baselineFormation.phase {
        case .waitingForEvidence, .learning:
            return true
        case .ready:
            return !deviatedScoreIDs.isEmpty
        }
    }

    @ViewBuilder
    private var baselineContext: some View {
        switch model.baselineFormation.phase {
        case .waitingForEvidence:
            baselineLearningRow(label: "初始基线 · 等待数据")
        case .learning:
            baselineLearningRow(
                label: "初始基线 · \(model.baselineFormation.observedDays)/\(model.baselineFormation.requiredDays) 天"
            )
        case .ready:
            if !deviatedScoreIDs.isEmpty {
                HStack(spacing: 8) {
                    Circle()
                        .fill(VelaTheme.stressColor)
                        .frame(width: 8, height: 8)
                    Text("\(deviatedScoreIDs.count) 项偏离个人基线")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 4)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("发现 \(deviatedScoreIDs.count) 项个人基线偏离；这表示对你而言不寻常，不等同于医学异常")
            }
        }
    }

    private func baselineLearningRow(label: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "hourglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmDeep)
            Text(label)
                .font(VelaTheme.caption1().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
                .lineLimit(1)
            Spacer(minLength: 8)
            ProgressView(value: model.baselineFormation.progress)
                .tint(VelaTheme.rhythmDeep)
                .frame(width: 72)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "初始个人基线已记录 \(model.baselineFormation.observedDays) 个有效日，共需 \(model.baselineFormation.requiredDays) 天；每项分数仍会按自己的有效数据独立启用"
        )
    }

    private var primaryScores: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("今日状态")
                    .font(VelaTheme.title3().weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                DataFreshnessIndicator(freshness: freshness, showText: false)
            }

            scoreCollection(primaryCards, ringSize: 88)

            Divider()
                .overlay(VelaTheme.rhythmMist)

            agentGuidance

            if showsBaselineContext {
                baselineContext
            }
        }
        .padding(VelaTheme.space5)
        .todayDashboardCard(radius: VelaTheme.radiusHero, depth: .featured)
    }

    private var secondaryScores: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("压力与能量")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.rhythmInk)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 12) {
                    stressPanel(stressCard)
                    energyPanel(energyCard)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    stressPanel(stressCard)
                    energyPanel(energyCard)
                }
            }
        }
    }

    private func stressPanel(_ card: TodayExperienceSignalCard) -> some View {
        NavigationLink {
            VelaMetricDetailView(metric: .stress)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor(card.accent))
                    Text(card.title)
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(1)
                    if deviatedScoreIDs.contains(card.id) {
                        Circle()
                            .fill(VelaTheme.stressColor)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 2)
                    stressValue(card)
                    metricChevron
                }

                VStack(alignment: .leading, spacing: 4) {
                    TodaySecondaryTrendLine(
                        values: card.trend,
                        color: accentColor(card.accent),
                        isMissing: card.value == "--"
                    )
                    .frame(height: 24)

                    Text(card.value == "--" ? "等待压力数据" : "近 7 日趋势")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .contentShape(Rectangle())
            .todayDashboardCard(radius: VelaTheme.radiusCardStandard, depth: .standard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-secondary-stress")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(secondaryAccessibilityLabel(card))
        .accessibilityHint("查看压力的时间变化和依据")
    }

    private func stressValue(_ card: TodayExperienceSignalCard) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(card.value)
                .font(VelaTheme.title3().weight(.bold).monospacedDigit())
                .foregroundStyle(VelaTheme.rhythmInk)
            if card.value != "--" {
                Text(stressStateLabel(for: card.state))
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(VelaTheme.textColor(for: card.state))
            }
        }
    }

    private func stressStateLabel(for state: MetricState) -> String {
        switch state {
        case .good: return "低"
        case .moderate: return "适中"
        case .poor: return "高"
        }
    }

    private func energyPanel(_ card: TodayExperienceSignalCard) -> some View {
        NavigationLink {
            VelaMetricDetailView(metric: .energy)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor(card.accent))
                    Text(card.title)
                        .font(VelaTheme.subheadline().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(1)
                    if deviatedScoreIDs.contains(card.id) {
                        Circle()
                            .fill(VelaTheme.stressColor)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                    }
                    Spacer(minLength: 2)
                    energyValue(card)
                    metricChevron
                }

                VStack(alignment: .leading, spacing: 4) {
                    TodayEnergyGauge(
                        value: Double(card.value),
                        color: accentColor(card.accent)
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)

                    Text(card.value == "--" ? "等待能量模型" : "当前电量储备")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .contentShape(Rectangle())
            .todayDashboardCard(radius: VelaTheme.radiusCardStandard, depth: .standard)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-secondary-energy")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(secondaryAccessibilityLabel(card))
        .accessibilityHint("查看能量的充入、消耗和时间变化")
    }

    private func energyValue(_ card: TodayExperienceSignalCard) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text(card.value)
                .font(VelaTheme.title3().weight(.bold).monospacedDigit())
                .foregroundStyle(VelaTheme.rhythmInk)
            if card.value != "--" {
                Text("%")
                    .font(VelaTheme.caption1().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
        }
    }

    private var metricChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.55))
    }

    private func secondaryAccessibilityLabel(_ card: TodayExperienceSignalCard) -> String {
        let value = card.value == "--" ? "暂无数据" : "\(card.value) 分"
        let deviation = deviatedScoreIDs.contains(card.id) ? "，偏离个人基线" : ""
        return "\(card.title)，\(value)，\(card.directionLabel)\(deviation)"
    }

    private var agentGuidance: some View {
        Button {
            VelaHaptic.selection()
            onAskCoach()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text("指导")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }

                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(agentSentence)
                        .font(VelaTheme.body().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-guidance")
        .accessibilityLabel("今日指导，\(agentSentence)")
        .accessibilityHint("打开教练继续追问")
    }

    @ViewBuilder
    private func scoreCollection(
        _ cards: [TodayExperienceSignalCard],
        ringSize: CGFloat
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(cards) { card in
                    scoreLink(card, ringSize: 58, horizontal: true)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    scoreLink(card, ringSize: ringSize, horizontal: false)
                        .frame(maxWidth: .infinity)

                    if index < cards.count - 1 {
                        Divider()
                            .overlay(VelaTheme.rhythmMist.opacity(0.8))
                            .frame(height: ringSize + 16)
                            .padding(.horizontal, 4)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scoreLink(
        _ card: TodayExperienceSignalCard,
        ringSize: CGFloat,
        horizontal: Bool
    ) -> some View {
        if let metric = detailMetric(for: card.id) {
            NavigationLink {
                VelaMetricDetailView(metric: metric)
            } label: {
                scoreLabel(card, ringSize: ringSize, horizontal: horizontal)
            }
            .buttonStyle(.plain)
            .accessibilityHint("查看\(card.title)的依据和个人趋势")
            .accessibilityIdentifier("today-score-\(card.id)")
        } else {
            scoreLabel(card, ringSize: ringSize, horizontal: horizontal)
        }
    }

    @ViewBuilder
    private func scoreLabel(
        _ card: TodayExperienceSignalCard,
        ringSize: CGFloat,
        horizontal: Bool
    ) -> some View {
        let hasDeviation = deviatedScoreIDs.contains(card.id)
        let scoreDescription = card.value == "--" ? "暂无数据" : "\(card.value) 分"

        // A concrete container is intentional here. A `Group` can distribute
        // accessibility modifiers across its branches, which made the stable
        // score identifier disappear on the empty-data (non-ring) projection.
        VStack(spacing: 0) {
            if horizontal {
                HStack(spacing: 12) {
                    scoreRing(card, size: ringSize)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(card.title)
                                .font(VelaTheme.body().weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            if hasDeviation {
                                Circle()
                                    .fill(VelaTheme.stressColor)
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                            }
                        }
                        if !dynamicTypeSize.isAccessibilitySize {
                            Text(card.directionLabel)
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.65))
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            } else {
                VStack(spacing: 8) {
                    scoreRing(card, size: ringSize)
                    HStack(spacing: 3) {
                        Text(card.title)
                            .font(VelaTheme.subheadline().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .lineLimit(1)
                        if hasDeviation {
                            Circle()
                                .fill(VelaTheme.stressColor)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(card.title)，\(scoreDescription)，\(card.directionLabel)\(hasDeviation ? "，偏离个人基线" : "")"
        )
        .accessibilityIdentifier("today-score-\(card.id)")
    }

    private func scoreRing(
        _ card: TodayExperienceSignalCard,
        size: CGFloat
    ) -> some View {
        let accent = accentColor(card.accent)
        let score = Double(card.value)

        return VelaMetricScoreRing(
            score: score,
            label: card.title,
            domain: metricDomain(for: card.id),
            size: size,
            accent: accent,
            showsLabel: false,
            direction: card.directionLabel,
            dataState: deviatedScoreIDs.contains(card.id) ? "偏离个人基线" : nil
        )
    }

    private func card(for descriptor: SignalDescriptor) -> TodayExperienceSignalCard {
        model.signalCards.first(where: { $0.id == descriptor.id })
            ?? TodayExperienceSignalCard(
                id: descriptor.id,
                title: descriptor.title,
                value: "--",
                directionLabel: "待同步",
                confidenceLabel: "数据不足",
                coverageLabel: "未同步",
                subtitle: "等待健康数据",
                trend: [],
                accent: descriptor.accent,
                state: .moderate
            )
    }

    private func detailMetric(for cardID: String) -> VelaMetricDetailView.MetricType? {
        switch cardID {
        case "recovery": return .recovery
        case "sleep": return .sleep
        case "strain": return .strain
        case "stress": return .stress
        case "energy": return .energy
        default: return nil
        }
    }

    private func metricDomain(for cardID: String) -> VelaMetricDomain {
        switch cardID {
        case "recovery": return .recovery
        case "sleep": return .sleep
        case "strain": return .strain
        case "stress": return .stress
        case "energy": return .energy
        default: return .neutral
        }
    }
}

private struct TodaySecondaryTrendLine: View {
    let values: [Double]
    let color: Color
    let isMissing: Bool

    var body: some View {
        Canvas { context, size in
            guard !isMissing, values.count > 1 else {
                var placeholder = Path()
                placeholder.move(to: CGPoint(x: 0, y: size.height * 0.5))
                placeholder.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                context.stroke(
                    placeholder,
                    with: .color(VelaTheme.rhythmInkSecondary.opacity(0.32)),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 6])
                )
                return
            }

            let low = values.min() ?? 0
            let high = values.max() ?? 100
            let span = max(20, high - low)
            let step = size.width / CGFloat(values.count - 1)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) * step,
                    y: size.height * (0.85 - 0.70 * CGFloat((value - low) / span))
                )
            }

            var area = Path()
            area.move(to: CGPoint(x: 0, y: size.height))
            for point in points { area.addLine(to: point) }
            area.addLine(to: CGPoint(x: size.width, y: size.height))
            area.closeSubpath()
            context.fill(
                area,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.18), color.opacity(0.01)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )

            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() { line.addLine(to: point) }
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}

private struct TodayEnergyGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Double?
    let color: Color

    private var progress: CGFloat {
        guard let value else { return 0 }
        return CGFloat(min(1, max(0, value / 100)))
    }

    private let segmentCount = 14

    private var filledSegments: Int {
        guard value != nil else { return 0 }
        return Int((progress * CGFloat(segmentCount)).rounded(.up))
    }

    var body: some View {
        // One Canvas node renders all segments to keep the SwiftUI layout tree small.
        Canvas { context, size in
            let spacing: CGFloat = 3
            let count = segmentCount
            let segmentWidth = (size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            let segmentHeight: CGFloat = 20
            let top = (size.height - segmentHeight) / 2
            for index in 0..<count {
                let rect = CGRect(
                    x: CGFloat(index) * (segmentWidth + spacing),
                    y: top,
                    width: segmentWidth,
                    height: segmentHeight
                )
                let path = Path(roundedRect: rect, cornerRadius: min(segmentWidth, segmentHeight) / 2)
                context.fill(
                    path,
                    with: .color(index < filledSegments ? color : VelaTheme.rhythmMist)
                )
            }
        }
        .animation(VelaTheme.dataAnimation(reduceMotion: reduceMotion), value: filledSegments)
        .accessibilityHidden(true)
    }
}

private enum TodayDashboardCardDepth: Equatable {
    case featured
    case standard
}

private struct TodayDashboardCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let radius: CGFloat
    let depth: TodayDashboardCardDepth

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // Perf: shadows on every card re-rasterize per frame while scrolling
        // (CA::Layer::commit cost dominates hitches). The soft elevation is
        // preserved through the stroke + raised fill; drop the blur shadow.
        let _ = depth

        content
            .background(VelaTheme.rhythmCanvasRaised)
            .compositingGroup()
            .clipShape(shape)
            .overlay {
                shape.stroke(
                    colorSchemeContrast == .increased
                        ? VelaTheme.rhythmInk
                        : VelaTheme.rhythmMist.opacity(0.82),
                    lineWidth: colorSchemeContrast == .increased ? 1 : 0.6
                )
            }
    }
}

private extension View {
    func todayDashboardCard(
        radius: CGFloat,
        depth: TodayDashboardCardDepth
    ) -> some View {
        modifier(TodayDashboardCardModifier(radius: radius, depth: depth))
    }
}

// MARK: - Today plan

/// The first downstream capability after the score and lived-state calibration.
/// A conservative local fallback keeps Today useful while the persisted plan is
/// still loading; the Training surface remains the place where users adjust it.
struct TodayDailyPlanCard: View {
    let model: TodayExperienceModel
    let payload: DailyOperatingPlanPayload?
    let onAction: (TodayExperienceAction) -> Void
    let onOpenPlan: () -> Void

    private var primaryAction: TodayExperienceAction {
        if let action = payload?.primaryAction {
            return TodayExperienceAction(
                id: action.id,
                title: action.title,
                detail: action.detail,
                destination: action.destination,
                isPrimary: true,
                evidence: action.evidence
            )
        }
        if let action = model.actions.first(where: \.isPrimary) ?? model.actions.first {
            return action
        }
        return TodayExperienceAction(
            id: "conservative_default",
            title: "先保留今天的安排",
            detail: "数据同步前不用额外加量；感觉不对时，随时把计划调轻一点。",
            destination: "evidence",
            isPrimary: true
        )
    }

    private var supportingActions: [TodayExperienceAction] {
        if let payload {
            return payload.supportingActions.prefix(2).map { action in
                TodayExperienceAction(
                    id: action.id,
                    title: action.title,
                    detail: action.detail,
                    destination: action.destination,
                    isPrimary: false,
                    evidence: action.evidence
                )
            }
        }
        return Array(model.actions.filter { !$0.isPrimary }.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("今日计划")
                    .font(VelaTheme.headline())
                    .foregroundStyle(VelaTheme.rhythmInk)

                Spacer()

                Button {
                    VelaHaptic.selection()
                    onOpenPlan()
                } label: {
                    Label("调整", systemImage: "pencil")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                }
            }

            Button {
                VelaHaptic.selection()
                onAction(primaryAction)
            } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(primaryAction.title)
                            .font(VelaTheme.title3().weight(.bold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }

                    Text(primaryAction.detail)
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !supportingActions.isEmpty {
                Divider()
                    .overlay(VelaTheme.rhythmMist)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(supportingActions) { action in
                        Button {
                            VelaHaptic.selection()
                            onAction(action)
                        } label: {
                            HStack(spacing: 9) {
                                Circle()
                                    .fill(VelaTheme.rhythmDeep)
                                    .frame(width: 5, height: 5)
                                Text(action.title)
                                    .font(VelaTheme.footnote().weight(.medium))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.65))
                            }
                            .frame(minHeight: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            VelaTheme.rhythmCanvasRaised,
            in: RoundedRectangle(cornerRadius: VelaTheme.radiusCardStandard, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardStandard, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Equatable Breakers
//
// The Today scroll container re-evaluates its body on every frame while
// scrolling (iOS 26 preference propagation). These `Equatable` conformances
// let SwiftUI skip re-building the heavy card subtrees when their inputs are
// unchanged — the dominant per-frame cost of the fixed five-score dashboard.
extension TodaySignalGrid: Equatable {
    nonisolated static func == (lhs: TodaySignalGrid, rhs: TodaySignalGrid) -> Bool {
        lhs.model.signalCards == rhs.model.signalCards
            && lhs.model.baselineFormation == rhs.model.baselineFormation
            && lhs.freshness == rhs.freshness
            && lhs.deviatedScoreIDs == rhs.deviatedScoreIDs
            && lhs.agentSentence == rhs.agentSentence
    }
}

extension TodayDailyPlanCard: Equatable {
    nonisolated static func == (lhs: TodayDailyPlanCard, rhs: TodayDailyPlanCard) -> Bool {
        lhs.model.actions == rhs.model.actions && lhs.payload == rhs.payload
    }
}
