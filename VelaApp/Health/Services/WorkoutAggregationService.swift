import Foundation
import SwiftData

@MainActor
public final class WorkoutAggregationService {
    public static let shared = WorkoutAggregationService()
    
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
        
        let localRecords = (try? modelContext.fetch(descriptor)) ?? []
        
        var merged: [WorkoutSummary] = []
        
        // 1. Keep HealthKit workouts (except those that are already manually handled or duplicated)
        let localRecordIDs = Set(localRecords.map(\.id))
        
        for hk in healthKitWorkouts {
            if !localRecordIDs.contains(hk.id) {
                merged.append(hk)
            }
        }
        
        // 2. Add local records (manual / strength / healthKit mirrored)
        for local in localRecords {
            // Find if there is a HealthKit workout with same id to preserve averageHeartRate etc.
            let matchedHK = healthKitWorkouts.first { $0.id == local.id }
            
            merged.append(WorkoutSummary(
                id: local.id,
                start: local.startedAt,
                end: local.endedAt,
                activityName: local.activityType,
                energyKilocalories: local.energyKilocalories ?? matchedHK?.energyKilocalories,
                averageHeartRate: local.averageHeartRate ?? matchedHK?.averageHeartRate,
                distanceMeters: matchedHK?.distanceMeters,
                source: local.source,
                rpe: local.rpe
            ))
        }
        
        return merged
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

        let merged = aggregateWorkouts(
            healthKitWorkouts: record.toSnapshot().workouts,
            for: dayStart,
            modelContext: modelContext,
            calendar: calendar
        )
        let duration = merged.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start) / 60) }
        let energy = merged.compactMap(\.energyKilocalories).reduce(0, +)
        let load = merged.reduce(0) { partial, workout in
            partial + max(0, workout.end.timeIntervalSince(workout.start) / 60) * (workout.rpe ?? 5) * 0.3
        }
        let dailyLoad = (record.activityLoad ?? 0) + load
        record.workoutsData = try JSONEncoder().encode(merged)
        record.workoutCount = merged.count
        record.workoutTypes = Set(merged.map(\.activityName)).sorted().joined(separator: ", ")
        record.workoutDuration = duration
        record.activeMinutes = max(record.activeMinutes ?? 0, duration)
        record.activeCalories = max(record.activeCalories ?? 0, energy)
        record.workoutLoad = load
        record.dailyLoad = dailyLoad
        if dailyLoad > 0 {
            record.strainScore = 100 * (1 - exp(-0.75 * dailyLoad / 100))
        }
        record.updatedAt = Date()
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
        for plan in plans {
            let planStart = calendar.startOfDay(for: plan.startDate)
            let workoutDay = calendar.startOfDay(for: event.startedAt)
            guard let delta = calendar.dateComponents([.day], from: planStart, to: workoutDay).day, delta >= 0 else { continue }
            let weekNumber = delta / 7 + 1
            let dayNumber = delta % 7 + 1
            guard let index = plan.days.firstIndex(where: { $0.weekNumber == weekNumber && $0.dayNumber == dayNumber }) else { continue }
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
