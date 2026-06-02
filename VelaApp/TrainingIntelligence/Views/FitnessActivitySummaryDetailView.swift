import SwiftUI
import SwiftData

struct FitnessActivitySummaryDetailView: View {
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \DailyHealthSummaryRecord.date, order: .forward) private var records: [DailyHealthSummaryRecord]

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
                trendCard
                guidanceCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 80)
        }
        .scrollIndicators(.hidden)
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("活动摘要")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("过去 30 天")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color(hex: "#8E8A80"))
            Text("\(workoutMinutes / 60)小时 \(workoutMinutes % 60)分钟")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A1917"))
            Text("Apple 健康训练与日常活动汇总")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#8E8A80"))
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
                .foregroundStyle(Color(hex: "#1A1917"))
            if chartPoints.isEmpty {
                Text("积累至少 2 天记录后显示趋势。")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            } else {
                AreaChartCurveView(points: chartPoints)
                    .frame(height: 112)
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
                    .foregroundStyle(Color(hex: "#C56B4A"))
                VStack(alignment: .leading, spacing: 3) {
                    Text("让 Coach 分析活动趋势")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text("结合恢复、睡眠和能量给出下一步建议")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#8E8A80"))
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
                .foregroundStyle(Color(hex: "#C56B4A"))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A1917"))
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(hex: "#8E8A80"))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(activityCardBackground)
    }

    private var activityCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
            )
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
                .stroke(Color(hex: "#C56B4A"), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                
                ForEach(0..<points.count, id: \.self) { idx in
                    let pt = points[idx]
                    if idx % 3 == 0 || idx == points.count - 1 {
                        let x = pt.x * geo.size.width
                        let y = pt.y * geo.size.height
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(Color(hex: "#C56B4A"), lineWidth: 1.5))
                            .position(x: x, y: y)
                    }
                }
            }
        }
    }
}
