import Charts
import SwiftUI

struct VitalsMetricDetailView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRange: RecoveryDetailRange = .month

    let metric: VitalsMetricDetailKind

    var body: some View {
        ZStack {
            VelaBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    hero
                    trendCard
                    contextCard
                    actionCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("")
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                metricHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                DateNavigationBar()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                
                Divider()
                    .opacity(0.4)
            }
            .background(.ultraThinMaterial)
        }
        .task {
            await reload()
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task { await reload() }
        }
    }

    private var metricHeader: some View {
        HStack(alignment: .center) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.surface))
                    .overlay(Circle().stroke(VelaTheme.stroke, lineWidth: 0.5))
            }
            .buttonStyle(.cardPress)
            .accessibilityLabel("返回")

            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
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
            .buttonStyle(.cardPress)
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
        .padding(18)
        .velaNativeCard(radius: 20)
    }

    private var trendCard: some View {
        VelaGlassCard(padding: 16, cornerRadius: 20) {
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
        }
    }

    private var contextCard: some View {
        VelaGlassCard(padding: 16, cornerRadius: 20) {
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
        }
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
                .buttonStyle(.cardPress)
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

