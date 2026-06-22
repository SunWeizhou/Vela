import SwiftUI
import SwiftData

// MARK: - VelaVitalsView — Bevel Replica Vitals Tab
// Biological Age dial gauge × Interactive Sparkline Biomarker list

struct VelaVitalsView: View {
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @State private var biomarkers: [BiomarkerRecord] = []
    @State private var latestRecord: DailyHealthSummaryRecord?

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    // Dynamic states for RHR, HRV, Weight, Fat histories (normalized for sparklines)
    @State private var weightHistoryData: [Double] = []
    @State private var hrvHistoryData: [Double] = []
    @State private var rhrHistoryData: [Double] = []
    @State private var respiratoryRateHistoryData: [Double] = []
    @State private var bloodOxygenHistoryData: [Double] = []
    @State private var fatHistoryData: [Double] = []

    // Raw (non-normalized) history arrays for trend evaluations
    @State private var rawWeightHistory: [Double] = []
    @State private var rawHrvHistory: [Double] = []
    @State private var rawRhrHistory: [Double] = []
    @State private var rawRespiratoryRateHistory: [Double] = []
    @State private var rawBloodOxygenHistory: [Double] = []
    @State private var rawFatHistory: [Double] = []

    @State private var hrvValueText: String = "--"
    @State private var rhrValueText: String = "--"
    @State private var respiratoryRateValueText: String = "--"
    @State private var bloodOxygenValueText: String = "--"
    @State private var weightValueText: String = "--"
    @State private var fatValueText: String = "--"

    // MARK: - Vitals Title Header
    private var vitalsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("体征")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("健康信号与核心指标")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Spacer()
            
            Button {
                VelaAppState.shared.triggerBloodLog = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("记录健康指标")
            .accessibilityHint("添加化验或健康记录")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Health-signal reference or complete PhenoAge estimate
                biologicalAgeHero

                // 2. Other Biomarkers Section
                otherBiomarkersSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, VelaFloatingNavigationMetrics.contentBottomPadding)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                vitalsHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                
                Divider()
                    .opacity(0.4)
            }
        }
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
        dashboard.extendedMetrics.age
            ?? UserProfileSettings.age()
            ?? WikiFileService.getAgeFromWiki()
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
        let age = Double(chronologicalAge ?? 0)
        let deltaText: String = {
            guard let result, chronologicalAge != nil else {
                return "连接 Apple Health 后生成"
            }
            guard result.isPhenoAge else {
                return "健康信号参考：\(result.healthAgeTrendLabel)"
            }
            let delta = result.biologicalAge - age
            if abs(delta) < 0.05 {
                return "与实际年龄接近"
            }
            return String(format: delta < 0 ? "估算比实际年龄低 %.1f 岁" : "估算比实际年龄高 %.1f 岁", abs(delta))
        }()

        let deltaColor: Color = {
            guard let result, chronologicalAge != nil else { return VelaTheme.muted }
            guard result.isPhenoAge else { return Color(hex: "#5B8C6F") }
            let delta = result.biologicalAge - age
            if abs(delta) < 0.05 {
                return VelaTheme.muted
            }
            return delta < 0 ? Color(hex: "#5B8C6F") : VelaTheme.strainColor
        }()

        return Group {
            if result == nil || chronologicalAge == nil {
                biologicalAgeUnavailableCard
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isPhenoAge ? "cross.case.fill" : "waveform.path.ecg")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VelaTheme.accent)
                            .frame(width: 36, height: 36)
                            .background(RoundedRectangle(cornerRadius: 8).fill(VelaTheme.accent.opacity(0.12)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isPhenoAge ? "生物年龄估算" : "健康信号参考")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(VelaTheme.fg)
                            Text(selectedDateText)
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer()
                        Button {
                            VelaAppState.shared.triggerBloodLog = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VelaTheme.accent)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("记录健康指标")
                    }

                    Divider()

                    HStack(alignment: .firstTextBaseline, spacing: 18) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isPhenoAge ? String(format: "%.1f", result!.biologicalAge) : "\(Int(result!.overallScore.rounded()))")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(isPhenoAge ? "岁（估算）" : "信号评分")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(deltaText)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(deltaColor)
                            Text(isPhenoAge
                                 ? "基于完整生物标志物输入的研究模型估算。"
                                 : "仅汇总可用的静息心率、睡眠、活动等信号，不等同于生物年龄。")
                                .font(.system(size: 11))
                                .foregroundStyle(VelaTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 14) {
                        Text("可用信号 \(result!.factors.count)")
                        Text("参考积极 \(result!.optimalCount)")
                        if result!.suboptimalCount > 0 {
                            Text("待关注 \(result!.suboptimalCount)")
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(VelaTheme.cardBg))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(VelaTheme.separatorSoft, lineWidth: 0.5))
            }
        }
    }

    private var biologicalAgeUnavailableCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 42, height: 42)
                .background(Circle().fill(VelaTheme.accent.opacity(0.12)))

            VStack(alignment: .leading, spacing: 5) {
                Text("健康信号尚未生成")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text("填写年龄，并积累静息心率、睡眠或活动等核心信号后再生成参考趋势。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(VelaTheme.cardBg))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
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
                let weightEval = evaluateBiomarker(.weight, latestValue: rawWeightHistory.last, history: rawWeightHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .weight)) {
                    biomarkerRow(
                        title: "体重",
                        trendText: weightEval.text,
                        trendIcon: weightEval.icon,
                        valueText: weightValueText,
                        valueColor: weightEval.color,
                        history: weightHistoryData,
                        graphColor: weightEval.color,
                        freshness: freshness(for: rawWeightHistory.last)
                    )
                }
                .buttonStyle(.cardPress)

                // Card 2: HRV 基线 (HRV Baseline) - Open HRV Detail
                let hrvEval = evaluateBiomarker(.hrv, latestValue: rawHrvHistory.last, history: rawHrvHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .hrv)) {
                    biomarkerRow(
                        title: "HRV 基线",
                        trendText: hrvEval.text,
                        trendIcon: hrvEval.icon,
                        valueText: hrvValueText,
                        valueColor: hrvEval.color,
                        history: hrvHistoryData,
                        graphColor: hrvEval.color,
                        freshness: freshness(for: rawHrvHistory.last)
                    )
                }
                .buttonStyle(.cardPress)

                // Card 3: RHR 基线 (RHR Baseline) - Open RHR Detail
                let rhrEval = evaluateBiomarker(.rhr, latestValue: rawRhrHistory.last, history: rawRhrHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .rhr)) {
                    biomarkerRow(
                        title: "RHR 基线",
                        trendText: rhrEval.text,
                        trendIcon: rhrEval.icon,
                        valueText: rhrValueText,
                        valueColor: rhrEval.color,
                        history: rhrHistoryData,
                        graphColor: rhrEval.color,
                        freshness: freshness(for: rawRhrHistory.last)
                    )
                }
                .buttonStyle(.cardPress)

                // Card 4: 呼吸率 (Respiratory Rate)
                let respEval = evaluateBiomarker(.respiratoryRate, latestValue: rawRespiratoryRateHistory.last, history: rawRespiratoryRateHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .respiratoryRate)) {
                    biomarkerRow(
                        title: "呼吸率",
                        trendText: respEval.text,
                        trendIcon: respEval.icon,
                        valueText: respiratoryRateValueText,
                        valueColor: respEval.color,
                        history: respiratoryRateHistoryData,
                        graphColor: respEval.color,
                        freshness: freshness(for: rawRespiratoryRateHistory.last)
                    )
                }
                .buttonStyle(.cardPress)

                // Card 5: 血氧 (Blood Oxygen)
                let o2Eval = evaluateBiomarker(.bloodOxygen, latestValue: rawBloodOxygenHistory.last, history: rawBloodOxygenHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .bloodOxygen)) {
                    biomarkerRow(
                        title: "血氧",
                        trendText: o2Eval.text,
                        trendIcon: o2Eval.icon,
                        valueText: bloodOxygenValueText,
                        valueColor: o2Eval.color,
                        history: bloodOxygenHistoryData,
                        graphColor: o2Eval.color,
                        freshness: freshness(for: rawBloodOxygenHistory.last)
                    )
                }
                .buttonStyle(.cardPress)

                // Card 6: 体脂 (Body Fat)
                let fatEval = evaluateBiomarker(.bodyFat, latestValue: rawFatHistory.last, history: rawFatHistory)
                NavigationLink(destination: VelaMetricDetailView(metric: .bodyFat)) {
                    biomarkerRow(
                        title: "体脂",
                        trendText: fatEval.text,
                        trendIcon: fatEval.icon,
                        valueText: fatValueText,
                        valueColor: fatEval.color,
                        history: fatHistoryData,
                        graphColor: fatEval.color,
                        freshness: freshness(for: rawFatHistory.last)
                    )
                }
                .buttonStyle(.cardPress)
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
        graphColor: Color,
        freshness: DataFreshness
    ) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    
                    DataFreshnessIndicator(freshness: freshness, showText: false)
                }

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

        // Fetch biomarkers dynamically
        var biomarkerDesc = FetchDescriptor<BiomarkerRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        biomarkerDesc.fetchLimit = 100
        self.biomarkers = (try? modelContext.fetch(biomarkerDesc)) ?? []

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
                    self.latestRecord = latest
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

                // Update raw arrays
                rawWeightHistory = rawWeight
                rawHrvHistory = rawHRV
                rawRhrHistory = rawRHR
                rawRespiratoryRateHistory = rawRespiratoryRate
                rawBloodOxygenHistory = rawBloodOxygen
                rawFatHistory = rawFat

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
        latestRecord = nil
        hrvHistoryData = []
        rhrHistoryData = []
        respiratoryRateHistoryData = []
        bloodOxygenHistoryData = []
        weightHistoryData = []
        fatHistoryData = []

        rawWeightHistory = []
        rawHrvHistory = []
        rawRhrHistory = []
        rawRespiratoryRateHistory = []
        rawBloodOxygenHistory = []
        rawFatHistory = []

        hrvValueText = "--"
        rhrValueText = "--"
        respiratoryRateValueText = "--"
        bloodOxygenValueText = "--"
        weightValueText = "--"
        fatValueText = "--"
    }

    private func freshness(for value: Double?) -> DataFreshness {
        guard value != nil, let latestRecord else { return .missing }
        let now = Date()
        let referenceDate = latestRecord.updatedAt
        let age = now.timeIntervalSince(referenceDate)
        if age <= 2 * 3_600 { return .live }
        if Calendar.current.isDate(referenceDate, inSameDayAs: now) { return .today }
        if age <= 3 * 86_400 { return .recent }
        return .stale
    }

    struct BiomarkerEvaluation {
        let text: String
        let icon: String
        let color: Color
    }

    private func evaluateBiomarker(
        _ metric: VelaMetricDetailView.MetricType,
        latestValue: Double?,
        history: [Double]
    ) -> BiomarkerEvaluation {
        guard let latestValue else {
            return BiomarkerEvaluation(text: "暂无数据", icon: "questionmark.circle", color: VelaTheme.muted)
        }
        
        let validHistory = history.filter { $0 > 0 }
        let avg = validHistory.isEmpty ? latestValue : validHistory.reduce(0, +) / Double(validHistory.count)
        
        switch metric {
        case .weight:
            let diff = latestValue - avg
            if diff > 0.2 {
                return BiomarkerEvaluation(text: "呈上升趋势", icon: "arrow.up.forward", color: VelaTheme.fg)
            } else if diff < -0.2 {
                return BiomarkerEvaluation(text: "呈下降趋势", icon: "arrow.down.forward", color: Color(hex: "#5B8C6F"))
            } else {
                return BiomarkerEvaluation(text: "保持稳定", icon: "minus", color: VelaTheme.muted)
            }
            
        case .hrv:
            let diffPercent = avg > 0 ? (latestValue - avg) / avg : 0.0
            if diffPercent > 0.05 {
                return BiomarkerEvaluation(text: "高于基线", icon: "arrow.up.forward", color: Color(hex: "#5B8C6F"))
            } else if diffPercent < -0.05 {
                return BiomarkerEvaluation(text: "低于基线", icon: "arrow.down.forward", color: VelaTheme.strainColor)
            } else {
                return BiomarkerEvaluation(text: "稳定", icon: "minus", color: VelaTheme.fg)
            }
            
        case .rhr:
            let diff = latestValue - avg
            if diff > 2.0 {
                return BiomarkerEvaluation(text: "偏高", icon: "arrow.up.forward", color: VelaTheme.strainColor)
            } else if diff < -2.0 {
                return BiomarkerEvaluation(text: "优秀/偏低", icon: "arrow.down.forward", color: Color(hex: "#5B8C6F"))
            } else {
                return BiomarkerEvaluation(text: "稳定", icon: "minus", color: Color(hex: "#5B8C6F"))
            }
            
        case .respiratoryRate:
            let diff = latestValue - avg
            if diff > 1.0 {
                return BiomarkerEvaluation(text: "偏快", icon: "arrow.up.forward", color: VelaTheme.strainColor)
            } else if diff < -1.0 {
                return BiomarkerEvaluation(text: "偏慢", icon: "arrow.down.forward", color: VelaTheme.muted)
            } else {
                return BiomarkerEvaluation(text: "正常", icon: "minus", color: Color(hex: "#5B8C6F"))
            }
            
        case .bloodOxygen:
            if latestValue >= 95.0 {
                return BiomarkerEvaluation(text: "正常", icon: "checkmark.circle.fill", color: Color(hex: "#5B8C6F"))
            } else {
                return BiomarkerEvaluation(text: "偏低", icon: "exclamationmark.triangle.fill", color: VelaTheme.strainColor)
            }
            
        case .bodyFat:
            let diff = latestValue - avg
            if diff > 0.2 {
                return BiomarkerEvaluation(text: "有所上升", icon: "arrow.up.forward", color: VelaTheme.fg)
            } else if diff < -0.2 {
                return BiomarkerEvaluation(text: "有所下降", icon: "arrow.down.forward", color: Color(hex: "#5B8C6F"))
            } else {
                return BiomarkerEvaluation(text: "稳定", icon: "minus", color: VelaTheme.muted)
            }
            
        default:
            return BiomarkerEvaluation(text: "已同步", icon: "arrow.right", color: VelaTheme.fg)
        }
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
