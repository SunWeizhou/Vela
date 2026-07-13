import SwiftUI

struct EvidenceItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let detail: String
}

struct MetricEvidenceSection: View {
    let isSleep: Bool
    let items: [EvidenceItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("数据依据")
                    .font(VelaTheme.footnote())
                    .fontWeight(.bold)
                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                    .padding(.leading, 4)

                Text("用于解释当前指标的原始读数与评分组成")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(VelaTheme.subheadline().weight(.semibold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(item.detail)
                                .font(VelaTheme.caption1())
                                .foregroundStyle(VelaTheme.muted)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        Text(item.value)
                            .font(VelaTheme.headline().monospacedDigit())
                            .foregroundStyle(VelaTheme.fg)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if index < items.count - 1 {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
            )
        }
    }
}
