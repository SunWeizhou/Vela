import Foundation
import SwiftData

/// Repository for querying historical DailyHealthSnapshot data from persisted records.
/// Complements SwiftDataDailyHealthSummaryRepository with trend-analysis queries.
final class HealthSnapshotRepository {
    private let modelContext: ModelContext
    private let calendar: Calendar

    init(modelContext: ModelContext, calendar: Calendar = .current) {
        self.modelContext = modelContext
        self.calendar = calendar
    }

    /// Save a DailyHealthSnapshot from the scoring pipeline (upsert: one snapshot per day).
    /// Delegates to the canonical SwiftDataDailyHealthSummaryRepository.upsert.
    func saveDailySnapshot(_ snapshot: DailyHealthSnapshot) throws {
        try SwiftDataDailyHealthSummaryRepository(modelContext: modelContext).upsert(snapshot, calendar: calendar)
    }

    /// Fetch snapshots for the last N days (including today).
    func fetchSnapshots(days: Int, endingAt endDate: Date = Date()) throws -> [DailyHealthSnapshot] {
        let safeDays = max(days, 1)
        let range = DateRangeQuery.recentDays(safeDays, endingAt: endDate, calendar: calendar)
        let rangeStart = range.start
        let rangeEnd = range.end
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate { record in
                record.date >= rangeStart && record.date < rangeEnd
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try modelContext.fetch(descriptor).map { $0.toSnapshot() }
    }

    /// Fetch this week vs last week comparison data.
    /// Returns (thisWeek, lastWeek) snapshots with the most recent complete day as reference.
    func fetchWeeklyComparison(
        referenceDate: Date = Date()
    ) throws -> (thisWeek: [DailyHealthSnapshot], lastWeek: [DailyHealthSnapshot]) {
        let today = calendar.startOfDay(for: referenceDate)

        // Last 14 days of data
        let range = DateRangeQuery.recentDays(14, endingAt: referenceDate, calendar: calendar)
        let rangeStart = range.start
        let rangeEnd = range.end
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate { record in
                record.date >= rangeStart && record.date < rangeEnd
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let allRecords = try modelContext.fetch(descriptor).map { $0.toSnapshot() }

        // Split into this week (last 7 days) and last week (8-14 days ago)
        let weekBoundary = calendar.date(byAdding: .day, value: -7, to: today) ?? today

        let thisWeek = allRecords.filter { $0.date >= weekBoundary }
        let lastWeek = allRecords.filter { $0.date < weekBoundary }

        return (thisWeek, lastWeek)
    }

    /// Build weekly trend summary: compute average deltas (this week vs last week) for key metrics.
    func buildWeeklyTrendSummary(
        referenceDate: Date = Date()
    ) throws -> [String: String] {
        let (thisWeek, lastWeek) = try fetchWeeklyComparison(referenceDate: referenceDate)

        guard !thisWeek.isEmpty else {
            return ["note": "Insufficient data for weekly trend comparison."]
        }

        var trends: [String: String] = [:]

        // --- HRV ---
        let thisHrv = thisWeek.compactMap(\.hrvAverage)
        let lastHrv = lastWeek.compactMap(\.hrvAverage)
        if let thisAvg = averageOf(thisHrv), let lastAvg = averageOf(lastHrv), lastAvg > 0 {
            let delta = ((thisAvg - lastAvg) / lastAvg) * 100
            trends["hrv_delta_pct"] = String(format: "%+.1f%%", delta)
            trends["hrv_this_week_avg"] = String(format: "%.0f", thisAvg)
            trends["hrv_last_week_avg"] = String(format: "%.0f", lastAvg)
        }

        // --- Resting Heart Rate ---
        let thisRhr = thisWeek.compactMap(\.restingHeartRate)
        let lastRhr = lastWeek.compactMap(\.restingHeartRate)
        if let thisAvg = averageOf(thisRhr), let lastAvg = averageOf(lastRhr), lastAvg > 0 {
            let delta = ((thisAvg - lastAvg) / lastAvg) * 100
            trends["rhr_delta_pct"] = String(format: "%+.1f%%", delta)
            trends["rhr_this_week_avg"] = String(format: "%.0f", thisAvg)
            trends["rhr_last_week_avg"] = String(format: "%.0f", lastAvg)
        }

        // --- Sleep Score ---
        let thisSleep = thisWeek.compactMap(\.sleepScore)
        let lastSleep = lastWeek.compactMap(\.sleepScore)
        if let thisAvg = averageOf(thisSleep), let lastAvg = averageOf(lastSleep), lastAvg > 0 {
            let delta = ((thisAvg - lastAvg) / lastAvg) * 100
            trends["sleep_score_delta_pct"] = String(format: "%+.1f%%", delta)
            trends["sleep_score_this_week_avg"] = String(format: "%.0f", thisAvg)
        }

        // --- Recovery Score ---
        let thisRec = thisWeek.compactMap(\.recoveryScore)
        let lastRec = lastWeek.compactMap(\.recoveryScore)
        if let thisAvg = averageOf(thisRec), let lastAvg = averageOf(lastRec), lastAvg > 0 {
            let delta = ((thisAvg - lastAvg) / lastAvg) * 100
            trends["recovery_score_delta_pct"] = String(format: "%+.1f%%", delta)
            trends["recovery_score_this_week_avg"] = String(format: "%.0f", thisAvg)
        }

        // --- Strain Score ---
        let thisStrain = thisWeek.compactMap(\.strainScore)
        let lastStrain = lastWeek.compactMap(\.strainScore)
        if let thisAvg = averageOf(thisStrain), let lastAvg = averageOf(lastStrain), lastAvg > 0 {
            let delta = ((thisAvg - lastAvg) / lastAvg) * 100
            trends["strain_score_delta_pct"] = String(format: "%+.1f%%", delta)
            trends["strain_score_this_week_avg"] = String(format: "%.0f", thisAvg)
        }

        // --- Sleep Hours ---
        let thisSleepHrs = thisWeek.compactMap(\.sleepHours)
        if let thisAvg = averageOf(thisSleepHrs) {
            trends["sleep_hours_this_week_avg"] = String(format: "%.1f", thisAvg)
        }

        // --- Steps ---
        let thisSteps = thisWeek.compactMap(\.steps)
        if let thisAvg = averageOf(thisSteps) {
            trends["steps_this_week_avg"] = String(format: "%.0f", thisAvg)
        }

        // --- Stress Index ---
        let thisStress = thisWeek.compactMap(\.stressIndex)
        if let thisAvg = averageOf(thisStress) {
            trends["stress_index_this_week_avg"] = String(format: "%.0f", thisAvg)
        }

        // --- Day count for context ---
        trends["this_week_days"] = "\(thisWeek.count)"
        trends["last_week_days"] = "\(lastWeek.count)"

        return trends
    }

    private func averageOf(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
