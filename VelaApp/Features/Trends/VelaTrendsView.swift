import SwiftUI
import SwiftData

private struct ScoreTrendDescriptor: Identifiable {
    let metric: CoreHealthMetric
    let detail: VelaMetricDetailView.MetricType
    let title: String
    let icon: String

    var id: String { metric.rawValue }
}

// MARK: - VelaTrendsView — five scored time series first, raw vitals second

struct VelaTrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared

    @State private var selectedHorizon: HealthTrendHorizon = .thirtyDays
    @State private var selectedMetricForDetail: VelaMetricDetailView.MetricType?
    @State private var showAllMetricCatalog = false
    @State private var dailyRecords: [DailyHealthSummaryRecord] = []
    @State private var memoizedScoreHistories: [CoreHealthMetric: [Double]] = [:]
    @State private var memoizedNormalizedHistories: [CoreHealthMetric: [Double]] = [:]

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

    private var scoreDescriptors: [ScoreTrendDescriptor] {
        [
            .init(metric: .recovery, detail: .recovery, title: "恢复", icon: "heart.circle.fill"),
            .init(metric: .sleepScore, detail: .sleep, title: "睡眠", icon: "moon.stars.fill"),
            .init(metric: .strain, detail: .strain, title: "负荷", icon: "figure.run"),
            .init(metric: .stress, detail: .stress, title: "压力", icon: "waveform.path.ecg"),
            .init(metric: .energy, detail: .energy, title: "能量", icon: "bolt.fill")
        ]
    }

    private var scoreMetrics: Set<CoreHealthMetric> {
        Set(scoreDescriptors.map(\.metric))
    }

    private var notableScoreShifts: [HealthTrendFinding] {
        horizonNotableShifts.filter { scoreMetrics.contains($0.metric) }
    }

    private var hasAnyScoreHistory: Bool {
        scoreDescriptors.contains { descriptor in
            scoreHistory(for: descriptor.metric).count >= 2
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: VelaTheme.sectionGap) {
                horizonPicker
                fiveScoreTrendSection

                if !hasAnyScoreHistory && scoreDescriptors.allSatisfy({ finding(for: $0.metric)?.isAvailable != true }) {
                    compactCalibrationCard
                } else {
                    if !notableScoreShifts.isEmpty {
                        notableShiftsSection
                    }
                    compactAgentObservation
                }

                metricCatalogDisclosure
                if showAllMetricCatalog {
                    groupedMetricBrowserSection
                }

                if selectedHorizon != .threeYears {
                    threeYearTrajectoryCard
                }

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
        .onAppear(perform: loadDailyRecords)
        .onChange(of: dashboardVM.selectedDate) { _, _ in loadDailyRecords() }
        .onChange(of: appState.localDataRevision) { _, _ in loadDailyRecords() }
        .onChange(of: selectedHorizon) { _, _ in recomputeMemoizedHistories() }
        .sheet(item: $selectedMetricForDetail) { metric in
            NavigationStack {
                VelaMetricDetailView(metric: metric)
            }
            .environmentObject(dashboardVM)
            .presentationDetents([.large])
            .velaSheetSurface()
        }
    }

    // MARK: - Five scored time series

    private var fiveScoreTrendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("身体状态")
                            .font(VelaTheme.headline())
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Text(selectedHorizon.detailedTitle)
                            .font(VelaTheme.caption1().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("身体状态")
                            .font(VelaTheme.headline())
                            .foregroundStyle(VelaTheme.rhythmInk)
                        Spacer()
                        Text(selectedHorizon.detailedTitle)
                            .font(VelaTheme.caption1().weight(.semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(scoreDescriptors.enumerated()), id: \.element.id) { index, descriptor in
                    scoreTrendRow(descriptor)
                    if index < scoreDescriptors.count - 1 {
                        Divider()
                            .overlay(VelaTheme.rhythmMist)
                            .padding(.leading, 52)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .fill(VelaTheme.rhythmCanvasRaised)
            )
            .overlay {
                RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                    .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
            }
            .shadow(color: VelaTheme.cardShadow(colorScheme), radius: 14, x: 0, y: 6)
        }
    }

    private func scoreTrendRow(_ descriptor: ScoreTrendDescriptor) -> some View {
        let finding = finding(for: descriptor.metric)
        let values = memoizedScoreHistories[descriptor.metric] ?? scoreHistory(for: descriptor.metric)
        let normalized = memoizedNormalizedHistories[descriptor.metric] ?? normalizedHistory(values)
        let color = scoreColor(for: descriptor.metric)
        let valueText = scoreValueText(descriptor: descriptor, finding: finding, values: values)

        return Button {
            selectedMetricForDetail = descriptor.detail
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            scoreTrendIcon(descriptor, color: color)

                            Text(descriptor.title)
                                .font(VelaTheme.subheadline().weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            if finding?.isNotable == true {
                                Circle()
                                    .fill(VelaTheme.stressColor)
                                    .frame(width: 7, height: 7)
                                    .accessibilityHidden(true)
                            }

                            Spacer(minLength: 8)

                            Text(valueText)
                                .font(.system(.headline, design: .rounded, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(valueText == "--" ? VelaTheme.muted : VelaTheme.rhythmInk)

                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.55))
                        }

                        Text(scoreTrendCaption(finding: finding, sampleCount: values.count))
                            .font(VelaTheme.caption2())
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if normalized.count >= 2 {
                            SparklineLineGraph(
                                data: normalized,
                                color: color,
                                height: 42,
                                width: 220
                            )
                            .accessibilityHidden(true)
                        } else {
                            Capsule()
                                .fill(VelaTheme.rhythmMist)
                                .frame(maxWidth: .infinity)
                                .frame(height: 2)
                                .accessibilityHidden(true)
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        scoreTrendIcon(descriptor, color: color)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(descriptor.title)
                                    .font(VelaTheme.subheadline().weight(.semibold))
                                    .foregroundStyle(VelaTheme.rhythmInk)
                                if finding?.isNotable == true {
                                    Circle()
                                        .fill(VelaTheme.stressColor)
                                        .frame(width: 7, height: 7)
                                        .accessibilityHidden(true)
                                }
                            }

                            Text(scoreTrendCaption(finding: finding, sampleCount: values.count))
                                .font(VelaTheme.caption2())
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 4)

                        if normalized.count >= 2 {
                            SparklineLineGraph(
                                data: normalized,
                                color: color,
                                height: 34,
                                width: 88
                            )
                            .accessibilityHidden(true)
                        } else {
                            Capsule()
                                .fill(VelaTheme.rhythmMist)
                                .frame(width: 88, height: 2)
                                .accessibilityHidden(true)
                        }

                        Text(valueText)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(valueText == "--" ? VelaTheme.muted : VelaTheme.rhythmInk)
                            .frame(minWidth: 38, alignment: .trailing)

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.55))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scoreAccessibilityLabel(descriptor: descriptor, finding: finding, values: values))
        .accessibilityHint("打开\(descriptor.title)详情")
    }

    private func scoreTrendIcon(
        _ descriptor: ScoreTrendDescriptor,
        color: Color
    ) -> some View {
        Image(systemName: descriptor.icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(color.opacity(0.10), in: Circle())
    }

    private var compactCalibrationCard: some View {
        NavigationLink(destination: HistoricalBackfillView()) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmDeep)
                Text("同步或回填健康数据，建立个人趋势")
                    .font(VelaTheme.footnote().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(14)
            .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.cardPress)
    }

    @ViewBuilder
    private var compactAgentObservation: some View {
        if let brief = healthBrief, !brief.subheadline.isEmpty {
            Button {
                appState.routeToCoach(question: selectedHorizonCoachQuestion, surface: .trends)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(VelaTheme.rhythmDeep)
                    Text(brief.subheadline)
                        .font(VelaTheme.footnote())
                        .foregroundStyle(VelaTheme.rhythmInk)
                        .lineLimit(2)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.rhythmInkSecondary)
                }
                .padding(14)
                .background(VelaTheme.rhythmMist.opacity(0.42), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.cardPress)
        }
    }

    private var metricCatalogDisclosure: some View {
        Button {
            withAnimation(.snappy(duration: 0.24)) {
                showAllMetricCatalog.toggle()
            }
            VelaHaptic.selection()
        } label: {
            HStack {
                Text("更多健康指标")
                    .font(VelaTheme.callout().weight(.semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                Image(systemName: showAllMetricCatalog ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(showAllMetricCatalog ? "已展开" : "已收起")
    }

    private func finding(for metric: CoreHealthMetric) -> HealthTrendFinding? {
        allTrends.first { $0.metric == metric && $0.horizon == selectedHorizon }
    }

    private func scoreHistory(for metric: CoreHealthMetric) -> [Double] {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let start = calendar.date(byAdding: .day, value: -selectedHorizon.windowDays, to: end) ?? end

        return dailyRecords
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }
            .compactMap { record in
                switch metric {
                case .recovery: record.recoveryScore
                case .sleepScore: record.sleepScore
                case .strain: record.strainScore
                case .stress: record.stressIndex
                case .energy: record.currentEnergy ?? record.energyBank ?? record.morningEnergy
                default: nil
                }
            }
    }

    private func normalizedHistory(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        let sampled = downsample(values, maximumCount: 72)
        guard let minimum = sampled.min(), let maximum = sampled.max() else { return [] }
        let distance = maximum - minimum
        guard distance > 0 else { return sampled.map { _ in 0.5 } }
        return sampled.map { ($0 - minimum) / distance }
    }

    private func downsample(_ values: [Double], maximumCount: Int) -> [Double] {
        guard values.count > maximumCount else { return values }
        let bucketSize = Double(values.count) / Double(maximumCount)
        return (0..<maximumCount).compactMap { bucket in
            let lower = Int((Double(bucket) * bucketSize).rounded(.down))
            let upper = min(values.count, Int((Double(bucket + 1) * bucketSize).rounded(.down)))
            guard lower < upper else { return nil }
            let slice = values[lower..<upper]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func scoreValueText(
        descriptor: ScoreTrendDescriptor,
        finding: HealthTrendFinding?,
        values: [Double]
    ) -> String {
        let value = finding?.isAvailable == true
            ? finding?.currentValue
            : currentScoreValue(for: descriptor.metric)
        guard let value else { return "--" }
        let rounded = Int(value.rounded())
        return descriptor.metric == .energy ? "\(rounded)%" : "\(rounded)"
    }

    private func scoreTrendCaption(finding: HealthTrendFinding?, sampleCount: Int) -> String {
        guard let finding, finding.isAvailable else {
            if sampleCount >= selectedHorizon.requiredSampleCount {
                return "\(sampleCount) 天记录"
            }
            return "\(sampleCount)/\(selectedHorizon.requiredSampleCount) 天"
        }
        if finding.isNotable { return "偏离个人基线" }
        if let baseline = finding.baselineValue {
            return "基线 \(Int(baseline.rounded())) · \(finding.valueDirection.label)"
        }
        return "\(finding.sampleCount) 天 · \(finding.valueDirection.label)"
    }

    private func scoreAccessibilityLabel(
        descriptor: ScoreTrendDescriptor,
        finding: HealthTrendFinding?,
        values: [Double]
    ) -> String {
        let value = scoreValueText(descriptor: descriptor, finding: finding, values: values)
        let state = scoreTrendCaption(finding: finding, sampleCount: values.count)
        return "\(descriptor.title)，\(value)，\(state)"
    }

    private func currentScoreValue(for metric: CoreHealthMetric) -> Double? {
        switch metric {
        case .recovery: return dashboard.recovery.hasData ? dashboard.recovery.value : nil
        case .sleepScore: return dashboard.sleepScore.hasData ? dashboard.sleepScore.value : nil
        case .strain: return dashboard.strain.hasData ? dashboard.strain.value : nil
        case .stress: return dashboard.stress.hasData ? dashboard.stress.value : nil
        case .energy: return dashboard.energy.hasData ? dashboard.energy.value : nil
        default: return nil
        }
    }

    private func scoreColor(for metric: CoreHealthMetric) -> Color {
        switch metric {
        case .recovery: return VelaTheme.recoveryColor
        case .sleepScore: return VelaTheme.sleepColor
        case .strain: return VelaTheme.strainColor
        case .stress: return VelaTheme.stressColor
        case .energy: return VelaTheme.energyColor
        default: return VelaTheme.rhythmDeep
        }
    }

    private func loadDailyRecords() {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let start = calendar.date(byAdding: .day, value: -HealthTrendHorizon.threeYears.windowDays, to: end) ?? end
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        dailyRecords = (try? modelContext.fetch(descriptor)) ?? []
        recomputeMemoizedHistories()
    }

    private func recomputeMemoizedHistories() {
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: dashboardVM.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let start = calendar.date(byAdding: .day, value: -selectedHorizon.windowDays, to: end) ?? end

        let filtered = dailyRecords
            .filter { $0.date >= start && $0.date < end }
            .sorted { $0.date < $1.date }

        var histories: [CoreHealthMetric: [Double]] = [:]
        var normalized: [CoreHealthMetric: [Double]] = [:]

        for metric in scoreMetrics {
            let values: [Double] = filtered.compactMap { record in
                switch metric {
                case .recovery: record.recoveryScore
                case .sleepScore: record.sleepScore
                case .strain: record.strainScore
                case .stress: record.stressIndex
                case .energy: record.currentEnergy ?? record.energyBank ?? record.morningEnergy
                default: nil
                }
            }
            histories[metric] = values
            normalized[metric] = normalizedHistory(values)
        }

        memoizedScoreHistories = histories
        memoizedNormalizedHistories = normalized
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
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text("趋势时间范围")
                                .font(VelaTheme.subheadline().weight(.semibold))
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(VelaTheme.caption1().weight(.semibold))
                        }
                        Text(selectedHorizon.detailedTitle)
                            .font(VelaTheme.subheadline())
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
                let shifts = Array(notableScoreShifts.prefix(3))
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
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            browserMetricIcon(metric)
                            Text(metric.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInk)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                        }

                        Text(finding?.isAvailable == true
                             ? (finding?.summary ?? "")
                             : "需至少 \(selectedHorizon.requiredSampleCount) 天，当前 \(finding?.sampleCount ?? 0) 天")
                            .font(VelaTheme.footnote())
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
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
                    }
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        browserMetricIcon(metric)

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
                                .lineLimit(2)
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
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: VelaTheme.minimumHitTarget, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cardPress)
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开指标详情")
    }

    private func browserMetricIcon(_ metric: CoreHealthMetric) -> some View {
        Image(systemName: metric.icon)
            .font(.body.weight(.semibold))
            .foregroundStyle(accentColor(for: metric))
            .frame(width: 32, height: 32)
            .background(VelaTheme.rhythmMist.opacity(0.72), in: Circle())
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
            appState.routeToCoach(question: selectedHorizonCoachQuestion, surface: .trends)
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
        case .sleepDuration, .sleepScore: return .sleep
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
        case .sleepDuration, .sleepScore: return VelaTheme.sleepColor
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
