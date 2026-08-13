import Foundation
import SwiftData

// MARK: - Tool Definition

protocol AgentTool: Sendable {
    var name: String { get }
    var description: String { get }
    var parameters: [String: Value] { get }
    var riskLevel: ToolRiskLevel { get }
    func execute(arguments: String) async throws -> String
}

extension AgentTool {
    var riskLevel: ToolRiskLevel {
        .read
    }

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

    var allowedToolNames: [String] {
        tools.map(\.name)
    }

    func contains(name: String) -> Bool {
        tools.contains(where: { $0.name == name })
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

    func risk(for name: String) -> ToolRiskLevel {
        tools.first(where: { $0.name == name })?.riskLevel ?? .destructive
    }
}

@MainActor
final class ToolExecutionContext: @unchecked Sendable {
    let modelContext: ModelContext
    let dashboard: DashboardSummary

    init(modelContext: ModelContext, dashboard: DashboardSummary) {
        self.modelContext = modelContext
        self.dashboard = dashboard
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
        let citationSuffix = "\n\n[Source Policy: \(policy.rawValue.uppercased()) - Search query biased toward authoritative sources when possible. Verify linked sources before applying medical, supplement, or training advice.]"

        guard !results.isEmpty else {
            return "No search results found for '\(query)'."
        }
        return WebSearchHelper.untrustedContext(results) + citationSuffix
    }

    static func detectPolicy(for query: String) -> SearchSourcePolicy {
        let q = query.lowercased()
        let medicalTerms = [
            "disease", "medicine", "supplement", "vitamin", "dose", "clinical", "study", "guideline",
            "nih", "who", "cdc", "health", "symptom", "blood", "hormone", "cortisol", "nutrition", "diet",
            "疾病", "药", "药物", "补剂", "营养补充", "维生素", "剂量", "临床", "指南", "症状",
            "血液", "激素", "皮质醇", "营养", "饮食", "肌酸", "咖啡因", "蛋白粉"
        ]
        let sportsTerms = [
            "vo2", "zone 2", "cardio", "training", "strength", "hypertrophy", "overreaching",
            "overtraining", "recovery", "acsm", "nsca", "heart rate",
            "有氧", "力量", "训练", "增肌", "肌肥大", "运动科学", "恢复", "过度训练", "心率", "最大摄氧量"
        ]

        if medicalTerms.contains(where: { q.contains($0) }) {
            return .medicalPrimary
        } else if sportsTerms.contains(where: { q.contains($0) }) {
            return .sportsScience
        } else {
            return .general
        }
    }

    static func enrichQuery(_ query: String, policy: SearchSourcePolicy) -> String {
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
    let riskLevel: ToolRiskLevel = .propose

    let executionContext: ToolExecutionContext

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
                let ledger = MemoryLedger(modelContext: executionContext.modelContext)
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

/// Unified today's health tool — single source of truth for all current body metrics.
/// Reads raw metrics from SwiftData (ground truth) and computed fields (bands, reasons,
/// confidence, training decisions) from the live DashboardSummary. Always returns a
/// freshness timestamp so the LLM knows how current the data is.
struct TodayHealthTool: AgentTool {
    let name = "get_today_health"
    let description = "Retrieve today's complete health snapshot — all scores, autonomic metrics (HRV, RHR), sleep details, strain/load, stress, energy bank (ATL/CTL/TSB), workouts, body metrics, and training readiness. Always use this FIRST when the user asks about their current body state, training readiness, recovery, or any specific health metric. Returns data with freshness timestamps. Use 'sections' to request only the parts you need."

    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "sections": .object([
                    "type": .string("array"),
                    "description": .string("Optional: specific sections to return. Omit for all. Available: scores, autonomic, sleep, strain, stress, energy, workouts, body, training_readiness"),
                    "items": .object(["type": .string("string")]),
                ]),
            ]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        let requestedSections: Set<String>? = {
            guard let data = arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sections = json["sections"] as? [String] else { return nil }
            return Set(sections)
        }()

        return await MainActor.run {
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= today && $0.date < tomorrow },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let todayRecord = (try? executionContext.modelContext.fetch(descriptor))?.first
            let dashboard = executionContext.dashboard

            let now = Date()
            let ageSeconds = now.timeIntervalSince(dashboard.date)
            let freshness: String = ageSeconds < 300 ? "live (<5min)"
                : ageSeconds < 1800 ? "recent (<30min)"
                : ageSeconds < 7200 ? "moderate (<2h)"
                : "stale (>2h — a background sync may have fresher raw data in the database; call get_health_history for the latest persisted values)"

            var result: [String: Any] = [
                "generated_at": ISO8601DateFormatter().string(from: now),
                "data_date": ISO8601DateFormatter().string(from: dashboard.date),
                "source": dashboard.source.rawValue,
                "freshness": freshness,
                "data_version": ContentHash.hash("\(todayRecord?.dayIdentifier ?? "")-\(dashboard.date.timeIntervalSince1970)"),
                "_note": "Raw metrics: SwiftData (latest persisted). Scores/bands/reasons: live computation from DashboardSummary. For historical trends use get_health_history."
            ]

            func include(_ section: String) -> Bool {
                requestedSections?.contains(section) ?? true
            }

            // ── Scores ──
            if include("scores") {
                func roundedValue(_ value: Double?) -> Any {
                    value.map { Int($0.rounded()) } ?? NSNull()
                }

                result["scores"] = [
                    "recovery": ["value": roundedValue(dashboard.recovery.hasData ? dashboard.recovery.value : nil), "band": dashboard.recovery.hasData ? dashboard.recovery.band.rawValue : "unavailable", "confidence": dashboard.recovery.confidence.rawValue],
                    "sleep": ["value": roundedValue(dashboard.sleepScore.hasData ? dashboard.sleepScore.value : nil), "band": dashboard.sleepScore.hasData ? dashboard.sleepScore.band.rawValue : "unavailable", "confidence": dashboard.sleepScore.confidence.rawValue],
                    "strain": ["value": roundedValue(dashboard.strain.hasData ? dashboard.strain.value : nil), "band": dashboard.strain.hasData ? dashboard.strain.band.rawValue : "unavailable", "target_status": dashboard.strain.hasData ? dashboard.strain.targetStatus.rawValue : "unavailable", "confidence": dashboard.strain.confidence.rawValue],
                    "stress": ["value": roundedValue(dashboard.stress.hasData ? dashboard.stress.value : nil), "band": dashboard.stress.hasData ? dashboard.stress.band.rawValue : "unavailable", "confidence": dashboard.stress.confidence.rawValue],
                    "energy": ["current": roundedValue(dashboard.energy.hasData ? dashboard.energy.value : nil), "morning": roundedValue(dashboard.energy.hasData ? dashboard.energy.morningEnergy : nil), "bank": roundedValue(dashboard.energy.hasData ? dashboard.energy.value : nil), "status": dashboard.energy.hasData ? dashboard.energy.status.rawValue : "unavailable", "confidence": dashboard.energy.confidence.rawValue]
                ]
            }

            // ── Autonomic (HRV / RHR) ──
            if include("autonomic") {
                let hrvMs = todayRecord?.hrvAverage ?? dashboard.recoveryMetrics.hrvMilliseconds
                let rhrBpm = todayRecord?.restingHeartRate ?? dashboard.recoveryMetrics.restingHeartRate
                let rr = todayRecord?.respiratoryRate ?? dashboard.recoveryMetrics.respiratoryRate
                var auto: [String: Any] = [
                    "hrv_avg_ms": hrvMs as Any,
                    "resting_hr_bpm": rhrBpm as Any,
                    "respiratory_rate_brpm": rr as Any,
                ]
                if let z = dashboard.recovery.metrics["hrv_z_score"] { auto["hrv_z_score"] = (z * 100).rounded() / 100 }
                if let z = dashboard.recovery.metrics["rhr_z_score"] { auto["rhr_z_score"] = (z * 100).rounded() / 100 }
                // prefix(3) 返回 ArraySlice（Swift 结构体），必须转 Array——
                // 否则 JSONSerialization 抛不可捕获的 NSException (__SwiftValue)
                if !dashboard.recovery.reasons.isEmpty { auto["recovery_key_factors"] = Array(dashboard.recovery.reasons.prefix(3)) }
                result["autonomic"] = auto
            }

            // ── Sleep detail ──
            if include("sleep") {
                let totalMin = todayRecord?.sleepHours.map { $0 * 60 } ?? Double(dashboard.sleepSummary.totalSleepMinutes)
                var slp: [String: Any] = [
                    "total_hours": (totalMin / 60.0 * 10).rounded() / 10,
                    "efficiency_pct": todayRecord?.sleepEfficiency ?? dashboard.sleepScore.metrics["sleep_efficiency"] as Any,
                    "deep_pct": todayRecord?.deepSleepPercent ?? dashboard.sleepScore.metrics["deep_pct"] as Any,
                    "rem_pct": todayRecord?.remSleepPercent ?? dashboard.sleepScore.metrics["rem_pct"] as Any,
                ]
                if let bt = todayRecord?.bedtime ?? dashboard.sleepSummary.bedtime {
                    let f = DateFormatter(); f.dateFormat = "HH:mm"; slp["bedtime"] = f.string(from: bt)
                }
                if let wt = todayRecord?.wakeTime ?? dashboard.sleepSummary.wakeTime {
                    let f = DateFormatter(); f.dateFormat = "HH:mm"; slp["wake_time"] = f.string(from: wt)
                }
                // 同上：ArraySlice 必须转 Array 才能进 JSONSerialization
                if !dashboard.sleepScore.reasons.isEmpty { slp["key_factors"] = Array(dashboard.sleepScore.reasons.prefix(3)) }
                result["sleep"] = slp
            }

            // ── Strain / Load ──
            if include("strain") {
                result["strain_detail"] = [
                    "daily_load": todayRecord?.dailyLoad ?? dashboard.strain.metrics["daily_load"] as Any,
                    "workout_load": todayRecord?.workoutLoad ?? dashboard.strain.metrics["workout_load"] as Any,
                    "training_load_ratio": todayRecord?.trainingLoadRatio ?? dashboard.strain.metrics["training_load_ratio"] as Any,
                    "steps": todayRecord?.steps ?? dashboard.strain.metrics["steps_raw"] as Any,
                    "active_calories_kcal": todayRecord?.activeCalories ?? dashboard.strain.metrics["active_energy_raw"] as Any,
                    "exercise_minutes": todayRecord?.activeMinutes ?? dashboard.strain.metrics["exercise_minutes_raw"] as Any,
                    "recommended_range": [dashboard.strain.recommendedRange.lowerBound, dashboard.strain.recommendedRange.upperBound],
                ]
            }

            // ── Energy Bank (ATL/CTL/TSB) ──
            if include("energy") {
                result["energy_detail"] = [
                    "atl_7day": todayRecord?.atl ?? dashboard.energy.metrics["atl"] as Any,
                    "ctl_42day": todayRecord?.ctl ?? dashboard.energy.metrics["ctl"] as Any,
                    "tsb": todayRecord?.tsb ?? dashboard.energy.metrics["tsb"] as Any,
                    "acwr": todayRecord?.acwr ?? dashboard.energy.metrics["acwr"] as Any,
                ]
            }

            // ── Workouts ──
            if include("workouts") {
                let wos = dashboard.workouts
                result["workouts"] = [
                    "count": wos.count,
                    "types": Array(Set(wos.map(\.activityName))),
                    "total_duration_min": wos.map { Int($0.end.timeIntervalSince($0.start) / 60) }.reduce(0, +),
                    "total_energy_kcal": Int(wos.compactMap(\.energyKilocalories).reduce(0, +)),
                    "items": wos.map { w in
                        ["name": w.activityName, "duration_min": Int(w.end.timeIntervalSince(w.start) / 60), "energy_kcal": w.energyKilocalories as Any, "avg_hr_bpm": w.averageHeartRate as Any]
                    }
                ]
            }

            // ── Body Metrics ──
            if include("body") {
                let ext = dashboard.extendedMetrics
                let body = dashboard.bodyMetrics
                result["body"] = [
                    "weight_kg": body.weightKilograms as Any,
                    "body_fat_pct": body.bodyFatPercentage as Any,
                    "bmi": ext.bmi as Any,
                    "vo2max": body.vo2Max as Any,
                    "spo2_pct": todayRecord?.oxygenSaturation ?? ext.oxygenSaturation as Any,
                    "wrist_temp_c": todayRecord?.wristTemperature ?? ext.bodyTemperature as Any,
                ]
            }

            // ── Training Readiness ──
            if include("training_readiness") {
                let td = dashboard.trainingDecision
                result["training_readiness"] = [
                    "level": td.readinessLevel,
                    "guidance": td.readinessGuidance,
                    "recommended_type": td.recommendedTrainingType,
                    "max_intensity": td.maxIntensity,
                    "volume_multiplier": td.volumeMultiplier,
                    "main_limiter": td.limiter.map { "\($0.title): \($0.detail)" } ?? "none",
                ]
            }

            // isValidJSONObject 防御：阻止任何 Swift 值（如 ArraySlice/结构体）
            // 混入 payload 时触发不可捕获的 NSException
            guard JSONSerialization.isValidJSONObject(result),
                  let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
                  let json = String(data: data, encoding: .utf8) else {
                return "Error: failed to encode health data."
            }
            return json
        }
    }
}

struct StrengthWorkoutHistoryTool: AgentTool {
    let name = "get_strength_workout_history"
    let description = "Retrieve recent locally logged strength workouts with exercises, equipment, sets, repetitions, weights, and calculated training volume. Use this when the user asks about gym progress, lifting history, exercise selection, or volume trends."

    let executionContext: ToolExecutionContext

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
            let records = Array(((try? executionContext.modelContext.fetch(descriptor)) ?? []).prefix(limit))
            let payload = records.map { record in
                StrengthWorkoutHistoryPayload(workout: record)
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(payload) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }
}

struct HealthTrendTool: AgentTool {
    let name = "get_health_trends"
    let description = "Return 7, 14, or 30-day trends for HRV, resting heart rate, sleep, recovery, strain, stress, and energy from local daily summaries."
    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "enum": .array([.number(7), .number(14), .number(30)])
                ]),
                "metrics": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")])
                ])
            ])
        ]
    }

    func execute(arguments: String) async throws -> String {
        let request = Self.request(from: arguments)
        return await MainActor.run {
            let start = Calendar.current.startOfDay(
                for: Date().addingTimeInterval(-Double(request.days - 1) * 86_400)
            )
            let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= start },
                sortBy: [SortDescriptor(\.date)]
            )
            let records = (try? executionContext.modelContext.fetch(descriptor)) ?? []
            let points = records.map { record -> [String: Any] in
                var item: [String: Any] = [
                    "date": ISO8601DateFormatter().string(from: record.date),
                    "source": "DailyHealthSummaryRecord"
                ]
                for metric in request.metrics {
                    switch metric {
                    case "hrv": item[metric] = record.hrvAverage
                    case "rhr": item[metric] = record.restingHeartRate
                    case "sleep": item[metric] = record.sleepHours
                    case "recovery": item[metric] = record.recoveryScore
                    case "strain": item[metric] = record.strainScore
                    case "stress": item[metric] = record.stressIndex
                    case "energy": item[metric] = record.currentEnergy
                    default: break
                    }
                }
                return item
            }
            let payload: [String: Any] = [
                "days": request.days,
                "metrics": request.metrics,
                "source": "DailyHealthSummaryRecord",
                "confidence": records.isEmpty ? "unavailable" : "measured_and_derived",
                "safety": "General wellness guidance only; not a medical diagnosis.",
                "points": points
            ]
            guard JSONSerialization.isValidJSONObject(payload),
                  let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
                return "{}"
            }
            return String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    private static func request(from arguments: String) -> (days: Int, metrics: [String]) {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (14, ["hrv", "rhr", "sleep", "recovery", "strain", "stress", "energy"])
        }
        let requestedDays = json["days"] as? Int ?? 14
        let days = [7, 14, 30].contains(requestedDays) ? requestedDays : 14
        let supported = Set(["hrv", "rhr", "sleep", "recovery", "strain", "stress", "energy"])
        let metrics = (json["metrics"] as? [String] ?? Array(supported)).filter { supported.contains($0) }
        return (days, metrics)
    }
}

struct TrainingResponseHistoryTool: AgentTool {
    let name = "get_training_response_history"
    let description = "Return recent workout-to-next-day recovery, HRV, and resting-heart-rate deltas with muscle groups, set counts, and notable-response flags."
    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "days": .object(["type": .string("integer")]),
                "muscle_group": .object(["type": .string("string")])
            ])
        ]
    }

    func execute(arguments: String) async throws -> String {
        let request = Self.request(from: arguments)
        return await MainActor.run {
            let start = Date().addingTimeInterval(-Double(request.days) * 86_400)
            let descriptor = FetchDescriptor<TrainingResponseRecord>(
                predicate: #Predicate<TrainingResponseRecord> { $0.date >= start },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let records = ((try? executionContext.modelContext.fetch(descriptor)) ?? []).filter {
                guard let muscle = request.muscleGroup else { return true }
                return $0.primaryMuscleGroups.contains { $0.localizedCaseInsensitiveContains(muscle) }
            }
            let payload = TrainingResponseHistoryResult(
                source: "TrainingResponseRecord",
                confidence: records.isEmpty ? "unavailable" : "measured_and_derived",
                safety: "General wellness guidance only; not a medical diagnosis.",
                records: records.map(TrainingResponseHistoryPayload.init(record:))
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(payload) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    private static func request(from arguments: String) -> (days: Int, muscleGroup: String?) {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (28, nil)
        }
        return (min(max(json["days"] as? Int ?? 28, 1), 60), json["muscle_group"] as? String)
    }
}

private struct TrainingResponseHistoryResult: Encodable {
    var source: String
    var confidence: String
    var safety: String
    var records: [TrainingResponseHistoryPayload]
}

private struct TrainingResponseHistoryPayload: Encodable {
    var workoutId: UUID
    var date: Date
    var nextDayDate: Date
    var primaryMuscleGroups: [String]
    var totalEffectiveSets: Int
    var totalVolumeKg: Double
    var sessionRPE: Double?
    var nextDayRecoveryDelta: Double?
    var nextDayHRVDelta: Double?
    var nextDayRHRDelta: Double?
    var flagged: Bool

    init(record: TrainingResponseRecord) {
        workoutId = record.workoutId
        date = record.date
        nextDayDate = record.nextDayDate
        primaryMuscleGroups = record.primaryMuscleGroups
        totalEffectiveSets = record.totalEffectiveSets
        totalVolumeKg = record.totalVolumeKg
        sessionRPE = record.sessionRPE
        nextDayRecoveryDelta = record.nextDayRecoveryDelta
        nextDayHRVDelta = record.nextDayHRVDelta
        nextDayRHRDelta = record.nextDayRHRDelta
        flagged = (record.nextDayRecoveryDelta ?? 0) <= -8
            || (record.nextDayHRVDelta ?? 0) <= -10
            || (record.nextDayRHRDelta ?? 0) >= 5
    }

    enum CodingKeys: String, CodingKey {
        case workoutId = "workout_id"
        case date
        case nextDayDate = "next_day_date"
        case primaryMuscleGroups = "primary_muscle_groups"
        case totalEffectiveSets = "total_effective_sets"
        case totalVolumeKg = "total_volume_kg"
        case sessionRPE = "session_rpe"
        case nextDayRecoveryDelta = "next_day_recovery_delta"
        case nextDayHRVDelta = "next_day_hrv_delta"
        case nextDayRHRDelta = "next_day_rhr_delta"
        case flagged
    }
}

private struct StrengthWorkoutHistoryPayload: Encodable {
    var title: String
    var startedAt: Date
    var durationMinutes: Int
    var exerciseCount: Int
    var completedWorkSets: Int
    var completedRepetitions: Int
    var completedVolumeKilograms: Double
    var warmupSets: Int
    var uncompletedSets: Int
    var exercises: [StrengthExerciseHistoryPayload]

    init(workout: StrengthWorkoutRecord) {
        title = workout.title
        startedAt = workout.startedAt
        durationMinutes = workout.durationMinutes
        exerciseCount = workout.exerciseCount
        exercises = workout.exercises.map(StrengthExerciseHistoryPayload.init(exercise:))
        completedWorkSets = exercises.reduce(0) { $0 + $1.completedSets.count }
        completedRepetitions = exercises.reduce(0) { total, exercise in
            total + exercise.completedSets.reduce(0) { $0 + $1.repetitions }
        }
        completedVolumeKilograms = exercises.reduce(0) { total, exercise in
            total + exercise.completedSets.reduce(0) { $0 + $1.volumeKilograms }
        }
        warmupSets = exercises.reduce(0) { $0 + $1.warmupSets.count }
        uncompletedSets = exercises.reduce(0) { $0 + $1.uncompletedSets.count }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case startedAt = "started_at"
        case durationMinutes = "duration_minutes"
        case exerciseCount = "exercise_count"
        case completedWorkSets = "completed_work_sets"
        case completedRepetitions = "completed_repetitions"
        case completedVolumeKilograms = "completed_volume_kilograms"
        case warmupSets = "warmup_sets"
        case uncompletedSets = "uncompleted_sets"
        case exercises
    }
}

private struct StrengthExerciseHistoryPayload: Encodable {
    var name: String
    var equipment: String
    var primaryMuscleGroup: String?
    var completedSets: [StrengthSetHistoryPayload]
    var warmupSets: [StrengthSetHistoryPayload]
    var uncompletedSets: [StrengthSetHistoryPayload]

    init(exercise: StrengthExerciseLog) {
        name = exercise.name
        equipment = exercise.equipment
        primaryMuscleGroup = exercise.primaryMuscleGroup
        completedSets = exercise.sets
            .filter { !$0.isWarmup && $0.isCompleted != false }
            .map(StrengthSetHistoryPayload.init(set:))
        warmupSets = exercise.sets
            .filter { $0.isWarmup && $0.isCompleted != false }
            .map(StrengthSetHistoryPayload.init(set:))
        uncompletedSets = exercise.sets
            .filter { $0.isCompleted == false }
            .map(StrengthSetHistoryPayload.init(set:))
    }

    enum CodingKeys: String, CodingKey {
        case name
        case equipment
        case primaryMuscleGroup = "primary_muscle_group"
        case completedSets = "completed_sets"
        case warmupSets = "warmup_sets"
        case uncompletedSets = "uncompleted_sets"
    }
}

private struct StrengthSetHistoryPayload: Encodable {
    var repetitions: Int
    var weightKilograms: Double
    var volumeKilograms: Double
    var rpe: Double?
    var rir: Double?
    var status: String

    init(set: StrengthSetLog) {
        repetitions = set.repetitions
        weightKilograms = set.weightKilograms
        volumeKilograms = set.isWarmup ? 0 : Double(set.repetitions) * set.weightKilograms
        rpe = set.rpe
        rir = set.rir
        if set.isCompleted == false {
            status = "uncompleted"
        } else if set.isWarmup {
            status = "warmup"
        } else {
            status = "completed"
        }
    }

    enum CodingKeys: String, CodingKey {
        case repetitions
        case weightKilograms = "weight_kilograms"
        case volumeKilograms = "volume_kilograms"
        case rpe
        case rir
        case status
    }
}

struct UnifiedWorkoutHistoryTool: AgentTool {
    let name = "get_unified_workout_history"
    let description = "Retrieve the user's unified workout timeline across Apple Watch/HealthKit, Xunji-enriched strength sessions, manual entries, running, swimming, walking, and other activities. Use this as the primary workout history tool when the user asks about training history, activity patterns, cardio, swimming, running, or merged Apple/Xunji workout records."

    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Lookback window in days. Defaults to 28 and is capped at 180."),
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum sessions to return. Defaults to 20 and is capped at 60."),
                ]),
                "activity_type": .object([
                    "type": .string("string"),
                    "description": .string("Optional case-insensitive filter such as strength, running, swimming, walking, cycling, or a Chinese activity/title fragment."),
                ]),
                "include_strength_details": .object([
                    "type": .string("boolean"),
                    "description": .string("When true, includes linked strength exercises/sets for Apple+Xunji or Xunji strength sessions. Defaults to true."),
                ]),
            ]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        let parsed = Self.parse(arguments: arguments)
        return await MainActor.run {
            let cutoff = Date().addingTimeInterval(-Double(parsed.days) * 24 * 3600)
            let descriptor = FetchDescriptor<WorkoutEventRecord>(
                predicate: #Predicate<WorkoutEventRecord> { $0.startedAt >= cutoff },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            var events = (try? executionContext.modelContext.fetch(descriptor)) ?? []
            if let activityType = parsed.activityType?.trimmingCharacters(in: .whitespacesAndNewlines),
               !activityType.isEmpty {
                let needle = activityType.lowercased()
                events = events.filter {
                    $0.activityType.lowercased().contains(needle)
                    || $0.title.lowercased().contains(needle)
                    || $0.source.lowercased().contains(needle)
                }
            }

            let limited = Array(events.prefix(parsed.limit))
            let strengthIDs = Set(limited.compactMap(\.linkedStrengthWorkoutId))
            let strengthRecords = fetchStrengthRecords(ids: strengthIDs)
            let strengthMap = Dictionary(uniqueKeysWithValues: strengthRecords.map { ($0.id, $0) })

            let payload = limited.map { event in
                UnifiedWorkoutHistoryPayload(
                    event: event,
                    strengthWorkout: parsed.includeStrengthDetails
                        ? event.linkedStrengthWorkoutId.flatMap { strengthMap[$0] }
                        : nil
                )
            }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(payload) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    @MainActor
    private func fetchStrengthRecords(ids: Set<UUID>) -> [StrengthWorkoutRecord] {
        guard !ids.isEmpty else { return [] }
        let descriptor = FetchDescriptor<StrengthWorkoutRecord>()
        return ((try? executionContext.modelContext.fetch(descriptor)) ?? []).filter { ids.contains($0.id) }
    }

    private static func parse(arguments: String) -> (days: Int, limit: Int, activityType: String?, includeStrengthDetails: Bool) {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (28, 20, nil, true)
        }
        let days = min(max(json["days"] as? Int ?? 28, 1), 180)
        let limit = min(max(json["limit"] as? Int ?? 20, 1), 60)
        let activityType = json["activity_type"] as? String
        let includeStrengthDetails = json["include_strength_details"] as? Bool ?? true
        return (days, limit, activityType, includeStrengthDetails)
    }
}

private struct UnifiedWorkoutHistoryPayload: Encodable {
    var id: UUID
    var source: String
    var title: String
    var activityType: String
    var startedAt: Date
    var endedAt: Date
    var durationMinutes: Double
    var energyKilocalories: Double?
    var averageHeartRate: Double?
    var rpe: Double?
    var linkedStrengthWorkoutId: UUID?
    var linkedHealthKitWorkoutId: UUID?
    var strengthDetails: StrengthWorkoutHistoryPayload?

    init(event: WorkoutEventRecord, strengthWorkout: StrengthWorkoutRecord?) {
        id = event.id
        source = event.source
        title = event.title
        activityType = event.activityType
        startedAt = event.startedAt
        endedAt = event.endedAt
        durationMinutes = event.durationMinutes
        energyKilocalories = event.energyKilocalories
        averageHeartRate = event.averageHeartRate
        rpe = event.rpe
        linkedStrengthWorkoutId = event.linkedStrengthWorkoutId
        linkedHealthKitWorkoutId = event.linkedHealthKitWorkoutId
        if let strengthWorkout {
            strengthDetails = StrengthWorkoutHistoryPayload(workout: strengthWorkout)
        } else {
            strengthDetails = nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case title
        case activityType = "activity_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case energyKilocalories = "energy_kilocalories"
        case averageHeartRate = "average_heart_rate"
        case rpe
        case linkedStrengthWorkoutId = "linked_strength_workout_id"
        case linkedHealthKitWorkoutId = "linked_healthkit_workout_id"
        case strengthDetails = "strength_details"
    }
}

struct HealthHistoryTool: AgentTool {
    let name = "get_health_history"
    let description = "Retrieve daily historical body and health metrics from local HealthKit-derived summaries, including sleep, recovery, strain, HRV, resting heart rate, stress, energy bank, steps, calories, body metrics, oxygen saturation, respiratory rate, wrist temperature, and training-load fields. Use this when the user asks about trends, correlations, baselines, or past body state."

    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "days": .object([
                    "type": .string("integer"),
                    "description": .string("Lookback window in days. Defaults to 30 and is capped at 180."),
                ]),
                "include_workouts": .object([
                    "type": .string("boolean"),
                    "description": .string("Whether to include each day's compact workout summaries. Defaults to false."),
                ]),
            ]),
        ]
    }

    func execute(arguments: String) async throws -> String {
        let parsed = Self.parse(arguments: arguments)
        return await MainActor.run {
            let cutoff = Calendar.current.startOfDay(for: Date().addingTimeInterval(-Double(parsed.days) * 24 * 3600))
            let descriptor = FetchDescriptor<DailyHealthSummaryRecord>(
                predicate: #Predicate<DailyHealthSummaryRecord> { $0.date >= cutoff },
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            let records = (try? executionContext.modelContext.fetch(descriptor)) ?? []
            let payload = records.map { HealthHistoryDayPayload(record: $0, includeWorkouts: parsed.includeWorkouts) }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(payload) else { return "[]" }
            return String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    private static func parse(arguments: String) -> (days: Int, includeWorkouts: Bool) {
        guard let data = arguments.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (30, false)
        }
        let days = min(max(json["days"] as? Int ?? 30, 1), 180)
        let includeWorkouts = json["include_workouts"] as? Bool ?? false
        return (days, includeWorkouts)
    }
}

private struct HealthHistoryDayPayload: Encodable {
    var date: Date
    var sleepScore: Double?
    var recoveryScore: Double?
    var strainScore: Double?
    var stressIndex: Double?
    var morningEnergy: Double?
    var currentEnergy: Double?
    var energyBank: Double?
    var healthAge: Double?
    var hrvAverage: Double?
    var restingHeartRate: Double?
    var sleepHours: Double?
    var deepSleepPercent: Double?
    var remSleepPercent: Double?
    var sleepEfficiency: Double?
    var steps: Double?
    var activeCalories: Double?
    var activeMinutes: Double?
    var workoutCount: Int?
    var workoutTypes: String?
    var workoutDuration: Double?
    var bodyWeight: Double?
    var bodyFatPercent: Double?
    var bmi: Double?
    var oxygenSaturation: Double?
    var respiratoryRate: Double?
    var wristTemperature: Double?
    var dailyLoad: Double?
    var workoutLoad: Double?
    var activityLoad: Double?
    var trainingLoadRatio: Double?
    var atl: Double?
    var ctl: Double?
    var tsb: Double?
    var acwr: Double?
    var bedtime: Date?
    var wakeTime: Date?
    var awakeMinutes: Double?
    var awakeEpisodeCount: Int?
    var deepSleepMinutes: Double?
    var remSleepMinutes: Double?
    var workouts: [WorkoutSummary]?

    init(record: DailyHealthSummaryRecord, includeWorkouts: Bool) {
        date = record.date
        sleepScore = record.sleepScore
        recoveryScore = record.recoveryScore
        strainScore = record.strainScore
        stressIndex = record.stressIndex
        morningEnergy = record.morningEnergy
        currentEnergy = record.currentEnergy
        energyBank = record.energyBank
        healthAge = record.healthAge
        hrvAverage = record.hrvAverage
        restingHeartRate = record.restingHeartRate
        sleepHours = record.sleepHours
        deepSleepPercent = record.deepSleepPercent
        remSleepPercent = record.remSleepPercent
        sleepEfficiency = record.sleepEfficiency
        steps = record.steps
        activeCalories = record.activeCalories
        activeMinutes = record.activeMinutes
        workoutCount = record.workoutCount
        workoutTypes = record.workoutTypes
        workoutDuration = record.workoutDuration
        bodyWeight = record.bodyWeight
        bodyFatPercent = record.bodyFatPercent
        bmi = record.bmi
        oxygenSaturation = record.oxygenSaturation
        respiratoryRate = record.respiratoryRate
        wristTemperature = record.wristTemperature
        dailyLoad = record.dailyLoad
        workoutLoad = record.workoutLoad
        activityLoad = record.activityLoad
        trainingLoadRatio = record.trainingLoadRatio
        atl = record.atl
        ctl = record.ctl
        tsb = record.tsb
        acwr = record.acwr
        bedtime = record.bedtime
        wakeTime = record.wakeTime
        awakeMinutes = record.awakeMinutes
        awakeEpisodeCount = record.awakeEpisodeCount
        deepSleepMinutes = record.deepSleepMinutes
        remSleepMinutes = record.remSleepMinutes
        workouts = includeWorkouts ? record.toSnapshot().workouts : nil
    }

    enum CodingKeys: String, CodingKey {
        case date
        case sleepScore = "sleep_score"
        case recoveryScore = "recovery_score"
        case strainScore = "strain_score"
        case stressIndex = "stress_index"
        case morningEnergy = "morning_energy"
        case currentEnergy = "current_energy"
        case energyBank = "energy_bank"
        case healthAge = "health_age"
        case hrvAverage = "hrv_average"
        case restingHeartRate = "resting_heart_rate"
        case sleepHours = "sleep_hours"
        case deepSleepPercent = "deep_sleep_percent"
        case remSleepPercent = "rem_sleep_percent"
        case sleepEfficiency = "sleep_efficiency"
        case steps
        case activeCalories = "active_calories"
        case activeMinutes = "active_minutes"
        case workoutCount = "workout_count"
        case workoutTypes = "workout_types"
        case workoutDuration = "workout_duration"
        case bodyWeight = "body_weight"
        case bodyFatPercent = "body_fat_percent"
        case bmi
        case oxygenSaturation = "oxygen_saturation"
        case respiratoryRate = "respiratory_rate"
        case wristTemperature = "wrist_temperature"
        case dailyLoad = "daily_load"
        case workoutLoad = "workout_load"
        case activityLoad = "activity_load"
        case trainingLoadRatio = "training_load_ratio"
        case atl
        case ctl
        case tsb
        case acwr
        case bedtime
        case wakeTime = "wake_time"
        case awakeMinutes = "awake_minutes"
        case awakeEpisodeCount = "awake_episode_count"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case workouts
    }
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
        context += "| Readiness | \(decision.readinessLevel) |\n"
        context += "| Recommendation | \(decision.readinessGuidance) |\n"

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
    let riskLevel: ToolRiskLevel = .write

    let executionContext: ToolExecutionContext

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
            let modelContext = executionContext.modelContext
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
    let riskLevel: ToolRiskLevel = .write

    let executionContext: ToolExecutionContext

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
                ]),
                "idempotency_key": .object([
                    "type": .string("string"),
                    "description": .string("Unique key for idempotency. Generate once and reuse on retry to prevent duplicate plan creation. Use a UUID string.")
                ])
            ]),
            "required": .array([.string("title"), .string("goal_description"), .string("weeks_count"), .string("days")])
        ]
    }

    func execute(arguments: String) async throws -> String {
        return try await MainActor.run {
            let modelContext = executionContext.modelContext
            try PersistenceWriteGate.shared.assertWritable(operation: "CreateTrainingPlanTool", modelContext: modelContext)

            guard let data = arguments.data(using: .utf8) else {
                return "Error: invalid UTF-8 string."
            }

        struct PlanInput: Codable {
            let idempotency_key: String?
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

        // Check idempotency: skip if a plan with this key already exists
        let idempotencyKey = input.idempotency_key ?? UUID().uuidString
        if let key = input.idempotency_key {
            let keyFetch = FetchDescriptor<TrainingPlanRecord>(
                predicate: #Predicate { $0.idempotencyKey == key }
            )
            if let existing = try? modelContext.fetch(keyFetch), let plan = existing.first {
                return "Plan already exists: \(plan.title) (idempotency_key=\(key)). No duplicate created."
            }
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
        plan.idempotencyKey = idempotencyKey

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

/// Delete or deactivate an existing training plan.
struct DeleteTrainingPlanTool: AgentTool {
    let name = "delete_plan"
    let description = "Delete or deactivate an existing training plan by its ID. This is a highly destructive action."
    let riskLevel: ToolRiskLevel = .destructive

    let executionContext: ToolExecutionContext

    var parameters: [String: Value] {
        [
            "type": .string("object"),
            "properties": .object([
                "plan_id": .object([
                    "type": .string("string"),
                    "description": .string("The UUID string of the training plan to delete.")
                ])
            ]),
            "required": .array([.string("plan_id")])
        ]
    }

    func execute(arguments: String) async throws -> String {
        return try await MainActor.run {
            let modelContext = executionContext.modelContext
            try PersistenceWriteGate.shared.assertWritable(operation: "DeleteTrainingPlanTool", modelContext: modelContext)

            guard let data = arguments.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let planIdStr = json["plan_id"] as? String,
                  let planId = UUID(uuidString: planIdStr) else {
                return "Error: missing or invalid 'plan_id' argument."
            }

            let descriptor = FetchDescriptor<TrainingPlanRecord>(
                predicate: #Predicate<TrainingPlanRecord> { $0.id == planId }
            )
            if let plan = try modelContext.fetch(descriptor).first {
                modelContext.delete(plan)
                try modelContext.save()
                return "Successfully deleted training plan \(planId)."
            } else {
                return "Error: training plan \(planId) not found."
            }
        }
    }
}
