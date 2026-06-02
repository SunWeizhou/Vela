import SwiftData
import XCTest
@testable import Vela

final class PersistenceFoundationTests: XCTestCase {
    func testDailyHealthRecordCanApplySnapshotWithoutLosingDate() throws {
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 12)))
        let snapshot = DailyHealthSnapshot(
            date: date,
            sleepScore: 76,
            recoveryScore: 68,
            strainScore: 42,
            stressIndex: 38,
            morningEnergy: 70,
            currentEnergy: 51
        )

        let record = DailyHealthSummaryRecord(snapshot: snapshot, calendar: Calendar(identifier: .gregorian))

        XCTAssertEqual(record.sleepScore, 76)
        XCTAssertEqual(record.recoveryScore, 68)
        XCTAssertEqual(record.strainScore, 42)
        XCTAssertEqual(Calendar(identifier: .gregorian).component(.hour, from: record.date), 0)
        XCTAssertEqual(record.configVersion, VelaAppMetadata.configVersion)
    }

    func testDailyHealthRecordRoundTripsEnergyTrainingLoadComponents() throws {
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 12)))
        let snapshot = DailyHealthSnapshot(
            date: date,
            atl: 74,
            ctl: 48,
            tsb: -26,
            acwr: 1.62
        )

        let restored = DailyHealthSummaryRecord(
            snapshot: snapshot,
            calendar: Calendar(identifier: .gregorian)
        ).toSnapshot()

        XCTAssertEqual(restored.atl, 74)
        XCTAssertEqual(restored.ctl, 48)
        XCTAssertEqual(restored.tsb, -26)
        XCTAssertEqual(restored.acwr, 1.62)
    }

    func testDailyHealthRecordPreservesManualWorkoutAcrossHealthKitRefreshWithoutDoubleCounting() throws {
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 12)))
        let workout = WorkoutSummary(
            start: date.addingTimeInterval(-30 * 60),
            end: date,
            activityName: "力量训练",
            energyKilocalories: 250,
            source: "manual"
        )
        let record = DailyHealthSummaryRecord(
            snapshot: DailyHealthSnapshot(
                date: date,
                activeCalories: 250,
                workoutCount: 1,
                workoutDuration: 30,
                workouts: [workout]
            ),
            calendar: calendar
        )

        record.apply(
            snapshot: DailyHealthSnapshot(date: date, activeCalories: 100),
            calendar: calendar
        )
        XCTAssertEqual(record.toSnapshot().workouts, [workout])
        XCTAssertEqual(record.activeCalories, 350)
        XCTAssertEqual(record.workoutDuration, 30)

        record.apply(snapshot: record.toSnapshot(), calendar: calendar)
        XCTAssertEqual(record.activeCalories, 350)
        XCTAssertEqual(record.workoutCount, 1)
    }

    func testJournalEntryRoundTripsTagsThroughStorage() {
        let entry = JournalEntryRecord(tags: ["Coffee", "Late Dinner"], note: "Felt wired before bed.")

        XCTAssertEqual(entry.tags, ["Coffee", "Late Dinner"])

        entry.tags = ["Workout"]
        XCTAssertEqual(entry.serializedTags, "Workout")
        XCTAssertEqual(entry.tags, ["Workout"])
    }

    func testFoodLogRecordPreservesStructuredNutritionAnalysis() throws {
        let analysis = FoodAnalysisResult(
            foods: [
                IdentifiedFood(name: "Chicken breast", portion: "150g", calories: 240),
                IdentifiedFood(name: "Rice", portion: "1 cup", calories: 205)
            ],
            totalCalories: 445,
            macros: MacroBreakdown(protein: 35, carbs: 45, fat: 12, fiber: 3),
            healthScore: "good",
            suggestions: ["Add vegetables", "Hydrate with water"],
            rawAnalysis: #"{"foods":[]}"#
        )

        let record = FoodLogRecord(
            analysis: analysis,
            mealName: "Lunch",
            source: .photoAnalysis,
            createdAt: Date(timeIntervalSince1970: 1_800)
        )

        XCTAssertEqual(record.mealName, "Lunch")
        XCTAssertEqual(record.source, FoodLogSource.photoAnalysis.rawValue)
        XCTAssertEqual(record.totalCalories, 445)
        XCTAssertEqual(record.proteinGrams, 35)
        XCTAssertEqual(record.carbsGrams, 45)
        XCTAssertEqual(record.fatGrams, 12)
        XCTAssertEqual(record.fiberGrams, 3)
        XCTAssertEqual(record.foods.map(\.name), ["Chicken breast", "Rice"])
        XCTAssertEqual(record.foods.map(\.portion), ["150g", "1 cup"])
        XCTAssertEqual(record.suggestions, ["Add vegetables", "Hydrate with water"])
        XCTAssertTrue(record.summaryLine.contains("445 kcal"))
    }

    func testFoodLogRecordPersistsInVelaModelContainerSchema() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let record = FoodLogRecord(
            mealName: "Dinner",
            foods: [FoodLogItem(name: "Salmon", portion: "180g", calories: 360)],
            totalCalories: 360,
            proteinGrams: 38,
            carbsGrams: 0,
            fatGrams: 22,
            fiberGrams: 0,
            healthScore: "good",
            suggestions: ["Add leafy greens"],
            source: .manual,
            createdAt: Date(timeIntervalSince1970: 2_400)
        )

        context.insert(record)
        try context.save()

        let records = try context.fetch(FetchDescriptor<FoodLogRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.foods.first?.name, "Salmon")
        XCTAssertEqual(records.first?.suggestions, ["Add leafy greens"])
    }

    func testStrengthWorkoutRecordCalculatesVolumeAndRoundTripsExerciseDetails() {
        let record = StrengthWorkoutRecord(
            title: "Push Day",
            startedAt: Date(timeIntervalSince1970: 1_800),
            durationMinutes: 55,
            exercises: [
                StrengthExerciseLog(
                    name: "Bench Press",
                    equipment: "Barbell",
                    sets: [
                        StrengthSetLog(repetitions: 10, weightKilograms: 60),
                        StrengthSetLog(repetitions: 8, weightKilograms: 70)
                    ]
                )
            ]
        )

        XCTAssertEqual(record.exerciseCount, 1)
        XCTAssertEqual(record.totalSetCount, 2)
        XCTAssertEqual(record.totalRepetitionCount, 18)
        XCTAssertEqual(record.totalVolumeKilograms, 1_160)
        XCTAssertEqual(record.exercises.first?.equipment, "Barbell")
    }

    func testStrengthWorkoutRecordPersistsInVelaModelContainerSchema() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let record = StrengthWorkoutRecord(
            title: "Lower Body",
            durationMinutes: 50,
            exercises: [
                StrengthExerciseLog(
                    name: "Squat",
                    equipment: "Barbell",
                    sets: [StrengthSetLog(repetitions: 5, weightKilograms: 100)]
                )
            ]
        )

        context.insert(record)
        try context.save()

        let records = try context.fetch(FetchDescriptor<StrengthWorkoutRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.exercises.first?.name, "Squat")
        XCTAssertEqual(records.first?.totalVolumeKilograms, 500)
    }

    func testCachePolicyDetectsStaleRecords() {
        let now = Date(timeIntervalSince1970: 1_800)
        let fresh = HealthCachePolicy(maxAge: 600)

        XCTAssertFalse(fresh.isStale(lastUpdatedAt: Date(timeIntervalSince1970: 1_500), now: now))
        XCTAssertTrue(fresh.isStale(lastUpdatedAt: Date(timeIntervalSince1970: 1_100), now: now))
    }

    func testDailySummaryRepositoryUpsertsByCalendarDay() throws {
        let container = try ModelContainer(
            for: DailyHealthSummaryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataDailyHealthSummaryRepository(modelContext: ModelContext(container))
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 17, hour: 8)))

        try repository.upsert(DailyHealthSnapshot(date: date, sleepScore: 70, recoveryScore: 61, strainScore: 22, stressIndex: nil, morningEnergy: nil, currentEnergy: nil), calendar: calendar)
        try repository.upsert(DailyHealthSnapshot(date: date.addingTimeInterval(3_600), sleepScore: 80, recoveryScore: 71, strainScore: 32, stressIndex: nil, morningEnergy: nil, currentEnergy: nil), calendar: calendar)

        let records = try repository.fetch(in: DateRangeQuery.recentDays(1, endingAt: date, calendar: calendar))

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.sleepScore, 80)
        XCTAssertEqual(records.first?.recoveryScore, 71)
    }

    @MainActor
    func testDailySummaryHydratesPersistedDashboardBeforeHealthRefreshWithoutInventingValues() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 8)))
        let record = DailyHealthSummaryRecord(
            snapshot: DailyHealthSnapshot(
                date: date,
                sleepScore: 67,
                recoveryScore: 61,
                strainScore: 48,
                stressIndex: 35,
                morningEnergy: 72,
                currentEnergy: 17,
                hrvAverage: 57.5,
                restingHeartRate: 59,
                sleepHours: 7.25,
                steps: 8_400,
                activeCalories: 510,
                activeMinutes: 36,
                workoutDuration: 75,
                atl: 74,
                ctl: 48,
                tsb: -26,
                acwr: 1.62
            ),
            calendar: calendar
        )
        context.insert(record)
        try context.save()

        let dashboard = try XCTUnwrap(
            DailySummaryUseCase(calendar: calendar).loadCachedDashboard(
                for: date,
                modelContext: context
            )
        )

        XCTAssertEqual(dashboard.source, .cache)
        XCTAssertEqual(dashboard.sleepScore.score, 67)
        XCTAssertEqual(dashboard.recovery.score, 61)
        XCTAssertEqual(dashboard.strain.score, 48)
        XCTAssertEqual(dashboard.energy.currentEnergy, 17)
        XCTAssertEqual(dashboard.energy.metrics["atl"], 74)
        XCTAssertEqual(dashboard.energy.metrics["ctl"], 48)
        XCTAssertEqual(dashboard.energy.metrics["tsb"], -26)
        XCTAssertEqual(dashboard.energy.metrics["acwr"], 1.62)
        XCTAssertEqual(dashboard.strain.metrics["exercise_minutes_raw"], 36)
        XCTAssertEqual(dashboard.recoveryMetrics.hrvMilliseconds, 57.5)
        XCTAssertNil(dashboard.bodyMetrics.weightKilograms)
        XCTAssertNil(dashboard.extendedMetrics.age)
    }

    @MainActor
    func testDashboardViewModelHydratesCachedDashboardSynchronously() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let calendar = Calendar(identifier: .gregorian)
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 31, hour: 8)))
        context.insert(DailyHealthSummaryRecord(
            snapshot: DailyHealthSnapshot(
                date: date,
                sleepScore: 67,
                recoveryScore: 61,
                strainScore: 48,
                stressIndex: 35,
                morningEnergy: 72,
                currentEnergy: 17
            ),
            calendar: calendar
        ))
        try context.save()

        let viewModel = DashboardViewModel(useCase: DailySummaryUseCase(calendar: calendar))
        viewModel.selectedDate = date

        XCTAssertTrue(viewModel.hydrateFromCache(modelContext: context))
        XCTAssertEqual(viewModel.dashboard.source, .cache)
        XCTAssertEqual(viewModel.dashboard.recovery.score, 61)
        XCTAssertNotNil(viewModel.lastUpdated)
    }
}
