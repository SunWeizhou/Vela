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
        // Calculate derived recovery values
        let hrvToday = dashboard.recoveryMetrics.hrvMilliseconds
        let hrvBaseline = dashboard.recoveryBaseline.hrvMilliseconds
        let hrvVsBaselinePct: String
        if let hrvToday, let hrvBaseline, hrvBaseline > 0 {
            let diffPct = ((hrvToday - hrvBaseline) / hrvBaseline) * 100
            hrvVsBaselinePct = String(format: "%+.1f%%", diffPct)
        } else {
            hrvVsBaselinePct = "N/A"
        }
        
        let hrvZScoreVal = dashboard.recovery.metrics["hrv_z_score"]
        let hrvZScoreStr = hrvZScoreVal.map { String(format: "%.2f", $0) } ?? "N/A"

        // Sleep metrics
        let sleepMetrics = dashboard.sleepScore.metrics
        let sleepEfficiencyPct = sleepMetrics["sleep_efficiency"].map { String(format: "%.1f%%", $0) } ?? "N/A"
        let remPct = sleepMetrics["rem_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A"
        let deepPct = sleepMetrics["deep_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A"

        let envelope = AgentContextEnvelope(
            metadata: AgentContextMetadata(generatedAt: generatedAt, contextWindow: "today"),
            todaySummary: [
                "date": dashboard.date.formatted(date: .numeric, time: .omitted),
                "overall_state": dashboard.recovery.band.rawValue.lowercased(),
                "source": dashboard.source.rawValue,
                "top_reason": dashboard.recovery.reasons.first ?? dashboard.dailyInsight
            ],
            sleep: [
                "sleep_score": dashboard.sleepScore.score.formatted(.number.precision(.fractionLength(0))),
                "duration_minutes": "\(dashboard.sleepSummary.totalSleepMinutes)",
                "band": dashboard.sleepScore.band.rawValue,
                "reason": dashboard.sleepScore.reasons.first ?? "",
                "rem_minutes": "\(dashboard.sleepSummary.stageMinutes[.rem] ?? 0)",
                "deep_minutes": "\(dashboard.sleepSummary.stageMinutes[.deep] ?? 0)",
                "core_minutes": "\(dashboard.sleepSummary.stageMinutes[.core] ?? 0)",
                "awake_minutes": "\(dashboard.sleepSummary.stageMinutes[.awake] ?? 0)",
                "sleep_efficiency_pct": sleepEfficiencyPct,
                "rem_pct": remPct,
                "deep_pct": deepPct
            ],
            recovery: [
                "score": dashboard.recovery.score.formatted(.number.precision(.fractionLength(0))),
                "band": dashboard.recovery.band.rawValue,
                "confidence": dashboard.recovery.confidence.rawValue,
                "reason": dashboard.recovery.reasons.first ?? "",
                "hrv_ms": dashboard.recoveryMetrics.hrvMilliseconds.map { "\(Int($0))" } ?? "N/A",
                "rhr_bpm": dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))" } ?? "N/A",
                "respiratory_rate": dashboard.recoveryMetrics.respiratoryRate.map { String(format: "%.1f", $0) } ?? "N/A",
                "hrv_z_score": hrvZScoreStr,
                "hrv_vs_baseline_pct": hrvVsBaselinePct
            ],
            strain: [
                "score": dashboard.strain.score.formatted(.number.precision(.fractionLength(0))),
                "band": dashboard.strain.band.rawValue,
                "target_status": dashboard.strain.targetStatus.rawValue,
                "recommended_range": "\(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)",
                "steps": dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "N/A",
                "active_energy_kcal": dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0))" } ?? "N/A",
                "exercise_minutes": dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))" } ?? "N/A"
            ],
            workouts: buildWorkoutsDict(dashboard.workouts),
            stress: [
                "stress_index": dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))),
                "band": dashboard.stress.band.rawValue,
                "confidence": dashboard.stress.confidence.rawValue,
                "proxy_notice": "Stress is a physiological proxy, not a medical or mental health diagnosis."
            ],
            energyBank: [
                "morning_energy": dashboard.energy.morningEnergy.formatted(.number.precision(.fractionLength(0))),
                "current_energy": dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))),
                "status": dashboard.energy.status.rawValue,
                "charge_efficiency": dashboard.energy.metrics["charge_efficiency"].map { String(format: "%.0f%%", $0 * 100) } ?? "N/A",
                "atl_7day": dashboard.energy.metrics["atl"].map { String(format: "%.0f", $0) } ?? "N/A",
                "ctl_42day": dashboard.energy.metrics["ctl"].map { String(format: "%.0f", $0) } ?? "N/A",
                "tsb_freshness": dashboard.energy.metrics["tsb"].map { String(format: "%+.0f", $0) } ?? "N/A"
            ],
            healthAgeTrend: [
                "trend": dashboard.healthAge.label.rawValue,
                "trend_score": dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2))),
                "beta_notice": "Health Age Trend is beta and does not claim biological age."
            ],
            recentTrends: [
                "note": "Recent trend calculations are v0.1 placeholders until enough cached history exists."
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
            extendedMetrics: buildExtendedMetricsDict(dashboard.extendedMetrics, body: dashboard.bodyMetrics)
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
        let age = WikiFileService.getAgeFromWiki() ?? ext.age ?? 30
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

    private func buildExtendedMetricsDict(_ ext: ExtendedHealthMetrics, body: BodyMetricsSummary) -> [String: String] {
        var d: [String: String] = [:]

        // Personal
        let age = WikiFileService.getAgeFromWiki() ?? ext.age ?? 30
        d["age"] = "\(age)"
        if let sex = ext.biologicalSex { d["biological_sex"] = sex }
        if let h = ext.heightCm { d["height_cm"] = String(format: "%.1f", h) }
        if let bmi = ext.bmi { d["bmi"] = String(format: "%.1f", bmi) }

        // Body composition
        if let w = body.weightKilograms { d["weight_kg"] = String(format: "%.1f", w) }
        if let bf = body.bodyFatPercentage { d["body_fat_pct"] = String(format: "%.1f", bf) }
        if let lbm = body.leanBodyMassKilograms { d["lean_body_mass_kg"] = String(format: "%.1f", lbm) }
        if let vo2 = body.vo2Max { d["vo2_max"] = String(format: "%.1f", vo2) }

        // Cardiovascular
        if let whr = ext.walkingHeartRateAvg { d["walking_hr_avg"] = "\(Int(whr))" }
        if let spo2 = ext.oxygenSaturation { d["spo2_pct"] = String(format: "%.0f", spo2) }
        if let sbp = ext.bloodPressureSystolic { d["blood_pressure_systolic"] = "\(Int(sbp))" }
        if let dbp = ext.bloodPressureDiastolic { d["blood_pressure_diastolic"] = "\(Int(dbp))" }

        // Metabolic
        if let glucose = ext.bloodGlucose { d["blood_glucose_mgdl"] = String(format: "%.0f", glucose) }

        // Mobility
        if let ws = ext.walkingSpeed {
            d["walking_speed_ms"] = String(format: "%.2f", ws)
            let baselineSpeed = 1.15
            let pct = ((ws - baselineSpeed) / baselineSpeed) * 100
            d["walking_speed_vs_7day_avg_pct"] = String(format: "%+.1f%%", pct)
        } else {
            d["walking_speed_vs_7day_avg_pct"] = "N/A"
        }
        if let wa = ext.walkingAsymmetry { d["walking_asymmetry_pct"] = String(format: "%.1f", wa) }
        if let wds = ext.walkingDoubleSupport { d["double_support_pct"] = String(format: "%.1f", wds) }
        if let wst = ext.walkingSteadiness { d["walking_steadiness_pct"] = String(format: "%.0f", wst) }
        if let smw = ext.sixMinuteWalkDistance { d["six_min_walk_m"] = "\(Int(smw))" }
        if let sas = ext.stairAscentSpeed { d["stair_ascent_speed_ms"] = String(format: "%.2f", sas) }

        // Activity
        if let ex = ext.exerciseMinutes { d["exercise_minutes"] = "\(ex)" }
        if let st = ext.standMinutes { d["stand_minutes"] = "\(st)" }
        if let fc = ext.flightsClimbed { d["flights_climbed"] = "\(fc)" }
        if let dist = ext.distanceKm { d["distance_km"] = String(format: "%.1f", dist) }

        // Environment
        if let env = ext.environmentalNoisedB { d["env_noise_db"] = String(format: "%.0f", env) }
        if let daylight = ext.timeInDaylight { d["daylight_minutes"] = "\(Int(daylight))" }

        // Nutrition
        if let water = ext.waterMl { d["water_ml"] = "\(Int(water))" }
        if let caff = ext.caffeineMg { d["caffeine_mg"] = "\(Int(caff))" }
        if let kcal = ext.dietaryEnergyKcal { d["dietary_energy_kcal"] = "\(Int(kcal))" }
        if let protein = ext.dietaryProteinG { d["dietary_protein_g"] = String(format: "%.0f", protein) }
        if let carbs = ext.dietaryCarbsG { d["dietary_carbs_g"] = String(format: "%.0f", carbs) }
        if let fat = ext.dietaryFatG { d["dietary_fat_g"] = String(format: "%.0f", fat) }

        // Temperature
        if let temp = ext.bodyTemperature { d["body_temp_c"] = String(format: "%.1f", temp) }

        // Wellness
        if let mindful = ext.mindfulMinutes { d["mindful_minutes"] = "\(Int(mindful))" }
        if let sbd = ext.sleepBreathingDisturbances { d["sleep_breathing_disturbances"] = "\(Int(sbd))" }

        return d
    }

    private func buildWorkoutsDict(_ workouts: [WorkoutSummary]) -> [String: String] {
        guard !workouts.isEmpty else {
            return ["note": "No workouts recorded today.", "count": "0"]
        }

        let totalKcal = workouts.compactMap(\.energyKilocalories).reduce(0, +)
        let totalDurationMin = workouts.map { Int($0.end.timeIntervalSince($0.start) / 60) }.reduce(0, +)
        let types = Set(workouts.map(\.activityName)).sorted().joined(separator: ", ")

        // Serialize each workout into a concise dict
        let workoutList: [[String: String]] = workouts.map { w in
            var d: [String: String] = [
                "type": w.activityName,
                "duration_min": "\(Int(w.end.timeIntervalSince(w.start) / 60))",
            ]
            if let kcal = w.energyKilocalories { d["calories"] = "\(Int(kcal))" }
            if let hr = w.averageHeartRate { d["avg_hr_bpm"] = "\(Int(hr))" }
            if let dist = w.distanceMeters { d["distance_m"] = String(format: "%.0f", dist) }
            return d
        }

        let encoder = JSONEncoder()
        let listJSON = (try? String(data: encoder.encode(workoutList), encoding: .utf8)) ?? "[]"

        return [
            "count": "\(workouts.count)",
            "types": types,
            "total_energy_kcal": "\(Int(totalKcal))",
            "total_duration_min": "\(totalDurationMin)",
            "list": listJSON
        ]
    }
}
