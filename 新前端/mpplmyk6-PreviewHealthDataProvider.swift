import Foundation

enum PreviewHealthDataProvider {
    static func dailySnapshots(
        days: Int,
        endingAt date: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyHealthSnapshot] {
        let safeDays = max(days, 1)

        return (0..<safeDays).compactMap { offset in
            guard let snapshotDate = calendar.date(byAdding: .day, value: -(safeDays - 1 - offset), to: date) else {
                return nil
            }

            let recovery = 58 + Double((offset * 7) % 24)
            let sleep = 66 + Double((offset * 5) % 18)
            let strain = 32 + Double((offset * 9) % 46)

            return DailyHealthSnapshot(
                date: snapshotDate,
                sleepScore: sleep,
                recoveryScore: recovery,
                strainScore: strain,
                stressIndex: 35 + Double((offset * 3) % 30),
                morningEnergy: (0.65 * recovery) + (0.35 * sleep),
                currentEnergy: max(0, min(100, (0.65 * recovery) + (0.35 * sleep) - (0.45 * strain)))
            )
        }
    }

    static func sleepSummary(for date: Date = Date(), calendar: Calendar = .current) -> SleepSummary {
        let start = calendar.date(bySettingHour: 23, minute: 42, second: 0, of: date.addingTimeInterval(-86_400)) ?? date
        let deepEnd = start.addingTimeInterval(84 * 60)
        let coreEnd = deepEnd.addingTimeInterval(210 * 60)
        let remEnd = coreEnd.addingTimeInterval(92 * 60)
        let awakeEnd = remEnd.addingTimeInterval(18 * 60)

        return SleepSampleNormalizer.summary(
            for: date,
            segments: [
                .init(stage: .deep, start: start, end: deepEnd),
                .init(stage: .core, start: deepEnd, end: coreEnd),
                .init(stage: .rem, start: coreEnd, end: remEnd),
                .init(stage: .awake, start: remEnd, end: awakeEnd)
            ],
            sleepScore: 76
        )
    }
}
