import SwiftUI

struct TodayHeroCard: View {
    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日训练状态")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)

                    Text(model.hero.decisionTitle)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(model.hero.confidenceLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(accent)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(recoveryScoreText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                        .monospacedDigit()
                    Text("恢复评分")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)
                }
            }

            Rectangle()
                .fill(accent.opacity(0.22))
                .frame(height: 1)

            Text(model.hero.summary)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(3)
                .lineLimit(3)

            HStack(spacing: 8) {
                ForEach(model.evidenceChips.prefix(3), id: \.self) { chip in
                    Text(localizedReason(chip))
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(VelaTheme.fg2)
                }
            }

            Button {
                onPrimaryAction()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: primaryActionIcon)
                    Text(model.hero.primaryActionTitle)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(accent.opacity(0.22), lineWidth: 0.8)
        )
    }
}
