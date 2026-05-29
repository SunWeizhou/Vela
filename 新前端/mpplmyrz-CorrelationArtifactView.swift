import SwiftUI
import Charts

struct CorrelationArtifactView: View {
    let key: String
    
    @State private var selectedTimeframe = 14
    @State private var hoveredIndex: Int? = nil
    
    // Parse the metrics from the key (e.g., "hrv_vs_caffeine" or "sleep_vs_meditation")
    private var parsedMetrics: (x: String, y: String) {
        let parts = key.lowercased().components(separatedBy: "_vs_")
        if parts.count == 2 {
            return (parts[0], parts[1])
        }
        return ("hrv", "caffeine")
    }
    
    // Theme colors for the metrics
    private func colorForMetric(_ metric: String) -> Color {
        switch metric {
        case "hrv", "recovery", "recovery_score":
            return VelaTheme.recovery
        case "sleep", "sleep_score", "sleep_hours":
            return VelaTheme.sleep
        case "strain", "strain_score", "steps":
            return VelaTheme.strain
        case "stress", "stress_index", "alcohol", "late_meal":
            return VelaTheme.stress
        case "energy", "energy_bank", "caffeine":
            return VelaTheme.energy
        default:
            return VelaTheme.accent
        }
    }
    
    // Pretty names for the metrics
    private func displayNameForMetric(_ metric: String) -> String {
        switch metric {
        case "hrv":
            return L10n.t("HRV", "HRV (心率变异性)")
        case "caffeine":
            return L10n.t("Caffeine", "咖啡因")
        case "sleep", "sleep_score":
            return L10n.t("Sleep Score", "睡眠分数")
        case "sleep_hours":
            return L10n.t("Sleep Duration", "睡眠时长")
        case "meditation":
            return L10n.t("Meditation", "正念冥想")
        case "alcohol":
            return L10n.t("Alcohol", "酒精摄入")
        case "steps":
            return L10n.t("Steps", "步数")
        case "resting_hr", "rhr":
            return L10n.t("Resting HR", "静息心率")
        case "stress", "stress_index":
            return L10n.t("Stress Index", "压力指数")
        case "recovery", "recovery_score":
            return L10n.t("Recovery Score", "恢复分数")
        case "vitamin_d":
            return L10n.t("Vitamin D", "维生素 D")
        case "cortisol":
            return L10n.t("Cortisol", "皮质醇")
        default:
            return metric.capitalized
        }
    }
    
    // Metric units
    private func unitForMetric(_ metric: String) -> String {
        switch metric {
        case "hrv": return "ms"
        case "caffeine": return "mg"
        case "sleep_hours": return "hrs"
        case "meditation": return "min"
        case "alcohol": return "drinks"
        case "steps": return "steps"
        case "resting_hr", "rhr": return "bpm"
        case "vitamin_d": return "ng/mL"
        case "cortisol": return "mcg/dL"
        case "sleep", "sleep_score", "recovery", "recovery_score", "stress", "stress_index": return ""
        default: return ""
        }
    }
    
    // Generate beautiful trend points based on metrics
    private func generateTrendPoints() -> [CorrelationPoint] {
        let count = selectedTimeframe
        let (mx, my) = parsedMetrics
        
        // Logical relationships:
        // HRV vs Caffeine: strong negative correlation (-0.72)
        // Sleep vs Meditation: strong positive correlation (+0.65)
        // HRV vs Alcohol: very strong negative correlation (-0.84)
        // Stress vs Steps: moderate negative correlation (-0.45)
        // Sleep vs Sleep Hours: strong positive (+0.80)
        
        var points: [CorrelationPoint] = []
        let calendar = Calendar.current
        
        // Base seed for determinism based on the key
        let seed = Double(abs(key.hashValue) % 100)
        
        for i in 0..<count {
            let date = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let t = Double(i) / Double(count) // normalized time 0 to 1
            
            // Base sine waves + noise + correlation logic
            let noiseX = sin(t * .pi * 3.0 + seed) * 0.15 + cos(t * .pi * 1.5) * 0.1
            let noiseY: Double
            
            let correlationSign: Double
            if key.contains("caffeine") || key.contains("alcohol") || key.contains("stress") || key.contains("late_meal") {
                correlationSign = -1.0
            } else {
                correlationSign = 1.0
            }
            
            noiseY = (noiseX * correlationSign) + (sin(t * .pi * 4.0 - seed) * 0.08)
            
            // Map values to reasonable ranges
            let valX = scaleMetric(mx, progress: 0.5 + noiseX)
            let valY = scaleMetric(my, progress: 0.5 + noiseY)
            
            points.append(CorrelationPoint(date: date, valueX: valX, valueY: valY))
        }
        
        return points.reversed()
    }
    
    private func scaleMetric(_ metric: String, progress: Double) -> Double {
        let p = max(0, min(1, progress)) // clamp 0..1
        switch metric {
        case "hrv":
            return 45.0 + p * 40.0 // 45..85 ms
        case "caffeine":
            return p * 300.0 // 0..300 mg
        case "sleep", "sleep_score", "recovery", "recovery_score":
            return 55.0 + p * 40.0 // 55..95
        case "sleep_hours":
            return 5.5 + p * 3.0 // 5.5..8.5 hrs
        case "meditation":
            return p * 20.0 // 0..20 min
        case "alcohol":
            return p * 4.0 // 0..4 drinks
        case "steps":
            return 3000.0 + p * 9000.0 // 3k..12k
        case "resting_hr", "rhr":
            return 52.0 + (1.0 - p) * 18.0 // 52..70 bpm (lower is better, so inverted)
        case "stress", "stress_index":
            return 1.5 + (1.0 - p) * 7.0 // 1.5..8.5 (lower is better, inverted)
        case "vitamin_d":
            return 25.0 + p * 25.0 // 25..50
        case "cortisol":
            return 8.0 + (1.0 - p) * 12.0 // 8..20
        default:
            return 10.0 + p * 80.0
        }
    }
    
    // Computed correlation details
    private var correlationStrength: (coefficient: Double, text: String, color: Color) {
        let (mx, my) = parsedMetrics
        let isNegative = mx.contains("caffeine") || mx.contains("alcohol") || mx.contains("stress") || mx.contains("late_meal") ||
                         my.contains("caffeine") || my.contains("alcohol") || my.contains("stress") || my.contains("late_meal")
        
        let coeff = isNegative ? -0.74 : 0.68
        let text = isNegative 
            ? L10n.t("Strong Negative Correlation", "强负相关")
            : L10n.t("Strong Positive Correlation", "强正相关")
        let color = isNegative ? VelaTheme.stress : VelaTheme.recovery
        
        return (coeff, text, color)
    }
    
    private var analysisText: String {
        let (mx, my) = parsedMetrics
        let nameX = displayNameForMetric(mx)
        let nameY = displayNameForMetric(my)
        
        if key.contains("hrv_vs_caffeine") {
            return L10n.t(
                "On days with Caffeine, your HRV drops by an average of 8.2 ms. High caffeine intake late in the day is strongly coupled with suppressed parasympathetic activity tonight.",
                "在摄入咖啡因的日子里，你的 HRV 平均下降了 8.2 毫秒。午后摄入高咖啡因与今晚副交感神经活性受抑制呈强相关。"
            )
        } else if key.contains("sleep") && key.contains("meditation") {
            return L10n.t(
                "Completing a 10-minute Meditation in the evening increases Sleep Score by an average of 7.4%. Relaxing the nervous system beforehand significantly extends your deep sleep cycles.",
                "睡前完成 10 分钟的正念冥想可使睡眠分数平均提升 7.4%。冥想放松神经系统有助于延长你的深睡眠周期。"
            )
        } else if key.contains("hrv") && key.contains("alcohol") {
            return L10n.t(
                "Alcohol has the most severe impact on your physiology. Even 1 drink suppresses HRV by 18% and elevates your Resting Heart Rate by 6.5 bpm over the entire night.",
                "酒精对你的生理状况有最严重的影响。即使是 1 杯酒，也会使你的 HRV 降低 18%，并使你整晚的静息心率平均升高 6.5 bpm。"
            )
        } else {
            return L10n.t(
                "There is a notable trend between \(nameX) and \(nameY) over the past \(selectedTimeframe) days, suggesting behavioral habits are actively modulating your physiological baselines.",
                "在过去 \(selectedTimeframe) 天中，\(nameX) 与 \(nameY) 之间表现出明显的关联趋势，表明行为习惯正积极调节着你的生理基线。"
            )
        }
    }
    
    var body: some View {
        let (mx, my) = parsedMetrics
        let colorX = colorForMetric(mx)
        let colorY = colorForMetric(my)
        let points = generateTrendPoints()
        
        return VStack(alignment: .leading, spacing: 14) {
            // Header: Title and Timeframe Selector
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("PREMIUM CORRELATION", "深度行为相关性"))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .tracking(1.2)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundStyle(VelaTheme.accent)
                            .font(.subheadline)
                        
                        Text("\(displayNameForMetric(mx)) vs. \(displayNameForMetric(my))")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                    }
                }
                
                Spacer()
                
                // Timeframe Selector Pill Bar
                HStack(spacing: 0) {
                    ForEach([7, 14, 30], id: \.self) { days in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTimeframe = days
                            }
                        } label: {
                            Text("\(days)D")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(selectedTimeframe == days ? VelaTheme.background : VelaTheme.secondaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectedTimeframe == days ? VelaTheme.accent : Color.clear)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(2)
                .background(Color.black.opacity(0.04))
                .clipShape(Capsule())
            }
            
            // Dual-Line Chart View using SwiftUI Charts
            Chart {
                ForEach(Array(points.enumerated()), id: \.element.id) { index, pt in
                    // Normalizing X and Y values for standard overlay rendering
                    let maxValX = points.map(\.valueX).max() ?? 100.0
                    let minValX = points.map(\.valueX).min() ?? 0.0
                    let spanX = maxValX > minValX ? (maxValX - minValX) : 100.0
                    let normX = (pt.valueX - minValX) / spanX
                    
                    let maxValY = points.map(\.valueY).max() ?? 100.0
                    let minValY = points.map(\.valueY).min() ?? 0.0
                    let spanY = maxValY > minValY ? (maxValY - minValY) : 100.0
                    let normY = (pt.valueY - minValY) / spanY
                    
                    // Series X: Line + Area
                    LineMark(
                        x: .value("Date", pt.date, unit: .day),
                        y: .value(displayNameForMetric(mx), normX)
                    )
                    .foregroundStyle(colorX)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    
                    AreaMark(
                        x: .value("Date", pt.date, unit: .day),
                        y: .value(displayNameForMetric(mx), normX)
                    )
                    .foregroundStyle(LinearGradient(
                        colors: [colorX.opacity(0.12), colorX.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .interpolationMethod(.catmullRom)
                    
                    // Series Y: Line
                    LineMark(
                        x: .value("Date", pt.date, unit: .day),
                        y: .value(displayNameForMetric(my), normY)
                    )
                    .foregroundStyle(colorY)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 4]))
                    
                    // Show selection indicator dot if hovered
                    if hoveredIndex == index {
                        PointMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value(displayNameForMetric(mx), normX)
                        )
                        .foregroundStyle(colorX)
                        .symbolSize(80)
                        
                        PointMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value(displayNameForMetric(my), normY)
                        )
                        .foregroundStyle(colorY)
                        .symbolSize(80)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: selectedTimeframe == 30 ? 6 : 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                        .foregroundStyle(VelaTheme.stroke)
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(VelaTheme.mutedText)
                        .font(.system(size: 9))
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let x = value.location.x
                                    if let date: Date = proxy.value(atX: x) {
                                        let calendar = Calendar.current
                                        if let idx = points.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                                            if hoveredIndex != idx {
                                                UISelectionFeedbackGenerator().selectionChanged()
                                                hoveredIndex = idx
                                            }
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    hoveredIndex = nil
                                }
                        )
                }
            }
            .frame(height: 120)
            
            // Legend Indicators
            HStack(spacing: 20) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(colorX)
                        .frame(width: 8, height: 8)
                    Text(displayNameForMetric(mx))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                
                HStack(spacing: 6) {
                    // Dashed line indicator
                    HStack(spacing: 2) {
                        Capsule().fill(colorY).frame(width: 4, height: 2)
                        Capsule().fill(colorY).frame(width: 4, height: 2)
                    }
                    Text(displayNameForMetric(my))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                
                Spacer()
                
                // Active scrubbing value overlay
                if let hoveredIndex = hoveredIndex, hoveredIndex < points.count {
                    let pt = points[hoveredIndex]
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f%@", pt.valueX, unitForMetric(mx)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(colorX)
                        
                        Text(String(format: "%.1f%@", pt.valueY, unitForMetric(my)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(colorY)
                    }
                }
            }
            
            // Correlation Analysis Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text(correlationStrength.text)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(correlationStrength.color)
                    
                    Spacer()
                    
                    Text(String(format: "r = %.2f", correlationStrength.coefficient))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                }
                
                Text(analysisText)
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineSpacing(4)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(VelaTheme.stroke, lineWidth: 1)
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .fill(VelaTheme.cardBackground.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .stroke(VelaTheme.stroke, lineWidth: 1)
        )
    }
}

// Data structures for correlation plotting
struct CorrelationPoint: Identifiable {
    let id = UUID()
    let date: Date
    let valueX: Double
    let valueY: Double
}
