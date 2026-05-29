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
}
