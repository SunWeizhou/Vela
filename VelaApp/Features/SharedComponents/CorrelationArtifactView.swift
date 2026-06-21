import SwiftUI

struct CorrelationArtifactView: View {
    let key: String

    private var parsedMetrics: (x: String, y: String) {
        let parts = key.lowercased().components(separatedBy: "_vs_")
        guard parts.count == 2 else { return ("health_signal", "journal_tag") }
        return (parts[0], parts[1])
    }

    private func colorForMetric(_ metric: String) -> Color {
        switch metric {
        case "hrv", "recovery", "recovery_score":
            return VelaTheme.recovery
        case "sleep", "sleep_score", "sleep_hours":
            return VelaTheme.sleep
        case "strain", "strain_score", "steps":
            return VelaTheme.strain
        case "stress", "stress_index", "alcohol", "late_meal":
            return VelaTheme.stress
        case "energy", "energy_bank", "caffeine":
            return VelaTheme.energy
        default:
            return VelaTheme.accent
        }
    }

    private func displayNameForMetric(_ metric: String) -> String {
        switch metric {
        case "hrv": return L10n.t("HRV", "HRV（心率变异性）")
        case "caffeine": return L10n.t("Caffeine", "咖啡因")
        case "sleep", "sleep_score": return L10n.t("Sleep Score", "睡眠分数")
        case "sleep_hours": return L10n.t("Sleep Duration", "睡眠时长")
        case "meditation": return L10n.t("Meditation", "正念冥想")
        case "alcohol": return L10n.t("Alcohol", "酒精摄入")
        case "steps": return L10n.t("Steps", "步数")
        case "resting_hr", "rhr": return L10n.t("Resting HR", "静息心率")
        case "stress", "stress_index": return L10n.t("Stress Index", "压力指数")
        case "recovery", "recovery_score": return L10n.t("Recovery Score", "恢复分数")
        case "vitamin_d": return L10n.t("Vitamin D", "维生素 D")
        case "cortisol": return L10n.t("Cortisol", "皮质醇")
        case "health_signal": return L10n.t("Health signal", "健康信号")
        case "journal_tag": return L10n.t("Journal record", "随手记记录")
        default: return metric.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var body: some View {
        let metrics = parsedMetrics

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text("行为关联检查")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text("尚未生成可验证的统计结果")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.mutedText)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                metricPill(displayNameForMetric(metrics.x), color: colorForMetric(metrics.x))
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                metricPill(displayNameForMetric(metrics.y), color: colorForMetric(metrics.y))
            }

            Text("关联分析需要同一日期的行为记录与健康数据配对计算。当前卡片未携带原始样本、样本量或统计检验，因此不会展示趋势图、相关系数或因果结论。")
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.secondaryText)
                .lineSpacing(3)

            Label("即使后续出现关联，也应结合样本量、生活变化和身体感受解读，不能据此认定因果。", systemImage: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(VelaTheme.mutedText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .fill(VelaTheme.cardBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .stroke(VelaTheme.stroke, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("行为关联检查，尚未生成可验证的统计结果")
    }

    private func metricPill(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.10)))
    }
}
