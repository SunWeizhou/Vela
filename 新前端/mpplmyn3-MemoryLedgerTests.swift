import XCTest
import SwiftData
@testable import Vela

@MainActor
final class MemoryLedgerTests: XCTestCase {

    var modelContainer: ModelContainer!
    var modelContext: ModelContext!

    override func setUp() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: MemoryEventRecord.self, AgentRunRecord.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
    }

    override func tearDown() {
        modelContext = nil
        modelContainer = nil
    }

    // MARK: - Create Proposal

    func testCreateProposalSavesToSwiftData() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        let record = try ledger.createProposal(
            targetFile: "habits.md",
            memoryType: .observation,
            content: "Caffeine after 2 PM correlates with reduced REM sleep.",
            evidence: "14-day pattern: 8 of 10 late-caffeine days had REM < 18%.",
            confidence: 0.75,
            source: "test"
        )

        XCTAssertEqual(record.status, "proposed")
        XCTAssertEqual(record.targetFile, "habits.md")
        XCTAssertEqual(record.memoryType, .observation)
        XCTAssertEqual(record.confidence, 0.75)

        let pending = ledger.pendingProposals()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, record.id)
    }

    func testCreateMultipleProposals() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        _ = try ledger.createProposal(
            targetFile: "habits.md", memoryType: .observation,
            content: "Meditation improves sleep onset.", evidence: "10-day data",
            confidence: 0.8, source: "test"
        )
        _ = try ledger.createProposal(
            targetFile: "goals.md", memoryType: .goalChange,
            content: "New goal: increase VO2 max by 5%.", evidence: "User stated goal in conversation.",
            confidence: 0.95, source: "test"
        )

        let pending = ledger.pendingProposals()
        XCTAssertEqual(pending.count, 2)
    }

    // MARK: - Confirm

    func testConfirmProposalChangesStatus() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        let record = try ledger.createProposal(
            targetFile: "habits.md", memoryType: .observation,
            content: "Test observation", evidence: "test",
            confidence: 0.7, source: "test"
        )

        try ledger.confirmProposal(record.id)

        let pending = ledger.pendingProposals()
        XCTAssertEqual(pending.count, 0, "Confirmed proposal should not be pending")

        let history = ledger.history(for: "habits.md")
        let confirmed = history.first { $0.id == record.id }
        XCTAssertNotNil(confirmed)
        XCTAssertEqual(confirmed?.status, "accepted")
    }

    // MARK: - Reject

    func testRejectProposalChangesStatus() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        let record = try ledger.createProposal(
            targetFile: "habits.md", memoryType: .hypothesis,
            content: "Unlikely pattern", evidence: "weak",
            confidence: 0.3, source: "test"
        )

        try ledger.rejectProposal(record.id, reason: "Not enough evidence")

        let pending = ledger.pendingProposals()
        XCTAssertEqual(pending.count, 0)

        let history = ledger.history(for: "habits.md")
        let rejected = history.first { $0.id == record.id }
        XCTAssertEqual(rejected?.status, "rejected")
        XCTAssertEqual(rejected?.userNote, "Not enough evidence")
    }

    // MARK: - Rollback

    func testRollbackMarksAsSuperseded() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        let record = try ledger.createProposal(
            targetFile: "habits.md", memoryType: .observation,
            content: "Content to rollback", evidence: "test",
            confidence: 0.8, source: "test"
        )
        try ledger.confirmProposal(record.id)

        try ledger.rollback(recordId: record.id)

        let history = ledger.history(for: "habits.md")
        let rolledBack = history.first { $0.id == record.id }
        XCTAssertEqual(rolledBack?.status, "superseded")
    }

    // MARK: - Expire

    func testExpireOldPendingProposals() throws {
        let ledger = MemoryLedger(modelContext: modelContext)
        // Create proposals with old dates by directly inserting
        let oldRecord = MemoryEventRecord(
            createdAt: Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
            source: "test", targetFile: "habits.md",
            memoryType: .observation, operation: "propose",
            content: "Old proposal", evidence: "old",
            confidence: 0.5, status: .proposed
        )
        modelContext.insert(oldRecord)
        try modelContext.save()

        try ledger.expireOldPendingProposals(olderThan: 14)

        let pending = ledger.pendingProposals()
        XCTAssertEqual(pending.count, 0, "Old pending proposals should be expired")
    }
}
