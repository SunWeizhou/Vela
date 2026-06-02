import Vapor

/// Chinese LLM prompt templates for Vela.
/// ALL prompts are written in Chinese and request structured JSON output.
/// Each prompt injects the user's recent health context as reasoning evidence.

enum PromptService {

    // MARK: - Temperature Constants

    static let tempFactual: Double = 0.2   // Data analysis, evidence chains
    static let tempBalanced: Double = 0.5  // Training suggestions
    static let tempCreative: Double = 0.7   // Coach conversation, insights

    // MARK: - Coach Chat Prompt

    /// System prompt for the Vela health coach. Uses Claude's system message format.
    static func coachSystemPrompt(lang: String, personality: String = "friend") -> String {
        let langInstruction = lang == "zh"
            ? "你必须始终用简体中文回复。"
            : "You must always reply in English."

        let personalityGuide = personalityGuide(for: personality, lang: lang)

        return """
        你是一个名为 Vela 的 AI 身体智能教练。你运行在用户的 iPhone 上，通过分析 Apple Watch 的健康数据来提供个性化建议。

        ## 身份
        - 名字：Vela
        - 角色：私人健康分析师和生活方式教练
        - 风格：\(personalityGuide)

        ## 语言要求
        \(langInstruction)

        ## 安全规则（绝对不能违反）
        1. 你绝不能做出医疗诊断。你可以说"数据显示你的恢复状态偏低"，但不能说"你可能有过度训练综合征"。
        2. 如果用户描述疼痛、眩晕、胸痛等症状，你必须先建议就医，然后再提供数据解读。
        3. 你的建议是基于生理数据的推理，不是医学建议。每次重要建议前声明这一点。
        4. 永远不要建议极端饮食、禁食、或超出安全范围的运动强度。

        ## 数据上下文
        系统会在每次对话中注入用户最近 7 天的健康摘要，包括：
        - 睡眠：时长、阶段分布（深睡/REM/核心睡眠）、效率、入睡/起床时间
        - 恢复：HRV（心率变异性）、静息心率、呼吸频率、与基线对比
        - 负荷：活动热量、锻炼分钟、步数、运动强度
        - 压力：生理压力指数（基于心率抬升、HRV 抑制、睡眠负债、负荷压力）
        - 能量：晨间能量、当前能量、ATL（7日急性负荷）、CTL（42日慢性负荷）、TSB（训练压力平衡）
        - 身体：体重、体脂、BMI、VO2max、血压、血氧
        - 运动：今日运动列表（类型、时长、心率、热量）

        ## 输出要求
        1. 在分析健康问题时，按以下结构回复：
           - 判断（一句话总结当前状态）
           - 证据（引用具体数据点，如"你的 HRV 是 42ms，比基线 48ms 低了 13%"）
           - 行动建议（今天应该做什么，具体、可执行）
           - 避坑提醒（今天不该做什么）
           - 可追问（给用户 1-2 个可以继续追问的方向）

        2. 如果你认为需要查询网络获取最新健康研究，使用 web_search 工具。
        3. 如果你发现值得记录的模式，使用 propose_memory 工具建议用户保存。
        4. 如果用户询问训练计划，使用 suggest_training 工具生成建议。

        ## 时间感知
        当前时间是用户的本地时间。根据时段调整你的建议：
        - 早晨（6:00-11:00）：关注恢复状态和今日计划
        - 下午（11:00-17:00）：关注能量管理和训练建议
        - 晚上（17:00-22:00）：关注睡眠准备和次日规划
        - 深夜（22:00-6:00）：简洁回复，鼓励休息

        ## 回复长度
        - 一般问题：2-3 句话，简洁直接
        - 分析性问题（"我今天状态怎么样？"）：完整 5 段结构
        - 闲聊：1 句友好回复
        """
    }

    // MARK: - Today Insight Prompt

    static func todayInsightPrompt(context: HealthContext, lang: String) -> String {
        let langInstruction = lang == "zh"
            ? "用简体中文回复。"
            : "Reply in English."

        return """
        \(langInstruction)

        以下是用户今天的健康数据摘要。请根据这些数据生成今日洞察。

        ## 用户数据
        \(formatHealthContext(context))

        ## 任务
        生成一个 JSON 对象（不是自然语言段落），包含以下字段：
        {
          "state_summary": "用户当前整体状态的一句话总结（中文不超过20字）",
          "top_insight": "最重要的一个发现（基于数据异常的优先级）",
          "risks": ["需要关注的风险点，最多2个"],
          "opportunities": ["可以利用的优势窗口，最多2个"],
          "actions": [
            {
              "title": "行动名称（中文，简短）",
              "description": "具体怎么做（中文，1句话）",
              "priority": "high|medium|low",
              "category": "recovery|sleep|strain|nutrition|mindfulness"
            }
          ],
          "accent": "recovery|sleep|strain|energy|stress",
          "confidence": 0.85
        }

        ## 推理规则
        - 如果恢复分数 < 40，state_summary 必须强调"恢复优先"
        - 如果 HRV 比基线低 10% 以上，top_insight 应该指出自主神经恢复不足
        - 如果睡眠效率 < 85%，应该在 risks 中标注睡眠质量问题
        - 如果 TSB < -10，应该建议减量训练
        - confidence 值：所有关键指标都有数据 = 0.85+，缺失 1-2 个 = 0.5-0.7，缺失超过一半 = 0.3

        只返回 JSON，不要有任何额外文字。
        """
    }

    // MARK: - Training Adaptation Prompt

    static func trainingAdaptationPrompt(weekPlan: [TrainingAdaptationRequest.TrainingDay], context: HealthContext, lang: String) -> String {
        let langInstruction = lang == "zh"
            ? "用简体中文回复。"
            : "Reply in English."

        return """
        \(langInstruction)

        以下是一个用户本周的训练计划和他们当前的身体状态数据。请判断哪些训练需要调整。

        ## 本周原始计划
        \(formatTrainingPlan(weekPlan))

        ## 当前身体状态
        \(formatHealthContext(context))

        ## 调整规则
        1. 恢复分数 < 40 → 取消高强度训练日，改为主动恢复
        2. 恢复分数 40-60 → 降低强度，但保持训练日结构
        3. 恢复分数 > 75 + TSB > 5 → 可以适当增加强度
        4. 睡眠分数 < 50 → 训练日后移，先保护睡眠
        5. 压力指数 > 70 → 所有训练降低一级强度

        ## 任务
        生成一个 JSON 数组（不是自然语言段落），包含每天的训练调整建议：
        [
          {
            "day": "周一",
            "keep_original": true/false,
            "suggestion": {
              "title": "调整后的训练名称（如果需要调整）",
              "focus": "cardio|strength|flexibility|rest",
              "duration_minutes": 45,
              "intensity": "low|moderate|high"
            },
            "reason": "中文，解释为什么这样调整，引用具体数据（如：因为你的HRV比基线低12%，说明自主神经恢复不足）",
            "confidence": 0.75
          }
        ]

        对于不需要调整的训练日，suggestion 设为 null，keep_original 设为 true，reason 写"当前恢复状态支持原计划"。

        只返回 JSON 数组，不要有任何额外文字。
        """
    }

    // MARK: - Evidence Chain Prompt

    static func evidenceChainPrompt(claim: String, context: HealthContext, lang: String) -> String {
        let langInstruction = lang == "zh"
            ? "用简体中文回复。"
            : "Reply in English."

        return """
        \(langInstruction)

        用户有一个健康建议声明，需要你分析支撑这条建议的生理数据证据链。

        ## 声明
        \(claim)

        ## 可用的生理数据
        \(formatHealthContext(context))

        ## 任务
        构建一条因果证据链。生成以下 JSON：
        {
          "evidence_chain": [
            {
              "data_point": "具体的数据指标名称（如：7日HRV均值）",
              "value": "该指标的值（如：38ms）",
              "baseline": "该指标的基线或个人正常范围（如：基线45ms）",
              "deviation": "偏离程度（如：-15.6%）",
              "reasoning": "这个数据点为什么支持或不支持该声明（中文，1-2句话）",
              "direction": "supporting|contradicting|neutral",
              "confidence": 0.82
            }
          ],
          "overall_assessment": "综合证据链的总结判断（中文，1-2句话）",
          "overall_confidence": 0.78,
          "limitations": ["证据链的局限性（如：缺少血检数据，无法确认炎症水平）"]
        }

        ## 推理要求
        - 每个证据链节点必须引用具体数字，不能模糊表达
        - 如果数据不足以支持该声明，诚实地在 limitations 中指出
        - confidence 值必须基于数据完整性：所有相关指标都有数据 = 高，缺失关键指标 = 低
        - 区分相关性（correlation）和因果性（causation），明确标注

        只返回 JSON，不要有任何额外文字。
        """
    }

    // MARK: - Memory Pattern Detection Prompt

    static func memoryPatternPrompt(recentContexts: [HealthContext], lang: String) -> String {
        let langInstruction = lang == "zh"
            ? "用简体中文回复。"
            : "Reply in English."

        return """
        \(langInstruction)

        以下用户最近 7 天的健康数据摘要。请识别值得记录的模式。

        ## 7日数据
        \(recentContexts.enumerated().map { i, ctx in
            "第\(i+1)天: \(formatHealthContextBrief(ctx))"
        }.joined(separator: "\n"))

        ## 任务
        生成一个 JSON 数组，包含发现的模式卡片：
        [
          {
            "pattern": "模式名称（中文，5-10字，如：周末睡眠延迟）",
            "description": "模式的详细描述（中文，1-2句话，引用具体数据）",
            "evidence": "支撑数据（如：周六入睡时间 01:30，平日 23:00，平均偏移 2.5 小时）",
            "type": "behavior|physiological|correlation",
            "confidence": 0.78,
            "actionable": true/false,
            "suggested_action": "如果 actionable=true，给出建议（中文，1句话）"
          }
        ]

        ## 检测规则
        - 关注日间变化（如周末 vs 工作日的行为差异）
        - 关注趋势方向（连续改善或恶化的指标）
        - 关注异常值（超出正常范围的数据点）
        - confidence < 0.5 的模式不应该出现
        - 只返回真正有意义的模式，不要为了凑数而生成

        只返回 JSON 数组，不要有任何额外文字。
        """
    }

    // MARK: - Private Helpers

    private static func personalityGuide(for personality: String, lang: String) -> String {
        let zh = lang == "zh"
        switch personality {
        case "data_nerd":
            return zh ? "数据极客——详细分析，引用具体数字，用专业术语，提供完整的数据解读。" : "Data Nerd — detailed analysis, cite specific numbers, use technical terms."
        case "guardian":
            return zh ? "守护者——保守谨慎，优先考虑安全和恢复，强调风险规避。" : "Guardian — conservative and cautious, prioritize safety and recovery."
        case "commander":
            return zh ? "指挥官——直接高效，最短的句子，只说必要的行动建议。" : "Commander — direct and efficient, shortest sentences, action-focused."
        default: // friend
            return zh ? "朋友——轻松友好，鼓励为主，用简单的语言解释复杂概念。" : "Friend — casual and friendly, encouraging, explain complex concepts simply."
        }
    }

    static func formatHealthContext(_ ctx: HealthContext) -> String {
        var parts: [String] = []
        parts.append("日期: \(ctx.date)")

        if let s = ctx.sleep {
            parts.append("睡眠: 分数=\(s.score ?? 0), 时长=\(s.totalMinutes ?? 0)分钟, 深睡=\(s.deepMinutes ?? 0)分钟, REM=\(s.remMinutes ?? 0)分钟, 效率=\(s.efficiency ?? 0)%, 入睡=\(s.bedtime ?? "N/A"), 起床=\(s.wakeTime ?? "N/A")")
        }
        if let r = ctx.recovery {
            parts.append("恢复: 分数=\(r.score ?? 0), HRV=\(r.hrvMs ?? 0)ms(基线\(r.hrvBaseline ?? 0)), 静息心率=\(r.restingHR ?? 0)bpm(基线\(r.rhrBaseline ?? 0)), 呼吸频率=\(r.respiratoryRate ?? 0)")
        }
        if let st = ctx.strain {
            parts.append("负荷: 分数=\(st.score ?? 0), 活动热量=\(st.activeEnergyKcal ?? 0)kcal, 锻炼=\(st.exerciseMinutes ?? 0)分钟, 步数=\(st.stepCount ?? 0), 运动数=\(st.workoutCount ?? 0)")
        }
        if let ss = ctx.stress {
            parts.append("压力: 指数=\(ss.index ?? 0), 等级=\(ss.band ?? "N/A")")
        }
        if let e = ctx.energy {
            parts.append("能量: 晨间=\(e.morningEnergy ?? 0), 当前=\(e.currentEnergy ?? 0), ATL=\(e.atl ?? 0), CTL=\(e.ctl ?? 0), TSB=\(e.tsb ?? 0)")
        }
        if let b = ctx.bodyMetrics {
            parts.append("身体: 体重=\(b.weightKg ?? 0)kg, 体脂=\(b.bodyFatPct ?? 0)%, BMI=\(b.bmi ?? 0), VO2Max=\(b.vo2Max ?? 0)")
        }
        return parts.joined(separator: "\n")
    }

    static func formatHealthContextBrief(_ ctx: HealthContext) -> String {
        let sleep = ctx.sleep.map { "💤\(Int($0.score ?? 0))" } ?? "💤N/A"
        let recovery = ctx.recovery.map { "💚\(Int($0.score ?? 0))" } ?? "💚N/A"
        let strain = ctx.strain.map { "🏃\(Int($0.score ?? 0))" } ?? "🏃N/A"
        let stress = ctx.stress.map { "😓\(Int($0.index ?? 0))" } ?? "😓N/A"
        return "\(sleep) \(recovery) \(strain) \(stress)"
    }

    static func formatTrainingPlan(_ days: [TrainingAdaptationRequest.TrainingDay]) -> String {
        days.map { d in
            "\(d.day): \(d.title) (\(d.focus), \(d.durationMinutes)分钟, \(d.intensity)) [\(d.status)]"
        }.joined(separator: "\n")
    }
}
