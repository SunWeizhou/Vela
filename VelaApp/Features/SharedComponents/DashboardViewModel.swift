import Foundation
import SwiftData
import UIKit

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct RecoveryTrendPoint: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
    let value: Double
}

enum VitalsTrendMetric {
    case hrv
    case restingHeartRate
    case respiratoryRate
    case bloodOxygen
    case weight
    case bodyFat
    case bmi
    case healthAge
    case steps
    case activeCalories
    case activeMinutes

    func value(from record: DailyHealthSummaryRecord) -> Double? {
        switch self {
        case .hrv:
            return record.hrvAverage
        case .restingHeartRate:
            return record.restingHeartRate
        case .respiratoryRate:
            return record.respiratoryRate
        case .bloodOxygen:
            return record.oxygenSaturation
        case .weight:
            return record.bodyWeight
        case .bodyFat:
            return record.bodyFatPercent
        case .bmi:
            return record.bmi
        case .healthAge:
            return record.healthAge
        case .steps:
            return record.steps
        case .activeCalories:
            return record.activeCalories
        case .activeMinutes:
            return record.activeMinutes ?? record.workoutDuration
        }
    }
}

struct WeeklyComparison {
    let thisWeekAvg: Double
    let lastWeekAvg: Double
    let delta: Double
    var isPositive: Bool { delta >= 0 }
}

struct HeatmapPoint: Identifiable, Hashable {
    var id: String { dayIdentifier }
    let date: Date
    let dayIdentifier: String
    let score: Double?
}

struct FitnessActivityDay: Identifiable, Hashable {
    var id: String { dayIdentifier }
    let date: Date
    let dayIdentifier: String
    let strainScore: Double?
    let steps: Double?
    let activeCalories: Double?
    let workoutCount: Int?
    let workoutDuration: Double?
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published private(set) var dashboard = DashboardSummary.empty()
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var currentError: VelaError?
    @Published private(set) var sleepTrend: [TrendPoint] = []
    @Published private(set) var recoveryTrend: [RecoveryTrendPoint] = []
    @Published private(set) var strainTrend: [TrendPoint] = []
    @Published private(set) var stressTrend: [TrendPoint] = []
    @Published private(set) var vitalsTrend: [TrendPoint] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var weeklyRecovery: WeeklyComparison?
    @Published private(set) var weeklySleep: WeeklyComparison?
    @Published private(set) var weeklyHRV: WeeklyComparison?
    @Published private(set) var weeklyStrain: WeeklyComparison?
    @Published var selectedDate: Date = Date()
    @Published private(set) var heatmapPoints: [HeatmapPoint] = []
    @Published private(set) var fitnessActivityHistory: [FitnessActivityDay] = []

    // Secondary data properties for the dashboard view
    @Published private(set) var todayExperience: TodayExperienceModel?
    @Published private(set) var todayCommandState: TodayCommandState?
    @Published private(set) var latestTodayArtifact: CoachArtifact?
    @Published private(set) var persistedOperatingPlan: DailyOperatingPlanRecord?
    @Published private(set) var todayCalories: Int = 0
    @Published private(set) var todayProtein: Int = 0
    @Published private(set) var todayCarbs: Int = 0
    @Published private(set) var todayFat: Int = 0

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        selectDate(prev)
    }

    func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        selectDate(next)
    }

    func goToToday() {
        selectDate(Date())
    }

    func selectDate(_ date: Date) {
        let calendar = Calendar.current
        selectedDate = min(calendar.startOfDay(for: date), calendar.startOfDay(for: Date()))
    }

    private let useCase: DailySummaryUseCase
    private let services: VelaServices?
    private var refreshTask: Task<Void, Never>?
    private var refreshTaskDate: Date?
    private var lastRefreshAttemptAt: Date?
    private var lastRefreshAttemptDate: Date?

    init(useCase: DailySummaryUseCase = DailySummaryUseCase(), services: VelaServices? = nil) {
        self.useCase = useCase
        self.services = services
    }

    @discardableResult
    func hydrateFromCache(modelContext: ModelContext) -> Bool {
        do {
            guard let cached = try useCase.loadCachedDashboard(
                for: selectedDate,
                modelContext: modelContext
            ) else {
                if !Calendar.current.isDate(dashboard.date, inSameDayAs: selectedDate) {
                    dashboard = .empty(date: selectedDate)
                    lastUpdated = nil
                }
                return false
            }
            dashboard = cached
            lastUpdated = cached.recovery.lastUpdated
            computeStreaK(modelContext: modelContext)
            computeWeeklyComparison(modelContext: modelContext)
            loadSecondaryData(modelContext: modelContext)
            return true
        } catch {
            return false
        }
    }

    func refresh(modelContext: ModelContext? = nil, force: Bool = false) async {
        if let modelContext,
           dashboard.source == .empty || !Calendar.current.isDate(dashboard.date, inSameDayAs: selectedDate) {
            hydrateFromCache(modelContext: modelContext)
        }

        if let runningTask = refreshTask {
            let runningDate = refreshTaskDate
            await runningTask.value
            if let runningDate,
               !Calendar.current.isDate(runningDate, inSameDayAs: selectedDate) {
                await refresh(modelContext: modelContext, force: force)
            }
            return
        }

        if !force,
           let lastRefreshAttemptDate,
           Calendar.current.isDate(lastRefreshAttemptDate, inSameDayAs: selectedDate),
           !HealthCachePolicy.dashboard.isStale(lastUpdatedAt: lastRefreshAttemptAt) {
            return
        }

        let requestedDate = selectedDate
        lastRefreshAttemptDate = requestedDate
        lastRefreshAttemptAt = Date()
        refreshTaskDate = requestedDate
        refreshTask = Task { [weak self] in
            guard let self else { return }
            await performRefresh(for: requestedDate, modelContext: modelContext)
            refreshTask = nil
            refreshTaskDate = nil
        }
        await refreshTask?.value
    }

    private func performRefresh(for requestedDate: Date, modelContext: ModelContext?) async {
        isLoading = true
        errorMessage = nil
        currentError = nil
        defer { isLoading = false }

        do {
            let refreshedDashboard = try await useCase.loadDashboard(
                for: requestedDate,
                modelContext: modelContext
            )
            guard Calendar.current.isDate(selectedDate, inSameDayAs: requestedDate) else { return }
            dashboard = refreshedDashboard
            if Calendar.current.isDateInToday(dashboard.date) {
                try? DailyLogService.refresh(dashboard: dashboard)
            }
            lastUpdated = Date()
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            if let modelContext {
                computeStreaK(modelContext: modelContext)
                computeWeeklyComparison(modelContext: modelContext)
                loadSecondaryData(modelContext: modelContext)
            }
        } catch {
            let message = error.localizedDescription
            if message.contains("HKErrorDomain") || message.contains("health") {
                errorMessage = AppLanguage.stored.isChinese
                    ? "健康数据读取失败，请检查 Health 权限设置。下拉刷新重试。"
                    : "Health data read failed. Check Health permissions and pull to refresh."
            } else {
                errorMessage = AppLanguage.stored.isChinese
                    ? "数据加载失败：\(message)。下拉刷新重试。"
                    : "Data load failed: \(message). Pull to refresh."
            }
            currentError = (error as? VelaError) ?? .unknown(underlying: error)
            if !Calendar.current.isDate(dashboard.date, inSameDayAs: requestedDate) {
                dashboard = .empty(date: requestedDate)
            }
        }
    }

    private func computeStreaK(modelContext: ModelContext) {
        let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(60, endingAt: selectedDate, calendar: .current)
        let records = (try? repo.fetch(in: range)) ?? []
        let calendar = Calendar.current
        var streak = 0
        var dayOffset = 0
        while true {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: selectedDate) ?? selectedDate
            let id = DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar)
            if records.contains(where: { $0.dayIdentifier == id && ($0.recoveryScore != nil || $0.sleepScore != nil) }) {
                streak += 1
                dayOffset += 1
            } else if dayOffset == 0 {
                dayOffset += 1
            } else {
                break
            }
        }
        streakDays = streak
    }

    private func computeWeeklyComparison(modelContext: ModelContext) {
        // Clear prior-date values before calculating so a sparse historical day
        // never keeps a comparison produced for the previously selected date.
        weeklyRecovery = nil
        weeklySleep = nil
        weeklyHRV = nil
        weeklyStrain = nil

        let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let calendar = Calendar.current
        let now = selectedDate
        let thisWeekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let lastWeekStart = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let thisWeekRange = DateRangeQuery(start: calendar.startOfDay(for: thisWeekStart), end: calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now))
        let lastWeekRange = DateRangeQuery(start: calendar.startOfDay(for: lastWeekStart), end: calendar.startOfDay(for: thisWeekStart))

        let thisWeek = (try? repo.fetch(in: thisWeekRange)) ?? []
        let lastWeek = (try? repo.fetch(in: lastWeekRange)) ?? []

        let thisRecovery = thisWeek.compactMap(\.recoveryScore)
        let lastRecovery = lastWeek.compactMap(\.recoveryScore)
        if !thisRecovery.isEmpty, !lastRecovery.isEmpty {
            let thisAvg = thisRecovery.reduce(0, +) / Double(thisRecovery.count)
            let lastAvg = lastRecovery.reduce(0, +) / Double(lastRecovery.count)
            weeklyRecovery = WeeklyComparison(thisWeekAvg: thisAvg, lastWeekAvg: lastAvg, delta: thisAvg - lastAvg)
        }

        let thisSleep = thisWeek.compactMap(\.sleepScore)
        let lastSleep = lastWeek.compactMap(\.sleepScore)
        if !thisSleep.isEmpty, !lastSleep.isEmpty {
            let thisAvg = thisSleep.reduce(0, +) / Double(thisSleep.count)
            let lastAvg = lastSleep.reduce(0, +) / Double(lastSleep.count)
            weeklySleep = WeeklyComparison(thisWeekAvg: thisAvg, lastWeekAvg: lastAvg, delta: thisAvg - lastAvg)
        }

        let thisHRV = thisWeek.compactMap(\.hrvAverage)
        let lastHRV = lastWeek.compactMap(\.hrvAverage)
        if !thisHRV.isEmpty, !lastHRV.isEmpty {
            let thisAvg = thisHRV.reduce(0, +) / Double(thisHRV.count)
            let lastAvg = lastHRV.reduce(0, +) / Double(lastHRV.count)
            weeklyHRV = WeeklyComparison(thisWeekAvg: thisAvg, lastWeekAvg: lastAvg, delta: thisAvg - lastAvg)
        }

        let thisStrain = thisWeek.compactMap(\.strainScore)
        let lastStrain = lastWeek.compactMap(\.strainScore)
        if !thisStrain.isEmpty, !lastStrain.isEmpty {
            let thisAvg = thisStrain.reduce(0, +) / Double(thisStrain.count)
            let lastAvg = lastStrain.reduce(0, +) / Double(lastStrain.count)
            weeklyStrain = WeeklyComparison(thisWeekAvg: thisAvg, lastWeekAvg: lastAvg, delta: thisAvg - lastAvg)
        }
    }

    func loadSleepTrend(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(7, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        sleepTrend = records.compactMap { record -> TrendPoint? in
            guard let score = record.sleepScore, score > 0 else { return nil }
            return TrendPoint(date: record.date, value: score)
        }
    }

    func loadRecoveryTrend(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(30, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        recoveryTrend = records.compactMap { record -> RecoveryTrendPoint? in
            guard let score = record.recoveryScore, score > 0 else { return nil }
            return RecoveryTrendPoint(name: "Recovery", date: record.date, value: score)
        }
    }

    func loadStrainTrend(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(30, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        strainTrend = records.compactMap { record -> TrendPoint? in
            guard let score = record.strainScore, score > 0 else { return nil }
            return TrendPoint(date: record.date, value: score)
        }
    }

    func loadFitnessActivityHistory(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(35, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        fitnessActivityHistory = records.map { record in
            FitnessActivityDay(
                date: record.date,
                dayIdentifier: record.dayIdentifier,
                strainScore: record.strainScore,
                steps: record.steps,
                activeCalories: record.activeCalories,
                workoutCount: record.workoutCount,
                workoutDuration: record.workoutDuration
            )
        }
    }

    func loadStressTrend(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(30, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        stressTrend = records.compactMap { record -> TrendPoint? in
            guard let index = record.stressIndex, index > 0 else { return nil }
            return TrendPoint(date: record.date, value: index)
        }
    }

    func loadVitalsTrend(metric: VitalsTrendMetric, modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let range = DateRangeQuery.recentDays(30, endingAt: selectedDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        vitalsTrend = records.compactMap { record -> TrendPoint? in
            guard let value = metric.value(from: record), value > 0 else { return nil }
            return TrendPoint(date: record.date, value: value)
        }
    }

    func clearVitalsTrend() {
        vitalsTrend = []
    }

    func loadHeatmap(modelContext: ModelContext) async {
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        let endDate = selectedDate
        let range = DateRangeQuery.recentDays(15, endingAt: endDate, calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        
        let calendar = Calendar.current
        var points: [HeatmapPoint] = []
        
        for i in (0..<15).reversed() {
            let day = calendar.date(byAdding: .day, value: -i, to: endDate) ?? endDate
            let id = DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar)
            let record = records.first(where: { $0.dayIdentifier == id })
            let score = record?.recoveryScore
            points.append(HeatmapPoint(date: day, dayIdentifier: id, score: score))
        }
        
        self.heatmapPoints = points
    }

    func loadSecondaryData(modelContext: ModelContext) {
        let calendar = Calendar.current
        let refDate = selectedDate
        let startOfDayRef = calendar.startOfDay(for: refDate)
        
        let healthLookbackDays = 42
        let trainingLookbackDays = 30
        
        let startLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -healthLookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let trainingStartLimit = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -trainingLookbackDays, to: startOfDayRef) ?? startOfDayRef)
        let endLimit = calendar.date(byAdding: .day, value: 1, to: startOfDayRef) ?? startOfDayRef
        
        let artifactsDesc = FetchDescriptor<CoachArtifactRecord>(
            predicate: #Predicate<CoachArtifactRecord> { $0.createdAt >= trainingStartLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let coachArtifacts = (try? modelContext.fetch(artifactsDesc)) ?? []

        let strengthDesc = FetchDescriptor<StrengthWorkoutRecord>(
            predicate: #Predicate<StrengthWorkoutRecord> { $0.startedAt >= trainingStartLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let strengthWorkouts = (try? modelContext.fetch(strengthDesc)) ?? []

        let eventsDesc = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= trainingStartLimit && $0.startedAt <= endLimit },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let workoutEvents = (try? modelContext.fetch(eventsDesc)) ?? []

        let responsesDesc = FetchDescriptor<TrainingResponseRecord>(
            predicate: #Predicate<TrainingResponseRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let trainingResponses = (try? modelContext.fetch(responsesDesc)) ?? []

        let foodDesc = FetchDescriptor<FoodLogRecord>(
            predicate: #Predicate<FoodLogRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let foodLogs = (try? modelContext.fetch(foodDesc)) ?? []

        let journalDesc = FetchDescriptor<JournalEntryRecord>(
            predicate: #Predicate<JournalEntryRecord> { $0.createdAt >= startLimit && $0.createdAt <= endLimit },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let journalEntries = (try? modelContext.fetch(journalDesc)) ?? []

        let summaryDesc = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= startLimit && $0.date <= endLimit },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let dailySummaries = (try? modelContext.fetch(summaryDesc)) ?? []

        var plansDesc = FetchDescriptor<TrainingPlanRecord>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        plansDesc.fetchLimit = 10
        let trainingPlans = (try? modelContext.fetch(plansDesc)) ?? []

        let dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: refDate, calendar: calendar)
        var opPlansDesc = FetchDescriptor<DailyOperatingPlanRecord>(
            predicate: #Predicate<DailyOperatingPlanRecord> { $0.dayIdentifier == dayIdentifier },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        opPlansDesc.fetchLimit = 1
        let operatingPlans = (try? modelContext.fetch(opPlansDesc)) ?? []
        
        let activePlan = trainingPlans.first(where: \.isActive)
        
        // 1. Resolve Persisted Operating Plan
        self.persistedOperatingPlan = operatingPlans.first
        
        // 2. Build BodyState
        let currentDailySummary = dailySummaries.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: refDate)
        })
        let bodyState = BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            dailySummary: currentDailySummary,
            workoutEvents: workoutEvents,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            activePlan: activePlan,
            activeStatus: ActiveStatusSettings.resolveCurrentStatus(),
            generatedAt: Date()
        ))
        
        // 3. Build Training Decision
        let recentStrengthSummary = TrainingAnalyticsService().buildRecentSummary(
            workouts: strengthWorkouts,
            days: 7,
            endingAt: refDate
        )
        
        let dailyTrainingDecision: DailyTrainingDecision
        if let persistedPlan = persistedOperatingPlan,
           let decoded = persistedPlan.trainingDecision {
            dailyTrainingDecision = decoded
        } else {
            dailyTrainingDecision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
                bodyState: bodyState,
                activePlan: activePlan,
                recentStrengthSummary: recentStrengthSummary,
                trainingResponses: trainingResponses
            ))
        }
        
        // 4. Update Dashboard metrics
        var updatedDashboard = dashboard
        updatedDashboard.bodyState = bodyState
        updatedDashboard.trainingDecision = TrainingDecision.compatibilityView(
            of: dailyTrainingDecision,
            bodyState: bodyState
        )
        self.dashboard = updatedDashboard
        
        // 5. Build TodayExperienceModel
        let todayLogs = foodLogs.filter { calendar.isDate($0.createdAt, inSameDayAs: startOfDayRef) }
        let cals = todayLogs.map(\.totalCalories).reduce(0, +)
        let prot = todayLogs.map(\.proteinGrams).reduce(0, +)
        let carbs = todayLogs.map(\.carbsGrams).reduce(0, +)
        let fat = todayLogs.map(\.fatGrams).reduce(0, +)
        
        self.todayCalories = cals
        self.todayProtein = prot
        self.todayCarbs = carbs
        self.todayFat = fat
        
        let targetCalorieTarget = UserDefaults.standard.integer(forKey: "vela_daily_calorie_target")
        let dailyTarget = targetCalorieTarget > 0 ? targetCalorieTarget : 2000
        
        self.todayExperience = TodayExperienceModel.build(
            dashboard: updatedDashboard,
            bodyState: bodyState,
            trainingDecision: dailyTrainingDecision,
            nutrition: TodayExperienceNutrition(
                calories: cals,
                calorieTarget: dailyTarget,
                protein: prot,
                carbs: carbs,
                fat: fat
            ),
            history: dailySummaries
        )
        
        // 6. Build Latest Today Artifact
        self.latestTodayArtifact = coachArtifacts
            .map(\.artifact)
            .first { artifact in
                guard let relatedDate = artifact.relatedDate else { return true }
                return Calendar.current.isDate(relatedDate, inSameDayAs: refDate)
            }
            
        // 7. Build TodayCommandState
        let commandState = TodayCommandBuilder.build(
            from: updatedDashboard,
            recentStrengthSummary: recentStrengthSummary,
            coachArtifact: latestTodayArtifact,
            generatedAt: Date()
        )
        self.todayCommandState = commandState

        let scheduledDay = activePlan.flatMap {
            TrainingScheduleResolver.resolve(
                plan: $0,
                on: refDate,
                events: workoutEvents,
                calendar: calendar
            )
        }
        if calendar.isDateInToday(refDate), let activePlan {
            _ = try? AdaptiveTrainingManager().refreshDailyProposal(
                plan: activePlan,
                dashboard: updatedDashboard,
                events: workoutEvents,
                foodLogs: foodLogs,
                journalEntries: journalEntries,
                modelContext: modelContext,
                date: refDate,
                calendar: calendar
            )
        }
        if calendar.isDateInToday(refDate) {
            WristSnapshotBridge.shared.publish(
                dashboard: updatedDashboard,
                command: commandState,
                plan: activePlan,
                scheduledDay: scheduledDay
            )
        }
    }
}
