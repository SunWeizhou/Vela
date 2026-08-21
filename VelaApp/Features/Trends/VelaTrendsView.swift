import SwiftUI
import SwiftData

// MARK: - VelaTrendsView — 3-Tier Multi-Scale Health Trends & Vitals

struct VelaTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared

    @State private var selectedHorizon: HealthTrendHorizon = .thirtyDays
    @State private var selectedMetricForDetail: VelaMetricDetailView.MetricType?

    private var dashboard: DashboardSummary { dashboardVM.dashboard }
    private var healthBrief: PersonalHealthBrief? { dashboard.personalHealthBrief }
    private var allTrends: [HealthTrendFinding] { dashboard.healthTrends }

    private var horizonNotableShifts: [HealthTrendFinding] {
        allTrends.filter { $0.horizon == selectedHorizon && $0.isNotable && $0.isAvailable }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                // Horizon Picker (7d / 30d / 6m / 3y)
                horizonPicker

                // Tier 1: 本周期最值得关注的变化 (1–3 Top Notable Shifts)
                notableShiftsSection

                // Tier 2: 系统关联解释 (Inter-metric Connections & Grounded Narrative)
                systemNarrativeSection

                // Tier 3: 按生理系统分组的完整指标浏览器 (Grouped Metric Browser)
                groupedMetricBrowserSection

                // Three-Year Long Term Trajectory Entry
                threeYearTrajectoryCard

                // Ask Vela Contextual Analysis
                askVelaTrendCard
            }
            .padding(.horizontal, VelaTheme.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding + 20)
        }
        .scrollIndicators(.hidden)
        .background(VelaTheme.rhythmCanvas)
        .navigationTitle("趋势")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    appState.triggerBloodLog = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                }
                .accessibilityLabel("记录健康指标")
            }
        }
        .sheet(item: $selectedMetricForDetail) { metric in
            NavigationStack {
                VelaMetricDetailView(metric: metric)
            }
            .presentationDetents([.large])
            .velaSheetSurface()
        }
    }

    // MARK: - Horizon Picker

    private var horizonPicker: some View {
        HStack(spacing: 8) {
            ForEach(HealthTrendHorizon.allCases) { horizon in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedHorizon = horizon
                    }
                } label: {
                    Text(horizon.detailedTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selectedHorizon == horizon ? VelaTheme.rhythmDeepOn : VelaTheme.rhythmInkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedHorizon == horizon
                                ? AnyView(Capsule().fill(VelaTheme.rhythmDeep))
                                : AnyView(Capsule().fill(VelaTheme.rhythmMist.opacity(0.6)))
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Tier 1: Notable Shifts Section

    private var notableShiftsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform.path.badge.plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("\(selectedHorizon.detailedTitle)关键偏离与变化")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
            }

            if horizonNotableShifts.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(VelaTheme.brandLeaf)
                    Text("\(selectedHorizon.detailedTitle)各项体征平稳运行在个人基线范围内，未观察到显著偏离。")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
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
                VStack(spacing: 8) {
                    ForEach(horizonNotableShifts.prefix(3)) { finding in
                        notableShiftCard(finding: finding)
                    }
                }
            }
        }
    }

    private func notableShiftCard(finding: HealthTrendFinding) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: finding.metric.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accentColor(for: finding.metric))
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(VelaTheme.rhythmMist.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(finding.metric.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text(finding.currentValueFormatted)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    Spacer()
                    Image(systemName: finding.direction.icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(directionColor(for: finding.direction, metric: finding.metric))
                    Text(finding.direction.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(directionColor(for: finding.direction, metric: finding.metric))
                }

                Text(finding.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.rhythmDeep)
                        Spacer()
                    }

                    Text(brief.subheadline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineSpacing(3)

                    if !brief.possibleDrivers.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(brief.possibleDrivers, id: \.self) { driver in
                                HStack(alignment: .top, spacing: 6) {
                                    Circle()
                                        .fill(VelaTheme.rhythmDeep.opacity(0.7))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 6)
                                    Text(driver)
                                        .font(.system(size: 12))
                                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                        .lineSpacing(2)
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
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .padding(.leading, 2)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(metrics, id: \.0.rawValue) { metric, detailType in
                    browserCard(for: metric, metricType: detailType)
                }
            }
        }
    }

    private func browserCard(for metric: CoreHealthMetric, metricType: VelaMetricDetailView.MetricType) -> some View {
        let finding = allTrends.first { $0.metric == metric && $0.horizon == selectedHorizon }

        return Button {
            selectedMetricForDetail = metricType
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: metric.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor(for: metric))
                    Text(metric.shortTitle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Spacer()
                    if let f = finding, f.isAvailable {
                        Image(systemName: f.direction.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(directionColor(for: f.direction, metric: metric))
                    }
                }

                if let f = finding, f.isAvailable {
                    Text(f.currentValueFormatted)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.rhythmInk)

                    Text(f.summary)
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("--")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.muted)

                    Text("需至少 \(selectedHorizon.requiredSampleCount) 天（当前 \(finding?.sampleCount ?? 0) 天）")
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.muted)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VelaTheme.rhythmCanvasRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Three-Year Trajectory Card

    private var threeYearTrajectoryCard: some View {
        NavigationLink(destination: LongTermHealthTrendView()) {
            HStack(spacing: 14) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VelaTheme.rhythmMist.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("三年健康轨迹与基线")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text("查看长期月均演变、季节性波动与个人历史百分位")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
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
            appState.routeToCoach(question: "请综合分析我最近 30 天的身体体征与长期趋势变化，指出哪些变化值得关注，并说明它们之间的可能联系。")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)

                VStack(alignment: .leading, spacing: 2) {
                    Text("向 Vela 深入分析近期变化原因")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaTheme.rhythmInk)
                    Text("探讨心率、睡眠与压力之间的相关性")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VelaTheme.rhythmMist.opacity(0.45))
            )
        }
        .buttonStyle(.plain)
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

    private func directionColor(for direction: HealthTrendDirection, metric: CoreHealthMetric) -> Color {
        switch direction {
        case .improving: return VelaTheme.brandLeaf
        case .declining: return VelaTheme.strainColor
        case .stable: return VelaTheme.muted
        case .elevated: return metric.polarity == .lowerIsBetter ? VelaTheme.strainColor : VelaTheme.brandLeaf
        case .suppressed: return metric.polarity == .higherIsBetter ? VelaTheme.strainColor : VelaTheme.muted
        case .insufficientData: return VelaTheme.muted
        }
    }
}
