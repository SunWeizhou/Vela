import SwiftUI
import Charts
import MapKit
import HealthKit
import SwiftData

struct WorkoutDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    let workout: WorkoutSummary
    
    @State private var heartRates: [HeartRateSample] = []
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoading = true
    @State private var showHeartRateInsight = false
    @State private var showDeleteConfirmation = false
    @State private var selectedSet: StrengthSetDetail?

    @Query(sort: \WorkoutEventRecord.startedAt, order: .reverse) private var workoutEvents: [WorkoutEventRecord]
    @Query(sort: \StrengthWorkoutRecord.startedAt, order: .reverse) private var strengthWorkouts: [StrengthWorkoutRecord]
    
    private let queryService = HealthKitQueryService()
    
    var body: some View {
        ZStack {
            detailBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    intelligenceStrip
                    heartRateChartSection
                    
                    if let strength = linkedStrengthWorkout {
                        muscleDistribution(strength)
                        exerciseList(strength)
                        notesCard(strength)
                    }
                    
                    if !routeCoordinates.isEmpty {
                        gpsRouteSection
                    }
                    workoutCoachCard
                }
                .padding(16)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.activityName)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                            .lineLimit(1)
                        Text(workout.start.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: iconForWorkout(workout.activityName))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(workoutAccentColor)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(workoutAccentColor.opacity(0.14)))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                Divider().opacity(0.4)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showHeartRateInsight = true
                    } label: {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(heartRates.isEmpty ? VelaTheme.muted : VelaTheme.accent)
                    }
                    .disabled(heartRates.isEmpty)
                    
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showHeartRateInsight) {
            WorkoutHeartRateInsightSheet(
                averageText: averageHeartRateText,
                peakText: peakHeartRateText,
                rangeText: heartRateRangeText,
                intensityText: heartRateIntensityText,
                segments: heartRateZoneSegments
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .sheet(item: $selectedSet) { detail in
            StrengthSetDetailSheet(detail: detail)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(VelaTheme.systemGroupedBackground)
        }
        .confirmationDialog("确定要删除这条健身记录吗？", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                deleteWorkout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后，该训练对应的耗力、卡路里和负荷计算都将被移除。")
        }
        .task {
            await loadWorkoutDetails()
        }
    }
    
    // MARK: - Subviews

    private var bodyTextColor: Color { VelaTheme.fg }
    private var mutedColor: Color { VelaTheme.muted }
    private var accentColor: Color { VelaTheme.accent }

    private var detailBackground: some View {
        ZStack {
            VelaTheme.bg
            LinearGradient(
                colors: [workoutAccentColor.opacity(0.06), VelaTheme.bg, VelaTheme.bg],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func heroMetric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(VelaTheme.primaryText)
                Text(unit)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(mutedColor)
                    .lineLimit(1)
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(mutedColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.primaryText.opacity(0.06)))
    }

    private var hero: some View {
        VelaGlassCard(padding: 18, cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    heroMetric("时长", "\(Int((workout.end.timeIntervalSince(workout.start) / 60).rounded()))", "分钟")
                    heroMetric("活动消耗", workout.energyKilocalories.map { "\(Int($0))" } ?? "--", "kcal")
                    if let dist = workout.distanceMeters, dist > 0 {
                        heroMetric("距离", dist >= 1000 ? String(format: "%.1f", dist/1000) : "\(Int(dist.rounded()))", dist >= 1000 ? "km" : "m")
                    } else {
                        heroMetric("平均心率", workout.averageHeartRate.map { "\(Int($0))" } ?? "--", "bpm")
                    }
                }
            }
        }
    }

    private var intelligenceStrip: some View {
        VelaGlassCard(padding: 16, cornerRadius: 20) {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VelaTheme.accent)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(VelaTheme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("训练智能摘要")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text("本次为 \(workout.activityName) 运动，持续时间约 \(Int((workout.end.timeIntervalSince(workout.start) / 60).rounded())) 分钟。")
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)
                }
            }
        }
        .appleIntelligenceGlow(isHighlighted: true, radius: 20)
    }
    
    private var heartRateChartSection: some View {
        VelaGlassCard(padding: 18, cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF5252"))
                
                Text(L10n.t("Heart Rate Fluctuation", "心率波动趋势"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.primaryText)
            }
            
            if isLoading {
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 60)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 60)
                            .shimmer()
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VelaTheme.borderSoft)
                            .frame(height: 60)
                            .shimmer()
                    }
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(VelaTheme.borderSoft)
                        .frame(height: 28)
                        .shimmer()
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
            } else if heartRates.isEmpty {
                Text(L10n.t("No heart rate details recorded for this period.", "此时间段未记录心率明细。"))
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(height: 160)
            } else {
                HStack(spacing: 10) {
                    heartRateFact(title: L10n.t("Average", "平均"), value: averageHeartRateText)
                    heartRateFact(title: L10n.t("Range", "范围"), value: heartRateRangeText)
                    heartRateFact(title: L10n.t("Peak", "峰值"), value: peakHeartRateText)
                }

                HeartRateZoneRibbonView(segments: heartRateZoneSegments)
                    .frame(height: 28)

                Chart {
                    if let averageHeartRate {
                        RuleMark(y: .value("Average", averageHeartRate))
                            .foregroundStyle(Color(hex: "#FF5252").opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("AVG")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(Color(hex: "#FF5252"))
                            }
                    }

                    ForEach(binnedHeartRates) { bin in
                        BarMark(
                            x: .value("Time", bin.date),
                            yStart: .value("Min BPM", bin.minBPM),
                            yEnd: .value("Max BPM", bin.maxBPM),
                            width: .fixed(3.0)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "#00C7BE").opacity(0.85), Color(hex: "#30B0C7")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(1.5)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VelaTheme.separatorSoft)
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.6, dash: [2, 4]))
                            .foregroundStyle(Color(hex: "#E5E5EA"))
                        AxisValueLabel()
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
                .chartYScale(domain: heartRateDomain)
                .frame(height: 160)
                .padding(.top, 6)

                Button {
                    showHeartRateInsight = true
                } label: {
                    HStack {
                        Text(heartRateIntensityText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        Spacer()
                        Text(L10n.t("View zones", "查看区间"))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VelaTheme.accent)
                    }
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
          }
        }
    }

    private func heartRateFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.primaryText.opacity(0.05)))
    }
    
    private var gpsRouteSection: some View {
        VelaGlassCard(padding: 18, cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#4CAF50"))
                
                Text(L10n.t("GPS Workout Route", "GPS 运动轨迹"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.primaryText)
            }
            
            if isLoading {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VelaTheme.borderSoft)
                    .frame(height: 220)
                    .shimmer()
                    .frame(maxWidth: .infinity)
            } else if routeCoordinates.isEmpty {
                Text(L10n.t("No GPS route mapping recorded for this workout.", "此项运动未记录 GPS 运动轨迹。"))
                    .font(.system(size: 13))
                    .foregroundStyle(VelaTheme.muted)
                    .frame(height: 100)
            } else {
                Map(position: .constant(.region(MKCoordinateRegion(
                    center: centerOfCoordinates(routeCoordinates),
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )))) {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(Color(hex: "#FF5722"), lineWidth: 4.5) // Reddish-orange loop like Apple Watch route!
                    
                    if let first = routeCoordinates.first {
                        Annotation(L10n.t("Start", "起点"), coordinate: first) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 2)
                        }
                    }
                    if let last = routeCoordinates.last {
                        Annotation(L10n.t("End", "终点"), coordinate: last) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 2)
                        }
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.6)
                )
            }
          }
        }
    }
    
    private var workoutCoachCard: some View {
        MetricCoachCard(
            dashboard: dashboardVMForWorkout,
            focus: CoachContextFocus(
                title: workout.activityName,
                systemContext: L10n.t(
                    "Analyze detailed workout segment, heart rate ranges, recovery speed, energy expense, and distance coverage.",
                    "分析特定的训练表现、心率区间分布、恢复速率、运动热量消耗和距离表现细节。"
                )
            ),
            suggestedQuestion: L10n.t(
                "Analyze my \(workout.activityName) workout today: duration of \(formattedDuration(workout.start, workout.end)), calories burned \(workout.energyKilocalories.map { "\(Int($0))" } ?? "N/A"), average HR \(workout.averageHeartRate.map { "\(Int($0))" } ?? "N/A"). What is the strain score consequence and impact on tomorrow's recovery?",
                "请分析我今天进行的 \(workout.activityName) 运动：持续时间为 \(formattedDuration(workout.start, workout.end))，热量消耗 \(workout.energyKilocalories.map { "\(Int($0))" } ?? "N/A")，平均心率 \(workout.averageHeartRate.map { "\(Int($0))" } ?? "N/A")。它产生了什么负荷影响，对明天的恢复有什么建议？"
            )
        )
    }
    
    // MARK: - Helpers
    
    private var formattedWorkoutTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: workout.start)
    }

    private var formattedDistance: String {
        guard let meters = workout.distanceMeters, meters > 0 else { return "--" }
        if meters >= 1_000 {
            return String(format: "%.2f km", meters / 1_000)
        }
        return "\(Int(meters.rounded())) m"
    }

    private var binnedHeartRates: [HeartRateRangeBin] {
        guard !heartRates.isEmpty else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: heartRates) { sample in
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: sample.date)
            return calendar.date(from: components) ?? sample.date
        }
        return grouped.compactMap { (minuteDate, samples) -> HeartRateRangeBin? in
            let bpms = samples.map(\.bpm)
            guard let minVal = bpms.min(), let maxVal = bpms.max() else { return nil }
            return HeartRateRangeBin(date: minuteDate, minBPM: minVal, maxBPM: maxVal)
        }.sorted { $0.date < $1.date }
    }

    private var heartRateDomain: ClosedRange<Double> {
        let values = heartRates.map(\.bpm)
        guard let minimum = values.min(), let maximum = values.max() else {
            return 60...180
        }
        let lower = max(30, floor((minimum - 10) / 10) * 10)
        let upper = max(lower + 20, ceil((maximum + 10) / 10) * 10)
        return lower...upper
    }

    private var heartRateRangeText: String {
        let values = heartRates.map(\.bpm)
        guard let minimum = values.min(), let maximum = values.max() else { return "--" }
        return "\(Int(minimum.rounded()))-\(Int(maximum.rounded())) bpm"
    }

    private var peakHeartRateText: String {
        guard let maximum = heartRates.map(\.bpm).max() else { return "--" }
        return "\(Int(maximum.rounded())) bpm"
    }

    private var averageHeartRate: Double? {
        if !heartRates.isEmpty {
            return heartRates.map(\.bpm).reduce(0, +) / Double(heartRates.count)
        }
        return workout.averageHeartRate
    }

    private var averageHeartRateText: String {
        guard let averageHeartRate else { return "--" }
        return "\(Int(averageHeartRate.rounded())) bpm"
    }

    private var maxHeartRateSample: HeartRateSample? {
        heartRates.max { $0.bpm < $1.bpm }
    }

    private var heartRateIntensityText: String {
        guard let averageHeartRate else {
            return L10n.t("No heart rate intensity available", "暂无心率强度")
        }
        if averageHeartRate >= 155 {
            return L10n.t("High cardiovascular load", "心肺负荷较高")
        }
        if averageHeartRate >= 130 {
            return L10n.t("Steady aerobic effort", "稳定有氧输出")
        }
        return L10n.t("Low-to-moderate intensity", "低到中等强度")
    }

    private var heartRateZoneSegments: [HeartRateZoneSegment] {
        guard !heartRates.isEmpty else { return [] }
        return [
            HeartRateZoneSegment(label: L10n.t("Easy", "轻松"), count: heartRates.filter { $0.bpm < 110 }.count, color: Color(hex: "#4DA3FF")),
            HeartRateZoneSegment(label: L10n.t("Aerobic", "有氧"), count: heartRates.filter { $0.bpm >= 110 && $0.bpm < 140 }.count, color: Color(hex: "#34C759")),
            HeartRateZoneSegment(label: L10n.t("Tempo", "节奏"), count: heartRates.filter { $0.bpm >= 140 && $0.bpm < 165 }.count, color: Color(hex: "#FF9500")),
            HeartRateZoneSegment(label: L10n.t("Peak", "峰值"), count: heartRates.filter { $0.bpm >= 165 }.count, color: Color(hex: "#FF3B30"))
        ]
    }

    private var workoutAccentColor: Color {
        let lowName = workout.activityName.lowercased()
        if lowName.contains("run") || lowName.contains("walk") {
            return Color(hex: "#FF6B35")
        }
        if lowName.contains("cycl") {
            return Color(hex: "#34C759")
        }
        if lowName.contains("swim") {
            return Color(hex: "#1E88E5")
        }
        if lowName.contains("strength") || lowName.contains("lift") || lowName.contains("weight") || lowName.contains("力量") {
            return Color(hex: "#7B61FF")
        }
        return VelaTheme.accent
    }

    private var workoutSecondaryColor: Color {
        let lowName = workout.activityName.lowercased()
        if lowName.contains("run") || lowName.contains("walk") {
            return Color(hex: "#FFD166")
        }
        if lowName.contains("cycl") {
            return Color(hex: "#4DA3FF")
        }
        if lowName.contains("swim") {
            return Color(hex: "#7FDBFF")
        }
        if lowName.contains("strength") || lowName.contains("lift") || lowName.contains("weight") || lowName.contains("力量") {
            return Color(hex: "#FF9F7A")
        }
        return Color(hex: "#E0A926")
    }
    
    private var formattedHomeDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: workout.start)
    }
    
    private func formattedDuration(_ start: Date, _ end: Date) -> String {
        let diff = Int(end.timeIntervalSince(start))
        let min = diff / 60
        let sec = diff % 60
        if min > 0 {
            return "\(min)m \(sec)s"
        }
        return "\(sec)s"
    }
    
    private func iconForWorkout(_ name: String) -> String {
        let lowName = name.lowercased()
        if lowName.contains("run") { return "figure.run" }
        if lowName.contains("walk") { return "figure.walk" }
        if lowName.contains("cycl") { return "figure.outdoor.cycle" }
        if lowName.contains("strength") || lowName.contains("lift") || lowName.contains("weight") { return "figure.strengthtraining.traditional" }
        if lowName.contains("yoga") { return "figure.yoga" }
        if lowName.contains("swim") { return "figure.pool.swim" }
        return "figure.run"
    }
    
    private func centerOfCoordinates(_ coords: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        guard !coords.isEmpty else { return CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090) }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let minLat = lats.min() ?? 0
        let maxLat = lats.max() ?? 0
        let minLon = lons.min() ?? 0
        let maxLon = lons.max() ?? 0
        return CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
    }
    
    private var dashboardVMForWorkout: DashboardSummary {
        var base = dashboardVM.dashboard
        base.workouts = [workout]
        return base
    }
    
    private func loadWorkoutDetails() async {
        isLoading = true
        
        do {
            let samples = try await queryService.heartRateSamples(start: workout.start, end: workout.end)
            heartRates = samples
            
            let route = try await queryService.workoutRoute(workoutId: workout.id)
            if !route.isEmpty {
                routeCoordinates = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            } else {
                routeCoordinates = []
            }
        } catch {
            print("Workout detail loading failed: \(error.localizedDescription)")
            heartRates = []
            routeCoordinates = []
        }
        
        isLoading = false
    }

    private func deleteWorkout() {
        do {
            let workoutID = workout.id
            let eventDescriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.id == workoutID || $0.linkedHealthKitWorkoutId == workoutID }
            )
            let events = try modelContext.fetch(eventDescriptor)
            for event in events {
                if let hkId = event.linkedHealthKitWorkoutId {
                    modelContext.insert(DeletedWorkoutRecord(id: hkId.uuidString))
                } else if event.source == "healthKit" {
                    modelContext.insert(DeletedWorkoutRecord(id: event.id.uuidString))
                }
                if let strengthId = event.linkedStrengthWorkoutId {
                    let strDescriptor = FetchDescriptor<StrengthWorkoutRecord>(
                        predicate: #Predicate<StrengthWorkoutRecord> { $0.id == strengthId }
                    )
                    if let strWorkout = try? modelContext.fetch(strDescriptor).first {
                        try? WorkoutAggregationService.shared.deleteStrengthWorkout(strWorkout, modelContext: modelContext)
                    }
                }
                modelContext.delete(event)
            }
            if workout.source == "healthKit" || workout.source == nil {
                modelContext.insert(DeletedWorkoutRecord(id: workout.id.uuidString))
            }
            try modelContext.save()
            try? WorkoutAggregationService.shared.aggregateDay(date: workout.start, modelContext: modelContext)
            
            VelaAppState.shared.markLocalDataChanged()
            
            Task {
                await dashboardVM.refresh(modelContext: modelContext)
            }
            dismiss()
        } catch {
            print("Failed to delete workout: \(error)")
        }
    }

    private var linkedStrengthWorkout: StrengthWorkoutRecord? {
        // 1. Try explicit link via WorkoutEventRecord
        if let event = workoutEvents.first(where: { $0.id == workout.id || $0.linkedHealthKitWorkoutId == workout.id }),
           let strengthId = event.linkedStrengthWorkoutId {
            if let match = strengthWorkouts.first(where: { $0.id == strengthId }) {
                return match
            }
        }
        // 2. Try direct matching of workout.id
        if let match = strengthWorkouts.first(where: { $0.id == workout.id }) {
            return match
        }
        // 3. Fallback: Find by time overlap (30 mins range)
        let matchRange: TimeInterval = 30 * 60
        if let match = strengthWorkouts.first(where: { abs($0.startedAt.timeIntervalSince(workout.start)) <= matchRange }) {
            return match
        }
        return nil
    }

    private func muscleDistribution(_ strength: StrengthWorkoutRecord) -> some View {
        let analysis = TrainingAnalyticsService().summarizeWorkout(
            strength,
            history: strengthWorkouts.filter { $0.startedAt < strength.startedAt },
            exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
        )
        return VelaGlassCard(padding: 16, cornerRadius: 20) {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("肌群分布")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text("有效组")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            if analysis.muscleGroupSets.isEmpty {
                Text("这次训练暂未形成有效组。")
                    .font(.system(size: 13))
                    .foregroundStyle(mutedColor)
            } else {
                ForEach(analysis.muscleGroupSets.sorted { $0.value > $1.value }, id: \.key) { muscle, sets in
                    let maxSets = max(analysis.muscleGroupSets.values.max() ?? 1, 1)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(localizedMuscle(muscle))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(bodyTextColor)
                            Spacer()
                            Text("\(sets) 组")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(mutedColor)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: "#EFEAE2"))
                                Capsule()
                                    .fill(muscleColor(muscle))
                                    .frame(width: geo.size.width * CGFloat(Double(sets) / Double(maxSets)))
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
          }
        }
    }

    private func exerciseList(_ strength: StrengthWorkoutRecord) -> some View {
        let analysis = TrainingAnalyticsService().summarizeWorkout(
            strength,
            history: strengthWorkouts.filter { $0.startedAt < strength.startedAt },
            exerciseLibrary: ExerciseLibraryService.defaultDefinitions()
        )
        return VStack(alignment: .leading, spacing: 12) {
            Text("动作与组次")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VelaTheme.primaryText)

            ForEach(strength.exercises) { exercise in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(bodyTextColor)
                            Text("\(exercise.equipment) · \(Int(exercise.volumeKilograms.rounded())) kg")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(mutedColor)
                        }
                        Spacer()
                        if let e1RM = analysis.estimatedOneRepMaxByExercise[exercise.name] {
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(Int(e1RM.rounded())) kg")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(accentColor)
                                Text("e1RM")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(mutedColor)
                            }
                        }
                    }

                    if !exercise.sets.isEmpty {
                        HStack(spacing: 12) {
                            Text("组")
                                .frame(width: 32, alignment: .leading)
                            Text("重量")
                                .frame(width: 70, alignment: .center)
                            Spacer()
                            Text("次数")
                                .frame(width: 50, alignment: .center)
                            Text("RPE")
                                .frame(width: 44, alignment: .center)
                            Text("状态")
                                .frame(width: 32, alignment: .trailing)
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(mutedColor)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    }

                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                        Button {
                            selectedSet = StrengthSetDetail(
                                exerciseName: exercise.name,
                                setIndex: index + 1,
                                set: set
                            )
                        } label: {
                            setRow(index: index, set: set)
                        }
                        .buttonStyle(.cardPress)
                    }
                }
                .padding(16)
                .velaNativeCard(radius: 16)
            }
        }
    }

    private func setRow(index: Int, set: StrengthSetLog) -> some View {
        HStack(spacing: 12) {
            Text(set.isWarmup ? "热" : "\(index + 1)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(set.isWarmup ? Color(hex: "#FF9500") : VelaTheme.accent))
                .frame(width: 32, alignment: .leading)

            Text("\(set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(bodyTextColor)
                .frame(width: 70, alignment: .center)

            Spacer()

            Text("\(set.repetitions) 次")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(bodyTextColor)
                .frame(width: 50, alignment: .center)

            Text(set.rpe.map { "\(Int($0))" } ?? "—")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(set.rpe != nil ? VelaTheme.accent : mutedColor)
                .frame(width: 44, height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.04)))

            Image(systemName: (set.isCompleted ?? true) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle((set.isCompleted ?? true) ? VelaTheme.success : mutedColor)
                .font(.system(size: 20))
                .frame(width: 32, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func notesCard(_ strength: StrengthWorkoutRecord) -> some View {
        if !strength.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VelaGlassCard(padding: 16, cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("训练备注", systemImage: "note.text")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(strength.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(VelaTheme.secondaryText)
                }
            }
        }
    }

    private func localizedMuscle(_ muscle: String) -> String {
        [
            "chest": "胸部",
            "back": "背部",
            "quads": "股四头肌",
            "hamstrings": "腘绳肌",
            "glutes": "臀部",
            "shoulders": "肩部",
            "biceps": "肱二头肌",
            "triceps": "肱三头肌",
            "core": "核心",
            "other": "其他"
        ][muscle] ?? muscle
    }

    private func muscleColor(_ muscle: String) -> Color {
        switch muscle {
        case "chest": return Color(hex: "#FF8A65")
        case "back": return Color(hex: "#4DB6AC")
        case "quads", "hamstrings", "glutes": return Color(hex: "#66BB6A")
        case "shoulders": return Color(hex: "#5C6BC0")
        case "biceps", "triceps": return Color(hex: "#AB47BC")
        case "core": return Color(hex: "#FFCA28")
        default: return Color(hex: "#90A4AE")
        }
    }

}

struct HeartRateRangeBin: Identifiable {
    let id = UUID()
    let date: Date
    let minBPM: Double
    let maxBPM: Double
}

private struct HeartRateZoneSegment: Identifiable {
    let id = UUID()
    let label: String
    let count: Int
    let color: Color
}

private struct HeartRateZoneRibbonView: View {
    let segments: [HeartRateZoneSegment]

    var body: some View {
        GeometryReader { proxy in
            let visibleSegments = segments.filter { $0.count > 0 }
            let total = max(1, visibleSegments.reduce(0) { $0 + $1.count })
            let spacing = CGFloat(max(visibleSegments.count - 1, 0)) * 3
            let availableWidth = max(0, proxy.size.width - spacing)

            HStack(spacing: 3) {
                if visibleSegments.isEmpty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: "#E5E5EA"))
                } else {
                    ForEach(visibleSegments) { segment in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(segment.color)
                            .frame(width: max(12, availableWidth * CGFloat(segment.count) / CGFloat(total)))
                    }
                }
            }
        }
        .accessibilityLabel("Heart rate zone distribution")
    }
}

private struct WorkoutHeartRateInsightSheet: View {
    let averageText: String
    let peakText: String
    let rangeText: String
    let intensityText: String
    let segments: [HeartRateZoneSegment]

    private var totalCount: Int {
        max(1, segments.reduce(0) { $0 + $1.count })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text("心率区间")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                Text(intensityText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)
            }

            HStack(spacing: 10) {
                insightTile(title: "平均", value: averageText)
                insightTile(title: "峰值", value: peakText)
                insightTile(title: "范围", value: rangeText)
            }

            HeartRateZoneRibbonView(segments: segments)
                .frame(height: 34)

            VStack(spacing: 10) {
                ForEach(segments) { segment in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 9, height: 9)
                        Text(segment.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(VelaTheme.fg)
                        Spacer()
                        Text("\(Int((Double(segment.count) / Double(totalCount) * 100).rounded()))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.muted)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func insightTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VelaTheme.cardBg))
    }
}

private struct StrengthSetDetail: Identifiable {
    let id = UUID()
    var exerciseName: String
    var setIndex: Int
    var set: StrengthSetLog
}

private struct StrengthSetDetailSheet: View {
    let detail: StrengthSetDetail

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(detail.exerciseName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("第 \(detail.setIndex) 组")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VelaTheme.muted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metric("重量", "\(detail.set.weightKilograms.formatted(.number.precision(.fractionLength(0...1)))) kg")
                    metric("次数", "\(detail.set.repetitions)")
                    metric("容量", "\(Int(detail.set.volumeKilograms.rounded())) kg")
                    metric("RPE", detail.set.rpe.map { "\(Int($0))" } ?? "--")
                    metric("RIR", detail.set.rir.map { "\(Int($0))" } ?? "--")
                    metric("状态", (detail.set.isCompleted ?? true) ? "已完成" : "未完成")
                }
                Spacer()
            }
            .padding(18)
            .background(VelaTheme.systemGroupedBackground)
            .navigationTitle("组详情")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(VelaTheme.cardBg))
    }
}
