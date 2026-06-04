import SwiftUI
import SwiftData

// MARK: - VelaVitalsView — Bevel Replica Vitals Tab
// Biological Age dial gauge × Interactive Sparkline Biomarker list

struct VelaVitalsView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @Query(sort: \BiomarkerRecord.date, order: .reverse) private var biomarkers: [BiomarkerRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    // Dynamic states for RHR, HRV, Weight, Fat histories
    @State private var weightHistoryData: [Double] = []
    @State private var hrvHistoryData: [Double] = []
    @State private var rhrHistoryData: [Double] = []
    @State private var respiratoryRateHistoryData: [Double] = []
    @State private var bloodOxygenHistoryData: [Double] = []
    @State private var fatHistoryData: [Double] = []

    @State private var hrvValueText: String = "--"
    @State private var rhrValueText: String = "--"
    @State private var respiratoryRateValueText: String = "--"
    @State private var bloodOxygenValueText: String = "--"
    @State private var weightValueText: String = "--"
    @State private var fatValueText: String = "--"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Biological Age Card (生物年龄 cockpit)
                biologicalAgeHero

                // 2. Other Biomarkers Section
                otherBiomarkersSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(VelaTheme.systemGroupedBackground)
        .onAppear {
            loadRealVitalsData()
        }
        .onChange(of: dashboardVM.selectedDate) {
            loadRealVitalsData()
        }
        .onChange(of: appState.localDataRevision) {
            loadRealVitalsData()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Biological Age cockpit
    private var biologicalAgeResult: BiologicalAgeResult? {
        guard let chronologicalAge else { return nil }

        let restingHR = dashboard.recoveryMetrics.restingHeartRate
        let vo2Max = dashboard.bodyMetrics.vo2Max
        let sleepHours = dashboard.sleepSummary.totalSleepMinutes > 0
            ? Double(dashboard.sleepSummary.totalSleepMinutes) / 60.0
            : nil
        let sleepEfficiency = dashboard.sleepScore.metrics["sleep_efficiency"].map { $0 / 100.0 }
        let steps = dashboard.strain.metrics["steps_raw"]
        let hasLiveSignal = restingHR != nil
            || vo2Max != nil
            || sleepHours != nil
            || sleepEfficiency != nil
            || steps != nil
            || !biomarkers.isEmpty

        guard hasLiveSignal else { return nil }

        return BiologicalAgeEngine().calculate(
            input: BiologicalAgeInput(
                chronologicalAge: Double(chronologicalAge),
                restingHR: restingHR,
                vo2Max: vo2Max,
                sleepHours: sleepHours,
                sleepEfficiency: sleepEfficiency,
                steps: steps,
                biomarkers: Array(biomarkers)
            )
        )
    }

    private var chronologicalAge: Int? {
        WikiFileService.getAgeFromWiki() ?? dashboard.extendedMetrics.age
    }

    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "更新于 M月d日"
        return formatter.string(from: dashboardVM.selectedDate)
    }

    private var biologicalAgeHero: some View {
        let result = biologicalAgeResult
        let isPhenoAge = result?.isPhenoAge == true
        let biologicalAge = result?.biologicalAgeEstimate.map { String(format: "%.1f", $0) }
            ?? result?.healthAgeTrendLabel
            ?? "--"
        let age = Double(chronologicalAge ?? 0)
        let minAgeRange = chronologicalAge.map { String(format: "%.0f", Double($0) - 7.0) } ?? "--"
        let maxAgeRange = chronologicalAge.map { String(format: "%.0f", Double($0) + 3.0) } ?? "--"
        let gaugeProgress = min(max((result?.overallScore ?? 0) / 100.0, 0), 1)
        let deltaText: String = {
            guard let result, chronologicalAge != nil else {
                return "连接 Apple Health 后生成"
            }
            guard result.isPhenoAge else {
                return "健康年龄趋势 Beta：\(result.healthAgeTrendLabel)"
            }
            let delta = result.biologicalAge - age
            if abs(delta) < 0.05 {
                return "与实际年龄接近"
            }
            return String(format: delta < 0 ? "比实际年龄年轻 %.1f 岁" : "比实际年龄高 %.1f 岁", abs(delta))
        }()

        return VStack(spacing: 8) {
            // Header
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Text(isPhenoAge ? "生物年龄估算" : "健康年龄趋势 Beta")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)

                    Text(selectedDateText)
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }

                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    VelaAppState.shared.triggerBloodLog = true
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VelaTheme.muted)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.top, 8)

            // Circular Dial Gauge
            ZStack {
                // Background ticks gauge
                GaugeScaleArcView(size: 220)

                Circle()
                    .trim(from: 0.15, to: 0.15 + (0.70 * gaugeProgress))
                    .stroke(
                        Color(hex: "#5B8C6F"),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
                    .frame(width: 220, height: 220)

                // Glowing cell dots visual effect
                scatteredParticles
                    .frame(width: 140, height: 100)
                    .offset(y: -10)

                // Center dial text values
                VStack(spacing: 0) {
                    Text(biologicalAge)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)

                    Text(deltaText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(result == nil ? VelaTheme.muted : Color(hex: "#5B8C6F"))
                        .padding(.top, 4)

                    if isPhenoAge {
                        Text(minAgeRange)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.muted)
                            .offset(x: -78, y: 50)

                        Text(maxAgeRange)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.muted)
                            .offset(x: 78, y: 37)
                    }
                }

                // End Dot indicator at bottom center
                Circle()
                    .fill(VelaTheme.muted)
                    .frame(width: 8, height: 8)
                    .offset(y: 65)
            }
            .frame(width: 220, height: 180)
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                VelaTheme.cardBg

                LinearGradient(
                    colors: [
                        VelaTheme.accent.opacity(0.12),
                        VelaTheme.recoveryColor.opacity(0.08),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: VelaTheme.nativeShadow(cs), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
    }

    // MARK: - Scattered glowing particles in center of age gauge
    private var scatteredParticles: some View {
        Canvas { context, size in
            let points = [
                CGPoint(x: 0.25, y: 0.3), CGPoint(x: 0.35, y: 0.2), CGPoint(x: 0.45, y: 0.25),
                CGPoint(x: 0.3, y: 0.45), CGPoint(x: 0.4, y: 0.4), CGPoint(x: 0.38, y: 0.55),
                CGPoint(x: 0.6, y: 0.35), CGPoint(x: 0.7, y: 0.22), CGPoint(x: 0.65, y: 0.48),
                CGPoint(x: 0.58, y: 0.52), CGPoint(x: 0.72, y: 0.42), CGPoint(x: 0.68, y: 0.3)
            ]

            for pt in points {
                let rect = CGRect(
                    x: pt.x * size.width - 2.5,
                    y: pt.y * size.height - 2.5,
                    width: 5,
                    height: 5
                )
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.85)))
            }
        }
    }

    // MARK: - Other Biomarkers Section
    private var otherBiomarkersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("其他生物标志物")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(VelaTheme.muted)

                Spacer()

                Button("编辑") {
                    VelaAppState.shared.triggerBloodLog = true
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VelaTheme.accent) // Brand Accent
            }
            .padding(.horizontal, 2)

            VStack(spacing: 12) {
                // Card 1: 体重 (Weight)
                NavigationLink(destination: VelaMetricDetailView(metric: .weight)) {
                    biomarkerRow(
                        title: "体重",
                        trendText: syncStatusText(for: weightValueText),
                        trendIcon: "arrow.right",
                        valueText: weightValueText,
                        valueColor: VelaTheme.fg,
                        history: weightHistoryData,
                        graphColor: VelaTheme.muted
                    )
                }
                .buttonStyle(.plain)

                // Card 2: HRV 基线 (HRV Baseline) - Open HRV Detail
                NavigationLink(destination: VelaMetricDetailView(metric: .hrv)) {
                    biomarkerRow(
                        title: "HRV 基线",
                        trendText: syncStatusText(for: hrvValueText),
                        trendIcon: "arrow.right",
                        valueText: hrvValueText,
                        valueColor: VelaTheme.fg,
                        history: hrvHistoryData,
                        graphColor: Color(hex: "#6E6A63")
                    )
                }
                .buttonStyle(.plain)

                // Card 3: RHR 基线 (RHR Baseline) - Open RHR Detail
                NavigationLink(destination: VelaMetricDetailView(metric: .rhr)) {
                    biomarkerRow(
                        title: "RHR 基线",
                        trendText: syncStatusText(for: rhrValueText),
                        trendIcon: "arrow.right",
                        valueText: rhrValueText,
                        valueColor: Color(hex: "#5B8C6F"), // Sage Green for healthy RHR
                        history: rhrHistoryData,
                        graphColor: Color(hex: "#5B8C6F")
                    )
                }
                .buttonStyle(.plain)

                // Card 4: 呼吸率 (Respiratory Rate)
                NavigationLink(destination: VelaMetricDetailView(metric: .respiratoryRate)) {
                    biomarkerRow(
                        title: "呼吸率",
                        trendText: syncStatusText(for: respiratoryRateValueText),
                        trendIcon: "arrow.right",
                        valueText: respiratoryRateValueText,
                        valueColor: Color(hex: "#5B8C6F"),
                        history: respiratoryRateHistoryData,
                        graphColor: Color(hex: "#5B8C6F")
                    )
                }
                .buttonStyle(.plain)

                // Card 5: 血氧 (Blood Oxygen)
                NavigationLink(destination: VelaMetricDetailView(metric: .bloodOxygen)) {
                    biomarkerRow(
                        title: "血氧",
                        trendText: syncStatusText(for: bloodOxygenValueText),
                        trendIcon: "arrow.right",
                        valueText: bloodOxygenValueText,
                        valueColor: VelaTheme.accent,
                        history: bloodOxygenHistoryData,
                        graphColor: VelaTheme.accent
                    )
                }
                .buttonStyle(.plain)

                // Card 6: 体脂 (Body Fat)
                NavigationLink(destination: VelaMetricDetailView(metric: .bodyFat)) {
                    biomarkerRow(
                        title: "体脂",
                        trendText: syncStatusText(for: fatValueText),
                        trendIcon: "arrow.right",
                        valueText: fatValueText,
                        valueColor: VelaTheme.fg,
                        history: fatHistoryData,
                        graphColor: VelaTheme.muted
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Row builder
    private func biomarkerRow(
        title: String,
        trendText: String,
        trendIcon: String,
        valueText: String,
        valueColor: Color,
        history: [Double],
        graphColor: Color
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)

                HStack(spacing: 4) {
                    Image(systemName: trendIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(valueColor)

                    Text("\(trendText) · \(valueText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(valueColor)
                }
            }

            Spacer()

            if history.isEmpty {
                Text("暂无趋势")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(width: 90, alignment: .trailing)
                    .padding(.trailing, 4)
            } else {
                SparklineLineGraph(data: history, color: graphColor, height: 38, width: 90)
                    .padding(.trailing, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .velaNativeCard(radius: 16)
    }

    // MARK: - Dynamic Vitals Sync Loader
    private func loadRealVitalsData() {
        let calendar = Calendar.current
        let now = dashboardVM.selectedDate
        let startDate = calendar.date(byAdding: .day, value: -9, to: now) ?? now // Fetch 10 points
        let startOfDay = calendar.startOfDay(for: startDate)
        let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        // Fetch DailyHealthSummaryRecord from SwiftData
        var descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { record in
                record.date >= startOfDay && record.date <= endOfDay
            },
            sortBy: [SortDescriptor(\DailyHealthSummaryRecord.date, order: .forward)]
        )
        descriptor.fetchLimit = 10

        do {
            let records = try modelContext.fetch(descriptor)
            usePendingDefaults()

            if !records.isEmpty {
                // Extract arrays
                let rawHRV = records.compactMap { $0.hrvAverage }
                let rawRHR = records.compactMap { $0.restingHeartRate }
                let rawRespiratoryRate = records.compactMap { $0.respiratoryRate }
                let rawBloodOxygen = records.compactMap { $0.oxygenSaturation }
                let rawWeight = records.compactMap { $0.bodyWeight }
                let rawFat = records.compactMap { $0.bodyFatPercent }

                // Update latest values from the newest record
                if let latest = records.last {
                    if let hrv = latest.hrvAverage {
                        hrvValueText = String(format: "%.1f ms", hrv)
                    }
                    if let rhr = latest.restingHeartRate {
                        rhrValueText = String(format: "%.1f bpm", rhr)
                    }
                    if let respiratoryRate = latest.respiratoryRate {
                        respiratoryRateValueText = String(format: "%.1f /min", respiratoryRate)
                    }
                    if let bloodOxygen = latest.oxygenSaturation {
                        bloodOxygenValueText = String(format: "%.1f %%", bloodOxygen)
                    }
                    if let wt = latest.bodyWeight {
                        weightValueText = String(format: "%.1f kg", wt)
                    }
                    if let fat = latest.bodyFatPercent {
                        fatValueText = String(format: "%.1f %%", fat)
                    }
                }

                // Normalize to 0...1 for sparklines
                hrvHistoryData = normalizeData(rawHRV)
                rhrHistoryData = normalizeData(rawRHR)
                respiratoryRateHistoryData = normalizeData(rawRespiratoryRate)
                bloodOxygenHistoryData = normalizeData(rawBloodOxygen)
                weightHistoryData = normalizeData(rawWeight)
                fatHistoryData = normalizeData(rawFat)
            } else {
                usePendingDefaults()
            }
        } catch {
            usePendingDefaults()
        }
    }

    private func normalizeData(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        if values.count == 1 { return [0.5] }
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let diff = maxVal - minVal
        guard diff > 0 else { return values.map { _ in 0.5 } }
        return values.map { ($0 - minVal) / diff }
    }

    private func usePendingDefaults() {
        hrvHistoryData = []
        rhrHistoryData = []
        respiratoryRateHistoryData = []
        bloodOxygenHistoryData = []
        weightHistoryData = []
        fatHistoryData = []

        hrvValueText = "--"
        rhrValueText = "--"
        respiratoryRateValueText = "--"
        bloodOxygenValueText = "--"
        weightValueText = "--"
        fatValueText = "--"
    }

    private func syncStatusText(for valueText: String) -> String {
        valueText == "--" ? "暂无数据" : "已同步"
    }
}

// MARK: - Custom Arc View for Gauge
struct GaugeScaleArcView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Main gauge track arc
            Circle()
                .trim(from: 0.15, to: 0.85)
                .stroke(
                    Color(hex: "#E5E5EA"),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: size, height: size)

            // Radial Tick Marks
            ForEach(0..<41) { tick in
                let angle = 144 + (Double(tick) * 6.3) // Map 41 ticks around the arc
                Rectangle()
                    .fill(Color(hex: "#D5D0C8"))
                    .frame(width: tick % 5 == 0 ? 8 : 4, height: 1)
                    .offset(x: (size / 2) - 8)
                    .rotationEffect(.degrees(angle))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VelaVitalsView()
        .environmentObject(DashboardViewModel())
}
