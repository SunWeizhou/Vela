import SwiftData
import SwiftUI

struct VelaMinimalVitalsView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    biologicalAgeHero
                    sleepLastNightCard
                    recoveryBreakdownCard
                    bodyMetricsGrid
                    healthRecordsCard
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .task {
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
        }
    }

    // MARK: - 1. Biological Age Hero

    private var biologicalAgeHero: some View {
        VStack(alignment: .center, spacing: 16) {
            // Age display
            VStack(spacing: 2) {
                Text(biologicalAgeDisplay)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                    .foregroundStyle(VelaTheme.onSurface)

                Text(deltaText)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(deltaColor)
            }

            // Badges
            HStack(spacing: 8) {
                VelaConfidenceBadge(confidence: healthAgeDataConfidence)
                freshnessBadge
            }

            // Contributor chips
            if !contributorChips.isEmpty {
                HStack(spacing: 8) {
                    ForEach(contributorChips.indices, id: \.self) { idx in
                        let chip = contributorChips[idx]
                        VelaMinimalChip(
                            text: chip.text,
                            systemImage: chip.icon,
                            tint: chip.tint
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            VelaTheme.surfaceContainerLowest,
                            VelaTheme.tertiaryContainer.opacity(0.20)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaRadius.hero, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    // MARK: - 2. Sleep · Last Night

    private var sleepLastNightCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest.opacity(0.92))
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)

            // Left accent strip — Indigo
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(VelaTheme.sleep)
                .frame(width: 3, height: 20)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Sleep · Last Night", "睡眠 · 昨晚"))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(VelaTheme.onSurface)
                        Text(VelaMinimalFormat.minutesAsHours(viewModel.dashboard.sleepSummary.totalSleepMinutes))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(VelaTheme.onSurfaceVariant)
                    }
                    Spacer()
                    Image(systemName: "moon.zzz.fill")
                        .font(.title3)
                        .foregroundStyle(VelaTheme.sleep)
                }

                // Sleep timeline chart
                VelaMinimalSleepArchitectureBar(stageMinutes: viewModel.dashboard.sleepSummary.stageMinutes)

                // Efficiency + Sleep Debt
                HStack {
                    Label(
                        L10n.t("Efficiency", "效率") + " \(sleepEfficiencyText)",
                        systemImage: "checkmark.circle.fill"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(VelaTheme.recovery)

                    Spacer()

                    Label(
                        sleepDebtText,
                        systemImage: sleepDebtIcon
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(sleepDebtColor)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 3. Recovery Breakdown

    private var recoveryBreakdownCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest.opacity(0.92))
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)

            // Left accent strip — Sage
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(VelaTheme.recovery)
                .frame(width: 3, height: 20)
                .padding(.top, 20)

            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.t("Recovery Breakdown", "恢复分解"))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.onSurface)

                recoveryMetricRow(
                    title: "HRV",
                    value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.hrvMilliseconds),
                    unit: "ms",
                    trend: hrvTrend,
                    icon: "heart.fill",
                    tint: VelaTheme.recovery
                )

                Divider().opacity(0.5)

                recoveryMetricRow(
                    title: L10n.t("Resting HR", "静息心率"),
                    value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.restingHeartRate),
                    unit: "bpm",
                    trend: rhrTrend,
                    icon: "waveform.path.ecg",
                    tint: VelaTheme.recovery
                )

                Divider().opacity(0.5)

                recoveryMetricRow(
                    title: L10n.t("Temperature", "体温"),
                    value: temperatureValue,
                    unit: "°C",
                    trend: temperatureTrend,
                    icon: "thermometer.medium",
                    tint: VelaTheme.strain
                )

                Divider().opacity(0.5)

                recoveryMetricRow(
                    title: "SpO2",
                    value: spo2Value,
                    unit: "%",
                    trend: spo2Trend,
                    icon: "drop.fill",
                    tint: VelaTheme.sleep
                )
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 4. Body Metrics Grid

    private var bodyMetricsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            VelaMinimalSectionTitle(
                title: L10n.t("Body Metrics", "身体指标"),
                subtitle: L10n.t("Today", "今日")
            )

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                bodyMetricTile(
                    label: L10n.t("Blood Pressure", "血压"),
                    value: bloodPressureValue,
                    unit: "mmHg",
                    icon: "gauge.with.dots.needle.33percent",
                    tint: VelaTheme.stress
                )

                bodyMetricTile(
                    label: L10n.t("Weight", "体重"),
                    value: weightDisplay,
                    unit: "kg",
                    icon: "scalemass.fill",
                    tint: VelaTheme.primary
                )

                bodyMetricTile(
                    label: L10n.t("Blood Glucose", "血糖"),
                    value: glucoseDisplay,
                    unit: "mg/dL",
                    icon: "drop.fill",
                    tint: VelaTheme.strain
                )

                bodyMetricTile(
                    label: "BMI",
                    value: bmiDisplay,
                    unit: "",
                    icon: "figure.stand",
                    tint: VelaTheme.energy
                )

                bodyMetricTile(
                    label: L10n.t("Respiratory Rate", "呼吸率"),
                    value: VelaMinimalFormat.whole(viewModel.dashboard.recoveryMetrics.respiratoryRate),
                    unit: "/min",
                    icon: "lungs.fill",
                    tint: VelaTheme.sleep
                )

                bodyMetricTile(
                    label: "VO₂ Max",
                    value: vo2MaxDisplay,
                    unit: "",
                    icon: "figure.run",
                    tint: VelaTheme.recovery
                )
            }
        }
        .cardSurface()
    }

    // MARK: - 5. Health Records

    private var healthRecordsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.t("Health Records", "健康记录"))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.onSurface)

            VStack(spacing: 0) {
                NavigationLink {
                    BiologyView()
                        .environmentObject(viewModel)
                } label: {
                    healthRecordRow(
                        title: L10n.t("Health Profile", "健康档案"),
                        date: viewModel.dashboard.extendedMetrics.age.map { "\($0) \(L10n.t("yrs", "岁"))" },
                        icon: "person.text.rectangle.fill",
                        tint: VelaTheme.primary
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                NavigationLink {
                    VitalsMetricDetailView(metric: .bloodOxygen)
                        .environmentObject(viewModel)
                } label: {
                    healthRecordRow(
                        title: L10n.t("Blood Oxygen Record", "血氧记录"),
                        date: spo2DateLabel,
                        icon: "drop.fill",
                        tint: VelaTheme.sleep
                    )
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 52)

                NavigationLink {
                    VitalsMetricDetailView(metric: .weight)
                        .environmentObject(viewModel)
                } label: {
                    healthRecordRow(
                        title: L10n.t("Body Metrics Record", "身体指标记录"),
                        date: weightDateLabel,
                        icon: "scalemass.fill",
                        tint: VelaTheme.primary
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            Divider().padding(.horizontal, 16)

            // Import button
            Button {

            } label: {
                Label(
                    L10n.t("Import Record", "导入记录"),
                    systemImage: "doc.badge.plus"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .fill(VelaTheme.surfaceContainerLowest.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaRadius.card, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    // MARK: - Recovery Metric Row

    private func recoveryMetricRow(
        title: String,
        value: String,
        unit: String,
        trend: (arrow: String, color: Color),
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(title)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(VelaTheme.onSurface)

            Spacer()

            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .foregroundStyle(VelaTheme.onSurface)

            Text(unit)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(VelaTheme.onSurfaceVariant)

            Text(trend.arrow)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(trend.color)
                .frame(width: 20)
        }
    }

    // MARK: - Body Metric Tile

    private func bodyMetricTile(
        label: String,
        value: String,
        unit: String,
        icon: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
                    .tracking(0.6)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(VelaTheme.onSurface)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(VelaTheme.onSurfaceVariant)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous)
                .fill(VelaTheme.surfaceContainerLow.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaRadius.row, style: .continuous)
                .stroke(VelaTheme.outline, lineWidth: 0.5)
        )
    }

    // MARK: - Health Record Row

    private func healthRecordRow(
        title: String,
        date: String?,
        icon: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(title)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.onSurface)

            Spacer()

            if let date {
                Text(date)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(VelaTheme.onSurfaceVariant)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(.vertical, 13)
    }

    // MARK: - Biological Age Computed Properties

    private var biologicalAgeDisplay: String {
        if let age = viewModel.dashboard.extendedMetrics.age {
            let bioAge = Double(age) + viewModel.dashboard.healthAge.trendScore
            return String(format: "%.1f", bioAge)
        }
        return viewModel.dashboard.healthAge.hasData
            ? String(format: "%+.1f", viewModel.dashboard.healthAge.trendScore)
            : "--"
    }

    private var deltaText: String {
        if viewModel.dashboard.extendedMetrics.age == nil, !viewModel.dashboard.healthAge.hasData {
            return L10n.t("Insufficient data", "数据不足")
        }
        let delta = viewModel.dashboard.healthAge.trendScore
        let sign = delta < 0 ? "" : "+"
        return "\(sign)\(String(format: "%.1f", delta)) \(L10n.t("yrs vs chronological", "岁 vs 实际年龄"))"
    }

    private var deltaColor: Color {
        let delta = viewModel.dashboard.healthAge.trendScore
        if delta < -0.05 { return VelaTheme.recovery }
        if delta > 0.05 { return VelaTheme.strain }
        return VelaTheme.onSurfaceVariant
    }

    private var healthAgeDataConfidence: DataConfidence {
        switch viewModel.dashboard.healthAge.confidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private var freshnessBadge: some View {
        let fresh: DataFreshness = viewModel.dashboard.sleepSummary.totalSleepMinutes > 0 ? .today : .missing
        return VelaFreshnessBadge(freshness: fresh)
    }

    private var contributorChips: [(text: String, icon: String, tint: Color)] {
        var chips: [(String, String, Color)] = []
        for factor in viewModel.dashboard.healthAge.positiveFactors {
            chips.append((factor, "arrow.up.right", VelaTheme.recovery))
        }
        for factor in viewModel.dashboard.healthAge.negativeFactors {
            chips.append((factor, "arrow.down.right", VelaTheme.stress))
        }
        return chips
    }

    // MARK: - Sleep Computed Properties

    private var sleepEfficiencyText: String {
        let stages = viewModel.dashboard.sleepSummary.stageMinutes
        let asleep = stages[.asleep] ?? 0
        let rem = stages[.rem] ?? 0
        let core = stages[.core] ?? 0
        let deep = stages[.deep] ?? 0
        let awake = stages[.awake] ?? 0
        let totalInBed = asleep + rem + core + deep + awake
        guard totalInBed > 0 else { return "--%" }
        let efficiency = Double(asleep + rem + core + deep) / Double(totalInBed) * 100
        return "\(Int(efficiency.rounded()))%"
    }

    private var sleepDebtText: String {
        let total = viewModel.dashboard.sleepSummary.totalSleepMinutes
        guard total > 0 else { return L10n.t("No data", "无数据") }
        let target: Int = 480
        let debt = total - target
        if debt >= 0 {
            return L10n.t("+\(debt / 60)h \(debt % 60)m vs target", "+\(debt / 60)时\(debt % 60)分 vs 目标")
        } else {
            let absDebt = abs(debt)
            return L10n.t("-\(absDebt / 60)h \(absDebt % 60)m debt", "缺少 \(absDebt / 60)时\(absDebt % 60)分")
        }
    }

    private var sleepDebtColor: Color {
        let total = viewModel.dashboard.sleepSummary.totalSleepMinutes
        let target = 480
        if total >= target { return VelaTheme.recovery }
        if total >= target - 60 { return VelaTheme.strain }
        return VelaTheme.stress
    }

    private var sleepDebtIcon: String {
        let total = viewModel.dashboard.sleepSummary.totalSleepMinutes
        return total >= 480 ? "moon.fill" : "moon.haze.fill"
    }

    // MARK: - Recovery Trend Helpers

    private var hrvTrend: (arrow: String, color: Color) {
        trendArrow(
            today: viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
            baseline: viewModel.dashboard.recoveryBaseline.hrvMilliseconds,
            lowerIsBetter: false
        )
    }

    private var rhrTrend: (arrow: String, color: Color) {
        trendArrow(
            today: viewModel.dashboard.recoveryMetrics.restingHeartRate,
            baseline: viewModel.dashboard.recoveryBaseline.restingHeartRate,
            lowerIsBetter: true
        )
    }

    private var temperatureTrend: (arrow: String, color: Color) {
        guard let temp = viewModel.dashboard.extendedMetrics.bodyTemperature else {
            return ("—", VelaTheme.muted)
        }
        if (36.1...37.2).contains(temp) {
            return ("→", VelaTheme.recovery)
        }
        if temp > 37.2 {
            return ("↑", VelaTheme.stress)
        }
        return ("↓", VelaTheme.strain)
    }

    private var spo2Trend: (arrow: String, color: Color) {
        guard let spo2 = viewModel.dashboard.extendedMetrics.oxygenSaturation else {
            return ("—", VelaTheme.muted)
        }
        if spo2 >= 95 {
            return ("→", VelaTheme.recovery)
        }
        return ("↓", VelaTheme.stress)
    }

    private func trendArrow(today: Double?, baseline: Double?, lowerIsBetter: Bool) -> (arrow: String, color: Color) {
        guard let today, let baseline, baseline > 0 else {
            return ("—", VelaTheme.muted)
        }
        let diff = today - baseline
        let pct = abs(diff) / baseline
        if pct < 0.03 { return ("→", VelaTheme.muted) }
        let isUp = diff > 0
        if lowerIsBetter {
            return isUp ? ("↑", VelaTheme.stress) : ("↓", VelaTheme.recovery)
        } else {
            return isUp ? ("↑", VelaTheme.recovery) : ("↓", VelaTheme.stress)
        }
    }

    // MARK: - Temperature / SpO2 Display Helpers

    private var temperatureValue: String {
        viewModel.dashboard.extendedMetrics.bodyTemperature
            .map { String(format: "%.1f", $0) } ?? "--"
    }

    private var spo2Value: String {
        viewModel.dashboard.extendedMetrics.oxygenSaturation
            .map { "\(Int($0.rounded()))" } ?? "--"
    }

    // MARK: - Body Metrics Display Helpers

    private var bloodPressureValue: String {
        let systolic = viewModel.dashboard.extendedMetrics.bloodPressureSystolic
        let diastolic = viewModel.dashboard.extendedMetrics.bloodPressureDiastolic
        guard let systolic, let diastolic else { return "--/--" }
        return "\(Int(systolic.rounded()))/\(Int(diastolic.rounded()))"
    }

    private var weightDisplay: String {
        viewModel.dashboard.bodyMetrics.weightKilograms
            .map { String(format: "%.1f", $0) } ?? "--"
    }

    private var glucoseDisplay: String {
        viewModel.dashboard.extendedMetrics.bloodGlucose
            .map { "\(Int($0.rounded()))" } ?? "--"
    }

    private var bmiDisplay: String {
        viewModel.dashboard.extendedMetrics.bmi
            .map { String(format: "%.1f", $0) } ?? "--"
    }

    private var vo2MaxDisplay: String {
        viewModel.dashboard.bodyMetrics.vo2Max
            .map { String(format: "%.1f", $0) } ?? "--"
    }

    // MARK: - Health Records Helpers

    private var spo2DateLabel: String? {
        viewModel.dashboard.extendedMetrics.oxygenSaturation != nil
            ? L10n.t("Latest", "最新") : nil
    }

    private var weightDateLabel: String? {
        viewModel.dashboard.bodyMetrics.weightKilograms != nil
            ? L10n.t("Latest", "最新") : nil
    }
}
