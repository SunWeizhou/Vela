import Charts
import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Vitals", "生命体征"),
            subtitle: L10n.t("Health Monitor", "健康监测"),
            showDateNavigation: false,
            hero: {
                vitalsMonitorHero
            },
            content: {
                vitalsMetricListCard
                biologySnapshotCard
                recoverySignalCard
                physiologyTrendCard

                MetricActionCard(
                    title: L10n.t("Recovery Decision", "今日恢复决策"),
                    bodyText: L10n.t(
                        "Use HRV, resting heart rate, sleep, and prior strain to decide whether today should be a push, maintain, or recovery day.",
                        "结合 HRV、静息心率、睡眠和昨日负荷，判断今天应该推进、维持还是恢复。"
                    ),
                    actionTitle: L10n.t("Decide today's load", "判断今日训练负荷"),
                    systemImage: "heart.text.square.fill",
                    tint: VelaTheme.recovery,
                    coachQuestion: L10n.t(
                        "Based on my recovery, HRV, resting heart rate, sleep, and prior strain, decide if today should be a push day, maintenance day, or recovery day. Give one training recommendation and one recovery action.",
                        "请基于我的恢复、HRV、静息心率、睡眠和昨日负荷，判断今天应该推进、维持还是恢复。给我一个训练建议和一个恢复行动。"
                    )
                )

                MetricCoachCard(
                    dashboard: viewModel.dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Vitals", "生命体征"),
                        systemContext: L10n.t(
                            "Analyze recovery score, HRV, resting heart rate, sleep contribution, prior strain, confidence, and recovery reasons.",
                            "分析恢复评分、HRV、静息心率、睡眠贡献、前一日负荷、置信度和恢复原因。"
                        )
                    ),
                    suggestedQuestion: L10n.t(
                        "Analyze my recovery data. Start with the conclusion, then the main limiting factor, then the single most important action for today.",
                        "请分析我的恢复数据。先给结论，再说明主要限制因素，最后给今天最重要的一步行动。"
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
    }

    private var vitalsMonitorHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                ScoreRingView(
                    score: viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : 0,
                    tint: VelaTheme.recovery,
                    size: 96,
                    lineWidth: 9
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("Health Monitor", "健康监测"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)

                    Text(vitalsHeroCopy)
                        .font(.subheadline)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineSpacing(3)

                    Text(viewModel.dashboard.recovery.hasData ? localizedBand(viewModel.dashboard.recovery.band) : L10n.t("No Data", "暂无数据"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.recovery)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(VelaTheme.recovery.opacity(0.12)))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                vitalsPill(title: "HRV", value: hrvText, tint: VelaTheme.accent)
                vitalsPill(title: L10n.t("RHR", "静息心率"), value: rhrText, tint: VelaTheme.sleep)
                vitalsPill(title: L10n.t("Resp", "呼吸"), value: respiratoryText, tint: VelaTheme.energy)
            }
        }
        .heroCardSurface(accent: VelaTheme.recovery)
    }

    private var vitalsMetricListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Vitals", "生命体征"), systemImage: "heart.text.square")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(L10n.t("Today", "今日"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            VStack(spacing: 0) {
                vitalsMetricRow(
                    title: L10n.t("Recovery", "恢复"),
                    value: viewModel.dashboard.recovery.hasData ? "\(Int(viewModel.dashboard.recovery.score))" : "--",
                    subtitle: viewModel.dashboard.recovery.hasData ? localizedBand(viewModel.dashboard.recovery.band) : L10n.t("Waiting for Health data", "等待健康数据"),
                    icon: "bolt.heart.fill",
                    tint: VelaTheme.recovery
                ) {
                    RecoveryMetricDetailView()
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: "HRV", value: hrvText, subtitle: baselineDeltaText(today: viewModel.dashboard.recoveryMetrics.hrvMilliseconds, baseline: viewModel.dashboard.recoveryBaseline.hrvMilliseconds, unit: "ms", lowerIsBetter: false), icon: "waveform.path.ecg", tint: VelaTheme.accent) {
                    VitalsMetricDetailView(metric: .hrv)
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: L10n.t("Resting Heart Rate", "静息心率"), value: rhrText, subtitle: baselineDeltaText(today: viewModel.dashboard.recoveryMetrics.restingHeartRate, baseline: viewModel.dashboard.recoveryBaseline.restingHeartRate, unit: "bpm", lowerIsBetter: true), icon: "heart.fill", tint: VelaTheme.sleep) {
                    VitalsMetricDetailView(metric: .restingHeartRate)
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: L10n.t("Sleep Heart Rate", "睡眠心率"), value: sleepHeartRateText, subtitle: L10n.t("Overnight cardiovascular signal", "夜间心血管信号"), icon: "bed.double.fill", tint: VelaTheme.energy) {
                    VitalsMetricDetailView(metric: .sleepHeartRate)
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: L10n.t("Respiratory Rate", "呼吸率"), value: respiratoryText, subtitle: L10n.t("Breaths per minute during rest", "休息时每分钟呼吸次数"), icon: "lungs.fill", tint: VelaTheme.recovery) {
                    VitalsMetricDetailView(metric: .respiratoryRate)
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: L10n.t("Blood Oxygen", "血氧"), value: oxygenText, subtitle: L10n.t("Latest HealthKit sample", "最新健康数据样本"), icon: "drop.fill", tint: VelaTheme.accent) {
                    VitalsMetricDetailView(metric: .bloodOxygen)
                        .environmentObject(viewModel)
                }
                vitalsMetricRow(title: L10n.t("Weight", "体重"), value: weightText, subtitle: bodyCompositionText, icon: "scalemass.fill", tint: VelaTheme.mutedText) {
                    VitalsMetricDetailView(metric: .weight)
                        .environmentObject(viewModel)
                }
            }
        }
        .cardSurface()
    }

    private var biologySnapshotCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Biology", "生物特征"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Wearables and body metrics", "可穿戴与身体指标"))
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                }
                Spacer()
                Text(healthAgeTrendLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(healthAgeTrendTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(healthAgeTrendTint.opacity(0.12)))
            }

            HStack(spacing: 8) {
                vitalsPill(title: L10n.t("Trend", "趋势"), value: healthAgeTrendScore, tint: healthAgeTrendTint)
                vitalsPill(title: "VO2 Max", value: vo2MaxText, tint: VelaTheme.recovery)
                vitalsPill(title: L10n.t("Body Fat", "体脂"), value: bodyFatText, tint: VelaTheme.energy)
            }

            NavigationLink {
                BiologyView()
                    .environmentObject(viewModel)
            } label: {
                HStack {
                    Label(L10n.t("Open Biology", "打开生物特征"), systemImage: "chevron.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(VelaTheme.primaryText)
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
        }
        .cardSurface()
    }

    private var recoverySignalCard: some View {
        HStack(spacing: 18) {
            ScoreRingView(
                score: viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : 0,
                tint: VelaTheme.recovery,
                size: 92,
                lineWidth: 8
            )

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("Recovery signals", "恢复信号"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)

                VelaRangeBar(
                    label: "HRV",
                    todayValue: viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
                    baselineValue: viewModel.dashboard.recoveryBaseline.hrvMilliseconds,
                    isLowerBetter: false,
                    unit: "ms"
                )

                VelaRangeBar(
                    label: L10n.t("RHR", "静息心率"),
                    todayValue: viewModel.dashboard.recoveryMetrics.restingHeartRate,
                    baselineValue: viewModel.dashboard.recoveryBaseline.restingHeartRate,
                    isLowerBetter: true,
                    unit: "bpm"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cardSurface()
    }

    private var physiologyTrendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Recovery Trend", "恢复趋势"), systemImage: "chart.xyaxis.line")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            if viewModel.recoveryTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            } else {
                let avg = viewModel.recoveryTrend.map(\.value).reduce(0, +) / Double(max(viewModel.recoveryTrend.count, 1))

                Chart(viewModel.recoveryTrend) { item in
                    BarMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(recoveryBarColor(for: item.value))

                    RuleMark(y: .value("Avg", avg))
                        .foregroundStyle(VelaTheme.mutedText.opacity(0.45))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 140)
            }
        }
        .cardSurface()
    }

    private var vitalsHeroCopy: String {
        L10n.t(
            "Scan recovery, autonomic signals, sleep physiology, and body metrics in one place.",
            "在一个页面扫描恢复、自主神经、睡眠生理和身体指标。"
        )
    }

    private var hrvText: String {
        viewModel.dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--"
    }

    private var rhrText: String {
        viewModel.dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "--"
    }

    private var sleepHeartRateText: String {
        viewModel.dashboard.recoveryMetrics.sleepHeartRate.map { "\(Int($0))bpm" } ?? "--"
    }

    private var respiratoryText: String {
        viewModel.dashboard.recoveryMetrics.respiratoryRate.map { "\(Int($0))/min" } ?? "--"
    }

    private var oxygenText: String {
        viewModel.dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0))%" } ?? "--"
    }

    private var weightText: String {
        viewModel.dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1fkg", $0) } ?? "--"
    }

    private var bodyFatText: String {
        viewModel.dashboard.bodyMetrics.bodyFatPercentage.map { "\(Int($0))%" } ?? "--"
    }

    private var bodyCompositionText: String {
        let bmi = viewModel.dashboard.extendedMetrics.bmi.map { String(format: "BMI %.1f", $0) }
        let lean = viewModel.dashboard.bodyMetrics.leanBodyMassKilograms.map { String(format: "%.1fkg lean", $0) }
        return [bmi, lean].compactMap { $0 }.joined(separator: " · ").isEmpty
            ? L10n.t("Body composition", "身体组成")
            : [bmi, lean].compactMap { $0 }.joined(separator: " · ")
    }

    private var vo2MaxText: String {
        viewModel.dashboard.bodyMetrics.vo2Max.map { "\(Int($0))" } ?? "--"
    }

    private var healthAgeTrendScore: String {
        let score = viewModel.dashboard.healthAge.trendScore
        return score == 0 ? "0.0" : String(format: "%+.1f", score)
    }

    private var healthAgeTrendLabel: String {
        switch viewModel.dashboard.healthAge.label {
        case .improving: return L10n.t("Improving", "改善中")
        case .stable: return L10n.t("Stable", "稳定")
        case .worsening: return L10n.t("Watch", "需关注")
        }
    }

    private var healthAgeTrendTint: Color {
        switch viewModel.dashboard.healthAge.label {
        case .improving: return VelaTheme.recovery
        case .stable: return VelaTheme.energy
        case .worsening: return VelaTheme.stress
        }
    }

    private func baselineDeltaText(today: Double?, baseline: Double?, unit: String, lowerIsBetter: Bool) -> String {
        guard let today, let baseline, baseline > 0 else {
            return L10n.t("28-day baseline pending", "28 天基线待建立")
        }
        let diff = today - baseline
        let isGood = lowerIsBetter ? diff <= 0 : diff >= 0
        let sign = diff >= 0 ? "+" : "-"
        let direction = isGood ? L10n.t("better", "更好") : L10n.t("watch", "关注")
        return "\(sign)\(abs(Int(diff)))\(unit) \(direction)"
    }

    private func vitalsMetricRow<Destination: View>(
        title: String,
        value: String,
        subtitle: String,
        icon: String,
        tint: Color,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                Text(value)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(VelaTheme.stroke)
                    .frame(height: 0.5)
                    .padding(.leading, 42)
            }
        }
        .buttonStyle(.plain)
    }

    private var vitalsSummaryCard: some View {
        let recoveryScore = viewModel.dashboard.recovery.hasData ? "\(Int(viewModel.dashboard.recovery.score))" : "--"
        let hrv = viewModel.dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--"
        let rhr = viewModel.dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "--"
        let band = viewModel.dashboard.recovery.hasData ? localizedBand(viewModel.dashboard.recovery.band) : L10n.t("No Data", "暂无数据")

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.t("Body status", "身体状态"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(band)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.recovery)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(VelaTheme.recovery.opacity(0.12)))
            }

            Text(L10n.t(
                "Recovery, heart rate, and sleep signals are grouped here so Vela can explain whether your system is ready to push or needs protection.",
                "恢复、心率和睡眠信号会在这里汇总，帮助 Vela 判断你今天适合推进还是需要保护。"
            ))
            .font(.subheadline)
            .foregroundStyle(VelaTheme.secondaryText)
            .lineSpacing(3)

            HStack(spacing: 8) {
                vitalsPill(title: L10n.t("Recovery", "恢复"), value: recoveryScore, tint: VelaTheme.recovery)
                vitalsPill(title: "HRV", value: hrv, tint: VelaTheme.accent)
                vitalsPill(title: L10n.t("RHR", "静息心率"), value: rhr, tint: VelaTheme.stress)
            }
        }
        .cardSurface()
    }

    private func vitalsPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaTheme.mutedText)
                .textCase(.uppercase)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private struct FactorCardData: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        let tint: Color
        let todayValue: String
        let baselineValue: String
        let delta: String
        let isPositive: Bool
        let weight: Double
    }

    private var factorCards: [FactorCardData] {
        let weights = viewModel.dashboard.recovery.weights
        let components = viewModel.dashboard.recovery.components
        let totalWeight = weights.values.reduce(0, +)
        guard totalWeight > 0 else { return [] }

        var cards: [FactorCardData] = []

        // HRV
        if let hrvToday = viewModel.dashboard.recoveryMetrics.hrvMilliseconds {
            let baseline = viewModel.dashboard.recoveryBaseline.hrvMilliseconds
            let weight = (weights["hrv"] ?? 0) / totalWeight
            let baselineStr = baseline.map { "\(Int($0))ms" } ?? "--"
            let deltaStr: String
            let isPositive: Bool
            if let bl = baseline, bl > 0 {
                let pct = ((hrvToday - bl) / bl) * 100
                isPositive = pct >= 0
                deltaStr = isPositive ? "↑\(Int(abs(pct)))%" : "↓\(Int(abs(pct)))%"
            } else {
                isPositive = true
                deltaStr = "--"
            }
            cards.append(FactorCardData(
                name: "HRV", icon: "waveform.path.ecg", tint: VelaTheme.recovery,
                todayValue: "\(Int(hrvToday))ms", baselineValue: baselineStr,
                delta: deltaStr, isPositive: isPositive, weight: weight
            ))
        }

        // Resting HR
        if let rhrToday = viewModel.dashboard.recoveryMetrics.restingHeartRate {
            let baseline = viewModel.dashboard.recoveryBaseline.restingHeartRate
            let weight = (weights["rhr"] ?? 0) / totalWeight
            let baselineStr = baseline.map { "\(Int($0))bpm" } ?? "--"
            let deltaStr: String
            let isPositive: Bool
            if let bl = baseline {
                let diff = Int(rhrToday - bl)
                isPositive = diff <= 0
                deltaStr = isPositive ? "↓\(abs(diff))" : "↑\(abs(diff))"
            } else {
                isPositive = true
                deltaStr = "--"
            }
            cards.append(FactorCardData(
                name: L10n.t("Resting HR", "静息心率"), icon: "heart.fill", tint: VelaTheme.sleep,
                todayValue: "\(Int(rhrToday))bpm", baselineValue: baselineStr,
                delta: deltaStr, isPositive: isPositive, weight: weight
            ))
        }

        // Sleep
        if let sleepScore = viewModel.dashboard.sleepSummary.sleepScore {
            let weight = (weights["sleep"] ?? 0) / totalWeight
            cards.append(FactorCardData(
                name: L10n.t("Sleep", "睡眠"), icon: "moon.fill", tint: VelaTheme.accent,
                todayValue: "\(Int(sleepScore))", baselineValue: L10n.t("Score", "评分"),
                delta: "", isPositive: sleepScore >= 70, weight: weight
            ))
        }

        // Prior Strain
        if let strainScore = components["prior_strain"] {
            let weight = (weights["prior_strain"] ?? 0) / totalWeight
            let isPositive = strainScore <= 60
            cards.append(FactorCardData(
                name: L10n.t("Prior Strain", "前日负荷"), icon: "flame.fill", tint: VelaTheme.strain,
                todayValue: "\(Int(strainScore))", baselineValue: L10n.t("Lower is better", "越低越好"),
                delta: isPositive ? "✓" : "!", isPositive: isPositive, weight: weight
            ))
        }

        return cards
    }

    /// Map recovery score to bar color using the same band thresholds as ScoringMath.band(for:)
    private func recoveryBarColor(for score: Double) -> Color {
        switch score {
        case ..<40: return VelaTheme.stress
        case ..<70: return VelaTheme.energy
        default:    return VelaTheme.recovery
        }
    }
}

struct RecoveryMetricDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRange: RecoveryDetailRange = .month

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricHeader
                    DateNavigationBar()
                    hero
                    trendCard
                    baselineCard
                    factorCard
                    decisionCard
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.refresh(modelContext: modelContext)
                await viewModel.loadRecoveryTrend(modelContext: modelContext)
            }
        }
    }

    private var metricHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.t("Recovery", "恢复"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Explain my recovery score, main limiter, and what I should do today.",
                    "请解释我的恢复评分、主要限制因素，以及今天应该做什么。"
                ))
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            ScoreRingView(
                score: viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : 0,
                tint: VelaTheme.recovery,
                size: 136,
                lineWidth: 11
            )

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("Readiness", "准备度"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                    Text(viewModel.dashboard.recovery.hasData ? "\(Int(viewModel.dashboard.recovery.score))" : "--")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                        .monospacedDigit()
                }

                Text(recoveryStatusCopy)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)

                HStack(spacing: 8) {
                    metricPill(title: "HRV", value: hrvText, tint: VelaTheme.accent)
                    metricPill(title: L10n.t("RHR", "静息心率"), value: rhrText, tint: VelaTheme.sleep)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.recovery)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Recovery Trend", "恢复趋势"), systemImage: "chart.xyaxis.line")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                rangeSelector
            }

            if filteredTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more days are saved.", "保存更多天后会显示趋势。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 16)
            } else {
                Chart(filteredTrend) { item in
                    BarMark(
                        x: .value("Day", item.date),
                        y: .value("Score", item.value)
                    )
                    .foregroundStyle(recoveryTint(for: item.value))
                    .cornerRadius(4)

                    RuleMark(y: .value("Good", 70))
                        .foregroundStyle(VelaTheme.recovery.opacity(0.35))
                    RuleMark(y: .value("Low", 40))
                        .foregroundStyle(VelaTheme.energy.opacity(0.35))
                }
                .chartYScale(domain: 0...100)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 160)
            }
        }
        .cardSurface()
    }

    private var baselineCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Baseline Signals", "基线信号"), systemImage: "waveform.path.ecg")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            VelaRangeBar(
                label: "HRV",
                todayValue: viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
                baselineValue: viewModel.dashboard.recoveryBaseline.hrvMilliseconds,
                isLowerBetter: false,
                unit: "ms"
            )

            VelaRangeBar(
                label: L10n.t("Resting HR", "静息心率"),
                todayValue: viewModel.dashboard.recoveryMetrics.restingHeartRate,
                baselineValue: viewModel.dashboard.recoveryBaseline.restingHeartRate,
                isLowerBetter: true,
                unit: "bpm"
            )

            Text(L10n.t(
                "Recovery is scored against your own baseline, not a generic population average.",
                "恢复评分会和你的个人基线比较，而不是只看通用人群平均值。"
            ))
            .font(.caption)
            .foregroundStyle(VelaTheme.secondaryText)
            .lineSpacing(3)
        }
        .cardSurface()
    }

    private var factorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Drivers", "影响因素"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            VStack(spacing: 0) {
                metricRow(title: "HRV", value: hrvText, icon: "waveform.path.ecg", tint: VelaTheme.accent)
                metricRow(title: L10n.t("Resting Heart Rate", "静息心率"), value: rhrText, icon: "heart.fill", tint: VelaTheme.sleep)
                metricRow(title: L10n.t("Sleep Score", "睡眠评分"), value: sleepScoreText, icon: "moon.fill", tint: VelaTheme.recovery)
                metricRow(title: L10n.t("Prior Strain", "前日负荷"), value: priorStrainText, icon: "flame.fill", tint: VelaTheme.strain)
            }
        }
        .cardSurface()
    }

    private var decisionCard: some View {
        MetricActionCard(
            title: L10n.t("Today's Recovery Decision", "今日恢复决策"),
            bodyText: recoveryStatusCopy,
            actionTitle: L10n.t("Ask Vela to decide", "让 Vela 判断"),
            systemImage: "heart.text.square.fill",
            tint: VelaTheme.recovery,
            coachQuestion: L10n.t(
                "Analyze recovery, HRV, resting heart rate, sleep, prior strain, and confidence. Tell me if today is push, maintain, or recovery, with one exact action.",
                "请分析恢复、HRV、静息心率、睡眠、前日负荷和置信度。告诉我今天是推进、维持还是恢复，并给出一个明确行动。"
            )
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(RecoveryDetailRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedRange == range ? VelaTheme.inverseText : VelaTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(selectedRange == range ? VelaTheme.strongControl : VelaTheme.subtleFill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredTrend: [RecoveryTrendPoint] {
        Array(viewModel.recoveryTrend.suffix(selectedRange.days))
    }

    private var hrvText: String {
        viewModel.dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--"
    }

    private var rhrText: String {
        viewModel.dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "--"
    }

    private var sleepScoreText: String {
        viewModel.dashboard.sleepSummary.sleepScore.map { "\(Int($0))" } ?? "--"
    }

    private var priorStrainText: String {
        viewModel.dashboard.recovery.components["prior_strain"].map { "\(Int($0))" } ?? "--"
    }

    private var recoveryStatusCopy: String {
        guard viewModel.dashboard.recovery.hasData else {
            return L10n.t("Connect Apple Health to see recovery, HRV, resting heart rate, and sleep signals.", "连接 Apple 健康后可查看恢复、HRV、静息心率和睡眠信号。")
        }
        let score = viewModel.dashboard.recovery.score
        if score >= 70 {
            return L10n.t("Your system is ready for productive work. Keep intensity aligned with today's strain target.", "身体系统适合推进。把强度控制在今日负荷目标内。")
        }
        if score >= 40 {
            return L10n.t("Recovery is mixed. Maintain routine, avoid heroic intensity, and watch HRV/RHR changes.", "恢复状态一般。保持节奏，避免硬上强度，并关注 HRV/静息心率变化。")
        }
        return L10n.t("Recovery is low. Make today a protection day: lower intensity, hydrate, and protect sleep.", "恢复偏低。今天应以保护为主：降低强度、补水并保护睡眠。")
    }

    private func recoveryTint(for score: Double) -> Color {
        switch score {
        case ..<40: return VelaTheme.stress
        case ..<70: return VelaTheme.energy
        default: return VelaTheme.recovery
        }
    }

    private func metricPill(title: String, value: String, tint: Color) -> some View {
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

    private func metricRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            Spacer()

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VelaTheme.stroke)
                .frame(height: 0.5)
                .padding(.leading, 40)
        }
    }
}

struct VitalsMetricDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var selectedRange: RecoveryDetailRange = .month

    let metric: VitalsMetricDetailKind

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    metricHeader
                    DateNavigationBar()
                    hero
                    trendCard
                    contextCard
                    actionCard
                }
                .padding(VelaTheme.screenPadding)
                .padding(.bottom, 96)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reload()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await reload() }
        }
    }

    private var metricHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: metric.coachQuestion)
            } label: {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 18) {
            ZStack {
                Circle()
                    .fill(metric.tint.opacity(0.14))
                    .frame(width: 120, height: 120)
                Circle()
                    .stroke(metric.tint.opacity(0.28), lineWidth: 10)
                    .frame(width: 120, height: 120)
                Image(systemName: metric.icon)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(metric.tint)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(metric.shortTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)

                Text(metric.valueText(in: viewModel.dashboard))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                Text(metric.statusCopy(in: viewModel.dashboard))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: metric.tint)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Trend", "趋势"), systemImage: "chart.xyaxis.line")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                rangeSelector
            }

            if filteredTrend.isEmpty {
                Text(L10n.t("Trend data will appear after more daily summaries are saved.", "保存更多每日摘要后会显示趋势。"))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 18)
            } else {
                Chart(filteredTrend) { item in
                    LineMark(
                        x: .value("Day", item.date),
                        y: .value(metric.shortTitle, item.value)
                    )
                    .foregroundStyle(metric.tint)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", item.date),
                        y: .value(metric.shortTitle, item.value)
                    )
                    .foregroundStyle(metric.tint)

                    if let baseline = metric.baselineValue(in: viewModel.dashboard) {
                        RuleMark(y: .value("Baseline", baseline))
                            .foregroundStyle(VelaTheme.mutedText.opacity(0.42))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 164)
            }
        }
        .cardSurface()
    }

    private var contextCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.t("Context", "指标背景"), systemImage: "slider.horizontal.3")
                .font(.headline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            if metric.supportsRangeBar {
                VelaRangeBar(
                    label: metric.shortTitle,
                    todayValue: metric.currentValue(in: viewModel.dashboard),
                    baselineValue: metric.baselineValue(in: viewModel.dashboard),
                    isLowerBetter: metric.lowerIsBetter,
                    unit: metric.unit
                )
            }

            contextRow(
                title: L10n.t("Today", "今日"),
                value: metric.valueText(in: viewModel.dashboard),
                icon: metric.icon,
                tint: metric.tint
            )

            contextRow(
                title: L10n.t("Baseline", "基线"),
                value: metric.baselineText(in: viewModel.dashboard),
                icon: "scope",
                tint: VelaTheme.secondaryText
            )

            Text(metric.explanation)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .lineSpacing(3)
        }
        .cardSurface()
    }

    private var actionCard: some View {
        MetricCoachCard(
            dashboard: viewModel.dashboard,
            focus: CoachContextFocus(title: metric.title, systemContext: metric.explanation),
            suggestedQuestion: metric.coachQuestion
        )
    }

    private var rangeSelector: some View {
        HStack(spacing: 4) {
            ForEach(RecoveryDetailRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.title)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(selectedRange == range ? VelaTheme.inverseText : VelaTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule(style: .continuous).fill(selectedRange == range ? VelaTheme.strongControl : VelaTheme.subtleFill))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredTrend: [TrendPoint] {
        Array(viewModel.vitalsTrend.suffix(selectedRange.days))
    }

    private func reload() async {
        await viewModel.refresh(modelContext: modelContext)
        if let trendMetric = metric.trendMetric {
            await viewModel.loadVitalsTrend(metric: trendMetric, modelContext: modelContext)
        }
    }

    private func contextRow(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)

            Spacer()

            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VelaTheme.stroke)
                .frame(height: 0.5)
                .padding(.leading, 40)
        }
    }
}

enum VitalsMetricDetailKind {
    case hrv
    case restingHeartRate
    case sleepHeartRate
    case respiratoryRate
    case bloodOxygen
    case weight
    case steps
    case activeCalories
    case activeMinutes

    var title: String {
        switch self {
        case .hrv: return "HRV"
        case .restingHeartRate: return L10n.t("Resting Heart Rate", "静息心率")
        case .sleepHeartRate: return L10n.t("Sleep Heart Rate", "睡眠心率")
        case .respiratoryRate: return L10n.t("Respiratory Rate", "呼吸率")
        case .bloodOxygen: return L10n.t("Blood Oxygen", "血氧")
        case .weight: return L10n.t("Weight", "体重")
        case .steps: return L10n.t("Daily Steps", "今日步数")
        case .activeCalories: return L10n.t("Active Calories", "活动消耗")
        case .activeMinutes: return L10n.t("Active Minutes", "活跃时长")
        }
    }

    var shortTitle: String {
        switch self {
        case .restingHeartRate: return L10n.t("RHR", "静息心率")
        case .sleepHeartRate: return L10n.t("Sleep HR", "睡眠心率")
        case .respiratoryRate: return L10n.t("Resp", "呼吸")
        case .steps: return L10n.t("Steps", "步数")
        case .activeCalories: return L10n.t("Active Burn", "活动消耗")
        case .activeMinutes: return L10n.t("Active Time", "活跃时长")
        default: return title
        }
    }

    var icon: String {
        switch self {
        case .hrv: return "waveform.path.ecg"
        case .restingHeartRate: return "heart.fill"
        case .sleepHeartRate: return "bed.double.fill"
        case .respiratoryRate: return "lungs.fill"
        case .bloodOxygen: return "drop.fill"
        case .weight: return "scalemass.fill"
        case .steps: return "shoeprints.fill"
        case .activeCalories: return "flame.fill"
        case .activeMinutes: return "clock.badge.checkmark"
        }
    }

    var tint: Color {
        switch self {
        case .hrv, .bloodOxygen, .steps: return VelaTheme.accent
        case .restingHeartRate, .activeMinutes: return VelaTheme.sleep
        case .sleepHeartRate: return VelaTheme.energy
        case .respiratoryRate: return VelaTheme.recovery
        case .weight: return VelaTheme.secondaryText
        case .activeCalories: return VelaTheme.strain
        }
    }

    var unit: String {
        switch self {
        case .hrv: return "ms"
        case .restingHeartRate, .sleepHeartRate: return "bpm"
        case .respiratoryRate: return "/min"
        case .bloodOxygen: return "%"
        case .weight: return "kg"
        case .steps: return ""
        case .activeCalories: return "kcal"
        case .activeMinutes: return "m"
        }
    }

    var lowerIsBetter: Bool {
        switch self {
        case .restingHeartRate, .sleepHeartRate:
            return true
        default:
            return false
        }
    }

    var trendMetric: VitalsTrendMetric? {
        switch self {
        case .hrv: return .hrv
        case .restingHeartRate: return .restingHeartRate
        case .sleepHeartRate: return nil
        case .respiratoryRate: return .respiratoryRate
        case .bloodOxygen: return .bloodOxygen
        case .weight: return .weight
        case .steps: return .steps
        case .activeCalories: return .activeCalories
        case .activeMinutes: return .activeMinutes
        }
    }

    var supportsRangeBar: Bool {
        switch self {
        case .hrv, .restingHeartRate, .respiratoryRate:
            return true
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return false
        }
    }

    var explanation: String {
        switch self {
        case .hrv:
            return L10n.t("HRV is compared to your personal baseline and is one of the strongest recovery drivers.", "HRV 会与个人基线比较，是恢复评分中最重要的信号之一。")
        case .restingHeartRate:
            return L10n.t("Resting heart rate rising above baseline often indicates stress, fatigue, illness, or poor recovery.", "静息心率高于基线通常提示压力、疲劳、疾病风险或恢复不足。")
        case .sleepHeartRate:
            return L10n.t("Sleep heart rate helps reveal overnight cardiovascular load and recovery quality.", "睡眠心率能帮助判断夜间心血管负担 and 恢复质量。")
        case .respiratoryRate:
            return L10n.t("Respiratory rate is useful as a freshness and illness-watch signal when it moves away from baseline.", "呼吸率偏离基线时，可作为状态新鲜度和疾病风险观察信号。")
        case .bloodOxygen:
            return L10n.t("Blood oxygen is a spot signal from HealthKit. Treat isolated readings cautiously and watch repeated changes.", "血氧是来自健康数据的采样信号。单次读数需要谨慎解读，更应关注重复变化。")
        case .weight:
            return L10n.t("Weight is most useful as a trend when combined with body fat, training load, and recovery.", "体重与体脂、训练负荷和恢复结合起来看，趋势价值最高。")
        case .steps:
            return L10n.t("Steps is a direct indicator of daily base movement and general physical activity.", "步数是每日基础活动量和整体身体活跃度的直接指标。")
        case .activeCalories:
            return L10n.t("Active calories measures the energy expended through exercises and movement.", "活动消耗衡量了通过锻炼和日常身体活动消耗的能量。")
        case .activeMinutes:
            return L10n.t("Active minutes represents the total duration spent in moderate-to-vigorous exercise.", "活跃时长代表了中高强度运动的总持续时间。")
        }
    }

    var actionTitle: String {
        switch self {
        case .hrv: return L10n.t("HRV Decision", "HRV 决策")
        case .restingHeartRate: return L10n.t("Heart Rate Decision", "心率决策")
        case .sleepHeartRate: return L10n.t("Overnight Load", "夜间负担")
        case .respiratoryRate: return L10n.t("Respiratory Check", "呼吸检查")
        case .bloodOxygen: return L10n.t("Oxygen Check", "血氧检查")
        case .weight: return L10n.t("Body Trend", "身体趋势")
        case .steps: return L10n.t("Steps Check", "步数检查")
        case .activeCalories: return L10n.t("Calorie Check", "热量消耗检查")
        case .activeMinutes: return L10n.t("Duration Check", "时长检查")
        }
    }

    var coachQuestion: String {
        switch self {
        case .hrv:
            return L10n.t("Analyze my HRV against baseline and tell me what it means for training and recovery today.", "请分析我的 HRV 与基线的关系，并说明它对今天训练和恢复意味着什么。")
        case .restingHeartRate:
            return L10n.t("Analyze my resting heart rate against baseline and decide whether I should push, maintain, or recover today.", "请分析我的静息心率与基线的关系，并判断今天应该推进、维持还是恢复。")
        case .sleepHeartRate:
            return L10n.t("Analyze my sleep heart rate and explain whether overnight recovery looks normal or elevated.", "请分析我的睡眠心率，并说明夜间恢复是否正常或偏高负担。")
        case .respiratoryRate:
            return L10n.t("Analyze my respiratory rate and tell me if there is anything I should watch today.", "请分析我的呼吸率，并告诉我今天是否有需要关注的事项。")
        case .bloodOxygen:
            return L10n.t("Analyze my blood oxygen reading carefully and explain what repeated changes would mean.", "请谨慎分析我的血氧读数，并说明如果连续变化代表什么。")
        case .weight:
            return L10n.t("Analyze my body weight trend with recovery and training context, and suggest one adjustment.", "请结合恢复和训练背景分析我的体重趋势，并给出一个调整建议。")
        case .steps:
            return L10n.t("Analyze my daily steps and active movement, and suggest one improvement.", "请分析我的每日步数和日常活动，并给出一个改善建议。")
        case .activeCalories:
            return L10n.t("Analyze my active calorie burn trend, and suggest one fitness adjustment.", "请分析我的活动消耗趋势，并给出一个健身调整建议。")
        case .activeMinutes:
            return L10n.t("Analyze my active minutes and training duration, and suggest one time-management improvement.", "请分析我的活跃时长和训练持续时间，并给出一个优化时间分配的建议。")
        }
    }

    func currentValue(in dashboard: DashboardSummary) -> Double? {
        switch self {
        case .hrv:
            return dashboard.recoveryMetrics.hrvMilliseconds
        case .restingHeartRate:
            return dashboard.recoveryMetrics.restingHeartRate
        case .sleepHeartRate:
            return dashboard.recoveryMetrics.sleepHeartRate
        case .respiratoryRate:
            return dashboard.recoveryMetrics.respiratoryRate
        case .bloodOxygen:
            return dashboard.extendedMetrics.oxygenSaturation
        case .weight:
            return dashboard.bodyMetrics.weightKilograms
        case .steps:
            return dashboard.strain.metrics["steps_raw"]
        case .activeCalories:
            return dashboard.strain.metrics["active_energy_raw"]
        case .activeMinutes:
            return dashboard.strain.metrics["exercise_minutes_raw"]
        }
    }

    func baselineValue(in dashboard: DashboardSummary) -> Double? {
        switch self {
        case .hrv:
            return dashboard.recoveryBaseline.hrvMilliseconds
        case .restingHeartRate:
            return dashboard.recoveryBaseline.restingHeartRate
        case .respiratoryRate:
            return dashboard.recoveryBaseline.respiratoryRate
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return nil
        }
    }

    func valueText(in dashboard: DashboardSummary) -> String {
        guard let value = currentValue(in: dashboard) else { return "--" }
        switch self {
        case .weight:
            return String(format: "%.1fkg", value)
        case .bloodOxygen:
            return "\(Int(value))%"
        case .respiratoryRate:
            return "\(Int(value))/min"
        case .hrv:
            return "\(Int(value))ms"
        case .restingHeartRate, .sleepHeartRate:
            return "\(Int(value))bpm"
        case .steps:
            return "\(Int(value))"
        case .activeCalories:
            return "\(Int(value)) kcal"
        case .activeMinutes:
            return "\(Int(value))m"
        }
    }

    func baselineText(in dashboard: DashboardSummary) -> String {
        guard let baseline = baselineValue(in: dashboard) else {
            return L10n.t("Pending", "待建立")
        }
        switch self {
        case .hrv:
            return "\(Int(baseline))ms"
        case .restingHeartRate:
            return "\(Int(baseline))bpm"
        case .respiratoryRate:
            return "\(Int(baseline))/min"
        case .sleepHeartRate, .bloodOxygen, .weight, .steps, .activeCalories, .activeMinutes:
            return L10n.t("Pending", "待建立")
        }
    }

    func statusCopy(in dashboard: DashboardSummary) -> String {
        guard let today = currentValue(in: dashboard) else {
            return L10n.t("Waiting for Health data to populate this metric.", "等待健康数据填充这个指标。")
        }
        switch self {
        case .steps:
            return L10n.t("Focus on consistent movement to maintain joint health and insulin sensitivity.", "注重持续的身体活动以维持关节健康和胰岛素敏感性。")
        case .activeCalories:
            return L10n.t("Make sure to replenish enough nutrition and energy to support recovery after high burns.", "在高消耗后，确保补充足够的营养和能量以支持恢复。")
        case .activeMinutes:
            return L10n.t("Ensure exercise duration matches your weekly training program requirements.", "确保运动持续时间符合你的每周训练计划要求。")
        default:
            guard let baseline = baselineValue(in: dashboard), baseline > 0 else {
                return L10n.t("Current value is available. More saved days will create a better baseline and trend.", "当前值已可用。保存更多天后会形成更好的基线和趋势。")
            }
            let diff = today - baseline
            let isBetter = lowerIsBetter ? diff <= 0 : diff >= 0
            if isBetter {
                return L10n.t("This is on the favorable side of your current baseline.", "该指标处在相对基线更有利的一侧。")
            }
            return L10n.t("This is away from your favorable baseline and should be interpreted with sleep, strain, and symptoms.", "该指标偏离有利基线，需要结合睡眠、负荷和身体感受一起判断。")
        }
    }

    func actionBody(in dashboard: DashboardSummary) -> String {
        switch self {
        case .hrv, .restingHeartRate, .sleepHeartRate, .respiratoryRate, .steps, .activeCalories, .activeMinutes:
            return statusCopy(in: dashboard)
        case .bloodOxygen:
            return L10n.t("Do not overreact to one sample. Watch repeated drops and pair this with respiratory rate and sleep quality.", "不要因单次样本过度反应。重点关注连续下降，并结合呼吸率和睡眠质量。")
        case .weight:
            return L10n.t("Use this as a multi-week trend, not a single-day judgment. Pair changes with training load and body composition.", "把它作为多周趋势，而不是单日判断。需结合训练负荷和身体组成变化。")
        }
    }
}



private enum RecoveryDetailRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
    var title: String {
        switch self {
        case .week: return L10n.t("7D", "7天")
        case .month: return L10n.t("30D", "30天")
        }
    }
}
