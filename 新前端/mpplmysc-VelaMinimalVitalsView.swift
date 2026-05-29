import SwiftData
import SwiftUI

struct VelaMinimalVitalsView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    biologicalAgeCard
                    sleepArchitectureCard
                    vitalsGrid
                    healthRecordsCard
                    coachCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
        .onAppear {
            viewModel.resetDateIfNeeded()
        }
    }

    private var biologicalAgeCard: some View {
        VelaMinimalGlassPanel(padding: 24, radius: 24) {
            VStack(alignment: .center, spacing: 10) {
                Text(L10n.t("Biological Age", "生物年龄"))
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)

                VelaMinimalValueText(value: biologicalAgeValue, unit: biologicalAgeUnit, size: 70, tint: VelaTheme.accent)

                VelaMinimalChip(
                    text: healthAgeTrendText,
                    systemImage: healthAgeTrendIcon,
                    tint: healthAgeTrendTint
                )
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        }
    }

    private var sleepArchitectureCard: some View {
        VelaMinimalGlassPanel(padding: 20, radius: 22) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Sleep Architecture", "睡眠结构"))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text("\(L10n.t("Last night", "昨晚")) · \(VelaMinimalFormat.minutesAsHours(viewModel.dashboard.sleepSummary.totalSleepMinutes))")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "bed.double.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                }

                VelaMinimalSleepArchitectureBar(stageMinutes: viewModel.dashboard.sleepSummary.stageMinutes)
            }
        }
    }

    private var vitalsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(title: L10n.t("Vitals", "生命体征"), subtitle: L10n.t("Today", "今日"))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                NavigationLink {
                    VitalsMetricDetailView(metric: .hrv)
                        .environmentObject(viewModel)
                } label: {
                    VelaMinimalBentoMetricCard(
                        title: "HRV",
                        value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.hrvMilliseconds),
                        unit: "ms",
                        subtitle: hrvStatusText,
                        systemImage: "heart.fill",
                        tint: VelaTheme.accent
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    VitalsMetricDetailView(metric: .restingHeartRate)
                        .environmentObject(viewModel)
                } label: {
                    VelaMinimalBentoMetricCard(
                        title: L10n.t("Resting HR", "静息心率"),
                        value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.restingHeartRate),
                        unit: "bpm",
                        subtitle: rhrStatusText,
                        systemImage: "waveform.path.ecg",
                        tint: VelaTheme.accent
                    )
                }
                .buttonStyle(.plain)

                VelaMinimalBentoMetricCard(
                    title: L10n.t("Blood Pressure", "血压"),
                    value: bloodPressureValue,
                    subtitle: L10n.t("Latest Health sample", "最新健康样本"),
                    systemImage: "gauge.with.dots.needle.33percent",
                    tint: VelaTheme.accent
                )

                NavigationLink {
                    VitalsMetricDetailView(metric: .respiratoryRate)
                        .environmentObject(viewModel)
                } label: {
                    VelaMinimalBentoMetricCard(
                        title: L10n.t("Respiratory Rate", "呼吸率"),
                        value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.respiratoryRate),
                        unit: "/min",
                        subtitle: L10n.t("Consistent overnight", "夜间稳定"),
                        systemImage: "lungs.fill",
                        tint: VelaTheme.accent
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var healthRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(title: L10n.t("Health Records", "健康记录"))
            VelaMinimalGlassPanel(padding: 0, radius: 22) {
                VStack(spacing: 0) {
                    NavigationLink {
                        BiologyView()
                            .environmentObject(viewModel)
                    } label: {
                        VelaMinimalRecordRow(
                            title: L10n.t("Health Profile", "健康档案"),
                            detail: viewModel.dashboard.extendedMetrics.age.map { "\($0)" },
                            systemImage: "person.text.rectangle.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56)

                    NavigationLink {
                        VitalsMetricDetailView(metric: .bloodOxygen)
                            .environmentObject(viewModel)
                    } label: {
                        VelaMinimalRecordRow(
                            title: L10n.t("Blood Oxygen", "血氧"),
                            detail: oxygenText,
                            systemImage: "drop.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 56)

                    NavigationLink {
                        VitalsMetricDetailView(metric: .weight)
                            .environmentObject(viewModel)
                    } label: {
                        VelaMinimalRecordRow(
                            title: L10n.t("Body Metrics", "身体指标"),
                            detail: weightText,
                            systemImage: "scalemass.fill"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var coachCard: some View {
        VelaMinimalGlassPanel(padding: 18, radius: 22) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("Ask Vela about today", "询问 Vela 今日状态"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(L10n.t("Recovery, HRV, sleep, and body metrics", "恢复、HRV、睡眠和身体指标"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.secondaryText)
                }

                Spacer()

                Button {
                    VelaAppState.shared.routeToCoach(question: L10n.t(
                        "Analyze my vitals today. Start with the conclusion, then explain HRV, resting heart rate, sleep architecture, and the one action I should take.",
                        "请分析我今天的生命体征。先给结论，再解释 HRV、静息心率、睡眠结构，以及我今天最应该做的一件事。"
                    ))
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VelaTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var biologicalAgeValue: String {
        if let age = viewModel.dashboard.extendedMetrics.age {
            return String(format: "%.1f", Double(age) + viewModel.dashboard.healthAge.trendScore)
        }
        return viewModel.dashboard.healthAge.hasData ? String(format: "%+.1f", viewModel.dashboard.healthAge.trendScore) : "--"
    }

    private var biologicalAgeUnit: String? {
        viewModel.dashboard.extendedMetrics.age == nil ? nil : L10n.t("yrs", "岁")
    }

    private var healthAgeTrendText: String {
        switch viewModel.dashboard.healthAge.label {
        case .improving: return L10n.t("Improving vs baseline", "相对基线改善")
        case .stable: return L10n.t("Stable vs baseline", "相对基线稳定")
        case .worsening: return L10n.t("Needs attention", "需要关注")
        }
    }

    private var healthAgeTrendIcon: String {
        switch viewModel.dashboard.healthAge.label {
        case .improving: return "arrow.down.right"
        case .stable: return "equal"
        case .worsening: return "arrow.up.right"
        }
    }

    private var healthAgeTrendTint: Color {
        switch viewModel.dashboard.healthAge.label {
        case .improving: return VelaTheme.recovery
        case .stable: return VelaTheme.energy
        case .worsening: return VelaTheme.stress
        }
    }

    private var hrvStatusText: String {
        baselineDeltaText(
            today: viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
            baseline: viewModel.dashboard.recoveryBaseline.hrvMilliseconds,
            unit: "ms",
            lowerIsBetter: false
        )
    }

    private var rhrStatusText: String {
        baselineDeltaText(
            today: viewModel.dashboard.recoveryMetrics.restingHeartRate,
            baseline: viewModel.dashboard.recoveryBaseline.restingHeartRate,
            unit: "bpm",
            lowerIsBetter: true
        )
    }

    private var bloodPressureValue: String {
        let systolic = viewModel.dashboard.extendedMetrics.bloodPressureSystolic
        let diastolic = viewModel.dashboard.extendedMetrics.bloodPressureDiastolic
        guard let systolic, let diastolic else { return "--" }
        return "\(Int(systolic.rounded()))/\(Int(diastolic.rounded()))"
    }

    private var oxygenText: String {
        viewModel.dashboard.extendedMetrics.oxygenSaturation.map { "\(Int($0.rounded()))%" } ?? "--"
    }

    private var weightText: String {
        viewModel.dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1fkg", $0) } ?? "--"
    }

    private func baselineDeltaText(today: Double?, baseline: Double?, unit: String, lowerIsBetter: Bool) -> String {
        guard let today, let baseline, baseline > 0 else {
            return L10n.t("Baseline pending", "基线待建立")
        }
        let diff = today - baseline
        let isGood = lowerIsBetter ? diff <= 0 : diff >= 0
        let direction = isGood ? L10n.t("Normal range", "正常范围") : L10n.t("Watch", "关注")
        let sign = diff >= 0 ? "+" : "-"
        return "\(sign)\(abs(Int(diff.rounded())))\(unit) · \(direction)"
    }
}

