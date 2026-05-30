import Foundation

struct EnergyBankInput: Hashable {
    var recoveryScore: Double?
    var sleepScore: Double?
    var strainScore: Double?
    var stressIndex: Double?

    // Research-backed inputs for charge/discharge model
    var hrvToday: Double?          // HRV in ms (RMSSD)
    var hrvBaseline: Double?        // 7-day rolling average
    var rhrToday: Double?           // RHR in bpm
    var rhrBaseline: Double?        // 7-day rolling average
    var sleepHours: Double?         // Total sleep duration in hours
    var strainHistory: [Double]?    // Last 42 days of strain scores
    var bodyTempDelta: Double?      // Deviation from baseline temp (°C)
}

enum EnergyBankStatus: String, Codable, Hashable {
    case depleted = "Depleted"
    case low = "Low"
    case stable = "Stable"
    case strong = "Strong"
}

struct EnergyBankResult: Codable, Hashable {
    var morningEnergy: Double
    var currentEnergy: Double
    var status: EnergyBankStatus
    var confidence: ScoreConfidence
    var components: [String: Double]
    var reasons: [String]
    var metrics: [String: Double]
    var configVersion: String = VelaAppMetadata.configVersion

    var hasData: Bool { !components.isEmpty }
}

struct EnergyBankEngine: ScoreEngine {
    func calculate(from input: EnergyBankInput) -> EnergyBankResult {
        let recovery = input.recoveryScore.map { ScoringMath.clamp($0) }
        let sleep = input.sleepScore.map { ScoringMath.clamp($0) }
        let strain = input.strainScore.map { ScoringMath.clamp($0) } ?? 0
        let stress = input.stressIndex.map { ScoringMath.clamp($0) } ?? 0

        var components: [String: Double] = [:]
        var reasons: [String] = []
        var metrics: [String: Double] = [:]

        if let recovery {
            components["recovery"] = recovery
        } else {
            reasons.append("Recovery score unavailable.")
        }

        if let sleep {
            components["sleep"] = sleep
        } else {
            reasons.append("Sleep score unavailable.")
        }

        // ── Firstbeat-Inspired Charge Efficiency ──
        // During sleep: high HRV + low RHR = parasympathetic dominance = good charge
        // During sleep: low HRV + high RHR = sympathetic residual = poor charge
        let chargeEfficiency = computeChargeEfficiency(input)
        metrics["charge_efficiency"] = chargeEfficiency
        if input.hrvToday != nil, input.hrvBaseline != nil {
            if chargeEfficiency >= 0.8 {
                reasons.append("Sleep charge was efficient — strong parasympathetic recovery.")
            } else if chargeEfficiency < 0.5 {
                reasons.append("Sleep charge was inefficient — possible sympathetic residual.")
            }
        }

        // ── Morning Energy (Base Charge) ──
        let morningEnergy: Double
        if let recovery, let sleep {
            // Weighted by charge efficiency: better charge = more morning energy
            let baseEnergy = (0.55 * recovery) + (0.30 * sleep) + (0.15 * chargeEfficiency * 100)
            morningEnergy = ScoringMath.clamp(baseEnergy)
            reasons.append("Morning energy: recovery + sleep + HRV-based charge efficiency.")
            components["charge_efficiency"] = chargeEfficiency * 100
        } else if let recovery {
            morningEnergy = recovery
            reasons.append("Morning energy used recovery only (sleep unavailable).")
        } else if let sleep {
            morningEnergy = sleep
            reasons.append("Morning energy used sleep only (recovery unavailable).")
        } else {
            morningEnergy = 0
            reasons.append("Morning energy unavailable.")
        }

        // ── TRIMP-Inspired ATL / CTL / TSB ──
        let atlCtl = computeATLCTL(strainHistory: input.strainHistory, todayStrain: strain)
        metrics["atl"] = atlCtl.atl
        metrics["ctl"] = atlCtl.ctl
        metrics["tsb"] = atlCtl.tsb

        if atlCtl.hasHistory {
            if atlCtl.tsb < -15 {
                reasons.append("Training Stress Balance negative — accumulated fatigue may impair energy.")
            } else if atlCtl.tsb > 10 {
                reasons.append("Positive TSB — training freshness may boost perceived energy.")
            }
        }

        // ── Energy Drain Calculation ──
        // 1. Strain drain — non-linear (TRIMP-like exponential weighting)
        let strainDrain: Double
        if strain > 60 {
            strainDrain = 0.45 * strain + 0.15 * (strain - 60) // extra penalty for high strain
        } else {
            strainDrain = 0.40 * strain
        }
        metrics["strain_drain"] = strainDrain

        // 2. Stress drain
        let stressDrain = 0.25 * stress
        metrics["stress_drain"] = stressDrain

        // 2b. Cumulative Fatigue / ACWR drain (Windt & Gabbett 2016)
        // High ACWR (>1.5) representing acute workload spikes increases injury risk and cumulative systemic fatigue,
        // accelerating the daily energy bank baseline discharge.
        var acwrDrain = 0.0
        if atlCtl.ctl > 0 {
            let acwr = atlCtl.atl / atlCtl.ctl
            metrics["acwr"] = acwr
            if acwr > 1.5 {
                acwrDrain = min(20.0, (acwr - 1.5) * 20.0) // up to 20 pts penalty
                reasons.append("Acute-to-Chronic Workload Ratio high (ACWR=\(String(format: "%.2f", acwr))) — accelerated discharge due to cumulative fatigue")
            }
        }
        metrics["acwr_drain"] = acwrDrain

        // 3. Allostatic load adjustment (elevated body temp → systemic stress)
        var allostaticDrain: Double = 0
        if let tempDelta = input.bodyTempDelta, abs(tempDelta) > 0.5 {
            allostaticDrain = min(15, abs(tempDelta) * 8) // up to ~15pts for fever-level temp
            metrics["allostatic_drain"] = allostaticDrain
            reasons.append("Elevated body temperature suggests systemic load — energy adjusted.")
        }

        // 4. Sleep debt drain (short sleep = energy penalty)
        var sleepDebtDrain: Double = 0
        if let sleepHours = input.sleepHours, sleepHours < 6 {
            sleepDebtDrain = (6 - sleepHours) * 5 // up to ~15pts for very short sleep
            metrics["sleep_debt_drain"] = sleepDebtDrain
        }

        let totalDrain = strainDrain + stressDrain + acwrDrain + allostaticDrain + sleepDebtDrain
        let currentEnergy = ScoringMath.clamp(morningEnergy - totalDrain)
        reasons.append("Current energy = morning energy − strain drain − stress drain − allostatic/sleep adjustments.")

        return EnergyBankResult(
            morningEnergy: morningEnergy,
            currentEnergy: currentEnergy,
            status: status(for: currentEnergy),
            confidence: ScoringMath.confidence(available: components.count, expected: 2),
            components: components,
            reasons: reasons,
            metrics: metrics
        )
    }

    // MARK: - Firstbeat Charge/Discharge Assessment

    /// Calculates how efficiently the body "charged" during sleep.
    /// Returns 0.0–1.0 where 1.0 = optimal parasympathetic recovery.
    /// Based on: high HRV + low RHR = parasympathetic dominance = good recovery
    /// (Firstbeat absolute recovery vector; Plews/Buchheit HRV principles)
    private func computeChargeEfficiency(_ input: EnergyBankInput) -> Double {
        guard let hrvToday = input.hrvToday,
              let hrvBaseline = input.hrvBaseline,
              hrvBaseline > 0,
              let rhrToday = input.rhrToday,
              let rhrBaseline = input.rhrBaseline,
              rhrBaseline > 0 else {
            return 0.6 // default: assume moderate charge when no data
        }

        // HRV: higher than baseline = good (parasympathetic)
        let hrvRatio = hrvToday / hrvBaseline
        let hrvScore: Double
        switch hrvRatio {
        case ..<0.8:  hrvScore = 0.2  // significantly suppressed
        case ..<0.9:  hrvScore = 0.4
        case ..<1.1:  hrvScore = 0.7  // near baseline
        case ..<1.3:  hrvScore = 0.9  // above baseline
        default:      hrvScore = 1.0  // significantly elevated
        }

        // RHR: lower than baseline = good (efficient)
        let rhrRatio = rhrToday / rhrBaseline
        let rhrScore: Double
        switch rhrRatio {
        case ..<0.90: rhrScore = 1.0  // significantly lower
        case ..<0.95: rhrScore = 0.9
        case ..<1.05: rhrScore = 0.7  // near baseline
        case ..<1.10: rhrScore = 0.4
        default:      rhrScore = 0.2  // significantly elevated
        }

        // Weighted: HRV is the stronger signal per Firstbeat/Whoop research
        return (0.6 * hrvScore) + (0.4 * rhrScore)
    }

    // MARK: - TRIMP / Banister ATL · CTL · TSB

    private struct ATLCTLResult {
        var atl: Double
        var ctl: Double
        var tsb: Double
        var hasHistory: Bool
    }

    /// Computes Acute Training Load (7-day), Chronic Training Load (42-day),
    /// and Training Stress Balance from strain history.
    /// Based on Banister's impulse-response model with exponential decay.
    private func computeATLCTL(strainHistory: [Double]?, todayStrain: Double) -> ATLCTLResult {
        guard let history = strainHistory, !history.isEmpty else {
            return ATLCTLResult(atl: todayStrain, ctl: todayStrain, tsb: 0, hasHistory: false)
        }

        // Exponential decay constants (standard Banister values)
        let tauA = 7.0   // ATL time constant (days)
        let tauC = 42.0  // CTL time constant (days)

        var atl = 0.0
        var ctl = 0.0

        // Iterate from oldest to newest
        let allStrains = history + [todayStrain]
        for (i, strain) in allStrains.enumerated() {
            let daysAgo = Double(allStrains.count - 1 - i)
            let decayA = exp(-daysAgo / tauA)
            let decayC = exp(-daysAgo / tauC)
            atl += strain * decayA
            ctl += strain * decayC
        }

        // Normalize
        let normA = allStrains.indices.reduce(0.0) { $0 + exp(-Double(allStrains.count - 1 - $1) / tauA) }
        let normC = allStrains.indices.reduce(0.0) { $0 + exp(-Double(allStrains.count - 1 - $1) / tauC) }
        atl = normA > 0 ? atl / normA : atl
        ctl = normC > 0 ? ctl / normC : ctl

        let tsb = ctl - atl

        return ATLCTLResult(atl: atl, ctl: ctl, tsb: tsb, hasHistory: true)
    }

    // MARK: - Status

    private func status(for energy: Double) -> EnergyBankStatus {
        switch energy {
        case ..<25:
            return .depleted
        case ..<50:
            return .low
        case ..<75:
            return .stable
        default:
            return .strong
        }
    }
}
