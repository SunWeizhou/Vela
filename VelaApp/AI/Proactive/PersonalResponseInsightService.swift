import Foundation
import SwiftData

/// Orchestrates personal response pattern discovery and feeds results into Memory Inbox.
/// Runs during Evening Review or on manual trigger.
@MainActor
struct PersonalResponseInsightService {

    private let model: PersonalResponseModel

    init() {
        self.model = PersonalResponseModel()
    }

    /// Full pipeline: discover rules → dedup → MemoryProposal → Inbox.
    /// Returns the number of new proposals created.
    func scanAndPropose(
        modelContext: ModelContext,
        snapshots: [DailyHealthSnapshot],
        journalEntries: [JournalEntryRecord],
        foodLogs: [FoodLogRecord],
        existingRules: [MemoryEventRecord] = []
    ) throws -> Int {
        // 1. Discover rules
        let discovered = model.discoverRules(
            snapshots: snapshots,
            journalEntries: journalEntries,
            foodLogs: foodLogs
        )

        guard !discovered.isEmpty else { return 0 }

        // 2. Dedup against existing confirmed rules
        let existingRuleNames = Set(existingRules
            .filter { $0.status == MemoryProposalStatus.accepted.rawValue }
            .compactMap { extractRuleName(from: $0.content) }
        )

        let newRules = discovered.filter { rule in
            !existingRuleNames.contains(rule.name)
        }

        // 3. Generate MemoryProposals via MemoryLedger
        let ledger = MemoryLedger(modelContext: modelContext)
        var created = 0
        for rule in newRules {
            let content = buildProposalContent(from: rule)
            let evidence = rule.evidenceSummary
            _ = try? ledger.createProposal(
                targetFile: "observations.md",
                memoryType: .observation,
                content: content,
                evidence: evidence,
                confidence: rule.confidence,
                source: "personal_response_model",
                linkedAgentRunId: nil
            )
            created += 1
        }

        // 4. Expire old pending proposals
        try? ledger.expireOldPendingProposals(olderThan: 30)

        return created
    }

    // MARK: - Helpers

    private func extractRuleName(from content: String) -> String? {
        // Content format: "**Rule**: rule_name\n..."
        guard let range = content.range(of: "**Rule**: ") else { return nil }
        let after = content[range.upperBound...]
        return after.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
    }

    private func buildProposalContent(from rule: PersonalResponseModel.PersonalRule) -> String {
        let lang = AppLanguage.stored
        if lang.isChinese {
            return """
            **规律**: \(rule.name)
            **触发条件**: \(rule.trigger)
            **效果**: \(rule.effect)
            **置信度**: \(String(format: "%.0f", rule.confidence * 100))%
            **观察次数**: \(rule.occurrenceCount) 次
            **证据**: \(rule.evidenceSummary)
            """
        }
        return """
        **Rule**: \(rule.name)
        **Trigger**: \(rule.trigger)
        **Effect**: \(rule.effect)
        **Confidence**: \(String(format: "%.0f", rule.confidence * 100))%
        **Occurrences**: \(rule.occurrenceCount)
        **Evidence**: \(rule.evidenceSummary)
        """
    }
}

struct WeeklyBodyReport: Codable, Hashable {
    var generatedAt: Date
    var markdown: String
    var trainingSessions: Int
    var averageRecoveryScore: Double?
    var averageSleepScore: Double?
    var trainingResponseCount: Int
}

/// Builds the local training-response loop independently from the LLM pipeline.
/// Stable patterns enter Memory Inbox as proposals and require user confirmation.
@MainActor
struct TrainingResponseInsightService {
    func captureTrainingResponses(
        modelContext: ModelContext,
        snapshots: [DailyHealthSnapshot],
        workouts: [StrengthWorkoutRecord],
        calendar: Calendar = .current
    ) throws -> Int {
        let existing = try modelContext.fetch(FetchDescriptor<TrainingResponseRecord>())
        let existingWorkoutIDs = Set(existing.map(\.workoutId))
        let snapshotsByDay = Dictionary(uniqueKeysWithValues: snapshots.map {
            (DailyHealthSummaryRecord.dayIdentifier(for: $0.date, calendar: calendar), $0)
        })
        var created = 0

        for workout in workouts where !existingWorkoutIDs.contains(workout.id) {
            let workoutDay = calendar.startOfDay(for: workout.startedAt)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: workoutDay) else { continue }
            let todayID = DailyHealthSummaryRecord.dayIdentifier(for: workoutDay, calendar: calendar)
            let nextDayID = DailyHealthSummaryRecord.dayIdentifier(for: nextDay, calendar: calendar)
            guard let today = snapshotsByDay[todayID], let following = snapshotsByDay[nextDayID] else { continue }

            let analysis = TrainingAnalyticsService().summarizeWorkout(workout)
            let setRPEs = workout.exercises.flatMap(\.sets).compactMap(\.rpe)
            let sessionRPE = workout.sessionRPE ?? average(setRPEs)
            let response = TrainingResponseRecord(
                workoutId: workout.id,
                date: workoutDay,
                nextDayDate: nextDay,
                primaryMuscleGroups: analysis.muscleGroupSets.keys.sorted(),
                totalEffectiveSets: analysis.effectiveSets,
                totalVolumeKg: analysis.totalVolumeKg,
                sessionRPE: sessionRPE,
                nextDayRecoveryDelta: delta(following.recoveryScore, today.recoveryScore),
                nextDayHRVDelta: delta(following.hrvAverage, today.hrvAverage),
                nextDayRHRDelta: delta(following.restingHeartRate, today.restingHeartRate),
                nextDaySleepScore: following.sleepScore
            )
            modelContext.insert(response)
            created += 1
        }

        if created > 0 {
            try PersistenceWriteGate.shared.assertWritable(
                operation: "TrainingResponseInsightService: capture responses",
                modelContext: modelContext
            )
            try modelContext.save()
        }
        return created
    }

    func buildWeeklyBodyReport(
        snapshots: [DailyHealthSnapshot],
        foodLogs: [FoodLogRecord],
        journalEntries: [JournalEntryRecord],
        strengthWorkouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) -> WeeklyBodyReport {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
        let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end.addingTimeInterval(-7 * 86_400)
        let weekSnapshots = snapshots.filter { $0.date >= start && $0.date < end }
        let weekWorkouts = strengthWorkouts.filter { $0.startedAt >= start && $0.startedAt < end }
        let weekResponses = trainingResponses.filter { $0.nextDayDate >= start && $0.nextDayDate < end }
        let weekFoodLogs = foodLogs.filter { $0.createdAt >= start && $0.createdAt < end }
        let weekJournalEntries = journalEntries.filter { $0.createdAt >= start && $0.createdAt < end }
        let recoveryAverage = average(
            weekSnapshots
                .filter(hasRecoverySourceData)
                .compactMap(\.recoveryScore)
        )
        let sleepAverage = average(
            weekSnapshots
                .filter(hasSleepSourceData)
                .compactMap(\.sleepScore)
        )
        
        let responseSummary = weekResponses.isEmpty
            ? "暂无足够的训练后次日数据。"
            : weekResponses.map {
                let muscles = $0.primaryMuscleGroups.isEmpty ? "未分类肌群" : $0.primaryMuscleGroups.joined(separator: "/")
                return "\(muscles)：恢复 \(formattedDelta($0.nextDayRecoveryDelta))，HRV \(formattedDelta($0.nextDayHRVDelta))，RHR \(formattedDelta($0.nextDayRHRDelta))"
            }.joined(separator: "\n")
            
        let workoutTitles = weekWorkouts.isEmpty ? "暂无力量训练" : weekWorkouts.map(\.title).joined(separator: "、")
        let journalTags = Set(weekJournalEntries.flatMap(\.tags)).sorted().joined(separator: "、")
        
        // --- 1. 睡眠-训练表现分析 (Sleep vs Performance) ---
        var sleepPerformanceAnalysis = "样本不足（近一周需要至少 2 次力量训练且前一日有睡眠分记录）"
        if weekWorkouts.count >= 2 {
            var sleepScoresWithRPE: [(sleep: Double, rpe: Double)] = []
            for workout in weekWorkouts {
                let workoutDay = calendar.startOfDay(for: workout.startedAt)
                let previousDay = calendar.date(byAdding: .day, value: -1, to: workoutDay) ?? workoutDay
                let prevDayID = DailyHealthSummaryRecord.dayIdentifier(for: previousDay, calendar: calendar)
                
                if let snap = snapshots.first(where: { DailyHealthSummaryRecord.dayIdentifier(for: $0.date, calendar: calendar) == prevDayID }),
                   let sleep = snap.sleepScore {
                    let setRPEs = workout.exercises.flatMap(\.sets).compactMap(\.rpe)
                    let rpe = workout.sessionRPE ?? average(setRPEs) ?? 7.0
                    sleepScoresWithRPE.append((sleep, rpe))
                }
            }
            
            if sleepScoresWithRPE.count >= 2 {
                let highSleep = sleepScoresWithRPE.filter { $0.sleep >= 75 }
                let lowSleep = sleepScoresWithRPE.filter { $0.sleep < 75 }
                
                if !highSleep.isEmpty && !lowSleep.isEmpty {
                    let avgRPEHigh = highSleep.map(\.rpe).reduce(0, +) / Double(highSleep.count)
                    let avgRPELow = lowSleep.map(\.rpe).reduce(0, +) / Double(lowSleep.count)
                    let diff = avgRPELow - avgRPEHigh
                    if diff > 0 {
                        sleepPerformanceAnalysis = "高睡眠质量（睡眠分 >= 75）的日子里，力量训练主观疲劳 RPE 平均低 \(String(format: "%.1f", diff)) 分，表现出更佳的体能状态。"
                    } else {
                        sleepPerformanceAnalysis = "睡眠充足与不足时的训练疲劳度无明显差异，可能受其他心理、营养等因素的代偿影响。"
                    }
                } else {
                    let avgSleep = sleepScoresWithRPE.map(\.sleep).reduce(0, +) / Double(sleepScoresWithRPE.count)
                    sleepPerformanceAnalysis = "近一周训练日前一晚的睡眠分较为单一（平均 \(String(format: "%.0f", avgSleep)) 分），相关性分析尚不显著。"
                }
            }
        }
        
        // --- 2. 饮食-恢复分析 (Diet vs Recovery) ---
        var dietRecoveryAnalysis = "样本不足（近一周需要至少 3 条餐食记录）"
        if weekFoodLogs.count >= 3 {
            var daysWithFoodLogs = Set<String>()
            for log in weekFoodLogs {
                daysWithFoodLogs.insert(DailyHealthSummaryRecord.dayIdentifier(for: log.createdAt, calendar: calendar))
            }
            
            var recoveryWithFood: [Double] = []
            var recoveryWithoutFood: [Double] = []
            
            for snap in weekSnapshots {
                let dayID = DailyHealthSummaryRecord.dayIdentifier(for: snap.date, calendar: calendar)
                if let rec = snap.recoveryScore {
                    if daysWithFoodLogs.contains(dayID) {
                        recoveryWithFood.append(rec)
                    } else {
                        recoveryWithoutFood.append(rec)
                    }
                }
            }
            
            if !recoveryWithFood.isEmpty && !recoveryWithoutFood.isEmpty {
                let avgWith = recoveryWithFood.reduce(0, +) / Double(recoveryWithFood.count)
                let avgWithout = recoveryWithoutFood.reduce(0, +) / Double(recoveryWithoutFood.count)
                let diff = avgWith - avgWithout
                if diff > 0 {
                    dietRecoveryAnalysis = "进行了完整餐食记录的日子里，当天的生理恢复分平均比未记录餐食的日子高出 \(String(format: "%.1f", diff)) 分，提示规律进食可能加速生理系统重建。"
                } else {
                    dietRecoveryAnalysis = "饮食记录与今日恢复无明显线性相关，建议继续保持营养追踪。"
                }
            } else {
                dietRecoveryAnalysis = "本周饮食追踪记录分布较为单一，建议增加记录频率以辅助生理恢复分析。"
            }
        }
        
        // --- 3. 生理压力源相关分析 (咖啡因/压力/熬夜/酒精) ---
        var stressorAnalysis = "样本不足（近一周需要至少 2 条带压力源标签的日志记录以分析关联）"
        if weekJournalEntries.count >= 2 {
            var caffeineImpact: [Double] = []
            var stressImpact: [Double] = []
            var lateImpact: [Double] = []
            var alcoholImpact: [Double] = []
            
            for entry in weekJournalEntries {
                let dayID = DailyHealthSummaryRecord.dayIdentifier(for: entry.createdAt, calendar: calendar)
                guard let snap = weekSnapshots.first(where: { DailyHealthSummaryRecord.dayIdentifier(for: $0.date, calendar: calendar) == dayID }),
                      let recovery = snap.recoveryScore else { continue }
                
                let tags = entry.tags.map { $0.lowercased() }
                if tags.contains(where: { $0.contains("caffeine") || $0.contains("coffee") || $0.contains("咖啡") }) {
                    caffeineImpact.append(recovery)
                }
                if tags.contains(where: { $0.contains("stress") || $0.contains("压力") || $0.contains("焦虑") }) {
                    stressImpact.append(recovery)
                }
                if tags.contains(where: { $0.contains("late") || $0.contains("熬夜") || $0.contains("晚睡") }) {
                    lateImpact.append(recovery)
                }
                if tags.contains(where: { $0.contains("alcohol") || $0.contains("酒") || $0.contains("啤酒") || $0.contains("饮酒") }) {
                    alcoholImpact.append(recovery)
                }
            }
            
            var findings: [String] = []
            let normalRecovery = recoveryAverage ?? 70.0
            
            if !lateImpact.isEmpty {
                let avg = lateImpact.reduce(0, +) / Double(lateImpact.count)
                let diff = avg - normalRecovery
                findings.append("熬夜日子平均恢复分为 \(String(format: "%.1f", avg))（比日常平均变动 \(String(format: "%+.1f", diff))）")
            }
            if !alcoholImpact.isEmpty {
                let avg = alcoholImpact.reduce(0, +) / Double(alcoholImpact.count)
                let diff = avg - normalRecovery
                findings.append("饮酒日子平均恢复分为 \(String(format: "%.1f", avg))（比日常平均变动 \(String(format: "%+.1f", diff))）")
            }
            if !stressImpact.isEmpty {
                let avg = stressImpact.reduce(0, +) / Double(stressImpact.count)
                let diff = avg - normalRecovery
                findings.append("高压力日子平均恢复分为 \(String(format: "%.1f", avg))（比日常平均变动 \(String(format: "%+.1f", diff))）")
            }
            if !caffeineImpact.isEmpty {
                let avg = caffeineImpact.reduce(0, +) / Double(caffeineImpact.count)
                let diff = avg - normalRecovery
                findings.append("摄入咖啡因日子平均恢复分为 \(String(format: "%.1f", avg))（比日常平均变动 \(String(format: "%+.1f", diff))）")
            }
            
            if !findings.isEmpty {
                stressorAnalysis = "- " + findings.joined(separator: "\n- ")
            } else {
                stressorAnalysis = "已记录日志，但暂不包含咖啡因、熬夜、高压力或酒精等显著生理相关标签，生理压力源相关性暂不显著。"
            }
        }

        let markdown = """
        # 每周身体报告

        ## 训练
        - 力量训练：\(weekWorkouts.count) 次（\(workoutTitles)）
        - 训练后次日反应记录：\(weekResponses.count) 条

        ## 恢复与睡眠
        - 平均恢复分：\(formatted(recoveryAverage))
        - 平均睡眠分：\(formatted(sleepAverage))

        ## 饮食与习惯
        - 饮食记录：\(weekFoodLogs.count) 条
        - 日志标签：\(journalTags.isEmpty ? "暂无" : journalTags)

        ## 训练后次日反应
        \(responseSummary)

        ## 进阶关联分析

        ### 睡眠与训练表现关联
        \(sleepPerformanceAnalysis)

        ### 饮食与恢复关联
        \(dietRecoveryAnalysis)

        ### 生理压力源相关分析（咖啡因/压力/熬夜/酒精与生理恢复）
        \(stressorAnalysis)
        """
        
        return WeeklyBodyReport(
            generatedAt: endDate,
            markdown: markdown,
            trainingSessions: weekWorkouts.count,
            averageRecoveryScore: recoveryAverage,
            averageSleepScore: sleepAverage,
            trainingResponseCount: weekResponses.count
        )
    }

    @discardableResult
    func persistWeeklyBodyReportIfNeeded(
        modelContext: ModelContext,
        snapshots: [DailyHealthSnapshot],
        foodLogs: [FoodLogRecord],
        journalEntries: [JournalEntryRecord],
        strengthWorkouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        endingAt endDate: Date = Date(),
        calendar: Calendar = .current
    ) throws -> AIReportRecord? {
        let reports = try modelContext.fetch(FetchDescriptor<AIReportRecord>(
            predicate: #Predicate<AIReportRecord> { $0.type == "weekly_body_report" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        ))
        if let latest = reports.first,
           calendar.isDate(latest.createdAt, equalTo: endDate, toGranularity: .weekOfYear) {
            return nil
        }
        let report = buildWeeklyBodyReport(
            snapshots: snapshots,
            foodLogs: foodLogs,
            journalEntries: journalEntries,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            endingAt: endDate,
            calendar: calendar
        )
        try PersistenceWriteGate.shared.assertWritable(
            operation: "TrainingResponseInsightService: persist weekly report",
            modelContext: modelContext
        )
        let record = AIReportRecord(
            createdAt: endDate,
            type: "weekly_body_report",
            title: AppLanguage.stored.isChinese ? "每周身体报告" : "Weekly Body Report",
            markdownContent: report.markdown,
            serializedContextSnapshot: "{}",
            tags: ["weekly_body_report", "training_intelligence"]
        )
        modelContext.insert(record)
        try modelContext.save()
        return record
    }

    func proposeStableTrainingResponses(
        modelContext: ModelContext,
        responses: [TrainingResponseRecord]
    ) throws -> Int {
        let existing = try modelContext.fetch(FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate<MemoryEventRecord> { $0.source == "training_response_model" }
        ))
        let grouped = Dictionary(grouping: responses.flatMap { response in
            response.primaryMuscleGroups.map { ($0, response) }
        }, by: \.0)
        let ledger = MemoryLedger(modelContext: modelContext)
        var created = 0

        for (muscle, pairs) in grouped {
            let records = pairs.map(\.1)
            guard records.count >= 3,
                  let recoveryDelta = average(records.compactMap(\.nextDayRecoveryDelta)),
                  abs(recoveryDelta) >= 5,
                  !existing.contains(where: { $0.content.contains("**肌群**: \(muscle)") || $0.content.contains("**Muscle group**: \(muscle)") }) else {
                continue
            }
            let hrvDelta = average(records.compactMap(\.nextDayHRVDelta))
            let rhrDelta = average(records.compactMap(\.nextDayRHRDelta))
            let content = """
            **肌群**: \(muscle)
            **规律**: \(muscle) 训练后次日恢复平均变化 \(formattedDelta(recoveryDelta))
            **HRV 变化**: \(formattedDelta(hrvDelta))
            **静息心率变化**: \(formattedDelta(rhrDelta))
            **观察次数**: \(records.count)
            """
            _ = try ledger.createProposal(
                targetFile: "training_history.md",
                memoryType: .observation,
                content: content,
                evidence: "\(records.count) 次训练后次日恢复记录",
                confidence: min(0.9, 0.55 + Double(records.count) * 0.05),
                source: "training_response_model"
            )
            created += 1
        }
        return created
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func hasRecoverySourceData(_ snapshot: DailyHealthSnapshot) -> Bool {
        snapshot.hrvAverage != nil
            || snapshot.restingHeartRate != nil
            || hasSleepSourceData(snapshot)
    }

    private func hasSleepSourceData(_ snapshot: DailyHealthSnapshot) -> Bool {
        (snapshot.sleepHours ?? 0) > 0
            || (snapshot.deepSleepMinutes ?? 0) > 0
            || (snapshot.remSleepMinutes ?? 0) > 0
    }

    private func delta(_ lhs: Double?, _ rhs: Double?) -> Double? {
        guard let lhs, let rhs else { return nil }
        return lhs - rhs
    }

    private func formatted(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? "暂无"
    }

    private func formattedDelta(_ value: Double?) -> String {
        value.map { String(format: "%+.1f", $0) } ?? "暂无"
    }
}
