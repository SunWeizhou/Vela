import SwiftUI
import SwiftData

// MARK: - VelaTrainingView — Bevel Replica Fitness Tab
// Double-Month thinned activity heatmaps × Area workouts summary × Target safe-zone Exertion workload chart

struct VelaTrainingView: View {
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var strengthWorkouts: [StrengthWorkoutRecord]

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    @State private var previousMonthActiveTiers: [Int: Int] = [:]
    @State private var currentMonthActiveTiers: [Int: Int] = [:]

    // Dynamic states for statistics & trend graphs
    @State private var totalWorkoutDurationText = "--"
    @State private var summaryPeakStrainText = "--"
    @State private var summaryWorkPathPoints: [CGPoint] = []
    @State private var dynamicExertionWorkload: [Double] = []
    @State private var changePercentageText = "--"
    @State private var isExertionBelowTarget: Bool = true
    @State private var recentWorkouts: [WorkoutSummary] = []
    @State private var showStrengthWorkoutLog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Fitness Title Header
                fitnessHeader
                
                // 2. Double-Month Thinned Activity Heatmap Card
                activityHeatmapCard
                
                // 3. Activity Summary Card (活动摘要 with orange filled area curve)
                NavigationLink(destination: FitnessActivitySummaryDetailView()) {
                    activitySummaryCard
                }
                .buttonStyle(.plain)
                
                // 4. Exertion Fatigue Load Card (耗力表现 with safe-zone range band)
                NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                    exertionLoadCard
                }
                .buttonStyle(.plain)

                strengthWorkoutsSection

                recentWorkoutsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(Color(hex: "#F5F3F0")) // Warm canvas base
        .onAppear {
            loadRealFitnessData()
        }
        .task {
            await syncRealFitnessData()
        }
        .refreshable {
            await syncRealFitnessData(force: true)
        }
        .onChange(of: dashboardVM.selectedDate) { _, _ in
            loadRealFitnessData()
            Task {
                await syncRealFitnessData()
            }
        }
        .onChange(of: appState.localDataRevision) { _, _ in
            loadRealFitnessData()
        }
        .sheet(isPresented: $showStrengthWorkoutLog) {
            StrengthWorkoutLogSheetView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
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
                    showStrengthWorkoutLog = true
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
                ForEach((0..<startOffset).map { "padding-\($0)" }, id: \.self) { _ in
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
                
                Text(summaryPeakStrainText)
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
            HStack {
                Text("Apple 健康训练记录")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                Spacer()
                Text("每项训练单独展示")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }

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
                            Image(systemName: workoutListIcon(workout.activityName))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.activityName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#1A1917"))
                                Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                                HStack(spacing: 8) {
                                    if let kcal = workout.energyKilocalories {
                                        Text("\(Int(kcal.rounded())) kcal")
                                    }
                                    if let hr = workout.averageHeartRate {
                                        Text("\(Int(hr.rounded())) bpm")
                                    }
                                    if let distance = workout.distanceMeters, distance > 0 {
                                        Text(distance >= 1_000
                                             ? String(format: "%.1f km", distance / 1_000)
                                             : "\(Int(distance.rounded())) m")
                                    }
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color(hex: "#B06A50"))
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

    private var strengthWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("力量训练记录")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text("动作、器械、组次与训练容量")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
                Spacer()
                Button {
                    showStrengthWorkoutLog = true
                } label: {
                    Label("记录力量", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#C56B4A"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }

            if strengthWorkouts.isEmpty {
                Text("尚未记录力量训练。完成一次动作与组次记录后，Coach 就能读取容量历史。")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
            } else {
                ForEach(strengthWorkouts.prefix(5)) { workout in
                    NavigationLink(destination: StrengthWorkoutDetailView(workout: workout)) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color(hex: "#FFF3EA")))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#1A1917"))
                                Text("\(workout.exerciseCount) 个动作 · \(workout.totalSetCount) 组 · \(Int(workout.totalVolumeKilograms.rounded())) kg 容量")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                                Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#BFB9AC"))
                            }

                            Spacer()

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

    private func workoutListIcon(_ name: String) -> String {
        let lowered = name.lowercased()
        if lowered.contains("strength") || lowered.contains("力量") || lowered.contains("weight") {
            return "figure.strengthtraining.traditional"
        }
        if lowered.contains("walk") || lowered.contains("步行") {
            return "figure.walk"
        }
        if lowered.contains("cycle") || lowered.contains("骑行") {
            return "figure.outdoor.cycle"
        }
        if lowered.contains("swim") || lowered.contains("游泳") {
            return "figure.pool.swim"
        }
        return "figure.run"
    }

    // MARK: - SwiftData and HealthKit loader
    private func syncRealFitnessData(force: Bool = false) async {
        loadRealFitnessData()
        await dashboardVM.refresh(modelContext: modelContext, force: force)
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
                    summaryPeakStrainText = "--"
                    return
                }
                let maxStrain = strains.max() ?? 10.0
                summaryPeakStrainText = "\(Int(maxStrain.rounded()))"
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
        summaryPeakStrainText = "--"
        summaryWorkPathPoints = []
        dynamicExertionWorkload = []
        changePercentageText = "--"
        isExertionBelowTarget = true
    }
}

private struct StrengthExerciseDraft: Identifiable {
    var id = UUID()
    var name = ""
    var equipment = "杠铃"
    var sets: [StrengthSetDraft] = [StrengthSetDraft()]
}

private struct StrengthSetDraft: Identifiable {
    var id = UUID()
    var repetitions = 10
    var weightKilograms = 20.0
    var isWarmup = false
}

struct StrengthWorkoutLogSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    
    @State private var title = "力量训练"
    @State private var durationMinutes = 60
    @State private var notes = ""
    @State private var exertionScore: Double = 7.0
    @State private var exercises = [StrengthExerciseDraft()]

    private let equipmentOptions = ["杠铃", "哑铃", "固定器械", "绳索", "壶铃", "自重", "其他"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sessionCard

                    ForEach($exercises) { $exercise in
                        exerciseCard(exercise: $exercise)
                    }

                    Button {
                        exercises.append(StrengthExerciseDraft())
                    } label: {
                        Label("添加动作", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#C56B4A"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.white))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Color(hex: "#F5F3F0"))
            .navigationTitle("记录力量训练")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(validExercises.isEmpty)
                }
            }
        }
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("训练名称", text: $title)
                .font(.system(size: 18, weight: .bold))
            Stepper("时长 \(durationMinutes) 分钟", value: $durationMinutes, in: 5...240, step: 5)
                .font(.system(size: 14, weight: .semibold))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("自觉竭力程度 (RPE):")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Spacer()
                    Text("\(Int(exertionScore)) / 10")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#C56B4A"))
                }
                Slider(value: $exertionScore, in: 1...10, step: 1)
                    .tint(Color(hex: "#C56B4A"))
                Text("1 = 极轻松，10 = 力竭且无任何保留组。用于重算今日负荷。")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            .padding(.top, 4)

            TextField("训练备注（可选）", text: $notes, axis: .vertical)
                .font(.system(size: 13))
                .lineLimit(2...4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    private func exerciseCard(exercise: Binding<StrengthExerciseDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("动作名称，例如卧推", text: exercise.name)
                    .font(.system(size: 16, weight: .bold))
                if exercises.count > 1 {
                    Button {
                        exercises.removeAll { $0.id == exercise.wrappedValue.id }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color(hex: "#FF3B30"))
                    }
                    .buttonStyle(.plain)
                }
            }

            Picker("器械", selection: exercise.equipment) {
                ForEach(equipmentOptions, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)

            ForEach(exercise.sets) { set in
                strengthSetRow(set: set, exercise: exercise)
            }

            Button {
                exercise.wrappedValue.sets.append(StrengthSetDraft())
            } label: {
                Label("添加一组", systemImage: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#C56B4A"))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
    }

    private func strengthSetRow(
        set: Binding<StrengthSetDraft>,
        exercise: Binding<StrengthExerciseDraft>
    ) -> some View {
        HStack(spacing: 10) {
            Toggle("热身", isOn: set.isWarmup)
                .font(.system(size: 11, weight: .medium))
                .toggleStyle(.button)

            TextField("kg", value: set.weightKilograms, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)

            Text("kg ×")
                .font(.system(size: 12))
                .foregroundStyle(Color(hex: "#8E8A80"))

            Stepper("\(set.wrappedValue.repetitions) 次", value: set.repetitions, in: 1...100)
                .font(.system(size: 12, weight: .semibold))

            if exercise.wrappedValue.sets.count > 1 {
                Button {
                    exercise.wrappedValue.sets.removeAll { $0.id == set.wrappedValue.id }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var validExercises: [StrengthExerciseLog] {
        exercises.compactMap { exercise in
            let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return StrengthExerciseLog(
                name: name,
                equipment: exercise.equipment,
                sets: exercise.sets.map {
                    StrengthSetLog(
                        repetitions: $0.repetitions,
                        weightKilograms: max(0, $0.weightKilograms),
                        isWarmup: $0.isWarmup
                    )
                }
            )
        }
    }

    private func save() {
        let record = StrengthWorkoutRecord(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "力量训练" : title,
            durationMinutes: durationMinutes,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            exercises: validExercises
        )
        modelContext.insert(record)
        
        // Companion WorkoutEventRecord
        let event = WorkoutEventRecord(
            source: "strengthLog",
            startedAt: record.startedAt,
            endedAt: record.endedAt,
            activityType: record.title,
            energyKilocalories: Double(durationMinutes) * 6.0, // Estimate 6 kcal/min for gym training
            rpe: exertionScore,
            linkedStrengthWorkoutId: record.id
        )
        modelContext.insert(event)
        
        do {
            try modelContext.save()
            VelaAppState.shared.markLocalDataChanged()
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
        } catch {
            print("Failed to save strength workout: \(error)")
        }
        dismiss()
    }
}

struct StrengthWorkoutDetailView: View {
    let workout: StrengthWorkoutRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(workout.title)
                        .font(.system(size: 26, weight: .bold))
                    Text(workout.startedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                    HStack(spacing: 12) {
                        strengthSummary("时长", "\(workout.durationMinutes) 分钟")
                        strengthSummary("组数", "\(workout.totalSetCount)")
                        strengthSummary("容量", "\(Int(workout.totalVolumeKilograms.rounded())) kg")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 22).fill(Color.white))

                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text(exercise.equipment)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: "#C56B4A"))
                        }

                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text("第 \(index + 1) 组")
                                Spacer()
                                Text(set.isWarmup ? "热身" : "\(set.repetitions) 次 × \(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                }

                if !workout.notes.isEmpty {
                    Text(workout.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                }
            }
            .padding(16)
        }
        .background(Color(hex: "#F5F3F0"))
        .navigationTitle("力量训练详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func strengthSummary(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "#8E8A80"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Activity Summary Detail

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
