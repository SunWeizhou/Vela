import Foundation

enum ReadinessDecisionKind: String, Codable, Hashable, CaseIterable {
    case keep
    case reduce
    case swap
    case recover
}

struct TodayHealthSignal: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var title: String
    var value: String
    var baseline: String?
    var interpretation: String
    var source: HealthDataSource
    var confidence: DataConfidence
    var metricKey: String
}

struct TodayAction: Codable, Hashable, Identifiable, Sendable {
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

struct ReadinessDecision: Codable, Hashable, Sendable {
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

struct TodayCommandState: Codable, Hashable, Sendable {
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

    private static func numericConfidence(_ confidence: MetricConfidence) -> Double {
        switch confidence {
        case .high: return 1.0
        case .medium: return 0.7
        case .low: return 0.4
        }
    }

    public static func readinessDecision(
        from dashboard: DashboardSummary,
        signals: [TodayHealthSignal],
        recentStrengthSummary: RecentTrainingSummary?
    ) -> (decision: ReadinessDecisionKind, confidence: Double, reasons: [String]) {
        var reasons: [String] = []
        if !dashboard.recovery.hasData {
            return (.reduce, 0.0, ["恢复基线数据不足，先按保守方案执行。"])
        }

        let recConf = dashboard.recovery.hasData ? numericConfidence(dashboard.recovery.confidence) : 0.0
        let sleepConf = dashboard.sleepScore.hasData ? numericConfidence(dashboard.sleepScore.confidence) : 0.0
        let stressConf = dashboard.stress.hasData ? numericConfidence(dashboard.stress.confidence) : 0.0

        // Weighted by per-source confidence, capped at 1.0, with no artificial
        // floor: sparse or low-confidence data must surface as genuinely low
        // readiness confidence rather than being coerced upward. Previously a
        // `max(0.3, …)` floor hid missing/low data, presenting pseudo-calibrated
        // certainty to the user.
        let computedConf = min(1.0, 0.50 * recConf + 0.30 * sleepConf + 0.20 * stressConf)
        let dynamicConfidence = computedConf

        if let first = dashboard.recovery.reasons.first {
            reasons.append(first)
        }
        let thresholds = PersonalBaselineEngine.resolveThresholds()
        if dashboard.recovery.score < thresholds.recoveryRest {
            reasons.append("Recovery \(Int(dashboard.recovery.score.rounded())) is below the recovery-day threshold (\(thresholds.source)).")
            return (.recover, 0.86 * dynamicConfidence, reasons)
        }
        if dashboard.sleepScore.hasData, dashboard.sleepScore.score < thresholds.sleepRest {
            reasons.append("Sleep score \(Int(dashboard.sleepScore.score.rounded())) is limiting readiness (\(thresholds.source)).")
            return (.recover, 0.78 * dynamicConfidence, reasons)
        }
        if dashboard.stress.hasData, dashboard.stress.stressIndex > 78 {
            reasons.append("Physiological stress is elevated.")
            return (.recover, 0.74 * dynamicConfidence, reasons)
        }
        if let summary = recentStrengthSummary,
           summary.localFatigue.values.contains(where: { $0.fatigueLevel == "high" }) {
            reasons.append("Local muscle fatigue is high from recent strength work.")
            return (.swap, 0.72 * dynamicConfidence, reasons)
        }
        if dashboard.recovery.score < thresholds.recoveryCaution || dashboard.sleepScore.score < thresholds.sleepCaution {
            reasons.append("Recovery or sleep is not low enough for rest, but not strong enough for full volume (\(thresholds.source)).")
            return (.reduce, 0.68 * dynamicConfidence, reasons)
        }
        if dashboard.strain.hasData, dashboard.strain.score > Double(dashboard.strain.recommendedRange.upperBound) {
            reasons.append("Current strain is already above today's target range.")
            return (.reduce, 0.70 * dynamicConfidence, reasons)
        }

        if reasons.isEmpty {
            reasons.append("Recovery, sleep, and strain are within an actionable range.")
        }
        return (.keep, 0.76 * dynamicConfidence, reasons)
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
                TodayAction(id: "recovery_plan", kind: .recovery, title: "执行恢复日", detail: "轻量 activity、补水、晚间提前睡眠。", destination: "recovery", isPrimary: true),
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
            return "恢复 \(recovery), 睡眠 \(sleep)、负荷 \(strain)。今天优先恢复，避免高强度训练。"
        }
    }

    private static func hrvInterpretation(_ dashboard: DashboardSummary) -> String {
        guard let hrv = dashboard.recoveryMetrics.hrvMilliseconds,
              let baseline = dashboard.recoveryBaseline.hrvMilliseconds,
              baseline > 0 else {
            return "HRV 基线仍在建立。"
        }
        let delta = (hrv - baseline) / baseline
        if delta < -0.10 { return "HRV 低于个人基线，今天宜结合睡眠和主观状态保守安排训练。" }
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
        if signals.contains(where: { $0.confidence == .unavailable }) { return .low }
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
