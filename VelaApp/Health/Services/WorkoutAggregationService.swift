import Foundation
import SwiftData

@MainActor
public final class WorkoutAggregationService {
    public static let shared = WorkoutAggregationService()
    private static let duplicateTimeTolerance: TimeInterval = 120
    
    private init() {}
    
    /// Merges HealthKit synced workouts with manual and strength workouts in SwiftData for a clean consolidated list.
    public func aggregateWorkouts(
        healthKitWorkouts: [WorkoutSummary],
        for date: Date,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) -> [WorkoutSummary] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        let descriptor = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> {
                $0.startedAt >= dayStart && $0.startedAt < dayEnd
            },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        
        let localRecords = consolidateLocalEvents((try? modelContext.fetch(descriptor)) ?? [])
        
        var merged: [WorkoutSummary] = []
        
        // 1. Keep HealthKit workouts unless a mirrored WorkoutEventRecord already represents them.
        for hk in healthKitWorkouts {
            if !localRecords.contains(where: { localRecordRepresentsHealthKitWorkout($0, hk) }) {
                merged.append(WorkoutSummary(
                    id: hk.id,
                    start: hk.start,
                    end: hk.end,
                    activityName: hk.activityName,
                    energyKilocalories: hk.energyKilocalories,
                    averageHeartRate: hk.averageHeartRate,
                    distanceMeters: hk.distanceMeters,
                    source: hk.source ?? "healthKit",
                    rpe: hk.rpe
                ))
            }
        }
        
        // 2. Add local records (manual / strength / xunji / HealthKit mirrors).
        for local in localRecords {
            let matchedHK = healthKitWorkouts.first { localRecordRepresentsHealthKitWorkout(local, $0) }
            let useHealthKitTiming = local.linkedHealthKitWorkoutId != nil && matchedHK != nil
            let useLocalDisplay = local.linkedStrengthWorkoutId != nil
            
            merged.append(WorkoutSummary(
                id: local.id,
                start: useHealthKitTiming ? matchedHK?.start ?? local.startedAt : local.startedAt,
                end: useHealthKitTiming ? matchedHK?.end ?? local.endedAt : local.endedAt,
                activityName: useLocalDisplay ? local.title : (useHealthKitTiming ? matchedHK?.activityName ?? local.activityType : local.activityType),
                energyKilocalories: local.energyKilocalories ?? matchedHK?.energyKilocalories,
                averageHeartRate: local.averageHeartRate ?? matchedHK?.averageHeartRate,
                distanceMeters: matchedHK?.distanceMeters,
                source: local.source,
                rpe: local.rpe
            ))
        }
        
        return deduplicateSummaries(merged).sorted { $0.start < $1.start }
    }

    public func upsertHealthKitWorkoutEvents(
        _ healthKitWorkouts: [WorkoutSummary],
        on date: Date,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        // 1. Identify and remove any previously synced HealthKit workouts for this day that are no longer in healthKitWorkouts payload
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        
        let descriptor = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> {
                $0.startedAt >= dayStart && $0.startedAt < dayEnd
            }
        )
        let existingEvents = (try? modelContext.fetch(descriptor)) ?? []
        let currentHKIDs = Set(healthKitWorkouts.map { $0.id })
        
        for event in existingEvents {
            if let hkId = event.linkedHealthKitWorkoutId, !currentHKIDs.contains(hkId) {
                if event.linkedStrengthWorkoutId != nil {
                    event.linkedHealthKitWorkoutId = nil
                    event.source = "strengthLog"
                    event.updatedAt = Date()
                } else {
                    modelContext.delete(event)
                }
            }
        }

        // 2. Upsert current HealthKit workouts
        for workout in healthKitWorkouts {
            let healthKitID = workout.id
            let fetchDescriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.linkedHealthKitWorkoutId == healthKitID }
            )
            let event: WorkoutEventRecord
            if let existing = try modelContext.fetch(fetchDescriptor).first {
                event = existing
                event.startedAt = workout.start
                event.endedAt = workout.end
                event.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: workout.start, calendar: calendar)
                if existing.linkedStrengthWorkoutId == nil {
                    event.activityType = workout.activityName
                    event.title = workout.activityName
                }
                event.durationMinutes = max(0, workout.end.timeIntervalSince(workout.start) / 60)
                event.energyKilocalories = workout.energyKilocalories
                event.averageHeartRate = workout.averageHeartRate
                event.linkedHealthKitWorkoutId = healthKitID
                event.source = resolvedSource(for: event)
                event.updatedAt = Date()
            } else if let matched = try findMergeCandidate(for: workout, modelContext: modelContext, calendar: calendar) {
                event = matched
                event.startedAt = workout.start
                event.endedAt = workout.end
                event.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: workout.start, calendar: calendar)
                if event.linkedStrengthWorkoutId != nil {
                    event.activityType = event.title
                }
                event.durationMinutes = max(0, workout.end.timeIntervalSince(workout.start) / 60)
                event.energyKilocalories = workout.energyKilocalories
                event.averageHeartRate = workout.averageHeartRate
                event.linkedHealthKitWorkoutId = healthKitID
                event.source = resolvedSource(for: event)
                event.updatedAt = Date()
            } else {
                event = WorkoutEventRecord(
                    id: workout.id,
                    source: "healthKit",
                    startedAt: workout.start,
                    endedAt: workout.end,
                    activityType: workout.activityName,
                    energyKilocalories: workout.energyKilocalories,
                    averageHeartRate: workout.averageHeartRate,
                    linkedHealthKitWorkoutId: workout.id,
                    calendar: calendar
                )
                modelContext.insert(event)
            }
        }
        try modelContext.save()
    }

    func mergeStrengthWorkoutDetails(
        event: WorkoutEventRecord,
        strengthWorkout: StrengthWorkoutRecord,
        displayTitle: String,
        sessionRPE: Double?,
        calendar: Calendar = .current
    ) {
        event.linkedStrengthWorkoutId = strengthWorkout.id
        event.activityType = displayTitle
        event.title = displayTitle
        event.rpe = event.rpe ?? sessionRPE
        event.source = resolvedSource(for: event)
        event.updatedAt = Date()
        strengthWorkout.linkedWorkoutEventId = event.id
    }

    func findMergeCandidate(
        for strengthWorkout: StrengthWorkoutRecord,
        in events: [WorkoutEventRecord],
        calendar: Calendar = .current
    ) -> WorkoutEventRecord? {
        events
            .compactMap { event -> (event: WorkoutEventRecord, score: Double)? in
                guard event.linkedStrengthWorkoutId == nil || event.linkedStrengthWorkoutId == strengthWorkout.id else {
                    return nil
                }
                guard event.linkedHealthKitWorkoutId != nil || event.source == "healthKit" else {
                    return nil
                }
                guard strengthEventRepresentsSameRealWorkout(event, strengthWorkout, calendar: calendar) else {
                    return nil
                }
                return (event, strengthMergeScore(event: event, strengthWorkout: strengthWorkout))
            }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.event.updatedAt > rhs.event.updatedAt
                }
                return lhs.score > rhs.score
            }
            .first?
            .event
    }

    @discardableResult
    func upsertWorkoutEvent(
        from strengthWorkout: StrengthWorkoutRecord,
        modelContext: ModelContext,
        sessionRPE: Double? = nil,
        calendar: Calendar = .current
    ) throws -> WorkoutEventRecord {
        let event = try prepareWorkoutEvent(
            from: strengthWorkout,
            modelContext: modelContext,
            sessionRPE: sessionRPE,
            calendar: calendar
        )
        try aggregateDay(date: strengthWorkout.startedAt, modelContext: modelContext, calendar: calendar)
        try modelContext.save()
        return event
    }

    @discardableResult
    func prepareWorkoutEvent(
        from strengthWorkout: StrengthWorkoutRecord,
        modelContext: ModelContext,
        sessionRPE: Double? = nil,
        calendar: Calendar = .current
    ) throws -> WorkoutEventRecord {
        let workoutID = strengthWorkout.id
        let descriptor = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> { $0.linkedStrengthWorkoutId == workoutID }
        )
        let resolvedRPE = sessionRPE ?? strengthWorkout.sessionRPE
        let event: WorkoutEventRecord
        if let existing = try modelContext.fetch(descriptor).first {
            event = existing
            event.startedAt = strengthWorkout.startedAt
            event.endedAt = strengthWorkout.endedAt
            event.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: strengthWorkout.startedAt, calendar: calendar)
            event.activityType = strengthWorkout.title
            event.title = strengthWorkout.title
            event.durationMinutes = Double(strengthWorkout.durationMinutes)
            event.energyKilocalories = event.energyKilocalories ?? Double(strengthWorkout.durationMinutes) * 6
            event.rpe = resolvedRPE
            event.updatedAt = Date()
        } else {
            // Find if there is an overlapping HealthKit event to merge with (30 mins range)
            let dayStart = calendar.startOfDay(for: strengthWorkout.startedAt)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let overlapDescriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> {
                    $0.startedAt >= dayStart && $0.startedAt < dayEnd && $0.linkedStrengthWorkoutId == nil
                }
            )
            let existingEvents = (try? modelContext.fetch(overlapDescriptor)) ?? []
            if let matched = findMergeCandidate(for: strengthWorkout, in: existingEvents, calendar: calendar) {
                event = matched
                event.linkedStrengthWorkoutId = strengthWorkout.id
                event.title = strengthWorkout.title
                event.activityType = strengthWorkout.title
                event.rpe = event.rpe ?? resolvedRPE
                event.source = resolvedSource(for: event)
                event.updatedAt = Date()
            } else {
                event = WorkoutEventRecord(
                    source: "strengthLog",
                    startedAt: strengthWorkout.startedAt,
                    endedAt: strengthWorkout.endedAt,
                    activityType: strengthWorkout.title,
                    energyKilocalories: Double(strengthWorkout.durationMinutes) * 6,
                    rpe: resolvedRPE,
                    linkedStrengthWorkoutId: strengthWorkout.id,
                    calendar: calendar
                )
                modelContext.insert(event)
            }
        }
        strengthWorkout.linkedWorkoutEventId = event.id
        strengthWorkout.sessionRPE = resolvedRPE
        strengthWorkout.completedAt = strengthWorkout.endedAt
        try linkActivePlanDay(for: event, strengthWorkout: strengthWorkout, modelContext: modelContext, calendar: calendar)
        return event
    }

    public func aggregateDay(
        date: Date,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let dayStart = calendar.startOfDay(for: date)
        let identifier = DailyHealthSummaryRecord.dayIdentifier(for: dayStart, calendar: calendar)
        let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
            predicate: #Predicate<DailyHealthSummaryRecord> { $0.dayIdentifier == identifier }
        )
        let record: DailyHealthSummaryRecord
        if let existing = try modelContext.fetch(descriptor).first {
            record = existing
        } else {
            record = DailyHealthSummaryRecord(dayIdentifier: identifier, date: dayStart)
            modelContext.insert(record)
        }

        let healthKitWorkouts = record.toSnapshot().workouts.filter { ($0.source ?? "healthKit") == "healthKit" }
        let merged = aggregateWorkouts(
            healthKitWorkouts: healthKitWorkouts,
            for: dayStart,
            modelContext: modelContext,
            calendar: calendar
        )
        let duration = merged.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start) / 60) }
        let energy = merged.compactMap(\.energyKilocalories).reduce(0, +)
        let load = merged.reduce(0) { partial, workout in
            partial + max(0, workout.end.timeIntervalSince(workout.start) / 60) * (workout.rpe ?? 5) * 0.3
        }
        // Algorithm v1/workoutAggregation: session-RPE fallback load.
        // Source: WorkoutEventRecord + current day's HealthKit workoutsData.
        // Confidence: medium for HR/RPE workouts, low for duration-only workouts.
        let activityLoad = normalizedActivityLoad(record)
        let dailyLoad = activityLoad + load
        record.workoutsData = try JSONEncoder().encode(merged)
        record.workoutCount = merged.count
        record.workoutTypes = Set(merged.map(\.activityName)).sorted().joined(separator: ", ")
        record.workoutDuration = duration
        record.activeMinutes = max(record.activeMinutes ?? 0, duration)
        record.activeCalories = max(record.activeCalories ?? 0, energy)
        record.activityLoad = activityLoad
        record.workoutLoad = load
        record.dailyLoad = dailyLoad
        record.updatedAt = Date()
    }

    private func normalizedActivityLoad(_ record: DailyHealthSummaryRecord) -> Double {
        guard let activityLoad = record.activityLoad else { return 0 }
        guard let previousWorkoutLoad = record.workoutLoad,
              previousWorkoutLoad > 0,
              let previousDailyLoad = record.dailyLoad,
              abs(previousDailyLoad - activityLoad) < 0.01 else {
            return activityLoad
        }
        return max(0, activityLoad - previousWorkoutLoad)
    }

    private func consolidateLocalEvents(_ events: [WorkoutEventRecord]) -> [WorkoutEventRecord] {
        var result: [String: WorkoutEventRecord] = [:]
        for event in events {
            let key = stableEventKey(event)
            if let existing = result[key] {
                result[key] = existing.updatedAt >= event.updatedAt ? existing : event
            } else {
                result[key] = event
            }
        }
        return Array(result.values).sorted { $0.startedAt < $1.startedAt }
    }

    private func stableEventKey(_ event: WorkoutEventRecord) -> String {
        if let linkedStrengthWorkoutId = event.linkedStrengthWorkoutId {
            return "strength:\(linkedStrengthWorkoutId.uuidString)"
        }
        if let linkedHealthKitWorkoutId = event.linkedHealthKitWorkoutId {
            return "healthKit:\(linkedHealthKitWorkoutId.uuidString)"
        }
        return [
            event.source,
            event.activityType.normalizedWorkoutText,
            "\(Int(event.startedAt.timeIntervalSince1970 / Self.duplicateTimeTolerance))",
            "\(Int(event.endedAt.timeIntervalSince1970 / Self.duplicateTimeTolerance))"
        ].joined(separator: "|")
    }

    private func localRecordRepresentsHealthKitWorkout(_ local: WorkoutEventRecord, _ healthKit: WorkoutSummary) -> Bool {
        if local.linkedHealthKitWorkoutId == healthKit.id || local.id == healthKit.id {
            return true
        }
        if workoutsOverlapByIdentity(
            lhsStart: local.startedAt,
            lhsEnd: local.endedAt,
            lhsActivity: local.activityType,
            rhsStart: healthKit.start,
            rhsEnd: healthKit.end,
            rhsActivity: healthKit.activityName
        ) {
            return true
        }
        let timeDifference = abs(local.startedAt.timeIntervalSince(healthKit.start))
        if timeDifference <= 30 * 60 && activitiesAreCompatible(local.activityType, healthKit.activityName) {
            return true
        }
        return false
    }

    private func deduplicateSummaries(_ workouts: [WorkoutSummary]) -> [WorkoutSummary] {
        var result: [String: WorkoutSummary] = [:]
        for workout in workouts {
            let key = summaryStableKey(workout)
            if let existing = result[key] {
                result[key] = richerSummary(existing, workout)
            } else {
                result[key] = workout
            }
        }
        return Array(result.values)
    }

    private func summaryStableKey(_ workout: WorkoutSummary) -> String {
        let source = workout.source ?? "healthKit"
        if source == "healthKit" {
            return "healthKit:\(workout.id.uuidString)"
        }
        return [
            source,
            workout.activityName.normalizedWorkoutText,
            "\(Int(workout.start.timeIntervalSince1970 / Self.duplicateTimeTolerance))",
            "\(Int(workout.end.timeIntervalSince1970 / Self.duplicateTimeTolerance))"
        ].joined(separator: "|")
    }

    private func richerSummary(_ lhs: WorkoutSummary, _ rhs: WorkoutSummary) -> WorkoutSummary {
        let lhsScore = [lhs.energyKilocalories, lhs.averageHeartRate, lhs.distanceMeters, lhs.rpe].compactMap { $0 }.count
        let rhsScore = [rhs.energyKilocalories, rhs.averageHeartRate, rhs.distanceMeters, rhs.rpe].compactMap { $0 }.count
        return rhsScore > lhsScore ? rhs : lhs
    }

    private func findMergeCandidate(
        for healthKitWorkout: WorkoutSummary,
        modelContext: ModelContext,
        calendar: Calendar
    ) throws -> WorkoutEventRecord? {
        let dayStart = calendar.startOfDay(for: healthKitWorkout.start)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let descriptor = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> {
                $0.startedAt >= dayStart && $0.startedAt < dayEnd
            },
            sortBy: [SortDescriptor(\.startedAt)]
        )
        return try modelContext.fetch(descriptor).first { event in
            event.linkedHealthKitWorkoutId == nil
                && eventRepresentsSameRealWorkout(event, healthKitWorkout)
        }
    }

    private func eventRepresentsSameRealWorkout(_ event: WorkoutEventRecord, _ healthKit: WorkoutSummary) -> Bool {
        guard healthKitWorkoutCanMergeWithStrengthDetails(healthKit.activityName) else { return false }
        guard activitiesAreCompatible(event.activityType, healthKit.activityName) else { return false }
        let overlapRatio = overlapRatio(
            lhsStart: event.startedAt,
            lhsEnd: event.endedAt,
            rhsStart: healthKit.start,
            rhsEnd: healthKit.end
        )
        let startClose = abs(event.startedAt.timeIntervalSince(healthKit.start)) <= 20 * 60
        let endClose = abs(event.endedAt.timeIntervalSince(healthKit.end)) <= 20 * 60
        return overlapRatio >= 0.5 && (startClose || endClose)
    }

    private func strengthEventRepresentsSameRealWorkout(
        _ event: WorkoutEventRecord,
        _ strengthWorkout: StrengthWorkoutRecord,
        calendar: Calendar
    ) -> Bool {
        guard calendar.isDate(event.startedAt, inSameDayAs: strengthWorkout.startedAt)
                || intervalsOverlap(
                    lhsStart: event.startedAt,
                    lhsEnd: event.endedAt,
                    rhsStart: strengthWorkout.startedAt,
                    rhsEnd: strengthWorkout.endedAt
                ) else {
            return false
        }
        guard healthKitWorkoutCanMergeWithStrengthDetails(event.activityType) else { return false }
        let overlapRatio = overlapRatio(
            lhsStart: event.startedAt,
            lhsEnd: event.endedAt,
            rhsStart: strengthWorkout.startedAt,
            rhsEnd: strengthWorkout.endedAt
        )
        let startClose = abs(event.startedAt.timeIntervalSince(strengthWorkout.startedAt)) <= 20 * 60
        let endClose = abs(event.endedAt.timeIntervalSince(strengthWorkout.endedAt)) <= 20 * 60
        return overlapRatio >= 0.5 && (startClose || endClose)
    }

    private func strengthMergeScore(event: WorkoutEventRecord, strengthWorkout: StrengthWorkoutRecord) -> Double {
        let overlap = overlapRatio(
            lhsStart: event.startedAt,
            lhsEnd: event.endedAt,
            rhsStart: strengthWorkout.startedAt,
            rhsEnd: strengthWorkout.endedAt
        )
        let startCloseness = closenessScore(abs(event.startedAt.timeIntervalSince(strengthWorkout.startedAt)), tolerance: 20 * 60)
        let endCloseness = closenessScore(abs(event.endedAt.timeIntervalSince(strengthWorkout.endedAt)), tolerance: 20 * 60)
        let durationDelta = abs(event.durationMinutes - Double(strengthWorkout.durationMinutes)) * 60
        let durationCloseness = closenessScore(durationDelta, tolerance: 30 * 60)
        let existingLinkBonus = event.linkedHealthKitWorkoutId != nil ? 0.1 : 0
        return overlap * 0.55 + max(startCloseness, endCloseness) * 0.25 + durationCloseness * 0.15 + existingLinkBonus
    }

    private func closenessScore(_ difference: TimeInterval, tolerance: TimeInterval) -> Double {
        guard tolerance > 0 else { return 0 }
        return max(0, 1 - difference / tolerance)
    }

    private func intervalsOverlap(
        lhsStart: Date,
        lhsEnd: Date,
        rhsStart: Date,
        rhsEnd: Date
    ) -> Bool {
        min(lhsEnd, rhsEnd) > max(lhsStart, rhsStart)
    }

    private func overlapRatio(
        lhsStart: Date,
        lhsEnd: Date,
        rhsStart: Date,
        rhsEnd: Date
    ) -> Double {
        let overlap = min(lhsEnd, rhsEnd).timeIntervalSince(max(lhsStart, rhsStart))
        guard overlap > 0 else { return 0 }
        let shorterDuration = min(lhsEnd.timeIntervalSince(lhsStart), rhsEnd.timeIntervalSince(rhsStart))
        guard shorterDuration > 0 else { return 0 }
        return overlap / shorterDuration
    }

    private func activitiesAreCompatible(_ lhs: String, _ rhs: String) -> Bool {
        let left = lhs.normalizedWorkoutText
        let right = rhs.normalizedWorkoutText
        if left == right { return true }
        let strengthTerms = ["strength", "traditionalstrengthtraining", "functionalstrengthtraining", "weight", "力量", "胸", "背", "肩", "腿", "臀", "二头", "三头"]
        let leftStrength = strengthTerms.contains { left.contains($0) }
        let rightStrength = strengthTerms.contains { right.contains($0) }
        return leftStrength && rightStrength
    }

    private func healthKitWorkoutCanMergeWithStrengthDetails(_ activity: String) -> Bool {
        let normalized = activity.normalizedWorkoutText
        let strengthTerms = [
            "strength",
            "traditionalstrengthtraining",
            "functionalstrengthtraining",
            "weighttraining",
            "力量",
            "传统力量训练",
            "功能性力量训练"
        ]
        return strengthTerms.contains { normalized.contains($0) }
    }

    private func resolvedSource(for event: WorkoutEventRecord) -> String {
        if event.linkedHealthKitWorkoutId != nil, event.linkedStrengthWorkoutId != nil {
            return "healthKit+xunji"
        }
        if event.linkedHealthKitWorkoutId != nil {
            return "healthKit"
        }
        return event.source
    }

    private func workoutsOverlapByIdentity(
        lhsStart: Date,
        lhsEnd: Date,
        lhsActivity: String,
        rhsStart: Date,
        rhsEnd: Date,
        rhsActivity: String
    ) -> Bool {
        lhsActivity.normalizedWorkoutText == rhsActivity.normalizedWorkoutText
            && abs(lhsStart.timeIntervalSince(rhsStart)) <= Self.duplicateTimeTolerance
            && abs(lhsEnd.timeIntervalSince(rhsEnd)) <= Self.duplicateTimeTolerance
    }

    public func rebuildRecentDays(
        days: Int,
        endingAt: Date = Date(),
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        for offset in 0..<max(0, days) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endingAt) else { continue }
            try aggregateDay(date: date, modelContext: modelContext, calendar: calendar)
        }
        try modelContext.save()
    }

    private func linkActivePlanDay(
        for event: WorkoutEventRecord,
        strengthWorkout: StrengthWorkoutRecord,
        modelContext: ModelContext,
        calendar: Calendar
    ) throws {
        let descriptor = FetchDescriptor<TrainingPlanRecord>(
            predicate: #Predicate<TrainingPlanRecord> { $0.isActive }
        )
        let plans = try modelContext.fetch(descriptor)
        let linker = TrainingPlanLinkingService()
        
        for plan in plans {
            let planStart = calendar.startOfDay(for: plan.startDate)
            var bestMatchIndex: Int?
            var bestMatchScore = 0.0
            
            for (index, day) in plan.days.enumerated() {
                let expectedDate = calendar.date(byAdding: .day, value: (day.weekNumber - 1) * 7 + (day.dayNumber - 1), to: planStart) ?? planStart
                let score = linker.calculateMatchScore(
                    event: event,
                    planDay: day,
                    strengthWorkout: strengthWorkout,
                    expectedDate: expectedDate,
                    calendar: calendar
                )
                if score > bestMatchScore {
                    bestMatchScore = score
                    bestMatchIndex = index
                }
            }
            
            if let index = bestMatchIndex, linker.isHighConfidenceMatch(score: bestMatchScore) {
                var day = plan.days[index]
                if !day.linkedWorkoutEventIds.contains(event.id) {
                    day.linkedWorkoutEventIds.append(event.id)
                }
                day.isCompleted = true
                day.completedAt = event.endedAt
                day.loggedStrain = event.durationMinutes * (event.rpe ?? 5) * 0.3
                day.adherenceScore = day.durationMinutes > 0
                    ? min(1.5, event.durationMinutes / Double(day.durationMinutes))
                    : 1
                let actual = [
                    "title": event.title,
                    "duration_minutes": event.durationMinutes.formatted(.number.precision(.fractionLength(0))),
                    "source": event.source
                ]
                if let data = try? JSONEncoder().encode(actual),
                   let json = String(data: data, encoding: .utf8) {
                    day.actualSummaryJSON = json
                }
                plan.days[index] = day
                plan.updatedAt = Date()
                event.linkedTrainingPlanDayId = day.id
                strengthWorkout.planDayId = day.id
                break
            }
        }
    }

    /// Deletes a StrengthWorkoutRecord and cleans up its linked WorkoutEventRecord, XunjiWorkoutMirrorRecord, and daily load.
    func deleteStrengthWorkout(
        _ workout: StrengthWorkoutRecord,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let workoutID = workout.id
        let workoutDate = workout.startedAt
        
        // 1. Find linked events
        let eventDescriptor = FetchDescriptor<WorkoutEventRecord>(
            predicate: #Predicate<WorkoutEventRecord> { $0.linkedStrengthWorkoutId == workoutID }
        )
        let events = try modelContext.fetch(eventDescriptor)
        for event in events {
            if let hkId = event.linkedHealthKitWorkoutId {
                modelContext.insert(DeletedWorkoutRecord(id: hkId.uuidString))
            }
            if event.source == "xunji" || event.source == "strengthLog" {
                modelContext.delete(event)
            } else {
                // If it is a HealthKit or other synced event, keep the event but unlink it
                event.linkedStrengthWorkoutId = nil
                event.updatedAt = Date()
            }
        }
        
        // 2. Find Xunji mirror records
        let mirrorDescriptor = FetchDescriptor<XunjiWorkoutMirrorRecord>(
            predicate: #Predicate<XunjiWorkoutMirrorRecord> { $0.linkedStrengthWorkoutID == workoutID }
        )
        let mirrors = try modelContext.fetch(mirrorDescriptor)
        for mirror in mirrors {
            modelContext.insert(DeletedWorkoutRecord(id: mirror.externalID))
            modelContext.delete(mirror)
        }
        
        // 3. Delete the StrengthWorkoutRecord itself
        modelContext.delete(workout)
        
        try modelContext.save()
        
        // 4. Recalculate summary and aggregation for the affected day
        try aggregateDay(date: workoutDate, modelContext: modelContext, calendar: calendar)
        try modelContext.save()
    }
}

@MainActor
struct WorkoutSaveCoordinator {
    enum Stage: Int, CaseIterable, Sendable {
        case workoutInsertion = 1
        case eventUpsert
        case artifactInsertion
        case aggregation
        case draftDeletion
        case save
    }

    struct CommitResult {
        let workout: StrengthWorkoutRecord
        let event: WorkoutEventRecord
    }

    typealias FailureInjector = @MainActor (Stage) throws -> Void

    private let failureInjector: FailureInjector
    private let aggregationService: WorkoutAggregationService
    private let calendar: Calendar

    init(
        aggregationService: WorkoutAggregationService = .shared,
        calendar: Calendar = .current,
        failureInjector: @escaping FailureInjector = { _ in }
    ) {
        self.aggregationService = aggregationService
        self.calendar = calendar
        self.failureInjector = failureInjector
    }

    init(failureInjector: @escaping FailureInjector) {
        self.init(
            aggregationService: .shared,
            calendar: .current,
            failureInjector: failureInjector
        )
    }

    func commitNewWorkout(
        workout: StrengthWorkoutRecord,
        artifact: CoachArtifactRecord,
        sessionRPE: Double?,
        modelContext: ModelContext
    ) throws -> CommitResult {
        do {
            try PersistenceWriteGate.shared.assertWritable(
                operation: "WorkoutSaveCoordinator.commitNewWorkout",
                modelContext: modelContext
            )

            try failureInjector(.workoutInsertion)
            modelContext.insert(workout)

            try failureInjector(.eventUpsert)
            let event = try aggregationService.prepareWorkoutEvent(
                from: workout,
                modelContext: modelContext,
                sessionRPE: sessionRPE,
                calendar: calendar
            )

            try failureInjector(.artifactInsertion)
            modelContext.insert(artifact)

            try failureInjector(.aggregation)
            try aggregationService.aggregateDay(
                date: workout.startedAt,
                modelContext: modelContext,
                calendar: calendar
            )

            try failureInjector(.draftDeletion)
            try deleteActiveDrafts(modelContext: modelContext)

            try failureInjector(.save)
            try modelContext.save()
            return CommitResult(workout: workout, event: event)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func commitWorkoutEdit(
        workout: StrengthWorkoutRecord,
        previousStartDate: Date,
        sessionRPE: Double?,
        modelContext: ModelContext
    ) throws -> CommitResult {
        do {
            try PersistenceWriteGate.shared.assertWritable(
                operation: "WorkoutSaveCoordinator.commitWorkoutEdit",
                modelContext: modelContext
            )

            try failureInjector(.eventUpsert)
            let event = try aggregationService.prepareWorkoutEvent(
                from: workout,
                modelContext: modelContext,
                sessionRPE: sessionRPE,
                calendar: calendar
            )

            try failureInjector(.aggregation)
            if !calendar.isDate(previousStartDate, inSameDayAs: workout.startedAt) {
                try aggregationService.aggregateDay(
                    date: previousStartDate,
                    modelContext: modelContext,
                    calendar: calendar
                )
            }
            try aggregationService.aggregateDay(
                date: workout.startedAt,
                modelContext: modelContext,
                calendar: calendar
            )

            try failureInjector(.save)
            try modelContext.save()
            return CommitResult(workout: workout, event: event)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func deleteActiveDrafts(modelContext: ModelContext) throws {
        for draft in try modelContext.fetch(FetchDescriptor<ActiveWorkoutDraftRecord>()) {
            modelContext.delete(draft)
        }
    }
}

private extension String {
    var normalizedWorkoutText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}
