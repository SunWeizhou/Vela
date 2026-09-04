import SwiftUI
import Charts

/// Small Swift Charts renderer for the Store-owned value series.  It renders
/// only contiguous non-missing runs, a supplied personal baseline band, and a
/// selected point for provenance drill-down.  It does not fetch SwiftData or
/// infer values.
struct TrendsOneMetricChart: View {
    let series: TrendsMetricSeries
    @Binding var selectedDate: Date?
    var tint: Color = .accentColor

    var body: some View {
        Chart {
            if let baselineBand = series.baselineBand,
               let firstDate = series.points.first?.date,
               let lastDate = series.points.last?.date {
                RectangleMark(
                    xStart: .value("Baseline start", firstDate, unit: .day),
                    xEnd: .value("Baseline end", lastDate, unit: .day),
                    yStart: .value("Baseline lower", baselineBand.lowerBound),
                    yEnd: .value("Baseline upper", baselineBand.upperBound)
                )
                .foregroundStyle(tint.opacity(0.10))
            }

            ForEach(Array(series.nonMissingSegments.enumerated()), id: \.offset) { index, segment in
                ForEach(segment) { point in
                    if let value = point.value {
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Value", value),
                            series: .value("Segment", index)
                        )
                        .foregroundStyle(tint)
                        .interpolationMethod(.linear)
                    }
                }
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected date", selected.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.5))
                if let value = selected.value {
                    PointMark(
                        x: .value("Selected point date", selected.date, unit: .day),
                        y: .value("Selected point value", value)
                    )
                    .foregroundStyle(tint)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .frame(height: 180)
        .accessibilityLabel("\(series.metric.title)趋势图")
        .accessibilityValue("真实读数 \(series.points.compactMap(\.value).count) 个")
    }

    private var selectedPoint: TrendsChartPoint? {
        guard let selectedDate else { return nil }
        return series.points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }
}
