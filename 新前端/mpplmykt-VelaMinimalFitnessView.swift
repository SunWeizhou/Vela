import SwiftData
import SwiftUI

struct VelaMinimalFitnessView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    activityHeatmapCard
                    dailyStrainCard
                    trainingPlanCard
                    recentWorkoutsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
    }

    // MARK: - 1. Activity Heatmap

    private var activityHeatmapCard: some View {
        VelaMinimalGlassPanel(padding: 20, radius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                VelaMinimalSectionTitle(
                    title: L10n.t("30-Day Activity", "30 天活动"),
                    subtitle: L10n.t("Daily strain at a glance", "每日负荷一览")
                )

                let days = Array(viewModel.fitnessActivityHistory.suffix(30))
                if days.isEmpty {
                    heatmapPlaceholder
                } else {
                    activityGrid(days: days)
                    heatmapLegend
                }
            }
        }
    }

    private func activityGrid(days: [FitnessActivityDay]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(heatmapColor(for: day.strainScore))
                        .frame(width: 12, height: 12)
                        .overlay {
                            if isToday {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .stroke(VelaTheme.primary, lineWidth: 1.5)
                            }
                        }
                        .accessibilityLabel(heatmapAccessibilityLabel(for: day, index: index))
                }
            }
        }
    }

    private var heatmapLegend: some View {
        HStack(spacing: 6) {
            Text(L10n.t("Low", "低"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.muted)
            HStack(spacing: 3) {
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(heatmapLevelColor(level))
                        .frame(width: 10, height: 10)
                }
            }
            Text(L10n.t("High", "高"))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.muted)
        }
    }

    private var heatmapPlaceholder: some View {
        HStack(spacing: 4) {
            ForEach(0..<30, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(VelaTheme.outline.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
        .overlay {
            Text(L10n.t("No activity data yet", "暂无活动数据"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.muted)
        }
    }

    private func heatmapColor(for score: Double?) -> Color {
        guard let score else { return VelaTheme.outline.opacity(0.25) }
        switch score {
        case ..<20:  return VelaTheme.quaternaryContainer
        case ..<40:  return VelaTheme.quaternary.opacity(0.3)
        case ..<60:  return VelaTheme.quaternary.opacity(0.55)
        case ..<80:  return VelaTheme.quaternary.opacity(0.78)
        default:     return VelaTheme.quaternary
        }
    }

    private func heatmapLevelColor(_ level: Int) -> Color {
        switch level {
        case 0: return VelaTheme.quaternaryContainer
        case 1: return VelaTheme.quaternary.opacity(0.3)
        case 2: return VelaTheme.quaternary.opacity(0.55)
        case 3: return VelaTheme.quaternary.opacity(0.78)
        default: return VelaTheme.quaternary
        }
    }

    private func heatmapAccessibilityLabel(for day: FitnessActivityDay, index: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let dateStr = formatter.string(from: day.date)
        if let score = day.strainScore {
            return "\(dateStr): \(Int(score))"
        }
        return "\(dateStr): \(L10n.t("No data", "无数据"))"
    }

    // MARK: - 2. Daily Strain

    private var dailyStrainCard: some View {
        let strain = viewModel.dashboard.strain
        let score = strain.hasData ? Int(strain.score.rounded()) : nil
        let range = strain.recommendedRange
        let targetLabel = "\(L10n.t("Target", "目标")) \(range.lowerBound)–\(range.upperBound)"

        return VelaMinimalGlassPanel(padding: 20, radius: 20) {
            HStack(alignment: .top, spacing: 0) {
                accentStrip(color: VelaTheme.strain)
                    .padding(.leading, -20)
                    .padding(.vertical, -20)

                VStack(alignment: .leading, spacing: 16) {
                    VelaMinimalSectionTitle(
                        title: L10n.t("Daily Strain", "每日负荷"),
                        subtitle: L10n.t("Training load score", "训练负荷评分")
                    )
                    .padding(.leading, -4)

                    HStack(spacing: 0) {
                        Spacer()
                        strainRing(score: score, maxScore: 100, tint: VelaTheme.strain)
                        Spacer()
                    }

                    if let score {
                        VStack(alignment: .center, spacing: 6) {
                            VelaMinimalChip(
                                text: targetLabel,
                                systemImage: "target",
                                tint: VelaTheme.strain
                            )
                            Text(strainStatusText(score: score, range: range))
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(L10n.t("Wear your Apple Watch to start tracking strain.", "佩戴 Apple Watch 开始追踪负荷。"))
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(VelaTheme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func strainRing(score: Int?, maxScore: Int, tint: Color) -> some View {
        let fraction = score.map { min(max(CGFloat($0) / CGFloat(maxScore), 0.01), 1.0) } ?? 0
        return ZStack {
            Circle()
                .stroke(VelaTheme.outline.opacity(0.25), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 1.2, bounce: 0.3), value: fraction)

            VStack(spacing: 2) {
                Text(score.map { "\($0)" } ?? "--")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(VelaTheme.onSurface)
                Text(L10n.t("strain", "负荷"))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.muted)
            }
        }
        .frame(width: 90, height: 90)
    }

    private func strainStatusText(score: Int, range: ClosedRange<Int>) -> String {
        if score < range.lowerBound {
            return L10n.t("Below target · Light day", "低于目标 · 轻松日")
        } else if score <= range.upperBound {
            return L10n.t("On track · Optimal load", "达标 · 最佳负荷")
        } else {
            return L10n.t("Above target · Heavy day", "高于目标 · 高强度日")
        }
    }

    // MARK: - 3. Training Plan

    private var trainingPlanCard: some View {
        let plan = DailyPlanEngine.recommendation(for: viewModel.dashboard)
        let workouts = viewModel.dashboard.workouts
        let recentWorkouts = workouts.filter {
            Calendar.current.dateComponents([.day], from: $0.start, to: Date()).day ?? 0 <= 7
        }

        return VelaMinimalGlassPanel(padding: 20, radius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                VelaMinimalSectionTitle(
                    title: L10n.t("This Week", "本周"),
                    subtitle: L10n.t("Training plan & sessions", "训练计划与课程")
                )

                coachPlanRow(plan: plan)

                if !recentWorkouts.isEmpty {
                    Divider().opacity(0.5)

                    ForEach(Array(recentWorkouts.prefix(4).enumerated()), id: \.element.id) { index, workout in
                        trainingSessionRow(
                            workout: workout,
                            status: .completed
                        )
                        if index < min(recentWorkouts.count, 4) - 1 {
                            Divider().padding(.leading, 52).opacity(0.4)
                        }
                    }
                }

                if recentWorkouts.isEmpty {
                    HStack(spacing: 14) {
                        Image(systemName: "figure.run")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(VelaTheme.strain)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(VelaTheme.strain.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.t("No sessions this week", "本周暂无课程"))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(L10n.t("Complete a workout to see it here.", "完成训练后将显示在这里。"))
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(VelaTheme.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private func coachPlanRow(plan: DailyPlanRecommendation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(planAccentColor(plan.accent))
                .frame(width: 36, height: 36)
                .background(Circle().fill(planAccentColor(plan.accent).opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)
                Text(plan.body)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            statusBadge(
                text: L10n.t("Adaptive", "自适应"),
                systemImage: "sparkles",
                tint: VelaTheme.energy,
                background: VelaTheme.senaryContainer
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VelaTheme.surfaceContainerLow.opacity(0.7))
        )
    }

    private func trainingSessionRow(workout: WorkoutSummary, status: TrainingSessionStatus) -> some View {
        HStack(spacing: 12) {
            Image(systemName: status.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(status.tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(status.tint.opacity(0.11)))

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)
                Text(workoutDayLabel(workout.start))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(workoutDurationLabel(workout))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(VelaTheme.secondaryText)
                statusBadge(
                    text: status.label,
                    systemImage: status.badgeIcon,
                    tint: status.tint,
                    background: status.background
                )
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }

    private func statusBadge(text: String, systemImage: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule(style: .continuous).fill(background))
    }

    private func planAccentColor(_ accent: DailyPlanAccent) -> Color {
        switch accent {
        case .recovery: return VelaTheme.recovery
        case .sleep:    return VelaTheme.sleep
        case .strain:   return VelaTheme.strain
        case .energy:   return VelaTheme.energy
        case .stress:   return VelaTheme.stress
        }
    }

    private func workoutDayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return L10n.t("Today", "今天")
        } else if calendar.isDateInYesterday(date) {
            return L10n.t("Yesterday", "昨天")
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func workoutDurationLabel(_ workout: WorkoutSummary) -> String {
        let minutes = max(1, Int(workout.end.timeIntervalSince(workout.start) / 60))
        return "\(minutes) min"
    }

    // MARK: - 4. Recent Workouts

    private var recentWorkoutsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(
                title: L10n.t("Recent Workouts", "最近训练"),
                subtitle: L10n.t("Last 7 days", "过去 7 天")
            )

            VelaMinimalGlassPanel(padding: 0, radius: 20) {
                VStack(spacing: 0) {
                    if viewModel.dashboard.workouts.isEmpty {
                        emptyWorkoutsView
                    } else {
                        let recent = Array(viewModel.dashboard.workouts.prefix(6))
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, workout in
                            recentWorkoutRow(workout)
                            if index < recent.count - 1 {
                                Divider().padding(.leading, 56).opacity(0.4)
                            }
                        }

                        Divider().opacity(0.5)

                        NavigationLink {
                            TrainingView()
                                .environmentObject(viewModel)
                        } label: {
                            HStack {
                                Text(L10n.t("View All", "查看全部"))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(VelaTheme.primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyWorkoutsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.t("No workout logged today", "今天还没有训练记录"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t("Vela will summarize sessions from Apple Health.", "Vela 会从 Apple Health 汇总训练。"))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .padding(18)
    }

    private func recentWorkoutRow(_ workout: WorkoutSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(VelaTheme.strain.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: workoutIcon(for: workout.activityName))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.strain)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)
                Text(workoutDayLabel(workout.start))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Text(workoutDurationLabel(workout))
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func workoutIcon(for activityName: String) -> String {
        let lower = activityName.lowercased()
        if lower.contains("run") || lower.contains("跑步") { return "figure.run" }
        if lower.contains("walk") || lower.contains("步行") { return "figure.walk" }
        if lower.contains("cycle") || lower.contains("骑行") || lower.contains("bike") { return "bicycle" }
        if lower.contains("swim") || lower.contains("游泳") { return "figure.pool.swim" }
        if lower.contains("yoga") || lower.contains("瑜伽") { return "figure.yoga" }
        if lower.contains("strength") || lower.contains("力量") || lower.contains("train") { return "dumbbell.fill" }
        if lower.contains("hiit") { return "figure.highintensity.intervaltraining" }
        return "figure.run"
    }

    // MARK: - Shared Helpers

    private func accentStrip(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(color)
            .frame(width: 4)
    }
}

// MARK: - Training Session Status

private enum TrainingSessionStatus {
    case planned
    case completed
    case adaptive

    var label: String {
        switch self {
        case .planned:   return L10n.t("Planned", "计划中")
        case .completed: return L10n.t("Completed", "已完成")
        case .adaptive:  return L10n.t("Adaptive", "自适应")
        }
    }

    var systemImage: String {
        switch self {
        case .planned:   return "circle.dashed"
        case .completed: return "checkmark.circle.fill"
        case .adaptive:  return "sparkles"
        }
    }

    var badgeIcon: String {
        switch self {
        case .planned:   return "calendar"
        case .completed: return "checkmark"
        case .adaptive:  return "sparkles"
        }
    }

    var tint: Color {
        switch self {
        case .planned:   return VelaTheme.muted
        case .completed: return VelaTheme.recovery
        case .adaptive:  return VelaTheme.energy
        }
    }

    var background: Color {
        switch self {
        case .planned:   return VelaTheme.outline.opacity(0.3)
        case .completed: return VelaTheme.secondaryContainer
        case .adaptive:  return VelaTheme.senaryContainer
        }
    }
}
