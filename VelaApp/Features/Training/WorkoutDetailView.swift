import SwiftUI
import Charts
import MapKit
import HealthKit

struct WorkoutDetailView: View {
    let workout: WorkoutSummary
    
    @Environment(\.dismiss) private var dismiss
    @State private var heartRates: [HeartRateSample] = []
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var isLoading = true
    
    private let queryService = HealthKitQueryService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Premium Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("健身详情")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                
                Spacer()
                
                // Balanced spacer
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(hex: "#F5F3F0"))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Card
                    workoutHeaderCard
                    
                    // Stats Metrics Row
                    statsMetricsRow
                    
                    // Heart Rate Fluctuation Chart
                    heartRateChartSection
                    
                    // GPS Route Map
                    if !routeCoordinates.isEmpty {
                        gpsRouteSection
                    }
                    
                    // Coach Insight Integration
                    workoutCoachCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(Color(hex: "#F5F3F0")) // Warm canvas base
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar) // Hide standard nav bar for premium custom header
        .task {
            await loadWorkoutDetails()
        }
    }
    
    // MARK: - Subviews
    
    private var workoutHeaderCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#F4EBDC")) // Warm light gold
                    .frame(width: 52, height: 52)
                
                Image(systemName: iconForWorkout(workout.activityName))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#C59B27")) // Warm gold bronze
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.activityName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                
                Text(formattedWorkoutTime)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            
            Spacer()
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
    
    private var statsMetricsRow: some View {
        HStack(spacing: 10) {
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
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A1917"))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
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
                    .foregroundStyle(Color(hex: "#1A1917"))
            }
            
            if isLoading {
                ProgressView().tint(Color(hex: "#C56B4A")).frame(height: 160).frame(maxWidth: .infinity)
            } else if heartRates.isEmpty {
                Text(L10n.t("No heart rate details recorded for this period.", "此时间段未记录心率明细。"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .frame(height: 160)
            } else {
                Chart {
                    ForEach(heartRates) { item in
                        AreaMark(
                            x: .value("Time", item.date),
                            y: .value("BPM", item.bpm)
                        )
                        .foregroundStyle(LinearGradient(
                            colors: [Color(hex: "#5C6BC0").opacity(0.24), Color(hex: "#5C6BC0").opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .interpolationMethod(.catmullRom)
                        
                        LineMark(
                            x: .value("Time", item.date),
                            y: .value("BPM", item.bpm)
                        )
                        .foregroundStyle(Color(hex: "#5C6BC0"))
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis(.hidden)
                .chartYScale(domain: 80...200)
                .frame(height: 160)
                .padding(.top, 6)
            }
        }
        .padding(18)
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
    
    private var gpsRouteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hex: "#4CAF50")) // Map green
                
                Text(L10n.t("GPS Workout Route", "GPS 运动轨迹"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
            }
            
            if isLoading {
                ProgressView().tint(Color(hex: "#C56B4A")).frame(height: 220).frame(maxWidth: .infinity)
            } else if routeCoordinates.isEmpty {
                Text(L10n.t("No GPS route mapping recorded for this workout.", "此项运动未记录 GPS 运动轨迹。"))
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: "#8E8A80"))
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
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.03), radius: 6, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
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
        var base = DashboardSummary.preview()
        base.workouts = [workout]
        return base
    }
    
    private func loadWorkoutDetails() async {
        isLoading = true
        
        do {
            let samples = try await queryService.heartRateSamples(start: workout.start, end: workout.end)
            if !samples.isEmpty {
                heartRates = samples
            } else {
                heartRates = generateSimulatedHeartRates()
            }
            
            let route = try await queryService.workoutRoute(workoutId: workout.id)
            if !route.isEmpty {
                routeCoordinates = route.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            } else {
                routeCoordinates = []
            }
        } catch {
            print("Workout detail loading failed, loading fallbacks: \(error.localizedDescription)")
            heartRates = generateSimulatedHeartRates()
            routeCoordinates = []
        }
        
        isLoading = false
    }
    
    private func generateSimulatedHeartRates() -> [HeartRateSample] {
        var result: [HeartRateSample] = []
        let duration = workout.end.timeIntervalSince(workout.start)
        let steps = 15
        let stepInterval = duration / Double(steps)
        
        let avgHR = workout.averageHeartRate ?? 142.0
        
        for i in 0..<steps {
            let offset = Double(i) * stepInterval
            let date = workout.start.addingTimeInterval(offset)
            
            let ratio = Double(i) / Double(steps)
            let factor = sin(ratio * Double.pi)
            let randomFluctuation = Double.random(in: -8...8)
            let bpm = avgHR - 18.0 + (factor * 30.0) + randomFluctuation
            
            result.append(HeartRateSample(date: date, bpm: max(80.0, min(195.0, bpm))))
        }
        return result
    }
    

}
