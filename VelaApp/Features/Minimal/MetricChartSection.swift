import SwiftUI
import Charts

enum DetailTimeRange: String, CaseIterable, Identifiable {
    case week, month, halfYear, day
    
    var id: String { rawValue }
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .halfYear: return 180
        case .day: return 1
        }
    }
    var title: String {
        switch self {
        case .week: return "7天"
        case .month: return "30天"
        case .halfYear: return "6个月"
        case .day: return "今天"
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
        VStack(alignment: .leading, spacing: 14) {
            // Header Top Bar: Range Picker & Active Date
            HStack(spacing: 8) {
                rangePicker
                Spacer()

                if rawSelectedDate != nil {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(metricColor)
                            .frame(width: 6, height: 6)
                        Text(displayDateText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInk)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(metricColor.opacity(0.12)))
                }
            }
            .padding(.horizontal, 14)
            
            // Value and Status Row
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(dynamicValueText)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VelaTheme.rhythmInk)

                    if rawSelectedDate == nil {
                        Text(metricSubtitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(metricColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(metricColor.opacity(0.12))
                            )
                    } else {
                        Text("按住滑动查看历史")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            
            // The Swift Chart!
            if points.isEmpty {
                VelaStateCard(
                    state: selectedRange == .day ? .empty : .calibrating,
                    message: selectedRange == .day
                        ? "今天尚无读数，可在上方切换至 7 天或 30 天查看趋势。"
                        : "继续佩戴设备并同步数据以建立趋势。"
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            } else if points.count < 3 && selectedRange != .day {
                VelaStateCard(
                    state: .calibrating,
                    message: "目前已有 \(points.count) 个读数，累计 3 个后展示个人基线与区间。"
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
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
                            .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .trailing, alignment: .trailing) {
                                Text("基线")
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.8))
                                    .padding(.trailing, 2)
                            }
                    }

                    ForEach(Array(chartSegments.enumerated()), id: \.offset) { segmentIndex, segment in
                        ForEach(segment) { pt in
                            if isBarChart {
                                BarMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value)
                                )
                                .foregroundStyle(metricColor.gradient)
                                .cornerRadius(4)
                            } else {
                                LineMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value),
                                    series: .value("Segment", segmentIndex)
                                )
                                .foregroundStyle(metricColor)
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .interpolationMethod(.catmullRom)

                                AreaMark(
                                    x: .value("Date", pt.date, unit: unit),
                                    y: .value("Value", pt.value),
                                    series: .value("Area segment", segmentIndex)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [metricColor.opacity(0.24), metricColor.opacity(0.01)],
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
                        .foregroundStyle(VelaTheme.rhythmInkSecondary.opacity(0.3))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        
                        PointMark(
                            x: .value("SelectedDatePoint", selectedPoint.date, unit: unit),
                            y: .value("SelectedValuePoint", selectedPoint.value)
                        )
                        .foregroundStyle(metricColor)
                        .symbolSize(88)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VelaTheme.rhythmMist.opacity(0.6))
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VelaTheme.rhythmMist.opacity(0.6))
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    }
                }
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 175)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .accessibilityLabel("\(metricSubtitle)趋势图，共\(points.count)个真实读数")
                .accessibilityValue(dynamicValueText)
                .onChange(of: rawSelectedDate) { oldValue, newValue in
                    if newValue != nil && oldValue == nil {
                        VelaHaptic.selection()
                    }
                }
            }
        }
        .padding(.vertical, 14)
        .background(VelaTheme.rhythmCanvasRaised, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(selectedRange == range ? VelaTheme.rhythmInk : VelaTheme.rhythmInkSecondary)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 28)
                        .background(
                            Capsule(style: .continuous)
                                .fill(selectedRange == range ? VelaTheme.rhythmCanvasRaised : Color.clear)
                        )
                }
                .buttonStyle(.cardPress)
                .accessibilityAddTraits(selectedRange == range ? .isSelected : [])
            }
        }
        .padding(3)
        .background(VelaTheme.rhythmMist.opacity(0.4), in: Capsule(style: .continuous))
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
