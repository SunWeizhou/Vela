import SwiftUI
import SwiftData

// MARK: - VelaTrendsView — 3-Tier Multi-Scale Health Trends & Vitals

struct VelaTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared

    @State private var selectedHorizon: HealthTrendHorizon = .thirtyDays
    @State private var selectedMetricForDetail: VelaMetricDetailView.MetricType?
    @State private var showAllMetricCatalog = false

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var healthBrief: PersonalHealthBrief? { dashboard.personalHealthBrief }
    private var allTrends: [HealthTrendFinding] { dashboard.healthTrends }

    private var horizonFindings: [HealthTrendFinding] {
        allTrends.filter { $0.horizon == selectedHorizon }
    }

    private var availableFindings: [HealthTrendFinding] {
        horizonFindings.filter { $0.isAvailable }
    }

    private var horizonNotableShifts: [HealthTrendFinding] {
        availableFindings.filter { $0.isNotable }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VelaTheme.sectionGap) {
                // Horizon Picker (7d / 30d / 6m / 3y)
                horizonPicker

                if availableFindings.isEmpty {
                    // Empty State: Clean single empty view with backfill / sync guidance
                    emptyHorizonStateView
                } else {
                    // Tier 1: 本周期最值得关注的变化 (1–3 Top Notable Shifts or Stable Reassurance)
                    notableShiftsSection

                    // Tier 2: 系统关联解释 (Inter-metric Connections & Grounded Narrative)
                    systemNarrativeSection

                    // Tier 3: 按生理系统分组的完整指标浏览器 (Grouped Metric Browser)
                    groupedMetricBrowserSection
                }

                // Three-Year Long Term Trajectory Entry
                threeYearTrajectoryCard

                // Ask Vela Contextual Analysis
                askVelaTrendCard
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding + 20)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .safeAreaInset(edge: .top, spacing: 0) {
            VelaSurfaceHeader(
                title: "趋势",
                subtitle: "把今天放进更长的时间里看"
            )
            .background(VelaTheme.rhythmCanvas.opacity(0.96))
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $selectedMetricForDetail) { metric in
            NavigationStack {
                VelaMetricDetailView(metric: metric)
            }
            .environmentObject(dashboardVM)
            .presentationDetents([.large])
            .velaSheetSurface()
        }
    }

    // MARK: - Horizon Picker

    private var horizonPicker: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                Menu {
                    ForEach(HealthTrendHorizon.allCases) { horizon in
                        Button {
                            selectedHorizon = horizon
                            VelaHaptic.selection()
                        } label: {
                            Label(horizon.detailedTitle, systemImage: horizon == selectedHorizon ? "checkmark" : "")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("趋势时间范围")
                            .font(VelaTheme.subheadline().weight(.semibold))
                        Spacer(minLength: 8)
                        Text(selectedHorizon.detailedTitle)
                            .font(VelaTheme.subheadline())
                        Image(systemName: "chevron.up.chevron.down")
                            .font(VelaTheme.caption1().weight(.semibold))
                    }
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                    )
                }
                .accessibilityLabel("趋势时间范围")
                .accessibilityValue(selectedHorizon.detailedTitle)
            } else {
                Picker("趋势范围", selection: $selectedHorizon) {
                    ForEach(HealthTrendHorizon.allCases) { horizon in
                        Text(horizon.detailedTitle).tag(horizon)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .accessibilityLabel("趋势时间范围")
        .onChange(of: selectedHorizon) { _, _ in
            VelaHaptic.selection()
        }
    }

    // MARK: - Empty State View

    private var emptyHorizonStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(VelaTheme.rhythmDeep.opacity(0.1))
                    .frame(width: 56, height: 56)
                Image(systemName: "waveform.path.badge.plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text("\(selectedHorizon.detailedTitle) 数据积累中")
                    .font(VelaTheme.headline().weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInk)

                Text("当前周期需要至少 \(selectedHorizon.requiredSampleCount) 天有效记录。继续佩戴 Apple Watch 记录，或在设置中回填历史健康数据。")
                    .font(VelaTheme.body())
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            NavigationLink(destination: HistoricalBackfillView()) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(VelaTheme.footnote().weight(.semibold))
                    Text("前往回填三年 Apple 健康数据")
                        .font(VelaTheme.footnote().weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(VelaTheme.rhythmDeepOn)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(VelaTheme.rhythmDeep))
            }
            .buttonStyle(.cardPress)
            .padding(.bottom, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }

    // MARK: - Tier 1: Notable Shifts Section

    private var notableShiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.badge.plus")
                    .font(VelaTheme.footnote().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("\(selectedHorizon.detailedTitle)关键偏离与变化")
                    .font(VelaTheme.callout().weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }

            if horizonNotableShifts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.brandLeaf)
                    Text("\(selectedHorizon.detailedTitle)各项体征平稳运行在个人基线范围内，未观察到显著偏离。")
                        .font(VelaTheme.body())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            } else {
                let shifts = Array(horizonNotableShifts.prefix(3))
                VStack(spacing: 0) {
                    ForEach(Array(shifts.enumerated()), id: \.offset) { index, finding in
                        notableShiftRow(finding: finding)
                        if index < shifts.count - 1 {
                            Divider()
                                .overlay(VelaTheme.rhythmMist)
                                .padding(.leading, 58)
                        }
                    }
                }
                .velaNativeCard(radius: VelaTheme.radiusLg)
            }
        }
    }

    private func notableShiftRow(finding: HealthTrendFinding) -> some View {
        Button {
            selectedMetricForDetail = detailMetric(for: finding.metric)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: finding.metric.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor(for: finding.metric))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VelaTheme.rhythmMist.opacity(0.8)))

                VStack(alignment: .leading, spacing: 4) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            Text(finding.metric.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Text(finding.currentValueFormatted)
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            Spacer(minLength: 6)
                            trendAssessment(finding)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(finding.metric.title)
                                    .font(.subheadline.weight(.semibold))
                                Text(finding.currentValueFormatted)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                            }
                            trendAssessment(finding)
                        }
                    }

                        Text(finding.summary)
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
        .accessibilityLabel("\(finding.metric.title)，\(finding.currentValueFormatted)，\(finding.assessment.label)。\(finding.summary)")
        .accessibilityHint("打开指标详情")
    }

    private func trendAssessment(_ finding: HealthTrendFinding) -> some View {
        Label(finding.assessment.label, systemImage: finding.valueDirection.icon)
            .font(VelaTheme.footnote().weight(.semibold))
            .foregroundStyle(assessmentColor(for: finding.assessment))
    }

    // MARK: - Tier 2: System Narrative Section

    private var systemNarrativeSection: some View {
        Group {
            if let brief = healthBrief, !brief.possibleDrivers.isEmpty || !brief.subheadline.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                        Text("系统关联观察")
                            .font(VelaTheme.footnote().weight(.bold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                        Spacer()
                    }

                    Text(brief.subheadline)
                        .font(VelaTheme.body().weight(.medium))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !brief.possibleDrivers.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(brief.possibleDrivers, id: \.self) { driver in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(VelaTheme.rhythmDeep.opacity(0.7))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(driver)
                                        .font(VelaTheme.footnote())
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(VelaTheme.rhythmCanvasRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
                )
            }
        }
    }

    // MARK: - Tier 3: Grouped Metric Browser

    private var groupedMetricBrowserSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("生理系统指标浏览")
                .font(VelaTheme.headline())
                .foregroundStyle(VelaTheme.rhythmInk)

            // 1. 心血管与节律
            metricGroup(
                title: "心血管与自主节律",
                metrics: [
                    (.hrv, .hrv),
                    (.restingHeartRate, .rhr),
                    (.respiratoryRate, .respiratoryRate),
                    (.oxygenSaturation, .bloodOxygen)
                ]
            )

            // 2. 睡眠与恢复
            metricGroup(
                title: "睡眠与恢复",
                metrics: [
                    (.sleepDuration, .sleep),
                    (.recovery, .recovery),
                    (.energy, .energy)
                ]
            )

            // 3. 日常负荷与活动
            metricGroup(
                title: "日常负荷与活动",
                metrics: [
                    (.strain, .strain),
                    (.stress, .stress),
                    (.steps, .steps),
                    (.activeCalories, .activeCalories)
                ]
            )

            // 4. 身体组成
            metricGroup(
                title: "身体组成",
                metrics: [
                    (.bodyWeight, .weight),
                    (.bodyFat, .bodyFat)
                ]
            )
        }
    }

    private func metricGroup(
        title: String,
        metrics: [(CoreHealthMetric, VelaMetricDetailView.MetricType)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(VelaTheme.footnote().weight(.semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { index, pair in
                    browserRow(for: pair.0, metricType: pair.1)
                    if index < metrics.count - 1 {
                        Divider()
                            .overlay(VelaTheme.rhythmMist)
                            .padding(.leading, 48)
                    }
                }
            }
            .velaNativeCard(radius: VelaTheme.radiusLg)
        }
    }

    private func browserRow(for metric: CoreHealthMetric, metricType: VelaMetricDetailView.MetricType) -> some View {
        let finding = allTrends.first { $0.metric == metric && $0.horizon == selectedHorizon }

        return Button {
            selectedMetricForDetail = metricType
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: metric.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accentColor(for: metric))
                    .frame(width: 32, height: 32)
                    .background(VelaTheme.rhythmMist.opacity(0.72), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(finding?.isAvailable == true
                         ? (finding?.summary ?? "")
                         : "需至少 \(selectedHorizon.requiredSampleCount) 天，当前 \(finding?.sampleCount ?? 0) 天")
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(finding?.isAvailable == true ? (finding?.currentValueFormatted ?? "--") : "--")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(finding?.isAvailable == true ? VelaTheme.rhythmInk : VelaTheme.muted)
                    if let finding, finding.isAvailable {
                        Image(systemName: finding.valueDirection.icon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(assessmentColor(for: finding.assessment))
                            .accessibilityLabel(finding.assessment.label)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开指标详情")
    }

    // MARK: - Three-Year Trajectory Card

    private var threeYearTrajectoryCard: some View {
        NavigationLink(destination: LongTermHealthTrendView()) {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(VelaTheme.title3().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VelaTheme.rhythmMist.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("三年健康轨迹与基线")
                        .font(VelaTheme.callout().weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("查看长期月均演变与同比分析")
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VelaTheme.rhythmCanvasRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Ask Vela Trend Card

    private var askVelaTrendCard: some View {
        Button {
            appState.routeToCoach(question: selectedHorizonCoachQuestion)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(VelaTheme.body().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)

                VStack(alignment: .leading, spacing: 2) {
                    Text("向 Vela 深入分析\(selectedHorizon.detailedTitle)变化")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("探讨心率、睡眠与压力之间的可能联系")
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VelaTheme.rhythmMist.opacity(0.45))
            )
        }
        .buttonStyle(.cardPress)
        .accessibilityHint("打开 Vela，并带入当前趋势范围与显著变化")
    }

    private var selectedHorizonCoachQuestion: String {
        let notable = horizonNotableShifts.prefix(3).map {
            "\($0.metric.title)：\($0.summary)"
        }
        let evidence = notable.isEmpty
            ? "本周期没有达到显著阈值的变化。"
            : "当前显著变化：" + notable.joined(separator: "；")
        return "请综合分析我\(selectedHorizon.detailedTitle)的身体体征变化，解释值得关注的关联，并给出一个最优先行动。\(evidence)"
    }

    private func detailMetric(for metric: CoreHealthMetric) -> VelaMetricDetailView.MetricType {
        switch metric {
        case .hrv: return .hrv
        case .restingHeartRate: return .rhr
        case .sleepDuration: return .sleep
        case .recovery: return .recovery
        case .strain: return .strain
        case .stress: return .stress
        case .energy: return .energy
        case .respiratoryRate: return .respiratoryRate
        case .oxygenSaturation: return .bloodOxygen
        case .bodyWeight: return .weight
        case .bodyFat: return .bodyFat
        case .steps: return .steps
        case .activeCalories: return .activeCalories
        }
    }

    // MARK: - Helper Colors

    private func accentColor(for metric: CoreHealthMetric) -> Color {
        switch metric {
        case .hrv, .recovery: return VelaTheme.recoveryColor
        case .restingHeartRate, .strain: return VelaTheme.strainColor
        case .sleepDuration: return VelaTheme.sleepColor
        case .stress: return VelaTheme.stressColor
        case .energy: return VelaTheme.energyColor
        case .respiratoryRate, .oxygenSaturation, .bodyWeight, .bodyFat, .steps, .activeCalories:
            return VelaTheme.rhythmDeep
        }
    }

    private func assessmentColor(for assessment: TrendAssessment) -> Color {
        switch assessment {
        case .favorable: return VelaTheme.brandLeaf
        case .unfavorable: return VelaTheme.strainColor
        case .neutral: return VelaTheme.rhythmInkSecondary
        case .insufficientData: return VelaTheme.muted
        }
    }
}
