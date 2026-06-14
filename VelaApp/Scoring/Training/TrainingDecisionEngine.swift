import Foundation

struct TrainingDecision: Codable, Hashable, Sendable {
    var kind: DailyPlanKind
    var accent: DailyPlanAccent
    var title: String
    var body: String
    var primaryActionTitle: String
    var secondaryActionTitle: String?
    var coachQuestion: String
    var limiter: DailyPlanLimiter?
    
    // Core Metrics v1.3 / Limiter Integration
    var readinessLevel: String // "HIGH", "MODERATE", "LOW"
    var readinessGuidance: String
    var limiters: [PlanLimiter]
    var trainingLoadConfidence: DataConfidence
    var atl: Double?
    var ctl: Double?
    var tsb: Double?
    var volumeMultiplier: Double
    var maxIntensity: String
    var recommendedTrainingType: String
    var whyThis: String
}

extension TrainingDecision {
    static func compatibilityView(
        of decision: DailyTrainingDecision,
        bodyState: BodyState
    ) -> TrainingDecision {
        let presentation: (
            kind: DailyPlanKind,
            accent: DailyPlanAccent,
            title: String,
            primaryActionTitle: String
        )

        switch decision.decision {
        case .keep:
            presentation = (.train, .strain, "Keep planned session", "Start planned session")
        case .reduce:
            presentation = (.maintain, .energy, "Reduce planned session", "Start reduced session")
        case .swap:
            presentation = (.downshift, .stress, "Swap planned session", "Choose an easier session")
        case .rest:
            presentation = (.rest, .recovery, "Prioritize recovery", "Start recovery")
        }

        let readinessLevel: String
        switch bodyState.readiness {
        case .ready:
            readinessLevel = "HIGH"
        case .caution, .unknown:
            readinessLevel = "MODERATE"
        case .recovering:
            readinessLevel = "LOW"
        }

        let whyThis = decision.reasons.joined(separator: " ")

        return TrainingDecision(
            kind: presentation.kind,
            accent: presentation.accent,
            title: presentation.title,
            body: decision.userFacingSummary,
            primaryActionTitle: presentation.primaryActionTitle,
            secondaryActionTitle: nil,
            coachQuestion: whyThis.isEmpty
                ? decision.userFacingSummary
                : "\(whyThis) \(decision.userFacingSummary)",
            limiter: nil,
            readinessLevel: readinessLevel,
            readinessGuidance: decision.userFacingSummary,
            limiters: [],
            trainingLoadConfidence: bodyState.confidence,
            atl: nil,
            ctl: nil,
            tsb: nil,
            volumeMultiplier: decision.volumeMultiplier,
            maxIntensity: "RPE \(decision.intensityCap)",
            recommendedTrainingType: decision.targetSessionTitle ?? decision.decision.rawValue,
            whyThis: whyThis
        )
    }
}

enum TrainingDecisionEngine {
    
    static func evaluate(
        _ dashboard: DashboardSummary,
        journalFlags: Set<String> = [],
        activePlan: TrainingPlanRecord? = nil,
        history: [DailyHealthSnapshot] = [],
        strengthWorkouts: [StrengthWorkoutRecord] = []
    ) -> TrainingDecision {
        // 1. Determine training load confidence & values
        // If history is insufficient (less than 7 records), training load metrics are low/unavailable
        let hasEnoughHistory = history.count >= 7
        let trainingLoadConfidence: DataConfidence = hasEnoughHistory ? .high : .unavailable
        
        let atl: Double? = hasEnoughHistory ? (dashboard.energy.metrics["atl"] ?? dashboard.strain.score) : nil
        let ctl: Double? = hasEnoughHistory ? (dashboard.energy.metrics["ctl"] ?? dashboard.strain.score) : nil
        let tsb: Double? = hasEnoughHistory ? (dashboard.energy.metrics["tsb"] ?? 0.0) : nil
        
        // 2. Call DailyPlanLimiterEngine to evaluate limiters
        let limiterInput = DailyPlanLimiterInput(
            sleepScore: dashboard.sleepScore.score,
            totalSleepMinutes: Double(dashboard.sleepSummary.totalSleepMinutes),
            recoveryScore: dashboard.recovery.score,
            strainScore: dashboard.strain.score,
            stressIndex: dashboard.stress.stressIndex,
            energyScore: dashboard.energy.currentEnergy,
            trainingLoadStatus: hasEnoughHistory ? (dashboard.strain.trainingLoadStatus) : .optimal, // Inhibits training load limiter when history is insufficient
            journalFlags: journalFlags,
            bodyTempDelta: dashboard.extendedMetrics.bodyTemperature.map { $0 - 36.5 } ?? 0.0,
            hrvZ: dashboard.recovery.metrics["hrv_z_score"] ?? 0.0,
            rhrZ: dashboard.recovery.metrics["rhr_z_score"] ?? 0.0
        )
        
        let limiterResult = DailyPlanLimiterEngine().calculate(input: limiterInput)
        let localFatigue = TrainingAnalyticsService().computeLocalFatigue(workouts: strengthWorkouts)
        let adaptation = RecoveryTrainingAdapter().adapt(input: RecoveryTrainingInput(
            recoveryScore: dashboard.recovery.score,
            sleepScore: dashboard.sleepScore.score,
            hrvZScore: dashboard.recovery.metrics["hrv_z_score"],
            restingHRZScore: dashboard.recovery.metrics["rhr_z_score"],
            tsb: tsb,
            energyScore: dashboard.energy.currentEnergy,
            localFatigue: localFatigue
        ))
        
        // 3. Fallback/Integrate with DailyPlanEngine.recommendation logic
        let legacyLimiter = mainLimiter(for: dashboard)
        
        // Let's determine the decision components:
        let kind: DailyPlanKind
        let accent: DailyPlanAccent
        let title: String
        let body: String
        let primaryActionTitle: String
        let secondaryActionTitle: String?
        let coachQuestion: String
        
        if !journalFlags.isDisjoint(with: ["sick", "injured"]) {
            kind = .rest
            accent = .recovery
            title = L10n.t("Make today a rest day", "今天安排休息")
            body = L10n.t(
                "Your journal reports illness or injury. Skip training and focus on recovery. Seek medical advice if symptoms are significant or persistent.",
                "你的日志记录了生病或受伤。今天停止训练，专注恢复。如果症状明显或持续，请咨询医生。"
            )
            primaryActionTitle = L10n.t("Plan a rest day", "规划休息日")
            secondaryActionTitle = nil
            coachQuestion = L10n.t(
                "Build a rest-day recovery plan for me. My journal reports illness or injury, so do not prescribe training.",
                "请为我制定休息日恢复计划。我的日志记录了生病或受伤，因此不要安排训练。"
            )
        } else if journalFlags.contains("resting") {
            kind = .rest
            accent = .recovery
            title = L10n.t("Keep today as a rest day", "今天保持休息")
            body = L10n.t(
                "You marked today as a rest period. Skip planned training and focus on recovery habits.",
                "你已将今天标记为休息期。暂停计划训练，优先安排恢复习惯。"
            )
            primaryActionTitle = L10n.t("Plan a rest day", "规划休息日")
            secondaryActionTitle = nil
            coachQuestion = L10n.t(
                "Build a rest-day recovery plan for me. I marked today as a rest period, so do not prescribe training.",
                "请为我制定休息日恢复计划。我已将今天标记为休息期，因此不要安排训练。"
            )
        } else if !dashboard.recovery.hasData {
            kind = .maintain
            accent = .energy
            title = L10n.t("Connect your baseline", "先建立你的基线")
            body = L10n.t(
                "Vela needs Apple Health recovery data before it can make a confident daily plan.",
                "Vela 需要 Apple 健康的恢复数据，才能给出可信的今日计划。"
            )
            primaryActionTitle = L10n.t("Ask what to set up", "询问如何设置")
            secondaryActionTitle = nil
            coachQuestion = L10n.t(
                "Tell me what health permissions and data I need to enable so Vela can generate a reliable daily plan.",
                "请告诉我需要开启哪些健康权限和数据，才能让 Vela 生成可靠的今日计划。"
            )
        } else if dashboard.recovery.score < 40 {
            kind = .recovery
            accent = .recovery
            title = L10n.t("Make today a recovery day", "今天按恢复日处理")
            body = bodyWithLimiter(
                L10n.t(
                    "Recovery is low. Keep training very light and spend your effort on sleep, food, hydration, and lowering physiological stress.",
                    "恢复偏低。训练保持很轻，把精力放在睡眠、饮食、补水和降低生理压力上。"
                ),
                limiter: legacyLimiter
            )
            primaryActionTitle = L10n.t("Plan recovery day", "规划恢复日")
            secondaryActionTitle = L10n.t("Check limiting factor", "查看限制因素")
            coachQuestion = Self.coachQuestion(
                base: L10n.t(
                    "Build a recovery day plan for me based on today's recovery, sleep, strain, stress, and energy. Be specific and tell me what training to avoid.",
                    "请基于今天的恢复、睡眠、负荷、压力和能量，为我制定一个恢复日计划。要具体，并告诉我哪些训练应该避免。"
                ),
                dashboard: dashboard,
                limiter: legacyLimiter
            )
        } else if dashboard.recovery.score >= 70 && dashboard.strain.score < Double(dashboard.strain.recommendedRange.lowerBound) {
            kind = .train
            accent = .strain
            title = L10n.t("Training window is open", "今天有训练窗口")
            body = bodyWithLimiter(
                L10n.t(
                    "Recovery is strong and current strain is still below target. This is a good window to add a controlled training stimulus.",
                    "恢复较好，而且当前负荷还低于目标区间。今天适合加入一次可控训练刺激。"
                ),
                limiter: legacyLimiter
            )
            primaryActionTitle = L10n.t("Build today's session", "生成今日训练")
            secondaryActionTitle = L10n.t("Set target strain", "设定目标负荷")
            coachQuestion = Self.coachQuestion(
                base: L10n.t(
                    "Use my recovery, strain target range, energy, stress, sleep, and training history to create today's training session. Include warm-up, main work, intensity, and when to stop.",
                    "请基于我的恢复、负荷目标区间、能量、压力、睡眠和训练历史，生成今天的训练内容。包括热身、主训练、强度和停止条件。"
                ),
                dashboard: dashboard,
                limiter: legacyLimiter
            )
        } else {
            kind = .maintain
            accent = .energy
            title = L10n.t("Keep the day controlled", "今天保持可控")
            body = bodyWithLimiter(
                L10n.t(
                    "Your signals are mixed. Keep the day steady: avoid chasing a high strain score and protect tonight's sleep.",
                    "今天信号比较混合。保持节奏稳定：不要强行追高负荷，优先保护今晚睡眠。"
                ),
                limiter: legacyLimiter
            )
            primaryActionTitle = L10n.t("Get today's plan", "获取今日计划")
            secondaryActionTitle = L10n.t("Review signals", "复盘关键指标")
            coachQuestion = Self.coachQuestion(
                base: L10n.t(
                    "Give me a controlled daily plan based on today's recovery, sleep, strain, stress, and energy. Start with what I should do, then what I should avoid.",
                    "请基于今天的恢复、睡眠、负荷、压力和能量，给我一个可控的今日计划。先说我应该做什么，再说应该避免什么。"
                ),
                dashboard: dashboard,
                limiter: legacyLimiter
            )
        }
        
        // 4. Compute readiness level and guidance (unified from both)
        let readinessLevel: String
        let readinessGuidance: String
        if !journalFlags.isDisjoint(with: ["sick", "injured", "resting"]) || dashboard.recovery.score < 40 {
            readinessLevel = "LOW"
            readinessGuidance = L10n.t("Prioritize recovery. Recommend rest or light mobility work only.", "今日建议以恢复为主。推荐休息或安排极轻量活动。")
        } else if dashboard.recovery.score > 75 && dashboard.energy.currentEnergy > 60 && (tsb ?? 0.0) > 5.0 {
            readinessLevel = "HIGH"
            readinessGuidance = L10n.t("Body is primed for intense training. Push hard — this is an optimal biological window for progression.", "身体状态极佳，适合进行高强度训练。今天是个极好的突破窗口。")
        } else {
            readinessLevel = "MODERATE"
            readinessGuidance = L10n.t("Train at controlled intensity. Moderate load or active recovery is appropriate.", "训练请保持适度。中等强度负荷或主动恢复是最佳选择。")
        }
        
        return TrainingDecision(
            kind: kind,
            accent: accent,
            title: title,
            body: body,
            primaryActionTitle: primaryActionTitle,
            secondaryActionTitle: secondaryActionTitle,
            coachQuestion: coachQuestion,
            limiter: legacyLimiter,
            readinessLevel: readinessLevel,
            readinessGuidance: readinessGuidance,
            limiters: limiterResult.limiters,
            trainingLoadConfidence: trainingLoadConfidence,
            atl: atl,
            ctl: ctl,
            tsb: tsb,
            volumeMultiplier: min(limiterResult.volumeMultiplier, adaptation.volumeMultiplier),
            maxIntensity: stricterIntensity(limiterResult.maxIntensity, adaptation.recommendedIntensity),
            recommendedTrainingType: adaptation.suggestedFocus,
            whyThis: [limiterResult.whyThis, adaptation.modifiedWorkoutDescription]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        )
    }

    private static func stricterIntensity(_ lhs: String, _ rhs: String) -> String {
        let rank = ["rest": 0, "low": 1, "moderate": 2, "high": 3]
        return (rank[lhs.lowercased()] ?? 2) <= (rank[rhs.lowercased()] ?? 2) ? lhs : rhs
    }
    
    private static func mainLimiter(for dashboard: DashboardSummary) -> DailyPlanLimiter? {
        var candidates: [DailyPlanLimiter] = []
        
        if let hrvScore = dashboard.recovery.components["hrv"], hrvScore < 50 {
            let z = dashboard.recovery.metrics["hrv_z_score"].map { String(format: "%.1f", $0) }
            candidates.append(.init(
                kind: .hrv,
                accent: .recovery,
                title: L10n.t("HRV is the limiter", "HRV 是主要限制因素"),
                detail: z.map { L10n.t("HRV z-score \($0)", "HRV z 值 \($0)") } ?? L10n.t("Autonomic recovery is below baseline", "自主神经恢复低于基线"),
                severity: 100 - hrvScore
            ))
        }

        if let rhrScore = dashboard.recovery.components["rhr"], rhrScore < 50 {
            let today = dashboard.recoveryMetrics.restingHeartRate
            let baseline = dashboard.recoveryBaseline.restingHeartRate
            let detail: String
            if let today, let baseline {
                detail = L10n.t("RHR \(Int(today))bpm vs \(Int(baseline))bpm baseline", "静息心率 \(Int(today))bpm，基线 \(Int(baseline))bpm")
            } else {
                detail = L10n.t("Resting heart rate is above baseline", "静息心率高于基线")
            }
            candidates.append(.init(
                kind: .restingHeartRate,
                accent: .recovery,
                title: L10n.t("Resting HR is elevated", "静息心率偏高"),
                detail: detail,
                severity: 100 - rhrScore
            ))
        }

        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 70 {
            candidates.append(.init(
                kind: .sleep,
                accent: .sleep,
                title: L10n.t("Sleep is limiting recovery", "睡眠限制恢复"),
                detail: dashboard.sleepScore.reasons.first.map(localizedReason) ?? L10n.t("Sleep score is below target", "睡眠评分低于目标"),
                severity: 70 - dashboard.sleepScore.score
            ))
        }

        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            candidates.append(.init(
                kind: .strain,
                accent: .strain,
                title: L10n.t("Strain is above target", "负荷高于目标"),
                detail: L10n.t("Current strain \(Int(dashboard.strain.score)) vs target \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)", "当前负荷 \(Int(dashboard.strain.score))，目标 \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)"),
                severity: dashboard.strain.score - Double(dashboard.strain.recommendedRange.upperBound)
            ))
        }

        if dashboard.energy.hasData, dashboard.energy.currentEnergy < 35 {
            candidates.append(.init(
                kind: .energy,
                accent: .energy,
                title: L10n.t("Energy reserve is low", "能量储备偏低"),
                detail: L10n.t("Current energy \(Int(dashboard.energy.currentEnergy))", "当前能量 \(Int(dashboard.energy.currentEnergy))"),
                severity: 35 - dashboard.energy.currentEnergy
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
    
    private static func localizedReason(_ reason: String) -> String {
        if reason.contains("Sleep efficiency") {
            return L10n.t("Sleep efficiency is low", "睡眠效率偏低")
        }
        if reason.contains("Consistency") {
            return L10n.t("Sleep bedtime is inconsistent", "入睡时间不规律")
        }
        if reason.contains("Short") {
            return L10n.t("Sleep duration is short", "睡眠时长不足")
        }
        return reason
    }
}
