import XCTest
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
    }

    @MainActor
    func testAgentLoopStreamsOnlyAfterNoToolCallsRemain() async throws {
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

        XCTAssertEqual(result.response, "stream final")
        XCTAssertEqual(streamed, "stream final")
        XCTAssertEqual(result.executedTools.map(\.name), ["first_tool"])
        XCTAssertEqual(provider.streamCallCount, 1)
        XCTAssertEqual(provider.chatCallToolAvailability, [true, true])
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
