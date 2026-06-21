import SwiftUI

struct TodayNutritionStrip: View {
    let nutrition: TodayExperienceNutrition
    let onAddClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("营养")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(nutrition.macroText)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.fg2)
                }
                Spacer()
                Text(nutrition.calorieText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.energyColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(VelaTheme.borderSoft)
                    Capsule()
                        .fill(VelaTheme.energyColor)
                        .frame(width: max(8, proxy.size.width * nutrition.calorieProgress))
                }
            }
            .frame(height: 8)

            HStack(spacing: 10) {
                macroBadge("P", value: nutrition.protein, color: VelaTheme.recoveryColor)
                macroBadge("C", value: nutrition.carbs, color: VelaTheme.sleepColor)
                macroBadge("F", value: nutrition.fat, color: VelaTheme.strainColor)
                Spacer()
                Button {
                    onAddClick()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(VelaTheme.energyColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }

    private func macroBadge(_ label: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 14, height: 14)
                .background(Circle().fill(color.opacity(0.12)))
            Text("\(value)g")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(VelaTheme.surface))
    }
}
