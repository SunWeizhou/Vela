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
            return record.workoutDuration
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
    @Published private(set) var dashboard = DashboardSummary.preview()
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

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    func goToPreviousDay() {
        let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        selectedDate = prev
    }

    func goToNextDay() {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        if next <= Date() { selectedDate = next }
    }

    func goToToday() {
        selectedDate = Date()
    }

    private let useCase: DailySummaryUseCase
    private let services: VelaServices?
    private var refreshTask: Task<Void, Never>?

    init(useCase: DailySummaryUseCase = DailySummaryUseCase(), services: VelaServices? = nil) {
        self.useCase = useCase
        self.services = services
    }

    func refresh(modelContext: ModelContext? = nil) async {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            isLoading = true
            errorMessage = nil
            currentError = nil
            do {
                dashboard = try await useCase.loadDashboard(for: selectedDate, modelContext: modelContext)
                lastUpdated = Date()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if let mc = modelContext {
                    computeStreaK(modelContext: mc)
                    computeWeeklyComparison(modelContext: mc)
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
                dashboard = .preview(date: Date())
            }
            isLoading = false
        }
        await refreshTask?.value
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
        // Query the last 15 days ending at Date() (anchored to today)
        let range = DateRangeQuery.recentDays(15, endingAt: Date(), calendar: .current)
        let records = (try? repository.fetch(in: range)) ?? []
        
        let calendar = Calendar.current
        var points: [HeatmapPoint] = []
        
        for i in (0..<15).reversed() {
            let day = calendar.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            let id = DailyHealthSummaryRecord.dayIdentifier(for: day, calendar: calendar)
            let record = records.first(where: { $0.dayIdentifier == id })
            let score = record?.recoveryScore
            points.append(HeatmapPoint(date: day, dayIdentifier: id, score: score))
        }
        
        self.heatmapPoints = points
    }
}
