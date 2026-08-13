import Foundation
import os.log
import SwiftData

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
        ("constraints.md", "个人约束"),
        ("preferences.md", "个人偏好"),
        ("habits.md", "生活与训练习惯"),
        ("training_history.md", "训练历史"),
        ("health_context.md", "健康背景"),
        ("baselines.md", "生理基线"),
        ("observations.md", "AI 观察"),
        ("strategies.md", "当前策略"),
        ("notes.md", "备注与发现"),
        ("archive.md", "历史归档"),
        ("diet.md", "饮食偏好与禁忌"),
        ("sleep.md", "睡眠卫生与环境")
    ]

    /// Wiki 合法文件名白名单。写入（updateSection）与提案入口（MemoryLedger.createProposal）
    /// 共用同一集合，防止 LLM 提供的文件名逃逸 user_wiki 目录（路径穿越）。
    static let allowedFilenames = Set(filenames.map(\.filename))

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
            let localContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let updatedAt = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date

            let bundledContent = bundledContent(for: entry.filename)
            let content = canonicalContent(
                localContent: localContent,
                bundledContent: bundledContent,
                filename: entry.filename
            )

            return WikiDocument(
                filename: entry.filename,
                title: entry.title,
                content: content,
                updatedAt: updatedAt ?? Date()
            )
        }
    }

    /// Load documents as a simple [filename: content] dictionary for AI context
    static func loadDictionary() -> [String: String] {
        filenames.reduce(into: [:]) { result, entry in
            let url = localURL(for: entry.filename)
            let localContent = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            let bundled = bundledContent(for: entry.filename)
            result[entry.filename] = canonicalContent(
                localContent: localContent,
                bundledContent: bundled,
                filename: entry.filename
            )
        }
    }

    private static func canonicalContent(localContent: String, bundledContent: String, filename: String) -> String {
        let trimmedLocal = localContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocal.isEmpty {
            return localContent
        }

        let trimmedBundled = bundledContent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBundled.isEmpty {
            return bundledContent
        }

        return defaultContent(for: filename)
    }

    // MARK: - Write (Agent-driven)

    /// Agent calls this to update a specific wiki section.
    /// - Returns: `true` if the file content actually changed; `false` if the
    ///   target file is not allowed, every new paragraph was deduplicated out, or
    ///   the new content equals the existing content. Callers (e.g. MemoryLedger)
    ///   must NOT mark a write as successful when this returns `false` — otherwise
    ///   a proposal would read as "accepted" while its content never reached the wiki.
    @discardableResult
    static func updateSection(filename: String, content: String, mode: WikiUpdateMode = .append) throws -> Bool {
        guard allowedFilenames.contains(filename) else {
            logger.warning("Wiki update rejected: unknown file '\(filename)'")
            return false
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
                return false
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())
            let block = existingParagraphs + ["## Updated \(timestamp)"] + newDeduplicated
            newContent = block.joined(separator: "\n\n")
        }

        try newContent.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    static func replacingStructuredFields(
        in markdown: String,
        title: String,
        fieldValues: [String: String],
        preferredOrder: [String]
    ) -> String {
        var lines = markdown.components(separatedBy: .newlines)
        if lines.isEmpty || lines.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            lines = ["# \(title)", ""]
        } else if !lines.contains(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }) {
            lines.insert(contentsOf: ["# \(title)", ""], at: 0)
        }

        var replaced = Set<String>()
        let fieldSet = Set(preferredOrder)

        for index in lines.indices {
            let line = lines[index]
            let leadingWhitespace = String(line.prefix { $0 == " " || $0 == "\t" })
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") else { continue }

            let marker = String(trimmed.prefix(2))
            let body = String(trimmed.dropFirst(2))
            guard let match = matchedField(in: body, fields: fieldSet) else { continue }

            let value = fieldValues[match] ?? ""
            lines[index] = "\(leadingWhitespace)\(marker)\(match): \(value)"
            replaced.insert(match)
        }

        let missing = preferredOrder.filter { !replaced.contains($0) }
        guard !missing.isEmpty else {
            return normalizedMarkdown(lines)
        }

        let insertionIndex = structuredFieldInsertionIndex(in: lines)
        let inserted = missing.map { "- \($0): \(fieldValues[$0] ?? "")" }
        lines.insert(contentsOf: inserted, at: insertionIndex)
        if insertionIndex < lines.count, !lines[insertionIndex + inserted.count - 1].isEmpty {
            lines.insert("", at: insertionIndex + inserted.count)
        }

        return normalizedMarkdown(lines)
    }

    private static func matchedField(in bulletBody: String, fields: Set<String>) -> String? {
        for field in fields.sorted(by: { $0.count > $1.count }) {
            if bulletBody == field || bulletBody.hasPrefix("\(field):") || bulletBody.hasPrefix("\(field)：") {
                return field
            }
        }
        return nil
    }

    private static func structuredFieldInsertionIndex(in lines: [String]) -> Int {
        guard let headingIndex = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }) else {
            return 0
        }

        var index = headingIndex + 1
        while index < lines.count, lines[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            index += 1
        }
        return index
    }

    private static func normalizedMarkdown(_ lines: [String]) -> String {
        var result = lines
        while result.last?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            result.removeLast()
        }
        return result.joined(separator: "\n") + "\n"
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

    // MARK: - Public URL Access (used by MemoryLedger)

    static func localURL(for filename: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Vela", isDirectory: true)
            .appendingPathComponent("user_wiki", isDirectory: true)
            .appendingPathComponent(filename)
    }

    @discardableResult
    static func deleteLocalDocuments(
        at directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> Int {
        let directory = directoryURL ?? localURL(for: "profile.md").deletingLastPathComponent()
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }

        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        try fileManager.removeItem(at: directory)
        return contents.count
    }

    static func localDocumentCount(fileManager: FileManager = .default) -> Int {
        let directory = localURL(for: "profile.md").deletingLastPathComponent()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return 0 }
        return contents.filter { $0.pathExtension.lowercased() == "md" }.count
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
        case "constraints.md":
            return "# Constraints\n\n- Injuries: \n- Equipment: \n- Time: \n- Dietary: \n"
        case "preferences.md":
            return "# Preferences\n\n- Training style: \n- Communication style: \n- Dietary preferences: \n"
        case "habits.md":
            return "# Habits\n\n- Caffeine: \n- Alcohol: \n- Evening routine: \n- Morning routine: \n"
        case "training_history.md":
            return "# Training History\n\n- Typical weekly volume: \n- Preferred training types: \n- Past injuries: \n"
        case "health_context.md":
            return "# Health Context\n\n- Known conditions: \n- Medications: \n- Recent changes: \n"
        case "baselines.md":
            return "# Personal Baselines\n\nYour physiological baselines will be computed automatically after 7+ days of data.\n"
        case "observations.md":
            return "# AI Observations\n\nPatterns observed from data but not yet user-confirmed.\n"
        case "strategies.md":
            return "# Active Strategies\n\nCurrent training/recovery strategies in use.\n"
        case "archive.md":
            return "# Archive\n\nSuperseded or expired memories.\n"
        case "diet.md":
            return "# Diet\n\n- Dietary restrictions: \n- Caffeine window: \n- Preferred meals: \n"
        case "sleep.md":
            return "# Sleep\n\n- Sleep environment: \n- Wind-down routine: \n- Targets: \n"
        case "notes.md":
            return "# Notes\n\n"
        default:
            return ""
        }
    }

    static func getAgeFromWiki() -> Int? {
        let dictionary = loadDictionary()
        guard let profileContent = dictionary["profile.md"] else { return nil }
        
        let lines = profileContent.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") {
                let body = String(trimmed.dropFirst(2))
                let colonPrefix = "Age: "
                let spacePrefix = "Age "
                if body.hasPrefix(colonPrefix) {
                    let ageStr = body.dropFirst(colonPrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                    return Int(ageStr)
                } else if body.hasPrefix(spacePrefix) {
                    let ageStr = body.dropFirst(spacePrefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
                    return Int(ageStr)
                }
            }
        }
        
        // As a fallback, use the regex
        let pattern = "(?i)(?:age|年龄)\\s*[:：]\\s*(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsRange = NSRange(profileContent.startIndex..<profileContent.endIndex, in: profileContent)
            if let match = regex.firstMatch(in: profileContent, options: [], range: nsRange) {
                if let range = Range(match.range(at: 1), in: profileContent) {
                    let ageStr = profileContent[range]
                    return Int(ageStr)
                }
            }
        }
        return nil
    }

    static func getMaxHeartRateFromWiki() -> Double? {
        let dictionary = loadDictionary()
        guard let profileContent = dictionary["profile.md"] else { return nil }

        let pattern = "(?i)(?:max(?:imum)?\\s*heart\\s*rate|max\\s*hr|最大心率)\\s*[:：]\\s*(\\d+(?:\\.\\d+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: profileContent,
                range: NSRange(profileContent.startIndex..<profileContent.endIndex, in: profileContent)
              ),
              let range = Range(match.range(at: 1), in: profileContent),
              let maxHeartRate = Double(profileContent[range]),
              (100...240).contains(maxHeartRate) else {
            return nil
        }
        return maxHeartRate
    }
}

enum WikiUpdateMode: String, Hashable {
    case append
    case replace
    case merge
}

@MainActor
public enum WikiSyncManager {
    public static func sync(modelContext: ModelContext) {
        let allDocs = WikiFileService.loadAllDocuments()
        
        let descriptor = FetchDescriptor<UserWikiDocumentRecord>()
        let existingRecords = (try? modelContext.fetch(descriptor)) ?? []
        
        let existingMap = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.filename, $0) })
        
        for doc in allDocs {
            let url = WikiFileService.localURL(for: doc.filename)
            if !FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? doc.content.write(to: url, atomically: true, encoding: .utf8)
            }
            
            if let existing = existingMap[doc.filename] {
                if existing.markdownContent != doc.content {
                    existing.markdownContent = doc.content
                    existing.title = doc.title
                    existing.updatedAt = doc.updatedAt
                }
            } else {
                let record = UserWikiDocumentRecord(
                    filename: doc.filename,
                    title: doc.title,
                    markdownContent: doc.content,
                    updatedAt: doc.updatedAt
                )
                modelContext.insert(record)
            }
        }
        
        let allowedFilenames = Set(allDocs.map(\.filename))
        for record in existingRecords {
            if !allowedFilenames.contains(record.filename) {
                modelContext.delete(record)
            }
        }
        
        try? modelContext.save()
    }
}
