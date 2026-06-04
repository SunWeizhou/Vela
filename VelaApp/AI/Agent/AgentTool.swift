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

enum SearchSourcePolicy: String, Codable, Sendable {
    case medicalPrimary = "medical_primary"
    case sportsScience = "sports_science"
    case general = "general"
}

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
                "source_policy": .object([
                    "type": .string("string"),
                    "description": .string("Prioritizes specific domain sources. Use 'medical_primary' for clinical, diseases, supplements or guidelines; 'sports_science' for training science and recovery; 'general' for other topics."),
                    "enum": .array([.string("medical_primary"), .string("sports_science"), .string("general")])
                ])
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

        let policyRaw = json["source_policy"] as? String
        let policy: SearchSourcePolicy
        if let policyRaw, let parsed = SearchSourcePolicy(rawValue: policyRaw) {
            policy = parsed
        } else {
            policy = Self.detectPolicy(for: query)
        }

        let enrichedQuery = Self.enrichQuery(query, policy: policy)
        let results = await WebSearchHelper.shared.search(enrichedQuery, maxResults: 3)
        let citationSuffix = "\n\n[Source Policy: \(policy.rawValue.uppercased()) - Authoritative sources prioritized. Citation from primary databases only. Marketing/forum sources ignored.]"

        return results.isEmpty ? "No search results found for '\(query)'." : (results + citationSuffix)
    }

    private static func detectPolicy(for query: String) -> SearchSourcePolicy {
        let q = query.lowercased()
        let medicalTerms = ["disease", "medicine", "supplement", "vitamin", "dose", "clinical", "study", "guideline", "nih", "who", "cdc", "health", "symptom", "blood", "hormone", "cortisol", "nutrition", "diet"]
        let sportsTerms = ["vo2", "zone 2", "cardio", "training", "strength", "hypertrophy", "overreaching", "overtraining", "recovery", "acsm", "nsca", "heart rate"]

        if medicalTerms.contains(where: { q.contains($0) }) {
            return .medicalPrimary
        } else if sportsTerms.contains(where: { q.contains($0) }) {
            return .sportsScience
        } else {
            return .general
        }
    }

    private static func enrichQuery(_ query: String, policy: SearchSourcePolicy) -> String {
        switch policy {
        case .medicalPrimary:
            return query + " (site:nih.gov OR site:who.int OR site:cdc.gov OR site:ncbi.nlm.nih.gov OR site:cochranelibrary.com OR site:fda.gov)"
        case .sportsScience:
            return query + " (site:acsm.org OR site:ncbi.nlm.nih.gov OR site:sportsci.org OR site:jissn.biomedcentral.com OR site:nsca.com)"
        case .general:
            return query
        }
    }
}

/// Proposes a new memory entry for the user's wiki. Generates a MemoryProposal
/// (status=proposed) that the user can review and confirm in their Wiki Profile.
/// No longer writes directly to Markdown — proposals require user confirmation.
struct UpdateWikiTool: AgentTool {
    let name = "update_user_wiki"
    let description = "Propose a durable long-term memory entry for the user's personal Wiki profile. Use only for stable preferences, confirmed facts, constraints, goals, or repeated patterns. Never store a one-day symptom, workout, meal, sleep result, or temporary body state here; those belong in the automatic daily Wiki log. Generates a proposal that the user can review and confirm. Available files: profile.md, goals.md, constraints.md, preferences.md, habits.md, training_history.md, health_context.md, observations.md, strategies.md."

    nonisolated(unsafe) let modelContext: ModelContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "file": .object([
                    "type": .string("string"),
                    "description": .string("The wiki file to update (e.g., goals.md, habits.md, observations.md, health_context.md, training_history.md, notes.md)"),
                ]),
                "memory_type": .object([
                    "type": .string("string"),
                    "description": .string("Type of memory: fact (confirmed by user), observation (data-driven pattern), hypothesis (AI speculation needing confirmation), strategy (current active approach), preference (user's stated preference), constraint (limitation), goal_change (updated goal), baseline_update (physiological baseline change)"),
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("The new content to propose. Only include confirmed long-term changes, not single-day observations."),
                ]),
                "evidence": .object([
                    "type": .string("string"),
                    "description": .string("Evidence or reasoning behind this proposal. What data, user statement, or pattern supports this?"),
                ]),
                "confidence": .object([
                    "type": .string("number"),
                    "description": .string("Confidence level 0.0-1.0. Use 0.9+ for user-confirmed facts, 0.5-0.8 for data-driven observations, below 0.5 for hypotheses."),
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

        let evidence = json["evidence"] as? String ?? "AI-generated proposal based on conversation context."
        let confidence = json["confidence"] as? Double ?? 0.7
        let memoryTypeRaw = json["memory_type"] as? String ?? "observation"
        let memoryType = MemoryType(rawValue: memoryTypeRaw) ?? .observation

        return await MainActor.run { () -> String in
            do {
                let ledger = MemoryLedger(modelContext: modelContext)
                let record = try ledger.createProposal(
                    targetFile: file,
                    memoryType: memoryType,
                    content: content,
                    evidence: evidence,
                    confidence: confidence,
                    source: "coach_tool"
                )
                return "Memory proposal created for \(file) [\(memoryType.rawValue)]. The user can review and confirm it in their Wiki Profile. Proposal ID: \(record.id.uuidString.prefix(8))..."
            } catch {
                return "Error creating memory proposal: \(error.localizedDescription)"
            }
        }
    }
}

/// Queries today's specific health metrics from the already-loaded context.
/// This tool only works when health data has been provided in the system prompt.
/// The coach should reference the context JSON directly most of the time —
/// use this tool only when the user asks for a specific metric value.
struct HealthDataTool: AgentTool {
    let name = "check_health_data"
    let description = "Retrieve a specific health metric value from today's context when the user asks for an exact number. Use this sparingly — most data is visible in the system prompt context JSON."

    nonisolated(unsafe) let dashboard: DashboardSummary

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "metric": .object([
                    "type": .string("string"),
                    "description": .string("The metric to retrieve. One of: sleep_score, recovery_score, strain_score, stress_index, hrv_avg, rhr_avg, energy_bank, health_age, steps, active_calories, sleep_hours, sleep_efficiency, rem_percent, deep_percent, resting_hr, respiratory_rate, spo2, body_temperature, atl, ctl, tsb, acwr, training_load_ratio, workouts_today."),
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
        
        struct MetricResponse: Codable {
            var metric: String
            var value: Double?
            var unit: String
            var confidence: String
            var source: String
            var lastUpdated: String
        }
        
        var response = MetricResponse(
            metric: metric,
            value: nil,
            unit: "",
            confidence: "high",
            source: dashboard.source.rawValue,
            lastUpdated: ISO8601DateFormatter().string(from: dashboard.date)
        )
        
        switch metric.lowercased() {
        case "sleep_score":
            response.value = dashboard.sleepScore.value
            response.unit = "pts"
            response.confidence = dashboard.sleepScore.confidence.rawValue
        case "recovery_score":
            response.value = dashboard.recovery.value
            response.unit = "pts"
            response.confidence = dashboard.recovery.confidence.rawValue
        case "strain_score":
            response.value = dashboard.strain.value
            response.unit = "pts"
            response.confidence = dashboard.strain.confidence.rawValue
        case "stress_index":
            response.value = dashboard.stress.value
            response.unit = "index"
            response.confidence = dashboard.stress.confidence.rawValue
        case "hrv_avg":
            response.value = dashboard.recoveryMetrics.hrvMilliseconds
            response.unit = "ms"
            response.confidence = dashboard.recoveryMetrics.hrvMilliseconds != nil ? "high" : "unavailable"
        case "rhr_avg", "resting_hr":
            response.value = dashboard.recoveryMetrics.restingHeartRate
            response.unit = "bpm"
            response.confidence = dashboard.recoveryMetrics.restingHeartRate != nil ? "high" : "unavailable"
        case "energy_bank":
            response.value = dashboard.energy.value
            response.unit = "pts"
            response.confidence = dashboard.energy.confidence.rawValue
        case "atl", "ctl", "tsb", "acwr":
            response.value = dashboard.energy.metrics[metric.lowercased()]
            response.unit = metric.lowercased() == "acwr" ? "ratio" : "AU"
            response.confidence = response.value == nil ? "unavailable" : dashboard.energy.confidence.rawValue
        case "training_load_ratio":
            response.value = dashboard.strain.metrics["training_load_ratio"]
            response.unit = "ratio"
            response.confidence = response.value == nil ? "unavailable" : dashboard.strain.confidence.rawValue
        case "steps":
            response.value = dashboard.strain.metrics["steps_raw"]
            response.unit = "steps"
            response.confidence = response.value == nil ? "unavailable" : dashboard.strain.confidence.rawValue
        case "active_calories":
            response.value = dashboard.strain.metrics["active_energy_raw"]
            response.unit = "kcal"
            response.confidence = response.value == nil ? "unavailable" : dashboard.strain.confidence.rawValue
        case "sleep_hours":
            response.value = dashboard.sleepSummary.totalSleepMinutes > 0 ? Double(dashboard.sleepSummary.totalSleepMinutes) / 60.0 : nil
            response.unit = "hours"
            response.confidence = response.value == nil ? "unavailable" : dashboard.sleepScore.confidence.rawValue
        case "sleep_efficiency":
            response.value = dashboard.sleepScore.metrics["sleep_efficiency"]
            response.unit = "%"
            response.confidence = response.value == nil ? "unavailable" : dashboard.sleepScore.confidence.rawValue
        case "rem_percent":
            response.value = dashboard.sleepScore.metrics["rem_pct"]
            response.unit = "%"
            response.confidence = response.value == nil ? "unavailable" : dashboard.sleepScore.confidence.rawValue
        case "deep_percent":
            response.value = dashboard.sleepScore.metrics["deep_pct"]
            response.unit = "%"
            response.confidence = response.value == nil ? "unavailable" : dashboard.sleepScore.confidence.rawValue
        case "health_age":
            response.value = dashboard.healthAge.trendScore
            response.unit = "trend_score"
            response.confidence = dashboard.healthAge.confidence.rawValue
        case "respiratory_rate":
            response.value = dashboard.recoveryMetrics.respiratoryRate
            response.unit = "breaths/min"
            response.confidence = response.value == nil ? "unavailable" : dashboard.recovery.confidence.rawValue
        case "spo2":
            response.value = dashboard.extendedMetrics.oxygenSaturation
            response.unit = "%"
            response.confidence = response.value == nil ? "unavailable" : "high"
        case "body_temperature":
            response.value = dashboard.extendedMetrics.bodyTemperature
            response.unit = "C"
            response.confidence = response.value == nil ? "unavailable" : "high"
        case "workouts_today":
            response.value = Double(dashboard.workouts.count)
            response.unit = "workouts"
            response.confidence = "high"
        default:
            return "Unknown metric '\(metric)'"
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let resData = try encoder.encode(response)
        return String(data: resData, encoding: .utf8) ?? "{}"
    }
}

struct StrengthWorkoutHistoryTool: AgentTool {
    let name = "get_strength_workout_history"
    let description = "Retrieve recent locally logged strength workouts with exercises, equipment, sets, repetitions, weights, and calculated training volume. Use this when the user asks about gym progress, lifting history, exercise selection, or volume trends."

    nonisolated(unsafe) let modelContext: ModelContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of recent sessions to return. Defaults to 8 and is capped at 20."),
                ]),
            ]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        let limit: Int = {
            guard let data = arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return 8
            }
            return min(max(json["limit"] as? Int ?? 8, 1), 20)
        }()

        return await MainActor.run {
            let descriptor = FetchDescriptor<StrengthWorkoutRecord>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            let records = Array(((try? modelContext.fetch(descriptor)) ?? []).prefix(limit))
            let payload = records.map { record in
                StrengthWorkoutHistoryPayload(
                    title: record.title,
                    startedAt: record.startedAt,
                    durationMinutes: record.durationMinutes,
                    exerciseCount: record.exerciseCount,
                    totalSets: record.totalSetCount,
                    totalRepetitions: record.totalRepetitionCount,
                    totalVolumeKilograms: record.totalVolumeKilograms,
                    exercises: record.exercises
                )
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(payload) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }
}

private struct StrengthWorkoutHistoryPayload: Encodable {
    var title: String
    var startedAt: Date
    var durationMinutes: Int
    var exerciseCount: Int
    var totalSets: Int
    var totalRepetitions: Int
    var totalVolumeKilograms: Double
    var exercises: [StrengthExerciseLog]
}

/// Generates a personalized training plan based on today's recovery, strain,
/// energy bank (ATL/CTL/TSB), sleep, and stress scores. The tool returns a
/// structured readiness context that the LLM uses to craft the final plan.
struct TrainingPlanTool: AgentTool {
    let name = "generate_training_plan"
    let description = "Generate a personalized training plan recommendation based on today's physiological readiness (recovery, strain, energy bank, sleep, stress) and the user's Wiki goals. Use this when the user asks about workout plans, training recommendations, or whether they should train today."

    let decision: TrainingDecision

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

        // ── Build structured context for the LLM ──
        var context = ""
        context += "## Training Plan Context (generated by generate_training_plan tool)\n\n"

        context += "### Today's Physiological State\n"
        context += "| Metric | Score |\n"
        context += "|--------|-------|\n"
        context += "| Recovery Volume Multiplier | \(decision.volumeMultiplier) |\n"
        context += "| Sleep | \(decision.body) |\n"

        context += "\n### Training Load Status (Banister ATL/CTL/TSB)\n"
        if decision.trainingLoadConfidence == .unavailable {
            context += "\n训练负荷历史不足，不能判断 ATL/CTL/TSB。今日建议只基于 recovery / sleep / current strain / subjective flags。\n"
        } else {
            context += "| Metric | Value |\n"
            context += "|--------|-------|\n"
            context += "| ATL (Acute, 7-day) | \(decision.atl.map { "\(Int($0.rounded()))" } ?? "N/A") |\n"
            context += "| CTL (Chronic, 42-day) | \(decision.ctl.map { "\(Int($0.rounded()))" } ?? "N/A") |\n"
            context += "| TSB (Fitness — Fatigue) | \(decision.tsb.map { "\(Int($0.rounded()))" } ?? "N/A") |\n"

            if let tsbVal = decision.tsb {
                if tsbVal < -15 {
                    context += "\nTSB is deeply negative — the athlete is carrying significant accumulated fatigue. Recommend reduced load or a deload day.\n"
                } else if tsbVal < -5 {
                    context += "\nTSB is slightly negative — some fatigue accumulation. Train but avoid maximum intensity.\n"
                } else if tsbVal > 10 {
                    context += "\nPositive TSB — the athlete is fresh and can absorb a high training stimulus.\n"
                } else {
                    context += "\nTSB is near neutral — maintain current training load.\n"
                }
            }
        }

        context += "\n### Readiness Assessment\n"
        context += "**\(decision.readinessLevel) READINESS** — \(decision.readinessGuidance)\n"
        context += "Target Intensity: \(decision.maxIntensity) · Recommended Type: \(decision.recommendedTrainingType)\n"

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
        context += "   - Readiness Level HIGH → push hard, recommend high-intensity (HR zone 4-5, heavy weights, sprint intervals)\n"
        context += "   - Readiness Level MODERATE → moderate training (HR zone 2-3, moderate weights, steady-state cardio) or active recovery\n"
        context += "   - Readiness Level LOW → rest or light mobility only (yoga, walking, foam rolling, stretching)\n"
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
                "protein_grams": .object([
                    "type": .string("integer"),
                    "description": .string("Estimated protein grams, if known"),
                ]),
                "carbs_grams": .object([
                    "type": .string("integer"),
                    "description": .string("Estimated carbohydrate grams, if known"),
                ]),
                "fat_grams": .object([
                    "type": .string("integer"),
                    "description": .string("Estimated fat grams, if known"),
                ]),
                "fiber_grams": .object([
                    "type": .string("integer"),
                    "description": .string("Estimated fiber grams, if known"),
                ]),
                "health_score": .object([
                    "type": .string("string"),
                    "description": .string("Meal quality score: good, moderate, or needs_improvement"),
                ]),
                "suggestions": .object([
                    "type": .string("array"),
                    "description": .string("Short suggestions for improving this meal"),
                ]),
            ]),
            "required": .array([.string("meal_name"), .string("foods"), .string("total_calories")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        return try await MainActor.run {
            try PersistenceWriteGate.shared.assertWritable(operation: "FoodLogTool", modelContext: modelContext)

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

            let foodLog = FoodLogRecord(
                mealName: mealName,
                foods: foods.map { FoodLogItem(name: $0, portion: "unspecified", calories: 0) },
                totalCalories: totalCalories,
                proteinGrams: json["protein_grams"] as? Int ?? 0,
                carbsGrams: json["carbs_grams"] as? Int ?? 0,
                fatGrams: json["fat_grams"] as? Int ?? 0,
                fiberGrams: json["fiber_grams"] as? Int ?? 0,
                healthScore: json["health_score"] as? String ?? "moderate",
                suggestions: json["suggestions"] as? [String] ?? [],
                source: .coachTool
            )
            modelContext.insert(foodLog)

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
}

/// Generates and saves a multi-week training program for the user.
struct CreateTrainingPlanTool: AgentTool {
    let name = "create_training_plan"
    let description = "Generate and save a multi-week training program for the user. When the user asks for a workout program, training plan, or structured fitness guidance, you must generate a comprehensive multi-week plan (typically 4 weeks, with specific activities for days 1-7 of each week) and call this tool to persist it. Use this tool only once per complete plan creation."

    nonisolated(unsafe) let modelContext: ModelContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("A motivating and descriptive title for the training plan (e.g. 4-Week VO2 Max Builder)"),
                ]),
                "goal_description": .object([
                    "type": .string("string"),
                    "description": .string("A comprehensive summary of the plan goals and physical target focus."),
                ]),
                "weeks_count": .object([
                    "type": .string("integer"),
                    "description": .string("The number of weeks in this plan (typically 4)"),
                ]),
                "days": .object([
                    "type": .string("array"),
                    "description": .string("The day-by-day training sessions. MUST cover all days in all weeks (e.g., 28 entries for 4 weeks)."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "week_number": .object(["type": .string("integer"), "description": .string("Week number, 1-indexed (e.g. 1, 2, 3, 4)")]),
                            "day_number": .object(["type": .string("integer"), "description": .string("Day of the week (1 = Monday, 2 = Tuesday, ..., 7 = Sunday)")]),
                            "title": .object(["type": .string("string"), "description": .string("Title of the session (e.g. Interval Sprints, Active Mobility, Rest Day)")]),
                            "description": .object(["type": .string("string"), "description": .string("Detailed instructions for the workout session (e.g., warm-up, main sets, reps, cool-down).")]),
                            "focus": .object(["type": .string("string"), "description": .string("The session category: cardio, strength, flexibility, or rest")]),
                            "duration_minutes": .object(["type": .string("integer"), "description": .string("Target duration in minutes (0 for rest days)")]),
                            "intensity": .object(["type": .string("string"), "description": .string("Intensity level: low, moderate, or high")])
                        ]),
                        "required": .array([
                            .string("week_number"),
                            .string("day_number"),
                            .string("title"),
                            .string("description"),
                            .string("focus"),
                            .string("duration_minutes"),
                            .string("intensity")
                        ])
                    ])
                ])
            ]),
            "required": .array([.string("title"), .string("goal_description"), .string("weeks_count"), .string("days")])
        ]
    }

    func execute(arguments: String) async throws -> String {
        return try await MainActor.run {
            try PersistenceWriteGate.shared.assertWritable(operation: "CreateTrainingPlanTool", modelContext: modelContext)

            guard let data = arguments.data(using: .utf8) else {
                return "Error: invalid UTF-8 string."
            }

        struct PlanInput: Codable {
            let title: String
            let goal_description: String
            let weeks_count: Int
            let days: [DayInput]
        }

        struct DayInput: Codable {
            let week_number: Int
            let day_number: Int
            let title: String
            let description: String
            let focus: String
            let duration_minutes: Int
            let intensity: String
        }

        let decoder = JSONDecoder()
        let input: PlanInput
        do {
            input = try decoder.decode(PlanInput.self, from: data)
        } catch {
            return "JSON decode error: \(error.localizedDescription)"
        }

        // Deactivate all existing plans first
        let activeFetch = FetchDescriptor<TrainingPlanRecord>(
            predicate: #Predicate { $0.isActive }
        )
        if let existingActivePlans = try? modelContext.fetch(activeFetch) {
            for p in existingActivePlans {
                p.isActive = false
            }
        }

        // Create new training days
        let trainingDays: [TrainingDay] = input.days.map { d in
            TrainingDay(
                weekNumber: d.week_number,
                dayNumber: d.day_number,
                title: d.title,
                description: d.description,
                focus: d.focus,
                durationMinutes: d.duration_minutes,
                intensity: d.intensity
            )
        }

        let plan = TrainingPlanRecord(
            title: input.title,
            goalDescription: input.goal_description,
            startDate: Date(),
            weeksCount: input.weeks_count,
            isActive: true,
            days: trainingDays
        )

        modelContext.insert(plan)
        try modelContext.save()

        return "Successfully created and activated your training plan: \(input.title) (\(input.weeks_count) weeks, \(trainingDays.count) sessions)!"
        }
    }
}

/// Generates and renders a correlation chart between two daily variables.
struct RenderCorrelationChartTool: AgentTool {
    let name = "render_correlation_chart"
    let description = "Generate and render an interactive correlation chart in the user's chat panel to analyze the relationship between two variables over 7, 14, or 30 days. Example variables: hrv, sleep_score, resting_hr, stress_index, steps, caffeine, alcohol, meditation, late_meal. Calling this tool will prepare the visual chart for rendering."

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "metric_x": .object([
                    "type": .string("string"),
                    "description": .string("The first variable (e.g. hrv, sleep_score, resting_hr, stress_index, steps, vitamin_d, cortisol)"),
                ]),
                "metric_y": .object([
                    "type": .string("string"),
                    "description": .string("The second variable to correlate (e.g. caffeine, alcohol, meditation, late_meal, steps, sleep_hours)"),
                ]),
            ]),
            "required": .array([.string("metric_x"), .string("metric_y")]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let metricX = json["metric_x"] as? String,
              let metricY = json["metric_y"] as? String else {
            return "Error: missing or invalid 'metric_x' or 'metric_y' arguments."
        }
        
        let key = "\(metricX.lowercased())_vs_\(metricY.lowercased())"
        return "Successfully prepared the correlation chart for '\(metricX)' vs '\(metricY)'. You MUST now include the tag `[ARTIFACT:correlation:\(key)]` in your final text response exactly where you want the visual chart to be rendered."
    }
}
