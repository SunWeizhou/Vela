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

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title)
                            .font(VelaTheme.caption2())
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)

                        Text(item.value)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Text(item.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                            .lineLimit(2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSleep ? Color.black.opacity(0.22) : Color.white)
                            .shadow(color: Color.black.opacity(isSleep ? 0.0 : 0.012), radius: 6, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSleep ? Color.white.opacity(0.06) : Color(hex: "#E5E5EA"), lineWidth: 0.5)
                    )
                }
            }
        }
    }
}
