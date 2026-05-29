import Foundation
import SwiftData

// MARK: - Tool Definition

protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Value] { get }
    func execute(arguments: String) async throws -> String
}

extension AgentTool {
    var definition: [String: Value] {
        [
            "type": .string("function"),
            "function": .object([
                "name": .string(name),
                "description": .string(description),
                "parameters": .object(parameters),
            ]),
        ]
    }
}

// MARK: - Tool Registry

struct ToolRegistry {
    private let tools: [AgentTool]

    init(tools: [AgentTool]) {
        self.tools = tools
    }

    var definitions: [[String: Value]] {
        tools.map { $0.definition }
    }

    func execute(name: String, arguments: String) async -> String {
        guard let tool = tools.first(where: { $0.name == name }) else {
            return "Error: unknown tool '\(name)'"
        }
        do {
            return try await tool.execute(arguments: arguments)
        } catch {
            return "Error executing '\(name)': \(error.localizedDescription)"
        }
    }
}

// MARK: - Concrete Tools

/// Searches Bing.com for web results.
struct WebSearchTool: AgentTool {
    let name = "web_search"
    let description = "Search the web for up-to-date health research, medical guidelines, nutrition information, or scientific studies. Use this when the user asks about recent findings, treatment guidelines, supplement recommendations, or any question requiring current external knowledge."

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("The search query. Write in English for best results."),
                ]),
            ]),
            "required": .array([.string("query")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = json["query"] as? String else {
            return "Error: missing or invalid 'query' argument."
        }
        let results = await WebSearchHelper.shared.search(query, maxResults: 3)
        return results.isEmpty ? "No search results found for '\(query)'." : results
    }
}

/// Updates a wiki file in the user's profile.
struct UpdateWikiTool: AgentTool {
    let name = "update_user_wiki"
    let description = "Update the user's wiki profile with new long-term preferences, habits, health context, training goals, or physiological baseline changes. Available files: goals.md, habits.md, training_history.md, health_context.md, notes.md."

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "file": .object([
                    "type": .string("string"),
                    "description": .string("The wiki file to update (e.g., goals.md, habits.md, health_context.md, training_history.md, notes.md)"),
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("The new content to write. Only include confirmed long-term changes, not single-day observations."),
                ]),
            ]),
            "required": .array([.string("file"), .string("content")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let file = json["file"] as? String,
              let content = json["content"] as? String else {
            return "Error: missing 'file' or 'content' arguments."
        }
        try WikiFileService.updateSection(filename: file, content: content, mode: .merge)
        return "Successfully updated \(file)."
    }
}

/// Queries today's specific health metrics from the already-loaded context.
/// This tool only works when health data has been provided in the system prompt.
/// The coach should reference the context JSON directly most of the time —
/// use this tool only when the user asks for a specific metric value.
struct HealthDataTool: AgentTool {
    let name = "check_health_data"
    let description = "Retrieve a specific health metric value from today's context when the user asks for an exact number. Use this sparingly — most data is visible in the system prompt context JSON."

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "metric": .object([
                    "type": .string("string"),
                    "description": .string("The metric to retrieve. One of: sleep_score, recovery_score, strain_score, stress_index, hrv_avg, rhr_avg, energy_bank, health_age, steps, active_calories, sleep_hours, sleep_efficiency, rem_percent, deep_percent, resting_hr, workouts_today."),
                ]),
            ]),
            "required": .array([.string("metric")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metric = json["metric"] as? String else {
            return "Error: missing 'metric' argument."
        }
        return "Metric '\(metric)' data is available in the system context JSON. Refer to the context provided in your system prompt for the exact value."
    }
}

/// Generates a personalized training plan based on today's recovery, strain,
/// energy bank (ATL/CTL/TSB), sleep, and stress scores. The tool returns a
/// structured readiness context that the LLM uses to craft the final plan.
struct TrainingPlanTool: AgentTool {
    let name = "generate_training_plan"
    let description = "Generate a personalized training plan recommendation based on today's physiological readiness (recovery, strain, energy bank, sleep, stress) and the user's Wiki goals. Use this when the user asks about workout plans, training recommendations, or whether they should train today."

    // Today's scores — populated from the dashboard
    let recoveryScore: Double
    let strainScore: Double
    let energyBankScore: Double
    let atl: Double
    let ctl: Double
    let tsb: Double
    let sleepScore: Double
    let stressIndex: Double

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "focus": .object([
                    "type": .string("string"),
                    "description": .string("Training focus area: cardio, strength, flexibility, or rest"),
                ]),
                "duration_minutes": .object([
                    "type": .string("integer"),
                    "description": .string("Desired workout duration in minutes (typically 15–120)"),
                ]),
                "intensity": .object([
                    "type": .string("string"),
                    "description": .string("Desired intensity level: low, moderate, or high"),
                ]),
            ]),
            "required": .array([.string("focus")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let focus = json["focus"] as? String else {
            return "Error: missing 'focus' argument."
        }

        let duration = json["duration_minutes"] as? Int ?? 45
        let intensity = json["intensity"] as? String ?? "moderate"

        // ── Readiness Assessment ──
        let readinessLevel: String
        let readinessGuidance: String

        if recoveryScore > 75 && energyBankScore > 60 && tsb > 5 {
            readinessLevel = "HIGH"
            readinessGuidance = "Body is primed for intense training. Push hard — this is an optimal biological window for progression."
        } else if recoveryScore > 50 && energyBankScore > 40 {
            readinessLevel = "MODERATE"
            readinessGuidance = "Train at controlled intensity. Moderate load or active recovery is appropriate."
        } else {
            readinessLevel = "LOW"
            readinessGuidance = "Prioritize recovery. Recommend rest or light mobility work only."
        }

        // ── Build structured context for the LLM ──
        var context = ""
        context += "## Training Plan Context (generated by generate_training_plan tool)\n\n"

        context += "### Today's Physiological State\n"
        context += "| Metric | Score |\n"
        context += "|--------|-------|\n"
        context += "| Recovery | \(Int(recoveryScore.rounded()))/100 |\n"
        context += "| Sleep | \(Int(sleepScore.rounded()))/100 |\n"
        context += "| Strain (today) | \(Int(strainScore.rounded()))/100 |\n"
        context += "| Stress Index | \(Int(stressIndex.rounded()))/100 |\n"
        context += "| Energy Bank | \(Int(energyBankScore.rounded()))/100 |\n\n"

        context += "### Training Load Status (Banister ATL/CTL/TSB)\n"
        context += "| Metric | Value |\n"
        context += "|--------|-------|\n"
        context += "| ATL (Acute, 7-day) | \(Int(atl.rounded())) |\n"
        context += "| CTL (Chronic, 42-day) | \(Int(ctl.rounded())) |\n"
        context += "| TSB (Fitness — Fatigue) | \(Int(tsb.rounded())) |\n"

        if tsb < -15 {
            context += "\nTSB is deeply negative — the athlete is carrying significant accumulated fatigue. Recommend reduced load or a deload day.\n"
        } else if tsb < -5 {
            context += "\nTSB is slightly negative — some fatigue accumulation. Train but avoid maximum intensity.\n"
        } else if tsb > 10 {
            context += "\nPositive TSB — the athlete is fresh and can absorb a high training stimulus.\n"
        } else {
            context += "\nTSB is near neutral — maintain current training load.\n"
        }

        context += "\n### Readiness Assessment\n"
        context += "**\(readinessLevel) READINESS** — \(readinessGuidance)\n"

        context += "\n### User Request\n"
        context += "- Focus: \(focus)\n"
        context += "- Requested Duration: \(duration) min\n"
        context += "- Requested Intensity: \(intensity)\n"

        context += "\n### Coach Instructions\n"
        context += "You are now generating the final training plan for the user. Follow these rules:\n\n"
        context += "1. **Override intensity if needed**: If the user requested 'high' but readiness is LOW, you MUST override to rest/active recovery and explain why.\n"
        context += "2. **Reference Wiki goals**: Check the user's goals.md from the Wiki profile. Align the plan with their long-term objectives.\n"
        context += "3. **Be specific**: Include concrete exercises, sets/reps (for strength), heart rate zones (for cardio), pace targets, or mobility drills. Not vague suggestions.\n"
        context += "4. **Energy Bank aware**: If TSB is negative or energy bank is low, reduce volume/intensity regardless of what the user requested.\n"
        context += "5. **Recovery-gated rules**:\n"
        context += "   - Recovery > 75 AND energy bank > 60 AND TSB positive → push hard, recommend high-intensity (HR zone 4-5, heavy weights, sprint intervals)\n"
        context += "   - Recovery 50-75 → moderate training (HR zone 2-3, moderate weights, steady-state cardio) or active recovery\n"
        context += "   - Recovery < 50 → rest or light mobility only (yoga, walking, foam rolling, stretching)\n"
        context += "6. **Format**: Use a clear structure with warm-up, main session, and cool-down. Include approximate time allocations.\n"

        return context
    }
}

/// Logs a food/meal entry to the user's journal with nutritional information.
/// Used by the coach after analyzing a meal photo or when the user describes what they ate.
struct FoodLogTool: AgentTool {
    let name = "log_food"
    let description = "Log a food or meal entry to the user's journal. Use this after analyzing a meal photo or when the user describes what they ate. The entry will be tagged with 'food' and 'meal' for later correlation analysis."

    /// ModelContext is always accessed from @MainActor via CoachChatVM.send(),
    /// so the non-Sendable storage is safe in practice.
    nonisolated(unsafe) let modelContext: ModelContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "meal_name": .object([
                    "type": .string("string"),
                    "description": .string("Name of the meal (e.g., Breakfast, Lunch, Dinner, Snack)"),
                ]),
                "foods": .object([
                    "type": .string("array"),
                    "description": .string("List of food items eaten"),
                ]),
                "total_calories": .object([
                    "type": .string("integer"),
                    "description": .string("Total estimated calories for this meal"),
                ]),
            ]),
            "required": .array([.string("meal_name"), .string("foods"), .string("total_calories")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mealName = json["meal_name"] as? String else {
            return "Error: missing 'meal_name' argument."
        }

        let foods: [String]
        if let foodsArray = json["foods"] as? [String] {
            foods = foodsArray
        } else if let foodsString = json["foods"] as? String {
            foods = [foodsString]
        } else {
            foods = []
        }

        let totalCalories = json["total_calories"] as? Int ?? 0

        let foodList = foods.joined(separator: ", ")
        let note = "[\(mealName)] \(foodList) — ~\(totalCalories) kcal"

        let entry = JournalEntryRecord(
            createdAt: Date(),
            tags: ["food", "meal"],
            note: note,
            value: Double(totalCalories),
            unit: "kcal"
        )
        modelContext.insert(entry)
        try modelContext.save()

        return "Successfully logged \(mealName): \(foodList) (\(totalCalories) kcal) to your journal."
    }
}
