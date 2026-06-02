import Vapor

struct InsightsRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.post("api", "insights", "evidence", use: getEvidence)
    }

    /// POST /api/insights/evidence
    func getEvidence(req: Request) async throws -> EvidenceResponse {
        let input = try req.content.decode(EvidenceRequest.self)
        let lang = SupportedLanguage.from(input.lang)
        let llm = LLMService(app: req.application)

        let prompt = PromptService.evidenceChainPrompt(
            claim: input.claim,
            context: input.context,
            lang: lang.rawValue
        )

        let jsonStr = try await llm.jsonCompletion(prompt: prompt, temperature: PromptService.tempFactual, lang: lang.rawValue)

        guard let data = jsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chain = json["evidence_chain"] as? [[String: Any]] else {
            throw Abort(.internalServerError, reason: "Failed to parse evidence chain")
        }

        return EvidenceResponse(
            evidenceChain: chain.compactMap { link in
                guard let dp = link["data_point"] as? String,
                      let val = link["value"] as? String,
                      let reason = link["reasoning"] as? String,
                      let dir = link["direction"] as? String,
                      let conf = link["confidence"] as? Double else { return nil }
                return EvidenceResponse.EvidenceLink(
                    dataPoint: dp, value: val,
                    trend: link["deviation"] as? String ?? dir,
                    reasoning: reason, confidence: conf
                )
            },
            overallConfidence: json["overall_confidence"] as? Double ?? 0.5,
            summary: json["overall_assessment"] as? String ?? ""
        )
    }
}
