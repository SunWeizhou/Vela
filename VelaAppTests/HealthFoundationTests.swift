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

    func requestAuthorization(toShare typesToShare: Set<HKSampleType>, read typesToRead: Set<HKObjectType>) async throws {
        requestedReadTypes = typesToRead
    }

    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        .notDetermined
    }
}
