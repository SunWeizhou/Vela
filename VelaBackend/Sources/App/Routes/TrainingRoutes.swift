import Vapor

struct TrainingRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let training = routes.grouped("api", "training")
        training.post("adaptations", use: getAdaptations)
    }

    /// POST /api/training/adaptations
    /// Body: { weekPlan, currentScores, lang }
    func getAdaptations(req: Request) async throws -> TrainingAdaptationResponse {
        let input = try req.content.decode(TrainingAdaptationRequest.self)
        let lang = SupportedLanguage.from(input.lang)
        let llm = LLMService(app: req.application)

        let prompt = PromptService.trainingAdaptationPrompt(
            weekPlan: input.weekPlan,
            context: input.currentScores,
            lang: lang.rawValue
        )

        let jsonStr = try await llm.jsonCompletion(
            prompt: prompt,
            temperature: PromptService.tempBalanced,
            lang: lang.rawValue
        )

        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw Abort(.internalServerError, reason: "Failed to parse LLM response")
        }

        let adaptations: [TrainingAdaptationResponse.DayAdaptation] = array.compactMap { day -> TrainingAdaptationResponse.DayAdaptation? in
            guard let dayName = day["day"] as? String,
                  let keep = day["keep_original"] as? Bool,
                  let reason = day["reason"] as? String,
                  let conf = day["confidence"] as? Double else { return nil }

            var suggestion: TrainingAdaptationRequest.TrainingDay?
            if !keep, let sug = day["suggestion"] as? [String: Any] {
                suggestion = TrainingAdaptationRequest.TrainingDay(
                    day: dayName,
                    title: sug["title"] as? String ?? "",
                    focus: sug["focus"] as? String ?? "rest",
                    durationMinutes: sug["duration_minutes"] as? Int ?? 30,
                    intensity: sug["intensity"] as? String ?? "low",
                    status: "adaptive"
                )
            }

            return TrainingAdaptationResponse.DayAdaptation(
                original: input.weekPlan.first(where: { $0.day == dayName }) ?? TrainingAdaptationRequest.TrainingDay(day: dayName, title: "", focus: "", durationMinutes: 0, intensity: "low", status: "unknown"),
                suggestion: suggestion,
                reason: reason,
                keepOriginal: keep,
                confidence: conf
            )
        }

        return TrainingAdaptationResponse(adaptations: adaptations)
    }
}
