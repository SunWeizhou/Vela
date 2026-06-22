import SwiftUI

struct TodayHeroCard: View {
    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void

    private var hasRecoveryScore: Bool {
        recoveryScoreText != "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("今日训练状态")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VelaTheme.muted)

                    Text(model.hero.decisionTitle)
                        .font(.system(size: 21, weight: .bold))
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

                if hasRecoveryScore {
                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(recoveryScoreText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.fg)
                            .monospacedDigit()
                        Text("恢复评分")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }

            Rectangle()
                .fill(accent.opacity(0.22))
                .frame(height: 1)

            Text(model.hero.summary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(2)
                .lineLimit(2)

            HStack(spacing: 10) {
                ForEach(model.evidenceChips.prefix(3), id: \.self) { chip in
                    Label(localizedReason(chip), systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(VelaTheme.fg2)
                }
            }
            .lineLimit(1)

            Button {
                onPrimaryAction()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: primaryActionIcon)
                    Text(model.hero.primaryActionTitle)
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(accent))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
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
