import Foundation

// MARK: - Tag Correlation Model

struct TagCorrelation: Identifiable, Hashable, Codable {
    var id: String { tag }
    var tag: String
    var count: Int
    var avgSleepScore: Double
    var avgRecoveryScore: Double
    var avgStrainScore: Double
    var avgHRV: Double
    var avgRHR: Double

    /// Days without this tag — used for baseline comparison
    var withoutCount: Int = 0
    var withoutAvgSleepScore: Double = 0
    var withoutAvgRecoveryScore: Double = 0
    var withoutAvgStrainScore: Double = 0
    var withoutAvgHRV: Double = 0
    var withoutAvgRHR: Double = 0

    /// Positive means the tag is associated with BETTER scores
    var sleepScoreDelta: Double { avgSleepScore - withoutAvgSleepScore }
    var recoveryScoreDelta: Double { avgRecoveryScore - withoutAvgRecoveryScore }
    var strainScoreDelta: Double { avgStrainScore - withoutAvgStrainScore }

    /// Overall impact: average of sleep and recovery deltas (higher = better)
    var overallImpact: Double {
        (sleepScoreDelta + recoveryScoreDelta) / 2.0
    }
}

// MARK: - Journal Correlation Engine

struct JournalCorrelationEngine {

    /// For each unique tag across `journalEntries`, compute average health scores
    /// on days that tag appeared vs days it did not, using `snapshots` as the score source.
    func correlateTags(
        journalEntries: [JournalEntryRecord],
        snapshots: [DailyHealthSnapshot],
        calendar: Calendar = .current
    ) -> [TagCorrelation] {
        // Build a date-keyed lookup for snapshots
        var snapshotByDay: [String: DailyHealthSnapshot] = [:]
        for snap in snapshots {
            let key = dayKey(for: snap.date, calendar: calendar)
            snapshotByDay[key] = snap
        }

        // Collect all unique tags and map them to the NEXT day (T+1) to capture lagged physiological impacts
        var tagDays: [String: Set<String>] = [:]  // tag -> Set<dayKey of T+1>
        for entry in journalEntries {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: entry.createdAt) {
                let key = dayKey(for: nextDay, calendar: calendar)
                for tag in entry.tags {
                    tagDays[tag, default: []].insert(key)
                }
            }
        }

        // Days that have snapshot data (the universe of comparable days)
        let allDays = Set(snapshotByDay.keys)

        var results: [TagCorrelation] = []

        for (tag, daysWithTag) in tagDays {
            let daysWith = daysWithTag.intersection(allDays)
            let daysWithout = allDays.subtracting(daysWith)

            guard daysWith.count >= 2 else { continue }

            // Scores for days WITH this tag
            let withSleep = daysWith.compactMap { snapshotByDay[$0]?.sleepScore }
            let withRecovery = daysWith.compactMap { snapshotByDay[$0]?.recoveryScore }
            let withStrain = daysWith.compactMap { snapshotByDay[$0]?.strainScore }
            let withHRV = daysWith.compactMap { snapshotByDay[$0]?.hrvAverage }
            let withRHR = daysWith.compactMap { snapshotByDay[$0]?.restingHeartRate }

            // Scores for days WITHOUT this tag
            let withoutSleep = daysWithout.compactMap { snapshotByDay[$0]?.sleepScore }
            let withoutRecovery = daysWithout.compactMap { snapshotByDay[$0]?.recoveryScore }
            let withoutStrain = daysWithout.compactMap { snapshotByDay[$0]?.strainScore }
            let withoutHRV = daysWithout.compactMap { snapshotByDay[$0]?.hrvAverage }
            let withoutRHR = daysWithout.compactMap { snapshotByDay[$0]?.restingHeartRate }

            results.append(TagCorrelation(
                tag: tag,
                count: daysWith.count,
                avgSleepScore: averageOf(withSleep),
                avgRecoveryScore: averageOf(withRecovery),
                avgStrainScore: averageOf(withStrain),
                avgHRV: averageOf(withHRV),
                avgRHR: averageOf(withRHR),
                withoutCount: daysWithout.count,
                withoutAvgSleepScore: averageOf(withoutSleep),
                withoutAvgRecoveryScore: averageOf(withoutRecovery),
                withoutAvgStrainScore: averageOf(withoutStrain),
                withoutAvgHRV: averageOf(withoutHRV),
                withoutAvgRHR: averageOf(withoutRHR)
            ))
        }

        // Sort by absolute impact (biggest difference, positive or negative, first)
        return results.sorted { abs($0.overallImpact) > abs($1.overallImpact) }
    }

    /// Return the top N correlations by absolute impact.
    func topCorrelations(correlations: [TagCorrelation], limit: Int = 5) -> [TagCorrelation] {
        Array(correlations.prefix(limit))
    }

    /// Format correlations as Markdown for inclusion in the AI system prompt.
    func formatCorrelationsForAI(_ correlations: [TagCorrelation]) -> String {
        guard !correlations.isEmpty else { return "" }

        var lines: [String] = [
            "## 日记标签相关性分析 (Journal Tag Correlation Analysis)",
            "",
            "以下是你记录的日记标签与健康指标之间的相关性分析。基于过去30天的数据：",
            "",
            "| 标签 | 次数 | 睡眠评分 | 恢复评分 | 负荷评分 | 影响 |",
            "|------|------|----------|----------|----------|------|",
        ]

        for c in correlations {
            let impactEmoji: String
            if c.overallImpact > 3 {
                impactEmoji = ":white_check_mark: 正向"
            } else if c.overallImpact < -3 {
                impactEmoji = ":warning: 负向"
            } else {
                impactEmoji = ":arrow_right: 中性"
            }

            lines.append(
                "| \(c.tag) | \(c.count)天 | \(String(format: "%.0f", c.avgSleepScore)) | \(String(format: "%.0f", c.avgRecoveryScore)) | \(String(format: "%.0f", c.avgStrainScore)) | \(impactEmoji) |"
            )
        }

        lines.append("")
        lines.append("**分析提示**: 正向标签（如冥想、补水）可能与更高的恢复/睡眠评分相关联，负向标签（如酒精、夜宵）可能与评分下降有关。请在回答中主动结合这些相关性与当前数据进行交叉分析。")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return [
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        ]
        .map { String(format: "%02d", $0) }
        .joined(separator: "-")
    }

    private func averageOf(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
