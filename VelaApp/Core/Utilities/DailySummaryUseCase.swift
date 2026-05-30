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
            #if DEBUG
            if let modelContext {
                seedMockDataIfNeeded(modelContext: modelContext, now: now)
                
                // Fetch the record we just seeded or existing
                let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
                let dayStart = calendar.startOfDay(for: now)
                let range = DateRangeQuery(start: dayStart, end: calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart)
                if let record = (try? repo.fetch(in: range))?.first {
                    return makeDashboardFromRecord(record)
                }
            }
            return PreviewDataFactory.makeDashboard(date: now)
            #else
            throw VelaError.healthKitDataUnavailable(sampleType: AppLanguage.stored.isChinese ? "Apple 健康" : "Apple Health")
            #endif
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

        let sleepTarget = UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60
        let effectiveSleepTarget = sleepTarget > 0 ? sleepTarget : 450

        let sleepScore = SleepScoreEngine().calculate(
            from: ScoreEngineFactory.sleep(
                from: context,
                sleepTarget: effectiveSleepTarget,
                bedtimeOffsetMinutes: sleepTimingBaseline?.bedtimeOffset,
                wakeOffsetMinutes: sleepTimingBaseline?.wakeOffset
            )
        )
        let resolvedSleepSummary = ScoreEngineFactory.resolvedSleepSummary(
            from: context,
            sleepScore: sleepScore.score
        )

        let recovery = RecoveryScoreEngine().calculate(
            from: ScoreEngineFactory.recovery(
                from: context,
                sleepScore: sleepScore.score,
                strainScoreYesterday: yesterdayStrain,
                hrvHistory: hrvHistory,
                rhrHistory: rhrHistory
            )
        )

        let strain = StrainScoreEngine().calculate(
            from: ScoreEngineFactory.strain(
                from: context,
                recoveryScore: recovery.score
            )
        )

        let stress = StressIndexEngine().calculate(
            from: ScoreEngineFactory.stress(
                from: context,
                sleepScore: sleepScore.score,
                strainScore: strain.score
            )
        )

        let energy = EnergyBankEngine().calculate(
            from: ScoreEngineFactory.energyBank(
                from: context,
                recoveryScore: recovery.score,
                sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
                strainScore: strain.score,
                stressIndex: stress.stressIndex,
                strainHistory: nil
            )
        )

        let healthAge = HealthAgeTrendEngine().calculate(
            from: ScoreEngineFactory.healthAge(
                from: context,
                recovery: recovery,
                sleepScore: sleepScore,
                strain: strain
            )
        )

        let dashboard = DashboardSummary(
            date: context.date,
            sleepSummary: resolvedSleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: context.recoveryMetrics,
            recoveryBaseline: context.recoveryBaseline,
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: healthAge,
            bodyMetrics: context.bodyMetrics,
            extendedMetrics: context.extendedMetrics,
            workouts: context.strainToday.workouts,
            dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
            source: .healthKit
        )
        let persistedSnapshot = makeSnapshot(from: dashboard, context: context, date: now)
        if let modelContext {
            let snapshotRepo = HealthSnapshotRepository(modelContext: modelContext, calendar: calendar)
            try? snapshotRepo.saveDailySnapshot(persistedSnapshot)

            // Auto-compute personal baselines if 7+ days of data exist
            await refreshPersonalBaselinesIfNeeded(modelContext: modelContext)

            // Prune snapshots older than 90 days (once per day, low priority)
            try? snapshotRepo.pruneOldSnapshots(keepingDays: 90)

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

            let sleepScore = SleepScoreEngine().calculate(
                from: ScoreEngineFactory.sleep(
                    from: context,
                    sleepTarget: 450,
                    bedtimeOffsetMinutes: nil,
                    wakeOffsetMinutes: nil
                )
            )
            let recovery = RecoveryScoreEngine().calculate(
                from: ScoreEngineFactory.recovery(
                    from: context,
                    sleepScore: sleepScore.score,
                    strainScoreYesterday: nil,
                    hrvHistory: [],
                    rhrHistory: []
                )
            )
            let strain = StrainScoreEngine().calculate(
                from: ScoreEngineFactory.strain(from: context, recoveryScore: recovery.score)
            )
            let stress = StressIndexEngine().calculate(
                from: ScoreEngineFactory.stress(from: context, sleepScore: sleepScore.score, strainScore: strain.score)
            )
            let energy = EnergyBankEngine().calculate(
                from: ScoreEngineFactory.energyBank(
                    from: context,
                    recoveryScore: recovery.score,
                    sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
                    strainScore: strain.score,
                    stressIndex: stress.stressIndex,
                    strainHistory: nil
                )
            )
            let healthAge = HealthAgeTrendEngine().calculate(
                from: ScoreEngineFactory.healthAge(from: context, recovery: recovery, sleepScore: sleepScore, strain: strain)
            )
            let dashboard = DashboardSummary(
                date: context.date,
                sleepSummary: context.sleepSummary ?? SleepSummary(date: context.date, totalSleepMinutes: 0, bedtime: nil, wakeTime: nil, stageMinutes: [:], segments: [], sleepScore: nil),
                sleepScore: sleepScore,
                recovery: recovery,
                recoveryMetrics: context.recoveryMetrics,
                recoveryBaseline: context.recoveryBaseline,
                strain: strain,
                stress: stress,
                energy: energy,
                healthAge: healthAge,
                bodyMetrics: context.bodyMetrics,
                extendedMetrics: context.extendedMetrics,
                workouts: context.strainToday.workouts,
                dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
                source: .healthKit
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

            let sleepScore = SleepScoreEngine().calculate(
                from: ScoreEngineFactory.sleep(
                    from: context,
                    sleepTarget: 450,
                    bedtimeOffsetMinutes: nil,
                    wakeOffsetMinutes: nil
                )
            )
            let recovery = RecoveryScoreEngine().calculate(
                from: ScoreEngineFactory.recovery(
                    from: context,
                    sleepScore: sleepScore.score,
                    strainScoreYesterday: nil,
                    hrvHistory: [],
                    rhrHistory: []
                )
            )
            let strain = StrainScoreEngine().calculate(
                from: ScoreEngineFactory.strain(from: context, recoveryScore: recovery.score)
            )
            let stress = StressIndexEngine().calculate(
                from: ScoreEngineFactory.stress(from: context, sleepScore: sleepScore.score, strainScore: strain.score)
            )
            let energy = EnergyBankEngine().calculate(
                from: ScoreEngineFactory.energyBank(
                    from: context,
                    recoveryScore: recovery.score,
                    sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
                    strainScore: strain.score,
                    stressIndex: stress.stressIndex,
                    strainHistory: nil
                )
            )
            let healthAge = HealthAgeTrendEngine().calculate(
                from: ScoreEngineFactory.healthAge(from: context, recovery: recovery, sleepScore: sleepScore, strain: strain)
            )
            let dashboard = DashboardSummary(
                date: context.date,
                sleepSummary: context.sleepSummary ?? SleepSummary(date: context.date, totalSleepMinutes: 0, bedtime: nil, wakeTime: nil, stageMinutes: [:], segments: [], sleepScore: nil),
                sleepScore: sleepScore,
                recovery: recovery,
                recoveryMetrics: context.recoveryMetrics,
                recoveryBaseline: context.recoveryBaseline,
                strain: strain,
                stress: stress,
                energy: energy,
                healthAge: healthAge,
                bodyMetrics: context.bodyMetrics,
                extendedMetrics: context.extendedMetrics,
                workouts: context.strainToday.workouts,
                dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
                source: .healthKit
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
        
        // Map bedtime seconds to be relative to 12:00 PM (noon). If bedtime is before 12:00 PM (e.g. 00:30), add 86400 to map it smoothly across midnight.
        let bedtimeSeconds = bedtimeComponents.map { comps -> Double in
            let secs = Double((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
            return secs < 43200.0 ? secs + 86400.0 : secs
        }
        let avgBedtimeSeconds = bedtimeSeconds.isEmpty ? nil : bedtimeSeconds.reduce(0, +) / Double(bedtimeSeconds.count)

        let waketimes: [Date] = pastEpisodes.compactMap(\.wakeTime)
        let waketimeComponents = waketimes.map { calendar.dateComponents([.hour, .minute], from: $0) }
        let waketimeSeconds = waketimeComponents.map { Double(($0.hour ?? 0) * 3600 + ($0.minute ?? 0) * 60) }
        let avgWaketimeSeconds = waketimeSeconds.isEmpty ? nil : Double(waketimeSeconds.reduce(0, +)) / Double(waketimeSeconds.count)

        guard let avgBedtimeSeconds, let avgWaketimeSeconds else { return nil }

        let todayBedtimeComps = calendar.dateComponents([.hour, .minute], from: todayBedtime)
        var todayBedtimeSeconds = Double((todayBedtimeComps.hour ?? 0) * 3600 + (todayBedtimeComps.minute ?? 0) * 60)
        if todayBedtimeSeconds < 43200.0 {
            todayBedtimeSeconds += 86400.0
        }

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

    private func dailyInsight(
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult,
        source: DashboardSummary.DataSource
    ) -> String {
        if source == .healthKit {
            return L10n.t(
                "Updated from Apple Health. Recovery \(Int(recovery.score.rounded())), sleep \(Int(sleepScore.score.rounded())), strain \(Int(strain.score.rounded())).",
                "已读取 Apple 健康数据。恢复 \(Int(recovery.score.rounded()))，睡眠 \(Int(sleepScore.score.rounded()))，负荷 \(Int(strain.score.rounded()))。"
            )
        }
        return L10n.t(
            "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
            "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
        )
    }

    private func seedMockDataIfNeeded(modelContext: ModelContext, now: Date) {
        let repo = SwiftDataDailyHealthSummaryRepository(modelContext: modelContext)
        
        // Check if there are already records in the last 30 days
        let range = DateRangeQuery.recentDays(30, endingAt: now, calendar: calendar)
        let existing = (try? repo.fetch(in: range)) ?? []
        
        // If there are already records, don't overwrite them
        guard existing.isEmpty else { return }
        
        // Seed 30 days of high-fidelity data
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            
            // Generate realistic variations based on day offset
            let seed = Double(offset)
            let recoveryScore = 55 + sin(seed * 0.8) * 20 + Double((offset * 7) % 8)
            let sleepScore = 65 + cos(seed * 0.6) * 15 + Double((offset * 3) % 10)
            let strainScore = 8 + abs(sin(seed * 1.2)) * 10 + Double((offset * 2) % 4)
            let stressIndex = 25 + cos(seed * 0.9) * 12 + Double((offset * 5) % 15)
            let steps = 4000 + abs(sin(seed * 0.5)) * 8000 + Double((offset * 500) % 3000)
            let activeCalories = 150 + abs(sin(seed * 0.5)) * 400 + Double((offset * 50) % 200)
            let rhr = 58 + cos(seed * 0.7) * 6 + Double((offset * 2) % 4)
            let hrv = 45 + sin(seed * 0.7) * 15 + Double((offset * 3) % 8)
            
            let snapshot = DailyHealthSnapshot(
                date: day,
                sleepScore: sleepScore,
                recoveryScore: recoveryScore,
                strainScore: strainScore,
                stressIndex: stressIndex,
                morningEnergy: 50 + sin(seed * 0.5) * 20,
                currentEnergy: max(10, min(100, 50 + sin(seed * 0.5) * 20 - strainScore * 2)),
                energyBank: 40 + cos(seed * 0.4) * 25,
                healthAge: 26.5,
                hrvAverage: hrv,
                restingHeartRate: rhr,
                sleepHours: 6.5 + cos(seed * 0.6) * 1.5,
                deepSleepPercent: 0.18 + sin(seed * 0.3) * 0.05,
                remSleepPercent: 0.22 + cos(seed * 0.3) * 0.04,
                sleepEfficiency: 0.88 + sin(seed * 0.2) * 0.05,
                steps: steps,
                activeCalories: activeCalories,
                workoutCount: offset % 3 == 0 ? 1 : 0,
                workoutTypes: offset % 3 == 0 ? "跑步" : nil,
                workoutDuration: offset % 3 == 0 ? 35.0 : 0.0,
                bodyWeight: 72.0,
                bodyFatPercent: 17.5,
                bmi: 22.8,
                oxygenSaturation: 0.98,
                respiratoryRate: 14.5,
                wristTemperature: 36.6
            )
            
            let record = DailyHealthSummaryRecord(snapshot: snapshot, calendar: calendar)
            modelContext.insert(record)
        }
        try? modelContext.save()
    }

    private func makeDashboardFromRecord(_ record: DailyHealthSummaryRecord) -> DashboardSummary {
        let sleepScoreVal = record.sleepScore ?? 75.0
        let recoveryScoreVal = record.recoveryScore ?? 78.0
        let strainScoreVal = record.strainScore ?? 12.0
        let stressIndexVal = record.stressIndex ?? 32.0
        let morningEnergyVal = record.morningEnergy ?? 85.0
        let currentEnergyVal = record.currentEnergy ?? 65.0
        
        let sleepScore = StandardScoreResult(
            score: sleepScoreVal,
            band: sleepScoreVal >= 85 ? .high : (sleepScoreVal >= 70 ? .moderate : .low),
            confidence: .high,
            components: ["duration": sleepScoreVal],
            weights: ["duration": 1.0],
            reasons: [L10n.t("Sleep duration meets target.", "睡眠时长达到目标。")],
            metrics: ["sleep_efficiency": (record.sleepEfficiency ?? 0.88) * 100.0]
        )
        
        let recovery = StandardScoreResult(
            score: recoveryScoreVal,
            band: recoveryScoreVal >= 66 ? .high : (recoveryScoreVal >= 33 ? .moderate : .low),
            confidence: .high,
            components: ["hrv": recoveryScoreVal],
            weights: ["hrv": 1.0],
            reasons: [L10n.t("HRV is stable within baseline.", "HRV 稳定在基线内。")],
            metrics: ["hrv_z_score": 0.5]
        )
        
        let strain = StrainScoreEngine().calculate(from: StrainScoreInput(
            activeEnergyToday: record.activeCalories,
            activeEnergyBaseline: 500,
            exerciseMinutesToday: record.workoutDuration,
            exerciseMinutesBaseline: 35,
            workoutIntensityLoad: strainScoreVal * 4,
            recoveryScore: recoveryScoreVal,
            stepCount: record.steps
        ))
        
        let stress = StressIndexEngine().calculate(from: StressIndexInput(
            heartRateElevationScore: stressIndexVal * 0.8,
            hrvSuppressionScore: stressIndexVal * 0.9,
            sleepDebtStressScore: max(0, 100 - sleepScoreVal),
            recentStrainStressScore: strainScoreVal
        ))
        
        let energy = EnergyBankEngine().calculate(from: EnergyBankInput(
            recoveryScore: recoveryScoreVal,
            sleepScore: sleepScoreVal,
            strainScore: strainScoreVal,
            stressIndex: stressIndexVal,
            hrvToday: record.hrvAverage ?? 50.0,
            hrvBaseline: 48.0,
            rhrToday: record.restingHeartRate ?? 60.0,
            rhrBaseline: 58.0,
            sleepHours: record.sleepHours ?? 7.5,
            strainHistory: nil,
            bodyTempDelta: 0.0
        ))
        
        let sleepSummary = SleepSummary(
            date: record.date,
            totalSleepMinutes: Int((record.sleepHours ?? 7.5) * 60),
            bedtime: calendar.date(bySettingHour: 23, minute: 30, second: 0, of: record.date.addingTimeInterval(-86_400)),
            wakeTime: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: record.date),
            stageMinutes: [
                .deep: Int((record.sleepHours ?? 7.5) * 60 * 0.18),
                .rem: Int((record.sleepHours ?? 7.5) * 60 * 0.22),
                .core: Int((record.sleepHours ?? 7.5) * 60 * 0.50),
                .awake: Int((record.sleepHours ?? 7.5) * 60 * 0.10)
            ],
            segments: [],
            sleepScore: sleepScoreVal
        )
        
        let dailyInsightText = recoveryScoreVal >= 70
            ? L10n.t("Recovery is strong today. Excellent window for focused training.", "今天恢复精力充沛。非常适合进行高强度或有针对性的训练。")
            : (recoveryScoreVal >= 40
                ? L10n.t("Recovery is moderate. Keep training controlled and protect sleep tonight.", "恢复中等。建议进行中低强度训练，并优先保证今晚睡眠。")
                : L10n.t("Recovery is low. Prioritize active rest and hydration.", "恢复偏低。建议彻底休息或进行温和拉伸，注意补水。"))
        
        return DashboardSummary(
            date: record.date,
            sleepSummary: sleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: record.hrvAverage,
                restingHeartRate: record.restingHeartRate,
                sleepHeartRate: (record.restingHeartRate ?? 60.0) - 4.0,
                respiratoryRate: record.respiratoryRate
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: 48.0,
                restingHeartRate: 58.0,
                sleepHeartRate: 54.0,
                respiratoryRate: 14.0
            ),
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: HealthAgeTrendEngine().calculate(from: HealthAgeTrendInput(factors: [])),
            bodyMetrics: BodyMetricsSummary(
                vo2Max: nil,
                weightKilograms: record.bodyWeight,
                bodyFatPercentage: record.bodyFatPercent,
                leanBodyMassKilograms: nil
            ),
            extendedMetrics: ExtendedHealthMetrics(age: 28, biologicalSex: "male", heightCm: 175),
            workouts: [],
            dailyInsight: dailyInsightText,
            source: .preview
        )
    }
}
