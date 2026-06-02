import Foundation

struct AIContextBuilder {
    static let schemaVersion = "v1.0"

    func build(
        dashboard: DashboardSummary,
        journalEntries: [JournalContextEntry],
        historicalReports: [GeneratedAIReport],
        userWiki: [String: String],
        weeklyTrends: [String: String] = [:],
        foodLogs: [FoodLogRecord] = [],
        generatedAt: Date = Date()
    ) -> (envelope: AgentContextEnvelope, metadata: ContextSnapshotMetadata) {
        let envelope = AgentContextEnvelope(
            metadata: AgentContextMetadata(generatedAt: generatedAt, contextWindow: "today"),
            todaySummary: [
                "date": dashboard.date.formatted(date: .numeric, time: .omitted),
                "overall_state": dashboard.recovery.band.rawValue.lowercased(),
                "source": dashboard.source.rawValue,
                "top_reason": dashboard.recovery.reasons.first ?? dashboard.dailyInsight,
                "readiness_level": dashboard.trainingDecision.readinessLevel,
                "readiness_guidance": dashboard.trainingDecision.readinessGuidance
            ],
            sleep: SleepContextBuilder().build(from: dashboard),
            recovery: RecoveryContextBuilder().build(from: dashboard),
            strain: StrainContextBuilder().build(from: dashboard),
            workouts: WorkoutsContextBuilder().build(from: dashboard.workouts),
            stress: StressContextBuilder().build(from: dashboard),
            energyBank: EnergyBankContextBuilder().build(from: dashboard),
            healthAgeTrend: HealthAgeContextBuilder().build(from: dashboard),
            recentTrends: [
                "note": "Recent trends require enough cached history. No trend is reported until sufficient snapshots exist."
            ],
            weeklyTrends: weeklyTrends.isEmpty ? ["note": "No weekly trend data available yet. Historical snapshots require a few days of data."] : weeklyTrends,
            nutrition: buildNutritionDict(foodLogs),
            journal: [
                "entries": journalEntries.map { "\($0.tags.joined(separator: "|")): \($0.text)" }.joined(separator: "\n")
            ],
            historicalAIReports: [
                "recent": historicalReports.map { "\($0.title): \($0.markdownContent.prefix(160))" }.joined(separator: "\n")
            ],
            userWiki: userWiki,
            agentInstruction: [
                "role": "Private health data analyst and lifestyle coach",
                "safety": "Do not diagnose. Be cautious with stress and health age trend."
            ],
            extendedMetrics: ExtendedMetricsContextBuilder().build(
                ext: dashboard.extendedMetrics,
                body: dashboard.bodyMetrics
            )
        )

        let contextJSON = (try? String(data: JSONEncoder().encode(envelope), encoding: .utf8)) ?? "{}"
        let hash = ContentHash.hash(contextJSON)
        let metadata = ContextSnapshotMetadata(
            schemaVersion: AIContextBuilder.schemaVersion,
            generatedAt: generatedAt,
            hash: hash,
            includedSections: [
                "today_summary", "sleep", "recovery", "strain", "workouts",
                "stress", "energy_bank", "health_age_trend", "nutrition",
                "journal", "user_wiki", "extended_metrics"
            ],
            redactedFields: []
        )
        return (envelope: envelope, metadata: metadata)
    }

    // MARK: - Typed Context Builder (v2)

    func buildTyped(
        dashboard: DashboardSummary,
        journalEntries: [JournalContextEntry],
        historicalReports: [GeneratedAIReport],
        userWiki: [String: String],
        weeklyTrends: [String: String] = [:],
        foodLogs: [FoodLogRecord] = [],
        generatedAt: Date = Date()
    ) -> (context: TypedAgentContext, metadata: ContextSnapshotMetadata) {
        let hrvMs = dashboard.recoveryMetrics.hrvMilliseconds
        let rhrBpm = dashboard.recoveryMetrics.restingHeartRate

        let recovery = RecoveryContext(
            score: MetricValue.live(dashboard.recovery.score, unit: "pts"),
            band: dashboard.recovery.band.rawValue,
            hrv: MetricValue.live(hrvMs ?? 0, unit: "ms", confidence: hrvMs != nil ? .high : .unavailable),
            restingHeartRate: MetricValue.live(rhrBpm ?? 0, unit: "bpm", confidence: rhrBpm != nil ? .high : .unavailable),
            respiratoryRate: MetricValue.live(dashboard.recoveryMetrics.respiratoryRate ?? 0, unit: "br/min"),
            topReason: dashboard.recovery.reasons.first
        )

        let sleepMetrics = dashboard.sleepScore.metrics
        let sleep = SleepContext(
            score: MetricValue.live(dashboard.sleepScore.score, unit: "pts"),
            band: dashboard.sleepScore.band.rawValue,
            totalMinutes: MetricValue.live(dashboard.sleepSummary.totalSleepMinutes, unit: "min"),
            efficiency: MetricValue.live(sleepMetrics["sleep_efficiency"] ?? 0, unit: "%"),
            remPercent: MetricValue.live(sleepMetrics["rem_pct"] ?? 0, unit: "%"),
            deepPercent: MetricValue.live(sleepMetrics["deep_pct"] ?? 0, unit: "%"),
            coreMinutes: MetricValue.live(dashboard.sleepSummary.stageMinutes[.core] ?? 0, unit: "min"),
            remMinutes: MetricValue.live(dashboard.sleepSummary.stageMinutes[.rem] ?? 0, unit: "min"),
            deepMinutes: MetricValue.live(dashboard.sleepSummary.stageMinutes[.deep] ?? 0, unit: "min"),
            awakeMinutes: MetricValue.live(dashboard.sleepSummary.stageMinutes[.awake] ?? 0, unit: "min"),
            bedtime: dashboard.sleepSummary.bedtime,
            wakeTime: dashboard.sleepSummary.wakeTime,
            topReason: dashboard.sleepScore.reasons.first
        )

        let strain = StrainContext(
            score: MetricValue.live(dashboard.strain.score, unit: "pts"),
            band: dashboard.strain.band.rawValue,
            targetStatus: dashboard.strain.targetStatus.rawValue,
            recommendedRangeLower: dashboard.strain.recommendedRange.lowerBound,
            recommendedRangeUpper: dashboard.strain.recommendedRange.upperBound,
            steps: MetricValue.live(Int(dashboard.strain.metrics["steps_raw"] ?? 0), unit: "steps"),
            activeEnergyKcal: MetricValue.live(Int(dashboard.strain.metrics["active_energy_raw"] ?? 0), unit: "kcal"),
            exerciseMinutes: MetricValue.live(Int(dashboard.strain.metrics["exercise_minutes_raw"] ?? 0), unit: "min")
        )

        let stress = StressContext(
            stressIndex: MetricValue.live(dashboard.stress.stressIndex, unit: "index"),
            band: dashboard.stress.band.rawValue,
            confidence: dashboard.stress.confidence.rawValue == "high" ? .high : .medium,
            proxyNote: "Physiological proxy, not a medical or mental health diagnosis."
        )

        let energyBank = EnergyBankContext(
            morningEnergy: MetricValue.live(dashboard.energy.morningEnergy, unit: "pts"),
            currentEnergy: MetricValue.live(dashboard.energy.currentEnergy, unit: "pts"),
            status: dashboard.energy.status.rawValue,
            chargeEfficiency: MetricValue.live(dashboard.energy.metrics["charge_efficiency"] ?? 0, unit: "ratio"),
            atl7Day: MetricValue.live(dashboard.energy.metrics["atl"] ?? 0, unit: "AU"),
            ctl42Day: MetricValue.live(dashboard.energy.metrics["ctl"] ?? 0, unit: "AU"),
            tsbFreshness: MetricValue.live(dashboard.energy.metrics["tsb"] ?? 0, unit: "AU")
        )

        let workouts = dashboard.workouts
        let training = TrainingContext(
            activePlan: nil,
            workoutCount: workouts.count,
            workoutTypes: Array(Set(workouts.map(\.activityName))).sorted(),
            totalEnergyKcal: workouts.compactMap(\.energyKilocalories).reduce(0, +),
            totalDurationMin: workouts.map { Int($0.end.timeIntervalSince($0.start) / 60) }.reduce(0, +),
            workoutListJSON: "[]"
        )

        let nutrition = NutritionContext(
            recentEntries: foodLogs.prefix(8).map { $0.summaryLine },
            recentCount: min(foodLogs.count, 8),
            totalCalories: foodLogs.prefix(8).map(\.totalCalories).reduce(0, +),
            totalProtein: foodLogs.prefix(8).map(\.proteinGrams).reduce(0, +),
            totalCarbs: foodLogs.prefix(8).map(\.carbsGrams).reduce(0, +),
            totalFat: foodLogs.prefix(8).map(\.fatGrams).reduce(0, +),
            totalFiber: foodLogs.prefix(8).map(\.fiberGrams).reduce(0, +)
        )

        let ext = dashboard.extendedMetrics
        let body = dashboard.bodyMetrics
        let age = WikiFileService.getAgeFromWiki() ?? ext.age
        let extended = ExtendedMetricsContext(
            age: age,
            biologicalSex: ext.biologicalSex,
            heightCm: ext.heightCm.map { MetricValue.live($0, unit: "cm") } ?? MetricValue.missing(),
            weightKg: body.weightKilograms.map { MetricValue.live($0, unit: "kg") } ?? MetricValue.missing(),
            bmi: ext.bmi.map { MetricValue.live($0, unit: "kg/m²") } ?? MetricValue.missing(),
            bodyFatPct: body.bodyFatPercentage.map { MetricValue.live($0, unit: "%") } ?? MetricValue.missing(),
            vo2Max: body.vo2Max.map { MetricValue.live($0, unit: "ml/kg/min") } ?? MetricValue.missing(),
            walkingSpeed: ext.walkingSpeed.map { MetricValue.live($0, unit: "m/s") } ?? MetricValue.missing(),
            walkingAsymmetry: ext.walkingAsymmetry.map { MetricValue.live($0, unit: "%") } ?? MetricValue.missing(),
            doubleSupportPct: ext.walkingDoubleSupport.map { MetricValue.live($0, unit: "%") } ?? MetricValue.missing(),
            spo2: ext.oxygenSaturation.map { MetricValue.live($0, unit: "%") } ?? MetricValue.missing(),
            bloodPressureSystolic: ext.bloodPressureSystolic.map { MetricValue.live(Int($0), unit: "mmHg") },
            bloodPressureDiastolic: ext.bloodPressureDiastolic.map { MetricValue.live(Int($0), unit: "mmHg") },
            bloodGlucose: ext.bloodGlucose.map { MetricValue.live($0, unit: "mg/dL") },
            waterMl: ext.waterMl.map { MetricValue.live(Int($0), unit: "ml") },
            caffeineMg: ext.caffeineMg.map { MetricValue.live(Int($0), unit: "mg") },
            envNoiseDb: ext.environmentalNoisedB.map { MetricValue.live($0, unit: "dB") },
            daylightMinutes: ext.timeInDaylight.map { MetricValue.live(Int($0), unit: "min") },
            wristTempC: ext.bodyTemperature.map { MetricValue.live($0, unit: "°C") }
        )

        let context = TypedAgentContext(
            schemaVersion: AIContextBuilder.schemaVersion,
            contextHash: "",
            generatedAt: generatedAt,
            contextWindow: "today",
            recovery: recovery,
            sleep: sleep,
            strain: strain,
            stress: stress,
            energyBank: energyBank,
            training: training,
            nutrition: nutrition,
            extendedMetrics: extended,
            recentTrends: ["note": "v2 typed context"],
            weeklyTrends: weeklyTrends.isEmpty ? ["note": "No weekly trend data available yet."] : weeklyTrends,
            journalEntries: journalEntries.map { "\($0.tags.joined(separator: "|")): \($0.text)" },
            historicalReports: historicalReports.map { "\($0.title): \($0.markdownContent.prefix(160))" },
            userWiki: userWiki
        )

        let contextJSON = (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}"
        let hash = ContentHash.hash(contextJSON)
        var withHash = context
        withHash.contextHash = hash

        let metadata = ContextSnapshotMetadata(
            schemaVersion: AIContextBuilder.schemaVersion,
            generatedAt: generatedAt,
            hash: hash,
            includedSections: ["recovery", "sleep", "strain", "stress", "energy_bank", "training", "nutrition", "extended_metrics"],
            redactedFields: []
        )

        return (context: withHash, metadata: metadata)
    }

    // MARK: - Private Helpers

    private func buildNutritionDict(_ foodLogs: [FoodLogRecord]) -> [String: String] {
        guard !foodLogs.isEmpty else {
            return ["note": "No structured food logs are available yet."]
        }

        let recent = foodLogs.prefix(8)
        let totalCalories = recent.map(\.totalCalories).reduce(0, +)
        let totalProtein = recent.map(\.proteinGrams).reduce(0, +)
        let totalCarbs = recent.map(\.carbsGrams).reduce(0, +)
        let totalFat = recent.map(\.fatGrams).reduce(0, +)
        let totalFiber = recent.map(\.fiberGrams).reduce(0, +)
        let entries = recent.map { log in
            "\(log.mealName): \(log.foods.map(\.name).joined(separator: ", ")) · \(log.totalCalories) kcal · P\(log.proteinGrams) C\(log.carbsGrams) F\(log.fatGrams) Fiber\(log.fiberGrams) · score=\(log.healthScore)"
        }.joined(separator: "\n")

        return [
            "recent_entries": entries,
            "recent_count": "\(recent.count)",
            "recent_total_calories": "\(totalCalories)",
            "recent_total_macros": "P\(totalProtein) C\(totalCarbs) F\(totalFat) Fiber\(totalFiber)",
            "source_note": "Structured food logs may come from Kimi vision analysis, Coach tools, or manual entry."
        ]
    }
}
