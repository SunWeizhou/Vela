import Foundation

public struct BiologicalAgeInput {
    public var chronologicalAge: Double
    public var restingHR: Double?
    public var vo2Max: Double?
    public var sleepHours: Double?
    public var sleepEfficiency: Double?
    public var steps: Double?
    public var biomarkers: [BiomarkerRecord]
    
    // Core Metrics v1 extensions
    public var bodyFatPercentage: Double?
    public var leanMassRatio: Double?
    public var bloodPressureSystolic: Double?
    public var bloodPressureDiastolic: Double?
    public var sleepScore: Double?

    public init(
        chronologicalAge: Double = 30.0,
        restingHR: Double? = nil,
        vo2Max: Double? = nil,
        sleepHours: Double? = nil,
        sleepEfficiency: Double? = nil,
        steps: Double? = nil,
        biomarkers: [BiomarkerRecord] = [],
        bodyFatPercentage: Double? = nil,
        leanMassRatio: Double? = nil,
        bloodPressureSystolic: Double? = nil,
        bloodPressureDiastolic: Double? = nil,
        sleepScore: Double? = nil
    ) {
        self.chronologicalAge = chronologicalAge
        self.restingHR = restingHR
        self.vo2Max = vo2Max
        self.sleepHours = sleepHours
        self.sleepEfficiency = sleepEfficiency
        self.steps = steps
        self.biomarkers = biomarkers
        self.bodyFatPercentage = bodyFatPercentage
        self.leanMassRatio = leanMassRatio
        self.bloodPressureSystolic = bloodPressureSystolic
        self.bloodPressureDiastolic = bloodPressureDiastolic
        self.sleepScore = sleepScore
    }
}

public struct BiologicalAgeResult {
    public var biologicalAge: Double
    public var overallScore: Double // 0-100
    public var wearableScore: Double // 0-100
    public var biomarkerScore: Double // 0-100
    public var suboptimalCount: Int
    public var optimalCount: Int
    public var factors: [BiologicalAgeFactor]
    
    // Core Metrics v1 fields
    public var isPhenoAge: Bool
    public var healthAgeTrend: String // "improving" / "stable" / "worsening"
    public var healthAgeTrendScore: Double // -1.0 to +1.0
    
    public var healthAgeTrendLabel: String {
        switch healthAgeTrend {
        case "improving":
            return L10n.t("Improving", "改善")
        case "worsening":
            return L10n.t("Worsening", "变差")
        default:
            return L10n.t("Stable", "稳定")
        }
    }
}

public struct BiologicalAgeFactor: Identifiable {
    public var id = UUID()
    public var name: String
    public var score: Double
    public var isOptimal: Bool
    public var description: String
    public var type: FactorType

    public enum FactorType {
        case wearable
        case biomarker
    }
}

public final class BiologicalAgeEngine {
    public init() {}

    public func calculate(input: BiologicalAgeInput) -> BiologicalAgeResult {
        var factors: [BiologicalAgeFactor] = []

        // Extract the 9 clinical biomarkers needed for Levine PhenoAge
        let albumin = input.biomarkers.first { $0.name.lowercased().contains("albumin") }?.value
        let creatinine = input.biomarkers.first { $0.name.lowercased().contains("creatinine") }?.value
        let glucose = input.biomarkers.first { $0.name.lowercased().contains("glucose") }?.value
        let crp = input.biomarkers.first { $0.name.lowercased().contains("crp") || $0.name.lowercased().contains("c-reactive") }?.value
        let lymphocyte = input.biomarkers.first { $0.name.lowercased().contains("lymphocyte") }?.value
        let mcv = input.biomarkers.first { $0.name.lowercased().contains("mcv") }?.value
        let rdw = input.biomarkers.first { $0.name.lowercased().contains("rdw") }?.value
        let alkPhos = input.biomarkers.first { $0.name.lowercased().contains("alkaline") || $0.name.lowercased().contains("alp") }?.value
        let wbc = input.biomarkers.first { $0.name.lowercased().contains("wbc") || $0.name.lowercased().contains("white blood cell") }?.value

        let allBiomarkersPresent = [albumin, creatinine, glucose, crp, lymphocyte, mcv, rdw, alkPhos, wbc].allSatisfy { $0 != nil }

        if allBiomarkersPresent,
           let alb = albumin, let cre = creatinine, let glu = glucose, let cReactive = crp,
           let lymp = lymphocyte, let mc = mcv, let rd = rdw, let alp = alkPhos, let wb = wbc {
            
            // ── Levine PhenoAge Clinical Estimation Mode ──
            let age = input.chronologicalAge
            let lnCRP = log(max(cReactive, 0.01))
            
            // Cox Proportional Hazard xb linear predictor
            let xb = -9.9269 + 0.0413 * age - 0.0055 * alb + 0.0916 * cre + 0.0039 * glu + 0.0895 * lnCRP - 0.0120 * lymp + 0.0268 * mc + 0.3306 * rd + 0.0019 * alp + 0.0554 * wb
            let S = exp(-exp(xb))
            let phenoAge = 141.50 + log(-log(S) / 0.005) / 0.09015
            
            // Map factors for display
            let bms = [
                ("Albumin", alb, 3.5...5.0, "Albumin indicates visceral protein reserve."),
                ("Creatinine", cre, 0.6...1.2, "Creatinine tracks kidney filtration capacity."),
                ("Glucose", glu, 70.0...100.0, "Glucose indicates metabolic sugar balance."),
                ("C-Reactive Protein (CRP)", cReactive, 0.0...3.0, "CRP is a systemic inflammation indicator."),
                ("Lymphocyte Percentage", lymp, 20.0...40.0, "Lymphocytes represent immune cell health."),
                ("MCV", mc, 80.0...100.0, "MCV indicates red cell size/anemia trends."),
                ("RDW", rd, 11.0...15.0, "RDW tracks red cell size variation."),
                ("Alkaline Phosphatase", alp, 44.0...147.0, "ALP represents liver/bone enzyme levels."),
                ("WBC", wb, 4.0...11.0, "WBC indicates total immune white blood cells.")
            ]
            
            var optimalCount = 0
            var suboptimalCount = 0
            for bm in bms {
                let isOptimal = bm.2.contains(bm.1)
                if isOptimal { optimalCount += 1 } else { suboptimalCount += 1 }
                
                factors.append(BiologicalAgeFactor(
                    name: bm.0,
                    score: isOptimal ? 100.0 : 50.0,
                    isOptimal: isOptimal,
                    description: isOptimal ? "Optimal range." : "Outside optimal bounds.",
                    type: .biomarker
                ))
            }
            
            let overallScore = Double(optimalCount) / Double(bms.count) * 100.0

            return BiologicalAgeResult(
                biologicalAge: phenoAge,
                overallScore: overallScore,
                wearableScore: 90.0,
                biomarkerScore: overallScore,
                suboptimalCount: suboptimalCount,
                optimalCount: optimalCount,
                factors: factors,
                isPhenoAge: true,
                healthAgeTrend: "stable",
                healthAgeTrendScore: 0.0
            )
            
        } else {
            
            // ── Health Age Trend Beta Mode ──
            var factorDirections: [Double] = []
            
            // VO2Max
            if let vo2 = input.vo2Max {
                let dir = vo2 >= 45.0 ? 1.0 : (vo2 < 35.0 ? -1.0 : 0.0)
                factorDirections.append(dir)
                factors.append(BiologicalAgeFactor(
                    name: L10n.t("VO2 Max", "最大摄氧量"),
                    score: dir > 0 ? 100.0 : (dir < 0 ? 30.0 : 70.0),
                    isOptimal: dir >= 0,
                    description: dir > 0 ? L10n.t("Superb aerobic capacity.", "心肺耐力水平极佳。") : L10n.t("Aerobic fitness has room to improve.", "心肺耐力有待提升。"),
                    type: .wearable
                ))
            }
            
            // RHR
            if let rhr = input.restingHR {
                let dir = rhr < 60.0 ? 1.0 : (rhr > 72.0 ? -1.0 : 0.0)
                factorDirections.append(dir)
                factors.append(BiologicalAgeFactor(
                    name: L10n.t("Resting Heart Rate", "静息心率"),
                    score: dir > 0 ? 100.0 : (dir < 0 ? 30.0 : 70.0),
                    isOptimal: dir >= 0,
                    description: dir > 0 ? L10n.t("Excellent cardiac efficiency.", "心肺效率极佳。") : L10n.t("Elevated heart rate indicates load.", "心肺负荷略有升高。"),
                    type: .wearable
                ))
            }
            
            // Sleep
            if let sleep = input.sleepScore ?? input.sleepHours.map({ $0 * 10.0 }) {
                let dir = sleep >= 80.0 ? 1.0 : (sleep < 60.0 ? -1.0 : 0.0)
                factorDirections.append(dir)
                factors.append(BiologicalAgeFactor(
                    name: L10n.t("Sleep Quality", "睡眠质量"),
                    score: dir > 0 ? 100.0 : (dir < 0 ? 30.0 : 70.0),
                    isOptimal: dir >= 0,
                    description: dir > 0 ? L10n.t("Excellent restorative sleep.", "深度睡眠恢复极佳。") : L10n.t("Poor sleep recovery.", "睡眠恢复质量欠佳。"),
                    type: .wearable
                ))
            }
            
            // Steps
            if let steps = input.steps {
                let dir = steps >= 10000.0 ? 1.0 : (steps < 5000.0 ? -1.0 : 0.0)
                factorDirections.append(dir)
                factors.append(BiologicalAgeFactor(
                    name: L10n.t("Daily Steps", "每日步数"),
                    score: dir > 0 ? 100.0 : (dir < 0 ? 30.0 : 70.0),
                    isOptimal: dir >= 0,
                    description: dir > 0 ? L10n.t("Highly active metabolic status.", "代谢非常活跃。") : L10n.t("Sedentary metabolic status.", "日常久坐活动量低。"),
                    type: .wearable
                ))
            }

            let trendScore = factorDirections.isEmpty ? 0.0 : factorDirections.reduce(0.0, +) / Double(factorDirections.count)
            
            let trend: String
            if trendScore >= 0.35 {
                trend = "improving"
            } else if trendScore <= -0.35 {
                trend = "worsening"
            } else {
                trend = "stable"
            }
            
            // Map to a mock biological age that is slightly modified by trend for visual progress
            let biologicalAge = max(18.0, input.chronologicalAge - trendScore * 3.5)
            
            let optimalCount = factors.filter { $0.isOptimal }.count
            let suboptimalCount = factors.count - optimalCount
            
            // Map trend score to 0-100 overall Score
            let overallScore = ScoringMath.clamp(50.0 + trendScore * 50.0, min: 0, max: 100)

            return BiologicalAgeResult(
                biologicalAge: biologicalAge,
                overallScore: overallScore,
                wearableScore: overallScore,
                biomarkerScore: 80.0, // default neutral
                suboptimalCount: suboptimalCount,
                optimalCount: optimalCount,
                factors: factors,
                isPhenoAge: false,
                healthAgeTrend: trend,
                healthAgeTrendScore: trendScore
            )
        }
    }
}
