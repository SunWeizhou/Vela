import Foundation

// MARK: - Daily State

enum DailyState: String, Codable, Hashable, CaseIterable {
    case great
    case good
    case fair
    case poor
    case unknown

    var label: String {
        switch self {
        case .great: return AppLanguage.stored.isChinese ? "状态极佳" : "Great"
        case .good: return AppLanguage.stored.isChinese ? "状态良好" : "Good"
        case .fair: return AppLanguage.stored.isChinese ? "一般" : "Fair"
        case .poor: return AppLanguage.stored.isChinese ? "需要休息" : "Need Rest"
        case .unknown: return AppLanguage.stored.isChinese ? "数据不足" : "Not Enough Data"
        }
    }

    var emoji: String {
        switch self {
        case .great: return "⚡️"
        case .good: return "👍"
        case .fair: return "🤔"
        case .poor: return "🛟"
        case .unknown: return "📡"
        }
    }

    var color: String {
        switch self {
        case .great: return "energy"
        case .good: return "accent"
        case .fair: return "strain"
        case .poor: return "recovery"
        case .unknown: return "muted"
        }
    }
}

// MARK: - Action Type

enum DailyActionType: String, Codable, Hashable, CaseIterable {
    case train
    case rest
    case activeRecovery
    case nutritionTip
    case sleepTip
    case hydrationTip
    case mobilityTip
    case stressTip
    case dailySummary
    case trainingPlanStep
}

// MARK: - Why This Item

struct WhyThisItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var metricName: String
    var currentValue: String
    var baselineValue: String?
    var interpretation: String
    var confidence: DataConfidence
    var source: HealthDataSource
}

// MARK: - Daily Action

struct DailyAction: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var type: DailyActionType
    var title: String
    var subtitle: String
    var detailMarkdown: String
    var whyThis: [WhyThisItem]
    var evidenceChain: [EvidenceChainItem] = []
    var priority: Int  // 0 = highest
    var iconName: String {
        switch type {
        case .train: return "figure.run"
        case .rest: return "bed.double.fill"
        case .activeRecovery: return "figure.walk"
        case .nutritionTip: return "fork.knife"
        case .sleepTip: return "moon.zzz.fill"
        case .hydrationTip: return "drop.fill"
        case .mobilityTip: return "figure.flexibility"
        case .stressTip: return "brain.head.profile"
        case .dailySummary: return "chart.bar.fill"
        case .trainingPlanStep: return "calendar.badge.clock"
        }
    }
}

// MARK: - Today Plan

struct TodayPlan: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var state: DailyState
    var headline: String
    var subheadline: String
    var topActions: [DailyAction]
    var confidenceNote: String
    var generatedAt: Date
    var contextHash: String
    var schemaVersion: String
    var bodyInterpretation: BodyInterpretation?
}

// MARK: - Daily Plan Builder

struct DailyPlanBuilder {

    static let schemaVersion = "v2.0"

    func build(
        dashboard: DashboardSummary,
        wiki: [String: String],
        activePlan: TrainingPlanRecord?,
        pendingProposals: [MemoryEventRecord] = [],
        generatedAt: Date = Date()
    ) -> TodayPlan {
        let recoveryScore = dashboard.recovery.score
        let energyScore = dashboard.energy.currentEnergy
        let tsb = dashboard.energy.metrics["tsb"] ?? 0
        let sleepScore = dashboard.sleepScore.score
        let strainScore = dashboard.strain.score
        let stressIndex = dashboard.stress.stressIndex

        // Determine state
        let state = computeState(
            recovery: recoveryScore,
            energy: energyScore,
            tsb: tsb,
            sleep: sleepScore,
            confidence: dashboard.recovery.confidence
        )

        // Build headline + subheadline
        let (headline, subheadline) = buildHeadlines(
            state: state,
            recovery: recoveryScore,
            energy: energyScore,
            tsb: tsb,
            sleep: sleepScore,
            strain: strainScore
        )

        // Build actions
        var actions: [DailyAction] = []

        // Primary action based on state
        actions.append(buildPrimaryAction(
            state: state,
            recovery: recoveryScore,
            energy: energyScore,
            tsb: tsb,
            sleep: sleepScore,
            dashboard: dashboard,
            wiki: wiki
        ))

        // Secondary actions
        if sleepScore < 80 {
            actions.append(buildSleepAction(dashboard: dashboard))
        }

        if stressIndex > 50 {
            actions.append(buildStressAction(dashboard: dashboard))
        }

        if let plan = activePlan, let todayStep = findTodayTrainingStep(plan) {
            actions.append(buildTrainingPlanStepAction(step: todayStep, plan: plan))
        }

        // Confidence note
        let confidenceNote = buildConfidenceNote(
            dashboard: dashboard,
            pendingProposals: pendingProposals
        )

        // Sort by priority
        actions.sort { $0.priority < $1.priority }

        let plan = TodayPlan(
            date: dashboard.date,
            state: state,
            headline: headline,
            subheadline: subheadline,
            topActions: Array(actions.prefix(4)),
            confidenceNote: confidenceNote,
            generatedAt: generatedAt,
            contextHash: "",
            schemaVersion: Self.schemaVersion
        )

        var withHash = plan
        if let data = try? JSONEncoder().encode(plan),
           let json = String(data: data, encoding: .utf8) {
            withHash.contextHash = ContentHash.hash(json)
        }
        return withHash
    }

    /// Builds a TodayPlan from a BodyInterpretation — the Vela 2.0 Beta path.
    /// Uses the BodyInterpreterEngine's rich output (fatigue sources, limiter,
    /// training window, risk flags, recovery tasks) instead of the old rule-based approach.
    func build(
        from interpretation: BodyInterpretation,
        activePlan: TrainingPlanRecord? = nil,
        pendingProposals: [MemoryEventRecord] = [],
        wiki: [String: String] = [:]
    ) -> TodayPlan {
        let lang = AppLanguage.stored
        var actions: [DailyAction] = []

        // Primary action from the interpretation's recommendation
        let primaryEvidence = interpretation.recommendedAction.evidenceChain.map { item in
            WhyThisItem(
                metricName: item.metricName,
                currentValue: item.currentValueFormatted,
                baselineValue: item.baselineFormatted,
                interpretation: item.interpretation,
                confidence: item.confidence,
                source: item.source
            )
        }

        actions.append(DailyAction(
            type: interpretation.recommendedAction.type,
            title: interpretation.recommendedAction.title,
            subtitle: interpretation.recommendedAction.subtitle,
            detailMarkdown: interpretation.recommendedAction.detailMarkdown,
            whyThis: primaryEvidence,
            evidenceChain: interpretation.recommendedAction.evidenceChain,
            priority: 0
        ))

        // Alternative actions
        for (i, alt) in interpretation.alternativeActions.enumerated() {
            let altEvidence = alt.evidenceChain.map { item in
                WhyThisItem(
                    metricName: item.metricName,
                    currentValue: item.currentValueFormatted,
                    baselineValue: item.baselineFormatted,
                    interpretation: item.interpretation,
                    confidence: item.confidence,
                    source: item.source
                )
            }
            actions.append(DailyAction(
                type: alt.type,
                title: alt.title,
                subtitle: alt.subtitle,
                detailMarkdown: alt.detailMarkdown,
                whyThis: altEvidence,
                evidenceChain: alt.evidenceChain,
                priority: i + 1
            ))
        }

        // Recovery tasks as actions
        for task in interpretation.recoveryTasks.prefix(2) {
            actions.append(DailyAction(
                type: task.category == "sleep" ? .sleepTip
                    : task.category == "mobility" ? .mobilityTip
                    : task.category == "hydration" ? .hydrationTip
                    : task.category == "breathwork" ? .stressTip
                    : .activeRecovery,
                title: task.title,
                subtitle: task.description,
                detailMarkdown: task.description,
                whyThis: [],
                priority: 2 + task.priority
            ))
        }

        // Risk flags as warnings
        for flag in interpretation.riskFlags {
            actions.append(DailyAction(
                type: .rest,
                title: (flag.level == .critical ? "⚠️ " : "ℹ️ ") + flag.message,
                subtitle: flag.detail,
                detailMarkdown: flag.detail,
                whyThis: [],
                priority: 5
            ))
        }

        actions.sort { $0.priority < $1.priority }

        // Build confidence note from interpretation
        var confidenceParts: [String] = []
        confidenceParts.append(lang.isChinese
            ? "整体置信度：\(interpretation.overallConfidence == .high ? "高" : interpretation.overallConfidence == .medium ? "中" : "低")"
            : "Overall confidence: \(interpretation.overallConfidence.rawValue)"
        )
        if !pendingProposals.isEmpty {
            confidenceParts.append(lang.isChinese
                ? "\(pendingProposals.count) 条待确认记忆"
                : "\(pendingProposals.count) pending memories"
            )
        }

        // Subheadline from limiter + training window
        let subheadline: String
        if lang.isChinese {
            subheadline = "主要限制：\(interpretation.primaryLimiter.system) · 训练窗口：\(interpretation.trainingWindow.isOpen ? "开启" : "关闭") · 疲劳：\(interpretation.fatigueLevel.label)"
        } else {
            subheadline = "Limiter: \(interpretation.primaryLimiter.system) · Window: \(interpretation.trainingWindow.isOpen ? "Open" : "Closed") · Fatigue: \(interpretation.fatigueLevel.label)"
        }

        let plan = TodayPlan(
            date: Date(),
            state: interpretation.dailyState,
            headline: interpretation.readinessNarrative.components(separatedBy: "\n").first ?? interpretation.readinessNarrative,
            subheadline: subheadline,
            topActions: Array(actions.prefix(5)),
            confidenceNote: confidenceParts.joined(separator: " · "),
            generatedAt: interpretation.generatedAt,
            contextHash: interpretation.contextHash,
            schemaVersion: BodyInterpreterEngine.schemaVersion,
            bodyInterpretation: interpretation
        )

        var withHash = plan
        if let data = try? JSONEncoder().encode(plan),
           let json = String(data: data, encoding: .utf8) {
            withHash.contextHash = ContentHash.hash(json)
        }
        return withHash
    }

    // MARK: - Private Helpers

    private func computeState(
        recovery: Double,
        energy: Double,
        tsb: Double,
        sleep: Double,
        confidence: ScoreConfidence
    ) -> DailyState {
        if confidence == .low { return .unknown }
        if recovery > 75 && energy > 60 && tsb > 5 && sleep > 80 { return .great }
        if recovery > 60 && energy > 40 && tsb > -5 { return .good }
        if recovery > 40 && energy > 20 { return .fair }
        if recovery > 0 { return .poor }
        return .unknown
    }

    private func buildHeadlines(
        state: DailyState,
        recovery: Double,
        energy: Double,
        tsb: Double,
        sleep: Double,
        strain: Double
    ) -> (String, String) {
        let lang = AppLanguage.stored

        switch state {
        case .great:
            if lang.isChinese {
                return ("今天适合高强度训练", "恢复评分 \(Int(recovery))，能量充足 (\(Int(energy)))，TSB +\(Int(tsb))")
            }
            return ("Ready for high-intensity training", "Recovery \(Int(recovery)), energy \(Int(energy)), TSB +\(Int(tsb))")
        case .good:
            if lang.isChinese {
                return ("今天可以正常训练", "恢复评分 \(Int(recovery))，建议中等强度")
            }
            return ("Good day to train", "Recovery \(Int(recovery)), moderate intensity recommended")
        case .fair:
            if lang.isChinese {
                return ("今天适合轻量活动", "恢复评分 \(Int(recovery))，建议以恢复为主")
            }
            return ("Light activity recommended", "Recovery \(Int(recovery)), focus on recovery")
        case .poor:
            if lang.isChinese {
                return ("今天建议休息", "恢复评分仅 \(Int(recovery))，身体需要恢复")
            }
            return ("Rest day recommended", "Recovery only \(Int(recovery)), your body needs rest")
        case .unknown:
            if lang.isChinese {
                return ("数据收集中...", "还需要几天数据才能给出准确建议")
            }
            return ("Collecting data...", "A few more days of data needed")
        }
    }

    private func buildPrimaryAction(
        state: DailyState,
        recovery: Double,
        energy: Double,
        tsb: Double,
        sleep: Double,
        dashboard: DashboardSummary,
        wiki: [String: String]
    ) -> DailyAction {
        let lang = AppLanguage.stored
        let whyItems = buildWhyItems(dashboard: dashboard)

        switch state {
        case .great:
            return DailyAction(
                type: .train,
                title: lang.isChinese ? "🏋️ 高强度训练日" : "🏋️ High-Intensity Training",
                subtitle: lang.isChinese ? "目标心率 Zone 4-5，力量训练 5x5" : "Target HR Zone 4-5, strength 5x5",
                detailMarkdown: buildTrainingDetail(recovery: recovery, tsb: tsb, wiki: wiki, lang: lang),
                whyThis: whyItems,
                priority: 0
            )
        case .good:
            return DailyAction(
                type: .train,
                title: lang.isChinese ? "💪 常规训练" : "💪 Regular Training",
                subtitle: lang.isChinese ? "中等强度，Zone 2-3 有氧 + 力量" : "Moderate, Zone 2-3 cardio + strength",
                detailMarkdown: lang.isChinese
                    ? "你今天恢复状态良好，可以进行常规训练。建议控制在中等强度，避免过度疲劳。"
                    : "Your recovery is solid. Regular training at moderate intensity is appropriate.",
                whyThis: whyItems,
                priority: 0
            )
        case .fair:
            return DailyAction(
                type: .activeRecovery,
                title: lang.isChinese ? "🚶 主动恢复" : "🚶 Active Recovery",
                subtitle: lang.isChinese ? "散步、瑜伽、泡沫轴放松" : "Walking, yoga, foam rolling",
                detailMarkdown: lang.isChinese
                    ? "身体处于中等恢复状态，不建议高强度训练。选择散步、瑜伽、泡沫轴放松等低强度活动。"
                    : "Your body is at moderate recovery. Choose walking, yoga, or foam rolling instead of intense training.",
                whyThis: whyItems,
                priority: 0
            )
        case .poor:
            return DailyAction(
                type: .rest,
                title: lang.isChinese ? "🛌 完整休息日" : "🛌 Full Rest Day",
                subtitle: lang.isChinese ? "睡眠优先，补充营养，轻度拉伸" : "Prioritize sleep, nutrition, light stretching",
                detailMarkdown: lang.isChinese
                    ? "你的身体今天需要休息。优先保证充足睡眠，补充营养，可以做些轻度拉伸帮助恢复。"
                    : "Your body needs rest today. Prioritize sleep, nutrition, and light stretching.",
                whyThis: whyItems,
                priority: 0
            )
        case .unknown:
            return DailyAction(
                type: .dailySummary,
                title: lang.isChinese ? "📡 建立基线中" : "📡 Building Baseline",
                subtitle: lang.isChinese ? "持续佩戴 Apple Watch 3-5 天" : "Wear Apple Watch for 3-5 more days",
                detailMarkdown: lang.isChinese
                    ? "Vela 正在建立你的个人生理基线。持续佩戴 Apple Watch 3-5 天后，系统就能给出个性化建议。"
                    : "Vela is building your personal baseline. Keep wearing your Apple Watch for 3-5 more days.",
                whyThis: [
                    WhyThisItem(
                        metricName: "Recovery",
                        currentValue: "\(Int(recovery))/100",
                        baselineValue: nil,
                        interpretation: lang.isChinese ? "需要更多数据来计算个人基线" : "Need more data to compute baseline",
                        confidence: .low,
                        source: .computed
                    )
                ],
                priority: 0
            )
        }
    }

    private func buildWhyItems(dashboard: DashboardSummary) -> [WhyThisItem] {
        var items: [WhyThisItem] = []

        items.append(WhyThisItem(
            metricName: "Recovery",
            currentValue: "\(Int(dashboard.recovery.score))/100",
            baselineValue: nil,
            interpretation: dashboard.recovery.reasons.first ?? "",
            confidence: dashboard.recovery.confidence.rawValue == "high" ? .high : .medium,
            source: .computed
        ))

        items.append(WhyThisItem(
            metricName: "Energy Bank",
            currentValue: "\(Int(dashboard.energy.currentEnergy))/100",
            baselineValue: nil,
            interpretation: dashboard.energy.status.rawValue,
            confidence: .medium,
            source: .computed
        ))

        if let tsb = dashboard.energy.metrics["tsb"] {
            let tsbInt = Int(tsb)
            let interpretation: String
            if tsbInt < -15 {
                interpretation = AppLanguage.stored.isChinese ? "训练负荷累积较高，建议减载" : "High accumulated fatigue, deload recommended"
            } else if tsbInt > 10 {
                interpretation = AppLanguage.stored.isChinese ? "身体充分恢复，可承受高负荷" : "Well recovered, ready for high load"
            } else {
                interpretation = AppLanguage.stored.isChinese ? "训练负荷适中" : "Training load is balanced"
            }
            items.append(WhyThisItem(
                metricName: "TSB",
                currentValue: "\(tsbInt > 0 ? "+" : "")\(tsbInt)",
                baselineValue: nil,
                interpretation: interpretation,
                confidence: .medium,
                source: .computed
            ))
        }

        return items
    }

    private func buildTrainingDetail(recovery: Double, tsb: Double, wiki: [String: String], lang: AppLanguage) -> String {
        let goalsText = wiki["goals.md"] ?? ""
        var detail = ""

        if lang.isChinese {
            detail += "**为什么今天是高强度训练日**\n\n"
            detail += "- 恢复评分 \(Int(recovery))/100：身体已充分恢复\n"
            detail += "- TSB +\(Int(tsb))：训练压力平衡为正，可承受高负荷\n\n"
            detail += "**建议训练方案**\n\n"
            detail += "- 热身：10 分钟动态拉伸 + Zone 1-2\n"
            detail += "- 主体：Zone 4-5 间歇训练 或 力量 5x5\n"
            detail += "- 放松：10 分钟静态拉伸\n"
        } else {
            detail += "**Why today is a high-intensity day**\n\n"
            detail += "- Recovery \(Int(recovery))/100: body is well recovered\n"
            detail += "- TSB +\(Int(tsb)): positive training stress balance\n\n"
            detail += "**Recommended Plan**\n\n"
            detail += "- Warmup: 10 min dynamic stretch + Zone 1-2\n"
            detail += "- Main: Zone 4-5 intervals or strength 5x5\n"
            detail += "- Cooldown: 10 min static stretch\n"
        }

        if !goalsText.isEmpty {
            detail += "\n\n**\(lang.isChinese ? "你的目标" : "Your Goals")**: \(goalsText.prefix(200))"
        }

        return detail
    }

    private func buildSleepAction(dashboard: DashboardSummary) -> DailyAction {
        let lang = AppLanguage.stored
        let efficiency = dashboard.sleepScore.metrics["sleep_efficiency"] ?? 0
        return DailyAction(
            type: .sleepTip,
            title: lang.isChinese ? "😴 优化睡眠" : "😴 Improve Sleep",
            subtitle: lang.isChinese
                ? "睡眠效率 \(String(format: "%.0f", efficiency))%，建议提前 30 分钟入睡"
                : "Sleep efficiency \(String(format: "%.0f", efficiency))%, try going to bed 30 min earlier",
            detailMarkdown: lang.isChinese
                ? "睡眠效率偏低。建议：睡前 1 小时不看屏幕，保持卧室凉爽（18-20°C），避免午后咖啡因。"
                : "Sleep efficiency is low. Tips: no screens 1h before bed, cool bedroom (18-20°C), avoid afternoon caffeine.",
            whyThis: [
                WhyThisItem(
                    metricName: "Sleep Efficiency",
                    currentValue: "\(String(format: "%.0f", efficiency))%",
                    baselineValue: "85%",
                    interpretation: lang.isChinese ? "低于 85% 理想值，可通过睡眠卫生改善" : "Below 85% ideal, improvable via sleep hygiene",
                    confidence: .high,
                    source: .healthKit
                )
            ],
            priority: 1
        )
    }

    private func buildStressAction(dashboard: DashboardSummary) -> DailyAction {
        let lang = AppLanguage.stored
        return DailyAction(
            type: .stressTip,
            title: lang.isChinese ? "🧘 压力管理" : "🧘 Manage Stress",
            subtitle: lang.isChinese
                ? "压力指数 \(Int(dashboard.stress.stressIndex))/100，建议正念或深呼吸"
                : "Stress index \(Int(dashboard.stress.stressIndex))/100, try mindfulness or breathwork",
            detailMarkdown: lang.isChinese
                ? "压力指数偏高。建议：5 分钟深呼吸练习（4-7-8 法），或 10 分钟正念冥想。"
                : "Stress index is elevated. Try: 5 min deep breathing (4-7-8 method), or 10 min mindfulness.",
            whyThis: [
                WhyThisItem(
                    metricName: "Stress Index",
                    currentValue: "\(Int(dashboard.stress.stressIndex))/100",
                    baselineValue: "< 40",
                    interpretation: lang.isChinese ? "高于理想范围，建议减压活动" : "Above ideal range, stress-reducing activities recommended",
                    confidence: .medium,
                    source: .computed
                )
            ],
            priority: 2
        )
    }

    private func buildTrainingPlanStepAction(step: TrainingDay, plan: TrainingPlanRecord) -> DailyAction {
        let lang = AppLanguage.stored
        let intensityText = lang.isChinese
            ? (step.intensity == "high" ? "高强度" : step.intensity == "moderate" ? "中等强度" : "低强度")
            : step.intensity

        return DailyAction(
            type: .trainingPlanStep,
            title: lang.isChinese
                ? "📅 今日训练计划：\(step.title)"
                : "📅 Today's Plan: \(step.title)",
            subtitle: "\(intensityText) · \(step.durationMinutes) min · \(step.focus)",
            detailMarkdown: step.description,
            whyThis: [
                WhyThisItem(
                    metricName: "Training Plan Progress",
                    currentValue: "W\(step.weekNumber)D\(step.dayNumber)",
                    baselineValue: "\(plan.weeksCount) weeks total",
                    interpretation: lang.isChinese ? "来自训练计划「\(plan.title)」" : "From training plan '\(plan.title)'",
                    confidence: .high,
                    source: .userProvided
                )
            ],
            priority: 1
        )
    }

    private func findTodayTrainingStep(_ plan: TrainingPlanRecord) -> TrainingDay? {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        // Convert Sunday=1 to Monday=1
        let dayNumber = weekday == 1 ? 7 : weekday - 1
        return plan.days.first { !$0.isCompleted && $0.dayNumber == dayNumber }
    }

    private func buildConfidenceNote(
        dashboard: DashboardSummary,
        pendingProposals: [MemoryEventRecord]
    ) -> String {
        let lang = AppLanguage.stored
        var notes: [String] = []

        if dashboard.recovery.confidence == .low {
            notes.append(lang.isChinese ? "恢复数据置信度较低，建议多佩戴 Apple Watch" : "Recovery confidence is low; wear Apple Watch more consistently")
        }

        if pendingProposals.count > 0 {
            let count = pendingProposals.count
            notes.append(lang.isChinese
                ? "有 \(count) 条待确认记忆等待你的审核"
                : "\(count) pending memories await your review"
            )
        }

        if notes.isEmpty {
            notes.append(lang.isChinese ? "所有数据置信度良好" : "All data confidence levels are good")
        }

        return notes.joined(separator: " · ")
    }
}
