import Foundation

struct DailyLogEntry: Hashable {
    var date: Date
    var healthBrief: String
    var chatSummary: String
    var keyInsights: [String]
}

private struct DailyBodyDataSnapshot: Encodable {
    var date: String
    var generatedAt: Date
    var source: String
    var recovery: MetricResult
    var sleepSummary: SleepSummary
    var sleepScore: MetricResult
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strain: MetricResult
    var stress: MetricResult
    var energy: MetricResult
    var healthAge: HealthAgeTrendResult
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics
    var workouts: [WorkoutSummary]
    var dailyInsight: String
    var wikiUpdatesDigest: String
    var coachArchiveMaintenanceSummary: String
}

enum DailyLogService {
    private static var baseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return appSupport.appendingPathComponent("Vela", isDirectory: true)
            .appendingPathComponent("daily_logs", isDirectory: true)
    }

    private static var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private static var isoFormatter: ISO8601DateFormatter {
        ISO8601DateFormatter()
    }

    static func filename(for date: Date) -> String {
        "\(dateFormatter.string(from: date)).md"
    }

    static func url(for date: Date) -> URL {
        baseURL.appendingPathComponent(filename(for: date))
    }

    // MARK: - Read / Write

    static func refresh(dashboard: DashboardSummary, date: Date = Date()) throws {
        try write(dashboard: dashboard, chatMessages: [], date: date)
    }

    static func recordInteraction(
        dashboard: DashboardSummary,
        userText: String,
        assistantText: String,
        date: Date = Date(),
        wikiUpdates: [String] = [],
        coachArchiveSummary: String? = nil
    ) throws {
        try write(
            dashboard: dashboard,
            chatMessages: [
                CoachChatMessage(role: .user, content: userText),
                CoachChatMessage(role: .assistant, content: assistantText)
            ],
            date: date,
            wikiUpdates: wikiUpdates,
            coachArchiveSummary: coachArchiveSummary
        )
    }

    static func write(
        dashboard: DashboardSummary,
        chatMessages: [CoachChatMessage],
        date: Date = Date(),
        wikiUpdates: [String] = [],
        coachArchiveSummary: String? = nil
    ) throws {
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: url(for: date), encoding: .utf8)) ?? ""
        let healthSection = buildHealthSection(from: dashboard)
        let chatSection = mergeConversation(
            existing: extractSection("Coach Conversation", from: existing),
            incoming: chatMessages
        )
        let wikiDigest = mergeWikiDigest(
            existing: extractSection("Wiki Updates Digest", from: existing),
            wikiUpdates: wikiUpdates
        )
        let archiveSummary = mergeArchiveSummary(
            existing: extractSection("Coach Archive Maintenance Summary", from: existing),
            incoming: coachArchiveSummary
        )
        let insights = buildInsights(from: dashboard)

        let bodyData = DailyBodyDataSnapshot(
            date: dateFormatter.string(from: date),
            generatedAt: Date(),
            source: dashboard.source.rawValue,
            recovery: dashboard.recovery,
            sleepSummary: dashboard.sleepSummary,
            sleepScore: dashboard.sleepScore,
            recoveryMetrics: dashboard.recoveryMetrics,
            recoveryBaseline: dashboard.recoveryBaseline,
            strain: dashboard.strain,
            stress: dashboard.stress,
            energy: dashboard.energy,
            healthAge: dashboard.healthAge,
            bodyMetrics: dashboard.bodyMetrics,
            extendedMetrics: dashboard.extendedMetrics,
            workouts: dashboard.workouts,
            dailyInsight: dashboard.dailyInsight,
            wikiUpdatesDigest: wikiDigest,
            coachArchiveMaintenanceSummary: archiveSummary
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonStr = String(data: try encoder.encode(bodyData), encoding: .utf8) ?? "{}"

        let content = """
        # \(dateFormatter.string(from: date))

        ## Health Brief
        \(healthSection)

        ## Key Metrics
        - Recovery: \(dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))/100 (\(dashboard.recovery.band.rawValue))" : "No data")
        - Sleep: \(dashboard.sleepScore.hasData ? "\(dashboard.sleepSummary.totalSleepMinutes / 60)h \(dashboard.sleepSummary.totalSleepMinutes % 60)m (Score: \(Int(dashboard.sleepScore.score.rounded())))" : "No data")
        - Strain: \(dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))/100 (\(dashboard.strain.targetStatus.rawValue))" : "No data")
        - Stress: \(dashboard.stress.hasData ? "\(Int(dashboard.stress.stressIndex.rounded()))/100 (\(dashboard.stress.band.rawValue))" : "No data")
        - Energy: \(dashboard.energy.hasData ? "Morning: \(Int(dashboard.energy.morningEnergy.rounded())), Current: \(Int(dashboard.energy.currentEnergy.rounded()))" : "No data")

        ## Wiki Updates Digest
        \(wikiDigest)

        ## Coach Archive Maintenance Summary
        \(archiveSummary)

        ## Insights
        \(insights)

        ## Coach Conversation
        \(chatSection)

        ## Daily Body Data JSON
        ```json
        \(jsonStr)
        ```

        ---
        Generated by Vela · \(isoFormatter.string(from: date))
        """

        try content.write(to: url(for: date), atomically: true, encoding: .utf8)
    }

    /// 删除 daily_logs 明文归档目录（含按天写入的身体数据 JSON 与对话文本）。
    /// 「清空 Vela 本地数据」必须覆盖此目录，否则删除承诺未兑现（审计 H7）。
    /// - Returns: 删除的文件数量；目录不存在时返回 0。
    static func deleteLocalLogs(
        at logBaseURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> Int {
        let url = logBaseURL ?? baseURL
        guard fileManager.fileExists(atPath: url.path) else { return 0 }
        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )
        try fileManager.removeItem(at: url)
        return contents.count
    }

    static func loadWeek(endingAt date: Date = Date(), calendar: Calendar = .current) -> [DailyLogEntry] {
        let today = calendar.startOfDay(for: date)
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }

        return (0...6).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let fileURL = url(for: day)
            guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
            return parseEntry(from: text, date: day)
        }
    }

    static func loadDate(_ date: Date) -> DailyLogEntry? {
        guard let text = try? String(contentsOf: url(for: date), encoding: .utf8) else { return nil }
        return parseEntry(from: text, date: date)
    }

    // MARK: - Private Helpers

    private static func buildHealthSection(from dashboard: DashboardSummary) -> String {
        var lines: [String] = []

        lines.append("Source: \(dashboard.source.rawValue)")

        if dashboard.recovery.hasData {
            lines.append("Recovery reasons:")
            for reason in dashboard.recovery.reasons.prefix(3) {
                lines.append("- \(reason)")
            }
        }

        if dashboard.sleepScore.hasData {
            lines.append("Sleep: \(dashboard.sleepSummary.totalSleepMinutes / 60)h \(dashboard.sleepSummary.totalSleepMinutes % 60)m")
            if let bedtime = dashboard.sleepSummary.bedtime {
                let fmt = DateFormatter()
                fmt.dateFormat = "HH:mm"
                lines.append("Bedtime: \(fmt.string(from: bedtime))")
            }
            if let waketime = dashboard.sleepSummary.wakeTime {
                let fmt = DateFormatter()
                fmt.dateFormat = "HH:mm"
                lines.append("Waketime: \(fmt.string(from: waketime))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func buildChatSection(from messages: [CoachChatMessage]) -> String {
        guard !messages.isEmpty else { return "No conversation today." }
        return messages.map { msg in
            "**\(msg.role == .user ? "User" : "Vela")**: \(msg.content.prefix(500))"
        }.joined(separator: "\n\n")
    }

    private static func mergeConversation(existing: String, incoming: [CoachChatMessage]) -> String {
        guard !incoming.isEmpty else {
            return existing.isEmpty ? "No conversation today." : existing
        }

        let incomingText = buildChatSection(from: incoming)
        guard !existing.isEmpty, existing != "No conversation today." else {
            return incomingText
        }
        return "\(existing)\n\n\(incomingText)"
    }

    private static func mergeWikiDigest(existing: String, wikiUpdates: [String]) -> String {
        let defaultDigest = "- 今日未发生个人 Wiki 档案的主动修改。"
        guard !wikiUpdates.isEmpty else {
            return existing.isEmpty ? defaultDigest : existing
        }

        let uniqueFiles = Array(Set(wikiUpdates)).sorted()
        let updateLine = "- Coach 主动提出个人 Wiki 档案更新：\(uniqueFiles.joined(separator: ", "))。待用户确认后写入长期档案。"
        guard !existing.isEmpty, existing != defaultDigest else {
            return updateLine
        }
        guard !uniqueFiles.allSatisfy({ existing.contains($0) }) else {
            return existing
        }
        return "\(existing)\n\(updateLine)"
    }

    private static func mergeArchiveSummary(existing: String, incoming: String?) -> String {
        let defaultSummary = "- 今日尚未运行主动档案维护。"
        guard let incoming, !incoming.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return existing.isEmpty ? defaultSummary : existing
        }

        let summary = "- \(incoming.trimmingCharacters(in: .whitespacesAndNewlines))"
        guard !existing.isEmpty, existing != defaultSummary else {
            return summary
        }
        return "\(existing)\n\(summary)"
    }

    private static func buildInsights(from dashboard: DashboardSummary) -> String {
        var insights: [String] = []
        let recoveryBand = dashboard.recovery.band
        if recoveryBand == .low, dashboard.recovery.hasData {
            insights.append("- Recovery is low. Consider a rest day or lighter activity.")
        }
        if dashboard.strain.targetStatus == .aboveTarget, dashboard.strain.hasData {
            insights.append("- Strain is above the recommended range. Watch for overtraining.")
        }
        if dashboard.stress.band == .normal || dashboard.stress.band == .high || dashboard.stress.band == .veryHigh, dashboard.stress.hasData {
            insights.append("- Stress proxy is elevated. HRV or heart rate may indicate physiological strain.")
        }
        if dashboard.energy.status == .depleted || dashboard.energy.status == .low, dashboard.energy.hasData {
            insights.append("- Energy is low. Prioritize recovery and sleep tonight.")
        }
        return insights.isEmpty ? "No notable patterns today." : insights.joined(separator: "\n")
    }

    private static func parseEntry(from text: String, date: Date) -> DailyLogEntry {
        let healthBrief = extractSection("Health Brief", from: text)
        let chatSummary = extractSection("Coach Conversation", from: text)
        let insights = extractSection("Insights", from: text)
            .components(separatedBy: "\n")
            .filter { $0.hasPrefix("-") }
            .map { String($0.dropFirst(2)) }
        return DailyLogEntry(date: date, healthBrief: healthBrief, chatSummary: chatSummary, keyInsights: insights)
    }

    private static func extractSection(_ title: String, from text: String) -> String {
        guard let range = text.range(of: "## \(title)\n") else { return "" }
        let start = range.upperBound
        let rest = String(text[start...])
        if let nextRange = rest.range(of: "\n## ") {
            return String(rest[..<nextRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return rest.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
