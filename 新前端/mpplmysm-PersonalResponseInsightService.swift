import Foundation
import SwiftData

/// Orchestrates personal response pattern discovery and feeds results into Memory Inbox.
/// Runs during Evening Review or on manual trigger.
@MainActor
struct PersonalResponseInsightService {

    private let model: PersonalResponseModel

    init() {
        self.model = PersonalResponseModel()
    }

    /// Full pipeline: discover rules → dedup → MemoryProposal → Inbox.
    /// Returns the number of new proposals created.
    func scanAndPropose(
        modelContext: ModelContext,
        snapshots: [DailyHealthSnapshot],
        journalEntries: [JournalEntryRecord],
        foodLogs: [FoodLogRecord],
        existingRules: [MemoryEventRecord] = []
    ) throws -> Int {
        // 1. Discover rules
        let discovered = model.discoverRules(
            snapshots: snapshots,
            journalEntries: journalEntries,
            foodLogs: foodLogs
        )

        guard !discovered.isEmpty else { return 0 }

        // 2. Dedup against existing confirmed rules
        let existingRuleNames = Set(existingRules
            .filter { $0.status == MemoryProposalStatus.accepted.rawValue }
            .compactMap { extractRuleName(from: $0.content) }
        )

        let newRules = discovered.filter { rule in
            !existingRuleNames.contains(rule.name)
        }

        // 3. Generate MemoryProposals via MemoryLedger
        let ledger = MemoryLedger(modelContext: modelContext)
        var created = 0
        for rule in newRules {
            let content = buildProposalContent(from: rule)
            let evidence = rule.evidenceSummary
            _ = try? ledger.createProposal(
                targetFile: "observations.md",
                memoryType: .observation,
                content: content,
                evidence: evidence,
                confidence: rule.confidence,
                source: "personal_response_model",
                linkedAgentRunId: nil
            )
            created += 1
        }

        // 4. Expire old pending proposals
        try? ledger.expireOldPendingProposals(olderThan: 30)

        return created
    }

    // MARK: - Helpers

    private func extractRuleName(from content: String) -> String? {
        // Content format: "**Rule**: rule_name\n..."
        guard let range = content.range(of: "**Rule**: ") else { return nil }
        let after = content[range.upperBound...]
        return after.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces)
    }

    private func buildProposalContent(from rule: PersonalResponseModel.PersonalRule) -> String {
        let lang = AppLanguage.stored
        if lang.isChinese {
            return """
            **规律**: \(rule.name)
            **触发条件**: \(rule.trigger)
            **效果**: \(rule.effect)
            **置信度**: \(String(format: "%.0f", rule.confidence * 100))%
            **观察次数**: \(rule.occurrenceCount) 次
            **证据**: \(rule.evidenceSummary)
            """
        }
        return """
        **Rule**: \(rule.name)
        **Trigger**: \(rule.trigger)
        **Effect**: \(rule.effect)
        **Confidence**: \(String(format: "%.0f", rule.confidence * 100))%
        **Occurrences**: \(rule.occurrenceCount)
        **Evidence**: \(rule.evidenceSummary)
        """
    }
}
