import XCTest
import HealthKit
@testable import Vela

final class HealthFoundationTests: XCTestCase {
    @MainActor
    func testHealthPermissionTiersRequestCumulativeReadTypes() async throws {
        let store = FakeHealthStore()
        let service = HealthAuthorizationService(healthStore: store)

        try await service.requestAuthorization(tier: .core)
        XCTAssertEqual(store.requestedReadTypes, Set(HealthDataTypeCatalog.coreTypes))

        try await service.requestAuthorization(tier: .enhanced)
        XCTAssertEqual(store.requestedReadTypes, Set(HealthDataTypeCatalog.coreTypes + HealthDataTypeCatalog.enhancedTypes))

        try await service.requestAuthorization(tier: .advanced)
        XCTAssertEqual(store.requestedReadTypes, Set(HealthDataTypeCatalog.readTypes))
    }

    @MainActor
    func testHealthSyncDefersUntilInitialAuthorizationRequest() async {
        let store = FakeHealthStore()
        let service = HealthAuthorizationService(healthStore: store)

        store.requestStatus = .shouldRequest
        let shouldDefer = await service.shouldDeferBackgroundSync()
        XCTAssertTrue(shouldDefer)

        store.requestStatus = .unnecessary
        let shouldSync = await service.shouldDeferBackgroundSync()
        XCTAssertFalse(shouldSync)
    }

    @MainActor
    func testSnapshotOmitsUncomputedScoresInsteadOfPersistingZeroes() {
        let date = Date()
        let context = DailyHealthContext(
            date: date,
            sleepSummary: nil,
            recoveryMetrics: RecoveryMetricSummary(),
            recoveryBaseline: RecoveryMetricSummary(),
            strainToday: StrainActivitySummary(workouts: []),
            strainBaselineDaily: StrainActivitySummary(workouts: []),
            bodyMetrics: BodyMetricsSummary()
        )

        let snapshot = DailySummaryUseCase().makeSnapshot(
            from: .empty(date: date),
            context: context,
            date: date
        )

        XCTAssertNil(snapshot.recoveryScore)
        XCTAssertNil(snapshot.sleepScore)
        XCTAssertNil(snapshot.strainScore)
        XCTAssertNil(snapshot.stressIndex)
        XCTAssertNil(snapshot.currentEnergy)
    }

    func testDataCoverageSummaryBuildsDomainScoresAndTopBlockers() {
        let groups = [
            CoverageGroup(
                id: "recovery",
                title: "恢复",
                icon: "heart.fill",
                signals: [
                    coverage(.hrvSDNN, usable: true),
                    coverage(.restingHR, usable: true),
                    coverage(.respiratoryRate, usable: false)
                ],
                affectedJudgments: ["Recovery Score"]
            ),
            CoverageGroup(
                id: "training",
                title: "训练",
                icon: "figure.run",
                signals: [
                    coverage(.workouts, usable: true),
                    coverage(.activeEnergy, usable: false),
                    coverage(.workoutHR, usable: false)
                ],
                affectedJudgments: ["Training Load"]
            )
        ]

        let summary = DataCoverageSummaryModel.build(groups: groups)

        XCTAssertEqual(summary.scorePercent, 50)
        XCTAssertEqual(summary.status, .moderate)
        XCTAssertEqual(summary.domainSummaries.map(\.id), ["recovery", "training"])
        XCTAssertEqual(summary.domainSummaries.map(\.scorePercent), [67, 33])
        XCTAssertEqual(summary.topBlockers.count, 3)
        XCTAssertTrue(summary.coachContextLine.contains("Data coverage 50%"))
    }

    func testDataCoverageSummaryStaysConservativeWhenCriticalSignalsAreMissing() {
        let groups = [
            CoverageGroup(
                id: "recovery",
                title: "恢复",
                icon: "heart.fill",
                signals: [
                    coverage(.hrvSDNN, usable: false),
                    coverage(.restingHR, usable: false),
                    coverage(.respiratoryRate, usable: false)
                ],
                affectedJudgments: ["Recovery Score", "Autonomic Fatigue"]
            )
        ]

        let summary = DataCoverageSummaryModel.build(groups: groups)

        XCTAssertEqual(summary.scorePercent, 0)
        XCTAssertEqual(summary.status, .low)
        XCTAssertTrue(summary.subtitle.contains("保守"))
        XCTAssertTrue(summary.actionTitle.contains("数据"))
    }

    func testCoverageDoesNotClaimAvailabilityWithoutReadableSamples() {
        let coverage = HealthSignalCoverage(
            signal: .hrvSDNN,
            authorizationState: .authorizedButNoSamples,
            sampleCount7d: 0,
            sampleCount30d: 0,
            latestSampleAt: nil,
            freshness: .missing,
            quality: .insufficient
        )

        XCTAssertFalse(coverage.isAvailable)
        XCTAssertFalse(coverage.analyticallyUsable)
        XCTAssertTrue(coverage.confidenceImpact.contains("Apple Health"))
    }

    private func coverage(_ signal: HealthSignal, usable: Bool) -> HealthSignalCoverage {
        HealthSignalCoverage(
            signal: signal,
            authorizationState: usable ? .authorized : .authorizedButNoSamples,
            sampleCount7d: usable ? 7 : 0,
            sampleCount30d: usable ? 21 : 0,
            latestSampleAt: usable ? Date() : nil,
            freshness: usable ? .today : .missing,
            quality: usable ? .enough : .insufficient
        )
    }
}

@MainActor
private final class FakeHealthStore: HealthStoreProviding {
    var isHealthDataAvailable = true
    var requestedReadTypes = Set<HKObjectType>()
    var requestStatus: HKAuthorizationRequestStatus = .unnecessary

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        requestedReadTypes = typesToRead
    }

    func authorizationRequestStatus(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws -> HKAuthorizationRequestStatus {
        requestStatus
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        .notDetermined
    }
}

// MARK: - BodyStateKernel & TrainingDecisionKernel Tests

final class BodyStateKernelTests: XCTestCase {
    func testBodyStateKernelBuildBasic() {
        let kernel = BodyStateKernel()
        let input = BodyStateInput(
            dashboard: .empty(date: Date()),
            activeStatus: "active",
            generatedAt: Date()
        )
        
        let state = kernel.build(input: input)
        XCTAssertEqual(state.activeStatus, "active")
        XCTAssertEqual(state.readiness, .unknown)
        XCTAssertEqual(state.drivers.count, 1)
        XCTAssertEqual(state.drivers.first?.kind, .dataCoverage)
        XCTAssertTrue(state.drivers.first?.detail.contains("保守训练窗口") == true)
    }

    func testBodyStateKernelSickStatusAddsDriver() {
        let kernel = BodyStateKernel()
        let input = BodyStateInput(
            dashboard: .empty(date: Date()),
            activeStatus: "sick",
            generatedAt: Date()
        )
        
        let state = kernel.build(input: input)
        XCTAssertEqual(state.activeStatus, "sick")
        XCTAssertFalse(state.drivers.isEmpty)
        XCTAssertTrue(state.drivers.contains(where: { $0.kind == .activeStatus }))
    }

    func testBodyStateKernelNutritionAddsDriver() {
        let kernel = BodyStateKernel()
        let food = FoodLogRecord(
            mealName: "Lunch",
            foods: [FoodLogItem(name: "Chicken Salad", portion: "1 bowl", calories: 350)],
            totalCalories: 350,
            proteinGrams: 30,
            carbsGrams: 10,
            fatGrams: 20,
            fiberGrams: 5,
            healthScore: "85",
            suggestions: ["Good protein source."],
            source: .manual,
            rawAnalysis: "",
            createdAt: Date()
        )
        let input = BodyStateInput(
            dashboard: .empty(date: Date()),
            foodLogs: [food],
            generatedAt: Date()
        )
        
        let state = kernel.build(input: input)
        XCTAssertTrue(state.drivers.contains(where: { $0.kind == .nutrition }))
    }
}

final class TrainingDecisionKernelTests: XCTestCase {
    func testTrainingDecisionKernelSickStatusForcesRest() {
        let kernel = TrainingDecisionKernel()
        let dashboard = DashboardSummary.empty(date: Date())
        
        // Mock bodyState with sick activeStatus
        var state = dashboard.bodyState
        state.activeStatus = "sick"
        state.readiness = .recovering
        
        let input = TrainingDecisionInput(
            bodyState: state,
            activePlan: nil,
            recentStrengthSummary: nil,
            trainingResponses: []
        )
        
        let decision = kernel.decide(input: input)
        XCTAssertEqual(decision.decision, .rest)
        XCTAssertEqual(decision.volumeMultiplier, 0.0)
    }
}
