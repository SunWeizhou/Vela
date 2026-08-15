import Foundation

struct ReportGenerator: Sendable {
    var provider: LLMProvider
    var language: AppLanguage = .stored
    /// Bounds the context JSON sent to the model to fit its context window.
    static let maxContextCharacters = 12_000

    func generate(type: AIReportType, context: AgentFactSnapshot) async throws -> GeneratedAIReport {
        let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return encoder
        }()
        let contextData = try encoder.encode(context)
        let fullContextJSON = String(data: contextData, encoding: .utf8) ?? "{}"
        // Cap the context sent to the model. The full AgentContextEnvelope (journal
        // history, wiki, 34-day trends, past reports) can exceed the model's context
        // window for long-standing users, causing a hard 400/context-length error on
        // every report. Bound it by dropping the largest top-level keys until the
        // serialized form fits — the model always receives VALID JSON, never a
        // character-truncated fragment. (The full snapshot is still stored.)
        let contextJSON = Self.trimmedContextJSON(from: fullContextJSON)

        var userPrompt = prompt(for: type)
        if type == .morningBrief {
            let facts = buildMorningBriefFactsPrompt(from: context)
            userPrompt += "\n\n" + facts
        }

        let response = try await provider.complete(
            request: LLMRequest(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                contextJSON: contextJSON
            )
        )
        return GeneratedAIReport(
            type: type,
            title: localizedReportTitle(type),
            markdownContent: response.content,
            contextSnapshot: fullContextJSON,
            createdAt: Date()
        )
    }

    /// 把超预算的 context JSON 裁剪为合法 JSON：解析为顶层字典后逐次丢弃
    /// 体积最大的键，直到序列化长度 ≤ maxChars。解析失败时退回前缀截断。
    static func trimmedContextJSON(
        from full: String,
        maxChars: Int = maxContextCharacters
    ) -> String {
        guard full.utf8.count > maxChars,
              let data = full.data(using: .utf8),
              var dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return String(full.prefix(maxChars))
        }
        func serializedSize(_ object: Any) -> Int {
            // JSONSerialization 要求顶层为数组/字典，标量直接写会抛 NSException
            // （try? 无法捕获），故标量先包一层数组估量。
            let topLevel: Any = (object is [String: Any] || object is [Any]) ? object : [object]
            return (try? JSONSerialization.data(withJSONObject: topLevel, options: []))?.count ?? 0
        }
        func fits(_ d: [String: Any]) -> Bool {
            serializedSize(d) <= maxChars
        }
        while !fits(dict), dict.count > 1 {
            guard let largestKey = dict.max(by: { serializedSize($0.value) < serializedSize($1.value) })?.key else {
                break
            }
            dict.removeValue(forKey: largestKey)
        }
        if let trimmed = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
           let json = String(data: trimmed, encoding: .utf8) {
            return json
        }
        return "{}"
    }

    // A6：晨报上下文从 v1 AgentContextEnvelope 迁移到 v2 AgentFactSnapshot，
    // 与 Coach / 晚间同步同源（此前三处对同一天产生不同表示）。
    private func buildMorningBriefFactsPrompt(from context: AgentFactSnapshot) -> String {
        func intMetric(_ metric: MetricValue<Double>) -> String {
            metric.value.map { "\(Int($0.rounded()))" } ?? "N/A"
        }
        let recoveryScore = intMetric(context.recovery.score)
        let recoveryBand = context.recovery.band
        let sleepScore = intMetric(context.sleep.score)
        let sleepDurationMin = context.sleep.totalMinutes.value.map { "\($0)" } ?? "N/A"
        let sleepEfficiencyPct = intMetric(context.sleep.efficiency)
        let hrvToday = intMetric(context.recovery.hrv)
        let hrvBaseline = context.recovery.hrv.baseline?.baselineValue.map { "\(Int($0.rounded()))" } ?? "N/A"
        let hrvZScore = context.recovery.hrv.baseline?.zScore.map { String(format: "%.2f", $0) } ?? "N/A"
        let hrvVsBaselinePct = context.recovery.hrv.baseline?.deltaPercent.map { "\(Int($0.rounded()))%" } ?? "N/A"
        let rhrToday = intMetric(context.recovery.restingHeartRate)
        let rhrBaseline = context.recovery.restingHeartRate.baseline?.baselineValue.map { "\(Int($0.rounded()))" } ?? "N/A"

        let readinessLevel = context.trainingDecision.readinessLevel
        let readinessGuidance = context.trainingDecision.readinessGuidance

        if language.isChinese {
            return """
            [CRITICAL DIRECTIVE: The following physical facts are pre-calculated locally from verified data sources. You MUST populate your Markdown table and verbal text strictly using these values. NEVER hallucinate, extrapolate, or alter any numbers. If any value is "N/A", display it as "N/A" or "--" and mention that historical calibration is in progress.]

            今日客观身体指标事实 (MorningBriefFacts):
            - 恢复得分 (Recovery Score): \(recoveryScore) 分 (Band: \(recoveryBand))
            - 睡眠得分 (Sleep Score): \(sleepScore) 分 (时长: \(sleepDurationMin) 分钟, 效率: \(sleepEfficiencyPct))
            - HRV 今日值: \(hrvToday) ms
            - HRV 基线值: \(hrvBaseline) ms
            - HRV 相对基线偏差 (vs Baseline): \(hrvVsBaselinePct) (Z-Score: \(hrvZScore))
            - 静息心率 今日值: \(rhrToday) bpm
            - 静息心率 基线值: \(rhrBaseline) bpm
            - 训练准备度级别 (Readiness): \(readinessLevel)
            - 训练指导建议 (Guidance): \(readinessGuidance)
            """
        } else {
            return """
            [CRITICAL DIRECTIVE: The following physical facts are pre-calculated locally from verified data sources. You MUST populate your Markdown table and verbal text strictly using these values. NEVER extrapolate or alter any numbers. If any value is "N/A", display it as "N/A" or "--" and mention that historical calibration is in progress.]

            Today's Objective Physical Facts (MorningBriefFacts):
            - Recovery Score: \(recoveryScore) (Band: \(recoveryBand))
            - Sleep Score: \(sleepScore) (Duration: \(sleepDurationMin) mins, Efficiency: \(sleepEfficiencyPct))
            - HRV Today: \(hrvToday) ms
            - HRV Baseline: \(hrvBaseline) ms
            - HRV vs Baseline Pct: \(hrvVsBaselinePct) (Z-Score: \(hrvZScore))
            - Resting HR Today: \(rhrToday) bpm
            - Resting HR Baseline: \(rhrBaseline) bpm
            - Athletic Readiness Level: \(readinessLevel)
            - Athletic Readiness Guidance: \(readinessGuidance)
            """
        }
    }

    private var systemPrompt: String {
        if language.isChinese {
            return """
            你是 Vela，一个 local-first 的私人健康数据分析与生活方式教练。
            使用简体中文回答。不要做医疗诊断。压力指数只能解释为生理代理指标；“健康信号参考”不代表真实生物年龄，只有明确标记的完整 PhenoAge 化验估算才可称为生物年龄估算。
            输出使用 Markdown，结构包含：结论、依据、建议。语言克制、具体、可执行。
            每条建议必须注明来源、置信度（高/中/低），并附“安全声明：一般健康建议，不构成医疗诊断。”
            """
        }
        return """
        You are Vela, a private local-first health data analyst. Give cautious wellness guidance.
        Do not diagnose. Explain stress as a proxy and a health-signal reference as distinct from a biological-age estimate; only an explicitly complete PhenoAge lab estimate may be called biological age.
        Use conclusion, evidence, suggestion. Keep the answer concise.
        Every recommendation must include source, confidence (high/medium/low), and "Safety: General wellness guidance only; not a medical diagnosis."
        """
    }

    private func prompt(for type: AIReportType) -> String {
        if language.isChinese {
            switch type {
            case .morningBrief:
                return """
                生成今日 Morning Brief，严格遵循以下结构，使用精美的 Emoji 和 Markdown 表格：
                
                ## 🌅 今日状态一句话
                (用一两句话简明扼要地概括今日整体生理恢复与准备度状态)
                
                ## 📊 关键指标对比
                | 指标 | 今日 | 基线 | 趋势 |
                | :--- | :--- | :--- | :--- |
                | 💓 HRV (心率变异性) | [数值] ms | [数值] ms | [Z-Score/百分比偏差] |
                | 🫀 RHR (静息心率) | [数值] bpm | [数值] bpm | [偏差值] |
                | 🛌 睡眠得分 | [数值] 分 | -- | [睡眠时长与效率] |
                | 🔋 恢复得分 | [数值] 分 | -- | [恢复级别/Band] |
                
                ## 🎯 今日建议
                (给出最多 3 条具体的、高度可执行的今日健康与恢复建议，例如补水、睡眠卫生或压力管理)
                
                ## ⚡ 训练与负荷窗口
                (优先遵循本地训练决策；如关键数据缺失，仅说明保守选择和待补信号。不要仅凭恢复分推荐高负荷、心率区间或加量。)
                """
            case .sleepReview:
                return "生成睡眠复盘：结论、可能影响因素、今晚建议。"
            case .workoutReadiness:
                return "生成训练准备度：优先复述本地训练决策；数据不足时给出保守选择，并说明依据和待补信号。"
            case .weeklyReview:
                return "基于可用趋势、日记和历史报告生成周复盘。"
            case .coachPrompt:
                return "基于当前健康数据和上下文回答用户的问题。"
            }
        }
        switch type {
        case .morningBrief:
            return """
            Generate today's Morning Brief, strictly following this structure with rich Emojis and Markdown tables:
            
            ## 🌅 Today in One Sentence
            (Summarize today's overall physiological recovery and readiness in 1-2 concise sentences)
            
            ## 📊 Key Metrics Comparison
            | Metric | Today | Baseline | Trend |
            | :--- | :--- | :--- | :--- |
            | 💓 HRV (Heart Rate Variability) | [Value] ms | [Value] ms | [Z-Score or Pct deviation] |
            | 🫀 RHR (Resting Heart Rate) | [Value] bpm | [Value] bpm | [Deviation] |
            | 🛌 Sleep Score | [Value] | -- | [Duration & Efficiency] |
            | 🔋 Recovery Score | [Value] | -- | [Recovery Level/Band] |
            
            ## 🎯 Recommendations for Today
            (List up to 3 highly actionable health, training, or recovery tips)
            
            ## ⚡ Training & Load Window
            (Recommend today's optimal training intensity, type, and target zones based on recovery state)
            """
        case .sleepReview:
            return "Generate a Sleep Review with conclusion, possible factors, and tonight's suggestion."
        case .workoutReadiness:
            return "Generate Workout Readiness: light, moderate, hard, or recovery day, with evidence."
        case .weeklyReview:
            return "Generate a Weekly Review from available trends, journal, and historical reports."
        case .coachPrompt:
            return "Answer the user's question based on current health data and context."
        }
    }
}
