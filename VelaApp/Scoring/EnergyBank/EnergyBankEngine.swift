import Foundation

public struct EnergyBankInput: Hashable {
    public var recoveryScore: Double?
    public var sleepScore: Double?
    public var strainScore: Double?
    public var stressIndex: Double?

    public var hrvToday: Double?
    public var hrvBaseline: Double?
    public var rhrToday: Double?
    public var rhrBaseline: Double?
    public var sleepHours: Double?
    public var strainHistory: [Double]?
    public var bodyTempDelta: Double?
    
    // New fields for Core Metrics v1
    public var hoursSinceWake: Double?
    public var respiratoryRateZ: Double?
    public var SpO2: Double?
    public var mindfulMinutes: Double?
    public var napMinutes: Double?
    public var trainingLoadStatus: TrainingLoadStatus?

    public init(
        recoveryScore: Double?,
        sleepScore: Double?,
        strainScore: Double?,
        stressIndex: Double?,
        hrvToday: Double? = nil,
        hrvBaseline: Double? = nil,
        rhrToday: Double? = nil,
        rhrBaseline: Double? = nil,
        sleepHours: Double? = nil,
        strainHistory: [Double]? = nil,
        bodyTempDelta: Double? = nil,
        hoursSinceWake: Double? = nil,
        respiratoryRateZ: Double? = nil,
        SpO2: Double? = nil,
        mindfulMinutes: Double? = nil,
        napMinutes: Double? = nil,
        trainingLoadStatus: TrainingLoadStatus? = nil
    ) {
        self.recoveryScore = recoveryScore
        self.sleepScore = sleepScore
        self.strainScore = strainScore
        self.stressIndex = stressIndex
        self.hrvToday = hrvToday
        self.hrvBaseline = hrvBaseline
        self.rhrToday = rhrToday
        self.rhrBaseline = rhrBaseline
        self.sleepHours = sleepHours
        self.strainHistory = strainHistory
        self.bodyTempDelta = bodyTempDelta
        self.hoursSinceWake = hoursSinceWake
        self.respiratoryRateZ = respiratoryRateZ
        self.SpO2 = SpO2
        self.mindfulMinutes = mindfulMinutes
        self.napMinutes = napMinutes
        self.trainingLoadStatus = trainingLoadStatus
    }
}

public struct EnergyBankEngine: ScoreEngine {
    public typealias Input = EnergyBankInput
    public typealias Output = MetricResult

    public init() {}

    public func calculate(from input: EnergyBankInput) -> MetricResult {
        var components: [String: Double] = [:]
        var reasons: [String] = []
        var missingInputs: [String] = []

        // 1. Overnight Stability (100 base)
        var overnightStability = 100.0
        if let bodyTempDelta = input.bodyTempDelta, bodyTempDelta > 0.5 {
            overnightStability -= 15.0
            reasons.append("夜间体温升高，扣除稳定性基准分")
        }
        if let rrZ = input.respiratoryRateZ, rrZ > 1.5 {
            overnightStability -= 10.0
        }
        if let spO2 = input.SpO2, spO2 < 94 {
            overnightStability -= 10.0
        }
        components["overnight_stability"] = overnightStability

        // 2. Morning Energy (0.45 Recovery + 0.35 Sleep + 0.20 Stability)
        var morningEnergy = 50.0
        let rec = input.recoveryScore
        let slp = input.sleepScore

        if let rec, let slp {
            morningEnergy = 0.45 * rec + 0.35 * slp + 0.20 * overnightStability
            components["recovery"] = rec
            components["sleep"] = slp
        } else if let rec {
            morningEnergy = 0.70 * rec + 0.30 * overnightStability
            components["recovery"] = rec
            missingInputs.append("sleepScore")
            reasons.append("睡眠数据缺失，早间能量根据恢复度估算")
        } else if let slp {
            morningEnergy = 0.70 * slp + 0.30 * overnightStability
            components["sleep"] = slp
            missingInputs.append("recoveryScore")
            reasons.append("恢复度数据缺失，早间能量根据睡眠评分估算")
        } else {
            morningEnergy = overnightStability
            missingInputs.append("recoveryScore")
            missingInputs.append("sleepScore")
        }
        morningEnergy = ScoringMath.clamp(morningEnergy, min: 0, max: 100)
        components["morningEnergy"] = morningEnergy

        // 3. Day Drain Calculations
        let strainScore = input.strainScore ?? 0.0
        let stressIndex = input.stressIndex ?? 0.0
        
        let strainDrain = 0.35 * strainScore
        let stressDrain = 0.25 * stressIndex
        
        let hoursSinceWake = input.hoursSinceWake ?? 8.0
        let timeDrain = ScoringMath.clamp(hoursSinceWake / 16.0 * 12.0, min: 0, max: 12.0)
        
        // Training Load status drain
        let loadDrain: Double
        switch input.trainingLoadStatus {
        case .elevated:
            loadDrain = 5.0
            reasons.append("检测到积累性训练负荷升高，加速能量消耗")
        case .highRisk:
            loadDrain = 10.0
            reasons.append("近期负荷激增，身体处于高敏感疲劳状态，加速日间能量流失")
        default:
            loadDrain = 0.0
        }

        // 4. Recharge behaviors
        let mindful = input.mindfulMinutes ?? 0.0
        let nap = input.napMinutes ?? 0.0
        let recharge = min(8.0, mindful * 0.15 + nap * 0.20)
        if recharge > 0 {
            reasons.append("今日通过静心/小憩补充了 \(String(format: "%.1f", recharge)) 点身体能量")
        }

        // Current Energy
        let currentEnergy = ScoringMath.clamp(morningEnergy - strainDrain - stressDrain - timeDrain - loadDrain + recharge, min: 0, max: 100)

        components["strain_drain"] = strainDrain
        components["stress_drain"] = stressDrain
        components["time_drain"] = timeDrain
        components["load_drain"] = loadDrain
        components["recharge"] = recharge

        let band: MetricBand
        if currentEnergy < 25 {
            band = .veryLow // depleted
        } else if currentEnergy < 50 {
            band = .low // low
        } else if currentEnergy < 75 {
            band = .normal // stable
        } else {
            band = .high // strong
        }

        reasons.append("能量电池是全天体能代理估算值，主要用于规划今日运动与恢复，非医学诊断。")

        let dataWindow = DateInterval(start: Calendar.current.date(byAdding: .hour, value: -12, to: Date()) ?? Date(), end: Date())

        return MetricResult(
            name: "Energy Bank",
            value: currentEnergy,
            band: band,
            confidence: (rec != nil && slp != nil) ? .high : .medium,
            components: components,
            componentWeights: [:],
            reasons: reasons,
            missingInputs: missingInputs,
            dataWindow: dataWindow,
            source: .derived,
            algorithmVersion: "1.0.0",
            lastUpdated: Date()
        )
    }
}
