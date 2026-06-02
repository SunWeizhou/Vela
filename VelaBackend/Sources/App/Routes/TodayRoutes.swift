import Vapor

struct TodayRoutes: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let today = routes.grouped("api", "today")
        today.get("plan", use: getPlan)
    }

    /// GET /api/today/plan?lang=zh&recovery=72&sleep=78&strain=65&stress=34&energy=71&hrv=42&hrvBaseline=45&rhr=62&rhrBaseline=60
    func getPlan(req: Request) async throws -> TodayPlanResponse {
        let lang = SupportedLanguage.from(queryString(req, "lang"))
        let llm = LLMService(app: req.application)
        let journalFlags = Set(
            (queryString(req, "journalFlags") ?? "")
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )

        // ── Parse query params into HealthContext ──
        let sleep = SleepCtx(
            score: queryDouble(req, "sleep"),
            totalMinutes: queryInt(req, "sleepMinutes"),
            awakeMinutes: queryInt(req, "awakeMinutes"),
            awakeEpisodeCount: queryInt(req, "awakeEpisodeCount"),
            remPct: queryDouble(req, "remPct"),
            deepPct: queryDouble(req, "deepPct"),
            efficiency: queryDouble(req, "sleepEfficiency")
        )
        let recovery = RecoveryCtx(
            score: queryDouble(req, "recovery"),
            hrvMs: queryDouble(req, "hrv"),
            hrvBaseline: queryDouble(req, "hrvBaseline"),
            restingHR: queryDouble(req, "rhr"),
            rhrBaseline: queryDouble(req, "rhrBaseline"),
            hrvZScore: queryDouble(req, "hrvZScore"),
            rhrZScore: queryDouble(req, "rhrZScore"),
            respiratoryRateZ: queryDouble(req, "respiratoryRateZ"),
            bodyTempDelta: queryDouble(req, "bodyTempDelta"),
            spo2: queryDouble(req, "spo2")
        )
        let strain = StrainCtx(
            score: queryDouble(req, "strain"),
            exerciseMinutes: queryInt(req, "exerciseMinutes")
        )
        let stress = StressCtx(index: queryDouble(req, "stress"))
        let energy = EnergyCtx(
            currentEnergy: queryDouble(req, "energy"),
            atl: queryDouble(req, "atl"),
            ctl: queryDouble(req, "ctl"),
            tsb: queryDouble(req, "tsb"),
            acwr: queryDouble(req, "acwr")
        )
        let ctx = HealthContext(
            date: ISO8601DateFormatter().string(from: Date()),
            sleep: sleep,
            recovery: recovery,
            strain: strain,
            stress: stress,
            energy: energy,
            bodyMetrics: nil
        )

        if !journalFlags.isDisjoint(with: ["sick", "injured"]) {
            return TodayPlanResponse(
                kind: "rest",
                title: "今天安排休息",
                body: "日志记录了生病或受伤。今天停止训练，专注恢复；症状明显或持续时请咨询医生。",
                primaryAction: "规划休息日",
                secondaryAction: nil,
                limiter: nil,
                accent: "recovery"
            )
        }

        // ── Generate plan via LLM ──
        let prompt = PromptService.todayInsightPrompt(context: ctx, lang: lang.rawValue)
        let jsonStr = try await llm.jsonCompletion(
            prompt: prompt,
            temperature: PromptService.tempFactual,
            lang: lang.rawValue
        )

        // ── Parse LLM JSON response ──
        guard let data = jsonStr.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Abort(.internalServerError, reason: "Failed to parse LLM response")
        }

        let actions = (json["actions"] as? [[String: Any]]) ?? []
        let primaryAction = (actions.first?["title"] as? String) ?? "查看详细分析"

        return TodayPlanResponse(
            kind: detectPlanKind(from: ctx),
            title: json["state_summary"] as? String ?? "今日状态分析",
            body: json["top_insight"] as? String ?? "",
            primaryAction: primaryAction,
            secondaryAction: actions.count > 1 ? (actions[1]["title"] as? String) : nil,
            limiter: detectLimiter(from: ctx),
            accent: json["accent"] as? String ?? "recovery"
        )
    }

    private func detectPlanKind(from ctx: HealthContext) -> String {
        let recovery = ctx.recovery?.score ?? 50
        let energy = ctx.energy?.currentEnergy ?? 50

        if recovery < 40 { return "recovery" }
        if recovery >= 70 && energy >= 60 { return "train" }
        if recovery >= 50 { return "maintain" }
        return "protect_sleep"
    }

    private func detectLimiter(from ctx: HealthContext) -> TodayPlanResponse.LimiterInfo? {
        if let hrv = ctx.recovery?.hrvMs, let baseline = ctx.recovery?.hrvBaseline, baseline > 0 {
            let pct = (hrv - baseline) / baseline * 100
            if pct < -10 {
                return TodayPlanResponse.LimiterInfo(kind: "hrv", title: "HRV 是主要限制因素", detail: "HRV 比基线低 \(String(format: "%.0f", abs(pct)))%")
            }
        }
        if let sleep = ctx.sleep?.score, sleep < 70 {
            return TodayPlanResponse.LimiterInfo(kind: "sleep", title: "睡眠限制恢复", detail: "睡眠分数低于 70")
        }
        return nil
    }

    private func queryString(_ req: Request, _ key: String) -> String? {
        req.query[String.self, at: key]
    }

    private func queryDouble(_ req: Request, _ key: String) -> Double? {
        queryString(req, key).flatMap { Double($0) }
    }

    private func queryInt(_ req: Request, _ key: String) -> Int? {
        queryString(req, key).flatMap { Int($0) }
    }
}
