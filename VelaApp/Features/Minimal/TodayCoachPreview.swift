import SwiftUI

struct TodayCoachPreview: View {
    let model: TodayExperienceModel
    let onQuestion: (String) -> Void

    private var prompts: [TodayCoachPrompt] {
        [
            TodayCoachPrompt(
                id: "explain",
                label: "为什么这样安排",
                icon: "questionmark.circle",
                question: "请解释今天「\(model.hero.decisionTitle)」的主要依据，指出最关键的身体信号，并说明判断的不确定性。"
            ),
            TodayCoachPrompt(
                id: "training",
                label: "调整今日训练",
                icon: "figure.strengthtraining.traditional",
                question: "请根据今天的身体状态，把「\(model.hero.primaryActionTitle)」细化成热身、主项、训练量和强度上限。"
            ),
            TodayCoachPrompt(
                id: "sleep",
                label: "规划今晚睡眠",
                icon: "moon.zzz",
                question: "请结合今天的恢复、睡眠、负荷、压力和能量，为今晚制定一个简洁的睡眠与恢复计划。"
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(VelaTheme.accent.opacity(0.12))
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Vela 教练 · 今日解读")
                        .font(VelaTheme.headline().weight(.bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("已读取今日身体状态与训练决策")
                        .font(VelaTheme.caption2())
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer(minLength: 8)

                Image(systemName: "checkmark.seal.fill")
                    .font(VelaTheme.subheadline())
                    .foregroundStyle(VelaTheme.success)
                    .accessibilityLabel("上下文已同步")
            }

            Text(model.coachPreview)
                .font(VelaTheme.subheadline())
                .foregroundStyle(VelaTheme.fg2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if !model.evidenceChips.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 7) {
                        ForEach(Array(model.evidenceChips.prefix(4)), id: \.self) { evidence in
                            Label(localizedReason(evidence), systemImage: "waveform.path.ecg")
                                .font(VelaTheme.caption2().weight(.semibold))
                                .foregroundStyle(VelaTheme.fg2)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(VelaTheme.fillSoft, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Divider()

            Text("继续问 Vela")
                .font(VelaTheme.caption1().weight(.bold))
                .foregroundStyle(VelaTheme.muted)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(prompts) { prompt in
                        Button {
                            onQuestion(prompt.question)
                        } label: {
                            Label(prompt.label, systemImage: prompt.icon)
                                .font(VelaTheme.footnote().weight(.semibold))
                                .foregroundStyle(VelaTheme.fg)
                                .padding(.horizontal, 12)
                                .frame(height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                                        .fill(VelaTheme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: VelaTheme.radiusMd, style: .continuous)
                                        .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.cardPress)
                    }
                }
            }
            .scrollIndicators(.hidden)

            Button {
                onQuestion(
                    "请根据今天全部可用数据，先总结身体状态，再确认训练建议，并给出今天最重要的三个行动。"
                )
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("进入完整教练对话")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(VelaTheme.subheadline().weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VelaTheme.accent)
                )
            }
            .buttonStyle(.cardPress)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .fill(VelaTheme.cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.radiusCardLarge, style: .continuous)
                .stroke(VelaTheme.accent.opacity(0.16), lineWidth: 0.75)
        )
    }
}

private struct TodayCoachPrompt: Identifiable {
    let id: String
    let label: String
    let icon: String
    let question: String
}
