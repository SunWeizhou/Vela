import SwiftUI
import SwiftData

/// Hero card that replaces the top of HomeView with a single-glance daily state summary.
struct TodayPlanHero: View {
    let plan: TodayPlan
    let onActionTap: (DailyAction) -> Void
    let onWhyThisTap: (DailyAction) -> Void

    @State private var expandedActionId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            cockpitHeader
            cockpitSignals
            actionStack
        }
        .padding(.horizontal, VelaTheme.screenPadding)
    }

    // MARK: - Body Intelligence Cockpit

    private var cockpitHeader: some View {
        VelaHeroSurface(tint: stateColor) {
            VStack(alignment: .center, spacing: 18) {
                VStack(spacing: 8) {
                    Text(AppLanguage.stored.isChinese ? "今日身体状态" : "Today's Body State")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                        .tracking(1.4)

                    readinessRing

                    HStack(spacing: 8) {
                        Text(plan.state.label)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                        VelaStatusBadge(label: fatigueLabel, systemImage: "waveform.path.ecg", tint: stateColor)
                    }

                    Text(readinessNarrative)
                        .font(.title3.weight(.medium))
                        .foregroundStyle(VelaTheme.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }

                if !riskFlags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(riskFlags.prefix(2)) { flag in
                            HStack(alignment: .top, spacing: 8) {
                                VelaRiskBadge(level: flag.level)
                                Text(flag.message)
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            }
        }
    }

    private var readinessRing: some View {
        ZStack {
            Circle()
                .stroke(VelaTheme.stroke, lineWidth: 9)
            Circle()
                .trim(from: 0, to: readinessProgress)
                .stroke(
                    AngularGradient(colors: [stateColor.opacity(0.55), stateColor, stateColor.opacity(0.78)], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: stateColor.opacity(0.25), radius: 8, y: 2)
            VStack(spacing: 2) {
                Text(readinessScoreText)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .monospacedDigit()
                Text(AppLanguage.stored.isChinese ? "准备度" : "Ready")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .frame(width: 112, height: 112)
        .accessibilityLabel(AppLanguage.stored.isChinese ? "今日准备度 \(readinessScoreText)" : "Today's readiness \(readinessScoreText)")
    }

    private var cockpitSignals: some View {
        VelaGlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    signalBlock(
                        title: AppLanguage.stored.isChinese ? "主要限制" : "Primary limiter",
                        value: primaryLimiterTitle,
                        detail: primaryLimiterDetail,
                        icon: "exclamationmark.arrow.triangle.2.circlepath",
                        tint: VelaTheme.strain
                    )

                    signalBlock(
                        title: AppLanguage.stored.isChinese ? "训练窗口" : "Training window",
                        value: trainingWindowTitle,
                        detail: trainingWindowDetail,
                        icon: "calendar.badge.clock",
                        tint: VelaTheme.energy
                    )
                }

                if !fatigueSources.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppLanguage.stored.isChinese ? "疲劳来源" : "Fatigue sources")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.mutedText)
                        FlowPills(items: fatigueSources.prefix(4).map { source in
                            (source.category.label, VelaSemanticColors.color(for: source.category.rawValue))
                        })
                    }
                }

                VelaInlineAlert(
                    title: AppLanguage.stored.isChinese ? "判断置信度" : "Confidence",
                    message: confidenceText,
                    systemImage: "checkmark.seal.fill",
                    tint: confidenceTint
                )
            }
        }
    }

    // MARK: - Action Card

    private var actionStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            VelaSectionHeader(
                title: AppLanguage.stored.isChinese ? "今日行动" : "Today's Actions",
                subtitle: AppLanguage.stored.isChinese ? "按优先级排列，可查看每条建议的判断依据。" : "Prioritized actions, each with reasoning when available."
            )

            ForEach(plan.topActions.prefix(3)) { action in
                actionCard(action)
            }

            if plan.confidenceNote.localizedCaseInsensitiveContains("pending") || plan.confidenceNote.contains("待确认") {
                memoryInboxTeaser
            }
        }
    }

    private func actionCard(_ action: DailyAction) -> some View {
        let isExpanded = expandedActionId == action.id
        let hasReasoning = !action.evidenceChain.isEmpty || !action.whyThis.isEmpty

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedActionId = isExpanded ? nil : action.id
                }
                onActionTap(action)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: action.iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(VelaTheme.accent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(VelaTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        if hasReasoning {
                            Image(systemName: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(VelaTheme.energy)
                        }
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VelaTheme.mutedText)
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    MarkdownText(markdown: action.detailMarkdown, font: .caption, color: VelaTheme.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, hasReasoning ? 6 : 14)
            }

            if hasReasoning {
                Button {
                    onWhyThisTap(action)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.caption2.weight(.semibold))
                        Text(AppLanguage.stored.isChinese ? "查看判断依据" : "Why This?")
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(VelaTheme.accent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(VelaTheme.accent.opacity(0.08))
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VelaTheme.elevatedSurface)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(hasReasoning ? VelaTheme.accent : VelaTheme.stroke)
                .frame(width: 3)
                .padding(.vertical, 12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(hasReasoning ? VelaTheme.accent.opacity(0.20) : VelaTheme.stroke, lineWidth: 0.7)
        )
    }

    private func signalBlock(title: String, value: String, detail: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(detail)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.08)))
    }

    // MARK: - Memory Inbox Teaser

    private var memoryInboxTeaser: some View {
        NavigationLink {
            WikiProfileView()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.energy)
                Text(
                    AppLanguage.stored.isChinese
                        ? "Vela 发现了一些可能值得记录的发现"
                        : "Vela has some findings for you to review"
                )
                .font(.caption)
                .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.mutedText)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VelaTheme.energy.opacity(0.08))
            )
        }
    }

    // MARK: - Helpers

    private var stateColor: Color {
        switch plan.state {
        case .great: return VelaTheme.energy
        case .good: return VelaTheme.accent
        case .fair: return VelaTheme.strain
        case .poor: return VelaTheme.recovery
        case .unknown: return VelaTheme.mutedText
        }
    }

    private var readinessScoreText: String {
        guard let score = plan.bodyInterpretation?.readinessScore else { return "--" }
        return "\(Int(score.rounded()))"
    }

    private var readinessProgress: CGFloat {
        guard let score = plan.bodyInterpretation?.readinessScore else { return 0.04 }
        return min(max(CGFloat(score / 100), 0.04), 1)
    }

    private var readinessNarrative: String {
        plan.bodyInterpretation?.readinessNarrative ?? plan.subheadline
    }

    private var fatigueLabel: String {
        plan.bodyInterpretation?.fatigueLevel.label ?? plan.state.label
    }

    private var primaryLimiterTitle: String {
        plan.bodyInterpretation?.primaryLimiter.metricName ?? (AppLanguage.stored.isChinese ? "数据基线" : "Data baseline")
    }

    private var primaryLimiterDetail: String {
        plan.bodyInterpretation?.primaryLimiter.interpretation ?? plan.subheadline
    }

    private var trainingWindowTitle: String {
        guard let window = plan.bodyInterpretation?.trainingWindow else {
            return AppLanguage.stored.isChinese ? "等待更多数据" : "Awaiting more data"
        }
        if !window.isOpen {
            return AppLanguage.stored.isChinese ? "窗口关闭" : "Window closed"
        }
        return "\(window.recommendedIntensity.capitalized) · \(window.maxDurationMinutes)m"
    }

    private var trainingWindowDetail: String {
        plan.bodyInterpretation?.trainingWindow.narrative ?? plan.headline
    }

    private var fatigueSources: [FatigueSource] {
        plan.bodyInterpretation?.fatigueSources ?? []
    }

    private var riskFlags: [RiskFlag] {
        plan.bodyInterpretation?.riskFlags ?? []
    }

    private var confidenceText: String {
        if let confidence = plan.bodyInterpretation?.overallConfidence {
            switch confidence {
            case .high: return AppLanguage.stored.isChinese ? "关键健康信号充足，建议可信度较高。" : "Key health signals are available, so this recommendation has high confidence."
            case .medium: return AppLanguage.stored.isChinese ? "部分信号可用，Vela 会保守解释今天的状态。" : "Some signals are available, so Vela is interpreting today conservatively."
            case .low: return AppLanguage.stored.isChinese ? "数据覆盖有限，请把建议视为低置信度参考。" : "Data coverage is limited; treat the recommendation as low-confidence guidance."
            case .unavailable: return plan.confidenceNote
            }
        }
        return plan.confidenceNote
    }

    private var confidenceTint: Color {
        guard let confidence = plan.bodyInterpretation?.overallConfidence else { return VelaTheme.accent }
        return VelaSemanticColors.color(for: confidence)
    }
}

private struct FlowPills: View {
    let items: [(String, Color)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { item in
                VelaStatusBadge(label: item.element.0, tint: item.element.1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Why This Sheet

struct WhyThisSheet: View {
    let action: DailyAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VelaHeroSurface(tint: VelaTheme.accent) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(AppLanguage.stored.isChinese ? "为什么 Vela 建议这样做？" : "Why is Vela recommending this?")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(VelaTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(action.title)
                                .font(.headline)
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(action.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(VelaTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Evidence Chain 2.0 (preferred)
                    if !action.evidenceChain.isEmpty {
                        VelaSectionHeader(
                            title: AppLanguage.stored.isChinese ? "证据链" : "Evidence Chain",
                            subtitle: AppLanguage.stored.isChinese ? "从健康信号到行动影响的推理路径。" : "The path from health signal to action impact."
                        )
                        VStack(spacing: 12) {
                            ForEach(Array(action.evidenceChain.enumerated()), id: \.element.id) { offset, item in
                                evidenceChainCard(item, index: offset + 1, isLast: offset == action.evidenceChain.count - 1)
                            }
                        }
                    } else {
                        // Legacy WhyThisItem fallback
                        VelaSectionHeader(
                            title: AppLanguage.stored.isChinese ? "判断依据" : "Reasoning",
                            subtitle: AppLanguage.stored.isChinese ? "旧版指标解释会作为备用显示。" : "Legacy metric explanations are shown as fallback."
                        )
                        VStack(spacing: 12) {
                            ForEach(Array(action.whyThis.enumerated()), id: \.element.id) { offset, item in
                                whyThisCard(item, index: offset + 1, isLast: offset == action.whyThis.count - 1)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(VelaBackground())
            .navigationTitle(AppLanguage.stored.isChinese ? "判断依据" : "Why This?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLanguage.stored.isChinese ? "完成" : "Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Evidence Chain Card (Vela 2.0 Beta)

    private func evidenceChainCard(_ item: EvidenceChainItem, index: Int, isLast: Bool) -> some View {
        let tint = colorForCategory(item.metricCategory)
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: iconForCategory(item.metricCategory))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(VelaTheme.background))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 1.2))
                if !isLast {
                    Rectangle()
                        .fill(VelaTheme.stroke)
                        .frame(width: 1.5, height: 116)
                }
            }

            VelaGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        Label(item.metricName, systemImage: iconForCategory(item.metricCategory))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Spacer()
                        VelaFreshnessBadge(freshness: item.dataFreshness)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        reasoningValue(
                            title: AppLanguage.stored.isChinese ? "当前" : "Current",
                            value: "\(item.currentValueFormatted) \(item.unit)",
                            tint: tint
                        )
                        reasoningValue(
                            title: AppLanguage.stored.isChinese ? "基线" : "Baseline",
                            value: item.baselineFormatted.map { "\($0) \(item.unit)" } ?? "--",
                            tint: VelaTheme.secondaryText
                        )
                        reasoningValue(
                            title: AppLanguage.stored.isChinese ? "趋势" : "Trend",
                            value: trendLabel(item.trend),
                            tint: trendColor(item.trend),
                            icon: trendIcon(item.trend)
                        )
                        reasoningValue(
                            title: AppLanguage.stored.isChinese ? "来源" : "Source",
                            value: sourceLabel(item.source),
                            tint: VelaTheme.mutedText
                        )
                    }

                    Text(item.interpretation)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.actionImpact.isEmpty {
                        VelaInlineAlert(
                            title: AppLanguage.stored.isChinese ? "对行动的影响" : "Action impact",
                            message: item.actionImpact,
                            systemImage: "lightbulb.fill",
                            tint: VelaTheme.energy
                        )
                    }

                    VelaConfidenceBadge(confidence: item.confidence)
                }
            }
        }
    }

    // MARK: - Legacy Why This Card

    private func whyThisCard(_ item: WhyThisItem, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                Text("\(index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(VelaTheme.background))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 1.2))
                if !isLast {
                    Rectangle()
                        .fill(VelaTheme.stroke)
                        .frame(width: 1.5, height: 92)
                }
            }

            VelaGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(item.metricName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)
                        Spacer()
                        VelaConfidenceBadge(confidence: item.confidence)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        reasoningValue(title: AppLanguage.stored.isChinese ? "当前" : "Current", value: item.currentValue, tint: VelaTheme.accent)
                        reasoningValue(title: AppLanguage.stored.isChinese ? "参考" : "Reference", value: item.baselineValue ?? "--", tint: VelaTheme.secondaryText)
                    }

                    Text(item.interpretation)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func reasoningValue(title: String, value: String, tint: Color, icon: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                }
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
            .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.08)))
    }

    private func confidenceBadge(_ confidence: DataConfidence) -> some View {
        let label: String
        let color: Color
        switch confidence {
        case .high:
            label = AppLanguage.stored.isChinese ? "高置信度" : "High"
            color = VelaTheme.energy
        case .medium:
            label = AppLanguage.stored.isChinese ? "中等" : "Medium"
            color = VelaTheme.accent
        case .low:
            label = AppLanguage.stored.isChinese ? "低" : "Low"
            color = VelaTheme.strain
        case .unavailable:
            label = AppLanguage.stored.isChinese ? "不可用" : "N/A"
            color = VelaTheme.mutedText
        }
        return Text(label)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Evidence Chain Helpers

    private func trendIcon(_ trend: MetricTrend) -> String {
        switch trend {
        case .improving: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .declining: return "arrow.down.right"
        case .insufficientData: return "questionmark"
        }
    }

    private func trendLabel(_ trend: MetricTrend) -> String {
        switch trend {
        case .improving: return AppLanguage.stored.isChinese ? "改善中" : "Improving"
        case .stable: return AppLanguage.stored.isChinese ? "稳定" : "Stable"
        case .declining: return AppLanguage.stored.isChinese ? "下降" : "Declining"
        case .insufficientData: return AppLanguage.stored.isChinese ? "数据不足" : "N/A"
        }
    }

    private func trendColor(_ trend: MetricTrend) -> Color {
        switch trend {
        case .improving: return VelaTheme.energy
        case .stable: return VelaTheme.accent
        case .declining: return VelaTheme.recovery
        case .insufficientData: return VelaTheme.mutedText
        }
    }

    private func freshnessBadge(_ freshness: DataFreshness) -> some View {
        let label: String; let color: Color
        switch freshness {
        case .live: label = AppLanguage.stored.isChinese ? "实时" : "Live"; color = VelaTheme.energy
        case .today: label = AppLanguage.stored.isChinese ? "今日" : "Today"; color = VelaTheme.accent
        case .recent: label = AppLanguage.stored.isChinese ? "近期" : "Recent"; color = VelaTheme.secondaryText
        case .stale: label = AppLanguage.stored.isChinese ? "陈旧" : "Stale"; color = VelaTheme.strain
        case .missing: label = AppLanguage.stored.isChinese ? "缺失" : "Missing"; color = VelaTheme.mutedText
        }
        return Text(label).font(.caption2.weight(.medium)).foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(color.opacity(0.1)))
    }

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "recovery": return "heart.fill"
        case "sleep": return "moon.zzz.fill"
        case "strain": return "figure.run"
        case "stress": return "brain.head.profile"
        case "energy": return "bolt.fill"
        case "gait": return "figure.walk"
        case "cardio": return "lungs.fill"
        default: return "chart.bar.fill"
        }
    }

    private func colorForCategory(_ category: String) -> Color {
        switch category {
        case "recovery": return VelaTheme.recovery
        case "sleep": return VelaTheme.sleep
        case "strain": return VelaTheme.strain
        case "stress": return VelaTheme.stress
        case "energy": return VelaTheme.energy
        case "gait": return VelaTheme.accent
        default: return VelaTheme.accent
        }
    }

    private func sourceLabel(_ source: HealthDataSource) -> String {
        switch source {
        case .healthKit: return "Apple Health"
        case .computed: return "Vela Engine"
        case .userProvided: return AppLanguage.stored.isChinese ? "用户输入" : "User Provided"
        case .aiEstimated: return AppLanguage.stored.isChinese ? "AI 估计" : "AI Estimated"
        case .wikiProfile: return AppLanguage.stored.isChinese ? "用户档案" : "Wiki Profile"
        case .biomarkerLab: return AppLanguage.stored.isChinese ? "实验室指标" : "Lab"
        }
    }

}
