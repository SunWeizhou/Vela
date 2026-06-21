import SwiftUI
import SwiftData

struct JournalTagInsights: View {
    let state: BodyModelState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 8).fill(bodyModelMaturityColor(state.maturity.overall)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("模型成熟度：\(bodyModelMaturityTitle(state.maturity.overall))")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("\(state.maturity.baselineDays) 天基线 · \(state.maturity.behaviorPairs) 条行为信号 · \(state.maturity.trainingSessions) 次训练事实")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
            }

            if !state.claims.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(state.claims.prefix(3)) { claim in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(confidenceColor(claim.confidence))
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(claim.title)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text("\(claim.summary) 置信度：\(displayConfidence(claim.confidence.rawValue))，n=\(claim.evidenceCount)。")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.muted)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
            }

            if !state.uncertainAreas.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("暂不下结论")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                        .textCase(.uppercase)
                    ForEach(state.uncertainAreas.prefix(3)) { area in
                        Text("• \(area.title)：\(area.detail)")
                            .font(.system(size: 11))
                            .foregroundStyle(VelaTheme.muted)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.secondaryGroupedBackground))
    }

    private func bodyModelMaturityTitle(_ level: BodyModelMaturityLevel) -> String {
        switch level {
        case .seed: return "种子期"
        case .learning: return "学习期"
        case .stable: return "稳定期"
        }
    }

    private func bodyModelMaturityColor(_ level: BodyModelMaturityLevel) -> Color {
        switch level {
        case .seed: return Color(hex: "#FF9F0A")
        case .learning: return VelaTheme.accent
        case .stable: return VelaTheme.success
        }
    }

    private func confidenceColor(_ confidence: DataConfidence) -> Color {
        switch confidence {
        case .high: return VelaTheme.success
        case .medium: return VelaTheme.accent
        case .low: return Color.orange
        case .unavailable: return VelaTheme.muted
        }
    }

    private func displayConfidence(_ conf: String) -> String {
        switch conf.lowercased() {
        case "high": return L10n.t("High", "高")
        case "medium": return L10n.t("Medium", "中")
        case "low": return L10n.t("Low", "低")
        case "unavailable": return L10n.t("Unavailable", "不可用")
        default: return conf
        }
    }
}
