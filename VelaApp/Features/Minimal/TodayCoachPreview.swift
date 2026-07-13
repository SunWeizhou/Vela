import SwiftUI

struct TodayCoachPreview: View {
    let model: TodayExperienceModel
    let onClick: () -> Void

    var body: some View {
        Button {
            onClick()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(VelaTheme.accent.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 6) {
                    Text("AI 教练")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text(model.coachPreview)
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.fg2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(VelaTheme.accent.opacity(0.14), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }
}
