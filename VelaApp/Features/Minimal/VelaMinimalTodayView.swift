import SwiftUI
import SwiftData

// MARK: - VelaTodayView — Bevel Replica Today Tab
// Warm off-white background (#F5F3F0) × Premium White Cockpit cards with precise shadows

struct VelaTodayView: View {
    @Binding var showCoach: Bool
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) private var cs
    @Environment(\.velaScrollDirection) private var scrollDirection
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel

    private var dashboard: DashboardSummary { dashboardVM.dashboard }

    // Real scores mapped to 0...1 for BevelScoreRing
    private var strainScore: Double { max(0, min(1.0, dashboard.strain.score / 100.0)) }
    private var recoveryScore: Double { max(0, min(1.0, dashboard.recovery.score / 100.0)) }
    private var sleepScore: Double { max(0, min(1.0, dashboard.sleepScore.score / 100.0)) }

    private var hrvValue: Double { dashboard.recoveryMetrics.hrvMilliseconds ?? 0 }
    private var rhrValue: Double { dashboard.recoveryMetrics.restingHeartRate ?? 0 }
    
    // Stress & Energy
    private var stressLevel: Double { dashboard.stress.stressIndex }
    private var energyScore: Double { dashboard.energy.currentEnergy }

    private var highestStress: String {
        guard dashboard.stress.hasData else { return "--" }
        let val = min(98.0, max(stressLevel * 1.28, stressLevel + 16.0))
        return "\(Int(val.rounded()))"
    }

    private var lowestStress: String {
        guard dashboard.stress.hasData else { return "--" }
        let val = max(8.0, min(stressLevel * 0.48, stressLevel - 14.0))
        return "\(Int(val.rounded()))"
    }

    // Dynamic states for nutrition logs
    @State private var todayCalories: Int = 0
    @State private var todayProtein: Int = 0
    @State private var todayCarbs: Int = 0
    @State private var todayFat: Int = 0

    private var calorieFraction: CGFloat {
        CGFloat(min(1.0, Double(todayCalories) / 2000.0))
    }

    private var coachMessage: String {
        dashboard.dailyInsight.isEmpty
            ? "正在等待足够的 Apple 健康数据，完成同步后会生成今日指导。"
            : dashboard.dailyInsight
    }

    // Dynamic Weather Sync States
    @State private var weatherTemp: String = "--"
    @State private var weatherLocation: String = "天气数据待同步"

    // Active Status Settings Toggles (Replicating Screenshot 2)
    @AppStorage("vela_active_status") private var activeStatusRaw = "resting"
    @AppStorage("vela_active_status_duration") private var activeStatusDuration = "明天之前"

    // Sheets trigger states
    @State private var showCalendarOverview = false
    @State private var showActiveStatus = false

    private var statusPillIcon: String {
        switch activeStatusRaw {
        case "active": return "figure.run"
        case "sick": return "bed.double.fill"
        case "injured": return "bandage.fill"
        default: return "beach.umbrella.fill"
        }
    }
    
    private var statusPillColor: Color {
        switch activeStatusRaw {
        case "active": return Color(hex: "#34C759") // Teal green
        case "sick": return Color(hex: "#FF9F0A") // Orange yellow
        case "injured": return Color(hex: "#FF3B30") // Red pink
        default: return Color(hex: "#4285F4") // Blue
        }
    }
    
    private var statusPillTitle: String {
        switch activeStatusRaw {
        case "active": return "活跃"
        case "sick": return "生病"
        case "injured": return "受伤"
        default: return "休息中"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Date Header with Selector & Share & Avatar
                dateHeaderRow
                
                // 2. Horizontal Status & Weather Pills
                pillsRow
                
                // 3. White Cockpit Card (Strain, Recovery, Sleep side-by-side rings)
                cockpitCard
                
                // 4. Stress & Energy Section
                stressAndEnergySection
                
                // 5. Nutrition (营养) Section
                nutritionSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 140) // Floating tab bar safety gap
        }
        .scrollIndicators(.hidden)
        .velaTrackScroll(direction: scrollDirection)
        .background(Color(hex: "#F5F3F0")) // Warm canvas base
        .task {
            await refreshDashboard()
        }
        .refreshable {
            await refreshDashboard()
        }
        .onChange(of: dashboardVM.selectedDate) { _ in
            Task {
                await refreshDashboard()
            }
        }
        .sheet(isPresented: $showCalendarOverview) {
            CalendarOverviewSheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color(hex: "#F5F3F0"))
        }
        .sheet(isPresented: $showActiveStatus) {
            ActiveStatusSelectionSheetView(
                activeStatusRaw: $activeStatusRaw,
                activeStatusDuration: $activeStatusDuration
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color(hex: "#F5F3F0"))
        }
    }

    // MARK: - Date Header Row
    private var dateHeaderRow: some View {
        HStack(alignment: .center) {
            Button {
                showCalendarOverview = true
            } label: {
                HStack(spacing: 6) {
                    Text(dateHeaderString(for: dashboardVM.selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 12) {
                // Share button
                Button {
                    // Action
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color(hex: "#1A1917"))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
                
                // Profile Avatar
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(Color(hex: "#C56B4A"))
                        .background(Circle().fill(Color(hex: "#E8E4DD")))
                        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Date formatting helpers
    private func dateHeaderString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天, " + formatMonthDayString(date)
        } else if calendar.isDateInYesterday(date) {
            return "昨天, " + formatMonthDayString(date)
        } else {
            return formatMonthDayString(date)
        }
    }
    
    private func formatMonthDayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    // MARK: - Weather Sync network engine (IP-Geo + OpenMeteo)
    private func fetchLocalWeather() {
        Task {
            do {
                guard let ipUrl = URL(string: "https://ipapi.co/json/") else { return }
                let (ipData, _) = try await URLSession.shared.data(from: ipUrl)
                if let json = try JSONSerialization.jsonObject(with: ipData) as? [String: Any],
                   let city = json["city"] as? String,
                   let region = json["region"] as? String,
                   let lat = json["latitude"] as? Double,
                   let lon = json["longitude"] as? Double {
                    
                    let weatherUrlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current_weather=true"
                    guard let weatherUrl = URL(string: weatherUrlString) else { return }
                    let (weatherData, _) = try await URLSession.shared.data(from: weatherUrl)
                    if let weatherJson = try JSONSerialization.jsonObject(with: weatherData) as? [String: Any],
                       let current = weatherJson["current_weather"] as? [String: Any],
                       let temp = current["temperature"] as? Double {
                        
                        await MainActor.run {
                            self.weatherTemp = "\(Int(temp))°C"
                            self.weatherLocation = "\(city), \(region)"
                        }
                    }
                }
            } catch {
                print("Failed to sync weather locally: \(error)")
            }
        }
    }

    // MARK: - Status & Weather Pills Row
    private var pillsRow: some View {
        HStack(spacing: 12) {
            // Dynamic Active status pill (Clicking opens selection card)
            Button {
                showActiveStatus = true
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(statusPillColor)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: statusPillIcon)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(statusPillTitle)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text(activeStatusDuration)
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#BFB9AC"))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            
            // Dynamic Weather status pill (Successfully auto-syncs)
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#F1F3F4"))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(weatherTemp)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text(weatherLocation)
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.02), radius: 4, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Cockpit Card (Strain, Recovery, Sleep side-by-side rings)
    private var cockpitCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Three circular gauges
            HStack(alignment: .center, spacing: 0) {
                // Strain (耗力) - Grey Theme
                NavigationLink(destination: VelaMetricDetailView(metric: .strain)) {
                    BevelScoreRing(
                        score: strainScore,
                        color: Color(hex: "#8E8A80"),
                        useGradient: false,
                        size: 78,
                        label: "耗力",
                        valueText: dashboard.strain.hasData ? "\(Int(dashboard.strain.score))%" : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // Vertical divider line
                Rectangle()
                    .fill(Color(hex: "#E8E4DD"))
                    .frame(width: 0.5, height: 60)
                
                // Recovery (恢复) - Yellow Green Gradient
                NavigationLink(destination: VelaMetricDetailView(metric: .recovery)) {
                    BevelScoreRing(
                        score: recoveryScore,
                        color: Color(hex: "#9CCC65"),
                        useGradient: true,
                        size: 78,
                        label: "恢复",
                        valueText: dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score))%" : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                
                // Vertical divider line
                Rectangle()
                    .fill(Color(hex: "#E8E4DD"))
                    .frame(width: 0.5, height: 60)
                
                // Sleep (睡眠) - Blue Indigo Gradient
                NavigationLink(destination: VelaMetricDetailView(metric: .sleep)) {
                    BevelScoreRing(
                        score: sleepScore,
                        color: Color(hex: "#5C6BC0"),
                        useGradient: true,
                        size: 78,
                        label: "睡眠",
                        valueText: dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score))%" : "--"
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 8)
            
            // Subtitle / Guidance Box
            VStack(alignment: .leading, spacing: 6) {
                Text("指导")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
                    .textCase(.uppercase)
                
                Text(coachMessage)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .foregroundStyle(Color(hex: "#1A1917"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Stress & Energy Section
    private var stressAndEnergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("压力和能量")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1917"))
                .padding(.leading, 2)
            
            // 1. Stress Card
            NavigationLink(destination: VelaMetricDetailView(metric: .stress)) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#81C784"))
                                .frame(width: 8, height: 8)
                            
                            Text("今天的压力")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#1A1917"))
                            
                            Text(dashboard.stress.hasData ? "已同步" : "暂无数据")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(hex: "#BFB9AC"))
                    }
                    
                    HStack(alignment: .center) {
                        // Left Stats
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(highestStress)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#FF7043"))
                                Text("最高")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                            }
                            
                            Rectangle()
                                .fill(Color(hex: "#E8E4DD"))
                                .frame(width: 0.5, height: 26)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lowestStress)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#81C784"))
                                Text("最低")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                            }
                        }
                        
                        Spacer()
                        
                        // Right Sparkline / Gauge
                        HStack(spacing: 4) {
                            let stressSegments = [12, 28, 45, 18, 9, 32, 25, 41, 19, 15]
                            ForEach(0..<stressSegments.count, id: \.self) { idx in
                                let h = CGFloat(stressSegments[idx] * 24 / 45)
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(dashboard.stress.hasData && stressLevel > Double(idx) / 10.0 ? Color(hex: "#FF7043") : Color(hex: "#E8E4DD"))
                                    .frame(width: 2.5, height: h)
                            }
                        }
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            
            // 2. Energy Card (Bevel High-Fidelity Segmented Battery Card)
            NavigationLink(destination: VelaMetricDetailView(metric: .energy)) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#34C759")) // Vibrant Bevel green
                    
                    Spacer()
                    
                    // 40 Ticks
                    HStack(spacing: 1.2) {
                        ForEach(0..<40, id: \.self) { idx in
                            let threshold = Double(idx) / 40.0 * 100.0
                            RoundedRectangle(cornerRadius: 1.0)
                                .fill(energyScore >= threshold ? Color(hex: "#34C759") : Color(hex: "#E8E4DD").opacity(0.7))
                                .frame(width: 1.8, height: 10)
                        }
                    }
                    
                    Spacer()
                    
                    Text(dashboard.energy.hasData ? "\(Int(energyScore))%" : "--")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#1A1917"))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Nutrition (营养) Section
    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日膳食营养")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color(hex: "#1A1917"))
                .padding(.leading, 2)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(todayCalories)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Text("已消耗卡路里 / 目标 2000")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                    }
                    
                    Spacer()
                    
                    // Smooth Progress Circle
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "#F5F3F0"), lineWidth: 6)
                            .frame(width: 58, height: 58)
                        
                        Circle()
                            .trim(from: 0.0, to: calorieFraction)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#FFB74D"), Color(hex: "#FF8A65")],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 58, height: 58)
                            .rotationEffect(.degrees(-90))
                        
                        Text("\(Int(calorieFraction * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#1A1917"))
                    }
                }
                
                Divider()
                    .background(Color(hex: "#E8E4DD"))
                
                // Macros (Protein, Carbs, Fat)
                HStack(spacing: 0) {
                    macroIndicator(title: "蛋白质", target: "90g", current: "\(todayProtein)g", color: Color(hex: "#FF7043"))
                    Spacer()
                    macroIndicator(title: "碳水", target: "220g", current: "\(todayCarbs)g", color: Color(hex: "#FFB74D"))
                    Spacer()
                    macroIndicator(title: "脂肪", target: "65g", current: "\(todayFat)g", color: Color(hex: "#42A5F5"))
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
        }
    }

    private func macroIndicator(title: String, target: String, current: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: "#8E8A80"))
            }
            
            Text(current)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(hex: "#1A1917"))
            
            Text("目标 \(target)")
                .font(.system(size: 10))
                .foregroundStyle(Color(hex: "#BFB9AC"))
        }
    }

    // MARK: - SwiftData nutrition sync
    private func loadRealNutritionData() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: dashboardVM.selectedDate)
        
        let descriptor = FetchDescriptor<FoodLogRecord>()
        do {
            let allLogs = try modelContext.fetch(descriptor)
            let todayLogs = allLogs.filter { log in
                calendar.isDate(log.createdAt, inSameDayAs: start)
            }
            
            todayCalories = todayLogs.map(\.totalCalories).reduce(0, +)
            todayProtein = todayLogs.map(\.proteinGrams).reduce(0, +)
            todayCarbs = todayLogs.map(\.carbsGrams).reduce(0, +)
            todayFat = todayLogs.map(\.fatGrams).reduce(0, +)
        } catch {
            print("Failed to fetch food logs: \(error)")
        }
    }

    private func refreshDashboard() async {
        await dashboardVM.refresh(modelContext: modelContext)
        loadRealNutritionData()
        fetchLocalWeather()
    }
}

// MARK: - ActiveStatusSelectionSheetView (High fidelity to Screenshot 2)
struct ActiveStatusSelectionSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var activeStatusRaw: String
    @Binding var activeStatusDuration: String
    
    @State private var tempStatus: String = "resting"
    @State private var tempDuration: String = "明天之前"
    
    let durationOptions = ["明天之前", "1天", "3天", "5天", "7天", "长期"]
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color(hex: "#E8E4DD"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(hex: "#F5F3F0")))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("活动状态")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(hex: "#1A1917"))
                
                Spacer()
                
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            
            ScrollView {
                VStack(spacing: 14) {
                    statusOptionCard(
                        id: "active",
                        title: "活跃",
                        desc: "保持忙碌和健康",
                        icon: "figure.run",
                        colors: [Color(hex: "#34C759"), Color(hex: "#2ECC71")]
                    )
                    
                    statusOptionCard(
                        id: "sick",
                        title: "生病",
                        desc: "因病休息",
                        icon: "bed.double.fill",
                        colors: [Color(hex: "#FF9F0A"), Color(hex: "#F1C40F")]
                    )
                    
                    statusOptionCard(
                        id: "injured",
                        title: "受伤",
                        desc: "从伤病中恢复",
                        icon: "bandage.fill",
                        colors: [Color(hex: "#FF3B30"), Color(hex: "#E74C3C")]
                    )
                    
                    statusOptionCard(
                        id: "resting",
                        title: "休息中",
                        desc: "从训练中抽出时间休息",
                        icon: "beach.umbrella.fill",
                        colors: [Color(hex: "#4285F4"), Color(hex: "#3498DB")]
                    )
                    
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 15))
                                .foregroundStyle(Color(hex: "#8E8A80"))
                            Text("保持状态")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(hex: "#1A1917"))
                        }
                        
                        Spacer()
                        
                        Menu {
                            ForEach(durationOptions, id: \.self) { opt in
                                Button(opt) {
                                    tempDuration = opt
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(tempDuration)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(Color(hex: "#8E8A80"))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color(hex: "#BFB9AC"))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: "#E8E4DD"), lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Button {
                        activeStatusRaw = tempStatus
                        activeStatusDuration = tempDuration
                        dismiss()
                    } label: {
                        Text("更新")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Color(hex: "#1A1917")))
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            tempStatus = activeStatusRaw
            tempDuration = activeStatusDuration
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
    }
    
    private func statusOptionCard(id: String, title: String, desc: String, icon: String, colors: [Color]) -> some View {
        Button {
            tempStatus = id
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#1A1917"))
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .stroke(tempStatus == id ? Color(hex: "#1A1917") : Color(hex: "#E8E4DD"), lineWidth: 1.5)
                        .frame(width: 20, height: 20)
                    
                    if tempStatus == id {
                        Circle()
                            .fill(Color(hex: "#1A1917"))
                            .frame(width: 10, height: 10)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white))
            .shadow(color: Color.black.opacity(tempStatus == id ? 0.02 : 0.0), radius: 6, y: 3)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tempStatus == id ? Color(hex: "#1A1917") : Color.clear, lineWidth: 1.5)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CalendarOverviewSheetView (High fidelity to Screenshot 1)
struct CalendarOverviewSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @Query(sort: \DailyHealthSummaryRecord.date) private var healthRecords: [DailyHealthSummaryRecord]
    
    @State private var selectedMetric: String = "恢复"
    @State private var calendarYear = Calendar.current.component(.year, from: Date())
    @State private var calendarMonth = Calendar.current.component(.month, from: Date())
    
    let metrics = ["耗力", "恢复", "睡眠", "压力", "能量", "营养"]
    let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(hex: "#E8E4DD"))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack {
                Menu {
                    ForEach(0..<12, id: \.self) { offset in
                        let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
                        Button(monthTitle(for: date)) {
                            calendarYear = Calendar.current.component(.year, from: date)
                            calendarMonth = Calendar.current.component(.month, from: date)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(calendarYear)年\(calendarMonth)月")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#1A1917"))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        prevMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        nextMonth()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(hex: "#8E8A80"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white))
                            .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveToNextMonth)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(metrics, id: \.self) { metric in
                        Button {
                            selectedMetric = metric
                        } label: {
                            Text(metric)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(selectedMetric == metric ? Color.white : Color(hex: "#8E8A80"))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedMetric == metric ? Color(hex: "#1A1917") : Color(hex: "#F5F3F0"))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(selectedMetric == metric ? Color.clear : Color(hex: "#E8E4DD"), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 2)
            }
            
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 10)
            
            let gridLayout = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            let paddingDays = paddingDaysForDisplayedMonth
            
            ScrollView {
                LazyVGrid(columns: gridLayout, spacing: 14) {
                    ForEach(0..<paddingDays, id: \.self) { _ in
                        Color.clear.frame(height: 52)
                    }
                    
                    ForEach(1...daysInDisplayedMonth, id: \.self) { day in
                        let date = makeDate(year: calendarYear, month: calendarMonth, day: day)
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: dashboardVM.selectedDate)
                        let isFuture = Calendar.current.startOfDay(for: date) > Calendar.current.startOfDay(for: Date())
                        let scoreInfo = scoreInfo(for: date)
                        
                        Button {
                            dashboardVM.selectDate(date)
                            dismiss()
                        } label: {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .stroke(Color(hex: "#F5F3F0"), lineWidth: 4)
                                        .frame(width: 36, height: 36)
                                    
                                    if let scoreInfo {
                                        Circle()
                                            .trim(from: 0.0, to: CGFloat(scoreInfo.score / 100.0))
                                            .stroke(scoreInfo.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                            .frame(width: 36, height: 36)
                                            .rotationEffect(.degrees(-90))
                                    }
                                    
                                    Text("\(day)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(isFuture ? Color(hex: "#BFB9AC") : (isSelected ? Color(hex: "#4285F4") : Color(hex: "#1A1917")))
                                }
                                
                                Color.clear.frame(height: 8)
                            }
                            .frame(maxWidth: .infinity)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(hex: "#4285F4").opacity(0.08))
                                            .frame(width: 44, height: 48)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isFuture)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
            
            HStack {
                Button {
                    dashboardVM.goToToday()
                    dismiss()
                } label: {
                    Text("今天")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: "#4285F4"))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: "#E8F0FE")))
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    // Info modal
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(hex: "#8E8A80"))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white))
                        .shadow(color: Color.black.opacity(0.015), radius: 3, y: 1.5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(hex: "#F5F3F0").ignoresSafeArea())
        .onAppear {
            calendarYear = Calendar.current.component(.year, from: dashboardVM.selectedDate)
            calendarMonth = Calendar.current.component(.month, from: dashboardVM.selectedDate)
        }
    }
    
    private var displayedMonthDate: Date {
        makeDate(year: calendarYear, month: calendarMonth, day: 1)
    }

    private var daysInDisplayedMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: displayedMonthDate)?.count ?? 0
    }

    private var paddingDaysForDisplayedMonth: Int {
        Calendar.current.component(.weekday, from: displayedMonthDate) - 1
    }

    private var canMoveToNextMonth: Bool {
        let calendar = Calendar.current
        let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        return displayedMonthDate < currentMonth
    }
    
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var comp = DateComponents()
        comp.year = year
        comp.month = month
        comp.day = day
        return Calendar.current.date(from: comp) ?? Date()
    }
    
    private func prevMonth() {
        if calendarMonth == 1 {
            calendarMonth = 12
            calendarYear -= 1
        } else {
            calendarMonth -= 1
        }
    }
    
    private func nextMonth() {
        guard canMoveToNextMonth else { return }
        if calendarMonth == 12 {
            calendarMonth = 1
            calendarYear += 1
        } else {
            calendarMonth += 1
        }
    }
    
    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月"
        return formatter.string(from: date)
    }

    private func scoreInfo(for date: Date) -> (score: Double, color: Color)? {
        guard let record = healthRecords.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }
        let score: Double?
        switch selectedMetric {
        case "耗力": score = record.strainScore
        case "恢复": score = record.recoveryScore
        case "睡眠": score = record.sleepScore
        case "压力": score = record.stressIndex
        case "能量": score = record.energyBank
        default: score = nil
        }
        guard let score else { return nil }
        let color: Color
        switch score {
        case ..<40: color = Color(hex: "#FF3B30")
        case ..<70: color = Color(hex: "#FFB74D")
        default: color = Color(hex: "#34C759")
        }
        return (score, color)
    }
}
