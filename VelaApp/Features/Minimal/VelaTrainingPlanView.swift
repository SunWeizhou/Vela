import SwiftUI
import SwiftData

struct VelaTrainingPlanView: View {
    @Query(sort: \TrainingPlanRecord.updatedAt, order: .reverse)
    private var plans: [TrainingPlanRecord]
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: \.isActive) ?? plans.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                planHero
                planRows

                VelaMakeCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("调整建议")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .systemIndigo))
                        Text(adaptationText)
                            .font(.system(size: 14))
                            .foregroundStyle(VelaTheme.fg)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        VelaAppState.shared.routeToCoach(question: "请根据我最新的恢复、睡眠和训练负荷重新生成未来一周训练计划。")
                    } label: {
                        Text("重新生成")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(VelaTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        VelaAppState.shared.routeToTab(VelaAppState.coachTabIndex)
                    } label: {
                        Text("打开教练页")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VelaTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(VelaTheme.cardBg)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(VelaTheme.systemGroupedBackground)
        .navigationTitle("训练计划")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var planHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("本周计划 · 由 Vela 生成", systemImage: "sparkles")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
            Text(activePlan?.title ?? "尚未生成训练计划")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text(activePlan.map { "\($0.days.filter(\.isCompleted).count) / \($0.days.count) 天已完成" } ?? "Vela 会结合恢复、目标和最近训练生成计划。")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [VelaTheme.accent, Color(uiColor: .systemIndigo)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var planRows: some View {
        if let activePlan, !activePlan.days.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(activePlan.days.enumerated()), id: \.element.id) { index, day in
                    HStack(spacing: 12) {
                        VStack(spacing: 1) {
                            Text("第 \(day.dayNumber) 天")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.white.opacity(0.86))
                            Text(day.isCompleted ? "完成" : "\(day.durationMinutes)′")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 52, height: 52)
                        .background(day.isCompleted ? VelaTheme.success : VelaTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(day.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(day.description.isEmpty ? "目标负荷会根据当日恢复调整" : day.description)
                                .font(.system(size: 13))
                                .foregroundStyle(VelaTheme.fg2)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    if index < activePlan.days.count - 1 {
                        Divider().padding(.leading, 78)
                    }
                }
            }
            .background(VelaTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            VelaMakeCard {
                Text("目前没有活动计划。点击「重新生成」让 Coach 创建。")
                    .font(.system(size: 15))
                    .foregroundStyle(VelaTheme.fg2)
            }
        }
    }

    private var adaptationText: String {
        let recovery = dashboardVM.dashboard.recovery.score
        if recovery >= 70 {
            return "当前恢复状态支持按计划执行；训练后记录 RPE，Vela 会据此调整下一节。"
        }
        return "当前恢复偏低，建议降低容量或改为 Zone 1–2 恢复训练。"
    }
}
