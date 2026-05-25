import Charts
import SwiftUI
import SwiftData

struct TrainingView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \TrainingPlanRecord.createdAt, order: .reverse)
    private var plans: [TrainingPlanRecord]

    private var activePlan: TrainingPlanRecord? {
        plans.first(where: { $0.isActive })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        trainingHeader
                        trainingReadinessHero
                        trainingQuickActions
                        TrainingCalendarView()
                    }
                    .padding(VelaTheme.screenPadding)
                    .padding(.bottom, 96)
                }
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadFitnessActivityHistory(modelContext: modelContext)
        }
    }

    private var trainingHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Training", "训练"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(activePlan?.title ?? L10n.t("Adaptive plan workspace", "自适应训练计划"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Create or update my training plan based on today's recovery, sleep, strain target, and goals in my Wiki.",
                    "请基于今天的恢复、睡眠、负荷目标和 Wiki 里的目标，创建或更新我的训练计划。"
                ))
            } label: {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var trainingReadinessHero: some View {
        HStack(alignment: .center, spacing: 18) {
            ArcProgressView(
                score: viewModel.dashboard.strain.score,
                tint: VelaTheme.strain,
                recommendedRange: viewModel.dashboard.strain.recommendedRange,
                size: 122,
                lineWidth: 10
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Today's Training Window", "今日训练窗口"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)

                    Text(targetRangeText)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 8) {
                    trainingSignalPill(
                        title: L10n.t("Recovery", "恢复"),
                        value: viewModel.dashboard.recovery.hasData ? "\(Int(viewModel.dashboard.recovery.score))" : "--",
                        tint: VelaTheme.recovery
                    )
                    trainingSignalPill(
                        title: L10n.t("Sleep", "睡眠"),
                        value: viewModel.dashboard.sleepSummary.sleepScore.map { "\(Int($0))" } ?? "--",
                        tint: VelaTheme.sleep
                    )
                }

                Text(trainingReadinessCopy)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.strain)
    }

    private var trainingQuickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            trainingActionTile(
                title: L10n.t("Generate Plan", "生成计划"),
                subtitle: L10n.t("7-day adaptive block", "7 天自适应周期"),
                icon: "sparkles",
                tint: VelaTheme.accent,
                question: L10n.t(
                    "Generate a 7-day training plan using my current readiness, recent strain, sleep, goals, and constraints. Save it as a training plan if possible.",
                    "请根据我当前准备度、近期负荷、睡眠、目标和限制，生成 7 天训练计划。可以的话保存为训练计划。"
                )
            )

            trainingActionTile(
                title: L10n.t("Adjust Today", "调整今天"),
                subtitle: L10n.t("Session fit check", "检查今日安排"),
                icon: "slider.horizontal.3",
                tint: VelaTheme.recovery,
                question: L10n.t(
                    "Check whether today's training should be progressed, maintained, or reduced. Give one exact session recommendation.",
                    "请判断今天训练应该加量、维持还是降级，并给出一个明确训练建议。"
                )
            )
        }
    }

    private var targetRangeText: String {
        let range = viewModel.dashboard.strain.recommendedRange
        return "\(range.lowerBound)-\(range.upperBound)"
    }

    private var trainingReadinessCopy: String {
        let range = viewModel.dashboard.strain.recommendedRange
        let score = Int(viewModel.dashboard.strain.score)
        if range.contains(score) {
            return L10n.t("Current strain is inside the recommended window. Keep the next session controlled and purposeful.", "当前负荷在建议窗口内。下一次训练保持可控和明确目标。")
        }
        if score > range.upperBound {
            return L10n.t("Current strain is above today's window. Prioritize recovery or low-intensity work.", "当前负荷高于今日窗口。优先恢复或低强度活动。")
        }
        return L10n.t("You still have room in today's window. Choose a session that matches recovery and the active plan.", "今日窗口仍有空间。选择匹配恢复状态和当前计划的训练。")
    }

    private func trainingSignalPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(VelaTheme.mutedText)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(tint.opacity(0.10)))
    }

    private func trainingActionTile(title: String, subtitle: String, icon: String, tint: Color, question: String) -> some View {
        Button {
            VelaAppState.shared.routeToCoach(question: question)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.black.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Strain Hero Section
    private var strainHero: some View {
        HStack(spacing: 20) {
            // Left side: Mini Arc Progress
            ArcProgressView(
                score: viewModel.dashboard.strain.score,
                tint: VelaTheme.strain,
                recommendedRange: viewModel.dashboard.strain.recommendedRange,
                size: 110,
                lineWidth: 10
            )

            // Right side: Optimal strain targets and status
            VStack(alignment: .leading, spacing: 10) {
                // Title/Status Row
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("STRAIN STATUS", "负荷状态"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VelaTheme.mutedText)
                    
                    HStack(spacing: 6) {
                        Text(viewModel.dashboard.strain.hasData ? localizedTarget(viewModel.dashboard.strain.targetStatus) : "--")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        let s = Int(viewModel.dashboard.strain.score)
                        let range = viewModel.dashboard.strain.recommendedRange
                        let pillColor = range.contains(s) ? VelaTheme.recovery : (s > range.upperBound ? VelaTheme.stress : VelaTheme.energy)
                        let pillLabel = range.contains(s) ? L10n.t("Optimal", "最佳") : (s > range.upperBound ? L10n.t("Overreaching", "超负荷") : L10n.t("Recovery Day", "恢复日"))
                        
                        Text(pillLabel)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(pillColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(pillColor.opacity(0.12)))
                    }
                }

                Divider().background(Color.black.opacity(0.08))

                // Target Zone
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("OPTIMAL TARGET ZONE", "建议负荷区间"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VelaTheme.mutedText)
                    
                    let range = viewModel.dashboard.strain.recommendedRange
                    Text("\(range.lowerBound).0 – \(range.upperBound).0")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                }

                Divider().background(Color.black.opacity(0.08))

                // Capacity Gauge
                VStack(alignment: .leading, spacing: 4) {
                    let score = viewModel.dashboard.strain.score
                    let upperBound = Double(viewModel.dashboard.strain.recommendedRange.upperBound)
                    let capacityPct = upperBound > 0 ? min(score / upperBound, 1.2) : 0
                    
                    HStack {
                        Text(L10n.t("CAPACITY LOADED", "负荷已用容量"))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VelaTheme.mutedText)
                        Spacer()
                        Text("\(Int(capacityPct * 100))%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(capacityPct > 1.0 ? VelaTheme.stress : VelaTheme.recovery)
                    }
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.06))
                                .frame(height: 4)
                            
                            Capsule()
                                .fill(capacityPct > 1.0 ? VelaTheme.stress : VelaTheme.strain)
                                .frame(width: geo.size.width * min(capacityPct, 1.0), height: 4)
                                .shadow(color: (capacityPct > 1.0 ? VelaTheme.stress : VelaTheme.strain).opacity(0.3), radius: 2)
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.strain)
    }

    // MARK: - Strain Content Section
    private var strainContent: some View {
        VStack(spacing: 20) {
            // Calculated Scores Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCardMini(
                    title: L10n.t("Energy Load", "能量评分"),
                    value: viewModel.dashboard.strain.components["energy_load_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "bolt.fill",
                    tint: VelaTheme.energy
                )
                metricCardMini(
                    title: L10n.t("Exercise", "运动评分"),
                    value: viewModel.dashboard.strain.components["exercise_duration_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "figure.run",
                    tint: VelaTheme.recovery
                )
                metricCardMini(
                    title: L10n.t("Intensity", "强度评分"),
                    value: viewModel.dashboard.strain.components["workout_intensity_score"]?.formatted(.number.precision(.fractionLength(0))) ?? "--",
                    icon: "flame.fill",
                    tint: VelaTheme.strain
                )
            }
            
            // Raw Indicators Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                metricCardMini(
                    title: L10n.t("Active Burn", "活动消耗"),
                    value: viewModel.dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0)) kcal" } ?? "--",
                    icon: "flame",
                    tint: VelaTheme.strain
                )
                metricCardMini(
                    title: L10n.t("Active Time", "活跃时长"),
                    value: viewModel.dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))m" } ?? "--",
                    icon: "clock.badge.checkmark",
                    tint: VelaTheme.sleep
                )
                metricCardMini(
                    title: L10n.t("Daily Steps", "今日步数"),
                    value: viewModel.dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "--",
                    icon: "shoeprints.fill",
                    tint: VelaTheme.accent
                )
            }

            // 30-Day Trend Chart
            VStack(alignment: .leading, spacing: 12) {
                Label(L10n.t("30-Day Strain Trend", "30 天负荷趋势"), systemImage: "chart.xyaxis.line")
                    .font(.headline)
                    .foregroundStyle(VelaTheme.primaryText)

                if viewModel.strainTrend.isEmpty {
                    Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                } else {
                    Chart(viewModel.strainTrend) { item in
                        AreaMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VelaTheme.strain.opacity(0.2), VelaTheme.strain.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(VelaTheme.strain)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                        
                        PointMark(
                            x: .value("Day", item.date),
                            y: .value("Score", item.value)
                        )
                        .foregroundStyle(VelaTheme.strain)
                        .symbolSize(20)
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .frame(height: 160)
                }
            }
            .cardSurface()

            PlaceholderInsightCard(
                title: L10n.t("Recommended Range", "建议范围"),
                bodyText: L10n.t("Today's target is derived from recovery: \(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound).", "今日目标由恢复状态推导：\(viewModel.dashboard.strain.recommendedRange.lowerBound)-\(viewModel.dashboard.strain.recommendedRange.upperBound)。")
            )

            PlaceholderInsightCard(
                title: L10n.t("Factor Breakdown", "因素拆解"),
                bodyText: viewModel.dashboard.strain.reasons.map(localizedReason).joined(separator: " ")
            )

            PlaceholderInsightCard(
                title: L10n.t("Strain Formula", "负荷评分公式"),
                bodyText: L10n.t(
                    "Strain = 0.40 × EnergyLoad + 0.25 × Duration + 0.35 × WorkoutIntensity.\n\nEnergy Load: TRIMP-inspired (Banister 1991) — log-transformed active calorie burn.\nDuration: workout + movement time (log-mapped).\nWorkout Intensity: HR-based exponential scoring (1 − e^(−0.03×load)).",
                    "负荷 = 0.40 × 能量消耗 + 0.25 × 时长 + 0.35 × 训练强度。\n\n能量消耗：TRIMP 启发式 (Banister 1991) — 活动热量对数变换。\n时长：运动 + 活动时间（对数映射）。\n训练强度：基于心率的指数评分 (1 − e^(−0.03×负荷))。"
                )
            )

            MetricCoachCard(
                dashboard: viewModel.dashboard,
                focus: CoachContextFocus(
                    title: L10n.t("Strain", "负荷"),
                    systemContext: L10n.t(
                        "Analyze today's strain score, active energy, exercise duration, workouts, recovery-adjusted recommended range, and workout readiness.",
                        "分析今日负荷评分、活动能量、锻炼时长、训练记录、由恢复状态调整的建议范围和训练准备度。"
                    )
                )
            )
        }
    }

    // MARK: - Mini Card Helper
    private func metricCardMini(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VelaTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
        )
    }
}
