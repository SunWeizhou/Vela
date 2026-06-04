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
        strengthWorkouts: [StrengthWorkoutRecord] = [],
        trainingResponses: [TrainingResponseRecord] = [],
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
            ),
            strengthTraining: buildStrengthTrainingDict(
                strengthWorkouts,
                trainingResponses: trainingResponses,
                dashboard: dashboard,
                generatedAt: generatedAt
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
                "journal", "user_wiki", "extended_metrics", "strength_training"
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
        strengthWorkouts: [StrengthWorkoutRecord] = [],
        trainingResponses: [TrainingResponseRecord] = [],
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
            strengthTraining: buildTypedStrengthTraining(
                strengthWorkouts,
                trainingResponses: trainingResponses,
                dashboard: dashboard,
                generatedAt: generatedAt
            ),
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
            includedSections: ["recovery", "sleep", "strain", "stress", "energy_bank", "training", "nutrition", "extended_metrics", "strength_training"],
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

    private func buildStrengthTrainingDict(
        _ workouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        dashboard: DashboardSummary,
        generatedAt: Date
    ) -> [String: String] {
        let sevenDaysAgo = generatedAt.addingTimeInterval(-7 * 24 * 3600)
        let fourteenDaysAgo = generatedAt.addingTimeInterval(-14 * 24 * 3600)

        let workouts7d = workouts.filter { $0.startedAt >= sevenDaysAgo && $0.startedAt <= generatedAt }
        let workouts14d = workouts.filter { $0.startedAt >= fourteenDaysAgo && $0.startedAt <= generatedAt }

        let sessions7d = workouts7d.count
        
        var hardSets7d = 0
        var volume7dKg = 0.0
        var muscleGroupSets7d: [String: Int] = [
            "chest": 0, "back": 0, "legs": 0, "shoulders": 0, "arms": 0, "core": 0, "other": 0
        ]

        for workout in workouts7d {
            for exercise in workout.exercises {
                let muscleGroup = inferMuscleGroup(exerciseName: exercise.name)
                for set in exercise.sets {
                    if !set.isWarmup {
                        hardSets7d += 1
                        volume7dKg += Double(set.repetitions) * set.weightKilograms
                        muscleGroupSets7d[muscleGroup, default: 0] += 1
                    }
                }
            }
        }

        // Exercise progress in past 14 days
        var exerciseStats: [String: (sets: Int, maxWeight: Double, max1RM: Double)] = [:]
        for workout in workouts14d {
            for exercise in workout.exercises {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                
                var setsCount = 0
                var localMaxWeight = 0.0
                var localMax1RM = 0.0
                
                for set in exercise.sets {
                    if !set.isWarmup {
                        setsCount += 1
                        if set.weightKilograms > localMaxWeight {
                            localMaxWeight = set.weightKilograms
                        }
                        let epley1RM = set.weightKilograms * (1.0 + Double(set.repetitions) / 30.0)
                        if epley1RM > localMax1RM {
                            localMax1RM = epley1RM
                        }
                    }
                }
                
                if setsCount > 0 {
                    let current = exerciseStats[name] ?? (sets: 0, maxWeight: 0.0, max1RM: 0.0)
                    exerciseStats[name] = (
                        sets: current.sets + setsCount,
                        maxWeight: max(current.maxWeight, localMaxWeight),
                        max1RM: max(current.max1RM, localMax1RM)
                    )
                }
            }
        }

        let progressList = exerciseStats.map { (name, stats) in
            "\(name): \(stats.sets) sets, max \(stats.maxWeight)kg, peak 1RM \(String(format: "%.1f", stats.max1RM))kg"
        }.sorted().joined(separator: "\n")

        // Last session summary
        var lastSessionStr = "No strength training sessions logged in the past 14 days."
        if let lastSession = workouts.sorted(by: { $0.startedAt > $1.startedAt }).first {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateStr = formatter.string(from: lastSession.startedAt)
            
            let exerciseSummaries = lastSession.exercises.map { exercise in
                let workingSets = exercise.sets.filter { !$0.isWarmup }
                return "\(exercise.name) (\(workingSets.count) hard sets)"
            }.joined(separator: ", ")
            
            lastSessionStr = "\(lastSession.title) on \(dateStr): \(lastSession.exerciseCount) exercises (\(exerciseSummaries)), \(lastSession.totalSetCount) sets total, volume \(Int(lastSession.totalVolumeKilograms))kg."
        }

        let muscleGroupStr = muscleGroupSets7d
            .sorted(by: { $0.key < $1.key })
            .map { pair in "\(pair.key): \(pair.value) sets" }
            .joined(separator: ", ")

        let analytics = TrainingAnalyticsService()
        let recent7d = analytics.buildRecentSummary(workouts: workouts, days: 7, endingAt: generatedAt)
        let recent14d = analytics.buildRecentSummary(workouts: workouts, days: 14, endingAt: generatedAt)
        let adaptation = trainingAdaptation(dashboard: dashboard, localFatigue: recent7d.localFatigue)
        let response = trainingResponseSummary(trainingResponses, generatedAt: generatedAt)
        return [
            "sessions_7d": "\(sessions7d)",
            "sessions_14d": "\(recent14d.sessions)",
            "hard_sets_7d": "\(hardSets7d)",
            "hard_sets_14d": "\(recent14d.effectiveSets)",
            "volume_7d_kg": String(format: "%.1f", volume7dKg),
            "volume_14d_kg": String(format: "%.1f", recent14d.volumeKg),
            "muscle_groups_7d": muscleGroupStr,
            "muscle_groups_14d": formatMuscleGroups(recent14d.muscleGroupSets),
            "recent_prs": recent14d.recentPRs.map(\.summary).joined(separator: "\n"),
            "local_fatigue": formatFatigue(recent7d.localFatigue),
            "training_adaptation": adaptation.modifiedWorkoutDescription + " " + adaptation.reasons.joined(separator: " "),
            "recovery_response_summary": response.summary,
            "average_next_day_recovery_delta": response.averageNextDayRecoveryDelta.map { String(format: "%+.1f", $0) } ?? "N/A",
            "flagged_response_count": "\(response.flaggedCount)",
            "exercise_progress_14d": progressList.isEmpty ? "No exercise data." : progressList,
            "last_session_summary": lastSessionStr
        ]
    }

    private func buildTypedStrengthTraining(
        _ workouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        dashboard: DashboardSummary,
        generatedAt: Date
    ) -> StrengthTrainingContext {
        let sevenDaysAgo = generatedAt.addingTimeInterval(-7 * 24 * 3600)
        let fourteenDaysAgo = generatedAt.addingTimeInterval(-14 * 24 * 3600)

        let workouts7d = workouts.filter { $0.startedAt >= sevenDaysAgo && $0.startedAt <= generatedAt }
        let workouts14d = workouts.filter { $0.startedAt >= fourteenDaysAgo && $0.startedAt <= generatedAt }

        let sessions7d = workouts7d.count
        
        var hardSets7d = 0
        var volume7dKg = 0.0
        var muscleGroupSets7d: [String: Int] = [
            "chest": 0, "back": 0, "legs": 0, "shoulders": 0, "arms": 0, "core": 0, "other": 0
        ]

        for workout in workouts7d {
            for exercise in workout.exercises {
                let muscleGroup = inferMuscleGroup(exerciseName: exercise.name)
                for set in exercise.sets {
                    if !set.isWarmup {
                        hardSets7d += 1
                        volume7dKg += Double(set.repetitions) * set.weightKilograms
                        muscleGroupSets7d[muscleGroup, default: 0] += 1
                    }
                }
            }
        }

        // Exercise progress in past 14 days
        var exerciseStats: [String: (sets: Int, maxWeight: Double, max1RM: Double)] = [:]
        for workout in workouts14d {
            for exercise in workout.exercises {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                
                var setsCount = 0
                var localMaxWeight = 0.0
                var localMax1RM = 0.0
                
                for set in exercise.sets {
                    if !set.isWarmup {
                        setsCount += 1
                        if set.weightKilograms > localMaxWeight {
                            localMaxWeight = set.weightKilograms
                        }
                        let epley1RM = set.weightKilograms * (1.0 + Double(set.repetitions) / 30.0)
                        if epley1RM > localMax1RM {
                            localMax1RM = epley1RM
                        }
                    }
                }
                
                if setsCount > 0 {
                    let current = exerciseStats[name] ?? (sets: 0, maxWeight: 0.0, max1RM: 0.0)
                    exerciseStats[name] = (
                        sets: current.sets + setsCount,
                        maxWeight: max(current.maxWeight, localMaxWeight),
                        max1RM: max(current.max1RM, localMax1RM)
                    )
                }
            }
        }

        let progressList = exerciseStats.map { (name, stats) in
            ExerciseProgressSummary(
                exerciseName: name,
                setsCount: stats.sets,
                maxWeightKg: stats.maxWeight,
                estimated1RMPeakKg: stats.max1RM
            )
        }.sorted(by: { $0.exerciseName < $1.exerciseName })

        // Last session summary
        var lastSessionStr = "No strength training sessions logged in the past 14 days."
        if let lastSession = workouts.sorted(by: { $0.startedAt > $1.startedAt }).first {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateStr = formatter.string(from: lastSession.startedAt)
            
            let exerciseSummaries = lastSession.exercises.map { exercise in
                let workingSets = exercise.sets.filter { !$0.isWarmup }
                return "\(exercise.name) (\(workingSets.count) hard sets)"
            }.joined(separator: ", ")
            
            lastSessionStr = "\(lastSession.title) on \(dateStr): \(lastSession.exerciseCount) exercises (\(exerciseSummaries)), \(lastSession.totalSetCount) sets total, volume \(Int(lastSession.totalVolumeKilograms))kg."
        }

        let analytics = TrainingAnalyticsService()
        let recent7d = analytics.buildRecentSummary(workouts: workouts, days: 7, endingAt: generatedAt)
        let recent14d = analytics.buildRecentSummary(workouts: workouts, days: 14, endingAt: generatedAt)
        let adaptation = trainingAdaptation(dashboard: dashboard, localFatigue: recent7d.localFatigue)
        let response = trainingResponseSummary(trainingResponses, generatedAt: generatedAt)
        return StrengthTrainingContext(
            sessions7d: sessions7d,
            sessions14d: recent14d.sessions,
            hardSets7d: hardSets7d,
            hardSets14d: recent14d.effectiveSets,
            volume7dKg: volume7dKg,
            volume14dKg: recent14d.volumeKg,
            muscleGroupSets7d: muscleGroupSets7d,
            muscleGroupSets14d: recent14d.muscleGroupSets,
            recentPRs: recent14d.recentPRs.map(\.summary),
            localFatigue: recent7d.localFatigue,
            recentExerciseProgress: progressList,
            lastSessionSummary: lastSessionStr,
            trainingAdaptation: adaptation.modifiedWorkoutDescription + " " + adaptation.reasons.joined(separator: " "),
            recoveryResponseSummary: response.summary,
            averageNextDayRecoveryDelta: response.averageNextDayRecoveryDelta,
            flaggedResponseCount: response.flaggedCount
        )
    }

    private func trainingAdaptation(
        dashboard: DashboardSummary,
        localFatigue: [String: LocalMuscleFatigue]
    ) -> TrainingAdaptationRecommendation {
        RecoveryTrainingAdapter().adapt(input: RecoveryTrainingInput(
            recoveryScore: dashboard.recovery.score,
            sleepScore: dashboard.sleepScore.score,
            hrvZScore: dashboard.recovery.metrics["hrv_z_score"],
            restingHRZScore: dashboard.recovery.metrics["rhr_z_score"],
            tsb: dashboard.energy.metrics["tsb"],
            energyScore: dashboard.energy.currentEnergy,
            localFatigue: localFatigue
        ))
    }

    private func formatMuscleGroups(_ values: [String: Int]) -> String {
        values.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value) sets" }.joined(separator: ", ")
    }

    private func formatFatigue(_ values: [String: LocalMuscleFatigue]) -> String {
        values.values.sorted { $0.muscleGroup < $1.muscleGroup }.map {
            "\($0.muscleGroup): \($0.fatigueLevel), \($0.setsLast48h) sets/48h, \($0.setsLast7d) sets/7d"
        }.joined(separator: "\n")
    }

    private func trainingResponseSummary(
        _ responses: [TrainingResponseRecord],
        generatedAt: Date
    ) -> (summary: String, averageNextDayRecoveryDelta: Double?, flaggedCount: Int) {
        let start = generatedAt.addingTimeInterval(-28 * 86_400)
        let recent = responses.filter { $0.date >= start && $0.date <= generatedAt }
        guard !recent.isEmpty else {
            return ("No post-training recovery response records in the past 28 days.", nil, 0)
        }

        let recoveryDeltas = recent.compactMap(\.nextDayRecoveryDelta)
        let averageRecoveryDelta = recoveryDeltas.isEmpty ? nil : recoveryDeltas.reduce(0, +) / Double(recoveryDeltas.count)
        let flagged = recent.filter { response in
            (response.nextDayRecoveryDelta ?? 0) <= -8
                || (response.nextDayHRVDelta ?? 0) <= -10
                || (response.nextDayRHRDelta ?? 0) >= 5
        }
        let hardest = recent.max { lhs, rhs in
            let lhsScore = (lhs.sessionRPE ?? 0) * 10 + Double(lhs.totalEffectiveSets)
            let rhsScore = (rhs.sessionRPE ?? 0) * 10 + Double(rhs.totalEffectiveSets)
            return lhsScore < rhsScore
        }

        let summary: String
        if let averageRecoveryDelta {
            summary = "Past 28d post-training response: average next-day recovery \(String(format: "%+.1f", averageRecoveryDelta)) pts across \(recent.count) captured sessions; \(flagged.count) sessions showed a notable recovery cost. Hardest captured session: \(hardest?.primaryMuscleGroups.joined(separator: ", ") ?? "unknown focus"), \(hardest?.totalEffectiveSets ?? 0) effective sets."
        } else {
            summary = "Past 28d post-training response: \(recent.count) sessions captured, but next-day recovery deltas are not available yet."
        }
        return (summary, averageRecoveryDelta, flagged.count)
    }

    private func inferMuscleGroup(exerciseName: String) -> String {
        let name = exerciseName.lowercased()
        if name.contains("bench") || name.contains("chest") || name.contains("fly") || name.contains("pushup") || name.contains("pec") || name.contains("incline press") || name.contains("decline press") {
            return "chest"
        }
        if name.contains("row") || name.contains("pullup") || name.contains("pulldown") || name.contains("deadlift") || name.contains("lats") || name.contains("chinup") || name.contains("shrug") || name.contains("back") {
            return "back"
        }
        if name.contains("squat") || name.contains("lunge") || name.contains("leg press") || name.contains("leg curl") || name.contains("leg extension") || name.contains("calf") || name.contains("quad") || name.contains("hamstring") || name.contains("glute") || name.contains("hip thrust") || name.contains("thigh") {
            return "legs"
        }
        if name.contains("shoulder") || name.contains("overhead") || name.contains("lateral raise") || name.contains("delt") || name.contains("military press") || name.contains("arnold press") {
            return "shoulders"
        }
        if name.contains("bicep") || name.contains("tricep") || name.contains("curl") || name.contains("dip") || name.contains("arm") {
            return "arms"
        }
        if name.contains("abs") || name.contains("plank") || name.contains("crunch") || name.contains("situp") || name.contains("sit-up") || name.contains("oblique") || name.contains("twist") || name.contains("abdominal") || name.contains("core") {
            return "core"
        }
        return "other"
    }
}
