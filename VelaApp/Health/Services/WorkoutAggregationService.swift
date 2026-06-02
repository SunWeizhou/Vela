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
        let localHKIds = Set(localRecords.filter { $0.source == "healthKit" }.map { $0.id })
        
        for hk in healthKitWorkouts {
            if !localHKIds.contains(hk.id) {
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
                averageHeartRate: matchedHK?.averageHeartRate,
                distanceMeters: matchedHK?.distanceMeters,
                source: local.source,
                rpe: local.rpe
            ))
        }
        
        return merged
    }
}
