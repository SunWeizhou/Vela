import XCTest
import SwiftData
@testable import Vela

@MainActor
final class MemoryLedgerTests: XCTestCase {
    func testCreateProposalRejectsNonWhitelistedTargetFile() throws {
        // LLM 提供的文件名未经白名单校验时，确认提案会触发对
        // user_wiki 目录外的路径穿越读取（如 "../../Vela.store"）。
        // 提案入口必须复用 WikiFileService 白名单，一处拦截全部三个调用源。
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let ledger = MemoryLedger(modelContext: context)

        XCTAssertThrowsError(try ledger.createProposal(
            targetFile: "../../Vela.store",
            memoryType: .observation,
            content: "Path traversal probe.",
            evidence: "Security regression test.",
            confidence: 0.5,
            source: "test"
        ))
    }

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

    func testProposalCanBeEditedBeforeConfirmationButNotAfter() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let ledger = MemoryLedger(modelContext: context)
        let proposal = try ledger.createProposal(
            targetFile: "notes.md",
            memoryType: .preference,
            content: "Original proposal",
            evidence: "User review",
            confidence: 0.8,
            source: "test"
        )

        try ledger.editProposal(proposal.id, content: "  User-edited proposal  ", userNote: "Corrected wording")

        XCTAssertEqual(proposal.content, "User-edited proposal")
        XCTAssertEqual(proposal.userNote, "Corrected wording")
        XCTAssertEqual(proposal.operation, "edit_proposal")

        proposal.status = MemoryProposalStatus.accepted.rawValue
        try context.save()
        try ledger.editProposal(proposal.id, content: "Must not replace")
        XCTAssertEqual(proposal.content, "User-edited proposal")
    }

    func testConfirmedMemoryFeedsCanonicalFactsAndRollbackRestoresWiki() throws {
        let filename = "notes.md"
        let url = WikiFileService.localURL(for: filename)
        let originalFile = try? String(contentsOf: url, encoding: .utf8)
        let original = "# Notes\n\n- Confirmed seed memory.\n"
        defer {
            if let originalFile {
                try? originalFile.write(to: url, atomically: true, encoding: .utf8)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try original.write(to: url, atomically: true, encoding: .utf8)

        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let ledger = MemoryLedger(modelContext: context)
        let proposal = try ledger.createProposal(
            targetFile: filename,
            memoryType: .preference,
            content: "- Confirmed preference: avoid late high-intensity training.",
            evidence: "User explicitly confirmed this preference.",
            confidence: 0.95,
            source: "test"
        )

        try ledger.confirmProposal(proposal.id)

        let confirmedWiki = WikiFileService.loadDictionary()
        let facts = AIContextBuilder().buildFacts(
            dashboard: .empty(date: Date()),
            journalEntries: [],
            historicalReports: [],
            userWiki: confirmedWiki
        ).snapshot
        XCTAssertTrue(facts.userWiki[filename]?.contains("avoid late high-intensity training") == true)

        try ledger.rollback(recordId: proposal.id)

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), original)
        XCTAssertFalse(WikiFileService.loadDictionary()[filename]?.contains("avoid late high-intensity training") == true)
    }

    func testAutomaticMemoryExtractorExtractsInjuryAndDietarySignals() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext

        let extractor = AutomaticMemoryExtractor(modelContext: context)
        let records = try extractor.extract(from: "右膝肌肉拉伤，今天对咖啡因敏感。")

        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.contains(where: { $0.memoryType == .constraint }))
        XCTAssertTrue(records.contains(where: { $0.memoryType == .preference }))
    }
}
