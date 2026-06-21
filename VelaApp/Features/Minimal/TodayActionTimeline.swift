import SwiftUI

struct TodayActionTimeline: View {
    let model: TodayExperienceModel
    let accent: Color
    let onAction: (TodayExperienceAction) -> Void
    let onEvidenceClick: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("今日行动")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Button {
                    onEvidenceClick()
                } label: {
                    HStack(spacing: 4) {
                        Text("证据")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 0) {
                ForEach(Array(model.actions.enumerated()), id: \.element.id) { index, action in
                    Button {
                        onAction(action)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(action.isPrimary ? accent : VelaTheme.border)
                                    .frame(width: 10, height: 10)
                                if index < model.actions.count - 1 {
                                    Rectangle()
                                        .fill(VelaTheme.borderSoft)
                                        .frame(width: 1, height: 42)
                                }
                            }
                            .padding(.top, 5)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.title)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text(action.detail)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VelaTheme.fg2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VelaTheme.muted)
                                .padding(.top, 4)
                        }
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
