import Foundation

struct DashboardSummary: Hashable, @unchecked Sendable {
    var date: Date
    var sleepSummary: SleepSummary
    var sleepScore: MetricResult
    var recovery: MetricResult
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strain: MetricResult
    var stress: MetricResult
    var energy: MetricResult
    var healthAge: HealthAgeTrendResult
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics
    var workouts: [WorkoutSummary]
    var dailyInsight: String
    var source: DataSource
    
    private var _trainingDecision: TrainingDecision?
    var trainingDecision: TrainingDecision {
        get {
            if let _trainingDecision { return _trainingDecision }
            return TrainingDecisionEngine.evaluate(self)
        }
        set {
            _trainingDecision = newValue
        }
    }
    
    init(
        date: Date,
        sleepSummary: SleepSummary,
        sleepScore: MetricResult,
        recovery: MetricResult,
        recoveryMetrics: RecoveryMetricSummary,
        recoveryBaseline: RecoveryMetricSummary,
        strain: MetricResult,
        stress: MetricResult,
        energy: MetricResult,
        healthAge: HealthAgeTrendResult,
        bodyMetrics: BodyMetricsSummary,
        extendedMetrics: ExtendedHealthMetrics,
        workouts: [WorkoutSummary],
        dailyInsight: String,
        source: DataSource
    ) {
        self.date = date
        self.sleepSummary = sleepSummary
        self.sleepScore = sleepScore
        self.recovery = recovery
        self.recoveryMetrics = recoveryMetrics
        self.recoveryBaseline = recoveryBaseline
        self.strain = strain
        self.stress = stress
        self.energy = energy
        self.healthAge = healthAge
        self.bodyMetrics = bodyMetrics
        self.extendedMetrics = extendedMetrics
        self.workouts = workouts
        self.dailyInsight = dailyInsight
        self.source = source
        self._trainingDecision = nil
    }

    enum DataSource: String, Hashable {
        case healthKit = "HealthKit"
        case cache = "Cached HealthKit"
        case empty = "Empty"
        case preview = "Preview"
    }

    static func preview(date: Date = Date()) -> DashboardSummary {
        PreviewDataFactory.makeDashboard(date: date)
    }

    static func empty(date: Date = Date()) -> DashboardSummary {
        func emptyMetric(name: String, reason: String) -> MetricResult {
            MetricResult(
                name: name,
                value: nil,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: [reason],
                missingInputs: ["healthData"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            )
        }

        return DashboardSummary(
            date: date,
            sleepSummary: SleepSummary(
                date: date,
                totalSleepMinutes: 0,
                bedtime: nil,
                wakeTime: nil,
                stageMinutes: [:],
                segments: [],
                sleepScore: nil
            ),
            sleepScore: MetricResult(
                name: "Sleep Score",
                value: 0,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: ["Sleep data unavailable."],
                missingInputs: ["sleepSummary"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            ),
            recovery: MetricResult(
                name: "Recovery Score",
                value: 0,
                band: .low,
                confidence: .low,
                components: [:],
                componentWeights: [:],
                reasons: ["Recovery data unavailable."],
                missingInputs: ["recoveryMetrics"],
                dataWindow: DateInterval(start: date, duration: 86400),
                source: .derived,
                algorithmVersion: "1.0.0",
                lastUpdated: date
            ),
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: nil,
                restingHeartRate: nil,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: nil,
                restingHeartRate: nil,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            strain: emptyMetric(name: "Strain Score", reason: "Strain data unavailable."),
            stress: emptyMetric(name: "Physiological Stress Index", reason: "Stress data unavailable."),
            energy: emptyMetric(name: "Energy Bank", reason: "Energy data unavailable."),
            healthAge: HealthAgeTrendEngine().calculate(from: HealthAgeTrendInput(factors: [])),
            bodyMetrics: BodyMetricsSummary(
                vo2Max: nil,
                weightKilograms: nil,
                bodyFatPercentage: nil,
                leanBodyMassKilograms: nil
            ),
            extendedMetrics: ExtendedHealthMetrics.empty,
            workouts: [],
            dailyInsight: "",
            source: .empty
        )
    }
}

private extension ExtendedHealthMetrics {
    static let empty = ExtendedHealthMetrics(
        age: nil, biologicalSex: nil, heightCm: nil, bmi: nil,
        walkingHeartRateAvg: nil, oxygenSaturation: nil,
        bloodPressureSystolic: nil, bloodPressureDiastolic: nil,
        bloodGlucose: nil,
        walkingSpeed: nil, walkingStepLength: nil, walkingAsymmetry: nil,
        walkingDoubleSupport: nil, walkingSteadiness: nil,
        stairAscentSpeed: nil, stairDescentSpeed: nil, sixMinuteWalkDistance: nil,
        exerciseMinutes: nil, standMinutes: nil, flightsClimbed: nil,
        distanceKm: nil, cyclingDistanceKm: nil,
        environmentalNoisedB: nil, headphoneNoisedB: nil, timeInDaylight: nil,
        bodyTemperature: nil,
        waterMl: nil, caffeineMg: nil, dietaryEnergyKcal: nil,
        dietaryProteinG: nil, dietaryCarbsG: nil, dietaryFatG: nil,
        mindfulMinutes: nil, sleepBreathingDisturbances: nil
    )
}

enum ReadinessDecisionKind: String, Codable, Hashable, CaseIterable {
    case keep
    case reduce
    case swap
    case recover
}

struct TodayHealthSignal: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var value: String
    var baseline: String?
    var interpretation: String
    var source: HealthDataSource
    var confidence: DataConfidence
    var metricKey: String
}

struct TodayAction: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, Hashable, CaseIterable {
        case training
        case recovery
        case checkIn
        case coach
        case insight
    }

    var id: String
    var kind: Kind
    var title: String
    var detail: String
    var destination: String
    var isPrimary: Bool
}

struct ReadinessDecision: Codable, Hashable {
    var decision: ReadinessDecisionKind
    var confidence: Double
    var reasons: [String]
    var supportingSignals: [TodayHealthSignal]
    var suggestedActions: [TodayAction]
    var userOverrideAvailable: Bool

    var displayTitle: String {
        switch decision {
        case .keep: return "按计划训练"
        case .reduce: return "降低容量"
        case .swap: return "替换训练"
        case .recover: return "恢复优先"
        }
    }
}

struct TodayCommandState: Codable, Hashable {
    var date: Date
    var bodyStateTitle: String
    var summary: String
    var readinessDecision: ReadinessDecision
    var keySignals: [TodayHealthSignal]
    var actions: [TodayAction]
    var coachArtifact: CoachArtifact?
    var dataConfidence: DataConfidence
}

enum TodayCommandBuilder {
    static func build(
        from dashboard: DashboardSummary,
        recentStrengthSummary: RecentTrainingSummary? = nil,
        coachArtifact: CoachArtifact? = nil,
        generatedAt: Date = Date()
    ) -> TodayCommandState {
        let signals = keySignals(from: dashboard, recentStrengthSummary: recentStrengthSummary)
        let decision = readinessDecision(from: dashboard, signals: signals, recentStrengthSummary: recentStrengthSummary)
        let actions = actions(for: decision.decision, dashboard: dashboard)
        let artifact = coachArtifact ?? localMorningBrief(from: dashboard, decision: decision, generatedAt: generatedAt)
        let confidence = aggregateConfidence(dashboard: dashboard, signals: signals)

        return TodayCommandState(
            date: dashboard.date,
            bodyStateTitle: title(for: decision.decision, dashboard: dashboard),
            summary: summary(for: decision.decision, dashboard: dashboard),
            readinessDecision: ReadinessDecision(
                decision: decision.decision,
                confidence: decision.confidence,
                reasons: decision.reasons,
                supportingSignals: signals,
                suggestedActions: actions,
                userOverrideAvailable: true
            ),
            keySignals: Array(signals.prefix(5)),
            actions: actions,
            coachArtifact: artifact,
            dataConfidence: confidence
        )
    }

    private static func readinessDecision(
        from dashboard: DashboardSummary,
        signals: [TodayHealthSignal],
        recentStrengthSummary: RecentTrainingSummary?
    ) -> (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]) {
        var reasons: [String] = []
        if !dashboard.recovery.hasData {
            return (.reduce, 0.32, ["恢复基线数据不足，先按保守方案执行。"])
        }

        if let first = dashboard.recovery.reasons.first {
            reasons.append(first)
        }
        if dashboard.recovery.score < 40 {
            reasons.append("Recovery \(Int(dashboard.recovery.score.rounded())) is below the recovery-day threshold.")
            return (.recover, 0.86, reasons)
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < 55 {
            reasons.append("Sleep score \(Int(dashboard.sleepScore.score.rounded())) is limiting readiness.")
            return (.recover, 0.78, reasons)
        }
        if dashboard.stress.hasData, dashboard.stress.stressIndex > 78 {
            reasons.append("Physiological stress is elevated.")
            return (.recover, 0.74, reasons)
        }
        if let summary = recentStrengthSummary,
           summary.localFatigue.values.contains(where: { $0.setsLast48h >= 10 || $0.setsLast7d >= 18 }) {
            reasons.append("Local muscle fatigue is high from recent strength work.")
            return (.swap, 0.72, reasons)
        }
        if dashboard.recovery.score < 62 || dashboard.sleepScore.score < 68 {
            reasons.append("Recovery or sleep is not low enough for rest, but not strong enough for full volume.")
            return (.reduce, 0.68, reasons)
        }
        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            reasons.append("Current strain is already above today's target range.")
            return (.reduce, 0.7, reasons)
        }

        if reasons.isEmpty {
            reasons.append("Recovery, sleep, and strain are within an actionable range.")
        }
        return (.keep, 0.76, reasons)
    }

    private static func keySignals(
        from dashboard: DashboardSummary,
        recentStrengthSummary: RecentTrainingSummary?
    ) -> [TodayHealthSignal] {
        var signals: [TodayHealthSignal] = []
        signals.append(TodayHealthSignal(
            id: "recovery",
            title: "Recovery",
            value: dashboard.recovery.hasData ? "\(Int(dashboard.recovery.score.rounded()))" : "--",
            baseline: nil,
            interpretation: dashboard.recovery.reasons.first ?? "恢复数据仍在建立基线。",
            source: .computed,
            confidence: confidence(from: dashboard.recovery.confidence),
            metricKey: "recovery"
        ))
        signals.append(TodayHealthSignal(
            id: "sleep",
            title: "Sleep",
            value: dashboard.sleepScore.hasData ? "\(Int(dashboard.sleepScore.score.rounded()))" : "--",
            baseline: dashboard.sleepSummary.totalSleepMinutes > 0 ? "\(dashboard.sleepSummary.totalSleepMinutes) min" : nil,
            interpretation: dashboard.sleepScore.reasons.first ?? "睡眠数据不足。",
            source: .computed,
            confidence: confidence(from: dashboard.sleepScore.confidence),
            metricKey: "sleep"
        ))
        let hrvValue = dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0.rounded())) ms" } ?? "--"
        let hrvBaseline = dashboard.recoveryBaseline.hrvMilliseconds.map { "\(Int($0.rounded())) ms baseline" }
        signals.append(TodayHealthSignal(
            id: "hrv",
            title: "HRV vs baseline",
            value: hrvValue,
            baseline: hrvBaseline,
            interpretation: hrvInterpretation(dashboard),
            source: .healthKit,
            confidence: dashboard.recoveryMetrics.hrvMilliseconds == nil ? .unavailable : .high,
            metricKey: "recovery"
        ))
        let rhrValue = dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0.rounded())) bpm" } ?? "--"
        let rhrBaseline = dashboard.recoveryBaseline.restingHeartRate.map { "\(Int($0.rounded())) bpm baseline" }
        signals.append(TodayHealthSignal(
            id: "rhr",
            title: "Resting HR",
            value: rhrValue,
            baseline: rhrBaseline,
            interpretation: rhrInterpretation(dashboard),
            source: .healthKit,
            confidence: dashboard.recoveryMetrics.restingHeartRate == nil ? .unavailable : .high,
            metricKey: "recovery"
        ))
        signals.append(TodayHealthSignal(
            id: "strain",
            title: "Training load",
            value: dashboard.strain.hasData ? "\(Int(dashboard.strain.score.rounded()))" : "--",
            baseline: "target \(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)",
            interpretation: dashboard.strain.reasons.first ?? "负荷数据不足。",
            source: .computed,
            confidence: confidence(from: dashboard.strain.confidence),
            metricKey: "strain"
        ))
        if let summary = recentStrengthSummary, !summary.muscleGroupSets.isEmpty {
            let top = summary.muscleGroupSets.sorted { $0.value > $1.value }.first
            signals.append(TodayHealthSignal(
                id: "local_fatigue",
                title: "Local fatigue",
                value: top.map { "\($0.key) \($0.value) sets" } ?? "--",
                baseline: "7d effective sets",
                interpretation: "近期肌群组数会影响今天是否换部位或减量。",
                source: .computed,
                confidence: .medium,
                metricKey: "training"
            ))
        }
        return signals
    }

    private static func actions(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> [TodayAction] {
        switch decision {
        case .keep:
            return [
                TodayAction(id: "start_training", kind: .training, title: "开始今日训练", detail: "按计划执行，训练中保留 1-2 次余力。", destination: "training", isPrimary: true),
                TodayAction(id: "why_this", kind: .insight, title: "查看证据", detail: "打开 HRV、睡眠、负荷和恢复解释。", destination: "evidence", isPrimary: false)
            ]
        case .reduce:
            return [
                TodayAction(id: "reduce_volume", kind: .training, title: "训练容量降低 20%", detail: "保留动作模式，减少组数或 RPE。", destination: "training", isPrimary: true),
                TodayAction(id: "check_in", kind: .checkIn, title: "记录疲劳/酸痛", detail: "把主观反馈写入今天的上下文。", destination: "journal", isPrimary: false)
            ]
        case .swap:
            return [
                TodayAction(id: "swap_workout", kind: .training, title: "替换训练部位", detail: "避开高疲劳肌群，改做低冲击训练。", destination: "training", isPrimary: true),
                TodayAction(id: "ask_coach_swap", kind: .coach, title: "让 Coach 改计划", detail: dashboard.trainingDecision.coachQuestion, destination: "coach", isPrimary: false)
            ]
        case .recover:
            return [
                TodayAction(id: "recovery_plan", kind: .recovery, title: "执行恢复日", detail: "轻量活动、补水、晚间提前睡眠。", destination: "recovery", isPrimary: true),
                TodayAction(id: "why_this", kind: .insight, title: "为什么这样安排", detail: "查看 HRV、RHR、睡眠和压力证据。", destination: "evidence", isPrimary: false)
            ]
        }
    }

    private static func localMorningBrief(
        from dashboard: DashboardSummary,
        decision: (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]),
        generatedAt: Date
    ) -> CoachArtifact {
        CoachArtifact(
            type: .morningBrief,
            title: "今日身体简报",
            summary: summary(for: decision.decision, dashboard: dashboard),
            createdAt: generatedAt,
            relatedDate: dashboard.date,
            decision: decision.decision.rawValue,
            confidence: decision.confidence,
            reasons: decision.reasons.prefix(3).map {
                CoachArtifactReason(signal: "readiness", value: decision.decision.rawValue, explanation: $0)
            },
            actions: actions(for: decision.decision, dashboard: dashboard).map {
                CoachArtifactAction(type: $0.destination, label: $0.title, payload: ["action_id": $0.id])
            },
            sourceContextHash: ContentHash.hash("\(dashboard.date.timeIntervalSince1970)-\(dashboard.recovery.score)-\(dashboard.sleepScore.score)-\(dashboard.strain.score)")
        )
    }

    private static func title(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> String {
        switch decision {
        case .keep: return "状态可训练"
        case .reduce: return "可训练，但建议减量"
        case .swap: return "建议换训练内容"
        case .recover: return "恢复优先"
        }
    }

    private static func summary(for decision: ReadinessDecisionKind, dashboard: DashboardSummary) -> String {
        let recovery = Int(dashboard.recovery.score.rounded())
        let sleep = Int(dashboard.sleepScore.score.rounded())
        let strain = Int(dashboard.strain.score.rounded())
        switch decision {
        case .keep:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天可以按计划训练，保持技术质量。"
        case .reduce:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天不需要完全休息，但应降低容量或强度。"
        case .swap:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。近期局部疲劳偏高，建议替换训练内容。"
        case .recover:
            return "恢复 \(recovery)、睡眠 \(sleep)、负荷 \(strain)。今天优先恢复，避免高强度训练。"
        }
    }

    private static func hrvInterpretation(_ dashboard: DashboardSummary) -> String {
        guard let hrv = dashboard.recoveryMetrics.hrvMilliseconds,
              let baseline = dashboard.recoveryBaseline.hrvMilliseconds,
              baseline > 0 else {
            return "HRV 基线仍在建立。"
        }
        let delta = (hrv - baseline) / baseline
        if delta < -0.10 { return "HRV 低于个人基线，提示自主神经恢复压力偏高。" }
        if delta > 0.10 { return "HRV 高于个人基线，恢复信号较积极。" }
        return "HRV 接近个人基线。"
    }

    private static func rhrInterpretation(_ dashboard: DashboardSummary) -> String {
        guard let rhr = dashboard.recoveryMetrics.restingHeartRate,
              let baseline = dashboard.recoveryBaseline.restingHeartRate else {
            return "静息心率基线仍在建立。"
        }
        if rhr >= baseline + 4 { return "静息心率高于基线，可能存在恢复压力。" }
        if rhr <= baseline - 3 { return "静息心率低于基线，恢复信号较好。" }
        return "静息心率接近基线。"
    }

    private static func aggregateConfidence(dashboard: DashboardSummary, signals: [TodayHealthSignal]) -> DataConfidence {
        if !dashboard.recovery.hasData { return .unavailable }
        if signals.contains(where: { $0.confidence == .unavailable }) { return .medium }
        if [dashboard.recovery.confidence, dashboard.sleepScore.confidence, dashboard.strain.confidence].contains(.low) {
            return .low
        }
        if [dashboard.recovery.confidence, dashboard.sleepScore.confidence, dashboard.strain.confidence].contains(.medium) {
            return .medium
        }
        return .high
    }

    private static func confidence(from metricConfidence: MetricConfidence) -> DataConfidence {
        switch metricConfidence {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}

enum DailyPlanKind: String, Codable, Hashable {
    case rest
    case recovery
    case train
    case maintain
    case protectSleep
    case downshift
}

enum DailyPlanAccent: String, Codable, Hashable {
    case recovery
    case sleep
    case strain
    case energy
    case stress
}

enum DailyPlanLimiterKind: String, Codable, Hashable {
    case hrv
    case restingHeartRate
    case sleep
    case strain
    case energy
    case stress
}

struct DailyPlanLimiter: Codable, Hashable {
    var kind: DailyPlanLimiterKind
    var accent: DailyPlanAccent
    var title: String
    var detail: String
    var severity: Double
}

struct DailyPlanRecommendation: Codable, Hashable {
    var kind: DailyPlanKind
    var accent: DailyPlanAccent
    var title: String
    var body: String
    var primaryActionTitle: String
    var secondaryActionTitle: String?
    var coachQuestion: String
    var limiter: DailyPlanLimiter?
}

enum DailyPlanEngine {
    static func recommendation(
        for dashboard: DashboardSummary,
        journalFlags: Set<String> = []
    ) -> DailyPlanRecommendation {
        let limiter = mainLimiter(for: dashboard)

        if !journalFlags.isDisjoint(with: ["sick", "injured"]) {
            return DailyPlanRecommendation(
                kind: .rest,
                accent: .recovery,
                title: L10n.t("Make today a rest day", "今天安排休息"),
                body: L10n.t(
                    "Your journal reports illness or injury. Skip training and focus on recovery. Seek medical advice if symptoms are significant or persistent.",
                    "你的日志记录了生病或受伤。今天停止训练，专注恢复。如果症状明显或持续，请咨询医生。"
                ),
                primaryActionTitle: L10n.t("Plan a rest day", "规划休息日"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Build a rest-day recovery plan for me. My journal reports illness or injury, so do not prescribe training.",
                    "请为我制定休息日恢复计划。我的日志记录了生病或受伤，因此不要安排训练。"
                ),
                limiter: nil
            )
        }

        if journalFlags.contains("resting") {
            return DailyPlanRecommendation(
                kind: .rest,
                accent: .recovery,
                title: L10n.t("Keep today as a rest day", "今天保持休息"),
                body: L10n.t(
                    "You marked today as a rest period. Skip planned training and focus on recovery habits.",
                    "你已将今天标记为休息期。暂停计划训练，优先安排恢复习惯。"
                ),
                primaryActionTitle: L10n.t("Plan a rest day", "规划休息日"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Build a rest-day recovery plan for me. I marked today as a rest period, so do not prescribe training.",
                    "请为我制定休息日恢复计划。我已将今天标记为休息期，因此不要安排训练。"
                ),
                limiter: nil
            )
        }

        if !dashboard.recovery.hasData {
            return DailyPlanRecommendation(
                kind: .maintain,
                accent: .energy,
                title: L10n.t("Connect your baseline", "先建立你的基线"),
                body: L10n.t(
                    "Vela needs Apple Health recovery data before it can make a confident daily plan.",
                    "Vela 需要 Apple 健康的恢复数据，才能给出可信的今日计划。"
                ),
                primaryActionTitle: L10n.t("Ask what to set up", "询问如何设置"),
                secondaryActionTitle: nil,
                coachQuestion: L10n.t(
                    "Tell me what health permissions and data I need to enable so Vela can generate a reliable daily plan.",
                    "请告诉我需要开启哪些健康权限和数据，才能让 Vela 生成可靠的今日计划。"
                ),
                limiter: nil
            )
        }

        if dashboard.recovery.score < 40 {
            return DailyPlanRecommendation(
                kind: .recovery,
                accent: .recovery,
                title: L10n.t("Make today a recovery day", "今天按恢复日处理"),
                body: bodyWithLimiter(
                    L10n.t(
                    "Recovery is low. Keep training very light and spend your effort on sleep, food, hydration, and lowering physiological stress.",
                    "恢复偏低。训练保持很轻，把精力放在睡眠、饮食、补水和降低生理压力上。"
                    ),
                    limiter: limiter
                ),
                primaryActionTitle: L10n.t("Plan recovery day", "规划恢复日"),
                secondaryActionTitle: L10n.t("Check limiting factor", "查看限制因素"),
                coachQuestion: coachQuestion(
                    base: L10n.t(
                    "Build a recovery day plan for me based on today's recovery, sleep, strain, stress, and energy. Be specific and tell me what training to avoid.",
                    "请基于今天的恢复、睡眠、负荷、压力和能量，为我制定一个恢复日计划。要具体，并告诉我哪些训练应该避免。"
                    ),
                    dashboard: dashboard,
                    limiter: limiter
                ),
                limiter: limiter
            )
        }

        if dashboard.recovery.score >= 70 && dashboard.strain.score < Double(dashboard.strain.recommendedRange.lowerBound) {
            return DailyPlanRecommendation(
                kind: .train,
                accent: .strain,
                title: L10n.t("Training window is open", "今天有训练窗口"),
                body: bodyWithLimiter(
                    L10n.t(
                    "Recovery is strong and current strain is still below target. This is a good window to add a controlled training stimulus.",
                    "恢复较好，而且当前负荷还低于目标区间。今天适合加入一次可控训练刺激。"
                    ),
                    limiter: limiter
                ),
                primaryActionTitle: L10n.t("Build today's session", "生成今日训练"),
                secondaryActionTitle: L10n.t("Set target strain", "设定目标负荷"),
                coachQuestion: coachQuestion(
                    base: L10n.t(
                    "Use my recovery, strain target range, energy, stress, sleep, and training history to create today's training session. Include warm-up, main work, intensity, and when to stop.",
                    "请基于我的恢复、负荷目标区间、能量、压力、睡眠和训练历史，生成今天的训练内容。包括热身、主训练、强度和停止条件。"
                    ),
                    dashboard: dashboard,
                    limiter: limiter
                ),
                limiter: limiter
            )
        }

        return DailyPlanRecommendation(
            kind: .maintain,
            accent: .energy,
            title: L10n.t("Keep the day controlled", "今天保持可控"),
            body: bodyWithLimiter(
                L10n.t(
                "Your signals are mixed. Keep the day steady: avoid chasing a high strain score and protect tonight's sleep.",
                "今天信号比较混合。保持节奏稳定：不要强行追高负荷，优先保护今晚睡眠。"
                ),
                limiter: limiter
            ),
            primaryActionTitle: L10n.t("Get today's plan", "获取今日计划"),
            secondaryActionTitle: L10n.t("Review signals", "复盘关键指标"),
            coachQuestion: coachQuestion(
                base: L10n.t(
                "Give me a controlled daily plan based on today's recovery, sleep, strain, stress, and energy. Start with what I should do, then what I should avoid.",
                "请基于今天的恢复、睡眠、负荷、压力和能量，给我一个可控的今日计划。先说我应该做什么，再说应该避免什么。"
                ),
                dashboard: dashboard,
                limiter: limiter
            ),
            limiter: limiter
        )
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
