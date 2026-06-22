import SwiftUI

struct TrainingStatsSection: View {
    @Binding var selectedAnalyticsTab: Int
    let changePercentageText: String
    let isExertionBelowTarget: Bool
    let dynamicExertionWorkload: [Double]
    let totalWorkoutDurationText: String
    let summaryWorkPathPoints: [CGPoint]
    let summaryPeakStrainText: String
    let selectedDate: Date
    let previousMonthActiveTiers: [Int: Int]
    let currentMonthActiveTiers: [Int: Int]

    private var currentMonthStart: Date {
        monthStart(for: selectedDate)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: selectedAnalyticsTab == 0 ? "bolt.heart.fill" : (selectedAnalyticsTab == 1 ? "chart.bar.fill" : "calendar"))
                        .font(.system(size: 14))
                        .foregroundStyle(VelaTheme.muted)
                    Text("表现与分析")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                }
                Spacer()
                
                Picker("", selection: $selectedAnalyticsTab) {
                    Text("负荷").tag(0)
                    Text("趋势").tag(1)
                    Text("热力").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Divider()

            switch selectedAnalyticsTab {
            case 0:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(changePercentageText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(dynamicExertionWorkload.isEmpty ? "暂无耗力记录" : (isExertionBelowTarget ? "低于目标值" : "高于目标值"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isExertionBelowTarget ? Color(hex: "#4285F4") : Color(hex: "#66BB6A"))
                        }
                        Spacer()
                        NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                            HStack(spacing: 4) {
                                  Text("详情")
                                  Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                        }
                        .buttonStyle(.cardPress)
                    }
                    
                    SafeZoneWorkloadChartView(workload: dynamicExertionWorkload)
                        .frame(height: 72)
                        .padding(.vertical, 4)
                }
            case 1:
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(totalWorkoutDurationText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text("过去 30 天耗力趋势")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VelaTheme.muted)
                        }
                        Spacer()
                        NavigationLink(destination: FitnessActivitySummaryDetailView()) {
                            HStack(spacing: 4) {
                                Text("分析")
                                Image(systemName: "chevron.right")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                        }
                        .buttonStyle(.cardPress)
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        AreaChartCurveView(points: summaryWorkPathPoints)
                            .frame(height: 100)
                            .padding(.top, 10)
                        
                        Text(summaryPeakStrainText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#BFB9AC"))
                            .offset(y: -4)
                        
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
            default:
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
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
                    
                    HStack(spacing: 12) {
                        legendItem(color: Color(hex: "#A5D6A7"), label: "1 项活动")
                        legendItem(color: Color(hex: "#66BB6A"), label: "2 项活动")
                        legendItem(color: Color(hex: "#29B6F6"), label: "3+ 活动")
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
    }

    private func monthHeatmap(
        monthTitle: String,
        totalDays: Int,
        startOffset: Int,
        activeTiers: [Int: Int]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
            
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
                .foregroundStyle(VelaTheme.muted)
        }
    }
}

struct MuscleVolumeCard: View {
    let summary: RecentTrainingSummary
    let exerciseProgressLines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("过去 7 天肌群有效组")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text("\(summary.sessions) 次力量训练")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            if summary.muscleGroupSets.isEmpty {
                Text("完成力量训练后，这里会显示肌群训练量与局部疲劳。")
                    .font(.system(size: 12))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 10) {
                    ForEach(summary.muscleGroupSets.sorted { $0.key < $1.key }, id: \.key) { muscle, sets in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(localizedMuscleGroup(muscle))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(VelaTheme.fg)
                                Spacer()
                                Text("\(sets) 组")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(sets >= 18 ? Color(hex: "#FF3B30") : (sets < 6 ? Color(hex: "#4285F4") : Color(hex: "#34C759")))
                            }
                            
                            GeometryReader { geo in
                                let pct = min(CGFloat(sets) / 20.0, 1.0)
                                let barColor = sets >= 18 ? Color(hex: "#FF3B30") : (sets < 6 ? Color(hex: "#4285F4") : Color(hex: "#34C759"))
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(VelaTheme.surface)
                                        .frame(height: 6)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(barColor)
                                        .frame(width: geo.size.width * pct, height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                    }
                }
            }
            
            if !summary.recentPRs.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("近期 PR")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VelaTheme.muted)
                    Text(summary.recentPRs.prefix(3).map(\.summary).joined(separator: " · "))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                }
            }
            
            if let latest = summary.lastWorkoutSummary {
                Divider()
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.caption2)
                        .foregroundStyle(VelaTheme.muted)
                    Text("最近一次：\(latest)")
                        .font(.system(size: 12))
                        .foregroundStyle(VelaTheme.muted)
                }
            }
            
            if !exerciseProgressLines.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("常练动作进步")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    ForEach(exerciseProgressLines.prefix(3), id: \.self) { line in
                        Text("• \(line)")
                            .font(.system(size: 12))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.borderSoft, lineWidth: 0.5)
        )
    }
}

struct RecentWorkoutsSection: View {
    let recentWorkouts: [WorkoutSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Spacer()
                Text("Apple + 训记自动合并")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }

            if recentWorkouts.isEmpty {
                Text("暂无可读取的训练记录")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            } else {
                ForEach(recentWorkouts.prefix(12)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                        workoutRow(workout)
                    }
                    .buttonStyle(.cardPress)
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workoutListIcon(workout.activityName))
                .foregroundStyle(VelaTheme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.muted)
                HStack(spacing: 8) {
                    Text(sourceLabel(for: workout.source))
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
                .foregroundStyle(VelaTheme.muted)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
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

    private func sourceLabel(for source: String?) -> String {
        switch source {
        case "healthKit+xunji":
            return "Apple + 训记"
        case "xunji":
            return "训记"
        case "strengthLog":
            return "力量"
        case "manual":
            return "手动"
        default:
            return "Apple"
        }
    }
}

struct StrengthWorkoutsSection: View {
    let strengthWorkouts: [StrengthWorkoutRecord]
    let startStrengthWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("力量训练记录")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VelaTheme.fg)
                    Text("动作、器械、组次与训练容量")
                        .font(.system(size: 11))
                        .foregroundStyle(VelaTheme.muted)
                }
                Spacer()
                Button {
                    startStrengthWorkout()
                } label: {
                    Label("记录力量", systemImage: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VelaTheme.cardBg))
                }
                .buttonStyle(.plain)
            }

            if strengthWorkouts.isEmpty {
                Text("尚未记录力量训练。完成一次动作与组次记录后，Coach 就能读取容量历史。")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.cardBg))
            } else {
                ForEach(strengthWorkouts.prefix(5)) { workout in
                    NavigationLink(destination: WorkoutDetailView(workout: WorkoutSummary(
                        id: workout.id,
                        start: workout.startedAt,
                        end: workout.startedAt.addingTimeInterval(TimeInterval(workout.durationMinutes * 60)),
                        activityName: workout.title,
                        source: "strengthLog"
                    ))) {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 18))
                                .foregroundStyle(VelaTheme.accent)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color(hex: "#EAF3FF")))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.title)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(VelaTheme.fg)
                                Text("\(workout.exerciseCount) 个动作 · \(workout.totalSetCount) 组 · \(Int(workout.totalVolumeKilograms.rounded())) kg 容量")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VelaTheme.muted)
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
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(VelaTheme.cardBg))
                    }
                    .buttonStyle(.plain)
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
