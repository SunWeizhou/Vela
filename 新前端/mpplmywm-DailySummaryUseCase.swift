import Foundation
import SwiftData

@MainActor
final class DailySummaryUseCase {
    private let refreshService: HealthDataRefreshService
    private let queryService: HealthKitQueryService
    private let calendar: Calendar

    init(
        refreshService: HealthDataRefreshService? = nil,
        queryService: HealthKitQueryService = HealthKitQueryService(),
        calendar: Calendar = .current
    ) {
        self.queryService = queryService
        self.refreshService = refreshService ?? HealthDataRefreshService(queryService: queryService)
        self.calendar = calendar
    }

    func loadDashboard(for date: Date = Date(), modelContext: ModelContext? = nil) async throws -> DashboardSummary {
        let now = date
        let context = try await refreshService.refreshContext(now: now)
        if !context.hasAnyData {
            return .preview(date: now)
        }

        let yesterdayStrain: Double?
        if let modelContext {
            let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            let snapshots = (try? snapshotRepo.fetchSnapshots(days: 2, endingAt: now)) ?? []
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
            yesterdayStrain = snapshots.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) })?.strainScore
        } else {
            yesterdayStrain = nil
        }

        // Backfill historical sleep data if needed
        if let modelContext {
            await backfillSleepHistoryIfNeeded(modelContext: modelContext, now: now)
        }

        // Compute sleep timing baseline from SwiftData history
        let sleepTimingBaseline: (bedtimeOffset: Double?, wakeOffset: Double?)?
        if let modelContext {
            sleepTimingBaseline = await computeSleepTimingBaseline(modelContext: modelContext, now: now)
        } else {
            sleepTimingBaseline = nil
        }

        // Query last 28 days of raw history for individual standard deviation calculation
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let range28 = DateRangeQuery.recentDays(28, endingAt: yesterday, calendar: calendar)
        let hrvHistory = (try? await queryService.hrvHistory(in: range28)) ?? []
        let rhrHistory = (try? await queryService.rhrHistory(in: range28)) ?? []

        let dashboard = DashboardSummary.healthKit(
            context: context,
            strainScoreYesterday: yesterdayStrain,
            bedtimeOffsetMinutes: sleepTimingBaseline?.bedtimeOffset,
            wakeOffsetMinutes: sleepTimingBaseline?.wakeOffset,
            hrvHistory: hrvHistory,
            rhrHistory: rhrHistory,
            now: now,
            calendar: calendar
        )
        let persistedSnapshot = makeSnapshot(from: dashboard, context: context, date: now)
        if let modelContext {
            let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            try? snapshotRepo.saveDailySnapshot(persistedSnapshot)

            // Auto-compute personal baselines if 7+ days of data exist
            await refreshPersonalBaselinesIfNeeded(modelContext: modelContext)

            // Check for abnormal metrics and send alerts if needed
            await checkAndAlertAbnormalMetrics(snapshot: persistedSnapshot, modelContext: modelContext)
        }
        return dashboard
    }

    private func backfillSleepHistoryIfNeeded(modelContext: ModelContext, now: Date) async {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        let existingSnapshots = (try? snapshotRepo.fetchSnapshots(days: 30, endingAt: now)) ?? []

        // Check if we need a full backfill — less than 5 records or missing recovery/strain scores
        let needsBackfill = existingSnapshots.count < 5
        let missingRecovery = existingSnapshots.filter { $0.recoveryScore != nil }.count < 5
        let needsFullBackfill = needsBackfill || missingRecovery
        guard needsFullBackfill else { return }

        let episodes = (try? await queryService.sleepEpisodes(in: DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar))) ?? []
        let pastDays = episodes.map(\.date)

        // Query 28-day baselines for scoring context
        let baselineRange = DateRangeQuery.recentDays(28, endingAt: calendar.startOfDay(for: now), calendar: calendar)
        let baselineRecovery = try? await queryService.recoveryMetrics(in: baselineRange)
        let baselineStrain = try? await queryService.strainSummary(in: baselineRange)
        let baselineStrainDaily = baselineStrain?.dailyAverage(days: 28)

        for episode in episodes {
            let dayStart = calendar.startOfDay(for: episode.date)
            let singleDayRange = DateRangeQuery(start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)

            // Query recovery and strain data for this specific day
            let dayRecovery = try? await queryService.recoveryMetrics(in: singleDayRange)
            let dayStrain = try? await queryService.strainSummary(in: singleDayRange)

            // Build a mini context for scoring
            let context = DailyHealthContext(
                date: episode.date,
                sleepSummary: episode,
                recoveryMetrics: dayRecovery ?? RecoveryMetricSummary(),
                recoveryBaseline: baselineRecovery ?? RecoveryMetricSummary(),
                strainToday: dayStrain ?? StrainActivitySummary(workouts: []),
                strainBaselineDaily: baselineStrainDaily ?? StrainActivitySummary(workouts: []),
                bodyMetrics: BodyMetricsSummary()
            )

            let dashboard = DashboardSummary.healthKit(
                context: context,
                strainScoreYesterday: nil,
                bedtimeOffsetMinutes: nil,
                wakeOffsetMinutes: nil,
                now: episode.date,
                calendar: calendar
            )

            let snapshot = makeSnapshot(from: dashboard, context: context, date: episode.date)
            try? HealthSnapshotRepository(modelContext: modelContext, calendar: calendar).saveDailySnapshot(snapshot)
        }

        // Also backfill days without sleep data (e.g. no sleep recorded)
        for dayOffset in 0..<30 {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) ?? now
            let dayStart = calendar.startOfDay(for: day)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

            // Skip days already covered by sleep episodes
            if pastDays.contains(where: { calendar.isDate($0, inSameDayAs: day) }) { continue }

            let singleDayRange = DateRangeQuery(start: dayStart, end: dayEnd)
            let dayRecovery = try? await queryService.recoveryMetrics(in: singleDayRange)
            let dayStrain = try? await queryService.strainSummary(in: singleDayRange)

            // Only create a record if there's at least some data
            let hasRecoveryData = dayRecovery?.hrvMilliseconds != nil || dayRecovery?.restingHeartRate != nil
            let hasStrainData = (dayStrain?.activeEnergyKilocalories ?? 0) > 0 || (dayStrain?.exerciseMinutes ?? 0) > 0
            guard hasRecoveryData || hasStrainData else { continue }

            let context = DailyHealthContext(
                date: day,
                sleepSummary: nil,
                recoveryMetrics: dayRecovery ?? RecoveryMetricSummary(),
                recoveryBaseline: baselineRecovery ?? RecoveryMetricSummary(),
                strainToday: dayStrain ?? StrainActivitySummary(workouts: []),
                strainBaselineDaily: baselineStrainDaily ?? StrainActivitySummary(workouts: []),
                bodyMetrics: BodyMetricsSummary()
            )

            let dashboard = DashboardSummary.healthKit(
                context: context,
                strainScoreYesterday: nil,
                bedtimeOffsetMinutes: nil,
                wakeOffsetMinutes: nil,
                now: day,
                calendar: calendar
            )

            let snapshot = makeSnapshot(from: dashboard, context: context, date: day)
            try? snapshotRepo.saveDailySnapshot(snapshot)
        }
    }

    private func computeSleepTimingBaseline(modelContext: ModelContext, now: Date) async -> (bedtimeOffset: Double?, wakeOffset: Double?)? {
        let thirtyDays = DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar)

        // Query raw sleep data for baseline timing
        guard let currentSleep = try? await queryService.sleepSummary(in: DateRangeQuery.recentDays(2, endingAt: now, calendar: calendar)),
              let todayBedtime = currentSleep.bedtime,
              let todayWaketime = currentSleep.wakeTime else { return nil }

        let episodes = (try? await queryService.sleepEpisodes(in: thirtyDays)) ?? []
        let pastEpisodes = episodes.filter { !calendar.isDate($0.date, inSameDayAs: now) }

        guard !pastEpisodes.isEmpty else { return nil }

        let bedtimes: [Date] = pastEpisodes.compactMap(\.bedtime)
        let bedtimeComponents = bedtimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let bedtimeSeconds = bedtimeComponents.map { ($0.hour ?? 0) * 3600 + ($0.minute ?? 0) * 60 }
        let avgBedtimeSeconds = bedtimeSeconds.isEmpty ? nil : Double(bedtimeSeconds.reduce(0, +)) / Double(bedtimeSeconds.count)

        let waketimes: [Date] = pastEpisodes.compactMap(\.wakeTime)
        let waketimeComponents = waketimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let waketimeSeconds = waketimeComponents.map { ($0.hour ?? 0) * 3600 + ($0.minute ?? 0) * 60 }
        let avgWaketimeSeconds = waketimeSeconds.isEmpty ? nil : Double(waketimeSeconds.reduce(0, +)) / Double(waketimeSeconds.count)

        guard let avgBedtimeSeconds, let avgWaketimeSeconds else { return nil }

        let todayBedtimeComps = calendar.dateComponents([.hour, .minute], from: todayBedtime)
        let todayBedtimeSeconds = Double((todayBedtimeComps.hour ?? 0) * 3600 + (todayBedtimeComps.minute ?? 0) * 60)

        let todayWaketimeComps = calendar.dateComponents([.hour, .minute], from: todayWaketime)
        let todayWaketimeSeconds = Double((todayWaketimeComps.hour ?? 0) * 3600 + (todayWaketimeComps.minute ?? 0) * 60)

        let bedtimeOffset = (todayBedtimeSeconds - avgBedtimeSeconds) / 60.0
        let wakeOffset = (todayWaketimeSeconds - avgWaketimeSeconds) / 60.0

        return (bedtimeOffset, wakeOffset)
    }

    private func refreshPersonalBaselinesIfNeeded(modelContext: ModelContext) async {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        let snapshots = (try? snapshotRepo.fetchSnapshots(days: 30)) ?? []
        guard snapshots.count >= 7 else { return }

        let baselines = PersonalBaselineEngine.computeBaselines(from: snapshots)
        PersonalBaselineEngine.saveBaselinesToWiki(baselines)
    }

    private func checkAndAlertAbnormalMetrics(snapshot: DailyHealthSnapshot, modelContext: ModelContext) async {
        let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
        let recentSnapshots = (try? snapshotRepo.fetchSnapshots(days: 28)) ?? []
        let baselines = recentSnapshots.count >= 7
            ? PersonalBaselineEngine.computeBaselines(from: recentSnapshots)
            : nil

        // Check yesterday's sleep score for consecutive low sleep detection
        let yesterday = calendar.date(byAdding: .day, value: -1, to: snapshot.date) ?? snapshot.date
        let yesterdaySnapshot = (try? snapshotRepo.fetchSnapshots(days: 7, endingAt: snapshot.date))
            .flatMap { $0.first(where: { calendar.isDate($0.date, inSameDayAs: yesterday) }) }

        let notificationService = NotificationService.shared

        // Handle consecutive low sleep check
        if notificationService.checkConsecutiveLowSleep(
            currentSleepScore: snapshot.sleepScore,
            yesterdaySleepScore: yesterdaySnapshot?.sleepScore
        ) {
            notificationService.sendNotification(
                title: "Sleep Alert",
                body: "Your sleep score has been below 50 for 2+ consecutive days. Consider prioritizing rest tonight.",
                category: .abnormalMetric
            )
        }

        notificationService.checkAndAlertAbnormalMetrics(snapshot: snapshot, baselines: baselines)
    }

    private func makeSnapshot(
        from dashboard: DashboardSummary,
        context: DailyHealthContext,
        date: Date
    ) -> DailyHealthSnapshot {
        let sleepMetrics = dashboard.sleepScore.metrics
        let strainMetrics = dashboard.strain.metrics

        return DailyHealthSnapshot(
            date: date,
            sleepScore: dashboard.sleepScore.score,
            recoveryScore: dashboard.recovery.score,
            strainScore: dashboard.strain.score,
            stressIndex: dashboard.stress.stressIndex,
            morningEnergy: dashboard.energy.morningEnergy,
            currentEnergy: dashboard.energy.currentEnergy,
            energyBank: nil,
            healthAge: dashboard.healthAge.trendScore,
            hrvAverage: dashboard.recoveryMetrics.hrvMilliseconds,
            restingHeartRate: dashboard.recoveryMetrics.restingHeartRate,
            sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
            deepSleepPercent: sleepMetrics["deep_pct"].map { $0 / 100.0 },
            remSleepPercent: sleepMetrics["rem_pct"].map { $0 / 100.0 },
            sleepEfficiency: sleepMetrics["sleep_efficiency"].map { $0 / 100.0 },
            steps: strainMetrics["steps_raw"],
            activeCalories: strainMetrics["active_energy_raw"],
            workoutCount: dashboard.workouts.isEmpty ? nil : dashboard.workouts.count,
            workoutTypes: dashboard.workouts.isEmpty ? nil : Set(dashboard.workouts.map(\.activityName)).sorted().joined(separator: ", "),
            workoutDuration: dashboard.workouts.isEmpty ? nil : dashboard.workouts.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } / 60.0,
            bodyWeight: context.bodyMetrics.weightKilograms,
            bodyFatPercent: context.bodyMetrics.bodyFatPercentage,
            bmi: context.extendedMetrics.bmi,
            oxygenSaturation: context.extendedMetrics.oxygenSaturation,
            respiratoryRate: dashboard.recoveryMetrics.respiratoryRate,
            wristTemperature: context.extendedMetrics.bodyTemperature
        )
    }
}
