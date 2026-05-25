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
        self.confidence = confidence
        self.status = status.rawValue
        self.userNote = userNote
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
}
