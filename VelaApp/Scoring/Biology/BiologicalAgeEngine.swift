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
    public var heartRateRecovery: Double?
    public var deepSleepFraction: Double?

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
        sleepScore: Double? = nil,
        heartRateRecovery: Double? = nil,
        deepSleepFraction: Double? = nil
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
        self.heartRateRecovery = heartRateRecovery
        self.deepSleepFraction = deepSleepFraction
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

    public var biologicalAgeEstimate: Double? {
        isPhenoAge ? biologicalAge : nil
    }
    
    public var healthAgeTrendLabel: String {
        switch healthAgeTrend {
        case "improving":
            return L10n.t("Favorable signals", "信号积极")
        case "worsening":
            return L10n.t("Needs attention", "需关注")
        default:
            return L10n.t("Mixed signals", "信号中性")
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

private struct CanonicalPhenoAgeInput {
    var albumin: Double
    var creatinine: Double
    var glucose: Double
    var crp: Double
    var lymphocyte: Double
    var mcv: Double
    var rdw: Double
    var alkalinePhosphatase: Double
    var wbc: Double
}

private enum PhenoAgeInputValidator {
    static func canonicalInput(from biomarkers: [BiomarkerRecord]) -> CanonicalPhenoAgeInput? {
        guard let albumin = canonicalValue(in: biomarkers, matching: ["albumin"], kind: .albumin),
              let creatinine = canonicalValue(in: biomarkers, matching: ["creatinine"], kind: .creatinine),
              let glucose = canonicalValue(in: biomarkers, matching: ["glucose"], kind: .glucose),
              let crp = canonicalValue(in: biomarkers, matching: ["crp", "c-reactive"], kind: .crp),
              let lymphocyte = canonicalValue(in: biomarkers, matching: ["lymphocyte"], kind: .percentage),
              let mcv = canonicalValue(in: biomarkers, matching: ["mcv"], kind: .mcv),
              let rdw = canonicalValue(in: biomarkers, matching: ["rdw"], kind: .percentage),
              let alkalinePhosphatase = canonicalValue(in: biomarkers, matching: ["alkaline", "alp"], kind: .alkalinePhosphatase),
              let wbc = canonicalValue(in: biomarkers, matching: ["wbc", "white blood cell"], kind: .wbc) else {
            return nil
        }

        guard (1.0...7.0).contains(albumin),
              (0.1...20.0).contains(creatinine),
              (20.0...1_000.0).contains(glucose),
              (0.0...1_000.0).contains(crp),
              (0.0...100.0).contains(lymphocyte),
              (40.0...150.0).contains(mcv),
              (5.0...40.0).contains(rdw),
              (1.0...2_000.0).contains(alkalinePhosphatase),
              (0.1...100.0).contains(wbc) else {
            return nil
        }

        return CanonicalPhenoAgeInput(
            albumin: albumin,
            creatinine: creatinine,
            glucose: glucose,
            crp: crp,
            lymphocyte: lymphocyte,
            mcv: mcv,
            rdw: rdw,
            alkalinePhosphatase: alkalinePhosphatase,
            wbc: wbc
        )
    }

    private enum BiomarkerKind {
        case albumin
        case creatinine
        case glucose
        case crp
        case percentage
        case mcv
        case alkalinePhosphatase
        case wbc
    }

    private static func canonicalValue(
        in biomarkers: [BiomarkerRecord],
        matching names: [String],
        kind: BiomarkerKind
    ) -> Double? {
        guard let record = biomarkers.first(where: { record in
            let name = record.name.lowercased()
            return names.contains { name.contains($0) }
        }) else {
            return nil
        }

        let unit = normalizedUnit(record.unit)
        switch kind {
        case .albumin:
            if unit == "g/dl" { return record.value }
            if unit == "g/l" { return record.value / 10.0 }
        case .creatinine:
            if unit == "mg/dl" { return record.value }
            if unit == "umol/l" { return record.value / 88.4 }
        case .glucose:
            if unit == "mg/dl" { return record.value }
            if unit == "mmol/l" { return record.value * 18.0182 }
        case .crp:
            if unit == "mg/l" { return record.value }
            if unit == "mg/dl" { return record.value * 10.0 }
        case .percentage:
            if unit == "%" || unit == "percent" { return record.value }
        case .mcv:
            if unit == "fl" { return record.value }
        case .alkalinePhosphatase:
            if unit == "u/l" || unit == "iu/l" { return record.value }
        case .wbc:
            if ["10^3/ul", "x10^3/ul", "k/ul", "10^9/l"].contains(unit) {
                return record.value
            }
        }
        return nil
    }

    private static func normalizedUnit(_ unit: String) -> String {
        unit.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "µ", with: "u")
            .replacingOccurrences(of: "μ", with: "u")
            .replacingOccurrences(of: "³", with: "^3")
    }
}

public final class BiologicalAgeEngine {
    public init() {}

    public func calculate(input: BiologicalAgeInput) -> BiologicalAgeResult {
        var factors: [BiologicalAgeFactor] = []

        if let phenoAgeInput = PhenoAgeInputValidator.canonicalInput(from: input.biomarkers) {
            let alb = phenoAgeInput.albumin
            let cre = phenoAgeInput.creatinine
            let glu = phenoAgeInput.glucose
            let cReactive = phenoAgeInput.crp
            let lymp = phenoAgeInput.lymphocyte
            let mc = phenoAgeInput.mcv
            let rd = phenoAgeInput.rdw
            let alp = phenoAgeInput.alkalinePhosphatase
            let wb = phenoAgeInput.wbc
            
            // ── Levine PhenoAge Clinical Estimation Mode ──
            let age = input.chronologicalAge
            let modelAlbumin = alb * 10.0 // g/dL -> g/L
            let modelCreatinine = cre * 88.4 // mg/dL -> umol/L
            let modelGlucose = glu / 18.0182 // mg/dL -> mmol/L
            // Levine PhenoAge 的 ln(CRP) 系数拟合自 NHANES 的 mg/dL 单位且取
            // ln(1 + CRP_mg/dL) 变换（BioAge 包确认）。canonicalValue 输出的
            // crp 恒为 mg/L，须先换算 mg/dL 再做 +1 偏移；直接 ln(mg/L) 会
            // 系统性 +ln(10) ≈ +2.303，使 PhenoAge 高估约 +2.4 岁。
            let modelCRP = cReactive / 10.0 // mg/L -> mg/dL
            let lnCRP = log(max(modelCRP + 1.0, 0.001))

            // Liu et al. PhenoAge model, using the paper's canonical units.
            let xb = -19.907
                - 0.0336 * modelAlbumin
                + 0.0095 * modelCreatinine
                + 0.1953 * modelGlucose
                + 0.0954 * lnCRP
                - 0.0120 * lymp
                + 0.0268 * mc
                + 0.3306 * rd
                + 0.00188 * alp
                + 0.0554 * wb
                + 0.0804 * age
            // Levine et al. (2018) PhenoAge 规范 mortality 公式（BioAge 包
            // commit 7e7764f 确认常数）：
            //   M = 1 − exp(−1.51714 × exp(xb) / 0.0076927)
            //   PhenoAge = 141.50225 + ln(−0.00553 × ln(1 − M)) / 0.090165
            // 旧实现丢掉了 1.51714 并把 ÷0.0076927 反成 ×0.0076927，hazard
            // 缩小 25,637 倍，健康 30 岁输出约 −64 岁；修复后 ≈ +23 岁。
            let mortality = 1.0 - exp(-1.51714 * exp(xb) / 0.0076927)
            let survival = max(1.0 - mortality, Double.leastNonzeroMagnitude)
            let rawPhenoAge = 141.50225 + log(-0.00553 * log(survival)) / 0.090165
            // 论文验证人群为 20–84 岁，钳制到可展示区间，避免极端化验输出负值/巨值
            let phenoAge = min(max(rawPhenoAge, 0.0), 150.0)
            
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
                wearableScore: 0.0,
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
                    description: dir > 0 ? L10n.t("Above the current reference threshold.", "高于当前参考阈值。") : L10n.t("Below the current reference threshold.", "低于当前参考阈值，可结合个人基线观察。"),
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
                    description: dir > 0 ? L10n.t("Below the current reference threshold.", "低于当前参考阈值，仍建议结合个人基线解读。") : L10n.t("Above the current reference threshold.", "高于当前参考阈值，需结合睡眠、压力和个人基线观察。"),
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
                    description: dir > 0 ? L10n.t("At or above the current reference threshold.", "达到当前参考阈值。") : L10n.t("Below the current reference threshold.", "低于当前参考阈值。"),
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
                    description: dir > 0 ? L10n.t("Activity is above the current reference threshold.", "活动量高于当前参考阈值。") : L10n.t("Activity is below the current reference threshold.", "活动量低于当前参考阈值。"),
                    type: .wearable
                ))
            }

            // Heart Rate Recovery (HRR)
            if let hrr = input.heartRateRecovery {
                let dir = hrr >= 25.0 ? 1.0 : (hrr < 15.0 ? -1.0 : 0.0)
                factorDirections.append(dir)
                factors.append(BiologicalAgeFactor(
                    name: L10n.t("Heart Rate Recovery", "心率恢复速率"),
                    score: dir > 0 ? 100.0 : (dir < 0 ? 30.0 : 70.0),
                    isOptimal: dir >= 0,
                    description: dir > 0 ? L10n.t("Vagal nerve reactivation is strong.", "迷走神经张力复常能力优秀。") : L10n.t("Heart rate recovery rate is lagging.", "心率恢复下降速率偏缓。"),
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
            
            // The beta path exposes trend only. Keep the required storage field factual.
            let biologicalAge = input.chronologicalAge
            
            let optimalCount = factors.filter { $0.isOptimal }.count
            let suboptimalCount = factors.count - optimalCount
            
            // Map trend score to 0-100 overall Score
            let overallScore = ScoringMath.clamp(50.0 + trendScore * 50.0, min: 0, max: 100)

            return BiologicalAgeResult(
                biologicalAge: biologicalAge,
                overallScore: overallScore,
                wearableScore: overallScore,
                biomarkerScore: 0.0,
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
