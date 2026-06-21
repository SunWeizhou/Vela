import XCTest
import SwiftData
@testable import Vela

@MainActor
final class MemoryLedgerTests: XCTestCase {
    func testCreateProposalClampsConfidenceIntoDisplayableRange() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let ledger = MemoryLedger(modelContext: context)

        let overconfident = try ledger.createProposal(
            targetFile: "profile.md",
            memoryType: .preference,
            content: "User prefers low-impact cardio on recovery days.",
            evidence: "User stated this directly in chat.",
            confidence: 1.42,
            source: "coach_tool"
        )
        let underconfident = MemoryEventRecord(
            source: "direct_test",
            targetFile: "profile.md",
            memoryType: .observation,
            operation: "propose",
            content: "Temporary observation.",
            evidence: "Synthetic test event.",
            confidence: -0.25
        )

        XCTAssertEqual(overconfident.confidence, 1.0, accuracy: 0.001)
        XCTAssertEqual(overconfident.toProposal().confidence, 1.0, accuracy: 0.001)
        XCTAssertEqual(underconfident.confidence, 0.0, accuracy: 0.001)
        XCTAssertEqual(underconfident.toProposal().confidence, 0.0, accuracy: 0.001)
    }

    func testPendingProposalsReturnsNewestProposedOnly() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let ledger = MemoryLedger(modelContext: context)

        let older = try ledger.createProposal(
            targetFile: "profile.md",
            memoryType: .constraint,
            content: "Avoid heavy squats during knee irritation.",
            evidence: "User confirmed knee irritation.",
            confidence: 0.82,
            source: "coach_tool"
        )
        older.createdAt = Date(timeIntervalSinceNow: -60)

        let newer = try ledger.createProposal(
            targetFile: "profile.md",
            memoryType: .goalChange,
            content: "User is prioritizing hypertrophy for the next block.",
            evidence: "User requested a hypertrophy-focused plan.",
            confidence: 0.74,
            source: "coach_tool"
        )
        try ledger.rejectProposal(older.id, reason: "Superseded by newer context.")

        let pending = ledger.pendingProposals()

        XCTAssertEqual(pending.map(\.id), [newer.id])
        XCTAssertEqual(pending.first?.proposalStatus, .proposed)
    }
}
