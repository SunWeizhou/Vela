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
        workoutEvents: [WorkoutEventRecord] = [],
        strengthWorkouts: [StrengthWorkoutRecord] = [],
        trainingResponses: [TrainingResponseRecord] = [],
        onboardingState: OnboardingState? = nil,
        bodyModelState: BodyModelState? = nil,
        bodyState: BodyState? = nil,
        generatedAt: Date = Date()
    ) -> (envelope: AgentContextEnvelope, metadata: ContextSnapshotMetadata) {
        let mergedUserWiki = Self.mergedUserWiki(userWiki, onboardingState: onboardingState, bodyModelState: bodyModelState)
        let resolvedBodyState = bodyState ?? BodyStateKernel().build(input: BodyStateInput(
            dashboard: dashboard,
            workoutEvents: workoutEvents,
            strengthWorkouts: strengthWorkouts,
            trainingResponses: trainingResponses,
            foodLogs: foodLogs,
            generatedAt: generatedAt
        ))
        let envelope = AgentContextEnvelope(
            metadata: AgentContextMetadata(generatedAt: generatedAt, contextWindow: "today"),
            todaySummary: [
                "date": dashboard.date.formatted(date: .numeric, time: .omitted),
                "overall_state": dashboard.recovery.hasData ? dashboard.recovery.band.rawValue.lowercased() : "unavailable",
                "source": dashboard.source.rawValue,
                "top_reason": dashboard.recovery.reasons.first ?? dashboard.dailyInsight,
                "readiness_level": dashboard.trainingDecision.readinessLevel,
                "readiness_guidance": dashboard.trainingDecision.readinessGuidance
            ],
            bodyState: [
                "readiness": resolvedBodyState.readiness.rawValue,
                "confidence": resolvedBodyState.confidence.rawValue,
                "freshness": resolvedBodyState.freshness.rawValue,
                "source": resolvedBodyState.source,
                "context_hash": resolvedBodyState.hash,
                "drivers": resolvedBodyState.drivers.map { "\($0.title): \($0.detail)" }.joined(separator: " | "),
                "safety": "General wellness guidance only; not a medical diagnosis."
            ],
            sleep: SleepContextBuilder().build(from: dashboard),
            recovery: RecoveryContextBuilder().build(from: dashboard),
            strain: StrainContextBuilder().build(from: dashboard),
            workouts: WorkoutsContextBuilder().build(from: dashboard.workouts),
            unifiedWorkouts: buildUnifiedWorkoutDict(workoutEvents, generatedAt: generatedAt),
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
            userWiki: mergedUserWiki,
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
                "today_summary", "body_state", "sleep", "recovery", "strain", "workouts",
                "unified_workouts", "stress", "energy_bank", "health_age_trend", "nutrition",
                "journal", "user_wiki", "extended_metrics", "strength_training"
            ] + (onboardingState == nil ? [] : ["body_model_profile"])
                + (bodyModelState == nil ? [] : ["body_model_state"]),
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
        workoutEvents: [WorkoutEventRecord] = [],
        strengthWorkouts: [StrengthWorkoutRecord] = [],
        trainingResponses: [TrainingResponseRecord] = [],
        onboardingState: OnboardingState? = nil,
        bodyModelState: BodyModelState? = nil,
        generatedAt: Date = Date()
    ) -> (context: TypedAgentContext, metadata: ContextSnapshotMetadata) {
        let mergedUserWiki = Self.mergedUserWiki(userWiki, onboardingState: onboardingState, bodyModelState: bodyModelState)
        let hrvMs = dashboard.recoveryMetrics.hrvMilliseconds
        let rhrBpm = dashboard.recoveryMetrics.restingHeartRate

        func healthMetric<T: Codable & Hashable>(
            _ value: T?,
            unit: String,
            note: String
        ) -> MetricValue<T> {
            guard let value else { return .missing(unit: unit, note: note) }
            return .live(value, unit: unit)
        }

        let recovery = RecoveryContext(
            score: healthMetric(dashboard.recovery.hasData ? dashboard.recovery.value : nil, unit: "pts", note: "Recovery score is not computed yet."),
            band: dashboard.recovery.hasData ? dashboard.recovery.band.rawValue : "unavailable",
            hrv: healthMetric(hrvMs, unit: "ms", note: "HRV is unavailable."),
            restingHeartRate: healthMetric(rhrBpm, unit: "bpm", note: "Resting heart rate is unavailable."),
            respiratoryRate: healthMetric(dashboard.recoveryMetrics.respiratoryRate, unit: "br/min", note: "Respiratory rate is unavailable."),
            topReason: dashboard.recovery.reasons.first
        )

        let sleepMetrics = dashboard.sleepScore.metrics
        let sleep = SleepContext(
            score: healthMetric(dashboard.sleepScore.hasData ? dashboard.sleepScore.value : nil, unit: "pts", note: "Sleep score is not computed yet."),
            band: dashboard.sleepScore.hasData ? dashboard.sleepScore.band.rawValue : "unavailable",
            totalMinutes: healthMetric(dashboard.sleepScore.hasData ? dashboard.sleepSummary.totalSleepMinutes : nil, unit: "min", note: "Sleep duration is unavailable."),
            efficiency: healthMetric(sleepMetrics["sleep_efficiency"], unit: "%", note: "Sleep efficiency is unavailable."),
            remPercent: healthMetric(sleepMetrics["rem_pct"], unit: "%", note: "REM sleep percentage is unavailable."),
            deepPercent: healthMetric(sleepMetrics["deep_pct"], unit: "%", note: "Deep sleep percentage is unavailable."),
            coreMinutes: healthMetric(dashboard.sleepSummary.stageMinutes[.core], unit: "min", note: "Core sleep duration is unavailable."),
            remMinutes: healthMetric(dashboard.sleepSummary.stageMinutes[.rem], unit: "min", note: "REM sleep duration is unavailable."),
            deepMinutes: healthMetric(dashboard.sleepSummary.stageMinutes[.deep], unit: "min", note: "Deep sleep duration is unavailable."),
            awakeMinutes: healthMetric(dashboard.sleepSummary.stageMinutes[.awake], unit: "min", note: "Awake duration is unavailable."),
            bedtime: dashboard.sleepSummary.bedtime,
            wakeTime: dashboard.sleepSummary.wakeTime,
            topReason: dashboard.sleepScore.reasons.first
        )

        let strain = StrainContext(
            score: healthMetric(dashboard.strain.hasData ? dashboard.strain.value : nil, unit: "pts", note: "Strain score is not computed yet."),
            band: dashboard.strain.hasData ? dashboard.strain.band.rawValue : "unavailable",
            targetStatus: dashboard.strain.hasData ? dashboard.strain.targetStatus.rawValue : "unavailable",
            recommendedRangeLower: dashboard.strain.recommendedRange.lowerBound,
            recommendedRangeUpper: dashboard.strain.recommendedRange.upperBound,
            steps: healthMetric(dashboard.strain.metrics["steps_raw"].map(Int.init), unit: "steps", note: "Step count is unavailable."),
            activeEnergyKcal: healthMetric(dashboard.strain.metrics["active_energy_raw"].map(Int.init), unit: "kcal", note: "Active energy is unavailable."),
            exerciseMinutes: healthMetric(dashboard.strain.metrics["exercise_minutes_raw"].map(Int.init), unit: "min", note: "Exercise duration is unavailable.")
        )

        let stress = StressContext(
            stressIndex: healthMetric(dashboard.stress.hasData ? dashboard.stress.value : nil, unit: "index", note: "Stress index is not computed yet."),
            band: dashboard.stress.hasData ? dashboard.stress.band.rawValue : "unavailable",
            confidence: dashboard.stress.hasData ? (dashboard.stress.confidence.rawValue == "high" ? .high : .medium) : .unavailable,
            proxyNote: "Physiological proxy, not a medical or mental health diagnosis."
        )

        let energyBank = EnergyBankContext(
            morningEnergy: healthMetric(dashboard.energy.hasData ? dashboard.energy.morningEnergy : nil, unit: "pts", note: "Morning energy is unavailable."),
            currentEnergy: healthMetric(dashboard.energy.hasData ? dashboard.energy.value : nil, unit: "pts", note: "Current energy is unavailable."),
            status: dashboard.energy.hasData ? dashboard.energy.status.rawValue : "unavailable",
            chargeEfficiency: healthMetric(dashboard.energy.metrics["charge_efficiency"], unit: "ratio", note: "Charge efficiency is unavailable."),
            atl7Day: healthMetric(dashboard.energy.metrics["atl"], unit: "AU", note: "Acute training load is unavailable."),
            ctl42Day: healthMetric(dashboard.energy.metrics["ctl"], unit: "AU", note: "Chronic training load is unavailable."),
            tsbFreshness: healthMetric(dashboard.energy.metrics["tsb"], unit: "AU", note: "Training stress balance is unavailable.")
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
            userWiki: mergedUserWiki
        )

        let contextJSON = (try? String(data: JSONEncoder().encode(context), encoding: .utf8)) ?? "{}"
        let hash = ContentHash.hash(contextJSON)
        var withHash = context
        withHash.contextHash = hash

        let metadata = ContextSnapshotMetadata(
            schemaVersion: AIContextBuilder.schemaVersion,
            generatedAt: generatedAt,
            hash: hash,
            includedSections: ["recovery", "sleep", "strain", "stress", "energy_bank", "training", "nutrition", "extended_metrics", "strength_training"]
                + (onboardingState == nil ? [] : ["body_model_profile"])
                + (bodyModelState == nil ? [] : ["body_model_state"]),
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

    private func buildUnifiedWorkoutDict(
        _ events: [WorkoutEventRecord],
        generatedAt: Date
    ) -> [String: String] {
        let sorted = events.sorted { $0.startedAt > $1.startedAt }
        let sevenDaysAgo = generatedAt.addingTimeInterval(-7 * 24 * 3600)
        let fourteenDaysAgo = generatedAt.addingTimeInterval(-14 * 24 * 3600)
        let twentyEightDaysAgo = generatedAt.addingTimeInterval(-28 * 24 * 3600)
        let recent7d = sorted.filter { $0.startedAt >= sevenDaysAgo && $0.startedAt <= generatedAt }
        let recent14d = sorted.filter { $0.startedAt >= fourteenDaysAgo && $0.startedAt <= generatedAt }
        let recent28d = sorted.filter { $0.startedAt >= twentyEightDaysAgo && $0.startedAt <= generatedAt }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let entries = sorted.prefix(12).map { UnifiedWorkoutContextEntry(event: $0) }
        let encodedEntries = (try? encoder.encode(entries))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

        return [
            "algorithm_version": "workoutEvents.v1",
            "source": "WorkoutEventRecord unified Apple Watch / HealthKit / Xunji / manual workout timeline",
            "confidence": sorted.isEmpty ? "unavailable" : "medium",
            "note": sorted.isEmpty
                ? "No unified workout history available yet."
                : "Use this as the primary workout timeline. Strength details may be linked through linked_strength_workout_id.",
            "sessions_7d": "\(recent7d.count)",
            "sessions_14d": "\(recent14d.count)",
            "sessions_28d": "\(recent28d.count)",
            "duration_7d_min": String(format: "%.0f", recent7d.reduce(0) { $0 + $1.durationMinutes }),
            "duration_14d_min": String(format: "%.0f", recent14d.reduce(0) { $0 + $1.durationMinutes }),
            "energy_14d_kcal": String(format: "%.0f", recent14d.compactMap(\.energyKilocalories).reduce(0, +)),
            "activity_types_14d": formatWorkoutActivityTypes(recent14d),
            "source_mix_14d": formatWorkoutSourceMix(recent14d),
            "recent_workout_events_json": encodedEntries
        ]
    }

    private func formatWorkoutActivityTypes(_ events: [WorkoutEventRecord]) -> String {
        guard !events.isEmpty else { return "None" }
        let counts = Dictionary(grouping: events, by: { workoutDisplayType($0) })
            .mapValues(\.count)
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    private func formatWorkoutSourceMix(_ events: [WorkoutEventRecord]) -> String {
        guard !events.isEmpty else { return "None" }
        let counts = Dictionary(grouping: events, by: \.source)
            .mapValues(\.count)
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
    }

    private func workoutDisplayType(_ event: WorkoutEventRecord) -> String {
        if !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return event.title
        }
        return event.activityType
    }

    private func buildStrengthTrainingDict(
        _ workouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        dashboard: DashboardSummary,
        generatedAt: Date
    ) -> [String: String] {
        // Algorithm v1/trainingAnalytics: strength context derives from TrainingAnalyticsService so
        // effective-set counting, muscle naming, fatigue and PR detection use one shared source of truth.
        let analytics = TrainingAnalyticsService()
        let recent7d = analytics.buildRecentSummary(workouts: workouts, days: 7, endingAt: generatedAt)
        let recent14d = analytics.buildRecentSummary(workouts: workouts, days: 14, endingAt: generatedAt)
        let adaptation = trainingAdaptationSummary(dashboard: dashboard)
        let response = trainingResponseSummary(trainingResponses, generatedAt: generatedAt)
        let progressList = exerciseProgressSummaries(workouts: workouts, generatedAt: generatedAt)
            .map {
                "\($0.exerciseName): \($0.setsCount) sets, max \($0.maxWeightKg)kg, peak 1RM \(String(format: "%.1f", $0.estimated1RMPeakKg))kg"
            }
            .sorted()
            .joined(separator: "\n")

        return [
            "algorithm_version": "trainingAnalytics.v1",
            "source": "StrengthWorkoutRecord + TrainingResponseRecord via TrainingAnalyticsService",
            "confidence": workouts.isEmpty ? "unavailable" : "medium",
            "note": workouts.isEmpty ? "No strength training data available yet." : "Strength context uses unified TrainingAnalyticsService muscle groups and effective-set rules.",
            "sessions_7d": "\(recent7d.sessions)",
            "sessions_14d": "\(recent14d.sessions)",
            "hard_sets_7d": "\(recent7d.effectiveSets)",
            "hard_sets_14d": "\(recent14d.effectiveSets)",
            "volume_7d_kg": String(format: "%.1f", recent7d.volumeKg),
            "volume_14d_kg": String(format: "%.1f", recent14d.volumeKg),
            "muscle_groups_7d": formatMuscleGroups(recent7d.muscleGroupSets),
            "muscle_groups_14d": formatMuscleGroups(recent14d.muscleGroupSets),
            "recent_prs": recent14d.recentPRs.map(\.summary).joined(separator: "\n"),
            "local_fatigue": formatFatigue(recent7d.localFatigue),
            "training_adaptation": adaptation,
            "recovery_response_summary": response.summary,
            "average_next_day_recovery_delta": response.averageNextDayRecoveryDelta.map { String(format: "%+.1f", $0) } ?? "N/A",
            "flagged_response_count": "\(response.flaggedCount)",
            "exercise_progress_14d": progressList.isEmpty ? "No exercise data." : progressList,
            "last_session_summary": recent14d.lastWorkoutSummary ?? "No strength training sessions logged in the past 14 days.",
            "recent_workout_details": formatRecentWorkoutDetails(workouts)
        ]
    }

    private func buildTypedStrengthTraining(
        _ workouts: [StrengthWorkoutRecord],
        trainingResponses: [TrainingResponseRecord],
        dashboard: DashboardSummary,
        generatedAt: Date
    ) -> StrengthTrainingContext {
        let analytics = TrainingAnalyticsService()
        let recent7d = analytics.buildRecentSummary(workouts: workouts, days: 7, endingAt: generatedAt)
        let recent14d = analytics.buildRecentSummary(workouts: workouts, days: 14, endingAt: generatedAt)
        let adaptation = trainingAdaptationSummary(dashboard: dashboard)
        let response = trainingResponseSummary(trainingResponses, generatedAt: generatedAt)
        return StrengthTrainingContext(
            sessions7d: recent7d.sessions,
            sessions14d: recent14d.sessions,
            hardSets7d: recent7d.effectiveSets,
            hardSets14d: recent14d.effectiveSets,
            volume7dKg: recent7d.volumeKg,
            volume14dKg: recent14d.volumeKg,
            muscleGroupSets7d: recent7d.muscleGroupSets,
            muscleGroupSets14d: recent14d.muscleGroupSets,
            recentPRs: recent14d.recentPRs.map(\.summary),
            localFatigue: recent7d.localFatigue,
            recentExerciseProgress: exerciseProgressSummaries(workouts: workouts, generatedAt: generatedAt),
            lastSessionSummary: recent14d.lastWorkoutSummary ?? "No strength training sessions logged in the past 14 days.",
            trainingAdaptation: adaptation,
            recoveryResponseSummary: response.summary,
            averageNextDayRecoveryDelta: response.averageNextDayRecoveryDelta,
            flaggedResponseCount: response.flaggedCount,
            recentWorkoutDetails: formatRecentWorkoutDetails(workouts)
        )
    }

    private func formatRecentWorkoutDetails(_ workouts: [StrengthWorkoutRecord]) -> String {
        let isZH = AppLanguage.stored.isChinese
        guard !workouts.isEmpty else {
            return isZH ? "近期无力量训练记录。" : "No recent strength workouts logged."
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        var result = ""
        for workout in workouts {
            let dateStr = dateFormatter.string(from: workout.startedAt)
            result += "### \(workout.title) (\(dateStr) · \(workout.durationMinutes) \(isZH ? "分钟" : "min"))\n"
            if !workout.notes.isEmpty {
                result += "\(isZH ? "备注" : "Notes"): \(workout.notes)\n"
            }
            if workout.exercises.isEmpty {
                result += isZH ? "本次训练未记录动作。\n" : "No exercises logged in this session.\n"
            } else {
                for exercise in workout.exercises {
                    let completedWorkSets = exercise.sets.filter { !$0.isWarmup && $0.isCompleted != false }
                    let warmupSets = exercise.sets.filter { $0.isWarmup && $0.isCompleted != false }
                    let uncompletedSets = exercise.sets.filter { $0.isCompleted == false }
                    result += "- \(exercise.name) (\(exercise.equipment)): \(completedWorkSets.count) \(isZH ? "完成工作组" : "completed work sets")"
                    if !uncompletedSets.isEmpty {
                        result += ", \(uncompletedSets.count) \(isZH ? "未完成组未计入容量" : "uncompleted sets excluded")"
                    }
                    result += "\n"
                    for (index, set) in completedWorkSets.enumerated() {
                        let rpeStr = set.rpe.map { " RPE \($0)" } ?? ""
                        result += "  * \(isZH ? "完成组" : "Completed set") \(index + 1): \(set.weightKilograms)kg x \(set.repetitions)\(isZH ? "次" : "reps")\(rpeStr)\n"
                    }
                    if !warmupSets.isEmpty {
                        result += "  * \(isZH ? "热身组" : "Warmup sets"): \(warmupSets.count) \(isZH ? "组，未计入工作容量" : "sets, excluded from work volume")\n"
                    }
                }
            }
            result += "\n"
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func exerciseProgressSummaries(
        workouts: [StrengthWorkoutRecord],
        generatedAt: Date
    ) -> [ExerciseProgressSummary] {
        let fourteenDaysAgo = generatedAt.addingTimeInterval(-14 * 24 * 3600)
        let workouts14d = workouts.filter { $0.startedAt >= fourteenDaysAgo && $0.startedAt <= generatedAt }
        var exerciseStats: [String: (sets: Int, maxWeight: Double, max1RM: Double)] = [:]

        for workout in workouts14d {
            for exercise in workout.exercises {
                let name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }

                var setsCount = 0
                var localMaxWeight = 0.0
                var localMax1RM = 0.0

                for set in exercise.sets where !set.isWarmup && set.isCompleted == true {
                    setsCount += 1
                    localMaxWeight = max(localMaxWeight, set.weightKilograms)
                    let epley1RM = set.weightKilograms * (1.0 + Double(set.repetitions) / 30.0)
                    localMax1RM = max(localMax1RM, epley1RM)
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

        return exerciseStats.map { name, stats in
            ExerciseProgressSummary(
                exerciseName: name,
                setsCount: stats.sets,
                maxWeightKg: stats.maxWeight,
                estimated1RMPeakKg: stats.max1RM
            )
        }.sorted(by: { $0.exerciseName < $1.exerciseName })
    }

    private func trainingAdaptationSummary(dashboard: DashboardSummary) -> String {
        let decision = dashboard.trainingDecision
        return [
            decision.body,
            "\(Int((decision.volumeMultiplier * 100).rounded()))% volume.",
            "\(decision.maxIntensity) cap.",
            decision.whyThis
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
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

    private static func mergedUserWiki(
        _ userWiki: [String: String],
        onboardingState: OnboardingState?,
        bodyModelState: BodyModelState? = nil
    ) -> [String: String] {
        var result = userWiki
        if let onboardingState {
            let goal = onboardingState.goalProfile
            let training = onboardingState.trainingPreference
            let equipment = onboardingState.equipmentProfile
            let coaching = onboardingState.coachingPreference
            let snapshot = onboardingState.initialBodySnapshot

            result["body_model.primary_goal"] = goal.primaryGoal
            result["body_model.secondary_goals"] = goal.secondaryGoals.joined(separator: ", ")
            result["body_model.experience_level"] = goal.experienceLevel
            result["body_model.body_concerns"] = goal.bodyConcerns.joined(separator: ", ")
            result["body_model.training_style"] = training.trainingStyle
            result["body_model.weekly_training_days"] = "\(training.weeklyTrainingDays)"
            result["body_model.session_duration_minutes"] = "\(training.sessionDurationMinutes)"
            result["body_model.preferred_days"] = training.preferredTrainingDays.joined(separator: ", ")
            result["body_model.equipment"] = equipment.equipment.joined(separator: ", ")
            result["body_model.schedule_notes"] = equipment.scheduleNotes
            result["body_model.coach_style"] = coaching.style
            result["body_model.explanation_depth"] = coaching.explanationDepth
            result["body_model.language"] = coaching.language
            result["body_model.initial_confidence"] = snapshot.dataConfidence.rawValue
            result["body_model.missing_data"] = snapshot.missingData.joined(separator: ", ")
            result["body_model.first_brief"] = onboardingState.firstBrief
            result["body_model.first_action_plan"] = onboardingState.firstActionPlan.joined(separator: " | ")
        }
        if let bodyModelState {
            result["body_model.maturity"] = bodyModelState.maturity.overall.rawValue
            result["body_model.baseline_days"] = "\(bodyModelState.maturity.baselineDays)"
            result["body_model.behavior_pairs"] = "\(bodyModelState.maturity.behaviorPairs)"
            result["body_model.training_sessions"] = "\(bodyModelState.maturity.trainingSessions)"
            result["body_model.claims"] = bodyModelState.claims.map {
                "\($0.title): \($0.summary) [\($0.confidence.rawValue), n=\($0.evidenceCount)]"
            }.joined(separator: " | ")
            result["body_model.uncertain_areas"] = bodyModelState.uncertainAreas.map(\.id).joined(separator: ", ")
            result["body_model.training_pattern_summary"] = bodyModelState.trainingPatternSummary
            result["body_model.coach_rules"] = bodyModelState.coachRules.joined(separator: " | ")
        }
        return result
    }

}
