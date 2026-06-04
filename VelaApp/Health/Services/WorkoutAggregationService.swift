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
            let useHealthKitTiming = local.source == "healthKit" && matchedHK != nil
            
            merged.append(WorkoutSummary(
                id: local.id,
                start: useHealthKitTiming ? matchedHK?.start ?? local.startedAt : local.startedAt,
                end: useHealthKitTiming ? matchedHK?.end ?? local.endedAt : local.endedAt,
                activityName: useHealthKitTiming ? matchedHK?.activityName ?? local.activityType : local.activityType,
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
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        for workout in healthKitWorkouts {
            let healthKitID = workout.id
            let descriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.linkedHealthKitWorkoutId == healthKitID }
            )
            let event: WorkoutEventRecord
            if let existing = try modelContext.fetch(descriptor).first {
                event = existing
                event.startedAt = workout.start
                event.endedAt = workout.end
                event.dayIdentifier = DailyHealthSummaryRecord.dayIdentifier(for: workout.start, calendar: calendar)
                event.activityType = workout.activityName
                event.title = workout.activityName
                event.durationMinutes = max(0, workout.end.timeIntervalSince(workout.start) / 60)
                event.energyKilocalories = workout.energyKilocalories
                event.averageHeartRate = workout.averageHeartRate
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

    @discardableResult
    func upsertWorkoutEvent(
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
        strengthWorkout.linkedWorkoutEventId = event.id
        strengthWorkout.sessionRPE = resolvedRPE
        strengthWorkout.completedAt = strengthWorkout.endedAt
        try linkActivePlanDay(for: event, strengthWorkout: strengthWorkout, modelContext: modelContext, calendar: calendar)
        try aggregateDay(date: strengthWorkout.startedAt, modelContext: modelContext, calendar: calendar)
        try modelContext.save()
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
        let dailyLoad = (record.activityLoad ?? 0) + load
        record.workoutsData = try JSONEncoder().encode(merged)
        record.workoutCount = merged.count
        record.workoutTypes = Set(merged.map(\.activityName)).sorted().joined(separator: ", ")
        record.workoutDuration = duration
        record.activeMinutes = max(record.activeMinutes ?? 0, duration)
        record.activeCalories = max(record.activeCalories ?? 0, energy)
        record.workoutLoad = load
        record.dailyLoad = dailyLoad
        record.updatedAt = Date()
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
        if let linkedHealthKitWorkoutId = event.linkedHealthKitWorkoutId {
            return "healthKit:\(linkedHealthKitWorkoutId.uuidString)"
        }
        if let linkedStrengthWorkoutId = event.linkedStrengthWorkoutId {
            return "strength:\(linkedStrengthWorkoutId.uuidString):\(event.source)"
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
        guard local.source == "healthKit" else { return false }
        return workoutsOverlapByIdentity(
            lhsStart: local.startedAt,
            lhsEnd: local.endedAt,
            lhsActivity: local.activityType,
            rhsStart: healthKit.start,
            rhsEnd: healthKit.end,
            rhsActivity: healthKit.activityName
        )
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
}

private extension String {
    var normalizedWorkoutText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
    }
}
