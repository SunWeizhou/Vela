import Vapor
import Fluent

struct CoachRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let coach = routes.grouped("api", "coach")
        coach.post("chat", use: chat)
    }

    /// POST /api/coach/chat
    /// Request: { message, lang, user_context, history }
    /// Response: { reply, insights, suggestedActions, toolCalls }
    func chat(req: Request) async throws -> CoachChatResponse {
        let input = try req.content.decode(CoachChatRequest.self)
        let lang = SupportedLanguage.from(input.lang)
        let llm = LLMService(app: req.application)

        // ── Build system prompt ──
        let systemPrompt = PromptService.coachSystemPrompt(
            lang: lang.rawValue,
            personality: input.personality ?? "friend"
        )

        // ── Inject health context into user message ──
        var userMessage = input.message
        if let ctx = input.userContext {
            userMessage = """
            ## 用户当前健康数据
            \(PromptService.formatHealthContext(ctx))

            ## 用户问题
            \(input.message)
            """
        }

        // ── Build message history ──
        var messages: [ChatMessage] = (input.history ?? []).map {
            ChatMessage(role: $0.role, content: $0.content)
        }
        messages.append(ChatMessage(role: "user", content: userMessage))

        // ── Call LLM with tools ──
        let initialResponse = try await llm.chat(
            messages: messages,
            systemPrompt: systemPrompt,
            tools: LLMService.coachTools,
            temperature: PromptService.tempCreative,
            lang: lang.rawValue
        )
        let toolResults = try await executeToolCalls(
            initialResponse.toolCalls ?? [],
            req: req
        )
        let response: ChatResponse
        if toolResults.isEmpty {
            response = initialResponse
        } else {
            let executionSummary = toolResults
                .map { "- \($0.name): \($0.result)" }
                .joined(separator: "\n")
            let toolNames = toolResults.map(\.name).joined(separator: ", ")
            messages.append(ChatMessage(
                role: "assistant",
                content: initialResponse.content.isEmpty
                    ? "I requested these tools: \(toolNames)."
                    : initialResponse.content
            ))
            messages.append(ChatMessage(
                role: "user",
                content: """
                Tool execution results:
                \(executionSummary)

                Use these completed results to answer my original question. Do not claim a tool ran unless its result says it succeeded.
                """
            ))
            response = try await llm.chat(
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: PromptService.tempBalanced,
                lang: lang.rawValue
            )
        }

        // ── Audit log ──
        try await logAudit(req: req, tool: "coach_chat", params: input.message, result: "success")

        return CoachChatResponse(
            reply: response.content,
            insights: extractInsights(from: response.content),
            suggestedActions: extractActions(from: response.content),
            toolCalls: toolResults.isEmpty ? nil : toolResults
        )
    }

    private func executeToolCalls(_ calls: [ToolCall], req: Request) async throws -> [ToolCallInfo] {
        guard !calls.isEmpty else { return [] }
        let userId = try req.authenticatedUser()
        var results: [ToolCallInfo] = []

        for call in calls {
            let result: String
            switch call.name {
            case "propose_memory":
                let pattern = call.input.string("pattern") ?? "Health pattern"
                let description = call.input.string("description") ?? ""
                let evidence = call.input.string("evidence") ?? description
                let confidence = min(max(call.input.double("confidence") ?? 0.5, 0), 1)
                let card = MemoryCard(
                    userId: userId,
                    pattern: pattern,
                    evidence: evidence,
                    confidence: confidence
                )
                try await card.save(on: req.db)
                result = "Succeeded. Added a pending memory card for user review."
            case "suggest_training":
                let focus = call.input.string("focus") ?? "rest"
                let duration = call.input.int("duration_minutes") ?? 30
                let intensity = call.input.string("intensity") ?? "low"
                let reason = call.input.string("reason") ?? "Based on today's readiness."
                result = "Succeeded. Suggested \(duration) minutes of \(focus) at \(intensity) intensity. \(reason)"
            default:
                result = "Failed. Unsupported tool."
            }

            results.append(ToolCallInfo(
                name: call.name,
                arguments: "\(call.input)",
                result: result
            ))
            try await logAudit(req: req, tool: call.name, params: "\(call.input)", result: result)
        }
        return results
    }

    private func extractInsights(from text: String) -> [String] {
        // Parse structured sections: "证据：" or "判断："
        var insights: [String] = []
        let lines = text.components(separatedBy: "\n")
        for line in lines where line.contains("判断") || line.contains("证据") {
            insights.append(line.trimmingCharacters(in: .whitespaces))
        }
        return insights.isEmpty ? [String(text.prefix(100))] : insights
    }

    private func extractActions(from text: String) -> [String] {
        var actions: [String] = []
        let lines = text.components(separatedBy: "\n")
        for line in lines where line.contains("建议") || line.contains("行动") || line.contains("避坑") {
            actions.append(line.trimmingCharacters(in: .whitespaces))
        }
        return actions
    }

    private func logAudit(req: Request, tool: String, params: String, result: String) async throws {
        let entry = TrustAuditEntry(
            userId: try req.authenticatedUser(),
            toolName: tool,
            parameters: params,
            resultStatus: result,
            modelVersion: Environment.get("LLM_MODEL") ?? "claude-sonnet-4-6"
        )
        try await entry.save(on: req.db)
    }
}

private extension Dictionary where Key == String, Value == AnyCodable {
    func string(_ key: String) -> String? {
        self[key]?.value as? String
    }

    func int(_ key: String) -> Int? {
        if let int = self[key]?.value as? Int { return int }
        if let double = self[key]?.value as? Double { return Int(double) }
        return nil
    }

    func double(_ key: String) -> Double? {
        if let double = self[key]?.value as? Double { return double }
        if let int = self[key]?.value as? Int { return Double(int) }
        return nil
    }
}
