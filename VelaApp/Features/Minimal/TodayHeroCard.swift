import SwiftUI

struct TodayHeroCard: View {
    let model: TodayExperienceModel
    let recoveryScoreText: String
    let accent: Color
    let primaryActionIcon: String
    let onPrimaryAction: () -> Void
    
    let generatedAt: Date?
    let safetyNotice: String?
    let isStale: Bool
    let confidence: Double

    private var hasRecoveryScore: Bool {
        recoveryScoreText != "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status and Time Header
            HStack {
                if isStale {
                    HStack(spacing: 4) {
                        Circle().fill(Color.red).frame(width: 6, height: 6)
                        Text("已失效，下拉刷新")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.red.opacity(0.08)))
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(VelaTheme.success).frame(width: 6, height: 6)
                        Text("已更新")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VelaTheme.success)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(VelaTheme.success.opacity(0.08)))
                }
                
                Spacer()
                
                if let generatedAt {
                    Text("计划生成时间: \(formattedTime(generatedAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            .padding(.bottom, 2)

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
                        Text("置信度 \(Int((confidence * 100).rounded()))%")
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
            
            if let safetyNotice, !safetyNotice.isEmpty {
                Text(safetyNotice)
                    .font(.system(size: 9))
                    .foregroundStyle(VelaTheme.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
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
    
    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
