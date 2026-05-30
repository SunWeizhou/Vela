import Foundation

struct DashboardSummary: Hashable {
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

    enum DataSource: String, Hashable {
        case healthKit = "HealthKit"
        case empty = "Empty"
        case preview = "Preview"
    }

    static func preview(date: Date = Date()) -> DashboardSummary {
        PreviewDataFactory.makeDashboard(date: date)
    }

    static func empty(date: Date = Date()) -> DashboardSummary {
        DashboardSummary(
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
            strain: StrainScoreEngine().calculate(from: StrainScoreInput()),
            stress: StressIndexEngine().calculate(from: StressIndexInput()),
            energy: EnergyBankEngine().calculate(from: EnergyBankInput(
                recoveryScore: nil,
                sleepScore: nil,
                strainScore: nil,
                stressIndex: nil
            )),
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

enum DailyPlanKind: String, Codable, Hashable {
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
    static func recommendation(for dashboard: DashboardSummary) -> DailyPlanRecommendation {
        let limiter = mainLimiter(for: dashboard)

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
        let plan = DailyPlanEngine.recommendation(for: dashboard)
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
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
