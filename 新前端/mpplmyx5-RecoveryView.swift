import Charts
import SwiftUI

struct RecoveryView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Recovery", "恢复"),
            subtitle: viewModel.isToday ? L10n.t("Today", "今日") : viewModel.selectedDate.formatted(date: .abbreviated, time: .omitted),
            showDateNavigation: true,
            hero: {
                HStack(spacing: 18) {
                    ScoreRingView(score: viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : 0, tint: VelaTheme.recovery)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.dashboard.recovery.hasData ? localizedBand(viewModel.dashboard.recovery.band) : L10n.t("No Data", "暂无数据"))
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(VelaTheme.primaryText)

                        Text(viewModel.dashboard.recovery.hasData ? localizedReason(viewModel.dashboard.recovery.reasons.first ?? L10n.t("Recovery uses HRV, RHR, sleep, and prior strain.", "恢复基于 HRV、静息心率、睡眠和前一日负荷。")) : L10n.t("Connect Apple Health to view recovery metrics.", "连接 Apple 健康以查看恢复指标。"))
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                }
                .cardSurface()
            },
            content: {
                MetricRow(items: [
                    .init(title: "HRV", value: viewModel.dashboard.recovery.hasData ? (viewModel.dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--") : "--"),
                    .init(title: L10n.t("RHR", "静息心率"), value: viewModel.dashboard.recovery.hasData ? (viewModel.dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "--") : "--"),
                    .init(title: L10n.t("Sleep", "睡眠"), value: viewModel.dashboard.recovery.hasData ? (viewModel.dashboard.recovery.components["sleep"]?.formatted(.number.precision(.fractionLength(0))) ?? "--") : "--")
                ])

                if viewModel.dashboard.recoveryMetrics.sleepHeartRate != nil || viewModel.dashboard.recoveryMetrics.respiratoryRate != nil {
                    MetricRow(items: [
                        .init(title: L10n.t("Sleep HR", "睡眠心率"), value: viewModel.dashboard.recoveryMetrics.sleepHeartRate.map { "\(Int($0))bpm" } ?? "--"),
                        .init(title: L10n.t("Resp Rate", "呼吸率"), value: viewModel.dashboard.recoveryMetrics.respiratoryRate.map { "\(Int($0))/min" } ?? "--"),
                        .init(title: L10n.t("Prior Strain", "前日负荷"), value: viewModel.dashboard.recovery.components["prior_strain"]?.formatted(.number.precision(.fractionLength(0))) ?? "--")
                    ])
                }

                // HRV and RHR baseline comparison
                if viewModel.dashboard.recovery.hasData {
                    MetricRow(items: [
                        .init(title: "HRV", value: {
                            if let today = viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
                               let baseline = viewModel.dashboard.recoveryBaseline.hrvMilliseconds, baseline > 0 {
                                let delta = ((today - baseline) / baseline) * 100
                                let symbol = delta >= 0 ? "↑" : "↓"
                                return "\(Int(today))ms \(symbol)\(Int(abs(delta)))%"
                            }
                            return viewModel.dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "--"
                        }()),
                        .init(title: L10n.t("RHR", "静息心率"), value: {
                            if let today = viewModel.dashboard.recoveryMetrics.restingHeartRate,
                               let baseline = viewModel.dashboard.recoveryBaseline.restingHeartRate, baseline > 0 {
                                let delta = Int(today - baseline)
                                let symbol = delta <= 0 ? "↓" : "↑"
                                return "\(Int(today))bpm \(symbol)\(abs(delta))"
                            }
                            return viewModel.dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "--"
                        }()),
                        .init(title: L10n.t("Baseline", "基线"), value: L10n.t("28-day", "28天"))
                    ])
                }

                // Contribution breakdown – 2x2 factor cards
                if viewModel.dashboard.recovery.hasData {
                    VStack(alignment: .leading, spacing: 12) {
                        Label(L10n.t("Contribution Breakdown", "贡献拆解"), systemImage: "chart.bar.doc.horizontal.fill")
                            .font(.headline)
                            .foregroundStyle(VelaTheme.primaryText)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(factorCards) { card in
                                RecoveryFactorCard(
                                    name: card.name,
                                    icon: card.icon,
                                    tint: card.tint,
                                    todayValue: card.todayValue,
                                    baselineValue: card.baselineValue,
                                    delta: card.delta,
                                    isPositive: card.isPositive,
                                    weight: card.weight
                                )
                            }
                        }
                    }
                    .cardSurface()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("30-Day Recovery Trend", "30 天恢复趋势"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    if viewModel.recoveryTrend.isEmpty {
                        Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
                    } else {
                        let avg = viewModel.recoveryTrend.map(\.value).reduce(0, +) / Double(max(viewModel.recoveryTrend.count, 1))

                        Chart(viewModel.recoveryTrend) { item in
                            AreaMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [VelaTheme.recovery.opacity(0.2), VelaTheme.recovery.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            LineMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(VelaTheme.recovery)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Day", item.date),
                                y: .value("Score", item.value)
                            )
                            .foregroundStyle(VelaTheme.recovery)
                            .symbolSize(20)

                            // Baseline average reference line
                            RuleMark(y: .value("Avg", avg))
                                .foregroundStyle(VelaTheme.mutedText.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                .annotation(position: .top, alignment: .trailing) {
                                    Text(L10n.t("Avg: \(Int(avg))", "平均：\(Int(avg))"))
                                        .font(.caption2)
                                        .foregroundStyle(VelaTheme.mutedText)
                                }
                        }
                        .chartYScale(domain: 0...100)
                        .chartXAxis(.hidden)
                        .frame(height: 160)
                    }
                }
                .cardSurface()

                PlaceholderInsightCard(
                    title: L10n.t("AI Recovery Insight", "AI 恢复洞察"),
                    bodyText: L10n.t("Coach output will cite score reasons instead of guessing from raw samples.", "Coach 会引用评分原因，而不是从原始样本中猜测。")
                )

                MetricCoachCard(
                    dashboard: viewModel.dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Recovery", "恢复"),
                        systemContext: L10n.t(
                            "Analyze recovery score, HRV, resting heart rate, sleep contribution, prior strain, confidence, and recovery reasons.",
                            "分析恢复评分、HRV、静息心率、睡眠贡献、前一日负荷、置信度和恢复原因。"
                        )
                    )
                )
            }
        )
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
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
}
