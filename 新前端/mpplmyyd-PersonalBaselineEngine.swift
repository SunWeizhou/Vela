import Foundation

// MARK: - Personal Baselines Data Structure

struct PersonalBaselines {
    var hrvBaselineMean: Double?
    var hrvBaselineSD: Double?
    var rhrBaselineMean: Double?
    var rhrBaselineSD: Double?
    var sleepHoursBaseline: Double?
    var sleepEfficiencyBaseline: Double?
    var deepSleepPercentBaseline: Double?
    var remSleepPercentBaseline: Double?
    var strainBaselineMean: Double?
    var stepsBaseline: Double?
    var activeCaloriesBaseline: Double?
    var calculatedAt: Date
    var daysOfData: Int
}

// MARK: - Personal Baseline Engine

enum PersonalBaselineEngine {

    // MARK: - Compute

    /// Compute personalized baselines from the user's own historical snapshots (last 30 days).
    static func computeBaselines(from snapshots: [DailyHealthSnapshot]) -> PersonalBaselines {
        let sorted = snapshots.sorted { $0.date < $1.date }
        let recent = Array(sorted.suffix(30))

        let hrvValues = recent.compactMap(\.hrvAverage)
        let rhrValues = recent.compactMap(\.restingHeartRate)
        let sleepHoursValues = recent.compactMap(\.sleepHours)
        let sleepEfficiencyValues = recent.compactMap(\.sleepEfficiency)
        let deepSleepValues = recent.compactMap(\.deepSleepPercent)
        let remSleepValues = recent.compactMap(\.remSleepPercent)
        let strainValues = recent.compactMap(\.strainScore)
        let stepsValues = recent.compactMap(\.steps)
        let caloriesValues = recent.compactMap(\.activeCalories)

        return PersonalBaselines(
            hrvBaselineMean: meanOf(hrvValues),
            hrvBaselineSD: standardDeviationOf(hrvValues),
            rhrBaselineMean: meanOf(rhrValues),
            rhrBaselineSD: standardDeviationOf(rhrValues),
            sleepHoursBaseline: meanOf(sleepHoursValues),
            sleepEfficiencyBaseline: meanOf(sleepEfficiencyValues),
            deepSleepPercentBaseline: meanOf(deepSleepValues),
            remSleepPercentBaseline: meanOf(remSleepValues),
            strainBaselineMean: meanOf(strainValues),
            stepsBaseline: meanOf(stepsValues),
            activeCaloriesBaseline: meanOf(caloriesValues),
            calculatedAt: Date(),
            daysOfData: recent.count
        )
    }

    // MARK: - Thresholds for AI Context

    /// Formats baselines as key-value strings suitable for AI coach context injection.
    static func thresholds(for baselines: PersonalBaselines) -> [String: String] {
        var result: [String: String] = [:]

        if let hrv = baselines.hrvBaselineMean {
            let sd = baselines.hrvBaselineSD.map { String(format: "%.0f", $0) } ?? "N/A"
            result["hrv_baseline_mean"] = String(format: "%.0f ms", hrv)
            result["hrv_baseline_sd"] = "\u{B1}\(sd) ms"
        }
        if let rhr = baselines.rhrBaselineMean {
            let sd = baselines.rhrBaselineSD.map { String(format: "%.0f", $0) } ?? "N/A"
            result["rhr_baseline_mean"] = String(format: "%.0f bpm", rhr)
            result["rhr_baseline_sd"] = "\u{B1}\(sd) bpm"
        }
        if let sleep = baselines.sleepHoursBaseline {
            result["sleep_hours_baseline"] = String(format: "%.1f hrs", sleep)
        }
        if let se = baselines.sleepEfficiencyBaseline {
            result["sleep_efficiency_baseline"] = String(format: "%.0f%%", se * 100)
        }
        if let deep = baselines.deepSleepPercentBaseline {
            result["deep_sleep_baseline"] = String(format: "%.0f%%", deep * 100)
        }
        if let rem = baselines.remSleepPercentBaseline {
            result["rem_sleep_baseline"] = String(format: "%.0f%%", rem * 100)
        }
        if let strain = baselines.strainBaselineMean {
            result["strain_baseline_mean"] = String(format: "%.0f", strain)
        }
        if let steps = baselines.stepsBaseline {
            result["steps_baseline"] = String(format: "%.0f steps", steps)
        }
        if let cal = baselines.activeCaloriesBaseline {
            result["active_calories_baseline"] = String(format: "%.0f kcal", cal)
        }
        result["baseline_days_of_data"] = "\(baselines.daysOfData)"
        result["baseline_calculated_at"] = ISO8601DateFormatter().string(from: baselines.calculatedAt)

        return result
    }

    // MARK: - Format for Wiki

    /// Generate a markdown string suitable for storage as baselines.md in the user Wiki.
    static func formatForWiki(_ baselines: PersonalBaselines) -> String {
        let th = thresholds(for: baselines)
        let dateStr = DateFormatter.localizedString(from: baselines.calculatedAt, dateStyle: .medium, timeStyle: .short)

        var lines: [String] = [
            "# Personal Baselines",
            "",
            "Your 30-day physiological baselines, computed from your own historical data.",
            "",
            "**Calculated:** \(dateStr)",
            "**Days of data:** \(baselines.daysOfData)",
            "",
            "| Metric | Baseline (Mean \u{B1} SD) |",
            "|--------|---------------------------|",
        ]

        if let hrv = th["hrv_baseline_mean"], let sd = th["hrv_baseline_sd"] {
            lines.append("| HRV | \(hrv) (\(sd)) |")
        }
        if let rhr = th["rhr_baseline_mean"], let sd = th["rhr_baseline_sd"] {
            lines.append("| RHR | \(rhr) (\(sd)) |")
        }
        if let sleep = th["sleep_hours_baseline"] {
            lines.append("| Sleep Duration | \(sleep) |")
        }
        if let se = th["sleep_efficiency_baseline"] {
            lines.append("| Sleep Efficiency | \(se) |")
        }
        if let deep = th["deep_sleep_baseline"] {
            lines.append("| Deep Sleep | \(deep) |")
        }
        if let rem = th["rem_sleep_baseline"] {
            lines.append("| REM Sleep | \(rem) |")
        }
        if let strain = th["strain_baseline_mean"] {
            lines.append("| Strain | \(strain) |")
        }
        if let steps = th["steps_baseline"] {
            lines.append("| Steps | \(steps) |")
        }
        if let cal = th["active_calories_baseline"] {
            lines.append("| Active Calories | \(cal) |")
        }

        return lines.joined(separator: "\n")
    }

    /// Format baselines as a concise natural-language block for the AI system prompt.
    static func formatForAIPrompt(_ baselines: PersonalBaselines) -> String {
        let th = thresholds(for: baselines)
        let dateStr = DateFormatter.localizedString(from: baselines.calculatedAt, dateStyle: .medium, timeStyle: .short)

        var parts: [String] = [
            "Calculated on \(dateStr) from \(baselines.daysOfData) days of your own historical data:",
        ]

        if let hrv = th["hrv_baseline_mean"], let sd = th["hrv_baseline_sd"] {
            parts.append("- HRV: \(hrv) (\(sd))")
        }
        if let rhr = th["rhr_baseline_mean"], let sd = th["rhr_baseline_sd"] {
            parts.append("- RHR: \(rhr) (\(sd))")
        }
        if let sleep = th["sleep_hours_baseline"] {
            parts.append("- Sleep Duration: \(sleep)")
        }
        if let se = th["sleep_efficiency_baseline"] {
            parts.append("- Sleep Efficiency: \(se)")
        }
        if let deep = th["deep_sleep_baseline"] {
            parts.append("- Deep Sleep: \(deep)")
        }
        if let rem = th["rem_sleep_baseline"] {
            parts.append("- REM Sleep: \(rem)")
        }
        if let strain = th["strain_baseline_mean"] {
            parts.append("- Strain: \(strain)")
        }
        if let steps = th["steps_baseline"] {
            parts.append("- Steps: \(steps)")
        }
        if let cal = th["active_calories_baseline"] {
            parts.append("- Active Calories: \(cal)")
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Save to Wiki

    /// Save computed baselines to baselines.md in the user Wiki for AI coach reference.
    static func saveBaselinesToWiki(_ baselines: PersonalBaselines) {
        let markdown = formatForWiki(baselines)
        try? WikiFileService.updateSection(filename: "baselines.md", content: markdown, mode: .replace)
    }

    // MARK: - Load from Wiki

    /// Attempts to load and parse previously saved baselines from the wiki.
    /// Returns nil if the file doesn't exist or cannot be parsed.
    static func loadBaselinesFromWiki() -> (baselines: PersonalBaselines, updatedAt: Date)? {
        let docs = WikiFileService.loadAllDocuments()
        guard let baselineDoc = docs.first(where: { $0.filename == "baselines.md" }),
              !baselineDoc.content.isEmpty,
              baselineDoc.content.count > 50 else {
            return nil
        }
        // We return the raw content and metadata; detailed parsing is done by callers.
        // For now we reconstruct minimal info from the markdown.
        let content = baselineDoc.content
        var daysOfData = 0
        if let range = content.range(of: #"\*\*Days of data:\*\* (\d+)"#, options: .regularExpression) {
            let match = String(content[range])
            daysOfData = Int(match.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) ?? 0
        }
        return (PersonalBaselines(calculatedAt: baselineDoc.updatedAt, daysOfData: daysOfData), baselineDoc.updatedAt)
    }

    // MARK: - Statistics Helpers

    private static func meanOf(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func standardDeviationOf(_ values: [Double]) -> Double? {
        guard values.count > 1, let mean = meanOf(values) else { return nil }
        let sumSquaredDiff = values.reduce(0.0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumSquaredDiff / Double(values.count - 1))
    }
}
