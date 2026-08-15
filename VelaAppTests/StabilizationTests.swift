import XCTest
import SwiftData
@testable import Vela

@MainActor
final class StabilizationTests: XCTestCase {
    private struct TestStore {
        let container: ModelContainer
        let context: ModelContext
    }

    private func makeStore() throws -> TestStore {
        let container = try VelaModelContainer.make(inMemory: true)
        return TestStore(container: container, context: ModelContext(container))
    }

    func testTrainingDecisionKernelV2FatigueAndResponseHistory() throws {
        // Create an input with chest muscle fatigue
        let date = Date()
        let localFatigue: [String: LocalMuscleFatigue] = [
            "chest": LocalMuscleFatigue(muscleGroup: "chest", fatigueLevel: "high", lastTrainedAt: date.addingTimeInterval(-2 * 86_400))
        ]
        
        let bodyState = BodyState(
            date: date,
            readiness: .optimal,
            confidence: .high,
            freshness: .live,
            activeStatus: "active",
            drivers: [],
            localFatigue: localFatigue,
            source: "Test"
        )
        
        // Mock active plan with Chest exercises today
        let plan = TrainingPlanRecord(
            title: "Chest Plan",
            goalDescription: "Grow Chest",
            weeksCount: 4,
            days: [
                TrainingDay(
                    weekNumber: 1,
                    dayNumber: Calendar.current.component(.weekday, from: date) == 1 ? 7 : Calendar.current.component(.weekday, from: date) - 1,
                    focus: "Chest",
                    title: "Chest Day",
                    description: "Focus on chest",
                    intensity: 8,
                    durationMinutes: 45,
                    plannedExercisesJSON: "[{\"exerciseCanonicalKey\":\"bench_press\",\"name\":\"卧推\",\"setsCount\":4,\"repsCount\":10,\"intensityRPE\":8,\"restSeconds\":90}]"
                )
            ],
            isActive: true
        )
        
        let input = TrainingDecisionInput(
            bodyState: bodyState,
            activePlan: plan,

            trainingResponses: []
        )
        
        let decision = TrainingDecisionKernel().decide(input: input)
        
        // Due to chest local fatigue being high, it should suggest swap!
        XCTAssertEqual(decision.decision, .swap)
        XCTAssertTrue(decision.reasons.contains { $0.contains("局部疲劳") })
    }

    func testTrainingDecisionKernelV2PoorResponseHistory() throws {
        let date = Date()
        let bodyState = BodyState(
            date: date,
            readiness: .optimal,
            confidence: .high,
            freshness: .live,
            activeStatus: "active",
            drivers: [],
            localFatigue: [:],
            source: "Test"
        )
        
        // Mock poor recovery response in the past 28 days for chest
        let response = TrainingResponseRecord(
            date: date.addingTimeInterval(-3 * 86_400),
            workoutTitle: "Chest Day",
            primaryMuscleGroups: ["chest"],
            nextDayRecoveryDelta: -10, // poor recovery delta
            nextDayHRVDelta: -12,
            nextDayRHRDelta: 6
        )
        
        let plan = TrainingPlanRecord(
            title: "Chest Plan",
            goalDescription: "Grow Chest",
            weeksCount: 4,
            days: [
                TrainingDay(
                    weekNumber: 1,
                    dayNumber: Calendar.current.component(.weekday, from: date) == 1 ? 7 : Calendar.current.component(.weekday, from: date) - 1,
                    focus: "Chest",
                    title: "Chest Day",
                    description: "Focus on chest",
                    intensity: 8,
                    durationMinutes: 45,
                    plannedExercisesJSON: "[{\"exerciseCanonicalKey\":\"bench_press\",\"name\":\"卧推\",\"setsCount\":4,\"repsCount\":10,\"intensityRPE\":8,\"restSeconds\":90}]"
                )
            ],
            isActive: true
        )
        
        let input = TrainingDecisionInput(
            bodyState: bodyState,
            activePlan: plan,

            trainingResponses: [response]
        )
        
        let decision = TrainingDecisionKernel().decide(input: input)
        
        // Due to recent poor recovery for chest, it should suggest reduce!
        XCTAssertEqual(decision.decision, .reduce)
        XCTAssertTrue(decision.reasons.contains { $0.contains("训练响应") })
    }

    struct MockChatProvider: AgentChatProvider {
        var response: LLMResponse
        func chat(messages: [ChatMessage], tools: [[String: Value]]?) async throws -> LLMResponse {
            return response
        }
        func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
            return AsyncThrowingStream { continuation in
                continuation.yield(response.content)
                continuation.finish()
            }
        }
    }

    func testAgentPermissionsHardeningRefusal() async throws {
        let store = try makeStore()
        let executionContext = ToolExecutionContext(modelContext: store.context, dashboard: DashboardSummary(date: Date(), source: .healthKit))
        
        let toolRegistry = ToolRegistry(tools: [
            FoodLogTool(executionContext: executionContext),
            CreateTrainingPlanTool(executionContext: executionContext),
            DeleteTrainingPlanTool(executionContext: executionContext)
        ])
        
        let tc = ToolCall(id: "tc_1", name: "log_food", arguments: "{\"meal_name\":\"Lunch\",\"foods\":[\"chicken\"],\"total_calories\":500}")
        let mockResponse = LLMResponse(content: "I will log this food.", toolCalls: [tc], reasoningContent: nil)
        let provider = MockChatProvider(response: mockResponse)
        
        // 1. With nil confirmation callback -> Refusal expected
        let agentLoopNoCallback = AgentLoop(provider: provider, toolRegistry: toolRegistry, onConfirmToolCall: nil)
        let resultNoCallback = try? await agentLoopNoCallback.run(messages: [ChatMessage(role: .user, content: "log food")], initialDataVersion: "1")
        
        XCTAssertNotNil(resultNoCallback)
        let toolMessagesNoCallback = resultNoCallback?.trace.executedTools ?? []
        XCTAssertEqual(toolMessagesNoCallback.count, 0) // should not have executed successfully

        // 2. With false returning callback -> User rejection expected
        let agentLoopRejected = AgentLoop(provider: provider, toolRegistry: toolRegistry, onConfirmToolCall: { _ in false })
        let resultRejected = try? await agentLoopRejected.run(messages: [ChatMessage(role: .user, content: "log food")], initialDataVersion: "1")
        XCTAssertNotNil(resultRejected)
    }

    func testDailyPlanRefreshCoordinatorDeduplicates() async throws {
        let store = try makeStore()
        let coordinator = DailyPlanRefreshCoordinator.shared
        
        let date = Date()
        // Run coordinator to generate initial plan
        await coordinator.refreshPlan(for: date, modelContext: store.context)
        
        let planDescriptor = FetchDescriptor<DailyOperatingPlanRecord>()
        let plansAfterFirst = try store.context.fetch(planDescriptor)
        XCTAssertEqual(plansAfterFirst.count, 1)
        let firstHash = plansAfterFirst.first?.bodyStateHash
        XCTAssertNotNil(firstHash)
        
        // Run again, should check hash and deduplicate (skipping upsert)
        await coordinator.refreshPlan(for: date, modelContext: store.context)
        
        let plansAfterSecond = try store.context.fetch(planDescriptor)
        XCTAssertEqual(plansAfterSecond.count, 1)
        XCTAssertEqual(plansAfterSecond.first?.bodyStateHash, firstHash)
    }
}
