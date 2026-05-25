import Charts
import SwiftData
import SwiftUI
import HealthKit
import CoreLocation
import MapKit

// MARK: - Card Layout Types (embedded to avoid pbxproj reference issues)

enum HomeCardType: String, Codable { case scoreCard, compactMetric }

enum HomeCard: String, CaseIterable, Codable, Identifiable {
    case sleep, strain, energy, stress, healthAge, journal, weeklyTrends, streak, recovery
    var id: String { rawValue }
    var type: HomeCardType {
        switch self {
        case .sleep, .strain, .energy, .recovery: return .scoreCard
        case .stress, .healthAge, .journal, .weeklyTrends, .streak: return .compactMetric
        }
    }
    var title: String {
        switch self {
        case .sleep: return L10n.t("Sleep", "睡眠")
        case .strain: return L10n.t("Strain", "负荷")
        case .energy: return L10n.t("Energy", "能量")
        case .stress: return L10n.t("Stress", "压力")
        case .healthAge: return L10n.t("Health Age", "健康年龄")
        case .journal: return L10n.t("Journal", "日记")
        case .weeklyTrends: return L10n.t("Trends", "趋势")
        case .streak: return L10n.t("Streak", "连续天数")
        case .recovery: return L10n.t("Recovery", "恢复")
        }
    }
    var icon: String {
        switch self {
        case .sleep: return "moon.fill"
        case .strain: return "flame.fill"
        case .energy: return "battery.75percent"
        case .stress: return "waveform.path.ecg"
        case .healthAge: return "arrow.up.heart.fill"
        case .journal: return "book.fill"
        case .weeklyTrends: return "chart.line.uptrend.xyaxis"
        case .streak: return "flame.fill"
        case .recovery: return "heart.fill"
        }
    }
    var tint: Color {
        switch self {
        case .sleep: return VelaTheme.sleep
        case .strain: return VelaTheme.strain
        case .energy: return VelaTheme.energy
        case .stress: return VelaTheme.stress
        case .healthAge: return VelaTheme.accent
        case .journal: return VelaTheme.secondaryText
        case .weeklyTrends: return VelaTheme.recovery
        case .streak: return VelaTheme.strain
        case .recovery: return VelaTheme.recovery
        }
    }
}

struct HomeReadinessBrief: Codable, Hashable {
    var statusLabel: String
    var why: String
    var nextAction: String
    var coachQuestion: String
    var accent: DailyPlanAccent

    static func make(dashboard: DashboardSummary, plan: DailyPlanRecommendation) -> HomeReadinessBrief {
        let statusLabel: String
        if !dashboard.recovery.hasData {
            statusLabel = "Building baseline"
        } else {
            switch dashboard.recovery.score {
            case ..<40:
                statusLabel = "Low readiness"
            case ..<65:
                statusLabel = "Controlled day"
            case ..<80:
                statusLabel = "Ready"
            default:
                statusLabel = "High readiness"
            }
        }

        let trimmedInsight = dashboard.dailyInsight.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackWhy = trimmedInsight.isEmpty
            ? "Vela is still collecting enough context to explain today's state."
            : trimmedInsight
        let why = dashboard.recovery.reasons.first
            ?? plan.limiter?.detail
            ?? fallbackWhy

        return HomeReadinessBrief(
            statusLabel: statusLabel,
            why: why,
            nextAction: plan.primaryActionTitle,
            coachQuestion: plan.coachQuestion,
            accent: plan.accent
        )
    }
}

private struct HomeDataTrust: Hashable {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    static func make(dashboard: DashboardSummary, isLoading: Bool, errorMessage: String?) -> HomeDataTrust {
        if isLoading {
            return HomeDataTrust(
                title: L10n.t("Syncing", "同步中"),
                detail: L10n.t("Refreshing Health data", "正在刷新健康数据"),
                systemImage: "arrow.triangle.2.circlepath",
                tint: VelaTheme.energy
            )
        }

        if errorMessage != nil {
            return HomeDataTrust(
                title: L10n.t("Needs attention", "需要处理"),
                detail: L10n.t("Check Health permissions", "检查健康权限"),
                systemImage: "exclamationmark.triangle.fill",
                tint: VelaTheme.stress
            )
        }

        if dashboard.recovery.hasData || dashboard.sleepScore.hasData || dashboard.strain.hasData {
            return HomeDataTrust(
                title: L10n.t("Fresh today", "今日已更新"),
                detail: L10n.t("Apple Health connected", "Apple Health 已连接"),
                systemImage: "checkmark.seal.fill",
                tint: VelaTheme.recovery
            )
        }

        return HomeDataTrust(
            title: L10n.t("Building baseline", "正在建立基线"),
            detail: L10n.t("Wear Apple Watch overnight", "夜间佩戴 Apple Watch"),
            systemImage: "clock.badge.checkmark",
            tint: VelaTheme.sleep
        )
    }
}

private enum VelaBevelHomeStyle {
    static let backgroundTop = VelaTheme.background
    static let backgroundBottom = VelaTheme.backgroundTertiary
    static let surface = VelaTheme.surface
    static let elevatedSurface = VelaTheme.elevatedSurface
    static let ink = VelaTheme.primaryText
    static let secondaryInk = VelaTheme.secondaryText
    static let tertiaryInk = VelaTheme.mutedText
    static let hairline = VelaTheme.stroke
    static let cardRadius: CGFloat = 24
    static let chipRadius: CGFloat = 16
}

private struct BevelGlassCard: ViewModifier {
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: VelaBevelHomeStyle.cardRadius, style: .continuous)
                    .fill(VelaBevelHomeStyle.surface)
                    .shadow(color: VelaTheme.cardShadowColor, radius: 22, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: VelaBevelHomeStyle.cardRadius, style: .continuous)
                            .stroke(VelaBevelHomeStyle.hairline, lineWidth: 0.8)
                    )
            )
    }
}

private extension View {
    func bevelGlassCard(padding: CGFloat = 18) -> some View {
        modifier(BevelGlassCard(padding: padding))
    }
}

private struct BevelScoreRing: View {
    let value: Double?
    let title: String
    let tint: Color
    var lineWidth: CGFloat = 7

    private var progress: CGFloat {
        guard let value else { return 0.0 }
        return min(max(CGFloat(value / 100), 0.02), 1.0)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(VelaTheme.stroke, lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.55), tint, tint.opacity(0.75)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.22), radius: 8, y: 2)

                Text(value.map { "\(Int($0.rounded()))%" } ?? "--%")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(value == nil ? VelaBevelHomeStyle.tertiaryInk : VelaBevelHomeStyle.ink)
                    .monospacedDigit()
            }
            .frame(width: 78, height: 78)

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VelaBevelHomeStyle.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HomeCardLayout: Codable {
    var cards: [HomeCard] = HomeCard.allCases
    var hiddenCards: Set<HomeCard> = []
    var enabledCards: [HomeCard] { cards.filter { !hiddenCards.contains($0) } }
    var scoreCards: [HomeCard] { enabledCards.filter { $0.type == .scoreCard } }
    var compactCards: [HomeCard] { enabledCards.filter { $0.type == .compactMetric } }
    static let `default` = HomeCardLayout(
        cards: [.sleep, .strain, .energy, .recovery, .stress, .healthAge, .journal],
        hiddenCards: [.weeklyTrends, .streak]
    )
}

@MainActor
final class HomeCardLayoutStore: ObservableObject {
    @Published var layout = HomeCardLayout.default
    @Published var isEditing = false
    private let key = "vela_home_layout"

    init() {
        if let d = UserDefaults.standard.data(forKey: key),
           var s = try? JSONDecoder().decode(HomeCardLayout.self, from: d) {
            
            var changed = false
            
            // Core cards self-healing migration: Ensure core cards are always in `cards` and never in `hiddenCards`
            let coreCards: [HomeCard] = [.sleep, .strain, .energy, .recovery]
            for c in coreCards {
                if s.hiddenCards.contains(c) {
                    s.hiddenCards.remove(c)
                    changed = true
                }
                if !s.cards.contains(c) {
                    s.cards.append(c)
                    changed = true
                }
            }
            
            // Standard missing migration for other cases
            let decodedSet = Set(s.cards).union(s.hiddenCards)
            let missing = HomeCard.allCases.filter { !decodedSet.contains($0) }
            if !missing.isEmpty {
                s.cards.append(contentsOf: missing)
                changed = true
            }
            
            // Deduplicate s.cards
            var uniqueCards: [HomeCard] = []
            for c in s.cards {
                if !uniqueCards.contains(c) {
                    uniqueCards.append(c)
                } else {
                    changed = true
                }
            }
            s.cards = uniqueCards
            
            layout = s
            if changed {
                save()
            }
        }
    }

    func save() {
        if let d = try? JSONEncoder().encode(layout) { UserDefaults.standard.set(d, forKey: key) }
    }

    func isVisible(_ c: HomeCard) -> Bool { !layout.hiddenCards.contains(c) }

    func hideCard(_ c: HomeCard) {
        layout.hiddenCards.insert(c)
        save()
    }

    func addCard(_ c: HomeCard) {
        layout.hiddenCards.remove(c)
        if !layout.cards.contains(c) { layout.cards.append(c) }
        save()
    }

    func moveCardUp(_ c: HomeCard) {
        guard let i = layout.cards.firstIndex(of: c), i > 0 else { return }
        layout.cards.swapAt(i, i - 1)
        save()
    }

    func moveCardDown(_ c: HomeCard) {
        guard let i = layout.cards.firstIndex(of: c), i < layout.cards.count - 1 else { return }
        layout.cards.swapAt(i, i + 1)
        save()
    }

    func canMoveUp(_ c: HomeCard) -> Bool {
        guard let i = layout.cards.firstIndex(of: c) else { return false }
        return i > 0
    }

    func canMoveDown(_ c: HomeCard) -> Bool {
        guard let i = layout.cards.firstIndex(of: c) else { return false }
        return i < layout.cards.count - 1
    }

    func resetToDefaults() {
        layout = .default
        save()
    }
}

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @ObservedObject private var appState = VelaAppState.shared
    @Environment(\.modelContext) private var modelContext
    @StateObject private var authorizationViewModel = HealthAuthorizationViewModel()
    @Query(sort: \JournalEntryRecord.createdAt, order: .reverse) private var journalEntries: [JournalEntryRecord]
    @Query(sort: \FoodLogRecord.createdAt, order: .reverse) private var foodLogs: [FoodLogRecord]
    @Query(sort: \AIReportRecord.createdAt, order: .reverse) private var savedReports: [AIReportRecord]
    @State private var heroVisible = false
    @State private var columnsVisible = false
    @StateObject private var layoutStore = HomeCardLayoutStore()
    @State private var todayPlan: TodayPlan?
    @State private var selectedActionForWhy: DailyAction?
    @Query(
        filter: #Predicate<MemoryEventRecord> { $0.status == "proposed" },
        sort: \MemoryEventRecord.createdAt,
        order: .reverse
    ) private var pendingProposals: [MemoryEventRecord]
    
    // CoreLocation & Weather
    @StateObject private var locationManager = LocationManager.shared
    @State private var localWeather: VelaWeather? = nil
    @State private var showWeatherSheet = false
    @State private var isFetchingWeather = false
    
    // Workouts Navigation and list
    @State private var showWorkoutsSheet = false
    @State private var recentWorkoutsList: [WorkoutSummary] = []
    private let healthKitQueryService = HealthKitQueryService()

    private var latestMorningBrief: AIReportRecord? {
        savedReports.first { $0.type == "morning_brief" }
    }

    private var dailyPlan: DailyPlanRecommendation {
        DailyPlanEngine.recommendation(for: viewModel.dashboard)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bevelHomeBackground

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerBar

                        if let plan = todayPlan {
                            TodayPlanHero(
                                plan: plan,
                                onActionTap: { _ in },
                                onWhyThisTap: { selectedActionForWhy = $0 }
                            )
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        if viewModel.isLoading {
                            HStack(spacing: 10) {
                                ProgressView().tint(VelaTheme.accent)
                                Text(L10n.t("Syncing...", "同步中..."))
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.mutedText)
                            }
                        }

                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(VelaTheme.stress)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(VelaTheme.stress.opacity(0.10)))
                        }

                        bevelHomeDashboard
                            .opacity(heroVisible ? 1 : 0)
                            .animation(.easeOut(duration: 0.4), value: heroVisible)


                        // Secondary score cards; the primary daily loop already owns Sleep, Strain, and Recovery.
                        let visibleScores = layoutStore.layout.scoreCards.filter { ![.sleep, .strain, .recovery].contains($0) }
                        if !visibleScores.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(visibleScores) { card in
                                    homeCardView(for: card)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        if !viewModel.dashboard.dailyInsight.isEmpty {
                            upgradedInsightCard
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Compact grid: Stress, Health Age, Journal, Streak, Weekly Trends
                        let visibleCompact = layoutStore.layout.compactCards
                        if !visibleCompact.isEmpty {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(visibleCompact, id: \.self) { card in
                                    compactCardView(for: card)
                                }
                            }
                        }

                        if layoutStore.isEditing {
                            hiddenCardsPanel
                        }

                        recoveryHeatmapCard

                        healthConnectCard
                    }
                    .padding(VelaTheme.screenPadding)
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }
                .refreshable {
                    await viewModel.refresh(modelContext: modelContext)
                    await viewModel.loadSleepTrend(modelContext: modelContext)
                    await viewModel.loadStrainTrend(modelContext: modelContext)
                    await viewModel.loadRecoveryTrend(modelContext: modelContext)
                    await viewModel.loadHeatmap(modelContext: modelContext)

                    if viewModel.dashboard.recovery.hasData {
                        await MorningBriefScheduler.shared.runIfNeeded(
                            modelContext: modelContext,
                            dashboard: viewModel.dashboard
                        )
                    }
                }
            }
            .navigationTitle("")
        }
        .id(appState.homeNavigationStackId)
        .task {
            Task {
                await refreshWeather()
            }
            Task {
                await loadRecentWorkouts()
            }
            await viewModel.refresh(modelContext: modelContext)
            await viewModel.loadSleepTrend(modelContext: modelContext)
            await viewModel.loadStrainTrend(modelContext: modelContext)
            await viewModel.loadRecoveryTrend(modelContext: modelContext)
            await viewModel.loadHeatmap(modelContext: modelContext)
            // Build today's plan after all data is loaded
            let wiki = WikiFileService.loadDictionary()
            let activePlanFetch = FetchDescriptor<TrainingPlanRecord>(predicate: #Predicate { $0.isActive })
            let activePlan = (try? modelContext.fetch(activePlanFetch))?.first
            todayPlan = DailyPlanBuilder().build(
                dashboard: viewModel.dashboard, wiki: wiki,
                activePlan: activePlan, pendingProposals: Array(pendingProposals)
            )
            await EveningWikiSyncAgent.shared.runIfNeeded(
                modelContext: modelContext,
                dashboard: viewModel.dashboard
            )
            withAnimation(.easeOut(duration: 0.4)) {
                heroVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.3)) {
                    columnsVisible = true
                }
            }
            BackgroundTaskManager.schedule()
            if viewModel.dashboard.recovery.hasData {
                Task {
                    await MorningBriefScheduler.shared.runIfNeeded(
                        modelContext: modelContext,
                        dashboard: viewModel.dashboard
                    )
                }
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            if let weather = localWeather {
                WeatherDetailsSheet(weather: weather)
            } else {
                WeatherDetailsSheet(weather: VelaWeather(
                    temperature: 24.0,
                    humidity: 60.0,
                    apparentTemperature: 24.5,
                    windSpeed: 10.0,
                    isDay: true,
                    conditionCode: 1
                ))
            }
        }
        .sheet(item: $selectedActionForWhy) { action in
            WhyThisSheet(action: action)
        }
        .sheet(isPresented: $showWorkoutsSheet) {
            recentWorkoutsDrawer
        }
    }

    private func refreshWeather() async {
        guard !isFetchingWeather else { return }
        isFetchingWeather = true
        locationManager.requestPermission()
        
        let startTime = Date()
        while locationManager.location == nil && Date().timeIntervalSince(startTime) < 2.0 {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        let lat: Double
        let lon: Double
        if let loc = locationManager.location {
            lat = loc.coordinate.latitude
            lon = loc.coordinate.longitude
        } else {
            lat = 37.3323
            lon = -122.0312 // default to Cupertino
        }
        
        do {
            let weather = try await WeatherService.shared.fetchWeather(latitude: lat, longitude: lon)
            localWeather = weather
        } catch {
            print("Failed to fetch weather: \(error.localizedDescription)")
            localWeather = VelaWeather(
                temperature: 22.0,
                humidity: 60.0,
                apparentTemperature: 22.5,
                windSpeed: 10.0,
                isDay: true,
                conditionCode: 1
            )
        }
        isFetchingWeather = false
    }

    private func loadRecentWorkouts() async {
        do {
            let list = try await healthKitQueryService.recentWorkouts(limit: 10)
            recentWorkoutsList = list
        } catch {
            print("Failed to fetch recent workouts: \(error.localizedDescription)")
        }
    }

    private var recentWorkoutsDrawer: some View {
        NavigationStack {
            ZStack {
                VelaBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.t("Workout History", "运动历史记录"))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                            .padding(.horizontal, 4)
                            .padding(.top, 16)
                        
                        Text(L10n.t("Select a workout to view heart rate charts and exact GPS trajectories.", "选择一项运动以查看心率波动曲线和精确的 GPS 运动轨迹。"))
                            .font(.caption)
                            .foregroundStyle(VelaTheme.secondaryText)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 8)
                        
                        if recentWorkoutsList.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "figure.run.circle.fill")
                                    .font(.system(size: 52))
                                    .foregroundStyle(VelaTheme.mutedText)
                                Text(L10n.t("No workouts found", "未发现运动记录"))
                                    .font(.headline)
                                    .foregroundStyle(VelaTheme.secondaryText)
                                Text(L10n.t("Record a workout on your Apple Watch or iPhone to view live maps and heart rate.", "在 Apple Watch 或 iPhone 上记录一次运动以获取明细。"))
                                    .font(.caption)
                                    .foregroundStyle(VelaTheme.mutedText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .padding(.vertical, 40)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
                        } else {
                            VStack(spacing: 10) {
                                ForEach(recentWorkoutsList) { w in
                                    NavigationLink {
                                        WorkoutDetailView(workout: w)
                                    } label: {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                Circle()
                                                    .fill(VelaTheme.strain.opacity(0.12))
                                                    .frame(width: 44, height: 44)
                                                Image(systemName: iconForWorkout(w.activityName))
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(VelaTheme.strain)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(w.activityName)
                                                    .font(.subheadline.bold())
                                                    .foregroundStyle(VelaTheme.primaryText)
                                                Text(formattedDate(w.start))
                                                    .font(.caption2)
                                                    .foregroundStyle(VelaTheme.secondaryText)
                                            }
                                            
                                            Spacer()
                                            
                                            VStack(alignment: .trailing, spacing: 3) {
                                                Text(w.energyKilocalories.map { "\(Int($0)) kcal" } ?? "--")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(VelaTheme.energy)
                                                Text(formattedDuration(w.start, w.end))
                                                    .font(.caption2)
                                                    .foregroundStyle(VelaTheme.mutedText)
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(VelaTheme.mutedText)
                                        }
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(VelaTheme.surface))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.black.opacity(0.04), lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(VelaTheme.screenPadding)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.t("Done", "完成")) {
                        showWorkoutsSheet = false
                    }
                    .font(.subheadline.bold())
                }
            }
        }
        .presentationDragIndicator(.visible)
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
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formattedDuration(_ start: Date, _ end: Date) -> String {
        let diff = Int(end.timeIntervalSince(start))
        let min = diff / 60
        if min > 0 {
            return "\(min)m"
        }
        return "\(diff)s"
    }

    private var todayJournalCount: Int {
        let start = Calendar.current.startOfDay(for: Date())
        return journalEntries.filter { $0.createdAt >= start }.count
    }

    private var bevelHomeBackground: some View {
        LinearGradient(
            colors: [
                VelaBevelHomeStyle.backgroundTop,
                Color(red: 0.96, green: 0.96, blue: 0.94),
                VelaBevelHomeStyle.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var formattedHomeDate: String {
        let date = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if AppLanguage.stored.isChinese {
            return "今天，\(month)月\(day)日"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "'Today,' MMM d"
        return formatter.string(from: date)
    }

    private var bevelHomeDashboard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showWorkoutsSheet = true
                } label: {
                    let activeDetail = recentWorkoutsList.isEmpty 
                        ? L10n.t("No workouts", "暂无记录") 
                        : L10n.t("\(recentWorkoutsList.count) recorded", "已记录 \(recentWorkoutsList.count) 次")
                    bevelStatusChip(
                        icon: "figure.run",
                        title: L10n.t("Active", "活跃"),
                        detail: activeDetail,
                        tint: VelaTheme.recovery
                    )
                }
                .buttonStyle(.plain)

                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    showWeatherSheet = true
                } label: {
                    bevelStatusChip(
                        icon: localWeather?.iconName ?? "cloud.sun.fill",
                        title: localWeather != nil ? String(format: "%.0f°C", localWeather!.temperature) : "24°C",
                        detail: localWeather?.conditionName ?? L10n.t("Local weather", "本地天气"),
                        tint: localWeather != nil ? (localWeather!.isDay ? VelaTheme.energy : VelaTheme.sleep) : Color(red: 0.65, green: 0.68, blue: 0.67)
                    )
                }
                .buttonStyle(.plain)
            }

            bevelPrimaryRingsCard
            bevelDailyPlanStrip
            
            // Full-width core metrics cards, matching Bevel 3.0 Home feed daily loop exactly
            homeCardView(for: .recovery)
            homeCardView(for: .sleep)
            homeCardView(for: .strain)

            homeAIInsightsSection

            bevelStressEnergySection

            bevelNutritionCard
        }
    }

    @ViewBuilder
    private var homeAIInsightsSection: some View {
        if viewModel.dashboard.recovery.hasData {
            let proactiveInsights = ProactiveInsightService.evaluate(dashboard: viewModel.dashboard)
            if !proactiveInsights.isEmpty || latestMorningBrief != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.t("Today's AI Insights", "今日 AI 洞察"))
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                        .padding(.horizontal, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            if let brief = latestMorningBrief {
                                NavigationLink {
                                    MorningBriefDetailView(report: brief)
                                } label: {
                                    aiInsightTile(
                                        icon: "sparkles",
                                        tint: VelaTheme.accent,
                                        title: AppLanguage.stored.isChinese ? "今日健康简报" : "Daily Intelligence",
                                        body: {
                                            let sentence = parseOneSentence(from: brief.markdownContent)
                                            return sentence.isEmpty ? brief.title : sentence
                                        }(),
                                        action: AppLanguage.stored.isChinese ? "点击查看完整健康建议" : "Tap to view full intelligence"
                                    )
                                }
                                .buttonStyle(.scaleOnPress)
                                .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
                            }

                            ForEach(proactiveInsights) { insight in
                                Button {
                                    VelaAppState.shared.routeToCoach(question: insight.coachPresetQuestion)
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                } label: {
                                    aiInsightTile(
                                        icon: insight.severity.icon,
                                        tint: insight.severity.color,
                                        title: insight.title,
                                        body: insight.body,
                                        action: insight.suggestedAction
                                    )
                                }
                                .buttonStyle(.scaleOnPress)
                                .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 0)
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, 4)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    private func aiInsightTile(icon: String, tint: Color, title: String, body: String, action: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)

                Text(body)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                if let action, !action.isEmpty {
                    Text(action)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaTheme.accent)
                        .padding(.top, 2)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                .fill(VelaTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .stroke(VelaTheme.stroke, lineWidth: 0.5)
                )
        )
    }

    private func bevelStatusChip(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VelaBevelHomeStyle.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: VelaBevelHomeStyle.chipRadius, style: .continuous)
                .fill(VelaBevelHomeStyle.elevatedSurface)
                .shadow(color: Color.black.opacity(0.045), radius: 10, y: 5)
                .overlay(
                    RoundedRectangle(cornerRadius: VelaBevelHomeStyle.chipRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.045), lineWidth: 0.6)
                )
        )
    }

    private var bevelPrimaryRingsCard: some View {
        VStack(spacing: 18) {
            HStack(alignment: .top, spacing: 8) {
                NavigationLink {
                    StrainMetricDetailView()
                } label: {
                    BevelScoreRing(
                        value: viewModel.dashboard.strain.hasData ? viewModel.dashboard.strain.score : nil,
                        title: L10n.t("Strain", "耗力"),
                        tint: VelaTheme.strain
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RecoveryMetricDetailView()
                } label: {
                    BevelScoreRing(
                        value: viewModel.dashboard.recovery.hasData ? viewModel.dashboard.recovery.score : nil,
                        title: L10n.t("Recovery", "恢复"),
                        tint: VelaTheme.recovery
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    SleepView()
                } label: {
                    BevelScoreRing(
                        value: viewModel.dashboard.sleepScore.hasData ? viewModel.dashboard.sleepScore.score : nil,
                        title: L10n.t("Sleep", "睡眠"),
                        tint: VelaTheme.sleep
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()
                .overlay(Color.black.opacity(0.06))

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.t("Guidance", "指导"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)

                    Text(bevelGuidanceText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    VelaAppState.shared.routeToCoach(question: dailyPlan.coachQuestion)
                } label: {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VelaBevelHomeStyle.secondaryInk)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.black.opacity(0.045)))
                }
                .buttonStyle(.plain)
            }
        }
        .bevelGlassCard(padding: 16)
    }

    private var bevelDailyPlanStrip: some View {
        let brief = HomeReadinessBrief.make(dashboard: viewModel.dashboard, plan: dailyPlan)
        let trust = HomeDataTrust.make(
            dashboard: viewModel.dashboard,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        )
        let accentColor = dailyPlanAccentColor(brief.accent)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(accentColor.opacity(0.12)))

                VStack(alignment: .leading, spacing: 4) {
                    Text(localizedReadinessStatus(brief.statusLabel))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaBevelHomeStyle.ink)

                    Text(brief.nextAction)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VelaBevelHomeStyle.secondaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Button {
                    VelaAppState.shared.routeToCoach(question: brief.coachQuestion)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.black.opacity(0.045)))
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 8) {
                Label(trust.title, systemImage: trust.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(trust.tint)
                    .lineLimit(1)

                Text(localizedReason(brief.why))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .bevelGlassCard(padding: 14)
    }

    private var bevelGuidanceText: String {
        let plan = dailyPlan
        if viewModel.dashboard.strain.hasData,
           viewModel.dashboard.strain.score >= Double(viewModel.dashboard.strain.recommendedRange.upperBound) {
            return L10n.t(
                "You have reached today's strain target. Ease off and make recovery the reward.",
                "已达到目标耗力！好好放松一下，休息是应得的奖励。"
            )
        }

        let brief = HomeReadinessBrief.make(dashboard: viewModel.dashboard, plan: plan)
        let why = localizedReason(brief.why)
        if !why.isEmpty {
            return why
        }
        return plan.title
    }

    private var bevelStressEnergySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("Stress and Energy", "压力和能量"))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(VelaBevelHomeStyle.ink)

            VStack(spacing: 12) {
                NavigationLink {
                    StressDetailView(dashboard: viewModel.dashboard)
                } label: {
                    bevelStressCard
                }
                .buttonStyle(.plain)

                NavigationLink {
                    EnergyBankDetailView(dashboard: viewModel.dashboard)
                } label: {
                    bevelEnergyCard
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bevelNutritionCard: some View {
        NavigationLink {
            NutritionDetailView()
                .environmentObject(viewModel)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(L10n.t("Nutrition", "营养"))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
                }

                HStack(spacing: 10) {
                    nutritionMetric(
                        title: L10n.t("Logged", "已记录"),
                        value: "\(todayFoodLogs.count)",
                        tint: VelaTheme.accent
                    )
                    nutritionMetric(
                        title: L10n.t("Calories", "热量"),
                        value: todayCalories > 0 ? "\(todayCalories)" : "--",
                        tint: VelaTheme.energy
                    )
                    nutritionMetric(
                        title: L10n.t("Protein", "蛋白质"),
                        value: todayProtein > 0 ? "\(todayProtein)g" : "--",
                        tint: VelaTheme.recovery
                    )
                }
            }
            .bevelGlassCard(padding: 16)
        }
        .buttonStyle(.plain)
    }

    private func nutritionMetric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
            Text(value)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(value == "--" ? VelaBevelHomeStyle.tertiaryInk : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }

    private var todayFoodLogs: [FoodLogRecord] {
        foodLogs.filter { Calendar.current.isDateInToday($0.createdAt) }
    }

    private var todayCalories: Int {
        todayFoodLogs.reduce(0) { $0 + $1.totalCalories }
    }

    private var todayProtein: Int {
        todayFoodLogs.reduce(0) { $0 + $1.proteinGrams }
    }

    private var bevelStressCard: some View {
        let stress = viewModel.dashboard.stress.hasData ? viewModel.dashboard.stress.stressIndex : nil
        let high = stress.map { min(100, max(0, $0 + 20)) }
        let low = stress.map { min(100, max(0, $0 - 25)) }

        return HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(VelaTheme.recovery)
                        .frame(width: 6, height: 6)
                    Text(L10n.t("Today's Stress", "今天的压力"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                    Spacer()
                }

                Text(L10n.t("Last updated just now", "最后更新于刚才"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)

                HStack(spacing: 16) {
                    bevelStressMetric(value: high, label: L10n.t("High", "最高"), color: VelaTheme.stress)
                    bevelStressMetric(value: low, label: L10n.t("Low", "最低"), color: VelaTheme.recovery)
                    bevelStressMetric(value: stress, label: L10n.t("Average", "平均"), color: VelaTheme.strain)
                }
            }

            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.045), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(max(CGFloat((stress ?? 0) / 100), 0.02), 1))
                    .stroke(
                        AngularGradient(colors: [VelaTheme.recovery, VelaTheme.energy, VelaTheme.stress], center: .center),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text(stress.map { "\(Int($0.rounded()))" } ?? "--")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                    Text(localizedStressBand(viewModel.dashboard.stress.band))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(VelaTheme.stress)
                }
            }
            .frame(width: 88, height: 88)
        }
        .bevelGlassCard(padding: 16)
    }

    private func bevelStressMetric(value: Double?, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { "\(Int($0.rounded()))" } ?? "--")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
        }
    }

    private var bevelEnergyCard: some View {
        let energy = viewModel.dashboard.energy.hasData ? viewModel.dashboard.energy.currentEnergy : nil

        return HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(VelaTheme.strain)

            GeometryReader { geo in
                let count = 44
                let active = Int(((energy ?? 0) / 100.0) * Double(count))
                HStack(spacing: 2) {
                    ForEach(0..<count, id: \.self) { index in
                        Capsule()
                            .fill(index <= active ? VelaTheme.energy : Color.black.opacity(0.075))
                            .frame(width: max(2, (geo.size.width - CGFloat(count - 1) * 2) / CGFloat(count)), height: 18)
                    }
                }
            }
            .frame(height: 18)

            Text(energy.map { "\(Int($0.rounded()))%" } ?? "--")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(VelaBevelHomeStyle.ink)
                .monospacedDigit()
        }
        .bevelGlassCard(padding: 13)
    }

    private func colloquialSleepStatus(_ score: Double) -> String {
        switch score {
        case ..<40: return L10n.t("Poor", "差")
        case ..<60: return L10n.t("Fair", "一般")
        case ..<80: return L10n.t("Good", "好")
        default: return L10n.t("Great", "很棒")
        }
    }

    private func colloquialSleepColor(_ score: Double) -> Color {
        switch score {
        case ..<40: return VelaTheme.stress
        case ..<60: return VelaTheme.energy
        case ..<80: return VelaTheme.sleep
        default: return VelaTheme.recovery
        }
    }

    private func colloquialStrainStatus(_ score: Double) -> String {
        switch score {
        case ..<25: return L10n.t("Rest", "休息")
        case ..<50: return L10n.t("Light", "轻度")
        case ..<75: return L10n.t("Moderate", "适中")
        case ..<90: return L10n.t("High", "高")
        default: return L10n.t("Peak", "巅峰")
        }
    }

    private func colloquialStrainColor(_ score: Double) -> Color {
        switch score {
        case ..<25: return VelaTheme.recovery
        case ..<50: return VelaTheme.energy
        case ..<75: return VelaTheme.strain
        default: return VelaTheme.stress
        }
    }

    private func colloquialEnergyStatus(_ score: Double) -> String {
        switch score {
        case ..<25: return L10n.t("Drained", "枯竭")
        case ..<50: return L10n.t("Low", "偏低")
        case ..<75: return L10n.t("Balanced", "平衡")
        default: return L10n.t("Full", "充沛")
        }
    }

    @ViewBuilder
    private func homeCardView(for card: HomeCard) -> some View {
        switch card {
        case .sleep:
            NavigationLink { SleepView() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.sleep)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(VelaTheme.sleep.opacity(0.12)))
                        
                        Text(card.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Spacer()
                        
                        if viewModel.dashboard.sleepScore.hasData {
                            Text(colloquialSleepStatus(viewModel.dashboard.sleepScore.score))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(colloquialSleepColor(viewModel.dashboard.sleepScore.score))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(colloquialSleepColor(viewModel.dashboard.sleepScore.score).opacity(0.10))
                                )
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.dashboard.sleepScore.hasData
                            ? "\(viewModel.dashboard.sleepSummary.totalSleepMinutes / 60)h \(viewModel.dashboard.sleepSummary.totalSleepMinutes % 60)m"
                            : "--")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        if viewModel.dashboard.sleepScore.hasData {
                            Text(L10n.t("Score \(Int(viewModel.dashboard.sleepScore.score))", "评分 \(Int(viewModel.dashboard.sleepScore.score))"))
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        } else {
                            Text(L10n.t("No data", "暂无数据"))
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                    }

                    let stageMinutes = viewModel.dashboard.sleepSummary.stageMinutes
                    let awake = stageMinutes[.awake] ?? 0
                    let rem = stageMinutes[.rem] ?? 0
                    let core = stageMinutes[.core] ?? 0
                    let deep = stageMinutes[.deep] ?? 0
                    let total = awake + rem + core + deep

                    if viewModel.dashboard.sleepScore.hasData && total > 0 {
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                if awake > 0 {
                                    VelaTheme.stress.opacity(0.6)
                                        .frame(width: max(0.5, (CGFloat(awake) / CGFloat(total)) * (geo.size.width - 6)))
                                }
                                if rem > 0 {
                                    Color(red: 0.2, green: 0.7, blue: 0.95)
                                        .frame(width: max(0.5, (CGFloat(rem) / CGFloat(total)) * (geo.size.width - 6)))
                                }
                                if core > 0 {
                                    VelaTheme.sleep
                                        .frame(width: max(0.5, (CGFloat(core) / CGFloat(total)) * (geo.size.width - 6)))
                                }
                                if deep > 0 {
                                    Color(red: 0.35, green: 0.15, blue: 0.75)
                                        .frame(width: max(0.5, (CGFloat(deep) / CGFloat(total)) * (geo.size.width - 6)))
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        .frame(height: 6)
                        .padding(.top, 2)
                        
                        Text(AppLanguage.stored.isChinese 
                            ? "深睡 \(deep)m · 快速眼动 \(rem)m" 
                            : "Deep \(deep)m · REM \(rem)m")
                            .font(.system(size: 8))
                            .foregroundStyle(VelaTheme.mutedText)
                    } else {
                        SparklineView(
                            data: viewModel.sleepTrend.map(\.value),
                            tint: VelaTheme.sleep,
                            height: 18
                        )
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .cardSurface()
                .overlay(cardEditOverlay(for: .sleep))
            }.buttonStyle(.scaleOnPress)
        case .strain:
            NavigationLink { StrainMetricDetailView() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.strain)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(VelaTheme.strain.opacity(0.12)))
                        
                        Text(card.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Spacer()
                        
                        if viewModel.dashboard.strain.hasData {
                            Text(localizedTarget(viewModel.dashboard.strain.targetStatus))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(colloquialStrainColor(viewModel.dashboard.strain.score))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(colloquialStrainColor(viewModel.dashboard.strain.score).opacity(0.10))
                                )
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.dashboard.strain.hasData ? "\(Int(viewModel.dashboard.strain.score))" : "--")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        if viewModel.dashboard.strain.hasData {
                            let range = viewModel.dashboard.strain.recommendedRange
                            Text(AppLanguage.stored.isChinese 
                                ? "目标 \(range.lowerBound)-\(range.upperBound)" 
                                : "Target \(range.lowerBound)-\(range.upperBound)")
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        } else {
                            Text(L10n.t("No data", "暂无数据"))
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                    }

                    if viewModel.dashboard.strain.hasData {
                        let score = viewModel.dashboard.strain.score
                        let range = viewModel.dashboard.strain.recommendedRange
                        
                        GeometryReader { geo in
                            let w = geo.size.width
                            let h = geo.size.height
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(VelaTheme.strain.opacity(0.12))
                                    .frame(height: h)

                                let targetMinRatio = CGFloat(range.lowerBound) / 100.0
                                let targetMaxRatio = CGFloat(range.upperBound) / 100.0
                                
                                Capsule()
                                    .fill(VelaTheme.strain.opacity(0.25))
                                    .frame(width: max(4, (targetMaxRatio - targetMinRatio) * w), height: h)
                                    .offset(x: targetMinRatio * w)

                                let currentRatio = CGFloat(score) / 100.0
                                let clampedRatio = min(max(currentRatio, 0.02), 0.98)
                                
                                Circle()
                                    .fill(VelaTheme.strain)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: VelaTheme.strain.opacity(0.6), radius: 3)
                                    .offset(x: clampedRatio * w - 4, y: (h - 8) / 2)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 2)
                        
                        Text(AppLanguage.stored.isChinese
                            ? "当前负荷 / 推荐训练区间"
                            : "Current strain / Target zone")
                            .font(.system(size: 8))
                            .foregroundStyle(VelaTheme.mutedText)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(VelaTheme.strain.opacity(0.12))
                            .frame(height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .cardSurface()
                .overlay(cardEditOverlay(for: .strain))
            }.buttonStyle(.scaleOnPress)
        case .energy:
            NavigationLink { EnergyBankDetailView(dashboard: viewModel.dashboard) } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: batteryIcon(for: viewModel.dashboard.energy.currentEnergy))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.energy)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(VelaTheme.energy.opacity(0.12)))
                        
                        Text(card.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Spacer()
                        
                        if viewModel.dashboard.energy.hasData {
                            Text(colloquialEnergyStatus(viewModel.dashboard.energy.currentEnergy))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(VelaTheme.energy)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(VelaTheme.energy.opacity(0.10))
                                )
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.dashboard.energy.hasData ? "\(Int(viewModel.dashboard.energy.currentEnergy))" : "--")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        if viewModel.dashboard.energy.hasData {
                            Text(AppLanguage.stored.isChinese 
                                ? "晨起 \(Int(viewModel.dashboard.energy.morningEnergy))" 
                                : "Morning \(Int(viewModel.dashboard.energy.morningEnergy))")
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        } else {
                            Text(L10n.t("No data", "暂无数据"))
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                    }

                    if viewModel.dashboard.energy.hasData {
                        let energyVal = viewModel.dashboard.energy.currentEnergy
                        GeometryReader { geo in
                            let w = geo.size.width
                            let h = geo.size.height
                            
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(VelaTheme.energy.opacity(0.12))
                                    .frame(height: h)
                                
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [VelaTheme.energy, VelaTheme.recovery],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(4, CGFloat(energyVal / 100.0) * w), height: h)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 2)
                        
                        Text(localizedEnergy(viewModel.dashboard.energy.status))
                            .font(.system(size: 8))
                            .foregroundStyle(VelaTheme.mutedText)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(VelaTheme.energy.opacity(0.12))
                            .frame(height: 6)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .cardSurface()
                .overlay(cardEditOverlay(for: .energy))
            }.buttonStyle(.scaleOnPress)
        case .recovery:
            NavigationLink { RecoveryMetricDetailView() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VelaTheme.recovery)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(VelaTheme.recovery.opacity(0.12)))
                        
                        Text(card.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        Spacer()
                        
                        if viewModel.dashboard.recovery.hasData {
                            Text(localizedBand(viewModel.dashboard.recovery.band))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(recoveryBandColor(viewModel.dashboard.recovery.score))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(recoveryBandColor(viewModel.dashboard.recovery.score).opacity(0.10))
                                )
                        }
                    }

                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(viewModel.dashboard.recovery.hasData ? "\(Int(viewModel.dashboard.recovery.score))" : "--")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                        
                        if viewModel.dashboard.recovery.hasData, let hrv = viewModel.dashboard.recoveryMetrics.hrvMilliseconds {
                            Text("HRV \(Int(hrv))ms")
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        } else {
                            Text(L10n.t("No data", "暂无数据"))
                                .font(.system(size: 10))
                                .foregroundStyle(VelaTheme.mutedText)
                        }
                    }

                    SparklineView(
                        data: viewModel.recoveryTrend.map(\.value),
                        tint: VelaTheme.recovery,
                        height: 18
                    )
                    .padding(.top, 2)
                    
                    Text(AppLanguage.stored.isChinese
                        ? "过去 14 天恢复趋势"
                        : "Last 14d recovery trend")
                        .font(.system(size: 8))
                        .foregroundStyle(VelaTheme.mutedText)
                }
                .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                .cardSurface()
                .overlay(cardEditOverlay(for: .recovery))
            }.buttonStyle(.scaleOnPress)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func hiddenCardButton(_ card: HomeCard) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { layoutStore.addCard(card) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: card.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(card.tint)
                Text(card.title)
                    .font(.caption2)
                    .foregroundStyle(VelaTheme.secondaryText)
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(VelaTheme.recovery)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(VelaTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(card.tint.opacity(0.2), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func compactCardView(for card: HomeCard) -> some View {
        switch card {
        case .stress:
            NavigationLink {
                StressDetailView(dashboard: viewModel.dashboard)
            } label: {
                HealthMetricCard(
                    title: L10n.t("Stress", "压力"),
                    value: viewModel.dashboard.stress.hasData ? viewModel.dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: viewModel.dashboard.stress.hasData ? L10n.t("\(viewModel.dashboard.stress.band.rawValue) proxy", "\(localizedStressBand(viewModel.dashboard.stress.band)) 代理指标") : L10n.t("No data", "暂无数据"),
                    tint: VelaTheme.stress,
                    systemImage: card.icon,
                    minHeight: 110,
                    style: .compact
                )
            }
            .buttonStyle(.scaleOnPress)
            .overlay(cardEditOverlay(for: card))

        case .healthAge:
            NavigationLink {
                BiologyView()
            } label: {
                HealthMetricCard(
                    title: L10n.t("Biological Age", "生物年龄"),
                    value: viewModel.dashboard.healthAge.hasData ? localizedHealthAge(viewModel.dashboard.healthAge.label) : "--",
                    subtitle: "Beta",
                    tint: VelaTheme.accent,
                    systemImage: card.icon,
                    minHeight: 110,
                    style: .compact
                )
            }
            .buttonStyle(.scaleOnPress)
            .overlay(cardEditOverlay(for: card))

        case .journal:
            NavigationLink { JournalView() } label: {
                HealthMetricCard(
                    title: L10n.t("Journal", "日记"),
                    value: "\(todayJournalCount)",
                    subtitle: L10n.t("Entries today", "今日记录"),
                    tint: VelaTheme.secondaryText,
                    systemImage: card.icon,
                    minHeight: 110,
                    style: .compact
                )
            }
            .buttonStyle(.scaleOnPress)
            .overlay(cardEditOverlay(for: card))

        case .streak:
            HealthMetricCard(
                title: L10n.t("Streak", "连续天数"),
                value: "\(viewModel.streakDays)",
                subtitle: viewModel.streakDays > 0 ? L10n.t("Days tracked", "天记录") : L10n.t("Start today", "从今天开始"),
                tint: VelaTheme.strain,
                systemImage: card.icon,
                minHeight: 110,
                style: .compact
            )
            .overlay(cardEditOverlay(for: card))

        case .weeklyTrends:
            HealthMetricCard(
                title: L10n.t("Trends", "趋势"),
                value: viewModel.weeklySleep != nil ? "\([viewModel.weeklySleep, viewModel.weeklyRecovery, viewModel.weeklyHRV, viewModel.weeklyStrain].compactMap{$0}.count)" : "--",
                subtitle: L10n.t("Weekly comparison", "周对比"),
                tint: VelaTheme.recovery,
                systemImage: card.icon,
                minHeight: 110,
                style: .compact
            )
            .overlay(cardEditOverlay(for: card))

        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func cardEditOverlay(for card: HomeCard) -> some View {
        if layoutStore.isEditing {
            VStack {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Button {
                            layoutStore.moveCardUp(card)
                        } label: {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(layoutStore.canMoveUp(card) ? VelaTheme.primaryText : VelaTheme.mutedText.opacity(0.3))
                                .frame(width: 22, height: 18)
                                .background(Circle().fill(VelaTheme.surface.opacity(0.9)))
                        }
                        .disabled(!layoutStore.canMoveUp(card))

                        Button {
                            layoutStore.moveCardDown(card)
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(layoutStore.canMoveDown(card) ? VelaTheme.primaryText : VelaTheme.mutedText.opacity(0.3))
                                .frame(width: 22, height: 18)
                                .background(Circle().fill(VelaTheme.surface.opacity(0.9)))
                        }
                        .disabled(!layoutStore.canMoveDown(card))

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                layoutStore.hideCard(card)
                            }
                        } label: {
                            Image(systemName: "eye.slash.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VelaTheme.stress)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(VelaTheme.stress.opacity(0.15)))
                        }
                    }
                }
                Spacer()
            }
            .padding(6)
        }
    }

    private var hiddenCardsPanel: some View {
        let hidden = layoutStore.layout.hiddenCards
        return Group {
            if !hidden.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(VelaTheme.mutedText)
                        Text(L10n.t("Hidden Cards", "已隐藏卡片"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.mutedText)
                        Spacer()
                    }

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(Array(hidden), id: \.self) { card in
                            hiddenCardButton(card)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                        .fill(VelaTheme.background.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusCard, style: .continuous)
                                .stroke(VelaTheme.mutedText.opacity(0.15), lineWidth: 0.5)
                        )
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }

    // MARK: - Subviews

    private var motivationalPhrase: String {
        let score = viewModel.dashboard.recovery.score
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        let timeGreeting: String = {
            if hour >= 5 && hour < 11 {
                return AppLanguage.stored.isChinese ? "清晨好！" : "Good morning! "
            } else if hour >= 11 && hour < 14 {
                return AppLanguage.stored.isChinese ? "中午好！" : "Good afternoon! "
            } else if hour >= 14 && hour < 18 {
                return AppLanguage.stored.isChinese ? "下午好！" : "Good afternoon! "
            } else {
                return AppLanguage.stored.isChinese ? "晚安！" : "Good evening! "
            }
        }()

        if score >= 80 {
            let options = AppLanguage.stored.isChinese ? [
                "今天身体电力满格，是个突破自我的绝佳时机！🚀",
                "状态拉满！去尽情释放你的潜能与热情吧！🔥",
                "准备度处于巅峰，今天适合安排高强度挑战！💪"
            ] : [
                "Peak physical readiness! Perfect day to break boundaries! 🚀",
                "Energy fully restored! Unleash your full potential! 🔥",
                "Optimal state today. Perfect time for a high-intensity workout! 💪"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        } else if score >= 50 {
            let options = AppLanguage.stored.isChinese ? [
                "状态很稳，稳扎稳打。今天保持节奏继续加油！✨",
                "能量均衡，听从身体的声音，今天也是美好的一天。🍀",
                "恢复良好，保持规律运作，科学训练。🏃‍♂️"
            ] : [
                "Steady readiness. Keep up the rhythm and have a great day! ✨",
                "Balanced energy. Listen to your body and pace yourself. 🍀",
                "Recovery on track. Maintain consistency in your routine. 🏃‍♂️"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        } else {
            let options = AppLanguage.stored.isChinese ? [
                "电量稍微有些低，今天记得对自己温柔一点，多休息。☕️",
                "身体在发出放松信号。适合做些轻量拉伸，早点充电。🛌",
                "蓄力恢复中... 适当的停歇也是为了更好的出发。🍃"
            ] : [
                "Energy is a bit low today. Be gentle with yourself and rest. ☕️",
                "Your body is asking to slow down. Great day for light stretching. 🛌",
                "Recharging... Remember, smart rest is a vital part of progress. 🍃"
            ]
            let index = Int(score) % options.count
            return timeGreeting + options[index]
        }
    }

    private func parseOneSentence(from markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        
        var sentenceHeaderIndex: Int?
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("今日状态一句话") || trimmed.contains("Today in One Sentence") || trimmed.contains("🌅") {
                sentenceHeaderIndex = index
                break
            }
        }
        
        guard let headerIndex = sentenceHeaderIndex else {
            return ""
        }
        
        for i in (headerIndex + 1)..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("#") {
                break
            }
            if line.hasPrefix("(") && line.hasSuffix(")") {
                continue
            }
            let cleaned = line
                .replacingOccurrences(of: "**", with: "")
                .replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        
        return ""
    }


    private var headerBar: some View {
        let trust = HomeDataTrust.make(
            dashboard: viewModel.dashboard,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage
        )

        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formattedHomeDate)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(VelaBevelHomeStyle.secondaryInk)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: trust.systemImage)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(trust.tint)
                    Text(trust.title)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaBevelHomeStyle.ink)
                    Text(trust.detail)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaBevelHomeStyle.tertiaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }

            Spacer()

            Button {
                VelaAppState.shared.routeToCoach(question: L10n.t(
                    "Create a concise shareable summary of my current recovery, sleep, strain, stress, energy, and today's action.",
                    "请基于我当前的恢复、睡眠、负荷、压力、能量和今日行动，生成一段适合分享的简洁总结。"
                ))
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VelaBevelHomeStyle.secondaryInk)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(VelaBevelHomeStyle.elevatedSurface))
                    .overlay(Circle().stroke(Color.black.opacity(0.045), lineWidth: 0.6))
            }
            .buttonStyle(.plain)

            Menu {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label(L10n.t("Settings", "设置"), systemImage: "gearshape.fill")
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        layoutStore.isEditing.toggle()
                    }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Label(
                        layoutStore.isEditing ? L10n.t("Done Customizing", "完成自定义") : L10n.t("Customize Home", "自定义首页"),
                        systemImage: "slider.horizontal.3"
                    )
                }
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(VelaBevelHomeStyle.ink, VelaBevelHomeStyle.elevatedSurface)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.top, 4)
    }

    private var readinessCockpit: some View {
        NavigationLink { RecoveryMetricDetailView() } label: {
            HStack(spacing: 16) {
                ScoreRingView(score: viewModel.dashboard.recovery.score, tint: VelaTheme.recovery, size: 100, lineWidth: 9)

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("Readiness", "准备度"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                        .textCase(.uppercase)
                        .tracking(1)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(viewModel.dashboard.recovery.hasData
                            ? "\(Int(viewModel.dashboard.recovery.score))"
                            : "--")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.dashboard.recovery.hasData
                                ? recoveryBandColor(viewModel.dashboard.recovery.score)
                                : VelaTheme.mutedText)
                        
                        Text(viewModel.dashboard.recovery.hasData
                            ? localizedBand(viewModel.dashboard.recovery.band)
                            : "--")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(viewModel.dashboard.recovery.hasData
                                ? recoveryBandColor(viewModel.dashboard.recovery.score)
                                : VelaTheme.mutedText)
                    }

                    Text(viewModel.dashboard.recovery.hasData
                        ? localizedReason(viewModel.dashboard.recovery.reasons.first ?? "")
                        : L10n.t("Connect Apple Health", "请连接 Apple 健康"))
                        .font(.system(size: 10))
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(2)

                    if viewModel.dashboard.recovery.hasData {
                        Divider().background(Color.black.opacity(0.12))
                            .padding(.vertical, 2)
                        
                        VStack(spacing: 8) {
                            HorizontalRangeBar(
                                label: "HRV",
                                todayValue: viewModel.dashboard.recoveryMetrics.hrvMilliseconds,
                                baselineValue: viewModel.dashboard.recoveryBaseline.hrvMilliseconds,
                                isLowerBetter: false,
                                unit: "ms"
                            )
                            
                            HorizontalRangeBar(
                                label: L10n.t("Resting HR", "静息心率"),
                                todayValue: viewModel.dashboard.recoveryMetrics.restingHeartRate,
                                baselineValue: viewModel.dashboard.recoveryBaseline.restingHeartRate,
                                isLowerBetter: true,
                                unit: "bpm"
                            )
                        }
                    } else {
                        HStack(spacing: 12) {
                            compactMiniMetric(
                                label: L10n.t("Sleep", "睡眠"),
                                value: viewModel.dashboard.sleepScore.hasData ? "\(Int(viewModel.dashboard.sleepScore.score))" : "--",
                                tint: VelaTheme.sleep
                            )
                            compactMiniMetric(
                                label: L10n.t("Strain", "负荷"),
                                value: viewModel.dashboard.strain.hasData ? "\(Int(viewModel.dashboard.strain.score))" : "--",
                                tint: VelaTheme.strain
                            )
                            compactMiniMetric(
                                label: L10n.t("Stress", "压力"),
                                value: viewModel.dashboard.stress.hasData ? "\(Int(viewModel.dashboard.stress.stressIndex))" : "--",
                                tint: VelaTheme.stress
                            )
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface(accent: VelaTheme.recovery)
        }
        .buttonStyle(.scaleOnPress)
    }

    private var dailyPlanCard: some View {
        let plan = dailyPlan
        let accent = dailyPlanAccentColor(plan.accent)

        return Button {
            VelaAppState.shared.routeToCoach(question: plan.coachQuestion)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: dailyPlanIcon(plan.kind))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(accent.opacity(0.14)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.t("Today's Plan", "今日计划"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VelaTheme.mutedText)
                            .textCase(.uppercase)
                            .tracking(1)

                        Text(plan.title)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(VelaTheme.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title3)
                        .foregroundStyle(accent.opacity(0.9))
                }

                Text(dailyPlanDisplayBody(plan))
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.secondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let limiter = plan.limiter {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(limiter.title)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(VelaTheme.primaryText)
                            Text(limiter.detail)
                                .font(.caption2)
                                .foregroundStyle(VelaTheme.mutedText)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                            .fill(accent.opacity(0.10))
                    )
                }

                HStack(spacing: 10) {
                    Label(plan.primaryActionTitle, systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Spacer(minLength: 8)

                    if let secondaryActionTitle = plan.secondaryActionTitle {
                        Text(secondaryActionTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VelaTheme.mutedText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface(accent: accent)
        }
        .buttonStyle(.scaleOnPress)
    }

    private var readinessBriefCard: some View {
        let brief = HomeReadinessBrief.make(dashboard: viewModel.dashboard, plan: dailyPlan)
        let accent = dailyPlanAccentColor(brief.accent)

        return Button {
            VelaAppState.shared.routeToCoach(question: brief.coachQuestion)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.clipboard.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(accent)
                    Text(localizedReadinessStatus(brief.statusLabel))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.mutedText)
                }

                VStack(alignment: .leading, spacing: 8) {
                    explanationRow(
                        label: L10n.t("Why", "原因"),
                        text: localizedReason(brief.why),
                        accent: accent
                    )
                    explanationRow(
                        label: L10n.t("Next", "下一步"),
                        text: brief.nextAction,
                        accent: accent
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.scaleOnPress)
    }

    private func explanationRow(label: String, text: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 44, alignment: .leading)
            Text(text)
                .font(.caption)
                .foregroundStyle(VelaTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func localizedReadinessStatus(_ status: String) -> String {
        guard AppLanguage.stored.isChinese else { return status }
        switch status {
        case "Building baseline": return "正在建立基线"
        case "Low readiness": return "准备度偏低"
        case "Controlled day": return "控制负荷日"
        case "Ready": return "状态可用"
        case "High readiness": return "准备度较高"
        default: return status
        }
    }

    private func dailyPlanAccentColor(_ accent: DailyPlanAccent) -> Color {
        switch accent {
        case .recovery: return VelaTheme.recovery
        case .sleep: return VelaTheme.sleep
        case .strain: return VelaTheme.strain
        case .energy: return VelaTheme.energy
        case .stress: return VelaTheme.stress
        }
    }

    private func dailyPlanDisplayBody(_ plan: DailyPlanRecommendation) -> String {
        let separators = [" Main limiter:", " 主要限制因素："]
        for separator in separators {
            if let range = plan.body.range(of: separator) {
                return String(plan.body[..<range.lowerBound])
            }
        }
        return plan.body
    }

    private func dailyPlanIcon(_ kind: DailyPlanKind) -> String {
        switch kind {
        case .recovery: return "heart.fill"
        case .train: return "figure.run"
        case .protectSleep: return "moon.zzz.fill"
        case .downshift: return "arrow.down.heart.fill"
        case .maintain: return "target"
        }
    }

    private func compactMiniMetric(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(VelaTheme.primaryText)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(VelaTheme.mutedText)
        }
        .frame(minWidth: 36)
    }

    // MARK: - Score Cards

    private func batteryIcon(for energy: Double) -> String {
        switch energy {
        case ..<25: return "battery.25percent"
        case ..<50: return "battery.50percent"
        case ..<75: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.strain)
                Text(L10n.t("Streak", "连续天数"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
            }
            Text("\(viewModel.streakDays)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t("days of data", "天数据"))
                .font(.caption2)
                .foregroundStyle(VelaTheme.mutedText)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .cardSurface()
        .overlay(cardEditOverlay(for: .streak))
    }

    private func weeklyDeltaCard(_ wc: WeeklyComparison, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: wc.isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(wc.isPositive ? VelaTheme.recovery : VelaTheme.stress)
                Text(L10n.t("Weekly", "本周"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                    .textCase(.uppercase)
            }
            Text(String(format: "%.0f", wc.thisWeekAvg))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(VelaTheme.primaryText)
            Text(L10n.t(
                "\(wc.isPositive ? "+" : "")\(String(format: "%.0f", wc.delta)) vs last week",
                "较上周\(wc.isPositive ? "+" : "")\(String(format: "%.0f", wc.delta))"
            ))
            .font(.caption2)
            .foregroundStyle(wc.isPositive ? VelaTheme.recovery : VelaTheme.stress)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        .cardSurface()
    }

    private var weeklySnapshotCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(VelaTheme.accent)
                Text(L10n.t("Weekly Trends", "本周趋势"))
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text(L10n.t("This wk -> Last wk", "本周 -> 上周"))
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)
            }

            Divider().background(VelaTheme.mutedText.opacity(0.15))

            if let ws = viewModel.weeklySleep {
                weeklyTrendRow(
                    icon: "moon.fill",
                    label: L10n.t("Sleep", "睡眠"),
                    tint: VelaTheme.sleep,
                    comparison: ws,
                    format: { String(format: "%.0f", $0) }
                )
            }
            if let wr = viewModel.weeklyRecovery {
                weeklyTrendRow(
                    icon: "heart.fill",
                    label: L10n.t("Recovery", "恢复"),
                    tint: VelaTheme.recovery,
                    comparison: wr,
                    format: { String(format: "%.0f", $0) }
                )
            }
            if let wh = viewModel.weeklyHRV {
                weeklyTrendRow(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    tint: VelaTheme.accent,
                    comparison: wh,
                    format: { String(format: "%.0f ms", $0) }
                )
            }
            if let wst = viewModel.weeklyStrain {
                weeklyTrendRow(
                    icon: "flame.fill",
                    label: L10n.t("Strain", "负荷"),
                    tint: VelaTheme.strain,
                    comparison: wst,
                    format: { String(format: "%.0f", $0) }
                )
            }
        }
        .cardSurface()
        .overlay(cardEditOverlay(for: .weeklyTrends))
    }

    private func weeklyTrendRow(
        icon: String, label: String, tint: Color,
        comparison: WeeklyComparison, format: (Double) -> String
    ) -> some View {
        let pctDelta: Double = comparison.lastWeekAvg > 0
            ? ((comparison.thisWeekAvg - comparison.lastWeekAvg) / comparison.lastWeekAvg) * 100 : 0
        let isUp = pctDelta >= 0

        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.12)))

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(VelaTheme.primaryText)
                .frame(width: 60, alignment: .leading)

            Spacer()

            HStack(spacing: 4) {
                Text(format(comparison.thisWeekAvg))
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(VelaTheme.mutedText)
                Text(format(comparison.lastWeekAvg))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(VelaTheme.secondaryText)
            }

            HStack(spacing: 2) {
                Image(systemName: isUp ? "arrow.up" : "arrow.down")
                    .font(.system(size: 9, weight: .bold))
                Text(String(format: "%+.0f%%", pctDelta))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isUp ? VelaTheme.recovery : VelaTheme.stress)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isUp ? VelaTheme.recovery.opacity(0.12) : VelaTheme.stress.opacity(0.12))
            )
            .frame(width: 56, alignment: .trailing)
        }
    }

    private var upgradedInsightCard: some View {
        Button {
            VelaAppState.shared.routeToCoach(question: L10n.t(
                "Analyze my latest health data and daily insight. Use recovery, sleep, strain, stress, energy, vitals, journal, and Wiki context. Give conclusion, evidence, and one next action.",
                "请分析我的最新健康数据和今日洞察。使用恢复、睡眠、负荷、压力、能量、生命体征、手记和 Wiki 上下文。给出结论、依据和一个下一步行动。"
            ))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [VelaTheme.accent, VelaTheme.sleep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VelaTheme.accent.opacity(0.2), VelaTheme.sleep.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("AI Daily Insight", "AI 今日洞察"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VelaTheme.primaryText)
                    Text(viewModel.dashboard.dailyInsight)
                        .font(.caption)
                        .foregroundStyle(VelaTheme.secondaryText)
                        .lineLimit(3)
                }

                Spacer()

                VStack {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VelaTheme.accent)
                    Text(L10n.t("Ask Coach", "问教练"))
                        .font(.system(size: 9))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }
            .cardSurface()
        }
        .buttonStyle(.scaleOnPress)
    }

    private var recoveryHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.caption)
                        .foregroundStyle(VelaTheme.recovery)
                    Text(L10n.t("Readiness Calendar", "准备度日历"))
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                Spacer()
                Text(viewModel.selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(VelaTheme.recovery)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(VelaTheme.recovery.opacity(0.12)))
            }

            HStack(spacing: 5) {
                ForEach(viewModel.heatmapPoints) { point in
                    let isSelected = Calendar.current.isDate(point.date, inSameDayAs: viewModel.selectedDate)
                    let baseColor = VelaTheme.recovery
                    let opacity: Double = {
                        guard let score = point.score, score > 0 else { return 0.05 }
                        return 0.15 + (score / 100.0) * 0.85
                    }()

                    Button {
                        viewModel.selectedDate = point.date
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        Task { await viewModel.refresh(modelContext: modelContext) }
                    } label: {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(baseColor.opacity(opacity))
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 1.5 : 0.5)
                            )
                            .shadow(color: isSelected ? VelaTheme.recovery.opacity(0.4) : Color.clear, radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text(L10n.t("14d ago", "14天前"))
                Spacer()
                Text(L10n.t("Today", "今天"))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(VelaTheme.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private var healthConnectCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(VelaTheme.recovery)
                .frame(width: 36, height: 36)
                .background(Circle().fill(VelaTheme.recovery.opacity(0.15)))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t("Apple Health", "Apple 健康"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VelaTheme.primaryText)
                Text(authorizationViewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.mutedText)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task {
                    await authorizationViewModel.requestAuthorization()
                    await viewModel.refresh(modelContext: modelContext)
                }
            } label: {
                Label(L10n.t("Connect", "连接"), systemImage: "checkmark.shield.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .tint(VelaTheme.recovery)
        }
        .cardSurface()
    }

    private func recoveryBandColor(_ score: Double) -> Color {
        switch score {
        case ..<40: return VelaTheme.stress
        case ..<70: return VelaTheme.energy
        default: return VelaTheme.recovery
        }
    }
}

// MARK: - StressDetailView with Formula Card

private struct StressDetailView: View {
    let dashboard: DashboardSummary
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Stress", "压力"),
            subtitle: L10n.t("Physiological proxy", "生理代理指标"),
            hero: {
                HealthMetricCard(
                    title: L10n.t("Stress Index", "压力指数"),
                    value: dashboard.stress.hasData ? dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))) : "--",
                    subtitle: dashboard.stress.hasData ? L10n.t("\(dashboard.stress.band.rawValue). \(dashboard.stress.confidence.rawValue) confidence.", "\(localizedStressBand(dashboard.stress.band))。\(localizedConfidence(dashboard.stress.confidence))置信度。") : L10n.t("No stress data available yet.", "暂无压力数据。"),
                    tint: VelaTheme.stress,
                    systemImage: "waveform.path.ecg"
                )
            },
            content: {
                MetricRow(items: dashboard.stress.components.sorted(by: { $0.key < $1.key }).map {
                    .init(title: localizedMetricName($0.key), value: $0.value.formatted(.number.precision(.fractionLength(0))))
                })

                VStack(alignment: .leading, spacing: 12) {
                    Label(L10n.t("30-Day Stress Trend", "30 天压力趋势"), systemImage: "chart.xyaxis.line")
                        .font(.headline)
                        .foregroundStyle(VelaTheme.primaryText)

                    if viewModel.stressTrend.isEmpty {
                        Text(L10n.t("Trend data will appear after more days of use.", "使用更多天后趋势数据会出现。"))
                            .font(.subheadline)
                            .foregroundStyle(VelaTheme.secondaryText)
                    } else {
                        Chart(viewModel.stressTrend) { item in
                            AreaMark(x: .value("Day", item.date), y: .value("Index", item.value))
                                .foregroundStyle(LinearGradient(
                                    colors: [VelaTheme.stress.opacity(0.2), VelaTheme.stress.opacity(0.02)],
                                    startPoint: .top, endPoint: .bottom))
                            LineMark(x: .value("Day", item.date), y: .value("Index", item.value))
                                .foregroundStyle(VelaTheme.stress).lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(x: .value("Day", item.date), y: .value("Index", item.value))
                                .foregroundStyle(VelaTheme.stress).symbolSize(20)
                        }
                        .chartYScale(domain: 0...100).chartXAxis(.hidden).frame(height: 160)
                    }
                }
                .cardSurface()

                PlaceholderInsightCard(
                    title: L10n.t("Stress Formula", "压力公式"),
                    bodyText: L10n.t(
                        "0.40 x RHR(elev) + 0.35 x HRV(supp) + 0.15 x SleepDebt + 0.10 x RecentStrain",
                        "0.40 x 静态心率(升高) + 0.35 x HRV(抑制) + 0.15 x 睡眠债务 + 0.10 x 近期负荷"
                    )
                )

                PlaceholderInsightCard(
                    title: L10n.t("AI Explanation", "AI 解释"),
                    bodyText: dashboard.stress.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Stress", "压力"),
                        systemContext: L10n.t(
                            "Analyze Stress Index as a physiological proxy using HR, HRV, sleep debt, and recent strain. Avoid diagnosis.",
                            "将压力指数作为生理代理指标分析，结合心率、HRV、睡眠债和近期负荷，避免诊断。"
                        )
                    )
                )
            }
        )
        .task { await viewModel.loadStressTrend(modelContext: modelContext) }
    }
}

// MARK: - EnergyBankDetailView with Formula Cards

private struct EnergyBankDetailView: View {
    let dashboard: DashboardSummary
    var body: some View { DetailedEnergyBankView(dashboard: dashboard) }
}

private struct DetailedEnergyBankView: View {
    let dashboard: DashboardSummary

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Energy Bank", "能量银行"),
            subtitle: L10n.t("Today", "今日"),
            hero: {
                cockpitCard
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Morning", "早晨"), value: dashboard.energy.hasData ? dashboard.energy.morningEnergy.formatted(.number.precision(.fractionLength(0))) : "--"),
                    .init(title: L10n.t("Current", "当前"), value: dashboard.energy.hasData ? dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))) : "--"),
                    .init(title: L10n.t("Confidence", "置信度"), value: localizedConfidence(dashboard.energy.confidence))
                ])

                if dashboard.energy.hasData {
                    let metrics = dashboard.energy.metrics
                    let tsb = metrics["tsb"] ?? 0.0
                    TSBRangeGauge(tsb: tsb)
                }

                // Upgraded Morning Charge Model Card
                if dashboard.energy.hasData {
                    let metrics = dashboard.energy.metrics
                    let efficiency = metrics["charge_efficiency"] ?? 0.0
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "sun.max.fill")
                                .foregroundStyle(VelaTheme.recovery)
                                .font(.system(size: 14, weight: .bold))
                            
                            Text(L10n.t("Morning Charge Model", "早晨充电模型"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VelaTheme.primaryText)
                        }
                        
                        // Formula Graphic Block
                        VStack(alignment: .center, spacing: 4) {
                            Text("Morning Base Charge =")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(VelaTheme.mutedText)
                            
                            Text("0.55 × Recovery + 0.30 × Sleep + 0.15 × HRV Charge")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(VelaTheme.energy)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.04)))
                        }
                        .frame(maxWidth: .infinity)
                        
                        Divider().background(Color.black.opacity(0.08))
                        
                        // Weighted inputs visualization
                        VStack(spacing: 8) {
                            formulaInputRow(
                                title: L10n.t("Recovery Contribution (55%)", "恢复贡献 (55%)"),
                                value: "\(Int(dashboard.recovery.score))",
                                score: dashboard.recovery.score,
                                maxVal: 100.0,
                                tint: VelaTheme.recovery
                            )
                            
                            formulaInputRow(
                                title: L10n.t("Sleep Contribution (30%)", "睡眠贡献 (30%)"),
                                value: "\(Int(dashboard.sleepScore.score))",
                                score: dashboard.sleepScore.score,
                                maxVal: 100.0,
                                tint: VelaTheme.sleep
                            )
                            
                            formulaInputRow(
                                title: L10n.t("HRV Charge Efficiency (15%)", "HRV 充电效率 (15%)"),
                                value: "\(Int(efficiency * 100))%",
                                score: efficiency * 100.0,
                                maxVal: 100.0,
                                tint: VelaTheme.energy
                            )
                        }
                    }
                    .padding(16)
                    .cardSurface()
                }

                // Upgraded Energy Drain Model Card
                if dashboard.energy.hasData {
                    let metrics = dashboard.energy.metrics
                    let strainDrain = metrics["strain_drain"] ?? 0.0
                    let stressDrain = metrics["stress_drain"] ?? 0.0
                    let sleepDebtDrain = metrics["sleep_debt_drain"] ?? 0.0
                    let allostaticDrain = metrics["allostatic_drain"] ?? 0.0
                    let totalDrain = strainDrain + stressDrain + sleepDebtDrain + allostaticDrain
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bolt.slash.fill")
                                .foregroundStyle(VelaTheme.stress)
                                .font(.system(size: 14, weight: .bold))
                            
                            Text(L10n.t("Energy Discharge Model", "能量消耗模型"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(VelaTheme.primaryText)
                        }
                        
                        // Total Drain bar relative to morning energy
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L10n.t("Total Daily Drains", "今日累计扣除量"))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(VelaTheme.secondaryText)
                                Spacer()
                                Text("-\(Int(totalDrain))%")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(VelaTheme.stress)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.black.opacity(0.05))
                                        .frame(height: 6)
                                    
                                    let morning = dashboard.energy.morningEnergy > 0 ? dashboard.energy.morningEnergy : 100.0
                                    let ratio = CGFloat(min(max(totalDrain / morning, 0.0), 1.0))
                                    Capsule()
                                        .fill(VelaTheme.stress)
                                        .frame(width: geo.size.width * ratio, height: 6)
                                        .shadow(color: VelaTheme.stress.opacity(0.4), radius: 2)
                                }
                            }
                            .frame(height: 6)
                        }
                        
                        Divider().background(Color.black.opacity(0.08))
                        
                        // Grid of detailed drains
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            drainCardMini(
                                title: L10n.t("Strain Drain", "负荷扣减"),
                                value: "-\(Int(strainDrain))%",
                                desc: L10n.t("Active TRIMP energy load", "活动 TRIMP 能量消耗"),
                                tint: VelaTheme.strain
                            )
                            
                            drainCardMini(
                                title: L10n.t("Stress Drain", "压力扣减"),
                                value: "-\(Int(stressDrain))%",
                                desc: L10n.t("Elevated heart rate & tension", "心率升高及日常焦虑"),
                                tint: VelaTheme.accent
                            )
                            
                            drainCardMini(
                                title: L10n.t("Sleep Debt Penalty", "睡眠债扣减"),
                                value: "-\(Int(sleepDebtDrain))%",
                                desc: L10n.t("Sleep hours deficit penalty", "睡眠不足的额外压力扣除"),
                                tint: VelaTheme.sleep
                            )
                            
                            drainCardMini(
                                title: L10n.t("Systemic/Temp Load", "生理热量/系统负荷"),
                                value: "-\(Int(allostaticDrain))%",
                                desc: L10n.t("Body temp deviation penalty", "体温偏离基线的代谢损耗"),
                                tint: VelaTheme.energy
                            )
                        }
                    }
                    .padding(16)
                    .cardSurface()
                }

                if dashboard.energy.hasData, !dashboard.energy.components.isEmpty {
                    PlaceholderInsightCard(
                        title: L10n.t("Components", "组成"),
                        bodyText: dashboard.energy.components.sorted(by: { $0.value > $1.value }).map { "\($0.key): \(Int($0.value))" }.joined(separator: " · ")
                    )
                }

                PlaceholderInsightCard(
                    title: L10n.t("Status", "状态"),
                    bodyText: dashboard.energy.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Energy Bank", "能量银行"),
                        systemContext: L10n.t(
                            "Analyze morning energy, current energy, recovery, sleep, strain drains, stress proxy drain, and practical pacing.",
                            "分析早晨能量、当前能量、恢复、睡眠、负荷消耗、压力代理消耗和今日节奏建议。"
                        )
                    )
                )
            }
        )
    }

    private var cockpitCard: some View {
        HStack(spacing: 20) {
            // Left side: Large glowing battery circular meter
            ZStack {
                Circle()
                    .stroke(Color.black.opacity(0.04), lineWidth: 10)
                    .frame(width: 100, height: 100)
                
                let score = dashboard.energy.hasData ? dashboard.energy.currentEnergy : 0.0
                Circle()
                    .trim(from: 0.0, to: CGFloat(score / 100.0))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [VelaTheme.energy.opacity(0.8), VelaTheme.energy, VelaTheme.energy.opacity(0.8)]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: VelaTheme.energy.opacity(0.3), radius: 6)
                
                VStack(spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text("\(Int(score))")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.primaryText)
                        Text("%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                    
                    Image(systemName: "battery.100.bolt")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VelaTheme.energy)
                }
            }
            .frame(width: 100, height: 100)

            // Right side: Morning Charge, Strain Drain, Stress/Allostatic Drain
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.t("DAILY ENERGY BALANCE", "今日能量平衡"))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VelaTheme.mutedText)
                
                let morning = dashboard.energy.hasData ? dashboard.energy.morningEnergy : 0.0
                flowItemRow(
                    label: L10n.t("Morning Charge", "早晨充电"),
                    value: "+\(Int(morning))%",
                    color: VelaTheme.recovery,
                    icon: "plus.circle.fill"
                )
                
                let strain = dashboard.energy.hasData ? (dashboard.energy.metrics["strain_drain"] ?? 0.0) : 0.0
                flowItemRow(
                    label: L10n.t("Strain Drain", "负荷消耗"),
                    value: "-\(Int(strain))%",
                    color: VelaTheme.strain,
                    icon: "minus.circle.fill"
                )
                
                let stress = dashboard.energy.hasData ? (dashboard.energy.metrics["stress_drain"] ?? 0.0) : 0.0
                let allo = dashboard.energy.hasData ? (dashboard.energy.metrics["allostatic_drain"] ?? 0.0) : 0.0
                let sleepDebt = dashboard.energy.hasData ? (dashboard.energy.metrics["sleep_debt_drain"] ?? 0.0) : 0.0
                let otherDrain = stress + allo + sleepDebt
                flowItemRow(
                    label: L10n.t("Stress & Load Drain", "压力与适应消耗"),
                    value: "-\(Int(otherDrain))%",
                    color: VelaTheme.accent,
                    icon: "minus.circle.fill"
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .heroCardSurface(accent: VelaTheme.energy)
    }

    private func flowItemRow(label: String, value: String, color: Color, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.secondaryText)
                
            Spacer()
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(color.opacity(0.12)))
        }
    }

    private func formulaInputRow(title: String, value: String, score: Double, maxVal: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(VelaTheme.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 3)
                    
                    Capsule()
                        .fill(tint)
                        .frame(width: geo.size.width * CGFloat(min(max(score / maxVal, 0.0), 1.0)), height: 3)
                        .shadow(color: tint.opacity(0.3), radius: 1)
                }
            }
            .frame(height: 3)
        }
    }

    private func drainCardMini(title: String, value: String, desc: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(tint)
                    .frame(width: 4, height: 4)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.secondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            Text(desc)
                .font(.system(size: 8))
                .foregroundStyle(VelaTheme.mutedText)
                .lineLimit(2)
                .frame(height: 20, alignment: .topLeading)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.04), lineWidth: 0.5))
    }
}

private struct TSBRangeGauge: View {
    let tsb: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(L10n.t("Training Stress Balance (TSB)", "训练负荷平衡 (TSB)"), systemImage: "scale.3d")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(VelaTheme.primaryText)
                Spacer()
                Text("\(tsb > 0 ? "+" : "")\(Int(tsb))")
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(tsbZoneColor(tsb))
            }
            
            // The Slider/Gauge itself
            GeometryReader { geo in
                let width = geo.size.width
                
                // Normalizing today's value from [-30, 30] to [0, 1]
                let clampedTSB = min(max(tsb, -30), 30)
                let pct = (clampedTSB - (-30)) / 60.0
                let thumbOffset = pct * width
                
                ZStack(alignment: .leading) {
                    // Colored track representing zones:
                    // High Fatigue (< -15) : red/orange
                    // Balanced (-15 to 10) : yellow/white/gray
                    // Fresh (> 10)         : green/cyan
                    HStack(spacing: 0) {
                        // High Fatigue (-30 to -15, width: 25% of total)
                        Capsule()
                            .fill(VelaTheme.stress)
                            .frame(width: width * 0.25, height: 6)
                        
                        // Balanced (-15 to +10, width: 41.67% of total)
                        Rectangle()
                            .fill(VelaTheme.energy)
                            .frame(width: width * 0.4167, height: 6)
                        
                        // Fresh (+10 to +30, width: 33.33% of total)
                        Capsule()
                            .fill(VelaTheme.recovery)
                            .frame(width: width * 0.3333, height: 6)
                    }
                    .clipShape(Capsule())
                    .opacity(0.3)
                    
                    // Ticks at -15, 0, +10
                    Group {
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 1.5, height: 10)
                            .offset(x: width * 0.25) // -15
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 1.5, height: 12)
                            .offset(x: width * 0.5)  // 0
                        
                        Rectangle()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 1.5, height: 10)
                            .offset(x: width * 0.6667) // +10
                    }
                    
                    // Glowing active thumb indicator
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(tsbZoneColor(tsb), lineWidth: 3)
                        )
                        .shadow(color: tsbZoneColor(tsb).opacity(0.6), radius: 4)
                        .offset(x: max(0, min(width - 14, thumbOffset - 7)), y: -4)
                }
            }
            .frame(height: 12)
            .padding(.vertical, 4)
            
            // Labels below the gauge
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("-30")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(L10n.t("High Fatigue", "高疲劳"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VelaTheme.stress)
                }
                
                Spacer()
                
                VStack(alignment: .center, spacing: 2) {
                    Text("0")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(L10n.t("Optimal Balanced", "状态平衡"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VelaTheme.energy)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("+30")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                    Text(L10n.t("Fresh & Ready", "精力充沛"))
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(VelaTheme.recovery)
                }
            }
            
            Divider().background(Color.black.opacity(0.08))
            
            // Current TSB Status Text Description
            let statusText = tsbDescription(tsb)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VelaTheme.secondaryText)
                .lineSpacing(4)
        }
        .padding(16)
        .cardSurface()
    }
    
    private func tsbZoneColor(_ val: Double) -> Color {
        if val < -15 {
            return VelaTheme.stress
        } else if val > 10 {
            return VelaTheme.recovery
        } else {
            return VelaTheme.energy
        }
    }
    
    private func tsbDescription(_ val: Double) -> String {
        if val < -15 {
            return L10n.t(
                "Your acute training load (7-day) is significantly higher than your chronic load (42-day). Fatigue is high, and performance might be temporarily impaired. Consider an active recovery day.",
                "你的短期训练负荷（7天）显著高于长期训练负荷（42天）。身体积累了较高疲劳，运动表现可能受到抑制。建议安排主动恢复日。"
            )
        } else if val > 10 {
            return L10n.t(
                "Your training stress balance is highly positive. Your body is primed, fresh, and ready for high-intensity efforts. Great day for a peak performance workout!",
                "你的训练压力平衡处于高度正值。身体处于充沛活跃的就绪状态，疲劳基本清除，非常适合进行高强度的突破性训练！"
            )
        } else {
            return L10n.t(
                "Your training load is perfectly balanced. You are maintaining your fitness base without excessive systemic fatigue. Good state for sustained consistent training.",
                "你的训练负荷处于理想的平衡区间。在维持体能基底的同时没有积累过载的系统性疲劳，非常利于进行持续、稳定的日常训练。"
            )
        }
    }
}

// MARK: - HealthAgeDetailView with Biomarkers

private struct HealthAgeDetailView: View {
    let dashboard: DashboardSummary
    var body: some View { DetailedHealthAgeView(dashboard: dashboard) }
}

private struct DetailedHealthAgeView: View {
    let dashboard: DashboardSummary

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Biological Age", "生物年龄"),
            subtitle: "Beta",
            hero: {
                HealthMetricCard(
                    title: L10n.t("Trend", "趋势"),
                    value: dashboard.healthAge.hasData ? localizedHealthAge(dashboard.healthAge.label) : "--",
                    subtitle: dashboard.healthAge.hasData ? L10n.t("Beta trend score \(dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2)))).", "Beta 趋势分 \(dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2))))。") : L10n.t("Not enough data for health age trend.", "数据不足，无法计算健康年龄趋势。"),
                    tint: VelaTheme.accent,
                    systemImage: "arrow.up.forward.heart.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Positive", "正向"), value: "\(dashboard.healthAge.positiveFactors.count)"),
                    .init(title: L10n.t("Negative", "负向"), value: "\(dashboard.healthAge.negativeFactors.count)"),
                    .init(title: L10n.t("Confidence", "置信度"), value: localizedConfidence(dashboard.healthAge.confidence))
                ])

                if dashboard.healthAge.hasData, !dashboard.healthAge.positiveFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("Positive Biomarkers", "正向指标"), systemImage: "arrow.up.heart.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(VelaTheme.recovery)
                        ForEach(dashboard.healthAge.positiveFactors, id: \.self) { factor in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.up.circle.fill").font(.caption).foregroundStyle(VelaTheme.recovery)
                                Text(localizedMetricName(factor)).font(.caption).foregroundStyle(VelaTheme.primaryText)
                                Spacer()
                            }
                        }
                    }
                    .cardSurface()
                }

                if dashboard.healthAge.hasData, !dashboard.healthAge.negativeFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(L10n.t("Negative Biomarkers", "负向指标"), systemImage: "arrow.down.heart.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(VelaTheme.stress)
                        ForEach(dashboard.healthAge.negativeFactors, id: \.self) { factor in
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down.circle.fill").font(.caption).foregroundStyle(VelaTheme.stress)
                                Text(localizedMetricName(factor)).font(.caption).foregroundStyle(VelaTheme.primaryText)
                                Spacer()
                            }
                        }
                    }
                    .cardSurface()
                }

                if dashboard.healthAge.hasData {
                    NavigationLink {
                        BiologyView()
                    } label: {
                        Label(L10n.t("View Biological Age & Biomarkers", "查看生物年龄与血检指标"), systemImage: "drop.fill")
                            .font(.subheadline.weight(.medium)).foregroundStyle(VelaTheme.accent)
                            .frame(maxWidth: .infinity).padding(12)
                            .background(RoundedRectangle(cornerRadius: VelaTheme.cornerRadiusTile, style: .continuous)
                                .fill(VelaTheme.accent.opacity(0.12)))
                    }
                    .buttonStyle(.scaleOnPress)
                }

                PlaceholderInsightCard(
                    title: L10n.t("Beta Notice", "Beta 说明"),
                    bodyText: dashboard.healthAge.reasons.map(localizedReason).joined(separator: " ")
                )

                MetricCoachCard(
                    dashboard: dashboard,
                    focus: CoachContextFocus(
                        title: L10n.t("Biological Age", "生物年龄"),
                        systemContext: L10n.t(
                            "Analyze Health Age Trend beta label, positive and negative drivers. Do not claim biological age.",
                            "分析健康年龄趋势 beta 标签及正负驱动因素，不声称真实生物年龄。"
                        )
                    )
                )
            }
        )
    }
}

// MARK: - BodyView

struct BodyView: View {
    @EnvironmentObject var viewModel: DashboardViewModel
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        DetailScreenScaffold(
            title: L10n.t("Body Metrics", "身体指标"),
            subtitle: L10n.t("Latest readings from Apple Health", "来自 Apple 健康的最新读数"),
            hero: {
                HealthMetricCard(
                    title: L10n.t("VO2 Max", "最大摄氧量"),
                    value: viewModel.dashboard.bodyMetrics.vo2Max.map { String(format: "%.1f", $0) } ?? "--",
                    subtitle: viewModel.dashboard.bodyMetrics.vo2Max.map { vo2MaxInterpretation($0) } ?? L10n.t("No VO2 Max data. Record a brisk walk or run.", "暂无最大摄氧量数据，请记录快走或跑步。"),
                    tint: VelaTheme.recovery,
                    systemImage: "heart.circle.fill"
                )
            },
            content: {
                MetricRow(items: [
                    .init(title: L10n.t("Weight", "体重"), value: viewModel.dashboard.bodyMetrics.weightKilograms.map { String(format: "%.1f", $0) + "kg" } ?? "--"),
                    .init(title: L10n.t("Body Fat", "体脂率"), value: viewModel.dashboard.bodyMetrics.bodyFatPercentage.map { String(format: "%.1f", $0) + "%" } ?? "--"),
                    .init(title: L10n.t("Lean Mass", "去脂体重"), value: viewModel.dashboard.bodyMetrics.leanBodyMassKilograms.map { String(format: "%.1f", $0) + "kg" } ?? "--")
                ])

                if let bf = viewModel.dashboard.bodyMetrics.bodyFatPercentage {
                    PlaceholderInsightCard(
                        title: L10n.t("Body Fat", "体脂率"),
                        bodyText: L10n.t("Body fat \(String(format: "%.1f", bf))% — \(bfCategory(bf)).", "体脂率 \(String(format: "%.1f", bf))% — \(bfCategory(bf))。")
                    )
                }

                if let weight = viewModel.dashboard.bodyMetrics.weightKilograms,
                   let lean = viewModel.dashboard.bodyMetrics.leanBodyMassKilograms, weight > 0 {
                    let ratio = Int((lean / weight) * 100)
                    PlaceholderInsightCard(
                        title: L10n.t("Body Composition", "身体成分"),
                        bodyText: L10n.t(
                            "Lean body mass is \(ratio)% of total weight (\(String(format: "%.1f", lean))kg). Higher lean mass ratio generally indicates better metabolic health.",
                            "去脂体重占总重量的 \(ratio)%（\(String(format: "%.1f", lean))kg）。较高的去脂体重比例通常表示更好的代谢健康。"
                        )
                    )
                }

                PlaceholderInsightCard(
                    title: L10n.t("About VO2 Max", "关于最大摄氧量"),
                    bodyText: L10n.t(
                        "VO2 Max measures your body's ability to use oxygen during exercise. Higher values indicate better cardiovascular fitness. Apple Watch estimates this during outdoor walks, runs, or hikes.",
                        "最大摄氧量衡量身体在运动中利用氧气的能力。数值越高代表心肺功能越好。Apple Watch 会在户外步行、跑步或徒步时估算此指标。"
                    )
                )

                PlaceholderInsightCard(
                    title: L10n.t("Data Source", "数据来源"),
                    bodyText: L10n.t(
                        "All body metrics are read from Apple Health. Use a smart scale that syncs with Apple Health for automatic weight and body composition updates. Data never leaves your device.",
                        "所有身体指标均从 Apple 健康读取。使用可同步至 Apple 健康的智能秤即可自动更新体重和身体成分数据。数据不会离开你的设备。"
                    )
                )
            }
        )
        .task { await viewModel.refresh(modelContext: modelContext) }
    }

    private func vo2MaxInterpretation(_ value: Double) -> String {
        switch value {
        case ..<25: return L10n.t("Low — consider adding cardio", "偏低 — 建议增加有氧运动")
        case ..<35: return L10n.t("Below average", "低于平均水平")
        case ..<45: return L10n.t("Average to good", "中等至良好")
        case ..<55: return L10n.t("Excellent", "优秀")
        default: return L10n.t("Superior — elite level", "卓越 — 精英水平")
        }
    }

    private func bfCategory(_ value: Double) -> String {
        switch value {
        case ..<10: return L10n.t("Low", "偏低")
        case ..<20: return L10n.t("Athletic", "运动员水平")
        case ..<25: return L10n.t("Fit", "健康")
        case ..<32: return L10n.t("Average", "平均水平")
        default: return L10n.t("Above average", "高于平均")
        }
    }
}

// MARK: - HealthAuthorizationViewModel

@MainActor
final class HealthAuthorizationViewModel: ObservableObject {
    @Published var statusText = L10n.t("HealthKit is ready to request read permission.", "HealthKit 已准备好请求读取权限。")
    private let service = HealthAuthorizationService()

    init() {
        let snapshot = service.permissionSnapshot()
        statusText = snapshot.isHealthDataAvailable
            ? L10n.t("Ready to read \(snapshot.requestedReadTypes) HealthKit data types.", "可读取 \(snapshot.requestedReadTypes) 类健康数据。")
            : L10n.t("Health data is unavailable on this device.", "此设备无法使用健康数据。")
    }

    func requestAuthorization() async {
        do {
            try await service.requestAuthorization()
            statusText = L10n.t("Authorization request completed. Data will refresh when available.", "授权请求已完成，可用数据会自动刷新。")
        } catch HealthAuthorizationError.healthDataUnavailable {
            statusText = L10n.t("Health data is unavailable on this device.", "此设备无法使用健康数据。")
        } catch {
            statusText = L10n.t("Could not complete HealthKit authorization.", "无法完成 HealthKit 授权。")
        }
    }
}

struct BreathingDot: View {
    @State private var animate = false
    let tint: Color

    var body: some View {
        Circle()
            .fill(tint)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(tint, lineWidth: 2)
                    .scaleEffect(animate ? 2.4 : 1.0)
                    .opacity(animate ? 0.0 : 0.7)
            )
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    animate = true
                }
            }
    }
}

// MARK: - Bevel Health-inspired Baseline Range Gauge
private struct HorizontalRangeBar: View {
    let label: String
    let todayValue: Double?
    let baselineValue: Double?
    let isLowerBetter: Bool
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(VelaTheme.mutedText)
                Spacer()
                if let today = todayValue {
                    Text("\(Int(today))\(unit)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                } else {
                    Text("--")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.mutedText)
                }
            }

            if let today = todayValue, let baseline = baselineValue, baseline > 0 {
                let minScale = 0.5
                let maxScale = 1.5
                let scaleRange = maxScale - minScale
                let todayRatio = (today / baseline - minScale) / scaleRange
                let clampedTodayRatio = min(max(todayRatio, 0.05), 0.95)

                let normalMinRatio = (0.85 - minScale) / scaleRange
                let normalMaxRatio = (1.15 - minScale) / scaleRange

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.06))
                            .frame(height: 4)

                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: max(4, (normalMaxRatio - normalMinRatio) * geo.size.width), height: 4)
                            .offset(x: normalMinRatio * geo.size.width)

                        Rectangle()
                            .fill(VelaTheme.mutedText.opacity(0.3))
                            .frame(width: 1, height: 6)
                            .offset(x: 0.5 * geo.size.width)

                        let deviationPercent = ((today - baseline) / baseline) * 100
                        let isPositiveDeviation = isLowerBetter ? (today <= baseline) : (today >= baseline)
                        let dotColor = isPositiveDeviation ? VelaTheme.recovery : (abs(deviationPercent) > 15 ? VelaTheme.stress : VelaTheme.energy)

                        Circle()
                            .fill(dotColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: dotColor, radius: 4)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                            )
                            .offset(x: clampedTodayRatio * geo.size.width - 4, y: -2)
                    }
                }
                .frame(height: 4)
            } else {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 4)
            }
        }
    }
}

struct WeatherDetailsSheet: View {
    let weather: VelaWeather
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            VelaTheme.background
                .ignoresSafeArea()
            
            Circle()
                .fill(weather.isDay ? VelaTheme.energy.opacity(0.12) : VelaTheme.sleep.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 40)
                .offset(y: -80)
            
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(VelaTheme.secondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                VStack(spacing: 8) {
                    Image(systemName: weather.iconName)
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [weather.isDay ? .orange : .indigo, VelaTheme.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: VelaTheme.accent.opacity(0.2), radius: 8, y: 4)
                    
                    Text(weather.conditionName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                    
                    Text(String(format: "%.0f°", weather.temperature))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(VelaTheme.primaryText)
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    weatherStatCard(title: L10n.t("Apparent Temp", "体感温度"), value: String(format: "%.1f°C", weather.apparentTemperature), icon: "thermometer.medium", tint: VelaTheme.energy)
                    weatherStatCard(title: L10n.t("Relative Humidity", "相对湿度"), value: String(format: "%.0f%%", weather.humidity), icon: "humidity.fill", tint: VelaTheme.accent)
                    weatherStatCard(title: L10n.t("Wind Speed", "风速"), value: String(format: "%.1f km/h", weather.windSpeed), icon: "wind", tint: VelaTheme.recovery)
                    weatherStatCard(title: L10n.t("Ultraviolet Index", "紫外线"), value: weather.isDay ? L10n.t("Moderate", "中等") : L10n.t("None", "无"), icon: "sun.max.fill", tint: .orange)
                }
                .padding(.horizontal, 20)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.t("5-Day Forecast", "五天天气预报"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(VelaTheme.primaryText)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 8) {
                        forecastRow(day: L10n.t("Tomorrow", "明天"), temp: "22°C / 14°C", icon: "cloud.sun.fill", condition: L10n.t("Partly Cloudy", "多云"))
                        Divider().opacity(0.3)
                        forecastRow(day: L10n.t("Wednesday", "周三"), temp: "24°C / 15°C", icon: "sun.max.fill", condition: L10n.t("Sunny", "晴朗"))
                        Divider().opacity(0.3)
                        forecastRow(day: L10n.t("Thursday", "周四"), temp: "21°C / 16°C", icon: "cloud.rain.fill", condition: L10n.t("Moderate Rain", "中雨"))
                        Divider().opacity(0.3)
                        forecastRow(day: L10n.t("Friday", "周五"), temp: "23°C / 14°C", icon: "cloud.fill", condition: L10n.t("Overcast", "阴天"))
                        Divider().opacity(0.3)
                        forecastRow(day: L10n.t("Saturday", "周六"), temp: "25°C / 17°C", icon: "sun.max.fill", condition: L10n.t("Sunny", "晴朗"))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(VelaTheme.surface))
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
    }
    
    private func weatherStatCard(title: String, value: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.12)))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VelaTheme.mutedText)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VelaTheme.primaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(VelaTheme.surface))
    }
    
    private func forecastRow(day: String, temp: String, icon: String, condition: String) -> some View {
        HStack {
            Text(day)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)
                .frame(width: 70, alignment: .leading)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(VelaTheme.accent)
                Text(condition)
                    .font(.caption)
                    .foregroundStyle(VelaTheme.secondaryText)
            }
            
            Spacer()
            
            Text(temp)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(VelaTheme.primaryText)
        }
    }
}
