import SwiftUI

struct TodayHeroCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void
    
    let generatedAt: Date?
    let safetyNotice: String?
    let isStale: Bool

    private var hasRecoveryScore: Bool {
        recoveryScoreText != "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label(statusTitle, systemImage: statusIcon)
                    .font(VelaTheme.caption2().weight(.semibold))
                    .foregroundStyle(statusColor)
                Spacer()
                if let generatedAt {
                    Text("更新于 \(formattedTime(generatedAt))")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今天建议你")
                        .font(VelaTheme.caption1().weight(.semibold))
                        .foregroundStyle(VelaTheme.muted)

                    Text(model.hero.decisionTitle)
                        .font(VelaTheme.title1())
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 5) {
                        Image(systemName: hasRecoveryScore ? "checkmark.seal.fill" : "info.circle.fill")
                            .font(.caption.weight(.semibold))
                        Text(model.hero.confidenceLabel)
                            .font(VelaTheme.caption1().weight(.semibold))
                    }
                    .foregroundStyle(accent)
                }

                if hasRecoveryScore {
                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(recoveryScoreText)
                            .font(.title.weight(.bold).monospacedDigit())
                            .foregroundStyle(VelaTheme.fg)
                        Text("恢复评分")
                            .font(VelaTheme.caption2())
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }

            Text(model.hero.summary)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(3)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)

            if !model.evidenceChips.isEmpty {
                Text("依据 · " + model.evidenceChips.prefix(2).map(localizedReason).joined(separator: " · "))
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
                    .lineLimit(2)
            }

            Button {
                onPrimaryAction()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: primaryActionIcon)
                    Text(model.hero.primaryActionTitle)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(VelaTheme.headline())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
            
            if let safetyNotice, !safetyNotice.isEmpty {
                Text(safetyNotice)
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft.opacity(0.7), lineWidth: 0.5)
        )
        .accessibilityElement(children: .contain)
    }

    private var statusTitle: String {
        if generatedAt == nil { return "等待健康数据" }
        if isStale { return "建议需要刷新" }
        return "今日建议已更新"
    }

    private var statusIcon: String {
        if generatedAt == nil { return "circle.dotted" }
        if isStale { return "arrow.clockwise" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if generatedAt == nil { return VelaTheme.muted }
        if isStale { return VelaTheme.warn }
        return VelaTheme.recoveryColor
    }
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
