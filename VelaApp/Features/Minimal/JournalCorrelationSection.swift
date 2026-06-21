import SwiftUI
import SwiftData

struct JournalCorrelationSection: View {
    let bodyModelState: BodyModelState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("行为信号与待验证区域")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.muted)

            if bodyModelState.maturity.overall == .seed || bodyModelState.uncertainAreas.contains(where: { $0.id == "behavior_pairs" }) {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 24))
                        .foregroundStyle(VelaTheme.muted)
                    Text("行为-结果配对仍在积累")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                    Text("继续用「随手记」记录酒精、咖啡因、晚餐时间、吃撑、补水等低摩擦信号。Vela 会先积累样本，再把它们和次日睡眠、HRV、RHR、恢复进行配对。")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                    bodyModelStatsRow(bodyModelState)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
            } else {
                VStack(spacing: 12) {
                    bodyModelStatsRow(bodyModelState)
                    ForEach(bodyModelState.claims) { claim in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(claim.title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(claim.summary)
                                .font(.system(size: 12))
                                .foregroundStyle(VelaTheme.muted)
                                .lineSpacing(3)
                            Text("置信度 \(displayConfidence(claim.confidence.rawValue)) · n=\(claim.evidenceCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(confidenceColor(claim.confidence))
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(VelaTheme.borderSoft, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private func bodyModelStatsRow(_ state: BodyModelState) -> some View {
        HStack(spacing: 8) {
            detailStat("基线", "\(state.maturity.baselineDays)天")
            detailStat("行为", "\(state.maturity.behaviorPairs)条")
            detailStat("训练", "\(state.maturity.trainingSessions)次")
        }
        .padding(.horizontal, 12)
    }

    private func detailStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VelaTheme.secondaryGroupedBackground))
    }

    private func confidenceColor(_ conf: DataConfidence) -> Color {
        switch conf {
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
