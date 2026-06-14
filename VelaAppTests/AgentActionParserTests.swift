import XCTest
import SwiftData
@testable import Vela

final class AgentActionParserTests: XCTestCase {
    func testAgentActionParserPlaceholder() {
        XCTAssertTrue(true)
    }

    func testCoachArtifactParserParsesStructuredJSON() throws {
        let json = """
        {
          "artifactType": "morning_brief",
          "title": "今天适合减量训练",
          "summary": "睡眠充足，但 HRV 低于基线且下肢局部负荷偏高。",
          "decision": "reduce",
          "confidence": 0.78,
          "reasons": [
            {
              "signal": "HRV",
              "value": "below_baseline",
              "explanation": "HRV 低于 14 天基线，提示恢复压力偏高。"
            }
          ],
          "actions": [
            {
              "type": "adjust_workout",
              "label": "将今天训练容量降低 20%",
              "payload": {}
            }
          ],
          "followUpQuestion": "训练后是否感觉异常疲劳？"
        }
        """

        let artifact = try CoachArtifactParser.parse(json, sourceContextHash: "ctx-1")

        XCTAssertEqual(artifact.type, .morningBrief)
        XCTAssertEqual(artifact.decision, "reduce")
        XCTAssertEqual(artifact.confidence, 0.78, accuracy: 0.001)
        XCTAssertEqual(artifact.reasons.first?.signal, "HRV")
        XCTAssertEqual(artifact.actions.first?.type, "adjust_workout")
        XCTAssertEqual(artifact.sourceContextHash, "ctx-1")
    }

    func testCoachArtifactParserFallsBackWhenJSONIsInvalid() {
        let artifact = CoachArtifactParser.fallback(
            from: "今天数据不足，但建议先做轻量活动。",
            type: .askCoachAnswer,
            sourceContextHash: "ctx-fallback"
        )

        XCTAssertEqual(artifact.type, .askCoachAnswer)
        XCTAssertEqual(artifact.status, .created)
        XCTAssertEqual(artifact.sourceContextHash, "ctx-fallback")
        XCTAssertTrue(artifact.summary.contains("轻量活动"))
        XCTAssertEqual(artifact.actions.first?.type, "start_check_in")
    }

    func testAgentLoopRunsMultipleToolIterationsBeforeFinalAnswer() async throws {
        let provider = FakeAgentChatProvider(responses: [
            LLMResponse(
                content: "",
                toolCalls: [ToolCall(id: "call-1", name: "first_tool", arguments: #"{"step":1}"#)]
            ),
            LLMResponse(
                content: "",
                toolCalls: [ToolCall(id: "call-2", name: "second_tool", arguments: #"{"step":2}"#)]
            ),
            LLMResponse(content: "final answer", toolCalls: nil)
        ])
        let registry = ToolRegistry(tools: [
            StaticAgentTool(name: "first_tool", result: "first result"),
            StaticAgentTool(name: "second_tool", result: "second result")
        ])
        let loop = AgentLoop(provider: provider, toolRegistry: registry, maxIterations: 3)

        let result = try await loop.run(messages: [ChatMessage(role: .user, content: "run tools")])

        XCTAssertEqual(result.response, "final answer")
        XCTAssertEqual(result.executedTools.map(\.name), ["first_tool", "second_tool"])
        XCTAssertEqual(provider.chatCallToolAvailability, [true, true, true])
        XCTAssertEqual(result.finalMessages.filter { $0.role == .tool }.map(\.content), ["first result", "second result"])
        XCTAssertEqual(result.trace.executedTools.map(\.name), ["first_tool", "second_tool"])
        XCTAssertEqual(result.trace.finalResponse, "final answer")
        XCTAssertFalse(result.trace.contextHash.isEmpty)
    }

    @MainActor
    func testHealthTrendToolReturnsRequestedMetricsAndWindow() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date()
        context.insert(DailyHealthSummaryRecord(
            dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: now),
            date: now,
            recoveryScore: 72,
            stressIndex: 38,
            currentEnergy: 64,
            hrvAverage: 51,
            restingHeartRate: 57,
            sleepHours: 7.4
        ))
        try context.save()

        let output = try await HealthTrendTool(
            executionContext: ToolExecutionContext(modelContext: context, dashboard: .preview(date: now))
        ).execute(arguments: #"{"days":14,"metrics":["hrv","rhr","sleep","recovery","stress","energy"]}"#)

        XCTAssertTrue(output.contains(#""days" : 14"#))
        XCTAssertTrue(output.contains(#""hrv" : 51"#))
        XCTAssertTrue(output.contains(#""recovery" : 72"#))
        XCTAssertTrue(output.contains(#""source" : "DailyHealthSummaryRecord""#))
    }

    @MainActor
    func testTrainingResponseHistoryToolReturnsRecoveryDeltasAndFlags() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let now = Date()
        context.insert(TrainingResponseRecord(
            workoutId: UUID(),
            date: now.addingTimeInterval(-86_400),
            nextDayDate: now,
            primaryMuscleGroups: ["legs"],
            totalEffectiveSets: 12,
            totalVolumeKg: 8_400,
            sessionRPE: 8,
            nextDayRecoveryDelta: -11,
            nextDayHRVDelta: -13,
            nextDayRHRDelta: 6
        ))
        try context.save()

        let output = try await TrainingResponseHistoryTool(
            executionContext: ToolExecutionContext(modelContext: context, dashboard: .preview(date: now))
        ).execute(arguments: #"{"days":28,"muscle_group":"legs"}"#)

        XCTAssertTrue(output.contains(#""next_day_recovery_delta" : -11"#))
        XCTAssertTrue(output.contains(#""primary_muscle_groups" : ["#))
        XCTAssertTrue(output.contains(#""flagged" : true"#))
    }

    func testAgentLoopRequestsFinalAnswerWhenLastAllowedIterationStillUsesTool() async throws {
        let provider = FakeAgentChatProvider(responses: [
            LLMResponse(
                content: "",
                toolCalls: [ToolCall(id: "call-1", name: "first_tool", arguments: "{}")]
            ),
            LLMResponse(
                content: "",
                toolCalls: [ToolCall(id: "call-2", name: "second_tool", arguments: "{}")]
            ),
            LLMResponse(content: "final after tools", toolCalls: nil)
        ])
        let registry = ToolRegistry(tools: [
            StaticAgentTool(name: "first_tool", result: "first result"),
            StaticAgentTool(name: "second_tool", result: "second result")
        ])
        let loop = AgentLoop(provider: provider, toolRegistry: registry, maxIterations: 2)

        let result = try await loop.run(messages: [ChatMessage(role: .user, content: "run bounded tools")])

        XCTAssertEqual(result.response, "final after tools")
        XCTAssertEqual(result.executedTools.map(\.name), ["first_tool", "second_tool"])
        XCTAssertEqual(provider.chatCallToolAvailability, [true, true, false])
    }

    @MainActor
    func testAgentLoopPublishesExistingFinalResponseWithoutDuplicateStreamingRequest() async throws {
        let provider = FakeAgentChatProvider(
            responses: [
                LLMResponse(
                    content: "",
                    toolCalls: [ToolCall(id: "call-1", name: "first_tool", arguments: "{}")]
                ),
                LLMResponse(content: "non-stream final", toolCalls: nil)
            ],
            streamChunks: ["stream ", "final"]
        )
        let registry = ToolRegistry(tools: [
            StaticAgentTool(name: "first_tool", result: "first result")
        ])
        let loop = AgentLoop(provider: provider, toolRegistry: registry, maxIterations: 3)
        var streamed = ""

        let result = try await loop.run(
            messages: [ChatMessage(role: .user, content: "run tool then stream")],
            onStreamDelta: { streamed += $0 }
        )

        XCTAssertEqual(result.response, "non-stream final")
        XCTAssertEqual(streamed, "non-stream final")
        XCTAssertEqual(result.executedTools.map(\.name), ["first_tool"])
        XCTAssertEqual(provider.streamCallCount, 0)
        XCTAssertEqual(provider.chatCallToolAvailability, [true, true])
        XCTAssertEqual(result.trace.providerCallCount, 2)
    }

    func testProviderFailureMessageClassifiesOfflineTimeoutAndAuthentication() {
        XCTAssertEqual(
            LLMProviderError.classify(URLError(.notConnectedToInternet)),
            .networkUnavailable
        )
        XCTAssertEqual(
            LLMProviderError.classify(URLError(.timedOut)),
            .timedOut
        )
        XCTAssertEqual(
            LLMProviderError.httpFailure(statusCode: 401, body: "invalid key"),
            .authenticationFailed
        )
        XCTAssertTrue(LLMProviderError.networkUnavailable.userFacingMessage(isChinese: true).contains("网络"))
        XCTAssertTrue(LLMProviderError.authenticationFailed.userFacingMessage(isChinese: false).contains("Settings"))
    }

    @MainActor
    func testUnifiedWorkoutHistoryToolReturnsMergedWorkoutTimeline() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date().addingTimeInterval(-3600)
        let strength = StrengthWorkoutRecord(
            title: "背部二头",
            startedAt: start,
            durationMinutes: 60,
            exercises: [
                StrengthExerciseLog(
                    name: "杠铃划船",
                    equipment: "barbell",
                    primaryMuscleGroup: "back",
                    sets: [StrengthSetLog(repetitions: 8, weightKilograms: 80, isCompleted: true)]
                )
            ]
        )
        context.insert(strength)
        context.insert(WorkoutEventRecord(
            source: "healthKit+xunji",
            startedAt: start,
            endedAt: start.addingTimeInterval(3600),
            activityType: "TraditionalStrengthTraining",
            title: "背部二头",
            energyKilocalories: 420,
            averageHeartRate: 132,
            linkedStrengthWorkoutId: strength.id,
            linkedHealthKitWorkoutId: UUID()
        ))
        try context.save()

        let tool = UnifiedWorkoutHistoryTool(
            executionContext: ToolExecutionContext(modelContext: context, dashboard: .preview())
        )
        let output = try await tool.execute(arguments: #"{"days":7,"include_strength_details":true}"#)

        XCTAssertTrue(output.contains("healthKit+xunji"))
        XCTAssertTrue(output.contains("背部二头"))
        XCTAssertTrue(output.contains("杠铃划船"))
        XCTAssertTrue(output.contains("strength_details"))
    }

    @MainActor
    func testUnifiedWorkoutHistoryToolSeparatesCompletedAndUncompletedStrengthSets() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        let start = Date().addingTimeInterval(-3600)
        let strength = StrengthWorkoutRecord(
            title: "胸部训练",
            startedAt: start,
            durationMinutes: 50,
            exercises: [
                StrengthExerciseLog(
                    name: "杠铃卧推",
                    equipment: "barbell",
                    primaryMuscleGroup: "chest",
                    sets: [
                        StrengthSetLog(repetitions: 8, weightKilograms: 80, isCompleted: true),
                        StrengthSetLog(repetitions: 8, weightKilograms: 90, isCompleted: false),
                        StrengthSetLog(repetitions: 5, weightKilograms: 60, isWarmup: true, isCompleted: true)
                    ]
                )
            ]
        )
        context.insert(strength)
        context.insert(WorkoutEventRecord(
            source: "healthKit+xunji",
            startedAt: start,
            endedAt: start.addingTimeInterval(3000),
            activityType: "TraditionalStrengthTraining",
            title: "胸部训练",
            linkedStrengthWorkoutId: strength.id,
            linkedHealthKitWorkoutId: UUID()
        ))
        try context.save()

        let tool = UnifiedWorkoutHistoryTool(
            executionContext: ToolExecutionContext(modelContext: context, dashboard: .preview())
        )
        let output = try await tool.execute(arguments: #"{"days":7,"include_strength_details":true}"#)

        XCTAssertTrue(output.contains(#""completed_work_sets" : 1"#))
        XCTAssertTrue(output.contains(#""completed_volume_kilograms" : 640"#))
        XCTAssertTrue(output.contains(#""uncompleted_sets" : ["#))
        XCTAssertTrue(output.contains(#""weight_kilograms" : 90"#))
        XCTAssertTrue(output.contains(#""warmup_sets" : ["#))
    }

    @MainActor
    func testHealthHistoryToolReturnsDailyBodyMetrics() async throws {
        let container = try VelaModelContainer.make(inMemory: true)
        let context = container.mainContext
        context.insert(DailyHealthSummaryRecord(
            dayIdentifier: DailyHealthSummaryRecord.dayIdentifier(for: Date()),
            date: Date(),
            sleepScore: 82,
            recoveryScore: 74,
            strainScore: 41,
            hrvAverage: 52,
            restingHeartRate: 58,
            sleepHours: 7.3,
            bodyWeight: 76.5,
            oxygenSaturation: 98,
            dailyLoad: 88,
            tsb: -4
        ))
        try context.save()

        let tool = HealthHistoryTool(
            executionContext: ToolExecutionContext(modelContext: context, dashboard: .preview())
        )
        let output = try await tool.execute(arguments: #"{"days":7}"#)

        XCTAssertTrue(output.contains(#""recovery_score" : 74"#))
        XCTAssertTrue(output.contains(#""hrv_average" : 52"#))
        XCTAssertTrue(output.contains(#""body_weight" : 76.5"#))
        XCTAssertTrue(output.contains(#""daily_load" : 88"#))
    }
}

private final class FakeAgentChatProvider: AgentChatProvider, @unchecked Sendable {
    private var responses: [LLMResponse]
    private let streamChunks: [String]

    private(set) var chatCallToolAvailability: [Bool] = []
    private(set) var streamCallCount: Int = 0

    init(responses: [LLMResponse], streamChunks: [String] = []) {
        self.responses = responses
        self.streamChunks = streamChunks
    }

    func chat(messages: [ChatMessage], tools: [[String: Value]]?) async throws -> LLMResponse {
        chatCallToolAvailability.append(tools?.isEmpty == false)
        guard !responses.isEmpty else {
            return LLMResponse(content: "", toolCalls: nil)
        }
        return responses.removeFirst()
    }

    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        streamCallCount += 1
        let chunks = streamChunks

        return AsyncThrowingStream { continuation in
            for chunk in chunks {
                continuation.yield(chunk)
            }
            continuation.finish()
        }
    }
}

private struct StaticAgentTool: AgentTool {
    let name: String
    let result: String
    let description = "Static test tool."
    let parameters: [String: Value] = ["type": .string("object")]

    func execute(arguments: String) async throws -> String {
        result
    }
}
