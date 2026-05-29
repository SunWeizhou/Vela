import SwiftUI

struct VelaMinimalCoachView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                coachHero
                promptGrid
                contextCard
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var coachHero: some View {
        VelaMinimalGlassPanel(padding: 24, radius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                VelaMinimalSectionTitle(title: L10n.t("Coach", "教练"), subtitle: L10n.t("Personal health intelligence", "个人健康智能"))

                Text(L10n.t("Ask Vela to explain your body.", "让 Vela 解释你的身体状态。"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)

                Text(L10n.t("The coach uses your recovery, sleep, strain, stress, energy, workouts, journal, and personal wiki.", "教练会结合恢复、睡眠、负荷、压力、能量、训练、手记和个人 Wiki。"))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(4)

                Button {
                    VelaAppState.shared.showCoachHub = true
                } label: {
                    Label(L10n.t("Open Coach", "打开教练"), systemImage: "sparkles")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Capsule(style: .continuous).fill(VelaTheme.accent))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var promptGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            promptCard(
                title: L10n.t("Readiness", "准备度"),
                body: L10n.t("Explain today's recovery and what to do.", "解释今天的恢复和行动。"),
                icon: "heart.text.square.fill",
                question: L10n.t(
                    "Explain today's recovery and readiness. Give me the conclusion, the main limiter, and one action.",
                    "请解释今天的恢复和准备度。给我结论、主要限制因素和一个行动。"
                )
            )
            promptCard(
                title: L10n.t("Training", "训练"),
                body: L10n.t("Build a session from current signals.", "基于当前信号生成训练。"),
                icon: "figure.run",
                question: L10n.t(
                    "Build today's training session from my recovery, strain, energy, sleep, and workouts.",
                    "请基于我的恢复、负荷、能量、睡眠和训练记录生成今天的训练。"
                )
            )
            promptCard(
                title: L10n.t("Sleep", "睡眠"),
                body: L10n.t("Find the sleep factor to improve.", "找出睡眠改善点。"),
                icon: "bed.double.fill",
                question: L10n.t(
                    "Analyze my sleep and tell me the one factor that would most improve recovery.",
                    "请分析我的睡眠，并告诉我最能改善恢复的一个因素。"
                )
            )
            promptCard(
                title: L10n.t("Trends", "趋势"),
                body: L10n.t("Summarize what changed recently.", "总结近期变化。"),
                icon: "chart.line.uptrend.xyaxis",
                question: L10n.t(
                    "Summarize my recent health trends and tell me what changed most.",
                    "请总结我近期的健康趋势，并告诉我变化最大的是什么。"
                )
            )
        }
    }

    private var contextCard: some View {
        VelaMinimalGlassPanel(padding: 18, radius: 22) {
            HStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VelaTheme.recovery)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VelaTheme.recovery.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Local-first context", "本地优先上下文"))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Vela sends structured summaries, not raw HealthKit data.", "Vela 发送结构化摘要，不发送原始 HealthKit 数据。"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                }
            }
        }
    }

    private func promptCard(title: String, body: String, icon: String, question: String) -> some View {
        Button {
            VelaAppState.shared.routeToCoach(question: question)
        } label: {
            VelaMinimalGlassPanel(padding: 16, radius: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(body)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            }
        }
        .buttonStyle(.plain)
    }
}

