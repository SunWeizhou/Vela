import Charts
import SwiftData
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authorizationViewModel = HealthAuthorizationViewModel()
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @State private var heroVisible = false
    @State private var columnsVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                VelaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Compact header
                        headerBar

                        // Loading / Error
                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(VelaTheme.accent)
                                Text(L10n.t("Syncing...", "同步中..."))
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.mutedText)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(VelaTheme.stress)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VelaTheme.stress.opacity(0.10)))
                        }

                        // Hero readiness cockpit
                        readinessCockpit
                            .opacity(heroVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.4), value: heroVisible)

                        // Proactive AI Insights Carousel
                        if viewModel.dashboard.recovery.hasData {
                            let proactiveInsights = ProactiveInsightService.evaluate(dashboard: viewModel.dashboard)
                            if !proactiveInsights.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(L10n.t("Today's AI Insights", "今日 AI 洞察"))
                                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                                        .foregroundStyle(VelaTheme.primaryText)
                                        .padding(.horizontal, 4)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(proactiveInsights) { insight in
                                                Button {
                                                    VelaAppState.shared.prefilledCoachQuestion = insight.coachPresetQuestion
                                                    VelaAppState.shared.selectedTab = 4 // Switch to Coach Tab
                                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                                    generator.impactOccurred()
                                                } label: {
                                                    HStack(alignment: .top, spacing: 12) {
                                                        Image(systemName: insight.severity.icon)
                                                            .font(.title3)
                                                            .foregroundStyle(insight.severity.color)
                                                            .frame(width: 36, height: 36)
                                                            .background(Circle().fill(insight.severity.color.opacity(0.12)))
                                                        
                                                        VStack(alignment: .leading, spacing: 4) {
                                                            Text(insight.title)
                                                                    .font(.subheadline.weight(.semibold))
                                                                    .foregroundStyle(VelaTheme.primaryText)
                                                            
                                                            Text(insight.body)
                                                                .font(.caption)
                                                                .foregroundStyle(VelaTheme.secondaryText)
                                                                .lineLimit(3)
                                                                .multilineTextAlignment(.leading)
                                                            
                                                            if let action = insight.suggestedAction {
                                                                Text("💡 \(action)")
                                                                    .font(.system(size: 11, weight: .medium))
                                                                    .foregroundStyle(VelaTheme.accent)
                                                                    .padding(.top, 2)
                                                            }
                                                        }
                                                    }
                                                    .frame(width: 280, height: 112, alignment: .topLeading)
                                                    .padding(14)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                                                            .fill(VelaTheme.cardBackground)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                                                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                                            )
                                                    )
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }

                        // Streak + weekly comparison
                        if viewModel.streakDays > 0 || viewModel.weeklyRecovery != nil {
                            HStack(spacing: 10) {
                                if viewModel.streakDays > 0 {
                                    streakCard
                                }
                                if let wr = viewModel.weeklyRecovery {
                                    weeklyDeltaCard(wr, label: L10n.t("Recovery", "恢复"), tint: VelaTheme.recovery)
                                }
                            }
                        }

                        // Weekly Snapshot Card
                        if viewModel.weeklySleep != nil || viewModel.weeklyRecovery != nil || viewModel.weeklyHRV != nil || viewModel.weeklyStrain != nil {
                            weeklySnapshotCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Three-column core metrics
                        threeColumnRow
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                        // AI daily insight (upgraded)
                        if !viewModel.dashboard.dailyInsight.isEmpty {
                            upgradedInsightCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Secondary metrics
                        LazyVGrid(columns: [.init(.flexible(), spacing: 12), .init(.flexible(), spacing: 12)], spacing: 12) {
                            NavigationLink {
                                StressDetailView(dashboard: viewModel.dashboard)
                            } label: {
                                CompactHomeMetric(title: L10n.t("Stress", "压力"), value: viewModel.dashboard.stress.hasData ? viewModel.dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))) : "--", detail: viewModel.dashboard.stress.hasData ? L10n.t("\(viewModel.dashboard.stress.band.rawValue) proxy", "\(localizedStressBand(viewModel.dashboard.stress.band)) 代理指标") : L10n.t("No data", "暂无数据"), tint: VelaTheme.stress)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                EnergyBankDetailView(dashboard: viewModel.dashboard)
                            } label: {
                                CompactHomeMetric(title: L10n.t("Energy", "能量"), value: viewModel.dashboard.energy.hasData ? viewModel.dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))) : "--", detail: viewModel.dashboard.energy.hasData ? localizedEnergy(viewModel.dashboard.energy.status) : L10n.t("No data", "暂无数据"), tint: VelaTheme.energy)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                HealthAgeDetailView(dashboard: viewModel.dashboard)
                            } label: {
                                CompactHomeMetric(title: L10n.t("Health Age", "健康年龄趋势"), value: viewModel.dashboard.healthAge.hasData ? localizedHealthAge(viewModel.dashboard.healthAge.label) : "--", detail: "Beta", tint: VelaTheme.accent)
                            }
                            .buttonStyle(.plain)

                            NavigationLink { JournalView() } label: {
                                CompactHomeMetric(title: L10n.t("Journal", "日记"), value: "\(todayJournalCount)", detail: L10n.t("Entries today", "今日记录"), tint: VelaTheme.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }

                        // Heatmap contribution history
                        recoveryHeatmapCard

                        // Apple Health connect
                        healthConnectCard
                    }
                    .padding(VelaTheme.screenPadding)
                }
                .refreshable {
                    await viewModel.refresh(modelContext: modelContext)
                    await viewModel.loadSleepTrend(modelContext: modelContext)
                    await viewModel.loadStrainTrend(modelContext: modelContext)
                    await viewModel.loadRecoveryTrend(modelContext: modelContext)
                    await viewModel.loadHeatmap(modelContext: modelContext)
                    
                    if viewModel.dashboard.recovery.hasData {
                        await MorningBriefScheduler.shared.runIfNeeded(
                            modelContext: modelContext,
                            dashboard: viewModel.dashboard
                        )
                    }
                }
            }
            .navigationTitle("")
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
            await viewModel.loadHeatmap(modelContext: modelContext)
            // Auto agent: evening wiki sync
            await EveningWikiSyncAgent.shared.runIfNeeded(
                modelContext: modelContext,
                dashboard: viewModel.dashboard
            )
            withAnimation(.easeOut(duration: 0.4)) {
                heroVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    columnsVisible = true
                }
            }
            
            // Ensure background refresh is scheduled
            BackgroundTaskManager.schedule()

            // Auto-trigger Morning Brief check and generation
            if viewModel.dashboard.recovery.hasData {
                Task {
                    await MorningBriefScheduler.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: viewModel.dashboard
                    )
                }
            }
        }
    }

    private var todayJournalCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return journalEntries.filter { $0.createdAt >= start }.count
    }

    // MARK: - Subviews

    private var motivationalPhrase: String {
        let score = viewModel.dashboard.recovery.score
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        
        let timeGreeting: String = {
            if hour >= 5 && hour < 11 {
                return AppLanguage.stored.isChinese ? "清晨好！" : "Good morning! "
            } else if hour >= 11 && hour < 14 {
                return AppLanguage.stored.isChinese ? "中午好！" : "Good afternoon! "
            } else if hour >= 14 && hour < 18 {
                return AppLanguage.stored.isChinese ? "下午好！" : "Good afternoon! "
            } else {
                return AppLanguage.stored.isChinese ? "晚安！" : "Good evening! "
            }
        }()
        
        if score >= 80 {
            let options = AppLanguage.stored.isChinese ? [
                "今天身体电力满格，是个突破自我的绝佳时机！🚀",
                "状态拉满！去尽情释放你的潜能与热情吧！🔥",
                "准备度处于巅峰，今天适合安排高强度挑战！💪"
            ] : [
                "Peak physical readiness! Perfect day to break boundaries! 🚀",
                "Energy fully restored! Unleash your full potential! 🔥",
                "Optimal state today. Perfect time for a high-intensity workout! 💪"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        } else if score >= 50 {
            let options = AppLanguage.stored.isChinese ? [
                "状态很稳，稳扎稳打。今天保持节奏继续加油！✨",
                "能量均衡，听从身体的声音，今天也是美好的一天。🍀",
                "恢复良好，保持规律运作，科学训练。🏃‍♂️"
            ] : [
                "Steady readiness. Keep up the rhythm and have a great day! ✨",
                "Balanced energy. Listen to your body and pace yourself. 🍀",
                "Recovery on track. Maintain consistency in your routine. 🏃‍♂️"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        } else {
            let options = AppLanguage.stored.isChinese ? [
                "电量稍微有些低，今天记得对自己温柔一点，多休息。☕️",
                "身体在发出放松信号。适合做些轻量拉伸，早点充电。🛌",
                "蓄力恢复中... 适当的停歇也是为了更好的出发。🍃"
            ] : [
                "Energy is a bit low today. Be gentle with yourself and rest. ☕️",
                "Your body is asking to slow down. Great day for light stretching. 🛌",
                "Recharging... Remember, smart rest is a vital part of progress. 🍃"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            BreathingDot(tint: recoveryBandColor(viewModel.dashboard.recovery.score))
            
            Text(motivationalPhrase)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var readinessCockpit: some View {
        NavigationLink { RecoveryView() } label: {
            HStack(spacing: 20) {
                ScoreRingView(score: viewModel.dashboard.recovery.score, tint: VelaTheme.recovery, size: 110, lineWidth: 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.t("Readiness", "准备度"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(viewModel.dashboard.recovery.hasData
                        ? localizedBand(viewModel.dashboard.recovery.band)
                        : "--")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(viewModel.dashboard.recovery.hasData
                            ? recoveryBandColor(viewModel.dashboard.recovery.score)
                            : VelaTheme.mutedText)

                    Text(viewModel.dashboard.recovery.hasData
                        ? localizedReason(viewModel.dashboard.recovery.reasons.first ?? "")
                        : L10n.t("Connect Apple Health", "请连接 Apple 健康"))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        compactMiniMetric(
                            label: L10n.t("Sleep", "睡眠"),
                            value: viewModel.dashboard.sleepScore.hasData ? "\(Int(viewModel.dashboard.sleepScore.score))" : "--",
                            tint: VelaTheme.sleep
                        )
                        compactMiniMetric(
                            label: L10n.t("Strain", "负荷"),
                            value: viewModel.dashboard.strain.hasData ? "\(Int(viewModel.dashboard.strain.score))" : "--",
                            tint: VelaTheme.strain
                        )
                        compactMiniMetric(
                            label: L10n.t("Stress", "压力"),
                            value: viewModel.dashboard.stress.hasData ? "\(Int(viewModel.dashboard.stress.stressIndex))" : "--",
                            tint: VelaTheme.stress
                        )
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface(accent: VelaTheme.recovery)
        }
        .buttonStyle(.plain)
    }

    private func compactMiniMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(VelaTheme.mutedText)
        }
        .frame(minWidth: 36)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.strain)
                Text(L10n.t("Streak", "连续天数"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
            }
            Text("\(viewModel.streakDays)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t("days of data", "天数据"))
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .cardSurface()
    }

    private func weeklyDeltaCard(_ wc: WeeklyComparison, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: wc.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(wc.isPositive ? VelaTheme.recovery : VelaTheme.stress)
                Text(L10n.t("Weekly", "本周"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
            }
            Text(String(format: "%.0f", wc.thisWeekAvg))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t(
                "\(wc.isPositive ? "+" : "")\(String(format: "%.0f", wc.delta)) vs last week",
                "较上周\(wc.isPositive ? "+" : "")\(String(format: "%.0f", wc.delta))"
            ))
            .font(.caption2)
            .foregroundStyle(wc.isPositive ? VelaTheme.recovery : VelaTheme.stress)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .cardSurface()
    }

    private var weeklySnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.accent)
                Text(L10n.t("Weekly Trends", "本周趋势"))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(L10n.t("This wk → Last wk", "本周 → 上周"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)
            }

            Divider().background(VelaTheme.mutedText.opacity(0.15))

            if let ws = viewModel.weeklySleep {
                weeklyTrendRow(
                    icon: "moon.fill",
                    label: L10n.t("Sleep", "睡眠"),
                    tint: VelaTheme.sleep,
                    comparison: ws,
                    format: { String(format: "%.0f", $0) }
                )
            }

            if let wr = viewModel.weeklyRecovery {
                weeklyTrendRow(
                    icon: "heart.fill",
                    label: L10n.t("Recovery", "恢复"),
                    tint: VelaTheme.recovery,
                    comparison: wr,
                    format: { String(format: "%.0f", $0) }
                )
            }

            if let wh = viewModel.weeklyHRV {
                weeklyTrendRow(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    tint: VelaTheme.accent,
                    comparison: wh,
                    format: { String(format: "%.0f ms", $0) }
                )
            }

            if let wst = viewModel.weeklyStrain {
                weeklyTrendRow(
                    icon: "flame.fill",
                    label: L10n.t("Strain", "负荷"),
                    tint: VelaTheme.strain,
                    comparison: wst,
                    format: { String(format: "%.0f", $0) }
                )
            }
        }
        .cardSurface()
    }

    private func weeklyTrendRow(
        icon: String,
        label: String,
        tint: Color,
        comparison: WeeklyComparison,
        format: (Double) -> String
    ) -> some View {
        let pctDelta: Double = comparison.lastWeekAvg > 0
            ? ((comparison.thisWeekAvg - comparison.lastWeekAvg) / comparison.lastWeekAvg) * 100
            : 0
        let isUp = pctDelta >= 0

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.primaryText)
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Text(format(comparison.thisWeekAvg))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)

                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)

                Text(format(comparison.lastWeekAvg))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            HStack(spacing: 2) {
                Image(systemName: isUp ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%+.0f%%", pctDelta))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isUp ? VelaTheme.recovery : VelaTheme.stress)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isUp ? VelaTheme.recovery.opacity(0.12) : VelaTheme.stress.opacity(0.12))
            )
            .frame(width: 56, alignment: .trailing)
        }
    }

    private var threeColumnRow: some View {
        HStack(spacing: 10) {
            // Sleep card
            NavigationLink { SleepView() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.sleep)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(VelaTheme.sleep.opacity(0.15)))
                        Spacer()
                    }

                    Spacer(minLength: 0)

                    Text(viewModel.dashboard.sleepScore.hasData ? "\(viewModel.dashboard.sleepSummary.totalSleepMinutes / 60)h \(viewModel.dashboard.sleepSummary.totalSleepMinutes % 60)m" : "--")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                    Text(viewModel.dashboard.sleepScore.hasData ? L10n.t("Score \(Int(viewModel.dashboard.sleepScore.score))", "评分 \(Int(viewModel.dashboard.sleepScore.score))") : L10n.t("No data", "暂无数据"))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                        .lineLimit(1)

                    SparklineView(
                        data: viewModel.sleepTrend.map(\.value),
                        tint: VelaTheme.sleep,
                        height: 16
                    )
                }
                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
                .compactCard()
            }
            .buttonStyle(.plain)

            // Strain card
            NavigationLink { StrainView() } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.strain)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(VelaTheme.strain.opacity(0.15)))
                        Spacer()
                    }

                    Spacer(minLength: 0)

                    Text(viewModel.dashboard.strain.hasData ? "\(Int(viewModel.dashboard.strain.score))" : "--")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                    Text(localizedTarget(viewModel.dashboard.strain.targetStatus))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                        .lineLimit(1)

                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(VelaTheme.strain.opacity(0.12))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(VelaTheme.strain)
                                .frame(width: max(CGFloat(viewModel.dashboard.strain.score / 100) * geo.size.width, 4), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(height: 16, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
                .compactCard()
            }
            .buttonStyle(.plain)

            // Energy card
            NavigationLink { EnergyBankDetailView(dashboard: viewModel.dashboard) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "battery.75percent")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.energy)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(VelaTheme.energy.opacity(0.15)))
                        Spacer()
                    }

                    Spacer(minLength: 0)

                    Text(viewModel.dashboard.energy.hasData ? "\(Int(viewModel.dashboard.energy.currentEnergy))" : "--")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .lineLimit(1)
                    Text(viewModel.dashboard.energy.hasData ? localizedEnergy(viewModel.dashboard.energy.status) : L10n.t("No data", "暂无数据"))
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.mutedText)
                        .lineLimit(1)

                    // Mini progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(VelaTheme.energy.opacity(0.12))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(VelaTheme.energy)
                                .frame(width: max(CGFloat(viewModel.dashboard.energy.currentEnergy / 100) * geo.size.width, 4), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(height: 16, alignment: .bottom)
                }
                .frame(maxWidth: .infinity, minHeight: 96, maxHeight: 96, alignment: .leading)
                .compactCard()
            }
            .buttonStyle(.plain)
        }
        .opacity(columnsVisible ? 1 : 0)
    }

    private var upgradedInsightCard: some View {
        NavigationLink { CoachView() } label: {
            HStack(spacing: 14) {
                // Gradient sparkle icon
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [VelaTheme.accent, VelaTheme.sleep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VelaTheme.accent.opacity(0.2), VelaTheme.sleep.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("AI Daily Insight", "AI 今日洞察"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(viewModel.dashboard.dailyInsight)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(3)
                }

                Spacer()

                VStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.accent)

                    Text(L10n.t("Ask Coach", "问教练"))
                        .font(.system(size: 9))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    private var recoveryHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.recovery)
                    Text(L10n.t("Readiness Calendar", "准备度日历"))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                Spacer()
                
                // Show currently selected date formatted
                Text(viewModel.selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.recovery)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(VelaTheme.recovery.opacity(0.12)))
            }
            
            // Heatmap row of squares
            HStack(spacing: 5) {
                ForEach(viewModel.heatmapPoints) { point in
                    let isSelected = Calendar.current.isDate(point.date, inSameDayAs: viewModel.selectedDate)
                    let baseColor = VelaTheme.recovery
                    let opacity: Double = {
                        guard let score = point.score, score > 0 else {
                            return 0.05 // extremely dark gray/transparent for no data
                        }
                        return 0.15 + (score / 100.0) * 0.85 // continuous opacity mapping
                    }()
                    
                    Button {
                        viewModel.selectedDate = point.date
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        Task {
                            await viewModel.refresh(modelContext: modelContext)
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(baseColor.opacity(opacity))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                            .shadow(color: isSelected ? VelaTheme.recovery.opacity(0.4) : Color.clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Heatmap calendar labels
            HStack {
                Text(L10n.t("14d ago", "14天前"))
                Spacer()
                Text(L10n.t("Today", "今天"))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(VelaTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var healthConnectCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(VelaTheme.recovery)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(VelaTheme.recovery.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("Apple Health", "Apple 健康"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(authorizationViewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task {
                    await authorizationViewModel.requestAuthorization()
                    await viewModel.refresh(modelContext: modelContext)
                }
            } label: {
                Label(L10n.t("Connect", "连接"), systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(VelaTheme.recovery)
        }
        .cardSurface()
    }

    private func recoveryBandColor(_ score: Double) -> Color {
        switch score {
        case ..<40: return VelaTheme.stress
        case ..<70: return VelaTheme.energy
        default: return VelaTheme.recovery
        }
    }

}

private struct StressDetailView: View {
    let dashboard: DashboardSummary
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Stress", "压力"),
            subtitle: L10n.t("Physiological proxy", "生理代理指标"),
            hero: {
                HealthMetricCard(
                    title: L10n.t("Stress Index", "压力指数"),
                    value: dashboard.stress.hasData ? dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: dashboard.stress.hasData ? L10n.t("\(dashboard.stress.band.rawValue). \(dashboard.stress.confidence.rawValue) confidence.", "\(localizedStressBand(dashboard.stress.band))。\(localizedConfidence(dashboard.stress.confidence))置信度。") : L10n.t("No stress data available yet.", "暂无压力数据。"),
                    tint: VelaTheme.stress,
                    systemImage: "waveform.path.ecg"
                )
            },
            content: {
                MetricRow(items: dashboard.stress.components.sorted(by: { $0.key < $1.key }).map {
                    .init(title: localizedMetricName($0.key), value: $0.value.formatted(.number.precision(.fractionLength(0))))
                })

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("30-Day Stress Trend", "30 天压力趋势"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    if viewModel.stressTrend.isEmpty {
                        Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
                    } else {
                        Chart(viewModel.stressTrend) { item in
                            AreaMark(
                                x: .value("Day", item.date),
                                y: .value("Index", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [VelaTheme.stress.opacity(0.2), VelaTheme.stress.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", item.date),
                                y: .value("Index", item.value)
                            )
                            .foregroundStyle(VelaTheme.stress)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Day", item.date),
                                y: .value("Index", item.value)
                            )
                            .foregroundStyle(VelaTheme.stress)
                            .symbolSize(20)
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .frame(height: 160)
                    }
                }
                .cardSurface()

                PlaceholderInsightCard(
                    title: L10n.t("Proxy Notice", "代理指标说明"),
                    bodyText: L10n.t("Stress Index is a wellness proxy based on HR, HRV, sleep debt, and recent strain. It is not a medical or mental health diagnosis.", "压力指数是基于心率、HRV、睡眠债和近期负荷的健康代理指标，不是医学或心理健康诊断。")
                )

                PlaceholderInsightCard(
                    title: L10n.t("AI Explanation", "AI 解释"),
                    bodyText: dashboard.stress.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Stress", "压力"),
                        systemContext: L10n.t(
                            "Analyze Stress Index as a physiological proxy using HR, HRV, sleep debt, and recent strain. Avoid diagnosis.",
                            "将压力指数作为生理代理指标分析，结合心率、HRV、睡眠债和近期负荷，避免诊断。"
                        )
                    )
                )
            }
        )
        .task {
            await viewModel.loadStressTrend(modelContext: modelContext)
        }
    }
}

private struct EnergyBankDetailView: View {
    let dashboard: DashboardSummary

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Energy Bank", "能量银行"),
            subtitle: L10n.t("Today", "今日"),
            hero: {
                HealthMetricCard(
                    title: L10n.t("Current Energy", "当前能量"),
                    value: dashboard.energy.hasData ? dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: dashboard.energy.hasData ? localizedEnergy(dashboard.energy.status) : L10n.t("No energy data available yet.", "暂无能量数据。"),
                    tint: VelaTheme.energy,
                    systemImage: "battery.75percent"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Morning", "早晨"), value: dashboard.energy.hasData ? dashboard.energy.morningEnergy.formatted(.number.precision(.fractionLength(0))) : "--"),
                    .init(title: L10n.t("Current", "当前"), value: dashboard.energy.hasData ? dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))) : "--"),
                    .init(title: L10n.t("Confidence", "置信度"), value: localizedConfidence(dashboard.energy.confidence))
                ])

                if dashboard.energy.hasData, !dashboard.energy.components.isEmpty {
                    PlaceholderInsightCard(
                        title: L10n.t("Components", "组成"),
                        bodyText: dashboard.energy.components.sorted(by: { $0.value > $1.value }).map { "\($0.key): \(Int($0.value))" }.joined(separator: " · ")
                    )
                }

                PlaceholderInsightCard(
                    title: L10n.t("Status", "状态"),
                    bodyText: dashboard.energy.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Energy Bank", "能量银行"),
                        systemContext: L10n.t(
                            "Analyze morning energy, current energy, recovery, sleep, strain drains, stress proxy drain, and practical pacing.",
                            "分析早晨能量、当前能量、恢复、睡眠、负荷消耗、压力代理消耗和今日节奏建议。"
                        )
                    )
                )
            }
        )
    }
}

private struct HealthAgeDetailView: View {
    let dashboard: DashboardSummary

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Health Age Trend", "健康年龄趋势"),
            subtitle: "Beta",
            hero: {
                HealthMetricCard(
                    title: L10n.t("Trend", "趋势"),
                    value: dashboard.healthAge.hasData ? localizedHealthAge(dashboard.healthAge.label) : "--",
                    subtitle: dashboard.healthAge.hasData ? L10n.t("Beta trend score \(dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2)))).", "Beta 趋势分 \(dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2))))。") : L10n.t("Not enough data for health age trend.", "数据不足，无法计算健康年龄趋势。"),
                    tint: VelaTheme.accent,
                    systemImage: "arrow.up.forward.heart.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Positive", "正向"), value: "\(dashboard.healthAge.positiveFactors.count)"),
                    .init(title: L10n.t("Negative", "负向"), value: "\(dashboard.healthAge.negativeFactors.count)"),
                    .init(title: L10n.t("Confidence", "置信度"), value: localizedConfidence(dashboard.healthAge.confidence))
                ])

                if dashboard.healthAge.hasData {
                    PlaceholderInsightCard(
                        title: L10n.t("Drivers", "驱动因素"),
                        bodyText: L10n.t(
                            "Positive: \(dashboard.healthAge.positiveFactors.joined(separator: ", ")). Negative: \(dashboard.healthAge.negativeFactors.joined(separator: ", ")).",
                            "正向：\(dashboard.healthAge.positiveFactors.map(localizedMetricName).joined(separator: "、"))。负向：\(dashboard.healthAge.negativeFactors.map(localizedMetricName).joined(separator: "、"))。"
                        )
                    )

                    NavigationLink {
                        BodyView()
                    } label: {
                        Label(L10n.t("View Body Metrics", "查看身体指标"), systemImage: "figure.strengthtraining.traditional")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(VelaTheme.accent)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                    .fill(VelaTheme.accent.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                }

                PlaceholderInsightCard(
                    title: L10n.t("Beta Notice", "Beta 说明"),
                    bodyText: dashboard.healthAge.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Health Age Trend", "健康年龄趋势"),
                        systemContext: L10n.t(
                            "Analyze Health Age Trend beta label, positive and negative drivers. Do not claim biological age.",
                            "分析健康年龄趋势 beta 标签及正负驱动因素，不声称真实生物年龄。"
                        )
                    )
                )
            }
        )
    }
}

private struct CompactHomeMetric: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)

                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
            }

            Text(value)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .cardSurface()
    }
}

// MARK: - BodyView

struct BodyView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Body Metrics", "身体指标"),
            subtitle: L10n.t("Latest readings from Apple Health", "来自 Apple 健康的最新读数"),
            hero: {
                HealthMetricCard(
                    title: L10n.t("VO2 Max", "最大摄氧量"),
                    value: viewModel.dashboard.bodyMetrics.vo2Max.map { String(format: "%.1f", $0) } ?? "--",
                    subtitle: viewModel.dashboard.bodyMetrics.vo2Max.map { vo2MaxInterpretation($0) } ?? L10n.t("No VO2 Max data. Record a brisk walk or run.", "暂无最大摄氧量数据，请记录快走或跑步。"),
                    tint: VelaTheme.recovery,
                    systemImage: "heart.circle.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Weight", "体重"), value: viewModel.dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f", $0) + "kg" } ?? "--"),
                    .init(title: L10n.t("Body Fat", "体脂率"), value: viewModel.dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f", $0) + "%" } ?? "--"),
                    .init(title: L10n.t("Lean Mass", "去脂体重"), value: viewModel.dashboard.bodyMetrics.leanBodyMassKilograms.map { String(format: "%.1f", $0) + "kg" } ?? "--")
                ])

                if let bf = viewModel.dashboard.bodyMetrics.bodyFatPercentage {
                    PlaceholderInsightCard(
                        title: L10n.t("Body Fat", "体脂率"),
                        bodyText: L10n.t(
                            "Body fat \(String(format: "%.1f", bf))% — \(bfCategory(bf)).",
                            "体脂率 \(String(format: "%.1f", bf))% — \(bfCategory(bf))。"
                        )
                    )
                }

                if let weight = viewModel.dashboard.bodyMetrics.weightKilograms,
                   let lean = viewModel.dashboard.bodyMetrics.leanBodyMassKilograms, weight > 0 {
                    let ratio = Int((lean / weight) * 100)
                    PlaceholderInsightCard(
                        title: L10n.t("Body Composition", "身体成分"),
                        bodyText: L10n.t(
                            "Lean body mass is \(ratio)% of total weight (\(String(format: "%.1f", lean))kg). Higher lean mass ratio generally indicates better metabolic health.",
                            "去脂体重占总重量的 \(ratio)%（\(String(format: "%.1f", lean))kg）。较高的去脂体重比例通常表示更好的代谢健康。"
                        )
                    )
                }

                PlaceholderInsightCard(
                    title: L10n.t("About VO2 Max", "关于最大摄氧量"),
                    bodyText: L10n.t(
                        "VO2 Max measures your body's ability to use oxygen during exercise. Higher values indicate better cardiovascular fitness. Apple Watch estimates this during outdoor walks, runs, or hikes.",
                        "最大摄氧量衡量身体在运动中利用氧气的能力。数值越高代表心肺功能越好。Apple Watch 会在户外步行、跑步或徒步时估算此指标。"
                    )
                )

                PlaceholderInsightCard(
                    title: L10n.t("Data Source", "数据来源"),
                    bodyText: L10n.t(
                        "All body metrics are read from Apple Health. Use a smart scale that syncs with Apple Health for automatic weight and body composition updates. Data never leaves your device.",
                        "所有身体指标均从 Apple 健康读取。使用可同步至 Apple 健康的智能秤即可自动更新体重和身体成分数据。数据不会离开你的设备。"
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
        }
    }

    private func vo2MaxInterpretation(_ value: Double) -> String {
        switch value {
        case ..<25: return L10n.t("Low — consider adding cardio", "偏低 — 建议增加有氧运动")
        case ..<35: return L10n.t("Below average", "低于平均水平")
        case ..<45: return L10n.t("Average to good", "中等至良好")
        case ..<55: return L10n.t("Excellent", "优秀")
        default: return L10n.t("Superior — elite level", "卓越 — 精英水平")
        }
    }

    private func bfCategory(_ value: Double) -> String {
        switch value {
        case ..<10: return L10n.t("Low", "偏低")
        case ..<20: return L10n.t("Athletic", "运动员水平")
        case ..<25: return L10n.t("Fit", "健康")
        case ..<32: return L10n.t("Average", "平均水平")
        default: return L10n.t("Above average", "高于平均")
        }
    }
}

// MARK: - HealthAuthorizationViewModel

@MainActor
final class HealthAuthorizationViewModel: ObservableObject {
    @Published var statusText = L10n.t("HealthKit is ready to request read permission.", "HealthKit 已准备好请求读取权限。")

    private let service = HealthAuthorizationService()

    init() {
        let snapshot = service.permissionSnapshot()
        statusText = snapshot.isHealthDataAvailable
            ? L10n.t("Ready to read \(snapshot.requestedReadTypes) HealthKit data types.", "可读取 \(snapshot.requestedReadTypes) 类健康数据。")
            : L10n.t("Health data is unavailable on this device.", "此设备无法使用健康数据。")
    }

    func requestAuthorization() async {
        do {
            try await service.requestAuthorization()
            statusText = L10n.t("Authorization request completed. Data will refresh when available.", "授权请求已完成，可用数据会自动刷新。")
        } catch HealthAuthorizationError.healthDataUnavailable {
            statusText = L10n.t("Health data is unavailable on this device.", "此设备无法使用健康数据。")
        } catch {
            statusText = L10n.t("Could not complete HealthKit authorization.", "无法完成 HealthKit 授权。")
        }
    }
}

struct BreathingDot: View {
    @State private var animate = false
    let tint: Color
    
    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(tint, lineWidth: 2)
                    .scaleEffect(animate ? 2.4 : 1.0)
                    .opacity(animate ? 0.0 : 0.7)
            )
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}
