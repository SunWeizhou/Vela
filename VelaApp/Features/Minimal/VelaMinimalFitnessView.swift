import SwiftUI
import SwiftData

// MARK: - VelaTrainingView — Bevel Replica Fitness Tab
// Double-Month thinned activity heatmaps × Area workouts summary × Target safe-zone Exertion workload chart

struct VelaTrainingView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    @State private var previousMonthActiveTiers: [Int: Int] = [:]
    @State private var currentMonthActiveTiers: [Int: Int] = [:]

    // Dynamic states for statistics & trend graphs
    @State private var totalWorkoutDurationText = "--"
    @State private var summaryWorkPathPoints: [CGPoint] = []
    @State private var dynamicExertionWorkload: [Double] = []
    @State private var changePercentageText = "--"
    @State private var isExertionBelowTarget: Bool = true
    @State private var recentWorkouts: [WorkoutSummary] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Fitness Title Header
                fitnessHeader
                
                // 2. Double-Month Thinned Activity Heatmap Card
                activityHeatmapCard
                
                // 3. Activity Summary Card (活动摘要 with orange filled area curve)
                activitySummaryCard
                
                // 4. Exertion Fatigue Load Card (耗力表现 with safe-zone range band)
                exertionLoadCard

                recentWorkoutsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(Color(hex: "#F5F3F0")) // Warm canvas base
        .task {
            await syncRealFitnessData()
        }
        .refreshable {
            await syncRealFitnessData()
        }
        .onChange(of: dashboardVM.selectedDate) { _ in
            Task {
                await syncRealFitnessData()
            }
        }
    }

    // MARK: - Fitness Title Header
    private var fitnessHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("健身")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Text("过去 30 天")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    VelaAppState.shared.routeToCoach(question: trainingAnalysisQuestion)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                        Text("分析")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(Color(hex: "#1A1917"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                    .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    VelaAppState.shared.triggerWorkoutLog = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Double-Month Activity Heatmap Card
    private var activityHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                monthHeatmap(
                    monthTitle: monthTitle(for: previousMonthStart),
                    totalDays: dayCount(in: previousMonthStart),
                    startOffset: startOffset(for: previousMonthStart),
                    activeTiers: previousMonthActiveTiers
                )
                
                monthHeatmap(
                    monthTitle: monthTitle(for: currentMonthStart),
                    totalDays: dayCount(in: currentMonthStart),
                    startOffset: startOffset(for: currentMonthStart),
                    activeTiers: currentMonthActiveTiers
                )
            }
            
            // Legend
            HStack(spacing: 12) {
                legendItem(color: Color(hex: "#A5D6A7"), label: "1 项活动")
                legendItem(color: Color(hex: "#66BB6A"), label: "2 项活动")
                legendItem(color: Color(hex: "#29B6F6"), label: "3+ 活动")
            }
            .padding(.top, 4)
            .padding(.leading, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
        )
    }

    // Individual Month Heatmap builder
    private func monthHeatmap(
        monthTitle: String,
        totalDays: Int,
        startOffset: Int,
        activeTiers: [Int: Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(hex: "#8E8A80"))
            
            // Grid Header Days
            HStack(spacing: 5) {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { d in
                    Text(d)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                        .frame(width: 16)
                }
            }
            
            // Grid Cells
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(16), spacing: 5), count: 7),
                spacing: 5
            ) {
                // Empty padding offset cells
                ForEach(0..<startOffset, id: \.self) { _ in
                    Color.clear
                        .frame(width: 16, height: 16)
                }
                
                // Active calendar days
                ForEach(1...totalDays, id: \.self) { day in
                    let tier = activeTiers[day] ?? 0
                    let cellColor: Color = {
                        switch tier {
                        case 1:  return Color(hex: "#C8E6C9") // light green
                        case 2:  return Color(hex: "#81C784") // medium green
                        case 3:  return Color(hex: "#29B6F6") // teal-blue
                        default: return Color(hex: "#ECEFF1") // light grey/off-white
                        }
                    }()
                    
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(cellColor)
                        .frame(width: 16, height: 16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#8E8A80"))
        }
    }

    // MARK: - Activity Summary Card (活动摘要 with orange filled area curve)
    private var activitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                    
                    Text("活动摘要")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#BFB9AC"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(totalWorkoutDurationText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#1A1917"))
                
                HStack(spacing: 8) {
                    Text("过去 30 天耗力趋势")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
            }
            
            // Filled Workload Area Chart
            ZStack(alignment: .topTrailing) {
                // Main Area / Line Canvas
                AreaChartCurveView(points: summaryWorkPathPoints)
                    .frame(height: 100)
                    .padding(.top, 10)
                
                Text("21")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#BFB9AC"))
                    .offset(y: -4)
                
                // Chart timeline labels
                HStack {
                    Text("30天前")
                    Spacer()
                    Text("15天前")
                    Spacer()
                    Text("今天")
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(hex: "#BFB9AC"))
                .padding(.top, 114)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
        )
    }

    // MARK: - Exertion Fatigue Load Card (耗力表现 with safe-zone range band)
    private var exertionLoadCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                    
                    Text("耗力表现")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: "#BFB9AC"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(changePercentageText)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#1A1917"))
                
                Text(dynamicExertionWorkload.isEmpty ? "暂无耗力记录" : (isExertionBelowTarget ? "低于目标值" : "高于目标值"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isExertionBelowTarget ? Color(hex: "#4285F4") : Color(hex: "#66BB6A")) // Soft Blue or Green
            }
            
            // Workload graph with Safe Range Band
            SafeZoneWorkloadChartView(workload: dynamicExertionWorkload)
                .frame(height: 72)
                .padding(.vertical, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
        )
    }

    private var currentMonthStart: Date {
        monthStart(for: dashboardVM.selectedDate)
    }

    private var previousMonthStart: Date {
        Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
    }

    private func monthStart(for date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func dayCount(in date: Date) -> Int {
        Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 0
    }

    private func startOffset(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date) - 1
    }

    private var trainingAnalysisQuestion: String {
        "请结合我过去 30 天的 Apple 健康训练记录、耗力趋势、恢复、睡眠和能量，分析训练状态并给出下一次训练建议。"
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple 健康训练记录")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1917"))

            if recentWorkouts.isEmpty {
                Text("暂无可读取的训练记录")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
            } else {
                ForEach(recentWorkouts.prefix(8)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.run")
                                .foregroundStyle(Color(hex: "#C56B4A"))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.activityName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#1A1917"))
                                Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                            }
                            Spacer()
                            Text("\(Int(workout.end.timeIntervalSince(workout.start) / 60)) 分钟")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#BFB9AC"))
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - SwiftData and HealthKit loader
    private func syncRealFitnessData() async {
        await dashboardVM.refresh(modelContext: modelContext)
        loadRealFitnessData()
        recentWorkouts = (try? await HealthKitQueryService().recentWorkouts(limit: 30)) ?? []
    }

    private func loadRealFitnessData() {
        let calendar = Calendar.current
        let now = dashboardVM.selectedDate
        
        let currentMonthStart = monthStart(for: now)
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? now
        
        // Fetch all records to filter in memory (highly performant and compile-safe)
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            sortBy: [SortDescriptor(\DailyHealthSummaryRecord.date, order: .forward)]
        )
        
        do {
            let allRecords = try modelContext.fetch(descriptor)
            
            let records = allRecords.filter { $0.date >= previousMonthStart && $0.date < nextMonthStart }
            
            var apTiers: [Int: Int] = [:]
            var myTiers: [Int: Int] = [:]
            
            for record in records {
                let day = calendar.component(.day, from: record.date)
                
                let count = record.workoutCount ?? 0
                let calories = record.activeCalories ?? 0
                let duration = record.workoutDuration ?? 0
                
                var tier = 0
                if count >= 3 {
                    tier = 3
                } else if count == 2 {
                    tier = 2
                } else if count == 1 {
                    tier = 1
                } else if calories > 400 || duration > 45 {
                    tier = 2
                } else if calories > 150 || duration > 15 {
                    tier = 1
                }
                
                if calendar.isDate(record.date, equalTo: previousMonthStart, toGranularity: .month) {
                    apTiers[day] = tier
                } else if calendar.isDate(record.date, equalTo: currentMonthStart, toGranularity: .month) {
                    myTiers[day] = tier
                }
            }
            
            previousMonthActiveTiers = apTiers
            currentMonthActiveTiers = myTiers
            
            // 2. Fetch past 30 days of records for statistics
            let startDate30 = calendar.date(byAdding: .day, value: -29, to: now) ?? now
            let startOf30 = calendar.startOfDay(for: startDate30)
            let endOf30 = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            
            let records30 = allRecords.filter { $0.date >= startOf30 && $0.date <= endOf30 }
            if !records30.isEmpty {
                // Calculate total duration in minutes
                let totalMin = records30.compactMap { $0.workoutDuration }.reduce(0, +)
                let hours = Int(totalMin) / 60
                let mins = Int(totalMin) % 60
                totalWorkoutDurationText = "\(hours)小时 \(mins)分钟"
                
                // Construct points for summaryWorkPath
                let strains = records30.compactMap(\.strainScore)
                guard !strains.isEmpty else {
                    summaryWorkPathPoints = []
                    dynamicExertionWorkload = []
                    changePercentageText = "--"
                    return
                }
                let maxStrain = strains.max() ?? 10.0
                let minStrain = strains.min() ?? 0.0
                let strainDiff = maxStrain - minStrain
                
                var pts: [CGPoint] = []
                for idx in 0..<records30.count {
                    let x = Double(idx) / Double(max(records30.count - 1, 1))
                    let strain = records30[idx].strainScore ?? minStrain
                    let normalized = strainDiff > 0 ? (strain - minStrain) / strainDiff : 0.5
                    let y = 0.9 - (normalized * 0.78)
                    pts.append(CGPoint(x: x, y: y))
                }
                summaryWorkPathPoints = pts
                
                // Exertion workload (recent 12 records)
                let recent12 = records30.suffix(12)
                let strainRecent = recent12.compactMap(\.strainScore)
                let maxSR = strainRecent.max() ?? 10.0
                let minSR = strainRecent.min() ?? 0.0
                let srDiff = maxSR - minSR
                dynamicExertionWorkload = strainRecent.map { srDiff > 0 ? ($0 - minSR) / srDiff : 0.5 }
                
                // Target exertion zone comparison
                let avgStrain = strains.reduce(0, +) / Double(strains.count)
                let target = Double(dashboard.strain.recommendedRange.lowerBound + dashboard.strain.recommendedRange.upperBound) / 2
                let percentDiff = target > 0 ? Int((avgStrain - target) / target * 100.0) : 0
                if percentDiff >= 0 {
                    changePercentageText = "+\(percentDiff)%"
                    isExertionBelowTarget = false
                } else {
                    changePercentageText = "\(percentDiff)%"
                    isExertionBelowTarget = true
                }
            } else {
                useEmptyFitnessDefaults()
            }
            
        } catch {
            useEmptyFitnessDefaults()
        }
    }
    
    private func useEmptyFitnessDefaults() {
        previousMonthActiveTiers = [:]
        currentMonthActiveTiers = [:]
        totalWorkoutDurationText = "--"
        summaryWorkPathPoints = []
        dynamicExertionWorkload = []
        changePercentageText = "--"
        isExertionBelowTarget = true
    }
}

// MARK: - Area chart drawing helpers
struct AreaChartCurveView: View {
    let points: [CGPoint]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Shaded Area path below curve
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
                
                // Solid line curve
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
                
                // Specific highlighted dot nodes along path
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

// MARK: - Safe-zone workload chart helpers
struct SafeZoneWorkloadChartView: View {
    let workload: [Double]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Green-tinged horizontal safe-zone band
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(hex: "#E8F5E9").opacity(0.8))
                    .frame(height: geo.size.height * 0.45)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                
                // Colored workload line
                Path { path in
                    guard workload.count > 1 else { return }
                    let stepX = geo.size.width / CGFloat(workload.count - 1)
                    for idx in 0..<workload.count {
                        let x = CGFloat(idx) * stepX
                        let y = geo.size.height - (CGFloat(workload[idx]) * (geo.size.height - 8) + 4)
                        if idx == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#81C784"), Color(hex: "#FFB74D"), Color(hex: "#64B5F6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                
                // Highlighting end node dot
                if let lastVal = workload.last {
                    let x = geo.size.width
                    let y = geo.size.height - (CGFloat(lastVal) * (geo.size.height - 8) + 4)
                    Circle()
                        .fill(Color(hex: "#4285F4"))
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .position(x: x, y: y)
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VelaTrainingView()
        .environmentObject(DashboardViewModel())
}
