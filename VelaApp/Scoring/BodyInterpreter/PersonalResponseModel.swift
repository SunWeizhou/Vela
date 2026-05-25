import Foundation
import SwiftData

/// Learns individual response patterns from historical health data.
/// Discovers personal rules like:
/// - "low sleep + high intensity → next-day HRV drop"
/// - "caffeine after 2 PM → reduced sleep efficiency"
/// - "high strain 2 consecutive days → requires deload"
struct PersonalResponseModel {

    struct PersonalRule: Codable, Hashable, Identifiable {
        var id: UUID = UUID()
        var name: String
        var trigger: String
        var effect: String
        var confidence: Double
        var occurrenceCount: Int
        var evidenceSummary: String
        var discoveredAt: Date
        var lastObservedAt: Date
        var status: MemoryProposalStatus = .proposed
    }

    /// Analyzes health snapshots and journal entries to discover personal patterns.
    func discoverRules(
        snapshots: [DailyHealthSnapshot],
        journalEntries: [JournalEntryRecord],
        foodLogs: [FoodLogRecord]
    ) -> [PersonalRule] {
        var rules: [PersonalRule] = []

        guard snapshots.count >= 7 else { return rules }

        rules.append(contentsOf: detectSleepIntensityHRVRule(snapshots: snapshots))
        rules.append(contentsOf: detectConsecutiveStrainRule(snapshots: snapshots))
        rules.append(contentsOf: detectCaffeineSleepRule(snapshots: snapshots, journalEntries: journalEntries))
        rules.append(contentsOf: detectStressRecoveryRule(snapshots: snapshots))
        rules.append(contentsOf: detectHydrationRecoveryRule(snapshots: snapshots, journalEntries: journalEntries))

        return rules.filter { $0.confidence >= 0.4 }
    }

    // MARK: - Pattern Detectors

    /// "Low sleep + high-intensity day → next-day HRV drops > 15%"
    private func detectSleepIntensityHRVRule(snapshots: [DailyHealthSnapshot]) -> [PersonalRule] {
        guard snapshots.count >= 14 else { return [] }

        var triggeredCount = 0
        var totalHRVDrop = 0.0
        var eligiblePairs = 0

        for i in 1..<snapshots.count {
            let today = snapshots[i]
            let yesterday = snapshots[i-1]

            guard let todayHRV = today.hrvAverage,
                  let yesterdayHRV = yesterday.hrvAverage,
                  yesterdayHRV > 0,
                  let yesterdaySleep = yesterday.sleepScore,
                  let yesterdayStrain = yesterday.strainScore else { continue }

            let hrvDrop = (yesterdayHRV - todayHRV) / yesterdayHRV

            if yesterdaySleep < 75 && yesterdayStrain > 60 {
                eligiblePairs += 1
                if hrvDrop > 0.15 {
                    triggeredCount += 1
                    totalHRVDrop += hrvDrop
                }
            }
        }

        guard eligiblePairs >= 3, triggeredCount >= 2 else { return [] }

        let confidence = min(Double(triggeredCount) / Double(eligiblePairs), 1.0)
        let avgDrop = totalHRVDrop / Double(max(triggeredCount, 1))

        return [PersonalRule(
            name: "low_sleep_high_intensity_causes_next_day_hrv_drop",
            trigger: "Sleep score < 75 + Strain > 60 on the same day",
            effect: "Next-day HRV drops by \(String(format: "%.0f", avgDrop * 100))% on average",
            confidence: confidence,
            occurrenceCount: triggeredCount,
            evidenceSummary: "In \(triggeredCount) of \(eligiblePairs) low-sleep + high-strain days, next-day HRV dropped significantly (avg \(String(format: "%.0f", avgDrop * 100))%).",
            discoveredAt: Date(),
            lastObservedAt: Date()
        )]
    }

    /// "Two consecutive high-strain days → requires deload on day 3"
    private func detectConsecutiveStrainRule(snapshots: [DailyHealthSnapshot]) -> [PersonalRule] {
        guard snapshots.count >= 14 else { return [] }

        var triggeredCount = 0
        var eligibleSequences = 0
        var recoveryDropSum = 0.0

        for i in 2..<snapshots.count {
            let day1 = snapshots[i-2]
            let day2 = snapshots[i-1]
            let day3 = snapshots[i]

            guard let strain1 = day1.strainScore,
                  let strain2 = day2.strainScore,
                  let recovery3 = day3.recoveryScore,
                  let recovery2 = day2.recoveryScore else { continue }

            if strain1 > 60 && strain2 > 50 {
                eligibleSequences += 1
                let recoveryDrop = recovery2 - recovery3
                if recoveryDrop > 10 {
                    triggeredCount += 1
                    recoveryDropSum += recoveryDrop
                }
            }
        }

        guard eligibleSequences >= 3, triggeredCount >= 2 else { return [] }

        let confidence = min(Double(triggeredCount) / Double(eligibleSequences), 1.0)

        return [PersonalRule(
            name: "high_strain_two_days_requires_deload",
            trigger: "Strain > 60 on Day 1 AND Strain > 50 on Day 2",
            effect: "Day 3 recovery drops by \(String(format: "%.0f", recoveryDropSum / Double(max(triggeredCount, 1)))) pts on average",
            confidence: confidence,
            occurrenceCount: triggeredCount,
            evidenceSummary: "In \(triggeredCount) of \(eligibleSequences) two-day high-strain sequences, Day 3 recovery dropped significantly.",
            discoveredAt: Date(),
            lastObservedAt: Date()
        )]
    }

    /// "Caffeine after 2 PM → sleep efficiency < 85%"
    private func detectCaffeineSleepRule(
        snapshots: [DailyHealthSnapshot],
        journalEntries: [JournalEntryRecord]
    ) -> [PersonalRule] {
        let caffeineEntries = journalEntries.filter { entry in
            entry.tags.contains("caffeine") || entry.tags.contains("咖啡因")
        }

        guard caffeineEntries.count >= 5, snapshots.count >= 10 else { return [] }

        // Match caffeine days with sleep efficiency
        var caffeineDays = 0
        var poorSleepDays = 0

        let calendar = Calendar.current
        for entry in caffeineEntries {
            let entryDay = calendar.startOfDay(for: entry.createdAt)
            // Check sleep on the night OF that day (next day's snapshot)
            if let snapshot = snapshots.first(where: { calendar.startOfDay(for: $0.date) == entryDay }),
               let sleepEff = snapshot.sleepEfficiency,
               sleepEff > 0 {
                caffeineDays += 1
                if sleepEff < 85 {
                    poorSleepDays += 1
                }
            }
        }

        guard caffeineDays >= 5, poorSleepDays >= 2 else { return [] }

        let confidence = min(Double(poorSleepDays) / Double(caffeineDays), 1.0)

        return [PersonalRule(
            name: "caffeine_after_2pm_reduces_sleep_efficiency",
            trigger: "Caffeine intake logged (afternoon/evening)",
            effect: "Sleep efficiency below 85% in \(poorSleepDays) of \(caffeineDays) caffeine days",
            confidence: confidence,
            occurrenceCount: poorSleepDays,
            evidenceSummary: "On \(poorSleepDays) out of \(caffeineDays) days with caffeine, sleep efficiency was below 85%.",
            discoveredAt: Date(),
            lastObservedAt: Date()
        )]
    }

    /// "High stress index → recovery score drops next day"
    private func detectStressRecoveryRule(snapshots: [DailyHealthSnapshot]) -> [PersonalRule] {
        guard snapshots.count >= 14 else { return [] }

        var highStressDays = 0
        var recoveryDropDays = 0

        for i in 1..<snapshots.count {
            let yesterday = snapshots[i-1]
            let today = snapshots[i]

            guard let yesterdayStress = yesterday.stressIndex,
                  let yesterdayRecovery = yesterday.recoveryScore,
                  let todayRecovery = today.recoveryScore else { continue }

            if yesterdayStress > 50 {
                highStressDays += 1
                if todayRecovery < yesterdayRecovery - 5 {
                    recoveryDropDays += 1
                }
            }
        }

        guard highStressDays >= 5, recoveryDropDays >= 2 else { return [] }

        let confidence = min(Double(recoveryDropDays) / Double(highStressDays), 1.0)

        return [PersonalRule(
            name: "high_stress_causes_recovery_drop",
            trigger: "Stress index > 50",
            effect: "Next-day recovery drops in \(recoveryDropDays) of \(highStressDays) high-stress days",
            confidence: confidence,
            occurrenceCount: recoveryDropDays,
            evidenceSummary: "On \(recoveryDropDays) out of \(highStressDays) high-stress days, recovery dropped the next day.",
            discoveredAt: Date(),
            lastObservedAt: Date()
        )]
    }

    /// "Low hydration → reduced recovery"
    private func detectHydrationRecoveryRule(
        snapshots: [DailyHealthSnapshot],
        journalEntries: [JournalEntryRecord]
    ) -> [PersonalRule] {
        let hydrationEntries = journalEntries.filter { entry in
            entry.tags.contains("hydration") || entry.tags.contains("补水") ||
            entry.note.lowercased().contains("water") || entry.note.contains("水")
        }
        guard hydrationEntries.count >= 5, snapshots.count >= 10 else { return [] }

        var lowHydrationDays = 0
        var lowRecoveryDays = 0
        let calendar = Calendar.current

        for entry in hydrationEntries {
            let entryDay = calendar.startOfDay(for: entry.createdAt)
            if let snapshot = snapshots.first(where: { calendar.startOfDay(for: $0.date) == entryDay }),
               let recovery = snapshot.recoveryScore {
                lowHydrationDays += 1
                if recovery < 60 {
                    lowRecoveryDays += 1
                }
            }
        }

        guard lowHydrationDays >= 5, lowRecoveryDays >= 2 else { return [] }

        return [PersonalRule(
            name: "low_hydration_correlates_with_low_recovery",
            trigger: "Water intake logged as low",
            effect: "Recovery below 60 in \(lowRecoveryDays) of \(lowHydrationDays) low-hydration days",
            confidence: min(Double(lowRecoveryDays) / Double(lowHydrationDays), 1.0),
            occurrenceCount: lowRecoveryDays,
            evidenceSummary: "On \(lowRecoveryDays) out of \(lowHydrationDays) low-hydration days, recovery was below 60.",
            discoveredAt: Date(),
            lastObservedAt: Date()
        )]
    }
}
