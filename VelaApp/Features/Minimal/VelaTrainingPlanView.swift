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
            VStack(alignment: .leading, spacing: 30) {
                planHero

                VStack(alignment: .leading, spacing: 14) {
                    VelaRhythmSectionHeader(
                        eyebrow: "FLEXIBLE ROTATION",
                        title: "训练轮转",
                        actionTitle: nil,
                        action: {}
                    )
                    planRows
                }

                adaptationSection
                coachActions
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 16)
            .padding(.bottom, 44)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("训练计划")
        .velaRhythmDetailChrome()
    }

    private var planHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 7) {
                Circle()
                    .fill(VelaTheme.rhythmDeep)
                    .frame(width: 7, height: 7)
                Text("LIVING PLAN")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            Text(activePlan?.title ?? "建立可调整的训练轮转")
                .font(.system(size: 32, weight: .semibold))
                .tracking(-0.8)
                .foregroundStyle(VelaTheme.rhythmInk)
                .fixedSize(horizontal: false, vertical: true)

            Text(planSummary)
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(3)

            HStack(spacing: 0) {
                planMetric("已完成", activePlan.map { "\($0.days.filter(\.isCompleted).count)" } ?? "—")
                metricDivider
                planMetric("训练日", activePlan.map { "\($0.days.count)" } ?? "—")
                metricDivider
                planMetric("周期", activePlan.map { "\($0.weeksCount) 周" } ?? "—")
            }
        }
        .padding(.vertical, 10)
        .background(alignment: .topTrailing) {
            RadialGradient(
                colors: [VelaTheme.rhythmGlow.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 170
            )
            .frame(width: 220, height: 190)
            .offset(x: 30, y: -30)
        }
    }

    @ViewBuilder
    private var planRows: some View {
        if let activePlan, !activePlan.days.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(activePlan.days.enumerated()), id: \.element.id) { index, day in
                    planRow(day)
                    if index < activePlan.days.count - 1 {
                        Rectangle()
                            .fill(VelaTheme.rhythmMist)
                            .frame(height: 0.75)
                            .padding(.leading, 59)
                    }
                }
            }
            .padding(.horizontal, 15)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            }
        } else {
            HStack(spacing: 12) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("目前没有活动计划。Vela 可以根据恢复、目标与最近训练建立第一版。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(16)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private func planRow(_ day: TrainingDay) -> some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(day.isCompleted ? VelaTheme.rhythmDeep : VelaTheme.rhythmMist)
                if day.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(day.dayNumber)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInk)
                }
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(day.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(1)

                    if day.isCompleted {
                        Text("已完成")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                    }
                }

                Text(day.description.isEmpty ? "边界会在训练当天根据状态调整" : day.description)
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(day.focus == "rest" ? "恢复" : "\(day.durationMinutes)′")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var adaptationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S ADAPTATION")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.25)
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text("今天如何调整")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInk)
            Text(adaptationText)
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .background(VelaTheme.rhythmMist.opacity(0.72), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var coachActions: some View {
        VStack(spacing: 10) {
            Button {
                VelaAppState.shared.routeToCoach(question: "请根据我最新的恢复、睡眠、局部疲劳和训练负荷，提出未来一周训练轮转的调整方案；修改前先让我确认。")
            } label: {
                Label("和 Vela 调整计划", systemImage: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeepOn)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(VelaTheme.rhythmDeep, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.cardPress)

            Text("Vela 只提出方案；任何影响后续安排的修改都由你确认。")
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var planSummary: String {
        guard let activePlan else {
            return "计划不是日历任务，而是背、胸、肩、腿与小肌群之间可移动的下一站。"
        }
        if !activePlan.goalDescription.isEmpty { return activePlan.goalDescription }
        return "保留训练方向，同时允许恢复、科研压力与临时有氧改变当天落点。"
    }

    private var adaptationText: String {
        let recovery = dashboardVM.dashboard.recovery.score
        if recovery >= 70 {
            return "当前恢复支持保留计划方向。训练时按 Apple Watch 记录，容量与强度仍以身体边界为准。"
        }
        return "恢复信号偏弱。建议保留训练习惯但降低容量，或换到疲劳更低的部位；如精神压力明显，恢复也算完成计划。"
    }

    private func planMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(VelaTheme.rhythmMist)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 12)
    }
}
