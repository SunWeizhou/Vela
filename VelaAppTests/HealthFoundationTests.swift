import XCTest
import HealthKit
import SwiftData
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
            authorizationState: .noReadableSamples,
            sampleCount7d: 0,
            sampleCount30d: 0,
            latestSampleAt: nil,
            freshness: .missing,
            quality: .insufficient
        )

        XCTAssertFalse(coverage.isAvailable)
        XCTAssertFalse(coverage.analyticallyUsable)
        XCTAssertTrue(
            coverage.confidenceImpact.contains("读取") ||
            coverage.confidenceImpact.contains("readable")
        )
    }

    func testHealthSignalCatalogCoversEveryQueriedSignalAndSeparatesAudioSources() {
        XCTAssertTrue(HealthSignal.allCases.allSatisfy { $0.objectType != nil })
        XCTAssertNotEqual(
            HealthSignal.envNoise.objectType?.identifier,
            HealthSignal.headphoneNoise.objectType?.identifier
        )

        let advancedIdentifiers = Set(
            HealthSignalCatalog.readTypes(for: .advanced).map(\.identifier)
        )
        XCTAssertTrue(advancedIdentifiers.contains(HealthSignal.height.objectType!.identifier))
        XCTAssertTrue(advancedIdentifiers.contains(HealthSignal.workoutRoute.objectType!.identifier))
        XCTAssertTrue(advancedIdentifiers.contains(HealthSignal.daylight.objectType!.identifier))
    }

    func testReadStateResolverNeverInfersReadDenialFromMissingSamples() {
        XCTAssertEqual(
            HealthReadStateResolver.resolve(
                requestStatus: .unnecessary,
                sampleCount7d: 0,
                sampleCount30d: 0
            ),
            .noReadableSamples
        )
        XCTAssertEqual(
            HealthReadStateResolver.resolve(
                requestStatus: .shouldRequest,
                sampleCount7d: 0,
                sampleCount30d: 0
            ),
            .notRequested
        )
        XCTAssertEqual(
            HealthReadStateResolver.resolve(
                requestStatus: .unnecessary,
                sampleCount7d: 0,
                sampleCount30d: 12
            ),
            .readableSamplesStale
        )
    }

    func testHealthSyncPlannerBootstrapsBaselinesButScoresRequestedWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let end = Date(timeIntervalSince1970: 1_785_369_600)

        let plan = HealthSyncPlanner.plan(
            requestedDays: 3,
            endingAt: end,
            cachedDays: [],
            state: HealthSyncCursorState(),
            forceRefreshRecentDays: 3,
            calendar: calendar
        )

        XCTAssertEqual(plan.rawRefreshDays.count, 45)
        XCTAssertEqual(plan.scoreRecomputeDays.count, 3)
    }

    func testHealthSyncPlannerRecomputesForwardFromDirtyDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let end = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_785_369_600))
        let allDays = Set((0..<45).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: end)
        })
        let dirty = calendar.date(byAdding: .day, value: -10, to: end)!
        let dirtyID = DailyHealthSummaryRecord.dayIdentifier(for: dirty, calendar: calendar)
        let state = HealthSyncCursorState(
            lastSuccessfulSyncAt: end.addingTimeInterval(-3_600),
            pendingDirtyDayIdentifiers: [dirtyID]
        )

        let plan = HealthSyncPlanner.plan(
            requestedDays: 3,
            endingAt: end,
            cachedDays: allDays,
            state: state,
            forceRefreshRecentDays: 2,
            calendar: calendar
        )

        XCTAssertTrue(plan.rawRefreshDays.contains(dirty))
        XCTAssertEqual(plan.scoreRecomputeDays.first, dirty)
        XCTAssertEqual(plan.scoreRecomputeDays.last, end)
        XCTAssertEqual(plan.scoreRecomputeDays.count, 11)
    }

    func testHealthSyncCursorStorePersistsDirtyDays() {
        let suiteName = "HealthSyncCursor-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = HealthSyncCursorStore(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_785_369_600)

        store.markDirty(date)

        XCTAssertEqual(store.load().pendingDirtyDayIdentifiers.count, 1)
    }

    func testHealthDayBoundaryAssignsAfterMidnightSamplesToPreviousHealthDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let boundary = HealthDayBoundary(calendar: calendar, boundaryMinutes: 4 * 60)
        let twoAM = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 31, hour: 2
        )))
        let fiveAM = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 31, hour: 5
        )))

        XCTAssertEqual(
            DailyHealthSummaryRecord.dayIdentifier(
                for: boundary.labelDate(containing: twoAM),
                calendar: calendar
            ),
            "2026-07-30"
        )
        XCTAssertEqual(
            DailyHealthSummaryRecord.dayIdentifier(
                for: boundary.labelDate(containing: fiveAM),
                calendar: calendar
            ),
            "2026-07-31"
        )
    }

    func testHealthDayBoundaryUsesCalendarDaysAcrossDSTAndTravelTimeZones() throws {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let boundary = HealthDayBoundary(calendar: losAngeles, boundaryMinutes: 4 * 60)
        let springForward = try XCTUnwrap(losAngeles.date(from: DateComponents(
            year: 2026, month: 3, day: 8, hour: 12
        )))
        let range = boundary.range(containing: springForward)
        XCTAssertEqual(
            losAngeles.dateComponents([.day], from: range.start, to: range.end).day,
            1
        )

        let instant = Date(timeIntervalSince1970: 1_785_369_600)
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let shanghaiLabel = HealthDayBoundary(
            calendar: shanghai,
            boundaryMinutes: 4 * 60
        ).labelDate(containing: instant)
        let losAngelesLabel = HealthDayBoundary(
            calendar: losAngeles,
            boundaryMinutes: 4 * 60
        ).labelDate(containing: instant)
        XCTAssertNotEqual(
            DailyHealthSummaryRecord.dayIdentifier(for: shanghaiLabel, calendar: shanghai),
            DailyHealthSummaryRecord.dayIdentifier(for: losAngelesLabel, calendar: losAngeles)
        )
    }

    private func coverage(_ signal: HealthSignal, usable: Bool) -> HealthSignalCoverage {
        HealthSignalCoverage(
            signal: signal,
            authorizationState: usable ? .readableSamples : .noReadableSamples,
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
        XCTAssertTrue(state.drivers.contains(where: { $0.kind == BodyStateDriver.Kind.nutrition }))
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

final class ProactiveIntelligenceOrchestratorTests: XCTestCase {
    @MainActor
    func testProactiveIntelligenceOrchestratorRunAsyncCheck() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        
        let orchestrator = ProactiveIntelligenceOrchestrator()
        let insights = await orchestrator.runAsyncCheck(modelContext: context)
        
        XCTAssertFalse(insights.isEmpty)
        
        let records = (try? context.fetch(FetchDescriptor<ProactiveInsightRecord>())) ?? []
        XCTAssertEqual(records.count, insights.count)
        
        let events = (try? context.fetch(FetchDescriptor<VelaEventRecord>())) ?? []
        XCTAssertTrue(events.contains(where: { $0.eventType == VelaProductEventType.proactiveInsightGenerated }))
    }
}

final class WorkoutAdaptationServiceTests: XCTestCase {
    @MainActor
    func testWorkoutAdaptationServiceProcessWorkoutCompletion() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        
        let plan = TrainingPlanRecord(
            title: "Hypothalamic Adaptation Plan",
            goalDescription: "Strength Development",
            days: [
                TrainingDay(
                    weekNumber: 1,
                    dayNumber: 1,
                    title: "Lower Body Heavy",
                    description: "Squat 4x5",
                    focus: "strength",
                    durationMinutes: 45,
                    intensity: "high"
                )
            ]
        )
        context.insert(plan)
        try context.save()
        
        let service = WorkoutAdaptationService()
        let workoutID = UUID()
        _ = try await service.processWorkoutCompletion(workoutID: workoutID, modelContext: context)
        
        let events = (try? context.fetch(FetchDescriptor<VelaEventRecord>())) ?? []
        XCTAssertTrue(events.contains(where: { $0.eventType == VelaProductEventType.workoutCompleted }))
    }
}

final class CircadianAlignmentKernelTests: XCTestCase {
    func testCircadianAlignmentKernelEvaluation() {
        let kernel = CircadianAlignmentKernel()
        let input = CircadianInput(
            sleepStartHour: 23.5,
            sleepEndHour: 7.5,
            targetBedtimeHour: 23.0,
            hrvLowestPointHour: 3.5
        )
        let result = kernel.evaluate(input: input)

        XCTAssertEqual(result.phaseOffsetMinutes, 30)
        XCTAssertEqual(result.estimatedCortisolPeak, "08:00")
        XCTAssertEqual(result.caffeineCutoffTime, "13:30")
        XCTAssertFalse(result.recommendations.isEmpty)
    }
}

final class PipelineDiagnosticsLoggerTests: XCTestCase {
    @MainActor
    func testPipelineDiagnosticsSelfCheck() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext

        PipelineDiagnosticsLogger.log(
            modelContext: context,
            stage: "health_kit_sync",
            isSuccess: true,
            summary: "Sync completed successfully."
        )

        let report = PipelineDiagnosticsLogger.performSelfCheck(modelContext: context)

        XCTAssertTrue(report.isHealthy)
        XCTAssertEqual(report.recentErrorsCount, 0)
    }
}

final class ArtifactGeneratorToolTests: XCTestCase {
    @MainActor
    func testArtifactGeneratorToolCreatesAndPersistsArtifactRecord() throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext

        let artifact = ArtifactGeneratorTool.createArtifact(
            type: .morningBrief,
            title: "Today's Briefing",
            summary: "Optimal recovery state.",
            modelContext: context
        )

        XCTAssertEqual(artifact.title, "Today's Briefing")

        let records = (try? context.fetch(FetchDescriptor<AgentArtifactRecord>())) ?? []
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.title, "Today's Briefing")
    }
}

final class BiologicalAgeEngineTests: XCTestCase {
    func testBiologicalAgeEngineEvaluatesHeartRateRecoveryFactor() {
        let engine = BiologicalAgeEngine()
        let input = BiologicalAgeInput(
            chronologicalAge: 28.0,
            restingHR: 58.0,
            vo2Max: 48.0,
            heartRateRecovery: 28.0
        )
        let result = engine.calculate(input: input)

        XCTAssertTrue(result.factors.contains(where: { $0.name.contains("心率恢复") || $0.name.contains("Heart Rate Recovery") }))
        XCTAssertEqual(result.healthAgeTrend, "improving")
    }
}

final class AutonomousHealthDigitalTwinTests: XCTestCase {
    @MainActor
    func testAutonomousHealthDigitalTwinSimulation() {
        let twin = AutonomousHealthDigitalTwin()
        let dashboard = DashboardSummary.empty(date: Date())
        let scenario = SimulationScenarioInput(
            plannedWorkoutStrain: 15.0,
            plannedWorkoutHour: 21.0,
            targetSleepDurationHours: 6.5
        )

        let result = twin.simulateNextDay(dashboard: dashboard, scenario: scenario)

        XCTAssertEqual(result.scenarioTag, "suboptimal_timing")
        XCTAssertLessThan(result.sleepQualityMultiplier, 1.0)
        XCTAssertFalse(result.recommendation.isEmpty)
    }
}

final class FoodVisionIntelligenceEngineTests: XCTestCase {
    func testFoodVisionIntelligenceEngineMealAnalysis() {
        let engine = FoodVisionIntelligenceEngine()
        let result = engine.analyzeMealText("香煎鸡胸肉配紫米饭和西兰花沙拉")

        XCTAssertEqual(result.metabolicTag, "protein_rich")
        XCTAssertGreaterThan(result.proteinGrams, 30)
        XCTAssertGreaterThan(result.estimatedCalories, 300)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
}

final class PersonalBaselineEngineHuberTests: XCTestCase {
    func testHuberMeanRejectsExtremeSingleDayOutliers() {
        let sampleHRVs = [48.0, 52.0, 49.0, 51.0, 50.0, 47.0, 53.0, 250.0]

        let huber = PersonalBaselineEngine.huberMean(sampleHRVs)
        XCTAssertNotNil(huber)
        if let huber {
            XCTAssertLessThan(huber, 60.0)
            XCTAssertGreaterThan(huber, 45.0)
        }
    }
}

final class JournalCrossLaggedCorrelationTests: XCTestCase {
    func testJournalCrossLaggedCorrelationCalculation() {
        let engine = JournalCorrelationEngine()
        let seriesA = [15.0, 16.0, 14.0, 18.0, 12.0, 17.0, 15.0, 19.0]
        let seriesB = [75.0, 50.0, 48.0, 65.0, 35.0, 70.0, 55.0, 30.0]

        let results = engine.calculateCrossLaggedCorrelation(seriesA: seriesA, seriesB: seriesB, maxLagDays: 2)

        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(results.contains(where: \.isOptimalLag))
    }
}

final class WorkoutHeartRateRecoveryMatcherTests: XCTestCase {
    func testMatchesNearestPositiveRecoverySampleToEachWorkoutOnlyOnce() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let first = WorkoutSummary(
            id: UUID(),
            start: base,
            end: base.addingTimeInterval(3_600),
            activityName: "Outdoor Run"
        )
        let second = WorkoutSummary(
            id: UUID(),
            start: base.addingTimeInterval(5 * 3_600),
            end: base.addingTimeInterval(6 * 3_600),
            activityName: "Cycling"
        )
        let samples = [
            HeartRateRecoverySample(date: first.end.addingTimeInterval(120), bpm: 27),
            HeartRateRecoverySample(date: second.end.addingTimeInterval(180), bpm: 31)
        ]

        let result = WorkoutHeartRateRecoveryMatcher.match(samples: samples, workouts: [first, second])

        XCTAssertEqual(result[first.id], 27)
        XCTAssertEqual(result[second.id], 31)
        XCTAssertEqual(result.count, 2)
    }

    func testDoesNotAttachStaleOrNegativeRecoverySamples() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let workout = WorkoutSummary(
            id: UUID(),
            start: base,
            end: base.addingTimeInterval(3_600),
            activityName: "Outdoor Run"
        )
        let samples = [
            HeartRateRecoverySample(date: workout.end.addingTimeInterval(7 * 3_600), bpm: 25),
            HeartRateRecoverySample(date: workout.end.addingTimeInterval(60), bpm: -5)
        ]

        XCTAssertTrue(WorkoutHeartRateRecoveryMatcher.match(samples: samples, workouts: [workout]).isEmpty)
    }
}


