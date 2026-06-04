import SwiftUI
import SwiftData

struct FitnessActivitySummaryDetailView: View {
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \DailyHealthSummaryRecord.date, order: .forward) private var records: [DailyHealthSummaryRecord]
    @Query(sort: \WorkoutEventRecord.startedAt, order: .forward) private var workoutEvents: [WorkoutEventRecord]

    private var recentRecords: [DailyHealthSummaryRecord] {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dashboardVM.selectedDate))
            ?? dashboardVM.selectedDate
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        return records.filter { $0.date >= start && $0.date < end }
    }

    private var activeDays: Int {
        recentRecords.filter {
            ($0.workoutCount ?? 0) > 0 || ($0.activeCalories ?? 0) > 0 || ($0.workoutDuration ?? 0) > 0
        }.count
    }

    private var workoutCount: Int {
        recentRecords.compactMap(\.workoutCount).reduce(0, +)
    }

    private var workoutMinutes: Int {
        Int(recentRecords.compactMap(\.workoutDuration).reduce(0, +).rounded())
    }

    private var activeCalories: Int {
        Int(recentRecords.compactMap(\.activeCalories).reduce(0, +).rounded())
    }

    private var averageStrain: Double? {
        let values = recentRecords.compactMap(\.strainScore)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var recentWorkoutEvents: [WorkoutEventRecord] {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: dashboardVM.selectedDate))
            ?? dashboardVM.selectedDate
        let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        return workoutEvents.filter { $0.startedAt >= start && $0.startedAt < end }
    }

    private var workoutHeartRates: [Double] {
        recentWorkoutEvents.compactMap(\.averageHeartRate)
    }

    private var averageWorkoutHeartRate: Double? {
        guard !workoutHeartRates.isEmpty else { return nil }
        return workoutHeartRates.reduce(0, +) / Double(workoutHeartRates.count)
    }

    private var maxWorkoutHeartRate: Double? {
        workoutHeartRates.max()
    }

    private var chartPoints: [CGPoint] {
        let values = recentRecords.compactMap(\.strainScore)
        guard values.count > 1 else { return [] }
        let low = values.min() ?? 0
        let high = values.max() ?? low
        let range = high - low
        return values.enumerated().map { index, value in
            let x = Double(index) / Double(max(values.count - 1, 1))
            let normalized = range > 0 ? (value - low) / range : 0.5
            return CGPoint(x: x, y: 0.9 - normalized * 0.78)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryHero
                activityStats
                workoutHeartRateCard
                trendCard
                guidanceCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(detailBackground.ignoresSafeArea())
        .navigationTitle("活动摘要")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("过去 30 天")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
            Text("\(workoutMinutes / 60)小时 \(workoutMinutes % 60)分钟")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text("Apple 健康训练与日常活动汇总")
                .font(.system(size: 13))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activityCardBackground)
    }

    private var activityStats: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            activityStat(title: "活跃天数", value: "\(activeDays) 天", icon: "calendar")
            activityStat(title: "训练次数", value: "\(workoutCount) 次", icon: "figure.run")
            activityStat(title: "活动消耗", value: "\(activeCalories) kcal", icon: "flame.fill")
            activityStat(title: "平均耗力", value: averageStrain.map { String(format: "%.0f", $0) } ?? "--", icon: "bolt.heart.fill")
        }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("耗力趋势")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(VelaTheme.fg)
            if chartPoints.isEmpty {
                Text("积累至少 2 天记录后显示趋势。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            } else {
                AreaChartCurveView(points: chartPoints)
                    .frame(height: 112)
            }
        }
        .padding(16)
        .background(activityCardBackground)
    }

    private var workoutHeartRateCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("训练心率波动")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("来自统一训练记录的平均心率")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(averageWorkoutHeartRate.map { "\(Int($0.rounded()))" } ?? "--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.fg)
                    Text("bpm 平均")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                }
            }

            if workoutHeartRates.count < 2 {
                Text("导入或同步至少 2 次带心率的训练后显示波动图。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            } else {
                WorkoutHeartRateRibbonView(values: workoutHeartRates)
                    .frame(height: 126)
                HStack {
                    Label("峰值 \(Int((maxWorkoutHeartRate ?? 0).rounded())) bpm", systemImage: "heart.fill")
                    Spacer()
                    Text("\(workoutHeartRates.count) 次训练")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.accent)
            }
        }
        .padding(16)
        .background(activityCardBackground)
    }

    private var guidanceCard: some View {
        Button {
            VelaAppState.shared.routeToCoach(
                question: "请结合我过去 30 天的活动摘要、耗力趋势、恢复和睡眠，给出下一次训练的明确建议。"
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .foregroundStyle(VelaTheme.accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("让 Coach 分析活动趋势")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("结合恢复、睡眠和能量给出下一步建议")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#BFB9AC"))
            }
            .padding(16)
            .background(activityCardBackground)
        }
        .buttonStyle(.plain)
    }

    private func activityStat(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VelaTheme.accent)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.muted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activityCardBackground)
    }

    private var activityCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(VelaTheme.cardBg)
            .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
            )
    }

    private var detailBackground: some View {
        ZStack {
            VelaTheme.systemGroupedBackground
            LinearGradient(
                colors: [Color(hex: "#EAF3FF"), VelaTheme.systemGroupedBackground, Color(hex: "#EEF7F5")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct AreaChartCurveView: View {
    let points: [CGPoint]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    guard points.count > 1 else { return }
                    path.move(to: CGPoint(x: 0, y: geo.size.height))
                    for pt in points {
                        let x = pt.x * geo.size.width
                        let y = pt.y * geo.size.height
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#FFAB91").opacity(0.24), Color(hex: "#FFAB91").opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                Path { path in
                    guard points.count > 1 else { return }
                    for idx in 0..<points.count {
                        let pt = points[idx]
                        let x = pt.x * geo.size.width
                        let y = pt.y * geo.size.height
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(VelaTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                ForEach(0..<points.count, id: \.self) { idx in
                    let pt = points[idx]
                    if idx % 3 == 0 || idx == points.count - 1 {
                        let x = pt.x * geo.size.width
                        let y = pt.y * geo.size.height
                        Circle()
                            .fill(VelaTheme.cardBg)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(VelaTheme.accent, lineWidth: 1.5))
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}

struct WorkoutHeartRateRibbonView: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let minValue = max(40, (values.min() ?? 60) - 8)
            let maxValue = max(minValue + 1, (values.max() ?? 120) + 8)
            let range = maxValue - minValue
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(hex: "#EAF3FF"))
                    .frame(height: geo.size.height * 0.42)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.52)

                ForEach(0..<4, id: \.self) { idx in
                    Rectangle()
                        .fill(Color(hex: "#E5E5EA"))
                        .frame(height: 0.7)
                        .position(x: geo.size.width / 2, y: geo.size.height * CGFloat(idx + 1) / 5)
                }

                Path { path in
                    guard values.count > 1 else { return }
                    for index in values.indices {
                        let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * geo.size.width
                        let normalized = (values[index] - minValue) / range
                        let y = geo.size.height - CGFloat(normalized) * (geo.size.height - 14) - 7
                        if index == values.startIndex {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#FF7043"), Color(hex: "#EF5350"), Color(hex: "#AB47BC")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                ForEach(values.indices, id: \.self) { index in
                    if index == values.startIndex || index == values.index(before: values.endIndex) || index % 3 == 0 {
                        let x = CGFloat(index) / CGFloat(max(values.count - 1, 1)) * geo.size.width
                        let normalized = (values[index] - minValue) / range
                        let y = geo.size.height - CGFloat(normalized) * (geo.size.height - 14) - 7
                        Circle()
                            .fill(VelaTheme.cardBg)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().stroke(Color(hex: "#EF5350"), lineWidth: 1.5))
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
