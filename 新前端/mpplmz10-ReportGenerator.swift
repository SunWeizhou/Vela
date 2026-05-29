import Foundation

struct ReportGenerator: Sendable {
    var provider: LLMProvider
    var language: AppLanguage = .stored

    func generate(type: AIReportType, context: AgentContextEnvelope) async throws -> GeneratedAIReport {
        let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return encoder
        }()
        let contextData = try encoder.encode(context)
        let contextJSON = String(data: contextData, encoding: .utf8) ?? "{}"
        let response = try await provider.complete(
            request: LLMRequest(
                systemPrompt: systemPrompt,
                userPrompt: prompt(for: type),
                contextJSON: contextJSON
            )
        )
        return GeneratedAIReport(
            type: type,
            title: localizedReportTitle(type),
            markdownContent: response.content,
            contextSnapshot: contextJSON,
            createdAt: Date()
        )
    }

    private var systemPrompt: String {
        if language.isChinese {
            return """
            你是 Vela，一个 local-first 的私人健康数据分析与生活方式教练。
            使用简体中文回答。不要做医疗诊断。Stress 只能解释为生理代理指标，Health Age Trend 是 beta 趋势，不代表真实生物年龄。
            输出使用 Markdown，结构包含：结论、依据、建议。语言克制、具体、可执行。
            """
        }
        return """
        You are Vela, a private local-first health data analyst. Give cautious wellness guidance.
        Do not diagnose. Explain stress as a proxy and health age as a beta trend.
        Use conclusion, evidence, suggestion. Keep the answer concise.
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
                (根据恢复评分，推荐今日最适合的训练类型和心率区间，指明是否适合高负荷冲击)
                """
            case .sleepReview:
                return "生成睡眠复盘：结论、可能影响因素、今晚建议。"
            case .workoutReadiness:
                return "生成训练准备度：建议轻量、中等、较高强度或恢复日，并说明依据。"
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
