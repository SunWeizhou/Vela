import Foundation

/// Each domain provides its own AI context mapping.
/// Add a new builder when adding a new health domain — AIContextBuilder stays unchanged.
protocol DomainContextBuilder {
    /// Returns a [String: String] dict ready for the LLM context envelope.
    func build(from dashboard: DashboardSummary) -> [String: String]
}

// MARK: - Sleep Context

struct SleepContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        let metrics = dashboard.sleepScore.metrics
        return [
            "sleep_score": dashboard.sleepScore.score.formatted(.number.precision(.fractionLength(0))),
            "duration_minutes": "\(dashboard.sleepSummary.totalSleepMinutes)",
            "band": dashboard.sleepScore.band.rawValue,
            "reason": dashboard.sleepScore.reasons.first ?? "",
            "rem_minutes": "\(dashboard.sleepSummary.stageMinutes[.rem] ?? 0)",
            "deep_minutes": "\(dashboard.sleepSummary.stageMinutes[.deep] ?? 0)",
            "core_minutes": "\(dashboard.sleepSummary.stageMinutes[.core] ?? 0)",
            "awake_minutes": "\(dashboard.sleepSummary.stageMinutes[.awake] ?? 0)",
            "sleep_efficiency_pct": metrics["sleep_efficiency"].map { String(format: "%.1f%%", $0) } ?? "N/A",
            "rem_pct": metrics["rem_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A",
            "deep_pct": metrics["deep_pct"].map { String(format: "%.1f%%", $0) } ?? "N/A"
        ]
    }
}

// MARK: - Recovery Context

struct RecoveryContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        let hrvToday = dashboard.recoveryMetrics.hrvMilliseconds
        let hrvBaseline = dashboard.recoveryBaseline.hrvMilliseconds
        let hrvVsBaselinePct: String = {
            if let t = hrvToday, let b = hrvBaseline, b > 0 {
                return String(format: "%+.1f%%", ((t - b) / b) * 100)
            }
            return "N/A"
        }()
        let hrvZ = dashboard.recovery.metrics["hrv_z_score"].map { String(format: "%.2f", $0) } ?? "N/A"

        return [
            "score": dashboard.recovery.score.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.recovery.band.rawValue,
            "confidence": dashboard.recovery.confidence.rawValue,
            "reason": dashboard.recovery.reasons.first ?? "",
            "hrv_ms": hrvToday.map { "\(Int($0))" } ?? "N/A",
            "rhr_bpm": dashboard.recoveryMetrics.restingHeartRate.map { "\(Int($0))" } ?? "N/A",
            "respiratory_rate": dashboard.recoveryMetrics.respiratoryRate.map { String(format: "%.1f", $0) } ?? "N/A",
            "hrv_z_score": hrvZ,
            "hrv_vs_baseline_pct": hrvVsBaselinePct,
            "hrv_baseline_ms": hrvBaseline.map { "\(Int($0))" } ?? "N/A",
            "rhr_baseline_bpm": dashboard.recoveryBaseline.restingHeartRate.map { "\(Int($0))" } ?? "N/A"
        ]
    }
}

// MARK: - Strain Context

struct StrainContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "score": dashboard.strain.score.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.strain.band.rawValue,
            "target_status": dashboard.strain.targetStatus.rawValue,
            "recommended_range": "\(dashboard.strain.recommendedRange.lowerBound)-\(dashboard.strain.recommendedRange.upperBound)",
            "steps": dashboard.strain.metrics["steps_raw"].map { "\(Int($0))" } ?? "N/A",
            "active_energy_kcal": dashboard.strain.metrics["active_energy_raw"].map { "\(Int($0))" } ?? "N/A",
            "exercise_minutes": dashboard.strain.metrics["exercise_minutes_raw"].map { "\(Int($0))" } ?? "N/A"
        ]
    }
}

// MARK: - Stress Context

struct StressContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "stress_index": dashboard.stress.stressIndex.formatted(.number.precision(.fractionLength(0))),
            "band": dashboard.stress.band.rawValue,
            "confidence": dashboard.stress.confidence.rawValue,
            "proxy_notice": "Stress is a physiological proxy, not a medical or mental health diagnosis."
        ]
    }
}

// MARK: - Energy Bank Context

struct EnergyBankContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "morning_energy": dashboard.energy.morningEnergy.formatted(.number.precision(.fractionLength(0))),
            "current_energy": dashboard.energy.currentEnergy.formatted(.number.precision(.fractionLength(0))),
            "status": dashboard.energy.status.rawValue,
            "charge_efficiency": dashboard.energy.metrics["charge_efficiency"].map { String(format: "%.0f%%", $0 * 100) } ?? "N/A",
            "atl_7day": dashboard.energy.metrics["atl"].map { String(format: "%.0f", $0) } ?? "N/A",
            "ctl_42day": dashboard.energy.metrics["ctl"].map { String(format: "%.0f", $0) } ?? "N/A",
            "tsb_freshness": dashboard.energy.metrics["tsb"].map { String(format: "%+.0f", $0) } ?? "N/A",
            "acwr_ratio": dashboard.energy.metrics["acwr"].map { String(format: "%.2f", $0) } ?? "N/A"
        ]
    }
}

// MARK: - Health Age Context

struct HealthAgeContextBuilder: DomainContextBuilder {
    func build(from dashboard: DashboardSummary) -> [String: String] {
        [
            "trend": dashboard.healthAge.label.rawValue,
            "trend_score": dashboard.healthAge.trendScore.formatted(.number.precision(.fractionLength(2))),
            "beta_notice": "Health Age Trend is beta and does not claim biological age."
        ]
    }
}

// MARK: - Workouts Context Builder

struct WorkoutsContextBuilder {
    func build(from workouts: [WorkoutSummary]) -> [String: String] {
        guard !workouts.isEmpty else {
            return ["note": "No workouts recorded today.", "count": "0"]
        }
        let totalKcal = workouts.compactMap(\.energyKilocalories).reduce(0, +)
        let totalDurationMin = workouts.map { Int($0.end.timeIntervalSince($0.start) / 60) }.reduce(0, +)
        let types = Set(workouts.map(\.activityName)).sorted().joined(separator: ", ")
        let workoutList: [[String: String]] = workouts.map { w in
            var d: [String: String] = [
                "type": w.activityName,
                "duration_min": "\(Int(w.end.timeIntervalSince(w.start) / 60))"
            ]
            if let kcal = w.energyKilocalories { d["calories"] = "\(Int(kcal))" }
            if let hr = w.averageHeartRate { d["avg_hr_bpm"] = "\(Int(hr))" }
            if let dist = w.distanceMeters { d["distance_m"] = String(format: "%.0f", dist) }
            return d
        }
        let listJSON = (try? String(data: JSONEncoder().encode(workoutList), encoding: .utf8)) ?? "[]"
        return [
            "count": "\(workouts.count)",
            "types": types,
            "total_energy_kcal": "\(Int(totalKcal))",
            "total_duration_min": "\(totalDurationMin)",
            "list": listJSON
        ]
    }
}

// MARK: - Extended Metrics Context Builder

struct ExtendedMetricsContextBuilder {
    func build(ext: ExtendedHealthMetrics, body: BodyMetricsSummary) -> [String: String] {
        var d: [String: String] = [:]
        if let age = WikiFileService.getAgeFromWiki() ?? ext.age {
            d["age"] = "\(age)"
        }
        if let sex = ext.biologicalSex { d["biological_sex"] = sex }
        if let h = ext.heightCm { d["height_cm"] = String(format: "%.1f", h) }
        if let bmi = ext.bmi { d["bmi"] = String(format: "%.1f", bmi) }
        if let w = body.weightKilograms { d["weight_kg"] = String(format: "%.1f", w) }
        if let bf = body.bodyFatPercentage { d["body_fat_pct"] = String(format: "%.1f", bf) }
        if let lbm = body.leanBodyMassKilograms { d["lean_body_mass_kg"] = String(format: "%.1f", lbm) }
        if let vo2 = body.vo2Max { d["vo2_max"] = String(format: "%.1f", vo2) }
        if let spo2 = ext.oxygenSaturation { d["spo2_pct"] = String(format: "%.0f", spo2) }
        if let sbp = ext.bloodPressureSystolic { d["blood_pressure_systolic"] = "\(Int(sbp))" }
        if let dbp = ext.bloodPressureDiastolic { d["blood_pressure_diastolic"] = "\(Int(dbp))" }
        if let glucose = ext.bloodGlucose { d["blood_glucose_mgdl"] = String(format: "%.0f", glucose) }
        if let ws = ext.walkingSpeed { d["walking_speed_ms"] = String(format: "%.2f", ws) }
        if let wa = ext.walkingAsymmetry { d["walking_asymmetry_pct"] = String(format: "%.1f", wa) }
        if let temp = ext.bodyTemperature { d["body_temp_c"] = String(format: "%.1f", temp) }
        if let water = ext.waterMl { d["water_ml"] = "\(Int(water))" }
        if let caff = ext.caffeineMg { d["caffeine_mg"] = "\(Int(caff))" }
        if let mindful = ext.mindfulMinutes { d["mindful_minutes"] = "\(Int(mindful))" }
        return d
    }
}
