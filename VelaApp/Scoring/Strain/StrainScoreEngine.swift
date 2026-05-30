import Foundation

public struct WorkoutInput: Codable, Hashable {
    public var id: UUID
    public var durationMinutes: Double
    public var averageHeartRate: Double?
    public var heartRateSamples: [Double] = []

    public init(
        id: UUID = UUID(),
        durationMinutes: Double,
        averageHeartRate: Double? = nil,
        heartRateSamples: [Double] = []
    ) {
        self.id = id
        self.durationMinutes = durationMinutes
        self.averageHeartRate = averageHeartRate
        self.heartRateSamples = heartRateSamples
    }
}

public struct StrainScoreInput: Hashable {
    public var workouts: [WorkoutInput] = []
    public var activeEnergyToday: Double?
    public var exerciseMinutesToday: Double?
    public var stepCount: Double?
    
    public var restingHR: Double
    public var maxHR: Double
    public var biologicalSex: String? // "male" / "female" / "other"
    
    public var last28DaysDailyLoads: [Double] = [] // historical daily loads
    
    // Legacy support fields
    public var activeEnergyBaseline: Double?
    public var exerciseMinutesBaseline: Double?
    public var workoutIntensityLoad: Double?
    public var recoveryScore: Double?

    public init(
        workouts: [WorkoutInput] = [],
        activeEnergyToday: Double? = nil,
        exerciseMinutesToday: Double? = nil,
        stepCount: Double? = nil,
        restingHR: Double = 60,
        maxHR: Double = 190,
        biologicalSex: String? = nil,
        last28DaysDailyLoads: [Double] = [],
        activeEnergyBaseline: Double? = nil,
        exerciseMinutesBaseline: Double? = nil,
        workoutIntensityLoad: Double? = nil,
        recoveryScore: Double? = nil
    ) {
        self.workouts = workouts
        self.activeEnergyToday = activeEnergyToday
        self.exerciseMinutesToday = exerciseMinutesToday
        self.stepCount = stepCount
        self.restingHR = restingHR
        self.maxHR = maxHR
        self.biologicalSex = biologicalSex
        self.last28DaysDailyLoads = last28DaysDailyLoads
        self.activeEnergyBaseline = activeEnergyBaseline
        self.exerciseMinutesBaseline = exerciseMinutesBaseline
        self.workoutIntensityLoad = workoutIntensityLoad
        self.recoveryScore = recoveryScore
    }
}



public struct StrainScoreEngine: ScoreEngine {
    public typealias Input = StrainScoreInput
    public typealias Output = MetricResult

    public init() {}

    private func calculateMedian(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        if sorted.count % 2 == 1 {
            return sorted[sorted.count / 2]
        } else {
            return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
        }
    }

    public func calculate(from input: StrainScoreInput) -> MetricResult {
        var components: [String: Double] = [:]
        var componentWeights: [String: Double] = [:]
        var reasons: [String] = []
        var missingInputs: [String] = []

        let restingHR = input.restingHR > 0 ? input.restingHR : 60.0
        let maxHR = input.maxHR > restingHR ? input.maxHR : 190.0
        let hrRange = maxHR - restingHR

        // 1. Calculate Workout Loads
        var totalWorkoutLoad = 0.0
        for workout in input.workouts {
            var workoutLoad = 0.0
            if !workout.heartRateSamples.isEmpty {
                // Method A: Time-in-zone Lucia's TRIMP
                let sampleWeight = workout.durationMinutes / Double(workout.heartRateSamples.count)
                for hr in workout.heartRateSamples {
                    let hrr = (hr - restingHR) / hrRange
                    let weight: Double
                    if hrr >= 0.90 {
                        weight = 8.0 // Z5
                    } else if hrr >= 0.80 {
                        weight = 5.0 // Z4
                    } else if hrr >= 0.70 {
                        weight = 3.0 // Z3
                    } else if hrr >= 0.60 {
                        weight = 2.0 // Z2
                    } else if hrr >= 0.50 {
                        weight = 1.0 // Z1
                    } else {
                        weight = 0.5
                    }
                    workoutLoad += sampleWeight * weight
                }
            } else if let avgHR = workout.averageHeartRate {
                // Method B: Banister TRIMP using average heart rate fallback
                let hrr = (avgHR - restingHR) / hrRange
                let clampedHRR = ScoringMath.clamp(hrr, min: 0.01, max: 1.0)
                let trimp: Double
                if input.biologicalSex == "male" {
                    trimp = workout.durationMinutes * clampedHRR * 0.64 * exp(1.92 * clampedHRR)
                } else if input.biologicalSex == "female" {
                    trimp = workout.durationMinutes * clampedHRR * 0.86 * exp(1.67 * clampedHRR)
                } else {
                    // gender neutral fallback
                    trimp = workout.durationMinutes * clampedHRR * 0.75 * exp(1.80 * clampedHRR)
                }
                workoutLoad = trimp
            } else {
                // Method C: duration fallback
                workoutLoad = workout.durationMinutes * 1.5
            }
            totalWorkoutLoad += workoutLoad
        }

        // 2. Non-workout activity load
        let activeEnergy = input.activeEnergyToday ?? 0.0
        let steps = input.stepCount ?? 0.0
        let exerciseMin = input.exerciseMinutesToday ?? 0.0
        
        let rawActivityLoad = 0.02 * activeEnergy + 0.0015 * steps + 0.5 * exerciseMin
        let activityMultiplier = input.workouts.isEmpty ? 1.0 : 0.35
        let activityLoad = rawActivityLoad * activityMultiplier

        // Total daily load
        let dailyLoad = totalWorkoutLoad + activityLoad

        // 3. Baseline & Score Mapping
        let historyToUse = input.last28DaysDailyLoads.filter { $0 > 0 }
        let baselineDailyLoad = calculateMedian(historyToUse) ?? 60.0
        let loadRatio = dailyLoad / baselineDailyLoad
        
        // Logarithmic saturation Daily Strain curve
        let strainValue = 100.0 * (1.0 - exp(-0.75 * loadRatio))
        
        components["workout_load"] = totalWorkoutLoad
        components["activity_load"] = activityLoad
        components["raw_activity_load"] = rawActivityLoad
        components["activity_multiplier"] = activityMultiplier
        components["daily_load"] = dailyLoad
        components["steps_raw"] = steps
        components["active_energy_raw"] = activeEnergy
        components["exercise_minutes_raw"] = exerciseMin
        
        componentWeights["workout_load"] = 0.60
        componentWeights["activity_load"] = 0.40

        // Reasons
        if !input.workouts.isEmpty {
            reasons.append("今日完成了 \(input.workouts.count) 次运动训练，贡献了主要身体负荷")
        }
        reasons.append("非运动日常活动负荷为 \(Int(activityLoad)) (步数: \(Int(steps)), 活动能量: \(Int(activeEnergy)) kcal)")

        // 4. Training Load Status (ATL / CTL)
        let acute7 = dailyLoad + input.last28DaysDailyLoads.suffix(6).reduce(0, +)
        
        let chronicHistory = Array(input.last28DaysDailyLoads.suffix(28))
        let chronicSum = chronicHistory.reduce(0, +)
        let chronic28Equivalent = chronicHistory.isEmpty ? baselineDailyLoad * 7.0 : chronicSum / 4.0
        
        let trainingLoadRatio = chronic28Equivalent > 0 ? acute7 / chronic28Equivalent : 1.0

        let loadStatus: TrainingLoadStatus
        if trainingLoadRatio < 0.60 {
            loadStatus = .wellBelow
            reasons.append("近期训练负荷显著低于过去 28 天平均水平，可能处于减量或停训状态。")
        } else if trainingLoadRatio <= 0.85 {
            loadStatus = .below
            reasons.append("近期训练负荷略低于基线水平。")
        } else if trainingLoadRatio <= 1.20 {
            loadStatus = .optimal
            reasons.append("近期训练负荷处于最佳提升区间，体能正在稳步发展。")
        } else if trainingLoadRatio <= 1.50 {
            loadStatus = .elevated
            reasons.append("近期训练负荷已偏高，建议控制强度，避免连续高负荷。")
        } else {
            loadStatus = .highRisk
            reasons.append("近期训练负荷显著高于过去 28 天平均水平，建议控制增量，防范运动伤病。")
        }

        components["training_load_ratio"] = trainingLoadRatio
        components["acute_7d_load"] = acute7
        components["chronic_28d_equivalent"] = chronic28Equivalent
        let statusCode: Double
        switch loadStatus {
        case .wellBelow: statusCode = 0.0
        case .below: statusCode = 1.0
        case .optimal: statusCode = 2.0
        case .elevated: statusCode = 3.0
        case .highRisk: statusCode = 4.0
        }
        components["training_load_status_code"] = statusCode
        components["recommended_lower"] = Double(recommendedRange(for: input.recoveryScore).lowerBound)
        components["recommended_upper"] = Double(recommendedRange(for: input.recoveryScore).upperBound)

        let band = ScoringMath.band(for: strainValue)
        let confidence: MetricConfidence = input.activeEnergyToday != nil ? .high : .medium

        let dataWindow = DateInterval(start: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(), end: Date())

        return MetricResult(
            name: "Strain Score",
            value: strainValue,
            band: band,
            confidence: confidence,
            components: components,
            componentWeights: componentWeights,
            reasons: reasons,
            missingInputs: missingInputs,
            dataWindow: dataWindow,
            source: .healthKit,
            algorithmVersion: "1.0.0",
            lastUpdated: Date()
        )
    }

    private func recommendedRange(for recoveryScore: Double?) -> ClosedRange<Int> {
        guard let recoveryScore else { return 40...70 }
        if recoveryScore < 40 {
            return 15...40   // Low recovery → rest or very light
        } else if recoveryScore < 70 {
            return 35...65   // Moderate → controlled training
        } else {
            return 55...85   // High recovery → can push harder
        }
    }
}
