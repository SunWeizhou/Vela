import Foundation
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "WikiFileService")

struct WikiDocument: Hashable, Identifiable {
    var id: String { filename }
    var filename: String
    var title: String
    var content: String
    var updatedAt: Date
}

enum WikiFileService {
    private static let filenames: [(filename: String, title: String)] = [
        ("profile.md", "个人档案"),
        ("goals.md", "健康目标"),
        ("habits.md", "生活与训练习惯"),
        ("training_history.md", "训练历史"),
        ("health_context.md", "健康背景"),
        ("notes.md", "备注与发现"),
        ("baselines.md", "生理基线")
    ]

    private static let allowedFilenames = Set(filenames.map(\.filename))

    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count + 1)
        var last = [Int](0...s2.count)
        var current = empty

        for (i, char1) in s1.enumerated() {
            current[0] = i + 1
            for (j, char2) in s2.enumerated() {
                current[j + 1] = char1 == char2
                    ? last[j]
                    : min(last[j], last[j + 1], current[j]) + 1
            }
            last = current
        }
        return last.last ?? 0
    }

    private static func levenshteinSimilarity(_ s1: String, _ s2: String) -> Double {
        let maxLen = max(s1.count, s2.count)
        guard maxLen > 0 else { return 1.0 }
        let distance = levenshteinDistance(s1, s2)
        return 1.0 - Double(distance) / Double(maxLen)
    }

    // MARK: - Read

    static func loadAllDocuments() -> [WikiDocument] {
        filenames.compactMap { entry in
            let url = localURL(for: entry.filename)
            let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let updatedAt = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date

            let bundledContent = bundledContent(for: entry.filename)
            let merged = [bundledContent, content].filter { !$0.isEmpty }.joined(separator: "\n\n")

            return WikiDocument(
                filename: entry.filename,
                title: entry.title,
                content: merged.isEmpty ? defaultContent(for: entry.filename) : merged,
                updatedAt: updatedAt ?? Date()
            )
        }
    }

    /// Load documents as a simple [filename: content] dictionary for AI context
    static func loadDictionary() -> [String: String] {
        filenames.reduce(into: [:]) { result, entry in
            let url = localURL(for: entry.filename)
            var content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let bundled = bundledContent(for: entry.filename)
            if !bundled.isEmpty, content.isEmpty {
                content = bundled
            } else if !bundled.isEmpty {
                content = bundled + "\n\n" + content
            }
            if content.isEmpty {
                content = defaultContent(for: entry.filename)
            }
            result[entry.filename] = content
        }
    }

    // MARK: - Write (Agent-driven)

    /// Agent calls this to update a specific wiki section
    static func updateSection(filename: String, content: String, mode: WikiUpdateMode = .append) throws {
        guard allowedFilenames.contains(filename) else {
            logger.warning("Wiki update rejected: unknown file '\(filename)'")
            return
        }

        let url = localURL(for: filename)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""

        let newContent: String
        switch mode {
        case .replace:
            newContent = content
        case .append:
            let timestamp = ISO8601DateFormatter().string(from: Date())
            let block = existing.isEmpty
                ? content
                : "\(existing)\n\n## Updated \(timestamp)\n\(content)"
            newContent = block
        case .merge:
            let existingParagraphs = existing.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let newParagraphs = content.components(separatedBy: "\n\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            // Deduplicate: check if a paragraph already exists exactly, is a substring of existing,
            // or existing is a substring of new, or they have Levenshtein similarity > 0.85
            let newDeduplicated = newParagraphs.filter { newPara in
                !existingParagraphs.contains { existingPara in
                    existingPara.contains(newPara) || newPara.contains(existingPara)
                    || levenshteinSimilarity(existingPara, newPara) > 0.85
                }
            }

            guard !newDeduplicated.isEmpty else {
                logger.info("Wiki merge skipped: all paragraphs are duplicates for '\(filename)'")
                return
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let block = existingParagraphs + ["" , "## Updated \(timestamp)"] + newDeduplicated
            newContent = block.joined(separator: "\n")
        }

        try newContent.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Generate a weekly wiki review prompt for the agent
    static func weeklyReviewPrompt(dailyLogs: [DailyLogEntry], language: AppLanguage = .stored) -> String {
        let weekSummary = dailyLogs.map { log in
            let dateStr = DateFormatter.localizedString(from: log.date, dateStyle: .medium, timeStyle: .none)
            return """
            ### \(dateStr)
            Health: \(String(log.healthBrief.prefix(300)))
            Key Insights: \(log.keyInsights.joined(separator: "; "))
            """
        }.joined(separator: "\n\n")

        let currentWiki = loadDictionary().map { "### \($0.key)\n\($0.value)" }.joined(separator: "\n\n")

        if language.isChinese {
            return """
            你正在为你的用户做每周 Wiki 回顾。请仔细阅读这周的健康日志和当前 Wiki，找出用户的新模式、习惯变化、或者值得记录的稳定特征。

            ## 本周日志
            \(weekSummary)

            ## 当前 Wiki
            \(currentWiki)

            ## 任务
            分析本周日志，识别出值得更新到 Wiki 的内容。输出格式：

            [ACTION:update_wiki]
            file: habits.md
            [内容——只写新发现或变化，不要重复已有信息]
            [/ACTION]

            每个 Wiki 文件最多更新一条。如果没有值得记录的新信息，就不输出任何 ACTION。
            只在发现用户的稳定模式、偏好变化、或新的健康背景时才更新。
            """
        }

        return """
        You are reviewing the past week's health logs and current wiki for your user.
        Identify new patterns, habit changes, or stable characteristics worth recording.

        ## This Week's Logs
        \(weekSummary)

        ## Current Wiki
        \(currentWiki)

        ## Task
        Analyze the week's logs and identify wiki-worthy updates. Output format:

        [ACTION:update_wiki]
        file: habits.md
        [content — only new findings or changes, don't repeat existing info]
        [/ACTION]

        At most one update per wiki file. If nothing new is worth recording, output no ACTION at all.
        Only record stable patterns, preference changes, or new health context.
        """
    }

    // MARK: - Private

    private static func localURL(for filename: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Vela", isDirectory: true)
            .appendingPathComponent("user_wiki", isDirectory: true)
            .appendingPathComponent(filename)
    }

    private static func bundledContent(for filename: String) -> String {
        let name = (filename as NSString).deletingPathExtension
        guard let url = Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "user_wiki"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }

    private static func defaultContent(for filename: String) -> String {
        switch filename {
        case "profile.md":
            return "# Profile\n\n- Age: \n- Activity level: \n- Primary sports: \n- Health goals: \n"
        case "goals.md":
            return "# Goals\n\n- Sleep: \n- Activity: \n- Recovery: \n- Other: \n"
        case "habits.md":
            return "# Habits\n\n- Caffeine: \n- Alcohol: \n- Evening routine: \n- Morning routine: \n"
        case "training_history.md":
            return "# Training History\n\n- Typical weekly volume: \n- Preferred training types: \n- Past injuries: \n"
        case "health_context.md":
            return "# Health Context\n\n- Known conditions: \n- Medications: \n- Recent changes: \n"
        case "notes.md":
            return "# Notes\n\n"
        case "baselines.md":
            return "# Personal Baselines\n\nYour physiological baselines will be computed automatically after 7+ days of data.\n"
        default:
            return ""
        }
    }
}

enum WikiUpdateMode: String, Hashable {
    case append
    case replace
    case merge
}
