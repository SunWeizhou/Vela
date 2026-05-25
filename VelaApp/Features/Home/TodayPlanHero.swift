import SwiftUI
import SwiftData

/// Hero card that replaces the top of HomeView with a single-glance daily state summary.
struct TodayPlanHero: View {
    let plan: TodayPlan
    let onActionTap: (DailyAction) -> Void
    let onWhyThisTap: (DailyAction) -> Void

    @State private var expandedActionId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // State banner
            stateBanner

            // Top actions
            VStack(spacing: 8) {
                ForEach(plan.topActions) { action in
                    actionCard(action)
                }

                // Memory inbox teaser
                if plan.confidenceNote.contains("pending") || plan.confidenceNote.contains("待确认") {
                    memoryInboxTeaser
                }
            }
            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .padding(.horizontal, VelaTheme.screenPadding)
    }

    // MARK: - State Banner

    private var stateBanner: some View {
        HStack(spacing: 12) {
            // Emoji + score ring placeholder
            ZStack {
                Circle()
                    .fill(stateColor.opacity(0.12))
                    .frame(width: 56, height: 56)
                Text(plan.state.emoji)
                    .font(.title)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.headline)
                    .font(.headline)
                    .foregroundStyle(VelaTheme.primaryText)
                Text(plan.subheadline)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(stateColor.opacity(0.06))
        )
    }

    // MARK: - Action Card

    private func actionCard(_ action: DailyAction) -> some View {
        let isExpanded = expandedActionId == action.id

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedActionId = isExpanded ? nil : action.id
                }
                onActionTap(action)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: action.iconName)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.accent)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(action.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text(action.subtitle)
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                }
                .padding(12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    MarkdownText(markdown: action.detailMarkdown, font: .caption, color: VelaTheme.secondaryText)

                    if !action.whyThis.isEmpty {
                        Button {
                            onWhyThisTap(action)
                        } label: {
                            Label(
                                AppLanguage.stored.isChinese ? "查看判断依据" : "Why This?",
                                systemImage: "info.circle"
                            )
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.accent)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VelaTheme.elevatedSurface)
        )
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
}

// MARK: - Why This Sheet

struct WhyThisSheet: View {
    let action: DailyAction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(action.title)
                            .font(.headline)
                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()

                    // Evidence Chain 2.0 (preferred)
                    if !action.evidenceChain.isEmpty {
                        ForEach(action.evidenceChain) { item in
                            evidenceChainCard(item)
                        }
                    } else {
                        // Legacy WhyThisItem fallback
                        ForEach(action.whyThis) { item in
                            whyThisCard(item)
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

    private func evidenceChainCard(_ item: EvidenceChainItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Step 1: Metric name + current value + trend
            HStack {
                Image(systemName: iconForCategory(item.metricCategory))
                    .font(.subheadline)
                    .foregroundStyle(colorForCategory(item.metricCategory))
                Text(item.metricName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                freshnessBadge(item.dataFreshness)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLanguage.stored.isChinese ? "当前值" : "Current")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                    Text("\(item.currentValueFormatted) \(item.unit)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                if let baseline = item.baselineFormatted {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppLanguage.stored.isChinese ? "基线" : "Baseline")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                        Text("\(baseline) \(item.unit)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppLanguage.stored.isChinese ? "趋势" : "Trend")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon(item.trend))
                            .font(.caption)
                        Text(trendLabel(item.trend))
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(trendColor(item.trend))
                }
            }

            // Step 2: Interpretation
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.mutedText)
                Text(item.interpretation)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            // Step 3: Action Impact
            if !item.actionImpact.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.energy)
                    Text(item.actionImpact)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.primaryText)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(VelaTheme.energy.opacity(0.08)))
            }

            // Meta: confidence + source
            HStack(spacing: 8) {
                confidenceBadge(item.confidence)
                Text("·")
                    .foregroundStyle(VelaTheme.mutedText)
                Text(item.source == .healthKit ? "Apple Health" : item.source == .computed ? "Vela Engine" : "User Profile")
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.mutedText)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.surface))
    }

    // MARK: - Legacy Why This Card

    private func whyThisCard(_ item: WhyThisItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.metricName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                confidenceBadge(item.confidence)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading) {
                    Text(AppLanguage.stored.isChinese ? "当前值" : "Current")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(item.currentValue)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                }

                if let baseline = item.baselineValue {
                    VStack(alignment: .leading) {
                        Text(AppLanguage.stored.isChinese ? "参考值" : "Reference")
                            .font(.caption2)
                            .foregroundStyle(VelaTheme.mutedText)
                        Text(baseline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                }
            }

            Text(item.interpretation)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VelaTheme.surface)
        )
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

}
