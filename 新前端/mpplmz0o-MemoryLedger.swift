import Foundation
import SwiftData
import os.log

private let logger = Logger(subsystem: "com.sunweizhou.Vela", category: "MemoryLedger")

/// Manages the memory proposal lifecycle: create, confirm, reject, rollback.
/// Stores proposals as MemoryEventRecord in SwiftData and writes confirmed
/// entries to wiki markdown files.
@MainActor
final class MemoryLedger {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create Proposal

    func createProposal(
        targetFile: String,
        memoryType: MemoryType,
        content: String,
        evidence: String,
        confidence: Double,
        source: String,
        linkedAgentRunId: String? = nil
    ) throws -> MemoryEventRecord {
        let record = MemoryEventRecord(
            source: source,
            targetFile: targetFile,
            memoryType: memoryType,
            operation: "propose",
            content: content,
            evidence: evidence,
            confidence: confidence,
            status: .proposed,
            linkedAgentRunId: linkedAgentRunId
        )
        modelContext.insert(record)
        try modelContext.save()
        logger.info("Memory proposal created: \(targetFile) [\(memoryType.rawValue)]")
        return record
    }

    // MARK: - Confirm (accept proposal → write to wiki)

    func confirmProposal(_ proposalId: UUID) throws {
        let descriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.id == proposalId }
        )
        guard let record = try modelContext.fetch(descriptor).first else {
            logger.warning("Proposal \(proposalId) not found for confirmation.")
            return
        }

        guard record.status == MemoryProposalStatus.proposed.rawValue else {
            logger.warning("Proposal \(proposalId) is not in 'proposed' status.")
            return
        }

        // Write to wiki markdown file
        let previousContent = (try? String(contentsOf: WikiFileService.localURL(for: record.targetFile), encoding: .utf8)) ?? ""
        record.previousContentHash = ContentHash.hash(previousContent)

        try WikiFileService.updateSection(
            filename: record.targetFile,
            content: record.content,
            mode: .merge
        )

        let newContent = (try? String(contentsOf: WikiFileService.localURL(for: record.targetFile), encoding: .utf8)) ?? ""
        record.newContentHash = ContentHash.hash(newContent)
        record.status = MemoryProposalStatus.accepted.rawValue
        record.operation = "apply"
        try modelContext.save()

        logger.info("Memory proposal confirmed and written: \(record.targetFile)")
    }

    // MARK: - Reject Proposal

    func rejectProposal(_ proposalId: UUID, reason: String? = nil) throws {
        let descriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.id == proposalId }
        )
        guard let record = try modelContext.fetch(descriptor).first else { return }
        record.status = MemoryProposalStatus.rejected.rawValue
        record.userNote = reason
        record.operation = "reject"
        try modelContext.save()
        logger.info("Memory proposal rejected: \(proposalId)")
    }

    // MARK: - Rollback (revert a confirmed memory)

    func rollback(recordId: UUID) throws {
        let descriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.id == recordId }
        )
        guard let record = try modelContext.fetch(descriptor).first,
              record.status == MemoryProposalStatus.accepted.rawValue else {
            logger.warning("Cannot rollback: record \(recordId) is not in accepted state.")
            return
        }

        record.status = MemoryProposalStatus.superseded.rawValue
        record.operation = "rollback"
        try modelContext.save()
        logger.info("Memory record rolled back: \(recordId)")
    }

    // MARK: - Query

    func pendingProposals() -> [MemoryEventRecord] {
        let descriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.status == "proposed" },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func history(for filename: String, limit: Int = 50) -> [MemoryEventRecord] {
        var descriptor = FetchDescriptor<MemoryEventRecord>(
            predicate: #Predicate { $0.targetFile == filename },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func allRecords(limit: Int = 100) -> [MemoryEventRecord] {
        var descriptor = FetchDescriptor<MemoryEventRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Cleanup (auto-expire old pending proposals)

    func expireOldPendingProposals(olderThan days: Int = 14) throws {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let pending = pendingProposals()
        for record in pending where record.createdAt < cutoff {
            record.status = MemoryProposalStatus.expired.rawValue
        }
        try modelContext.save()
        logger.info("Expired \(pending.filter { $0.createdAt < cutoff }.count) old pending proposals.")
    }
}

// MARK: - Content Hash Helper

enum ContentHash {
    /// Computes a stable content hash for deduplication and change detection.
    static func hash(_ string: String) -> String {
        let input = string.data(using: .utf8) ?? Data()
        // FNV-1a 64-bit hash — fast, stable, no external dependencies
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in input {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        // Mix in the length for extra spread
        hash ^= UInt64(input.count)
        return String(format: "%016llx", hash)
    }
}
