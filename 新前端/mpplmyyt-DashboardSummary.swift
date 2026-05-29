import Foundation

struct DashboardSummary: Hashable {
    var date: Date
    var sleepSummary: SleepSummary
    var sleepScore: StandardScoreResult
    var recovery: StandardScoreResult
    var recoveryMetrics: RecoveryMetricSummary
    var recoveryBaseline: RecoveryMetricSummary
    var strain: StrainScoreResult
    var stress: StressIndexResult
    var energy: EnergyBankResult
    var healthAge: HealthAgeTrendResult
    var bodyMetrics: BodyMetricsSummary
    var extendedMetrics: ExtendedHealthMetrics
    var workouts: [WorkoutSummary]
    var dailyInsight: String
    var source: DataSource

    enum DataSource: String, Hashable {
        case healthKit = "HealthKit"
        case preview = "Preview"
    }

    static func preview(date: Date = Date()) -> DashboardSummary {
        let sleepSummary = PreviewHealthDataProvider.sleepSummary(for: date)
        let sleepScore = SleepScoreEngine().calculate(
            from: SleepScoreInput(
                totalSleepMinutes: Double(sleepSummary.totalSleepMinutes),
                sleepTargetMinutes: 450,
                bedtimeOffsetMinutes: 45,
                wakeOffsetMinutes: 20
            )
        )
        let recovery = RecoveryScoreEngine().calculate(
            from: RecoveryScoreInput(
                hrvToday: 42,
                hrvBaseline: 45,
                restingHeartRateToday: 62,
                restingHeartRateBaseline: 60,
                sleepScoreLastNight: sleepScore.score,
                strainScoreYesterday: 58
            )
        )
        let strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: 420,
                activeEnergyBaseline: 500,
                exerciseMinutesToday: 28,
                exerciseMinutesBaseline: 35,
                workoutIntensityLoad: 42,
                recoveryScore: recovery.score
            )
        )
        let stress = StressIndexEngine().calculate(
            from: StressIndexInput(
                heartRateElevationScore: 38,
                hrvSuppressionScore: 45,
                sleepDebtStressScore: max(0, 100 - sleepScore.score),
                recentStrainStressScore: strain.score
            )
        )
        let energy = EnergyBankEngine().calculate(
            from: EnergyBankInput(
                recoveryScore: recovery.score,
                sleepScore: sleepScore.score,
                strainScore: strain.score,
                stressIndex: stress.stressIndex,
                hrvToday: 42,
                hrvBaseline: 45,
                rhrToday: 62,
                rhrBaseline: 60,
                sleepHours: 7.2,
                strainHistory: [45, 52, 58, 55, 48, 60, 58],
                bodyTempDelta: 0.0
            )
        )
        let healthAge = HealthAgeTrendEngine().calculate(
            from: HealthAgeTrendInput(
                factors: [
                    .init(name: "VO2 Max", direction: .neutral),
                    .init(name: "Resting heart rate", direction: .positive),
                    .init(name: "Sleep regularity", direction: .negative),
                    .init(name: "Activity consistency", direction: .positive)
                ]
            )
        )

        return DashboardSummary(
            date: date,
            sleepSummary: sleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: RecoveryMetricSummary(
                hrvMilliseconds: 42,
                restingHeartRate: 62,
                sleepHeartRate: 58,
                respiratoryRate: 14
            ),
            recoveryBaseline: RecoveryMetricSummary(
                hrvMilliseconds: 45,
                restingHeartRate: 60,
                sleepHeartRate: nil,
                respiratoryRate: nil
            ),
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: healthAge,
            bodyMetrics: BodyMetricsSummary(
                vo2Max: 42,
                weightKilograms: 72,
                bodyFatPercentage: 18,
                leanBodyMassKilograms: 59
            ),
            extendedMetrics: ExtendedHealthMetrics(age: 28, biologicalSex: "male", heightCm: 175),
            workouts: [],
            dailyInsight: L10n.t(
                "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
                "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
            ),
            source: .preview
        )
    }

    static func healthKit(
        context: DailyHealthContext,
        strainScoreYesterday: Double? = nil,
        bedtimeOffsetMinutes: Double? = nil,
        wakeOffsetMinutes: Double? = nil,
        hrvHistory: [Double] = [],
        rhrHistory: [Double] = [],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DashboardSummary {
        let sleepTarget = UserDefaults.standard.double(forKey: "vela_sleep_target_hours") * 60
        let effectiveSleepTarget = sleepTarget > 0 ? sleepTarget : 450
        let sleepSummary = context.sleepSummary ?? SleepSummary(
            date: context.date,
            totalSleepMinutes: 0,
            bedtime: nil,
            wakeTime: nil,
            stageMinutes: [:],
            segments: [],
            sleepScore: nil
        )
        let sleepScore = SleepScoreEngine().calculate(
            from: SleepScoreInput(
                totalSleepMinutes: context.sleepSummary.map { Double($0.totalSleepMinutes) },
                sleepTargetMinutes: effectiveSleepTarget,
                bedtimeOffsetMinutes: bedtimeOffsetMinutes,
                wakeOffsetMinutes: wakeOffsetMinutes,
                remMinutes: context.sleepSummary?.stageMinutes[.rem].map { Double($0) },
                deepMinutes: context.sleepSummary?.stageMinutes[.deep].map { Double($0) },
                awakeMinutes: context.sleepSummary?.stageMinutes[.awake].map { Double($0) },
                inBedMinutes: context.sleepSummary?.stageMinutes[.inBed].map { Double($0) }
            )
        )
        let resolvedSleepSummary = SleepSummary(
            date: sleepSummary.date,
            totalSleepMinutes: sleepSummary.totalSleepMinutes,
            bedtime: sleepSummary.bedtime,
            wakeTime: sleepSummary.wakeTime,
            stageMinutes: sleepSummary.stageMinutes,
            segments: sleepSummary.segments,
            sleepScore: sleepScore.score
        )
        let recovery = RecoveryScoreEngine().calculate(
            from: RecoveryScoreInput(
                hrvToday: context.recoveryMetrics.hrvMilliseconds,
                hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
                hrvHistory: hrvHistory,
                restingHeartRateToday: context.recoveryMetrics.restingHeartRate,
                restingHeartRateBaseline: context.recoveryBaseline.restingHeartRate,
                rhrHistory: rhrHistory,
                sleepScoreLastNight: context.sleepSummary == nil ? nil : sleepScore.score,
                strainScoreYesterday: strainScoreYesterday
            )
        )
        let workoutLoad = context.strainToday.workouts
            .compactMap(\.averageHeartRate)
            .max()
            .map { ScoringMath.clamp(($0 - 90) / 80 * 100) }
        let strain = StrainScoreEngine().calculate(
            from: StrainScoreInput(
                activeEnergyToday: context.strainToday.activeEnergyKilocalories,
                activeEnergyBaseline: context.strainBaselineDaily.activeEnergyKilocalories,
                exerciseMinutesToday: context.strainToday.exerciseMinutes,
                exerciseMinutesBaseline: context.strainBaselineDaily.exerciseMinutes,
                workoutIntensityLoad: workoutLoad ?? (context.strainToday.workouts.isEmpty ? nil : 45),
                recoveryScore: recovery.score,
                stepCount: context.strainToday.stepCount
            )
        )
        let stress = StressIndexEngine().calculate(
            from: StressIndexInput(
                heartRateElevationScore: stressHeartRateScore(today: context.recoveryMetrics.restingHeartRate, baseline: context.recoveryBaseline.restingHeartRate),
                hrvSuppressionScore: stressHRVScore(today: context.recoveryMetrics.hrvMilliseconds, baseline: context.recoveryBaseline.hrvMilliseconds),
                sleepDebtStressScore: context.sleepSummary == nil ? nil : max(0, 100 - sleepScore.score),
                recentStrainStressScore: strain.score
            )
        )
        let energy = EnergyBankEngine().calculate(
            from: EnergyBankInput(
                recoveryScore: recovery.score,
                sleepScore: context.sleepSummary == nil ? nil : sleepScore.score,
                strainScore: strain.score,
                stressIndex: stress.stressIndex,
                hrvToday: context.recoveryMetrics.hrvMilliseconds,
                hrvBaseline: context.recoveryBaseline.hrvMilliseconds,
                rhrToday: context.recoveryMetrics.restingHeartRate,
                rhrBaseline: context.recoveryBaseline.restingHeartRate,
                sleepHours: context.sleepSummary.map { Double($0.totalSleepMinutes) / 60.0 },
                strainHistory: nil, // populated if available from historical context
                bodyTempDelta: context.extendedMetrics.bodyTemperature.map { $0 - 36.5 }
            )
        )
        let healthAge = HealthAgeTrendEngine().calculate(
            from: HealthAgeTrendInput(
                factors: healthAgeFactors(context: context, recovery: recovery, sleepScore: sleepScore, strain: strain)
            )
        )

        return DashboardSummary(
            date: context.date,
            sleepSummary: resolvedSleepSummary,
            sleepScore: sleepScore,
            recovery: recovery,
            recoveryMetrics: context.recoveryMetrics,
            recoveryBaseline: context.recoveryBaseline,
            strain: strain,
            stress: stress,
            energy: energy,
            healthAge: healthAge,
            bodyMetrics: context.bodyMetrics,
            extendedMetrics: context.extendedMetrics,
            workouts: context.strainToday.workouts,
            dailyInsight: dailyInsight(recovery: recovery, sleepScore: sleepScore, strain: strain, source: .healthKit),
            source: .healthKit
        )
    }

    private static func stressHeartRateScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((today - baseline) / baseline) * 250 + 35)
    }

    private static func stressHRVScore(today: Double?, baseline: Double?) -> Double? {
        guard let today, let baseline, baseline > 0 else { return nil }
        return ScoringMath.clamp(((baseline - today) / baseline) * 250 + 35)
    }

    private static func healthAgeFactors(
        context: DailyHealthContext,
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult
    ) -> [HealthAgeTrendFactor] {
        var factors: [HealthAgeTrendFactor] = []
        if let vo2 = context.bodyMetrics.vo2Max {
            factors.append(.init(name: "VO2 Max", direction: vo2 >= 40 ? .positive : .neutral))
        }
        if let rhr = context.recoveryMetrics.restingHeartRate {
            factors.append(.init(name: "Resting heart rate", direction: rhr <= 62 ? .positive : .negative))
        }
        if let bf = context.bodyMetrics.bodyFatPercentage {
            // Healthy body fat: roughly 10-20% men, 18-28% women — use a mid-range check
            factors.append(.init(name: "Body fat", direction: (10...30).contains(bf) ? .positive : .negative))
        }
        if let weight = context.bodyMetrics.weightKilograms, let lean = context.bodyMetrics.leanBodyMassKilograms, weight > 0 {
            let leanRatio = lean / weight
            factors.append(.init(name: "Lean mass ratio", direction: leanRatio >= 0.65 ? .positive : .neutral))
        }
        factors.append(.init(name: "Sleep duration", direction: sleepScore.score >= 70 ? .positive : .negative))
        factors.append(.init(name: "Recovery trend", direction: recovery.score >= 70 ? .positive : (recovery.score < 40 ? .negative : .neutral)))
        factors.append(.init(name: "Activity consistency", direction: strain.confidence == .high ? .positive : .neutral))
        return factors
    }

    private static func dailyInsight(
        recovery: StandardScoreResult,
        sleepScore: StandardScoreResult,
        strain: StrainScoreResult,
        source: DataSource
    ) -> String {
        if source == .healthKit {
            return L10n.t(
                "Updated from Apple Health. Recovery \(Int(recovery.score.rounded())), sleep \(Int(sleepScore.score.rounded())), strain \(Int(strain.score.rounded())).",
                "已读取 Apple 健康数据。恢复 \(Int(recovery.score.rounded()))，睡眠 \(Int(sleepScore.score.rounded()))，负荷 \(Int(strain.score.rounded()))。"
            )
        }
        return L10n.t(
            "Recovery is moderate. Keep training controlled and protect sleep timing tonight.",
            "恢复处于中等水平。今天训练保持可控，今晚优先保护睡眠时间。"
        )
    }
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
