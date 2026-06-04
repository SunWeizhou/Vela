import SwiftUI
import Charts
import MapKit
import HealthKit

struct WorkoutDetailView: View {
    let workout: WorkoutSummary
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @State private var heartRates: [HeartRateSample] = []
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoading = true
    @State private var showHeartRateInsight = false
    
    private let queryService = HealthKitQueryService()
    
    var body: some View {
        ZStack {
            workoutDetailBackground

            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VelaTheme.accent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("健身详情")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VelaTheme.fg)

                    Spacer()

                    Button {
                        showHeartRateInsight = true
                    } label: {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(heartRates.isEmpty ? VelaTheme.muted : VelaTheme.accent)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(heartRates.isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(.regularMaterial)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(VelaTheme.separatorSoft)
                        .frame(height: 0.5)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        workoutHeaderCard
                        statsMetricsRow
                        heartRateChartSection

                        if !routeCoordinates.isEmpty {
                            gpsRouteSection
                        }

                        workoutCoachCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar) // Hide standard nav bar for premium custom header
        .task {
            await loadWorkoutDetails()
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
    }
    
    // MARK: - Subviews

    private var workoutDetailBackground: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [
                    workoutAccentColor.opacity(0.18),
                    VelaTheme.systemGroupedBackground,
                    VelaTheme.systemGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        workoutAccentColor.opacity(0.16),
                        workoutSecondaryColor.opacity(0.10),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }
    
    private var workoutHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(workoutAccentColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                
                Image(systemName: iconForWorkout(workout.activityName))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(workoutAccentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
                
                Text(formattedWorkoutTime)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [VelaTheme.cardBg, workoutAccentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.black.opacity(0.012), radius: 10, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
    }
    
    private var statsMetricsRow: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
            workoutStatTile(
                title: L10n.t("Duration", "持续时间"),
                value: formattedDuration(workout.start, workout.end),
                icon: "clock.fill",
                color: Color(hex: "#E0A926") // Deep warm yellow
            )
            
            workoutStatTile(
                title: L10n.t("Active Burn", "活动消耗"),
                value: workout.energyKilocalories.map { "\(Int($0)) kcal" } ?? "--",
                icon: "flame.fill",
                color: Color(hex: "#FF7043") // Orange fire
            )
            
            workoutStatTile(
                title: L10n.t("Avg Heart Rate", "平均心率"),
                value: workout.averageHeartRate.map { "\(Int($0)) bpm" } ?? "--",
                icon: "heart.fill",
                color: Color(hex: "#5C6BC0") // Indigo purple
            )

            workoutStatTile(
                title: L10n.t("Distance", "距离"),
                value: formattedDistance,
                icon: "location.fill",
                color: Color(hex: "#4CAF50")
            )
        }
    }
    
    private func workoutStatTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VelaTheme.muted)
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VelaTheme.cardBg)
                .shadow(color: Color.black.opacity(0.01), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(VelaTheme.separatorSoft, lineWidth: 0.5)
        )
    }
    
    private var heartRateChartSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#FF5252")) // Vibrant pulse red
                
                Text(L10n.t("Heart Rate Fluctuation", "心率波动趋势"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            
            if isLoading {
                ProgressView().tint(VelaTheme.accent).frame(height: 160).frame(maxWidth: .infinity)
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
                            .foregroundStyle(VelaTheme.muted.opacity(0.45))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .trailing, alignment: .center) {
                                Text("AVG")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(VelaTheme.muted)
                            }
                    }

                    ForEach(heartRates) { item in
                        AreaMark(
                            x: .value("Time", item.date),
                            y: .value("BPM", item.bpm)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex: "#FF3B30").opacity(0.26), Color(hex: "#FF9500").opacity(0.03)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Time", item.date),
                            y: .value("BPM", item.bpm)
                        )
                        .foregroundStyle(Color(hex: "#FF3B30"))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }

                    if let maxHeartRateSample {
                        PointMark(
                            x: .value("Peak Time", maxHeartRateSample.date),
                            y: .value("Peak BPM", maxHeartRateSample.bpm)
                        )
                        .symbolSize(70)
                        .foregroundStyle(Color.white)
                        .annotation(position: .top, alignment: .center) {
                            Text("\(Int(maxHeartRateSample.bpm.rounded()))")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#FF3B30"))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(VelaTheme.cardBg))
                        }
                    }
                }
                .chartXAxis(.hidden)
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
        .padding(18)
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

    private func heartRateFact(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.fg)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(VelaTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(VelaTheme.systemGroupedBackground))
    }
    
    private var gpsRouteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#4CAF50")) // Map green
                
                Text(L10n.t("GPS Workout Route", "GPS 运动轨迹"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VelaTheme.fg)
            }
            
            if isLoading {
                ProgressView().tint(VelaTheme.accent).frame(height: 220).frame(maxWidth: .infinity)
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
        .padding(18)
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
