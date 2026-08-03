import Foundation
import SwiftData

// MARK: - Memory Types

enum MemoryType: String, Codable, Hashable, CaseIterable {
    case fact
    case observation
    case hypothesis
    case strategy
    case preference
    case constraint
    case goalChange
    case baselineUpdate
}

enum MemoryProposalStatus: String, Codable, Hashable, CaseIterable {
    case proposed
    case accepted
    case rejected
    case superseded
    case expired
}

// MARK: - Memory Proposal (created by AI tools, confirmed by user)

struct MemoryProposal: Codable, Hashable, Identifiable {
    var id: UUID
    var createdAt: Date
    var source: String
    var targetFile: String
    var memoryType: MemoryType
    var content: String
    var evidence: String
    var confidence: Double
    var status: MemoryProposalStatus
    var userNote: String?

    var displayTitle: String {
        let prefix: String
        switch memoryType {
        case .fact: prefix = "Fact"
        case .observation: prefix = "Observation"
        case .hypothesis: prefix = "Hypothesis"
        case .strategy: prefix = "Strategy"
        case .preference: prefix = "Preference"
        case .constraint: prefix = "Constraint"
        case .goalChange: prefix = "Goal Change"
        case .baselineUpdate: prefix = "Baseline Update"
        }
        let preview = String(content.prefix(80)).replacingOccurrences(of: "\n", with: " ")
        return "[\(prefix)] \(preview)\(content.count > 80 ? "..." : "")"
    }
}

// MARK: - SwiftData Memory Event Record

@Model
final class MemoryEventRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var source: String
    var targetFile: String
    var memoryTypeRaw: String
    var operation: String
    var content: String
    var evidence: String
    var confidence: Double
    var status: String
    var userNote: String?
    /// Exact pre-apply markdown needed for a real rollback. Hashes alone can
    /// audit a change but cannot restore it.
    var previousContent: String?
    var previousContentHash: String?
    var newContentHash: String?
    var linkedAgentRunId: String?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        source: String,
        targetFile: String,
        memoryType: MemoryType,
        operation: String,
        content: String,
        evidence: String,
        confidence: Double,
        status: MemoryProposalStatus = .proposed,
        userNote: String? = nil,
        previousContent: String? = nil,
        previousContentHash: String? = nil,
        newContentHash: String? = nil,
        linkedAgentRunId: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.targetFile = targetFile
        self.memoryTypeRaw = memoryType.rawValue
        self.operation = operation
        self.content = content
        self.evidence = evidence
        self.confidence = min(1, max(0, confidence))
        self.status = status.rawValue
        self.userNote = userNote
        self.previousContent = previousContent
        self.previousContentHash = previousContentHash
        self.newContentHash = newContentHash
        self.linkedAgentRunId = linkedAgentRunId
    }

    var memoryType: MemoryType {
        MemoryType(rawValue: memoryTypeRaw) ?? .observation
    }

    var proposalStatus: MemoryProposalStatus {
        MemoryProposalStatus(rawValue: status) ?? .proposed
    }

    func toProposal() -> MemoryProposal {
        MemoryProposal(
            id: id,
            createdAt: createdAt,
            source: source,
            targetFile: targetFile,
            memoryType: memoryType,
            content: content,
            evidence: evidence,
            confidence: confidence,
            status: proposalStatus,
            userNote: userNote
        )
    }
}

// MARK: - Agent Run Record (for morning brief / evening wiki sync / coach)

@Model
final class AgentRunRecord {
    @Attribute(.unique) var id: UUID
    var agentName: String
    var startedAt: Date
    var endedAt: Date?
    var status: String
    var reason: String?
    var inputContextHash: String
    var outputSummary: String
    var toolCallsJSON: String
    var errorMessage: String?

    init(
        id: UUID = UUID(),
        agentName: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        status: AgentRunStatus = .running,
        reason: String? = nil,
        inputContextHash: String = "",
        outputSummary: String = "",
        toolCallsJSON: String = "[]",
        errorMessage: String? = nil
    ) {
        self.id = id
        self.agentName = agentName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.status = status.rawValue
        self.reason = reason
        self.inputContextHash = inputContextHash
        self.outputSummary = outputSummary
        self.toolCallsJSON = toolCallsJSON
        self.errorMessage = errorMessage
    }
}

enum AgentRunStatus: String, Codable, Hashable {
    case running
    case success
    case failed
    case skipped
}

// MARK: - Context Snapshot Metadata

struct ContextSnapshotMetadata: Codable, Hashable {
    var schemaVersion: String
    var generatedAt: Date
    var hash: String
    var includedSections: [String]
    var redactedFields: [String]

    static let currentVersion = "v2.0"
}

// MARK: - Context Budget (for dynamic context selection)

struct ContextBudget: Codable, Hashable {
    var maxWikiCharacters: Int = 6000
    var maxJournalEntries: Int = 12
    var maxHistoricalReports: Int = 4
    var maxTrainingPlanDays: Int = 14
    /// Maximum characters for the inline snapshot in the system prompt.
    /// Snapshot content beyond this limit should be available via tools instead.
    var maxSnapshotCharacters: Int = 800
    /// Maximum characters for wiki content in the system prompt.
    var maxWikiPromptCharacters: Int = 3000
    /// Maximum characters for weekly trends in the system prompt.
    var maxTrendsCharacters: Int = 500

    /// Applies budget trimming to wiki text, keeping the most important sections first.
    static func trimWiki(_ wikiText: String, maxChars: Int = 3000) -> String {
        guard wikiText.count > maxChars else { return wikiText }
        // Priority: baselines > goals > profile > constraints > preferences > habits > observations > strategies
        let sections = wikiText.components(separatedBy: "\n### ")
        guard sections.count > 1 else {
            return String(wikiText.prefix(maxChars)) + "\n\n[Wiki truncated to fit context budget. Call update_user_wiki for full access.]"
        }
        let priorityOrder = ["baselines", "goals", "profile", "constraints", "preferences", "habits", "observations", "strategies"]
        var prioritized: [String] = []
        var other: [String] = []
        for section in sections {
            let lower = section.lowercased()
            if priorityOrder.contains(where: { lower.hasPrefix($0) }) {
                prioritized.append(section)
            } else {
                other.append(section)
            }
        }
        prioritized.sort { a, b in
            let ai = priorityOrder.firstIndex(where: { a.lowercased().hasPrefix($0) }) ?? 99
            let bi = priorityOrder.firstIndex(where: { b.lowercased().hasPrefix($0) }) ?? 99
            return ai < bi
        }
        let ordered = prioritized + other
        var result = ""
        for section in ordered {
            let candidate = result.isEmpty ? section : "### \(section)"
            if result.count + candidate.count > maxChars { break }
            result += (result.isEmpty ? "" : "\n") + candidate
        }
        return result + "\n\n[Wiki truncated to fit context budget. Remaining sections available via Wiki profile.]"
    }

    /// Applies budget trimming to weekly trends, keeping the most impactful categories.
    static func trimTrends(_ trendsText: String, maxChars: Int = 500) -> String {
        guard trendsText.count > maxChars else { return trendsText }
        let lines = trendsText.components(separatedBy: "\n")
        let priorityKeywords = ["recovery", "sleep", "strain", "hrv", "rhr", "energy", "stress", "恢复", "睡眠", "负荷", "能量", "压力"]
        var priorityLines: [String] = []
        var otherLines: [String] = []
        for line in lines {
            let lower = line.lowercased()
            if priorityKeywords.contains(where: { lower.contains($0) }) {
                priorityLines.append(line)
            } else {
                otherLines.append(line)
            }
        }
        var result = ""
        for line in priorityLines + otherLines {
            let candidate = result.isEmpty ? line : "\n\(line)"
            if result.count + candidate.count > maxChars { break }
            result += candidate
        }
        return result + "\n[Trends truncated — call get_health_history for full data.]"
    }
}

// MARK: - Wiki File Schema Definition

enum WikiFileRole: String, Codable, Hashable, CaseIterable {
    case profile
    case goals
    case constraints
    case preferences
    case trainingHistory
    case habits
    case baselines
    case observations
    case strategies
    case archive

    var filename: String {
        switch self {
        case .profile: return "profile.md"
        case .goals: return "goals.md"
        case .constraints: return "constraints.md"
        case .preferences: return "preferences.md"
        case .trainingHistory: return "training_history.md"
        case .habits: return "habits.md"
        case .baselines: return "baselines.md"
        case .observations: return "observations.md"
        case .strategies: return "strategies.md"
        case .archive: return "archive.md"
        }
    }

    var title: String {
        switch self {
        case .profile: return "Personal Profile"
        case .goals: return "Goals"
        case .constraints: return "Constraints"
        case .preferences: return "Preferences"
        case .trainingHistory: return "Training History"
        case .habits: return "Habits"
        case .baselines: return "Baselines"
        case .observations: return "AI Observations"
        case .strategies: return "Active Strategies"
        case .archive: return "Archive"
        }
    }

    var isStable: Bool {
        switch self {
        case .profile, .constraints, .trainingHistory: return true
        case .goals, .preferences, .habits: return true
        case .baselines: return true
        case .observations, .strategies: return false
        case .archive: return true
        }
    }

    var memoryType: MemoryType {
        switch self {
        case .profile: return .fact
        case .goals: return .goalChange
        case .constraints: return .constraint
        case .preferences: return .preference
        case .trainingHistory: return .fact
        case .habits: return .observation
        case .baselines: return .baselineUpdate
        case .observations: return .observation
        case .strategies: return .strategy
        case .archive: return .fact
        }
    }

    /// Maps a filename string to its memory type for proposal creation.
    static func memoryTypeFor(filename: String) -> MemoryType {
        WikiFileRole.allCases.first { $0.filename == filename }?.memoryType ?? .observation
    }
}
