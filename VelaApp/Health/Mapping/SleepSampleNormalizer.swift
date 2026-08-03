import Foundation

enum SleepSampleNormalizer {
    static func summary(
        for date: Date,
        segments: [SleepStageSegment],
        sleepScore: Double? = nil
    ) -> SleepSummary {
        let sortedSegments = segments.sorted { $0.start < $1.start }
        let stageMinutes = Dictionary(grouping: sortedSegments, by: \.stage)
            .mapValues { segments in
                segments.reduce(0) { $0 + $1.durationMinutes }
            }

        let totalSleepMinutes = sortedSegments.reduce(0) { partial, segment in
            guard segment.stage.countsTowardSleepDuration else { return partial }
            return partial + segment.durationMinutes
        }

        return SleepSummary(
            date: date,
            totalSleepMinutes: totalSleepMinutes,
            bedtime: sortedSegments.first?.start,
            wakeTime: sortedSegments.last?.end,
            stageMinutes: stageMinutes,
            segments: sortedSegments,
            sleepScore: sleepScore
        )
    }

    static func mostRecentEpisodeSummary(
        for date: Date,
        segments: [SleepStageSegment],
        sleepScore: Double? = nil,
        maximumGapMinutes: Int = 120
    ) -> SleepSummary? {
        let sortedSegments = segments
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard !sortedSegments.isEmpty else { return nil }

        let maximumGap = TimeInterval(maximumGapMinutes * 60)
        var episodes: [[SleepStageSegment]] = []
        var currentEpisode: [SleepStageSegment] = []

        for segment in sortedSegments {
            if let previous = currentEpisode.last,
               segment.start.timeIntervalSince(previous.end) > maximumGap {
                episodes.append(currentEpisode)
                currentEpisode = [segment]
            } else {
                currentEpisode.append(segment)
            }
        }

        if !currentEpisode.isEmpty {
            episodes.append(currentEpisode)
        }

        guard let latestSleepEpisode = episodes
            .filter({ episode in
                episode.contains { $0.stage.countsTowardSleepDuration }
            })
            .max(by: { lhs, rhs in
                (lhs.last?.end ?? .distantPast) < (rhs.last?.end ?? .distantPast)
            })
        else {
            return nil
        }

        return summary(for: date, segments: latestSleepEpisode, sleepScore: sleepScore)
    }

    static func allNightlyEpisodes(
        segments: [SleepStageSegment],
        maximumGapMinutes: Int = 120
    ) -> [SleepSummary] {
        let sortedSegments = segments
            .filter { $0.end > $0.start }
            .sorted { $0.start < $1.start }
        guard !sortedSegments.isEmpty else { return [] }

        let calendar = Calendar.current
        let boundary = HealthDayBoundary(calendar: calendar)
        let maximumGap = TimeInterval(maximumGapMinutes * 60)
        var episodes: [[SleepStageSegment]] = []
        var currentEpisode: [SleepStageSegment] = []

        for segment in sortedSegments {
            if let previous = currentEpisode.last,
               segment.start.timeIntervalSince(previous.end) > maximumGap {
                episodes.append(currentEpisode)
                currentEpisode = [segment]
            } else {
                currentEpisode.append(segment)
            }
        }
        if !currentEpisode.isEmpty {
            episodes.append(currentEpisode)
        }

        return episodes.compactMap { episode in
            guard episode.contains(where: { $0.stage.countsTowardSleepDuration }),
                  let lastSegment = episode.last else { return nil }
            let date = boundary.labelDate(containing: lastSegment.end)
            return summary(for: date, segments: episode)
        }
    }
}
