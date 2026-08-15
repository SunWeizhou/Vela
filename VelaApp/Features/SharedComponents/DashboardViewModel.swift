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
    /// 未经反馈校准的 readiness 置信度（校准乘数基于它，避免重复缩放）。
    private var baseReadinessConfidence: Double = 0
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
    func hydrateFromCache(modelContext: ModelContext) async -> Bool {
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
            await loadSecondaryData(modelContext: modelContext)
            return true
        } catch {
            return false
        }
    }

    /// 已确认的个人反应规律（observation 类 MemoryEventRecord）摘要，
    /// 供今日计划文案引用（C2：个人反应规律接入 Daily Operating Plan）。
    @MainActor
    private func confirmedObservationSummaries(modelContext: ModelContext) -> [String] {
        let records = (try? modelContext.fetch(FetchDescriptor<MemoryEventRecord>())) ?? []
        return records
            .filter { $0.memoryTypeRaw == "observation" && $0.status == MemoryProposalStatus.accepted.rawValue }
            .compactMap { record -> String? in
                // content 形如 "**规律**: 咖啡因过午影响睡眠\n..."
                let range = record.content.range(of: "**规律**: ") ?? record.content.range(of: "**Rule**: ")
                guard let range else { return nil }
                let name = record.content[range.upperBound...]
                    .components(separatedBy: "\n")
                    .first?
                    .trimmingCharacters(in: .whitespaces)
                guard let name, !name.isEmpty else { return nil }
                return name.count > 40 ? String(name.prefix(40)) + "…" : name
            }
    }

    /// 按历史反馈校准当前决策置信度（从 base 重新计算，避免重复缩放）。
    @MainActor
    func applyFeedbackCalibration(modelContext: ModelContext) {
        guard var state = todayCommandState else { return }
        let records = (try? modelContext.fetch(FetchDescriptor<DailyDecisionFeedbackRecord>())) ?? []
        let calibrated = DecisionFeedbackCalibrator.calibratedConfidence(
            base: baseReadinessConfidence,
            decision: state.readinessDecision.decision,
            records: records
        )
        guard abs(calibrated - state.readinessDecision.confidence) > 0.0001 else { return }
        var decision = state.readinessDecision
        decision.confidence = calibrated
        decision.reasons.append("置信度已按你过去的反馈校准。")
        state.readinessDecision = decision
        todayCommandState = state
    }

    func refresh(modelContext: ModelContext? = nil, force: Bool = false) async {
        if let modelContext,
           dashboard.source == .empty || !Calendar.current.isDate(dashboard.date, inSameDayAs: selectedDate) {
            await hydrateFromCache(modelContext: modelContext)
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
            await performRefresh(for: requestedDate, modelContext: modelContext, force: force)
            refreshTask = nil
            refreshTaskDate = nil
        }
        await refreshTask?.value
    }

    private func performRefresh(for requestedDate: Date, modelContext: ModelContext?, force: Bool) async {
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
            // F9 修复：只有数据实际变化（或用户显式强制刷新）才推进「上次更新」。
            // 此前任何一次 load 都把墙钟时间当新鲜度，no-op 刷新也被标记为新鲜。
            let dataChanged = refreshedDashboard.source != dashboard.source
                || refreshedDashboard.recovery.value != dashboard.recovery.value
                || refreshedDashboard.sleepScore.value != dashboard.sleepScore.value
                || refreshedDashboard.strain.value != dashboard.strain.value
                || refreshedDashboard.stress.value != dashboard.stress.value
                || refreshedDashboard.energy.value != dashboard.energy.value
            dashboard = refreshedDashboard
            if Calendar.current.isDateInToday(dashboard.date) {
                try? DailyLogService.refresh(dashboard: dashboard)
            }
            if dataChanged || force {
                lastUpdated = Date()
            }
            if let modelContext {
                computeStreaK(modelContext: modelContext)
                computeWeeklyComparison(modelContext: modelContext)
                await loadSecondaryData(modelContext: modelContext)
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
        let calendar = Calendar.current
        let range = DateRangeQuery.recentDays(30, endingAt: selectedDate, calendar: calendar)
        let records = (try? repository.fetch(in: range)) ?? []
        let recordMap = Dictionary(uniqueKeysWithValues: records.map { ($0.dayIdentifier, $0) })

        strainTrend = (0..<30).reversed().compactMap { offset -> TrendPoint? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: selectedDate) else { return nil }
            let dayId = DailyHealthSummaryRecord.dayIdentifier(for: date, calendar: calendar)
            let score = recordMap[dayId]?.strainScore ?? 0.0
            return TrendPoint(date: date, value: max(0.0, score))
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

    func loadSecondaryData(modelContext: ModelContext) async {
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
        let persistedPlan = operatingPlans.first
        self.persistedOperatingPlan = persistedPlan

        // Domain assembly (pure computation, no DB writes / Watch I/O) is extracted
        // into SecondaryDataAssembler so it is unit-testable. The ViewModel converts
        // its SwiftData @Model records to value-type DTOs on the main thread, then hops
        // off the main actor to run the pure assembly, so the training kernels and score
        // aggregation do not block the UI.
        let dailySummaryDTOs = dailySummaries.map { $0.dto }
        let eventDTOs = workoutEvents.map { $0.dto }
        let strengthDTOs = strengthWorkouts.map { $0.dto }
        let responseDTOs = trainingResponses.map { $0.dto }
        let foodDTOs = foodLogs.map { $0.dto }
        let journalDTOs = journalEntries.map { $0.dto }
        let artifactValues = coachArtifacts.map(\.artifact)
        let activePlanDTO = activePlan?.dto
        let persistedDecision = persistedPlan?.trainingDecision
        let dashboardSnapshot = dashboard
        let observationSummaries = confirmedObservationSummaries(modelContext: modelContext)

        let assembly = await Task.detached {
            SecondaryDataAssembler.assemble(
                dashboard: dashboardSnapshot,
                refDate: refDate,
                calendar: calendar,
                dailySummaries: dailySummaryDTOs,
                workoutEvents: eventDTOs,
                strengthWorkouts: strengthDTOs,
                trainingResponses: responseDTOs,
                foodLogs: foodDTOs,
                journalEntries: journalDTOs,
                coachArtifacts: artifactValues,
                activePlan: activePlanDTO,
                persistedDecision: persistedDecision,
                confirmedObservations: observationSummaries
            )
        }.value

        // The detached task ran off-main; the user may have selected a different day
        // while it was in flight. Apply the result only if selection is unchanged.
        guard Calendar.current.isDate(selectedDate, inSameDayAs: refDate) else { return }

        self.dashboard = assembly.updatedDashboard
        self.todayCalories = assembly.todayCalories
        self.todayProtein = assembly.todayProtein
        self.todayCarbs = assembly.todayCarbs
        self.todayFat = assembly.todayFat
        self.todayExperience = assembly.todayExperience
        self.latestTodayArtifact = assembly.latestTodayArtifact
        self.todayCommandState = assembly.todayCommandState
        baseReadinessConfidence = assembly.todayCommandState.readinessDecision.confidence
        applyFeedbackCalibration(modelContext: modelContext)

        // Side effects stay in the VM (coordination, not pure assembly). They run on the
        // main actor using the real SwiftData records fetched above.
        if calendar.isDateInToday(refDate), let activePlan {
            _ = try? AdaptiveTrainingManager().refreshDailyProposal(
                plan: activePlan,
                dashboard: assembly.updatedDashboard,
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
                dashboard: assembly.updatedDashboard,
                command: assembly.todayCommandState,
                plan: activePlan,
                scheduledDay: assembly.scheduledDay
            )
        }
    }
}

// MARK: - Secondary Data Assembly

/// Pure result of the dashboard secondary-data computation. Extracted from
/// `DashboardViewModel.loadSecondaryData` so the heavy domain logic is a pure,
/// unit-testable function of the already-fetched records — the ViewModel keeps
/// only fetching, property assignment, and side effects (Watch publish,
/// adaptive-training write).
struct SecondaryDataAssembly: Sendable {
    var bodyState: BodyState
    var dailyTrainingDecision: DailyTrainingDecision
    var updatedDashboard: DashboardSummary
    var todayCalories: Int
    var todayProtein: Int
    var todayCarbs: Int
    var todayFat: Int
    var todayExperience: TodayExperienceModel
    var latestTodayArtifact: CoachArtifact?
    var todayCommandState: TodayCommandState
    var scheduledDay: TrainingDay?
}

enum SecondaryDataAssembler {
    /// Pure, Sendable secondary-data computation over value-type DTOs. Runs off the
    /// main actor (the ViewModel converts its SwiftData `@Model` records to DTOs on
    /// the main thread first, then hops off to invoke this), so the training kernels
    /// and score aggregation no longer block the UI.
    static nonisolated func assemble(
        dashboard: DashboardSummary,
        refDate: Date,
        calendar: Calendar,
        dailySummaries: [DailyHealthSummaryDTO],
        workoutEvents: [WorkoutEventDTO],
        strengthWorkouts: [StrengthWorkoutDTO],
        trainingResponses: [TrainingResponseDTO],
        foodLogs: [FoodLogDTO],
        journalEntries: [JournalEntryDTO],
        coachArtifacts: [CoachArtifact],
        activePlan: TrainingPlanDTO?,
        persistedDecision: DailyTrainingDecision?,
        confirmedObservations: [String] = []
    ) -> SecondaryDataAssembly {
        let startOfDayRef = calendar.startOfDay(for: refDate)

        // 2. Build BodyState
        let currentDailySummary = dailySummaries.first(where: {
            calendar.isDate($0.date, inSameDayAs: refDate)
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
        // F4 修复：窗口与 loadDashboard 持久化路径保持一致（28 天），
        // 避免「持久化计划决策」与「展示决策」因 7d/28d 摘要分歧而产生不同结论。
        let recentStrengthSummary = TrainingAnalyticsService().buildRecentSummary(
            workouts: strengthWorkouts,
            days: 28,
            endingAt: refDate
        )
        let dailyTrainingDecision: DailyTrainingDecision
        if let persistedDecision {
            dailyTrainingDecision = persistedDecision
        } else {
            dailyTrainingDecision = TrainingDecisionKernel().decide(input: TrainingDecisionInput(
                bodyState: bodyState,
                activePlan: activePlan,
                recentStrengthSummary: recentStrengthSummary,
                trainingResponses: trainingResponses,
                longTermTrainingVolume: dashboard.longTermBaselines?.trainingVolume
            ))
        }

        // 4. Update Dashboard metrics
        var updatedDashboard = dashboard
        updatedDashboard.bodyState = bodyState
        updatedDashboard.trainingDecision = TrainingDecision.compatibilityView(
            of: dailyTrainingDecision,
            bodyState: bodyState
        )

        // 5. Latest today artifact（提前计算：CommandState 构建需要）
        let latestTodayArtifact = coachArtifacts
            .first { artifact in
                guard let relatedDate = artifact.relatedDate else { return true }
                return calendar.isDate(relatedDate, inSameDayAs: refDate)
            }

        // 6. Today nutrition aggregates + experience model
        let todayLogs = foodLogs.filter { calendar.isDate($0.createdAt, inSameDayAs: startOfDayRef) }
        let cals = todayLogs.map(\.totalCalories).reduce(0, +)
        let prot = todayLogs.map(\.proteinGrams).reduce(0, +)
        let carbs = todayLogs.map(\.carbsGrams).reduce(0, +)
        let fat = todayLogs.map(\.fatGrams).reduce(0, +)
        let targetCalorieTarget = UserDefaults.standard.integer(forKey: "vela_daily_calorie_target")
        let dailyTarget = targetCalorieTarget > 0 ? targetCalorieTarget : 2000
        // 先构建 CommandState：今日页行动列表与 Hero 标题统一跟随 readiness 结论
        let todayCommandState = TodayCommandBuilder.build(
            from: updatedDashboard,
            recentStrengthSummary: recentStrengthSummary,
            coachArtifact: latestTodayArtifact,
            generatedAt: Date(),
            confirmedObservations: confirmedObservations
        )
        let todayExperience = TodayExperienceModel.build(
            dashboard: updatedDashboard,
            bodyState: bodyState,
            trainingDecision: dailyTrainingDecision,
            readiness: todayCommandState.readinessDecision.decision,
            nutrition: TodayExperienceNutrition(
                calories: cals,
                calorieTarget: dailyTarget,
                protein: prot,
                carbs: carbs,
                fat: fat
            ),
            history: dailySummaries
        )

        // 7. scheduled day（CommandState 已在第 6 步提前构建，供行动列表统一结论）
        let scheduledDay = activePlan.flatMap {
            TrainingScheduleResolver.resolve(
                plan: $0,
                on: refDate,
                events: workoutEvents,
                calendar: calendar
            )
        }

        return SecondaryDataAssembly(
            bodyState: bodyState,
            dailyTrainingDecision: dailyTrainingDecision,
            updatedDashboard: updatedDashboard,
            todayCalories: cals,
            todayProtein: prot,
            todayCarbs: carbs,
            todayFat: fat,
            todayExperience: todayExperience,
            latestTodayArtifact: latestTodayArtifact,
            todayCommandState: todayCommandState,
            scheduledDay: scheduledDay
        )
    }
}
