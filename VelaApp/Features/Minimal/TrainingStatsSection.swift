import SwiftUI

enum TrainingTargetComparison: Equatable {
    case unavailable
    case below(Int)
    case withinTarget
    case above(Int)

    static func evaluate(strainValues: [Double], target: MetricResult) -> Self {
        guard target.hasData,
              strainValues.count >= 3,
              let lower = target.components["recommended_lower"],
              let upper = target.components["recommended_upper"],
              upper >= lower else {
            return .unavailable
        }

        let targetMidpoint = (lower + upper) / 2
        guard targetMidpoint > 0 else { return .unavailable }
        let average = strainValues.reduce(0, +) / Double(strainValues.count)
        let percent = Int(((average - targetMidpoint) / targetMidpoint * 100).rounded())

        if abs(percent) <= 5 { return .withinTarget }
        return percent < 0 ? .below(abs(percent)) : .above(percent)
    }

    var valueText: String {
        switch self {
        case .unavailable: return "--"
        case let .below(percent): return "低 \(percent)%"
        case .withinTarget: return "接近目标"
        case let .above(percent): return "高 \(percent)%"
        }
    }

    var contextText: String {
        switch self {
        case .unavailable: return "目标范围待计算"
        case .below: return "低于个人目标中值"
        case .withinTarget: return "处于个人目标范围"
        case .above: return "高于个人目标中值"
        }
    }

    var tint: Color {
        switch self {
        case .unavailable: return VelaTheme.muted
        case .below: return VelaTheme.accent
        case .withinTarget: return VelaTheme.success
        case .above: return VelaTheme.warn
        }
    }
}

enum CardioLoadStatus: String, Equatable {
    case building
    case maintaining
    case easing
    case spike

    var title: String {
        switch self {
        case .building: "逐步提升"
        case .maintaining: "维持"
        case .easing: "负荷回落"
        case .spike: "短期陡增"
        }
    }
}

struct CardioTrainingSnapshot: Equatable {
    var acuteMinutes: Int
    var baselineWeeklyMinutes: Int?
    var loadRatio: Double?
    var status: CardioLoadStatus?
    var focus: String?
    var cardioSessions: Int
    var heartRateCoverage: Int
    var heartRateRecoveryBPM: Double?
}

enum CardioTrainingAnalyzer {
    static func analyze(
        workouts: [WorkoutSummary],
        endingAt endDate: Date,
        heartRateRecoverySamples: [Double] = [],
        calendar: Calendar = .current
    ) -> CardioTrainingSnapshot {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let acuteStart = calendar.date(byAdding: .day, value: -7, to: end) ?? end.addingTimeInterval(-7 * 86_400)
        let baselineStart = calendar.date(byAdding: .day, value: -28, to: end) ?? end.addingTimeInterval(-28 * 86_400)
        let cardio = workouts.filter {
            $0.start >= baselineStart && $0.start < end && isCardio($0.activityName) && $0.end > $0.start
        }
        let acute = cardio.filter { $0.start >= acuteStart }
        let baseline = cardio.filter { $0.start < acuteStart }
        let acuteMinutes = Int(acute.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 60)
        let baselineMinutes = Int(baseline.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 60)
        let baselineWeekly = baseline.count >= 3 ? Int((Double(baselineMinutes) / 3).rounded()) : nil
        let ratio: Double? = {
            guard let baselineWeekly, baselineWeekly > 0, !acute.isEmpty else { return nil }
            return Double(acuteMinutes) / Double(baselineWeekly)
        }()
        let status = ratio.map { value -> CardioLoadStatus in
            switch value {
            case ..<0.75: .easing
            case 0.75..<1.15: .maintaining
            case 1.15...1.5: .building
            default: .spike
            }
        }
        let focus = Dictionary(grouping: acute, by: { focusName($0.activityName) })
            .mapValues { sessions in sessions.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } }
            .max(by: { $0.value < $1.value })?.key
        let sourcedRecovery = heartRateRecoverySamples.isEmpty
            ? acute.compactMap(\.heartRateRecoveryOneMinuteBPM)
            : heartRateRecoverySamples
        let validRecovery = sourcedRecovery.filter { $0.isFinite && $0 >= 0 && $0 <= 120 }.sorted()
        let recovery: Double? = validRecovery.count >= 3 ? median(validRecovery) : nil

        return CardioTrainingSnapshot(
            acuteMinutes: acuteMinutes,
            baselineWeeklyMinutes: baselineWeekly,
            loadRatio: ratio,
            status: status,
            focus: focus,
            cardioSessions: acute.count,
            heartRateCoverage: acute.filter { $0.averageHeartRate != nil }.count,
            heartRateRecoveryBPM: recovery
        )
    }

    private static func isCardio(_ name: String) -> Bool {
        let value = name.lowercased()
        let excluded = ["strength", "力量", "weight", "yoga", "瑜伽", "flexibility", "mobility"]
        if excluded.contains(where: value.contains) { return false }
        let included = [
            "run", "跑", "walk", "步行", "hiking", "徒步", "cycle", "cycling", "骑行",
            "swim", "游泳", "row", "划船", "elliptical", "椭圆", "cardio", "有氧",
            "soccer", "football", "basketball", "dance", "舞蹈", "stair", "爬楼"
        ]
        return included.contains(where: value.contains)
    }

    private static func focusName(_ name: String) -> String {
        let value = name.lowercased()
        if value.contains("run") || value.contains("跑") { return "跑步" }
        if value.contains("walk") || value.contains("步行") || value.contains("hiking") || value.contains("徒步") { return "步行 / 徒步" }
        if value.contains("cycle") || value.contains("骑行") { return "骑行" }
        if value.contains("swim") || value.contains("游泳") { return "游泳" }
        if value.contains("row") || value.contains("划船") { return "划船" }
        return "综合有氧"
    }

    private static func median(_ values: [Double]) -> Double {
        let middle = values.count / 2
        return values.count.isMultiple(of: 2)
            ? (values[middle - 1] + values[middle]) / 2
            : values[middle]
    }
}

struct CardioStatusCard: View {
    let snapshot: CardioTrainingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("有氧状态", systemImage: "heart.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                Text("最近 7 天")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            HStack(spacing: 8) {
                cardioMetric("Cardio Load", snapshot.cardioSessions == 0 ? "—" : "\(snapshot.acuteMinutes) 分", detail: baselineDetail)
                cardioMetric("Cardio Status", snapshot.status?.title ?? "校准中", detail: statusDetail)
            }
            HStack(spacing: 8) {
                cardioMetric("Cardio Focus", snapshot.focus ?? "—", detail: snapshot.focus == nil ? "暂无有氧训练" : "按训练时长最多")
                cardioMetric("心率恢复", snapshot.heartRateRecoveryBPM.map { "\(Int($0.rounded())) bpm" } ?? "—", detail: recoveryDetail)
            }

            if snapshot.loadRatio.map({ $0 > 1.5 }) == true {
                Label("短期有氧时长明显高于前三周基线；结合恢复与身体感受决定是否降量。", systemImage: "exclamationmark.triangle.fill")
                    .font(VelaTheme.caption2())
                    .foregroundStyle(VelaTheme.warn)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(VelaTheme.rhythmMist, lineWidth: 0.75))
    }

    private var baselineDetail: String {
        guard let baseline = snapshot.baselineWeeklyMinutes else { return "需前三周至少 3 次" }
        return "前三周均值 \(baseline) 分/周"
    }

    private var statusDetail: String {
        guard let ratio = snapshot.loadRatio else { return "基线不足，不作判断" }
        return "7 天 / 基线 \(String(format: "%.2f", ratio))×"
    }

    private var recoveryDetail: String {
        snapshot.heartRateRecoveryBPM == nil
            ? "需至少 3 次训练后心率下降样本"
            : "训练后 1 分钟下降中位数"
    }

    private func cardioMetric(_ title: String, _ value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaTheme.rhythmInk)
            Text(detail)
                .font(.system(size: 9))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineLimit(2)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .background(VelaTheme.rhythmMist.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct TrainingStatsSection: View {
    @Binding var selectedAnalyticsTab: Int
    let targetComparison: TrainingTargetComparison
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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaTheme.rhythmInk)
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
                if dynamicExertionWorkload.isEmpty {
                    compactEmptyState(
                        icon: "waveform.path.ecg",
                        title: "负荷趋势将在训练后出现",
                        detail: "完成或同步一次训练，即可开始建立个人目标范围。"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(targetComparison.valueText)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundStyle(VelaTheme.fg)
                            Text(dynamicExertionWorkload.isEmpty ? "暂无耗力记录" : targetComparison.contextText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(targetComparison.tint)
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
                    
                    SafeZoneWorkloadChartView(
                        workload: dynamicExertionWorkload,
                        showsTargetZone: targetComparison != .unavailable
                    )
                        .frame(height: 72)
                        .padding(.vertical, 4)
                    }
                }
            case 1:
                if summaryWorkPathPoints.isEmpty || totalWorkoutDurationText == "--" {
                    compactEmptyState(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "还没有可分析的趋势",
                        detail: "积累几次训练后，这里会显示 30 天训练量变化。"
                    )
                } else {
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
                            .foregroundStyle(VelaTheme.meta)
                            .offset(y: -4)
                        
                        HStack {
                            Text("30天前")
                            Spacer()
                            Text("15天前")
                            Spacer()
                            Text("今天")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VelaTheme.meta)
                        .padding(.top, 114)
                    }
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
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }

    private func compactEmptyState(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VelaTheme.accent)
                .frame(width: 36, height: 36)
                .background(VelaTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VelaTheme.subheadline().weight(.semibold))
                    .foregroundStyle(VelaTheme.fg)
                Text(detail)
                    .font(VelaTheme.footnote())
                    .foregroundStyle(VelaTheme.muted)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
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
                        .foregroundStyle(VelaTheme.meta)
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
                                    .foregroundStyle(sets >= 18 ? VelaTheme.danger : (sets < 6 ? VelaTheme.accent : VelaTheme.success))
                            }
                            
                            GeometryReader { geo in
                                let pct = min(CGFloat(sets) / 20.0, 1.0)
                                let barColor = sets >= 18 ? VelaTheme.danger : (sets < 6 ? VelaTheme.accent : VelaTheme.success)
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
                .fill(VelaTheme.rhythmCanvasRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
        )
    }
}

struct RecentWorkoutsSection: View {
    let recentWorkouts: [WorkoutSummary]
    /// Resolves a HealthKit/merged summary back to a locally-logged strength
    /// workout record, if any, so strength workouts open the rich detail view.
    var strengthWorkout: (WorkoutSummary) -> StrengthWorkoutRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("训练记录")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Spacer()
                Text("Apple + 训记自动合并")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
            }

            if recentWorkouts.isEmpty {
                Text("暂无可读取的训练记录")
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
            } else {
                ForEach(recentWorkouts.prefix(12)) { workout in
                    // Strength workouts that were logged locally open the rich
                    // strength detail (PR trophies, muscle distribution, edit/delete).
                    // Previously ALL workouts opened the generic HealthKit detail, so
                    // this entire feature was unreachable.
                    NavigationLink(destination: destination(for: workout)) {
                        workoutRow(workout)
                    }
                    .buttonStyle(.cardPress)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for workout: WorkoutSummary) -> some View {
        if let strength = strengthWorkout(workout) {
            StrengthWorkoutDetailView(workout: strength)
        } else {
            WorkoutDetailView(workout: workout)
        }
    }

    private func workoutRow(_ workout: WorkoutSummary) -> some View {
        HStack(spacing: 12) {
            Image(systemName: workoutListIcon(workout.activityName))
                .foregroundStyle(VelaTheme.rhythmDeep)
                .frame(width: 36, height: 36)
                .background(Circle().fill(VelaTheme.rhythmMist))
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VelaTheme.rhythmInk)
                Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.rhythmInkSecondary)
                HStack(spacing: 6) {
                    Text(sourceLabel(for: workout.source))
                    Text("·")
                    Text("\(Int(workout.end.timeIntervalSince(workout.start) / 60)) 分钟")
                    if let kcal = workout.energyKilocalories {
                        Text("·")
                        Text("\(Int(kcal.rounded())) kcal")
                    }
                    if let hr = workout.averageHeartRate {
                        Text("·")
                        Text("\(Int(hr.rounded())) bpm")
                    }
                    if let distance = workout.distanceMeters, distance > 0 {
                        Text("·")
                        Text(distance >= 1_000
                             ? String(format: "%.1f km", distance / 1_000)
                             : "\(Int(distance.rounded())) m")
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
                .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.rhythmInkSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.rhythmCanvasRaised))
        .overlay {
            RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous)
                .stroke(VelaTheme.rhythmMist, lineWidth: 0.75)
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
                                    .foregroundStyle(VelaTheme.meta)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VelaTheme.meta)
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: VelaTheme.radiusLg, style: .continuous).fill(VelaTheme.cardBg))
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
    let showsTargetZone: Bool
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Green-tinged horizontal safe-zone band
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(
                        showsTargetZone
                            ? Color(hex: "#E8F5E9").opacity(0.8)
                            : VelaTheme.surface.opacity(0.8)
                    )
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
                        colors: [VelaTheme.recoveryColor, VelaTheme.strainColor, VelaTheme.accent],
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
                        .fill(VelaTheme.accent)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(VelaTheme.cardBg, lineWidth: 1.5))
                        .position(x: x, y: y)
                }
            }
        }
    }
}
