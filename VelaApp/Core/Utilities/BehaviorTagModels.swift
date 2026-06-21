import Foundation
import SwiftUI

enum BehaviorTag: String, Codable, Hashable, CaseIterable {
    case alcohol
    case caffeine
    case lateMeal
    case highFat
    case highSalt
    case highSugar
    case overeating
    case lowHydration
    case spicy
    case lowProtein

    var displayTitle: String {
        switch self {
        case .alcohol: return "饮酒"
        case .caffeine: return "咖啡因"
        case .lateMeal: return "晚餐过晚"
        case .highFat: return "高油"
        case .highSalt: return "高盐"
        case .highSugar: return "高糖"
        case .overeating: return "吃撑"
        case .lowHydration: return "补水不足"
        case .spicy: return "辛辣"
        case .lowProtein: return "蛋白不足"
        }
    }
}

enum BehaviorIntensity: String, Codable, Hashable, CaseIterable {
    case low
    case medium
    case high
}

enum BehaviorTiming: String, Codable, Hashable, CaseIterable {
    case morning
    case midday
    case evening
    case preSleep
    case unknown
}

enum BehaviorSignalConfidence: String, Codable, Hashable, CaseIterable {
    case userConfirmed
    case aiInferred
    case photoAssisted
}

struct BehaviorSignal: Codable, Hashable, Identifiable {
    var id: String
    var tag: BehaviorTag
    var intensity: BehaviorIntensity
    var timing: BehaviorTiming
    var confidence: BehaviorSignalConfidence
    var sourceNote: String
    var createdAt: Date
}

enum BehaviorSignalExtractor {
    static func extract(
        from text: String,
        createdAt: Date = Date(),
        confidence: BehaviorSignalConfidence = .aiInferred
    ) -> [BehaviorSignal] {
        let lowered = text.lowercased()
        var signals: [BehaviorTag: BehaviorSignal] = [:]

        func timing(default fallback: BehaviorTiming = .unknown) -> BehaviorTiming {
            if lowered.contains("睡前") || lowered.contains("临睡") || lowered.contains("before bed") { return .preSleep }
            if lowered.contains("早上") || lowered.contains("早餐") || lowered.contains("morning") { return .morning }
            if lowered.contains("中午") || lowered.contains("午餐") || lowered.contains("lunch") { return .midday }
            if lowered.contains("晚上") || lowered.contains("晚餐") || lowered.contains("夜宵") || lowered.contains("dinner") { return .evening }
            return fallback
        }

        func intensity(for tag: BehaviorTag) -> BehaviorIntensity {
            if tag == .overeating, lowered.contains("吃撑") || lowered.contains("撑") {
                return .high
            }
            if lowered.contains("两杯") || lowered.contains("2杯") || lowered.contains("中等") || lowered.contains("medium") {
                return .medium
            }
            if lowered.contains("一点") || lowered.contains("少量") || lowered.contains("一杯") || lowered.contains("1杯") {
                return .low
            }
            if lowered.contains("很多") || lowered.contains("大量") || lowered.contains("high") {
                return .high
            }
            switch tag {
            case .overeating: return .high
            case .alcohol: return .medium
            default: return .medium
            }
        }

        func add(_ tag: BehaviorTag, timing explicitTiming: BehaviorTiming? = nil) {
            signals[tag] = BehaviorSignal(
                id: "\(Int(createdAt.timeIntervalSince1970))-\(tag.rawValue)",
                tag: tag,
                intensity: intensity(for: tag),
                timing: explicitTiming ?? timing(default: .unknown),
                confidence: confidence,
                sourceNote: text,
                createdAt: createdAt
            )
        }

        func addLegacy(_ tag: BehaviorTag, timing explicitTiming: BehaviorTiming? = nil) {
            signals[tag] = BehaviorSignal(
                id: "\(Int(createdAt.timeIntervalSince1970))-\(tag.rawValue)",
                tag: tag,
                intensity: intensity(for: tag),
                timing: explicitTiming ?? timing(default: .unknown),
                confidence: confidence,
                sourceNote: text,
                createdAt: createdAt
            )
        }

        if lowered.contains("酒") || lowered.contains("啤酒") || lowered.contains("红酒") || lowered.contains("白酒") || lowered.contains("alcohol") || lowered.contains("beer") {
            addLegacy(.alcohol)
        }
        if lowered.contains("咖啡") || lowered.contains("拿铁") || lowered.contains("美式") || lowered.contains("caffeine") || lowered.contains("coffee") {
            addLegacy(.caffeine, timing: lowered.contains("睡前") ? .preSleep : nil)
        }
        if lowered.contains("夜宵") || lowered.contains("很晚") || lowered.contains("晚吃") || lowered.contains("late meal") {
            addLegacy(.lateMeal)
        }
        if lowered.contains("火锅") || lowered.contains("油炸") || lowered.contains("炸鸡") || lowered.contains("烧烤") || lowered.contains("高油") || lowered.contains("high fat") {
            addLegacy(.highFat)
        }
        if lowered.contains("火锅") || lowered.contains("烧烤") || lowered.contains("外卖") || lowered.contains("咸") || lowered.contains("高盐") || lowered.contains("high salt") {
            addLegacy(.highSalt)
        }
        if lowered.contains("甜") || lowered.contains("奶茶") || lowered.contains("蛋糕") || lowered.contains("高糖") || lowered.contains("sugar") {
            addLegacy(.highSugar)
        }
        if lowered.contains("吃撑") || lowered.contains("撑了") || lowered.contains("过饱") || lowered.contains("overeating") {
            addLegacy(.overeating)
        }
        if lowered.contains("没喝水") || lowered.contains("喝水少") || lowered.contains("缺水") || lowered.contains("low hydration") {
            addLegacy(.lowHydration)
        }
        if lowered.contains("辣") || lowered.contains("辛辣") || lowered.contains("spicy") {
            addLegacy(.spicy)
        }
        if lowered.contains("蛋白不足") || lowered.contains("没吃蛋白") || lowered.contains("low protein") {
            addLegacy(.lowProtein)
        }
        return signals.values.sorted { $0.tag.rawValue < $1.tag.rawValue }
    }

    static func extract(from entry: JournalEntryRecord) -> [BehaviorSignal] {
        var signals = extract(from: entry.note, createdAt: entry.createdAt)
        for tag in entry.tags {
            guard tag.hasPrefix("behavior:"),
                  let behavior = BehaviorTag(rawValue: String(tag.dropFirst("behavior:".count))) else {
                continue
            }
            if !signals.contains(where: { $0.tag == behavior }) {
                signals.append(BehaviorSignal(
                    id: "\(Int(entry.createdAt.timeIntervalSince1970))-\(behavior.rawValue)",
                    tag: behavior,
                    intensity: intensity(from: entry.tags),
                    timing: .unknown,
                    confidence: .userConfirmed,
                    sourceNote: entry.note,
                    createdAt: entry.createdAt
                ))
            }
        }
        return signals.sorted { $0.tag.rawValue < $1.tag.rawValue }
    }

    private static func intensity(from tags: [String]) -> BehaviorIntensity {
        if tags.contains("intensity:high") { return .high }
        if tags.contains("intensity:low") { return .low }
        return .medium
    }
}

enum BodyModelMaturityLevel: String, Codable, Hashable, CaseIterable {
    case seed
    case learning
    case stable
}

struct BodyModelMaturity: Codable, Hashable {
    var overall: BodyModelMaturityLevel
    var baselineDays: Int
    var behaviorPairs: Int
    var trainingSessions: Int
}

struct BodyModelClaim: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var confidence: DataConfidence
    var evidenceCount: Int
}

struct BodyModelUncertainArea: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var detail: String
}

struct BodyModelState: Codable, Hashable {
    var generatedAt: Date
    var maturity: BodyModelMaturity
    var claims: [BodyModelClaim]
    var uncertainAreas: [BodyModelUncertainArea]
    var behaviorSignals: [BehaviorSignal]
    var trainingPatternSummary: String
    var coachRules: [String]
}

struct BodyModelBuilder {
    func build(
        onboarding: OnboardingState?,
        dailySummaries: [DailyHealthSummaryRecord],
        journalEntries: [JournalEntryRecord],
        strengthWorkouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> BodyModelState {
        let baselineDays = Set(dailySummaries.map { calendar.startOfDay(for: $0.date) }).count
        let behaviorSignals = journalEntries.flatMap { BehaviorSignalExtractor.extract(from: $0) }
        let behaviorPairs = behaviorSignals.count
        let trainingSessions = strengthWorkouts.count
        let maturity = BodyModelMaturity(
            overall: maturityLevel(baselineDays: baselineDays, behaviorPairs: behaviorPairs, trainingSessions: trainingSessions),
            baselineDays: baselineDays,
            behaviorPairs: behaviorPairs,
            trainingSessions: trainingSessions
        )

        var claims: [BodyModelClaim] = []
        if let onboarding {
            claims.append(BodyModelClaim(
                id: "profile_seed",
                title: "目标与训练偏好已建立",
                summary: "目标 \(onboarding.goalProfile.primaryGoal)，训练风格 \(onboarding.trainingPreference.trainingStyle)，每周 \(onboarding.trainingPreference.weeklyTrainingDays) 次。",
                confidence: onboarding.isCompleted ? .medium : .low,
                evidenceCount: 1
            ))
        }
        if trainingSessions > 0 {
            let analysis = TrainingAnalyticsService().buildRecentSummary(workouts: strengthWorkouts, days: 28, endingAt: asOf)
            claims.append(BodyModelClaim(
                id: "training_facts",
                title: "训练事实正在积累",
                summary: "近 28 天 \(analysis.sessions) 次训练，\(analysis.effectiveSets) 个有效组；这些数据会先用于局部疲劳和训练后反应观察。",
                confidence: trainingSessions >= 6 ? .medium : .low,
                evidenceCount: trainingSessions
            ))
        }
        if behaviorPairs >= 6 {
            let grouped = Dictionary(grouping: behaviorSignals, by: \.tag)
            if let top = grouped.max(by: { $0.value.count < $1.value.count }) {
                claims.append(BodyModelClaim(
                    id: "behavior_pattern_\(top.key.rawValue)",
                    title: "行为信号样本开始可用",
                    summary: "\(top.key.displayTitle) 已记录 \(top.value.count) 次。下一步会和次日睡眠、HRV、RHR、恢复进行配对分析。",
                    confidence: .medium,
                    evidenceCount: top.value.count
                ))
            }
        }

        var uncertain: [BodyModelUncertainArea] = []
        if baselineDays < 7 {
            uncertain.append(BodyModelUncertainArea(
                id: "baseline_history",
                title: "个人基线仍在建立",
                detail: "需要至少 7 天健康摘要，才能把 HRV、RHR、睡眠和负荷判断从通用规则转向个人基线。"
            ))
        }
        if behaviorPairs < 6 {
            uncertain.append(BodyModelUncertainArea(
                id: "behavior_pairs",
                title: "行为-结果配对不足",
                detail: "饮食、咖啡因、饮酒、补水等行为至少需要约 6 次配对记录后才报告个人化影响。"
            ))
        }
        if trainingSessions < 3 || trainingResponses.count < 3 {
            uncertain.append(BodyModelUncertainArea(
                id: "training_response",
                title: "训练后反应样本不足",
                detail: "需要更多训练事实和次日恢复反馈，才能判断不同肌群/容量对你的恢复冲击。"
            ))
        }

        return BodyModelState(
            generatedAt: asOf,
            maturity: maturity,
            claims: claims,
            uncertainAreas: uncertain,
            behaviorSignals: behaviorSignals,
            trainingPatternSummary: trainingSummary(strengthWorkouts, asOf: asOf),
            coachRules: coachRules(for: maturity, uncertainAreas: uncertain)
        )
    }

    private func maturityLevel(baselineDays: Int, behaviorPairs: Int, trainingSessions: Int) -> BodyModelMaturityLevel {
        if baselineDays >= 28, behaviorPairs >= 12, trainingSessions >= 8 { return .stable }
        if baselineDays >= 7 || behaviorPairs >= 6 || trainingSessions >= 3 { return .learning }
        return .seed
    }

    private func trainingSummary(_ workouts: [StrengthWorkoutRecord], asOf: Date) -> String {
        guard !workouts.isEmpty else { return "尚无训练事实。训记或 Vela 训练记录同步后会开始学习训练反应。" }
        let summary = TrainingAnalyticsService().buildRecentSummary(workouts: workouts, days: 28, endingAt: asOf)
        return "近 28 天 \(summary.sessions) 次训练，\(summary.effectiveSets) 个有效组，容量 \(Int(summary.volumeKg.rounded())) kg。"
    }

    private func coachRules(for maturity: BodyModelMaturity, uncertainAreas: [BodyModelUncertainArea]) -> [String] {
        var rules = [
            "只把样本充足的模式描述为个人规律；样本不足时使用“正在学习”。",
            "训练建议必须同时展示证据、置信度和可替代行动。"
        ]
        if maturity.overall == .seed {
            rules.append("Body Model 处于种子期，Coach 默认采用保守训练建议。")
        }
        if uncertainAreas.contains(where: { $0.id == "behavior_pairs" }) {
            rules.append("行为影响暂不下结论，只收集低摩擦手记信号。")
        }
        return rules
    }
}

struct DailyPlanLimiter: Codable, Hashable, Identifiable {
    var id: String { kind.rawValue }
    var kind: LimiterKind
    var accent: DailyPlanAccent
    var title: String
    var detail: String
    var severity: Double

    enum LimiterKind: String, Codable {
        case recovery, sleep, strain, stress, energy, localFatigue, trainingResponse
        case hrv, restingHeartRate
    }
}

enum LocalDailyPlanLimiterEngine {
    static func detect(
        dashboard: DashboardSummary,
        bodyState: BodyState,
        trainingDecision: DailyTrainingDecision
    ) -> DailyPlanLimiter? {
        var candidates: [DailyPlanLimiter] = []

        if let local = bodyState.drivers.first(where: { $0.kind == .localFatigue }) {
            candidates.append(.init(
                kind: .localFatigue,
                accent: .strain,
                title: L10n.t("Local muscle fatigue", "局部肌群疲劳"),
                detail: L10n.t("\(local.title) fatigue", "\(local.title)疲劳偏高"),
                severity: 75
            ))
        }

        if dashboard.recovery.hasData, dashboard.recovery.score < 40 {
            candidates.append(.init(
                kind: .recovery,
                accent: .recovery,
                title: L10n.t("Recovery is low", "身体恢复不足"),
                detail: L10n.t("Recovery score \(Int(dashboard.recovery.score))", "恢复评分 \(Int(dashboard.recovery.score))"),
                severity: 100 - dashboard.recovery.score
            ))
        }

        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 50 {
            candidates.append(.init(
                kind: .sleep,
                accent: .sleep,
                title: L10n.t("Sleep is insufficient", "睡眠质量不佳"),
                detail: L10n.t("Sleep score \(Int(dashboard.sleepScore.score))", "睡眠评分 \(Int(dashboard.sleepScore.score))"),
                severity: 100 - dashboard.sleepScore.score
            ))
        }

        if dashboard.stress.hasData, dashboard.stress.stressIndex > 70 {
            candidates.append(.init(
                kind: .stress,
                accent: .stress,
                title: L10n.t("Stress load is high", "压力负荷偏高"),
                detail: L10n.t("Stress index \(Int(dashboard.stress.stressIndex))", "压力指数 \(Int(dashboard.stress.stressIndex))"),
                severity: dashboard.stress.stressIndex - 70
            ))
        }

        return candidates.max { $0.severity < $1.severity }
    }

    private static func bodyWithLimiter(_ body: String, limiter: DailyPlanLimiter?) -> String {
        guard let limiter else { return body }
        return L10n.t(
            "\(body) Main limiter: \(limiter.title).",
            "\(body) 主要限制因素：\(limiter.title)。"
        )
    }

    private static func coachQuestion(base: String, dashboard: DashboardSummary, limiter: DailyPlanLimiter?) -> String {
        let limiterText = limiter.map { "\($0.title) - \($0.detail)" } ?? L10n.t("none detected", "暂未识别")
        let snapshot = L10n.t(
            "Snapshot: Recovery \(Int(dashboard.recovery.score)), Sleep \(Int(dashboard.sleepScore.score)), Strain \(Int(dashboard.strain.score)), Energy \(Int(dashboard.energy.currentEnergy)), HRV \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "N/A"), RHR \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "N/A"), main limiter: \(limiterText).",
            "今日快照：恢复 \(Int(dashboard.recovery.score))，睡眠 \(Int(dashboard.sleepScore.score))，负荷 \(Int(dashboard.strain.score))，能量 \(Int(dashboard.energy.currentEnergy))，HRV \(dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))ms" } ?? "无")，静息心率 \(dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))bpm" } ?? "无")，主要限制因素：\(limiterText)。"
        )
        return "\(base)\n\n\(snapshot)"
    }
}

enum CoachSnapshotDirective {
    static func build(
        dashboard: DashboardSummary,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let plan = dashboard.trainingDecision
        let limiterText = plan.limiter.map { "\($0.title) - \($0.detail)" } ?? L10n.t("none detected", "暂未识别")
        let time = formattedTime(generatedAt, calendar: calendar)
        let hrv = dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0.rounded()))ms" } ?? "N/A"
        let rhr = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded()))bpm" } ?? "N/A"
        let targetRange = "\(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)"

        if AppLanguage.stored.isChinese {
            return """
            ## 当前健康快照协议（必须优先于旧对话）
            - 生成时间：\(time)
            - 恢复 \(Int(dashboard.recovery.score.rounded()))，睡眠 \(Int(dashboard.sleepScore.score.rounded()))，负荷 \(Int(dashboard.strain.score.rounded()))（目标 \(targetRange)），能量 \(Int(dashboard.energy.currentEnergy.rounded()))，压力 \(Int(dashboard.stress.stressIndex.rounded()))
            - HRV \(hrv)，静息心率 \(rhr)
            - 主要限制因素：\(limiterText)

            回答健康或训练问题时，必须以这份最新快照为准；如果历史聊天与它冲突，以这里的数据为准。输出结构保持为：判断 / 原因 / 今天怎么做 / 不要做什么 / 可追问。不要把旧对话里的过期分数当成当前状态。
            """
        }

        return """
        ## Current Health Snapshot Protocol (fresh data has priority over old chat)
        - Generated at: \(time)
        - Recovery \(Int(dashboard.recovery.score.rounded())), Sleep \(Int(dashboard.sleepScore.score.rounded())), Strain \(Int(dashboard.strain.score.rounded())) (target \(targetRange)), Energy \(Int(dashboard.energy.currentEnergy.rounded())), Stress \(Int(dashboard.stress.stressIndex.rounded()))
        - HRV \(hrv), resting heart rate \(rhr)
        - Main limiter: \(limiterText)

        For health or training questions, treat this snapshot as the source of truth. If prior chat history conflicts with it, use these values. Keep the answer structure: judgment / reason / what to do today / what to avoid / follow-up. Do not reuse stale scores from older conversation turns as current state.
        """
    }

    private static func formattedTime(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = AppLanguage.stored.isChinese ? Locale(identifier: "zh_CN") : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm XXX"
        return formatter.string(from: date)
    }
}
