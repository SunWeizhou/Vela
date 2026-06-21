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
    let id = UUID()
    let date: Date
    let value: Double
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Segment Selector
            HStack {
                Picker("时间区间", selection: $selectedRange) {
                    ForEach(DetailTimeRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                
                Spacer()
                if rawSelectedDate != nil {
                    // Scrub indicator info
                    Text(displayDateText)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        .padding(.trailing, 16)
                }
            }
            
            // Value and Status
            VStack(alignment: .leading, spacing: 4) {
                Text(dynamicValueText)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isSleep ? Color(hex: "#F2EFE8") : VelaTheme.fg)
                
                Text(rawSelectedDate != nil ? "选定读数" : metricSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
            }
            .padding(.horizontal, 16)
            
            // The Swift Chart!
            if points.isEmpty {
                VStack {
                    Spacer()
                    Text(selectedRange == .day ? "当天仅有日汇总；切换至 7 天查看真实趋势" : "暂无趋势数据")
                        .font(.system(size: 13))
                        .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    Spacer()
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            } else {
                Chart {
                    let unit: Calendar.Component = selectedRange == .day ? .hour : .day
                    ForEach(points) { pt in
                        if isBarChart {
                            BarMark(
                                x: .value("Date", pt.date, unit: unit),
                                y: .value("Value", pt.value)
                            )
                            .foregroundStyle(metricColor)
                            .cornerRadius(3)
                        } else {
                            // Line Graph with Area Mark
                            LineMark(
                                x: .value("Date", pt.date, unit: unit),
                                y: .value("Value", pt.value)
                            )
                            .foregroundStyle(metricColor)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Date", pt.date, unit: unit),
                                y: .value("Value", pt.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [metricColor.opacity(0.24), metricColor.opacity(0.0)]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
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
                                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: points.count > 10 ? points.count / 5 : 2)) { value in
                            AxisValueLabel(format: .dateTime.month().day(), centered: true)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                            .foregroundStyle(isSleep ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                        AxisValueLabel()
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(isSleep ? Color(hex: "#7E7A70") : VelaTheme.muted)
                    }
                }
                .chartXSelection(value: $rawSelectedDate)
                .frame(height: 160)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .onChange(of: rawSelectedDate) { oldValue, newValue in
                    if newValue != nil {
                        VelaHaptic.selection()
                    }
                }
            }
        }
        .padding(.vertical, 14)
    }
}
