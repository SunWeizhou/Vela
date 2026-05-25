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

                    ForEach(action.whyThis) { item in
                        whyThisCard(item)
                    }
                }
                .padding()
            }
            .background(VelaBackground())
            .navigationTitle(AppLanguage.stored.isChinese ? "判断依据" : "Why This?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppLanguage.stored.isChinese ? "完成" : "Done") {
                        dismiss()
                    }
                }
            }
        }
    }

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
}
