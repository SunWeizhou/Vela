import SwiftUI
import Charts

enum DetailTimeRange: String, CaseIterable, Identifiable {
    case day, week, month, halfYear
    
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .halfYear: return 180
        }
    }
    var title: String {
        switch self {
        case .day: return "今天"
        case .week: return "7天"
        case .month: return "30天"
        case .halfYear: return "6个月"
        }
    }
}

struct ChartPoint: Identifiable {
    let date: Date
    let value: Double
    var id: Date { date }
}

enum VelaChartSegmentation {
    static func segments(points: [ChartPoint], maximumGap: TimeInterval) -> [[ChartPoint]] {
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return [] }

        return sorted.dropFirst().reduce(into: [[sorted[0]]]) { segments, point in
            guard let last = segments.last?.last else { return }
            if point.date.timeIntervalSince(last.date) > maximumGap {
                segments.append([point])
            } else {
                segments[segments.count - 1].append(point)
            }
        }
    }
}

struct MetricChartSection: View {
    let metric: VelaMetricDetailView.MetricType
    let isSleep: Bool
    let points: [ChartPoint]
    let isBarChart: Bool
    let metricColor: Color
    @Binding var selectedRange: DetailTimeRange
    @Binding var rawSelectedDate: Date?
    let displayDateText: String
    let dynamicValueText: String
    let metricSubtitle: String
    var baselineValue: Double? = nil
    var targetRange: ClosedRange<Double>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                rangePicker
                Spacer()

                if rawSelectedDate != nil {
                    Text(displayDateText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg2)
                        .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 14)
            
            // Value and Status
            VStack(alignment: .leading, spacing: 4) {
                Text(dynamicValueText)
                    .font(.largeTitle.weight(.bold).monospacedDigit())
                    .foregroundStyle(isSleep ? VelaTheme.sleepText : VelaTheme.fg)
                
                Text(rawSelectedDate != nil ? "选定读数" : metricSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSleep ? VelaTheme.inkGray : VelaTheme.muted)
            }
            .padding(.horizontal, 16)
            
            // The Swift Chart!
            if points.isEmpty {
                VelaStateCard(
                    state: selectedRange == .day ? .empty : .calibrating,
                    message: selectedRange == .day
                        ? "今天尚无可绘制的真实读数，可切换至 7 天查看历史趋势。"
                        : "继续佩戴设备并同步数据，Vela 不会用插值伪造缺失趋势。"
                )
                .padding(.horizontal, 14)
            } else if points.count < 3 {
                VelaStateCard(
                    state: .calibrating,
                    message: "目前只有 \(points.count) 个真实读数；达到 3 个后显示方向与个人基线。"
                )
                .padding(.horizontal, 14)
            } else {
                Chart {
                    let unit: Calendar.Component = selectedRange == .day ? .hour : .day

                    if let targetRange,
                       let firstDate = points.first?.date,
                       let lastDate = points.last?.date {
                        RectangleMark(
                            xStart: .value("Target start", firstDate, unit: unit),
                            xEnd: .value("Target end", lastDate, unit: unit),
                            yStart: .value("Target lower", targetRange.lowerBound),
                            yEnd: .value("Target upper", targetRange.upperBound)
                        )
                        .foregroundStyle(metricColor.opacity(0.08))
                    }

                    if let effectiveBaseline {
                        RuleMark(y: .value("Personal baseline", effectiveBaseline))
                            .foregroundStyle(VelaTheme.muted.opacity(0.58))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }

                    ForEach(Array(chartSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                        ForEach(segment) { pt in
                            if isBarChart {
                                BarMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value)
                                )
                                .foregroundStyle(metricColor)
                                .cornerRadius(3)
                            } else {
                                LineMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value),
                                    series: .value("Segment", segmentIndex)
                                )
                                .foregroundStyle(metricColor)
                                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value),
                                    series: .value("Area segment", segmentIndex)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [metricColor.opacity(0.20), metricColor.opacity(0.0)]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .interpolationMethod(.catmullRom)
                            }
                        }
                    }
                    
                    // Scrub vertical line and dot overlay
                    if let selectedPoint = points.min(by: {
                        guard let rawSelectedDate else { return false }
                        return abs($0.date.timeIntervalSince(rawSelectedDate)) < abs($1.date.timeIntervalSince(rawSelectedDate))
                    }), rawSelectedDate != nil {
                        RuleMark(
                            x: .value("SelectedDate", selectedPoint.date, unit: unit)
                        )
                        .foregroundStyle(isSleep ? Color.white.opacity(0.25) : Color.black.opacity(0.12))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        
                        PointMark(
                            x: .value("SelectedDatePoint", selectedPoint.date, unit: unit),
                            y: .value("SelectedValuePoint", selectedPoint.value)
                        )
                        .foregroundStyle(metricColor)
                        .symbolSize(80)
                    }
                }
                .chartXAxis {
                    if selectedRange == .day {
                        AxisMarks(values: .stride(by: .hour, count: 4)) { value in
                            AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), centered: true)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: points.count > 10 ? points.count / 5 : 2)) { value in
                            AxisValueLabel(format: .dateTime.month().day(), centered: true)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(VelaTheme.muted)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(VelaTheme.separatorSoft)
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 160)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .accessibilityLabel("\(metricSubtitle)趋势图，共\(points.count)个真实读数")
                .accessibilityValue(dynamicValueText)
                .onChange(of: rawSelectedDate) { oldValue, newValue in
                    if newValue != nil {
                        VelaHaptic.selection()
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .background(VelaTheme.cardBg, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.borderSoft.opacity(0.65), lineWidth: 0.5)
        )
    }

    private var rangePicker: some View {
        HStack(spacing: 3) {
            ForEach(DetailTimeRange.allCases) { range in
                Button {
                    guard selectedRange != range else { return }
                    selectedRange = range
                    rawSelectedDate = nil
                    VelaHaptic.selection()
                } label: {
                    Text(range.title)
                        .font(VelaTheme.caption2().weight(.semibold))
                        .foregroundStyle(selectedRange == range ? VelaTheme.fg : VelaTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 32)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedRange == range ? VelaTheme.cardBg : Color.clear)
                        )
                }
                .buttonStyle(.cardPress)
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(3)
        .background(VelaTheme.secondaryGroupedBackground, in: Capsule(style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("时间区间")
    }

    private var effectiveBaseline: Double? {
        if let baselineValue { return baselineValue }
        guard points.count >= 3 else { return nil }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private var chartSegments: [[ChartPoint]] {
        let maximumGap: TimeInterval = selectedRange == .day ? 2 * 60 * 60 : 36 * 60 * 60
        return VelaChartSegmentation.segments(points: points, maximumGap: maximumGap)
    }
}
